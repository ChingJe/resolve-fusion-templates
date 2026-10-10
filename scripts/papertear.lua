-- Paper Tear transition: clip A is ripped in two along a ragged line and the halves are pulled apart, clip B is underneath.
-- Built in the lab clip comp with two procedural stand-ins. FX_SRC=media uses the clip for A and a later
-- part of the same clip for B. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Paper Tear")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "TearCtrl", -5, -3)
ctrl.UserControls = {
  TearAngle  = L.num("Angle", 12, -180, 180),
  TearOffset = L.num("Line Position", 0, -0.5, 0.5),
  TearRough  = L.num("Roughness", 0.05, 0, 0.2),
  TearGap    = L.num("Rip Gap", 0.02, 0, 0.1),
  TearEdge   = L.num("Paper Edge Width", 0.012, 0, 0.05),
  TearShadow = L.num("Shadow", 0.6, 0, 1),
  TearShadowW = L.num("Shadow Width", 0.03, 0, 0.15),
  TearSeed   = L.num("Tear Shape", 0, 0, 20),
  TearRip    = L.num("Rip Time", 0.36, 0.02, 0.95),
  TearSteps  = L.num("Stop Motion Steps", 0, 0, 24, nil, true),
  P  = L.num("P", 0, 0, 1, "Driver"),
  Q  = L.num("Q", 0, 0, 1, "Driver"),
  F  = L.num("F", 0, -1, 20, "Driver"),
  Slide = L.num("Slide", 0, 0, 3, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:AddModifier("P", "LUTLookup")
local curve = ctrl.P:GetConnectedOutput():GetTool()
curve:SetAttrs({TOOLS_Name = "TearProgress"})
curve:SetInput("Source", "Transition")
curve:SetInput("Curve", "Linear")
-- optionally held on a few steps so the tear jerks along like stop motion
expr(ctrl, "Q", "iif(TearSteps >= 1, floor(P*TearSteps + 0.5)/max(TearSteps, 1), P)")
-- F: how far the rip has travelled along its line (0 one end of the frame, 1 the other), done at Q = Rip Time.
-- Slide: how far each half has then been pulled away sideways; it starts while the rip is still running.
expr(ctrl, "F", "Q/TearRip")
expr(ctrl, "Slide", "(0.7 + abs(TearOffset) + TearRough) * (function(t) return t*t*(3 - 2*t) end)(min(max((Q - 0.7*TearRip)/(1 - 0.7*TearRip), 0), 1))")

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
expr(cut, "NumberIn7", "TearCtrl.F")
expr(cut, "NumberIn8", "TearCtrl.TearGap")
expr(cut, "PointIn1", "Point(TearCtrl.TearOffset, TearCtrl.Slide)")
-- The rip line stays where it is on the paper. The rip travels along it and leaves a narrow gap behind,
-- then the two halves of A slide apart without changing shape.
-- i1 position along the line (0..1 across the frame), i2 how far each half has been pulled here
cut:SetInput("Intermediate1", "0.5 + ((y - 0.5)*(h/w)*cos(n2) - (x - 0.5)*sin(n2))/(abs(sin(n2)) + (h/w)*abs(cos(n2)))")
cut:SetInput("Intermediate2", "n8*min(max((n7 - i1)/0.12, 0), 1) + p1y")
-- i3 distance across the line in units of the frame width, measured on the paper before it was pulled
cut:SetInput("Intermediate3", "(x - 0.5)*cos(n2) + (y - 0.5)*(h/w)*sin(n2) - p1x - n3*2*(getr3b(0.27, 0.5 + 0.75*((y - 0.5)*(h/w)*cos(n2) - (x - 0.5)*sin(n2))) - 0.5)")
-- i4 > 0 inside the half that moves one way, i5 > 0 inside the other half, both negative in the gap
cut:SetInput("Intermediate4", "i3 - i2")
cut:SetInput("Intermediate5", "-i3 - i2")
-- i6 how far the white paper core shows at this spot, i7 paper grain, i8 shadow the halves cast on B
cut:SetInput("Intermediate6", "n4*(0.25 + 1.5*getr3b(0.71, frac(i1*3.7)))*min(i2/0.004, 1)")
cut:SetInput("Intermediate7", "0.9 + 0.1*getr3b(frac(x*5), frac(y*5))")
cut:SetInput("Intermediate8", "1 - n5*max(0, 1 - max(min(-i4, -i5), 0)/max(n6, 0.0001))^2")
-- a half only covers the spots where the picture it carries exists; beyond the old frame edge B shows
local function chan(c)
  local function half(sign, inside, core)
    local sx = string.format("(x %s i2*cos(n2))", sign)
    local sy = string.format("(y %s i2*sin(n2)*w/h)", sign)
    return string.format("if(min(min(%s, 1 - %s), min(%s, 1 - %s)) < 0, %s2, if(%s > %s, get%s1b(%s, %s), i7))",
      sx, sx, sy, sy, c, inside, core, c, sx, sy)
  end
  return string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, if(i4 > 0, %s, if(i5 > 0, %s, %s2*i8))))",
    c, c, half("-", "i4", "i6"), half("+", "i5", "i6*0.5"), c)
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
    {"CTL", "TearCtrl", "TearOffset", "Line Position"},
    {"CTL", "TearCtrl", "TearGap", "Rip Gap"},
    {"CTL", "TearCtrl", "TearRough", "Roughness"},
    {"CTL", "TearCtrl", "TearSeed", "Tear Shape"},
    {"CTL", "TearCtrl", "TearEdge", "Paper Edge Width"},
    {"CTL", "TearCtrl", "TearShadow", "Shadow"},
    {"CTL", "TearCtrl", "TearShadowW", "Shadow Width"},
    {"CTL", "TearCtrl", "TearRip", "Rip Time"},
    {"CTL", "TearCtrl", "TearSteps", "Stop Motion Steps"},
  })
  srcA.Input = a.Output; srcB.Input = b.Output
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  L.render(comp, cut.Output, os.getenv("FX_PREFIX") or "pt", tonumber(os.getenv("FX_STEPS") or "12"))
end
