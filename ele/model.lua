-- #####################
-- # Model struct
-- Implements the core app

require'civ':grequire()
local T = require'ele.types'
local civix = require'civ.unix'
local posix = require'posix'
local action = require'ele.action'
local term = require'ele.term'
local gap  = require'ele.gap'
local edit = require'ele.edit'
local buffer = require'ele.buffer'
local bindings = require'ele.bindings'
local data = require'ele.data'
local window = require'ele.window'

local yld = coroutine.yield

local M = {} -- module

local DRAW_PERIOD = Duration(0.03)
local MODE = { command='command', insert='insert' }
local Actions = action.Actions
local Model, Edit, Buffer, Bindings = T.Model, T.Edit, T.Buffer, T.Bindings

methods(Model, {
__tostring=function() return 'APP' end,
new=function(term_, inputCo)
  local mdl = {
    mode='command',
    h=-1, w=-1,
    buffers=Map{}, bufId=1, bufIds=List{},
    start=Epoch(0), lastDraw=Epoch(0),
    bindings=Bindings.default(),

    inputCo=inputCo, term=term_,
    events=LL(),
  }
  mdl = setmetatable(mdl, Model)
  mdl.statusEdit = mdl:newEdit('status')
  mdl.searchEdit = mdl:newEdit('search')
  return mdl
end,
-- Call after term is setup
init=function(m)
  m.th, m.tw = m.term:size()
  m:draw()
end,

-- #####################
-- # Status
showStatus=function(self)
  local s = self.statusEdit
  if s.container then return end
  window.windowAdd(self.view, s, 'h', false)
  s.fh, s.fw = 1, nil
end,
showSearch=function(self)
  local s = self.searchEdit; if s.container then return end
  if self.statusEdit.container then -- piggyback on status
    window.windowAdd(self.statusEdit, s, 'v', true)
  else -- create our own
    window.windowAdd(self.view, s, 'h', false)
    s.fh, s.fw = 1, nil
  end
  assert(s.container)
end,

status=function(self, msg, kind)
  if type(msg) ~= 'string' then msg = concat(msg) end
  kind = kind and string.format('[%s] ', kind) or '[status] '
  msg = kind .. msg
  local e = self.statusEdit
  e:changeStart()
  assert(not msg:find('\n')); e:append(msg)
  pnt('Status: ', msg)
end,
spent=function(self)
  return civix.epoch() - self.start
end,
loopReturn=function(self)
  -- local spent = self:spent()
  -- if DRAW_PERIOD < spent then
  --   return true
  -- end
  return false
end,

-- #####################
-- # Bindings
getBinding=function(self, key)
  local b = self.bindings[self.mode]
  pnt('!! getBinding', key)
  if 'string' == type(key) then
    pnt(string.format('  %s', b[key]))
    return b[key]
  end
  pnt(string.format('  %s', b:getPath(key)))
  return b:getPath(key)
end,

-- #####################
-- # Buffers
newBuffer=function(self, id, s)
  id = id or self.bufIds:pop()
  if not id then id = self.bufId; self.bufId = self.bufId + 1 end
  if self.buffers[id] then error('Buffer already exists: ' .. tostring(id)) end
  local b = Buffer.new(s); b.id = id
  self.buffers[id] = b
  return b
end,
closeBuffer=function(self, b)
  local id = b.id; self.buffers[id] = nil
  if type(id) == 'number' then self.bufIds:add(id) end
  return b
end,
newEdit=function(self, bufId, bufS)
  return Edit.new(nil, self:newBuffer(bufId, bufS))
end,

-- #####################
-- # Windows
moveFocus=function(self, direction)
  assert(window.VIEW_DIRECTIONS[direction])
  local sib = window.viewSiblings(self.edit)
  local e = window.focusIndexBestEffort(sib[direction], sib.index)
  if e then
    assert(ty(e) == T.Edit)
    self.edit = e
  end
end,

-- #####################
--   * draw
draw=function(mdl)
  mdl.th, mdl.tw = mdl.term:size()
  update(mdl.view, {tl=1, tc=1, th=mdl.th, tw=mdl.tw})
  mdl.view:draw(mdl.term, true)
  mdl.edit:drawCursor(mdl.term)
end,

-- #####################
--   * update
unrecognized=function(self, keys)
  self:status('chord: ' .. concat(keys, ' '), 'unset')
end,

actRaw=function(self, ev)
  local act = Actions[ev[1]]
  if not act then error('unknown action: ' .. tfmt(ev)) end
  local out = act.fn(self, ev) or List{}
  return out
end,

actionHandler=function(self, out, depth)
  while #out > 0 do
    local e = table.remove(out); e.depth = (depth or 1) + 1
    self.events:addBack(e)
  end
end,

update=function(self)
  while not self.events:isEmpty() do
    local ev = self.events:popBack();
    if (ev.depth or 1) > 12 then error('event depth: ' .. ev.depth) end
    pnt('Event: ', ev)
    local out = nil
    if self.chain then
      update(self.chain, ev)
      ev = self.chain; self.chain = nil
    end
    out = self:actRaw(ev)
    if ty(out) ~= List then error('action returned non-list: '..tfmt(out)) end
    self:actionHandler(out, ev.depth)
  end
end,
-- the main loop

-- #####################
--   * step: run all pieces
step=function(self)
  local key = self.inputCo()
  pnt(string.format('!! got key %q', key))
  self.start = civix.epoch()
  if key == '^C' then
    pnt('\nctl+C received, ending\n')
    return false
  end
  if key then self.events:addFront({'rawKey', key=key}) end
  self:update()
  if self.mode == 'quit' then return false end
  self:draw()
  return true
end,

app=function(self)
  pnt('starting app')
  self.term:start()
  self.term:clear()
  self:init()
  while true do
    if not self:step() then break end
  end
  self.term:stop()
  pnt('\nExited app')
end,
}) -- END Model methods


-- #####################
-- # Main

M.testModel = function(t, inp)
  local mdl = Model.new(t, inp)
  mdl.edit = mdl:newEdit(nil, data.TEST_MSG)
  mdl.edit.container = mdl
  mdl.view = mdl.edit; mdl:showStatus()

  return mdl, mdl.statusEdit, mdl.edit
end

return M
