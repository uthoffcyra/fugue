--[[
fugue lang ast tree walker
]]--

local lib = require('fugue_lib')
local symtab = require('fugue_symtab')
local fe_global = require('fugue_builtin')
local unpack = table.unpack

local dispatch = {}

-------------------------------------------------------------------------

function get_type(v)
    if type(v) == 'table' and v._interp_type then
        return value._interp_type
    else
        return type(v)
    end
end

function treat_as_boolean(v)
    -- v = { type, value }
    if v[1] == 'boolean' then
        return exp[2]
    elseif v[1] == 'none' then
        return {'boolean', false}
    elseif v[1] == 'number' and v[2] == 0 then
        return {'boolean', false}
    else
        return {'boolean', true}
    end
end

function scope_with_args(ard,arc,fb)
    -- load arguments...
    symtab:push_scope()

    --[[for i,name in ipairs(ard) do
        if arc[i] then -- if matching value in call
            symtab:declare(name,arc[i])
        else
            symtab:declare(name,{'none'})
        end
    end]]

    local i = 1
    while true do
        -- both decl and call
        if ard[i] and arc[i] then
            symtab:declare(ard[i],arc[i])
        -- decl, no call
        elseif ard[i] then
            symtab:declare(ard[i],{'none'})
        -- call, no decl
        elseif arc[i] then
            break
        -- neither
        else
            break
        end
        i = i + 1
    end

    -- run function...
    local return_value = walk(fb)
    symtab:pop_scope()

    return return_value
end

function validate_event_call(event,arc)
    local t = {}
    for i,v in ipairs(arc) do
        if v == nil then break end
        -- custom exceptions
        if lib.tcontains({'key', 'key_up'},event) and i==1 then
            v = keys.getName(v)
        end

        table.insert(t, {type(v),v})
    end
    return t
end

function wrap_peripherals()
    local names = peripheral.getNames()
    for i,n in ipairs(names) do
        peripheral.wrap(n)
    end
end

-------------------------------------------------------------------------
-- node functions
-------------------------------------------------------------------------

dispatch['STMT_LIST'] = function(node)
    local STMT_LIST, lst = unpack(node)
    local return_value = {'NONE'}
    symtab:push_scope()
    for i,stmt in ipairs(lst) do
        if stmt[1] == 'FN_RETURN' then
            return_value = walk(stmt)
            break
        else
            walk(stmt)
        end
    end
    symtab:pop_scope()
    return return_value
end

-------------------------------------------------------------------------

dispatch['VAR_DECL'] = function(node)
    local VAR_DECL, name, value = unpack(node)
    name = name[2]
    value = walk(value)

    symtab:declare(name, value)

    return
end
dispatch['FN_DECL'] = function(node)
    local FN_DECL, name, ard, fb = unpack(node)
    name = name[2]
    ard = walk(ard) -- see 'DECL_ARGS'

    symtab:declare(name, {'function', {arguments=ard, body=fb}})

    return
end
dispatch['FN_RETURN'] = function(node)
    local FN_RETURN, exp = unpack(node)
    return walk(exp)
end
dispatch['ASSIGN'] = function(node)
    local ASSIGN, name, exp = unpack(node)
    symtab:update_sym(name[2], walk(exp))
    return
end
dispatch['FN_CALL'] = function(node)
    local FN_CALL, name, arc = unpack(node)
    name = name[2]
    arc = walk(arc) -- see 'CALL_ARGS'

    local fn = symtab:lookup_sym(name)

    if fn[1] == 'function' then
        
        local ard, fb = fn[2]['arguments'], fn[2]['body']
        return scope_with_args(ard, arc, fb)

    elseif not (fn[1] == 'none') then
        lib.err('attempted to call function of type {}', {fn[1]})
    elseif type(fe_global.builtins[name]) == 'function' then
        return fe_global.builtins[name](arc)
    else
        lib.err('attempted to call function that doesnt exist')
    end

end
dispatch['LOAD'] = function(node)
    local LOAD, exp = unpack(node)
    exp = walk(exp)

    -- load 'loadable' special type
    if exp[1] == 'special' and exp[2].kind == 'loadable' then
        -- load peripherals
        if exp[2].value[2] == 'peripherals' then
            wrap_peripherals()
        else
            lib.err('unknown \'loadable\': {}', {exp[2].value[2]})
        end
    else
        -- maybe one day, external code?
        lib.err('attempted to \'load\' non-loadable value')
    end
end
dispatch['IF'] = function(node)
    local IF, exp, stmt = unpack(node)
    exp = walk(exp)
    local check = treat_as_boolean(exp)
    if check[2] then walk(stmt) end
end
dispatch['EVENT_LOOP'] = function(node)
    local EVENT_LOOP, res_list = unpack(node)

    -- load all event responses to map
    local res_map = {}
    for i,res in ipairs(res_list) do
        local EVENT_RES, exp, ard, stmt = unpack(res)
        exp = walk(exp)
        ard = walk(ard)
        res_map[exp[2]] = {ard, stmt} -- DECL_ARGS, STMT_LIST
    end

    -- run event loop
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        for i,res in ipairs(res_list) do
            if not (res_map[event] == nil) then
                local match = res_map[event]
                local arc = validate_event_call(event,{p1,p2,p3,p4,p5})
                scope_with_args(match[1],arc,match[2])
            end
        end
    end

    return {'none'}
end

-------------------------------------------------------------------------

dispatch['DECL_ARGS'] = function(node)
    local DECL_ARGS, arg_list = unpack(node)
    local response = {}
    for i,name in ipairs(arg_list) do
        table.insert(response, name[2])
    end
    return response
end
dispatch['CALL_ARGS'] = function(node)
    local CALL_ARGS, arg_list = unpack(node)
    local response = {}
    for i,exp in ipairs(arg_list) do
        table.insert(response, walk(exp))
    end
    return response
end

-------------------------------------------------------------------------

-- exp low
dispatch['EQU'] = function(node)
    local EQU, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[2] == e2[2] then
        return {'boolean', true}
    else
        return {'boolean', false}
    end
end
dispatch['NEQ'] = function(node)
    local NEQ, e1, e2 = unpack(node)
    local EQU, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[2] == e2[2] then
        return {'boolean', false}
    else
        return {'boolean', true}
    end
end
dispatch['LEQ'] = function(node)
    local LEQ, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)

    if e1[1] == 'number' and e2[1] == 'number' then
        if e1[2] <= e2[2] then
            return {'boolean', true}
        else
            return {'boolean', false}
        end
    else
        lib.err('attempted to check size of non-number type(s)')
    end
end
dispatch['GEQ'] = function(node)
    local GEQ, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)

    if e1[1] == 'number' and e2[1] == 'number' then
        if e1[2] >= e2[2] then
            return {'boolean', true}
        else
            return {'boolean', false}
        end
    else
        lib.err('attempted to check size of non-number type(s)')
    end
end

-- exp medium
dispatch['PLUS'] = function(node)
    local PLUS, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[1] == 'number' and e2[1] == 'number' then
        return {'number', e1[2] + e2[2]}
    else
        lib.err('attempted to perform addition on non-number type(s)')
    end
end
dispatch['MINUS'] = function(node)
    local MINUS, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[1] == 'number' and e2[1] == 'number' then
        return {'number', e1[2] - e2[2]}
    else
        lib.err('attempted to perform subtraction on non-number type(s)')
    end
end
dispatch['CONCAT'] = function(node)
    local CONCAT, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[1] == 'string' and e2[1] == 'string' then
        return {'number', e1[2]..e2[2]}
    else
        lib.err('attempted to concatenate non-string type(s)')
    end
end

-- exp high
dispatch['MUL'] = function(node)
    local MUL, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[1] == 'number' and e2[1] == 'number' then
        return {'number', e1[2] * e2[2]}
    else
        lib.err('attempted to perform multiplication on non-number type(s)')
    end
end
dispatch['DIV'] = function(node)
    local DIV, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)
    
    if e1[1] == 'number' and e2[1] == 'number' then
        return {'number', e1[2] / e2[2]}
    else
        lib.err('attempted to perform division on non-number type(s)')
    end
end

-------------------------------------------------------------------------

dispatch['NAME'] = function(node)
    local NAME, n = unpack(node)
    local check = symtab:lookup_sym(n)
    if type(check) == 'table' and check[1] == 'special' then
        return check[2].value
    end
    return check
end
dispatch['SPECIAL'] = function(node)
    local SPECIAL, n = unpack(node)
    return symtab:lookup_sym(n, true)
end
dispatch['CONST'] = function(node)
    local CONST, v = unpack(node)
    return {get_type(v), v} -- returns value
end
dispatch['NONE'] = function(node)
    return {'none'}
end
dispatch['NOT'] = function(node)
    local NOT, exp = unpack(node)
    exp = walk(exp) -- { type, value }

    local check = treat_as_boolean(exp)
    check[2] = not check[2]

    return check
end

-------------------------------------------------------------------------
-- walk
-------------------------------------------------------------------------

function run(node)
    -- variable environment
    symtab:initialize()

    -- load initial globals
    symtab:push_scope()
    for name,value in pairs(fe_global.defaults) do
        symtab:declare(name, value)
    end

    -- start walk...
    walk(node)

end

function walk(node)
    
    if node == nil then
        lib.err('FE_WALK: node does not exist')
        return
    end

    local t = node[1]
    -- term.setTextColor(colors.orange)
    -- print(''..t..' walk...')
    -- term.setTextColor(colors.white)
    -- lib.tprint(node)

    if (type(dispatch[t]) == 'function') then
        return dispatch[t](node)
    else
        lib.err('walk : unknown tree node type: {}', {t})
    end

end

-- exports
return run