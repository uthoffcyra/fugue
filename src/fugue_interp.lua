--[[
fugue language interpreter
]]--

-- loads fugue's version # to global
_G.fugue = {_VERSION_ = '0.2.0'}

-- debug runtime values
_G.fugue._DEBUG_ = {
    current_process = 'start',
    at_line = 1
}

local lib = require('fugue_lib')

local parse = require('fugue_fe')
local state = require('fugue_state')

local run = require('fugue_walk')

local args = {...}
local show_ast = false

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
    _G.fugue._DEBUG_.current_process = 'parse'
    parse(input_stream)
    if show_ast then print_ast() end
    _G.fugue._DEBUG_.current_process = 'interp'
    run(state.program)
end

if args[1] then
    if fs.exists(args[1]) then
        -- load file
        local file = fs.open(args[1], 'r')
        local contents = file.readAll()
        file.close()
        -- show ast flag
        if lib.tcontains(args, '--ast') then
            show_ast = true
        end
        -- run interpreter
        interp(contents)
    else
        lib.err('file not found: {}', {args[1]})
    end
else
    -- show version
    local mem = term.getTextColor()
    term.setTextColor(colors.orange)
    print('Fugue Language')
    term.setTextColor(colors.lightGray)
    print('Version '.._G.fugue._VERSION_)

    print('\nSource code and wiki at...')
    term.setTextColor(colors.cyan)
    print('github.com/uthoffcyra/fugue')

    term.setTextColor(mem)
end