
require'civ':grequire()
grequire'buf'


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
end)
