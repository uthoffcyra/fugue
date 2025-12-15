--[[
fugue library
]]--

--------------------------------------

function tconcat(table1,table2)
    local res = {}
    table.move(table1, 1, #table1, 1, res)
    table.move(table2, 1, #table2, #res + 1, res)
    return res
end

--------------------------------------

function tprint(table)
    if type(table) == 'table' then
        tprint_local(table)
        print()
    else
        print(table)
    end
end
function tprint_local(table)
    -- write('<table> ')
    if not table then return end
    for i,v in ipairs(table) do
        tprint_types(v)
    end
    for k,v in pairs(table) do
        if not (type(k) == 'number') then
            write(k..'=')
            tprint_types(v)
        end
    end
end
function tprint_types(value)
    if type(value) == 'table' then
        local rem = term.getTextColor()
        term.setTextColor(colors.lightGray)
        write('{ ')
        term.setTextColor(colors.white)
        tprint_local(value)
        term.setTextColor(colors.lightGray)
        write('} ')
        term.setTextColor(rem)
    else
        write(tostring(value)..' ')
    end
end

--------------------------------------

function tcontains(table,val)
    for i,x in ipairs(table) do
        if x == val then
            return true
        end
    end
    return false
end

--------------------------------------

function format(base,repl)
    local res = base
    for i,v in ipairs(repl) do
        res = string.gsub(res, '{}', v, 1)
    end
    return res
end

--------------------------------------

function warn(text,repl)
    local mem = {term.getTextColor(),term.getBackgroundColor()}
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.orange)
    if repl then text = format(text,repl) end
    write(text)
    term.setTextColor(mem[1])
    term.setBackgroundColor(mem[2])
    write('\n')
end

function err(text,repl)
    local mem = {term.getTextColor(),term.getBackgroundColor()}
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.red)
    if repl then text = format(text,repl) end
    write(text)
    term.setTextColor(mem[1])
    term.setBackgroundColor(mem[2])
    write('\n')

    error('',0)
end

--------------------------------------

function finditer_multi(token_specs, text)
    local init = 1
    return function()
        if init > #text then return nil end
        
        local best_start, best_end, best_pattern, best_type
        
        -- Try each pattern and find the earliest match
        for _, spec in ipairs(token_specs) do
            local pattern = spec[2]
            local results = {string.find(text, pattern, init)}
            if #results > 0 then
                local start_pos, end_pos = results[1], results[2]
                if not best_start or start_pos < best_start then
                    best_start = start_pos
                    best_end = end_pos
                    best_pattern = pattern
                    best_type = spec[1]
                end
            end
        end
        
        if not best_start then return nil end
        
        init = best_end + 1
        
        return {
            type = best_type,
            start = best_start,
            finish = best_end,
            value = string.sub(text, best_start, best_end),
            pattern = best_pattern,
        }
    end
end

--------------------------------------

return {
    tconcat=tconcat,
    tprint=tprint,
    format=format,
    finditer=finditer,
    finditer_multi=finditer_multi,
    err=err, warn=warn,
    tcontains=tcontains
}