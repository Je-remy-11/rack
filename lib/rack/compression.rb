# frozen_string_literal: true

require_relative "deflater"

module Rack
  class Compression < Deflater
  end
end
