local civ = require'civ':grequire()
civ.TESTING = true
local model = grequire'model'
local shix = require'shix'
local term = require'term'; local tunix = term.unix
local types = require'types'
local window = require'window'
local data = require'data'

local add = table.insert

test('keypress', nil, function()
  assertEq({'a', 'b'},  term.parseKeys('a b'))
  assertEq({'a', '^B'}, term.parseKeys('a ^b'))
  assertEq({'a', '^B'}, term.parseKeys('a ^b'))
  assertEq({'return', '^B'}, term.parseKeys('return ^b'))
end)

test('ctrl', nil, function()
  assertEq('P', term.ctrlChar(16))
end)

local function mockInputs(inputs)
  return List(term.parseKeys(inputs))
end

test('edit (only)', nil, function()
  local t = term.FakeTerm(1, 4); assert(t)
  local e = Edit.new(nil, Buffer.new("1234567\n123\n12345\n"))
  e.tl, e.tc, e.th, e.tw = 1, 1, 1, 4
  e:draw(t, true); assertEq(List{'1234'}, e.canvas)
  e.th, e.tw = 2, 4; t:init(2, 4)
  e:draw(t, true)
  assertEq(List{'1234', '123'}, e.canvas)
  e.l, e.vl = 2, 2; e:draw(t, true)
  assertEq(List{'123', '1234'}, e.canvas)
  assertEq("123\n1234", tostring(t))
end)

local function mockedModel(h, w, s, inputs)
  types.ViewId = 0
  local mdl = Model.new(
    term.FakeTerm(h, w),
    mockInputs(inputs or ''):iterV())
  local e = mdl:newEdit(nil, s)
  e.container, mdl.view, mdl.edit = mdl, e, e
  mdl:init()
  return mdl
end

test('bindings', nil, function()
  local m = mockedModel(5, 5)
  assertEq(m:getBinding('K'), {'up', times=15})
end)


local function testModel(h, w)
  local mdl, status, eTest = model.testModel(
    term.FakeTerm(h, w), mockInputs(''):iterV())
  mdl:init()
  return mdl, status, eTest
end

test('insert', nil, function()
  local m = mockedModel(
    1, 4, -- h, w
    '1234567\n123\n12345\n',
    '1 2 i 8 9')
  assertEq('1', m.inputCo())
  assertEq('2', m.inputCo())
  local e = m.edit;
  assertEq(1, e.l); assertEq(1, e.c)
  m:step(); assertEq(List{'1234'}, e.canvas)
            assertEq(1, e.l); assertEq(1, e.c)
  m:step(); assertEq(List{'8123'}, e.canvas)
            assertEq(1, e.l); assertEq(2, e.c)
  m:step(); assertEq(List{'8912'}, e.canvas)
            assertEq(1, e.l); assertEq(3, e.c)
end)

test('back', nil, function()
  local m = mockedModel(
    1, 7, -- h, w
    '1234567',
    'i back back x')
  local e = m.edit;
  e.l, e.c = 1, 4 -- '4'
  m:step(); assertEq(List{'1234567'}, e.canvas) -- i
            assertEq(1, e.l); assertEq(4, e.c)
  m:step(); assertEq(List{'124567'}, e.canvas) -- back
            assertEq(1, e.l); assertEq(3, e.c)
  m:step(); assertEq(List{'14567'}, e.canvas)  -- back
            assertEq(1, e.l); assertEq(2, e.c)
  m:step(); assertEq(List{'1x4567'}, e.canvas)
            assertEq(1, e.l); assertEq(3, e.c)
end)

local function steps(m, num) for _=1, num do m:step() end end
local function stepKeys(m, keys)
  local inp = mockInputs(keys)
  m.inputCo = inp:iterV()
  for _ in ipairs(inp) do m:step() end
end

test('move', nil, function()
  local m = mockedModel(
    1, 7, -- h, w
    '1234567\n123\n12345',
    'k l h j j') -- up right left down down
  local e = m.edit; e.l, e.c = 2, 3            -- '3' (l 2)
  m:step(); assertEq(1, e.l); assertEq(3, e.c) -- k '3' (l 1)
  m:step(); assertEq(1, e.l); assertEq(4, e.c) -- l '4' (l 1)
  m:step(); assertEq(1, e.l); assertEq(3, e.c) -- h '3' (l 1)
  m:step(); assertEq(2, e.l); assertEq(3, e.c) -- j '3' (l 2)
  m:step(); assertEq(3, e.l); assertEq(3, e.c) -- j '3' (l 3)

  -- now test boundaries
  m.inputCo = mockInputs('j L k l'):iterV() -- down RIGHT up right
  m:step(); assertEq(3, e.l); assertEq(3, e.c) -- '\n' (l 3 EOF)
  m:step(); assertEq(3, e.l); assertEq(6, e.c) -- '\n' (l 3 EOF)
  m:step(); assertEq(2, e.l); assertEq(6, e.c) -- '\n' (l 2)
  m:step(); assertEq(2, e.l); assertEq(4, e.c) -- '\n' l2  (overflow set)

  -- now test insert on overflow
  -- up 3*right down insert-x-
  m.inputCo = mockInputs('k l l l j i x'):iterV()  -- k l l l
  steps(m, 4); assertEq(1, e.l); assertEq(7, e.c); -- '7' (l 1)
               assertEq(1, e.vl)
  m:step();    assertEq(2, e.l); assertEq(7, e.c); -- j (l2 overflow)
               assertEq(2, e.vl)
  m:step();    assertEq(2, e.l); assertEq(7, e.c); -- i
  m:step();    assertEq({2, 5}, {e.l, e.c}) -- x
               assertEq(List{'123x'}, e.canvas)

  -- now test multi-movement
  stepKeys(m, '^J K'); assertEq({1, 5}, {e.l, e.c})
end)

local function splitSetup(m, kind)
  local eR = m.edit
  local eL = window.splitEdit(m.edit, kind)
  local w = eL.container
  assert(rawequal(w, m.view))
  assert(rawequal(w, eR.container))
  assert(rawequal(eR.buf, eL.buf))
  assertEq(eL, w[1]); assertEq(eR, w[2]);
  m:draw()
  return w, eL, eR
end

test('splitH', nil, function()
  local m = mockedModel(
    5, 7, -- h, w
    '1234567\n123')
  local w, eL, eR = splitSetup(m, 'h')
  assertEq(7, w.tw)
  assertEq(7, eR.tw); assertEq(7, eL.tw)
  assertEq(2, eR.th); assertEq(2, eL.th)
  assertEq([[
1234567
123
-------
1234567
123]], tostring(m.term))
end)

test('splitV', nil, function()
  local m = mockedModel(
    2, 20, -- h, w
    '1234567\n123')
  local w, eL, eR = splitSetup(m, 'v')
  assertEq(20, w.tw)
  assertEq(10, eR.tw)
  assertEq(9,  eL.tw)
  assertEq([[
1234567  |1234567
123      |123]], tostring(m.term))
end)


test('splitEdit', nil, function()
  local m = mockedModel(
    5, 7, -- h, w
    '1234567\n123')
  local w, eT, eB = splitSetup(m, 'h')
  stepKeys(m, 'i a b c')
  assertEq([[
abc1234
123
-------
abc1234
123]], tostring(m.term))
  -- go down twice (to EOF) then insert stuff
  stepKeys(m, '^J j j i 4 return b o t t o m')
  assertEq([[
abc1234
1234
-------
1234
bottom]], tostring(m.term))
    assertEq(3, eB.l); assertEq(7, eB.c)
end)


test('withStatus', nil, function()
  local h, w = 9, 16
  local m, status, eTest = testModel(h, w)
  local t = m.term
  m:draw()
  assertEq(eTest, m.edit)
  assertEq(1, indexOf(m.view, eTest))
  assertEq(2, indexOf(m.view, status))
  assertEq(1, status.fh); assertEq(1, status:forceHeight())
  assertEq(1, m.view:forceDim('forceHeight', false))
  assertEq(7, m.view:period(9, 'forceHeight', 1))

  assertEq([[
*123456789*12345
1 This is to man
2               
3               
4     It's nice 
5               
6               
----------------
]], tostring(t))

  stepKeys(m, 'i h i space ^J ~') -- type a bit, trigger status
  assertEq([[
hi *123456789*12
1 This is to man
2               
3               
4     It's nice 
5               
6               
----------------
[unset] chord: ~]], tostring(t))
end)

test('moveWord', nil, function()
  local m = mockedModel(
    1, 7, -- h, w
    ' bc+12 -de \n  z(45+ 7)')
  local e = m.edit; e.l, e.c = 1, 1
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 2) -- 'bc'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 4) -- '+'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 5) -- '12'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 8) -- '-'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 9) -- 'de'
  stepKeys(m, 'w'); assertEq(2, e.l); assertEq(e.c, 3) -- 'z' (next line)

  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 9) -- 'de'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 8) -- '-'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 5) -- '12'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 4) -- '+'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 2) -- 'bc'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 1) -- SOL
  stepKeys(m, 'j b'); assertEq(1, e.l); assertEq(e.c, 9)  -- 'de'
end)

------------
-- Test D C modline
MODLINE_0 = '12345\n8909876'
test('modLine', nil, function()
  local m = mockedModel(2, 8, MODLINE_0)
  local e, t = m.edit, m.term
  e.l, e.c = 1, 1
  stepKeys(m, 'A 6 7 ^J'); assertEq(1, e.l); assertEq(8, e.c)
  assertEq('1234567\n8909876', tostring(t))
  stepKeys(m, 'h h D'); assertEq(1, e.l); assertEq(6, e.c)
    assertEq(MODLINE_0, tostring(t))
  stepKeys(m, 'h h C'); assertEq(1, e.l); assertEq(4, e.c)
    assertEq('insert', m.mode)
  stepKeys(m, 'a b c ^J'); assertEq(1, e.l); assertEq(7, e.c)
    assertEq('123abc\n8909876', tostring(t))
  stepKeys(m, 'H'); assertEq(1, e.l); assertEq(1, e.c)
  stepKeys(m, 'L'); assertEq(1, e.l); assertEq(7, e.c)
  stepKeys(m, 'o h i ^J'); assertEq(2, e.l); assertEq(3, e.c)
    assertEq('123abc\nhi', tostring(t))
  stepKeys(m, 'k H x x'); assertEq(1, e.l); assertEq(1, e.c)
    assertEq('3abc\nhi', tostring(t))
end)

------------
-- Test d delete
DEL = '12 34+56\n78+9'
test('deleteChain', nil, function()
  local m = mockedModel(1, 8, '12 34 567')
  local e, t = m.edit, m.term; e.l, e.c = 1, 1
  stepKeys(m, 'd w'); assertEq(1, e.l); assertEq(1, e.c)
    assertEq('34 567', tostring(t))
  stepKeys(m, '2 d w'); assertEq(1, e.l); assertEq(1, e.c)
     assertEq('', tostring(t))
  e.buf.gap:insert(DEL, 1, 1)
  t:init(2, 8); m:draw(); assertEq(DEL, tostring(t))
  stepKeys(m, 'l j d d');
     assertEq(1, e.l); assertEq(2, e.c)
     assertEq('12 34+56\n', tostring(t))
  stepKeys(m, 'f 4');
    assertEq(1, e.l); assertEq(5, e.c)
  stepKeys(m, 'd f 5');
     assertEq(1, e.l); assertEq(5, e.c)
     assertEq('12 356\n', tostring(t))

  stepKeys(m, 'd F 2');
    assertEq(1, e.l); assertEq(2, e.c)
    assertEq('156\n', tostring(t))
  stepKeys(m, 'g g d G')
    assertEq(1, e.l); assertEq(1, e.c)
    assertEq('\n', tostring(t))
end)

------------
-- Test /search
SEARCH_0 = '12345\n12345678\nabcdefg'
test('modLine', nil, function()
  local m = mockedModel(3, 9, SEARCH_0)
  local e, t, s, sch = m.edit, m.term, m.statusEdit, m.searchEdit
  e.l, e.c = 1, 1
  stepKeys(m, '/ 3 4'); assertEq(1, e.l); assertEq(1, e.c)
  assertEq([[
12345
---------
34]], tostring(t))
  stepKeys(m, 'return'); assertEq(1, e.l); assertEq(3, e.c)
    assertEq(SEARCH_0, tostring(t))
  stepKeys(m, '/ 2 3 4'); assertEq(1, e.l); assertEq(3, e.c)
  assertEq([[
12345
---------
234]], tostring(t))
  stepKeys(m, 'return'); assertEq(2, e.l); assertEq(2, e.c)
    assertEq(SEARCH_0, tostring(t))

  m:showStatus(); m:draw()
  assertEq([[
12345678
---------
]], tostring(t))

  stepKeys(m, '/ 1 2 3')
  assertEq(m.view[1], e)
  assertEq(m.view[2][1], sch)
  assertEq(m.view[2][2], s)
  assertEq(1, m.view[2]:forceHeight())
  assertEq({1, 4}, {s.th, s.tw})
  assertEq({2, 2, 1, 9}, {e.l, e.c, e.th, e.tw})
  assertEq([[
12345678
---------
123 |]], toString(t))
  stepKeys(m, 'return')
assertEq([[
12345678
---------
[find] no]], tostring(t))

  stepKeys(m, 'N'); assertEq(1, e.l); assertEq(1, e.c)
end)

UNDO_0 = '12345\n12345678\nabcdefg'
test('undo', nil, function()
  local m = mockedModel(1, 9, UNDO_0)
  local e, t, s, sch = m.edit, m.term, m.statusEdit, m.searchEdit
  assertEq('12345', tostring(t))

  stepKeys(m, 'd f 3'); assertEq({1, 1}, {e.l, e.c})
    assertEq('345', tostring(t))
  stepKeys(m, 'u'); assertEq({1, 1}, {e.l, e.c})
    assertEq('12345', tostring(t))
  stepKeys(m, 'U'); assertEq({1, 1}, {e.l, e.c})
    assertEq('345', tostring(t))
end)
