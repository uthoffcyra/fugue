--[[

symbol table for fugue lang

]]--

local lib = require('fugue_lib')

local CURR_SCOPE = 0;

SymTab = {}
SymTab.__index = SymTab
function SymTab.new()
    local self = setmetatable({},SymTab)
    self.initialize(self)
    return self
end
function SymTab:initialize()
    self.scoped_symtab = {}
end
function SymTab:push_scope()
    table.insert(self.scoped_symtab, {})
    CURR_SCOPE = CURR_SCOPE + 1
end
function SymTab:pop_scope()
    table.remove(self.scoped_symtab, CURR_SCOPE)
    CURR_SCOPE = CURR_SCOPE - 1
end
function SymTab:declare(sym,init)
    self.scoped_symtab[CURR_SCOPE][sym] = init
end
function SymTab:lookup_sym(sym, special)
    local b = CURR_SCOPE
    while b > 0 do
        local s = self.scoped_symtab[b][sym]
        if s then
            if special and s[1]=='special' then
                return s
            elseif not special then
                return s
            end
        end
        b = b - 1
    end
    return {'none'}
end
function SymTab:update_sym(sym,var)
    local b = CURR_SCOPE
    while b > 0 do
        if self.scoped_symtab[b][sym] then
            self.scoped_symtab[b][sym] = var
            return
        end
        b = b - 1
    end
    lib.err('attempt to update undeclared variable')
end
function SymTab:scope_id()
    return CURR_SCOPE
end

return SymTab.new()