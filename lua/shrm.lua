civ  = require'civ'
shix = require'shix'
term = require'plterm'

local SAVED, ATEXIT

local function enterRawMode()
  assert(nil == SAVED)
  local SAVED, err, msg = savemode()
  assert(err, msg); err, msg = nil, nil
atexit = {__gc = function()
  restoremode(SAVED)
    print('\n  exited shrm successfully\n')
  end}
  setmetatable(atexit, atexit)
  setrawmode()
end


