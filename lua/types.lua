local civ  = require'civ':grequire()
local gap  = require'gap'

local M = {}

M.Change = struct('Diff', {
  {'l', Num},  {'c', Num},                -- start of action
  {'l2', Num, false}, {'c2', Num, false}, -- (optional) end
  {'value', Str, false}, -- value removed in action
})

M.Buffer = struct('Buffer', {
  {'gap', gap.Gap},

  -- recorded changes from update
  {'changes', List}, {'changeI', Num}, -- undo/redo
})


M.Edit = struct('Edit', {
  {'buf', Buffer},
  {'canvas', List, false},

  {'l',  Num}, {'c',  Num}, -- cursor (line,col)
  {'vl', Num}, {'vc', Num}, -- view lines, cols
  {'vh', Num}, {'vw', Num}, -- view height, width

  -- where this is contained
  -- (Lede, Rows, Cols)
  'container',
})

M.Action = struct('Action', {
  {'name', Str}, {'fn', Fn},
  {'brief', Str, false}, {'doc', Str, false},
  'config', 'data', -- action specific
})

-- Bindings to Actions
M.Bindings = struct('Bindings', {
  {'insert', Map}, {'command', Map},
})

M.Lede = struct('Lede', {
  {'mode', Str}, -- the UI mode (command, insert)
  {'h', Num}, {'w', Num},
  'view', -- Edit or Cols or Rows
  'edit', -- The active editor
  {'buffers', List}, {'bufferI', Num},
  {'start', Epoch}, {'lastDraw', Epoch},
  {'bindings', Bindings},
  {'chord', Map, false}, {'chordKeys', List},

  {'inputCo'},

  -- events from inputCo (LL)
  {'events'},

  {'statusBuf', Buffer},
})

return M
