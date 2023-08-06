-- #####################
-- # Edit struct
require'civ':grequire()
grequire'types'
local term = require'term'

M = {}

-- Implements an edit view and state
method(Edit, 'new', function(container, buf, h, w)
  return Edit{
    id=nextViewId(),
    buf=buf, l=1, c=1,
    vh=h, vw=w,
    vl=1, vc=1,
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
  e.vl = max(1, e.l - e.vh)
  e.vc = max(1, e.c - e.vw)
end)

-- draw to term (l, c, w, h)
method(Edit, 'draw', function(e)
  e.canvas = List{}
  for i, line in ipairs(e.buf.gap:sub(e.vl, e.vl + e.vh - 1)) do
    local s = string.sub(line, e.vc, e.vc + e.vw - 1)
    e.canvas:add(table.concat(fillBuf({s}, e.vw - #s)))
  end
end)

method(Edit, 'paint', function(e, tl, tc)
  for l, line in ipairs(e.canvas) do
    term.golc(tl + l - 1, tc);
    term.outf(string.sub(line, 1, e.vw - 1))
  end
end)

return M
