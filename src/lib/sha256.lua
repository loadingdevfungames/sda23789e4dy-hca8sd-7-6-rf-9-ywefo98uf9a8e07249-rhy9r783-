--[[
    lua.rip - SHA256 Implementation
    Pure Lua SHA256 for integrity checking and key derivation
]]

local Bit = require("src.lib.bit")

local band = Bit.band
local bor = Bit.bor
local bxor = Bit.bxor
local bnot = Bit.bnot
local rshift = Bit.rshift
local lshift = Bit.lshift
local ror = Bit.ror

local SHA256 = {}

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function preprocess(message)
    local len = #message
    local bits = len * 8
    
    message = message .. string.char(0x80)
    
    local padding = (56 - (len + 1) % 64) % 64
    message = message .. string.rep(string.char(0), padding)
    
    for i = 7, 0, -1 do
        local byte = band(rshift(bits, i * 8), 0xFF)
        message = message .. string.char(byte)
    end
    
    return message
end

local function str_to_u32(s, i)
    local b1, b2, b3, b4 = s:byte(i, i + 3)
    return lshift(b1, 24) + lshift(b2, 16) + lshift(b3, 8) + b4
end

local function u32_to_str(n)
    return string.char(
        band(rshift(n, 24), 0xFF),
        band(rshift(n, 16), 0xFF),
        band(rshift(n, 8), 0xFF),
        band(n, 0xFF)
    )
end

function SHA256.hash(message)
    message = preprocess(message)
    
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    
    for chunk_start = 1, #message, 64 do
        local W = {}
        
        for i = 1, 16 do
            W[i] = str_to_u32(message, chunk_start + (i - 1) * 4)
        end
        
        for i = 17, 64 do
            local s0 = bxor(ror(W[i-15], 7), bxor(ror(W[i-15], 18), rshift(W[i-15], 3)))
            local s1 = bxor(ror(W[i-2], 17), bxor(ror(W[i-2], 19), rshift(W[i-2], 10)))
            W[i] = band(W[i-16] + s0 + W[i-7] + s1, 0xFFFFFFFF)
        end
        
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        
        for i = 1, 64 do
            local S1 = bxor(ror(e, 6), bxor(ror(e, 11), ror(e, 25)))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = band(h + S1 + ch + K[i] + W[i], 0xFFFFFFFF)
            local S0 = bxor(ror(a, 2), bxor(ror(a, 13), ror(a, 22)))
            local maj = bxor(band(a, b), bxor(band(a, c), band(b, c)))
            local temp2 = band(S0 + maj, 0xFFFFFFFF)
            
            h = g
            g = f
            f = e
            e = band(d + temp1, 0xFFFFFFFF)
            d = c
            c = b
            b = a
            a = band(temp1 + temp2, 0xFFFFFFFF)
        end
        
        H[1] = band(H[1] + a, 0xFFFFFFFF)
        H[2] = band(H[2] + b, 0xFFFFFFFF)
        H[3] = band(H[3] + c, 0xFFFFFFFF)
        H[4] = band(H[4] + d, 0xFFFFFFFF)
        H[5] = band(H[5] + e, 0xFFFFFFFF)
        H[6] = band(H[6] + f, 0xFFFFFFFF)
        H[7] = band(H[7] + g, 0xFFFFFFFF)
        H[8] = band(H[8] + h, 0xFFFFFFFF)
    end
    
    local result = ""
    for i = 1, 8 do
        result = result .. u32_to_str(H[i])
    end
    
    return result
end

function SHA256.hex(message)
    local hash = SHA256.hash(message)
    local hex = ""
    for i = 1, #hash do
        hex = hex .. string.format("%02x", hash:byte(i))
    end
    return hex
end

function SHA256.hmac(key, message)
    if #key > 64 then
        key = SHA256.hash(key)
    end
    if #key < 64 then
        key = key .. string.rep(string.char(0), 64 - #key)
    end
    
    local o_key_pad = ""
    local i_key_pad = ""
    for i = 1, 64 do
        local byte = key:byte(i)
        o_key_pad = o_key_pad .. string.char(bxor(byte, 0x5c))
        i_key_pad = i_key_pad .. string.char(bxor(byte, 0x36))
    end
    
    return SHA256.hash(o_key_pad .. SHA256.hash(i_key_pad .. message))
end

return SHA256
