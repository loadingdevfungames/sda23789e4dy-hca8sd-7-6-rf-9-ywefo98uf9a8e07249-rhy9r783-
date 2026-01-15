--[[
    lua.rip - Anti-Debugging System
    Detection and subtle response mechanisms
]]

local Engine = require("src.polymorphic.engine")
local Config = require("config")

local AntiDebug = {}

function AntiDebug.generateEnvironmentCheck()
    local vars = {
        debug_var = Engine.generateName("mixed", 25),
        type_var = Engine.generateName("mixed", 25),
        pcall_var = Engine.generateName("mixed", 25),
        result_var = Engine.generateName("mixed", 20),
    }
    
    local code = string.format([[
local %s = debug
local %s = type
local %s = pcall
local function %s()
    if %s(%s) ~= "table" then return false end
    if %s(%s.getinfo) ~= "function" then return false end
    if %s(%s.traceback) ~= "function" then return false end
    
    local info = %s.getinfo(1)
    if info and info.what ~= "Lua" and info.what ~= "main" then
        return false
    end
    
    return true
end
]], vars.debug_var, vars.type_var, vars.pcall_var, vars.result_var,
    vars.type_var, vars.debug_var,
    vars.type_var, vars.debug_var,
    vars.type_var, vars.debug_var,
    vars.debug_var)
    
    return code, vars.result_var
end

function AntiDebug.generateTimingCheck()
    local start_var = Engine.generateName("mixed", 25)
    local end_var = Engine.generateName("mixed", 25)
    local result_var = Engine.generateName("mixed", 25)
    local threshold = Engine.randomRange(50, 200)
    
    local code = string.format([[
local function %s()
    local %s = os.clock()
    local sum = 0
    for i = 1, 10000 do sum = sum + i end
    local %s = os.clock()
    
    if (%s - %s) * 1000 > %d then
        return false
    end
    return true
end
]], result_var, start_var, end_var, end_var, start_var, threshold)
    
    return code, result_var
end

function AntiDebug.generateSubtleFailure()
    local failure_var = Engine.generateName("mixed", 30)
    local counter_var = Engine.generateName("mixed", 25)
    
    local code = string.format([[
local %s = 0
local %s = function(v)
    %s = %s + 1
    if %s > 10 then
        if type(v) == "number" then
            return v + (math.random() * 0.0001)
        elseif type(v) == "string" then
            return v:sub(1, #v - 1) .. string.char(v:byte(#v) + 1)
        end
    end
    return v
end
]], counter_var, failure_var, counter_var, counter_var, counter_var)
    
    return code, failure_var
end

function AntiDebug.generateIntegrityCheck()
    local check_func = Engine.generateName("mixed", 35)
    local hash_table = Engine.generateName("mixed", 30)
    
    local code = string.format([[
local %s = {}
local function %s(name, func)
    if type(func) ~= "function" then return false end
    
    local info = debug and debug.getinfo and debug.getinfo(func)
    if info then
        local key = name .. tostring(info.linedefined or 0)
        if %s[key] and %s[key] ~= info.linedefined then
            return false
        end
        %s[key] = info.linedefined
    end
    
    return true
end
]], hash_table, check_func, hash_table, hash_table, hash_table)
    
    return code, check_func
end

function AntiDebug.generateGlobalCheck()
    local check_func = Engine.generateName("mixed", 35)
    
    local code = string.format([[
local function %s()
    local essentials = {"pcall", "xpcall", "type", "tostring", "pairs", "ipairs", "next"}
    for _, name in pairs(essentials) do
        if _G[name] == nil then return false end
    end
    
    if type(pcall) ~= "function" then return false end
    if type(type) ~= "function" then return false end
    
    return true
end
]], check_func)
    
    return code, check_func
end

function AntiDebug.generate()
    local parts = {}
    local checks = {}
    
    local env_code, env_check = AntiDebug.generateEnvironmentCheck()
    parts[#parts + 1] = env_code
    
    local global_code, global_check = AntiDebug.generateGlobalCheck()
    parts[#parts + 1] = global_code
    checks[#checks + 1] = global_check .. "()"
    
    if Config.get("AntiDebug.TimingChecks") then
        local timing_code, timing_check = AntiDebug.generateTimingCheck()
        parts[#parts + 1] = timing_code
        checks[#checks + 1] = timing_check .. "()"
    end
    
    local integrity_code, integrity_check = AntiDebug.generateIntegrityCheck()
    parts[#parts + 1] = integrity_code
    
    if Config.get("AntiDebug.SubtleFailure") then
        local failure_code, failure_func = AntiDebug.generateSubtleFailure()
        parts[#parts + 1] = failure_code
    end
    
    local runner_func = Engine.generateName("mixed", 35)
    local check_condition = table.concat(checks, " and ")
    if check_condition == "" then check_condition = "true" end
    
    parts[#parts + 1] = string.format([[
local function %s()
    if not (%s) then
        while true do end
    end
end
%s()
]], runner_func, check_condition, runner_func)
    
    return table.concat(parts, "\n")
end

function AntiDebug.process(code)
    if not Config.isEnabled("AntiDebug") then
        return code
    end
    
    local anti_debug_code = AntiDebug.generate()
    return anti_debug_code .. "\n" .. code
end

return AntiDebug
