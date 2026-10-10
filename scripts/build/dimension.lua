-- Dimension Line: a line between two points with a mark at each end and a label beside it, the way a drawing
-- shows a measurement. The line grows out from its middle.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Dimension Line")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "DimCtrl", {
  {"DimText",   L.text("Label", "120 cm")},
  {"DimA",      L.point("From", nil, true), {0.25, 0.4}},
  {"DimB",      L.point("To", nil, true), {0.75, 0.4}},
  {"DimSize",   L.num("Label Size", 0.05, 0.01, 0.3)},
  {"DimOffset", L.num("Label Distance From The Line", 0.06, -0.4, 0.4)},
  {"DimTurn",   L.check("Label Turns With The Line", 1)},
  {"DimEnds",   L.combo("Ends", {"Ticks", "Arrows", "Dots", "Plain"}, 0)},
  {"DimEndSize", L.num("End Size", 0.04, 0.005, 0.2)},
  {"DimThick",  L.num("Line Thickness", 0.005, 0.001, 0.03)},
  {"DimEdge",   L.num("Outline", 0.003, 0, 0.02)},
  {"DimIn",     L.num("Grow (seconds)", 0.4, 0, 3)},
  {"DimOut",    L.num("Fade Out (seconds)", 0.25, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"G",    L.num("G", 0, 0, 1, "Driver")},
  {"Fade", L.num("Fade", 0, 0, 1, "Driver")},
  {"Ang",  L.num("Ang", 0, -360, 360, "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
expr(ctrl, "G", "iif(DimIn <= 0, 1, 1 - (1 - min(max((time - comp.RenderStart + 1)/(DimIn*" .. FPS .. "), 0), 1))^3)")
expr(ctrl, "Fade", "iif(DimOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/(DimOut*" .. FPS .. "), 0), 1))")
-- the direction of the line in degrees, counter-clockwise
expr(ctrl, "Ang", "math.deg(math.atan2(DimB.Y - DimA.Y, (DimB.X - DimA.X)*" .. ASP .. "))")

local line = add("Custom", "DimDraw", -3, 0)
line.Image1 = ctrl.Output
expr(line, "PointIn1", "DimCtrl.DimA")
expr(line, "PointIn2", "DimCtrl.DimB")
expr(line, "NumberIn1", "DimCtrl.DimThick/2")
expr(line, "NumberIn2", "DimCtrl.DimEnds")
expr(line, "NumberIn3", "DimCtrl.DimEndSize")
expr(line, "NumberIn4", "DimCtrl.G")
expr(line, "NumberIn5", "DimCtrl.Ang")
-- i1 half the length (frame height = 1), i2 and i3 this pixel along and across the line, measured from its middle
L.cx(line, "Intermediate1", "max(sqrt(((p2x - p1x)*w/h)^2 + (p2y - p1y)^2)/2, 0.0001)*n4")
L.cx(line, "Intermediate2", "(x - (p1x + p2x)/2)*w/h*cos(n5) + (y - (p1y + p2y)/2)*sin(n5)")
L.cx(line, "Intermediate3", "(y - (p1y + p2y)/2)*cos(n5) - (x - (p1x + p2x)/2)*w/h*sin(n5)")
-- i4 how far before the end this pixel is (negative = beyond it)
L.cx(line, "Intermediate4", "i1 - abs(i2)")
-- i5 the line itself; with arrows it stops where the heads begin
L.cx(line, "Intermediate5", "min(max((n1 - abs(i3))*h + 0.5, 0), 1)*min(max((i4 - if(n2 == 1, n3*0.6, 0))*h + 0.5, 0), 1)")
-- i6 the ends: a cross stroke, an arrow head pointing outwards, or a dot
L.cx(line, "Intermediate6", "if(n2 == 0, min(max((n1 - abs(i4))*h + 0.5, 0), 1)*min(max((n3/2 - abs(i3))*h + 0.5, 0), 1), "
  .. "if(n2 == 1, min(max(i4*h + 0.5, 0), 1)*min(max((i4*0.45 - abs(i3))*h + 0.5, 0), 1)*min(max((n3 - i4)*h + 0.5, 0), 1), "
  .. "if(n2 == 2, min(max((n3/2 - sqrt(i4^2 + i3^2))*h + 0.5, 0), 1), 0)))")
L.cx(line, "Intermediate7", "max(i5, i6)")
for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(line, c .. "Expression", "i7") end

local label = add("TextPlus", "DimLabel", -3, 3)
label:SetInput("UseFrameFormatSettings", 1)
label:SetInput("Font", "Microsoft JhengHei"); label:SetInput("Style", "Bold")
expr(label, "StyledText", "Text(DimCtrl.DimText.Value)")
expr(label, "Size", "DimCtrl.DimSize")
-- the label sits beside the middle of the line, on the side that is "up" when the line is read left to right
local UP = "iif(math.cos(math.rad(DimCtrl.Ang)) < 0, -1, 1)"
expr(label, "Center", "Point((DimCtrl.DimA.X + DimCtrl.DimB.X)/2 - " .. UP .. "*math.sin(math.rad(DimCtrl.Ang))*DimCtrl.DimOffset/" .. ASP
  .. ", (DimCtrl.DimA.Y + DimCtrl.DimB.Y)/2 + " .. UP .. "*math.cos(math.rad(DimCtrl.Ang))*DimCtrl.DimOffset)")
-- turned along the line, but never upside down
expr(label, "AngleZ", "iif(DimCtrl.DimTurn == 1, DimCtrl.Ang + iif(math.cos(math.rad(DimCtrl.Ang)) < 0, 180, 0), 0)")

local matte = add("Merge", "DimMatte", -1, 0)
matte.Background = line.Output; matte.Foreground = label.Output
expr(matte, "Blend", "min(max(DimCtrl.G*2 - 1, 0), 1)")

local c1 = add("Background", "ColDim", -3, -5)
local c2 = add("Background", "ColDimEdge", -2, -5)
for _, hd in ipairs({c1, c2}) do hd:SetInput("UseFrameFormatSettings", 0); hd:SetInput("Width", 16); hd:SetInput("Height", 16) end
L.color(c1, 1, 1, 1, 1); L.color(c2, 0.05, 0.05, 0.08, 1)
local cols = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  cols[i] = "ColDim.TopLeft" .. ch; cols[i + 3] = "ColDimEdge.TopLeft" .. ch; cols[i + 6] = "0"
end
local painted = L.inked(comp, "DimPaint", 0, 0, matte.Output, "DimCtrl.DimEdge", "0", cols)
local out = add("Merge", "DimFinal", 3, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "DimCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 2, {"CTL", "DimLabel", "Font", "Font", "2"})
table.insert(spec, 3, {"CTL", "DimLabel", "Style", "", "2"})
for i, hd in ipairs({{"ColDim", "Colour"}, {"ColDimEdge", "Outline Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "dimension", name = "DimensionLine", out = out, ctrl = ctrl, spec = spec, prefix = "dm"})
