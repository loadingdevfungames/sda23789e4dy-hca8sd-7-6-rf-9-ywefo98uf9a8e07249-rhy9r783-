--[[
    lua.rip - The World's Most Advanced Lua Obfuscator
    
    Usage:
        lua lua.rip.lua <input.lua> [output.lua] [--profile speed|balanced|maximum]
    
    Examples:
        lua lua.rip.lua script.lua
        lua lua.rip.lua script.lua obfuscated.lua
        lua lua.rip.lua script.lua --profile maximum
]]

local function getScriptPath()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("^@(.+)") or info.source
    return path:match("(.+)[/\\][^/\\]+$") or "."
end

local script_path = getScriptPath()
package.path = script_path .. "/?.lua;" .. 
               script_path .. "/src/?.lua;" .. 
               script_path .. "/src/?/init.lua;" .. 
               package.path

local Config = require("config")
local Pipeline = require("src.core.pipeline")
local Engine = require("src.polymorphic.engine")

local VERSION = "1.0.0"
local BANNER = [[
  _                          
 | |  _   _  _  __      _ _  (_) _ __ 
 | | | | | |/ _` |     | |_) | || '_ \
 | |_| |_| | (_| /     |_ <| || |_) |
 |___||_____\__,_\ .   |_| \_\_|| .__/
                                |_|   
  The World's Most Advanced Lua Obfuscator
  Version ]] .. VERSION .. [[

]]

local function printBanner()
    print(BANNER)
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then
        return nil, "Could not open file: " .. path
    end
    
    local content = file:read("*all")
    file:close()
    
    return content
end

local function writeFile(path, content)
    local file = io.open(path, "wb")
    if not file then
        return false, "Could not write to file: " .. path
    end
    
    file:write(content)
    file:close()
    
    return true
end

local function parseArgs(args)
    local options = {
        input = nil,
        output = nil,
        profile = "balanced",
        help = false,
        vm = false,
        junk_yard = false,
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "--help" or arg == "-h" then
            options.help = true
        elseif arg == "--profile" or arg == "-p" then
            i = i + 1
            if args[i] then
                options.profile = args[i]
            end
        elseif arg == "--preset-luasec" then
            options.profile = "luasec"
        elseif arg == "--vm" then
            options.vm = true
        elseif arg == "--junk-yard" then
            options.junk_yard = true
        elseif arg:sub(1, 2) == "--" then
            -- Unknown option, ignore
        elseif not options.input then
            options.input = arg
        elseif not options.output then
            options.output = arg
        end
        
        i = i + 1
    end
    
    if options.input and not options.output then
        options.output = options.input:gsub("%.lua$", "") .. ".obf.lua"
    end
    
    return options
end

local function printUsage()
    print([[
Usage: lua lua.rip.lua <input.lua> [output.lua] [options]

Options:
    --help, -h          Show this help message
    --profile, -p       Set security profile (speed, balanced, maximum, luasec)
    --preset-luasec     Shortcut for luasec profile (50k junk + anti-tamper)
    --vm                Enable VM-based protection
    --junk-yard         Add 100k+ lines of trash code (file size bloat)

Profiles:
    speed      - Light obfuscation, fast execution
    balanced   - Medium obfuscation, good protection (default)
    maximum    - Extreme obfuscation, maximum security
    luasec     - Optimized 50k lines junk + aggressive protection

Examples:
    lua lua.rip.lua script.lua
    lua lua.rip.lua script.lua output.lua --profile maximum
    lua lua.rip.lua script.lua --vm --profile balanced
]])
end

local function validateProfile(profile)
    local valid_profiles = {"speed", "balanced", "maximum", "luasec"}
    for _, p in ipairs(valid_profiles) do
        if p == profile then
            return true
        end
    end
    return false
end

local function main(args)
    local options = parseArgs(args)
    
    if options.help or not options.input then
        printBanner()
        printUsage()
        return
    end
    
    printBanner()
    
    if not validateProfile(options.profile) then
        print("Error: Invalid profile '" .. options.profile .. "'")
        print("Valid profiles: speed, balanced, maximum")
        return
    end
    
    print("Input:   " .. options.input)
    print("Output:  " .. options.output)
    print("Profile: " .. options.profile)
    if options.vm then
        print("VM:      Enabled")
    end
    if options.junk_yard then
        print("JunkYard: Enabled (Adding ~100k lines of trash)")
    end
    print("")
    
    local source, err = readFile(options.input)
    if not source then
        print("Error: " .. err)
        return
    end
    
    print("Source size: " .. #source .. " bytes")
    print("Processing...")
    print("")
    
    local start_time = os.clock()
    
    
    local obfuscated
    
    -- Configure before processing to ensure overrides (like JunkYard) persist
    Config.setProfile(options.profile)
    if options.junk_yard then
        Config.set("JunkCode.JunkYard", true)
    end

    if options.vm then
        obfuscated = Pipeline.processWithVM(source)
    else
        obfuscated = Pipeline.process(source)
    end
    
    local end_time = os.clock()
    local elapsed = end_time - start_time
    
    local ok, write_err = writeFile(options.output, obfuscated)
    if not ok then
        print("Error: " .. write_err)
        return
    end
    
    print("Success!")
    print("")
    print("Statistics:")
    print("  Original size:   " .. #source .. " bytes")
    print("  Obfuscated size: " .. #obfuscated .. " bytes")
    print("  Size ratio:      " .. string.format("%.2fx", #obfuscated / #source))
    print("  Processing time: " .. string.format("%.3f", elapsed) .. "s")
    print("  Build ID:        " .. (Engine.getBuildId() or "N/A"))
    print("")
    print("Output saved to: " .. options.output)
end

if arg then
    main(arg)
else
    main({...})
end

return {
    Pipeline = Pipeline,
    Config = Config,
    Engine = Engine,
    VERSION = VERSION,
}
