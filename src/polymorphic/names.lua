--[[
    lua.rip - Polymorphic Name Generator
    Generates cryptographically random, unique identifiers
]]

local Crypto = require("src.core.crypto")

local Names = {}

local used_names = {}
local name_counter = 0

local CHARSET_ALPHA_LOWER = "abcdefghijklmnopqrstuvwxyz"
local CHARSET_ALPHA_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local CHARSET_NUMERIC = "0123456789"
local CHARSET_UNDERSCORE = "_"

local CHARSET_FIRST = CHARSET_ALPHA_LOWER .. CHARSET_ALPHA_UPPER .. CHARSET_UNDERSCORE
local CHARSET_REST = CHARSET_FIRST .. CHARSET_NUMERIC

local CONFUSING_CHARS = {
    {"l", "I", "1"},
    {"O", "0"},
    {"S", "5"},
    {"B", "8"},
    {"Z", "2"},
}

local LUA_KEYWORDS = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
    ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
    ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
    ["while"] = true, ["goto"] = true, ["continue"] = true,
}

function Names.reset()
    used_names = {}
    name_counter = 0
end

function Names.generateRandom(min_length, max_length)
    min_length = min_length or 40
    max_length = max_length or 60
    
    local length = Crypto.randomRange(min_length, max_length)
    local chars = {}
    
    local first_idx = Crypto.randomRange(1, #CHARSET_FIRST)
    chars[1] = CHARSET_FIRST:sub(first_idx, first_idx)
    
    for i = 2, length do
        local idx = Crypto.randomRange(1, #CHARSET_REST)
        chars[i] = CHARSET_REST:sub(idx, idx)
    end
    
    return table.concat(chars)
end

function Names.generateConfusing(length)
    length = length or Crypto.randomRange(30, 50)
    
    local chars = {}
    local confusing_set = {}
    
    for _, group in ipairs(CONFUSING_CHARS) do
        for _, char in ipairs(group) do
            confusing_set[#confusing_set + 1] = char
        end
    end
    
    local first_char = confusing_set[Crypto.randomRange(1, #confusing_set)]
    while first_char:match("%d") do
        first_char = confusing_set[Crypto.randomRange(1, #confusing_set)]
    end
    chars[1] = first_char
    
    for i = 2, length do
        chars[i] = confusing_set[Crypto.randomRange(1, #confusing_set)]
    end
    
    return table.concat(chars)
end

function Names.generateUnderscored(segments)
    segments = segments or Crypto.randomRange(4, 8)
    
    local parts = {}
    for i = 1, segments do
        local seg_len = Crypto.randomRange(2, 6)
        local seg = {}
        
        local first_idx = Crypto.randomRange(1, #CHARSET_ALPHA_LOWER)
        seg[1] = CHARSET_ALPHA_LOWER:sub(first_idx, first_idx)
        
        for j = 2, seg_len do
            local charset = (Crypto.randomFloat() < 0.3) and CHARSET_NUMERIC or 
                           (Crypto.randomFloat() < 0.5) and CHARSET_ALPHA_UPPER or 
                           CHARSET_ALPHA_LOWER
            local idx = Crypto.randomRange(1, #charset)
            seg[j] = charset:sub(idx, idx)
        end
        
        parts[i] = table.concat(seg)
    end
    
    return table.concat(parts, "_")
end

function Names.generateHex(length)
    length = length or Crypto.randomRange(16, 32)
    
    local hex_chars = "0123456789abcdef"
    local prefix_chars = "abcdef"
    local chars = {}
    
    local first_idx = Crypto.randomRange(1, #prefix_chars)
    chars[1] = prefix_chars:sub(first_idx, first_idx)
    
    for i = 2, length do
        local idx = Crypto.randomRange(1, #hex_chars)
        chars[i] = hex_chars:sub(idx, idx)
    end
    
    return table.concat(chars)
end

function Names.generateMixed(length)
    length = length or Crypto.randomRange(35, 55)
    
    local generators = {
        function() return Names.generateRandom(length, length) end,
        function() return Names.generateConfusing(length) end,
        function() return Names.generateUnderscored() end,
        function() return Names.generateHex(length) end,
    }
    
    local idx = Crypto.randomRange(1, #generators)
    return generators[idx]()
end

function Names.generate(style, length)
    local name
    local attempts = 0
    local max_attempts = 100
    
    repeat
        attempts = attempts + 1
        
        if style == "random" then
            name = Names.generateRandom(length, length)
        elseif style == "confusing" then
            name = Names.generateConfusing(length)
        elseif style == "underscored" then
            name = Names.generateUnderscored()
        elseif style == "hex" then
            name = Names.generateHex(length)
        else
            name = Names.generateMixed(length)
        end
        
        if LUA_KEYWORDS[name] or used_names[name] then
            name = nil
        end
        
    until name or attempts >= max_attempts
    
    if not name then
        name_counter = name_counter + 1
        name = "_rip_" .. name_counter .. "_" .. Names.generateRandom(20, 30)
    end
    
    used_names[name] = true
    return name
end

function Names.generateMany(count, style, length)
    local names = {}
    for i = 1, count do
        names[i] = Names.generate(style, length)
    end
    return names
end

function Names.generateTable(keys, style, length)
    local name_map = {}
    for _, key in ipairs(keys) do
        name_map[key] = Names.generate(style, length)
    end
    return name_map
end

function Names.isUsed(name)
    return used_names[name] == true
end

function Names.reserve(name)
    used_names[name] = true
end

function Names.getStats()
    local count = 0
    for _ in pairs(used_names) do
        count = count + 1
    end
    return {
        used = count,
        counter = name_counter
    }
end

return Names
