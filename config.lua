--[[
    lua.rip - Configuration System
    Security profiles and obfuscation settings
]]

local Config = {}

local settings = {}
local current_profile = "balanced"

local PROFILES = {
    speed = {
        Polymorphic = {
            Enabled = true,
            NameStyle = "random",
            NameLength = 20,
            ExpressionComplexity = 1,
        },
        Strings = {
            Enabled = true,
            Method = "xor",
            MultiLayer = false,
            ChunkSplit = false,
        },
        Numbers = {
            Enabled = true,
            MBAComplexity = 1,
            EnvironmentDependent = false,
        },
        ControlFlow = {
            Enabled = false,
            FakeStates = 0,
            OpaquePredicates = false,
        },
        VM = {
            Enabled = false,
        },
        AntiDebug = {
            Enabled = false,
        },
        AntiTamper = {
            Enabled = false,
        },
        JunkCode = {
            Enabled = false, -- Truly minimal for speed profile
            Density = 0.1,
            JunkYard = false,
        },
    },
    
    balanced = {
        Polymorphic = {
            Enabled = true,
            NameStyle = "mixed",
            NameLength = 40,
            ExpressionComplexity = 2,
        },
        Strings = {
            Enabled = true,
            Method = "multilayer",
            MultiLayer = true,
            ChunkSplit = true,
            ChunkCount = 4,
        },
        Numbers = {
            Enabled = true,
            MBAComplexity = 2,
            EnvironmentDependent = false,
        },
        ControlFlow = {
            Enabled = true,
            FakeStates = 10,
            OpaquePredicates = true,
            StateEncryption = false,
        },
        VM = {
            Enabled = true,
            OpcodeRandomization = true,
            InstructionChaining = false,
            DummyOpcodes = 5,
        },
        AntiDebug = {
            Enabled = true,
            SubtleFailure = true,
            TimingChecks = false,
        },
        AntiTamper = {
            Enabled = true,
            IntegrityHash = true,
        },
        JunkCode = {
            Enabled = true,
            Density = 0.3,
        },
    },
    
    maximum = {
        Polymorphic = {
            Enabled = true,
            NameStyle = "mixed",
            NameLength = 60,
            ExpressionComplexity = 3,
        },
        Strings = {
            Enabled = true,
            Method = "multilayer",
            MultiLayer = true,
            ChunkSplit = true,
            ChunkCount = 8,
            TableStorage = true,
        },
        Numbers = {
            Enabled = true,
            MBAComplexity = 3,
            EnvironmentDependent = true,
        },
        ControlFlow = {
            Enabled = true,
            FakeStates = 30,
            OpaquePredicates = true,
            StateEncryption = true,
        },
        VM = {
            Enabled = true,
            OpcodeRandomization = true,
            InstructionChaining = true,
            DummyOpcodes = 15,
            VariableLengthEncoding = true,
            StateObfuscation = true,
        },
        AntiDebug = {
            Enabled = true,
            SubtleFailure = true,
            TimingChecks = true,
            EnvironmentChecks = true,
            ContinuousMonitoring = true,
        },
        AntiTamper = {
            Enabled = true,
            IntegrityHash = true,
            SelfModifying = true,
        },
        JunkCode = {
            Enabled = true,
            Density = 0.5,
        },
        Binding = {
            LuaVersion = false,
            TimeExpiration = false,
        },
    },

    luasec = {
        Polymorphic = {
            Enabled = true,
            NameStyle = "mixed",
            NameLength = 50,
            ExpressionComplexity = 2,
        },
        Strings = {
            Enabled = true,
            Method = "multilayer",
            MultiLayer = true,
            ChunkSplit = true,
            ChunkCount = 6,
        },
        Numbers = {
            Enabled = true,
            MBAComplexity = 2,
            EnvironmentDependent = true,
        },
        ControlFlow = {
            Enabled = true,
            FakeStates = 20,
            OpaquePredicates = true,
            StateEncryption = true,
        },
        VM = {
            Enabled = true,
            OpcodeRandomization = true,
            InstructionChaining = false,
            DummyOpcodes = 10,
        },
        AntiDebug = {
            Enabled = true,
            SubtleFailure = true,
            TimingChecks = true,
            EnvironmentChecks = true,
        },
        AntiTamper = {
            Enabled = true,
            IntegrityHash = true,
            SelfModifying = true,
            SeparateChecks = true, -- Signals aggressive separation
        },
        JunkCode = {
            Enabled = true,
            Density = 0.4,
            JunkYard = true,
            JunkYardChunks = 5, -- 5 * 10 * 1000 = ~50k lines
        },
    },
}

local function deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

local function mergeTables(base, override)
    local result = deepCopy(base)
    for k, v in pairs(override) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = mergeTables(result[k], v)
        else
            result[k] = deepCopy(v)
        end
    end
    return result
end

function Config.setProfile(profile_name)
    if not PROFILES[profile_name] then
        error("Unknown profile: " .. tostring(profile_name))
    end
    current_profile = profile_name
    settings = deepCopy(PROFILES[profile_name])
    return Config
end

function Config.getProfile()
    return current_profile
end

function Config.get(path)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    
    local value = settings
    for _, part in ipairs(parts) do
        if type(value) ~= 'table' then
            return nil
        end
        value = value[part]
    end
    
    return value
end

function Config.set(path, value)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    
    local target = settings
    for i = 1, #parts - 1 do
        if type(target[parts[i]]) ~= 'table' then
            target[parts[i]] = {}
        end
        target = target[parts[i]]
    end
    
    target[parts[#parts]] = value
    return Config
end

function Config.override(overrides)
    settings = mergeTables(settings, overrides)
    return Config
end

function Config.getAll()
    return deepCopy(settings)
end

function Config.reset()
    Config.setProfile(current_profile)
    return Config
end

function Config.isEnabled(feature)
    local enabled = Config.get(feature .. ".Enabled")
    return enabled == true
end

function Config.getProfiles()
    local names = {}
    for name in pairs(PROFILES) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

Config.setProfile("balanced")

return Config
