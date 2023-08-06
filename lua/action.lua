local civ  = require'civ':grequire()
grequire'types'
local term = require'term'

local mod = {}
mod.Actions = {}
mod.actionStruct = getmetatable(Action).__call
constructor(Action, function(ty_, act)
  local name = assert(act.name)
  if not act.override and mod.Actions[name] then
    error('Action already defined: ' .. name)
  end
  mod.Actions[name] = mod.actionStruct(ty_, act)
  return mod.Actions[name]
end)

---------------------------------
-- Default Actions

Action{
  name='rawKey', brief='the raw key handler (directly handles all key events)',
  fn = function(mdl, event)
    local key = assert(event.key)
    assert(type(key) == 'string', key)

    local action, chordKeys = mdl:getBinding(key), mdl.chordKeys
    chordKeys:add(key)
    if not action then
      mdl.chord, mdl.chordKeys = nil, List{}
      return List{{'insertKeys', keys=chordKeys}}
    elseif Action == ty(action) then -- found, continue
      mdl.chord, mdl.chordKeys = nil, List{}
      return List{{action.name, keys=chordKeys}}
    elseif Map == ty(action) then
      mdl.chord = action
    else error(action) end
  end,
}

Action{
  name='insertKeys', brief='handle unbound key (in insert mode)',
  fn = function(mdl, event)
    local keys = assert(event.keys)
    if mdl.mode == 'command' then
      mdl:unrecognized(keys)
    elseif mdl.mode == 'insert' then
      if not mdl.edit then return mdl:status(
        'Open a buffer to insert'
      )end

      for _, k in ipairs(keys) do
        if not term.isInsertKey(k) then
          mdl:unrecognized(k)
        else
          mdl.edit:insert(term.KEY_INSERT[k] or k)
        end
      end
    end
  end,
}

Action{
  name='quit', brief='quit the application',
  fn = function(mdl) mdl.mode = 'quit'    end,
}
Action{
  name='command', brief='go to command mode',
  fn = function(mdl)
    mdl.mode = 'command'
    mdl.chord = nil
  end,
}
Action{
  name='insert', brief='go to insert mode',
  fn = function(mdl)
    mdl.mode = 'insert'
    mdl.chord = nil
  end,
}

return mod
