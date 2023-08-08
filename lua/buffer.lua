local civ  = require'civ':grequire()
local gap  = require'gap'

local buffer = {}

method(Buffer, 'new', function(s)
  return Buffer{
    gap=gap.Gap.new(s),
    changes=List{}, changeI=0,
  }
end)
method(Buffer, 'append', function(b, msg)
  b.gap:append(msg)
end)

return buffer
