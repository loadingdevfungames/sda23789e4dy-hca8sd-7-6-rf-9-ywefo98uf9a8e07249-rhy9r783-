--[[
    lua.rip v2.0 - Advanced Junk Code System
    Research-backed junk code that survives static analysis
]]

local Engine = require("src.polymorphic.engine")
local Expressions = require("src.polymorphic.expressions")
local Config = require("config")

local Junk = {}

local real_vars_cache = {}

function Junk.cacheRealVariables(code)
    real_vars_cache = {}
    for var in code:gmatch("local%s+([%w_]+)%s*=") do
        if #var > 2 then
            real_vars_cache[#real_vars_cache + 1] = var
        end
    end
    for var in code:gmatch("function%s+[%w_%.]*%(([^%)]+)%)") do
        for param in var:gmatch("([%w_]+)") do
            if #param > 1 then
                real_vars_cache[#real_vars_cache + 1] = param
            end
        end
    end
end

local function getRandomRealVar()
    if #real_vars_cache > 0 then
        return real_vars_cache[Engine.randomRange(1, #real_vars_cache)]
    end
    return nil
end

function Junk.generateNOPEquivalent()
    local generators = {
        function()
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 1000)
            return string.format("local %s = %d; %s = %s + 0", var, n, var, var)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 1000)
            return string.format("local %s = %d; %s = %s * 1", var, n, var, var)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 100)
            local offset = Engine.randomRange(1, 50)
            return string.format("local %s = %d; %s = ((%s + %d) * 2) / 2 - %d", var, n, var, var, offset, offset)
        end,
        function()
            local var1 = Engine.generateName("mixed", 25)
            local var2 = Engine.generateName("mixed", 20)
            local n = Engine.randomRange(1, 1000)
            return string.format("local %s = %d; local %s = %s; %s = %s", var1, n, var2, var1, var1, var2)
        end,
        function()
            local a = Engine.generateName("mixed", 20)
            local b = Engine.generateName("mixed", 20)
            local c = Engine.generateName("mixed", 20)
            local n1, n2, n3 = Engine.randomRange(1, 100), Engine.randomRange(1, 100), Engine.randomRange(1, 100)
            return string.format("local %s, %s, %s = %d, %d, %d; %s, %s, %s = %s, %s, %s; %s, %s, %s = %s, %s, %s",
                a, b, c, n1, n2, n3, a, b, c, b, c, a, a, b, c, c, a, b)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            local tbl = Engine.generateName("mixed", 20)
            local n = Engine.randomRange(1, 1000)
            return string.format("local %s = %d; local %s = {%s}; %s = %s[1]", var, n, tbl, var, var, tbl)
        end,
        function()
            local func = Engine.generateName("mixed", 30)
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 1000)
            return string.format("local function %s(v) return v end; local %s = %s(%d)", func, var, func, n)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 100)
            local factor = Engine.randomChoice({3, 5, 7, 9, 11})
            return string.format("local %s = %d; %s = ((%s * %d) / %d)", var, n, var, var, factor, factor)
        end,
    }
    
    return generators[Engine.randomRange(1, #generators)]()
end

function Junk.generateOpaquePredicate(always_true)
    local true_generators = {
        function()
            local x = Engine.randomRange(1, 1000)
            return string.format("((%d * %d) >= 0)", x, x)
        end,
        function()
            local n = Engine.randomRange(1, 100)
            return string.format("((%d * (%d + 1)) %% 2 == 0)", n, n)
        end,
        function()
            return "(type(_G) == 'table')"
        end,
        function()
            return "(type(type) == 'function')"
        end,
        function()
            local x = Engine.randomRange(1, 1000)
            return string.format("(math.abs(%d) == %d)", x, x)
        end,
        function()
            local x = Engine.randomRange(1, 100)
            return string.format("(math.floor(%d.9) == %d)", x, x)
        end,
        function()
            local x = Engine.randomRange(2, 100)
            return string.format("((%d %% 2 == 0) or (%d %% 2 == 1))", x, x)
        end,
        function()
            return "(_VERSION ~= nil)"
        end,
        function()
            local a = Engine.randomRange(1, 50)
            local b = Engine.randomRange(1, 50)
            return string.format("((%d + %d) == (%d + %d))", a, b, b, a)
        end,
        function()
            local x = Engine.randomRange(2, 20)
            return string.format("(((%d * %d) - %d) == (%d * (%d - 1)))", x, x, x, x, x)
        end,
    }
    
    local false_generators = {
        function()
            local x = Engine.randomRange(1, 1000)
            return string.format("((%d * %d) < 0)", x, x)
        end,
        function()
            return "(type(_G) == 'string')"
        end,
        function()
            return "(type(nil) == 'table')"
        end,
        function()
            local x = Engine.randomRange(1, 1000)
            return string.format("(%d > %d)", x, x)
        end,
        function()
            return "(_VERSION == nil)"
        end,
        function()
            local x = Engine.randomRange(1, 1000)
            return string.format("(math.abs(%d) < 0)", x)
        end,
        function()
            return "(type(1) == 'string')"
        end,
        function()
            local a = Engine.randomRange(1, 100)
            local b = Engine.randomRange(101, 200)
            return string.format("(%d > %d)", a, b)
        end,
    }
    
    if always_true then
        return true_generators[Engine.randomRange(1, #true_generators)]()
    else
        return false_generators[Engine.randomRange(1, #false_generators)]()
    end
end

function Junk.generateInterleaved()
    local real_var = getRandomRealVar()
    
    local generators = {
        function()
            local backup = Engine.generateName("mixed", 25)
            local temp = Engine.generateName("mixed", 20)
            if real_var then
                return string.format([[
local %s = %s
local %s = type(%s)
if %s and %s then
    local _ = tostring(%s)
end
%s = nil
%s = nil]], backup, real_var, temp, real_var, backup, temp, backup, backup, temp)
            else
                local var = Engine.generateName("mixed", 25)
                local n = Engine.randomRange(1, 100)
                return string.format("local %s = %d; if %s then local _ = %s end", var, n, Junk.generateOpaquePredicate(true), var)
            end
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            local n = Engine.randomRange(1, 1000)
            return string.format([[
local %s = %d
if type(%s) == "number" then
    if %s >= 0 and %s <= 10000 then
        local _ = %s
    end
end]], var, n, var, var, var, var)
        end,
        function()
            local result = Engine.generateName("mixed", 25)
            local a = Engine.randomRange(1, 100)
            local b = Engine.randomRange(1, 100)
            return string.format([[
local %s = %d + %d
local _ = %d * %d
local _ = %d - %d
local _ = math.floor(%d / (%d + 1))]], result, a, b, a, b, a, b, a, b)
        end,
        function()
            local success = Engine.generateName("mixed", 25)
            return string.format([[
local %s = true
if %s then
    local _ = 0
else
    error("unreachable")
end]], success, success)
        end,
        function()
            if real_var then
                local check = Engine.generateName("mixed", 25)
                return string.format([[
local %s = %s
if %s ~= nil then
    local _ = type(%s)
end
%s = nil]], check, real_var, check, check, check)
            else
                return Junk.generateNOPEquivalent()
            end
        end,
    }
    
    return generators[Engine.randomRange(1, #generators)]()
end

function Junk.generateFakeFunction()
    local func_name = Engine.generateName("mixed", 35)
    local templates = {
        function()
            local param = Engine.generateName("mixed", 15)
            local var = Engine.generateName("mixed", 20)
            return string.format([[
local function %s(%s)
    local %s = 0
    for i = 1, #%s do
        %s = (%s + string.byte(%s, i)) %% 256
    end
    return %s
end]], func_name, param, var, param, var, var, param, var)
        end,
        function()
            local p1 = Engine.generateName("mixed", 15)
            local p2 = Engine.generateName("mixed", 15)
            return string.format([[
local function %s(%s, %s)
    if type(%s) ~= type(%s) then return false end
    return %s == %s
end]], func_name, p1, p2, p1, p2, p1, p2)
        end,
        function()
            local param = Engine.generateName("mixed", 15)
            local result = Engine.generateName("mixed", 20)
            return string.format([[
local function %s(%s)
    local %s = {}
    for k, v in pairs(%s) do
        %s[k] = v
    end
    return %s
end]], func_name, param, result, param, result, result)
        end,
        function()
            local p1 = Engine.generateName("mixed", 15)
            local p2 = Engine.generateName("mixed", 15)
            local p3 = Engine.generateName("mixed", 15)
            return string.format([[
local function %s(%s, %s, %s)
    %s = %s or 0
    %s = %s or 100
    return math.max(%s, math.min(%s, %s))
end]], func_name, p1, p2, p3, p2, p2, p3, p3, p2, p3, p1)
        end,
    }
    
    return templates[Engine.randomRange(1, #templates)]()
end

function Junk.generateFakeDataStructure()
    local name = Engine.generateName("mixed", 30)
    local templates = {
        function()
            return string.format([[
local %s = {
    version = "%d.%d.%d",
    settings = {
        timeout = %d,
        retries = %d,
        enabled = %s
    },
    constants = {
        MAX_SIZE = %d,
        MIN_SIZE = %d,
        BUFFER = %d
    }
}]], name, 
    Engine.randomRange(1, 5), Engine.randomRange(0, 9), Engine.randomRange(0, 9),
    Engine.randomRange(10, 120), Engine.randomRange(1, 10), Engine.randomChoice({"true", "false"}),
    Engine.randomRange(512, 4096), Engine.randomRange(8, 64), Engine.randomRange(64, 512))
        end,
        function()
            return string.format([[
local %s = {
    [%d] = "%s",
    [%d] = "%s",
    [%d] = "%s",
    [%d] = "%s"
}]], name,
    Engine.randomRange(1, 100), Engine.generateName("random", 8),
    Engine.randomRange(101, 200), Engine.generateName("random", 8),
    Engine.randomRange(201, 300), Engine.generateName("random", 8),
    Engine.randomRange(301, 400), Engine.generateName("random", 8))
        end,
    }
    
    return templates[Engine.randomRange(1, #templates)]()
end

function Junk.generateComputationalJunk()
    local var = Engine.generateName("mixed", 25)
    local iterations = Engine.randomRange(100, 500)
    local modulo = Engine.randomChoice({97, 127, 251, 509})
    
    return string.format([[
local %s = 0
for i = 1, %d do
    %s = (%s + i) %% %d
end
%s = nil]], var, iterations, var, var, modulo, var)
end

function Junk.generate(junk_type)
    junk_type = junk_type or Engine.randomRange(1, 7)
    
    local generators = {
        Junk.generateNOPEquivalent,
        function() return "if " .. Junk.generateOpaquePredicate(true) .. " then end" end,
        function() 
            local fake = Engine.generateName("mixed", 20)
            local n = Engine.randomRange(1, 1000)
            return "if " .. Junk.generateOpaquePredicate(false) .. " then local " .. fake .. " = " .. n .. " end"
        end,
        Junk.generateInterleaved,
        Junk.generateFakeFunction,
        Junk.generateFakeDataStructure,
        Junk.generateComputationalJunk,
    }
    
    return generators[junk_type]()
end

function Junk.generateBatch(count, distribution)
    distribution = distribution or {25, 20, 15, 20, 8, 7, 5}
    
    local total_weight = 0
    for _, w in ipairs(distribution) do
        total_weight = total_weight + w
    end
    
    local junk_code = {}
    
    for _ = 1, count do
        local r = Engine.randomRange(1, total_weight)
        local cumulative = 0
        local selected_type = 1
        
        for i, weight in ipairs(distribution) do
            cumulative = cumulative + weight
            if r <= cumulative then
                selected_type = i
                break
            end
        end
        
        junk_code[#junk_code + 1] = Junk.generate(selected_type)
    end
    
    return table.concat(junk_code, "\n")
end

function Junk.addJunkYard(code)
    if not Config.get("JunkCode.JunkYard") then
        return code
    end
    
    local lines = {code}
    
    -- Generate a diverse base block of ~10 lines (very small to be strictly safe for local limit)
    local base_block_lines = {}
    for i = 1, 10 do
        base_block_lines[#base_block_lines + 1] = Junk.generate(Engine.randomRange(1, 4))
    end
    local base_block = table.concat(base_block_lines, "\n")
    
    -- Append this block 20000 times (split into chunks) to reach ~200k lines
    -- We split into 20 chunks of 1000 to avoid Lua 5.1 jump offset limits (18-bit signed integer)
    -- A single block of 200k lines requires a jump > 131071 instructions, crashing the compiler/interpreter.
    
    lines[#lines + 1] = "\n-- Junk Yard Start"
    local wrapper_var = Engine.generateName("mixed", 10)
    lines[#lines + 1] = string.format("local %s = 0", wrapper_var)
    
    -- Default 20 chunks of 1000 reps = 200k lines
    -- Configurable for presets like 'luasec' (50k lines = 5 chunks)
    local chunks = Config.get("JunkCode.JunkYardChunks") or 20
    
    -- We wrap each chunk in a function (IIFE) to:
    -- 1. Create a new register frame (avoiding "too many local variables" in main)
    -- 2. Move code into separate prototypes (avoiding main chunk jump size limits)
    for chunk = 1, chunks do
        lines[#lines + 1] = string.format("if %s > 1 then", wrapper_var)
        lines[#lines + 1] = "(function()"
        for i = 1, 1000 do
            lines[#lines + 1] = "do"
            lines[#lines + 1] = base_block
            lines[#lines + 1] = "end"
        end
        lines[#lines + 1] = "end)()"
        lines[#lines + 1] = "end"
    end
    
    lines[#lines + 1] = "-- Junk Yard End"
    
    return table.concat(lines, "\n")
end

function Junk.insertIntoCode(code, density)
    density = density or 0.5
    
    Junk.cacheRealVariables(code)
    
    local header_junk = {}
    local header_count = Engine.randomRange(10, 20)
    for _ = 1, header_count do
        if Engine.randomFloat() < 0.3 then
            header_junk[#header_junk + 1] = Junk.generateFakeFunction()
        elseif Engine.randomFloat() < 0.5 then
            header_junk[#header_junk + 1] = Junk.generateFakeDataStructure()
        else
            header_junk[#header_junk + 1] = Junk.generateNOPEquivalent()
        end
    end
    
    local lines = {}
    local in_block = 0
    local brace_depth = 0
    local line_count = 0
    
    for line in code:gmatch("[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        
        -- Robust block tracking using token counting
        local function countTokens(str, pattern)
            local count = 0
            for _ in str:gmatch(pattern) do count = count + 1 end
            return count
        end
        
        -- Openers
        local functions = countTokens(trimmed, "%f[%w]function%f[%W]")
        local dos = countTokens(trimmed, "%f[%w]do%f[%W]")
        local thens = countTokens(trimmed, "%f[%w]then%f[%W]")
        local repeats = countTokens(trimmed, "%f[%w]repeat%f[%W]")
        
        -- Closers
        local ends = countTokens(trimmed, "%f[%w]end%f[%W]")
        local untils = countTokens(trimmed, "%f[%w]until%f[%W]")
        
        -- Update depth
        in_block = in_block + functions + dos + thens + repeats
        in_block = in_block - ends - untils
        
        -- Ensure non-negative (safety)
        if in_block < 0 then in_block = 0 end
        
        -- Track braces for table constructors
        local _, open_braces = trimmed:gsub("{", "")
        local _, close_braces = trimmed:gsub("}", "")
        brace_depth = brace_depth + open_braces - close_braces
        
        lines[#lines + 1] = line
        line_count = line_count + 1
        
        -- Safety checks
        -- 1. Not in block
        -- 2. Not in table
        -- 3. Not a comment
        -- 4. Not a control flow keyword (else, elseif)
        -- 5. Not a return statement (return must be last)
        
        local is_safe = in_block == 0 and brace_depth == 0 and
                       not trimmed:match("^%-%-") and
                       not trimmed:match("^else") and
                       not trimmed:match("^elseif") and
                       not trimmed:match("^return") and
                       not trimmed:match("[%{%(%[,]$") and -- Safety: Don't insert after open structures
                       #trimmed > 0
        
        if is_safe and Engine.randomFloat() < density then
            local junk_count = Engine.randomRange(1, 3)
            -- Wrap junk in do...end to prevent polluting local scope and hitting 200 local limit
            lines[#lines + 1] = "do"
            for _ = 1, junk_count do
                local junk_type = Engine.randomRange(1, 4)
                lines[#lines + 1] = Junk.generate(junk_type)
            end
            lines[#lines + 1] = "end"
        end
    end
    
    return table.concat(header_junk, "\n") .. "\n" .. table.concat(lines, "\n")
end

return Junk
