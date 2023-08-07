local civ  = require'civ':grequire()
grequire'types'
local term = require'term'
local motion = require'motion'

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
-- Insert Mode
Action{
  name='insert', brief='go to insert mode',
  fn = function(mdl)
    mdl.mode = 'insert'
    mdl.chord = nil
  end,
}
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
  name='back', brief='delete previous character',
  fn = function(mdl, event)
    local l, c = mdl.edit:offset(-1)
    mdl.edit:remove(-1, l, c)
  end,
}

---------------------------------
-- Command Mode
Action{
  name='command', brief='go to command mode',
  fn = function(mdl)
    mdl.mode = 'command'
    mdl.chord = nil
  end,
}
Action{
  name='quit', brief='quit the application',
  fn = function(mdl) mdl.mode = 'quit'    end,
}
Action{
  name='left', brief='move cursor left',
  fn = function(mdl) mdl.edit.c = max(1, mdl.edit.c - 1) end,
}
Action{
  name='up', brief='move cursor up',
  fn = function(mdl) mdl.edit.l = max(1, mdl.edit.l - 1) end,
}
Action{
  name='right', brief='move cursor right',
  fn = function(mdl) mdl.edit.c = min(mdl.edit.c + 1, #mdl.edit:curLine() + 1) end,
}
Action{
  name='down', brief='move cursor down',
  fn = function(mdl)
    local e = mdl.edit
    e.l = min(mdl.edit.l + 1, e:len() + 1)
    if e.l > e:len() then
      e.l, e.c = e:len(), #e:lastLine() + 1
    end
  end,
}
Action{
  name='forword', brief='find the start of the next word',
  fn = function(mdl)
    local e = mdl.edit
    e.c = motion.forword(e.curLine(), e.c) or (#e.curLine() + 1)
  end,
}
Action{
  name='backword', brief='find the start of this (or previous) word',
  fn = function(mdl)
    local e = mdl.edit
    e.c = motion.backword(e.curLine(), e.c) or 1
  end,
}

return mod
