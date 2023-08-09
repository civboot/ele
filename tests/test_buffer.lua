
require'civ':grequire()
grequire'gap'
local buffer = require'buffer'

local function chUnpack(ch) return {ch.s, ch.l, ch.c} end

test('undo', nil, function()
  local b = Buffer.new(''); local g = b.gap
  local ch1 = {'hello ', 1, 1}
  local ch2 = {'world!', 1, 7}
  local ch = b:insert('hello ', 1, 2)
  -- assertEq(ch1, chUnpack(ch))
  assertEq('hello ', tostring(g))

  ch = b:insert('world!', 1, 7)
  -- assertEq(ch2, chUnpack(ch))
  assertEq('hello world!', tostring(g))

  -- undo + redo + undo again
  ch = b:undo()
  assertEq(ch2, chUnpack(ch))
  assertEq('hello ', tostring(g))

  ch = b:redo()
  assertEq(ch2, {ch.s, ch.l, ch.c})
  assertEq('hello world!', tostring(g))

  ch = b:undo()
  assertEq(ch2, {ch.s, ch.l, ch.c})
  assertEq('hello ', tostring(g))

  -- undo final, then redo twice
  -- ch = b:undo()
  -- assertEq(ch2, {ch.s, ch.l, ch.c})
  -- assertEq('hello ', tostring(g))
end)
