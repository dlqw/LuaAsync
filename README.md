# LuaAsync

## Qucik Start

```lua
require("async")

Async.Init()

function Tick(deltaTime)
    Async.Update(deltaTime)
end
```

## Example

```lua
local cts = CancellationTokenSource.new()
local cts2 = CancellationTokenSource.new()

local task1 = Task.new(function()
    print("Task 1 started")
    Await(Task.Delay(1000, cts:GetToken()))
    print("Task 1 finished")
    return "hello"
end, cts:GetToken())

local task2 = Task.new(function()
    print("Task 2 started")
    Await(Task.NextFrame(cts:GetToken()))
    print("Task 2 finished")
    return "world"
end, cts:GetToken())

Task.Run(function()
    local res1, res2 = table.unpack(Await(Task.WhenAll(cts:GetToken(), task1, task2)))
    print("All tasks finished ", res1, res2)
end, cts:GetToken())

local task3 = Task.new(function()
    print("Task 3 started")
    Task.Delay(2000, cts:GetToken()):Forget()
    print("Task 3 finished")
end, cts:GetToken())

task3:Start()

Player = {health = 100}

Task.Run(function()
    local index = Await(Task.WhenAny(cts2:GetToken(), Task.Delay(500, cts2:GetToken()):ToTask(),
        Task.Until(function() return Player.health <= 0 end, cts2:GetToken()):ToTask()))
    if (index == 2) then cts:Cancel() end
end, cts2:GetToken())
```
## license
