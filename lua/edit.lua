-- #####################
-- # Edit struct
require'civ':grequire()
grequire'types'
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

-- These are going to track state/cursor/etc
method(Edit, 'insert', function(e, s)
  e.buf.gap:insert(s, e.l, e.c - 1)
  e.l, e.c = e.buf.gap:offset(#s, e.l, e.c)
end)
method(Edit, 'remove', function(e, ...)
  self.gap:remove(...)
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
method(Edit, 'draw', function(e, term)
  assert(term)
  e.canvas = List{}
  for i, line in ipairs(e.buf.gap:sub(e.vl, e.vl + e.th - 1)) do
    local s = string.sub(line, e.vc, e.vc + e.tw - 1)
    e.canvas:add(table.concat(fillBuf({s}, e.tw - #s)))
  end
  local l = e.tl
  for _, line in ipairs(e.canvas) do
    local c = e.tc
    for char in line:gmatch'.' do
      term:set(l, c, char)
      c = c + 1
    end;
    l = l + 1
  end
end)

return M
