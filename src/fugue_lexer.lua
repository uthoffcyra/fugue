--[[
fugue language lexer
]]--

local lib = require('fugue_lib')
local args = {...}

local token_specs = {
    -- comments
    {'COMMENT', '~[^~]*~'},
    -- keywords
    {'VAR_DECL',    'let'},
    {'FN_DECL',     'fn'},
    {'FN_RETURN',   'res'},
    {'LOAD',        'load'},
    {'IF',          'if'},
--  {'ELSE_IF',     'elif'},
--  {'ELSE',        'else'},
    {'WHILE',       'while'},
    {'EVENT_LOOP',  'event%-loop'},
    {'AS',          'as'},
    -- special characters
    {'EQU',     '=='},
    {'LEQ',     '<='},
    {'NEQ',     '!='},
    {'GEQ',     '>='},
    {'GT',      '>'},
    {'LT',      '<'},
    {'PLUS',    '%+'},
    {'MINUS',   '%-'},
    {'MUL',     '%*'},
    {'DIV',     '%/'},
    {'CONCAT',  '%.%.'},
    {'LCURLY',  '{'},
    {'RCURLY',  '}'},
    {'LPAREN',  '%('},
    {'RPAREN',  '%)'},
    {'COMMA',   ','},
    {'COLON',   ':'},
    {'SEMI',    ';'},
    {'ASSIGN',  '='},
    {'SPECIAL', '@'},
    {'NOT',     '!'},
    -- names, numbers, etc
    {'NONE',       'none'},
    {'TRUE',       'true'},
    {'FALSE',      'false'},
    {'NAME',       '[%a_][%w_]*'},
    {'STRING',     '"[^\")]*"'},
    {'STRING',     "'[^\']*'"},
    {'INTEGER',    '%d+'},
    {'WHITESPACE', '[ \t\n]+'},
    {'UNKNOWN',    '.'}
}

-- used for sanity checking in lexer
local token_types = {}
for i,n in ipairs(token_specs) do table.insert(token_types,n[1]) end

Token = {}
Token.__index = Token
function Token.new(type, value)
    local self = setmetatable({}, Token)
    self.type = type
    self.value = value
    return self
end
function Token:string()
    return lib.format('Token({},{})',{self.type,self.value})
end

function tokenize(code)
    tokens = {}
    for match in finditer_multi(token_specs, code) do
        --print(string.format("'%s' at %d-%d (%s)", match.value, match.start, match.finish, match.type))
        if lib.tcontains({'WHITESPACE','COMMENT'}, match.type) then -- pass
            if (match.type == 'COMMENT') then
            end
        elseif match.type == 'UNKNOWN' then -- error, unknown token
            lib.err('unexpected character \'{}\'',{match.value})
        else -- apply token data
            table.insert(tokens, Token.new(match.type, match.value))
        end
    end
    table.insert(tokens, Token.new('EOF', '\\eof'))
    return tokens
end

Lexer = {}
Lexer.__index = Lexer
function Lexer.new(input_string)
    local self = setmetatable({},Lexer)
    self.tokens = tokenize(input_string)
    self.curr_token_ix = 1
    return self
end
function Lexer:pointer()
    return self.tokens[self.curr_token_ix]
end
function Lexer:next()
    if not self.is_eof(self) then
        self.curr_token_ix = self.curr_token_ix + 1
    end
    return self.pointer(self)
end
function Lexer:match(token_type)
    if token_type == self.pointer(self).type then
        local tk = self.pointer(self)
        self.next(self)
        return tk
    elseif not lib.tcontains(token_types,token_type) then
        lib.err('unknown token type \'{}\'',{token_type})
    else
        lib.err('unexpected token {} while parsing, expected {}',
            {self.pointer(self).type, token_type})
    end
end
function Lexer:optional(token_type)
    if lib.tcontains({token_type}, self.pointer(self).type) then
        self.match(self, token_type)
    end
end
function Lexer:is_eof()
    return (self.pointer(self).type == 'EOF')
end
function Lexer:string()
    return lib.format('Lexer({} tokens, index={})',{#self.tokens, self.curr_token_ix})
end

return { -- exports
    Lexer=Lexer
}