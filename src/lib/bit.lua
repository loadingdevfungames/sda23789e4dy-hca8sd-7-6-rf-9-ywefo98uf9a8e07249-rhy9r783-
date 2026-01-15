--[[
    lua.rip - Bit Operations Library
    Lua 5.1 compatible bit operations
]]

local Bit = {}

local floor = math.floor

local function tobits(n, bits)
    bits = bits or 32
    local result = {}
    for i = bits, 1, -1 do
        result[i] = n % 2
        n = floor(n / 2)
    end
    return result
end

local function frombits(bits)
    local n = 0
    for i = 1, #bits do
        n = n * 2 + bits[i]
    end
    return n
end

function Bit.band(a, b)
    local bits_a = tobits(a)
    local bits_b = tobits(b)
    local result = {}
    for i = 1, 32 do
        result[i] = (bits_a[i] == 1 and bits_b[i] == 1) and 1 or 0
    end
    return frombits(result)
end

function Bit.bor(a, b)
    local bits_a = tobits(a)
    local bits_b = tobits(b)
    local result = {}
    for i = 1, 32 do
        result[i] = (bits_a[i] == 1 or bits_b[i] == 1) and 1 or 0
    end
    return frombits(result)
end

function Bit.bxor(a, b)
    local bits_a = tobits(a)
    local bits_b = tobits(b)
    local result = {}
    for i = 1, 32 do
        result[i] = (bits_a[i] ~= bits_b[i]) and 1 or 0
    end
    return frombits(result)
end

function Bit.bnot(a)
    local bits_a = tobits(a)
    local result = {}
    for i = 1, 32 do
        result[i] = (bits_a[i] == 0) and 1 or 0
    end
    return frombits(result)
end

function Bit.lshift(a, n)
    return floor(a * (2 ^ n)) % 4294967296
end

function Bit.rshift(a, n)
    return floor(a / (2 ^ n)) % 4294967296
end

function Bit.arshift(a, n)
    local shifted = floor(a / (2 ^ n))
    if a >= 2147483648 then
        shifted = shifted + floor((2 ^ n - 1) * (2 ^ (32 - n)))
    end
    return shifted % 4294967296
end

function Bit.rol(a, n)
    n = n % 32
    return Bit.bor(Bit.lshift(a, n), Bit.rshift(a, 32 - n))
end

function Bit.ror(a, n)
    n = n % 32
    return Bit.bor(Bit.rshift(a, n), Bit.lshift(a, 32 - n))
end

function Bit.extract(a, start, len)
    len = len or 1
    return Bit.band(Bit.rshift(a, start), (2 ^ len) - 1)
end

function Bit.replace(a, v, start, len)
    len = len or 1
    local mask = (2 ^ len) - 1
    v = Bit.band(v, mask)
    a = Bit.band(a, Bit.bnot(Bit.lshift(mask, start)))
    return Bit.bor(a, Bit.lshift(v, start))
end

return Bit
