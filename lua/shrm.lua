local civ  = require'civ':grequire()
local shix = require'shix'
local term = require'plterm'
local gap  = require'gap'
local posix = require'posix'

local yld = coroutine.yield
local outf = term.outf
local debug = term.debug

local shrm = {} -- module

local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }

-- #####################
-- # Data structures

local Change = struct('Diff', {
  {'l', Num},  {'c', Num},                -- start of action
  {'l2', Num, false}, {'c2', Num, false}, -- (optional) end
  {'value', Str, false}, -- value removed in action
})

local Buffer = struct('Buffer', {
  {'gap', gap.Gap},

  -- recorded changes from update
  {'changes', List}, {'changeI', Num}, -- undo/redo
})
method(Buffer, 'new', function()
  return Buffer{
    gap=gap.Gap.new(),
    changes=List{}, changeI=0,
  }
end)

local Edit = struct('Edit', {
  {'buf', Buffer},

  {'l',  Num}, {'c',  Num}, -- cursor (line,col)
  {'vl', Num}, {'vc', Num}, -- view (top left l,c)

  -- where this is contained
  -- (Shrm, Rows, Cols)
  'container',
  'bindings',
})

local Action = struct('Action', {
  {'name', Str}, {'fn', Fn},
  {'brief', Str, false}, {'doc', Str, false},
  'config', 'data', -- action specific
})

-- Bindings to Actions
local Bindings = struct('Bindings', {
  {'insert', Map}, {'command', Map},
})

local Shrm = struct('Shrm', {
  {'mode', Str}, -- the UI mode (command, insert)
  'view', -- Edit or Cols or Rows
  'edit', -- The active editor
  {'buffers', List}, {'bufferI', Num},
  {'epoch', nil, shix.epoch},
  {'start', Epoch}, {'lastDraw', Epoch},
  {'bindings', Bindings},
  {'chord', Map, false}, {'chordKeys', List},

  {'inputCo'},

  -- events from inputCo (LL)
  {'events'},

  {'statusBuf', Buffer},
})


-- #####################
-- # Edit struct
-- Implements an edit view and state

-- These are going to track state/cursor/etc
method(Edit, 'insert', function(e, s)
  e.buf.gap:insert(s, e.l, e.c)
  e.l, e.c = e.buf.gap:offset(#s, e.l, e.c)
end)
method(Edit, 'remove', function(e, ...)
  self.gap:remove(...)
end)
method(Edit, 'append', function(e, ...)
  self.gap:append(...)
end)

-- draw to term (l, c, w, h)
method(Edit, 'draw', function(e, tl, tc, th, tw)
  assert((tl > 0) and (tc > 0) and (tw > 0) and (th > 0))
  for l, line in ipairs(e.buf.gap:sub(e.vl, e.vl + th - 1)) do
    term.golc(tl + l - 1, tc); term.cleareol()
    outf(string.sub(line, 1, e.vc + tw - 1))
  end
  term.golc(tl + e.l - 1, tc + e.c - 1)
end)

-- #####################
-- # Key Bindings

method(Bindings, '_update', function(b, mode, bindings, checker)
  local bm = b[mode]
  for keys, act in pairs(bindings) do
    assertEq(ty(act), Action)
    assertEq(ty(act.fn), Fn)
    keys = term.parseKeys(keys)
    if checker then
      for _, k in ipairs(keys) do checker(k) end
    end
    bm:setPath(keys, act)
  end
end)
method(Bindings, 'updateInsert', function(b, bindings)
  return b:_update('insert', bindings, function(k)
    if term.isInsertKey(k) then error(
      'bound visible in insert mode: '..k
    )end
  end)
end)
method(Bindings, 'updateCommand', function(b, bindings)
  return b:_update('command', bindings)
end)

-- default key bindings (updated in Default Bindings section)
local BINDINGS = Bindings{
  insert = Map{}, command = Map{},
}
method(Bindings, 'default', function() return deepcopy(BINDINGS) end)

-- #####################
-- # Shrm struct
-- Implements the core app

method(Shrm, '__tostring', function() return 'APP' end)
method(Shrm, 'new', function()
  local sts = Buffer.new()
  local sh = {
    mode='command',
    buffers=List{}, bufferI=1,
    start=Epoch(0), lastDraw=Epoch(0),
    bindings=Bindings.default(),
    chord=nil, chordKeys=List{},

    inputCo=nil,
    events=LL(),
    statusBuf=sts,
    w=100, h=50,
  }
  sh.view = Edit{buf=sts, l=1, c=1, vl=1, vc=1, container=sh}
  sh.edit = sh.view
  sh.inputCo  = term.input()
  return setmetatable(sh, Shrm)
end)

-- #####################
-- # Utility methods
method(Shrm, 'status', function(self, m)
  if type(m) ~= 'string' then m = concat(m) end
  self.statusBuf.gap:append(m)
  term.debug('Status: ', m)
end)
method(Shrm, 'spent', function(self)
  return shix.epoch() - self.start
end)
method(Shrm, 'loopReturn', function(self)
  -- local spent = self:spent()
  -- if DRAW_PERIOD < spent then
  --   return true
  -- end
  return false
end)

-- #####################
--   * draw
method(Shrm, 'draw', function(self)
  local lastDraw = shix.epoch() - self.lastDraw
  if DRAW_PERIOD < lastDraw then
    h, w = term.size()
    term.clear()
    self.view:draw(1, 1, h, w)
  end
end)

-- #####################
--   * update

method(Shrm, 'unrecognized', function(self, keys)
  self:status('unrecognized chord: ' .. concat(keys, ' '))
end)

method(Shrm, 'defaultAction', function(self, keys)
  if self.mode == 'command' then
    self:unrecognized(keys)
  elseif self.mode == 'insert' then
    if not self.edit then return self:status(
      'Open a buffer to insert'
    )end

    for _, k in ipairs(keys) do
      if not term.isInsertKey(k) then
        self:unrecognized(k)
      else
        self.edit:insert(term.KEY_INSERT[k] or k)
      end
    end
  end
end)

method(Shrm, 'update', function(self)
  debug('update loop')
  while not self.events:isEmpty() do
    local ev = self.events:popBack()
    local action = nil
    if type(ev) == 'string' then
      self.chordKeys:add(ev)
      self.chord = self.chord or self.bindings[self.mode]
      action = self.chord[ev]
      if not action then
        local keys = self.chordKeys
        self.chordKeys = List{}
        self:defaultAction(keys)
      elseif Action == ty(action) then -- found, continue
      elseif Map == ty(action) then
        self.chord, action = action, nil
        self.chordKeys = self.chordKeys or List{}
        self.chordKeys:add(ev)
      else error(action) end
    else error(ev) end

    if action then action.fn(self, action)
    else self:status({
      'NoAction[', self.mode, ']: ', tostring(ev)})
    end
    if self:loopReturn() then break end
  end
  debug('update end')
end)
-- the main loop

-- #####################
--   * step: run all pieces
method(Shrm, 'step', function(self)
  local key = self.inputCo()
  self.start = shix.epoch()
  debug('got key', key)
  if key == '^C' then
    debug('\nctl+C received, ending\n')
    return false
  end
  if key then self.events:addFront(key) end
  debug('calling update')
  self:update()
  if self.mode == 'quit' then return false end
  self:draw()
  return true
end)

method(Shrm, 'app', function(self)
  term.enterRawMode()
  while true do
    if not self:step() then break end
  end
  term.exitRawMode()
  print('\nExited app')
end)

-- #####################
-- # Actions
shrm.QuitAction = Action{
  name='quit', brief='quit the application',
  fn = function(app) app.mode = 'quit'    end,
}
shrm.CommandAction = Action{
  name='command', brief='go to command mode',
  fn = function(app)
    app.mode = 'command'
    app.chord = nil
  end,
}
shrm.InsertAction = Action{
  name='insert', brief='go to insert mode',
  fn = function(app)
    app.mode = 'insert'
    app.chord = nil
  end,
}

-- #####################
-- # Default Bindings

-- -- Insert Mode
BINDINGS:updateInsert{
  ['^Q ^Q'] = shrm.QuitAction,
  ['^J']    = shrm.CommandAction,
  ['esc']   = shrm.CommandAction,
}

-- Command Mode
BINDINGS:updateCommand{
  ['^Q ^Q'] = shrm.QuitAction,
  i         = shrm.InsertAction,
}

-- #####################
-- # Main

local function main()
  print"## Running (shrm ctl+q to quit)"
  local sh = Shrm.new()
  sh:app()
end

if not civ.TESTING then main() end

update(shrm, {
  Shrm=Shrm,
})
return shrm
