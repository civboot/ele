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
method(Lede, 'new', function()
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
  sh.view = Edit.new(sh, sts)
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
  local lastDraw = shix.epoch() - self.lastDraw
  if DRAW_PERIOD < lastDraw then
    h, w = term.size()
    term.clear()
    self.view:draw(1, 1, h, w)
  end
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
  self:draw()
  return true
end)

method(Lede, 'app', function(self)
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
  local sh = Lede.new()
  sh:app()
end

if not civ.TESTING then main() end

return M
