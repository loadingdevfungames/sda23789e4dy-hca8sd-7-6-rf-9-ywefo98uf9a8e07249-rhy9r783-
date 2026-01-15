--[[
    lua.rip - Multi-Layer String Encryption
    Advanced string obfuscation with multiple techniques
]]

local Engine = require("src.polymorphic.engine")
local Crypto = require("src.core.crypto")
local Config = require("config")

local Strings = {}

local function xorEncrypt(str, key)
    local result = {}
    for i = 1, #str do
        local byte = str:byte(i)
        local key_byte = key:byte(((i - 1) % #key) + 1)
        result[i] = string.char((byte + key_byte) % 256)
    end
    return table.concat(result)
end

local function splitIntoChunks(str, count)
    local chunks = {}
    local chunk_size = math.ceil(#str / count)
    
    for i = 1, count do
        local start_pos = (i - 1) * chunk_size + 1
        local end_pos = math.min(i * chunk_size, #str)
        if start_pos <= #str then
            chunks[#chunks + 1] = str:sub(start_pos, end_pos)
        end
    end
    
    return chunks
end

function Strings.generateDecryptor()
    local dec_func = Engine.generateName("mixed", 35)
    local key_var = Engine.generateName("mixed", 25)
    local data_var = Engine.generateName("mixed", 25)
    local result_var = Engine.generateName("mixed", 25)
    
    local code = "local function " .. dec_func .. "(" .. data_var .. ", " .. key_var .. ")\n"
    code = code .. "    local " .. result_var .. " = {}\n"
    code = code .. "    for i = 1, #" .. data_var .. " do\n"
    code = code .. "        local b = string.byte(" .. data_var .. ", i)\n"
    code = code .. "        local k = string.byte(" .. key_var .. ", ((i - 1) % #" .. key_var .. ") + 1)\n"
    code = code .. "        " .. result_var .. "[i] = string.char((b - k + 256) % 256)\n"
    code = code .. "    end\n"
    code = code .. "    return table.concat(" .. result_var .. ")\n"
    code = code .. "end\n"
    
    return code, dec_func
end

function Strings.generateChunkAssembler()
    local asm_func = Engine.generateName("mixed", 35)
    local tbl_var = Engine.generateName("mixed", 25)
    local order_var = Engine.generateName("mixed", 25)
    local result_var = Engine.generateName("mixed", 25)
    
    local code = "local function " .. asm_func .. "(" .. tbl_var .. ", " .. order_var .. ")\n"
    code = code .. "    local " .. result_var .. " = {}\n"
    code = code .. "    for i = 1, #" .. order_var .. " do\n"
    code = code .. "        " .. result_var .. "[i] = " .. tbl_var .. "[" .. order_var .. "[i]]\n"
    code = code .. "    end\n"
    code = code .. "    return table.concat(" .. result_var .. ")\n"
    code = code .. "end\n"
    
    return code, asm_func
end

function Strings.obfuscateSimple(str)
    local key = Engine.randomBytes(Engine.randomRange(8, 16))
    local encrypted = xorEncrypt(str, key)
    
    local escaped_data = {}
    for i = 1, #encrypted do
        escaped_data[i] = string.format("\\%d", encrypted:byte(i))
    end
    
    local escaped_key = {}
    for i = 1, #key do
        escaped_key[i] = string.format("\\%d", key:byte(i))
    end
    
    return {
        method = "xor",
        data = table.concat(escaped_data),
        key = table.concat(escaped_key),
    }
end

function Strings.obfuscateChunked(str, chunk_count)
    chunk_count = chunk_count or Config.get("Strings.ChunkCount") or 4
    
    local key = Engine.randomBytes(Engine.randomRange(12, 24))
    local encrypted = xorEncrypt(str, key)
    
    local chunks = splitIntoChunks(encrypted, chunk_count)
    
    local order = {}
    for i = 1, #chunks do
        order[i] = i
    end
    order = Engine.shuffle(order)
    
    local reverse_order = {}
    for new_pos, old_pos in ipairs(order) do
        reverse_order[old_pos] = new_pos
    end
    
    local shuffled_chunks = {}
    for i, idx in ipairs(order) do
        shuffled_chunks[i] = chunks[idx]
    end
    
    local chunk_strings = {}
    for i, chunk in ipairs(shuffled_chunks) do
        local escaped = {}
        for j = 1, #chunk do
            escaped[j] = string.format("\\%d", chunk:byte(j))
        end
        chunk_strings[i] = '"' .. table.concat(escaped) .. '"'
    end
    
    local escaped_key = {}
    for i = 1, #key do
        escaped_key[i] = string.format("\\%d", key:byte(i))
    end
    
    return {
        method = "chunked",
        chunks = chunk_strings,
        order = reverse_order,
        key = table.concat(escaped_key),
    }
end

function Strings.obfuscateCharConcat(str)
    local chars = {}
    for i = 1, #str do
        local byte = str:byte(i)
        local offset = Engine.randomRange(1, 100)
        chars[i] = string.format("string.char(%d - %d)", byte + offset, offset)
    end
    
    return {
        method = "charconcat",
        expression = "(" .. table.concat(chars, " .. ") .. ")",
    }
end

function Strings.generateRuntimeDecryptor()
    local parts = {}
    
    local dec_code, dec_func = Strings.generateDecryptor()
    parts[#parts + 1] = dec_code
    
    local asm_code, asm_func = Strings.generateChunkAssembler()
    parts[#parts + 1] = asm_code
    
    return table.concat(parts, "\n"), {
        decrypt = dec_func,
        assemble = asm_func,
    }
end

function Strings.obfuscate(str, complexity)
    complexity = complexity or (Config.get("Strings.MultiLayer") and 2 or 1)
    
    if #str == 0 then
        return {method = "empty", expression = '""'}
    end
    
    if complexity >= 2 and Config.get("Strings.ChunkSplit") then
        return Strings.obfuscateChunked(str)
    elseif complexity >= 1 then
        return Strings.obfuscateSimple(str)
    else
        return Strings.obfuscateCharConcat(str)
    end
end

function Strings.process(code)
    local decryptor_code, funcs = Strings.generateRuntimeDecryptor()
    
    local processed = code:gsub('(["\'])(.-)%1', function(quote, str)
        if #str == 0 then return quote .. quote end
        
        str = str:gsub('\\n', '\n')
        str = str:gsub('\\t', '\t')
        str = str:gsub('\\r', '\r')
        str = str:gsub('\\"', '"')
        str = str:gsub("\\'", "'")
        str = str:gsub('\\\\', '\\')
        
        local obfuscated = Strings.obfuscate(str)
        
        if obfuscated.method == "xor" then
            return funcs.decrypt .. '("' .. obfuscated.data .. '", "' .. obfuscated.key .. '")'
        elseif obfuscated.method == "chunked" then
            local chunks_str = table.concat(obfuscated.chunks, ",")
            local order_str = table.concat(obfuscated.order, ",")
            return funcs.decrypt .. "(" .. funcs.assemble .. "({" .. chunks_str .. "}, {" .. order_str .. '}), "' .. obfuscated.key .. '")'
        elseif obfuscated.method == "charconcat" then
            return obfuscated.expression
        else
            return quote .. str .. quote
        end
    end)
    
    return decryptor_code .. "\n" .. processed
end

return Strings
