# frozen_string_literal: true

require "zlib"
require "time"

require_relative 'constants'
require_relative 'utils'
require_relative 'request'
require_relative 'body_proxy'

module Rack
  class Compression

    GZIP_MTIME = RUBY_VERSION >= "2.7" ? 0 : 1

    def initialize(app, options = {})
      @app = app
      @condition = options[:if]
      @compressible_types = options[:include]
      @sync = options.fetch(:sync, true)
      @compressors = {}

      register_gzip
      register_brotli
      register_zstd

      @available_encodings = @compressors.keys
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
      when "identity"
        response
      when nil
        message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
        bp = Rack::BodyProxy.new([message]) { body.close if body.respond_to?(:close) }
        [406, { CONTENT_TYPE => "text/plain", CONTENT_LENGTH => message.length.to_s }, bp]
      else
        if compressor = @compressors[encoding]
          headers['content-encoding'] = encoding
          headers.delete(CONTENT_LENGTH)
          response[2] = compressor.call(headers, body)
          response
        else
          message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
          bp = Rack::BodyProxy.new([message]) { body.close if body.respond_to?(:close) }
          [406, { CONTENT_TYPE => "text/plain", CONTENT_LENGTH => message.length.to_s }, bp]
        end
      end
    end

    private

    def register_gzip
      @compressors['gzip'] = lambda { |_headers, body|
        GzipStream.new(body, GZIP_MTIME, @sync)
      }
    end

    def register_brotli
      return unless defined?(::Brotli)

      @compressors['br'] = lambda { |_headers, body|
        BrotliStream.new(body, @sync)
      }
    rescue LoadError
    end

    def register_zstd
      return unless defined?(::Zstd)

      @compressors['zstd'] = lambda { |_headers, body|
        ZstdStream.new(body, @sync)
      }
    rescue LoadError
    end

    def should_compress?(env, status, headers, body)
      if STATUS_WITH_NO_ENTITY_BODY.key?(status.to_i)
        return false
      end

      if headers[CONTENT_ENCODING]
        return false
      end

      if headers['cache-control'] && headers['cache-control'].include?('no-transform')
        return false
      end

      if @condition && !@condition.call(env, status, headers, body)
        return false
      end

      if headers[CONTENT_LENGTH] == '0'
        return false
      end

      true
    end

    class GzipStream

      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, mtime, sync)
        @body = body
        @mtime = mtime
        @sync = sync
      end

      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self)
        gzip.mtime = @mtime
        @body.each do |part|
          gzip.write(part)
          gzip.flush if @sync
        end
      ensure
        gzip.close
      end

      def write(data)
        @writer.call(data)
      end
    end

    class BrotliStream

      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, sync)
        @body = body
        @sync = sync
      end

      def each
        @body.each do |part|
          compressed = ::Brotli.deflate(part)
          yield compressed
        end
      end
    end

    class ZstdStream

      BUFFER_LENGTH = 128 * 1_024

      def initialize(body, sync)
        @body = body
        @sync = sync
      end

      def each
        stream = ::Zstd::StreamingCompress.new
        begin
          @body.each do |part|
            yield stream.compress(part)
          end
          yield stream.finish
        ensure
          stream.close
        end
      end
    end
  end
end