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
})

local Shrm = struct('Shrm', {
  {'mode', Str}, -- the UI mode (command, insert)
  'view', -- Edit or Cols or Rows
  {'buffers', List}, {'bufferI', Num},
  {'epoch', nil, shix.epoch},
  {'start', Epoch}, {'lastDraw', Epoch},

  {'inputCo'},

  -- events from inputCo (LL)
  {'events'},

  {'statusBuf', Buffer},
})


-- #####################
-- # Edit struct
-- Implements an edit view and state

-- draw to term (l, c, w, h)
method(Edit, 'draw', function(e, tl, tc, th, tw)
  assert((tl > 0) and (tc > 0) and (tw > 0) and (th > 0))
  for l, line in ipairs(e.buf.gap:sub(e.vl, e.vl + th - 1)) do
    term.golc(tl + l - 1, tc); term.cleareol()
    outf(string.sub(line, 1, e.vc + tw - 1))
  end
  term.golc(tl + e.l - 1, tc + e.c - 1)
end)

local function event(key)
  return key
end

-- #####################
-- # Key Bindings

-- the fields are type KeyBindings or Function
local KeyBindings = struct('KeyBindings', {'u', 'cmd', 'ctl'})
method(KeyBindings, 'new', function()
  return KeyBindings{u={}, cmd={}, ctl={}}
end)
local Bindings = struct('Bindings', {
  {'insert', KeyBindings}, {'command', KeyBindings},
})

local function assertBinding(ty_, key)
  -- Check the binding
  if     'u'   == ty_ then term.assertU(key)
  elseif 'cmd' == ty_ then term.assertCmd(key)
  elseif 'ctl' == ty_ then term.assertCtl(key)
  else assert(false, ty_) end
end

local function _unpackPart(part)
  if type(part) == 'string' then return 'u', part end
  if part.u   then return 'u', part.u end
  if part.ctl then return 'ctl', part.ctl end
  if part.cmd then return 'cmd', part.cmd end
  error('unknown part', tfmt(part))
end

local function setKeyUBinding(kb, u, v)
  for ch in string.gmatch(key, '.') do
  end

end

local function setKeyBindings(kb, chord, fn)
  for i, part in ipairs(chord) do
    local ty_, key = _unpackpart(part)
    -- if last set to fn, else set to key bindings
    local v; if #chord == i then v = fn

    else                         v = KeyBindings.new() end
    if ty == 'u' then
      setKeyUBinding(kb, u, v)
    else
      assertBinding(ty_, key)

    end

  end
end

-- Set bindings
--   b:set('command', 'ctl', 'a',       function(app) ... end)
--   b:set('command', {{ctl='a'}},      function(app) ... end)
--   b:set('command', {{ctl='a'}, 'a'}, function(app) ... end)
method(Bindings, 'set', function(b, mode, ty_, key, fn)
  local m = b[mode]
  if not m then error(
    string.format('%s not a valid mode: insert, command')
  )end

  local chord
  if type(ty_) == 'string' then chord = {[ty_] = key}
  else chord = ty_; fn = key; assert(not fn, 'extra arguments'); end
  for _, part in ipairs(chord) do


    local kb = m[ty_]
    if not kb then error(
      string.format('%s not a valid type: u, cmd, ctl', ty_)
    )end
    assertBinding(ty_, key)
    if mode ~= 'u' then kb[key] = fn; return end
    local i, len = 1, #key
    assert(len > 0, 'empty key')
    for ch in sring.gmatch(key, '.') do
      term.assertU(ch, key)
      if i == len then kb[ch] = fn; break end
      local ub = kb[ch]
      if type(ub) ~= 'table' then ub = {}; kb[ch] = ub end
      kb = ub
      i = i + i
    end

  end

end)
method(Bindings, 'update', function(b, mode, ty_, bindings)
  for key, fn in pairs(bindings) do
    b:set(mode, ty_, key, fn)
  end
end)

-- default key bindings (updated in Default Bindings section)
local _keyBindings = KeyBindings{u={}, cmd={}, ctl={}}
local BINDINGS = Bindings{
  insert = deepcopy(_keyBindings),
  command = deepcopy(_keyBindings),
}
method(Bindings, 'default', function() return deepcopy(BINDINGS) end)

-- #####################
-- # Shrm struct
-- Implements the core app


method(Shrm, '__tostring', function() return 'Shrm' end)
method(Shrm, 'new', function()
  local sts = Buffer.new()
  local sh = {
    mode='command',
    buffers=List{}, bufferI=1,
    start=Epoch(0), lastDraw=Epoch(0),
    inputCo=nil,
    events=LL(),
    statusBuf=sts,
    w=100, h=50,
  }
  sh.view = Edit{buf=sts, l=1, c=1, vl=1, vc=1, container=sh}
  sh.inputCo  = term.input()
  return setmetatable(sh, Shrm)
end)

-- #####################
-- # Utility methods
method(Shrm, 'status', function(self, m)
  if type(m) ~= 'string' then m = concat(m) end
  self.statusBuf.gap:append(m)
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
local _UPDATE_MODE = {
  command=function(shrm, ev)
  end,
  insert=function(shrm, ev)
    -- print('Doing insert', ev)
  end,
}
method(Shrm, 'update', function(self)
  debug('update loop')
  while not self.events:isEmpty() do
    if self:loopReturn() then return end
    local ev = self.events:popBack()


    self:status({
      'Event[', self.mode, ']: ', tostring(ev), '\n'})
    _UPDATE_MODE[self.mode](self, ev)
  end
  debug('update end')
end)
-- the main loop

-- #####################
--   * step: run all pieces
method(Shrm, 'step', function(self)
  local key = self.inputCo()
  debug('got key', key)
  if key.ctl == 'q' then
    debug('\nctl+q received, ending\n')
    return false
  end
  if key then self.events:addFront(event(key)) end
  debug('calling update')
  self:update()
  self:draw()
  return true
end)

method(Shrm, 'app', function(self)
  term.enterRawMode()
  while true do
    self.start = shix.epoch()
    if not self:step() then break end
    local spent = self:spent()
    if spent < DRAW_PERIOD then
      shix.sleep(DRAW_PERIOD - spent)
    end
  end
  term.exitRawMode()
  print('\nExited app')
end)

-- #####################
-- # Default Bindings

-- Insert Mode
BINDINGS:update('insert', 'ctl', {
  j=function(app) app.mode = 'command' end,
  q=function(app) app.mode = 'quit'    end,
})
BINDINGS:update('insert', 'cmd', {
  esc=function(app) app.mode = 'command' end,
  q=function(app) app.mode = 'quit'      end,
})

-- Command Mode
BINDINGS:update('command', 'u', {
  i=function(app) app.mode = 'insert'    end,
})

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
