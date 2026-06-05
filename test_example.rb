#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

puts "=== 测试方案一：条件性 autoload + Zeitwerk ==="
begin
  require 'rack'
  puts "✓ Rack 已加载 (版本: #{Rack::VERSION})"
  puts "  使用 Zeitwerk? #{Rack.use_zeitwerk?}"
  puts "  生产环境? #{Rack.production?}"
  puts "  Rack::Builder: #{Rack::Builder.test}"
  puts "  Rack::Utils: #{Rack::Utils.test}"
rescue => e
  puts "✗ 错误: #{e.message}"
  puts e.backtrace
end

puts "\n"

puts "=== 测试方案二：完全基于 Zeitwerk ==="
begin
  require 'rack_zeitwerk'
  puts "✓ Rack 已加载 (版本: #{Rack::VERSION})"
  puts "  使用 Zeitwerk loader: #{Rack.zeitwerk_loader ? '是' : '否'}"
  puts "  生产环境? #{Rack.production?}"
  puts "  Rack::Builder: #{Rack::Builder.test}"
  puts "  Rack::Utils: #{Rack::Utils.test}"
rescue => e
  puts "✗ 错误: #{e.message}"
  puts e.backtrace
end
