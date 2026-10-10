-- Zoom Through transition: the camera dives into the first clip and comes out in the second one.
-- Both clips are zoomed by the same accelerating move, so it reads as one continuous push (or pull).
-- FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Zoom Through")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "ZoomCtrl", {
  {"ZtDir",    L.combo("Direction", {"Push In", "Pull Out"}, 0)},
  {"ZtAmount", L.num("Zoom", 5, 1.5, 20)},
  {"ZtCenter", L.point("Zoom Center", nil, true), {0.5, 0.5}},
  {"ZtBlur",   L.num("Blur", 0.25, 0, 1)},
  {"ZtSnap",   L.num("Snap", 2.5, 1, 6)},
  {"ZtMix",    L.num("Cross Fade Length", 0.15, 0.01, 1)},
  {"ZtTwist",  L.num("Twist", 0, -180, 180)},
  {"ZtFlash",  L.num("Flash", 0.3, 0, 2)},
  {"P", L.num("P", 0, 0, 1, "Driver")},
  {"S", L.num("S", 0, 0, 1, "Driver")},
  {"V", L.num("V", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 2)
expr(ctrl, "S", "iif(P < 0.5, 0.5*(2*P)^ZtSnap, 1 - 0.5*(2 - 2*P)^ZtSnap)")
expr(ctrl, "V", "iif(P <= 0 or P >= 1, 0, (1 - abs(2*P - 1))^(ZtSnap - 1))")

local cam = add("Custom", "ZoomCam", 0, 1)
cam.Image1 = srcs[1].Output; cam.Image2 = srcs[2].Output
expr(cam, "NumberIn1", "ZoomCtrl.P")
-- n2, n3: how much clip A and clip B are enlarged. A goes 1 -> Zoom, B goes 1/Zoom -> 1 (the other way round for Pull Out).
expr(cam, "NumberIn2", "ZoomCtrl.ZtAmount ^ (iif(ZoomCtrl.ZtDir == 0, 1, -1) * ZoomCtrl.S)")
expr(cam, "NumberIn3", "ZoomCtrl.ZtAmount ^ (iif(ZoomCtrl.ZtDir == 0, 1, -1) * (ZoomCtrl.S - 1))")
expr(cam, "NumberIn4", "min(max((ZoomCtrl.S - 0.5)/max(ZoomCtrl.ZtMix, 0.001) + 0.5, 0), 1)")
expr(cam, "NumberIn5", "ZoomCtrl.ZtTwist * ZoomCtrl.S")
expr(cam, "NumberIn6", "ZoomCtrl.ZtTwist * (ZoomCtrl.S - 1)")
expr(cam, "NumberIn7", "1 + ZoomCtrl.ZtFlash * ZoomCtrl.V^3")
expr(cam, "PointIn1", "ZoomCtrl.ZtCenter")
local function spot(scale, turn)
  local dx, dy = "(x - p1x)", "(y - p1y)"
  return L.mirror(string.format("p1x + (%s*cos(%s) - %s*(h/w)*sin(%s))/%s", dx, turn, dy, turn, scale)),
         L.mirror(string.format("p1y + (%s*(w/h)*sin(%s) + %s*cos(%s))/%s", dx, turn, dy, turn, scale))
end
local ax, ay = spot("n2", "n5")
local bx, by = spot("n3", "n6")
cam:SetInput("Intermediate1", ax); cam:SetInput("Intermediate2", ay)
cam:SetInput("Intermediate3", bx); cam:SetInput("Intermediate4", by)
local function chan(c)
  return string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, (get%s1b(i1, i2)*(1 - n4) + get%s2b(i3, i4)*n4)*n7))", c, c, c, c)
end
cam:SetInput("RedExpression", chan("r")); cam:SetInput("GreenExpression", chan("g"))
cam:SetInput("BlueExpression", chan("b")); cam:SetInput("AlphaExpression", "1")

local blur = add("DirectionalBlur", "ZoomFinal", 2, 1)
blur.Input = cam.Output
blur:SetInput("Type", "Zoom")
expr(blur, "Center", "ZoomCtrl.ZtCenter")
expr(blur, "Length", "ZoomCtrl.ZtBlur * ZoomCtrl.V")

mediaOut.Input = blur.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "zoomthrough", name = "ZoomThrough", out = blur, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "zt"})
