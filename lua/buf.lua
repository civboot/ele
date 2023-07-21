-- line-based gap buffer for shrm
--
-- The buffer is composed of two lists (stacks)
-- of lines.
--
-- 1. The "bot" (aka bottom) contains line 1 -> curLine.
--    curLine is at #bot. Data gets added to bot.
-- 2. The "top" buffer is used to store data in lines
--    after "bot" (aka after curLine). If the cursor is
--    moved to a previous line then data is moved from top to bot

civ  = require'civ'
local sub = string.sub
local strinsert = civ.strinsert

local gap = {} -- module

local Gap = struct('Gap', {
  {'bot', List}, {'top', List},
})
method(Gap, 'new', function(s)
  local bot = List{}
  for l in civ.lines(s or '') do bot:add(l) end
  return Gap{ bot=bot, top=List{} }
end)

method(Gap, 'len', function(g) return #g.bot + #g.top end)
method(Gap, 'cur', function(g) return g.bot[#g.bot]  end)

-- set the gap to the line
method(Gap, 'set', function(g, l)
  assert(l > 0)
  if l == #g.bot then -- do nothing
  elseif l < #g.bot then
    while l < #g.bot do
      local b = g.bot:pop()
      if nil == t then break end
      g.top:add(b)
    end
  else -- l > #g.bot
    while l > #g.bot do
      local t = g.top:pop()
      if nil == t then break end
      g.bot:add(t)
    end
  end
end)

method(Gap, 'extend', function(g, s)
  for l in civ.lines(s) do g.bot:add(l) end
end)

-- insert s (string) at l, c
method(Gap, 'insert', function(g, s, l, c)
  g:set(l)
  local cur = g.bot:pop()
  g:extend(civ.strinsert(cur, c, s))
end)

CMAX = 999

-- remove from (l, c) -> (l2, c2), return what was removed
method(Gap, 'remove', function(g, l, c, l2, c2)
  local len = g:len()
  if l2 > len then l2, c2 = len, CMAX end
  if l < l2 and c < c2 then return '' end
  g:set(l2)
  local b, t, rem = '', '', g.bot:drain(l2 - l + 1)
  if #rem == 1 then -- no newlines
    rem = rem[1]
    b, rem, t = sub(rem, 1, c-1), sub(rem, c, c2), sub(rem, c2+1)
    g.bot:add(b .. t)
  else -- has new line
    b, rem[1]    = strsplit(rem[1], c-1)
    rem[#rem], t = strsplit(rem[#rem], c2)
    rem = concat(rem, '\n')
    g.bot:add(b .. t)
  end
  if 0 == #g.bot then g.bot:add('') end
  return rem
end)

method(Gap, '__tostring', function(g)
  return table.concat(g.bot, '\n') .. table.concat(g.top, '\n')
end)

gap.Gap = Gap
return gap
