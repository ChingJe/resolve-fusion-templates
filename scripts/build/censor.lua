-- Censor Patch: hides one spot of the picture with mosaic, blur or a block of colour. For faces, number plates,
-- anything on a screen that should not be read. Can be turned round to hide everything except the spot.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Censor Patch")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "CzCtrl", {
  {"CzStyle",  L.combo("Style", {"Mosaic", "Blur", "Colour Block"}, 0)},
  {"CzShape",  L.combo("Shape", {"Rectangle", "Ellipse"}, 0)},
  {"CzPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"CzW",      L.num("Width", 0.3, 0.01, 2)},
  {"CzH",      L.num("Height", 0.25, 0.01, 1)},
  {"CzAngle",  L.num("Angle", 0, -180, 180)},
  {"CzRound",  L.num("Rectangle: Corner Roundness", 0, 0, 1)},
  {"CzCell",   L.num("Mosaic: Cell Size", 0.04, 0.005, 0.2)},
  {"CzBlur",   L.num("Blur: Strength", 1, 0.1, 4)},
  {"CzSoft",   L.num("Edge Softness", 0, 0, 0.2)},
  {"CzInvert", L.check("Hide Everything Else Instead", 0)},
  {"CzIn",     L.num("Fade In (seconds)", 0, 0, 3)},
  {"CzOut",    L.num("Fade Out (seconds)", 0, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"Amt", L.num("Amt", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
expr(ctrl, "Amt", "min(iif(CzIn <= 0, 1, min(max((time - comp.RenderStart + 1)/(CzIn*" .. FPS .. "), 0), 1)), iif(CzOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/(CzOut*" .. FPS .. "), 0), 1)))")

-- The mosaic reads one point per cell from a picture that was blurred by about one cell first, so each cell
-- shows the average of what is under it and does not flicker when the video moves.
local soft = add("Blur", "CzSoften", -2, 2)
soft.Input = srcs[1].Output
expr(soft, "XBlurSize", "iif(CzCtrl.CzStyle == 0, CzCtrl.CzCell*400, iif(CzCtrl.CzStyle == 1, CzCtrl.CzBlur*25, 0))")
local block = add("Background", "ColCensor", -3, -5)
block:SetInput("UseFrameFormatSettings", 0); block:SetInput("Width", 16); block:SetInput("Height", 16)
L.color(block, 0, 0, 0, 1)

local patch = add("Custom", "CzFinal", 1, 1)
patch.Image1 = srcs[1].Output; patch.Image2 = soft.Output; patch.Image3 = block.Output
expr(patch, "PointIn1", "CzCtrl.CzPos")
expr(patch, "NumberIn1", "CzCtrl.CzStyle")
expr(patch, "NumberIn2", "CzCtrl.CzW/2")
expr(patch, "NumberIn3", "CzCtrl.CzH/2")
expr(patch, "NumberIn4", "CzCtrl.CzAngle")
expr(patch, "NumberIn5", "iif(CzCtrl.CzShape == 1, -1, CzCtrl.CzRound)")
expr(patch, "NumberIn6", "CzCtrl.CzCell")
expr(patch, "NumberIn7", "CzCtrl.CzSoft")
expr(patch, "NumberIn8", "iif(CzCtrl.CzInvert == 1, -1, 1) * CzCtrl.Amt")
-- i1, i2: this pixel seen from the middle of the patch, turned by the angle, frame height = 1. i3 = half width.
L.cx(patch, "Intermediate1", "(x - p1x)*w/h*cos(n4) + (y - p1y)*sin(n4)")
L.cx(patch, "Intermediate2", "(y - p1y)*cos(n4) - (x - p1x)*w/h*sin(n4)")
L.cx(patch, "Intermediate3", "n2")
L.cx(patch, "Intermediate4", "max(n5, 0)*min(i3, n3)")
-- i5: distance to the edge of the patch, negative inside
L.cx(patch, "Intermediate5", "if(n5 < 0, (sqrt((i1/i3)^2 + (i2/n3)^2) - 1)*min(i3, n3), sqrt(max(abs(i1) - i3 + i4, 0)^2 + max(abs(i2) - n3 + i4, 0)^2) + min(max(abs(i1) - i3 + i4, abs(i2) - n3 + i4), 0) - i4)")
-- i6: 1 where the picture is hidden
L.cx(patch, "Intermediate6", "abs(n8)*if(n8 < 0, 1 - min(max(0.5 - i5/max(n7, 1/h), 0), 1), min(max(0.5 - i5/max(n7, 1/h), 0), 1))")
-- i7, i8: the middle of the mosaic cell this pixel is in (cells are square)
L.cx(patch, "Intermediate7", "(floor(x*w/h/n6) + 0.5)*n6*h/w")
L.cx(patch, "Intermediate8", "(floor(y/n6) + 0.5)*n6")
for _, c in ipairs({"r", "g", "b"}) do
  patch:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("%s1*(1 - i6) + i6*if(n1 == 0, get%s2d(i7, i8), if(n1 == 1, %s2, get%s3b(0.5, 0.5)))", c, c, c, c))
end
L.cx(patch, "AlphaExpression", "a1")

mediaOut.Input = patch.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColCensor", "TopLeftRed", "Colour Block: Colour", "3"}
spec[#spec + 1] = {"CTL", "ColCensor", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColCensor", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "censor", name = "CensorPatch", out = patch, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "cz"})
