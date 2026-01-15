--[[
    lua.rip v2.0 - Distributed Anti-Tamper System
    Continuous checking network with subtle failure modes
]]

local Engine = require("src.polymorphic.engine")
local SHA256 = require("src.lib.sha256")
local Config = require("config")

local AntiTamper = {}

local STATE = {
    checkpoints = {},
    fail_counter = 0,
    fail_threshold = Engine.randomRange(3, 7),
    corruption_level = 0,
    delayed_fail_ops = 0,
    function_refs = {},
    timing_baseline = nil,
}

function AntiTamper.generateStateVariables()
    return {
        state_table = Engine.generateName("mixed", 35),
        checkpoints = Engine.generateName("mixed", 30),
        fail_counter = Engine.generateName("mixed", 30),
        corruption = Engine.generateName("mixed", 30),
        delayed_ops = Engine.generateName("mixed", 30),
        func_refs = Engine.generateName("mixed", 30),
        timing = Engine.generateName("mixed", 25),
    }
end

function AntiTamper.generateIntegrityCheck(vars)
    local check_func = Engine.generateName("mixed", 40)
    local hash_func = Engine.generateName("mixed", 35)
    
    return string.format([[
local function %s(s)
    local h = 5381
    for i = 1, #s do
        h = ((h * 33) + s:byte(i)) %% 4294967296
    end
    return h
end

local function %s(fn)
    if type(fn) ~= "function" then return false end
    local ok, info = pcall(function() return debug and debug.getinfo and debug.getinfo(fn, "S") end)
    if not ok or not info then return true end
    if info.what == "C" then return true end
    return info.linedefined ~= nil
end
]], hash_func, check_func), check_func, hash_func
end

function AntiTamper.generateEnvironmentCheck(vars)
    local check_func = Engine.generateName("mixed", 40)
    
    return string.format([[
local function %s()
    local checks = 0
    if type(_G) == "table" then checks = checks + 1 end
    if type(type) == "function" then checks = checks + 1 end
    if type(pairs) == "function" then checks = checks + 1 end
    if type(ipairs) == "function" then checks = checks + 1 end
    if type(pcall) == "function" then checks = checks + 1 end
    if type(tostring) == "function" then checks = checks + 1 end
    if _VERSION ~= nil then checks = checks + 1 end
    return checks >= 6
end
]], check_func), check_func
end

function AntiTamper.generateTimingCheck(vars)
    local check_func = Engine.generateName("mixed", 40)
    local threshold = Engine.randomRange(100, 500)
    
    return string.format([[
local function %s()
    local start = os.clock()
    local sum = 0
    for i = 1, 5000 do sum = sum + i end
    local elapsed = (os.clock() - start) * 1000
    return elapsed < %d
end
]], check_func, threshold), check_func
end

function AntiTamper.generateFunctionHookCheck(vars)
    local check_func = Engine.generateName("mixed", 40)
    
    return string.format([[
local function %s()
    local originals = %s.%s
    if not originals then return true end
    
    local current = {
        pcall = pcall,
        type = type,
        pairs = pairs,
        tostring = tostring
    }
    
    for name, orig in pairs(originals) do
        if current[name] ~= orig then
            return false
        end
    end
    return true
end
]], check_func, vars.state_table, vars.func_refs), check_func
end

function AntiTamper.generateCheckpointValidator(vars)
    local check_func = Engine.generateName("mixed", 40)
    
    return string.format([[
local function %s(expected_checkpoint)
    local cp = %s.%s
    if not cp[expected_checkpoint - 1] and expected_checkpoint > 1 then
        return false
    end
    cp[expected_checkpoint] = true
    return true
end
]], check_func, vars.state_table, vars.checkpoints), check_func
end

function AntiTamper.generateSubtleFailure(vars)
    local fail_func = Engine.generateName("mixed", 40)
    
    return string.format([[
local function %s(severity)
    severity = severity or 1
    local state = %s
    state.%s = state.%s + severity
    
    if state.%s >= state.%s then
        state.%s = state.%s + 1
        
        if state.%s == 1 then
            state.%s = %d
        elseif state.%s == 2 then
            math.randomseed(os.time() + state.%s)
        elseif state.%s >= 3 then
            state.%s = %d
        end
    end
end
]], fail_func, vars.state_table, 
    vars.fail_counter, vars.fail_counter,
    vars.fail_counter, "threshold",
    vars.corruption, vars.corruption,
    vars.corruption, vars.delayed_ops, Engine.randomRange(100, 500),
    vars.corruption, vars.fail_counter,
    vars.corruption, vars.delayed_ops, Engine.randomRange(10, 50)), fail_func
end

function AntiTamper.generateCorruptionApplier(vars)
    local apply_func = Engine.generateName("mixed", 40)
    
    return string.format([[
local function %s(value)
    local state = %s
    if state.%s > 0 then
        state.%s = state.%s - 1
        
        if state.%s == 0 and state.%s >= 3 then
            return nil
        end
        
        if type(value) == "number" then
            if state.%s >= 2 then
                return value + (math.random() * 0.001 - 0.0005)
            end
        elseif type(value) == "string" and #value > 0 then
            if state.%s >= 3 then
                local pos = math.random(1, #value)
                return value:sub(1, pos-1) .. string.char((value:byte(pos) + 1) %% 256) .. value:sub(pos+1)
            end
        end
    end
    return value
end
]], apply_func, vars.state_table,
    vars.delayed_ops, vars.delayed_ops, vars.delayed_ops,
    vars.delayed_ops, vars.corruption,
    vars.corruption,
    vars.corruption), apply_func
end

function AntiTamper.generateDistributedCheck(vars, check_funcs, fail_func)
    local distributed_check = Engine.generateName("mixed", 40)
    
    local check_calls = {}
    for i, func in ipairs(check_funcs) do
        check_calls[i] = string.format("if not %s() then %s(1) end", func, fail_func)
    end
    
    return string.format([[
local function %s()
    %s
end
]], distributed_check, table.concat(check_calls, "\n    ")), distributed_check
end

function AntiTamper.generateInlineCheck(check_funcs, fail_func)
    local selected = check_funcs[Engine.randomRange(1, #check_funcs)]
    return string.format("if not %s() then %s(%d) end", selected, fail_func, Engine.randomRange(1, 2))
end

function AntiTamper.generate()
    local vars = AntiTamper.generateStateVariables()
    
    local parts = {}
    local check_funcs = {}
    
    parts[#parts + 1] = string.format([[
local %s = {
    %s = {},
    %s = 0,
    threshold = %d,
    %s = 0,
    %s = 0,
    %s = {
        pcall = pcall,
        type = type,
        pairs = pairs,
        tostring = tostring,
        ipairs = ipairs,
        next = next
    }
}
]], vars.state_table, vars.checkpoints, vars.fail_counter, 
    Engine.randomRange(3, 7), vars.corruption, vars.delayed_ops, vars.func_refs)
    
    local integrity_code, integrity_check, hash_func = AntiTamper.generateIntegrityCheck(vars)
    parts[#parts + 1] = integrity_code
    check_funcs[#check_funcs + 1] = integrity_check
    
    local env_code, env_check = AntiTamper.generateEnvironmentCheck(vars)
    parts[#parts + 1] = env_code
    check_funcs[#check_funcs + 1] = env_check
    
    if Config.get("AntiDebug.TimingChecks") then
        local timing_code, timing_check = AntiTamper.generateTimingCheck(vars)
        parts[#parts + 1] = timing_code
        check_funcs[#check_funcs + 1] = timing_check
    end
    
    local hook_code, hook_check = AntiTamper.generateFunctionHookCheck(vars)
    parts[#parts + 1] = hook_code
    check_funcs[#check_funcs + 1] = hook_check
    
    local checkpoint_code, checkpoint_check = AntiTamper.generateCheckpointValidator(vars)
    parts[#parts + 1] = checkpoint_code
    
    local fail_code, fail_func = AntiTamper.generateSubtleFailure(vars)
    parts[#parts + 1] = fail_code
    
    local apply_code, apply_func = AntiTamper.generateCorruptionApplier(vars)
    parts[#parts + 1] = apply_code
    
    local dist_code, dist_check = AntiTamper.generateDistributedCheck(vars, check_funcs, fail_func)
    parts[#parts + 1] = dist_code
    
    parts[#parts + 1] = string.format("%s()", dist_check)
    
    return table.concat(parts, "\n"), {
        vars = vars,
        check_funcs = check_funcs,
        fail_func = fail_func,
        apply_func = apply_func,
        dist_check = dist_check,
        checkpoint_check = checkpoint_check,
    }
end

function AntiTamper.insertDistributedChecks(code, context)
    if not context or not context.check_funcs or #context.check_funcs == 0 then
        return code
    end
    
    local lines = {}
    local in_block = 0
    local brace_depth = 0
    local line_number = 0
    local check_interval = Engine.randomRange(15, 25)
    local checkpoint_num = 1
    
    for line in code:gmatch("[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        
        if trimmed:match("^function%s") or trimmed:match("^local%s+function%s") or
           trimmed:match("^if%s") or trimmed:match("^for%s") or 
           trimmed:match("^while%s") or trimmed:match("^repeat%s") or
           trimmed:match("^do$") or trimmed:match("=%s*function") then
            in_block = in_block + 1
        end
        
        if trimmed:match("^end$") or trimmed:match("^end[%s,)]") or
           trimmed:match("^until%s") then
            in_block = math.max(0, in_block - 1)
        end
        
        -- Track braces for table constructors
        local _, open_braces = trimmed:gsub("{", "")
        local _, close_braces = trimmed:gsub("}", "")
        brace_depth = brace_depth + open_braces - close_braces
        
        lines[#lines + 1] = line
        line_number = line_number + 1
        
        local is_safe = in_block == 0 and brace_depth == 0 and
                       not trimmed:match("^%-%-") and
                       not trimmed:match("^else") and
                       not trimmed:match("^elseif") and
                       #trimmed > 0
        
        if is_safe and line_number % check_interval == 0 then
            local inline_check = AntiTamper.generateInlineCheck(context.check_funcs, context.fail_func)
            lines[#lines + 1] = inline_check
            
            if line_number % (check_interval * 3) == 0 then
                lines[#lines + 1] = string.format("%s(%d)", context.checkpoint_check, checkpoint_num)
                checkpoint_num = checkpoint_num + 1
            end
        end
    end
    
    return table.concat(lines, "\n")
end

function AntiTamper.process(code)
    if not Config.isEnabled("AntiTamper") then
        return code
    end
    
    local anti_tamper_code, context = AntiTamper.generate()
    
    code = AntiTamper.insertDistributedChecks(code, context)
    
    return anti_tamper_code .. "\n" .. code
end

return AntiTamper
