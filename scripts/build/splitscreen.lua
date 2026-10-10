-- Split Screen: shows this clip in one part of the frame and leaves the rest clear. Stack two to four clips on
-- separate tracks, give each one this effect with the same layout and a different part, and they share the frame.
-- The dividing lines can be slanted, and the parts can slide in one after another.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Split Screen")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "SplCtrl", {
  {"SplLayout", L.combo("Layout", {"2 Side By Side", "2 Stacked", "3 Side By Side", "3 Stacked", "4 In A Grid"}, 0)},
  {"SplPart",   L.num("This Clip Is Part", 1, 1, 4, nil, true)},
  {"SplSlant",  L.num("Slant", 0, -40, 40)},
  {"SplGap",    L.num("Gap", 0.012, 0, 0.1)},
  {"SplGapShow", L.num("Gap Colour Opacity", 0, 0, 1)},
  {"SplPan",    L.point("Picture: What Goes In The Middle", nil, true), {0.5, 0.5}},
  {"SplZoom",   L.num("Picture: Zoom", 1, 0.3, 4)},
  {"SplEnter",  L.combo("Appears By", {"Sliding In", "Fading In"}, 0)},
  {"SplFrom",   L.combo("Slides In From", {"Automatic", "Left", "Right", "Top", "Bottom"}, 0)},
  {"SplIn",     L.num("Appear (seconds, 0 = already there)", 0.5, 0, 3)},
  {"SplDelay",  L.num("Each Part Starts Later By (seconds)", 0.12, 0, 2)},
  {"SplOut",    L.num("Leave (seconds, 0 = stays)", 0, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"Xr",  L.point("Xr", "Driver")},
  {"Yr",  L.point("Yr", "Driver")},
  {"Mid", L.point("Mid", "Driver")},
  {"Off", L.point("Off", "Driver")},
  {"E",   L.num("E", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
-- Which stretch of the frame this part covers, left-right (Xr) and bottom-top (Yr). An edge of the frame is
-- pushed far out, so a slanted divider never uncovers a corner.
local RANGE = [[(function(layout, part, axis)
  local n, k = 1, 0
  if layout == 0 or layout == 2 then if axis == 1 then n = (layout == 0) and 2 or 3; k = part - 1 end
  elseif layout == 1 or layout == 3 then if axis == 2 then n = (layout == 1) and 2 or 3; k = n - part end
  elseif axis == 1 then n = 2; k = (part - 1) % 2
  else n = 2; k = 1 - math.floor((part - 1)/2) end
  k = math.max(0, math.min(n - 1, k))
  return Point(k == 0 and -9 or k/n, k == n - 1 and 9 or (k + 1)/n)
end)(SplLayout, SplPart, AXIS)]]
expr(ctrl, "Xr", (RANGE:gsub("AXIS", "1")))
expr(ctrl, "Yr", (RANGE:gsub("AXIS", "2")))
expr(ctrl, "Mid", "Point((max(Xr.X, 0) + min(Xr.Y, 1))/2, (max(Yr.X, 0) + min(Yr.Y, 1))/2)")
expr(ctrl, "E", "min(iif(SplIn <= 0, 1, 1 - (1 - min(max(((time - comp.RenderStart + 1)/" .. FPS .. " - (SplPart - 1)*SplDelay)/SplIn, 0), 1))^3), "
  .. "iif(SplOut <= 0, 1, " .. L.SMOOTH .. "(min(max((comp.RenderEnd - time)/(SplOut*" .. FPS .. "), 0), 1))))")
-- how far the part is still away from its place. Automatic: columns come from above and below in turn, rows from
-- the left and the right in turn, the four of a grid each from their own corner.
expr(ctrl, "Off", [[(function(enter, from, layout, part, e)
  if enter ~= 0 then return Point(0, 0) end
  local dx, dy = 0, 0
  if from == 1 then dx = -1 elseif from == 2 then dx = 1 elseif from == 3 then dy = 1 elseif from == 4 then dy = -1
  elseif layout == 0 or layout == 2 then dy = (part % 2 == 1) and 1 or -1
  elseif layout == 1 or layout == 3 then dx = (part % 2 == 1) and -1 or 1
  else dx = ((part - 1) % 2 == 0) and -1 or 1; dy = (part <= 2) and 1 or -1 end
  return Point(dx*1.3*(1 - e), dy*1.3*(1 - e))
end)(SplEnter, SplFrom, SplLayout, SplPart, E)]])

local col = add("Background", "ColSplitGap", -3, -5)
col:SetInput("UseFrameFormatSettings", 0); col:SetInput("Width", 16); col:SetInput("Height", 16)
L.color(col, 1, 1, 1, 1)

local pane = add("Custom", "SplFinal", 1, 1)
pane.Image1 = srcs[1].Output; pane.Image2 = col.Output
expr(pane, "PointIn1", "SplCtrl.Xr")
expr(pane, "PointIn2", "SplCtrl.Yr")
expr(pane, "PointIn3", "SplCtrl.Off")
expr(pane, "PointIn4", "SplCtrl.SplPan")
-- the slant leans the upright dividers; in a stacked layout it leans the level ones instead
expr(pane, "NumberIn1", "iif(SplCtrl.SplLayout == 1 or SplCtrl.SplLayout == 3, 0, SplCtrl.SplSlant)")
expr(pane, "NumberIn2", "iif(SplCtrl.SplLayout == 1 or SplCtrl.SplLayout == 3, SplCtrl.SplSlant, 0)")
expr(pane, "NumberIn3", "SplCtrl.SplGap/2")
expr(pane, "NumberIn4", "SplCtrl.SplZoom")
expr(pane, "NumberIn5", "SplCtrl.SplGapShow")
expr(pane, "NumberIn6", "iif(SplCtrl.SplEnter == 1, SplCtrl.E, 1)")
expr(pane, "NumberIn7", "SplCtrl.Mid.X")
expr(pane, "NumberIn8", "SplCtrl.Mid.Y")
-- i1, i2: this pixel as if the part were already in place
L.cx(pane, "Intermediate1", "x - p3x")
L.cx(pane, "Intermediate2", "y - p3y")
-- i3: how far inside the part this pixel is (frame height = 1, negative = outside)
L.cx(pane, "Intermediate3", "min(min(i1 + (i2 - 0.5)*tan(n1)*h/w - p1x, p1y - i1 - (i2 - 0.5)*tan(n1)*h/w)*w/h*cos(n1), "
  .. "min(i2 + (i1 - 0.5)*tan(n2)*w/h - p2x, p2y - i2 - (i1 - 0.5)*tan(n2)*w/h)*cos(n2))")
L.cx(pane, "Intermediate4", "n6*min(max((i3 - n3)*h + 0.5, 0), 1)")                  -- the picture
L.cx(pane, "Intermediate5", "n6*n5*min(max(i3*h + 0.5, 0), 1)*(1 - min(max((i3 - n3)*h + 0.5, 0), 1))") -- its half of the gap
L.cx(pane, "Intermediate6", "p4x + (i1 - n7)/n4")
L.cx(pane, "Intermediate7", "p4y + (i2 - n8)/n4")
for _, c in ipairs({"r", "g", "b"}) do
  pane:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("get%s1b(i6, i7)*i4 + get%s2b(0.5, 0.5)*i5", c, c))
end
L.cx(pane, "AlphaExpression", "geta1b(i6, i7)*i4 + i5")

mediaOut.Input = pane.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColSplitGap", "TopLeftRed", "Gap Colour", "3"}
spec[#spec + 1] = {"CTL", "ColSplitGap", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColSplitGap", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "splitscreen", name = "SplitScreen", out = pane, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "ss"})
