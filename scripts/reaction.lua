-- Reaction Mark: the little drawn symbols variety shows put next to a face. An anger mark, a sweat drop,
-- a question mark, an exclamation mark, or focus lines around a spot. All drawn by the template, no image files.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Reaction Mark")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- per type: fill, inner outline, outer outline
local TYPES = {
  {"Anger",        {0.95,0.10,0.10, 1,1,1, 0.30,0.00,0.00}},
  {"Sweat Drop",   {0.55,0.85,1.00, 1,1,1, 0.05,0.25,0.50}},
  {"Question",     {1.00,0.88,0.15, 1,1,1, 0.10,0.08,0.02}},
  {"Exclamation",  {1.00,0.25,0.15, 1,1,1, 0.10,0.02,0.02}},
  {"Focus Lines",  {0.00,0.00,0.00, 1,1,1, 0.00,0.00,0.00}},
}
local names, rows = {}, {}
for _, t in ipairs(TYPES) do names[#names + 1] = t[1]; rows[#rows + 1] = "{" .. table.concat(t[2], ",") .. "}" end
local TABLE = "({" .. table.concat(rows, ",") .. "})"
local function col(k)
  local own = "MarkCtrl.MarkType + 1"
  if k > 6 then return string.format("%s[%s][%d]", TABLE, own, k) end
  local hold = (k <= 3 and "ColMark" or "ColMarkEdge") .. ".TopLeft" .. ({"Red", "Green", "Blue"})[(k - 1) % 3 + 1]
  return string.format("iif(MarkCtrl.MarkCustom > 0, %s, %s[%s][%d])", hold, TABLE, own, k)
end

local ctrl = add("Background", "MarkCtrl", -6, -3)
ctrl.UserControls = {
  MarkType  = L.combo("Mark", names, 0),
  MarkPos   = L.point("Position", nil, true),
  MarkSize  = L.num("Size", 0.09, 0.01, 0.5),
  MarkAngle = L.num("Angle", 12, -180, 180),
  MarkEdge  = L.num("Outline", 0.004, 0, 0.02),
  MarkEdgeB = L.num("Outer Outline", 0.002, 0, 0.02),
  MarkCustom = L.check("Use My Colours", 0),
  MarkIn    = L.num("Pop Frames", 6, 1, 40),
  MarkPulse = L.num("Throb", 1, 0, 4),
  MarkOut   = L.num("Fade Out Frames", 3, 0, 40),
  MarkCount = L.num("Focus Lines: Count", 70, 8, 200, nil, true),
  MarkHole  = L.num("Focus Lines: Clear Area", 1.6, 0.2, 6),
  MarkWidth = L.num("Focus Lines: Thickness", 0.55, 0.05, 1),
  MarkFlick = L.num("Focus Lines: Frames Per Change", 3, 1, 30, nil, true),
  T     = L.num("T", 0, 0, 1, "Driver"),
  Scale = L.num("Scale", 1, 0, 3, "Driver"),
  Fade  = L.num("Fade", 0, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("MarkPos", {0.68, 0.72})
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "T", "min(max((time - comp.RenderStart + 1)/max(MarkIn, 1), 0), 1)")
-- pops in with an overshoot, then keeps throbbing. Focus lines stay the same size.
expr(ctrl, "Scale", "iif(MarkType == 4, 1, (function(t) t = t - 1 return 1 + 2.70158*t*t*t + 1.70158*t*t end)(T) * (1 + 0.07*MarkPulse*sin(time*0.9)))")
expr(ctrl, "Fade", "min(T*4, 1) * iif(MarkOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/MarkOut, 0), 1))")

local shape = add("Custom", "MarkShape", -3, 0)
shape.Image1 = ctrl.Output
expr(shape, "PointIn1", "MarkCtrl.MarkPos")
expr(shape, "NumberIn1", "MarkCtrl.MarkType")
expr(shape, "NumberIn2", "MarkCtrl.MarkSize")
expr(shape, "NumberIn3", "floor(time/max(MarkCtrl.MarkFlick, 1))")
expr(shape, "NumberIn4", "MarkCtrl.MarkCount")
expr(shape, "NumberIn5", "MarkCtrl.MarkHole")
expr(shape, "NumberIn6", "MarkCtrl.MarkWidth")
expr(shape, "NumberIn7", "iif(MarkCtrl.MarkType == 4, 0, MarkCtrl.MarkAngle)")
expr(shape, "NumberIn8", "max(MarkCtrl.Scale, 0.001)")
-- i1, i2: this pixel seen from the mark, turned by Angle, in units of Size
shape:SetInput("Intermediate1", "((x - p1x)*w/h*cos(n7) + (y - p1y)*sin(n7))/(n2*n8)")
shape:SetInput("Intermediate2", "((y - p1y)*cos(n7) - (x - p1x)*w/h*sin(n7))/(n2*n8)")
-- anger mark: four arcs, one in each quadrant, each a piece of a ring centred further out on the diagonal
shape:SetInput("Intermediate3", "sqrt((abs(i1) - 1)*(abs(i1) - 1) + (abs(i2) - 1)*(abs(i2) - 1))")
-- sweat drop: a ball with a pointed top. i4 runs 0..1 from the middle of the ball to the tip.
shape:SetInput("Intermediate4", "(i2 + 0.3)/1.3")
-- focus lines: i5 which wedge around the centre, i6 a random number for that wedge, i7 distance from the centre
shape:SetInput("Intermediate5", "atan2(i2, i1)/360*n4 + n4")
shape:SetInput("Intermediate6", "abs(frac(sin(floor(i5)*744.3 + n3*91.7)*43758.5453))")
shape:SetInput("Intermediate7", "sqrt(i1*i1 + i2*i2)")
-- i8: pixels per unit, to soften edges by one pixel
shape:SetInput("Intermediate8", "n2*n8*h")
local anger = "if(abs(i1) < 0.9 && abs(i2) < 0.9, min(max((0.08 - abs(i3 - 0.8))*i8 + 0.5, 0), 1), 0)"
local sweat = "if(i4 < 0, min(max((0.55 - sqrt(i1*i1 + (i2 + 0.3)*(i2 + 0.3)))*i8 + 0.5, 0), 1), if(i4 <= 1, min(max((0.55*(1 - i4*i4) - abs(i1))*i8 + 0.5, 0), 1), 0))"
local focus = "if(frac(i6*7.13) > 0.25 && i7 > n5*(1 + 0.6*i6), min(max((0.5*n6*min((i7 - n5*(1 + 0.6*i6))/2, 1) - abs(frac(i5) - 0.5))*30 + 0.5, 0), 1), 0)"
local A = string.format("if(n1 == 0, %s, if(n1 == 1, %s, if(n1 == 4, %s, 0)))", anger, sweat, focus)
shape:SetInput("RedExpression", A); shape:SetInput("GreenExpression", A)
shape:SetInput("BlueExpression", A); shape:SetInput("AlphaExpression", A)

-- the question and exclamation marks are letters
local glyph = add("TextPlus", "MarkGlyph", -3, 1)
glyph:SetInput("UseFrameFormatSettings", 1)
glyph:SetInput("Font", "Arial"); glyph:SetInput("Style", "Bold")
expr(glyph, "StyledText", "Text(iif(MarkCtrl.MarkType == 2, '?', iif(MarkCtrl.MarkType == 3, '!', '')))")
expr(glyph, "Size", "3.6*MarkCtrl.MarkSize*MarkCtrl.Scale*comp:GetPrefs('Comp.FrameFormat.Height')/comp:GetPrefs('Comp.FrameFormat.Width')")
expr(glyph, "Center", "MarkCtrl.MarkPos")
expr(glyph, "AngleZ", "-MarkCtrl.MarkAngle")
local matte = add("Merge", "MarkMatte", -1, 0)
matte.Background = shape.Output; matte.Foreground = glyph.Output

local c1 = add("Background", "ColMark", -3, -5)
local c2 = add("Background", "ColMarkEdge", -2, -5)
for _, h in ipairs({c1, c2}) do h:SetInput("UseFrameFormatSettings", 0); h:SetInput("Width", 16); h:SetInput("Height", 16) end
L.color(c1, 0.95, 0.10, 0.10, 1); L.color(c2, 1, 1, 1, 1)
local cols = {}
for k = 1, 9 do cols[k] = col(k) end
local painted = L.inked(comp, "MarkPaint", 0, 0, matte.Output,
  "iif(MarkCtrl.MarkType == 4, 0, MarkCtrl.MarkEdge)", "iif(MarkCtrl.MarkType == 4, 0, MarkCtrl.MarkEdgeB)", cols)
local out = add("Merge", "MarkOut", 3, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "MarkCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "reaction", {
    {"NAME", "ReactionMark"},
    {"OUT", "MarkOut", "Output"},
    {"CTL", "MarkCtrl", "MarkType", "Mark"},
    {"CTL", "MarkCtrl", "MarkPos", "Position"},
    {"CTL", "MarkCtrl", "MarkSize", "Size"},
    {"CTL", "MarkCtrl", "MarkAngle", "Angle"},
    {"CTL", "MarkCtrl", "MarkIn", "Pop Frames"},
    {"CTL", "MarkCtrl", "MarkPulse", "Throb"},
    {"CTL", "MarkCtrl", "MarkOut", "Fade Out Frames"},
    {"CTL", "MarkCtrl", "MarkEdge", "Outline"},
    {"CTL", "MarkCtrl", "MarkEdgeB", "Outer Outline"},
    {"CTL", "MarkCtrl", "MarkCustom", "Use My Colours"},
    {"CTL", "ColMark", "TopLeftRed", "My Color", "3"}, {"CTL", "ColMark", "TopLeftGreen", "", "3"}, {"CTL", "ColMark", "TopLeftBlue", "", "3"},
    {"CTL", "ColMarkEdge", "TopLeftRed", "My Outline Color", "4"}, {"CTL", "ColMarkEdge", "TopLeftGreen", "", "4"}, {"CTL", "ColMarkEdge", "TopLeftBlue", "", "4"},
    {"CTL", "MarkCtrl", "MarkCount", "Focus Lines: Count"},
    {"CTL", "MarkCtrl", "MarkHole", "Focus Lines: Clear Area"},
    {"CTL", "MarkCtrl", "MarkWidth", "Focus Lines: Thickness"},
    {"CTL", "MarkCtrl", "MarkFlick", "Focus Lines: Frames Per Change"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local pos = os.getenv("FX_POS")
  if pos then local a, b = pos:match("([%d%.]+),([%d%.]+)"); ctrl:SetInput("MarkPos", {tonumber(a), tonumber(b)}) end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 5, 2)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "rm", tonumber(os.getenv("FX_STEPS") or "12"))
end
