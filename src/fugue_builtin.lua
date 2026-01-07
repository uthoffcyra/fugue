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
    elseif v[1] == 'function' then
        return {'string', '<function>'}
    elseif v[1] == 'list' then
        return {'string', 'list<'..v[2].length..'>'}
    elseif v[1] == 'base' then
        return {'string', 'base<'..v[2].length..'>'}
    elseif v[1] == 'none' then
        return {'string', 'none'}
    else
        return {'string', 'unknown'}
    end
end

-------------------------------------------------------------------------
-- complex variable types
-------------------------------------------------------------------------

List = {}
List.__index = List
function List.new (fe_values_table) -- { {'number', 12}, {'boolean', false} }
    local self = setmetatable({}, List)
    self.values = {}
    self.length = 0
    -- initializer?
    if fe_values_table then
        self.values = fe_values_table
        self.length = #fe_values_table
    end
    return self
end
function List:index(index,assign)
    -- only take numbers
    if index[1] ~= 'number' then
        return {'none'} end

    local v = index[2]
    -- inverse
    if v < 0 then v = self.length + v end
    -- no overflow
    if v > (self.length-1) then
        return {'none'}
    end
    -- reassignment?
    if assign then
        self.values[v+1] = assign
    end
    return self.values[v+1]
end
function List.prop__length(self,assign)
    return {'number', self.length}
end

Base = {}
Base.__index = Base
function Base.new (fe_names, fe_pairs)
    local self = setmetatable({}, Base)
    self.names = {}
    self.pairs = {}
    self.length = 0
    if fe_names and fe_pairs then
        self.names = fe_names
        self.pairs = fe_pairs
        self.length = #self.names
    end
    return self
end
function Base:index(index,assign)
    -- only take strings
    if index[1] ~= 'string' then
        return {'none'} end

    -- assignment?
    if assign then
        self.pairs[index[2]] = assign
        if not lib.tcontains(self.names, index[2]) then
            table.insert(self.names, index[2])
        end
        return assign
    end

    -- fetch value
    if lib.tcontains(self.names, index[2]) then
        return self.pairs[index[2]]
    else
        return {'none'}
    end
end
function Base:prop__(name,assign)
    return self:index({'string', ''..name}, assign)
end
function Base.prop__length(self,assign)
    return {'number', self.length}
end
function Base:func__has(arg_list)
    -- if no args...
    if #arg_list == 0 then return {'none'} end
    -- if not a string
    if arg_list[1][1] ~= 'string' then
        return {'boolean', false} end
    -- has name in base...
    if lib.tcontains(self.names, arg_list[1][2]) then
        return {'boolean', true}
    else return {'boolean', false} end
end

Struct = {}
Struct.__index = Struct

Increment = {}
Increment.__index = Increment
function Increment.new (list, index)
    local self = setmetatable({}, Increment)
    self.values = {}
    self.length = 0
    self.position = -1
    -- if provided list
    if list then
        self.values = list
        self.length = #list
        if #list > 0 then
            self.position = 0 end
    end
    -- if provided index, and list has elements
    if index and self.length > 0 then
        self.position = index
        -- clamp position to start of list
        if self.position < 0 then self.position = 0
        -- clamp position to end of list
        elseif self.position >= self.length then
            self.position = self.length - 1 end
    end
    return self
end
function Increment:index(index,assign)
    -- only take numbers
    if index[1] ~= 'number' then
        return {'none'} end
    local v = index[2]
    -- inverse
    if v < 0 then v = self.length + v end
    -- no overflow
    if v > (self.length-1) then
        return {'none'}
    end
    return self.values[v+1]
end
function Increment:func__next(arg_list)
    if (self.position + 1) >= self.length then 
        return {'special', {kind='Increment Bound', value={'string', 'EOL'}}}
    end
    self.position = self.position + 1
    return self:func__curr({})
end
function Increment:func__prev(arg_list)
    -- cant be less than -1
    if (self.position - 1) < -1 then 
        return {'special', {kind='Increment Bound', value={'string', 'SOL'}}}
    end
    self.position = self.position - 1
    return self:func__curr({})
end
function Increment:func__curr(arg_list)
    if (self.position == -1) then
        return {'special', {kind='Increment Bound', value={'string', 'SOL'}}} end
    return self.values[self.position+1]
end
function Increment:func__pos(arg_list)
    return {'number', self.position}
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
builtins['error'] = function(arg_list)
    local cmem = term.getTextColor()
    term.setTextColor(colors.red)
    write('\127\127 ')
    for i,value in ipairs(arg_list) do
        write(convert_to_string(value)[2])
        if i < #arg_list then write(' ') end
    end
    write(' \127\127')
    term.setTextColor(cmem)
    print()

    error('',0)
end
builtins['warn'] = function(arg_list)
    local cmem = term.getTextColor()
    term.setTextColor(colors.orange)
    write('\127\127 ')
    for i,value in ipairs(arg_list) do
        write(convert_to_string(value)[2])
        if i < #arg_list then write(' ') end
    end
    write(' \127\127')
    term.setTextColor(cmem)
    print()
end

-- conversion functions start with an _underscore
builtins['String'] = function(arg_list)
    if #arg_list > 0 then
        return convert_to_string(arg_list[1])
    end
end
builtins['Special'] = function(arg_list)
    -- more than 1 argument for function
    if #arg_list > 1 then
        -- first argument is string, second argument has 'type' and 'value'
        if arg_list[1][1] == 'string' and #arg_list[2] == 2 then
            return {'special', {kind=arg_list[1][2], value=arg_list[2]}}
        else
            lib.err('unexpected argument(s) for function \'_special\'')
        end
    else
        lib.err('too few arguments for function \'_special\'')
    end
end
builtins['Increment'] = function(arg_list)
    local list, index
    -- check validity
    if #arg_list > 0 then
        if arg_list[1] and arg_list[1][1] ~= 'list' then
            lib.err('Increment(1), expected list type.')
        end
        if arg_list[2] and arg_list[2][1] ~= 'number' then
            lib.err('Increment(2), expected number type.')
        end
    end
    -- parse values
    if arg_list[1] then list = arg_list[1][2].values end
    if arg_list[2] then index = arg_list[2][2] end
    return {'increment', Increment.new(list, index)}
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

builtins['*string:index'] = function(value, index)
    if index[1] ~= 'number' then
        lib.err('attempted to index string with non-number type') end
        
    local x = index[2]
    -- inverse
    if x < 0 then x = #value[2] + x end
    -- no overflow
    if x > (#value[2] - 1) then return {'none'} end

    return {'string', string.sub(value[2], x+1, x+1)}
end
builtins['*string.length'] = function(value)
    return {'number', #value[2]}
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

fe_defaults['IncrementSOL'] = 
    {'special', {kind='Increment Bound', value={'string', 'SOL'}}}
fe_defaults['IncrementEOL'] = 
    {'special', {kind='Increment Bound', value={'string', 'EOL'}}}

-- adds builtin functions as variables
for key, value in pairs(builtins) do
    if key[1] ~= '*' then
        fe_defaults[key] = {'function', {arguments=true, body=
            { 'FN_RETURN', {'RUN_LUA_FUNCTION', value } }
        }}
    end
end

-------------------------------------------------------------------------

return {builtins=builtins, defaults=fe_defaults,
    convert_to_string=convert_to_string,
    complex_types={List=List,Base=Base}}