# frozen_string_literal: true

#
# = debug_rack_autoload.rb
#
# 调试方法：当 Rack 的某个 +autoload+ 常量因对应的 .rb 文件缺失而触发 LoadError 时，
# 本模块能够反向定位出**是哪一个 autoload 常量**（以及它在 rack.rb 中的声明行号）
# 导致了加载失败。
#
# == 原理
#
# 1. 扫描 Rack（及其子模块 Rack::Auth）中所有已注册的 autoload，建立
#    "文件路径 → 完整常量名" 的逆向映射表。
# 2. 通过 Module#prepend 钩住 Kernel#require。
# 3. 当 require 抛出 LoadError 时，从映射表中查出对应的常量名与声明行，
#    打印详细诊断信息到 stderr，然后重新抛出异常。
#
# == 使用方式
#
#   require 'rack'
#   require 'debug_rack_autoload'
#
#   # 之后任意对缺失 autoload 常量的引用都会自动打印诊断信息
#   begin
#     Rack::BadRequest  # 如果 bad_request.rb 缺失，会触发诊断
#   rescue LoadError
#     # 异常已被重新抛出，按需处理
#   end
#
# == 主动检查模式
#
# 也可以调用 DebugRackAutoload.check! 主动扫描全部 autoload 常量并报告所有缺失：
#
#   DebugRackAutoload.check!
#

module DebugRackAutoload
  # ---------------------------------------------------------------
  # 逆向映射表：文件路径 => { const:, mod:, full_name: }
  # 例如：
  #   "rack/bad_request" => { const: :BadRequest, mod: Rack, full_name: "Rack::BadRequest" }
  # ---------------------------------------------------------------
  @reverse_map = {}

  class << self
    attr_reader :reverse_map
  end

  # ---------------------------------------------------------------
  # 扫描单个模块下所有 autoload 注册项
  # ---------------------------------------------------------------
  def self.scan_module(mod, prefix)
    mod.constants(false).each do |const_name|
      path = mod.autoload?(const_name)
      next unless path

      full_name = "#{prefix}::#{const_name}"
      @reverse_map[path] = { const: const_name, mod: mod, full_name: full_name }
    end
  end

  # ---------------------------------------------------------------
  # 在 rack.rb 中查找某 autoload 声明的行号
  # ---------------------------------------------------------------
  def self.find_autoload_line(path)
    rack_rb = $LOADED_FEATURES.find { |f| f.end_with?("/rack.rb") }
    return nil unless rack_rb && File.exist?(rack_rb)

    entry = @reverse_map[path]
    return nil unless entry

    const_name = entry[:const]
    # 匹配形如 "  autoload :BadRequest, \"rack/bad_request\"" 的行
    pattern = /^\s*autoload\s+:#{const_name}\b/

    File.readlines(rack_rb).each_with_index do |line, idx|
      return idx + 1 if line.match?(pattern)
    end
    nil
  rescue
    nil
  end

  # ---------------------------------------------------------------
  # 打印诊断信息
  # ---------------------------------------------------------------
  def self.diagnose(path, original_message)
    entry = @reverse_map[path]
    return unless entry  # 非我们跟踪的 autoload，跳过

    line_no = find_autoload_line(path)
    line_info = line_no ? "rack.rb:#{line_no}" : "unknown"

    $stderr.puts <<~MSG

      [DebugRackAutoload] ======== Autoload LoadError Diagnose ========
      [DebugRackAutoload] Failed constant : #{entry[:full_name]}
      [DebugRackAutoload] Declared at     : #{line_info}
      [DebugRackAutoload] Expected file   : #{path}.rb
      [DebugRackAutoload] Original error  : #{original_message}
      [DebugRackAutoload] =============================================

    MSG
  end

  # ---------------------------------------------------------------
  # 安装钩子 —— 核心入口
  #
  # 做了两件事：
  #   1. 扫描当前所有 autoload，建立逆向映射表
  #   2. 通过 Module#prepend 钩住 Kernel#require
  #   3. （可选）也钩住 Module#autoload 以便跟踪后续新增的 autoload
  # ---------------------------------------------------------------
  def self.install!
    # ---- 第 1 步：扫描现有 autoload ----
    scan_module(Rack, "Rack")
    scan_module(Rack::Auth, "Rack::Auth") if Rack.const_defined?(:Auth)

    # ---- 第 2 步：钩住 Kernel#require ----
    kernel_debug = Module.new do
      define_method(:require) do |path|
        super(path)
      rescue LoadError => e
        DebugRackAutoload.diagnose(path, e.message)
        raise
      end
    end
    Kernel.prepend(kernel_debug)

    # ---- 第 3 步（可选）：钩住 Module#autoload 以跟踪后续注册 ----
    Module.define_method(:autoload) do |const_name, path|
      super(const_name, path)
      if self == Rack || self == Rack::Auth
        prefix = (self == Rack::Auth) ? "Rack::Auth" : "Rack"
        full_name = "#{prefix}::#{const_name}"
        DebugRackAutoload.reverse_map[path] = { const: const_name, mod: self, full_name: full_name }
      end
    end
  end

  # ---------------------------------------------------------------
  # 主动检查模式：逐个尝试解析所有 autoload 常量，报告所有缺失
  #
  # 适合在程序启动时调用，提前发现所有缺失的 autoload 文件。
  # ---------------------------------------------------------------
  def self.check!
    failures = []

    @reverse_map.each do |path, info|
      begin
        info[:mod].const_get(info[:const])
      rescue LoadError => e
        line_no = find_autoload_line(path)
        line_info = line_no ? "rack.rb:#{line_no}" : "unknown"
        failures << { full_name: info[:full_name], line: line_info, path: path, error: e.message }
      end
    end

    if failures.empty?
      $stdout.puts "[DebugRackAutoload] All autoload constants loaded successfully."
    else
      $stdout.puts "[DebugRackAutoload] Found #{failures.size} failing autoload(s):"
      failures.each_with_index do |f, i|
        $stdout.puts "  #{i + 1}. #{f[:full_name]}"
        $stdout.puts "     Declared at : #{f[:line]}"
        $stdout.puts "     File path   : #{f[:path]}.rb"
        $stdout.puts "     Error       : #{f[:error]}"
      end
    end

    failures
  end
end

# 自动安装
DebugRackAutoload.install!