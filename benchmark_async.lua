-- LuaAsync Performance Benchmark Suite
-- Measures performance characteristics and checks for memory leaks

require("async")

local Benchmark = {}
Benchmark.results = {}

function Benchmark.measure(name, func, iterations)
    -- Warm-up
    for i = 1, math.min(100, iterations) do
        func()
    end

    -- Measure
    collectgarbage("collect")
    local memBefore = collectgarbage("count")
    local start = os.clock()

    for i = 1, iterations do
        func()
    end

    local elapsed = os.clock() - start
    local memAfter = collectgarbage("count")
    local memUsed = memAfter - memBefore

    local opsPerSecond = iterations / elapsed
    local avgTime = (elapsed / iterations) * 1000  -- in ms

    table.insert(Benchmark.results, {
        name = name,
        iterations = iterations,
        elapsed = elapsed,
        opsPerSecond = opsPerSecond,
        avgTimeMs = avgTime,
        memUsedKB = memUsed
    })

    return opsPerSecond, avgTime, memUsed
end

function Benchmark.printResults()
    print("\n" .. string.rep("=", 90))
    print("PERFORMANCE BENCHMARK RESULTS")
    print(string.rep("=", 90))
    print(string.format("%-40s %12s %12s %12s %12s",
        "Benchmark", "Iterations", "Ops/sec", "Avg (ms)", "Memory (KB)"))
    print(string.rep("-", 90))

    for _, result in ipairs(Benchmark.results) do
        print(string.format("%-40s %12d %12.0f %12.4f %12.2f",
            result.name,
            result.iterations,
            result.opsPerSecond,
            result.avgTimeMs,
            result.memUsedKB))
    end

    print(string.rep("=", 90))
end

-- ============================================================================
-- BENCHMARKS
-- ============================================================================

print("Initializing LuaAsync...")
Async.Init()

-- Benchmark 1: Task Creation Overhead
print("\n[1/8] Benchmarking Task creation overhead...")
Benchmark.measure("Task Creation (empty function)", function()
    local task = Task.new(function() end, nil)
    task:Start()
end, 10000)

-- Benchmark 2: Task Scheduling Throughput
print("[2/8] Benchmarking Task scheduling throughput...")
Benchmark.measure("Task.Run (simple yield)", function()
    Task.Run(function()
        coroutine.yield()
    end, nil)
end, 10000)

-- Run the queued tasks
for i = 1, 2000 do
    Async.Update(0.016)
end

-- Benchmark 3: Task.Delay Performance
print("[3/8] Benchmarking Task.Delay performance...")
Async.Init()
local delayCount = 0
local delayWaitables = {}
Benchmark.measure("Task.Delay (100ms)", function()
    table.insert(delayWaitables, Task.Delay(100, nil))
    delayCount = delayCount + 1
    if delayCount % 100 == 0 then
        -- Process some frames to prevent queue overflow
        for j = 1, 10 do
            Async.Update(0.016)
        end
    end
end, 1000)

-- Process remaining tasks
for i = 1, 5000 do
    Async.Update(0.016)
end

-- Benchmark 4: Task.FromResult Performance
print("[4/8] Benchmarking Task.FromResult performance...")
Async.Init()
Benchmark.measure("Task.FromResult", function()
    local task = Task.FromResult("test")
end, 100000)

-- Benchmark 5: WhenAll Performance
print("[5/8] Benchmarking WhenAll performance...")
Async.Init()
Benchmark.measure("Task.WhenAll (10 tasks)", function()
    local tasks = {}
    for i = 1, 10 do
        table.insert(tasks, Task.new(function()
            coroutine.yield()
            return i
        end, nil))
    end

    local waitable = Task.WhenAll(nil, table.unpack(tasks))
    waitable()  -- Start tasks

    for j = 1, 3 do
        Async.Update(0.016)
    end
end, 1000)

-- Benchmark 6: Nested Tasks (Sub-tasks)
print("[6/8] Benchmarking nested task performance...")
Async.Init()
Benchmark.measure("Nested Tasks (3 levels)", function()
    Task.Run(function()
        Task.RunAsSub(function()
            Task.RunAsSub(function()
                coroutine.yield()
            end, nil)
            coroutine.yield()
        end, nil)
        coroutine.yield()
    end, nil)

    for j = 1, 5 do
        Async.Update(0.016)
    end
end, 1000)

-- Benchmark 7: Memory Leak Test - Long Running
print("[7/8] Testing for memory leaks (long-running)...")
Async.Init()
collectgarbage("collect")
local memStart = collectgarbage("count")

local tasks = {}
for i = 1, 1000 do
    local task = Task.Run(function()
        Await(Task.Delay(10, nil))
    end, nil)

    table.insert(tasks, task)

    if i % 100 == 0 then
        -- Process some frames
        for j = 1, 20 do
            Async.Update(0.016)
        end
    end
end

-- Process all remaining tasks
for i = 1, 10000 do
    Async.Update(0.016)
    if #Async._pendingTaskQueue == 0 then
        break
    end
end

collectgarbage("collect")
local memEnd = collectgarbage("count")
local memLeaked = memEnd - memStart

print(string.format("  Memory before: %.2f KB", memStart))
print(string.format("  Memory after:  %.2f KB", memEnd))
print(string.format("  Memory leaked: %.2f KB", memLeaked))

if memLeaked > 100 then
    print("  ⚠️  WARNING: Possible memory leak detected!")
else
    print("  ✓ Memory usage is acceptable")
end

-- Benchmark 8: Cancellation Performance
print("[8/8] Benchmarking cancellation performance...")
Async.Init()
Benchmark.measure("Task Cancellation", function()
    local cts = CancellationTokenSource.new()
    local task = Task.Run(function()
        Await(Task.Delay(1000, cts:GetToken()))
    end, cts:GetToken())

    cts:Cancel()
    Async.Update(0.016)
end, 10000)

-- ============================================================================
-- RESULTS
-- ============================================================================

Benchmark.printResults()

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 90))
print("PERFORMANCE ANALYSIS")
print(string.rep("=", 90))

-- Find key metrics
local creationTime = Benchmark.results[1].avgTimeMs
local schedulingOps = Benchmark.results[2].opsPerSecond
local fromResultOps = Benchmark.results[4].opsPerSecond

print(string.format("\n✓ Task Creation:        %.4f ms per task", creationTime))
print(string.format("✓ Scheduling Throughput: %.0f tasks/second", schedulingOps))
print(string.format("✓ FromResult Speed:      %.0f tasks/second", fromResultOps))

if creationTime < 0.1 then
    print("  ✓ Excellent - Task creation is very fast")
elseif creationTime < 1.0 then
    print("  ✓ Good - Task creation overhead is acceptable")
else
    print("  ⚠️  Warning - Task creation may be slow")
end

if schedulingOps > 10000 then
    print("  ✓ Excellent - High scheduling throughput")
elseif schedulingOps > 1000 then
    print("  ✓ Good - Reasonable scheduling throughput")
else
    print("  ⚠️  Warning - Low scheduling throughput")
end

print("\n" .. string.rep("=", 90))
print("Benchmark complete!")
print(string.rep("=", 90) .. "\n")
