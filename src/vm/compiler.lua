--[[
    lua.rip - VM Bytecode Compiler
    Compiles Lua source to custom VM bytecode
]]

local Engine = require("src.polymorphic.engine")
local Opcodes = require("src.vm.opcodes")
local Bit = require("src.lib.bit")

local Compiler = {}

local OPCODE_TYPES = {
    MOVE = "ABC",
    LOADK = "ABx",
    LOADBOOL = "ABC",
    LOADNIL = "ABC",
    GETUPVAL = "ABC",
    GETGLOBAL = "ABx",
    GETTABLE = "ABC",
    SETGLOBAL = "ABx",
    SETUPVAL = "ABC",
    SETTABLE = "ABC",
    NEWTABLE = "ABC",
    SELF = "ABC",
    ADD = "ABC",
    SUB = "ABC",
    MUL = "ABC",
    DIV = "ABC",
    MOD = "ABC",
    POW = "ABC",
    UNM = "ABC",
    NOT = "ABC",
    LEN = "ABC",
    CONCAT = "ABC",
    JMP = "AsBx",
    EQ = "ABC",
    LT = "ABC",
    LE = "ABC",
    TEST = "ABC",
    TESTSET = "ABC",
    CALL = "ABC",
    TAILCALL = "ABC",
    RETURN = "ABC",
    FORLOOP = "AsBx",
    FORPREP = "AsBx",
    TFORLOOP = "ABC",
    SETLIST = "ABC",
    CLOSE = "ABC",
    CLOSURE = "ABx",
    VARARG = "ABC",
}

local function serializeNumber(n)
    local bytes = {}
    for i = 1, 8 do
        bytes[i] = string.char(Bit.band(n, 0xFF))
        n = Bit.rshift(n, 8)
    end
    return table.concat(bytes)
end

local function serializeString(s)
    local len = #s
    local header = ""
    
    if len < 254 then
        header = string.char(len)
    else
        header = string.char(254) .. serializeNumber(len):sub(1, 4)
    end
    
    return header .. s
end

local function serializeInstruction(opcode_name, a, b, c, bx, sbx)
    local opcode = Opcodes.get(opcode_name)
    local instruction_type = OPCODE_TYPES[opcode_name] or "ABC"
    
    local encoded
    
    if instruction_type == "ABC" then
        encoded = Opcodes.encode(opcode, a or 0, b or 0, c or 0)
    elseif instruction_type == "ABx" then
        local bx_high = Bit.rshift(bx or 0, 8)
        local bx_low = Bit.band(bx or 0, 0xFF)
        encoded = Opcodes.encode(opcode, a or 0, bx_low, bx_high)
    elseif instruction_type == "AsBx" then
        local adjusted = (sbx or 0) + 131071
        local bx_high = Bit.rshift(adjusted, 8)
        local bx_low = Bit.band(adjusted, 0xFF)
        encoded = Opcodes.encode(opcode, a or 0, bx_low, bx_high)
    end
    
    return serializeNumber(encoded):sub(1, 4)
end

function Compiler.new()
    local compiler = {
        constants = {},
        constant_map = {},
        instructions = {},
        prototypes = {},
        
        num_params = 0,
        is_vararg = 0,
        max_stack = 2,
        
        current_line = 0,
        line_info = {},
        
        upvalues = {},
        locals = {},
        
        debug_info = {},
    }
    
    setmetatable(compiler, {__index = Compiler})
    
    return compiler
end

function Compiler:addConstant(value)
    local key = type(value) .. ":" .. tostring(value)
    
    if self.constant_map[key] then
        return self.constant_map[key]
    end
    
    local index = #self.constants
    self.constants[index + 1] = value
    self.constant_map[key] = index
    
    return index
end

function Compiler:emit(opcode_name, a, b, c, bx, sbx)
    local instr = {
        opcode = opcode_name,
        a = a,
        b = b,
        c = c,
        bx = bx,
        sbx = sbx,
        line = self.current_line,
    }
    
    self.instructions[#self.instructions + 1] = instr
    self.line_info[#self.line_info + 1] = self.current_line
    
    return #self.instructions - 1
end

function Compiler:emitABC(opcode_name, a, b, c)
    return self:emit(opcode_name, a, b, c)
end

function Compiler:emitABx(opcode_name, a, bx)
    return self:emit(opcode_name, a, nil, nil, bx)
end

function Compiler:emitAsBx(opcode_name, a, sbx)
    return self:emit(opcode_name, a, nil, nil, nil, sbx)
end

function Compiler:patchJump(instr_index, target)
    local instr = self.instructions[instr_index + 1]
    if instr then
        instr.sbx = target - instr_index - 1
    end
end

function Compiler:getCurrentPC()
    return #self.instructions
end

function Compiler:setLine(line)
    self.current_line = line
end

function Compiler:serialize()
    Opcodes.init()
    
    local parts = {}
    
    parts[#parts + 1] = string.char(self.num_params)
    parts[#parts + 1] = string.char(self.is_vararg)
    parts[#parts + 1] = string.char(self.max_stack)
    
    local num_instructions = #self.instructions
    parts[#parts + 1] = serializeNumber(num_instructions):sub(1, 4)
    
    for _, instr in ipairs(self.instructions) do
        parts[#parts + 1] = serializeInstruction(
            instr.opcode,
            instr.a,
            instr.b,
            instr.c,
            instr.bx,
            instr.sbx
        )
    end
    
    local num_constants = #self.constants
    parts[#parts + 1] = serializeNumber(num_constants):sub(1, 4)
    
    for _, const in ipairs(self.constants) do
        local const_type = type(const)
        
        if const == nil then
            parts[#parts + 1] = string.char(0)
        elseif const_type == "boolean" then
            parts[#parts + 1] = string.char(1)
            parts[#parts + 1] = string.char(const and 1 or 0)
        elseif const_type == "number" then
            parts[#parts + 1] = string.char(3)
            parts[#parts + 1] = serializeNumber(const)
        elseif const_type == "string" then
            parts[#parts + 1] = string.char(4)
            parts[#parts + 1] = serializeString(const)
        end
    end
    
    local num_protos = #self.prototypes
    parts[#parts + 1] = serializeNumber(num_protos):sub(1, 4)
    
    for _, proto in ipairs(self.prototypes) do
        parts[#parts + 1] = proto:serialize()
    end
    
    local num_lines = #self.line_info
    parts[#parts + 1] = serializeNumber(num_lines):sub(1, 4)
    for _, line in ipairs(self.line_info) do
        parts[#parts + 1] = serializeNumber(line):sub(1, 4)
    end
    
    return table.concat(parts)
end

function Compiler:encrypt(key)
    local serialized = self:serialize()
    return Engine.encrypt(serialized, key or "bytecode")
end

function Compiler.compileString(lua_code)
    local compiler = Compiler.new()
    
    local chunk_func, err = loadstring or load
    if not chunk_func then
        return nil, "loadstring not available"
    end
    
    local func, load_err = chunk_func(lua_code)
    if not func then
        return nil, "Failed to parse: " .. tostring(load_err)
    end
    
    local dump_func = string.dump
    if not dump_func then
        return nil, "string.dump not available"
    end
    
    local bytecode = dump_func(func)
    
    return compiler, bytecode
end

return Compiler
