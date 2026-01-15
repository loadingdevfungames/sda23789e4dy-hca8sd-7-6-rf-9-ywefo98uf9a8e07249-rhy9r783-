--[[
    lua.rip - Multi-Key Derivation System
    Generates unique encryption keys for different components
]]

local SHA256 = require("src.lib.sha256")
local Crypto = require("src.core.crypto")

local Keys = {}

local master_key = nil
local derived_keys = {}
local key_counter = 0

local KEY_CONTEXTS = {
    STRINGS = "lua.rip.strings.v1",
    NUMBERS = "lua.rip.numbers.v1",
    BYTECODE = "lua.rip.bytecode.v1",
    VM_INSTRUCTIONS = "lua.rip.vm.instructions.v1",
    STATE_TABLE = "lua.rip.state.v1",
    CONTROL_FLOW = "lua.rip.controlflow.v1",
    INTEGRITY = "lua.rip.integrity.v1",
    SESSION = "lua.rip.session.v1",
}

function Keys.init(source_code, custom_seed)
    local seed_parts = {}
    
    seed_parts[#seed_parts + 1] = tostring(os.time())
    seed_parts[#seed_parts + 1] = tostring(os.clock())
    seed_parts[#seed_parts + 1] = tostring(math.random(0, 2147483647))
    
    if source_code then
        seed_parts[#seed_parts + 1] = SHA256.hex(source_code)
    end
    
    if custom_seed then
        seed_parts[#seed_parts + 1] = tostring(custom_seed)
    end
    
    if _VERSION then
        seed_parts[#seed_parts + 1] = _VERSION
    end
    
    seed_parts[#seed_parts + 1] = tostring(collectgarbage("count"))
    
    local combined = table.concat(seed_parts, "|")
    master_key = SHA256.hash(combined)
    
    derived_keys = {}
    key_counter = 0
    
    Crypto.init(Keys.toNumber(master_key))
    
    return Keys
end

function Keys.getMaster()
    if not master_key then
        Keys.init()
    end
    return master_key
end

function Keys.derive(context, length)
    length = length or 32
    
    if not master_key then
        Keys.init()
    end
    
    local cache_key = context .. "_" .. length
    if derived_keys[cache_key] then
        return derived_keys[cache_key]
    end
    
    local derived = Crypto.deriveKey(master_key, context, length)
    derived_keys[cache_key] = derived
    
    return derived
end

function Keys.getStringKey()
    return Keys.derive(KEY_CONTEXTS.STRINGS, 32)
end

function Keys.getNumberKey()
    return Keys.derive(KEY_CONTEXTS.NUMBERS, 32)
end

function Keys.getBytecodeKey()
    return Keys.derive(KEY_CONTEXTS.BYTECODE, 32)
end

function Keys.getVMKey()
    return Keys.derive(KEY_CONTEXTS.VM_INSTRUCTIONS, 32)
end

function Keys.getStateKey()
    return Keys.derive(KEY_CONTEXTS.STATE_TABLE, 32)
end

function Keys.getControlFlowKey()
    return Keys.derive(KEY_CONTEXTS.CONTROL_FLOW, 32)
end

function Keys.getIntegrityKey()
    return Keys.derive(KEY_CONTEXTS.INTEGRITY, 32)
end

function Keys.generateSessionKey()
    key_counter = key_counter + 1
    local context = KEY_CONTEXTS.SESSION .. "." .. key_counter .. "." .. tostring(os.clock())
    return Keys.derive(context, 32)
end

function Keys.evolve(current_key, step)
    step = step or 1
    local evolved = current_key
    for _ = 1, step do
        evolved = SHA256.hash(evolved .. "evolve")
    end
    return evolved
end

function Keys.toNumber(key)
    local n = 0
    for i = 1, math.min(#key, 4) do
        n = n * 256 + key:byte(i)
    end
    return n
end

function Keys.toHex(key)
    local hex = {}
    for i = 1, #key do
        hex[i] = string.format("%02x", key:byte(i))
    end
    return table.concat(hex)
end

function Keys.fromHex(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = string.char(tonumber(hex:sub(i, i + 1), 16))
    end
    return table.concat(bytes)
end

function Keys.split(key, parts)
    parts = parts or 4
    local part_len = math.ceil(#key / parts)
    local result = {}
    
    for i = 1, parts do
        local start_pos = (i - 1) * part_len + 1
        local end_pos = math.min(i * part_len, #key)
        result[i] = key:sub(start_pos, end_pos)
    end
    
    return result
end

function Keys.combine(parts)
    return table.concat(parts)
end

function Keys.xorKeys(key1, key2)
    local result = {}
    local len = math.max(#key1, #key2)
    
    for i = 1, len do
        local b1 = key1:byte(((i - 1) % #key1) + 1)
        local b2 = key2:byte(((i - 1) % #key2) + 1)
        result[i] = string.char(Crypto.bxor and Crypto.bxor(b1, b2) or ((b1 + b2) % 256))
    end
    
    return table.concat(result)
end

function Keys.getInfo()
    local count = 0
    for _ in pairs(derived_keys) do
        count = count + 1
    end
    
    return {
        initialized = master_key ~= nil,
        derived_count = count,
        session_count = key_counter,
    }
end

function Keys.reset()
    master_key = nil
    derived_keys = {}
    key_counter = 0
end

return Keys
