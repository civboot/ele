-- #####################
-- # Model struct
-- Implements the core app

require'civ':grequire()
grequire'types'
local action = require'action'
local posix = require'posix'
local shix = require'shix'
local term = require'term'
local gap  = require'gap'
local edit = require'edit'
local buffer = require'buffer'
local bindings = require'bindings'
local data = require'data'
local window = require'window'

local yld = coroutine.yield

local M = {} -- module

local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }
local Actions = action.Actions

method(Model, '__tostring', function() return 'APP' end)
method(Model, 'new', function(term_, inputCo)
  local mdl = {
    mode='command',
    h=-1, w=-1,
    buffers=List{}, bufferI=1,
    start=Epoch(0), lastDraw=Epoch(0),
    bindings=Bindings.default(),
    chord=nil, chordKeys=List{},

    inputCo=inputCo, term=term_,
    events=LL(),
  }
  mdl.statusEdit = Edit.new(mdl, Buffer.new())
  mdl.view, mdl.edit = mdl.statusEdit, mdl.statusEdit
  return setmetatable(mdl, Model)
end)
-- Call after term is setup
method(Model, 'init', function(m)
  m.h, m.w = m.term:size()
  m:draw()
end)

-- #####################
-- # Utility methods
method(Model, 'status', function(self, msg)
  if type(msg) ~= 'string' then msg = concat(msg) end
  local e = self.statusEdit
  e.buf.gap:append(msg); e.l, e.c = e:len(), 1
  pnt('Status: ', msg)
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
method(Model, 'draw', function(mdl)
  mdl.h, mdl.w = mdl.term:size()
  update(mdl.view, {tl=1, tc=1, th=mdl.h, tw=mdl.w})
  mdl.view:draw(mdl.term, true)
  mdl.edit:drawCursor(mdl.term)
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
  while not self.events:isEmpty() do
    local ev = self.events:popBack(); assert((ev.depth or 1) <= 12)
    pnt('Event', ev)
    local evName = assert(ev[1])
    local act = Actions[evName]
    if not act then error('unknown action: ' .. tfmt(ev)) end
    local events = act.fn(self, ev) or {}
    while #events > 0 do
      local e = table.remove(events); e.depth = (ev.depth or 1) + 1
      self.events:addBack(e)
    end
  end
end)
-- the main loop

-- #####################
--   * step: run all pieces
method(Model, 'step', function(self)
  local key = self.inputCo()
  self.start = shix.epoch()
  if key == '^C' then
    pnt('\nctl+C received, ending\n')
    return false
  end
  if key then self.events:addFront({'rawKey', key=key}) end
  self:update()
  if self.mode == 'quit' then return false end
  self:draw()
  return true
end)

method(Model, 'app', function(self)
  pnt('starting app')
  self.term:start()
  self.term:clear()
  self:init()
  while true do
    if not self:step() then break end
  end
  self.term:stop()
  pnt('\nExited app')
end)

-- #####################
-- # Actions
-- #####################
-- # Default Bindings

local A = action.Actions
-- -- Insert Mode
bindings.BINDINGS:updateInsert{
  ['^Q ^Q'] = A.quit,
  ['^J']    = A.command,
  ['esc']   = A.command,
  ['back']  = A.back,
}

-- Command Mode
bindings.BINDINGS:updateCommand{
  ['q q'] = A.quit,
  i       = A.insert,
  h=A.left, j=A.down, k=A.up, l=A.right,
  w=A.forword, b=A.backword,
  ['0']=A.SoL, ['$']=A.EoL,
  A=A.appendLine, C=A.changeLine, D=A.deleteLine,
}

-- #####################
-- # Main

M.testModel = function(t, inp)
  local mdl = Model.new(t, inp)
  local status = mdl.edit
  local eTest = window.splitEdit(mdl.edit, 'h')
  eTest = window.replaceEdit(eTest, Edit.new(mdl, Buffer.new(data.TEST_MSG)))
  mdl.edit = eTest
  return mdl, status, eTest
end

local function main()
  local inp = term.unix.input()
  pnt"## Running ('q q' to quit)"
  local mdl = M.testModel(term.UnixTerm, inp)
  mdl:app()
end

if not civ.TESTING then main() end

return M
