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
  # algorithms and automatically selects the best encoding based on the
  # client's Accept-Encoding header.
  #
  # Supported encodings:
  #
  # * gzip - GNU zip compression (widely supported)
  # * deflate - zlib compression with deflate encoding
  # * br - Brotli compression (better compression ratio, modern browsers)
  # * identity - no transformation (pass-through)
  #
  # This middleware automatically detects when encoding is supported and
  # allowed. No encoding is applied when:
  # - A cache directive of 'no-transform' is present
  # - The response status code doesn't allow an entity body
  # - The body is empty
  # - The Content-Encoding header already indicates compression
  #
  # Example usage:
  #
  #   use Rack::Compression
  #
  #   use Rack::Compression, level: Zlib::BEST_COMPRESSION
  #
  #   use Rack::Compression,
  #     include: %w(text/html application/json text/css),
  #     level: Zlib::DEFAULT_COMPRESSION,
  #     if: ->(env, status, headers, body) { status == 200 }
  #
  class Compression

    # Default quality values for each encoding
    ENCODING_QUALITY = {
      'br' => 1.1,
      'gzip' => 1.0,
      'deflate' => 0.9,
      'identity' => 0.001
    }.freeze

    # Modification time for gzip/deflate headers (0 means "now" in Ruby < 2.7)
    GZIP_MTIME = RUBY_VERSION >= "2.7" ? 0 : 1

    # Creates Rack::Compression middleware. Options:
    #
    # :if :: a lambda enabling/disabling compression based on returned boolean value
    #        (e.g., use Rack::Compression, if: ->(env, status, headers, body) { status == 200 })
    # :include :: a list of content types that should be compressed. By default, all
    #             content types are compressed.
    # :exclude :: a list of content types that should NOT be compressed.
    # :level :: the compression level (0-9 or Zlib:: constants). Defaults to
    #           Zlib::DEFAULT_COMPRESSION.
    # :strategy :: the compression strategy (Zlib::DEFAULT_STRATEGY, Zlib::FILTERED,
    #              Zlib::HUFFMAN_ONLY, Zlib::RLE, Zlib::FIXED). Defaults to
    #              Zlib::DEFAULT_STRATEGY.
    # :sync :: determines if the stream is flushed after every chunk. Defaults to +true+.
    # :encodings :: a hash of encoding configurations. Keys are encoding names, values
    #               are hashes with :enabled (boolean) and optional :quality (float).
    #               Example: { 'br' => { enabled: false }, 'gzip' => { enabled: true, quality: 1.0 } }
    # :custom_encoders :: a hash of custom encoders. Keys are encoding names, values are
    #                     callables that take (body, options) and return an encoded body object.
    def initialize(app, options = {})
      @app = app
      @condition = options[:if]
      @compressible_types = options[:include]
      @uncompressible_types = options[:exclude]
      @level = options.fetch(:level, Zlib::DEFAULT_COMPRESSION)
      @strategy = options.fetch(:strategy, Zlib::DEFAULT_STRATEGY)
      @sync = options.fetch(:sync, true)
      @custom_encoders = options[:custom_encoders]

      @encodings = setup_encodings(options[:encodings])
      @available_encodings = @encodings.keys.select { |enc| @encodings[enc][:enabled] }.freeze
    end

    def call(env)
      status, headers, body = response = @app.call(env)

      unless should_compress?(env, status, headers, body)
        return response
      end

      request = Request.new(env)
      encoding = select_encoding(request.accept_encoding)

      case encoding
      when 'gzip'
        headers['content-encoding'] = 'gzip'
        headers.delete(CONTENT_LENGTH)
        response[2] = GzipStream.new(body, @level, @strategy, @sync, GZIP_MTIME)
        response
      when 'deflate'
        headers['content-encoding'] = 'deflate'
        headers.delete(CONTENT_LENGTH)
        response[2] = DeflateStream.new(body, @level, @strategy, @sync, GZIP_MTIME)
        response
      when 'br'
        headers['content-encoding'] = 'br'
        headers.delete(CONTENT_LENGTH)
        response[2] = BrotliStream.new(body, @level, @sync)
        response
      when 'identity'
        response
      else
        if encoder = @custom_encoders&.[](encoding)
          headers['content-encoding'] = encoding
          headers.delete(CONTENT_LENGTH)
          response[2] = encoder.call(body, level: @level, strategy: @strategy, sync: @sync)
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

      def initialize(body, level, strategy, sync, mtime)
        @body = body
        @level = level
        @strategy = strategy
        @sync = sync
        @mtime = mtime
      end

      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self, @level, @strategy)
        gzip.mtime = @mtime if @mtime
        process_body(gzip)
      ensure
        gzip.finish
      end

      def write(data)
        @writer.call(data)
      end

      def close
        @body.close if @body.respond_to?(:close)
      end

      private

      def process_body(gzip)
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
      end
    end

    # Body class for deflate encoded responses.
    class DeflateStream
      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, level, strategy, sync, mtime)
        @body = body
        @level = level
        @strategy = strategy
        @sync = sync
        @mtime = mtime
      end

      def each(&block)
        @writer = block
        deflater = ::Zlib::Deflate.new(@level, -::Zlib::MAX_WBITS)
        deflater.params(@level, @strategy)
        process_body(deflater)
      ensure
        deflater&.close
      end

      def write(data)
        @writer.call(data)
      end

      def close
        @body.close if @body.respond_to?(:close)
      end

      private

      def process_body(deflater)
        if @body.is_a? ::File
          while part = @body.read(BUFFER_LENGTH)
            compressed = deflater.deflate(part, @sync ? ::Zlib::SYNC_FLUSH : ::Zlib::NO_FLUSH)
            @writer.call(compressed) unless compressed.empty?
          end
        else
          @body.each { |part|
            next if part.empty?
            compressed = deflater.deflate(part, @sync ? ::Zlib::SYNC_FLUSH : ::Zlib::NO_FLUSH)
            @writer.call(compressed) unless compressed.empty?
          }
        end
        final = deflater.finish
        @writer.call(final) unless final.empty?
      end
    end

    # Body class for Brotli encoded responses.
    # Note: Requires the 'brotli' gem to be installed.
    class BrotliStream
      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, quality, sync)
        @body = body
        @quality = quality
        @sync = sync
        begin
          require 'brotli'
          @brotli_available = true
        rescue LoadError
          @brotli_available = false
        end
      end

      def each(&block)
        unless @brotli_available
          raise "Brotli compression requires the 'brotli' gem. Add `gem 'brotli'` to your Gemfile."
        end

        @writer = block
        compressor = ::Brotli::Compressor.new(quality: @quality)
        process_body(compressor)
      ensure
        compressor&.finish
      end

      def write(data)
        @writer.call(data)
      end

      def close
        @body.close if @body.respond_to?(:close)
      end

      private

      def process_body(compressor)
        if @body.is_a? ::File
          while part = @body.read(BUFFER_LENGTH)
            compressed = compressor.compress(part)
            @writer.call(compressed) unless compressed.empty?
          end
        else
          @body.each { |part|
            next if part.empty?
            compressed = compressor.compress(part)
            @writer.call(compressed) unless compressed.empty?
          }
        end
        final = compressor.finish
        @writer.call(final) unless final.empty?
      end
    end

    private

    # Setup encodings with their enabled status and quality
    def setup_encodings(custom_encodings)
      encodings = {
        'br' => { enabled: true, quality: ENCODING_QUALITY['br'] },
        'gzip' => { enabled: true, quality: ENCODING_QUALITY['gzip'] },
        'deflate' => { enabled: true, quality: ENCODING_QUALITY['deflate'] },
        'identity' => { enabled: true, quality: ENCODING_QUALITY['identity'] }
      }

      return encodings unless custom_encodings

      custom_encodings.each do |enc, config|
        if encodings.key?(enc)
          encodings[enc].merge!(config)
        else
          encodings[enc] = { enabled: config[:enabled] || true, quality: config[:quality] || 1.0 }
        end
      end

      encodings
    end

    # Select the best encoding based on client's Accept-Encoding header
    def select_encoding(accept_encoding)
      return 'identity' if accept_encoding.nil? || accept_encoding.empty?

      # Parse Accept-Encoding header
      encodings = parse_accept_encoding(accept_encoding)

      # Find the best matching encoding
      best_encoding = nil
      best_quality = 0

      encodings.each do |enc, q|
        next unless @available_encodings.include?(enc)

        encoding_quality = @encodings[enc][:quality] || 1.0
        combined_quality = q * encoding_quality

        if combined_quality > best_quality
          best_quality = combined_quality
          best_encoding = enc
        end
      end

      best_encoding || 'identity'
    end

    # Parse Accept-Encoding header into a hash of encoding => quality
    def parse_accept_encoding(header)
      encodings = {}
      header.to_s.split(',').each do |part|
        encoding, params = part.split(';', 2)
        encoding = encoding.strip.downcase
        quality = 1.0

        if params
          match = params.match(/q\s*=\s*([\d.]+)/)
          quality = match[1].to_f if match
        end

        encodings[encoding] = quality if encoding && !encoding.empty?
      end
      encodings
    end

    # Determine if the response should be compressed
    def should_compress?(env, status, headers, body)
      # Skip if status doesn't allow entity body
      return false if Utils::STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i)

      # Skip if no-transform cache directive is present
      return false if /\bno-transform\b/.match?(headers[CACHE_CONTROL].to_s)

      # Skip if content is already encoded
      return false if headers['content-encoding'] && !headers['content-encoding'].empty?

      # Skip if content type is not compressible
      if @compressible_types
        return false unless headers[CONTENT_TYPE] && @compressible_types.include?(headers[CONTENT_TYPE][/[^;]*/])
      end

      # Skip if content type is in uncompressible list
      if @uncompressible_types
        return false if headers[CONTENT_TYPE] && @uncompressible_types.include?(headers[CONTENT_TYPE][/[^;]*/])
      end

      # Skip if condition lambda returns false
      return false if @condition && !@condition.call(env, status, headers, body)

      # Skip empty body
      return false if headers[CONTENT_LENGTH] == '0'

      true
    end
  end
end
