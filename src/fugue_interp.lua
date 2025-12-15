--[[
fugue language interpreter
]]--

-- loads fugue's version # to global
_G.fugue = {_VERSION_ = '0.2.0'}

local lib = require('fugue_lib')

local parse = require('fugue_fe')
local state = require('fugue_state')

-- local symtab = require('fugue_symtab')
-- local fe_global = require('fugue_builtin')
local run = require('fugue_walk')

local args = {...}

function print_ast()

    term.setTextColor(colors.lime)
    write('Parsed!')

    term.setTextColor(colors.orange)
    print(' - x'..(state.instr_ix-1))

    for i,x in ipairs(state.program[2]) do
        term.setTextColor(colors.gray)
        write(''..i..') ')
        term.setTextColor(colors.white)
        lib.tprint(x)
    end

    term.setTextColor(colors.lime)
    print('Running...')
    term.setTextColor(colors.white)

end

function interp(input_stream)
    state:initialize()
    parse(input_stream)
    -- print_ast()
    run(state.program)
end

if args[1] then
    if fs.exists(args[1]) then
        local file = fs.open(args[1], 'r')
        local contents = file.readAll()
        file.close()
        interp(contents)
    else
        lib.err('file not found: {}', {args[1]})
    end
else
    local mem = term.getTextColor()
    term.setTextColor(colors.orange)
    print('Fugue Language')
    term.setTextColor(colors.gray)
    print('Version '.._G.fugue._VERSION_)
    term.setTextColor(mem)
end