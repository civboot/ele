require'civ':grequire()
grequire'types'
local posix = require'posix'
local shix = require'shix'
local term = require'plterm'
local gap  = require'gap'
local edit = require'edit'
local buffer = require'buffer'
local bindings = require'bindings'

local yld = coroutine.yield
local outf = term.outf
local debug = term.debug

local M = {} -- module

local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }


-- #####################
-- # Lede struct
-- Implements the core app

method(Lede, '__tostring', function() return 'APP' end)
method(Lede, 'new', function(h, w)
  local sts = Buffer.new()
  local sh = {
    mode='command',
    h=h, w=w,
    buffers=List{}, bufferI=1,
    start=Epoch(0), lastDraw=Epoch(0),
    bindings=Bindings.default(),
    chord=nil, chordKeys=List{},

    inputCo=nil,
    events=LL(),
    statusBuf=sts,
  }
  sh.view = Edit.new(sh, sts, h, w)
  sh.edit = sh.view
  sh.inputCo  = term.input()
  return setmetatable(sh, Lede)
end)

-- #####################
-- # Utility methods
method(Lede, 'status', function(self, m)
  if type(m) ~= 'string' then m = concat(m) end
  self.statusBuf.gap:append(m)
  term.debug('Status: ', m)
end)
method(Lede, 'spent', function(self)
  return shix.epoch() - self.start
end)
method(Lede, 'loopReturn', function(self)
  -- local spent = self:spent()
  -- if DRAW_PERIOD < spent then
  --   return true
  -- end
  return false
end)

-- #####################
--   * draw
method(Lede, 'draw', function(self)
  self.view:draw(self.h, self.w)
end)

method(Lede, 'paint', function(self)
  -- local lastDraw = shix.epoch() - self.lastDraw
  -- if DRAW_PERIOD < lastDraw then
  -- end
  term.clear()
  local tl, tc = 1, 1
  for l, line in ipairs(e.canvas) do
    term.golc(tl + l - 1, tc);
    term.cleareol()
    term.outf(string.sub(line, 1, tw - 1))
  end
  term.golc(tl + e.l - 1, tc + e.c - 1)

  -- update the widths/heights for next draw/paint
  local th, tw = term.size(); assert((tw > 0) and (th > 0))
  self.h, self.w = th, tw
  e = self.edit
  e.vh, e.vw = th, tw
end)

-- #####################
--   * update

method(Lede, 'unrecognized', function(self, keys)
  self:status('unrecognized chord: ' .. concat(keys, ' '))
end)

method(Lede, 'defaultAction', function(self, keys)
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

method(Lede, 'update', function(self)
  debug('update loop')
  while not self.events:isEmpty() do
    local ev = self.events:popBack()
    assert(type(ev) == 'string', ev)

    local action = nil
    self.chordKeys:add(ev)
    self.chord = self.chord or self.bindings[self.mode]
    action = self.chord[ev]
    if not action then
      local keys = self.chordKeys
      self.chordKeys = List{}
      self:defaultAction(keys)
    elseif Action == ty(action) then -- found, continue
      self.chord = nil
      self.chordKeys = List{}
      action.fn(self, action)
    elseif Map == ty(action) then
      self.chord, action = action, nil
      self.chordKeys = self.chordKeys or List{}
      self.chordKeys:add(ev)
    else error(action) end
    if self:loopReturn() then break end
  end
  debug('update end')
end)
-- the main loop

-- #####################
--   * step: run all pieces
method(Lede, 'step', function(self)
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
  self:draw(); self:paint()
  return true
end)

method(Lede, 'app', function(self)
  print('\nEntering raw mode')
  term.enterRawMode()
  while true do
    if not self:step() then break end
  end
  term.exitRawMode()
  print('\nExited app')
end)

-- #####################
-- # Actions
M.QuitAction = Action{
  name='quit', brief='quit the application',
  fn = function(app) app.mode = 'quit'    end,
}
M.CommandAction = Action{
  name='command', brief='go to command mode',
  fn = function(app)
    app.mode = 'command'
    app.chord = nil
  end,
}
M.InsertAction = Action{
  name='insert', brief='go to insert mode',
  fn = function(app)
    app.mode = 'insert'
    app.chord = nil
  end,
}

-- #####################
-- # Default Bindings

-- -- Insert Mode
bindings.BINDINGS:updateInsert{
  ['^Q ^Q'] = M.QuitAction,
  ['^J']    = M.CommandAction,
  ['esc']   = M.CommandAction,
}

-- Command Mode
bindings.BINDINGS:updateCommand{
  ['^Q ^Q'] = M.QuitAction,
  i         = M.InsertAction,
}

-- #####################
-- # Main

local function main()
  print"## Running (shrm ctl+q to quit)"
  local sh = Lede.new(20, 10)
  sh:app()
end

if not civ.TESTING then main() end

return M
