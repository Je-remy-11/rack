# frozen_string_literal: true

module Rack
  AUTOLOADS = {
    BadRequest: "rack/bad_request",
    BodyProxy: "rack/body_proxy",
    Builder: "rack/builder",
    Cascade: "rack/cascade",
    CommonLogger: "rack/common_logger",
    ConditionalGet: "rack/conditional_get",
    Config: "rack/config",
    ContentLength: "rack/content_length",
    ContentType: "rack/content_type",
    Deflater: "rack/deflater",
    Directory: "rack/directory",
    ETag: "rack/etag",
    Events: "rack/events",
    Files: "rack/files",
    ForwardRequest: "rack/recursive",
    Head: "rack/head",
    Headers: "rack/headers",
    Lint: "rack/lint",
    Lock: "rack/lock",
    MediaType: "rack/media_type",
    MethodOverride: "rack/method_override",
    Mime: "rack/mime",
    MockRequest: "rack/mock_request",
    MockResponse: "rack/mock_response",
    Multipart: "rack/multipart",
    NullLogger: "rack/null_logger",
    QueryParser: "rack/query_parser",
    Recursive: "rack/recursive",
    Reloader: "rack/reloader",
    Request: "rack/request",
    Response: "rack/response",
    RewindableInput: "rack/rewindable_input",
    Runtime: "rack/runtime",
    Sendfile: "rack/sendfile",
    ShowExceptions: "rack/show_exceptions",
    ShowStatus: "rack/show_status",
    Static: "rack/static",
    TempfileReaper: "rack/tempfile_reaper",
    URLMap: "rack/urlmap",
    Utils: "rack/utils"
  }.freeze

  AUTOLOADS.each do |const_name, path|
    autoload const_name, path
  end

  module Auth
    AUTOLOADS = {
      Basic: "rack/auth/basic",
      AbstractHandler: "rack/auth/abstract/handler",
      AbstractRequest: "rack/auth/abstract/request"
    }.freeze

    AUTOLOADS.each do |const_name, path|
      autoload const_name, path
    end
  end
end
