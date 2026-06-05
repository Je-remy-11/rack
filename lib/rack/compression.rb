# frozen_string_literal: true

require_relative 'constants'
require_relative 'utils'
require_relative 'request'

module Rack
  class Compression
    def initialize(app, options = {})
      @app = app
      @options = options
    end

    def call(env)
      @app.call(env)
    end
  end
end
