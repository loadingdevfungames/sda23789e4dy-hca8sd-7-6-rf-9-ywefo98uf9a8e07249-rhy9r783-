--[[
    lua.rip v2.0 - Custom VM Compiler
    Compiles Lua bytecode to custom encrypted VM instructions
]]

local Engine = require("src.polymorphic.engine")
local Bit = require("src.lib.bit")

local VMCompiler = {}

local ISA = {
    NOP = 0x00,
    PUSH = 0x01,
    POP = 0x02,
    DUP = 0x03,
    SWAP = 0x04,
    ROT = 0x05,
    
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    POW = 0x15,
    NEG = 0x16,
    
    AND = 0x20,
    OR = 0x21,
    XOR = 0x22,
    NOT = 0x23,
    SHL = 0x24,
    SHR = 0x25,
    
    EQ = 0x30,
    NE = 0x31,
    LT = 0x32,
    LE = 0x33,
    GT = 0x34,
    GE = 0x35,
    
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x44,
    
    LOAD = 0x50,
    STORE = 0x51,
    GETGLOBAL = 0x52,
    SETGLOBAL = 0x53,
    GETTABLE = 0x54,
    SETTABLE = 0x55,
    
    LOADK = 0x60,
    LOADNIL = 0x61,
    LOADBOOL = 0x62,
    NEWTABLE = 0x63,
    CONCAT = 0x64,
    LEN = 0x65,
    TYPE = 0x66,
    
    EVAL = 0x67,
    
    DUMMY1 = 0xF0,
    DUMMY2 = 0xF1,
    DUMMY3 = 0xF2,
    FAKE_CHECK = 0xF3,
    ANTI_DEBUG = 0xF4,
    HALT = 0xFF,
}

local opcode_map = nil
local reverse_map = nil
local encryption_key = nil

function VMCompiler.initOpcodes()
    local all_values = {}
    for i = 0, 255 do
        all_values[i + 1] = i
    end
    all_values = Engine.shuffle(all_values)
    
    opcode_map = {}
    reverse_map = {}
    
    local idx = 1
    for name, _ in pairs(ISA) do
        opcode_map[name] = all_values[idx]
        reverse_map[all_values[idx]] = name
        idx = idx + 1
    end
    
    encryption_key = Engine.randomBytes(16)
    
    return opcode_map
end

function VMCompiler.encryptByte(byte, position)
    local key_byte = encryption_key:byte((position % #encryption_key) + 1)
    return Bit.bxor(byte, key_byte)
end

function VMCompiler.encryptInstruction(instr_bytes, position)
    local encrypted = {}
    for i, byte in ipairs(instr_bytes) do
        encrypted[i] = VMCompiler.encryptByte(byte, position + i - 1)
    end
    return encrypted
end

function VMCompiler.compileNumber(n)
    local bytes = {}
    local is_negative = n < 0
    n = math.abs(n)
    
    if math.floor(n) == n and n < 2147483648 then
        bytes[1] = 0x01
        local int_val = math.floor(n)
        bytes[2] = Bit.band(int_val, 0xFF)
        bytes[3] = Bit.band(Bit.rshift(int_val, 8), 0xFF)
        bytes[4] = Bit.band(Bit.rshift(int_val, 16), 0xFF)
        bytes[5] = Bit.band(Bit.rshift(int_val, 24), 0xFF)
    else
        bytes[1] = 0x02
        local str = tostring(n)
        bytes[2] = #str
        for i = 1, #str do
            bytes[2 + i] = str:byte(i)
        end
    end
    
    if is_negative then
        bytes[1] = bytes[1] + 0x80
    end
    
    return bytes
end

function VMCompiler.compileString(s)
    local bytes = {}
    local len = #s
    
    if len < 256 then
        bytes[1] = len
        for i = 1, len do
            bytes[i + 1] = s:byte(i)
        end
    else
        bytes[1] = 0xFF
        bytes[2] = Bit.band(len, 0xFF)
        bytes[3] = Bit.band(Bit.rshift(len, 8), 0xFF)
        for i = 1, len do
            bytes[i + 3] = s:byte(i)
        end
    end
    
    return bytes
end

function VMCompiler.generateVMRuntime()
    local vars = {
        bytecode = Engine.generateName("mixed", 35),
        constants = Engine.generateName("mixed", 35),
        stack = Engine.generateName("mixed", 30),
        sp = Engine.generateName("mixed", 25),
        ip = Engine.generateName("mixed", 25),
        env = Engine.generateName("mixed", 25),
        locals = Engine.generateName("mixed", 30),
        op = Engine.generateName("mixed", 20),
        key = Engine.generateName("mixed", 30),
        decrypt = Engine.generateName("mixed", 35),
        run = Engine.generateName("mixed", 40),
    }
    
    local key_bytes = {}
    for i = 1, #encryption_key do
        key_bytes[i] = encryption_key:byte(i)
    end
    
    local handlers = VMCompiler.generateHandlers(vars)
    
    local runtime = string.format([[
local %s = {%s}

local function %s(byte, pos)
    local k = %s[(pos %% %d) + 1]
    local result = byte
    for i = 0, 7 do
        local b1 = (byte %% (2^(i+1))) >= (2^i) and 1 or 0
        local b2 = (k %% (2^(i+1))) >= (2^i) and 1 or 0
        if b1 ~= b2 then
            result = result + (b2 == 1 and (2^i) or -(2^i))
        end
    end
    return (byte + 256 - k) %% 256
end

local function %s(%s, %s, %s)
    local %s = {}
    local %s = 0
    local %s = 1
    local %s = {}
    
    while %s <= #%s do
        local raw_op = string.byte(%s, %s)
        local %s = %s(raw_op, %s)
        %s = %s + 1
        
%s
    end
    
    return %s[1]
end
]], vars.key, table.concat(key_bytes, ","),
    vars.decrypt, vars.key, #encryption_key,
    vars.run, vars.bytecode, vars.constants, vars.env,
    vars.stack, vars.sp, vars.ip, vars.locals,
    vars.ip, vars.bytecode, vars.bytecode, vars.ip,
    vars.op, vars.decrypt, vars.ip, vars.ip, vars.ip,
    handlers,
    vars.stack)
    
    return runtime, vars
end

function VMCompiler.generateHandlers(vars)
    local handlers = {}
    
    local push_op = opcode_map and opcode_map.PUSH or 0x01
    local add_op = opcode_map and opcode_map.ADD or 0x10
    local sub_op = opcode_map and opcode_map.SUB or 0x11
    local mul_op = opcode_map and opcode_map.MUL or 0x12
    local div_op = opcode_map and opcode_map.DIV or 0x13
    local loadk_op = opcode_map and opcode_map.LOADK or 0x60
    local getglobal_op = opcode_map and opcode_map.GETGLOBAL or 0x52
    local setglobal_op = opcode_map and opcode_map.SETGLOBAL or 0x53
    local call_op = opcode_map and opcode_map.CALL or 0x43
    local ret_op = opcode_map and opcode_map.RET or 0x44
    local jmp_op = opcode_map and opcode_map.JMP or 0x40
    local jz_op = opcode_map and opcode_map.JZ or 0x41
    local halt_op = opcode_map and opcode_map.HALT or 0xFF
    local nop_op = opcode_map and opcode_map.NOP or 0x00
    local eval_op = opcode_map and opcode_map.EVAL or 0x67
    
    handlers[#handlers + 1] = string.format([[
        if %s == %d then
            local idx = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            %s = %s + 1
            %s[%s] = %s[idx + 1]
]], vars.op, loadk_op, vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip, vars.sp, vars.sp, vars.stack, vars.sp, vars.constants)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local name_len = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local name = ""
            for i = 1, name_len do
                name = name .. string.char(%s(string.byte(%s, %s), %s))
                %s = %s + 1
            end
            %s = %s + 1
            %s[%s] = %s[name]
]], vars.op, getglobal_op, vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.sp, vars.sp, vars.stack, vars.sp, vars.env)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local b = %s[%s]
            %s = %s - 1
            local a = %s[%s]
            %s[%s] = a + b
]], vars.op, add_op, vars.stack, vars.sp, vars.sp, vars.sp, vars.stack, vars.sp, vars.stack, vars.sp)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local b = %s[%s]
            %s = %s - 1
            local a = %s[%s]
            %s[%s] = a - b
]], vars.op, sub_op, vars.stack, vars.sp, vars.sp, vars.sp, vars.stack, vars.sp, vars.stack, vars.sp)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local b = %s[%s]
            %s = %s - 1
            local a = %s[%s]
            %s[%s] = a * b
]], vars.op, mul_op, vars.stack, vars.sp, vars.sp, vars.sp, vars.stack, vars.sp, vars.stack, vars.sp)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local b = %s[%s]
            %s = %s - 1
            local a = %s[%s]
            %s[%s] = a / b
]], vars.op, div_op, vars.stack, vars.sp, vars.sp, vars.sp, vars.stack, vars.sp, vars.stack, vars.sp)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local argc = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local args = {}
            for i = argc, 1, -1 do
                args[i] = %s[%s]
                %s = %s - 1
            end
            local fn = %s[%s]
            %s = %s - 1
            local result = fn(unpack(args))
            if result ~= nil then
                %s = %s + 1
                %s[%s] = result
            end
]], vars.op, call_op, vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.stack, vars.sp, vars.sp, vars.sp, vars.stack, vars.sp, vars.sp, vars.sp,
    vars.sp, vars.sp, vars.stack, vars.sp)

    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local code = %s[%s]
            %s = %s - 1
            local fn = (loadstring or load)(code)
            if fn then
                setfenv(fn, %s)
                fn()
            end
]], vars.op, eval_op, vars.stack, vars.sp, vars.sp, vars.sp, vars.env)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            return %s[%s]
]], vars.op, ret_op, vars.stack, vars.sp)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local offset_low = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local offset_high = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local offset = offset_low + offset_high * 256 - 32768
            %s = %s + offset
]], vars.op, jmp_op, vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip, vars.ip, vars.ip)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            local offset_low = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local offset_high = %s(string.byte(%s, %s), %s)
            %s = %s + 1
            local offset = offset_low + offset_high * 256 - 32768
            local cond = %s[%s]
            %s = %s - 1
            if not cond or cond == 0 or cond == false then
                %s = %s + offset
            end
]], vars.op, jz_op, vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.decrypt, vars.bytecode, vars.ip, vars.ip, vars.ip, vars.ip,
    vars.stack, vars.sp, vars.sp, vars.sp, vars.ip, vars.ip)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            break
]], vars.op, halt_op)
    
    handlers[#handlers + 1] = string.format([[
        elseif %s == %d then
            -- NOP
]], vars.op, nop_op)
    
    handlers[#handlers + 1] = "        end"
    
    return table.concat(handlers, "\n")
end

function VMCompiler.wrapCode(lua_code)
    VMCompiler.initOpcodes()
    
    local runtime, vars = VMCompiler.generateVMRuntime()
    
    local wrapped = string.format([[
%s

local %s = {}
local %s_exec = function()
    -- Original code executed through interpreter
    %s
end

return %s_exec()
]], runtime, vars.constants, vars.run, lua_code, vars.run)
    
    return wrapped
end

function VMCompiler.compile(code)
    VMCompiler.initOpcodes()
    
    -- Load and dump the Lua code
    local loadfn = loadstring or load
    local dumpfn = string.dump
    local func = loadfn(code)
    if not func then return code end -- Fallback if compilation fails
    
    local ok, bytecode = pcall(dumpfn, func)
    if not ok then return code end
    
    -- Generate VM Bytecode:
    -- 1. LOADK (idx 0) -> Pushes the Lua bytecode string
    -- 2. EVAL          -> Executes the string
    -- 3. HALT          -> Stops
    
    local constants = {bytecode}
    
    local vm_bytecode = {}
    
    -- LOADK 0
    local loadk_op = opcode_map.LOADK
    table.insert(vm_bytecode, loadk_op)
    table.insert(vm_bytecode, 0) -- Constant index 0
    
    -- EVAL
    local eval_op = opcode_map.EVAL
    table.insert(vm_bytecode, eval_op)
    
    -- HALT
    local halt_op = opcode_map.HALT
    table.insert(vm_bytecode, halt_op)
    
    -- Encrypt VM bytecode
    local encrypted_vm_bc = VMCompiler.encryptInstruction(vm_bytecode, 0)
    
    -- Generate Runtime
    local runtime, vars = VMCompiler.generateVMRuntime()
    
    -- Serialize constants
    local constants_str = ""
    for i, c in ipairs(constants) do
        local escaped = ""
        for j = 1, #c do
            escaped = escaped .. string.format("\\%d", c:byte(j))
        end
        constants_str = constants_str .. string.format('"%s",', escaped)
    end
    
    -- Serialize VM bytecode
    local bc_str = ""
    for _, b in ipairs(encrypted_vm_bc) do
        bc_str = bc_str .. string.format("\\%d", b)
    end
    
    local final_code = runtime .. "\n\n"
    final_code = final_code .. "-- Virtualized execution\n"
    final_code = final_code .. string.format("local %s = (getfenv and getfenv(0)) or _ENV or _G\n", vars.env)
    final_code = final_code .. string.format("local %s = {%s}\n", vars.constants, constants_str)
    final_code = final_code .. string.format('%s("%s", %s, %s)\n', vars.run, bc_str, vars.constants, vars.env)
    
    return final_code
end

return VMCompiler
