-- #####################
-- # Model struct
-- Implements the core app

require'civ':grequire()
grequire'types'
local action = require'action'
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
local Actions = action.Actions



method(Model, '__tostring', function() return 'APP' end)
method(Model, 'new', function(h, w)
  local sts = Buffer.new()
  local mdl = {
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
  mdl.view = Edit.new(mdl, sts, h, w)
  mdl.edit = mdl.view
  mdl.inputCo  = term.input()
  return setmetatable(mdl, Model)
end)

-- #####################
-- # Utility methods
method(Model, 'status', function(self, m)
  if type(m) ~= 'string' then m = concat(m) end
  self.statusBuf.gap:append(m)
  term.debug('Status: ', m)
end)
method(Model, 'spent', function(self)
  return shix.epoch() - self.start
end)
method(Model, 'loopReturn', function(self)
  -- local spent = self:spent()
  -- if DRAW_PERIOD < spent then
  --   return true
  -- end
  return false
end)
method(Model, 'getBinding', function(self, key)
  if self.chord then return self.chord[key] end
  -- TODO: buffer bindings
  return self.bindings[self.mode][key]
end)

-- #####################
--   * draw
method(Model, 'draw', function(self)
  self.view:draw(self.h, self.w)
end)

method(Model, 'paint', function(self)
  -- local lastDraw = shix.epoch() - self.lastDraw
  -- if DRAW_PERIOD < lastDraw then
  -- end
  term.clear()
  local th, tw = term.size(); assert((tw > 0) and (th > 0))
  self.h, self.w = th, tw
  local e = self.edit; e.vh, e.vw = th, tw

  local tl, tc = 1, 1
  for l, line in ipairs(e.canvas) do
    term.golc(tl + l - 1, tc);
    term.cleareol()
    term.outf(string.sub(line, 1, tw - 1))
  end
  term.golc(tl + e.l - 1, tc + e.c - 1)
end)

-- #####################
--   * update

method(Model, 'unrecognized', function(self, keys)
  self:status('unrecognized chord: ' .. concat(keys, ' '))
end)

method(Model, 'defaultAction', function(self, keys)
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

method(Model, 'update', function(self)
  debug('update loop')
  while not self.events:isEmpty() do
    local ev = self.events:popBack(); assert((ev.depth or 1) <= 12)
    local evName = assert(ev[1])
    local act = Actions[evName]
    if not act then error('unknown action: ' .. tfmt(ev)) end
    local events = act.fn(self, ev) or {}
    while #events > 0 do
      local e = table.remove(events); e.depth = (ev.depth or 1) + 1
      self.events:addBack(e)
    end
  end
  debug('update end')
end)
-- the main loop

-- #####################
--   * step: run all pieces
method(Model, 'step', function(self)
  local key = self.inputCo()
  self.start = shix.epoch()
  debug('got key', key)
  if key == '^C' then
    debug('\nctl+C received, ending\n')
    return false
  end
  if key then self.events:addFront({'rawKey', key=key}) end
  debug('calling update')
  self:update()
  if self.mode == 'quit' then return false end
  self:draw(); self:paint()
  return true
end)

method(Model, 'app', function(self)
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
-- #####################
-- # Default Bindings

-- -- Insert Mode
bindings.BINDINGS:updateInsert{
  ['^Q ^Q'] = action.Actions.quit,
  ['^J']    = action.Actions.command,
  ['esc']   = action.Actions.command,
}

-- Command Mode
bindings.BINDINGS:updateCommand{
  ['^Q ^Q'] = action.Actions.quit,
  i         = action.Actions.insert,
}

-- #####################
-- # Main

local function main()
  print"## Running (shrm ctl+q to quit)"
  local sh = Model.new(20, 10)
  sh:app()
end

if not civ.TESTING then main() end

return M