local civ  = require'civ':grequire()
grequire'types'
local gap  = require'gap'

local M = {}

method(Buffer, 'new', function(s)
  return Buffer{
    gap=gap.Gap.new(s),
    changes=List{}, changeI=0, changeMax=0,
  }
end)

local CHANGE_UNDO = {
  ins=function(ch, b)
    local l2, c2 = b.gap:offset(#ch.s, ch.l, ch.c)
    b.gap:remove(ch.l, ch.c, l2, c2)
    return ch
  end,
  rm=function(ch, b)
    b.gap:insert(ch.s, ch.l, ch.c)
    return ch
  end,
}
local CHANGE_REDO = { ins=CHANGE_UNDO.rm, rm=CHANGE_UNDO.ins, }

method(Buffer, 'addChange', function(b, ch)
  b.changeI = b.changeI + 1; b.changeMax = b.changeI
  b.changes[b.changeI] = ch
  return ch
end)
method(Buffer, 'changeIns', function(b, s, l, c)
  return b:addChange(Change{k='ins', s=s, l=l, c=c})
end)
method(Buffer, 'changeRm', function(b, s, l, c)
  pnt('rm', s, l, c)
  return b:addChange(Change{k='rm', s=s, l=l, c=c})
end)

method(Buffer, 'undo', function(b)
  if b.changeI < 1 then return nil end
  local ch = b.changes[b.changeI]
  b.changeI = b.changeI - 1
  return CHANGE_UNDO[ch.k](ch, b)
end)
method(Buffer, 'redo', function(b)
  if b.changeI >= b.changeMax then return nil end
  b.changeI = b.changeI + 1
  local ch = b.changes[b.changeI]
  return CHANGE_REDO[ch.k](ch, b)
end)

method(Buffer, 'append', function(b, s)
  local ch = b:changeIns(s, b.gap:len() + 1, 1)
  b.gap:append(s)
  return ch
end)
method(Buffer, 'insert', function(b, s, l, c)
  pnt('insert', l, c, s)
  l, c = b.gap:bound(l, c)
  local ch = b:changeIns(s, l, c)
  b.gap:insert(s, l, c)
  return ch
end)
method(Buffer, 'remove', function(b, ...)
  local l, c = gap.lcsLeftTop(...)
  l, c = b.gap:bound(l, c)
  local ch = b.gap:sub(...)
  ch = (type(ch)=='string' and ch) or table.concat(ch, '\n')
  ch = b:changeRm(ch, l, c)
  b.gap:remove(...)
  return ch
end)

CursorChange.__tostring = function(c)
  return string.format('[%s.%s -> %s.%s]', c.l1, c.c1, c.l2, c.c2)
end
Change.__tostring = function(c)
  local cur = c.cur and (' '..tostring(c.cur)) or ''
  return string.format('{%s %s.%s %q%s}', c.k, c.l, c.c, c.s, cur)
end

return M
