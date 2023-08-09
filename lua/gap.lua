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

local M = {} -- module

require'civ':grequire()
local sub = string.sub
local motion = require'motion'

local CMAX = 999; M.CMAX = CMAX
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

local function lcs(l, c, l2, c2)
  if nil == l2 and nil == c2 then return l, nil, c, nil end
  if nil == l2 or  nil == c2 then error(
    'must provide 2 or 4 indexes (l, l2) or (l, c, l2, c2'
  )end;
  return l, c, l2, c2
end; M.lcs = lcs

-- get the left/top most location of lcs
M.lcsLeftTop = function(...)
  local l, c, l2, c2 = lcs(...)
  c, c2 = c or 1, c2 or 1
  if l == l2 then return l, min(c, c2) end
  if l < l2  then return l, c end
  return l2, c2
end


method(Gap, 'len',  function(g) return #g.bot + #g.top end)

method(Gap, 'cur',  function(g) return g.bot[#g.bot]  end)

method(Gap, 'get', function(g, l)
  local bl = #g.bot
  if l <= bl then  return g.bot[l]
  else return g.top[#g.top - (l - bl) + 1] end
end)
method(Gap, 'last', function(g) return g:get(g:len()) end)
method(Gap, 'bound', function(g, l, c, len, line)
  len = len or g:len()
  l = bound(l, 1, len)
  return l, bound(c, 1, #(line or g:get(l)) + 1)
end)

-- Get the l, c with the +/- offset applied

method(Gap, 'offset', function(g, off, l, c)
  pnt('## offset', off, l, c)
  local len, m, llen, line = g:len()
  -- 0 based index for column
  l = bound(l, 1, len); c = bound(c - 1, 0, #g:get(l))
  while off > 0 do
    line = g:get(l)
    if nil == line then return len, #g:get(len) + 1 end
    llen = #line + 1 -- +1 is for the newline
    c = bound(c, 0, llen); m = llen - c
    pnt('off>0', off, l, c, m, llen)
    if m > off then c = c + off; off = 0;
    else l, c, off = l + 1, 0, off - m
    end
    if l > len then return len, #g:get(len) + 1 end
  end
  while off < 0 do
    line = g:get(l)
    if nil == line then return 1, 1 end
    llen = #line
    c = bound(c, 0, llen); m = -c - 1
    if m < off then c = c + off; off = 0
    else l, c, off = l - 1, CMAX, off - m
    end
    if l <= 0 then return 1, 1 end
  end
  l = bound(l, 1, len)
  return l, bound(c, 0, #g:get(l)) + 1
end)

method(Gap, 'offsetOf', function(g, l, c, l2, c2)
  local off, len, llen = 0, g:len()
  l, c = g:bound(l, c, len);  l2, c2 = g:bound(l2, c2, len)
  c, c2 = c - 1, c2 - 1 -- column math is 0-indexed
  while l < l2 do
    llen = #g:get(l) + 1
    c = bound(c, 0, llen)
    off = off + (llen - c)
    l, c = l + 1, 0
  end
  while l > l2 do
    llen = #g:get(l) + ((l==len and 0) or 1)
    c = bound(c, 0, llen)
    off = off - c
    l, c = l - 1, CMAX
  end
  llen = #g:get(l) + ((l==len and 0) or 1)
  c, c2 = bound(c, 0, llen), bound(c2, 0, llen)
  off = off + (c2 - c)
  return off
end)

-- set the gap to the line
method(Gap, 'set', function(g, l)
  l = l or (#g.bot + #g.top)
  assert(l > 0)
  if l == #g.bot then return end -- do nothing
  if l < #g.bot then
    while l < #g.bot do
      local v = g.bot:pop()
      if nil == v then break end
      g.top:add(v)
    end
  else -- l > #g.bot
    while l > #g.bot do
      local v = g.top:pop()
      if nil == v then break end
      g.bot:add(v)
    end
  end
end)

-- get the sub-buf (slice)
-- of lines (l, l2) or str (l, c, l2, c2)
method(Gap, 'sub', function(g, ...)
  local l, c, l2, c2 = lcs(...)
  local s = List{}
  for i=l, min(l2,   #g.bot)        do s:add(g.bot[i]) end
  for i=1, min((l2-l+1)-#s, #g.top) do s:add(g.top[#g.top - i + 1]) end
  if nil == c then -- skip, only lines
  else
    s[1] = sub(s[1], c, CMAX)
    if #s >= l2 - l then s[#s] = sub(s[#s], 1, c2) end
    s = table.concat(s, '\n')
  end
  return s
end)

method(Gap, '__tostring', function(g)
  local bot = concat(g.bot, '\n')
  if #g.top == 0 then return bot  end
  return bot..'\n'..concat(g.top, '\n')
end)

-- find the pattern starting at l/c
method(Gap, 'find', function(g, pat, l, c)
  c = c or 1
  while true do
    local s = g:get(l)
    if not s then return nil end
    c = s:find(pat, c); if c then return l, c end
    l, c = l + 1, 1
  end
end)

-- find the pattern (backwards) starting at l/c
method(Gap, 'findBack', function(g, pat, l, c)
  while true do
    local s = g:get(l)
    if not s then return nil end
    c = motion.findBack(s, pat, c)
    if c then return l, c end
    l, c = l - 1, nil
  end
end)

--------------------------
-- Gap Mutations

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
  g:set(l2)
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
    b, rem[1]    = strdivide(rem[1], c-1)
    rem[#rem], t = strdivide(rem[#rem], c2)
    rem = concat(rem, '\n')
    g.bot:add(b .. t)
  end
  if 0 == #g.bot then g.bot:add('') end
  return rem
end)

method(Gap, 'append', function(g, s)
  g:set(); g.bot:add(s)
end)

-- extend onto gap. Mostly used internally
method(Gap, 'extend', function(g, s)
  for l in lines(s) do g.bot:add(l) end
end)

Gap.CMAX = CMAX
M.Gap = Gap
return M
