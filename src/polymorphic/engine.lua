--[[
    lua.rip - Polymorphic Engine Core
    Coordinates all polymorphic transformations
]]

local Crypto = require("src.core.crypto")
local Names = require("src.polymorphic.names")
local Expressions = require("src.polymorphic.expressions")
local Keys = require("src.polymorphic.keys")

local Engine = {}

local initialized = false
local build_id = nil

function Engine.init(source_code, custom_seed)
    Keys.init(source_code, custom_seed)
    
    Names.reset()
    
    build_id = string.format("%08x%08x", 
        Crypto.random(), 
        Crypto.random()
    )
    
    initialized = true
    
    return Engine
end

function Engine.isInitialized()
    return initialized
end

function Engine.getBuildId()
    return build_id
end

function Engine.generateName(style, length)
    if not initialized then
        Engine.init()
    end
    return Names.generate(style, length)
end

function Engine.generateNames(count, style, length)
    if not initialized then
        Engine.init()
    end
    return Names.generateMany(count, style, length)
end

function Engine.obfuscateNumber(n, complexity)
    if not initialized then
        Engine.init()
    end
    return Expressions.obfuscateNumber(n, complexity)
end

function Engine.obfuscateString(s, complexity)
    if not initialized then
        Engine.init()
    end
    return Expressions.obfuscateString(s, complexity)
end

function Engine.generateOpaqueTrue()
    return Expressions.generateOpaqueTrue()
end

function Engine.generateOpaqueFalse()
    return Expressions.generateOpaqueFalse()
end

function Engine.wrapInCondition(code, always_execute)
    return Expressions.wrapInCondition(code, always_execute)
end

function Engine.getKey(context)
    if context == "strings" then
        return Keys.getStringKey()
    elseif context == "numbers" then
        return Keys.getNumberKey()
    elseif context == "bytecode" then
        return Keys.getBytecodeKey()
    elseif context == "vm" then
        return Keys.getVMKey()
    elseif context == "state" then
        return Keys.getStateKey()
    elseif context == "controlflow" then
        return Keys.getControlFlowKey()
    elseif context == "integrity" then
        return Keys.getIntegrityKey()
    else
        return Keys.generateSessionKey()
    end
end

function Engine.encrypt(data, context)
    local key = Engine.getKey(context or "session")
    return Crypto.encrypt(data, key)
end

function Engine.randomRange(min, max)
    return Crypto.randomRange(min, max)
end

function Engine.randomFloat()
    return Crypto.randomFloat()
end

function Engine.randomBytes(length)
    return Crypto.randomBytes(length)
end

function Engine.randomChoice(options)
    local idx = Crypto.randomRange(1, #options)
    return options[idx]
end

function Engine.shuffle(array)
    local n = #array
    local shuffled = {}
    for i = 1, n do
        shuffled[i] = array[i]
    end
    
    for i = n, 2, -1 do
        local j = Crypto.randomRange(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    
    return shuffled
end

function Engine.generateStateValue()
    return Crypto.randomRange(0x1000, 0xFFFF)
end

function Engine.generateOpcodeValue()
    return Crypto.randomRange(0x00, 0xFF)
end

function Engine.reset()
    initialized = false
    build_id = nil
    Names.reset()
    Keys.reset()
end

function Engine.getStats()
    return {
        initialized = initialized,
        build_id = build_id,
        names = Names.getStats(),
        keys = Keys.getInfo(),
    }
end

return Engine
