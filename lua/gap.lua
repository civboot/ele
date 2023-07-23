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

local gap = {} -- module

require'civ':grequire()
local sub = string.sub

local CMAX = 999
local Gap = struct('Gap', {
  {'bot', List}, {'top', List},
})

method(Gap, 'new', function(s)
  local bot; if not s or type(s) == 'string' then
    bot = List{}
    for l in lines(s or '') do bot:add(l) end
  else
    bot = List(s)
  end
  return Gap{ bot=bot, top=List{} }
end)


function lcs(l, c, l2, c2)
  if nil == l2 and nil == c2 then return l, nil, c, nil end
  if nil == l2 or  nil == c2 then error(
    'must provide 2 or 4 indexes (l, l2) or (l, c, l2, c2'
  )end; return l, c, l2, c2
end

method(Gap, 'len', function(g) return #g.bot + #g.top end)
method(Gap, 'cur', function(g) return g.bot[#g.bot]  end)

method(Gap, 'get', function(g, l)
  local bl = #g.bot
  if l <= bl then  return g.bot[l]
  else return g.top[#g.top - (l - bl) + 1] end
end)

-- Get the l, c with the +/- offset applied
method(Gap, 'offset', function(g, off, l, c)
  local len, m = g:len(), 0
  local line = g:get(l); c = max(1, min(c, #line + 1))
  while off > 0 do
    line = g:get(l)
    if nil == line then return len, #g:get(len) + 1 end
    if c < #line then
      m = min(off, #line - c) -- move amount
      off, c = off - m, c + m
    else
      off, l, c = off - 1, l + 1, 1
    end
  end
  while off < 0 do
    line = g:get(l)
    if nil == line then return 1, 1 end
    c = min(#line, c)
    print('off,l,c,line', off,l, c, line)
    if c > 1 then
      m = max(off, -c) -- move amount (negative)
      print('m', m)
      off, c = off - m, c + m
    else
      print('l', l)
      off, l, c = off + 1, l - 1, CMAX
    end
  end
  return l, (CMAX == c and #(g:get(l))) or c
end)

-- set the gap to the line
method(Gap, 'set', function(g, l)
  l = l or (#g.bot + #g.top)
  assert(l > 0)
  if l == #g.bot then return end -- do nothing
  if l < #g.bot then
    while l < #g.bot do
      local v = g.bot:pop()
      print('<', v, l)
      if nil == v then break end
      g.top:add(v)
      print('set top', g.top)
    end
  else -- l > #g.bot
    while l > #g.bot do
      local v = g.top:pop()
      print('>', v, l)
      if nil == v then break end
      g.bot:add(v)
    end
  end
end)

-- insert s (string) at l, c
method(Gap, 'insert', function(g, s, l, c)
  g:set(l)
  local cur = g.bot:pop()
  g:extend(strinsert(cur, c or 0, s))
end)


-- remove from (l, c) -> (l2, c2), return what was removed
method(Gap, 'remove', function(g, ...)
  local l, c, l2, c2 = lcs(...);
  local len = g:len()
  if l2 > len then l2, c2 = len, CMAX end
  print('removing', l, c, l2, c2)
  print('preset bot', g.bot)
  print('preset top', g.top)
  g:set(l2)
  print('postset bot', g.bot)
  print('postset top', g.top)
  if l2 < l then
    if nil == c then return List{}
    else             return '' end
  end
  local b, t, rem = '', '', g.bot:drain(l2 - l + 1)
  if c == nil then      -- only lines, leave as list
  elseif #rem == 1 then -- no newlines (out=str)
    rem = rem[1]
    b, rem, t = sub(rem, 1, c-1), sub(rem, c, c2), sub(rem, c2+1)
    g.bot:add(b .. t)
  else -- has new line (out=str)
    b, rem[1]    = strsplit(rem[1], c-1)
    rem[#rem], t = strsplit(rem[#rem], c2)
    rem = concat(rem, '\n')
    g.bot:add(b .. t)
  end
  if 0 == #g.bot then g.bot:add('') end
  print('return', #rem, rem)
  return rem
end)

-- get the sub-buf (slice)
-- of lines (l, l2) or str (l, c, l2, c2)
method(Gap, 'sub', function(g, ...)
  local l, c, l2, c2 = lcs(...)
  local s = List{}
  for i=l, min(l2, #g.bot)   do s:add(g.bot[i]) end
  for i=1, min(l2-l, #g.top) do s:add(g.top[i]) end
  if nil == c then -- only lines
  else
    print('not only lines')
    s[1] = sub(s[1], c, CMAX)
    if #s >= l2 - l then s[#s] = sub(s[#s], 1, c2) end
    s = concat(s, '\n')
  end
  return s
end)

method(Gap, 'append', function(g, s)
  g:set(); g.bot:add(s)
end)

method(Gap, '__tostring', function(g)
  local bot = concat(g.bot, '\n')
  if #g.top == 0 then return bot  end
  return bot..'\n'..concat(g.top, '\n')
end)

-- extend onto gap. Mostly used internally
method(Gap, 'extend', function(g, s)
  for l in lines(s) do g.bot:add(l) end
end)

gap.Gap = Gap
return gap
