-- Text Label: a line of text on a frame that always fits it. A general building block: pick a frame shape,
-- a colour set and an entrance, then stack several of them on different tracks to build bigger graphics.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the text from a UTF-8 file, FX_POS="0.5,0.5" moves it.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Text Label")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local SHAPES = {"Rectangle", "Rounded", "Pill", "Slanted", "Ribbon", "Underline", "Corner Marks", "Speech Bubble", "No Frame"}
-- text, text outline, frame fill, frame border, shadow
local PRESETS = {
  {"White On Red",    {1.00,1.00,1.00, 0.45,0.00,0.05, 0.86,0.10,0.16, 1.00,1.00,1.00, 0.25,0.02,0.05}},
  {"Black On Yellow", {0.10,0.08,0.02, 1.00,1.00,1.00, 1.00,0.86,0.12, 0.10,0.08,0.02, 0.10,0.08,0.02}},
  {"White On Black",  {1.00,1.00,1.00, 0.00,0.00,0.00, 0.06,0.06,0.08, 1.00,1.00,1.00, 0.00,0.00,0.00}},
  {"Black On White",  {0.08,0.08,0.10, 1.00,1.00,1.00, 1.00,1.00,1.00, 0.08,0.08,0.10, 0.08,0.08,0.10}},
  {"White On Blue",   {1.00,1.00,1.00, 0.02,0.10,0.40, 0.10,0.36,0.90, 1.00,1.00,1.00, 0.03,0.10,0.35}},
  {"White On Pink",   {1.00,1.00,1.00, 0.50,0.05,0.25, 0.95,0.30,0.60, 1.00,1.00,1.00, 0.45,0.05,0.25}},
  {"White On Green",  {1.00,1.00,1.00, 0.02,0.25,0.10, 0.10,0.60,0.30, 1.00,1.00,1.00, 0.03,0.25,0.12}},
  {"Yellow On Purple",{1.00,0.92,0.25, 0.20,0.02,0.30, 0.42,0.16,0.70, 1.00,0.92,0.25, 0.15,0.03,0.30}},
}
local names, rows = {"Custom"}, {}
for _, p in ipairs(PRESETS) do names[#names + 1] = p[1]; rows[#rows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
local TABLE = "({" .. table.concat(rows, ",") .. "})"
local HOLD = {"ColLblText", "ColLblTextEdge", "ColLblFill", "ColLblBorder", "ColLblShadow"}
local function col(k, c)
  local ch = ({"Red", "Green", "Blue"})[c]
  return string.format("iif(LblCtrl.LblPreset == 0, %s.TopLeft%s, %s[max(LblCtrl.LblPreset, 1)][%d])", HOLD[k], ch, TABLE, (k - 1)*3 + c)
end

local ctrl = add("Background", "LblCtrl", -6, -3)
ctrl.UserControls = {
  LblText   = L.text("Text", "本集主題", nil, 3),
  LblSize   = L.num("Size", 0.05, 0.01, 0.3),
  LblPos    = L.point("Position", nil, true),
  LblAnchor = L.combo("Position Is The", {"Left Edge", "Middle", "Right Edge"}, 1),
  LblTilt   = L.num("Tilt", 0, -45, 45),
  LblShape  = L.combo("Frame", SHAPES, 1),
  LblPadX   = L.num("Frame Padding X", 0.45, 0, 2),
  LblPadY   = L.num("Frame Padding Y", 0.3, 0, 2),
  LblRound  = L.num("Roundness", 0.4, 0, 1),
  LblSlant  = L.num("Slant", 0.3, -1, 1),
  LblPreset = L.combo("Colours", names, 1),
  LblFillOp = L.num("Frame Opacity", 1, 0, 1),
  LblBorder = L.num("Border", 0.004, 0, 0.03),
  LblTextEdge = L.num("Text Outline", 0, 0, 0.02),
  LblShadowX = L.num("Shadow X", 0.007, -0.05, 0.05),
  LblShadowY = L.num("Shadow Y", -0.007, -0.05, 0.05),
  LblShadowOp = L.num("Shadow Opacity", 1, 0, 1),
  LblEnter  = L.combo("Entrance", {"None", "Pop", "From Left", "From Right", "From Below", "From Above", "Wipe"}, 1),
  LblIn     = L.num("Entrance Frames", 8, 1, 60),
  LblDist   = L.num("Slide Distance", 0.15, 0, 1),
  LblLeave  = L.check("Leave The Same Way At The End", 0),
  LblOut    = L.num("Leave Frames", 8, 1, 60),
  Show = L.num("Show", 0, 0, 1, "Driver"),
  Half = L.point("Half", "Driver"), Ctr = L.point("Ctr", "Driver"),
  Move = L.point("Move", "Driver"),
  Scale = L.num("Scale", 1, 0, 3, "Driver"),
  Fade = L.num("Fade", 1, 0, 1, "Driver"),
  Wipe = L.num("Wipe", 1, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("LblPos", {0.5, 0.5})
L.color(ctrl, 0, 0, 0, 0)
local ASPECT = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"

-- Show: 0 when away, 1 when in place
expr(ctrl, "Show", [[min(min(max((time - comp.RenderStart + 1)/max(LblIn, 1), 0), 1),
  iif(LblLeave > 0, min(max((comp.RenderEnd - time + 1)/max(LblOut, 1), 0), 1), 1))]])
expr(ctrl, "Scale", "iif(LblEnter == 1, (function(t) t = t - 1 return 1 + 2.70158*t*t*t + 1.70158*t*t end)(Show), 1)")
expr(ctrl, "Move", [[(function(e, d)
  local u = 1 - Show
  u = u*u*u*d
  if e == 2 then return Point(-u, 0) elseif e == 3 then return Point(u, 0)
  elseif e == 4 then return Point(0, -u) elseif e == 5 then return Point(0, u) end
  return Point(0, 0)
end)(LblEnter, LblDist)]])
expr(ctrl, "Fade", "iif(LblEnter >= 1 and LblEnter <= 5, min(Show*3, 1), 1)")
expr(ctrl, "Wipe", "iif(LblEnter == 6, (function(t) return t*t*(3 - 2*t) end)(Show), 1)")

-- the words, rendered in the middle of the frame so they can be measured, then moved into place
local words = add("TextPlus", "LblWords", -4, 0)
words:SetInput("UseFrameFormatSettings", 1)
words:SetInput("Font", "Microsoft JhengHei"); words:SetInput("Style", "Bold")
expr(words, "StyledText", "Text(LblCtrl.LblText.Value)")
expr(words, "Size", "LblCtrl.LblSize")

-- Half: half the width and height of the frame, in units of the picture height.
-- One line of text always gets the same height whatever the letters are, so labels line up when stacked.
expr(ctrl, "Half", string.format([[(function()
  local asp = %s
  local tw, th = 0, 0
  local d = LblWords.StyledText.Value ~= "" and LblWords.Output.DataWindow
  if d then tw, th = (d.right - d.left)/LblWords.Output.Height, (d.top - d.bottom)/LblWords.Output.Height end
  th = math.max(th, LblSize*asp*0.6)
  return Point(tw/2 + LblPadX*LblSize*asp, th/2 + LblPadY*LblSize*asp)
end)()]], ASPECT))
expr(ctrl, "Ctr", "Point(LblPos.X - (LblAnchor - 1)*Half.X/" .. ASPECT .. ", LblPos.Y)")

local put = add("Merge", "LblPut", -2, 0)
put.Background = ctrl.Output; put.Foreground = words.Output
expr(put, "Center", "LblCtrl.Ctr")

for i, name in ipairs(HOLD) do
  local h = add("Background", name, -6 + i, -5)
  h:SetInput("UseFrameFormatSettings", 0); h:SetInput("Width", 16); h:SetInput("Height", 16)
  local d = PRESETS[1][2]
  L.color(h, d[(i - 1)*3 + 1], d[(i - 1)*3 + 2], d[(i - 1)*3 + 3], 1)
end
local tc = {}
for k = 1, 2 do for c = 1, 3 do tc[#tc + 1] = col(k, c) end end
tc[7], tc[8], tc[9] = "0", "0", "0"
local inked = L.inked(comp, "LblInk", -1, 0, put.Output, "LblCtrl.LblTextEdge", "0", tc)

-- The frame. Red carries the fill, green the border, blue the shadow; LblPaint colours them.
-- Shapes: 0 rectangle, 1 rounded, 2 pill, 3 slanted, 4 ribbon, 5 underline, 6 corner marks, 7 speech bubble, 8 none
local S = "LblCtrl.LblShape"
local draw = add("Custom", "LblDraw", -2, 3)
draw.Image1 = ctrl.Output
expr(draw, "NumberIn1", string.format("iif(%s == 1 or %s == 7, LblCtrl.LblRound*LblCtrl.Half.Y, iif(%s == 2, LblCtrl.Half.Y, 0))", S, S, S))
expr(draw, "NumberIn2", string.format("iif(%s == 3, LblCtrl.LblSlant, 0)", S))
expr(draw, "NumberIn3", "LblCtrl.LblBorder")
expr(draw, "NumberIn4", string.format("iif(%s == 4, 0.7*LblCtrl.Half.Y, 0)", S))
expr(draw, "NumberIn5", string.format("iif(%s == 6, LblCtrl.Half.Y, 0)", S))
expr(draw, "NumberIn6", string.format("iif(%s == 7, 0.9*LblCtrl.Half.Y, 0)", S))
expr(draw, "NumberIn7", string.format("iif(%s == 6 or %s == 8, 0, 1)", S, S))
expr(draw, "NumberIn8", string.format("iif(%s == 5 or %s == 8 or LblCtrl.LblBorder <= 0, 0, 1)", S, S))
-- the underline is a thin bar along the bottom, the ribbon is longer so the notches clear the text
expr(draw, "PointIn1", string.format("iif(%s == 5, Point(LblCtrl.Ctr.X, LblCtrl.Ctr.Y - LblCtrl.Half.Y), LblCtrl.Ctr)", S))
expr(draw, "PointIn2", string.format("iif(%s == 5, Point(LblCtrl.Half.X, 0.07*LblCtrl.LblSize*%s), iif(%s == 4, Point(LblCtrl.Half.X + 0.7*LblCtrl.Half.Y, LblCtrl.Half.Y), LblCtrl.Half))", S, ASPECT, S))
expr(draw, "PointIn3", "Point(LblCtrl.LblShadowX, LblCtrl.LblShadowY)")
expr(draw, "PointIn4", string.format("Point(iif(%s == 6 or %s == 8, 0, 1), 0)", S, S))
-- distance to the edge of the shape, negative inside, for a point (U, V) whose corner offsets are QX, QY
local function dist(U, V, QX, QY)
  local rbox = string.format("(sqrt(max(%s, 0)*max(%s, 0) + max(%s, 0)*max(%s, 0)) + min(max(%s, %s), 0) - n1)", QX, QX, QY, QY, QX, QY)
  local notch = string.format("(abs(%s) - p2x + n4*(1 - abs(%s)/p2y))", U, V)
  local tail = string.format("if(n6 <= 0, 1, max((abs(%s + p2x*0.4) - n6*0.5*(1 + (%s + p2y)/n6))*0.8, %s + p2y - n1 - 0.002))", U, V, V)
  return string.format("min(max(%s, %s), %s)", rbox, notch, tail)
end
draw:SetInput("Intermediate2", "y - p1y")
draw:SetInput("Intermediate1", "(x - p1x)*w/h - n2*(y - p1y)")
draw:SetInput("Intermediate3", "abs(i1) - p2x + n1")
draw:SetInput("Intermediate4", "abs(i2) - p2y + n1")
draw:SetInput("Intermediate5", dist("i1", "i2", "i3", "i4"))
local US, VS = "(i1 - p3x + n2*p3y)", "(i2 - p3y)"
draw:SetInput("Intermediate6", "abs" .. US .. " - p2x + n1")
draw:SetInput("Intermediate7", "abs" .. VS .. " - p2y + n1")
draw:SetInput("Intermediate8", dist(US, VS, "i6", "i7"))
draw:SetInput("RedExpression", "n7*min(max(-i5*h + 0.5, 0), 1)")
draw:SetInput("GreenExpression", "n8*min(max((n3/2 - abs(i5))*h + 0.5, 0), 1)*if(n5 <= 0, 1, if((i1 < n5 - p2x && i2 > p2y - n5) || (i1 > p2x - n5 && i2 < n5 - p2y), 1, 0))")
draw:SetInput("BlueExpression", "p4x*min(max((n3/2*n8 - i8)*h + 0.5, 0), 1)")
draw:SetInput("AlphaExpression", "1")

local paint = add("Custom", "LblPaint", 0, 3)
paint.Image1 = draw.Output
for c = 1, 3 do
  expr(paint, "NumberIn" .. c, col(3, c))
  expr(paint, "NumberIn" .. (c + 3), col(4, c))
end
expr(paint, "PointIn1", "Point(" .. col(5, 1) .. ", " .. col(5, 2) .. ")")
expr(paint, "PointIn2", "Point(" .. col(5, 3) .. ", 0)")
expr(paint, "NumberIn7", "LblCtrl.LblFillOp")
expr(paint, "NumberIn8", "LblCtrl.LblShadowOp")
-- i1 fill, i2 shadow where the fill does not cover it, i3 everything under the border
paint:SetInput("Intermediate1", "r1*n7")
paint:SetInput("Intermediate2", "b1*n8*(1 - r1*n7)")
paint:SetInput("RedExpression",   "n4*g1 + (1 - g1)*(n1*i1 + p1x*i2)")
paint:SetInput("GreenExpression", "n5*g1 + (1 - g1)*(n2*i1 + p1y*i2)")
paint:SetInput("BlueExpression",  "n6*g1 + (1 - g1)*(n3*i1 + p2x*i2)")
paint:SetInput("AlphaExpression", "g1 + (1 - g1)*(i1 + i2)")

local both = add("Merge", "LblBoth", 2, 1)
both.Background = paint.Output; both.Foreground = inked.Output
local move = add("Transform", "LblMove", 3, 1)
move.Input = both.Output
expr(move, "Pivot", "LblCtrl.Ctr")
expr(move, "Center", "Point(0.5 + LblCtrl.Move.X, 0.5 + LblCtrl.Move.Y)")
expr(move, "Size", "max(LblCtrl.Scale, 0.001)")
expr(move, "Angle", "LblCtrl.LblTilt")
-- the wipe uncovers the label from its left end to its right end
local wipe = add("Custom", "LblWipe", 4, 1)
wipe.Image1 = move.Output
expr(wipe, "NumberIn1", "LblCtrl.Wipe")
expr(wipe, "PointIn1", string.format("Point(LblCtrl.Ctr.X - (LblCtrl.Half.X*1.2 + LblCtrl.Half.Y + 0.06)/%s, LblCtrl.Ctr.X + (LblCtrl.Half.X*1.2 + LblCtrl.Half.Y + 0.06)/%s)", ASPECT, ASPECT))
wipe:SetInput("Intermediate1", "if(n1 >= 1, 1, if(x < p1x + (p1y - p1x)*n1, 1, 0))")
wipe:SetInput("RedExpression", "r1*i1"); wipe:SetInput("GreenExpression", "g1*i1")
wipe:SetInput("BlueExpression", "b1*i1"); wipe:SetInput("AlphaExpression", "a1*i1")
local out = add("Merge", "LblFinal", 5, 1)
out.Background = ctrl.Output; out.Foreground = wipe.Output
expr(out, "Blend", "LblCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  local spec = {
    {"NAME", "TextLabel"},
    {"OUT", "LblFinal", "Output"},
    {"CTL", "LblCtrl", "LblText", "Text"},
    {"CTL", "LblWords", "Font", "Font", "2"}, {"CTL", "LblWords", "Style", "", "2"},
    {"CTL", "LblCtrl", "LblSize", "Size"},
    {"CTL", "LblCtrl", "LblPos", "Position"},
    {"CTL", "LblCtrl", "LblAnchor", "Position Is The"},
    {"CTL", "LblCtrl", "LblTilt", "Tilt"},
    {"CTL", "LblCtrl", "LblShape", "Frame"},
    {"CTL", "LblCtrl", "LblPadX", "Frame Padding X"},
    {"CTL", "LblCtrl", "LblPadY", "Frame Padding Y"},
    {"CTL", "LblCtrl", "LblRound", "Roundness"},
    {"CTL", "LblCtrl", "LblSlant", "Slant"},
    {"CTL", "LblCtrl", "LblBorder", "Border"},
    {"CTL", "LblCtrl", "LblFillOp", "Frame Opacity"},
    {"CTL", "LblCtrl", "LblTextEdge", "Text Outline"},
    {"CTL", "LblCtrl", "LblShadowX", "Shadow X"},
    {"CTL", "LblCtrl", "LblShadowY", "Shadow Y"},
    {"CTL", "LblCtrl", "LblShadowOp", "Shadow Opacity"},
    {"CTL", "LblCtrl", "LblEnter", "Entrance"},
    {"CTL", "LblCtrl", "LblIn", "Entrance Frames"},
    {"CTL", "LblCtrl", "LblDist", "Slide Distance"},
    {"CTL", "LblCtrl", "LblLeave", "Leave The Same Way At The End"},
    {"CTL", "LblCtrl", "LblOut", "Leave Frames"},
    {"CTL", "LblCtrl", "LblPreset", "Colours"},
  }
  local labels = {"Custom Text", "Custom Text Outline", "Custom Frame", "Custom Border", "Custom Shadow"}
  for i, name in ipairs(HOLD) do
    local g = tostring(10 + i)
    spec[#spec + 1] = {"CTL", name, "TopLeftRed", labels[i], g}
    spec[#spec + 1] = {"CTL", name, "TopLeftGreen", "", g}
    spec[#spec + 1] = {"CTL", name, "TopLeftBlue", "", g}
  end
  L.export(comp, "textlabel", spec)
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("LblText", file:read("*a")); file:close() end
  local pos = os.getenv("FX_POS")
  if pos then local a, b = pos:match("([%d%.]+),([%d%.]+)"); ctrl:SetInput("LblPos", {tonumber(a), tonumber(b)}) end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 6, 3)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  local hf = ctrl:GetInput("Half", 30)
  print("half", hf and hf[1], hf and hf[2])
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "tl", tonumber(os.getenv("FX_STEPS") or "12"))
end
