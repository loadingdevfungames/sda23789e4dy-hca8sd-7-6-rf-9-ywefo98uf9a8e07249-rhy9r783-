--[[
    lua.rip - Core Cryptographic Primitives
    CSPRNG, key derivation, and encryption utilities
]]

local SHA256 = require("src.lib.sha256")
local Bit = require("src.lib.bit")

local Crypto = {}

local bxor = Bit.bxor
local band = Bit.band
local lshift = Bit.lshift
local rshift = Bit.rshift

local state = {}
local state_index = 0

function Crypto.init(seed)
    seed = seed or (os.time() * 1000 + os.clock() * 1000000)
    
    local seed_str = tostring(seed) .. tostring(os.time()) .. tostring(os.clock())
    
    if _VERSION then
        seed_str = seed_str .. _VERSION
    end
    
    local hash = SHA256.hash(seed_str)
    
    for i = 1, 8 do
        local b1, b2, b3, b4 = hash:byte((i-1)*4+1, i*4)
        state[i] = lshift(b1, 24) + lshift(b2, 16) + lshift(b3, 8) + b4
    end
    state_index = 0
    
    for _ = 1, 16 do
        Crypto.random()
    end
    
    return Crypto
end

function Crypto.random()
    state_index = state_index + 1
    
    if state_index > 8 then
        local combined = ""
        for i = 1, 8 do
            combined = combined .. string.char(
                band(rshift(state[i], 24), 0xFF),
                band(rshift(state[i], 16), 0xFF),
                band(rshift(state[i], 8), 0xFF),
                band(state[i], 0xFF)
            )
        end
        
        local new_hash = SHA256.hash(combined .. tostring(os.clock()))
        
        for i = 1, 8 do
            local b1, b2, b3, b4 = new_hash:byte((i-1)*4+1, i*4)
            state[i] = lshift(b1, 24) + lshift(b2, 16) + lshift(b3, 8) + b4
        end
        state_index = 1
    end
    
    local result = state[state_index]
    state[state_index] = band(result * 1103515245 + 12345, 0xFFFFFFFF)
    
    return result
end

function Crypto.randomRange(min, max)
    local range = max - min + 1
    local random_value = Crypto.random()
    return min + (random_value % range)
end

function Crypto.randomFloat()
    return Crypto.random() / 0xFFFFFFFF
end

function Crypto.randomBytes(length)
    local bytes = {}
    for i = 1, length do
        bytes[i] = string.char(Crypto.randomRange(0, 255))
    end
    return table.concat(bytes)
end

function Crypto.deriveKey(master, context, length)
    length = length or 32
    
    local derived = ""
    local counter = 0
    
    while #derived < length do
        counter = counter + 1
        local input = master .. context .. string.char(counter)
        derived = derived .. SHA256.hash(input)
    end
    
    return derived:sub(1, length)
end

function Crypto.xorEncrypt(data, key)
    local result = {}
    local key_len = #key
    
    for i = 1, #data do
        local key_byte = key:byte(((i - 1) % key_len) + 1)
        local data_byte = data:byte(i)
        result[i] = string.char(bxor(data_byte, key_byte))
    end
    
    return table.concat(result)
end

Crypto.xorDecrypt = Crypto.xorEncrypt

function Crypto.rc4Init(key)
    local S = {}
    for i = 0, 255 do
        S[i] = i
    end
    
    local j = 0
    local key_len = #key
    for i = 0, 255 do
        j = (j + S[i] + key:byte((i % key_len) + 1)) % 256
        S[i], S[j] = S[j], S[i]
    end
    
    return { S = S, i = 0, j = 0 }
end

function Crypto.rc4Process(state, data)
    local S = state.S
    local i = state.i
    local j = state.j
    local result = {}
    
    for k = 1, #data do
        i = (i + 1) % 256
        j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        local K = S[(S[i] + S[j]) % 256]
        result[k] = string.char(bxor(data:byte(k), K))
    end
    
    state.i = i
    state.j = j
    
    return table.concat(result)
end

function Crypto.encrypt(data, key)
    local iv = Crypto.randomBytes(16)
    local full_key = SHA256.hash(key .. iv)
    local rc4_state = Crypto.rc4Init(full_key)
    local encrypted = Crypto.rc4Process(rc4_state, data)
    return iv .. encrypted
end

function Crypto.decrypt(data, key)
    local iv = data:sub(1, 16)
    local encrypted = data:sub(17)
    local full_key = SHA256.hash(key .. iv)
    local rc4_state = Crypto.rc4Init(full_key)
    return Crypto.rc4Process(rc4_state, encrypted)
end

function Crypto.base64Encode(data)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    local padding = (3 - #data % 3) % 3
    data = data .. string.rep("\0", padding)
    
    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        local n = lshift(b1, 16) + lshift(b2, 8) + b3
        
        result[#result + 1] = alphabet:sub(rshift(n, 18) % 64 + 1, rshift(n, 18) % 64 + 1)
        result[#result + 1] = alphabet:sub(rshift(n, 12) % 64 + 1, rshift(n, 12) % 64 + 1)
        result[#result + 1] = alphabet:sub(rshift(n, 6) % 64 + 1, rshift(n, 6) % 64 + 1)
        result[#result + 1] = alphabet:sub(n % 64 + 1, n % 64 + 1)
    end
    
    for i = 1, padding do
        result[#result - i + 1] = "="
    end
    
    return table.concat(result)
end

function Crypto.base64Decode(data)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, 64 do
        lookup[alphabet:sub(i, i)] = i - 1
    end
    lookup["="] = 0
    
    local result = {}
    
    for i = 1, #data, 4 do
        local c1, c2, c3, c4 = data:sub(i, i), data:sub(i+1, i+1), data:sub(i+2, i+2), data:sub(i+3, i+3)
        local n = lshift(lookup[c1] or 0, 18) + lshift(lookup[c2] or 0, 12) + lshift(lookup[c3] or 0, 6) + (lookup[c4] or 0)
        
        result[#result + 1] = string.char(rshift(n, 16) % 256)
        if c3 ~= "=" then
            result[#result + 1] = string.char(rshift(n, 8) % 256)
        end
        if c4 ~= "=" then
            result[#result + 1] = string.char(n % 256)
        end
    end
    
    return table.concat(result)
end

Crypto.init()

return Crypto
