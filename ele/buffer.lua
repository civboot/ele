local civ  = require'civ':grequire()
local T = require'ele.types'
local motion  = require'ele.motion'
local gap  = require'ele.gap'

local M = {}

local function redoRm(ch, b)
  local len = #ch.s - 1; if len < 0 then return ch end
  local l2, c2 = b.gap:offset(len, ch.l, ch.c)
  b.gap:remove(ch.l, ch.c, l2, c2)
  return ch
end

local function redoIns(ch, b)
  b.gap:insert(ch.s, ch.l, ch.c)
  return ch
end

local CHANGE_REDO = { ins=redoIns, rm=redoRm, }
local CHANGE_UNDO = { ins=redoRm, rm=redoIns, }

methods(T.Buffer, {
new=function(s)
  return T.Buffer{
    gap=T.Gap.new(s),
    changes=List{}, changeI=0, changeMax=0,
  }
end,

addChange=function(b, ch)
  b.changeI = b.changeI + 1; b.changeMax = b.changeI
  b.changes[b.changeI] = ch
  return ch
end,

changeIns=function(b, s, l, c)
  return b:addChange(T.Change{k='ins', s=s, l=l, c=c})
end,

changeRm=function(b, s, l, c)
  return b:addChange(T.Change{k='rm', s=s, l=l, c=c})
end,

undo=function(b)
  if b.changeI < 1 then return nil end
  local ch = b.changes[b.changeI]
  b.changeI = b.changeI - 1
  return CHANGE_UNDO[ch.k](ch, b)
end,

redo=function(b)
  if b.changeI >= b.changeMax then return nil end
  b.changeI = b.changeI + 1
  local ch = b.changes[b.changeI]
  return CHANGE_REDO[ch.k](ch, b)
end,

append=function(b, s)
  local ch = b:changeIns(s, b.gap:len() + 1, 1)
  b.gap:append(s)
  return ch
end,

insert=function(b, s, l, c)
  l, c = b.gap:bound(l, c)
  local ch = b:changeIns(s, l, c)
  b.gap:insert(s, l, c)
  return ch
end,

remove=function(b, ...)
  local l, c, l2, c2 = gap.lcs(...)
  local lt, ct = motion.topLeft(l, c, l2, c2)
  lt, ct = b.gap:bound(lt, ct)
  local ch = b.gap:sub(l, c, l2, c2)
  ch = (type(ch)=='string' and ch) or table.concat(ch, '\n')
  ch = b:changeRm(ch, lt, ct)
  b.gap:remove(l, c, l2, c2)
  return ch
end,
}) -- END Buffer methods

T.CursorChange.__tostring = function(c)
  return string.format('[%s.%s -> %s.%s]', c.l1, c.c1, c.l2, c.c2)
end
T.Change.__tostring = function(c)
  local cur = c.cur and (' '..tostring(c.cur)) or ''
  return string.format('{%s %s.%s %q%s}', c.k, c.l, c.c, c.s, cur)
end

return M
