local mty = require'metaty'
local term = require'civix.term'
local model = require'ele.model'

local M = {}
M.main = function()
  local inp = term.unix.input()
  mty.pnt"## Running ('q q' to quit)"
  local mdl = model.testModel(term.Term, inp)
  mdl:app()
end

M.main()

return M
