# Rack Autoload 重构示例

本项目提供了两种支持 Zeitwerk 自动加载器的兼容方案。

## 方案一：条件性 autoload + Zeitwerk（推荐）

**文件：`lib/rack.rb`**

这种方案提供了最高的兼容性，特点：
- 生产环境默认使用传统 `autoload`
- 开发/测试环境自动使用 Zeitwerk
- 可通过环境变量 `RACK_USE_ZEITWERK=true` 强制使用 Zeitwerk

### 使用方式
```ruby
# 默认根据环境自动选择
require 'rack'

# 强制使用 Zeitwerk
ENV['RACK_USE_ZEITWERK'] = 'true'
require 'rack'
```

## 方案二：完全基于 Zeitwerk（带兼容层）

**文件：`lib/rack_zeitwerk.rb`**

这种方案完全依赖 Zeitwerk，但提供兼容层，特点：
- 始终使用 Zeitwerk 作为主要加载器
- 通过方法和 const_missing 提供旧代码兼容性
- 适合作为最终迁移目标

### 使用方式
```ruby
require 'rack_zeitwerk'
```

## 测试示例

```ruby
# 测试方案一
require './lib/rack'
puts Rack::Builder.test    # => "Rack::Builder is loaded"
puts Rack::Utils.test      # => "Rack::Utils is loaded"

# 测试方案二
require './lib/rack_zeitwerk'
puts Rack::Builder.test    # => "Rack::Builder is loaded"
puts Rack::Utils.test      # => "Rack::Utils is loaded"
```
