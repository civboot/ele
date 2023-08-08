local civ  = require'civ':grequire()
grequire'types'
local gap = require'gap'
local term = require'term'
local motion = require'motion'

local M = {}
M.Actions = {}
M.actionStruct = getmetatable(Action).__call
constructor(Action, function(ty_, act)
  local name = assert(act.name)
  if not act.override and M.Actions[name] then
    error('Action already defined: ' .. name)
  end
  M.Actions[name] = M.actionStruct(ty_, act)
  return M.Actions[name]
end)

-- Handle a sub-chain event. This mostly involves storing
-- a sub if we don't have one or cleaning ourselves up
-- if there are multiple (accidental) chains.
local function chainSub(chain, mdl, ev, options)
  local out
  if ev[1] == 'chain' then
    out = List{}
    if self.sub then
      mdl:status("warn: double chain sub, clearing sub")
      mdl.chain = ev
    else
      if options.times and not ev.times then
        ev.times = options.times
      end
      chain.sub = ev
    end
  elseif chain.sub then out = chain.sub:fn(mdl, ev)
  else                  out = mdl:actRaw(ev) end
  return out
end

M.move = function(mdl, ev)
  local e = mdl.edit; e.l, e.c = ev.l, ev.c
end
local function clearState(mdl)
  mdl.chord = nil
  mdl.chain = nil
end
M.insert = function(mdl)
  mdl.mode = 'insert'; clearState(mdl)
end
M.deleteLine = function(mdl)
  local e = mdl.edit; e.buf.gap:remove(e.l, e.c, e.l, gap.CMAX)
end

---------------------------------
-- Core Functionality
Action{ name='chain', brief='start a chain', fn = function(mdl, ev)
  pnt('chain set', ev)
  mdl.chain = ev
end}
Action{ name='move', brief='move cursor', fn = M.move, }

---------------------------------
-- Insert Mode
Action{ name='insert', brief='go to insert mode', fn = M.insert, }
Action{
  name='rawKey', brief='the raw key handler (directly handles all key events)',
  fn = function(mdl, event)
    pnt('raw 0')
    local key = assert(event.key)
    assert(type(key) == 'string', key)

    local action, chordKeys = mdl:getBinding(key), mdl.chordKeys
    chordKeys:add(key)
    pnt('raw 1', ty(action))
    if not action then
      mdl.chord, mdl.chordKeys = nil, List{}
      return List{{'unboundKeys', keys=chordKeys}}
    elseif Action == ty(action) then -- found, continue
      pnt('raw 2')
      mdl.chord, mdl.chordKeys = nil, List{}
      return List{{action.name, keys=chordKeys}}
    elseif Map == ty(action) then
      mdl.chord = action
    else error(action) end
    pnt('raw end')
  end,
}

local function unboundCommand(mdl, keys)
  mdl:unrecognized(keys)
end
local function unboundInsert(mdl, keys)
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

Action{
  name='unboundKeys', brief='handle unbound key',
  fn = function(mdl, event)
    local keys = assert(event.keys)
    if mdl.mode == 'command' then
      unboundCommand(mdl, event.keys)
    elseif mdl.mode == 'insert' then
      unboundInsert(mdl, event.keys)
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
Action{ name='command', brief='go to command mode',
  fn = function(mdl)
    mdl.mode = 'command'; clearState(mdl)
  end,
}
Action{ name='quit', brief='quit the application',
  fn = function(mdl) mdl.mode = 'quit'    end,
}

-- Direct Modification
Action{ name='appendLine', brief='append to line', fn = function(mdl)
  mdl.edit.c = mdl.edit:colEnd(); M.insert(mdl)
end}
Action{ name='changeLine', brief='change line', fn = function(mdl)
  M.deleteLine(mdl); M.insert(mdl)
end}
Action{ name='deleteLine', brief='delete line', fn = M.deleteLine }

----------------
-- Movement: these can be used by commands that expect a movement
--           event to be emitted.
Action{ name='left', brief='move cursor left',
  fn = function(mdl) return List{{'move', l = mdl.edit.l,
    c=max(1, mdl.edit.c - 1)
  }}
  end,
}
Action{ name='up', brief='move cursor up',
  fn = function(mdl) return List{{'move', c = mdl.edit.c,
    l=max(1, mdl.edit.l - 1),
  }}
  end,
}
Action{ name='right', brief='move cursor right',
  fn = function(mdl) return List{{'move', l = mdl.edit.l,
    c=min(mdl.edit.c + 1, #mdl.edit:curLine() + 1),
  }}
  end,
}
Action{ name='down', brief='move cursor down',
  fn = function(mdl)
    local e, ev = mdl.edit, {'move'}
    ev.l, ev.c = min(e.l + 1, e:len() + 1), e.c
    if ev.l > e:len() then
      ev.l, ev.c = e:len(), #e:lastLine() + 1
    end;
    return List{ev}
  end,
}

Action{ name='forword', brief='find the start of the next word',
  fn = function(mdl)
    pnt('forword start')
    local e = mdl.edit
    local out = List{{'move', l=e.l,
      c = motion.forword(e:curLine(), e.c) or (#e:curLine() + 1),
    }}
    pnt('forword start')
    return out
  end,
}
Action{ name='backword', brief='find the start of this (or previous) word',
  fn = function(mdl)
    local e = mdl.edit
    return List{{'move', l=e.l,
      c = motion.backword(e:curLine(), e.c) or 1,
    }}
  end,
}
Action{ name='SoL', brief='start of line', fn = function(mdl)
  return List{{'move', l=mdl.edit.l, c=1}}
end}
Action{ name='EoL', brief='end of line', fn = function(mdl)
  local e = mdl.edit; return List{{'move', l=e.l, c=e:colEnd()}}
end}

----------------
-- Chains
local function timesChain(self, mdl, ev)
  if ev[1] == 'rawKey' and '0' <= ev.key and ev.key <= '9' then
    self.times = (self.times * 10) + tonumber(ev.key)
  else
    ev.times, mdl.chain = max(1, self.times), nil
    return List{ev}
  end
end
Action{ name='times', brief='set mdl.times (do an action multiple times)',
  fn = function(mdl, _ev)
    local ev = {'chain', 'times', times=_ev.times or 0, sub=false, fn=timesChain}
    return List{ev}
  end
}

----
-- Delete Chain
local function deleteChain(self, mdl, ev)
  local out, mv, act = nil, nil, ev[1]
  if act == 'rawKey' and ev.key == 'd' then -- special: delete line
    e.buf.gap:remove(e.l, e.l)
  elseif act == 'move' then
    local e = mdl.edit
    if e.l == ev.l then
      e.buf.gap:remove(e.l, ev.l, e.c, motion.decDistance(e.c, ev.c))
    else e.buf.gap:remove(e.l, ev.l)
    end
  else out = chainSub(self, mdl, ev, {times=self.times}) end
  return out
end
Action{ name='delete', brief='delete chain (use movement)',
  fn = function(mdl, _ev)
    local ev = {'chain', 'delete', times=_ev.times or 1, sub=false, fn=deleteChain}
    return List{ev}
  end
}

return M
