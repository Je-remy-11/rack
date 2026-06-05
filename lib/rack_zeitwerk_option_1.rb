# frozen_string_literal: true

require_relative 'rack/version'
require_relative 'rack/constants'

module Rack
  AUTOLOADS = {
    BadRequest: 'rack/bad_request',
    BodyProxy: 'rack/body_proxy',
    Builder: 'rack/builder',
    Cascade: 'rack/cascade',
    CommonLogger: 'rack/common_logger',
    ConditionalGet: 'rack/conditional_get',
    Config: 'rack/config',
    ContentLength: 'rack/content_length',
    ContentType: 'rack/content_type',
    Deflater: 'rack/deflater',
    Directory: 'rack/directory',
    ETag: 'rack/etag',
    Events: 'rack/events',
    Files: 'rack/files',
    ForwardRequest: 'rack/recursive',
    Head: 'rack/head',
    Headers: 'rack/headers',
    Lint: 'rack/lint',
    Lock: 'rack/lock',
    MediaType: 'rack/media_type',
    MethodOverride: 'rack/method_override',
    Mime: 'rack/mime',
    MockRequest: 'rack/mock_request',
    MockResponse: 'rack/mock_response',
    Multipart: 'rack/multipart',
    NullLogger: 'rack/null_logger',
    QueryParser: 'rack/query_parser',
    Recursive: 'rack/recursive',
    Reloader: 'rack/reloader',
    Request: 'rack/request',
    Response: 'rack/response',
    RewindableInput: 'rack/rewindable_input',
    Runtime: 'rack/runtime',
    Sendfile: 'rack/sendfile',
    ShowExceptions: 'rack/show_exceptions',
    ShowStatus: 'rack/show_status',
    Static: 'rack/static',
    TempfileReaper: 'rack/tempfile_reaper',
    URLMap: 'rack/urlmap',
    Utils: 'rack/utils'
  }.freeze

  ZEITWERK_INFLECTIONS = {
    'etag' => 'ETag',
    'urlmap' => 'URLMap'
  }.freeze

  ZEITWERK_IGNORES = [
    File.join(__dir__, 'rack/constants.rb'),
    File.join(__dir__, 'rack/version.rb')
  ].freeze

  ZEITWERK_COLLAPSE_DIRS = [
    File.join(__dir__, 'rack/auth/abstract')
  ].freeze

  def self.setup_autoloads
    register_autoloads(self, AUTOLOADS)
    Auth.setup_autoloads
    self
  end

  def self.setup_zeitwerk(loader)
    loader.push_dir(File.join(__dir__, 'rack'), namespace: self)
    loader.inflector.inflect(ZEITWERK_INFLECTIONS) if loader.respond_to?(:inflector)

    if loader.respond_to?(:ignore)
      ZEITWERK_IGNORES.each do |path|
        loader.ignore(path)
      end
    end

    if loader.respond_to?(:collapse)
      ZEITWERK_COLLAPSE_DIRS.each do |path|
        loader.collapse(path)
      end
    end

    register_autoloads(self, ForwardRequest: AUTOLOADS.fetch(:ForwardRequest))
    self
  end

  def self.register_autoloads(namespace, mapping)
    mapping.each do |constant_name, require_path|
      next if namespace.const_defined?(constant_name, false)
      next if namespace.autoload?(constant_name)

      namespace.autoload(constant_name, require_path)
    end
  end
  private_class_method :register_autoloads

  module Auth
    AUTOLOADS = {
      Basic: 'rack/auth/basic',
      AbstractHandler: 'rack/auth/abstract/handler',
      AbstractRequest: 'rack/auth/abstract/request'
    }.freeze

    def self.setup_autoloads
      Rack.__send__(:register_autoloads, self, AUTOLOADS)
      self
    end
  end

  setup_autoloads unless ENV['RACK_AUTOLOADER'] == 'zeitwerk'
end
