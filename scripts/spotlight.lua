-- Spotlight: everything outside one spot goes dark (and soft, and grey if wanted) so the viewer looks at that spot.
-- The spot can also work as a magnifying glass. For tutorials and for pointing at a detail.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Spotlight")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "SpotCtrl", {
  {"SpPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"SpSize",   L.num("Size", 0.4, 0.02, 2)},
  {"SpAspect", L.num("Width / Height", 1, 0.2, 5)},
  {"SpRound",  L.num("Corner Roundness", 1, 0, 1)},
  {"SpSoft",   L.num("Edge Softness", 0.02, 0, 0.3)},
  {"SpDark",   L.num("Outside: Darken", 0.65, 0, 1)},
  {"SpBlur",   L.num("Outside: Blur", 0, 0, 30)},
  {"SpGrey",   L.num("Outside: Remove Colour", 0, 0, 1)},
  {"SpZoom",   L.num("Magnify", 1, 1, 6)},
  {"SpRing",   L.num("Ring Width", 0, 0, 0.03)},
  {"SpIn",     L.num("Fade In Frames", 8, 0, 60)},
  {"SpOut",    L.num("Fade Out Frames", 8, 0, 60)},
  {"Amt", L.num("Amt", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
expr(ctrl, "Amt", L.SMOOTH .. "(min(iif(SpIn <= 0, 1, min(max((time - comp.RenderStart)/SpIn, 0), 1)), iif(SpOut <= 0, 1, min(max((comp.RenderEnd - time)/SpOut, 0), 1))))")

local soft = add("Blur", "SpotBlur", -2, 2)
soft.Input = srcs[1].Output
expr(soft, "XBlurSize", "SpotCtrl.SpBlur * SpotCtrl.Amt")
local ring = add("Background", "ColSpotRing", -3, -5)
ring:SetInput("UseFrameFormatSettings", 0); ring:SetInput("Width", 16); ring:SetInput("Height", 16)
L.color(ring, 1, 0.85, 0.1, 1)

local spot = add("Custom", "SpotFinal", 1, 1)
spot.Image1 = srcs[1].Output; spot.Image2 = soft.Output; spot.Image3 = ring.Output
expr(spot, "NumberIn1", "SpotCtrl.SpSize / 2")
expr(spot, "NumberIn2", "SpotCtrl.SpAspect")
expr(spot, "NumberIn3", "SpotCtrl.SpRound")
expr(spot, "NumberIn4", "max(SpotCtrl.SpSoft, 0.001)")
expr(spot, "NumberIn5", "SpotCtrl.SpDark * SpotCtrl.Amt")
expr(spot, "NumberIn6", "SpotCtrl.SpGrey * SpotCtrl.Amt")
expr(spot, "NumberIn7", "1 + (SpotCtrl.SpZoom - 1) * SpotCtrl.Amt")
expr(spot, "NumberIn8", "SpotCtrl.SpRing * SpotCtrl.Amt")
expr(spot, "PointIn1", "SpotCtrl.SpPos")
spot:SetInput("Intermediate1", "(x - p1x)*w/h")
spot:SetInput("Intermediate2", "y - p1y")
spot:SetInput("Intermediate3", "n1*n2")
spot:SetInput("Intermediate4", "n3*min(n1, i3)")
-- i5 distance to the outline of the spot, negative inside
spot:SetInput("Intermediate5", "sqrt(max(abs(i1) - i3 + i4, 0)^2 + max(abs(i2) - n1 + i4, 0)^2) + min(max(abs(i1) - i3 + i4, abs(i2) - n1 + i4), 0) - i4")
-- i6 = 1 inside the spot, 0 outside, i7 = 1 on the ring
spot:SetInput("Intermediate6", "min(max(0.5 - i5/n4, 0), 1)")
spot:SetInput("Intermediate7", "if(n8 > 0, min(max((n8/2 - abs(i5))*h + 0.5, 0), 1), 0)")
-- i8 the grey value of the picture outside
spot:SetInput("Intermediate8", "0.299*r2 + 0.587*g2 + 0.114*b2")
for _, c in ipairs({"r", "g", "b"}) do
  local inside = string.format("get%s1b(p1x + (x - p1x)/n7, p1y + (y - p1y)/n7)", c)
  local outside = string.format("(%s2 + (i8 - %s2)*n6)*(1 - n5)", c, c)
  spot:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("(%s*i6 + %s*(1 - i6))*(1 - i7) + get%s3b(0.5, 0.5)*i7", inside, outside, c))
end
spot:SetInput("AlphaExpression", "a1")

mediaOut.Input = spot.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColSpotRing", "TopLeftRed", "Ring Colour", "3"}
spec[#spec + 1] = {"CTL", "ColSpotRing", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColSpotRing", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "spotlight", name = "Spotlight", out = spot, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "sp"})
