--[[
    lua.rip - VM Runtime Generator
    Generates the complete VM runtime with deserializer
]]

local Engine = require("src.polymorphic.engine")
local Opcodes = require("src.vm.opcodes")
local Dispatcher = require("src.vm.dispatcher")
local Crypto = require("src.core.crypto")
local Bit = require("src.lib.bit")

local Runtime = {}

function Runtime.generateDeserializer(vars)
    vars = vars or Dispatcher.generateVariables()
    
    local encoding = Opcodes.getEncodingSchema()
    
    local byte_func = Engine.generateName("mixed", 30)
    local int_func = Engine.generateName("mixed", 30)
    local num_func = Engine.generateName("mixed", 30)
    local str_func = Engine.generateName("mixed", 30)
    local decode_instr = Engine.generateName("mixed", 30)
    local deserialize = Engine.generateName("mixed", 35)
    
    local source_var = Engine.generateName("mixed", 25)
    local idx_var = Engine.generateName("mixed", 20)
    
    local code = string.format([[
local %s, %s = nil, 1

local function %s()
    local b = string.byte(%s, %s)
    %s = %s + 1
    return b
end

local function %s()
    local b1, b2, b3, b4 = string.byte(%s, %s, %s + 3)
    %s = %s + 4
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function %s()
    local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(%s, %s, %s + 7)
    %s = %s + 8
    local sign = 1
    if b8 >= 128 then sign = -1; b8 = b8 - 128 end
    local exp = b8 * 16 + math.floor(b7 / 16)
    local frac = (b7 %% 16) * 2^48 + b6 * 2^40 + b5 * 2^32 + b4 * 2^24 + b3 * 2^16 + b2 * 2^8 + b1
    if exp == 0 then
        if frac == 0 then return 0 end
        return sign * frac * 2^(-1074)
    elseif exp == 2047 then
        if frac == 0 then return sign * (1/0) end
        return 0/0
    end
    return sign * 2^(exp - 1023) * (1 + frac / 2^52)
end

local function %s()
    local len = %s()
    if len == 0 then return nil end
    if len == 254 then len = %s() end
    local s = string.sub(%s, %s, %s + len - 1)
    %s = %s + len
    return s
end

local function %s(encoded)
    local xor_key = %d
    encoded = encoded - (xor_key * 0x01010101)
    if encoded < 0 then encoded = encoded + 4294967296 end
    
    local op = encoded %% 256
    local rest = math.floor(encoded / 256)
    local A = rest %% %d
    rest = math.floor(rest / %d)
    local B = rest %% %d
    local C = math.floor(rest / %d)
    
    return op, A, B, C
end

local function %s()
    %s = 1
    
    local num_params = %s()
    local is_vararg = %s()
    local max_stack = %s()
    
    local num_instructions = %s()
    local instructions = {}
    for i = 1, num_instructions do
        local encoded = %s()
        local op, A, B, C = %s(encoded)
        local Bx = B + C * 256
        local sBx = Bx - 131071
        instructions[i] = {op, A, B, C, Bx, sBx}
    end
    
    local num_constants = %s()
    local constants = {}
    for i = 1, num_constants do
        local const_type = %s()
        if const_type == 0 then
            constants[i] = nil
        elseif const_type == 1 then
            constants[i] = (%s() ~= 0)
        elseif const_type == 3 then
            constants[i] = %s()
        elseif const_type == 4 then
            constants[i] = %s()
        end
    end
    
    local num_protos = %s()
    local protos = {}
    for i = 1, num_protos do
        protos[i] = %s()
    end
    
    local num_lines = %s()
    for i = 1, num_lines do
        %s()
    end
    
    return {
        instructions = instructions,
        constants = constants,
        protos = protos,
        num_params = num_params,
        is_vararg = is_vararg,
        max_stack = max_stack,
    }
end
]], 
        source_var, idx_var,
        byte_func, source_var, idx_var, idx_var, idx_var,
        int_func, source_var, idx_var, idx_var, idx_var, idx_var,
        num_func, source_var, idx_var, idx_var, idx_var, idx_var,
        str_func, byte_func, int_func, source_var, idx_var, idx_var, idx_var, idx_var,
        decode_instr, encoding.xor_key,
        2^encoding.a_bits, 2^encoding.a_bits, 2^encoding.b_bits, 2^encoding.b_bits,
        deserialize, idx_var,
        byte_func, byte_func, byte_func,
        int_func,
        int_func, decode_instr,
        int_func,
        byte_func,
        byte_func,
        num_func,
        str_func,
        int_func, deserialize,
        int_func, int_func
    )
    
    return code, {
        source_var = source_var,
        idx_var = idx_var,
        deserialize = deserialize,
        byte_func = byte_func,
        int_func = int_func,
    }
end

function Runtime.generateWrapper(deserializer_vars, dispatcher_name)
    local wrap_func = Engine.generateName("mixed", 35)
    local execute_func = Engine.generateName("mixed", 35)
    
    local bytecode_var = Engine.generateName("mixed", 25)
    local proto_var = Engine.generateName("mixed", 25)
    local env_var = Engine.generateName("mixed", 20)
    
    local code = string.format([[
local function %s(%s, %s)
    %s = %s
    local %s = %s()
    
    return function(...)
        local varargs = {...}
        return %s(%s.instructions, %s.constants, %s.protos, %s, nil, varargs)
    end
end
]],
        wrap_func, bytecode_var, env_var,
        deserializer_vars.source_var, bytecode_var,
        proto_var, deserializer_vars.deserialize,
        dispatcher_name, proto_var, proto_var, proto_var, env_var
    )
    
    return code, wrap_func
end

function Runtime.generate()
    Engine.init()
    Opcodes.init()
    
    local parts = {}
    
    local dispatcher_func = Engine.generateName("mixed", 40)
    
    local vars = Dispatcher.generateVariables()
    
    local deserializer_code, deserializer_vars = Runtime.generateDeserializer(vars)
    parts[#parts + 1] = deserializer_code
    parts[#parts + 1] = ""
    
    local dispatcher_code = Runtime.generateDispatcher(dispatcher_func, vars)
    parts[#parts + 1] = dispatcher_code
    parts[#parts + 1] = ""
    
    local wrapper_code, wrapper_func = Runtime.generateWrapper(deserializer_vars, dispatcher_func)
    parts[#parts + 1] = wrapper_code
    parts[#parts + 1] = ""
    
    return table.concat(parts, "\n"), wrapper_func, deserializer_vars.source_var
end

function Runtime.generateDispatcher(func_name, vars)
    local lines = {}
    
    local function add(line)
        lines[#lines + 1] = line
    end
    
    add("local function " .. func_name .. "(" .. vars.instructions .. ", " .. vars.constants .. ", " .. vars.protos .. ", " .. vars.env .. ", " .. vars.upvals .. ", " .. vars.varargs .. ")")
    add("    local " .. vars.stack .. " = {}")
    add("    local " .. vars.pc .. " = 1")
    add("    local " .. vars.top .. " = 0")
    add("    local " .. vars.vararg_len .. " = " .. vars.varargs .. " and #" .. vars.varargs .. " or 0")
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
    
    local op_handlers = {
        MOVE = string.format("%s[%s] = %s[%s]", vars.stack, vars.a, vars.stack, vars.b),
        LOADK = string.format("%s[%s] = %s[%s + 1]", vars.stack, vars.a, vars.constants, vars.bx),
        LOADBOOL = string.format("%s[%s] = (%s ~= 0); if %s ~= 0 then %s = %s + 1 end", vars.stack, vars.a, vars.b, vars.c, vars.pc, vars.pc),
        LOADNIL = string.format("for i = %s, %s do %s[i] = nil end", vars.a, vars.b, vars.stack),
        GETGLOBAL = string.format("%s[%s] = %s[%s[%s + 1]]", vars.stack, vars.a, vars.env, vars.constants, vars.bx),
        SETGLOBAL = string.format("%s[%s[%s + 1]] = %s[%s]", vars.env, vars.constants, vars.bx, vars.stack, vars.a),
        NEWTABLE = string.format("%s[%s] = {}", vars.stack, vars.a),
        ADD = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L + R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        SUB = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L - R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        MUL = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L * R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        DIV = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L / R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        MOD = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L %% R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        POW = string.format("local L = %s >= 256 and %s[%s - 255] or %s[%s]; local R = %s >= 256 and %s[%s - 255] or %s[%s]; %s[%s] = L ^ R", vars.b, vars.constants, vars.b, vars.stack, vars.b, vars.c, vars.constants, vars.c, vars.stack, vars.c, vars.stack, vars.a),
        UNM = string.format("%s[%s] = -%s[%s]", vars.stack, vars.a, vars.stack, vars.b),
        NOT = string.format("%s[%s] = not %s[%s]", vars.stack, vars.a, vars.stack, vars.b),
        LEN = string.format("%s[%s] = #%s[%s]", vars.stack, vars.a, vars.stack, vars.b),
        JMP = string.format("%s = %s + %s", vars.pc, vars.pc, vars.sbx),
        RETURN = string.format("if %s == 1 then return elseif %s == 0 then return unpack(%s, %s, %s) else return unpack(%s, %s, %s + %s - 2) end", vars.b, vars.b, vars.stack, vars.a, vars.top, vars.stack, vars.a, vars.a, vars.b),
    }
    
    for i, case in ipairs(dispatch_cases) do
        local handler = op_handlers[case.name]
        if handler then
            local condition = (i == 1) and "if" or "elseif"
            add("        " .. condition .. " " .. vars.op .. " == " .. case.value .. " then -- " .. case.name)
            add("            " .. handler)
        end
    end
    
    add("        end")
    add("    end")
    add("end")
    
    return table.concat(lines, "\n")
end

return Runtime
