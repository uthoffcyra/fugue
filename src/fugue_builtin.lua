--[[

built in functions for fugue lang

]]--

local lib = require('fugue_lib')

-------------------------------------------------------------------------
-- library for walker / functions
-------------------------------------------------------------------------

function convert_to_string(v)
    if v[1] == 'special' then
        return convert_to_string(v[2].value)
    elseif v[1] == 'string' then
        return {'string', v[2]}
    elseif v[1] == 'number' then
        return {'string', (''..v[2])}
    elseif v[1] == 'boolean' then
        if v[2] then
            return {'string', 'true'}
        else
            return {'string', 'false'}
        end
    elseif v[1] == 'none' then
        return {'string', 'none'}
    else
        return {'string', 'unknown'}
    end
end

-------------------------------------------------------------------------
-- functions in lua
-------------------------------------------------------------------------

local builtins = {}

builtins['print'] = function(arg_list)

    local cmem = term.getTextColor()

    for i,value in ipairs(arg_list) do

        -- if arg is @color...
        if value[1] == 'special' and value[2].kind == 'color' then
            if type(value[2].value[2]) == 'number' then
                term.setTextColor(value[2].value[2])
            else
                lib.err('unexpected value type of \'special\': {}',
                    {type(value[2].value[2])})
            end
        
        -- any other variables...
        else
            write(convert_to_string(value)[2])
            if i < #arg_list then write(' ') end
        end

    end

    term.setTextColor(cmem)
    print()

    return {'boolean', true}
end

-- conversion functions start with an _underscore
builtins['_str'] = function(arg_list)
    if #arg_list > 0 then
        return convert_to_string(arg_list[1])
    end
end
builtins['_special'] = function(arg_list)
    if #arg_list > 1 then
        if arg_list[1][1] == 'string' and #arg_list[2] == 2 then
            return {'special', {kind=arg_list[1][2], value=arg_list[2]}}
        else
            lib.err('unexpected argument(s) for function \'_special\'')
        end
    else
        lib.err('too few arguments for function \'_special\'')
    end
end

builtins['kind'] = function(arg_list)
    if (#arg_list > 0) and (arg_list[1][1] == 'special') then
        return {'string', arg_list[1][2].kind}
    else return {'none'} end
end
builtins['type'] = function(arg_list)
    if #arg_list > 0 then
        local res = {'string', arg_list[1][1]}
        if res[2] == nil then res[2] = 'err' end
        return res
    else return {'none'} end
end
builtins['child'] = function(arg_list)
    if #arg_list > 0 and arg_list[1][1] == 'special' then
        return arg_list[1][2].value
    elseif #arg_list > 0 and not (arg_list[1][1] == 'none') then
        return {'boolean', false}
    else return {'none'} end
end

-------------------------------------------------------------------------
-- initial global variables
-------------------------------------------------------------------------

local fe_defaults = {}

fe_defaults['_VERSION_']   = {'string', _G['fugue']['_VERSION_']}
fe_defaults['_EXEC_TIME_'] = {'string', os.date('%c')}

fe_defaults['peripherals'] = {'special', {kind='loadable',
     value={'string', 'peripherals'}}}

fe_defaults['white']     = {'special', {kind='color', value={'number', 0x1}}}
fe_defaults['orange']    = {'special', {kind='color', value={'number', 0x2}}}
fe_defaults['magenta']   = {'special', {kind='color', value={'number', 0x4}}}
fe_defaults['lightBlue'] = {'special', {kind='color', value={'number', 0x8}}}
fe_defaults['yellow']    = {'special', {kind='color', value={'number', 0x10}}}
fe_defaults['lime']      = {'special', {kind='color', value={'number', 0x20}}}
fe_defaults['pink']      = {'special', {kind='color', value={'number', 0x40}}}
fe_defaults['gray']      = {'special', {kind='color', value={'number', 0x80}}}
fe_defaults['lightGray'] = {'special', {kind='color', value={'number', 0x100}}}
fe_defaults['cyan']      = {'special', {kind='color', value={'number', 0x200}}}
fe_defaults['purple']    = {'special', {kind='color', value={'number', 0x400}}}
fe_defaults['blue']      = {'special', {kind='color', value={'number', 0x800}}}
fe_defaults['brown']     = {'special', {kind='color', value={'number', 0x1000}}}
fe_defaults['green']     = {'special', {kind='color', value={'number', 0x2000}}}
fe_defaults['red']       = {'special', {kind='color', value={'number', 0x4000}}}
fe_defaults['black']     = {'special', {kind='color', value={'number', 0x8000}}}

-------------------------------------------------------------------------

return {builtins=builtins, defaults=fe_defaults,
    convert_to_string=convert_to_string}