# LuaAsync

<div align="center">

**A modern async/await library for Lua, inspired by C#'s Task-based Asynchronous Pattern**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://www.lua.org/)
[![Performance](https://img.shields.io/badge/Performance-238K%20tasks%2Fs-brightgreen.svg)](benchmark_async.lua)

</div>

## ✨ Features

- 🚀 **High Performance**: ~238,000 tasks/second throughput
- 🎯 **C#-like API**: Familiar async/await pattern
- 🔄 **Cancellation Support**: Cooperative cancellation tokens
- 📊 **Task Status Tracking**: Complete task lifecycle visibility
- 🧪 **Well Tested**: Comprehensive unit and memory tests
- 💾 **Memory Safe**: No memory leaks detected
- 🔧 **Production Ready**: Battle-tested and optimized

## 📦 Installation

Simply copy `async.lua` to your project:

```bash
curl -O https://raw.githubusercontent.com/dlqw/LuaAsync/main/async.lua
```

Or require it directly in your project.

## 🚀 Quick Start

```lua
require("async")

-- Initialize the async system
Async.Init()

-- Update function (call each frame from your game loop)
function Tick(deltaTime)
    Async.Update(deltaTime)
end

-- Create and run async tasks
local task = Task.Run(function()
    print("Task started!")
    Await(Task.Delay(1000))  -- Wait 1 second
    print("Task finished!")
    return "result"
end)

-- Add completion callback
task:OnCompleted(function()
    print("Task result:", task._result)
end)
```

## 📖 API Overview

### Task Creation

```lua
-- Run a task (root task - creates new task group)
Task.Run(function()
    -- Your async code here
end, cancellationToken)

-- Create task and start manually
local task = Task.new(function()
    return "result"
end, cancellationToken)
task:Start()

-- Create already-completed task
local task = Task.FromResult("immediate result")

-- Create sub-task (executes in current task group)
Task.RunAsSub(function()
    -- Runs within parent task group
end, cancellationToken)
```

### Async Waiting

```lua
-- Wait for a delay
Await(Task.Delay(1000))  -- 1000ms

-- Wait until next frame
Await(Task.NextFrame())

-- Wait for a condition
Await(Task.Until(function()
    return Player.health <= 0
end))

-- Wait for multiple tasks (all)
local results = {Await(Task.WhenAll(nil, task1, task2, task3))}

-- Wait for multiple tasks (any)
local firstIndex = Await(Task.WhenAny(nil, task1, task2))
```

### Task Status & Results

```lua
-- Get task status
local status = task:GetStatus()
-- Possible values:
--   TaskStatus.Created
--   TaskStatus.Running
--   TaskStatus.Completed
--   TaskStatus.Cancelled
--   TaskStatus.Faulted

-- Access result
if status == TaskStatus.Completed then
    print("Result:", task._result)
end

-- Add completion callback
task:OnCompleted(function()
    print("Task completed!")
end)

-- Fire-and-forget (starts task as root)
Task.Run(function()
    -- This runs without awaiting
end):Forget()
```

### Cancellation

```lua
-- Create cancellation token source
local cts = CancellationTokenSource.new()

-- Get token
local token = cts:GetToken()

-- Pass to tasks
local task = Task.Run(function()
    Await(Task.Delay(5000, token))
end, token)

-- Cancel from anywhere
cts:Cancel()

-- Check if cancelled
if token:IsCancellationRequested() then
    print("Cancelled!")
end
```

### Waitable to Task Conversion

```lua
-- Convert any Waitable to a Task
local delayWaitable = Task.Delay(1000)
local delayTask = delayWaitable:ToTask(optionalToken)
```

## 📚 Complete Example

```lua
require("async")

Async.Init()

function Tick(deltaTime)
    Async.Update(deltaTime)
end

-- Example 1: Simple delay
local task1 = Task.Run(function()
    print("Loading...")
    Await(Task.Delay(1000))
    print("Loaded!")
end)

-- Example 2: Multiple tasks with WhenAll
local task2 = Task.new(function()
    Await(Task.Delay(500))
    return "Hello"
end)

local task3 = Task.new(function()
    Await(Task.Delay(500))
    return "World"
end)

Task.Run(function()
    local results = {Await(Task.WhenAll(nil, task2, task3))}
    print(results[1], results[2])  -- "Hello World"
end)

-- Example 3: Cancellation
local cts = CancellationTokenSource.new()

local longTask = Task.Run(function()
    for i = 1, 100 do
        if cts:GetToken():IsCancellationRequested() then
            print("Task cancelled!")
            return
        end
        Await(Task.Delay(100))
        print("Progress:", i .. "%")
    end
end, cts:GetToken())

-- Cancel after 2 seconds
Task.Run(function()
    Await(Task.Delay(2000))
    cts:Cancel()
end):Forget()

-- Example 4: Conditional waiting
local player = { health = 100 }

Task.Run(function()
    -- Wait for player death or timeout
    local index = Await(Task.WhenAny(nil,
        Task.Delay(5000):ToTask(),
        Task.Until(function() return player.health <= 0 end):ToTask()
    ))

    if index == 1 then
        print("Timeout!")
    else
        print("Player died!")
    end
end):Forget()
```

## 🧪 Testing

Run the test suite:

```bash
# Unit tests (15 tests covering all features)
lua test_async.lua

# Memory leak tests
lua memory_test.lua

# Performance benchmarks
lua benchmark_async.lua
```

### Test Results

```bash
$ lua test_async.lua
✓ All 15 tests passed!

$ lua memory_test.lua
✓ ALL MEMORY TESTS PASSED - No significant leaks detected

$ lua benchmark_async.lua
✓ Task Creation: 0.0031 ms
✓ Scheduling Throughput: 238,095 tasks/sec
✓ FromResult Speed: 2,439,024 tasks/sec
```

## 📊 Performance

| Metric | Value | Rating |
|--------|-------|--------|
| Task Creation | ~0.003ms | ⭐⭐⭐⭐⭐ |
| Scheduling Throughput | ~238,000 tasks/sec | ⭐⭐⭐⭐⭐ |
| FromResult | ~2,400,000 tasks/sec | ⭐⭐⭐⭐⭐ |
| Memory Usage | No leaks | ⭐⭐⭐⭐⭐ |

## 🎯 Use Cases

- **Game Development**: Asynchronous game logic, animations, AI
- **Network Programming**: Non-blocking HTTP requests, websockets
- **File I/O**: Asynchronous file operations
- **UI Programming**: Smooth animations, transitions
- **Background Tasks**: Data processing, calculations

## 🔧 Advanced Usage

### Nested Tasks

```lua
Task.Run(function()
    print("Parent task")

    Task.RunAsSub(function()
        print("Child task 1")
        Await(Task.Delay(100))
    end)

    Task.RunAsSub(function()
        print("Child task 2")
        Await(Task.Delay(100))
    end)

    -- Wait for all children to complete
    coroutine.yield()
    print("All children done")
end)
```

### Task Status Monitoring

```lua
local task = Task.Run(function()
    for i = 1, 10 do
        coroutine.yield()
    end
end)

while task:GetStatus() ~= TaskStatus.Completed do
    print("Task is still running...")
    Tick(0.016)
end

print("Task completed with status:", task:GetStatus())
```

### Error Handling

```lua
local task = Task.Run(function()
    if some_error then
        error("Something went wrong!")
    end
    return "success"
end)

task:OnCompleted(function()
    if task:GetStatus() == TaskStatus.Faulted then
        print("Task failed!")
    else
        print("Task succeeded:", task._result)
    end
end)
```

## 📖 API Reference

### Task Functions

| Function | Description |
|----------|-------------|
| `Task.new(func, token)` | Create a new task |
| `Task.Run(func, token)` | Create and run a task (root) |
| `Task.RunAsSub(func, token)` | Create and run as sub-task |
| `Task.Delay(ms, token)` | Create a delay waitable |
| `Task.NextFrame(token)` | Wait until next frame |
| `Task.Until(condition, token)` | Wait for condition |
| `Task.WhenAll(token, ...)` | Wait for all tasks |
| `Task.WhenAny(token, ...)` | Wait for first task |
| `Task.FromResult(value)` | Create completed task |

### Task Methods

| Method | Description |
|--------|-------------|
| `task:Start()` | Start as root task |
| `task:StartAsSub()` | Start as sub-task |
| `task:Forget()` | Start without awaiting (uses Start) |
| `task:OnCompleted(callback)` | Add completion callback |
| `task:GetStatus()` | Get current status |
| `task:Complete()` | Mark as complete (internal) |

### CancellationToken

| Method/Property | Description |
|-----------------|-------------|
| `CancellationTokenSource.new()` | Create token source |
| `source:Cancel()` | Request cancellation |
| `source:GetToken()` | Get the token |
| `token:IsCancellationRequested()` | Check if cancelled |

### TaskStatus Enum

| Value | Description |
|-------|-------------|
| `TaskStatus.Created` | Task created, not started |
| `TaskStatus.Running` | Task is executing |
| `TaskStatus.Completed` | Task completed successfully |
| `TaskStatus.Cancelled` | Task was cancelled |
| `TaskStatus.Faulted` | Task encountered an error |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by C#'s Task-based Asynchronous Pattern
- Built with Lua coroutines

## 📞 Support

For issues, questions, or suggestions, please [open an issue](https://github.com/dlqw/LuaAsync/issues) on GitHub.

---

<div align="center">

**Made with ❤️ by the LuaAsync community**

</div>
