local civ  = require'civ':grequire()
local gap  = require'ele.gap'

local M = {Gap=gap.Gap}

M.ViewId = 0
M.ChangeId = 0
M.nextViewId   = function() M.ViewId   = M.ViewId   + 1; return M.ViewId   end
M.nextChangeId = function() M.ChangeId = M.ChangeId + 1; return M.ChangeId end

-- Buffer and sub-types
M.ChangeStart = struct('ChangeStart', {
  {'l1', Num}, {'c1', Num}, {'l2', Num, false}, {'c2', Num, false},
})
M.Change = struct('Change', {
  {'k', Str}, -- kind: ins/rm
  {'s', Str}, {'l', Num}, {'c', Num},
})
M.Buffer = struct('Buffer', {
  'id',
  {'gap', gap.Gap},

  -- recorded changes from update (for undo/redo)
  {'changes', List}, {'changeMax', Num},
  {'changeStartI', Num}, {'changeI', Num},
  'mdl',
})

-- Window container
-- Note: Window also acts as a list for it's children
M.Window = struct('Window', {
  {'id', Num},
  'container', -- parent (Window/Model)
  {'splitkind', Str, false}, -- nil, h, v
  {'tl', Num}, {'tc', Num}, -- term lines, cols
  {'th', Num}, {'tw', Num}, -- term height, width
})

M.Edit = struct('Edit', {
  {'id', Num},
  'container', -- parent (Window/Model)
  {'canvas', List, false},
  {'buf', Buffer},

  {'l',  Num}, {'c',  Num}, -- cursor line, col
  {'vl', Num}, {'vc', Num}, -- view   line, col (top-left)
  {'tl', Num}, {'tc', Num}, -- term   line, col (top-left)
  {'th', Num}, {'tw', Num}, -- term   height, width
  {'fh', Num, 0}, {'fw', Num, 0}, -- force h,w

  -- where this is contained
  -- (Lede, Rows, Cols)
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

M.Model = struct('Model', {
  {'mode', Str}, -- the UI mode (command, insert)
  {'h', Num}, {'w', Num}, -- window height/width
  'view', -- Edit or Cols or Rows
  'edit', -- The active editor
  'statusEdit', 'searchEdit',
  {'buffers', Map}, {'bufId', Num}, {'bufIds', Map},
  {'start', Epoch}, {'lastDraw', Epoch},
  {'bindings', Bindings},
  {'chord', Map, false}, {'chordKeys', List},
  'chain',
  'inputCo', 'term',
})


return M
