require'civ':grequire()
grequire'motion'

test('wordKind', nil, function()
  assertEq('let', wordKind('a'))
  assertEq('()',  wordKind('('))
  assertEq('()',  wordKind(')'))
  assertEq('sym', wordKind('+'))
end)

test('forword', nil, function()
  assertEq(3, forword('a bcd'))
  assertEq(3, forword('  bcd'))
  assertEq(2, forword(' bcd'))
  assertEq(3, forword('--bcd'))
  assertEq(2, forword('a+ bcd'))
  assertEq(5, forword('+12 +de', 2))
end)

test('backword', nil, function()
  assertEq(3,   backword('a bcd', 4))
  assertEq(3,   backword('  bcd', 4))
  assertEq(nil, backword('  bcd', 3))
end)
