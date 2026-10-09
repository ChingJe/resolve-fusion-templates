-- Video Wall transition: pull back from clip A to a wall of screens, slide across, push into clip B.
-- Built in the lab clip comp with two procedural stand-ins. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Video Wall")
local _, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "WallCtrl", -5, -3)
ctrl.UserControls = {
  PullBack = L.num("Pull Back", 1, 0.4, 2),
  Gutter   = L.num("Gap", 0.02, 0, 0.08),
  TimeOffset = L.num("Time Offset", 12, 0, 60),
  Dim      = L.num("Other Screens Brightness", 0.75, 0, 1),
  P     = L.num("P", 0, 0, 1, "Driver"),
  ViewS = L.num("ViewS", 0.33, 0, 2, "Driver"),
  CX    = L.num("CX", 0.5, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
-- built-in transitions take their 0..1 progress from an AnimCurves modifier, so do the same
ctrl:AddModifier("P", "LUTLookup")
local curve = ctrl.P:GetConnectedOutput():GetTool()
curve:SetAttrs({TOOLS_Name = "WallProgress"})
curve:SetInput("Source", "Transition")
curve:SetInput("Curve", "Linear")
expr(ctrl, "ViewS", "(1 - 2*Gutter)/3 + (PullBack - (1 - 2*Gutter)/3) * sin(3.14159265*P)^2")
expr(ctrl, "CX", "1/6 + (4/6) * P*P*(3 - 2*P)")

local srcA = add("BrightnessContrast", "SrcA", -5, 0)
local srcB = add("BrightnessContrast", "SrcB", -5, 2)
local a, b = L.testsource(comp, "A", 0), L.testsource(comp, "B", 1)
srcA.Input = a.Output; srcB.Input = b.Output

-- the other seven screens: small copies of A (earlier moments) and B (later moments)
local TW, TH = 960, 540
local smallA = add("BetterResize", "SmallA", -4, 0)
smallA.Input = srcA.Output
local smallB = add("BetterResize", "SmallB", -4, 2)
smallB.Input = srcB.Output
for _, s in ipairs({smallA, smallB}) do s:SetInput("Width", TW); s:SetInput("Height", TH); s:SetInput("KeepAspect", 0) end
local atlas = add("Background", "WallBase", -4, 6)
L.color(atlas, 0, 0, 0)
atlas:SetInput("UseFrameFormatSettings", 0)
atlas:SetInput("Width", TW * 3); atlas:SetInput("Height", TH * 3)
local last, n = atlas, 0
for id = 0, 8 do
  if id ~= 3 and id ~= 5 then -- 3 is clip A itself, 5 is clip B itself
    n = n + 1
    local fromA = (n % 2 == 1)
    local ts = add("TimeStretcher", "Screen" .. id, -3 + n, fromA and 0 or 2)
    ts.Input = (fromA and smallA or smallB).Output
    ts:SetInput("InterpolateBetweenFrames", 0)
    expr(ts, "SourceTime", string.format("time %s floor(%d * WallCtrl.TimeOffset)", fromA and "-" or "+", math.ceil(n / 2)))
    local m = add("Merge", "Place" .. id, -3 + n, 6)
    m.Background = last.Output
    m.Foreground = ts.Output
    m:SetInput("Center", {(id % 3 + 0.5) / 3, (math.floor(id / 3) + 0.5) / 3})
    last = m
  end
end

-- the camera: every output pixel looks up a spot on the (endlessly repeating) wall
local cam = add("Custom", "WallCam", 6, 3)
cam.Image1 = srcA.Output
cam.Image2 = srcB.Output
cam.Image3 = last.Output
expr(cam, "NumberIn1", "WallCtrl.P")
expr(cam, "NumberIn2", "WallCtrl.ViewS")
expr(cam, "NumberIn3", "WallCtrl.Gutter")
expr(cam, "NumberIn4", "WallCtrl.CX")
expr(cam, "NumberIn6", "WallCtrl.Dim")
cam:SetInput("Intermediate1", "10 + n4 + (x - 0.5)*n2")
cam:SetInput("Intermediate2", "10.5 + (y - 0.5)*n2")
cam:SetInput("Intermediate3", "floor(frac(i1)*3)")
cam:SetInput("Intermediate4", "floor(frac(i2)*3)")
cam:SetInput("Intermediate5", "(frac(frac(i1)*3) - n3)/(1 - 2*n3)")
cam:SetInput("Intermediate6", "(frac(frac(i2)*3) - n3)/(1 - 2*n3)")
cam:SetInput("Intermediate7", "i3 + i4*3")
cam:SetInput("Intermediate8", "if(min(min(i5, 1 - i5), min(i6, 1 - i6)) > 0, 1, 0)")
local function chan(c)
  return string.format(
    "if(n1 <= 0, %s1, if(n1 >= 1, %s2, if(i8 < 1, 0.03, if(abs(i7 - 3) < 0.5, get%s1b(i5, i6), if(abs(i7 - 5) < 0.5, get%s2b(i5, i6), get%s3b((i3 + i5)/3, (i4 + i6)/3)*n6)))))",
    c, c, c, c, c)
end
cam:SetInput("RedExpression", chan("r"))
cam:SetInput("GreenExpression", chan("g"))
cam:SetInput("BlueExpression", chan("b"))
cam:SetInput("AlphaExpression", "1")

mediaOut.Input = cam.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  srcA.Input = nil; srcB.Input = nil
  L.export(comp, "videowall", {
    {"NAME", "VideoWall"},
    {"MAIN", "SrcA", "Input"},
    {"MAIN", "SrcB", "Input"},
    {"OUT", "WallCam", "Output"},
    {"CTL", "WallCtrl", "PullBack", "Pull Back"},
    {"CTL", "WallCtrl", "Gutter", "Gap"},
    {"CTL", "WallCtrl", "TimeOffset", "Time Offset"},
    {"CTL", "WallCtrl", "Dim", "Other Screens Brightness"},
  })
  srcA.Input = a.Output; srcB.Input = b.Output
else
  L.render(comp, cam.Output, os.getenv("FX_PREFIX") or "vw", tonumber(os.getenv("FX_STEPS") or "12"))
end
