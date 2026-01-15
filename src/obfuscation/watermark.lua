--[[
    lua.rip v2.0 - Watermark System
    Inserts specific watermarks deep into the code
]]

local Engine = require("src.polymorphic.engine")

local Watermark = {}

function Watermark.generate()
    return string.format([[
print("lua.rip affiliated with luasec.cc")
-- luasec
-- lua.rip
-- noob
]])
end

function Watermark.insert(code)
    -- Split code into lines
    local lines = {}
    for line in code:gmatch("([^\r\n]*)\r?\n?") do
        table.insert(lines, line)
    end
    
    -- Find a safe insertion spot (roughly middle, not breaking blocks)
    -- Simply inserting between lines in a safe spot (depth 0) is ideal,
    -- but determining depth purely by line is consistent with other modules.
    
    local safe_indices = {}
    local in_block = 0
    local brace_depth = 0
    
    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        
        -- Token counting for robust block tracking
        -- This handles multi-line and single-line blocks correctly (net change 0 for single-line)
        
        -- Start keywords: function, if, for, while, repeat, do
        local _, c_func = trimmed:gsub("%f[%w]function%f[%W]", "")
        local _, c_if = trimmed:gsub("%f[%w]if%f[%W]", "")
        local _, c_for = trimmed:gsub("%f[%w]for%f[%W]", "")
        local _, c_while = trimmed:gsub("%f[%w]while%f[%W]", "")
        local _, c_repeat = trimmed:gsub("%f[%w]repeat%f[%W]", "")
        local _, c_do = trimmed:gsub("%f[%w]do%f[%W]", "")
        
        in_block = in_block + c_func + c_if + c_for + c_while + c_repeat + c_do
        
        -- End keywords: end, until
        local _, c_end = trimmed:gsub("%f[%w]end%f[%W]", "")
        local _, c_until = trimmed:gsub("%f[%w]until%f[%W]", "")
        
        in_block = in_block - c_end - c_until
        
        -- Check brace depth
        local _, open_braces = trimmed:gsub("{", "")
        local _, close_braces = trimmed:gsub("}", "")
        brace_depth = brace_depth + open_braces - close_braces
        
        -- Consider indices from 15% to 85% of file as "deep"
        if in_block == 0 and brace_depth == 0 and i > #lines * 0.15 and i < #lines * 0.85 then
            table.insert(safe_indices, i)
        end
    end
    
    -- If no safe spot found in middle, try anywhere safe, else append
    local insert_idx = #lines + 1
    if #safe_indices > 0 then
        insert_idx = safe_indices[Engine.randomRange(1, #safe_indices)]
    end
    
    local watermark_code = Watermark.generate()
    
    if insert_idx > #lines then
        table.insert(lines, watermark_code)
    else
        table.insert(lines, insert_idx, watermark_code)
    end
    
    return table.concat(lines, "\n")
end

return Watermark
