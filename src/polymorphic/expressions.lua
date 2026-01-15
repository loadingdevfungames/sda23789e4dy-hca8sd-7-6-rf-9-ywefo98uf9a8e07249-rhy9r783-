--[[
    lua.rip - Expression Variation System
    Multiple equivalent implementations for every operation
]]

local Crypto = require("src.core.crypto")

local Expressions = {}

local number_variants = {}
local string_variants = {}
local operation_variants = {}

function number_variants.identity(n)
    return tostring(n)
end

function number_variants.double_half(n)
    return string.format("((%d * 2) / 2)", n)
end

function number_variants.add_subtract(n)
    local offset = Crypto.randomRange(1, 1000)
    return string.format("(%d + %d - %d)", n, offset, offset)
end

function number_variants.multiply_divide(n)
    local factors = {2, 3, 4, 5, 7, 8, 9, 10, 11, 13}
    local factor = factors[Crypto.randomRange(1, #factors)]
    return string.format("((%d * %d) / %d)", n, factor, factor)
end

function number_variants.xor_xor(n)
    local key = Crypto.randomRange(1, 65535)
    local Bit = require("src.lib.bit")
    local xored = Bit.bxor(n, key)
    return string.format("(bit32 and bit32.bxor(%d, %d) or (function(a,b) local r=0 for i=0,31 do local ba,bb=a%%2,b%%2 if ba~=bb then r=r+2^i end a,b=math.floor(a/2),math.floor(b/2) end return r end)(%d, %d))", xored, key, xored, key)
end

function number_variants.complex_math(n)
    local a = Crypto.randomRange(1, 100)
    local b = Crypto.randomRange(1, 100)
    local c = Crypto.randomRange(1, 100)
    local result = n + a * b - c
    return string.format("(%d - %d * %d + %d)", result, a, b, c)
end

function number_variants.floor_ceil(n)
    local decimal = Crypto.randomFloat() * 0.9
    return string.format("math.floor(%f + 0.5)", n + decimal - 0.5)
end

function number_variants.modulo_chain(n)
    local large = n + Crypto.randomRange(10000, 100000) * 1000
    return string.format("(%d %% %d)", large, large - n + 1) .. " + " .. tostring(n - (large % (large - n + 1)))
end

function number_variants.nested_functions(n)
    return string.format("(function() local x = %d return x end)()", n)
end

function number_variants.table_lookup(n)
    local idx = Crypto.randomRange(1, 10)
    local values = {}
    for i = 1, 10 do
        if i == idx then
            values[i] = n
        else
            values[i] = Crypto.randomRange(-10000, 10000)
        end
    end
    return string.format("({%s})[%d]", table.concat(values, ","), idx)
end

local all_number_variants = {
    number_variants.identity,
    number_variants.double_half,
    number_variants.add_subtract,
    number_variants.multiply_divide,
    number_variants.complex_math,
    number_variants.floor_ceil,
    number_variants.nested_functions,
    number_variants.table_lookup,
}

function Expressions.obfuscateNumber(n, complexity)
    complexity = complexity or 1
    
    if complexity == 0 then
        return tostring(n)
    end
    
    local result = tostring(n)
    
    for _ = 1, complexity do
        local variant = all_number_variants[Crypto.randomRange(2, #all_number_variants)]
        result = variant(n)
        
        local parsed = (loadstring or load)("return " .. result)
        if parsed then
            local ok, val = pcall(parsed)
            if ok and val == n then
                break
            end
        end
        result = tostring(n)
    end
    
    return result
end

function string_variants.char_concat(s)
    local chars = {}
    for i = 1, #s do
        chars[i] = string.format("string.char(%d)", s:byte(i))
    end
    return "(" .. table.concat(chars, "..") .. ")"
end

function string_variants.char_table(s)
    local bytes = {}
    for i = 1, #s do
        bytes[i] = s:byte(i)
    end
    return string.format("(function() local t={%s} local r={} for i=1,#t do r[i]=string.char(t[i]) end return table.concat(r) end)()", table.concat(bytes, ","))
end

function string_variants.reverse_reverse(s)
    return string.format("string.reverse(string.reverse(%q))", s)
end

function string_variants.sub_concat(s)
    if #s < 2 then
        return string.format("%q", s)
    end
    
    local parts = {}
    local pos = 1
    while pos <= #s do
        local chunk_size = Crypto.randomRange(1, math.min(5, #s - pos + 1))
        parts[#parts + 1] = string.format("%q", s:sub(pos, pos + chunk_size - 1))
        pos = pos + chunk_size
    end
    
    return "(" .. table.concat(parts, "..") .. ")"
end

function string_variants.gsub_identity(s)
    return string.format("(string.gsub(%q, '(.)', '%%1'))", s)
end

function string_variants.xor_encrypt(s)
    local key = Crypto.randomRange(1, 255)
    local encrypted = {}
    for i = 1, #s do
        local byte = s:byte(i)
        local xored = (byte >= 0 and byte <= 255) and ((byte + key) % 256) or byte
        encrypted[i] = xored
    end
    
    return string.format("(function() local k=%d local e={%s} local r={} for i=1,#e do r[i]=string.char((e[i]-k)%%256) end return table.concat(r) end)()", key, table.concat(encrypted, ","))
end

function string_variants.base64_like(s)
    local encoded = {}
    for i = 1, #s do
        local b = s:byte(i)
        encoded[i] = string.format("%02x", b)
    end
    local hex = table.concat(encoded)
    
    return string.format("(function() local h='%s' local r={} for i=1,#h,2 do r[#r+1]=string.char(tonumber(h:sub(i,i+1),16)) end return table.concat(r) end)()", hex)
end

local all_string_variants = {
    function(s) return string.format("%q", s) end,
    string_variants.char_concat,
    string_variants.char_table,
    string_variants.reverse_reverse,
    string_variants.sub_concat,
    string_variants.xor_encrypt,
    string_variants.base64_like,
}

function Expressions.obfuscateString(s, complexity)
    complexity = complexity or 1
    
    if complexity == 0 or #s == 0 then
        return string.format("%q", s)
    end
    
    local variant_idx = Crypto.randomRange(2, #all_string_variants)
    return all_string_variants[variant_idx](s)
end

function operation_variants.add(a, b)
    local variants = {
        function() return string.format("(%s + %s)", a, b) end,
        function() return string.format("(%s - (-%s))", a, b) end,
        function() return string.format("(-%s - %s) * -1", a, b) end,
        function() return string.format("((%s * 2 + %s * 2) / 2)", a, b) end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function operation_variants.sub(a, b)
    local variants = {
        function() return string.format("(%s - %s)", a, b) end,
        function() return string.format("(%s + (-%s))", a, b) end,
        function() return string.format("(-(%s - %s) * -1)", a, b) end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function operation_variants.mul(a, b)
    local variants = {
        function() return string.format("(%s * %s)", a, b) end,
        function() return string.format("(-%s * -%s)", a, b) end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function operation_variants.div(a, b)
    local variants = {
        function() return string.format("(%s / %s)", a, b) end,
        function() return string.format("(%s * (1 / %s))", a, b) end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function operation_variants.concat(a, b)
    local variants = {
        function() return string.format("(%s .. %s)", a, b) end,
        function() return string.format("table.concat({%s, %s})", a, b) end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function Expressions.obfuscateOperation(op, a, b)
    local handler = operation_variants[op]
    if handler then
        return handler(a, b)
    end
    return string.format("(%s %s %s)", a, op, b)
end

function Expressions.generateOpaqueTrue()
    local variants = {
        function()
            local x = Crypto.randomRange(1, 1000)
            return string.format("((%d * %d) >= 0)", x, x)
        end,
        function()
            local n = Crypto.randomRange(1, 100)
            return string.format("((%d * (%d + 1)) %% 2 == 0)", n, n)
        end,
        function()
            return "(type(_G) == 'table')"
        end,
        function()
            return "(1 == 1)"
        end,
        function()
            local x = Crypto.randomRange(1, 1000)
            return string.format("(math.abs(%d) == %d)", x, x)
        end,
        function()
            return "('' == '')"
        end,
        function()
            return "(nil == nil)"
        end,
        function()
            local x = Crypto.randomRange(1, 100)
            return string.format("(math.floor(%d.5) == %d)", x, x)
        end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function Expressions.generateOpaqueFalse()
    local variants = {
        function()
            local x = Crypto.randomRange(1, 1000)
            return string.format("((%d * %d) < 0)", x, x)
        end,
        function()
            return "(type(_G) == 'string')"
        end,
        function()
            return "(1 == 0)"
        end,
        function()
            return "(nil ~= nil)"
        end,
        function()
            local x = Crypto.randomRange(1, 1000)
            return string.format("(%d > %d)", x, x)
        end,
    }
    return variants[Crypto.randomRange(1, #variants)]()
end

function Expressions.wrapInCondition(code, always_execute)
    if always_execute then
        return string.format("if %s then\n%s\nend", Expressions.generateOpaqueTrue(), code)
    else
        return string.format("if %s then\n%s\nend", Expressions.generateOpaqueFalse(), code)
    end
end

return Expressions
