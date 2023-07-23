-- Copyright (c) 2022 Phil Leblanc  BSD License github.com/philanc/ple
-- This file has been modified by Rett Berg for civboot. All modificaitons are
-- in the public domain (the original license is preserved)
--[[
plterm - Pure Lua ANSI Terminal functions - unix only

This module assumes that
  - the terminal supports the common ANSI sequences,
  - the current tty encoding is UTF-8,
  - the unix command 'stty' is available (it is used to save
    and restore the tty mode and set the tty in raw mode).

Module functions:

clear()     -- clear screen
cleareol()  -- clear to end of line
golc(l, c)  -- move the cursor to line l, column c
up(n)
down(n)
right(n)
left(n)     -- move the cursor by n positions (default to 1)
color(f, b, m)
            -- change the color used to write characters
    (foreground color, background color, modifier)
    see term.colors
hide()
show()      -- hide or show the cursor
save()
restore()   -- save and restore the position of the cursor
reset()     -- reset the terminal (colors, cursor position)

input()     -- input iterator (coroutine-based)
         return a "next key" function that can be iteratively
         called to read a key (UTF8 sequences and escape 
         sequences returned by function keys are parsed)
rawinput()  -- same, but UTF8 and escape sequences are not parsed.
getcurpos() -- return the current position of the cursor
getscrlc()  -- return the dimensions of the screen
               (number of lines and columns)
keyname()   -- return a printable name for any key
    - key names in term.keys for function keys,
    - control characters are represented as "^A"
    - the character itself for other keys

tty mode management functions

setrawmode()       -- set the terminal in raw mode
setsanemode()      -- set the terminal in a default "sane mode"
savemode()         -- get the current mode as a string
restoremode(mode)  -- restore a mode saved by savemode()

License: BSD
https://github.com/philanc/plterm

-- just in case, a good ref on ANSI esc sequences:
https://en.wikipedia.org/wiki/ANSI_escape_code
(in the text, "CSI" is "<esc>[")

]]

-- if UTF8 below is true, the module assumes that the terminal supports
-- UTF8.  If false, it assumes that the terminal uses an 8-bit encoding 
-- where each character is encoded as one 8-bit byte (eg Latin-1 or 
-- other ISO-8859 encodings).
-- It doesn't make a difference except for the input() and keyname()
-- functions.

-- local UTF8 = false -- 8-bit encoding (eg. ISO-8859 encodings)
local UTF8 = true  -- UTF8 encoding

civ = require'civ'

if UTF8 then local utf8 = require "utf8" end

-- some local definitions

local byte, char, yield = string.byte, string.char, coroutine.yield

-- esc sequenc ascii:     esc,  O, [,    ~
local ESC, LETO, LBR, TIL= 27, 79, 91, 126


------------------------------------------------------------------------

local out = io.write

local function outf(...)
  -- write arguments to stdout, then flush.
  io.write(...); io.flush()
end

local function codepoint(ch)
  if UTF8 then return string.byte(ch)
  else         return utf8.codepoint(ch) end
end

-- following definitions (from term.clear to term.restore) are
-- based on public domain code by Luiz Henrique de Figueiredo
-- http://lua-users.org/lists/lua-l/2009-12/msg00942.html

local term={ -- the plterm module
  out = out,
  outf = outf,
  clear    = function()    out("\027[2J") end, -- *whole screen + move cursor
  cleareol = function()    out("\027[K") end,  -- *from cursor to eol
  golc     = function(l,c) out("\027[",l,";",c,"H") end, -- * line,col
  up       = function(n)   out("\027[",n or 1,"A") end, -- *move cursor
  down     = function(n)   out("\027[",n or 1,"B") end,
  right    = function(n)   out("\027[",n or 1,"C") end,
  left     = function(n)   out("\027[",n or 1,"D") end,
  color = function(f,b,m)
      if m then out("\027[",f,";",b,";",m,"m")
      elseif b then out("\027[",f,";",b,"m")
      else out("\027[",f,"m") end
  end,
  hide    = function() out("\027[?25l") end, -- *the cursor
  show    = function() out("\027[?25h") end, -- *the cursor
  save    = function() out("\027[s") end,    -- *cursor position
  restore = function() out("\027[u") end,    -- *cursor position
  -- reset terminal (clear and reset default colors)
  reset   = function() out("\027c") end,
}

local debugF = io.open('./out/debug.log', 'w')

term.debug = function(...)
  for _, v in ipairs({...}) do
    debugF:write(tostring(v))
    debugF:write('\t')
  end
  debugF:write('\n')
  debugF:flush()
end
local debug = term.debug

term.colors = {
  default = 0,
  -- foreground colors
  black = 30, red = 31, green = 32, yellow = 33,
  blue = 34, magenta = 35, cyan = 36, white = 37,
  -- backgroud colors
  bgblack = 40, bgred = 41, bggreen = 42, bgyellow = 43,
  bgblue = 44, bgmagenta = 45, bgcyan = 46, bgwhite = 47,
  -- attributes
  reset = 0, normal= 0, bright= 1, bold = 1, reverse = 7,
}

----------------
-- parse a string of key presses into its parts
--   example: a b ^c return
local VALID_KEY = {}
for c=byte'A', byte'Z' do VALID_KEY['^'..char(c)] = true end
-- m and i don't have ctrl variants
VALID_KEY['m'] = 'ctrl+m == return';
VALID_KEY['i'] = 'ctrl+i == tabl'

local function assertKey(key)
  assert(#key > 0, 'empty key')
  local v = VALID_KEY[key]; if true == v then return key end
  if #key == 1 then
    local cp = codepoint(key)
    if cp <= 32 or (127 <= cp and cp <= 255) then error(
      string.format(
        '%q is not a printable character for u (in key %q)',
        ch, key)
    )end; return key
  end
  if v then error(string.format('%q not valid key: %s', key, v))
  else error(string.format('%q not valid key', key)) end
end

local function fixKeys(keys)
  for i, k in ipairs(keys) do
    if string.match(k, '^%^') then k = string.upper(k) end
    assertKey(k); keys[i] = k
  end; return keys
end; term.fixKeys = fixKeys

term.parseKeys = function(key)
  local out = {}; for key in string.gmatch(key, '%S+') do
     table.insert(out, key)
  end; return fixKeys(out)
end

term.KEY_INSERT = {
  ['tab']       = '\t',
  ['return'     = '\n',
  ['space']     = ' ',
  ['slash']     = '/',
  ['backslash'] = '\\',
  ['caret']     = '^',
}
for c in pairs(term.KEY_INSERT) do VALID_KEY[c] = true end
local CMD = { -- command characters (not sequences)
  [  9] = 'tab',
  [ 13] = 'return',
  [127] = 'back',
  [ESC] = 'esc',
}
for _, k in pairs(CMD) do
  term.KEY_INSERT[k] = true; VALID_KEY[k] = true
end
term.KEY_INSERT['esc'] = nil

term.isInsertKey = function(k)
  return 1 == #k or term.KEY_INSERT[k]
end

local isdigitsc = function(c)
  -- return true if c is the code of a digit or ';'
  return (c >= 48 and c < 58) or c == 59
end

--ansi sequence lookup table
local CMD_SEQ = {
  ['[A'] = 'up',
  ['[B'] = 'down',
  ['[C'] = 'right',
  ['[D'] = 'left',

  ['[2~'] = 'ins',
  ['[3~'] = 'del',
  ['[5~'] = 'pgup',
  ['[6~'] = 'pgdn',
  ['[7~'] = 'home',  --rxv
  ['[8~'] = 'end',   --rxv
  ['[1~'] = 'home',  --linu
  ['[4~'] = 'end',   --linu
  ['[11~'] = 'f1',
  ['[12~'] = 'f2',
  ['[13~'] = 'f3',
  ['[14~'] = 'f4',
  ['[15~'] = 'f5',
  ['[17~'] = 'f6',
  ['[18~'] = 'f7',
  ['[19~'] = 'f8',
  ['[20~'] = 'f9',
  ['[21~'] = 'f10',
  ['[23~'] = 'f11',
  ['[24~'] = 'f12',

  ['OP'] = 'f1',   --xterm
  ['OQ'] = 'f2',   --xterm
  ['OR'] = 'f3',   --xterm
  ['OS'] = 'f4',   --xterm
  ['[H'] = 'home', --xterm
  ['[F'] = 'end',  --xterm

  ['[[A'] = 'f1',  --linux
  ['[[B'] = 'f2',  --linux
  ['[[C'] = 'f3',  --linux
  ['[[D'] = 'f4',  --linux
  ['[[E'] = 'f5',  --linux

  ['OH'] = 'home', --vt
  ['OF'] = 'end',  --vt
}
for _, kc in pairs(CMD_SEQ) do VALID_KEY[kc] = true end
VALID_KEY['unknown'] = true

local getcode = function()
  local c = io.read(1)
  return byte(c)
end

local function ctrlChar(c)
  if c >= 32 then return nil end
  return char(64+c)
end term.ctrlChar = ctrlChar

local function codeKey(c)
  if     CMD[c]     then return CMD[c]
  elseif ctrlChar(c) then return '^'..ctrlChar(c) end
  return string.char(c)
end

term.input = function()
  -- return a "read next key" function that can be used in a loop
  -- the "next" function blocks until a key is read
  -- it returns ascii or unicode code for all regular keys,
  -- or a key code for special keys (see term.keys)
  return coroutine.wrap(function()
    local c, c1, c2, ci, s, u
    while true do
    c = getcode()
    ::restart::
    if UTF8 and (c & 0xc0 == 0xc0) then
      -- utf8 sequence start
      if c & 0x20 == 0 then -- 2-byte seq
        u = c & 0x1f
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        yield(utf8.char(u))
        goto continue
      elseif c & 0xf0 == 0xe0 then -- 3-byte seq
        u = c & 0x0f
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        yield(utf8.char(u))
        goto continue
      else -- assume it is a 4-byte seq
        u = c & 0x07
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        c = getcode()
        u = (u << 6) | (c & 0x3f)
        yield(utf8.char(u))
        goto continue
      end
    end -- end utf8 sequence. continue with c.
    if c ~= ESC then -- not an esc sequence, yield c
      yield(codeKey(c))
      goto continue
    end
    c1 = getcode()
    if c1 == ESC then -- esc esc [ ... sequence
      yield('esc')
      -- here c still contains ESC, read a new c1
      c1 = getcode() -- and carry on ...
    end
    if c1 ~= LBR and c1 ~= LETO then -- not a valid seq
      yield('esc') ; c = c1
      goto restart
    end
    c2 = getcode()
    s = char(c1, c2)
    if c2 == LBR then -- esc[[x sequences (F1-F5 in linux console)
      s = s .. char(getcode())
    end
    if CMD_SEQ[s] then
      yield(CMD_SEQ[s])
      goto continue
    end
    if not isdigitsc(c2) then
      yield('esc')
      -- TODO: I'm pretty sure this isn't right
      -- We havne't checked the character type of c1 or c2...
      yield(KeyPress.c(c1))
      yield(KeyPress.c(c2))
      goto continue
    end
    while true do -- read until tilde '~'
      ci = getcode()
      s = s .. char(ci)
      if ci == TIL then
        if CMD_SEQ[s] then
          yield(CMD_SEQ[s])
          goto continue
        else
          -- valid but unknown sequence
          -- ignore it
          yield('unknown')
          goto continue
        end
      end
      if not isdigitsc(ci) then
        -- not a valid seq.
        -- return all the chars
        yield('esc')
        for i = 1, #s do yield(codekey(byte(s, i))) end
        goto continue
      end
    end--while read until tilde '~'
    ::continue::
    end--coroutine while loop
  end)--coroutine
end--input()

term.rawinput = function()
  -- return a "read next key" function that can be used in a loop
  -- the "next" function blocks until a key is read
  -- it returns ascii code for all keys
  -- (this function assume the tty is already in raw mode)
  return coroutine.wrap(function()
    local c
    while true do
      c = getcode()
      yield(c)
    end
  end)--coroutine
end--rawinput()

term.getcurpos = function()
  -- return current cursor position (line, column as integers)
  --
  outf("\027[6n") -- report cursor position. answer: esc[n;mR
  local i, c = 0
  local s = ""
  c = getcode(); if c ~= ESC then return nil end
  c = getcode(); if c ~= LBR then return nil end
  while true do
    i = i + 1
    if i > 8 then return nil end
    c = getcode()
    if c == byte'R' then break end
    s = s .. char(c)
  end
  -- here s should be n;m
  local n, m = s:match("(%d+);(%d+)")
  if not n then return nil end
  return tonumber(n), tonumber(m)
end

term.size = function()
  -- return current screen dimensions (line, coloumn as integers)
  term.save()
  term.down(999); term.right(999)
  local l, c = term.getcurpos()
  term.restore()
  return l, c
end

------------------------------------------------------------------------
-- poor man's tty mode management, based on stty
-- (better use slua linenoise extension if available)


-- use the following to define a non standard stty location
-- eg.:  stty = "/opt/busybox/bin/stty"
--
local stty = "stty" -- use the default stty

term.setrawmode = function()
  return os.execute(stty .. " raw -echo 2> /dev/null")
end

term.setsanemode = function()
  return os.execute(stty .. " sane")
end

-- the string meaning that file:read() should return all the
-- content of the file is "*a"  for Lua 5.0-5.2 and LuaJIT,
-- and "a" for more recent Lua versions
-- thanks to Phil Hagelberg for the heads up.
local READALL = (_VERSION < "Lua 5.3") and "*a" or "a"

term.savemode = function()
  local fh = io.popen(stty .. " -g")
  local mode = fh:read(READALL)
  local succ, e, msg = fh:close()
  return succ and mode or nil, e, msg
end

term.restoremode = function(mode)
  return os.execute(stty .. " " .. mode)
end

-- setting __gc causes restoremode to be called on program exit
term.ATEXIT = {}
term.enterRawMode = function()
  assert(not getmetatable(term.ATEXIT))
  local SAVED, err, msg = term.savemode()
  assert(err, msg); err, msg = nil, nil
  local atexit = {
    __gc = function()
      term.clear()
      term.restoremode(SAVED)
      debug('Exited raw mode')
   end,
  }
  setmetatable(term.ATEXIT, atexit)
  term.setrawmode()
  debug('Entered raw mode')
end
term.exitRawMode = function()
  local mt = getmetatable(term.ATEXIT); assert(mt)
  mt.__gc()
  setmetatable(term.ATEXIT, nil)
end

return term
