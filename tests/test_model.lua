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

test('edit', nil, function()
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
  local e = Edit.new(mdl, Buffer.new(s), h, w)
  mdl.view, mdl.edit = e, e
  mdl:init()
  return mdl
end

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
  e.l, e.c = 1, 4
  m:step(); assertEq(List{'1234567'}, e.canvas)
            assertEq(1, e.l); assertEq(4, e.c)
  m:step(); assertEq(List{'124567'}, e.canvas)
            assertEq(1, e.l); assertEq(3, e.c)
  m:step(); assertEq(List{'14567'}, e.canvas)
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
  local e = m.edit; e.l, e.c = 2, 3
  m:step(); assertEq(1, e.l); assertEq(3, e.c)
  m:step(); assertEq(1, e.l); assertEq(4, e.c)
  m:step(); assertEq(1, e.l); assertEq(3, e.c)
  m:step(); assertEq(2, e.l); assertEq(3, e.c)
  m:step(); assertEq(3, e.l); assertEq(3, e.c)

  -- now test boundaries
  m.inputCo = mockInputs('j k l'):iterV() -- down right up right
  m:step(); assertEq(3, e.l); assertEq(6, e.c) -- down (does nothing)
  m:step(); assertEq(2, e.l); assertEq(6, e.c) -- up    (column overflow keep)
  m:step(); assertEq(2, e.l); assertEq(4, e.c) -- right (column overflow set)

  -- now test insert on overflow
  -- up 3*right down insert-x-
  m.inputCo = mockInputs('k l l l j i x'):iterV()
  steps(m, 4); assertEq(1, e.l); assertEq(7, e.c); -- k l l l
               assertEq(1, e.vl)
  m:step();    assertEq(2, e.l); assertEq(7, e.c); -- j
               assertEq(2, e.vl)
  m:step();    assertEq(2, e.l); assertEq(7, e.c); -- i
  m:step();    assertEq(2, e.l); assertEq(5, e.c); -- x
               assertEq(List{'123x'}, e.canvas)
end)

test('calcPeriod', nil, function()
  assertEq(9, window.calcPeriod(20, 2, 2))
end)

local function splitSetup(m, kind)
  local eR = m.edit
  assertEq(2, eR.id)
  local eL = window.splitEdit(m.edit, kind)
  local w = eL.container
  assert(rawequal(w, m.view))
  assert(rawequal(w, eR.container))
  assert(rawequal(eR.buf, eL.buf))
  assertEq(3, w.id)
  assertEq(4, eL.id)
  assertEq(eL, w[1]); assertEq(eR, w[2]);
  m:draw()
  return w, eL, eR
end

local SPLIT_CANVAS_H = [[
1234567
123
-------
1234567
123]]
test('splitH', nil, function()
  local m = mockedModel(
    5, 7, -- h, w
    '1234567\n123')
  local w, eL, eR = splitSetup(m, 'h')
  assertEq(7, w.tw)
  assertEq(7, eR.tw); assertEq(7, eL.tw)
  assertEq(2, eR.th); assertEq(2, eL.th)
  assertEq(SPLIT_CANVAS_H, tostring(m.term))
end)

local SPLIT_CANVAS_V = [[
1234567  |1234567
123      |123]]
test('splitV', nil, function()
  local m = mockedModel(
    2, 20, -- h, w
    '1234567\n123')
  local w, eL, eR = splitSetup(m, 'v')
  assertEq(20, w.tw)
  assertEq(10, eR.tw);
  assertEq(9,  eL.tw)
  assertEq(SPLIT_CANVAS_V, tostring(m.term))
end)


local SPLIT_EDIT_1 = [[
abc1234
123
-------
abc1234
123]]
local SPLIT_EDIT_2 = [[
abc1234
1234
-------
1234
bottom]]
test('splitEdit', nil, function()
  local m = mockedModel(
    5, 7, -- h, w
    '1234567\n123')
  local w, eT, eB = splitSetup(m, 'h')
  stepKeys(m, 'i a b c')
    assertEq(SPLIT_EDIT_1, tostring(m.term))
  -- go down twice (to EOF) then insert stuff
  stepKeys(m, '^J j j i 4 return b o t t o m')
    assertEq(SPLIT_EDIT_2, tostring(m.term))
    assertEq(3, eB.l); assertEq(7, eB.c)
end)

local STATUS_1 = [[
*123456789*12345
1 This is to man
----------------

]]

local STATUS_2 = [[
hi *123456789*12
1 This is to man
----------------

]]

test('withStatus', nil, function()
  local m, status, eTest = testModel(5, 16)
  local t = m.term
  assertEq(eTest, m.edit)
  assertEq(1, indexOf(m.view, eTest))
  assertEq(2, indexOf(m.view, status))
  assertEq(STATUS_1, tostring(t))
  stepKeys(m, 'i h i space')
  assertEq(STATUS_2, tostring(t))
end)

test('moveWord', nil, function()
  local m = mockedModel(
    1, 7, -- h, w
    ' bc+12 -de \n  z(45+ 7)')
  local e = m.edit; e.l, e.c = 1, 1
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 2)  -- 'bc'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 4)  -- '+'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 5)  -- '12'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 8)  -- '-'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 9)  -- 'de'
  stepKeys(m, 'w'); assertEq(1, e.l); assertEq(e.c, 12) -- EOL

  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 9)  -- 'de'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 8)  -- '-'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 5)  -- '12'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 4)  -- '+'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 2)  -- 'bc'
  stepKeys(m, 'b'); assertEq(1, e.l); assertEq(e.c, 1)  -- SOL
end)

MODLINE_0 = '12345\n8909876'
MODLINE_1 = '1234567\n8909876'
MODLINE_2 = '123abc\n8909876'
test('modLine', nil, function()
  local m = mockedModel(2, 8, MODLINE_0)
  local e, t = m.edit, m.term
  e.l, e.c = 1, 1
  stepKeys(m, 'A 6 7 ^J'); assertEq(1, e.l); assertEq(8, e.c)
    assertEq(MODLINE_1, tostring(t))
  stepKeys(m, 'h h D'); assertEq(1, e.l); assertEq(6, e.c)
    assertEq(MODLINE_0, tostring(t))
  stepKeys(m, 'h h C'); assertEq(1, e.l); assertEq(4, e.c)
    assertEq('insert', m.mode)
  stepKeys(m, 'a b c ^J'); assertEq(1, e.l); assertEq(7, e.c)
    assertEq(MODLINE_2, tostring(t))
  stepKeys(m, '0'); assertEq(1, e.l); assertEq(1, e.c)
  stepKeys(m, '$'); assertEq(1, e.l); assertEq(7, e.c)
end)


DEL_CHAIN_0 = '12 34 567'
DEL_CHAIN_1 = '34 567'
DEL_CHAIN_2 = '567'
test('deleteChain', nil, function()
  local m = mockedModel(1, 8, DEL_CHAIN_0)
  local e, t = m.edit, m.term; e.l, e.c = 1, 1
  stepKeys(m, 'd w'); assertEq(1, e.l); assertEq(1, e.c)
    assertEq(DEL_CHAIN_1, tostring(t))
  stepKeys(m, 'd w'); assertEq(1, e.l); assertEq(1, e.c)
    assertEq(DEL_CHAIN_2, tostring(t))
  stepKeys(m, 'd w'); assertEq(1, e.l); assertEq(1, e.c)
    assertEq('', tostring(t))
end)


