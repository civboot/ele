local civ  = require'civ':grequire()
local gap  = require'gap'

local buffer = {}

method(Buffer, 'new', function(s)
  return Buffer{
    gap=gap.Gap.new(s),
    changes=List{}, changeI=0, changeMax=0,
  }
end)


-- this is done first
method(Buffer, 'changeAppend', function(b, ch)
  b.changeI = b.changeI + 1; b.changeMax = b.changeI
  b.changes[b.changeI] = ch
end)
method(Buffer, 'changeIns', function(b, len, l, c)
  b:changeAppend({'ins', len=len, l=l, c=c})
end)
method(Buffer, 'changeRm', function(b, s, l, c)
  b:changeAppend({'rm', s=s, l=l, c=c})
end)

method(Buffer, 'append', function(b, s)
  changeIns(b.gap:len(), #b.gap:last() + 1, #s + 1)
  b.gap:append(s)
end)
method(Buffer, 'insert', function(b, s, l, c)
  changeIns(#s, l, c); b.gap:insert(s, l, c)
end)
method(Buffer, 'remove', function(b, ...)
  local l, c, l2, c2 = lcs(...)
  changeIns(#s, l, c); b.gap:insert(s, l, c)
end)

return buffer
