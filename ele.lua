local mty = require'metaty'
local term = require'civix.term'
local model = require'ele.model'

local M = {}
M.main = function()
  local log = io.open('./out/LOG', 'w')
  local tm = term.Term
  tm:start(log, log)
  local inp = term.niceinput(stdout)
  local mdl = model.testModel(term.Term, inp)
  mdl:app()
end

M.main()

return M
