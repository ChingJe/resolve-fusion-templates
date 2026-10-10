-- Pen Mark: a mark drawn by hand over the picture. A circle around something, a line under it, a highlighter,
-- a box, an arrow, a tick, a cross. The line wobbles like a real pen and draws itself on.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Pen Mark")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local SHAPES = {"Circle", "Line", "Wavy Line", "Highlighter", "Box", "Corners", "Arrow", "Tick", "Cross"}
local ctrl, spec = L.panel(comp, "PenCtrl", {
  {"PenShape",   L.combo("Shape", SHAPES, 0)},
  {"PenPos",     L.point("Position", nil, true), {0.5, 0.5}},
  {"PenW",       L.num("Width", 0.3, 0.01, 2)},
  {"PenH",       L.num("Height", 0.3, 0.01, 1)},
  {"PenAngle",   L.num("Angle", 0, -180, 180)},
  {"PenFrom",    L.point("Arrow: From", nil, true), {0.3, 0.3}},
  {"PenTo",      L.point("Arrow: To", nil, true), {0.6, 0.6}},
  {"PenBend",    L.num("Arrow: Bend", 0.15, -0.6, 0.6)},
  {"PenHead",    L.num("Arrow: Head Size", 0.06, 0, 0.3)},
  {"PenThick",   L.num("Thickness", 0.01, 0.001, 0.05)},
  {"PenTaper",   L.num("Thin Ends", 0.5, 0, 1)},
  {"PenWobble",  L.num("Wobble", 1, 0, 4)},
  {"PenSeed",    L.num("Wobble Seed", 1, 0, 50)},
  {"PenPasses",  L.num("Times Drawn Over", 1, 1, 2, nil, true)},
  {"PenBoil",    L.num("Redraw Every (frames, 0 = never)", 0, 0, 24, nil, true)},
  {"PenOverlap", L.num("Circle: Overlap", 0.1, 0, 0.5)},
  {"PenStart",   L.num("Circle: Start Angle", 120, -180, 180)},
  {"PenCorner",  L.num("Corners: Length", 0.35, 0.05, 1)},
  {"PenWaves",   L.num("Wavy Line: Waves", 6, 1, 30)},
  {"PenOpacity", L.num("Opacity", 1, 0, 1)},
  {"PenEdge",    L.num("Outline", 0, 0, 0.01)},
  {"PenDraw",    L.num("Draw (seconds)", 0.4, 0, 3)},
  {"PenExit",    L.combo("Leaves By", {"Fading", "Being Erased", "Staying"}, 0)},
  {"PenOut",     L.num("Leave (seconds)", 0.25, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"Mid", L.point("Mid", "Driver")},
  {"A",   L.num("A", 0, 0, 5, "Driver")},
  {"B",   L.num("B", 0, 0, 5, "Driver")},
  {"Ang", L.num("Ang", 0, -360, 360, "Driver")},
  {"D",   L.num("D", 0, 0, 3, "Driver")},
  {"E",   L.num("E", 0, 0, 1, "Driver")},
  {"Fade", L.num("Fade", 0, 0, 1, "Driver")},
  {"Split", L.num("Split", 1, 0, 1, "Driver")},
  {"S1", L.point("S1", "Driver")}, {"S2", L.point("S2", "Driver")}, {"S3", L.point("S3", "Driver")},
  {"S4", L.point("S4", "Driver")}, {"S5", L.point("S5", "Driver")}, {"S6", L.point("S6", "Driver")},
})
local DIV = os.getenv("FX_DIV") or "2"
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
-- the arrow is given by its two ends, everything else by a centre and a size. A and B are half sizes with the
-- frame height as 1.
expr(ctrl, "Mid", "iif(PenShape == 6, Point((PenFrom.X + PenTo.X)/2, (PenFrom.Y + PenTo.Y)/2), Point(PenPos.X, PenPos.Y))")
expr(ctrl, "A", "iif(PenShape == 6, math.sqrt(((PenTo.X - PenFrom.X)*" .. ASP .. ")^2 + (PenTo.Y - PenFrom.Y)^2)/2, PenW/2)")
expr(ctrl, "B", "PenH/2")
expr(ctrl, "Ang", "iif(PenShape == 6, math.deg(math.atan2(PenTo.Y - PenFrom.Y, (PenTo.X - PenFrom.X)*" .. ASP .. ")), PenAngle)")
-- D runs 0 -> Times Drawn Over while the pen draws, E runs 0 -> 1 while it is erased
expr(ctrl, "D", "PenPasses * iif(PenDraw <= 0, 1, 1 - (1 - min(max((time - comp.RenderStart + 1)/(PenDraw*" .. FPS .. "), 0), 1))^1.5)")
expr(ctrl, "E", "iif(PenExit == 1 and PenOut > 0, 1 - min(max((comp.RenderEnd - time)/(PenOut*" .. FPS .. "), 0), 1), 0)")
expr(ctrl, "Fade", "iif(PenExit == 0 and PenOut > 0, min(max((comp.RenderEnd - time + 1)/(PenOut*" .. FPS .. "), 0), 1), 1)")
-- The straight shapes are up to three lines, given by their ends (seen from the middle of the mark, frame height = 1).
-- Lines 2 and 3 are drawn after line 1, both at the same time. Split = the part of the drawing time line 1 takes.
for i = 1, 6 do
  expr(ctrl, "S" .. i, string.format([[(function(s, A, B, H, i)
  local P
  if s == 6 then P = {{-A, 0}, {A, 0}, {A, 0}, {A - H*0.883, H*0.469}, {A, 0}, {A - H*0.883, -H*0.469}}
  elseif s == 7 then P = {{-A, 0}, {-0.3*A, -B}, {-0.3*A, -B}, {A, B}}
  elseif s == 8 then P = {{-A, B}, {A, -B}, {A, B}, {-A, -B}}
  else P = {{-A, 0}, {A, 0}} end
  local p = P[i] or {99, 99 + i}
  return Point(p[1], p[2])
end)(PenShape, A, B, PenHead, %d)]], i))
end
expr(ctrl, "Split", "iif(PenShape == 6, 0.75, iif(PenShape == 7, 0.3, iif(PenShape == 8, 0.5, 1)))")

-- Custom expressions are slow (every pixel runs the whole expression, unused branches included), so:
-- the strokes are worked out on a small image (distances change smoothly, nothing is lost), each family of shapes
-- has its own node, and Dissolves pick the one in use so that the others are never asked for a picture.
local float = add("Background", "PenFloat", -6, -1)
float:SetInput("UseFrameFormatSettings", 0); float:SetInput("Depth", 4)
expr(float, "Width", "comp:GetPrefs('Comp.FrameFormat.Width')/" .. DIV)
expr(float, "Height", "comp:GetPrefs('Comp.FrameFormat.Height')/" .. DIV)
L.color(float, 0, 0, 0, 0)
local off = add("Background", "PenNone", -1, 5) -- "no stroke anywhere", stands in for the second pass when it is off
off:SetInput("UseFrameFormatSettings", 0); off:SetInput("Width", 16); off:SetInput("Height", 16); off:SetInput("Depth", 4)
L.color(off, 9, 0, 9, 0)

-- Every stroke node writes, per pixel: R the distance to the centre line of stroke 1, G how far along the pen is
-- there (0 at the start, 1 at the end), B and A the same for stroke 2.
local function chain(k)
  -- where this pixel is, seen from the middle of the mark and turned by the angle, then pushed around by slow
  -- waves (that is what makes the line unsteady). The arrow's bend and the wavy line are made here as well, by
  -- bending the space the straight line is drawn in.
  local warp = add("Custom", "PenWarp" .. k, -5, k*4 - 5)
  warp.Image1 = float.Output
  expr(warp, "PointIn1", "PenCtrl.Mid")
  expr(warp, "NumberIn1", "PenCtrl.Ang")
  expr(warp, "NumberIn2", "PenCtrl.PenWobble * 0.035")
  expr(warp, "NumberIn3", string.format("PenCtrl.PenSeed + %d*7.1 + iif(PenCtrl.PenBoil > 0, floor(time/PenCtrl.PenBoil)*3.3, 0)", k))
  expr(warp, "NumberIn4", "max(PenCtrl.A, iif(PenCtrl.PenShape == 1 or PenCtrl.PenShape == 6, 0, PenCtrl.B), 0.001)")
  expr(warp, "NumberIn5", "iif(PenCtrl.PenShape == 6, PenCtrl.PenBend, 0)")
  expr(warp, "NumberIn6", "max(PenCtrl.A, 0.0005)")
  expr(warp, "NumberIn7", "iif(PenCtrl.PenShape == 2, PenCtrl.B, 0)")
  expr(warp, "NumberIn8", "PenCtrl.PenWaves")
  L.cx(warp, "Intermediate1", "(x - p1x)*w/h*cos(n1) + (y - p1y)*sin(n1)")
  L.cx(warp, "Intermediate2", "(y - p1y)*cos(n1) - (x - p1x)*w/h*sin(n1)")
  L.cx(warp, "Intermediate3", "min(max((i1 + n6)/(2*n6), 0), 1)")
  L.cx(warp, "RedExpression", "i1 + n2*n4*(sin(i1/n4*190 + i2/n4*110 + n3*97) + 0.5*sin(i1/n4*430 - i2/n4*310 + n3*211))")
  L.cx(warp, "GreenExpression", "i2 + n2*n4*(sin(i2/n4*170 - i1/n4*130 + n3*133) + 0.5*sin(i2/n4*390 + i1/n4*290 + n3*57)) - n5*8*n6*i3*(1 - i3) - n7*sin(i3*360*n8)")
  L.cx(warp, "BlueExpression", "0"); L.cx(warp, "AlphaExpression", "0")

  -- circle: the pen goes round n3 turns and drifts outwards by n5, so the two ends do not meet
  local round = add("Custom", "PenRound" .. k, -3, k*4 - 6)
  round.Image1 = warp.Output
  expr(round, "NumberIn1", "max(PenCtrl.A, 0.0005)"); expr(round, "NumberIn2", "max(PenCtrl.B, 0.0005)")
  expr(round, "NumberIn3", "1 + PenCtrl.PenOverlap"); expr(round, "NumberIn4", "PenCtrl.PenStart")
  expr(round, "NumberIn5", "0.5*PenCtrl.PenOverlap")
  L.cx(round, "Intermediate1", "sqrt((r1/n1)^2 + (g1/n2)^2)")                           -- 1 on the ellipse
  L.cx(round, "Intermediate2", "frac((n4 - atan2(g1/n2, r1/n1))/360 + 3)")              -- how far round, clockwise
  L.cx(round, "Intermediate3", "sqrt((r1/(n1*n1))^2 + (g1/(n2*n2))^2)/max(i1, 0.0001)") -- turns i1 into a distance
  L.cx(round, "RedExpression", "abs(i1 - (1 + n5*(i2/n3 - 0.5)))/i3")
  L.cx(round, "GreenExpression", "i2/n3")
  L.cx(round, "BlueExpression", "if(i2 + 1 <= n3, abs(i1 - (1 + n5*((i2 + 1)/n3 - 0.5)))/i3, 9)")
  L.cx(round, "AlphaExpression", "(i2 + 1)/n3")

  local lines = add("Custom", "PenLines" .. k, -3, k*4 - 5)
  lines.Image1 = warp.Output
  for i = 1, 4 do expr(lines, "PointIn" .. i, "PenCtrl.S" .. i) end
  expr(lines, "NumberIn1", "PenCtrl.S5.X"); expr(lines, "NumberIn2", "PenCtrl.S5.Y")
  expr(lines, "NumberIn3", "PenCtrl.S6.X"); expr(lines, "NumberIn4", "PenCtrl.S6.Y")
  expr(lines, "NumberIn5", "PenCtrl.Split")
  local function along(ax, ay, bx, by) -- 0 at a, 1 at b
    return string.format("min(max(((r1 - %s)*(%s - %s) + (g1 - %s)*(%s - %s))/((%s - %s)^2 + (%s - %s)^2), 0), 1)", ax, bx, ax, ay, by, ay, bx, ax, by, ay)
  end
  local function away(ax, ay, bx, by, hh)
    return string.format("sqrt((r1 - %s - (%s - %s)*%s)^2 + (g1 - %s - (%s - %s)*%s)^2)", ax, bx, ax, hh, ay, by, ay, hh)
  end
  L.cx(lines, "Intermediate1", along("p1x", "p1y", "p2x", "p2y"))
  L.cx(lines, "Intermediate2", along("p3x", "p3y", "p4x", "p4y"))
  L.cx(lines, "Intermediate3", along("n1", "n2", "n3", "n4"))
  L.cx(lines, "Intermediate4", away("p3x", "p3y", "p4x", "p4y", "i2"))
  L.cx(lines, "Intermediate5", away("n1", "n2", "n3", "n4", "i3"))
  L.cx(lines, "RedExpression", away("p1x", "p1y", "p2x", "p2y", "i1"))
  L.cx(lines, "GreenExpression", "n5*i1")
  L.cx(lines, "BlueExpression", "min(i4, i5)")
  L.cx(lines, "AlphaExpression", "n5 + (1 - n5)*if(i4 < i5, i2, i3)")

  -- box (the pen goes round clockwise from the top left), corners (each drawn outwards from its corner),
  -- highlighter (the whole rectangle, filled, swept from left to right)
  local box = add("Custom", "PenBox" .. k, -3, k*4 - 4)
  box.Image1 = warp.Output
  expr(box, "NumberIn1", "max(PenCtrl.A, 0.0005)"); expr(box, "NumberIn2", "max(PenCtrl.B, 0.0005)")
  expr(box, "NumberIn3", "PenCtrl.PenShape"); expr(box, "NumberIn4", "PenCtrl.PenCorner * min(PenCtrl.A, PenCtrl.B)")
  L.cx(box, "Intermediate1", "sqrt(max(abs(r1) - n1, 0)^2 + max(abs(g1) - n2, 0)^2) + min(max(abs(r1) - n1, abs(g1) - n2), 0)")
  L.cx(box, "Intermediate2", "r1/n1"); L.cx(box, "Intermediate3", "g1/n2")
  L.cx(box, "RedExpression", "if(n3 == 3, i1, if(n3 == 4 || (n1 - abs(r1) < n4 && n2 - abs(g1) < n4), abs(i1), 9))")
  L.cx(box, "GreenExpression", "if(n3 == 3, (i2 + 1)/2, if(n3 == 5, max(n1 - abs(r1), n2 - abs(g1))/n4, "
    .. "if(i3 >= abs(i2), (i2 + 1)/8, if(i2 > abs(i3), 0.25 + (1 - i3)/8, if(i3 <= -abs(i2), 0.5 + (1 - i2)/8, 0.75 + (i3 + 1)/8)))))")
  L.cx(box, "BlueExpression", "9"); L.cx(box, "AlphaExpression", "0")

  local d2 = add("Dissolve", "PenPickB" .. k, -1, k*4 - 5)
  d2.Background = lines.Output; d2.Foreground = box.Output
  expr(d2, "Mix", "iif(PenCtrl.PenShape >= 3 and PenCtrl.PenShape <= 5, 1, 0)")
  local d1 = add("Dissolve", "PenPickA" .. k, -1, k*4 - 6)
  d1.Background = round.Output; d1.Foreground = d2.Output
  expr(d1, "Mix", "iif(PenCtrl.PenShape == 0, 0, 1)")
  return d1
end
local pass1, pass2 = chain(1), chain(2)
local second = add("Dissolve", "PenSecond", 0, 4)
second.Background = off.Output; second.Foreground = pass2.Output
expr(second, "Mix", "iif(PenCtrl.PenPasses >= 2, 1, 0)")

-- the ink: wherever a stroke is near enough and the pen has already been there
local ink = add("Custom", "PenInk", 1, 0)
ink.Image1 = ctrl.Output; ink.Image2 = pass1.Output; ink.Image3 = second.Output
expr(ink, "NumberIn1", "iif(PenCtrl.PenShape == 3, 0, PenCtrl.PenThick/2)")
expr(ink, "NumberIn2", "PenCtrl.D")
expr(ink, "NumberIn3", "PenCtrl.E")
expr(ink, "NumberIn4", "iif(PenCtrl.PenShape == 3, 0, PenCtrl.PenTaper)")
expr(ink, "NumberIn5", "PenCtrl.PenPasses")
local function dab(d, t, k)
  return string.format("if(%d <= n5 && %s <= n2 - %d && %s >= n3 && %s < 8, min(max((n1*(1 - n4*(1 - min(min(%s, 1 - %s)*5, 1))) - %s)*h + 0.5, 0), 1), 0)",
    k, t, k - 1, t, d, t, t, d)
end
L.cx(ink, "Intermediate1", "getr2b(x, y)"); L.cx(ink, "Intermediate2", "getg2b(x, y)")
L.cx(ink, "Intermediate3", "getb2b(x, y)"); L.cx(ink, "Intermediate4", "geta2b(x, y)")
L.cx(ink, "Intermediate5", "max(" .. dab("i1", "i2", 1) .. ", " .. dab("i3", "i4", 1) .. ")")
L.cx(ink, "Intermediate6", "getr3b(x, y)"); L.cx(ink, "Intermediate7", "getg3b(x, y)")
L.cx(ink, "Intermediate8", "max(i5, max(" .. dab("i6", "i7", 2) .. ", " .. dab("getb3b(x, y)", "geta3b(x, y)", 2) .. "))")
for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(ink, c .. "Expression", "i8") end

local c1 = add("Background", "ColPen", -3, -8)
local c2 = add("Background", "ColPenEdge", -2, -8)
for _, hd in ipairs({c1, c2}) do hd:SetInput("UseFrameFormatSettings", 0); hd:SetInput("Width", 16); hd:SetInput("Height", 16) end
L.color(c1, 0.95, 0.15, 0.12, 1); L.color(c2, 1, 1, 1, 1)
local cols = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  cols[i] = "ColPen.TopLeft" .. ch; cols[i + 3] = "ColPenEdge.TopLeft" .. ch; cols[i + 6] = "0"
end
local painted = L.inked(comp, "PenPaint", 2, 0, ink.Output, "PenCtrl.PenEdge", "0", cols)
local out = add("Merge", "PenFinal", 5, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "PenCtrl.PenOpacity * PenCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
for i, hd in ipairs({{"ColPen", "Colour"}, {"ColPenEdge", "Outline Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "penmark", name = "PenMark", out = out, ctrl = ctrl, spec = spec, prefix = "pm"})
