
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

  g:insert('baz ', 1, 4)
  assertEq('foo baz bar', tostring(g))

  g:insert('\nand', 1, 3)
  assertEq('foo\nand baz bar', tostring(g))
  g:insert('buz ', 2, 4)
  assertEq('foo\nand buz baz bar', tostring(g))
end)

test('remove', nil, function()
  local g = Gap.new()
  g:insert('foo bar', 1, 0)
  local r = g:remove(1, 3, 1, 5)
  assertEq('foar', tostring(g))
  assertEq('o b', r)

  g:insert('ab\n123', 1, 3)
  assertEq('foaab\n123r', tostring(g))
  r = g:remove(1, 3, 2, 2)

  g = Gap.new('a\nb')
  r = g:remove(1, 2, 2, 0) -- remove newline
  assertEq('\n', r); assertEq('ab', tostring(g))
  r = g:remove(1, 1, 2, 1)
  assertEq('ab', r); assertEq('', tostring(g))

  g = Gap.new('ab\nc')
  r = g:remove(1, 2, 2, 1)
  assertEq('b\nc', r); assertEq('a', tostring(g));

  g = Gap.new('ab\nc\n\nd')
  assertEq('ab\nc\n\nd', tostring(g));
  print('g.bot', #g.bot, g.bot)
  print('g.top', #g.top, g.top)
  r = g:remove(2, 3)
  print('r', r)
  print('g', g)
  print('g.bot', #g.bot, g.bot)
  print('g.top', #g.top, g.top)
  assertEq(List{'c', ''}, r);
  assertEq('ab\nd', tostring(g));
end)

test('sub', nil, function()
  local g = Gap.new('ab\nc\n\nd')
  assertEq({},          g:sub(1, 0))
  assertEq({'ab'},      g:sub(1, 1))
  assertEq({'ab', 'c'}, g:sub(1, 2))
  assertEq('b\nc',      g:sub(1, 2, 2, 1))
end)

local function _testOffset(g)
  local l, c = g:offset(3, 1, 1)
  assertEq(1, l); assertEq(4, c)
  l, c = g:offset(5, 1, 1)
  assertEq(2, l); assertEq(1, c)
  l, c = g:offset(5, 1, 3)
  assertEq(2, l); assertEq(3, c)
  l, c = g:offset(100, 1, 1)
  assertEq(4, l); assertEq(1, c)

  l, c = g:offset(-1, 1, 3)
  assertEq(1, l); assertEq(2, c)
  l, c = g:offset(-7, 2, 4)
  assertEq(1, l); assertEq(3, c)
  l, c = g:offset(-5, 1, 1)
  assertEq(1, l); assertEq(1, c)
end
test('offset', nil, function()
  local g = Gap.new('12345\n6789\n98765\n')
  _testOffset(g)
  g:set(1) _testOffset(g)
  g:set(2) _testOffset(g)
  g:set(4) _testOffset(g)
end)
