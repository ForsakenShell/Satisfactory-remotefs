local fifo = require( "/lib/fifo", ____RemoteCommonLib )

-- We dont want user to be able to mess with the events
local old_pull = event.pull
local old_listen = event.listen
local old_clear = event.clear
local old_ignore = event.ignore
local old_ignore_all = event.ignoreAll
-- Every coroutine had its own registry
local EventRegistry = {}

function EventRegistry:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.queue = fifo()
    o.queue:setempty(function()
        return nil
    end)
    o.compo_hooks = {} -- store listening components
    o.event_hooks = {} -- store listening events
    return o
end

EventDispatcher = {
    registries = {},
    event_queue = fifo(),
    consumed = false
}

function EventDispatcher:init()
    self.event_queue:setempty(function()
        return nil
    end)
    old_clear() -- clear out the queue
    -- spawn listener thread
    Process:create({
        name = "event"
    }, self.dispatch):start()

end

function EventDispatcher.dispatch()
    while true do
        EventDispatcher:_dispatchFINEvent({old_pull(0)})
        EventDispatcher:_dispatchTriggerEvent()
    end
end

function EventDispatcher:_dispatchFINEvent(e)
    if e[1] == nil then
        return
    end
    for co, entry in pairs(self.registries) do
        for hash, hook in pairs(entry.compo_hooks) do
            if e[2].hash == hash then
                entry.queue:push(e)
            end
        end
    end
    -- System Wide event
    if e[1] == "FileSystemUpdate" then
        for co, entry in pairs(self.registries) do
            entry.queue:push(e)
        end
    end
    self.event_queue:push(e) -- collect all events
end

function EventDispatcher:_dispatchTriggerEvent()
    -- dispatch events from event_queue
    for i = 1, #self.event_queue do
        self.consumed = false
        local arr = self.event_queue:pop()
        local e = arr[1]
        for co, entry in pairs(self.registries) do
            -- if hook found
            if entry.event_hooks[e] then
                for _, cb in ipairs(entry.event_hooks[e]) do
                    -- callback safely
                    local normal, err_msg = xpcall(cb, debug.traceback, table.unpack(arr, 2))
                    if not normal then
                        print(string.format('Error occur when dispatching event %s: %s', e, err_msg))
                    end
                    if self.consumed == true then
                        break
                    end
                end
            end
            if self.consumed == true then
                break
            end
        end
    end
end

function EventDispatcher:addEventEntry(co)
    self.registries[co] = EventRegistry:new()
end

----------------------------------------------
--          High Level Event APIs
----------------------------------------------
function EventDispatcher:fireEvent(e, ...)
    self.event_queue:push({e, ...})
    if coroutine.isyieldable() then
        coroutine.yield()
    end
end

function EventDispatcher:addEventListener(e, cb)
    local curr_co = coroutine.running()
    -- if no hook found, create one
    if not self.registries[curr_co] then
        self:addEventEntry(curr_co)
    end
    if not self.registries[curr_co].event_hooks[e] then
        self.registries[curr_co].event_hooks[e] = {}
    end
    -- place
    table.insert(self.registries[curr_co].event_hooks[e], cb)
end

function EventDispatcher:removeEventListener(e)
    local curr_co = coroutine.running()
    -- clear callbacks, create if not exist
    self.registries[curr_co].event_hooks[e] = {}
end

function EventDispatcher:consumeEvent()
    self.consumed = true
    coroutine.yield()
end

----------------------------------------------
--          Override Event APIs
--        Only call it in process
----------------------------------------------
function event.listen(comp)
    -- get caller coroutine
    local curr_co = coroutine.running()
    -- if no entry in registy
    if not EventDispatcher.registries[curr_co] then
        -- create one
        EventDispatcher:addEventEntry(curr_co)
    end
    -- you only listen once
    if not EventDispatcher.registries[curr_co].compo_hooks[comp.hash] then
        old_listen(comp)
        EventDispatcher.registries[curr_co].compo_hooks[comp.hash] = comp
    end
end

function event.pull(timeout)
    -- get caller coroutine
    local curr_co = coroutine.running()
    if not EventDispatcher.registries[curr_co] then
        -- create one
        EventDispatcher:addEventEntry(curr_co)
    end
    local queue = EventDispatcher.registries[curr_co].queue
    -- if not set, it will block until signal get pushed
    if not timeout then
        while #queue == 0 do
            coroutine.yield()
        end
    elseif timeout > 0 then -- wait for signals
        timeout = timeout * 1000
        local t0 = computer.millis()
        while computer.millis() - t0 < timeout do
            coroutine.yield()
        end
    end
    local item = queue:pop()
    if not item then
        return nil
    end
    return table.unpack(item) -- event, component, ...
end

function event.ignore(comp)
    -- if registry exist
    local curr_co = coroutine.running()
    local registry = EventDispatcher.registries[curr_co]
    if not registry then
        return
    end
    -- remove hook
    registry.compo_hooks[comp.hash] = nil
    -- remove related events
    for i = 1, #registry.queue do
        local e = registry.queue:peek(i)
        if e[2] == comp.hash then
            registry.queue.remove(i)
        end
    end
end

function event.clear()
    local curr_co = coroutine.running()
    if not EventDispatcher.registries[curr_co] then
        return
    end
    EventDispatcher.registries[curr_co].queue = fifo()
    EventDispatcher.registries[curr_co].queue:setempty(function()
        return nil
    end)
end

function event.ignoreAll()
    local curr_co = coroutine.running()
    if not EventDispatcher.registries[curr_co] then
        return
    end
    EventDispatcher.registries[curr_co] = EventRegistry:new()
end
