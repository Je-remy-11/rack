# 方案二：完全基于 Zeitwerk 的版本（带兼容层）
# 这种方案完全使用 Zeitwerk，同时提供对旧代码的兼容性

require 'zeitwerk'

module Rack
  class << self
    attr_reader :zeitwerk_loader

    def setup_autoloading
      @zeitwerk_loader = Zeitwerk::Loader.new
      @zeitwerk_loader.push_dir(__dir__)
      @zeitwerk_loader.ignore("#{__dir__}/rack/version.rb")
      @zeitwerk_loader.inflector.inflect(
        'rack' => 'Rack',
        'http' => 'HTTP'
      )

      setup_compatibility_autoload
      @zeitwerk_loader.setup
      @zeitwerk_loader.eager_load if production?
    end

    def production?
      ENV['RACK_ENV'] == 'production'
    end

    private

    def setup_compatibility_autoload
      compatibility_map = {
        :Builder          => 'rack/builder',
        :Cascade          => 'rack/cascade',
        :CommonLogger     => 'rack/common_logger',
        :ContentLength    => 'rack/content_length',
        :ContentType      => 'rack/content_type',
        :Deflater         => 'rack/deflater',
        :Directory        => 'rack/directory',
        :ETag             => 'rack/etag',
        :File             => 'rack/file',
        :Head             => 'rack/head',
        :Lint             => 'rack/lint',
        :Lock             => 'rack/lock',
        :Logger           => 'rack/logger',
        :MethodOverride   => 'rack/method_override',
        :Mime             => 'rack/mime',
        :NullLogger       => 'rack/null_logger',
        :Recursive        => 'rack/recursive',
        :Request          => 'rack/request',
        :Response         => 'rack/response',
        :Runtime          => 'rack/runtime',
        :Sendfile         => 'rack/sendfile',
        :ShowExceptions   => 'rack/show_exceptions',
        :ShowStatus       => 'rack/show_status',
        :Static           => 'rack/static',
        :TempfileReaper   => 'rack/tempfile_reaper',
        :URLMap           => 'rack/urlmap',
        :Utils            => 'rack/utils'
      }

      compatibility_map.each do |const_name, path|
        define_autoload(const_name, path)
      end
    end

    def define_autoload(const_name, path)
      singleton_class.define_method(const_name) do
        unless const_defined?(const_name, false)
          require path
        end
        const_get(const_name, false)
      end

      const_missing = lambda do |missing_name|
        if compatibility_map.key?(missing_name)
          require compatibility_map[missing_name]
          const_get(missing_name, false)
        else
          super(missing_name)
        end
      end

      unless method_defined?(:const_missing)
        define_singleton_method(:const_missing, const_missing)
      end
    end
  end
end

Rack.setup_autoloading
