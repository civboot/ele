
M = {}
local byte, char = string.byte, string.char

local WordKind = {}; M.WordKind = WordKind -- ws, sym, let
for c=0, 127 do
  local ch, kind = char(c), nil
  if 0 <= c and ch <= ' '        then kind = 'ws'
  elseif 'a' <= ch and ch <= 'z' then -- let, leave
  elseif 'A' <= ch and ch <= 'Z' then -- let, leave
  elseif ch == '_'               then -- let, leave
  else kind = 'sym' end
  WordKind[ch] = kind
end
WordKind['('] = '()'; WordKind[')'] = '()'
WordKind['['] = '[]'; WordKind[']'] = '[]'
WordKind['{'] = '{}'; WordKind['}'] = '{}'
WordKind['"'] = '"'   WordKind["'"] = "'"

local function wordKind(ch) return WordKind[ch] or 'let' end
M.wordKind = wordKind

-- Go forward to find the start of the next word
M.forword = function(s, begin)
  begin = begin or 1
  local i, kStart = 2, wordKind(s:sub(begin,begin))
  for ch in string.gmatch(s:sub(begin+1), '.') do
    local k = wordKind(ch)
    if k ~= kStart then
      if kStart ~= 'ws' and k == 'ws' then
        kStart = ws -- find first non-whitespace
      else return i end
    end
    i = i + 1
  end
end

-- Go backward to find the start of this (or previous) word
M.backword = function(s, end_)
  s = s:sub(1, end_-1):reverse()
  local i, kStart = 2, wordKind(s:sub(1,1))
  for ch in string.gmatch(s:sub(2), '.') do
    local k = wordKind(ch)
    if k ~= kStart then
      if kStart == 'ws' then kStart = k
      else return #s - i + 2 end
    end
    i = i + 1
  end
end

return M
