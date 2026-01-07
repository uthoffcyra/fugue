--[[

fugue language front-end

    builds an AST where each node is of the shape:

        (TYPE, [arg1, arg2, arg3,...])

    here TYPE is a string describing the node type.

]]--

local lib = require('fugue_lib')
local state = require('fugue_state')
local Lexer = require('fugue_lexer').Lexer
local args = {...}

-- stmt_list : ({<see below>} stmt)*
stmt_lookahead = {'VAR_DECL', 'FN_DECL', 'FN_RETURN', 'LCURLY', 
    'LOAD', 'IF', 'WHILE', 'EVENT_LOOP'} -- + exp lookahead
function stmt_list(stream)
    local lst = {}
    while lib.tcontains(stmt_lookahead, stream:pointer().type) do
        table.insert(lst, stmt(stream))
    end
    return {'STMT_LIST', lst}
end

-- stmt : {VAR_DECL} VAR_DECL NAME (ASSIGN exp)? (SEMI)?
--      | {FN_DECL} FN_DECL NAME decl_args (stmt)? (SEMI)?
--      | {FN_RETURN} FN_RETURN ({<see exp lookahead>} exp)? (SEMI)?
--      | {LCURLY} LCURLY stmt_list RCURLY (SEMI)?
--      | {LOAD} LOAD exp (SEMI)?
--      | {IF} IF if_suffix (SEMI)?
--      | {WHILE} WHILE while_suffix (SEMI)?
--      | {EVENT_LOOP} EVENT_LOOP COMMA event_res_list (SEMI)?
--      | {<see exp lookahead>} exp (SEMI)?
function stmt(stream)
    local token = stream:pointer()

    -- Variable Declarations
    if lib.tcontains({'VAR_DECL'}, token.type) then
        stream:match('VAR_DECL')
        local n = name(stream)
        local val = {'NONE'}
        if lib.tcontains({'ASSIGN'}, stream:pointer().type) then
            stream:match('ASSIGN')
            val = exp(stream)
        end
        stream:optional('SEMI')
        return {'VAR_DECL', n, val}
    
    -- Function Declarations
    elseif lib.tcontains({'FN_DECL'}, token.type) then
        stream:match('FN_DECL')
        local n = name(stream)
        local ard = decl_args(stream)
        local fb = {'STMT_LIST', {}}
        if lib.tcontains(stmt_lookahead, stream:pointer().type) then
            fb = stmt(stream)
        end
        stream:optional('SEMI')
        return {'FN_DECL', n, ard, fb}

    -- Function Return
    elseif lib.tcontains({'FN_RETURN'}, token.type) then
        stream:match('FN_RETURN')
        local e = {'NONE'}
        if lib.tcontains(exp_lookahead, stream:pointer().type) then
            e = exp(stream)
        end
        stream:optional('SEMI')
        return {'FN_RETURN', e}

    -- Grouped Statements
    elseif lib.tcontains({'LCURLY'}, token.type) then
        stream:match('LCURLY')
        local slist = stmt_list(stream)
        stream:match('RCURLY')
        stream:optional('SEMI')
        return slist

    -- Load Statement
    elseif lib.tcontains({'LOAD'}, token.type) then
        stream:match('LOAD')
        local e = exp(stream)
        stream:optional('SEMI')
        return {'LOAD', e}

    -- Conditional Statement
    elseif lib.tcontains({'IF'}, token.type) then
        stream:match('IF')
        local r = if_suffix(stream)
        stream:optional('SEMI')
        return r
    -- While Statement
    elseif lib.tcontains({'WHILE'}, token.type) then
        stream:match('WHILE')
        local r = while_suffix(stream)
        stream:optional('SEMI')
        return r
    -- Built-in Event Loop Structure
    elseif lib.tcontains({'EVENT_LOOP'}, token.type) then
        stream:match('EVENT_LOOP')
        stream:match('COMMA')
        local res = event_res_list(stream)
        stream:optional('SEMI')
        return {'EVENT_LOOP', res}
    -- Expressions
    elseif lib.tcontains(exp_lookahead, token.type) then
        local e = exp(stream)
        stream:optional('SEMI')
        return e
    else -- None of the above...
        lib.err('stmt: syntax error at {}',{token.value})
    end
end

-- decl_args : {LPAREN} LPAREN ({NAME} NAME ({COMMA} COMMA NAME)* )? RPAREN
function decl_args(stream)
    stream:match('LPAREN')
    local argd = {}
    if lib.tcontains({'NAME'}, stream:pointer().type) then
        local n = name(stream)
        argd = {n}
        while lib.tcontains({'COMMA'}, stream:pointer().type) do
            stream:match('COMMA')
            n = name(stream)
            table.insert(argd, n)
        end
    end
    stream:match('RPAREN')
    return {'DECL_ARGS', argd}
end

-- call_args : LPAREN (exp (COMMA exp)* )? RPAREN
function call_args(stream)
    stream:match('LPAREN')
    local argc = {}
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e = exp(stream)
        argc = {e}
        while lib.tcontains({'COMMA'}, stream:pointer().type) do
            stream:match('COMMA')
            e = exp(stream)
            table.insert(argc, e)
        end
    end
    stream:match('RPAREN')
    return {'CALL_ARGS', argc}
end

-- if_suffix : {LPAREN} LPAREN exp RPAREN stmt
--           | {<see exp lookahead>} exp COMMA stmt
-- ~~ will be updated with 'elif' and 'else' ~~
function if_suffix(stream)
    local token = stream:pointer()
    local e, r -- "expression, response"
    if lib.tcontains({'LPAREN'}, token.type) then
        stream:match('LPAREN')
        e = exp(stream)
        stream:match('RPAREN')
        r = stmt(stream)
    elseif lib.tcontains(exp_lookahead, token.type) then
        e = exp(stream)
        stream:match('COMMA')
        r = stmt(stream)
    else
        lib.err('if-suffix: syntax error at {}',{stream:pointer().value})
    end

    -- else if, else statements
    token = stream:pointer()
    local c = false -- continue?
    if lib.tcontains({'ELSE_IF'}, token.type) then
        stream:match('ELSE_IF')
        c = if_suffix(stream)
    elseif lib.tcontains({'ELSE'}, token.type) then
        stream:match('ELSE')
        local cr = stmt(stream)
        c = {'ELSE', cr}
    end

    return {'IF', e, r, c}
end

-- while_suffix : {LPAREN} LPAREN exp RPAREN stmt
--              | {<see exp lookahead>} exp COMMA stmt
function while_suffix(stream)
    local token = stream:pointer()
    local e, r
    if lib.tcontains({'LPAREN'}, token.type) then
        stream:match('LPAREN')
        e = exp(stream)
        stream:match('RPAREN')
        r = stmt(stream)
    elseif lib.tcontains(exp_lookahead, token.type) then
        e = exp(stream)
        stream:match('COMMA')
        r = stmt(stream)
    else
        lib.err('while-suffix: syntax error at {}',{stream:pointer().value})
    end
    return {'WHILE', e, r}
end

-- base_pair : {NAME,STRING} NAME|STRING COLON {...} exp
function base_pair(stream)
    local token = stream:pointer()

    local pair_name
    if lib.tcontains({'NAME'}, token.type) then
        local tk = stream:match('NAME')
        pair_name = {'NAME', tk.value}
    elseif lib.tcontains({'STRING'}, token.type) then
        local tk = stream:match('STRING')
        pair_name = {'NAME', tostring(tk.value:sub(2, -2))}
    else
        lib.err('base_pair: syntax error at {}',{stream:pointer().value})
    end

    stream:match('COLON')
    local pair_value = exp(stream)
    
    return {'BASE_PAIR', pair_name, pair_value}
end

-- event_res_list : {LPAREN} event_res ({COMMA} COMMA event_res)*
-- event_res      : {LPAREN} LPAREN exp RPAREN AS decl_args stmt
function event_res_list(stream)
    local rl = {}
    if lib.tcontains({'LPAREN'}, stream:pointer().type) then
        table.insert(rl, event_res(stream))
        while lib.tcontains({'COMMA'}, stream:pointer().type) do
            stream:match('COMMA')
            table.insert(rl, event_res(stream))
        end
        return rl
    else
        lib.err('event-res-list: syntax error at {}',{token.value})
    end
end
function event_res(stream)
    stream:match('LPAREN')
    local e = exp(stream)
    stream:match('RPAREN')
    stream:match('AS')
    local a = decl_args(stream)
    local s = stmt(stream)
    return {'EVENT_RES', e, a, s}
end

-- exp      : assign
-- assign   : logicals ({ASSIGN} ASSIGN logicals)*
-- logicals : exp_low (({AND,OR,XOR} AND|OR|XOR) exp_low)*
-- exp_low  : exp_med (({EQU,LEQ,NEQ,GEQ,GT,LT} EQU|LEQ|NEQ|GEQ|GT,LT) exp_med)*
-- exp_med  : exp_high (({PLUS,MINUS,CONCAT} PLUS|MINUS|CONCAT) exp_high)*
-- exp_high : primary (({MUL,DIV} MUL|DIV) primary)*
-- primary  : {MINUS|INTEGER} INTEGER
--          | {NONE} NONE
--          | {TRUE,FALSE} boolean
--          | {STRING} STRING
--          | {LBRACK} LBRACK ({<see exp lookahead>} exp COMMA)* RBRACK
--          | {LCURLY} LCURLY ({NAME,STRING} base_pair COMMA)* RCURLY
--          | {FN_DECL} lambda
--          | {NAME} NAME ({LPAREN} call_args)?
--          | {SPECIAL} special
--          | {LPAREN} LPAREN exp RPAREN
--          | {NOT} NOT exp
--          | * (primary_suffix)?
exp_lookahead = {'ASSIGN', 'AND', 'OR', 'XOR', 'EQU', 'LEQ', 'NEQ', 'GEQ', 'GT',
    'LT', 'PLUS', 'MINUS', 'CONCAT', 'MUL', 'DIV', 'INTEGER', 'STRING', 'LBRACK',
    'LCURLY', 'FN_DECL', 'NAME', 'SPECIAL', 'LPAREN', 'NOT', 'TRUE', 'FALSE',
    'NONE', 'BREAKLINE'}
function exp(stream)
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        return assign(stream)
    else
        lib.err('exp: syntax error at {}',{stream:pointer().value})
    end
end
function assign(stream)
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e1 = logicals(stream)
        while lib.tcontains({'ASSIGN'}, stream:pointer().type) do
            local op = stream:match(stream:pointer().type)
            local e2 = logicals(stream)
            e1 = {op.type, e1, e2} -- e1 (op) e2
        end
        return e1
    else
        lib.err('assign: syntax error at {}',{stream:pointer().value})
    end
end
function logicals(stream)
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e1 = exp_low(stream)
        while lib.tcontains({'AND', 'OR', 'XOR'}, stream:pointer().type) do
            local op = stream:match(stream:pointer().type)
            local e2 = exp_low(stream)
            e1 = {op.type, e1, e2} -- e1 (op) e2
        end
        return e1
    else
        lib.err('logicals: syntax error at {}',{stream:pointer().value})
    end
end
function exp_low(stream)
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e1 = exp_med(stream)
        while lib.tcontains({'EQU','LEQ','NEQ','GEQ','GT','LT'}, stream:pointer().type) do
            local op = stream:match(stream:pointer().type)
            local e2 = exp_med(stream)
            e1 = {op.type, e1, e2} -- e1 (op) e2
        end
        return e1
    else
        lib.err('exp-low: syntax error at {}',{stream:pointer().value})
    end
end
function exp_med(stream)
    if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e1 = exp_high(stream)
        while lib.tcontains({'PLUS','MINUS','CONCAT'}, stream:pointer().type) do
            local op = stream:match(stream:pointer().type)
            local e2 = exp_high(stream)
            e1 = {op.type, e1, e2} -- e1 (op) e2
        end
        return e1
    else
        lib.err('exp-med: syntax error at {}',{stream:pointer().value})
    end
end
function exp_high(stream)
        if lib.tcontains(exp_lookahead, stream:pointer().type) then
        local e1 = primary(stream)
        while lib.tcontains({'MUL','DIV'}, stream:pointer().type) do
            local op = stream:match(stream:pointer().type)
            local e2 = primary(stream)
            e1 = {op.type, e1, e2} -- e1 (op) e2
        end
        return e1
    else
        lib.err('exp-high: syntax error at {}',{stream:pointer().value})
    end
end
function primary(stream)
    local token = stream:pointer()
    local res_value

    -- Integer
    if lib.tcontains({'MINUS', 'INTEGER'}, token.type) then
        local sign = 1
        if token.type == 'MINUS' then
            sign = -1
            stream:match('MINUS')
        end
        local tk = stream:match('INTEGER')
        res_value = {'CONST', tonumber(tk.value) * sign}

    -- Non-value
    elseif lib.tcontains({'NONE'}, token.type) then
        stream:match('NONE')
        res_value = {'NONE'}
        
    -- Boolean Value
    elseif lib.tcontains({'TRUE','FALSE'}, token.type) then
        res_value = boolean(stream)

    -- String
    elseif lib.tcontains({'STRING'}, token.type) then
        local tk = stream:match('STRING')
        res_value = {'CONST', tostring(tk.value:sub(2, -2))}

    -- List
    elseif lib.tcontains({'LBRACK'}, token.type) then
        stream:match('LBRACK')
        local list_elements = {}
        while lib.tcontains(exp_lookahead, stream:pointer().type) do
            table.insert(list_elements, exp(stream))
            if stream:pointer().type ~= 'RBRACK' then
                stream:match('COMMA')
            end
        end
        stream:match('RBRACK')
        res_value = {'LIST', list_elements}

    -- Base
    elseif lib.tcontains({'LCURLY'}, token.type) then
        stream:match('LCURLY')
        local pair_list = {}
        while lib.tcontains({'NAME','STRING'}, stream:pointer().type) do
            table.insert(pair_list, base_pair(stream))
            if stream:pointer().type ~= 'RCURLY' then
                stream:match('COMMA')
            end
        end
        stream:match('RCURLY')
        res_value = {'BASE', pair_list}

    -- Lambda
    elseif lib.tcontains({'FN_DECL'}, token.type) then
        res_value = lambda(stream)

    -- Variable
    elseif lib.tcontains({'NAME'}, token.type) then
        local n = name(stream)
        res_value = n
    
    -- Special
    elseif lib.tcontains({'SPECIAL'}, token.type) then
        res_value = special(stream)

    -- Nested Expression
    elseif lib.tcontains({'LPAREN'}, token.type) then
        stream:match('LPAREN')
        local e = exp(stream)
        stream:match('RPAREN')
        res_value = e

    -- Not Expression
    elseif lib.tcontains({'NOT'}, token.type) then
        stream:match('NOT')
        res_value = {'NOT', exp(stream)}

    else
        lib.err('primary: syntax error at {}',{stream:pointer().value})
    end

    -- optional, suffix
    while lib.tcontains(primary_suffix_lookahead, stream:pointer().type) do
        local suffix = primary_suffix(stream)
        suffix[2] = res_value
        res_value = suffix
    end

    return res_value
end

-- primary suffix : {LBRACK} LBRACK exp RBRACK
--                | {PERIOD} PERIOD name
--                | {LPAREN} call_args
--                | * (primary_suffix)?
primary_suffix_lookahead = {'LBRACK', 'PERIOD', 'LPAREN'}
function primary_suffix(stream)
    local token = stream:pointer()
    local res_value
    -- of res_value, second value stays nil...

    -- indexing...
    if lib.tcontains({'LBRACK'}, token.type) then
        stream:match('LBRACK')
        local e = exp(stream)
        stream:match('RBRACK')
        res_value = {'INDEX', false, e}
    -- property...
    elseif lib.tcontains({'PERIOD'}, token.type) then
        stream:match('PERIOD')
        local n = name(stream)
        res_value = {'PROPERTY', false, n}
    -- function call...
    elseif lib.tcontains({'LPAREN'}, token.type) then
        local c = call_args(stream)
        res_value = {'FN_CALL', false, c}
    else
        lib.err('primary-suffix: syntax error at {}',{stream:pointer().value})
    end

    return res_value
end

-- lambda : {FN_DECL} FN_DECL decl_args stmt (SEMI)?
function lambda(stream)
    stream:match('FN_DECL')
    local ard = decl_args(stream)
    local fb = stmt(stream)
    stream:optional('SEMI')
    return {'LAMBDA', ard, fb}
end

function name(stream)
    if lib.tcontains({'NAME'}, stream:pointer().type) then
        local ntk = stream:match('NAME')
        return {'NAME', ntk.value}
    else
        lib.err('name: syntax error at {}',{stream:pointer().value})
    end
end
function special(stream)
    stream:match('SPECIAL')
    local ntk = stream:match('NAME')
    return {'SPECIAL', ntk.value}
end
function boolean(stream)
    local token = stream:pointer()
    if lib.tcontains({'TRUE'}, token.type) then
        stream:match('TRUE')
        return {'CONST', true}
    elseif lib.tcontains({'FALSE'}, token.type) then
        stream:match('FALSE')
        return {'CONST', false}
    else
        lib.err('boolean: syntax error at {}',{stream:pointer().value})
    end
end

------------------------------------------------------------
-- add exp_lookahead to stmt_lookahead
for i,v in ipairs(exp_lookahead) do table.insert(stmt_lookahead, v) end
------------------------------------------------------------

function parse(stream)
    local token_stream = Lexer.new(stream)
    state.program = stmt_list(token_stream)
    state.instr_ix = #state.program[2]+1
    if not token_stream:is_eof() then
        lib.err('parse: syntax error at {}',{token_stream:pointer().value})
    end
end

return parse