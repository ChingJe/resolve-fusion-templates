-- Line Art Reveal: the clip starts as an ink drawing on paper, then a scan line sweeps across and
-- leaves the real picture behind. FX_SRC=media uses the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local useMedia = os.getenv("FX_SRC") == "media"

comp:Lock()
comp:StartUndo("Build Line Art Reveal")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "SketchCtrl", -5, -3)
ctrl.UserControls = {
  SktStart   = L.num("Reveal Start", 0.2, 0, 1),
  SktEnd     = L.num("Reveal End", 0.8, 0, 1),
  SktAngle   = L.num("Sweep Angle", 0, -180, 180),
  SktSoft    = L.num("Sweep Softness", 0.06, 0.001, 0.5),
  SktGlow    = L.num("Scan Line Glow", 0.6, 0, 2),
  SktWidth   = L.num("Line Width", 1.5, 0.5, 6),
  SktGain    = L.num("Line Strength", 6, 0.5, 20),
  SktSmooth  = L.num("Detail Smoothing", 1.5, 0, 10),
  SktReverse = L.check("Reverse (Picture To Drawing)", 0),
  P = L.num("P", 0, 0, 1, "Driver"),
  T = L.num("T", 0, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
expr(ctrl, "P", L.P)
expr(ctrl, "T", "(function(t) return iif(SktReverse == 1, 1 - t, t) end)(min(max((P - SktStart)/max(SktEnd - SktStart, 0.001), 0), 1))")

local src = add("BrightnessContrast", "Src", -5, 0)
local source = useMedia and mediaIn.Output or L.testsource(comp).Output
src.Input = source

local smooth = add("Blur", "Smooth", -4, 1)
smooth.Input = src.Output
expr(smooth, "XBlurSize", "SketchCtrl.SktSmooth")

local paper = add("Background", "Paper", -4, 2)
L.color(paper, 0.96, 0.95, 0.91)
local ink = add("Background", "Ink", -4, 3)
L.color(ink, 0.08, 0.09, 0.14)
for _, t in ipairs({paper, ink}) do t:SetInput("UseFrameFormatSettings", 1) end

-- edge strength from the brightness difference of the four neighbours, drawn as ink on paper
local sketch = add("Custom", "Sketch", -3, 1)
sketch.Image1 = smooth.Output
sketch.Image2 = paper.Output
sketch.Image3 = ink.Output
expr(sketch, "NumberIn1", "SketchCtrl.SktWidth")
expr(sketch, "NumberIn2", "SketchCtrl.SktGain")
local function lum(dx, dy)
  local px, py = "x" .. dx, "y" .. dy
  return string.format("0.299*getr1d(%s, %s) + 0.587*getg1d(%s, %s) + 0.114*getb1d(%s, %s)", px, py, px, py, px, py)
end
sketch:SetInput("Intermediate1", lum(" + n1/w", ""))
sketch:SetInput("Intermediate2", lum(" - n1/w", ""))
sketch:SetInput("Intermediate3", lum("", " + n1/h"))
sketch:SetInput("Intermediate4", lum("", " - n1/h"))
sketch:SetInput("Intermediate5", "min(sqrt((i1 - i2)^2 + (i3 - i4)^2)*n2, 1)")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local l = string.lower(string.sub(c, 1, 1))
  sketch:SetInput(c .. "Expression", string.format("%s2*(1 - i5) + %s3*i5", l, l))
end
sketch:SetInput("AlphaExpression", "1")

-- the sweep: i1 is the position of a pixel along the sweep direction, i3 where the scan line is now
local reveal = add("Custom", "Reveal", -2, 0)
reveal.Image1 = src.Output
reveal.Image2 = sketch.Output
expr(reveal, "NumberIn1", "SketchCtrl.T")
expr(reveal, "NumberIn2", "SketchCtrl.SktAngle")
expr(reveal, "NumberIn3", "SketchCtrl.SktSoft")
expr(reveal, "NumberIn4", "SketchCtrl.SktGlow")
reveal:SetInput("Intermediate1", "(x - 0.5)*cos(n2) + (y - 0.5)*sin(n2)")
reveal:SetInput("Intermediate2", "0.5*(abs(cos(n2)) + abs(sin(n2)))")
reveal:SetInput("Intermediate3", "-i2 - n3 + n1*(2*i2 + 2*n3)")
reveal:SetInput("Intermediate4", "min(max((i3 - i1)/n3, 0), 1)")
reveal:SetInput("Intermediate5", "max(1 - abs(i3 - i1 - n3*0.5)/0.01, 0) * n4 * if(n1 <= 0, 0, if(n1 >= 1, 0, 1))")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local l = string.lower(string.sub(c, 1, 1))
  reveal:SetInput(c .. "Expression", string.format("if(n1 >= 1, %s1, %s2 + (%s1 - %s2)*i4 + i5)", l, l, l, l))
end
reveal:SetInput("AlphaExpression", "1")

mediaOut.Input = reveal.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  src.Input = nil
  L.export(comp, "lineart", {
    {"NAME", "LineArtReveal"},
    {"MAIN", "Src", "Input"},
    {"OUT", "Reveal", "Output"},
    {"CTL", "SketchCtrl", "SktStart", "Reveal Start"},
    {"CTL", "SketchCtrl", "SktEnd", "Reveal End"},
    {"CTL", "SketchCtrl", "SktReverse", "Reverse (Picture To Drawing)"},
    {"CTL", "SketchCtrl", "SktAngle", "Sweep Angle"},
    {"CTL", "SketchCtrl", "SktSoft", "Sweep Softness"},
    {"CTL", "SketchCtrl", "SktGlow", "Scan Line Glow"},
    {"CTL", "SketchCtrl", "SktWidth", "Line Width"},
    {"CTL", "SketchCtrl", "SktGain", "Line Strength"},
    {"CTL", "SketchCtrl", "SktSmooth", "Detail Smoothing"},
    {"CTL", "Paper", "TopLeftRed", "Paper Color", "2"}, {"CTL", "Paper", "TopLeftGreen", "", "2"}, {"CTL", "Paper", "TopLeftBlue", "", "2"},
    {"CTL", "Ink", "TopLeftRed", "Ink Color", "3"}, {"CTL", "Ink", "TopLeftGreen", "", "3"}, {"CTL", "Ink", "TopLeftBlue", "", "3"},
  })
  src.Input = source
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  L.render(comp, reveal.Output, os.getenv("FX_PREFIX") or "la", tonumber(os.getenv("FX_STEPS") or "12"))
end
