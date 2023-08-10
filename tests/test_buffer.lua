
require'civ':grequire()
grequire'ele.gap'
local buffer = require'ele.buffer'

test('undoIns', nil, function()
  local b = Buffer.new(''); local g = b.gap
  local ch1 = Change{k='ins', s='hello ', l=1, c=1}
  local ch2 = Change{k='ins', s='world!', l=1, c=7}
  local ch = b:insert('hello ', 1, 2)
  assertEq(ch1, ch)
  assertEq('hello ', tostring(g))

  ch = b:insert('world!', 1, 7)
  assertEq(ch2, ch)
  assertEq('hello world!', tostring(g))

  -- undo + redo + undo again
  ch = b:undo()
  assertEq(ch2, ch)
  assertEq('hello ', tostring(g))

  ch = b:redo()
  assertEq(ch2, ch)
  assertEq('hello world!', tostring(g))

  ch = b:undo()
  assertEq(ch2, ch)
  assertEq('hello ', tostring(g))

  -- undo final, then redo twice
  ch = b:undo()
  assertEq(ch1, ch)
  assertEq('', tostring(g))
  b:redo(); ch = b:redo()
  assertEq(ch2, ch)
  assertEq('hello world!', tostring(g))
end)

test('undoInsRm', nil, function()
  local b = Buffer.new(''); local g, ch = b.gap
  local ch1 = Change{k='ins', s='12345\n', l=1, c=1}
  local ch2 = Change{k='rm', s='12', l=1, c=1}
  ch = b:insert('12345\n', 1, 2); assertEq(ch1, ch)

  ch = b:remove(1, 1, 1, 2);      assertEq(ch2, ch)
  assertEq('345\n', tostring(g))

  ch = b:undo();                  assertEq(ch2, ch)
  assertEq('12345\n', tostring(g))

  ch = b:redo();                  assertEq(ch2, ch)
  assertEq('345\n', tostring(g))
end)

test('undoReal', nil, function()
  -- repro a bug I found
  local START = "4     It's nice to have some real data"
  local b = Buffer.new(START); local g, ch = b.gap
  local ch1 = Change{k='rm', s='It',  l=1, c=7}
  local ch2 = Change{k='rm', s="'",   l=1, c=7}
  local ch3 = Change{k='rm', s="'s ", l=1, c=7}
  ch = b:remove(1, 7, 1, 8); assertEq(ch1, ch)
  assertEq("4     's nice to have some real data", tostring(g))

  ch = b:remove(1, 7, 1, 7); assertEq(ch2, ch)
  assertEq("4     s nice to have some real data", tostring(g))

  ch = b:undo();             assertEq(ch2, ch)
  assertEq("4     's nice to have some real data", tostring(g))
  ch = b:undo();             assertEq(ch1, ch)
  assertEq("4     It's nice to have some real data", tostring(g))
  ch = b:redo();             assertEq(ch1, ch)
  assertEq("4     's nice to have some real data", tostring(g))
  ch = b:redo();             assertEq(ch2, ch)
  assertEq("4     s nice to have some real data", tostring(g))

end)

-- test('undoWords', nil, function()
--   "It's nic's nices nice tnice to have"
