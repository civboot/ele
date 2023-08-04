
local M = {}

mod.isInsertKey = function(k)
  return 1 == #k or term.KEY_INSERT[k]
end

