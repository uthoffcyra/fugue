--[[
stack interpreter : state
]]--

State = {}
State.__index = State
function State.new()
    local self = setmetatable({},State)
    self.initialize(self)
    return self
end
function State:initialize()
    self.program = {}
    self.stack = {}
    self.symbol_table = {}
    self.label_table = {}
    self.instr_ix = 1
end

return State.new()