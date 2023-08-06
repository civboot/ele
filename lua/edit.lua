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
method(Edit, 'curLine',  function(e) return e.buf.gap:get(e.l) end)
method(Edit, 'lastLine', function(e) return e.buf.gap:get(e.buf.gap:len()) end)
method(Edit, 'len',     function(e) return e.buf.gap:len() end)
-- bound the column for the line
method(Edit, 'boundCol',  function(e, c, l)
  return bound(c, 1, #e.buf.gap:get(l or e.l) + 1)
end)

-- update view to see cursor (if needed)
method(Edit, 'viewCursor', function(e)
  local l, c = e.l, e.c
  l = bound(l, 1, e:len()); c = e:boundCol(c, l)
  if l < e.vl            then e.vl = l end
  if l > e.vl + e.th - 1 then e.vl = l - e.th + 1 end
  if c < e.vc            then e.vc = c end
  if c > e.vc + e.tw - 1 then e.vc = c - e.tw + 1 end
end)

-- These are going to track state/cursor/etc
method(Edit, 'insert', function(e, s)
  local c = e.c; e.buf.gap:insert(s, e.l, c - 1);
  e.l, e.c = e.buf.gap:offset(#s, e.l, c)
  -- if causes cursor to move to next line, move to end of cur line
  -- except in specific circumstances
  if e.l > 1 and e.c == 1 and c > 1 and '\n' ~= strLast(s) then
    e.l, e.c = e.l - 1, #e.buf.gap:get(e.l - 1) + 1
  end
end)
method(Edit, 'remove', function(e, off, l, c)
  if off == 0 then return end
  l, c = l or e.l, c or e.c; local gap = e.buf.gap
  if l < e.l or (l == e.l and c <= e.c) then
    e.l, e.c = gap:offset(off, e.l, e.c)
  end
  local l2, c2 = gap:offset(decAbs(off), l, c)
  if off < 0 then l, l2, c, c2 = l2, l, c2, c end
  gap:remove(l, c, l2, c2)
end)
method(Edit, 'append', function(e, ...)
  self.gap:append(...)
end)

-- draw to term (l, c, w, h)
method(Edit, 'draw', function(e, term, isRight)
  assert(term)
  e:viewCursor()
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

method(Edit, 'drawCursor', function(e, term)
  term:golc(e.tl + (e.l - e.vl), e.tc + (e.c - e.vc))
end)

return M
