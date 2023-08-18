local term = require'ele.term'
local model = require'ele.model'

M = {}
M.main = function()
  local inp = term.unix.input()
  pnt"## Running ('q q' to quit)"
  local mdl = model.testModel(term.UnixTerm, inp)
  mdl:app()
end

M.main()

return M
