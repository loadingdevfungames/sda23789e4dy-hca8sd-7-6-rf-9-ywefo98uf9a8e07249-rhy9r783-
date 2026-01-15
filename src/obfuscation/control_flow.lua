--[[
    lua.rip - Control Flow Obfuscation
    State machine transformation with opaque predicates
]]

local Engine = require("src.polymorphic.engine")
local Expressions = require("src.polymorphic.expressions")
local Config = require("config")

local ControlFlow = {}

function ControlFlow.generateStateValue()
    return Engine.randomRange(0x1000, 0xFFFF)
end

function ControlFlow.generateFakeState()
    local state = ControlFlow.generateStateValue()
    
    local fake_actions = {
        function()
            local var = Engine.generateName("mixed", 20)
            return string.format("local %s = %d; %s = %s * 2", var, Engine.randomRange(1, 100), var, var)
        end,
        function()
            local var = Engine.generateName("mixed", 20)
            return string.format("local %s = {}; %s[1] = %d", var, var, Engine.randomRange(1, 100))
        end,
        function()
            local var = Engine.generateName("mixed", 20)
            return string.format("local %s = %q; %s = %s .. %s", var, Engine.generateName("random", 5), var, var, var)
        end,
        function()
            return string.format("if %s then end", Expressions.generateOpaqueFalse())
        end,
        function()
            local var = Engine.generateName("mixed", 20)
            return string.format("local %s = math.random(); %s = %s + 1", var, var, var)
        end,
    }
    
    local action = fake_actions[Engine.randomRange(1, #fake_actions)]()
    
    return {
        value = state,
        action = action,
        is_fake = true,
    }
end

function ControlFlow.flattenBlock(code, next_state)
    local state = ControlFlow.generateStateValue()
    
    return {
        value = state,
        action = code,
        next_state = next_state,
        is_fake = false,
    }
end

function ControlFlow.generateStateMachine(blocks, fake_count)
    fake_count = fake_count or Config.get("ControlFlow.FakeStates") or 10
    
    local states = {}
    
    for _, block in ipairs(blocks) do
        states[#states + 1] = ControlFlow.flattenBlock(block.code, block.next)
    end
    
    for _ = 1, fake_count do
        states[#states + 1] = ControlFlow.generateFakeState()
    end
    
    states = Engine.shuffle(states)
    
    return states
end

function ControlFlow.generateDispatcher(states, state_var)
    state_var = state_var or Engine.generateName("mixed", 30)
    
    local lines = {}
    
    local initial_state = nil
    for _, state in ipairs(states) do
        if not state.is_fake then
            initial_state = state.value
            break
        end
    end
    
    lines[#lines + 1] = string.format("local %s = %d", state_var, initial_state or 0)
    lines[#lines + 1] = "while true do"
    
    local first = true
    for _, state in ipairs(states) do
        local condition = first and "if" or "elseif"
        first = false
        
        lines[#lines + 1] = string.format("    %s %s == %d then", condition, state_var, state.value)
        
        if state.action then
            for line in state.action:gmatch("[^\n]+") do
                lines[#lines + 1] = "        " .. line
            end
        end
        
        if state.next_state then
            lines[#lines + 1] = string.format("        %s = %d", state_var, state.next_state)
        elseif not state.is_fake then
            lines[#lines + 1] = "        break"
        else
            local fake_next = states[Engine.randomRange(1, #states)]
            lines[#lines + 1] = string.format("        %s = %d", state_var, fake_next.value)
        end
    end
    
    lines[#lines + 1] = "    end"
    lines[#lines + 1] = "end"
    
    return table.concat(lines, "\n")
end

function ControlFlow.wrapWithOpaquePredicate(code, always_true)
    if always_true then
        return string.format("if %s then\n%s\nend", Expressions.generateOpaqueTrue(), code)
    else
        return string.format("if %s then\n    -- dead code\nelse\n%s\nend", Expressions.generateOpaqueFalse(), code)
    end
end

function ControlFlow.insertOpaquePredicates(code, density)
    density = density or 0.2
    
    local lines = {}
    local in_block = 0
    
    for line in code:gmatch("[^\n]+") do
        lines[#lines + 1] = line
        
        local trimmed = line:match("^%s*(.-)%s*$")
        
        if trimmed:match("^function%s") or trimmed:match("^local%s+function%s") or
           trimmed:match("^return%s+function") or
           trimmed:match("^if%s") or trimmed:match("^for%s") or 
           trimmed:match("^while%s") or trimmed:match("^repeat%s") or
           trimmed:match("^do$") or trimmed:match("= function") then
            in_block = in_block + 1
        end
        
        if trimmed:match("^end$") or trimmed:match("^end[%s,)]") or
           trimmed:match("^until%s") then
            in_block = math.max(0, in_block - 1)
        end
        
        local is_complete = trimmed:match("[%)%}%;]$") or 
                           trimmed:match("^local%s+[%w_]+%s*=%s*[%d\"'{]") or
                           trimmed:match("^print%(") or
                           trimmed:match("^return%s") or
                           trimmed:match("^break$") or
                           trimmed:match("^end$")
        
        local is_safe = in_block == 0 and is_complete and 
                       not trimmed:match("^%-%-") and
                       not trimmed:match("^else") and
                       not trimmed:match("^elseif") and
                       #trimmed > 0
        
        if is_safe and Engine.randomFloat() < density then
            if Engine.randomFloat() < 0.5 then
                lines[#lines + 1] = string.format("if %s then end", Expressions.generateOpaqueTrue())
            else
                local fake_code = string.format("local %s = %d", Engine.generateName("mixed", 20), Engine.randomRange(1, 1000))
                lines[#lines + 1] = string.format("if %s then %s end", Expressions.generateOpaqueFalse(), fake_code)
            end
        end
    end
    
    return table.concat(lines, "\n")
end

function ControlFlow.generateJunkCode(count)
    count = count or 5
    
    local junk = {}
    
    local generators = {
        function()
            local var = Engine.generateName("mixed", 25)
            return string.format("local %s = %d", var, Engine.randomRange(1, 10000))
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            return string.format("local %s = {}", var)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            return string.format("local %s = function() end", var)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            return string.format("local %s = %q", var, Engine.generateName("random", 10))
        end,
        function()
            return string.format("if %s then end", Expressions.generateOpaqueFalse())
        end,
        function()
            local var1 = Engine.generateName("mixed", 20)
            local var2 = Engine.generateName("mixed", 20)
            return string.format("local %s, %s = %d, %d; %s = %s + %s", var1, var2, Engine.randomRange(1, 100), Engine.randomRange(1, 100), var1, var1, var2)
        end,
        function()
            local var = Engine.generateName("mixed", 25)
            return string.format("local %s = math.floor(%f)", var, Engine.randomFloat() * 1000)
        end,
    }
    
    for _ = 1, count do
        local gen = generators[Engine.randomRange(1, #generators)]
        junk[#junk + 1] = gen()
    end
    
    return table.concat(junk, "\n")
end

function ControlFlow.process(code, max_depth)
    max_depth = max_depth or 3
    
    if Config.get("ControlFlow.OpaquePredicates") then
        code = ControlFlow.insertOpaquePredicates(code, 0.15)
    end
    
    local junk_density = Config.get("JunkCode.Density") or 0.3
    if Config.isEnabled("JunkCode") then
        local junk_count = math.floor(#code / 100 * junk_density)
        local junk = ControlFlow.generateJunkCode(junk_count)
        code = junk .. "\n" .. code
    end
    
    return code
end

function ControlFlow.transformToStateMachine(code)
    local blocks = {
        {code = code, next = nil}
    }
    
    local fake_count = Config.get("ControlFlow.FakeStates") or 10
    local states = ControlFlow.generateStateMachine(blocks, fake_count)
    
    return ControlFlow.generateDispatcher(states)
end

return ControlFlow
