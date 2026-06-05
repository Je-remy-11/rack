# 方案一：条件性 autoload + Zeitwerk 版本
# 这种方案在生产环境保持传统 autoload，在开发/测试环境使用 Zeitwerk

module Rack
  class << self
    def use_zeitwerk?
      ENV['RACK_USE_ZEITWERK'] == 'true' || (defined?(::Zeitwerk) && !production?)
    end

    def production?
      ENV['RACK_ENV'] == 'production'
    end

    def setup_autoloading
      if use_zeitwerk?
        setup_zeitwerk
      else
        setup_autoload
      end
    end

    private

    def setup_zeitwerk
      require 'zeitwerk'

      loader = Zeitwerk::Loader.new
      loader.push_dir(__dir__)
      loader.ignore("#{__dir__}/rack/version.rb")
      loader.inflector.inflect(
        'rack' => 'Rack',
        'http' => 'HTTP'
      )
      loader.setup
      loader.eager_load if production?

      @zeitwerk_loader = loader
    end

    def setup_autoload
      autoload :Builder,          'rack/builder'
      autoload :Cascade,          'rack/cascade'
      autoload :CommonLogger,     'rack/common_logger'
      autoload :ContentLength,    'rack/content_length'
      autoload :ContentType,      'rack/content_type'
      autoload :Deflater,         'rack/deflater'
      autoload :Directory,        'rack/directory'
      autoload :ETag,             'rack/etag'
      autoload :File,             'rack/file'
      autoload :Head,             'rack/head'
      autoload :Lint,             'rack/lint'
      autoload :Lock,             'rack/lock'
      autoload :Logger,           'rack/logger'
      autoload :MethodOverride,   'rack/method_override'
      autoload :Mime,             'rack/mime'
      autoload :NullLogger,       'rack/null_logger'
      autoload :Recursive,        'rack/recursive'
      autoload :Request,          'rack/request'
      autoload :Response,         'rack/response'
      autoload :Runtime,          'rack/runtime'
      autoload :Sendfile,         'rack/sendfile'
      autoload :ShowExceptions,   'rack/show_exceptions'
      autoload :ShowStatus,       'rack/show_status'
      autoload :Static,           'rack/static'
      autoload :TempfileReaper,   'rack/tempfile_reaper'
      autoload :URLMap,           'rack/urlmap'
      autoload :Utils,            'rack/utils'
    end
  end
end

Rack.setup_autoloading
