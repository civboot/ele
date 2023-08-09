
require'civ':grequire()
grequire'gap'

test('set', nil, function()
  local g = Gap.new('ab\nc\n\nd')
  assertEq('ab\nc\n\nd', tostring(g))
  assertEq({'ab', 'c', '', 'd'}, g.bot)
  g:set(3)
  assertEq({'ab', 'c', ''}, g.bot)
  assertEq({'d'},           g.top)
  assertEq('ab\nc\n\nd', tostring(g))
end)

test('insert', nil, function()
  local g = Gap.new()
  assertEq(1, g:len())
  g:set(1)
  assertEq(1, g:len()); assertEq(1, #g.bot)
  g:insert('foo bar', 1, 0)
  assertEq('foo bar', tostring(g))

  g:insert('baz ', 1, 5)
  assertEq('foo baz bar', tostring(g))

  g:insert('\nand', 1, 4)
  assertEq('foo\nand baz bar', tostring(g))
  g:insert('buz ', 2, 5)
  assertEq('foo\nand buz baz bar', tostring(g))

  g = Gap.new()
  g:insert('foo\nbar', 1, 1)
  assertEq('foo\nbar', tostring(g))
end)

test('remove', nil, function()
  local g = Gap.new()
  g:insert('foo bar', 1, 0)
  local r = g:remove(1, 3, 1, 5)
  assertEq('foar', tostring(g))
  assertEq('o b', r)

  g:insert('ab\n123', 1, 4)
  assertEq('foaab\n123r', tostring(g))
  r = g:remove(1, 3, 2, 2)

  g = Gap.new('a\nb')
  r = g:remove(1, 2, 2, 0) -- remove newline
  assertEq('\n', r);
  assertEq('ab', tostring(g))
  r = g:remove(1, 1, 2, 1)
  assertEq('ab', r); assertEq('', tostring(g))

  g = Gap.new('ab\nc')
  r = g:remove(1, 2, 2, 1)
  assertEq('b\nc', r); assertEq('a', tostring(g));

  g = Gap.new('ab\nc\n\nd')
  assertEq('ab\nc\n\nd', tostring(g));
  r = g:remove(2, 3)
  assertEq(List{'c', ''}, r);
  assertEq('ab\nd', tostring(g));
end)

local function subTests(g)
  assertEq(List{},          g:sub(1, 0))
  assertEq(List{'ab'},      g:sub(1, 1))
  assertEq(List{'ab', 'c'}, g:sub(1, 2))
  assertEq(List{'c', ''},   g:sub(2, 3))
  assertEq('b\nc',      g:sub(1, 2, 2, 1))
end
test('sub', nil, function()
  local g = Gap.new('ab\nc\n\nd')
  g:set(4); subTests(g)
  g:set(1); subTests(g)
  g:set(2); subTests(g)

  g = Gap.new("4     It's nice to have some real data")
  assertEq('It',     g:sub(1, 7, 1, 8))
  assertEq("'",      g:sub(1, 9, 1, 9))
  assertEq("s",      g:sub(1, 10, 1, 10))
  assertEq(" nice",  g:sub(1, 11, 1, 15))
end)

-- test round-trip offset
local function offsetRound(g, expect, off, l, c, expectOff)
  local l2, c2 = g:offset(off, l, c)
  assertEq(expect, {l2, c2})
  local res = g:offsetOf(l, c, l2, c2)
  assertEq(expectOff or off, res)
end

local OFFSET= '12345\n6789\n'
local function _testOffset(g)
  local l, c
  offsetRound(g, {1, 2}, 0,  1, 2)
  offsetRound(g, {1, 3}, 1,  1, 2)
  offsetRound(g, {1, 4}, 3,  1, 1)
  offsetRound(g, {1, 5}, 4,  1, 1) -- '5'
  offsetRound(g, {1, 6}, 5,  1, 1) -- '\n'
  offsetRound(g, {2, 1}, 6,  1, 1) -- '6'
  offsetRound(g, {2, 4}, 9,  1, 1) -- '9'
  offsetRound(g, {2, 5}, 10, 1, 1) -- '\n'
  offsetRound(g, {3, 1}, 11, 1, 1) -- ''
  offsetRound(g, {3, 1}, 12, 1, 1, 11) -- EOF

  offsetRound(g, {1, 2}, -3, 1, 5) -- '2'
  offsetRound(g, {1, 1}, -4, 1, 5) -- '1'
  offsetRound(g, {1, 1}, -5, 1, 5, -4) -- '1'

  offsetRound(g, {2, 5}, -1, 3, 1) -- '\n'
  offsetRound(g, {2, 4}, -2, 3, 1) -- '9'
  offsetRound(g, {2, 3}, -3, 3, 1) -- '8'
  offsetRound(g, {2, 2}, -4, 3, 1) -- '7'
  offsetRound(g, {2, 1}, -5, 3, 1) -- '6'
  offsetRound(g, {1, 6}, -6, 3, 1) -- '\n'
  offsetRound(g, {1, 1}, -11, 3, 1) -- '\n'
  offsetRound(g, {1, 1}, -12, 3, 1, -11) -- BOF


  -- Those are all "normal", let's do some OOB stuff
  offsetRound(g, {2, 1}, 1,  1, 6)
  offsetRound(g, {2, 1}, 1,  1, 10) -- note (1, 6) is EOL
end

test('offset', nil, function()
  local g = Gap.new(OFFSET)
  _testOffset(g)
  g:set(1) _testOffset(g)
  g:set(2) _testOffset(g)
  g:set(4) _testOffset(g)
end)

test('find', nil, function()
  local g = Gap.new('12345\n6789\n98765\n')
  assertEq({1, 3}, {g:find    ('34', 1, 1)})
  assertEq({1, 3}, {g:findBack('34', 2, 3)})
  assertEq({2, 1}, {g:find    ('67', 1, 3)})
  assertEq({2, 1}, {g:find    ('6', 1, 3)})
  assertEq({3, 4}, {g:find    ('6', 2, 2)})
end)
