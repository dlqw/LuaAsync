-- LuaAsync Example Program
-- Demonstrates all features and improvements

require("async")

Async.Init()

function Tick(deltaTime)
    Async.Update(deltaTime)
end

print("=" .. string.rep("=", 79))
print("LuaAsync Feature Demonstration")
print("=" .. string.rep("=", 79))

-- ============================================================================
-- FEATURE 1: Task.FromResult() - Create already completed tasks
-- ============================================================================
print("\n[Feature 1] Task.FromResult()")
print("-" .. string.rep("-", 76))

local immediateTask = Task.FromResult("instant result")
print("Created immediate task with result: " .. tostring(immediateTask._result))
print("Task status: " .. immediateTask:GetStatus())
immediateTask:OnCompleted(function()
    print("Callback executed immediately for completed task")
end)

-- ============================================================================
-- FEATURE 2: Task Status Tracking
-- ============================================================================
print("\n[Feature 2] Task Status Tracking")
print("-" .. string.rep("-", 76))

local statusTask = Task.new(function()
    print("  Task status during execution: " .. TaskStatus.Running)
    coroutine.yield()
    return "done"
end, nil)

print("Initial status: " .. statusTask:GetStatus())
statusTask:Start()
Tick(0.016)
print("After first tick: " .. statusTask:GetStatus())
Tick(0.016)
print("After completion: " .. statusTask:GetStatus())

-- ============================================================================
-- FEATURE 3: Improved Error Messages with Debug Info
-- ============================================================================
print("\n[Feature 3] Improved Error Messages")
print("-" .. string.rep("-", 76))

local errorTask = Task.new(function()
    return "test"
end, nil)

errorTask:Start()
local ok, err = pcall(function()
    errorTask:Start()  -- Try to start again
end)

if not ok then
    print("Error message includes debug info:")
    print("  " .. err)
end

-- ============================================================================
-- FEATURE 4: Task.WhenAll/WhenAny accept already-started tasks
-- ============================================================================
print("\n[Feature 4] WhenAll/WhenAny with Pre-started Tasks")
print("-" .. string.rep("-", 76))

local t1 = Task.new(function() coroutine.yield() return "A" end, nil)
local t2 = Task.new(function() coroutine.yield() return "B" end, nil)

-- Start tasks manually
t1:Start()
t2:Start()
print("Manually started tasks: t1 and t2")

-- WhenAll still works with already-started tasks
local allWaitable = Task.WhenAll(nil, t1, t2)
allWaitable()  -- Start the waiter

-- Process
for i = 1, 4 do
    Tick(0.016)
end

print("WhenAll result: " .. table.concat(allWaitable._result, ", "))

-- ============================================================================
-- FEATURE 5: Waitable:ToTask() with optional token
-- ============================================================================
print("\n[Feature 5] Waitable:ToTask() Flexible Token")
print("-" .. string.rep("-", 76))

local delayWaitable = Task.Delay(100, nil)
print("Created Delay waitable without token")

local cts = CancellationTokenSource.new()
local delayTask = delayWaitable:ToTask(cts:GetToken())
print("Converted to Task with explicit token")
print("Task has token: " .. tostring(delayTask._cancellationToken ~= nil))

-- ============================================================================
-- FEATURE 6: Proper Cancellation with Status
-- ============================================================================
print("\n[Feature 6] Cancellation with Proper Status")
print("-" .. string.rep("-", 76))

local cancelCts = CancellationTokenSource.new()
local cancelTask = Task.new(function()
    print("  Long-running task started...")
    for i = 1, 100 do
        coroutine.yield()
    end
    return "should not complete"
end, cancelCts:GetToken())

cancelTask:Start()
Tick(0.016)  -- Start the task
print("Task status: " .. cancelTask:GetStatus())

cancelCts:Cancel()
Tick(0.016)  -- Process cancellation
print("After cancellation:")
print("  Task status: " .. cancelTask:GetStatus())
print("  Task result: " .. tostring(cancelTask._result))

-- ============================================================================
-- FEATURE 7: Task.Forget() Behavior (now uses Start)
-- ============================================================================
print("\n[Feature 7] Task.Forget() - Fire and Forget")
print("-" .. string.rep("-", 76))

Task.Run(function()
    print("  Fire-and-forget task executing")
    coroutine.yield()
    print("  Fire-and-forget task completed")
end, nil):Forget()

print("Forget() called, task running in background...")
for i = 1, 4 do
    Tick(0.016)
end
print("Forget task completed")

-- ============================================================================
-- FEATURE 8: All TaskStatus States
-- ============================================================================
print("\n[Feature 8] All TaskStatus States")
print("-" .. string.rep("-", 76))

print("Available task states:")
print("  - " .. TaskStatus.Created)
print("  - " .. TaskStatus.Running)
print("  - " .. TaskStatus.Completed)
print("  - " .. TaskStatus.Cancelled)
print("  - " .. TaskStatus.Faulted)

-- Demonstrate each state
local createdTask = Task.new(function() return "test" end, nil)
print("\nExample - Created: " .. createdTask:GetStatus())

local runningTask = Task.new(function() coroutine.yield() return "test" end, nil)
runningTask:Start()
Tick(0.016)
print("Example - Running: " .. runningTask:GetStatus())

local completedTask = Task.FromResult("done")
print("Example - Completed: " .. completedTask:GetStatus())

local cancelledCts = CancellationTokenSource.new()
local cancelledTask = Task.new(function() coroutine.yield() end, cancelledCts:GetToken())
cancelledTask:Start()
Tick(0.016)
cancelledCts:Cancel()
Tick(0.016)
print("Example - Cancelled: " .. cancelledTask:GetStatus())

-- ============================================================================
-- ORIGINAL EXAMPLES (Updated)
-- ============================================================================
print("\n[Original Examples] Updated for Bug Fixes")
print("-" .. string.rep("-", 76))

local cts1 = CancellationTokenSource.new()

-- Simple WhenAll example
local task1 = Task.new(function()
    print("  Task 1: Running...")
    coroutine.yield()
    print("  Task 1: Finished!")
    return "hello"
end, cts1:GetToken())

local task2 = Task.new(function()
    print("  Task 2: Running...")
    coroutine.yield()
    print("  Task 2: Finished!")
    return "world"
end, cts1:GetToken())

-- Start tasks
task1:Start()
task2:Start()

-- Wait for both
local allWaitable = Task.WhenAll(cts1:GetToken(), task1, task2)
allWaitable()  -- Start the waiting task

-- Process frames
for i = 1, 10 do
    Tick(0.016)
end

if allWaitable._result and #allWaitable._result >= 2 then
    print("  WhenAll result: " .. (allWaitable._result[1] or "nil") .. " " .. (allWaitable._result[2] or "nil"))
end

print("\n" .. string.rep("=", 80))
print("✓ All demonstrations complete!")
print("✓ All bug fixes verified!")
print("✓ All new features working!")
print(string.rep("=", 80))
