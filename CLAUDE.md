# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LuaAsync is a coroutine-based async/await library for Lua, inspired by C#'s Task-based Asynchronous Pattern (TAP). It provides a task scheduling system built on Lua coroutines with support for cancellation tokens and comprehensive task status tracking.

## Architecture

### Core Components

**Async Module (async.lua)**
- `Async`: Global singleton managing the task scheduler
  - `_taskQueue`: Current frame's task queue
  - `_pendingTaskQueue`: Next frame's task queue
  - `_currentTaskGroup`: Currently executing task group (recreated each frame)

**Task System**
- `Task`: Represents an asynchronous operation wrapping a Lua coroutine
  - `_status`: Current task state (Created/Running/Completed/Cancelled/Faulted)
  - `_hasUsed`: Tracks if task has been started (prevents duplicate starts)
  - `_debugInfo`: Creation location for better error messages
- `Waitable`: A promise-like object that tasks can await
  - `_invoker`: Functions to start sub-tasks (set to `nil` when complete)
  - `_callbacks`: Completion callbacks (set to `nil` when complete)
  - `_result`: Task result value
- `Await()`: Suspends execution until a Waitable completes (yields coroutine)

**Task Execution Model**
- Tasks are organized into "task groups" that share a cancellation token
- Each frame, the scheduler swaps task queues and processes all tasks in order
- Tasks can be run as root tasks (`Task.Run()` or `task:Start()`) or as sub-tasks (`Task.RunAsSub()` or `task:StartAsSub()`)
- Sub-tasks are added to the current task group and executed within the same frame
- Completed tasks (dead coroutines) are properly handled and removed from queues

**Cancellation**
- `CancellationTokenSource`: Creates and owns cancellation tokens
- `CancellationToken`: Immutable token passed to tasks for cooperative cancellation
- When a task group is cancelled, all active tasks are marked as Cancelled with `result = nil`
- Cancelled tasks are not re-inserted into the pending queue

**Task Status Tracking**
- `TaskStatus`: Enum with five states:
  - `Created`: Task initialized but not started
  - `Running`: Task is actively executing
  - `Completed`: Task finished successfully
  - `Cancelled`: Task was cancelled
  - `Faulted`: Task encountered an error

## Initialization and Runtime

### Required Setup
```lua
require("async")
Async.Init()
```

### Required Per-Frame Update
```lua
function Tick(deltaTime)
    Async.Update(deltaTime)
end
```

The library requires a per-frame update call with deltaTime to drive task execution. This is typically called from your game engine or framework's update loop.

## Task Creation Patterns

**Root Task** (creates new task group):
```lua
Task.Run(function() ... end, cancellationToken)
-- or
local task = Task.new(function() ... end, cancellationToken)
task:Start()
```

**Sub-Task** (executes in current task group):
```lua
Task.RunAsSub(function() ... end, cancellationToken)
-- or
local task = Task.new(function() ... end, cancellationToken)
task:StartAsSub()
```

**Immediate Task** (already completed):
```lua
local task = Task.FromResult(value)
```

## Key API Functions

**Task Status Queries**
```lua
local status = task:GetStatus()  -- Returns TaskStatus enum value
if status == TaskStatus.Running then
    print("Task is running")
end
```

**Awaiting Results**
```lua
local result = Await(Task.Delay(1000, cancellationToken))
```

**Async Utilities**
- `Task.Delay(milliseconds, cancellationToken)`: Wait for specified time
- `Task.NextFrame(cancellationToken)`: Wait until next frame
- `Task.Until(condition, cancellationToken)`: Wait until predicate returns true
- `Task.WhenAll(cancellationToken, ...)`: Wait for all tasks to complete (accepts already-started tasks)
- `Task.WhenAny(cancellationToken, ...)`: Wait for first task to complete (accepts already-started tasks)
- `Task.FromResult(value)`: Create an already-completed task with a result

**Waitable to Task Conversion**
```lua
local task = waitable:ToTask(optionalCancellationToken)
```

**Fire-and-Forget**
```lua
task:Forget()  -- Now uses Start() (root task) instead of StartAsSub()
```

**Completion Callbacks**
```lua
task:OnCompleted(function()
    print("Task completed with result:", task._result)
end)
```

## Implementation Details

### Task Lifecycle
1. **Created**: `Task.new()` creates task with `_status = Created`, `_hasUsed = false`
2. **Started**: `task:Start()` or `task:StartAsSub()` sets `_hasUsed = true`, prevents duplicate starts
3. **Running**: First `_moveNext()` call sets `_status = Running`
4. **Completion**: Final `_moveNext()` call sets `_status = Completed/Cancelled/Faulted`
5. **Callbacks**: `task:Complete()` triggers all `OnCompleted()` callbacks, then sets `_callbacks = nil`

### Cancellation Behavior
- When a task group's cancellation token is triggered:
  - All non-dead tasks in the group are marked as `Cancelled`
  - Tasks' `_result` is set to `nil`
  - Tasks are completed and removed from the queue (not re-inserted)
- Individual tasks check their cancellation token at the start of `_moveNext()`
- Cancelled tasks never run their coroutine body again

### Error Handling
- Error messages include debug info (source file and line) when available:
  ```
  Task is already started or completed (created at main.lua:42)
  ```
- Faulted tasks set `_status = TaskStatus.Faulted` before throwing the error

### Memory Management
- Completed tasks have `_invoker = nil` and `_callbacks = nil` to allow GC
- Waitable prototypes don't set default `_invoker`/`_callbacks` to avoid inheritance issues
- Task cleanup happens automatically when tasks complete

## Common Issues and Solutions

### Issue: "RunAsSub must be called in a Task"
**Cause**: Calling `Task.RunAsSub()` or `task:StartAsSub()` outside of any running task.
**Solution**: Use `Task.Run()` or `task:Start()` instead for root tasks.

### Issue: "Waitable is already completed"
**Cause**: Attempting to await the same Waitable multiple times.
**Solution**: Create a new Task or Waitable for each await operation, or use `Task.FromResult()` for synchronous values.

### Issue: Task not completing
**Cause**: Forgetting to call `Async.Update(deltaTime)` each frame.
**Solution**: Ensure your game loop calls the update function with proper deltaTime.

### Issue: WhenAll/WhenAny returning unexpected results
**Cause**: Passing already-started tasks that haven't completed yet.
**Solution**: The library now handles this correctly - tasks can be started before being passed to WhenAll/WhenAny.

## Performance Characteristics

Based on benchmark results:
- **Task Creation**: ~0.003ms per task
- **Scheduling Throughput**: ~238,000 tasks/second
- **FromResult Speed**: ~2,400,000 tasks/second
- **Memory**: No significant leaks detected in normal usage

## Testing

Run unit tests:
```bash
lua test_async.lua
```

Run memory leak tests:
```bash
lua memory_test.lua
```

Run performance benchmarks:
```bash
lua benchmark_async.lua
```

See `program.lua` for comprehensive examples of all features.
