-- #####################
-- # Edit struct
require'civ':grequire()
grequire'types'
local gap = require'gap'
local motion = require'motion'
local term = require'term'; tunix = term.unix

M = {}

-- Implements an edit view and state
method(Edit, 'new', function(container, buf)
  return Edit{
    id=nextViewId(),
    buf=buf,
    l=1, c=1, vl=1, vc=1,
    th=-1, tw=-1,
    tl=-1, tc=-1,
    container=container,
    canvas=nil,
  }
end)
method(Edit, '__tostring', function(e)
  return string.format('Edit[id=%s]', e.id)
end)
method(Edit, 'copy', function(e)
  return copy(e, {id=nextViewId()})
end)
method(Edit, 'close', function(e) pnt('TODO<edit close>') end)
method(Edit, 'forceHeight', function(e) return e.fh end)
method(Edit, 'forceWidth', function(e)  return e.fw end)
method(Edit, 'offset', function(e, off)
  return e.buf.gap:offset(off, e.l, e.c)
end)
method(Edit, 'curLine',  function(e) return e.buf.gap:get(e.l) end)
method(Edit, 'colEnd', function(e) return #e:curLine() + 1 end)
method(Edit, 'len',     function(e) return e.buf.gap:len() end)
method(Edit, 'lastLine', function(e) return e.buf.gap:get(e:len()) end)
-- bound the column for the line
method(Edit, 'boundCol',  function(e, c, l)
  return bound(c, 1, #e.buf.gap:get(l or e.l) + 1)
end)

-- update view to see cursor (if needed)
method(Edit, 'viewCursor', function(e)
  -- if e.l > e:len() then e.l = e:len() end
  if e.l > e:len() then error(
    ('e.l OOB: %s > %s'):format(e.l, e:len())
  )end
  local l, c = e.l, e.c
  l = bound(l, 1, e:len()); c = e:boundCol(c, l)
  if e.vl > l            then e.vl = l end
  if l < e.vl            then e.vl = l end
  if l > e.vl + e.th - 1 then e.vl = l - e.th + 1 end
  if c < e.vc            then e.vc = c end
  if c > e.vc + e.tw - 1 then e.vc = c - e.tw + 1 end
end)

-----------------
-- Helpers
method(Edit, 'trailWs', function(e, msg)
  local g = e.buf.gap
  while g:get(g:len() - 1)    ~= ''
        or g:get(g:len() - 2) ~= '' do
    e:append('')
  end
end)

-----------------
-- Mutations: these update the changes in the buffer
method(Edit, 'append', function(e, msg)
  local l2 = e:len() + 1
  e.buf:append(msg).cursor = CursorChange{l1=e.l, c1=e.c, l2=l2, c2=1}
  e.l, e.c = l2, 1
end)

method(Edit, 'insert', function(e, s)
  local cur = CursorChange{l1=e.l, c1=e.c}
  local ch = e.buf:insert(s, e.l, e.c);
  e.l, e.c = e.buf.gap:offset(#s, e.l, e.c)
  -- if causes cursor to move to next line, move to end of cur line
  -- except in specific circumstances
  if (e.l > 1) and (e.c == 1) and ('\n' ~= strLast(s)) then
    e.l, e.c = e.l - 1, #e.buf.gap:get(e.l - 1) + 1
  end
  cur.l2, cur.c2, ch.cur = e.l, e.c, cur
end)

method(Edit, 'remove', function(e, ...)
  local l1, c1 = e.l, e.c
  local l, c, l2, c2 = gap.lcs(...)
  local g, ch = e.buf.gap
  local len = g:len()
  l, l2 = bound(l, 1, len), bound(l2, 1, len)
  if not c then -- only lines specified
    l, l2 = sort2(l, l2); assert(not c2)
    if e.l <= l2 then
      e.l = bound(e.l - (l2 - l), 1, len - (l2 - l1))
    end
    c, c2 = 1, #g:get(l2) + 1
  else
    l, c = g:bound(l, c);  l2, c2 = g:bound(l2, c2)
    if motion.lcGe(e.l, e.c, l2, c2) then
      local off = g:offsetOf(e.l, e.c, l2, c2)
      e.l, e.c = g:offset(off, e.l, e.c)
    end
  end
  ch = e.buf:remove(l, c, l2, c2)
  ch.cur = CursorChange{l1=l1, c1=c1, l2=e.l, c2=e.c}
end)

method(Edit, 'removeOff', function(e, off, l, c)
  if off == 0 then return end
  l, c = l or e.l, c or e.c;
  local l2, c2 = e.buf.gap:offset(decAbs(off), l, c)
  if off < 0 then l, l2, c, c2 = l2, l, c2, c end
  e:remove(l, c, l2, c2)
end)

-----------------
-- Undo / Redo
method(Edit, 'undo', function(e)
  local ch = e.buf:undo(); if not ch then return end
  local c = assert(ch.cur)
  e.l, e.c = c.l1, c.c1
end)
method(Edit, 'redo', function(e)
  local ch = e.buf:redo(); if not ch then return end
  local c = assert(ch.cur)
  e.l, e.c = c.l1, c.c1
end)

-----------------
-- Draw to terminal
method(Edit, 'draw', function(e, term, isRight)
  assert(term); e:viewCursor()
  e.canvas = List{}
  -- assert(e.fh == 0 or e.fh == e.th)
  -- assert(e.fw == 0 or e.fw == e.tw)
  for i, line in ipairs(e.buf.gap:sub(e.vl, e.vl + e.th - 1)) do
    e.canvas:add(string.sub(line, e.vc, e.vc + e.tw - 1))
  end
  while #e.canvas < e.th do e.canvas:add('') end
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

-- Called by model for only the focused editor
method(Edit, 'drawCursor', function(e, term)
  e:viewCursor()
  local c = min(e.c, #e:curLine() + 1)
  term:golc(e.tl + (e.l - e.vl), e.tc + (c - e.vc))
end)

return M
