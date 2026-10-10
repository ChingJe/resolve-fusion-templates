-- Paper Tear transition: a ragged edge sweeps across, clip A is torn away like a sheet of paper and clip B is underneath.
-- Built in the lab clip comp with two procedural stand-ins. FX_SRC=media uses the clip for A and a later
-- part of the same clip for B. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Paper Tear")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "TearCtrl", -5, -3)
ctrl.UserControls = {
  TearAngle  = L.num("Angle", 12, -180, 180),
  TearRough  = L.num("Roughness", 0.05, 0, 0.2),
  TearEdge   = L.num("Paper Edge Width", 0.012, 0, 0.05),
  TearShadow = L.num("Shadow", 0.6, 0, 1),
  TearShadowW = L.num("Shadow Width", 0.03, 0, 0.15),
  TearSeed   = L.num("Tear Shape", 0, 0, 20),
  TearSteps  = L.num("Stop Motion Steps", 0, 0, 24, nil, true),
  P  = L.num("P", 0, 0, 1, "Driver"),
  Q  = L.num("Q", 0, 0, 1, "Driver"),
  E  = L.num("E", 0, -2, 2, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:AddModifier("P", "LUTLookup")
local curve = ctrl.P:GetConnectedOutput():GetTool()
curve:SetAttrs({TOOLS_Name = "TearProgress"})
curve:SetInput("Source", "Transition")
curve:SetInput("Curve", "Linear")
-- eased, then optionally held on a few steps so the tear jerks along like stop motion
expr(ctrl, "Q", "(function(p, n) if n >= 1 then p = floor(p*n + 0.5)/n end return p*p*(3 - 2*p) end)(P, TearSteps)")
-- the edge starts and ends far enough off screen that nothing of it shows at either end
expr(ctrl, "E", "(function(r) return -r + 2*r*Q end)(0.6 + TearRough + TearEdge + TearShadowW)")

local srcA = add("BrightnessContrast", "SrcA", -5, 0)
local srcB = add("BrightnessContrast", "SrcB", -5, 2)
local a, b
if os.getenv("FX_SRC") == "media" then
  a = mediaIn
  b = add("TimeStretcher", "PrevLater", -6, 2)
  b.Input = mediaIn.Output
  b:SetInput("InterpolateBetweenFrames", 0)
  expr(b, "SourceTime", "time + 1500")
else
  a, b = L.testsource(comp, "A", 0), L.testsource(comp, "B", 1)
end
srcA.Input = a.Output; srcB.Input = b.Output

-- the shape of the tear and the paper grain both come from one still noise image
local noise = add("FastNoise", "TearNoise", -3, 4)
noise:SetInput("UseFrameFormatSettings", 0)
noise:SetInput("Width", 1024); noise:SetInput("Height", 1024)
noise:SetInput("Depth", 4)
noise:SetInput("Detail", 8)
noise:SetInput("Contrast", 2.2)
noise:SetInput("XScale", 6)
noise:SetInput("SeetheRate", 0)
expr(noise, "Seethe", "TearCtrl.TearSeed")

local cut = add("Custom", "TearCut", 2, 1)
cut.Image1 = srcA.Output
cut.Image2 = srcB.Output
cut.Image3 = noise.Output
expr(cut, "NumberIn1", "TearCtrl.P")
expr(cut, "NumberIn2", "TearCtrl.TearAngle")
expr(cut, "NumberIn3", "TearCtrl.TearRough")
expr(cut, "NumberIn4", "TearCtrl.TearEdge")
expr(cut, "NumberIn5", "TearCtrl.TearShadow")
expr(cut, "NumberIn6", "TearCtrl.TearShadowW")
expr(cut, "NumberIn7", "TearCtrl.E")
-- i1 across the tear, i2 along it, both in units of the frame width
cut:SetInput("Intermediate1", "(x - 0.5)*cos(n2) + (y - 0.5)*(h/w)*sin(n2)")
cut:SetInput("Intermediate2", "0.5 + 0.75*((y - 0.5)*(h/w)*cos(n2) - (x - 0.5)*sin(n2))")
-- i3 distance from the torn edge of A, positive on the side where A is still there
cut:SetInput("Intermediate3", "i1 - n7 - n3*2*(getr3b(0.27, i2) - 0.5)")
-- i4 how far the white paper core shows at this spot, i5 paper grain, i6 shadow that A casts on B
cut:SetInput("Intermediate4", "n4*(0.25 + 1.5*getr3b(0.71, frac(i2*3.7)))")
cut:SetInput("Intermediate5", "0.9 + 0.1*getr3b(frac(x*5), frac(y*5))")
cut:SetInput("Intermediate6", "1 - n5*max(0, 1 + i3/max(n6, 0.0001))^2")
local function chan(c)
  return string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, if(i3 > i4, %s1, if(i3 > 0, i5, %s2*i6))))", c, c, c, c)
end
cut:SetInput("RedExpression", chan("r"))
cut:SetInput("GreenExpression", chan("g"))
cut:SetInput("BlueExpression", chan("b"))
cut:SetInput("AlphaExpression", "1")

mediaOut.Input = cut.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  srcA.Input = nil; srcB.Input = nil
  L.export(comp, "papertear", {
    {"NAME", "PaperTear"},
    {"MAIN", "SrcA", "Input"},
    {"MAIN", "SrcB", "Input"},
    {"OUT", "TearCut", "Output"},
    {"CTL", "TearCtrl", "TearAngle", "Angle"},
    {"CTL", "TearCtrl", "TearRough", "Roughness"},
    {"CTL", "TearCtrl", "TearSeed", "Tear Shape"},
    {"CTL", "TearCtrl", "TearEdge", "Paper Edge Width"},
    {"CTL", "TearCtrl", "TearShadow", "Shadow"},
    {"CTL", "TearCtrl", "TearShadowW", "Shadow Width"},
    {"CTL", "TearCtrl", "TearSteps", "Stop Motion Steps"},
  })
  srcA.Input = a.Output; srcB.Input = b.Output
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  L.render(comp, cut.Output, os.getenv("FX_PREFIX") or "pt", tonumber(os.getenv("FX_STEPS") or "12"))
end
