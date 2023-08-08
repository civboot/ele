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

-- Helpful for constructing "state chains"
local function chain(ev, name, add)
  ev.chain = ev.chain or List{}; ev.chain:add(ev[1])
  ev[1] = name; if add then update(ev, add) end
  return List{ev}
end

local function doTimes(ev, fn)
  for _=1, ev.times or 1 do fn() end
  return nil, true
end

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
  return nil, true
end
M.deleteEoL = function(mdl)
  local e = mdl.edit; e.buf.gap:remove(e.l, e.c, e.l, gap.CMAX)
  return nil, true
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
  fn = function(mdl, ev)
    pnt('raw 0')
    local key = assert(ev.key)
    assert(type(key) == 'string', key)
    if ev.execRawKey then
      ev.rawKey = true
      assert(not M.Actions[ev.execRawKey].fn(mdl, ev))
      return nil, true
    end

    local action, chordKeys = mdl:getBinding(key), mdl.chordKeys
    chordKeys:add(key)
    pnt('raw 1', ty(action))
    if not action then
      mdl.chord, mdl.chordKeys = nil, List{}
      return chain(ev, 'unboundKeys', {keys=chordKeys})
    elseif Action == ty(action) then -- found, continue
      pnt('raw 2')
      mdl.chord, mdl.chordKeys = nil, List{}
      return chain(ev, action.name, {keys=chordKeys})
    elseif Map == ty(action) then
      mdl.chord = action
      if ev.chain then mdl.chain = ev end
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
    return nil, true
  end,
}
Action{
  name='back', brief='delete previous character',
  fn = function(mdl, ev)
    return doTimes(ev, function()
      local l, c = mdl.edit:offset(-1)
      mdl.edit:removeOff(-1, l, c)
    end)
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
  return nil, true
end}
Action{ name='changeEoL', brief='change to EoL', fn = function(mdl)
  M.deleteEoL(mdl); M.insert(mdl)
  return nil, true
end}
Action{ name='deleteEoL', brief='delete to EoL', fn = M.deleteEoL }

----------------
-- Movement: these can be used by commands that expect a movement
--           event to be emitted.

local function terminateMovement(mdl, ev, fn)
  local e = mdl.edit
  for _=1, ev.times or 1 do
    if ev.exec then
      ev.l, ev.c = fn(mdl, ev)
      assert(not M.Actions[ev.exec].fn(mdl, ev))
    else e.l, e.c = fn(mdl, ev) end
  end
end

Action{ name='left', brief='move cursor left',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, max(1, mdl.edit.c - 1)
    end
  )end,
}
Action{ name='up', brief='move cursor up',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      return max(1, mdl.edit.l - 1), mdl.edit.c
    end
  )end,
}
Action{ name='right', brief='move cursor right',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      local c = min(mdl.edit.c + 1, #mdl.edit:curLine() + 1)
      return mdl.edit.l, c
    end
  )end,
}
Action{ name='down', brief='move cursor down',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit
      local l, c = min(e.l + 1, e:len() + 1), e.c
      if l > e:len() then
        l, c = e:len(), #e:lastLine() + 1
      end; return l, c
    end
  )end,
}

Action{ name='forword', brief='find the start of the next word',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit;
      local c = motion.forword(e:curLine(), e.c) or (#e:curLine() + 1)
      return e.l, c
    end
  )end,
}
Action{ name='backword', brief='find the start of this (or previous) word',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit;
      return e.l, motion.backword(e:curLine(), e.c) or 1
    end
  )end,
}
Action{ name='SoL', brief='start of line',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, 1
    end
  )end,
}
Action{ name='EoL', brief='end of line',
  fn = function(mdl, ev) return terminateMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, mdl.edit:colEnd()
    end
  )end,
}

----------------
-- Chains
Action{ name='times',
  brief='do an action multiple times (set with 1-9)',
  fn = function(mdl, ev)
    return List{{'chain',
      times=((ev.times or 0) * 10) + tonumber(ev.key)
    }}
  end
}

Action{ name='delete', brief='delete to movement',
  fn = function(mdl, ev)
    if ev.delete and ev.key == 'd' then
      return chain(ev, 'deleteLine')
    end
    return chain(ev, 'chain', {exec='deleteDone', delete=true})
  end
}
Action{ name='deleteLine', brief='delete line',
  fn = function(mdl, ev)
    return doTimes(ev, function()
      local e = mdl.edit
      e.buf.gap:remove(e.l, e.l)
      e.l = min(1, e.l - 1)
    end)
  end,
}
Action{ name='deleteDone', brief='delete to movement',
  fn = function(mdl, ev)
    pnt('deleteDone', ev)
    local e = mdl.edit
    if ev.l then
     if e.l == ev.l then
       e.buf.gap:remove(
         e.l, ev.l, e.c, motion.decDistance(e.c, ev.c))
     else e.buf.gap:remove(e.l, ev.l)
     end
    end
  end
}

return M
