local civ = require'civ':grequire()
civ.TESTING = true
grequire'model'
local shix = require'shix'
local term = require'term'; local tunix = term.unix
local types = require'types'
local window = require'window'

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
  return List(term.parseKeys(inputs)):iterValues()
end

test('edit', nil, function()
  local e = Edit.new(nil, Buffer.new(
    "1234567\n123\n12345\n"), 1, 4)
  e:draw(); assertEq(List{'1234'}, e.canvas)
  e.vh, e.vw = 2, 4; e:draw()
  assertEq(List{'1234', '123 '}, e.canvas)
  e.vl = 2; e:draw()
  assertEq(List{'123 ', '1234'}, e.canvas)
end)

local function mockedModel(h, w, s, inputs)
  local app = Model.new(
    term.FakeTerm(h, w),
    mockInputs(inputs or ''))
  local e = Edit.new(app, Buffer.new(s), h, w)
  app.view, app.edit = e, e
  app.paint = function() end
  app.status = function(t, ...)
    if ty(t) == Tbl then print(concat(t))
    else print(t, ...) end
  end
  return app
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

test('calcPeriod', nil, function()
  assertEq(9, window.calcPeriod(20, 2, 2))
end)

local function splitSetup(m, kind)
  local e1 = m.edit
  assertEq(2, e1.id)
  local e2 = window.splitEdit(m.edit, kind)
  local w = e2.container
  assert(rawequal(w, m.view))
  assert(rawequal(w, e1.container))
  assert(rawequal(e1.buf, e2.buf))
  assertEq(3, w.id)
  assertEq(4, e2.id)
  assertEq(e2, w[1]); assertEq(e1, w[2]);
  m:draw()
  return w, e1, e2
end

local SPLIT_CANVAS_H = [[
1234567
123    
-------
1234567
123    ]]
test('splitH', nil, function()
  types.ViewId = 0
  local m = mockedModel(
    5, 7, -- h, w
    '1234567\n123')
  local w, e1, e2 = splitSetup(m, 'h')
  assertEq(7, w.vw)
  assertEq(7, e1.vw); assertEq(7, e2.vw)
  assertEq(2, e1.vh); assertEq(2, e2.vh)
  assertEq(SPLIT_CANVAS_H, table.concat(w.canvas, '\n'))
end)

local SPLIT_CANVAS_V = [[
1234567   | 1234567  
123       | 123      ]]

test('splitV', nil, function()
  types.ViewId = 0
  local m = mockedModel(
    2, 20, -- h, w
    '1234567\n123')
  local w, e1, e2 = splitSetup(m, 'v')
  assertEq(20, w.vw)
  assertEq(9, e1.vw); assertEq(9, e2.vw)
  -- assertEq(SPLIT_CANVAS_V, concat(w.canvas, '\n'))
end)



---------------------------------------------
-- These are commented out and require user-interaction

local function sleep()
  shix.sleep(Duration(0.9))
end


local TEST_MSG = [[
*123456789*123456789*123456789*123456789*123456789*
1       -- This is a test of the display.      -- 1
2                                                 2
3                                                 3
4                                                 4
5                                                 5
6                                                 6
7                                                 7
8                                                 8
9          -- Please do not be alarmed. --        9
*123456789*123456789*123456789*123456789*123456789*]]


--[[
test('display', nil, function()
  local sh = Model.new(term.UnixTerm)
  local e = sh.view
  e.buf.gap:insert(TEST_MSG, 1, 1)
  e.l, e.c = 5, 15
  tunix.enterRawMode()

  tunix.clear();
  e:draw(4, 4,  11, 51)
  tunix.outf("-- left box --")
  e:draw(4, 56, 11, 51)
  tunix.outf("-- right box --")
  sleep(); sleep()
  tunix.exitRawMode()
end) --]]

--[[
test('input', nil, function()
  print('Note: Cntrl+C to exit. Use to test input. '
         .. 'Logs are in out/debug.log')
  tunix.enterRawMode()
  for kp in tunix.input() do
    term.debug('Key: ', tostring(kp), kp.c and term.keyname(kp.c))
    if '^C' == kp then break end
  end
  tunix.exitRawMode()
end) --]]

