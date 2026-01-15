--[[
    lua.rip - VM Dispatcher Generator
    Generates polymorphic VM dispatcher code
]]

local Engine = require("src.polymorphic.engine")
local Opcodes = require("src.vm.opcodes")

local Dispatcher = {}

local function generateOpcodeHandler(name, vars)
    local handlers = {
        MOVE = function()
            return string.format("%s[%s] = %s[%s]", vars.stack, vars.a, vars.stack, vars.b)
        end,
        
        LOADK = function()
            return string.format("%s[%s] = %s[%s + 1]", vars.stack, vars.a, vars.constants, vars.bx)
        end,
        
        LOADBOOL = function()
            return string.format([[
%s[%s] = (%s ~= 0)
if %s ~= 0 then %s = %s + 1 end
]], vars.stack, vars.a, vars.b, vars.c, vars.pc, vars.pc)
        end,
        
        LOADNIL = function()
            return string.format([[
for %s = %s, %s do %s[%s] = nil end
]], vars.temp, vars.a, vars.b, vars.stack, vars.temp)
        end,
        
        GETGLOBAL = function()
            return string.format("%s[%s] = %s[%s[%s + 1]]", vars.stack, vars.a, vars.env, vars.constants, vars.bx)
        end,
        
        SETGLOBAL = function()
            return string.format("%s[%s[%s + 1]] = %s[%s]", vars.env, vars.constants, vars.bx, vars.stack, vars.a)
        end,
        
        GETTABLE = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s[%s][%s]", vars.stack, vars.a, vars.stack, vars.b, rk_c)
        end,
        
        SETTABLE = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s][%s] = %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        NEWTABLE = function()
            return string.format("%s[%s] = {}", vars.stack, vars.a)
        end,
        
        ADD = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s + %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        SUB = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s - %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        MUL = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s * %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        DIV = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s / %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        MOD = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s %% %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        POW = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("%s[%s] = %s ^ %s", vars.stack, vars.a, rk_b, rk_c)
        end,
        
        UNM = function()
            return string.format("%s[%s] = -%s[%s]", vars.stack, vars.a, vars.stack, vars.b)
        end,
        
        NOT = function()
            return string.format("%s[%s] = not %s[%s]", vars.stack, vars.a, vars.stack, vars.b)
        end,
        
        LEN = function()
            return string.format("%s[%s] = #%s[%s]", vars.stack, vars.a, vars.stack, vars.b)
        end,
        
        CONCAT = function()
            return string.format([[
local %s = {}
for %s = %s, %s do %s[#%s + 1] = %s[%s] end
%s[%s] = table.concat(%s)
]], vars.temp, vars.temp2, vars.b, vars.c, vars.temp, vars.temp, vars.stack, vars.temp2, vars.stack, vars.a, vars.temp)
        end,
        
        JMP = function()
            return string.format("%s = %s + %s", vars.pc, vars.pc, vars.sbx)
        end,
        
        EQ = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("if (%s == %s) ~= (%s ~= 0) then %s = %s + 1 end", rk_b, rk_c, vars.a, vars.pc, vars.pc)
        end,
        
        LT = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("if (%s < %s) ~= (%s ~= 0) then %s = %s + 1 end", rk_b, rk_c, vars.a, vars.pc, vars.pc)
        end,
        
        LE = function()
            local rk_b = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.b, vars.constants, vars.b, vars.stack, vars.b)
            local rk_c = string.format("(%s >= 256 and %s[%s - 255] or %s[%s])", vars.c, vars.constants, vars.c, vars.stack, vars.c)
            return string.format("if (%s <= %s) ~= (%s ~= 0) then %s = %s + 1 end", rk_b, rk_c, vars.a, vars.pc, vars.pc)
        end,
        
        TEST = function()
            return string.format("if (not %s[%s]) == (%s ~= 0) then %s = %s + 1 end", vars.stack, vars.a, vars.c, vars.pc, vars.pc)
        end,
        
        TESTSET = function()
            return string.format([[
if (not %s[%s]) == (%s ~= 0) then
    %s = %s + 1
else
    %s[%s] = %s[%s]
end
]], vars.stack, vars.b, vars.c, vars.pc, vars.pc, vars.stack, vars.a, vars.stack, vars.b)
        end,
        
        CALL = function()
            return string.format([[
local %s = %s[%s]
local %s
if %s == 0 then
    %s = {%s(unpack(%s, %s + 1, %s))}
elseif %s == 1 then
    %s = {%s()}
else
    %s = {%s(unpack(%s, %s + 1, %s + %s - 1))}
end
if %s == 0 then
    for %s = 1, #%s do %s[%s + %s - 1] = %s[%s] end
    %s = %s + #%s - 1
elseif %s > 1 then
    for %s = 1, %s - 1 do %s[%s + %s - 1] = %s[%s] end
end
]], vars.temp, vars.stack, vars.a, vars.temp2, vars.b, vars.temp2, vars.temp, vars.stack, vars.a, vars.top, vars.b, vars.temp2, vars.temp, vars.temp2, vars.temp, vars.stack, vars.a, vars.a, vars.b, vars.c, vars.temp3, vars.temp2, vars.stack, vars.a, vars.temp3, vars.temp2, vars.temp3, vars.top, vars.a, vars.temp2, vars.c, vars.temp3, vars.c, vars.stack, vars.a, vars.temp3, vars.temp2, vars.temp3)
        end,
        
        RETURN = function()
            return string.format([[
if %s == 0 then
    return unpack(%s, %s, %s)
elseif %s == 1 then
    return
else
    return unpack(%s, %s, %s + %s - 2)
end
]], vars.b, vars.stack, vars.a, vars.top, vars.b, vars.stack, vars.a, vars.a, vars.b)
        end,
        
        FORLOOP = function()
            return string.format([[
%s[%s] = %s[%s] + %s[%s + 2]
if %s[%s + 2] > 0 then
    if %s[%s] <= %s[%s + 1] then
        %s = %s + %s
        %s[%s + 3] = %s[%s]
    end
else
    if %s[%s] >= %s[%s + 1] then
        %s = %s + %s
        %s[%s + 3] = %s[%s]
    end
end
]], vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.pc, vars.pc, vars.sbx, vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.pc, vars.pc, vars.sbx, vars.stack, vars.a, vars.stack, vars.a)
        end,
        
        FORPREP = function()
            return string.format([[
%s[%s] = %s[%s] - %s[%s + 2]
%s = %s + %s
]], vars.stack, vars.a, vars.stack, vars.a, vars.stack, vars.a, vars.pc, vars.pc, vars.sbx)
        end,
        
        CLOSURE = function()
            return string.format("%s[%s] = %s[%s + 1](%s, %s)", vars.stack, vars.a, vars.protos, vars.bx, vars.env, vars.upvals)
        end,
        
        VARARG = function()
            return string.format([[
local %s = %s - %s + 1
if %s == 0 then
    for %s = 1, %s do %s[%s + %s - 1] = %s[%s] end
    %s = %s + %s - 1
else
    for %s = 1, %s - 1 do %s[%s + %s - 1] = %s[%s] end
end
]], vars.temp, vars.vararg_len, vars.num_params, vars.b, vars.temp2, vars.temp, vars.stack, vars.a, vars.temp2, vars.varargs, vars.temp2, vars.top, vars.a, vars.temp, vars.temp2, vars.b, vars.stack, vars.a, vars.temp2, vars.varargs, vars.temp2)
        end,
    }
    
    local handler = handlers[name]
    if handler then
        return handler()
    end
    
    return "-- " .. name .. " not implemented"
end

function Dispatcher.generateVariables()
    local vars = {
        stack = Engine.generateName("mixed", 30),
        constants = Engine.generateName("mixed", 30),
        instructions = Engine.generateName("mixed", 30),
        protos = Engine.generateName("mixed", 30),
        env = Engine.generateName("mixed", 30),
        upvals = Engine.generateName("mixed", 30),
        pc = Engine.generateName("mixed", 25),
        top = Engine.generateName("mixed", 25),
        a = Engine.generateName("mixed", 20),
        b = Engine.generateName("mixed", 20),
        c = Engine.generateName("mixed", 20),
        bx = Engine.generateName("mixed", 20),
        sbx = Engine.generateName("mixed", 20),
        op = Engine.generateName("mixed", 20),
        temp = Engine.generateName("mixed", 20),
        temp2 = Engine.generateName("mixed", 20),
        temp3 = Engine.generateName("mixed", 20),
        instr = Engine.generateName("mixed", 25),
        varargs = Engine.generateName("mixed", 25),
        vararg_len = Engine.generateName("mixed", 25),
        num_params = Engine.generateName("mixed", 25),
    }
    return vars
end

function Dispatcher.generate(used_opcodes)
    Opcodes.init()
    
    local vars = Dispatcher.generateVariables()
    
    local lines = {}
    
    local function add(line)
        lines[#lines + 1] = line
    end
    
    add("local function " .. Engine.generateName("mixed", 40) .. "(" .. vars.instructions .. ", " .. vars.constants .. ", " .. vars.protos .. ", " .. vars.env .. ", " .. vars.upvals .. ", " .. vars.varargs .. ")")
    add("    local " .. vars.stack .. " = {}")
    add("    local " .. vars.pc .. " = 1")
    add("    local " .. vars.top .. " = 0")
    add("    local " .. vars.vararg_len .. " = " .. vars.varargs .. " and #" .. vars.varargs .. " or 0")
    add("    local " .. vars.num_params .. " = 0")
    add("")
    add("    while true do")
    add("        local " .. vars.instr .. " = " .. vars.instructions .. "[" .. vars.pc .. "]")
    add("        if not " .. vars.instr .. " then return end")
    add("        " .. vars.pc .. " = " .. vars.pc .. " + 1")
    add("")
    add("        local " .. vars.op .. " = " .. vars.instr .. "[1]")
    add("        local " .. vars.a .. " = " .. vars.instr .. "[2]")
    add("        local " .. vars.b .. " = " .. vars.instr .. "[3]")
    add("        local " .. vars.c .. " = " .. vars.instr .. "[4]")
    add("        local " .. vars.bx .. " = " .. vars.instr .. "[5]")
    add("        local " .. vars.sbx .. " = " .. vars.instr .. "[6]")
    add("")
    
    local dispatch_cases = Opcodes.generateDispatcherCode()
    dispatch_cases = Engine.shuffle(dispatch_cases)
    
    for i, case in ipairs(dispatch_cases) do
        if used_opcodes == nil or used_opcodes[case.name] then
            local condition = (i == 1) and "if" or "elseif"
            add("        " .. condition .. " " .. vars.op .. " == " .. case.value .. " then")
            
            local handler = generateOpcodeHandler(case.name, vars)
            for line in handler:gmatch("[^\n]+") do
                if line:match("%S") then
                    add("            " .. line)
                end
            end
        end
    end
    
    add("        end")
    add("    end")
    add("end")
    
    return table.concat(lines, "\n"), vars
end

function Dispatcher.generateRuntime()
    local parts = {}
    
    local decode_func = Engine.generateName("mixed", 35)
    local deserialize_func = Engine.generateName("mixed", 35)
    local wrap_func = Engine.generateName("mixed", 35)
    
    parts[#parts + 1] = "local " .. decode_func .. ", " .. deserialize_func .. ", " .. wrap_func
    parts[#parts + 1] = ""
    
    local dispatcher_code, vars = Dispatcher.generate()
    parts[#parts + 1] = dispatcher_code
    
    return table.concat(parts, "\n")
end

return Dispatcher
