local civ  = require'civ':grequire()
grequire'types'
local term = require'term'

local M = {}

local VSEP = '|'
local HSEP = '-'

local BufFillerDash = {
  [6] = '------', [3] = '---',  [1] = '-',
}

---------------------
-- Helper Functions for windows
-- Technically these work on Edit or Window, but they often create a Window.

local function isSplitKind(w, kind)
  return ty(w) == Window and w.splitkind == kind
end
local SPLIT_KINDS = Set{'h', 'v'}

-- split the edit horizontally, return the new copied edit
-- (which will be on the top/left)
M.splitEdit = function(edit, kind)
  assert(SPLIT_KINDS[kind]);
  assert(Edit == ty(edit))
  local container = edit.container
  if not isSplitKind(edit, kind) then
    container = M.wrapWindow(edit)
    container.splitkind = kind
  end
  local new = edit:copy()
  table.insert(container, indexOf(container, edit), new)
  return new
end

-- Replace the view (Edit, Window) object with a new one
M.replaceView = function(mdl, view, new)
  local container = view.container
  if ty(container) == Model then
    container.view = view
  else container[indexOf(container, view)] = new
  end
  if mdl.edit == view then
    assert(ty(new) == Edit)
    mdl.edit = new
  end
  new.container = container; view.container = nil;
  view:close()
  return new
end

-- TODO: should just be windowAdd and you can specify the split type and
-- bot+top
M.windowAddBottom = function(view, add)
  if ty(view) == Model then assert(false) end
  if (ty(view) ~= Window) or w.splitkind == 'v' then
    view = M.wrapWindow(view)
  end
  if not view.splitkind then view.splitkind = 'h' end
  table.insert(view, add)
end



-- wrap an edit/window in a new window
M.wrapWindow = function(w)
  local container = w.container
  local wrapped = Window.new(container); wrapped[1] = w
  if ty(container) == Model then container.view = wrapped
  else container[indexOf(container, w)] = wrapped end
  w.container = wrapped
  return wrapped
end

---------------------
-- Window core methods

Window.__index = listIndex
method(Window, 'new', function(container)
  return Window{
    id=nextViewId(),
    container=container,
    tl=-1, tc=-1,
    th=-1, tw=-1,
  }
end)

----------------------------------
-- Draw Window

local function drawChild(isLast, point, remain, period, sep, force)
  if 0 == force then force = nil end
  local size = (isLast and remain) or force or period
  if size > remain then
    size, point = remain, point + remain
    remain = 0
  else
    point = point + size + ((isLast and 0) or sep)
    remain = remain - size - (isLast and sep or 0)
    size = size - (isLast and sep or 0)
  end
  return point, remain, size
end

-- Draw horizontal separator at l,c of width
local function drawSepH(term, l, c, w, sep)
  for char in sep:gmatch'.' do
    for tc=c, c + w - 1 do term:set(l, tc, sep) end
    l = l + 1
  end
end

-- Draw verticle separator at l,c of height
local function drawSepV(term, l, c, h, sep)
  for char in sep:gmatch'.' do
    for tl=l, l + h - 1 do term:set(tl, c, char) end
    c = c + 1
  end
end

-- return the forced dimension and the number of forceDim children
-- sc: if true, return 0 at first non-forceWidth child
method(Window, 'forceDim', function(w, dimFn, sc)
  local fd, n = 0, 0; for _, ch in ipairs(w) do
    local d = ch[dimFn](ch)
    if d ~= 0 then n, fd = n + 1, fd + d
    elseif sc then return 0, 0 end
  end; return fd, n
end)
method(Window, 'forceWidth',  function(w, dimFn)
  return  w:forceDim('forceWidth', true)
end)
method(Window, 'forceHeight', function(w, dimFn)
  return  w:forceDim('forceHeight', true)
end)

method(Window, 'period', function(w, size, forceDim, sep)
  assert(#w >= 1); sep = sep * (#w - 1)
  local fd, n = w:forceDim(forceDim, false)
  if fd + sep > size then return 0 end
  local varDim = math.floor((size - fd - sep) / (#w - n))
  return varDim
end)

method(Window, 'draw', function(w, term, isRight)
  assert(#w > 0, "Drawing empty window")
  if not w.splitkind then
    assert(#w == 1)
    updateKeys(w[1], w, {'tl', 'tc', 'th', 'tw'})
    child:draw(term, isRight)
  elseif 'v' == w.splitkind then -- verticle split
    assert(#w > 1)
    local tc, remain = w.tc, w.tw
    local period = w:period(w.tw, 'forceWidth', #VSEP)
    for ci, child in ipairs(w) do
      if remain <= 0 then break end
      local isLast = (ci == #w) or (remain <= 1)
      updateKeys(w[ci], w, {'tl', 'th'}); child.tc = tc
      tc, remain, w[ci].tw = drawChild(
        isLast, tc, remain, period, #VSEP, child:forceWidth())
      child:draw(term, isRight and isLast)
      if not isLast then
        drawSepV(term, w.tl, tc - #VSEP, w.th, VSEP)
      end
    end
  elseif 'h' == w.splitkind then -- horizontal split
    assert(#w > 1)
    local tl, remain = w.tl, w.th
    local period = w:period(w.th, 'forceHeight', #HSEP)
    for ci, child in ipairs(w) do
      if remain <= 0 then break end
      local isLast = ci == #w
      updateKeys(child, w, {'tc', 'tw'}); child.tl = tl
      tl, remain, child.th = drawChild(
        isLast, tl, remain, period, #HSEP, child:forceHeight())
      child:draw(term, isRight)
      if ci < #w and remain > 0 then
        drawSepH(term, tl - #HSEP, w.tc, w.tw, HSEP)
      end
    end
  end
end)

return M
