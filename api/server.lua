local Pegasus = require('pegasus')
local json = require('dkjson')

local PORT = 11081
local MASTER_KEY = os.getenv("MASTER_KEY") or "LUASEC.CC"

-- Create storage directory if missing
os.execute("mkdir api/temp 2>/dev/null || mkdir api\\temp 2>nul")

local function get_body(request)
    local body = request:receive_body()
    if not body then return nil end
    return json.decode(body)
end

local function response_json(res, status, data)
    res:add_header('Content-Type', 'application/json')
    res:status(status):write(json.encode(data))
end

local server = Pegasus:new({
    port = PORT,
    location = 'api/temp' -- For static file serving if pegasus supports it, 
                          -- otherwise we handle it in the handler
})

server:start(function(req, res)
    local path = req:path()
    local method = req:method()
    
    -- Master Key Auth
    local auth = req:header('Authorization')
    if path == '/obfuscate' and (not auth or auth ~= "Bearer " .. MASTER_KEY) then
        return response_json(res, 401, { error = "Unauthorized" })
    end

    -- Static File Serving (/files/lua/...)
    if path:match("^/files/lua/") then
        local filename = path:gsub("^/files/lua/", "")
        local filepath = "api/temp/" .. filename
        local f = io.open(filepath, "r")
        if f then
            local content = f:read("*all")
            f:close()
            res:add_header('Content-Type', 'text/plain')
            res:status(200):write(content)
            return
        else
            return response_json(res, 404, { error = "File not found" })
        end
    end

    -- Endpoints
    if path == '/status' then
        return response_json(res, 200, { status = "online", engine = "lua.rip v2.0", port = PORT })
    elseif path == '/type' then
        return response_json(res, 200, { type = "lua_dockerized_api" })
    elseif path == '/features' then
        return response_json(res, 200, {
            presets = {"speed", "balanced", "maximum", "luasec"},
            options = {"vm", "junk_yard", "anti_tamper"}
        })
    elseif path == '/obfuscate' and method == 'POST' then
        local data = get_body(req)
        if not data or not data.script then
            return response_json(res, 400, { error = "No script provided" })
        end

        local run_id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
        local input_file = "api/temp/" .. run_id .. ".in.lua"
        local output_file = "api/temp/" .. run_id .. ".lua"

        -- Save input
        local f = io.open(input_file, "w")
        f:write(data.script)
        f:close()

        -- Build Command
        local cmd = "lua lua.rip.lua \"" .. input_file .. "\" \"" .. output_file .. "\""
        
        if data.profile == 'luasec' or (data.options and data.options.preset == 'luasec') then
            cmd = cmd .. " --preset-luasec"
        else
            local profile = data.profile or "balanced"
            cmd = cmd .. " --profile " .. profile
        end

        if data.options then
            if data.options.vm then cmd = cmd .. " --vm" end
            if data.options.junk_yard then cmd = cmd .. " --junk-yard" end
        end

        print("Processing job " .. run_id .. "...")
        local success_exec = os.execute(cmd)

        if io.open(output_file, "r") then
            -- Success
            local host = req:header('Host') or "localhost:" .. PORT
            local protocol = "http" -- Default
            local file_url = protocol .. "://" .. host .. "/files/lua/" .. run_id .. ".lua"
            
            response_json(res, 200, {
                success = true,
                url = file_url,
                run_id = run_id
            })
            
            -- Simple cleanup of input
            os.remove(input_file)
        else
            response_json(res, 500, { error = "Obfuscation failed" })
            os.remove(input_file)
        end
    else
        response_json(res, 404, { error = "Route not found" })
    end
end)
