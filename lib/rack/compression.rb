# frozen_string_literal: true

require "zlib"
require "time"

require_relative 'constants'
require_relative 'utils'
require_relative 'request'
require_relative 'body_proxy'

module Rack
  # Rack::Compression is a middleware that enables content encoding of HTTP
  # responses for purposes of compression. It supports multiple encoding
  # algorithms and automatically negotiates the best encoding based on the
  # client's Accept-Encoding header.
  #
  # Supported encodings:
  #
  # * gzip - Standard gzip compression
  # * br - Brotli compression (if brotli gem is available)
  # * identity - No transformation
  #
  # This middleware automatically detects when encoding is supported and
  # allowed. No encoding is applied when:
  # - A cache directive of 'no-transform' is present
  # - The response status code doesn't allow an entity body
  # - The body is empty
  # - The content type is not in the include list (if specified)
  class Compression

    GZIP_MTIME = RUBY_VERSION >= "2.7" ? 0 : 1

    # Default content types that should be compressed
    DEFAULT_COMPRESSIBLE_TYPES = %w(
      text/plain
      text/html
      text/css
      text/javascript
      text/xml
      application/javascript
      application/json
      application/xml
      application/xhtml+xml
      application/rss+xml
      application/atom+xml
      application/vnd.ms-fontobject
      application/x-font-ttf
      application/x-font-opentype
      application/x-font-woff
      application/x-javascript
      application/xhtml+xml
      image/svg+xml
      image/x-icon
    ).freeze

    # Initialize the Compression middleware.
    #
    # Options:
    # :if :: A lambda that determines whether to compress based on the
    #        environment, status, headers, and body. Should return true/false.
    # :include :: An array of content types that should be compressed.
    #             By default, uses DEFAULT_COMPRESSIBLE_TYPES.
    # :exclude :: An array of content types that should NOT be compressed.
    # :level :: Compression level for gzip (0-9). Default is 6.
    # :brotli_quality :: Brotli compression quality (0-11). Default is 4.
    # :sync :: Whether to flush after every chunk. Default is +true+.
    # :encoders :: A hash of custom encoders. Keys are encoding names,
    #              values are callables that take (body, options) and return
    #              an encoded body object.
    def initialize(app, options = {})
      @app = app
      @condition = options[:if]
      @sync = options.fetch(:sync, true)
      @level = options.fetch(:level, 6)
      @brotli_quality = options.fetch(:brotli_quality, 4)
      @encoders = options[:encoders]

      if options[:include]
        @compressible_types = options[:include]
      else
        @compressible_types = DEFAULT_COMPRESSIBLE_TYPES
      end

      @exclude_types = options[:exclude]

      @available_encodings = []
      @available_encodings << 'br' if brotli_available?
      @available_encodings << 'gzip'
      @available_encodings << 'identity'
      @available_encodings.freeze
    end

    def call(env)
      status, headers, body = response = @app.call(env)

      unless should_compress?(env, status, headers, body)
        return response
      end

      request = Request.new(env)
      encoding = Utils.select_best_encoding(@available_encodings,
                                            request.accept_encoding)

      vary = headers["vary"].to_s.split(",").map(&:strip)
      unless vary.include?("*") || vary.any? { |v| v.downcase == 'accept-encoding' }
        headers["vary"] = vary.push("Accept-Encoding").join(",")
      end

      case encoding
      when "gzip"
        headers['content-encoding'] = "gzip"
        headers.delete(CONTENT_LENGTH)
        response[2] = GzipStream.new(body, @level, @sync, GZIP_MTIME)
        response
      when "br"
        headers['content-encoding'] = "br"
        headers.delete(CONTENT_LENGTH)
        response[2] = BrotliStream.new(body, @brotli_quality, @sync)
        response
      when "identity"
        response
      else
        if encoder = @encoders&.[](encoding)
          headers['content-encoding'] = encoding
          headers.delete(CONTENT_LENGTH)
          response[2] = encoder.call(body, level: @level, sync: @sync)
          response
        else
          message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
          bp = Rack::BodyProxy.new([message]) { body.close if body.respond_to?(:close) }
          [406, { CONTENT_TYPE => "text/plain", CONTENT_LENGTH => message.length.to_s }, bp]
        end
      end
    end

    # Body class for gzip encoded responses.
    class GzipStream

      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, level, sync, mtime)
        @body = body
        @level = level
        @sync = sync
        @mtime = mtime
      end

      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self, @level)
        gzip.mtime = @mtime if @mtime
        if @body.is_a? ::File
          while part = @body.read(BUFFER_LENGTH)
            gzip.write(part)
            gzip.flush if @sync
          end
        else
          @body.each { |part|
            next if part.empty?
            gzip.write(part)
            gzip.flush if @sync
          }
        end
      ensure
        gzip.finish
      end

      def write(data)
        @writer.call(data)
      end

      def close
        @body.close if @body.respond_to?(:close)
      end
    end

    # Body class for brotli encoded responses.
    class BrotliStream

      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, quality, sync)
        @body = body
        @quality = quality
        @sync = sync
        @brotli_available = defined?(::Brotli)
      end

      def each(&block)
        unless @brotli_available
          raise "Brotli encoding is not available. Please install the brotli gem."
        end

        @writer = block
        buffer = +""
        if @body.is_a? ::File
          while part = @body.read(BUFFER_LENGTH)
            buffer << ::Brotli.deflate(part, quality: @quality)
            flush_buffer(buffer) if @sync
          end
        else
          @body.each { |part|
            next if part.empty?
            buffer << ::Brotli.deflate(part, quality: @quality)
            flush_buffer(buffer) if @sync
          }
        end
        flush_buffer(buffer)
      end

      def close
        @body.close if @body.respond_to?(:close)
      end

      private

      def flush_buffer(buffer)
        return if buffer.empty?
        @writer.call(buffer)
        buffer.clear
      end
    end

    private

    # Check if brotli gem is available
    def brotli_available?
      defined?(::Brotli)
    end

    # Whether the body should be compressed.
    def should_compress?(env, status, headers, body)
      if Utils::STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i) ||
          /\bno-transform\b/.match?(headers[CACHE_CONTROL].to_s) ||
          headers['content-encoding']&.!~(/\bidentity\b/)
        return false
      end

      content_type = headers[CONTENT_TYPE][/[^;]*/] if headers[CONTENT_TYPE]

      if @exclude_types && content_type && @exclude_types.include?(content_type)
        return false
      end

      if @compressible_types && !(headers.has_key?(CONTENT_TYPE) && @compressible_types.include?(content_type))
        return false
      end

      return false if @condition && !@condition.call(env, status, headers, body)

      return false if headers[CONTENT_LENGTH] == '0'

      true
    end
  end
end
