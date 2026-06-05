# frozen_string_literal: true

# Rack Zeitwerk Option 1: Zeitwerk Loader with Explicit Inflector
#
# This approach replaces all `autoload` calls with a Zeitwerk loader.
# A custom inflector handles naming edge cases (URLMap, ForwardRequest, etc.).
# Zeitwerk is a hard dependency — if not available, the loader raises an error.
#
# Key design decisions:
#   - Custom inflector overrides for: URLMap, ContentType, ContentLength,
#     CommonLogger, ConditionalGet, MethodOverride, MockRequest, MockResponse,
#     NullLogger, QueryParser, ShowExceptions, ShowStatus, TempfileReaper,
#     RewindableInput, BodyProxy, BadRequest, MediaType, ForwardRequest
#   - ForwardRequest is defined in recursive.rb alongside Recursive,
#     so it must be pre-loaded via `require` before Zeitwerk takes over,
#     or we use `do_not_eager_load` + explicit require.

require_relative 'rack/version'
require_relative 'rack/constants'

require 'zeitwerk'

module Rack
  class RackInflector < Zeitwerk::Inflector
    EXCEPTIONS = {
      'urlmap'              => 'URLMap',
      'contenttype'         => 'ContentType',
      'contentlength'       => 'ContentLength',
      'commonlogger'        => 'CommonLogger',
      'conditionalget'      => 'ConditionalGet',
      'methodoverride'      => 'MethodOverride',
      'mockrequest'         => 'MockRequest',
      'mockresponse'        => 'MockResponse',
      'nulllogger'          => 'NullLogger',
      'queryparser'         => 'QueryParser',
      'showexceptions'      => 'ShowExceptions',
      'showstatus'          => 'ShowStatus',
      'tempfilereaper'      => 'TempfileReaper',
      'rewindableinput'     => 'RewindableInput',
      'bodyproxy'           => 'BodyProxy',
      'badrequest'          => 'BadRequest',
      'mediatype'           => 'MediaType',
      'forwardrequest'      => 'ForwardRequest'
    }.freeze

    def camelize(basename, abspath)
      underscored = basename.delete_suffix('.rb')
      EXCEPTIONS.fetch(underscored) { super }
    end
  end

  class << self
    attr_reader :loader
  end

  @loader = Zeitwerk::Loader.new
  @loader.inflector = RackInflector.new
  @loader.push_dir(__dir__, namespace: Rack)
  @loader.do_not_eager_load("#{__dir__}/recursive.rb")

  @loader.setup

  require_relative 'rack/recursive'
end
