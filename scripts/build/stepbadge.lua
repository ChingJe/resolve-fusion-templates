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
  {"BdgLabelSize", L.num("Text Size", 0.05, 0.01, 0.2)},
  {"BdgGap",    L.num("Text Distance", 0.025, 0, 0.2)},
  {"BdgTagH",   L.num("Capsule Height", 0.78, 0.2, 1.2)},
  {"BdgTagOp",  L.num("Capsule Opacity", 0.8, 0, 1)},
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
-- the capsule with the text slides out from behind the badge once the badge is there
expr(ctrl, "Late", "(function(t) return 1 - (1 - t)^3 end)(min(max(T*2 - 1, 0), 1))")

local holders = {{"ColBdg", {0.93, 0.22, 0.18}}, {"ColBdgBorder", {1, 1, 1}}, {"ColBdgNumber", {1, 1, 1}},
                 {"ColBdgLabel", {1, 1, 1}}, {"ColBdgTag", {0.07, 0.07, 0.1}}}
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
for _, ch in ipairs({"Red", "Green", "Blue"}) do expr(label, ch .. "1", "ColBdgLabel.TopLeft" .. ch) end

-- The capsule: a bar with round ends that starts behind the badge and reaches just past the end of the text.
-- It grows out to its full length, and the text only shows where the capsule already is.
local tag = add("Custom", "BdgTag", -2, 5)
tag.Image1 = ctrl.Output; tag.Image2 = label.Output
expr(tag, "PointIn1", "BdgCtrl.BdgPos")
expr(tag, "PointIn2", "Point(ColBdgTag.TopLeftRed, ColBdgTag.TopLeftGreen)")
expr(tag, "PointIn3", "Point(ColBdgTag.TopLeftBlue, BdgCtrl.BdgTagOp)")
expr(tag, "NumberIn1", "BdgCtrl.BdgSize/2*BdgCtrl.BdgTagH")
-- how long its straight part is: nothing without text, otherwise from the middle of the badge to just before
-- the end of the text (the round end adds the rest)
expr(tag, "NumberIn2", [[(function(late)
  local d = BdgLabelText.StyledText.Value ~= "" and BdgLabelText.Output.DataWindow
  if not d then return 0 end
  local wide = (d.right - d.left)/BdgLabelText.Output.Width/]] .. HW .. [[

  return late*(BdgCtrl.BdgSize/2 + BdgCtrl.BdgBorder + BdgCtrl.BdgGap + wide - BdgCtrl.BdgSize/2*BdgCtrl.BdgTagH*0.35)
end)(BdgCtrl.Late)]])
expr(tag, "NumberIn3", "iif(BdgCtrl.BdgSide == 0, 1, -1)")
L.cx(tag, "Intermediate1", "(x - p1x)*w/h*n3")
L.cx(tag, "Intermediate2", "if(n2 <= 0, 0, min(max((n1 - sqrt((i1 - min(max(i1, 0), n2))^2 + (y - p1y)^2))*h + 0.5, 0), 1))")
L.cx(tag, "Intermediate3", "a2*i2")
L.cx(tag, "RedExpression", "r2*i2 + p2x*p3y*i2*(1 - i3)")
L.cx(tag, "GreenExpression", "g2*i2 + p2y*p3y*i2*(1 - i3)")
L.cx(tag, "BlueExpression", "b2*i2 + p3x*p3y*i2*(1 - i3)")
L.cx(tag, "AlphaExpression", "i3 + p3y*i2*(1 - i3)")

local m0 = add("Merge", "BdgOverTag", 0, 0)
m0.Background = tag.Output; m0.Foreground = badge.Output
local m2 = add("Merge", "BdgWithNumber", 1, 0)
m2.Background = m0.Output; m2.Foreground = num.Output
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
                     {"ColBdgLabel", "Text Colour"}, {"ColBdgTag", "Capsule Colour"}}) do
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
