local civ  = require'civ':grequire()
local shix = require'shix'
local term = require'plterm'
local gap  = require'gap'
local posix = require'posix'

local yld = coroutine.yield
local outf = term.outf

local shrm = {} -- module

local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }

shrm.ATEXIT = {}
shrm.enterRawMode = function()
  assert(not getmetatable(shrm.ATEXIT))
  local SAVED, err, msg = term.savemode()
  assert(err, msg); err, msg = nil, nil
  local atexit = {
    __gc = function()
      term.clear()
      term.restoremode(SAVED)
      print('\n## Restored terminal from rawmode')
   end,
  }
  setmetatable(shrm.ATEXIT, atexit)
  term.setrawmode()
end
shrm.exitRawMode = function()
  local mt = getmetatable(shrm.ATEXIT); assert(mt)
  mt.__gc()
  setmetatable(shrm.ATEXIT, nil)
end

local debugF = io.open('./out/debug.log', 'w')
local function debug(...)
  for _, v in ipairs({...}) do
    debugF:write(tostring(v))
    debugF:write('\t')
  end
  debugF:write('\n')
  debugF:flush()
end

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
  return {key=key}
end

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

local _UPDATE_MODE = {
  command=function(shrm, ev)
  end,
  insert=function(shrm, ev)
    -- print('Doing insert', ev)
  end,
}
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
  sh.inputCo  = term.rawinput()
  return setmetatable(sh, Shrm)
end)
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
method(Shrm, 'draw', function(self)
  local lastDraw = shix.epoch() - self.lastDraw
  if DRAW_PERIOD < lastDraw then
    h, w = term.size()
    term.clear()
    self.view:draw(1, 1, h, w)
  end
end)
method(Shrm, 'update', function(self)
  debug('update loop')
  while not self.events:isEmpty() do
    debug('update event')
    if self:loopReturn() then return end
    local ev = self.events:popBack()
    debug('doing event', ev)
    self:status({'Event[', self.mode, ']: ', fmt(ev), '\n'})
    _UPDATE_MODE[self.mode](self, ev)
  end
  debug('update end')
end)
-- the main loop

method(Shrm, 'step', function(self)
  local key = self.inputCo()
  debug('got key', key)
  if 3 == key then
    debug('\nctrl+c received, ending\n')
    return false
  end
  if key then self.events:addFront(event(key)) end
  debug('calling update')
  self:update()
  self:draw()
  return true
end)

method(Shrm, 'app', function(self)
  shrm.enterRawMode()
  while true do
    self.start = shix.epoch()
    if not self:step() then break end
    local spent = self:spent()
    if spent < DRAW_PERIOD then
      shix.sleep(DRAW_PERIOD - spent)
    end
  end
  shrm.exitRawMode()
  print('\nExited app')
end)

update(shrm, {
  Shrm=Shrm,
})

if not civ.TESTING then
  print"## Running shrm"
  local sh = Shrm.new()
  sh:app()
end

return shrm
