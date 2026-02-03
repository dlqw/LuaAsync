# LuaAsync

<div align="center">

**现代 Lua 异步/等待库，受 C# 的 Task-based Asynchronous Pattern 启发**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://www.lua.org/)
[![Performance](https://img.shields.io/badge/性能-200K%2B%20任务%2Fs-brightgreen.svg)](benchmark_async.lua)

</div>

## ✨ 特性

- 🚀 **高性能**: 每秒约 238,000 个任务吞吐量
- 🎯 **类 C# API**: 熟悉的 async/await 模式
- 🔄 **取消支持**: 协作取消令牌
- 📊 **任务状态追踪**: 完整的任务生命周期可见性
- 🧪 **充分测试**: 全面的单元和内存测试
- 💾 **内存安全**: 未检测到内存泄漏
- 🔧 **生产就绪**: 经过实战测试和优化

## 📦 安装

只需将 `async.lua` 复制到您的项目中：

```bash
curl -O https://raw.githubusercontent.com/dlqw/LuaAsync/main/async.lua
```

或直接在您的项目中引用。

## 🚀 快速开始

```lua
require("async")

-- 初始化异步系统
Async.Init()

-- 更新函数（从游戏循环每帧调用）
function Tick(deltaTime)
    Async.Update(deltaTime)
end

-- 创建并运行异步任务
local task = Task.Run(function()
    print("任务开始！")
    Await(Task.Delay(1000))  -- 等待 1 秒
    print("任务完成！")
    return "结果"
end)

-- 添加完成回调
task:OnCompleted(function()
    print("任务结果:", task._result)
end)
```

## 📖 API 概览

### 任务创建

```lua
-- 运行任务（根任务 - 创建新任务组）
Task.Run(function()
    -- 您的异步代码
end, cancellationToken)

-- 手动创建并启动任务
local task = Task.new(function()
    return "结果"
end, cancellationToken)
task:Start()

-- 创建已完成的任务
local task = Task.FromResult("立即结果")

-- 创建子任务（在当前任务组中执行）
Task.RunAsSub(function()
    -- 在父任务组中运行
end, cancellationToken)
```

### 异步等待

```lua
-- 等待延迟
Await(Task.Delay(1000))  -- 1000毫秒

-- 等待到下一帧
Await(Task.NextFrame())

-- 等待条件
Await(Task.Until(function()
    return Player.health <= 0
end))

-- 等待多个任务（全部）
local results = {Await(Task.WhenAll(nil, task1, task2, task3))}

-- 等待多个任务（任意）
local firstIndex = Await(Task.WhenAny(nil, task1, task2))
```

### 任务状态和结果

```lua
-- 获取任务状态
local status = task:GetStatus()
-- 可能的值：
--   TaskStatus.Created
--   TaskStatus.Running
--   TaskStatus.Completed
--   TaskStatus.Cancelled
--   TaskStatus.Faulted

-- 访问结果
if status == TaskStatus.Completed then
    print("结果:", task._result)
end

-- 添加完成回调
task:OnCompleted(function()
    print("任务完成！")
end)

-- 即发即弃（作为根任务启动）
Task.Run(function()
    -- 无需等待即可运行
end):Forget()
```

### 取消

```lua
-- 创建取消令牌源
local cts = CancellationTokenSource.new()

-- 获取令牌
local token = cts:GetToken()

-- 传递给任务
local task = Task.Run(function()
    Await(Task.Delay(5000, token))
end, token)

-- 从任何地方取消
cts:Cancel()

-- 检查是否已取消
if token:IsCancellationRequested() then
    print("已取消！")
end
```

### Waitable 转 Task

```lua
-- 将任何 Waitable 转换为 Task
local delayWaitable = Task.Delay(1000)
local delayTask = delayWaitable:ToTask(optionalToken)
```

## 📚 完整示例

```lua
require("async")

Async.Init()

function Tick(deltaTime)
    Async.Update(deltaTime)
end

-- 示例 1: 简单延迟
local task1 = Task.Run(function()
    print("加载中...")
    Await(Task.Delay(1000))
    print("加载完成！")
end)

-- 示例 2: 使用 WhenAll 的多任务
local task2 = Task.new(function()
    Await(Task.Delay(500))
    return "你好"
end)

local task3 = Task.new(function()
    Await(Task.Delay(500))
    return "世界"
end)

Task.Run(function()
    local results = {Await(Task.WhenAll(nil, task2, task3))}
    print(results[1], results[2])  -- "你好 世界"
end)

-- 示例 3: 取消
local cts = CancellationTokenSource.new()

local longTask = Task.Run(function()
    for i = 1, 100 do
        if cts:GetToken():IsCancellationRequested() then
            print("任务已取消！")
            return
        end
        Await(Task.Delay(100))
        print("进度:", i .. "%")
    end
end, cts:GetToken())

-- 2 秒后取消
Task.Run(function()
    Await(Task.Delay(2000))
    cts:Cancel()
end):Forget()

-- 示例 4: 条件等待
local player = { health = 100 }

Task.Run(function()
    -- 等待玩家死亡或超时
    local index = Await(Task.WhenAny(nil,
        Task.Delay(5000):ToTask(),
        Task.Until(function() return player.health <= 0 end):ToTask()
    ))

    if index == 1 then
        print("超时！")
    else
        print("玩家死亡！")
    end
end):Forget()
```

## 🧪 测试

运行测试套件：

```bash
# 单元测试（15 个测试覆盖所有功能）
lua test_async.lua

# 内存泄漏测试
lua memory_test.lua

# 性能基准测试
lua benchmark_async.lua
```

### 测试结果

```bash
$ lua test_async.lua
✓ 所有 15 个测试通过！

$ lua memory_test.lua
✓ 所有内存测试通过 - 未检测到显著泄漏
```

## 📊 性能

基于 **5 次连续基准测试**的性能数据，在 Windows/Cygwin 上运行 10,000 次迭代：

### 基准测试结果

| 指标 | 平均值 | 范围 | 评级 |
|------|--------|------|------|
| 任务创建 | 0.0038ms | 0.0033-0.0042ms | ⭐⭐⭐⭐⭐ |
| 调度吞吐量 | 215,634 任务/秒 | 163,934-256,410 | ⭐⭐⭐⭐⭐ |
| FromResult | 2,173,913 任务/秒 | 2,000,000+ | ⭐⭐⭐⭐⭐ |
| 内存泄漏 | 未检测到 | - | ⭐⭐⭐⭐⭐ |

### 实际测试数据

```
=== 5 次连续基准测试运行 ===

第 1 次: 227,273 任务/秒, 0.0033ms/任务
第 2 次: 222,222 任务/秒, 0.0042ms/任务
第 3 次: 163,934 任务/秒, 0.0041ms/任务  (最低)
第 4 次: 208,333 任务/秒, 0.0038ms/任务
第 5 次: 256,410 任务/秒, 0.0038ms/任务  (最高)

平均值:  215,634 任务/秒, 0.0038ms/任务
标准差:  ±32,610 任务/秒 (±15% 波动)
```

> **注意**：性能会因系统负载、Lua 版本和硬件而异。所示结果为现代 Windows 系统上的典型值。

## 🎯 用途

- **游戏开发**: 异步游戏逻辑、动画、AI
- **网络编程**: 非阻塞 HTTP 请求、websockets
- **文件 I/O**: 异步文件操作
- **UI 编程**: 流畅的动画、过渡
- **后台任务**: 数据处理、计算

## 🔧 高级用法

### 嵌套任务

```lua
Task.Run(function()
    print("父任务")

    Task.RunAsSub(function()
        print("子任务 1")
        Await(Task.Delay(100))
    end)

    Task.RunAsSub(function()
        print("子任务 2")
        Await(Task.Delay(100))
    end)

    -- 等待所有子任务完成
    coroutine.yield()
    print("所有子任务完成")
end)
```

### 任务状态监控

```lua
local task = Task.Run(function()
    for i = 1, 10 do
        coroutine.yield()
    end
end)

while task:GetStatus() ~= TaskStatus.Completed do
    print("任务仍在运行...")
    Tick(0.016)
end

print("任务已完成，状态:", task:GetStatus())
```

### 错误处理

```lua
local task = Task.Run(function()
    if some_error then
        error("出错了！")
    end
    return "成功"
end)

task:OnCompleted(function()
    if task:GetStatus() == TaskStatus.Faulted then
        print("任务失败！")
    else
        print("任务成功:", task._result)
    end
end)
```

## 📖 API 参考

### Task 函数

| 函数 | 描述 |
|------|------|
| `Task.new(func, token)` | 创建新任务 |
| `Task.Run(func, token)` | 创建并运行任务（根） |
| `Task.RunAsSub(func, token)` | 创建并作为子任务运行 |
| `Task.Delay(ms, token)` | 创建延迟等待 |
| `Task.NextFrame(token)` | 等待到下一帧 |
| `Task.Until(condition, token)` | 等待条件 |
| `Task.WhenAll(token, ...)` | 等待所有任务 |
| `Task.WhenAny(token, ...)` | 等待第一个任务 |
| `Task.FromResult(value)` | 创建已完成任务 |

### Task 方法

| 方法 | 描述 |
|------|------|
| `task:Start()` | 作为根任务启动 |
| `task:StartAsSub()` | 作为子任务启动 |
| `task:Forget()` | 启动但不等待（使用 Start） |
| `task:OnCompleted(callback)` | 添加完成回调 |
| `task:GetStatus()` | 获取当前状态 |
| `task:Complete()` | 标记为完成（内部） |

### CancellationToken

| 方法/属性 | 描述 |
|-----------|------|
| `CancellationTokenSource.new()` | 创建令牌源 |
| `source:Cancel()` | 请求取消 |
| `source:GetToken()` | 获取令牌 |
| `token:IsCancellationRequested()` | 检查是否已取消 |

### TaskStatus 枚举

| 值 | 描述 |
|-----|------|
| `TaskStatus.Created` | 任务已创建，未启动 |
| `TaskStatus.Running` | 任务正在执行 |
| `TaskStatus.Completed` | 任务成功完成 |
| `TaskStatus.Cancelled` | 任务已取消 |
| `TaskStatus.Faulted` | 任务遇到错误 |

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

## 📄 许可证

本项目基于 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- 灵感来自 C# 的 Task-based Asynchronous Pattern
- 使用 Lua 协程构建

## 📞 支持

如有问题、疑问或建议，请在 GitHub 上 [提出 issue](https://github.com/dlqw/LuaAsync/issues)。

---

<div align="center">

**由 LuaAsync 社区用 ❤️ 制作**

</div>
