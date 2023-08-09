local civ  = require'civ':grequire()
grequire'types'
local gap = require'gap'
local term = require'term'
local motion = require'motion'
local window = require'window'

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
-- State chains simply build up an event by adding
-- data and modifying the name to execute a different
-- action.
--
-- If name='chain' then the mdl will store it
-- and include it in the next rawKey event.
local function chain(ev, name, add)
  ev.chain = ev.chain or List{}; ev.chain:add(ev[1])
  ev.depth = nil
  ev[1] = name; if add then update(ev, add) end
  return List{ev}, true
end

local function execChain(mdl, ev)
  local evs, sless = M.Actions[ev.exec].fn(mdl, ev)
  assert(not evs)
  return evs, sless
end

local function doTimes(ev, fn)
  for _=1, ev.times or 1 do fn() end
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
M.deleteEoL = function(mdl)
  local e = mdl.edit; e:remove(e.l, e.c, e.l, gap.CMAX)
end

---------------------------------
-- Core Functionality
Action{ name='chain', brief='start/continue a chain', fn = function(mdl, ev)
  mdl.chain = ev
end}
Action{ name='move', brief='move cursor', fn = M.move, }

---------------------------------
-- Insert Mode
Action{ name='insert', brief='go to insert mode', fn = M.insert, }
Action{
  name='rawKey', brief='the raw key handler (directly handles all key events)',
  fn = function(mdl, ev)
    local key = assert(ev.key)
    assert(type(key) == 'string', key)
    if ev.execRawKey then
      return chain(ev, pop(ev, 'execRawKey'), {rawKey=true})
    end
    local action, chordKeys = mdl:getBinding(key), mdl.chordKeys
    chordKeys:add(key)
    if not action then
      mdl.chord, mdl.chordKeys = nil, List{}
      return chain(ev, 'unboundKeys', {keys=chordKeys})
    elseif Action == ty(action) then -- found, continue
      mdl.chord, mdl.chordKeys = nil, List{}
      return chain(ev, action.name, {keys=chordKeys})
    elseif Map == ty(action) then
      mdl.chord = action
      if ev.chain then mdl.chain = ev end
      return nil, true
    elseif M.Actions[action[1]] then
      return List{action} -- raw event
    end error(tfmt(action))
  end,
}

local function unboundCommand(mdl, keys)
  mdl:unrecognized(keys); return nil, true
end
local function unboundInsert(mdl, keys)
  if not mdl.edit then return mdl:status(
    'open a buffer to insert', 'info'
  )end
  for _, k in ipairs(keys) do
    if not term.insertKey(k) then
      mdl:unrecognized(k); return nil, true
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
      return unboundCommand(mdl, event.keys)
    elseif mdl.mode == 'insert' then
      return unboundInsert(mdl, event.keys)
    end
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
end}
Action{ name='changeEoL', brief='change to EoL', fn = function(mdl)
  M.deleteEoL(mdl); M.insert(mdl)
end}
Action{ name='deleteEoL', brief='delete to EoL', fn = M.deleteEoL }
Action{ name='newline', brief='change a new line', fn = function(mdl, ev)
  local e = mdl.edit
  doTimes(ev, function() e:insert('\n') end)
  M.insert(mdl)
end}
local bol = Action{ name='BoL', brief='goto beginning of line',
  fn = function(mdl, ev)
    local e = mdl.edit
    e.c = e:curLine():find('%S') or #e:curLine()
  end
}
Action{ name='changeBoL', brief='change at beginning of line',
  fn = function(mdl, ev)
    bol.fn(mdl, ev); M.insert(mdl)
  end
}
Action{ name='del1', brief='delete single character',
  fn = function(mdl, ev) doTimes(ev, function()
      mdl.edit:removeOff(1)
    end)
  end
}

----------------
-- Movement: these can be used by commands that expect a movement
--           event to be emitted.

-- Do movement function.
-- If this ever results in a stateless movement
-- or action then short-circuit and return
-- whether state happened.
local function doMovement(mdl, ev, fn, once)
  local e, sless = mdl.edit, true
  for _=1, ev.times or 1 do
    local l, c = fn(mdl, ev)
    if not l or not c then break end
    l, c = bound(l, 1, mdl.edit:len()), max(1, c)
    if ev.exec then
      ev.l, ev.c = l, c
      sless = select(2, execChain(mdl, ev))
    else
      e.l, e.c, sless = l, c, false
    end
    if sless or once then break end
  end
  return nil, sless
end

Action{ name='left', brief='move cursor left',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, max(1, mdl.edit.c - 1)
    end
  )end,
}
Action{ name='up', brief='move cursor up',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      return max(1, mdl.edit.l - 1), mdl.edit.c
    end
  )end,
}
Action{ name='right', brief='move cursor right',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local c = min(mdl.edit.c + 1, #mdl.edit:curLine() + 1)
      return mdl.edit.l, c
    end
  )end,
}
Action{ name='down', brief='move cursor down',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit
      return bound(e.l + 1, 1, e:len()), e.c
    end
  )end,
}
Action{ name='forword', brief='find the start of the next word',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit; local l, c, len = e.l, e.c, e:len()
      while l <= len do
        c = motion.forword(e.buf.gap:get(l), c)
        if c then return l, c end
        l = l + 1; if l > len then break end
        c = 1
      end
      return len, #e:lastLine() + 1
    end
  )end,
}
Action{ name='backword', brief='find the start of this (or previous) word',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit; local l, c = e.l, e.c
      while l > 0 do
        c = motion.backword(e.buf.gap:get(l), c)
        if c then return l, c end
        l = l - 1; if l <= 0 then break end
        c = #e.buf.gap:get(l) + 1
      end
      return 1, 1
    end
  )end,
}
Action{ name='SoL', brief='start of line',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, 1
    end
  )end,
}
Action{ name='EoL', brief='end of line',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      return mdl.edit.l, mdl.edit:colEnd()
    end
  )end,
}
Action{ name='goTo', brief='go to top of buf',
  fn = function(mdl, ev)
    doMovement(mdl, ev,
      function(mdl, ev) return ev.times or 1, 1 end
  , true)end,
}
Action{ name='goBot', brief='go to bottom of buf',
  fn = function(mdl, ev) doMovement(mdl, ev,
    function(mdl, ev)
      local e = mdl.edit
      return e:len(), #e:lastLine() + 1
    end
  )end,
}

----------------
-- Chains
Action{ name='times',
  brief='do an action multiple times (set with 1-9)',
  fn = function(mdl, ev)
    return chain(ev, 'chain', {
      times=((ev.times or 0) * 10) + tonumber(ev.key)
    })
  end
}

----
-- Find Character
Action{ name='find', brief='find next character',
  fn = function(mdl, ev)
    return chain(ev, 'chain', {execRawKey='findChar'})
  end
}
Action{ name='findChar', brief='find a specific character',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local ch, e = ev.key, mdl.edit; assert(ev.rawKey)
      if #ch ~= 1 then
        mdl:status('find='..ch, 'invalid')
        return
      end
      return mdl.edit.l, e:curLine():find(ch, e.c)
    end
  )end,
}
Action{ name='findBack', brief='find prev character',
  fn = function(mdl, ev)
    return chain(ev, 'chain', {execRawKey='findCharBack'})
  end
}
Action{ name='findCharBack', brief='find a specific character',
  fn = function(mdl, ev) return doMovement(mdl, ev,
    function(mdl, ev)
      local ch, e = ev.key, mdl.edit; assert(ev.rawKey)
      if #ch ~= 1 then
        mdl:status('find='..ch, 'invalid')
        return
      end
      local r = e:curLine():sub(1, e.c-1):reverse()
      local i = r:find(ch)
      return mdl.edit.l, i and (#r - i + 1)
    end
  )end,
}

----
-- Delete
Action{ name='delete', brief='delete to movement',
  fn = function(mdl, ev)
    if ev.exec == 'deleteDone' and ev.key == 'd' then
      return chain(ev, 'deleteLine')
    end
    return chain(ev, 'chain', {exec='deleteDone'})
  end
}
Action{ name='deleteLine', brief='delete line',
  fn = function(mdl, ev)
    return doTimes(ev, function()
      local e = mdl.edit
      e:remove(e.l, e.l)
      e.l = min(1, e.l - 1)
    end)
  end,
}
Action{ name='deleteDone', brief='delete to movement',
  fn = function(mdl, ev)
    local e = mdl.edit, assert(ev.l and ev.c)
    local c, c2
    if e.l == ev.l then
      c, c2 = sort2(e.c, ev.c)
      e:remove(e.l, c, ev.l, c2 - 1)
      if ev.c < e.c then e.c = ev.c end
    else e:remove(e.l, ev.l)
    end
  end
}

----
-- Search
Action{ name='search', brief='search for pattern',
  fn = function(mdl, ev)
    local e = mdl.searchEdit;
    if not ev.search then
      mdl:showSearch()
      e:trailWs()
      return chain(ev, 'chain', {execRawKey='search', search=''})
    end
    local k = term.insertKey(ev.key)
    local search = ev.search .. (k or ('<'..ev.key..'>'))
    if ev.key == '^N' then return chain(ev, 'searchPrev')
    elseif k == '\n'  then return chain(ev, 'searchNext')
    elseif not k then
      mdl:status('search='..search, 'stop'); window.viewRemove(e)
    else -- append to search, keep searching
      assert(#k == 1)
      e:remove(e:len(), e:len())
      e:append(search)
      return chain(ev, 'chain', {execRawKey='search', search=search})
    end
  end
}

local function searchKind(gapSearch, inc)
  return function(mdl, ev)
    local out = doMovement(mdl, ev, function(mdl, ev)
      local e, search = mdl.edit, mdl.searchEdit:lastLine()
      local l, c = e.buf.gap[gapSearch](e.buf.gap, search, e.l, e.c + inc)
      if l and c then return l, c
      else mdl:status(string.format('not found: %q', search), 'find')
      end
    end)
    window.viewRemove(mdl.searchEdit)
    return out
  end
end
Action{ name='searchNext', brief='search for pattern',
  fn = searchKind('find', 1),
}
Action{ name='searchPrev', brief='search for previous pattern',
  fn = searchKind('findBack', -1),
}

----
-- Undo / Redo
Action{ name='undo', brief='undo previous action',
  fn = function(mdl, ev)
    -- Note: eventually this will "merge" chains of undo's
    mdl.edit:undo()
  end,
}
Action{ name='redo', brief='redo previous undo',
  fn = function(mdl, ev)
    -- Note: eventually this will "merge" chains of redo's
    mdl.edit:redo()
  end,
}


return M
