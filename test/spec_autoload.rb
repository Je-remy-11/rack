# frozen_string_literal: true

require_relative 'helper'
require 'open3'
require 'rbconfig'

separate_testing do
  require_relative '../lib/rack'
end

describe Rack do
  AUTOLOADS = {
    'Rack' => {
      'rack/bad_request' => ['BadRequest'],
      'rack/body_proxy' => ['BodyProxy'],
      'rack/builder' => ['Builder'],
      'rack/cascade' => ['Cascade'],
      'rack/common_logger' => ['CommonLogger'],
      'rack/conditional_get' => ['ConditionalGet'],
      'rack/config' => ['Config'],
      'rack/content_length' => ['ContentLength'],
      'rack/content_type' => ['ContentType'],
      'rack/deflater' => ['Deflater'],
      'rack/directory' => ['Directory'],
      'rack/etag' => ['ETag'],
      'rack/events' => ['Events'],
      'rack/files' => ['Files'],
      'rack/recursive' => ['ForwardRequest', 'Recursive'],
      'rack/head' => ['Head'],
      'rack/headers' => ['Headers'],
      'rack/lint' => ['Lint'],
      'rack/lock' => ['Lock'],
      'rack/media_type' => ['MediaType'],
      'rack/method_override' => ['MethodOverride'],
      'rack/mime' => ['Mime'],
      'rack/mock_request' => ['MockRequest'],
      'rack/mock_response' => ['MockResponse'],
      'rack/multipart' => ['Multipart'],
      'rack/null_logger' => ['NullLogger'],
      'rack/query_parser' => ['QueryParser'],
      'rack/reloader' => ['Reloader'],
      'rack/request' => ['Request'],
      'rack/response' => ['Response'],
      'rack/rewindable_input' => ['RewindableInput'],
      'rack/runtime' => ['Runtime'],
      'rack/sendfile' => ['Sendfile'],
      'rack/show_exceptions' => ['ShowExceptions'],
      'rack/show_status' => ['ShowStatus'],
      'rack/static' => ['Static'],
      'rack/tempfile_reaper' => ['TempfileReaper'],
      'rack/urlmap' => ['URLMap'],
      'rack/utils' => ['Utils']
    },
    'Rack::Auth' => {
      'rack/auth/basic' => ['Basic'],
      'rack/auth/abstract/handler' => ['AbstractHandler'],
      'rack/auth/abstract/request' => ['AbstractRequest']
    }
  }.freeze

  it 'autoloads every constant declared in rack.rb on first reference' do
    script = <<~RUBY
      autoloads = #{AUTOLOADS.inspect}

      $LOAD_PATH.unshift(File.expand_path('lib', Dir.pwd))
      require 'rack'

      def loaded_feature?(feature)
        normalized_feature = "/#{feature}.rb"
        $LOADED_FEATURES.any? do |loaded_feature|
          loaded_feature.tr('\\', '/').end_with?(normalized_feature)
        end
      end

      autoloads.each do |namespace_name, features|
        namespace = namespace_name.split('::').inject(Object) do |current_namespace, constant_name|
          current_namespace.const_get(constant_name)
        end

        features.each do |feature, constants|
          constants.each do |constant_name|
            actual = namespace.autoload?(constant_name.to_sym)
            unless actual == feature
              raise "#{namespace_name}::#{constant_name} expected autoload #{feature.inspect}, got #{actual.inspect}"
            end
          end
        end
      end

      autoloads.values.flat_map(&:keys).uniq.each do |feature|
        raise "#{feature} loaded before any constant was referenced" if loaded_feature?(feature)
      end

      autoloads.each do |namespace_name, features|
        namespace = namespace_name.split('::').inject(Object) do |current_namespace, constant_name|
          current_namespace.const_get(constant_name)
        end

        features.each do |feature, constants|
          constants.each do |constant_name|
            namespace.const_get(constant_name)
          end

          unless loaded_feature?(feature)
            raise "#{feature} was not loaded when #{namespace_name}::#{constants.first} was referenced"
          end
        end
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      '-e',
      script,
      chdir: File.expand_path('..', __dir__)
    )

    assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
  end
end
