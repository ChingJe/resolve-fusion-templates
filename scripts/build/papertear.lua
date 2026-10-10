-- Paper Tear transition: clip A is ripped in two along a ragged line and the halves swing away, clip B is underneath.
-- Built in the lab clip comp with two procedural stand-ins. FX_SRC=media uses the clip for A and a later
-- part of the same clip for B. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
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
  TearSwing  = L.num("Swing (degrees)", 14, 0, 45),
  TearStagger = L.num("Second Half Delay", 0.15, 0, 0.6),
  P  = L.num("P", 0, 0, 1, "Driver"),
  Q  = L.num("Q", 0, 0, 1, "Driver"),
  F  = L.num("F", 0, -1, 20, "Driver"),
  U  = L.num("U", 0, 0, 1, "Driver"),
  EaseA = L.num("EaseA", 0, 0, 1, "Driver"),
  EaseB = L.num("EaseB", 0, 0, 1, "Driver"),
  Pivot = L.point("Pivot", "Driver"),
  MoveA = L.point("MoveA", "Driver"),
  MoveB = L.point("MoveB", "Driver"),
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
expr(ctrl, "F", "Q/TearRip")
-- After the rip the two halves are pulled away. Each one swings about the end of the line the rip reached last, so the
-- end where it started opens first, and it leaves slowly and keeps speeding up. The second half follows a little later.
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
local EASE = "(function(t) t = min(max(t, 0), 1) return t*t*(2 - t) end)"
expr(ctrl, "U", "min(max((Q - TearRip)/max(1 - TearRip, 0.001), 0), 1)")
expr(ctrl, "EaseA", EASE .. "(U/(1 - TearStagger))")
expr(ctrl, "EaseB", EASE .. "((U - TearStagger)/(1 - TearStagger))")
expr(ctrl, "Pivot", "(function(a, asp) local s = 0.5*(abs(sin(a)) + abs(cos(a))/asp) "
  .. "return Point(0.5 + cos(a)*TearOffset - sin(a)*s, 0.5 + (sin(a)*TearOffset + cos(a)*s)*asp) end)(math.rad(TearAngle), " .. ASP .. ")")
local function move(sign, ease)
  return "(function(a, asp, e, far) return Point(0.5 + (" .. sign .. "cos(a)*far + sin(a)*0.18)*e, "
    .. "0.5 + (" .. sign .. "sin(a)*far - cos(a)*0.18)*e*asp) end)(math.rad(TearAngle), " .. ASP .. ", " .. ease
    .. ", 0.5*(abs(cos(math.rad(TearAngle))) + abs(sin(math.rad(TearAngle)))/" .. ASP .. ") + abs(TearOffset) + TearRough + 0.05)"
end
expr(ctrl, "MoveA", move("", "EaseA"))
expr(ctrl, "MoveB", move("-", "EaseB"))

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

-- one still picture holds everything about the line that does not change: R distance across the line (in frame
-- widths, with the ragged shape in it), G position along it (0..1), B how wide the white paper core is here, A grain
local base = add("Background", "TearBase", -3, 3)
base:SetInput("UseFrameFormatSettings", 1); base:SetInput("Depth", 4)
local field = add("Custom", "TearField", -1, 3)
field.Image1 = base.Output; field.Image2 = noise.Output
expr(field, "NumberIn1", "TearCtrl.TearOffset")
expr(field, "NumberIn2", "TearCtrl.TearAngle")
expr(field, "NumberIn3", "TearCtrl.TearRough")
L.cx(field, "Intermediate1", "(y - 0.5)*(h/w)*cos(n2) - (x - 0.5)*sin(n2)")
L.cx(field, "Intermediate2", "0.5 + i1/(abs(sin(n2)) + (h/w)*abs(cos(n2)))")
L.cx(field, "RedExpression", "(x - 0.5)*cos(n2) + (y - 0.5)*(h/w)*sin(n2) - n1 - n3*2*(getr2b(0.27, 0.5 + 0.75*i1) - 0.5)")
L.cx(field, "GreenExpression", "i2")
L.cx(field, "BlueExpression", "0.25 + 1.5*getr2b(0.71, frac(i2*3.7))")
L.cx(field, "AlphaExpression", "0.9 + 0.1*getr2b(frac(x*5), frac(y*5))")

-- each half of A on its own, still in place. The rip travels along the line and the gap behind it opens like a
-- wedge, widest where the rip started. Ahead of the rip the far half runs on under the near one, so no seam shows.
local function half(name, sign, under, core, row)
  local t = add("Custom", name, 1, row)
  t.Image1 = srcA.Output; t.Image2 = field.Output
  expr(t, "NumberIn1", "TearCtrl.F")
  expr(t, "NumberIn2", "TearCtrl.TearAngle")
  t:SetInput("NumberIn3", under)
  expr(t, "NumberIn4", "TearCtrl.TearEdge * " .. core)
  expr(t, "NumberIn8", "TearCtrl.TearGap")
  L.cx(t, "Intermediate1", "n8*(min(max((n1 - g2)/0.12, 0), 1) + 2*max(min(n1, 1) - g2, 0))")
  L.cx(t, "Intermediate2", sign .. "r2 - i1 + n3*if(i1 <= 0, 9, 0)")
  L.cx(t, "Intermediate3", "x - (" .. sign .. "i1)*cos(n2)")
  L.cx(t, "Intermediate4", "y - (" .. sign .. "i1)*sin(n2)*w/h")
  L.cx(t, "Intermediate5", "min(max(i2*w + 0.5, 0), 1)*if(min(min(i3, 1 - i3), min(i4, 1 - i4)) < 0, 0, 1)")
  L.cx(t, "Intermediate6", "n4*b2*min(i1/0.004, 1)")
  for _, c in ipairs({"r", "g", "b"}) do
    L.cx(t, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", string.format("i5*if(i2 > i6, get%s1b(i3, i4), a2)", c))
  end
  L.cx(t, "AlphaExpression", "i5")
  local m = add("Transform", name .. "Move", 2, row)
  m.Input = t.Output
  expr(m, "Pivot", "TearCtrl.Pivot")
  return m
end
local moveA = half("TearHalfA", "", 0, "1", 0)
local moveB = half("TearHalfB", "-", 1, "0.5", 1)
expr(moveA, "Center", "TearCtrl.MoveA"); expr(moveA, "Angle", "TearCtrl.TearSwing * TearCtrl.EaseA")
expr(moveB, "Center", "TearCtrl.MoveB"); expr(moveB, "Angle", "-TearCtrl.TearSwing * TearCtrl.EaseB")
local paper = add("Merge", "TearPaper", 3, 0)
paper.Background = moveB.Output; paper.Foreground = moveA.Output
local room = add("SetDomain", "TearRoom", 4, 0)
room.Input = paper.Output; room:SetInput("Mode", "Set")

-- the shadow the halves cast on B: wider, softer and further off as they lift away
local soft = add("Blur", "TearSoft", 4, 1)
soft.Input = room.Output
expr(soft, "XBlurSize", "TearCtrl.TearShadowW * 40 * (1 + 2*TearCtrl.EaseA)")
local shade = add("Custom", "TearShade", 5, 2)
shade.Image1 = srcB.Output; shade.Image2 = soft.Output
expr(shade, "NumberIn1", "TearCtrl.TearShadow")
expr(shade, "NumberIn2", "TearCtrl.TearShadowW * (0.15 + 0.6*TearCtrl.EaseA)")
L.cx(shade, "Intermediate1", "1 - n1*geta2b(x - n2*h/w, y + n2)")
for _, c in ipairs({"r", "g", "b"}) do L.cx(shade, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", c .. "1*i1") end
L.cx(shade, "AlphaExpression", "1")
local over = add("Merge", "TearOver", 5, 0)
over.Background = shade.Output; over.Foreground = room.Output

-- the first and the last frame are the clips themselves, untouched
local cut = add("Custom", "TearCut", 6, 0)
cut.Image1 = srcA.Output; cut.Image2 = srcB.Output; cut.Image3 = over.Output
expr(cut, "NumberIn1", "TearCtrl.P")
for _, c in ipairs({"r", "g", "b"}) do
  L.cx(cut, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, %s3))", c, c, c))
end
L.cx(cut, "AlphaExpression", "1")

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
    {"CTL", "TearCtrl", "TearSwing", "Swing (degrees)"},
    {"CTL", "TearCtrl", "TearStagger", "Second Half Delay"},
    {"CTL", "TearCtrl", "TearSteps", "Stop Motion Steps"},
  })
  srcA.Input = a.Output; srcB.Input = b.Output
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  L.render(comp, cut.Output, os.getenv("FX_PREFIX") or "pt", tonumber(os.getenv("FX_STEPS") or "12"))
end
