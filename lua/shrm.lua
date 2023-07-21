local civ  = require'civ'
local shix = require'shix'
local term = require'plterm'
local gap  = require'gap'
local posix = require'posix'

local yld = coroutine.yield

local shrm = {} -- module


local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }

local ATEXIT = {}
local function enterRawMode()
  assert(not getmetatable(ATEXIT))
  local SAVED, err, msg = term.savemode()
  assert(err, msg); err, msg = nil, nil
  local atexit = {
    __gc = function()
      term.restoremode(SAVED)
      print('\nExited shrm successfully\n')
   end,
  }
  setmetatable(ATEXIT, atexit)
  term.setrawmode()
end

local Change = struct('Diff', {
  {'l', Num},  {'c', Num},                -- start of action
  {'l2', Num, false}, {'c2', Num, false}, -- (optional) end
  {'value', Str, false}, -- value removed in action
})

local Buffer = struct('Buffer', {
  {'gap', gap.Gap},
  {'l', Num}, {'c', Num}, -- cursor

  -- recorded changes from update
  {'changes', List}, {'changeI', Num}, -- undo/redo
})
method(Buffer, 'new', function()
  return Buffer{
    gap=gap.Gap(), l=1, c=1,
    changes=List{}, changI=0,
  }
end)

local function event(key)
  return {key=key}
end

local Shrm = struct('Shrm', {
  {'mode', Str}, -- the UI mode (command, insert)
  {'buffers', List}, {'bufferI', Num},
  {'epoch', nil, shix.epoch},
  {'start', Epoch}, {'lastDraw', Epoch},

  {'inputCo'}, {'updateCo'}, {'drawCo'},

  -- events from inputCo (LL)
  {'events'},
})
method(Shrm, 'new', function()
  local sh = {
    mode='command',
    buffers=List{Buffer.new()}, bufferI=1,
    start=Epoch(0), lastDraw=Epoch(0),
    inputCo=nil,
  }
  sh.inputCo  = term.input()
  sh.updateCo = coroutine.create(shrmUpdate, sh)
  sh.drawCo   = coroutine.create(shrmDraw,   sh)
  return setmetatable(sh, Shrm)
end)
method(Shrm, 'spent', function(self)
  return shlx.epopch() - self.start
end)
method(Shrm, 'loopYld', function(self)
  local spent = self:spent()
  if DRAW_PERIOD < spent then
    yld();
    return Duration(0)
  end
  return spent
end)

-- the main loop

local _UPDATE_MODE = {
  command=function(self, ev)
    print('Doing command', ev)
  end,
  insert=function(self, ev)
    print('Doing insert', ev)
  end,
}

local function shrmUpdate(shrm)
  while true do
    while not shrm.events.isEmpty() do
      local spent = shrm:loopYld()
      local ev = shrm.events.popBack()
      _UPDATE_MODE[shrm.mode](ev)
    end
    yld()
  end
end

local function shrmDraw(shrm)
  while true do
    local lastDraw = shlx.epoch() - shrm.lastDraw
    if DRAW_PERIOD < lastDraw then shrm:draw() end
    yld()
  end
end

method(Shrm, 'step', function(self)
  self.start = shlx.epoch()
  local done, key = coroutine.resume(self, inputCo())
  assert(not done); if key then
    self.events.addFront(event(key))
  end
  assert(coroutine.resume(self.updateCo))
  assert(coroutine.resume(self.drawCo))
  local spent = self:spent()
  if spent < DRAW_PERIOD then
    shlx.sleep(DRAW_PERIOD - spent)
  end
end)

method(Shrm, 'app', function(self)
  enterRawMode()
  while true do self.step() end
end)

update(shrm, {
  Shrm=Shrm,
})
return shrm
