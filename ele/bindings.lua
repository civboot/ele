-- #####################
-- # Keyboard Bindings
grequire'ele.types'
local term = require'ele.term'
local A = require'ele.action'.Actions
local byte, char = string.byte, string.char

local M = {}

local BIND_TYPES = {
  Action,
}

methods(Bindings, {

new=function()
  return Bindings{insert = Map{}, command = Map{}}
end,
_update=function(b, mode, bindings, checker)
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
end,
updateInsert=function(b, bindings)
  return b:_update('insert', bindings, function(k)
    if term.insertKey(k) then error(
      'bound visible in insert mode: '..k
    )end
  end)
end,
updateCommand=function(b, bindings)
  return b:_update('command', bindings)
end,
DEFAULT = Bindings{insert = Map{}, command = Map{}},
default=function() return deepcopy(Bindings.DEFAULT) end,
})

-- default key bindings (updated in Default Bindings section)



-- #####################
-- # Default Bindings

-- -- Insert Mode
Bindings.DEFAULT:updateInsert{
  ['^Q ^Q'] = A.quit,
  ['^J']    = A.command, ['esc']   = A.command,
  ['back']  = A.back,
}

-- Command Mode
Bindings.DEFAULT:updateCommand{
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

  -- search
  ['/']=A.search, n=A.searchNext,
  N=A.searchPrev, ['^N']=A.searchPrev,

  -- chains
  f=A.find, F=A.findBack, d=A.delete,

  -- undo/redo
  u=A.undo, U=A.redo,
}
for b=byte('0'),byte('9') do
  Bindings.DEFAULT.command[char(b)] = A.times
end

assertEq(Bindings.DEFAULT.command.K, {'up', times=15})

-- default bindings for vim-mode
-- Ele has more consistent bindings than vim:
-- * Movement (including large movement) stick to hjkl
--   In vim they seem to be almost randomly chosen.
-- * Otherwise if a key does something, it's capital does it's opposite when
--   possible, i.e. u/U for undo/redo
M.VIM = Bindings.default()
M.VIM:updateCommand{
  -- In Ele, large movement commands use hjkl.
  ['0']=A.SoL, ['$']=A.EoL,
  H=false, L=false, J=false, L=false,
  ['^D']={'down', times=15}, ['^U']={'up', times=15},

  -- redo slightly different
  ['^R']=A.redo, U=false,
}
return M
