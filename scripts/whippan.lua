-- Whip Pan transition: the camera seems to swing away so fast that the picture smears, and lands on the next clip.
-- The first clip slides out, the second follows right behind it, and both are blurred along the move.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Whip Pan")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "WhipCtrl", {
  {"WhipDir",   L.combo("Picture Moves", {"Left", "Right", "Up", "Down"}, 0)},
  {"WhipAngle", L.num("Extra Angle", 0, -45, 45)},
  {"WhipBlur",  L.num("Blur", 0.35, 0, 1)},
  {"WhipSnap",  L.num("Snap", 2.5, 1, 6)},
  {"WhipScreens", L.num("Screens Travelled", 1, 1, 5, nil, true)},
  {"WhipZoom",  L.num("Zoom While Moving", 0.06, 0, 0.5)},
  {"P", L.num("P", 0, 0, 1, "Driver")},
  {"S", L.num("S", 0, 0, 1, "Driver")},
  {"V", L.num("V", 0, 0, 1, "Driver")},
  {"A", L.num("A", 0, -360, 360, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 2)
-- S: how far the move has come, slow at both ends and very fast in the middle. V: its speed, 0..1.
expr(ctrl, "S", "iif(P < 0.5, 0.5*(2*P)^WhipSnap, 1 - 0.5*(2 - 2*P)^WhipSnap)")
expr(ctrl, "V", "iif(P <= 0 or P >= 1, 0, (1 - abs(2*P - 1))^(WhipSnap - 1))")
expr(ctrl, "A", "({180, 0, 270, 90})[WhipDir + 1] + WhipAngle")

-- The two clips sit side by side on an endless mirrored strip, clip B one or more screens further along.
local cam = add("Custom", "WhipCam", 0, 1)
cam.Image1 = srcs[1].Output; cam.Image2 = srcs[2].Output
expr(cam, "NumberIn1", "WhipCtrl.P")
expr(cam, "NumberIn2", "WhipCtrl.S * WhipCtrl.WhipScreens")
expr(cam, "NumberIn3", "WhipCtrl.A")
expr(cam, "NumberIn4", "WhipCtrl.WhipScreens")
expr(cam, "NumberIn5", "1 + WhipCtrl.WhipZoom * WhipCtrl.V")
-- i1, i2: the step from one screen to the next, long enough to leave the frame in that direction
cam:SetInput("Intermediate1", "-cos(n3)/max(abs(cos(n3)), abs(sin(n3)))")
cam:SetInput("Intermediate2", "-sin(n3)/max(abs(cos(n3)), abs(sin(n3)))")
-- i3, i4: where this pixel is on the strip, in screens
cam:SetInput("Intermediate3", "0.5 + (x - 0.5)/n5 + n2*i1")
cam:SetInput("Intermediate4", "0.5 + (y - 0.5)/n5 + n2*i2")
-- i5: 1 once this pixel has passed the middle of the strip and belongs to clip B
cam:SetInput("Intermediate5", "if((i3 - 0.5)*i1 + (i4 - 0.5)*i2 > 0.5*n4*(i1*i1 + i2*i2), 1, 0)")
cam:SetInput("Intermediate6", L.mirror("i3 - i5*n4*i1"))
cam:SetInput("Intermediate7", L.mirror("i4 - i5*n4*i2"))
local function chan(c)
  return string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, if(i5 > 0, get%s2b(i6, i7), get%s1b(i6, i7))))", c, c, c, c)
end
cam:SetInput("RedExpression", chan("r")); cam:SetInput("GreenExpression", chan("g"))
cam:SetInput("BlueExpression", chan("b")); cam:SetInput("AlphaExpression", "1")

local blur = add("DirectionalBlur", "WhipFinal", 2, 1)
blur.Input = cam.Output
blur:SetInput("Type", "Linear")
expr(blur, "Angle", "WhipCtrl.A")
expr(blur, "Length", "WhipCtrl.WhipBlur * WhipCtrl.V")

mediaOut.Input = blur.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "whippan", name = "WhipPan", out = blur, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "wp"})
