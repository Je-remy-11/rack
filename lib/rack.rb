# frozen_string_literal: true

# Copyright (C) 2007-2019 Leah Neukirchen <http://leahneukirchen.org/infopage.html>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See MIT-LICENSE or https://opensource.org/licenses/MIT.

# The Rack main module, serving as a namespace for all core Rack
# modules and classes.
#
# All modules meant for use in your application are loaded via
# <tt>rack/autoloads</tt>, so it should be enough just to
# <tt>require 'rack'</tt> in your code.
require_relative 'rack/version'
require_relative 'rack/constants'
require_relative 'rack/autoloads'

module Rack
  # Return the Rack release as a dotted string.
  def self.release
    VERSION
  end
end