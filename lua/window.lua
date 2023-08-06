local civ  = require'civ':grequire()
grequire'types'
local term = require'term'

local M = {}

local VSEP = ' |'
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

-- split the edit horizontally, return the new copied edit
-- (which will be on the top/left)
M.splitEdit = function(edit, kind)
  assert(kind); assert(Edit == ty(edit))
  local container = edit.container
  if not isSplitKind(edit, kind) then
    container = M.wrapWindow(edit)
    container.splitkind = kind
  end
  local new = edit:copy()
  table.insert(container, indexOf(container, edit), new)
  return new
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
    vl=-1, vc=-1,
    vh=-1, vw=-1,
  }
end)

----------------------------------
-- Draw Window

M.calcPeriod = function(size, sep, num)
  assert(num >= 1)
  sep = sep * (num - 1)
  return math.floor((size - sep) / num)
end

local function drawChild(isLast, point, remain, period, sep)
  local size = (isLast and remain) or period
  point = point + size + ((isLast and 0) or sep)
  remain = remain - size
  return point, remain, size - (isLast and sep or 0)
end

method(Window, 'draw', function(w)
  assert(#w > 0, "Drawing empty window")
  if not w.splitkind then
    assert(#w == 1)
    updateFields(w[1], w, {'vl', 'vc', 'vh', 'vw'})
    child:draw()
    w.canvas = child.canvas
  elseif 'v' == w.splitkind then -- verticle split
    assert(#w > 1)
    local vc, vwRemain, period = w.vc, w.vw, M.calcPeriod(w.vw, #VSEP, #w)
    for ci, child in ipairs(w) do
      updateFields(w[ci], w, {'vl', 'vh'})
      vc, vwRemain, w[ci].vw = drawChild(ci == #w, vc, vwRemain, period, #VSEP)
      child:draw()
    end
  elseif 'h' == w.splitkind then -- horizontal split
    assert(#w > 1)
    w.canvas = List{}
    local vl, vhRemain, period = w.vl, w.vh, M.calcPeriod(w.vh, #HSEP, #w)
    local li = 1
    for ci, child in ipairs(w) do
      updateFields(w[ci], w, {'vc', 'vw'})
      vl, vhRemain, w[ci].vh = drawChild(ci == #w, vl, vhRemain, period, #HSEP)
      child:draw()
      for _, line in ipairs(child.canvas) do
        w.canvas[li] = line; li = li + 1
      end
      if ci < #w then -- separator
        w.canvas[li] = table.concat(fillBuf({}, w.vw, BufFillerDash))
        li = li + 1
      end
    end
  end

end)

return M