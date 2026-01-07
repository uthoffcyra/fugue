--[[
fugue lang ast tree walker
]]--

local lib = require('fugue_lib')
local symtab = require('fugue_symtab')
local fe_global = require('fugue_builtin')
local unpack = table.unpack

-- Complex Types
unpack(fe_global.complex_types)

local dispatch = {}

-------------------------------------------------------------------------

function fe_type(v)
    -- if type(v) == 'table' and v._interp_type then
    --     return value._interp_type
    -- else
    return type(v)
    -- end
end
function treat_as_boolean(v)
    -- v = { type, value }
    if v[1] == 'boolean' then
        return v
    elseif v[1] == 'none' then
        return {'boolean', false}
    elseif v[1] == 'number' and v[2] == 0 then
        return {'boolean', false}
    else
        return {'boolean', true}
    end
end

-- takes an AST and finds the location where assignments can be made.
function getMemoryLocation(node)
    -- simple — name
    if node[1] == 'NAME' then
        return node[2], false
    end
    -- get the top-level symbol
    local curr = node
    local top_level_symbol
    while curr[1] ~= 'NAME' do
        if lib.tcontains({'PROPERTY','INDEX'},curr[1]) then
            curr = curr[2]
        else
            lib.err('attempted to assign value to {}', {curr[1]})
        end
    end
    top_level_symbol = curr[2]
    return top_level_symbol, {node[1], walk(node[2]), node[3]}
end

-- creates a new scope with ...
-- 1) argument variable names
-- 2) argument input values
-- 3) internal function body
function scope_with_args(ard,arc,fb)
    -- load arguments...
    symtab:push_scope()

    -- take all arguments into one variable
    if ard == true then
        symtab:declare('*arg_list', arc)
    -- create respective arguments
    else
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
    end

    -- run function...
    local return_value = walk(fb)
    symtab:pop_scope()

    return return_value
end

-- gives custom event parameters
function validate_event_call(event,arc)
    local t = {}
    for i,v in ipairs(arc) do
        if v == nil then break end
        -- custom exceptions
        if lib.tcontains({'key', 'key_up'}, event) and i==1 then
            v = keys.getName(v)
        end

        table.insert(t, {fe_type(v),v})
    end
    return t
end

-- wraps all peripherals
-- runs at 'load @peripherals;'
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
dispatch['FN_CALL'] = function(node)
    local FN_CALL, fn, arc = unpack(node)

    fn = walk(fn)
    arc = walk(arc) -- see 'CALL_ARGS'

    -- is a function
    if fn[1] == 'function' then
        local ard, fb = fn[2]['arguments'], fn[2]['body']
        return scope_with_args(ard, arc, fb)

    -- attempt to call non-function variable
    elseif not (fn[1] == 'none') then
        lib.err('attempted to call function of type {}', {fn[1]})

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
    local IF, exp, stmt, cont = unpack(node)
    exp = walk(exp)
    local check = treat_as_boolean(exp)
    -- if true, walk...
    if check[2] == true then walk(stmt)
    -- not true, check for else_if/else
    elseif check[2] == false and cont ~= false then
        if cont[1] == 'IF' then
            walk(cont) -- walk embeded 'IF'
        elseif cont[1] == 'ELSE' then
            walk(cont[2]) -- walk 'ELSE' stmt
        end
    end
end
dispatch['WHILE'] = function(node)
    local IF, exp, stmt = unpack(node)
    local exp_it = walk(exp)
    local check = treat_as_boolean(exp_it)
    while check[2] do
        walk(stmt)
        -- re-compute check
        exp_it = walk(exp)
        check = treat_as_boolean(exp_it)
    end
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

-- assign
dispatch['ASSIGN'] = function(node)
    local ASSIGN, e1, e2 = unpack(node)
    local obj
    e1, obj = getMemoryLocation(e1)
    e2 = walk(e2)
    -- simple name assignment
    if obj == false then
        symtab:update_sym(e1, e2)
    -- assign to property/index
    else
        local action, value, location = unpack(obj)
        -- reassign at index
        if action == 'INDEX' then
            location = walk(location)
            if value[2].index then
                value[2]:index(location, e2) end
        -- reassign at property
        elseif action == 'PROPERTY' then
            local propname = location[2]
            -- specific builtin property
            if type(value[2]['prop__'..propname]) == 'function' then
                value[2]['prop__'..propname](value[2], e2)
            -- variable's ANY property
            elseif type(value[2]['prop__']) == 'function' then
                value[2]['prop__'](value[2], propname, e2) end
        end
    end
    return e2
end

-- logicals
dispatch['AND'] = function(node)
    local AND, e1, e2 = unpack(node)
    e1 = treat_as_boolean( walk(e1) )[2]
    e2 = treat_as_boolean( walk(e2) )[2]

    if e1 == true and e2 == true then -- T/T
        return {'boolean', true}
    else
        return {'boolean', false}
    end
end
dispatch['OR'] = function(node)
    local OR, e1, e2 = unpack(node)
    e1 = treat_as_boolean( walk(e1) )[2]
    e2 = treat_as_boolean( walk(e2) )[2]

    if (e1 == true and e2 == true) or -- T/T
    (e1 == true and e2 == false) or   -- T/F
    (e1 == false and e2 == true) then -- F/T
        return {'boolean', true}
    else
        return {'boolean', false}
    end
end
dispatch['XOR'] = function(node)
    local XOR, e1, e2 = unpack(node)
    e1 = treat_as_boolean( walk(e1) )[2]
    e2 = treat_as_boolean( walk(e2) )[2]

    if (e1 == true and e2 == false) or -- T/F
    (e1 == false and e2 == true) then  -- F/T
        return {'boolean', true}
    else
        return {'boolean', false}
    end
end

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
        lib.err('attempted to check numerical value of non-number type(s)')
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
        lib.err('attempted to check numerical value of non-number type(s)')
    end
end
dispatch['GT'] = function(node)
    local GT, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)

    if e1[1] == 'number' and e2[1] == 'number' then
        if e1[2] > e2[2] then
            return {'boolean', true}
        else
            return {'boolean', false}
        end
    else
        lib.err('attempted to check numerical value of non-number type(s)')
    end
end
dispatch['LT'] = function(node)
    local GT, e1, e2 = unpack(node)
    e1 = walk(e1) -- { type, value }
    e2 = walk(e2)

    if e1[1] == 'number' and e2[1] == 'number' then
        if e1[2] < e2[2] then
            return {'boolean', true}
        else
            return {'boolean', false}
        end
    else
        lib.err('attempted to check numerical value of non-number type(s)')
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

-- primary
dispatch['LAMBDA'] = function (node)
    local LAMBDA, ard, fb = unpack(node)
    ard = walk(ard) -- see 'DECL_ARGS'
    return {'function', {arguments=ard, body=fb}}
end
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
dispatch['LIST'] = function(node)
    local LIST, values = unpack(node)
    local fe_localized = {}
    for i,exp in ipairs(values) do
        table.insert(fe_localized, walk(exp))
    end
    return {'list', List.new(fe_localized)}
end
dispatch['BASE'] = function(node)
    local BASE, pairs = unpack(node)
    local fe_names = {}
    local fe_pairs = {}
    for i,bpair in ipairs(pairs) do
        local BASE_PAIR, name, exp = unpack(bpair)
        name = name[2]
        exp = walk(exp)
        table.insert(fe_names, name)
        fe_pairs[name] = exp
    end
    return {'base', Base.new(fe_names, fe_pairs)}
end
dispatch['CONST'] = function(node)
    local CONST, v = unpack(node)
    return {fe_type(v), v} -- returns value
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

-- primary suffix
dispatch['INDEX'] = function(node)
    local INDEX, value, exp = unpack(node)
    value = walk(value)
    exp = walk(exp)

    -- complex value
    if type(value[2]) == 'table' then
        -- check for index function
        if value[2].index then
            return value[2]:index(exp)
        else
            lib.err('type {} can\'t be indexed', {value[1]})
        end
    -- simple value
    else
        local index_fn = fe_global.builtins['*'..value[1]..':index']
        if index_fn then
            return index_fn(value,exp)
        else
            lib.err('type {} can\'t be indexed', {value[1]})
        end
    end

    return {'none'}
end
dispatch['PROPERTY'] = function(node)
    local PROPERTY, value, propname = unpack(node)
    value = walk(value)
    propname = propname[2] -- {NAME, '___'}

    -- complex value
    if type(value[2]) == 'table' then
        -- return complex's property
        if type(value[2]['prop__'..propname]) == 'function' then
            return value[2]['prop__'..propname](value[2])
        -- return complex's function
        elseif type(value[2]['func__'..propname]) == 'function' then
            return {'function', {arguments=true, body=
                { 'FN_RETURN', {'RUN_LUA_FUNCTION',
                    -- function— w/ arg_list, pass in self
                    function(arg_list)
                        return value[2]['func__'..propname](value[2],arg_list)
                    end
                } }
            }}
        -- return complex's ANY property
        elseif type(value[2]['prop__']) == 'function' then
            return value[2]['prop__'](value[2], propname, e2)
        -- otherwise, none
        else
            return {'none'}
        end
    -- simple value
    else
        local prop_fn = fe_global.builtins['*'..value[1]..'.'..propname]
        if prop_fn then
            return prop_fn(value)
        else
            return {'none'}
            -- lib.err('unknown property of type '..value[1]..' : '..propname)
        end
    end
end

-------------------------------------------------------------------------
-- builtin functions
-------------------------------------------------------------------------

dispatch['RUN_LUA_FUNCTION'] = function(node)
    local RUN_LUA_FUNCTION, fn = unpack(node)
    local arg_list = {}
    -- get arguments as passthrough
    if symtab:exists('*arg_list') then
        arg_list = symtab:lookup_sym('*arg_list')
    end
    return fn(arg_list)
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