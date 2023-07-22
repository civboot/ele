local civ = require'civ':grequire()
civ.TESTING = true
grequire'shrm'
local shix = require'shix'
local term = require'plterm'

local mockKeys = function()

end

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


test('display', nil, function()
  local sh = Shrm.new()
  local e = sh.view
  e.buf.gap:insert(TEST_MSG, 1, 1)
  e.l, e.c = 5, 15
  enterRawMode()

  term.clear();
  e:draw(4, 4,  11, 51)
  term.outf("-- left box --")
  e:draw(4, 56, 11, 51)
  term.outf("-- right box --")
  sleep(); sleep()
end)

