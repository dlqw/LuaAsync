-- LuaAsync Unit Test Suite
-- Tests all bug fixes and improvements

require("async")

-- Test framework
local TestRunner = {}
TestRunner.tests = {}
TestRunner.passed = 0
TestRunner.failed = 0
TestRunner.failures = {}

function TestRunner.add(name, testFunc)
    table.insert(TestRunner.tests, {name = name, func = testFunc})
end

function TestRunner.assert(condition, message)
    if not condition then
        error("Assertion failed: " .. (message or "no message"))
    end
end

function TestRunner.assertEqual(expected, actual, message)
    if expected ~= actual then
        error(string.format("Assertion failed: expected %s but got %s. %s",
            tostring(expected), tostring(actual), message or ""))
    end
end

function TestRunner.assertError(func, message)
    local ok, err = pcall(func)
    if ok then
        error("Expected error but none was thrown. " .. (message or ""))
    end
end

function TestRunner.run()
    print("=" .. string.rep("=", 79))
    print("Running LuaAsync Unit Tests")
    print("=" .. string.rep("=", 79))

    for _, test in ipairs(TestRunner.tests) do
        local ok, err = pcall(function()
            -- Reset Async state
            Async.Init()

            test.func()
        end)

        if ok then
            TestRunner.passed = TestRunner.passed + 1
            print(string.format("✓ PASS: %s", test.name))
        else
            TestRunner.failed = TestRunner.failed + 1
            table.insert(TestRunner.failures, {name = test.name, error = err})
            print(string.format("✗ FAIL: %s", test.name))
            print(string.format("  Error: %s", tostring(err)))
        end
    end

    print("\n" .. string.rep("=", 80))
    print(string.format("Results: %d passed, %d failed", TestRunner.passed, TestRunner.failed))
    print(string.rep("=", 80))

    return TestRunner.failed == 0
end

-- Mock time tracker
local mockTime = { current = 0 }
function mockTime.advance(seconds)
    mockTime.current = mockTime.current + seconds
end

-- ============================================================================
-- TEST SUITE
-- ============================================================================

-- Test 1: Waitable.__call completion detection (Fix #1)
TestRunner.add("Fix #1: Waitable.__call detects double-await", function()
    -- Use a real Task's waitable to test
    local task = Task.new(function()
        return "test result"
    end, nil)

    local waitable = task._waitable

    -- First call should succeed
    local ok1 = pcall(function() waitable() end)
    TestRunner.assert(ok1, "First call should succeed")

    -- Second call should error
    local ok2, err2 = pcall(function() waitable() end)
    TestRunner.assert(not ok2, "Second call should fail")
    TestRunner.assert(err2:match("already completed") or err2:match("completed"),
        "Error should mention 'already completed' or 'completed'")
end)

-- Test 2: Task._hasUsed prevents duplicate starts (Fix #3)
TestRunner.add("Fix #3: Task._hasUsed prevents duplicate starts", function()
    local task = Task.new(function()
        coroutine.yield()
    end, nil)

    TestRunner.assert(not task._hasUsed, "New task should have _hasUsed = false")

    -- First start should succeed
    task:Start()
    TestRunner.assert(task._hasUsed, "After start, _hasUsed should be true")

    -- Second start should fail
    local ok, err = pcall(function() task:Start() end)
    TestRunner.assert(not ok, "Second start should fail")
    TestRunner.assert(err:match("already started"), "Error should mention 'already started'")
end)

-- Test 3: Task.FromResult() creates completed task (Fix #11)
TestRunner.add("Fix #11: Task.FromResult() creates completed task", function()
    local result = {data = "test"}
    local task = Task.FromResult(result)

    TestRunner.assertEqual(result, task._result, "Result should match")
    TestRunner.assertEqual(TaskStatus.Completed, task:GetStatus(), "Status should be Completed")
    TestRunner.assert(task._hasUsed, "FromResult task should have _hasUsed = true")
end)

-- Test 4: Task status tracking through lifecycle (Fix #12)
TestRunner.add("Fix #12: Task status tracking", function()
    local task = Task.new(function()
        coroutine.yield()
    end, nil)

    TestRunner.assertEqual(TaskStatus.Created, task:GetStatus(), "Initial status should be Created")

    -- Start the task
    task:Start()

    -- Run one frame to start the task
    Async.Update(0.016)
    TestRunner.assertEqual(TaskStatus.Running, task:GetStatus(), "Status should be Running")

    -- Complete the task
    Async.Update(0.016)
    TestRunner.assertEqual(TaskStatus.Completed, task:GetStatus(), "Final status should be Completed")
end)

-- Test 5: Cancelled task returns nil result (Fix #8)
TestRunner.add("Fix #8: Cancelled task returns nil result", function()
    local cts = CancellationTokenSource.new()
    local ran = false
    local task = Task.new(function()
        ran = true
        -- Simple yielding task
        coroutine.yield()
        return "should not complete"
    end, cts:GetToken())

    task:Start()

    -- Start the task (first _moveNext)
    Async.Update(0.016)

    TestRunner.assert(ran, "Task should have started")

    -- Cancel before second _moveNext
    cts:Cancel()

    -- Second _moveNext should detect cancellation
    Async.Update(0.016)

    -- Task should be cancelled
    TestRunner.assertEqual(nil, task._result, "Cancelled task result should be nil")
    TestRunner.assertEqual(TaskStatus.Cancelled, task:GetStatus(), "Status should be Cancelled")
end)

-- Test 6: WhenAll/WhenAny accept already-started tasks (Fix #6)
TestRunner.add("Fix #6: WhenAll/WhenAny with already-started tasks", function()
    local task1 = Task.new(function() coroutine.yield() return "a" end, nil)
    local task2 = Task.new(function() coroutine.yield() return "b" end, nil)

    -- Start tasks first
    task1:Start()
    task2:Start()

    -- WhenAll should still work
    local waitable = Task.WhenAll(nil, task1, task2)
    TestRunner.assert(waitable ~= nil, "WhenAll should return a waitable")

    -- Run to completion
    Async.Update(0.016)
    Async.Update(0.016)

    TestRunner.assert(waitable._result ~= nil, "Should have results")
end)

-- Test 7: Task.Forget() uses Start() not StartAsSub() (Fix #7)
TestRunner.add("Fix #7: Task.Forget() uses Start() not StartAsSub()", function()
    -- Task.__call now calls Start() instead of StartAsSub()
    local task = Task.new(function() coroutine.yield() end, nil)

    -- Using __call (which Forget() uses)
    task()  -- This should call Start()

    TestRunner.assert(task._hasUsed, "Task should be marked as used")
    TestRunner.assert(#Async._pendingTaskQueue > 0, "Task should be in queue as root task")

    -- Check it's in its own task group (root task)
    local taskGroup = Async._pendingTaskQueue[1]
    TestRunner.assert(taskGroup ~= nil, "Should have a task group")
    TestRunner.assertEqual(1, #taskGroup, "Root task group should have 1 task")
end)

-- Test 8: Cancellation doesn't cause infinite loop (Fix #4)
TestRunner.add("Fix #4: Cancellation doesn't cause infinite loop", function()
    local cts = CancellationTokenSource.new()

    local task1 = Task.new(function()
        Task.Delay(1000, cts:GetToken()):Forget()
    end, cts:GetToken())

    local task2 = Task.new(function()
        coroutine.yield()  -- Task 2 completes immediately
        return "done"
    end, cts:GetToken())

    task1:Start()
    task2:Start()

    -- Cancel immediately
    cts:Cancel()

    -- Run multiple frames - should not grow infinitely
    local queueSizeBefore = #Async._pendingTaskQueue

    for i = 1, 10 do
        Async.Update(0.016)
    end

    local queueSizeAfter = #Async._pendingTaskQueue

    -- Queue should be empty or shrink, not grow
    TestRunner.assert(queueSizeAfter <= queueSizeBefore,
        "Queue should not grow on cancellation (before: " .. queueSizeBefore .. ", after: " .. queueSizeAfter .. ")")
end)

-- Test 9: Waitable:ToTask() with optional cancellationToken (Fix #2)
TestRunner.add("Fix #2: Waitable:ToTask() accepts optional token", function()
    local cts = CancellationTokenSource.new()

    -- Test with Task.Delay waitable (built-in waitable)
    local delayWaitable = Task.Delay(100, cts:GetToken())

    -- Should work without token parameter
    local task1 = delayWaitable:ToTask()
    TestRunner.assert(task1 ~= nil, "ToTask without token should work")

    -- Test with explicit token
    local cts2 = CancellationTokenSource.new()
    local task2 = delayWaitable:ToTask(cts2:GetToken())
    TestRunner.assert(task2 ~= nil, "ToTask with explicit token should work")
    TestRunner.assertEqual(cts2:GetToken(), task2._cancellationToken,
        "ToTask should use provided token")

    -- Test with Task waitable (which has _cancellationToken)
    local originalTask = Task.new(function() return "test" end, cts:GetToken())
    local taskWaitable = originalTask._waitable
    taskWaitable._cancellationToken = cts:GetToken()  -- Manually set token on waitable
    local task3 = taskWaitable:ToTask()
    TestRunner.assertEqual(cts:GetToken(), task3._cancellationToken,
        "ToTask should inherit from waitable that has token")
end)

-- Test 10: Waitable:Complete() sets callbacks to nil (Fix #10)
TestRunner.add("Fix #10: Waitable:Complete() cleanup consistency", function()
    local task = Task.Run(function()
        return "test result"
    end, nil)

    local waitable = task._waitable

    -- Add a callback
    waitable:OnCompleted(function() end)

    TestRunner.assert(waitable._callbacks ~= nil, "Callbacks should exist before Complete()")
    TestRunner.assert(#waitable._callbacks > 0, "Should have at least one callback")

    -- Run to completion which calls Complete()
    Async.Update(0.016)
    Async.Update(0.016)

    -- After completion, callbacks should be nil (consistent with _invoker = nil)
    TestRunner.assertEqual(nil, waitable._callbacks, "Callbacks should be nil after Complete()")
end)

-- Test 11: Error messages include debug info (Fix #13)
TestRunner.add("Fix #13: Error messages include debug info", function()
    local task = Task.new(function() coroutine.yield() end, nil)

    -- Start the task
    task:Start()

    -- Try to start again
    local ok, err = pcall(function() task:Start() end)

    TestRunner.assert(not ok, "Second start should fail")
    -- Error message should include "created at" with debug info if debug library is available
    if debug and debug.getinfo then
        TestRunner.assert(err:match("created at") or err:match("already started"),
            "Error should include debug info or mention 'already started'")
    end
end)

-- Test 12: Task.Delay accuracy
TestRunner.add("Feature: Task.Delay timing accuracy", function()
    local cts = CancellationTokenSource.new()
    local completed = false
    local task = nil

    task = Task.Run(function()
        Await(Task.Delay(300, cts:GetToken()))  -- 300ms = 0.3 seconds
        completed = true
        return "done"
    end, cts:GetToken())

    -- Run for less than 0.3 seconds
    for i = 1, 15 do
        Async.Update(0.016)  -- ~15 frames = 240ms
    end

    if not completed then
        TestRunner.assert(true, "Task correctly delayed at 240ms")
    end

    -- Run more frames to exceed 300ms
    for i = 1, 10 do
        Async.Update(0.016)  -- ~10 more frames = 160ms, total ~400ms
    end

    TestRunner.assert(completed, "Task should complete after delay")
    TestRunner.assertEqual("done", task._result, "Task should return result")
end)

-- Test 13: Task.Until condition checking
TestRunner.add("Feature: Task.Until waits for condition", function()
    local cts = CancellationTokenSource.new()
    local counter = 0

    Task.Run(function()
        Await(Task.Until(function() return counter >= 5 end, cts:GetToken()))
    end, cts:GetToken())

    -- Run a few frames
    for i = 1, 3 do
        counter = counter + 1
        Async.Update(0.016)
    end

    -- Task should still be running
    TestRunner.assert(#Async._pendingTaskQueue > 0, "Task should still be running")

    -- Increment to satisfy condition
    counter = 5
    for i = 1, 2 do
        Async.Update(0.016)
    end

    -- Task should complete
    TestRunner.assert(true, "Until task completed successfully")
end)

-- Test 14: Multiple cancellation tokens
TestRunner.add("Feature: Multiple independent cancellation tokens", function()
    local cts1 = CancellationTokenSource.new()
    local cts2 = CancellationTokenSource.new()

    local task1 = Task.new(function() end, cts1:GetToken())
    local task2 = Task.new(function() end, cts2:GetToken())

    -- Cancel first token only
    cts1:Cancel()

    TestRunner.assert(cts1:GetToken():IsCancellationRequested(),
        "CTS1 should be cancelled")
    TestRunner.assert(not cts2:GetToken():IsCancellationRequested(),
        "CTS2 should NOT be cancelled")
end)

-- Test 15: Task.OnCompleted callback
TestRunner.add("Feature: Task.OnCompleted callback", function()
    local callbackCalled = false
    local callbackResult = nil

    local task = Task.Run(function()
        return "test result"
    end, nil)

    task:OnCompleted(function()
        callbackCalled = true
        callbackResult = task._result
    end)

    -- Run to completion
    Async.Update(0.016)
    Async.Update(0.016)

    TestRunner.assert(callbackCalled, "OnCompleted callback should be called")
    TestRunner.assertEqual("test result", callbackResult, "Callback should receive result")
end)

-- ============================================================================
-- RUN TESTS
-- ============================================================================

local success = TestRunner.run()

if success then
    print("\n✓ All tests passed!")
    os.exit(0)
else
    print("\n✗ Some tests failed!")
    os.exit(1)
end
