-- Zoom Callout: a small ring marks a spot, lines lead from it to a larger window somewhere else, and the window
-- shows that spot magnified. The rest of the picture stays as it is. For tutorials and for small details.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Zoom Callout")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "CoCtrl", {
  {"CoSrc",    L.point("Look At", nil, true), {0.3, 0.45}},
  {"CoPos",    L.point("Window Position", nil, true), {0.7, 0.6}},
  {"CoSize",   L.num("Window Size", 0.5, 0.05, 1.5)},
  {"CoAspect", L.num("Window Width / Height", 1, 0.3, 4)},
  {"CoZoom",   L.num("Magnify", 2.5, 1.1, 10)},
  {"CoRound",  L.num("Corner Roundness", 1, 0, 1)},
  {"CoBorder", L.num("Border Width", 0.008, 0, 0.03)},
  {"CoShadow", L.num("Shadow", 0.4, 0, 1)},
  {"CoLine",   L.combo("Lines", {"Two", "One", "None"}, 0)},
  {"CoLineW",  L.num("Line Width", 0.004, 0.001, 0.02)},
  {"CoRing",   L.check("Ring Around The Spot", 1)},
  {"CoEnter",  L.combo("Appears By", {"Growing Out Of The Spot", "Fading In"}, 0)},
  {"CoIn",     L.num("Appear (seconds)", 0.35, 0, 3)},
  {"CoOut",    L.num("Fade Out (seconds)", 0.25, 0, 3)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"G",   L.num("G", 0, 0, 1, "Driver")},
  {"Mix", L.num("Mix", 0, 0, 1, "Driver")},
  {"Dst", L.point("Dst", "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
local IN = "iif(CoIn <= 0, 1, " .. L.SMOOTH .. "(min(max((time - comp.RenderStart + 1)/(CoIn*" .. FPS .. "), 0), 1)))"
local OUT = "iif(CoOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/(CoOut*" .. FPS .. "), 0), 1))"
expr(ctrl, "G", "iif(CoEnter == 0, " .. IN .. ", 1)")
expr(ctrl, "Mix", "iif(CoEnter == 0, min(" .. IN .. "*4, 1), " .. IN .. ") * " .. OUT)
expr(ctrl, "Dst", "Point(CoSrc.X + (CoPos.X - CoSrc.X)*G, CoSrc.Y + (CoPos.Y - CoSrc.Y)*G)")

local col = add("Background", "ColCallout", -3, -5)
col:SetInput("UseFrameFormatSettings", 0); col:SetInput("Width", 16); col:SetInput("Height", 16)
L.color(col, 1, 1, 1, 1)

local co = add("Custom", "CoFinal", 1, 1)
co.Image1 = srcs[1].Output; co.Image2 = col.Output
expr(co, "PointIn1", "CoCtrl.CoSrc")
expr(co, "PointIn2", "CoCtrl.Dst")
expr(co, "PointIn3", "Point(CoCtrl.CoAspect, CoCtrl.CoShadow)")
expr(co, "NumberIn1", "max(CoCtrl.CoSize/2*CoCtrl.G, 0.0005)")
expr(co, "NumberIn2", "CoCtrl.CoZoom")
expr(co, "NumberIn3", "CoCtrl.CoRound")
expr(co, "NumberIn4", "CoCtrl.CoBorder")
expr(co, "NumberIn5", "CoCtrl.CoLineW")
expr(co, "NumberIn6", "CoCtrl.CoLine")
expr(co, "NumberIn7", "CoCtrl.CoRing")
expr(co, "NumberIn8", "CoCtrl.Mix")
-- distance to the outline of a rounded box around (cx, cy), half height hh, negative inside. Frame height = 1.
local function box(cx, cy, hh)
  local qx = string.format("(abs((x - %s)*w/h) - (%s)*p3x + n3*(%s)*min(p3x, 1))", cx, hh, hh)
  local qy = string.format("(abs(y - %s) - (%s) + n3*(%s)*min(p3x, 1))", cy, hh, hh)
  return string.format("(sqrt(max(%s, 0)^2 + max(%s, 0)^2) + min(max(%s, %s), 0) - n3*(%s)*min(p3x, 1))", qx, qy, qx, qy, hh)
end
L.cx(co, "Intermediate1", box("p2x", "p2y", "n1"))        -- the window
L.cx(co, "Intermediate2", box("p1x", "p1y", "(n1/n2)"))    -- the spot it shows
L.cx(co, "Intermediate3", "max(((p2x - p1x)*w/h)^2 + (p2y - p1y)^2, 0.000001)")
-- i4: how far along the way from the spot to the window this pixel is (0..1), i5: how far beside that way.
-- One line runs along the way. Two lines run beside it, as far out as the ring at one end and the window at the other.
L.cx(co, "Intermediate4", "((x - p1x)*w/h*(p2x - p1x)*w/h + (y - p1y)*(p2y - p1y))/i3")
L.cx(co, "Intermediate5", "abs((x - p1x)*w/h*(p2y - p1y) - (y - p1y)*(p2x - p1x)*w/h)/sqrt(i3)")
L.cx(co, "Intermediate6", "if(n6 == 2 || i4 < 0 || i4 > 1, 9, if(n6 == 1, i5, abs(i5 - n1*min(p3x, 1)*(1/n2 + (1 - 1/n2)*i4))))")
-- i7 lines and ring; the window, its border and its shadow are worked out where they are used
L.cx(co, "Intermediate7", "n8*max(if(i2 > 0, min(max((n5/2 - i6)*h + 0.5, 0), 1), 0), n7*min(max((max(n5, 1.5/h)/2 - abs(i2))*h + 0.5, 0), 1))")
L.cx(co, "Intermediate8", "n8*min(max(0.5 - i1*h, 0), 1)")
local BORDER = "(n8*if(n4 > 0, min(max((n4/2 - abs(i1))*h + 0.5, 0), 1), 0))"
local SHADOW = "(n8*p3y*if(i1 > 0, max(1 - i1/0.04, 0)^2, 0))"
for _, c in ipairs({"r", "g", "b"}) do
  local pen = string.format("get%s2b(0.5, 0.5)", c)
  local under = string.format("(%s1*(1 - %s)*(1 - i7) + %s*i7)", c, SHADOW, pen)
  local inside = string.format("get%s1b(p1x + (x - p2x)/n2, p1y + (y - p2y)/n2)", c)
  L.cx(co, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("(%s*(1 - i8) + %s*i8)*(1 - %s) + %s*%s", under, inside, BORDER, pen, BORDER))
end
L.cx(co, "AlphaExpression", "a1")

mediaOut.Input = co.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColCallout", "TopLeftRed", "Border And Line Colour", "3"}
spec[#spec + 1] = {"CTL", "ColCallout", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColCallout", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "zoomcallout", name = "ZoomCallout", out = co, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "zc"})
