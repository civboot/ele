-- #####################
-- # Keyboard Bindings
grequire'types'
local term = require'term'

local M = {}

method(Bindings, '_update', function(b, mode, bindings, checker)
  local bm = b[mode]
  for keys, act in pairs(bindings) do
    assertEq(ty(act), Action)
    assertEq(ty(act.fn), Fn)
    keys = term.parseKeys(keys)
    if checker then
      for _, k in ipairs(keys) do checker(k) end
    end
    bm:setPath(keys, act)
  end
end)
method(Bindings, 'updateInsert', function(b, bindings)
  return b:_update('insert', bindings, function(k)
    if term.insertKey(k) then error(
      'bound visible in insert mode: '..k
    )end
  end)
end)
method(Bindings, 'updateCommand', function(b, bindings)
  return b:_update('command', bindings)
end)

-- default key bindings (updated in Default Bindings section)
M.BINDINGS = Bindings{
  insert = Map{}, command = Map{},
}
method(Bindings, 'default', function() return deepcopy(M.BINDINGS) end)

return M
