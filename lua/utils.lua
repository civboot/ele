
local M = {}

M.setDimensions = function(o, d)
  if d.vl then o.vl = d.vl end
  if d.vc then o.vc = d.vc end
  if d.vh then o.vh = d.vh end
  if d.vw then o.vw = d.vw end
end
