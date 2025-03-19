-- _                     _
-- | |    __ _ _   _     / \   ___ _   _ _ __   ___
-- | |   / _` | | | |   / _ \ / __| | | | '_ \ / __|
-- | |__| (_| | |_| |  / ___ \\__ \ |_| | | | | (__
-- |_____\__,_|\__,_| /_/   \_\___/\__, |_| |_|\___|
--                                 |___/
-- Author: rdququ
-- Github: https://github.com/dlqw/LuaAsync
-- Date: 2025-03-19
-- License: MIT
Async = {}

function Async.Init()
    Async._taskQueue = {}
    Async._pendingTaskQueue = {}
    Async._currentTaskGroup = nil
end

---@param deltaTime number
function Async.Update(deltaTime)
    Async._taskQueue = {}
    table.move(Async._pendingTaskQueue, 1, #Async._pendingTaskQueue, 1, Async._taskQueue)
    Async._pendingTaskQueue = {}
    for _, taskGroup in ipairs(Async._taskQueue) do
        Async._currentTaskGroup = { _cancellationToken = taskGroup._cancellationToken }
        local hasSuspended = taskGroup._cancellationToken and taskGroup._cancellationToken:IsCancellationRequested()
        for i = 1, #taskGroup, 1 do
            local value = taskGroup[i]
            if hasSuspended then
                table.insert(Async._currentTaskGroup, value)
            else
                if taskGroup._cancellationToken and taskGroup._cancellationToken:IsCancellationRequested() then
                    hasSuspended = true
                    table.insert(Async._currentTaskGroup, value)
                else
                    local isDone, isSuspended = value:_moveNext(deltaTime)
                    if not isDone then
                        hasSuspended = isSuspended
                        table.insert(Async._currentTaskGroup, value)
                    else
                        value:Complete()
                    end
                end
            end
        end

        if next(Async._currentTaskGroup) then
            table.insert(Async._pendingTaskQueue, Async._currentTaskGroup)
        end
    end
end

---Waitable
local Waitable = {}
Waitable.__call = function(self)
    if self._invoker == nil then
        error("Waitable is already completed")
        return self
    end
    for index, value in ipairs(self._invoker) do
        value()
    end
    self._invoker = {}
    return self
end
Waitable.__index = Waitable
Waitable._invoker = {}
Waitable._callbacks = {}

---Task
Task = {}
Task.__index = Task

---创建一个Task对象
---@param func function
---@param cancellationToken table
---@return table
function Task.new(func, cancellationToken)
    local task = setmetatable({
        _coroutine = coroutine.create(func),
        _cancellationToken = cancellationToken,
        _waitable = setmetatable({ _invoker = { Task._coroutine }, _callbacks = {} }, Waitable),
        _result = nil
    }, Task);
    task._result = task._waitable._result -- 成员而非继承
    return task
end

---@return boolean isDone
---@return boolean isSuspended
function Task:_moveNext(deltaTime)
    if self._cancellationToken ~= nil then
        if self._cancellationToken:IsCancellationRequested() then
            return true, false
        end
    end

    local success, result = coroutine.resume(self._coroutine, deltaTime)

    self._result = result

    if not success then
        error(result)
        return true, false
    end

    return coroutine.status(self._coroutine) == "dead", coroutine.status(self._coroutine) == "suspended"
end

function Task:setWaitable(waitable)
    self._waitable = waitable
end

function Task:OnCompleted(callback)
    self._waitable:OnCompleted(callback)
    return self
end

Task.__call = function(self)
    return self:StartAsSub()
end

function Waitable:OnCompleted(callback)
    table.insert(self._callbacks, callback)
    return self
end

function Waitable:Complete()
    for index, value in ipairs(self._callbacks) do
        value()
    end
    self._callbacks = {}
    return self
end

function Task:Complete()
    self._waitable:Complete()
    return self
end

function Waitable:ToTask()
    return Task.new(function()
        Await(self)
    end, self._cancellationToken)
end

---Core

---将传入工作加入队列, 并返回一个Task对象
---@param func function
---@param cancellationToken table
---@return table task
function Task.Run(func, cancellationToken)
    local task = Task.new(func, cancellationToken)
    local newTaskGroup = { task }
    newTaskGroup._cancellationToken = cancellationToken
    table.insert(Async._pendingTaskQueue, newTaskGroup)
    return task
end

---@return table task
function Task:Start()
    if self._hasUsed then
        error("Task " .. tostring(self) .. " is already completed")
        return self
    end
    self._hasUsed = true
    local newTaskGroup = { self }
    newTaskGroup._cancellationToken = self._cancellationToken
    table.insert(Async._pendingTaskQueue, newTaskGroup)
    return self
end

---@return table task
function Task.RunAsSub(func, cancellationToken)
    local task = Task.new(func, cancellationToken)
    local targetTaskGroup = Async._currentTaskGroup

    if (targetTaskGroup == nil) then
        targetTaskGroup = Async._pendingTaskQueue[#Async._pendingTaskQueue]
        if (targetTaskGroup == nil) then
            error("RunAsSub must be called in a Task")
            return task
        end
    end
    table.insert(targetTaskGroup, task)
    return task
end

---@return table task
function Task:StartAsSub()
    if self._hasUsed then
        error("Task " .. tostring(self) .. " is already completed")
        return self
    end
    self._hasUsed = true
    local targetTaskGroup = Async._currentTaskGroup
    if (targetTaskGroup == nil) then
        targetTaskGroup = Async._pendingTaskQueue[#Async._pendingTaskQueue]
        if (targetTaskGroup == nil) then
            error("StartAsSub must be called in a Task")
            return self
        end
    end
    table.insert(targetTaskGroup, self)
    return self
end

---@return any result
function Await(waitable)
    waitable()
    coroutine.yield()
    return waitable._result
end

function Waitable:Forget()
    self()
end

function Task:Forget()
    self()
end

---@return table waitable
function Task.NextFrame(cancellationToken)
    local waitable = setmetatable({}, Waitable)
    waitable._invoker = { function()
        Task.RunAsSub(function()
            coroutine.yield()
        end, cancellationToken):setWaitable(waitable)
    end }
    return waitable
end

---@return table waitable
function Task.Delay(milliseconds, cancellationToken)
    local waitable = setmetatable({
        _timer = 0,
        _duration = milliseconds / 1000
    }, Waitable)
    waitable._invoker = { function()
        Task.RunAsSub(function()
            while waitable._timer < waitable._duration do
                waitable._timer = waitable._timer + coroutine.yield()
            end
        end, cancellationToken):setWaitable(waitable)
    end }
    return waitable
end

---@param condition function
---@return table waitable
function Task.Until(condition, cancellationToken)
    local waitable = setmetatable({}, Waitable)
    waitable._invoker = { function()
        Task.RunAsSub(function()
            while not condition() do
                coroutine.yield()
            end
        end, cancellationToken):setWaitable(waitable)
    end }
    return waitable
end

---waitable返回的结果为存储所有任务结果的表, 可以使用 table.unpack 解包
---@param ... table @Task
---@return table waitable
function Task.WhenAll(cancellationToken, ...)
    local tasks = { ... }
    local waitable = setmetatable({
        _completedCount = #tasks,
        _callbacks = {},
        _invoker = {},
        _result = {}
    }, Waitable)

    waitable._invoker = { function()
        for index, task in ipairs(tasks) do
            task._waitable:OnCompleted(function()
                waitable._completedCount = waitable._completedCount - 1
                waitable._result[index] = task._result
            end)
            task:Start()
        end

        Task.RunAsSub(function()
            while waitable._completedCount > 0 do
                coroutine.yield()
            end
            return waitable._result
        end, cancellationToken):setWaitable(waitable)
    end }

    return waitable
end

---waitable返回的结果为第一个完成的任务的索引
---@param ... table @Task
---@return table waitable
function Task.WhenAny(cancellationToken, ...)
    local tasks = { ... }
    local waitable = setmetatable({
        _first = nil,
        _callbacks = {},
        _invoker = {},
        _result = nil
    }, Waitable)

    waitable._invoker = { function()
        for index, task in ipairs(tasks) do
            task._waitable:OnCompleted(function()
                if waitable._first == nil then
                    waitable._first = index
                end
            end)
            task:Start()
        end

        Task.RunAsSub(function()
            while not waitable._first do
                coroutine.yield()
            end
            waitable._result = waitable._first
        end, cancellationToken):setWaitable(waitable)
    end }

    return waitable
end

---CancellationToken
local CancellationToken = {}
CancellationToken.__index = CancellationToken

function CancellationToken.new()
    return setmetatable({
        _isCancellationRequested = false
    }, CancellationToken)
end

function CancellationToken:Cancel()
    self._isCancellationRequested = true
end

function CancellationToken:IsCancellationRequested()
    return self._isCancellationRequested
end

---CancellationTokenSource
CancellationTokenSource = {}
CancellationTokenSource.__index = CancellationTokenSource

function CancellationTokenSource.new()
    return setmetatable({
        _token = CancellationToken.new()
    }, CancellationTokenSource)
end

function CancellationTokenSource:Cancel()
    self._token:Cancel()
end

function CancellationTokenSource:GetToken()
    return self._token
end
