local civ  = require'civ':grequire()
local gap  = require'gap'

local M = {}

M.ViewId = 0
M.nextViewId = function() M.ViewId = M.ViewId + 1; return M.ViewId end

-- Id used for views and edit
-- Event object, sent to update method which can emit new events
M.Event = civ.newTy('Event')
M.Event.__index = civ.methIndex
civ.constructor(M.Event, function(ty_, ev)
  assert(ev[1], "missing event name as index 1: " + tfmt(ev))
end)

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

-- Window container
-- Note: Window also acts as a list for it's children
M.Window = struct('Window', {
  {'id', Num},
  'container', -- parent (Window/Model)
  {'canvas', List, false},
  {'splitkind', Str, false}, -- nil, h, v
  {'tl', Num}, {'tc', Num}, -- view lines, cols
  {'th', Num}, {'tw', Num}, -- view height, width
})

M.Edit = struct('Edit', {
  {'id', Num},
  'container', -- parent (Window/Model)
  {'canvas', List, false},
  {'buf', Buffer},

  {'l',  Num}, {'c',  Num}, -- cursor (line,col)
  {'tl', Num}, {'tc', Num}, -- view lines, cols
  {'th', Num}, {'tw', Num}, -- view height, width

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

M.Model = struct('Model', {
  {'mode', Str}, -- the UI mode (command, insert)
  {'h', Num}, {'w', Num}, -- window height/width
  'view', -- Edit or Cols or Rows
  'edit', -- The active editor
  {'buffers', List}, {'bufferI', Num},
  {'start', Epoch}, {'lastDraw', Epoch},
  {'bindings', Bindings},
  {'chord', Map, false}, {'chordKeys', List},

  'inputCo', 'term',

  {'statusBuf', Buffer},
})


return M
