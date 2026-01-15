--[[
    lua.rip - Custom VM Opcode Definitions
    Generates unique opcode mappings per build
]]

local Crypto = require("src.core.crypto")
local Engine = require("src.polymorphic.engine")

local Opcodes = {}

local CORE_OPCODES = {
    "MOVE",
    "LOADK",
    "LOADBOOL",
    "LOADNIL",
    "GETUPVAL",
    "GETGLOBAL",
    "GETTABLE",
    "SETGLOBAL",
    "SETUPVAL",
    "SETTABLE",
    "NEWTABLE",
    "SELF",
    "ADD",
    "SUB",
    "MUL",
    "DIV",
    "MOD",
    "POW",
    "UNM",
    "NOT",
    "LEN",
    "CONCAT",
    "JMP",
    "EQ",
    "LT",
    "LE",
    "TEST",
    "TESTSET",
    "CALL",
    "TAILCALL",
    "RETURN",
    "FORLOOP",
    "FORPREP",
    "TFORLOOP",
    "SETLIST",
    "CLOSE",
    "CLOSURE",
    "VARARG",
}

local DUMMY_OPCODE_NAMES = {
    "NOP",
    "DUMMY1",
    "DUMMY2",
    "FAKE_LOAD",
    "FAKE_STORE",
    "FAKE_CALL",
    "FAKE_JMP",
    "ANTI_DEBUG",
    "INTEGRITY_CHECK",
    "STATE_CORRUPT",
    "DECOY_OP",
    "TIMING_CHECK",
    "ENV_VERIFY",
    "HASH_CHECK",
    "KEY_EVOLVE",
}

local opcode_map = nil
local reverse_map = nil
local dummy_opcodes = nil
local encoding_schema = nil

function Opcodes.init(dummy_count)
    dummy_count = dummy_count or 10
    
    if not Engine.isInitialized() then
        Engine.init()
    end
    
    local all_values = {}
    for i = 0, 255 do
        all_values[i + 1] = i
    end
    all_values = Engine.shuffle(all_values)
    
    opcode_map = {}
    reverse_map = {}
    
    for i, name in ipairs(CORE_OPCODES) do
        local value = all_values[i]
        opcode_map[name] = value
        reverse_map[value] = name
    end
    
    dummy_opcodes = {}
    for i = 1, math.min(dummy_count, #DUMMY_OPCODE_NAMES) do
        local value = all_values[#CORE_OPCODES + i]
        local name = DUMMY_OPCODE_NAMES[i]
        dummy_opcodes[name] = value
        reverse_map[value] = name
    end
    
    encoding_schema = {
        byte_order = Engine.randomChoice({"little", "big"}),
        opcode_position = Engine.randomRange(0, 3),
        a_bits = Engine.randomRange(7, 9),
        b_bits = Engine.randomRange(8, 10),
        c_bits = Engine.randomRange(8, 10),
        xor_key = Engine.randomRange(0, 255),
    }
    
    return Opcodes
end

function Opcodes.get(name)
    if not opcode_map then
        Opcodes.init()
    end
    return opcode_map[name]
end

function Opcodes.getName(value)
    if not reverse_map then
        Opcodes.init()
    end
    return reverse_map[value]
end

function Opcodes.getAll()
    if not opcode_map then
        Opcodes.init()
    end
    return opcode_map
end

function Opcodes.getDummies()
    if not dummy_opcodes then
        Opcodes.init()
    end
    return dummy_opcodes
end

function Opcodes.getRandomDummy()
    if not dummy_opcodes then
        Opcodes.init()
    end
    
    local dummies = {}
    for name, value in pairs(dummy_opcodes) do
        dummies[#dummies + 1] = {name = name, value = value}
    end
    
    if #dummies == 0 then
        return nil
    end
    
    return dummies[Engine.randomRange(1, #dummies)]
end

function Opcodes.encode(opcode, a, b, c)
    if not encoding_schema then
        Opcodes.init()
    end
    
    a = a or 0
    b = b or 0
    c = c or 0
    
    local encoded = opcode
    
    local a_shift = 8
    local b_shift = a_shift + encoding_schema.a_bits
    local c_shift = b_shift + encoding_schema.b_bits
    
    local Bit = require("src.lib.bit")
    encoded = Bit.bor(encoded, Bit.lshift(a, a_shift))
    encoded = Bit.bor(encoded, Bit.lshift(b, b_shift))
    encoded = Bit.bor(encoded, Bit.lshift(c, c_shift))
    
    encoded = Bit.bxor(encoded, encoding_schema.xor_key * 0x01010101)
    
    return encoded
end

function Opcodes.decode(encoded)
    if not encoding_schema then
        Opcodes.init()
    end
    
    local Bit = require("src.lib.bit")
    
    encoded = Bit.bxor(encoded, encoding_schema.xor_key * 0x01010101)
    
    local opcode = Bit.band(encoded, 0xFF)
    
    local a_shift = 8
    local b_shift = a_shift + encoding_schema.a_bits
    local c_shift = b_shift + encoding_schema.b_bits
    
    local a_mask = Bit.lshift(1, encoding_schema.a_bits) - 1
    local b_mask = Bit.lshift(1, encoding_schema.b_bits) - 1
    local c_mask = Bit.lshift(1, encoding_schema.c_bits) - 1
    
    local a = Bit.band(Bit.rshift(encoded, a_shift), a_mask)
    local b = Bit.band(Bit.rshift(encoded, b_shift), b_mask)
    local c = Bit.band(Bit.rshift(encoded, c_shift), c_mask)
    
    return opcode, a, b, c
end

function Opcodes.getEncodingSchema()
    if not encoding_schema then
        Opcodes.init()
    end
    return encoding_schema
end

function Opcodes.generateDispatcherCode()
    if not opcode_map then
        Opcodes.init()
    end
    
    local cases = {}
    
    local entries = {}
    for name, value in pairs(opcode_map) do
        entries[#entries + 1] = {name = name, value = value}
    end
    entries = Engine.shuffle(entries)
    
    for _, entry in ipairs(entries) do
        cases[#cases + 1] = {
            value = entry.value,
            name = entry.name,
        }
    end
    
    return cases
end

function Opcodes.reset()
    opcode_map = nil
    reverse_map = nil
    dummy_opcodes = nil
    encoding_schema = nil
end

return Opcodes
