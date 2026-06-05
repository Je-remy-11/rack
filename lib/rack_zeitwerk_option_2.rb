# frozen_string_literal: true

# Copyright (C) 2007-2019 Leah Neukirchen <http://leahneukirchen.org/infopage.html>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See MIT-LICENSE or https://opensource.org/licenses/MIT.

require_relative 'rack/version'
require_relative 'rack/constants'

module Rack
  # 方案二：环境变量开关（Opt-in 模式）
  # 仅在设置了特定的环境变量时启用 Zeitwerk，否则默认使用原生的 autoload
  if ENV['RACK_AUTOLOAD_ZEITWERK']
    require "zeitwerk"

    class Inflector < Zeitwerk::Inflector
      def camelize(basename, abspath)
        case basename
        when "urlmap" then "URLMap"
        when "etag"   then "ETag"
        else super
        end
      end
    end

    loader = Zeitwerk::Loader.for_gem
    loader.inflector = Inflector.new
    
    # 忽略不符合 Zeitwerk 文件名约定的文件
    loader.ignore("#{__dir__}/rack/recursive.rb")
    loader.ignore("#{__dir__}/rack/auth/abstract/handler.rb")
    loader.ignore("#{__dir__}/rack/auth/abstract/request.rb")

    loader.setup

    # 手动为被忽略的特殊文件保留 autoload
    autoload :ForwardRequest, "rack/recursive"
    autoload :Recursive, "rack/recursive"
    
    module Auth
      autoload :AbstractHandler, "rack/auth/abstract/handler"
      autoload :AbstractRequest, "rack/auth/abstract/request"
    end
  else
    # 默认依然使用全量的 autoload 列表
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
