# frozen_string_literal: true

# OPTION 2: Inflector-based dual-mode approach with explicit switching
#
# Design:
#   - Keeps the autoload declarations inside the module body as a default
#     so that +require 'rack'+ works out-of-the-box on any Ruby.
#   - Provides Rack.use_zeitwerk! that, when called, tears down the
#     Module#autoload entries and hands over control to a custom Zeitwerk
#     inflector.
#   - The custom inflector (Rack::Inflector) implements the Zeitwerk
#     inflector interface and also serves as a single source of truth
#     for constant-to-file mappings — useful for documentation and tooling.
#   - This approach is ideal when you want zero-config defaults while
#     still giving power-users an opt-in path to Zeitwerk.
#
# Usage in development:
#   require 'rack'
#   Rack.use_zeitwerk!   # switches from autoload to Zeitwerk
#
# Usage in production (classic):
#   require 'rack'        # autoload works as before, no changes needed

require_relative 'rack/version'
require_relative 'rack/constants'

module Rack
  # ── Single source of truth for constant-to-file mappings ──────────
  # Used both by the legacy autoload calls below and by the Zeitwerk
  # inflector.  Add new constants here only.
  CONSTANT_MAPPINGS = {
    # leaf constants under Rack::
    "BadRequest"       => "rack/bad_request",
    "BodyProxy"        => "rack/body_proxy",
    "Builder"          => "rack/builder",
    "Cascade"          => "rack/cascade",
    "CommonLogger"     => "rack/common_logger",
    "ConditionalGet"   => "rack/conditional_get",
    "Config"           => "rack/config",
    "ContentLength"    => "rack/content_length",
    "ContentType"      => "rack/content_type",
    "Deflater"         => "rack/deflater",
    "Directory"        => "rack/directory",
    "ETag"             => "rack/etag",
    "Events"           => "rack/events",
    "Files"            => "rack/files",
    "ForwardRequest"   => "rack/recursive",
    "Head"             => "rack/head",
    "Headers"          => "rack/headers",
    "Lint"             => "rack/lint",
    "Lock"             => "rack/lock",
    "MediaType"        => "rack/media_type",
    "MethodOverride"   => "rack/method_override",
    "Mime"             => "rack/mime",
    "MockRequest"      => "rack/mock_request",
    "MockResponse"     => "rack/mock_response",
    "Multipart"        => "rack/multipart",
    "NullLogger"       => "rack/null_logger",
    "QueryParser"      => "rack/query_parser",
    "Recursive"        => "rack/recursive",
    "Reloader"         => "rack/reloader",
    "Request"          => "rack/request",
    "Response"         => "rack/response",
    "RewindableInput"  => "rack/rewindable_input",
    "Runtime"          => "rack/runtime",
    "Sendfile"         => "rack/sendfile",
    "ShowExceptions"   => "rack/show_exceptions",
    "ShowStatus"       => "rack/show_status",
    "Static"           => "rack/static",
    "TempfileReaper"   => "rack/tempfile_reaper",
    "URLMap"           => "rack/urlmap",
    "Utils"            => "rack/utils",

    # Auth sub-module constants
    "Auth::Basic"          => "rack/auth/basic",
    "Auth::AbstractHandler" => "rack/auth/abstract/handler",
    "Auth::AbstractRequest" => "rack/auth/abstract/request",
  }.freeze

  # ── Default: classic Module#autoload (zero-config) ────────────────
  autoload :BadRequest, "rack/bad_request"
  autoload :BodyProxy, "rack/body_proxy"
  autoload :Builder, "rack/builder"
  autoload :Cascade, "rack/cascade"
  autoload :CommonLogger, "rack/common_logger"
  autoload :ConditionalGet, "rack/conditional_get"
  autoload :Config, "rack/config"
  autoload :ContentLength, "rack/content_length"
  autoload :ContentType, "rack/content_type"
  autoload :Deflater, "rack/deflater"
  autoload :Directory, "rack/directory"
  autoload :ETag, "rack/etag"
  autoload :Events, "rack/events"
  autoload :Files, "rack/files"
  autoload :ForwardRequest, "rack/recursive"
  autoload :Head, "rack/head"
  autoload :Headers, "rack/headers"
  autoload :Lint, "rack/lint"
  autoload :Lock, "rack/lock"
  autoload :MediaType, "rack/media_type"
  autoload :MethodOverride, "rack/method_override"
  autoload :Mime, "rack/mime"
  autoload :MockRequest, "rack/mock_request"
  autoload :MockResponse, "rack/mock_response"
  autoload :Multipart, "rack/multipart"
  autoload :NullLogger, "rack/null_logger"
  autoload :QueryParser, "rack/query_parser"
  autoload :Recursive, "rack/recursive"
  autoload :Reloader, "rack/reloader"
  autoload :Request, "rack/request"
  autoload :Response, "rack/response"
  autoload :RewindableInput, "rack/rewindable_input"
  autoload :Runtime, "rack/runtime"
  autoload :Sendfile, "rack/sendfile"
  autoload :ShowExceptions, "rack/show_exceptions"
  autoload :ShowStatus, "rack/show_status"
  autoload :Static, "rack/static"
  autoload :TempfileReaper, "rack/tempfile_reaper"
  autoload :URLMap, "rack/urlmap"
  autoload :Utils, "rack/utils"

  module Auth
    autoload :Basic, "rack/auth/basic"
    autoload :AbstractHandler, "rack/auth/abstract/handler"
    autoload :AbstractRequest, "rack/auth/abstract/request"
  end

  # ── Custom Zeitwerk inflector ──────────────────────────────────────
  # Implements the Zeitwek::Inflector interface so that:
  #   1. We can override specific acronyms (ETag, URLMap, etc.).
  #   2. We do not need to repeat the mapping in two places — this
  #      class can optionally use CONSTANT_MAPPINGS as a validation
  #      source.
  class Inflector
    INFLECTIONS = {
      "etag"       => "ETag",
      "urlmap"     => "URLMap",
      "mime"       => "Mime",
      "head"       => "Head",
      "lint"       => "Lint",
      "cascade"    => "Cascade",
      "deflater"   => "Deflater",
      "sendfile"   => "Sendfile",
      "recursive"  => "Recursive",
      "reloader"   => "Reloader",
      "runtime"    => "Runtime",
      "static"     => "Static",
      "lock"       => "Lock",
      "builder"    => "Builder",
      "directory"  => "Directory",
      "events"     => "Events",
      "files"      => "Files",
      "mock"       => "Mock",
      "multipart"  => "Multipart",
      "body_proxy"                 => "BodyProxy",
      "common_logger"              => "CommonLogger",
      "conditional_get"            => "ConditionalGet",
      "content_length"             => "ContentLength",
      "content_type"               => "ContentType",
      "bad_request"                => "BadRequest",
      "method_override"            => "MethodOverride",
      "mock_request"               => "MockRequest",
      "mock_response"              => "MockResponse",
      "query_parser"               => "QueryParser",
      "rewindable_input"           => "RewindableInput",
      "show_exceptions"            => "ShowExceptions",
      "show_status"                => "ShowStatus",
      "tempfile_reaper"            => "TempfileReaper",
      "media_type"                 => "MediaType",
      "null_logger"                => "NullLogger",
      "generator"                  => "Generator",
      "parser"                     => "Parser",
      "uploaded_file"              => "UploadedFile",
      "handler"                    => "AbstractHandler",
      "request"                    => "AbstractRequest",
      "basic"                      => "Basic",
    }.freeze

    # Zeitwerk calls +camelize+ with the basename (without extension)
    # of each Ruby file it manages.
    def camelize(basename, _abspath)
      INFLECTIONS.fetch(basename) do
        basename.split("_").map(&:capitalize).join
      end
    end
  end

  class << self
    # Holds the Zeitwerk loader once +use_zeitwerk!+ is called.
    attr_reader :zeitwerk_loader

    # Whether Zeitwerk mode is active.
    def zeitwerk_mode?
      instance_variable_defined?(:@zeitwerk_loader) && !@zeitwerk_loader.nil?
    end

    # Activate Zeitwerk as the autoloader.
    #
    # 1. Requires 'zeitwerk'.
    # 2. Removes all Module#autoload registrations under Rack so they
    #    do not conflict with Zeitwerk's own constant management.
    # 3. Pushes the load path and configures the custom inflector.
    #
    # Safe to call multiple times — subsequent calls are no-ops.
    def use_zeitwerk!
      return self if zeitwerk_mode?

      require 'zeitwerk'

      # Tear down legacy autoload entries to prevent double-autoload
      # warnings or constant redefinition issues.
      remove_autoloads!

      @zeitwerk_loader = Zeitwerk::Loader.new
      @zeitwerk_loader.tag = "rack"
      @zeitwerk_loader.inflector = Rack::Inflector.new
      @zeitwerk_loader.push_dir(::File.expand_path(__dir__))

      # Files already loaded explicitly should not be managed by Zeitwerk.
      @zeitwerk_loader.do_not_eager_load(
        ::File.expand_path("rack.rb", __dir__),
        ::File.expand_path("rack/version.rb", __dir__),
        ::File.expand_path("rack/constants.rb", __dir__),
        ::File.expand_path("rack/mock.rb", __dir__)
      )

      @zeitwerk_loader.setup

      self
    end

    private

    # Walk the current +autoload+ registrations under Rack and its
    # sub-modules and remove them so that Zeitwerk can take over.
    def remove_autoloads!
      # Remove direct autoloads on Rack.
      CONSTANT_MAPPINGS.each_key do |constant_name|
        # Skip namespaced constants (e.g. "Auth::Basic") — handled below.
        next if constant_name.include?("::")

        # autoload? returns the path if registered, nil otherwise.
        # We use remove_const to fully delete the autoload trigger.
        Rack.send(:remove_const, constant_name) if Rack.autoload?(constant_name)
      end

      # Handle Auth sub-module constants.
      %w[Basic AbstractHandler AbstractRequest].each do |name|
        if Rack::Auth.autoload?(name)
          Rack::Auth.send(:remove_const, name)
        end
      end
    end
  end

  # ── Loader-agnostic eager-loading helper ───────────────────────────
  def self.eager_load!
    if zeitwerk_mode?
      @zeitwerk_loader.eager_load
    else
      constants(false).each { |c| const_get(c) }
      Auth.constants(false).each { |c| Auth.const_get(c) }
    end
  end
end