--[[
fugue language interpreter
]]--

local lib = require('fugue_lib')
local parse = require('fugue_fe')
local state = require('fugue_state')
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

    term.setTextColor(colors.white)

end

function interp(input_stream)
    print('Starting...')
    state:initialize()
    parse(input_stream)

    print_ast()

    -- interp_program()
end

if args[1] then
    local file = fs.open(args[1], 'r')
    local contents = file.readAll()
    file.close()
    interp(contents)
end