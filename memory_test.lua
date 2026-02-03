-- LuaAsync Memory Leak Test
-- Thorough test for memory leaks

require("async")

print("=" .. string.rep("=", 79))
print("MEMORY LEAK TEST")
print("=" .. string.rep("=", 79))

function testMemoryLeak(testName, taskFunc)
    collectgarbage("collect")
    collectgarbage("collect")

    local memBefore = collectgarbage("count")

    -- Create and complete many tasks
    for i = 1, 1000 do
        Async.Init()
        taskFunc()

        -- Process until all tasks complete
        local frameCount = 0
        for j = 1, 1000 do
            Async.Update(0.016)
            frameCount = frameCount + 1
            if #Async._pendingTaskQueue == 0 then
                break
            end
        end
    end

    -- Force garbage collection
    collectgarbage("collect")
    collectgarbage("collect")

    local memAfter = collectgarbage("count")
    local memLeaked = memAfter - memBefore

    print(string.format("\n%s:", testName))
    print(string.format("  Memory before: %.2f KB", memBefore))
    print(string.format("  Memory after:  %.2f KB (1000 iterations)", memAfter))
    print(string.format("  Memory leaked: %.2f KB", memLeaked))

    if memLeaked < 50 then
        print("  ✓ PASS - No significant memory leak")
        return true
    elseif memLeaked < 200 then
        print("  ⚠️  WARN - Minor memory growth (may be acceptable)")
        return true
    else
        print("  ✗ FAIL - Significant memory leak detected!")
        return false
    end
end

-- Test 1: Simple tasks
local allPass = true
allPass = testMemoryLeak("Test 1: Simple yield tasks", function()
    Task.Run(function()
        coroutine.yield()
    end, nil)
end) and allPass

-- Test 2: Task.Delay
allPass = testMemoryLeak("Test 2: Task.Delay tasks", function()
    Task.Run(function()
        Await(Task.Delay(1, nil))
    end, nil)
end) and allPass

-- Test 3: Nested tasks
allPass = testMemoryLeak("Test 3: Nested tasks", function()
    Task.Run(function()
        Task.RunAsSub(function()
            coroutine.yield()
        end, nil)
        coroutine.yield()
    end, nil)
end) and allPass

-- Test 4: WhenAll
allPass = testMemoryLeak("Test 4: WhenAll tasks", function()
    local tasks = {}
    for i = 1, 5 do
        table.insert(tasks, Task.new(function()
            coroutine.yield()
            return i
        end, nil))
    end

    local waitable = Task.WhenAll(nil, table.unpack(tasks))
    waitable()  -- Start all tasks
end) and allPass

-- Test 5: Task.FromResult
allPass = testMemoryLeak("Test 5: Task.FromResult", function()
    local task = Task.FromResult("test")
    task:OnCompleted(function() end)
end) and allPass

-- Test 6: Cancelled tasks
allPass = testMemoryLeak("Test 6: Cancelled tasks", function()
    local cts = CancellationTokenSource.new()
    Task.Run(function()
        Await(Task.Delay(1000, cts:GetToken()))
    end, cts:GetToken())
    cts:Cancel()
end) and allPass

print("\n" .. string.rep("=", 80))
if allPass then
    print("✓ ALL MEMORY TESTS PASSED - No significant leaks detected")
else
    print("✗ SOME MEMORY TESTS FAILED - Review memory management")
end
print(string.rep("=", 80) .. "\n")
