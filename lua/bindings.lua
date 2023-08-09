-- #####################
-- # Keyboard Bindings
grequire'types'
local term = require'term'
local A = require'action'.Actions
local byte, char = string.byte, string.char

local M = {}

method(Bindings, 'new', function()
  return Bindings{insert = Map{}, command = Map{}}
end)
local BIND_TYPES = {
  Action,
}
method(Bindings, '_update', function(b, mode, bindings, checker)
  local bm = b[mode]
  for keys, act in pairs(bindings) do
    if act then
      if ty(act) == Action then assertEq(ty(act.fn), Fn)
      else
        local aname = act[1]
        if not A[aname] then error(
          'event[1] is an unknown action: '..aname
        )end
      end
    end
    keys = term.parseKeys(keys)
    if checker then
      for _, k in ipairs(keys) do checker(k) end
    end
    bm:setPath(keys, act or nil)
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
M.BINDINGS = Bindings{insert = Map{}, command = Map{}}


method(Bindings, 'default', function() return deepcopy(M.BINDINGS) end)

-- #####################
-- # Default Bindings

-- -- Insert Mode
M.BINDINGS:updateInsert{
  ['^Q ^Q'] = A.quit,
  ['^J']    = A.command, ['esc']   = A.command,
  ['back']  = A.back,
}

-- Command Mode
M.BINDINGS:updateCommand{
  ['^Q ^Q'] = A.quit,  ['q q'] = A.quit,
  ['^J']  = A.command, ['esc'] = A.command,
  i       = A.insert,
  ['g g'] = A.goTo,   G=A.goBot,

  -- direct modification
  A=A.appendLine, C=A.changeEoL, D=A.deleteEoL,
  o=A.newline,    I=A.changeBoL,
  x=A.del1,

  -- movement
  h=A.left, j=A.down, k=A.up, l=A.right,
  w=A.forword, b=A.backword,
  H=A.SoL, L=A.EoL,
  J={'down', times=15}, K={'up', times=15},
  ['/']=A.search, n=A.searchNext,
  N=A.searchPrev, ['^N']=A.searchPrev,

  -- chains
  f=A.find, F=A.findBack, d=A.delete,

  -- undo/redo
  u=A.undo, U=A.redo,
}
for b=byte('0'),byte('9') do
  M.BINDINGS.command[char(b)] = A.times
end

assertEq(M.BINDINGS.command.K, {'up', times=15})

-- default bindings for vim-mode
M.VIM = Bindings.default()

M.VIM:updateCommand{
  -- SoL/EoL movement a bit different
  ['0']=A.SoL, ['$']=A.EoL,
  H=false, L=false,

  -- redo slightly different
  ['^R']=A.redo, U=false,
}
return M
