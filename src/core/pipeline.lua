--[[
    lua.rip v2.0 - Main Processing Pipeline
    Multi-layer obfuscation orchestration with advanced junk & anti-tamper
]]

local Config = require("config")
local Engine = require("src.polymorphic.engine")
local Keys = require("src.polymorphic.keys")

local Strings = require("src.obfuscation.strings")
local ControlFlow = require("src.obfuscation.control_flow")
local Junk = require("src.obfuscation.junk")
local AntiDebug = require("src.protection.anti_debug")
local AntiTamper = require("src.protection.anti_tamper")

local Pipeline = {}

function Pipeline.init(source_code, custom_seed)
    Engine.init(source_code, custom_seed)
    return Pipeline
end

function Pipeline.layer1_source_transform(code)
    return code
end

function Pipeline.layer2_string_encryption(code)
    if not Config.isEnabled("Strings") then
        return code
    end
    
    return Strings.process(code)
end

function Pipeline.layer3_control_flow(code)
    if not Config.isEnabled("ControlFlow") then
        return code
    end
    
    return ControlFlow.process(code)
end

function Pipeline.layer4_structure_obfuscation(code)
    -- If JunkYard mode is active, skip standard structure obfuscation to avoid 
    -- register limit issues and syntax errors in complex structures.
    -- The JunkYard layer adds enough junk (100k+ lines) so this is unnecessary.
    if Config.get("JunkCode.JunkYard") then
        return code
    end

    if Config.isEnabled("JunkCode") then
        local density = Config.get("JunkCode.Density") or 0.5
        code = Junk.insertIntoCode(code, density)
    end
    
    return code
end

function Pipeline.layer5_bytecode_compilation(code)
    if not Config.isEnabled("VM") then
        return code
    end
    
    local VMCompiler = require("src.vm.vm_compiler")
    return VMCompiler.compile(code)
end

function Pipeline.layer6_vm_wrapping(code)
    return code
end

local Watermark = require("src.obfuscation.watermark") -- Ensure this is required at top

function Pipeline.layer7_runtime_protection(code)
    if Config.isEnabled("AntiTamper") then
        code = AntiTamper.process(code)
    end
    
    if Config.isEnabled("AntiDebug") then
        code = AntiDebug.process(code)
    end
    
    return code
end

function Pipeline.layer7_5_junkyard(code)
    -- JunkYard is a massive file bloat mode.
    -- It should only trigger if explicitly enabled, NOT just because JunkCode is on.
    if Config.isEnabled("JunkCode") and Config.get("JunkCode.JunkYard") then
        code = Junk.addJunkYard(code)
    end
    return code
end

function Pipeline.stripComments(code)
    local lines = {}
    for line in code:gmatch("([^\r\n]*)\r?\n?") do
        -- Remove full line comments (ignoring whitespace)
        local trimmed = line:match("^%s*(.*)")
        if not (trimmed and trimmed:match("^%-%-")) then
            -- Note: We are preserving the line if it's not JUST a comment.
            -- This is safer than regex stripping which might break strings containing --.
            -- Most generated comments in this project are full-line comments.
             table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

function Pipeline.layer8_watermark(code)
    code = Pipeline.stripComments(code)
    code = Watermark.insert(code)
    return code
end

function Pipeline.generateHeader()
    local build_id = Engine.getBuildId() or "unknown"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local profile = Config.getProfile()
    
    local headers = {
        "-- Protected by lua.rip v2.0 Obfuscator",
        "-- Build: " .. build_id,
        "print(\"lua.rip affiliated with luasec.cc\")",
        "-- luasec",
        "-- lua.rip",
        "-- noob",
        "--",
        "-- This code is protected. Reverse engineering is prohibited.",
        "",
    }
    
    return table.concat(headers, "\n")
end

function Pipeline.process(code, profile)
    if profile then
        Config.setProfile(profile)
    end
    
    Pipeline.init(code)
    
    code = Pipeline.layer1_source_transform(code)
    
    code = Pipeline.layer2_string_encryption(code)
    
    code = Pipeline.layer3_control_flow(code)
    
    code = Pipeline.layer4_structure_obfuscation(code)
    
    code = Pipeline.layer7_runtime_protection(code)

    code = Pipeline.layer7_5_junkyard(code)
    
    code = Pipeline.layer8_watermark(code)
    
    local header = Pipeline.generateHeader()
    code = header .. code
    
    return code
end

function Pipeline.processWithVM(code, profile)
    if profile then
        Config.setProfile(profile)
    end
    
    Pipeline.init(code)
    
    code = Pipeline.layer1_source_transform(code)
    
    code = Pipeline.layer2_string_encryption(code)
    
    code = Pipeline.layer3_control_flow(code)
    
    code = Pipeline.layer4_structure_obfuscation(code)
    
    code = Pipeline.layer5_bytecode_compilation(code)
    
    code = Pipeline.layer6_vm_wrapping(code)
    
    code = Pipeline.layer7_runtime_protection(code)

    code = Pipeline.layer7_5_junkyard(code)
    
    code = Pipeline.layer8_watermark(code)
    
    local header = Pipeline.generateHeader()
    code = header .. code
    
    return code
end

return Pipeline
