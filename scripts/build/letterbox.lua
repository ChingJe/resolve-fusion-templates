-- Letterbox: cinema bars that slide in from the top and bottom (or from the sides, when the chosen shape is
-- narrower than the frame) and slide out again at the end. Put it on the top track and it covers every clip under it.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Letterbox")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local RATIOS = {{"2.39:1", 2.39}, {"2.35:1", 2.35}, {"2:1", 2}, {"1.85:1", 1.85}, {"4:3", 4/3}, {"1:1", 1}, {"9:16", 9/16}, {"Custom", 0}}
local names, values = {}, {}
for i, r in ipairs(RATIOS) do names[i] = r[1]; values[i] = tostring(r[2]) end
local ctrl, spec = L.panel(comp, "LbxCtrl", {
  {"LbxRatio",   L.combo("Shape", names, 0)},
  {"LbxCustom",  L.num("Custom Shape (width / height)", 2.39, 0.3, 4)},
  {"LbxOffset",  L.num("Move The Opening", 0, -0.3, 0.3)},
  {"LbxOpacity", L.num("Opacity", 1, 0, 1)},
  {"LbxIn",      L.num("Slide In (seconds)", 0.6, 0, 5)},
  {"LbxOut",     L.num("Slide Out (seconds)", 0.6, 0, 5)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"R",   L.num("R", 2.39, 0, 9, "Driver")},
  {"Amt", L.num("Amt", 0, 0, 1, "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
expr(ctrl, "R", "iif(LbxRatio == " .. (#RATIOS - 1) .. ", LbxCustom, ({" .. table.concat(values, ", ") .. "})[LbxRatio + 1])")
expr(ctrl, "Amt", L.SMOOTH .. "(min(iif(LbxIn <= 0, 1, min(max((time - comp.RenderStart)/(LbxIn*" .. FPS .. "), 0), 1)), iif(LbxOut <= 0, 1, min(max((comp.RenderEnd - time)/(LbxOut*" .. FPS .. "), 0), 1))))")

local col = add("Background", "ColLetterbox", -3, -5)
col:SetInput("UseFrameFormatSettings", 0); col:SetInput("Width", 16); col:SetInput("Height", 16)
L.color(col, 0, 0, 0, 1)

local bars = add("Custom", "LbxFinal", 0, 0)
bars.Image1 = ctrl.Output; bars.Image2 = col.Output
expr(bars, "NumberIn1", "max(LbxCtrl.R, 0.05)")
expr(bars, "NumberIn2", "LbxCtrl.Amt")
expr(bars, "NumberIn3", "LbxCtrl.LbxOffset")
expr(bars, "NumberIn4", "LbxCtrl.LbxOpacity")
-- i1: how far this pixel is inside a bar, in pixels. The opening is half the frame (no bars) when Amt is 0.
L.cx(bars, "Intermediate1", "if(n1 >= w/h, (abs(y - 0.5 - n3) - (0.5 + (w/h/n1/2 - 0.5)*n2))*h, (abs(x - 0.5 - n3) - (0.5 + (n1/(w/h)/2 - 0.5)*n2))*w)")
L.cx(bars, "Intermediate2", "n4*min(max(i1 + 0.5, 0), 1)")
L.cx(bars, "RedExpression", "getr2b(0.5, 0.5)*i2"); L.cx(bars, "GreenExpression", "getg2b(0.5, 0.5)*i2")
L.cx(bars, "BlueExpression", "getb2b(0.5, 0.5)*i2"); L.cx(bars, "AlphaExpression", "i2")

mediaOut.Input = bars.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColLetterbox", "TopLeftRed", "Colour", "3"}
spec[#spec + 1] = {"CTL", "ColLetterbox", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColLetterbox", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "letterbox", name = "Letterbox", out = bars, ctrl = ctrl, spec = spec, prefix = "lb"})
