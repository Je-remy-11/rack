# frozen_string_literal: true

# OPTION 1: Conditional Zeitwerk with autoload fallback
#
# Design:
#   - Uses Zeitwerk as the primary autoloading mechanism when available.
#   - Falls back to Ruby's built-in Module#autoload when Zeitwerk is not loaded.
#   - The loader setup is extracted into a dedicated class method Rack.setup_loader!,
#     keeping the module body clean and focused.
#   - This approach is ideal for gems that want to offer Zeitwerk support
#     in development without breaking existing deployments on older Ruby versions.
#
# Usage in development (with Zeitwerk installed):
#   require 'rack'
#   Rack.setup_loader!(:zeitwerk)
#
# Usage in production (no Zeitwerk, traditional autoload):
#   require 'rack'
#   Rack.setup_loader!(:autoload)   # or simply omit the call, defaults to :autoload

require_relative 'rack/version'
require_relative 'rack/constants'

module Rack
  class << self
    # Holds the active loader instance (either a Zeitwerk loader or nil).
    attr_reader :loader

    # Configure which autoloading mechanism to use.
    #
    #   Rack.setup_loader!(:zeitwerk)  # uses Zeitwerk if available
    #   Rack.setup_loader!(:autoload)  # uses Ruby Module#autoload (default)
    #
    # Raises LoadError if :zeitwerk is requested but the gem is not installed.
    def setup_loader!(mode = :autoload)
      case mode
      when :zeitwerk
        setup_zeitwerk!
      when :autoload
        setup_autoload!
      else
        raise ArgumentError, "Unknown loader mode: #{mode.inspect}. Supported: :zeitwerk, :autoload"
      end
    end

    private

    # Configure Zeitwerk as the autoloader.
    # Requires the 'zeitwerk' gem and pushes all Rack constants into
    # a dedicated loader instance so it can manage file-to-constant mapping.
    def setup_zeitwerk!
      require 'zeitwerk'

      @loader = Zeitwerk::Loader.new
      @loader.tag = "rack"

      # Register the root directory for Zeitwerk's autovivification.
      # Zeitwerk derives constants from the file system:
      #   lib/rack/body_proxy.rb  =>  Rack::BodyProxy
      #   lib/rack/auth/basic.rb  =>  Rack::Auth::Basic
      @loader.push_dir(::File.expand_path(__dir__))

      # ── Custom inflections ──────────────────────────────────────
      # Zeitwerk's default inflection uses #capitalize which handles
      # most cases, but some Rack constants require explicit overrides.
      @loader.inflector.inflect(
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
        "null_logger"                => "NullLogger",
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
        # Auth sub-module
        "basic"                      => "Basic",
        "handler"                    => "AbstractHandler",
        "request"                    => "AbstractRequest",
        # Multipart sub-module
        "generator"                  => "Generator",
        "parser"                     => "Parser",
        "uploaded_file"              => "UploadedFile"
      )

      # Explicitly ignore the main rack.rb entry-point and version/constants
      # files since they are already loaded via require_relative.
      @loader.do_not_eager_load(
        ::File.expand_path("rack.rb", __dir__),
        ::File.expand_path("rack/version.rb", __dir__),
        ::File.expand_path("rack/constants.rb", __dir__),
        ::File.expand_path("rack/mock.rb", __dir__)
      )

      @loader.setup
    end

    # Fall back to traditional Ruby Module#autoload.
    # This codifies the classic Rack autoload declarations so they stay
    # in one place and are easy to maintain.
    def setup_autoload!
      @loader = nil

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
    end
  end

  # ── Eager-loading helper ───────────────────────────────────────────
  # When Zeitwerk is active you may want to eager-load all Rack constants
  # in production.  This method exposes that in a loader-agnostic way.
  def self.eager_load!
    if @loader
      @loader.eager_load
    else
      # With Module#autoload there is no built-in eager-loading mechanism,
      # but you could walk the constant table and +require+ each one:
      constants(false).each do |c|
        const_get(c)
      end
      Auth.constants(false).each do |c|
        Auth.const_get(c)
      end
    end
  end
end