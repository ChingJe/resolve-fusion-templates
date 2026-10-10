-- Rec Frame: what a camera shows in its viewfinder. Corner marks, a blinking REC dot, a running timecode,
-- a battery, a line of text, a centre cross and a grid. Each part can be switched off.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Rec Frame")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "RecCtrl", {
  {"RecMargin",  L.num("Distance From The Edge", 0.06, 0, 0.3)},
  {"RecThick",   L.num("Line Thickness", 0.004, 0.001, 0.02)},
  {"RecCorners", L.num("Corner Marks: Length (0 = none)", 0.09, 0, 0.5)},
  {"RecDot",     L.check("REC Dot", 1)},
  {"RecBlink",   L.num("REC Dot: Seconds Per Blink (0 = steady)", 1, 0, 5)},
  {"RecWord",    L.text("REC Text", "REC")},
  {"RecTime",    L.check("Timecode", 1)},
  {"RecStart",   L.num("Timecode: Starts At (seconds)", 0, 0, 36000)},
  {"RecInfo",    L.text("Text At The Bottom Left (may be empty)", "4K 60FPS")},
  {"RecBattery", L.check("Battery", 1)},
  {"RecLevel",   L.num("Battery: Charge", 0.7, 0, 1)},
  {"RecCross",   L.check("Centre Cross", 1)},
  {"RecGrid",    L.num("Grid Opacity", 0, 0, 1)},
  {"RecSize",    L.num("Text Size", 0.035, 0.01, 0.12)},
  {"RecOpacity", L.num("Opacity", 0.9, 0, 1)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"Sec", L.num("Sec", 0, 0, 1e6, "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
expr(ctrl, "Sec", "(time - comp.RenderStart)/" .. FPS)

local c1 = add("Background", "ColRec", -3, -5)
local c2 = add("Background", "ColRecDot", -2, -5)
for _, hd in ipairs({c1, c2}) do hd:SetInput("UseFrameFormatSettings", 0); hd:SetInput("Width", 16); hd:SetInput("Height", 16) end
L.color(c1, 1, 1, 1, 1); L.color(c2, 1, 0.12, 0.1, 1)

-- Everything that is a line or a shape, in two nodes because an expression may not get long (see L.cx).
-- i1, i2 = this pixel from the middle of the frame, frame height = 1; i3, i4 = half the size of the marked area.
-- The top row (dot, battery) and the bottom row (texts) sit a little inside the corner marks.
local INSET, ROW = 0.035, 0.05
local function frame(name, col)
  local t = add("Custom", name, col, 0)
  expr(t, "NumberIn1", "RecCtrl.RecMargin")
  expr(t, "NumberIn2", "RecCtrl.RecThick/2")
  L.cx(t, "Intermediate1", "(x - 0.5)*w/h")
  L.cx(t, "Intermediate2", "y - 0.5")
  L.cx(t, "Intermediate3", "0.5*w/h - n1")
  L.cx(t, "Intermediate4", "0.5 - n1")
  return t
end
local marks = frame("RecMarks", -2)
marks.Image1 = ctrl.Output
expr(marks, "NumberIn3", "RecCtrl.RecCorners")
expr(marks, "NumberIn4", "RecCtrl.RecCross")
expr(marks, "NumberIn5", "RecCtrl.RecGrid")
L.cx(marks, "Intermediate5", "if(n3 > 0 && i3 - abs(i1) < n3 && i4 - abs(i2) < n3, min(max((n2 - abs(max(abs(i1) - i3, abs(i2) - i4)))*h + 0.5, 0), 1), 0)")
L.cx(marks, "Intermediate6", "if(n4 > 0, max(min(max((n2 - abs(i1))*h + 0.5, 0), 1)*min(max((0.03 - abs(i2))*h + 0.5, 0), 1), min(max((n2 - abs(i2))*h + 0.5, 0), 1)*min(max((0.03 - abs(i1))*h + 0.5, 0), 1)), 0)")
L.cx(marks, "Intermediate7", "n5*if(abs(i1) < i3 && abs(i2) < i4, min(max((n2*0.6 - min(abs(abs(i1) - i3/3), abs(abs(i2) - i4/3)))*h + 0.5, 0), 1), 0)")
for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(marks, c .. "Expression", "max(max(i5, i6), i7)") end

-- battery at the top right (an outline, the charge inside it, a nub on its right) and the REC dot at the top left
local draw = frame("RecDraw", -1)
draw.Image1 = marks.Output; draw.Image2 = c1.Output; draw.Image3 = c2.Output
expr(draw, "NumberIn6", "iif(RecCtrl.RecBattery == 1, RecCtrl.RecLevel, -1)")
expr(draw, "NumberIn7", "iif(RecCtrl.RecDot == 1 and (RecCtrl.RecBlink <= 0 or (RecCtrl.Sec/RecCtrl.RecBlink) % 1 < 0.6), 1, 0)")
expr(draw, "NumberIn8", "RecCtrl.RecSize")
local BX = string.format("(i1 - (i3 - %g - n8*1.1))", INSET)
local BY = string.format("(i2 - (i4 - %g))", ROW)
L.cx(draw, "Intermediate5", string.format("if(n6 < 0, 0, min(max((n2 - abs(max(abs(%s) - n8*1.1, abs(%s) - n8*0.55)))*h + 0.5, 0), 1))", BX, BY))
L.cx(draw, "Intermediate6", string.format("if(n6 >= 0 && %s + n8*0.85 < n8*1.7*n6, min(max((n8*0.85 - abs(%s))*h + 0.5, 0), 1)*min(max((n8*0.3 - abs(%s))*h + 0.5, 0), 1), 0)", BX, BX, BY))
L.cx(draw, "Intermediate7", string.format("if(n6 < 0, 0, min(max((n8*0.12 - abs(%s - n8*1.25))*h + 0.5, 0), 1)*min(max((n8*0.25 - abs(%s))*h + 0.5, 0), 1))", BX, BY))
L.cx(draw, "Intermediate8", string.format("n7*min(max((n8*0.42 - sqrt((i1 + i3 - %g - n8*0.42)^2 + (i2 - (i4 - %g))^2))*h + 0.5, 0), 1)", INSET, ROW))
local WHITE = "max(max(a1, i5), max(i6, i7))*(1 - i8)"
for _, c in ipairs({"r", "g", "b"}) do
  L.cx(draw, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", string.format("get%s2b(0.5, 0.5)*%s + get%s3b(0.5, 0.5)*i8", c, WHITE, c))
end
L.cx(draw, "AlphaExpression", WHITE .. " + i8")

-- the three texts. x positions are worked out the same way as in RecDraw, then turned into 0..1 across the frame.
local function words(name, y, text, xexpr, align, row)
  local t = add("TextPlus", name, -3, y)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("Font", "Consolas"); t:SetInput("Style", "Bold")
  expr(t, "StyledText", text)
  expr(t, "Size", "RecCtrl.RecSize")
  t:SetInput("HorizontalLeftCenterRight", align)
  expr(t, "Center", string.format("Point(0.5 + (%s)/%s, 0.5 + (%s)*(0.5 - RecCtrl.RecMargin - %g))", xexpr, ASP, row, ROW))
  for _, ch in ipairs({"Red", "Green", "Blue"}) do expr(t, ch .. "1", "ColRec.TopLeft" .. ch) end
  return t
end
local LEFT = string.format("-(0.5*%s - RecCtrl.RecMargin - %g)", ASP, INSET)
local rec = words("RecWordText", 2, "Text(RecCtrl.RecWord.Value)", LEFT .. " + iif(RecCtrl.RecDot == 1, RecCtrl.RecSize*1.15, 0)", -1, "1")
local info = words("RecInfoText", 3, "Text(RecCtrl.RecInfo.Value)", LEFT, -1, "-1")
local tc = words("RecTimeText", 4, [[Text((function(on, s, fps)
  if on ~= 1 then return "" end
  local f = math.floor((s % 1)*fps + 0.001)
  s = math.floor(s)
  return string.format("%02d:%02d:%02d:%02d", math.floor(s/3600), math.floor(s/60) % 60, s % 60, f)
end)(RecCtrl.RecTime, RecCtrl.Sec + RecCtrl.RecStart, ]] .. "iif(RecCtrl.FpsOverride > 0, RecCtrl.FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)))",
  "-(" .. LEFT .. ")", 1, "-1")

for _, t in ipairs({info, tc}) do expr(t, "Font", "RecWordText.Font"); expr(t, "Style", "RecWordText.Style") end
local last = draw
for i, t in ipairs({rec, info, tc}) do
  local m = add("Merge", "RecOver" .. i, i, 0)
  m.Background = last.Output; m.Foreground = t.Output
  last = m
end
local out = add("Merge", "RecFinal", 5, 0)
out.Background = ctrl.Output; out.Foreground = last.Output
expr(out, "Blend", "RecCtrl.RecOpacity")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "RecWordText", "Font", "Font", "2"}
spec[#spec + 1] = {"CTL", "RecWordText", "Style", "", "2"}
for i, hd in ipairs({{"ColRec", "Colour"}, {"ColRecDot", "REC Dot Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "recframe", name = "RecFrame", out = out, ctrl = ctrl, spec = spec, prefix = "rf"})
