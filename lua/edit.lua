-- #####################
-- # Edit struct
require'civ':grequire()
grequire'types'
local gap = require'gap'
local term = require'term'; tunix = term.unix

M = {}

-- Implements an edit view and state
method(Edit, 'new', function(container, buf, h, w)
  return Edit{
    id=nextViewId(),
    buf=buf,
    l=1, c=1, vl=1, vc=1,
    th=h, tw=w,
    tl=1, tc=1,
    container=container,
    canvas=nil,
  }
end)
method(Edit, 'copy', function(e)
  return copy(e, {id=nextViewId()})
end)
method(Edit, 'offset', function(e, off)
  return e.buf.gap:offset(off, e.l, e.c)
end)
method(Edit, 'curLine', function(e) return e.buf.gap:get(e.l) end)
method(Edit, 'len',     function(e) return e.buf.gap:len() end)

-- These are going to track state/cursor/etc
method(Edit, 'insert', function(e, s)
  e.buf.gap:insert(s, e.l, e.c - 1)
  e.c = min(e.c, #e:curLine())
  print('insert', e.l, e.c)
  e.l, e.c = e.buf.gap:offset(#s, e.l, e.c)
end)
method(Edit, 'remove', function(e, off, l, c)
  if off == 0 then return end
  print('remove start', e.l, e.c)
  l, c = l or e.l, c or e.c; local gap = e.buf.gap
  if l < e.l or (l == e.l and c <= e.c) then
    e.l, e.c = gap:offset(off, e.l, e.c)
  end
  local l2, c2 = gap:offset(decAbs(off), l, c)
  if off < 0 then l, l2, c, c2 = l2, l, c2, c end
  print('remove', e.l, e.c, 'from2', l, c, l2, c2)
  gap:remove(l, c, l2, c2)
end)
method(Edit, 'append', function(e, ...)
  self.gap:append(...)
end)
method(Edit, 'setCursor', function(e, l, c)
  e.l = min(e.gap:len(), max(1, l or 1))
  e.c = min(1, c or Gap.CMAX)
  e.tl = max(1, e.l - e.th)
  e.tc = max(1, e.c - e.tw)
end)

-- draw to term (l, c, w, h)
method(Edit, 'draw', function(e, term, isRight)
  assert(term)
  e.canvas = List{}
  for i, line in ipairs(e.buf.gap:sub(e.vl, e.vl + e.th - 1)) do
    e.canvas:add(string.sub(line, e.vc, e.vc + e.tw - 1))
  end
  local l = e.tl
  for _, line in ipairs(e.canvas) do
    local c = e.tc
    for char in line:gmatch'.' do
      term:set(l, c, char)
      c = c + 1
    end
    local fill = e.tw - #line
    if fill > 0 then
      if isRight then term:cleareol(l, c)
      else for _=1, fill do
        term:set(l, c, ' '); c = c + 1
      end end
    end
    l = l + 1
  end
end)

return M
