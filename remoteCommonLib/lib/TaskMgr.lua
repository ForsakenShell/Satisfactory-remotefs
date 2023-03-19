-- Allows user to run program shared time
-- Examples:
-- * Create processes
-- {{
-- Process:create({name = 'test'}, function ()
--     p = Process:create({name = 'donothing'}, function ()
--         local os = require("os")
--         while true do
--             --do nothing
--             os.sleep(1)
--             print('child alive')
--             coroutine.yield()
--         end
--     end):start()
--     local os = require("os")
--     for i = 1, 3, 1 do
--         os.sleep(1)
--         for _, report in ipairs(TaskMgr:report()) do
--             print('{')
--             for key, value in pairs(report) do
--                 print(key..' = '..value)
--             end
--             print('}')
--         end
--         coroutine.yield()
--     end
--     print('kill child')
--     TaskMgr:killProcess(p)
--     for i = 1, 3, 1 do
--         os.sleep(1)
--         for _, report in ipairs(TaskMgr:report()) do
--             print('{')
--             for key, value in pairs(report) do
--                 print(key..' = '..value)
--             end
--             print('}')
--         end
--         coroutine.yield()
--     end
-- end):start()
-- }}

-- * Start TaskMgr
-- TaskMgr:start() -- must start it outside coroutine

---------------------------------------
-- #region 

Process = {
    -- use current file and lines as name
    name = string.format("%s@%d", debug.getinfo(2, "S").short_src, debug.getinfo(2, "S").lastlinedefined),
    pid = -1,
    parent_pid = -1,
    error_handler = debug.traceback,
    start_time = 0,
    err = nil,
    co = nil
}

function Process:create(o, func, ...)
    local args = {...}
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.co = coroutine.create(function()
        local normal, err_msg = xpcall(func, o.error_handler, args)
        if not normal then
            o.err = err_msg
            print(string.format('Process %s(pid %d): %s', o.name, o.pid, o.err))
        end
    end)
    return o
end

function Process:start()
    self.start_time = computer.millis()
    TaskMgr:startProcess(self)
    return self
end

function Process:getStatus()
    return coroutine.status(self.co)
end

TaskMgr = {
    processes = {}, -- coroutine pool
    pid_counter = 0, -- keep track of new pid
    current_pid = -1
}

-- Start a process
function TaskMgr:startProcess(process)
    process.pid = self.pid_counter

    -- if we are not in a coroutine, the parent will be -1(root)
    -- otherwise, assign current pid to it.
    _, ismain = coroutine.running()
    if ismain then
        process.parent_pid = -1
    else
        process.parent_pid = self.current_pid
    end
    print('create process '..process.pid)
    self.processes[process.pid] = {kill = false, name=process.name, parent = process.parent_pid, instance = process}
    self.pid_counter = self.pid_counter + 1
    return process
end

-- kill parent process and its childs
function TaskMgr:killProcess(process)
    return self:killProcessById(process.pid)
end

function TaskMgr:killProcessById(pid)
    local res = false
    -- "I will find you, and I will kill you and your childs"
    self.processes[pid].kill = true
    
    -- kill its childs
    for child_pid, process in pairs(self.processes) do
        if process.parent > -1 and process.parent == pid then
            process.kill = true -- close coroutine, wait for taskmgr collect it
            res = true
        end
    end
    return res
end

function TaskMgr:findPIDByName(name)
    local res = {}
    for pid, desc in pairs(self.processes) do
        if desc.name == name then
            table.insert(res, pid)
        end
    end
    return res
end

function TaskMgr:report()
    local report = {}
    for pid, desc in pairs(self.processes) do
        table.insert(report, {pid = pid, parent = desc.parent, name = desc.name, status=coroutine.status(desc.instance.co)})
    end
    return report
end

--TODO: fire process killed
function TaskMgr:start()
    while true do
        -- keep the flow running
        for pid, proc_desc in pairs(self.processes) do
            if coroutine.status(proc_desc.instance.co) ~= "dead" and proc_desc.kill == false then
                self.current_pid = pid
                coroutine.resume(true, proc_desc.instance.co)
            else
                self:killProcessById(pid) -- for marking its child processes
                self.processes[pid] = nil -- remove process
            end
        end
        computer.skip()
    end
end
