-- Step Badge: a round badge with a number (or a letter, or a few characters) that pops up at a spot, with an
-- optional line of text next to it. For numbering the steps of a tutorial or the parts of a picture.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source. FX_TEXT sets the number for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Step Badge")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "BdgCtrl", {
  {"BdgText",   L.text("Number", "1")},
  {"BdgLabel",  L.text("Text Beside It (may be empty)", "")},
  {"BdgPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"BdgSize",   L.num("Size", 0.12, 0.02, 0.6)},
  {"BdgShape",  L.combo("Shape", {"Circle", "Rounded Square", "Square"}, 0)},
  {"BdgBorder", L.num("Border Width", 0.006, 0, 0.03)},
  {"BdgSide",   L.combo("Text Is On The", {"Right", "Left"}, 0)},
  {"BdgLabelSize", L.num("Text Size", 0.045, 0.01, 0.2)},
  {"BdgGap",    L.num("Text Distance", 0.02, 0, 0.2)},
  {"BdgEdge",   L.num("Text Outline", 0.004, 0, 0.02)},
  {"BdgEnter",  L.combo("Appears By", {"Popping Up", "Fading In"}, 0)},
  {"BdgIn",     L.num("Appear (seconds)", 0.3, 0, 3)},
  {"BdgOut",    L.num("Fade Out (seconds)", 0.2, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"T",     L.num("T", 0, 0, 1, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Fade",  L.num("Fade", 0, 0, 1, "Driver")},
  {"Late",  L.num("Late", 0, 0, 1, "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
local HW = "(comp:GetPrefs('Comp.FrameFormat.Height')/comp:GetPrefs('Comp.FrameFormat.Width'))"
expr(ctrl, "T", "iif(BdgIn <= 0, 1, min(max((time - comp.RenderStart + 1)/(BdgIn*" .. FPS .. "), 0), 1))")
-- pops in with an overshoot
expr(ctrl, "Scale", "iif(BdgEnter == 0, (function(t) t = t - 1 return 1 + 2.70158*t*t*t + 1.70158*t*t end)(T), 1)")
expr(ctrl, "Fade", "iif(BdgEnter == 0, min(T*4, 1), T) * iif(BdgOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/(BdgOut*" .. FPS .. "), 0), 1))")
-- the text beside it comes in a little after the badge
expr(ctrl, "Late", "min(max(T*2.5 - 1.5, 0), 1)")

local holders = {{"ColBdg", {0.93, 0.22, 0.18}}, {"ColBdgBorder", {1, 1, 1}}, {"ColBdgNumber", {1, 1, 1}},
                 {"ColBdgLabel", {1, 1, 1}}, {"ColBdgLabelEdge", {0.05, 0.05, 0.08}}}
for i, hd in ipairs(holders) do
  local b = add("Background", hd[1], -5 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, hd[2][1], hd[2][2], hd[2][3], 1)
end
local function cols(fill, edge)
  local c = {}
  for i, ch in ipairs({"Red", "Green", "Blue"}) do
    c[i] = fill .. ".TopLeft" .. ch; c[i + 3] = edge .. ".TopLeft" .. ch; c[i + 6] = "0"
  end
  return c
end

local plate = add("Custom", "BdgPlate", -3, 0)
plate.Image1 = ctrl.Output
expr(plate, "PointIn1", "BdgCtrl.BdgPos")
expr(plate, "NumberIn1", "max(BdgCtrl.BdgSize/2*BdgCtrl.Scale, 0.0005)")
expr(plate, "NumberIn2", "({1, 0.3, 0})[BdgCtrl.BdgShape + 1]")
L.cx(plate, "Intermediate1", "abs((x - p1x)*w/h) - n1*(1 - n2)")
L.cx(plate, "Intermediate2", "abs(y - p1y) - n1*(1 - n2)")
L.cx(plate, "Intermediate3", "min(max(0.5 - (sqrt(max(i1, 0)^2 + max(i2, 0)^2) + min(max(i1, i2), 0) - n1*n2)*h, 0), 1)")
for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(plate, c .. "Expression", "i3") end
local badge = L.inked(comp, "BdgPaint", -2, 0, plate.Output, "BdgCtrl.BdgBorder", "0", cols("ColBdg", "ColBdgBorder"))

local num = add("TextPlus", "BdgNumber", -3, 3)
num:SetInput("UseFrameFormatSettings", 1)
num:SetInput("Font", "Arial"); num:SetInput("Style", "Bold")
expr(num, "StyledText", "Text(BdgCtrl.BdgText.Value)")
expr(num, "Center", "BdgCtrl.BdgPos")
-- more than one character: smaller, so that it still fits
expr(num, "Size", "0.95*BdgCtrl.BdgSize*BdgCtrl.Scale*" .. HW .. "/math.max(1, 0.62*#BdgCtrl.BdgText.Value)")
for _, ch in ipairs({"Red", "Green", "Blue"}) do expr(num, ch .. "1", "ColBdgNumber.TopLeft" .. ch) end

local label = add("TextPlus", "BdgLabelText", -3, 5)
label:SetInput("UseFrameFormatSettings", 1)
label:SetInput("Font", "Microsoft JhengHei"); label:SetInput("Style", "Bold")
expr(label, "StyledText", "Text(BdgCtrl.BdgLabel.Value)")
expr(label, "Size", "BdgCtrl.BdgLabelSize")
expr(label, "HorizontalLeftCenterRight", "iif(BdgCtrl.BdgSide == 0, -1, 1)")
expr(label, "Center", "Point(BdgCtrl.BdgPos.X + iif(BdgCtrl.BdgSide == 0, 1, -1)*(BdgCtrl.BdgSize/2 + BdgCtrl.BdgBorder + BdgCtrl.BdgGap)*" .. HW .. ", BdgCtrl.BdgPos.Y)")
local labelInk = L.inked(comp, "BdgLabelPaint", -2, 5, label.Output, "BdgCtrl.BdgEdge", "0", cols("ColBdgLabel", "ColBdgLabelEdge"))

local m1 = add("Merge", "BdgWithNumber", 1, 0)
m1.Background = badge.Output; m1.Foreground = num.Output
local m2 = add("Merge", "BdgWithLabel", 2, 0)
m2.Background = m1.Output; m2.Foreground = labelInk.Output
expr(m2, "Blend", "BdgCtrl.Late")
local out = add("Merge", "BdgFinal", 4, 0)
out.Background = ctrl.Output; out.Foreground = m2.Output
expr(out, "Blend", "BdgCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 2, {"CTL", "BdgNumber", "Font", "Number Font", "2"})
table.insert(spec, 3, {"CTL", "BdgNumber", "Style", "", "2"})
table.insert(spec, 5, {"CTL", "BdgLabelText", "Font", "Text Font", "3"})
table.insert(spec, 6, {"CTL", "BdgLabelText", "Style", "", "3"})
for i, hd in ipairs({{"ColBdg", "Colour"}, {"ColBdgBorder", "Border Colour"}, {"ColBdgNumber", "Number Colour"},
                     {"ColBdgLabel", "Text Colour"}, {"ColBdgLabelEdge", "Text Outline Colour"}}) do
  local g = tostring(i + 3)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "stepbadge", name = "StepBadge", out = out, ctrl = ctrl, spec = spec, prefix = "sb",
  before = function()
    if os.getenv("FX_TEXT") then ctrl:SetInput("BdgText", os.getenv("FX_TEXT")) end
    local tf = os.getenv("FX_TEXTFILE")
    if tf then local f = io.open(tf, "r"); ctrl:SetInput("BdgLabel", (f:read("*a"):gsub("%s+$", ""))); f:close() end
  end})
