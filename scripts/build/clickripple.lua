-- Click Ripple: rings spread out from a point, the way screen recordings show a mouse click or a tap.
-- One clip is one click (or a double click), when the clip starts, at Position. For more clicks, more clips.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Click Ripple")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "RipCtrl", {
  {"RipPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"RipClicks", L.num("Clicks", 1, 1, 3, nil, true)},
  {"RipGap",    L.num("Seconds Between Clicks", 0.18, 0.05, 1)},
  {"RipSize",   L.num("Size", 0.14, 0.02, 1)},
  {"RipLife",   L.num("Ripple Lasts (seconds)", 0.5, 0.1, 3)},
  {"RipRings",  L.num("Rings", 2, 0, 3, nil, true)},
  {"RipThick",  L.num("Ring Thickness", 0.008, 0.001, 0.05)},
  {"RipFill",   L.num("Filled Disc", 0.25, 0, 1)},
  {"RipDot",    L.num("Centre Dot", 0.025, 0, 0.2)},
  {"RipOpacity", L.num("Opacity", 1, 0, 1)},
  {"RipEdge",   L.num("Outline", 0, 0, 0.01)},
  {"Hit",  L.point("Hit", "Driver")},
})
local FPS = "(comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
-- Hit: seconds since the latest click and since the one before it (-1 = none), so two ripples can overlap
expr(ctrl, "Hit", [[(function(ts, n, gap, life)
  local a, b = -1, -1
  for k = 0, n - 1 do
    local dt = ts - k*gap
    if dt >= 0 and dt < life then
      if a < 0 or dt < a then a, b = dt, a elseif b < 0 or dt < b then b = dt end
    end
  end
  return Point(a, b)
end)((time - comp.RenderStart)/]] .. FPS .. [[, RipClicks, RipGap, RipLife)]])
-- One node per ripple (an expression may not get long, see L.cx), so two ripples can be on screen at once.
local function ripple(name, since, row)
  local r = add("Custom", name, -2, row)
  r.Image1 = ctrl.Output
  expr(r, "PointIn1", "RipCtrl.RipPos")
  expr(r, "NumberIn1", "RipCtrl.RipSize/2")
  expr(r, "NumberIn2", "RipCtrl.RipThick")
  expr(r, "NumberIn3", "RipCtrl.RipRings")
  expr(r, "NumberIn4", "RipCtrl.RipFill")
  expr(r, "NumberIn5", "RipCtrl.RipDot/2")
  expr(r, "NumberIn6", "RipCtrl.Hit." .. since .. "/RipCtrl.RipLife") -- how far through its life, negative = not there
  L.cx(r, "Intermediate1", "sqrt(((x - p1x)*w/h)^2 + (y - p1y)^2)")
  -- i2..i4: the rings, each one starting a little after the one before
  for j = 0, 2 do
    local q = string.format("min(max(n6*(1 + 0.25*(n3 - 1)) - %g, 0), 1)", 0.25*j)
    L.cx(r, "Intermediate" .. (j + 2), string.format("if(n3 > %d && %s > 0, min(max((n2*(1 - 0.6*%s)/2 - abs(i1 - n1*(1 - (1 - %s)^3)))*h + 0.5, 0), 1)*(1 - %s)^1.2, 0)", j, q, q, q, q))
  end
  L.cx(r, "Intermediate5", "n4*(1 - n6)*min(max((n1*(1 - (1 - n6)^3) - i1)*h + 0.5, 0), 1)")          -- the disc
  L.cx(r, "Intermediate6", "min(max(1 - n6/0.6, 0), 1)*min(max((n5*min(n6*12, 1) - i1)*h + 0.5, 0), 1)") -- the dot
  L.cx(r, "Intermediate7", "if(n6 < 0, 0, max(max(max(i2, i3), max(i4, i5)), i6))")
  for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(r, c .. "Expression", "i7") end
  return r
end
local ra, rb = ripple("RipDrawA", "X", 0), ripple("RipDrawB", "Y", 1)
local rip = add("Merge", "RipBoth", -1, 0)
rip.Background = ra.Output; rip.Foreground = rb.Output

local c1 = add("Background", "ColRip", -3, -5)
local c2 = add("Background", "ColRipEdge", -2, -5)
for _, hd in ipairs({c1, c2}) do hd:SetInput("UseFrameFormatSettings", 0); hd:SetInput("Width", 16); hd:SetInput("Height", 16) end
L.color(c1, 1, 0.85, 0.1, 1); L.color(c2, 0.1, 0.08, 0.02, 1)
local cols = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  cols[i] = "ColRip.TopLeft" .. ch; cols[i + 3] = "ColRipEdge.TopLeft" .. ch; cols[i + 6] = "0"
end
local painted = L.inked(comp, "RipPaint", 0, 0, rip.Output, "RipCtrl.RipEdge", "0", cols)
local out = add("Merge", "RipFinal", 3, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "RipCtrl.RipOpacity")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
for i, hd in ipairs({{"ColRip", "Colour"}, {"ColRipEdge", "Outline Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "clickripple", name = "ClickRipple", out = out, ctrl = ctrl, spec = spec, prefix = "cr"})
