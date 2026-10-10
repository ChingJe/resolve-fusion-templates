-- Colour Bars transition: bands of flat colour sweep across the picture one after another and leave the next
-- clip behind them, the way variety shows change topic. The frame can be split into rows that start one after another.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Colour Bars")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- five colours per palette, in the order the bands arrive
local PALETTES = {
  {"Custom"},
  {"Variety",  {1.00,0.85,0.10, 1.00,0.35,0.55, 0.15,0.75,0.95, 0.45,0.85,0.25, 1.00,0.55,0.10}},
  {"Candy",    {1.00,0.72,0.80, 0.72,0.88,1.00, 1.00,0.95,0.70, 0.78,0.95,0.80, 0.86,0.78,1.00}},
  {"News",     {0.80,0.05,0.10, 1.00,1.00,1.00, 0.05,0.15,0.45, 1.00,1.00,1.00, 0.80,0.05,0.10}},
  {"Neon",     {1.00,0.10,0.60, 0.10,1.00,0.90, 0.95,1.00,0.10, 0.45,0.20,1.00, 0.10,0.10,0.12}},
  {"Mono",     {0.08,0.08,0.08, 0.95,0.95,0.95, 0.08,0.08,0.08, 0.95,0.95,0.95, 0.08,0.08,0.08}},
}
local names, rows = {}, {}
for i, p in ipairs(PALETTES) do
  names[i] = p[1]
  if p[2] then rows[#rows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
end
local TABLE = "({" .. table.concat(rows, ",") .. "})"

local ctrl, spec = L.panel(comp, "BarCtrl", {
  {"BwDir",    L.combo("Bars Move", {"Right", "Left", "Up", "Down"}, 0)},
  {"BwSlant",  L.num("Slant", 20, -60, 60)},
  {"BwCount",  L.num("Bars", 4, 1, 5, nil, true)},
  {"BwWidth",  L.num("Bar Width", 0.18, 0.02, 0.6)},
  {"BwRows",   L.num("Rows", 1, 1, 12, nil, true)},
  {"BwStagger", L.num("Row Delay", 0.3, 0, 1)},
  {"BwAlt",    L.check("Rows Alternate Direction", 0)},
  {"BwEase",   L.num("Ease", 1.6, 1, 4)},
  {"BwPalette", L.combo("Colours", names, 1)},
  {"P", L.num("P", 0, 0, 1, "Driver")},
  {"S", L.num("S", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 2)
expr(ctrl, "S", "iif(P < 0.5, 0.5*(2*P)^BwEase, 1 - 0.5*(2 - 2*P)^BwEase)")

-- the palette as a strip of five flat patches (ten pixels each, sampling a one pixel patch blends its neighbours in), so the cut only needs to know which band a pixel is in
for k = 1, 5 do
  local h = add("Background", "ColBar" .. k, -3 + k, -5)
  h:SetInput("UseFrameFormatSettings", 0); h:SetInput("Width", 16); h:SetInput("Height", 16)
  local c = PALETTES[2][2]
  L.color(h, c[k*3 - 2], c[k*3 - 1], c[k*3], 1)
end
local strip = add("Background", "BarStripBase", -3, 3)
strip:SetInput("UseFrameFormatSettings", 0); strip:SetInput("Width", 50); strip:SetInput("Height", 4); strip:SetInput("Depth", 4)
local pal = add("Custom", "BarStrip", -2, 3)
pal.Image1 = strip.Output
local ref = {"n1", "n2", "n3", "n4", "n5", "n6", "n7", "n8", "p1x", "p1y", "p2x", "p2y", "p3x", "p3y", "p4x"}
local function colour(k, ch)
  return string.format("iif(BarCtrl.BwPalette == 0, ColBar%d.TopLeft%s, %s[max(BarCtrl.BwPalette, 1)][%d])",
    k, ({"Red", "Green", "Blue"})[ch], TABLE, (k - 1)*3 + ch)
end
local flat = {}
for k = 1, 5 do for ch = 1, 3 do flat[#flat + 1] = colour(k, ch) end end
for i = 1, 8 do expr(pal, "NumberIn" .. i, flat[i]) end
expr(pal, "PointIn1", "Point(" .. flat[9] .. ", " .. flat[10] .. ")")
expr(pal, "PointIn2", "Point(" .. flat[11] .. ", " .. flat[12] .. ")")
expr(pal, "PointIn3", "Point(" .. flat[13] .. ", " .. flat[14] .. ")")
expr(pal, "PointIn4", "Point(" .. flat[15] .. ", 0)")
local function pick(ch)
  local e = ref[12 + ch]
  for k = 4, 1, -1 do e = string.format("if(x < %g, %s, %s)", k/5, ref[(k - 1)*3 + ch], e) end
  return e
end
pal:SetInput("RedExpression", pick(1)); pal:SetInput("GreenExpression", pick(2))
pal:SetInput("BlueExpression", pick(3)); pal:SetInput("AlphaExpression", "1")

local cut = add("Custom", "BarFinal", 1, 1)
cut.Image1 = srcs[1].Output; cut.Image2 = srcs[2].Output; cut.Image3 = pal.Output
expr(cut, "NumberIn1", "BarCtrl.P")
expr(cut, "NumberIn2", "BarCtrl.S")
expr(cut, "NumberIn3", "BarCtrl.BwDir")
expr(cut, "NumberIn4", "tan(BarCtrl.BwSlant*pi/180)")
expr(cut, "NumberIn5", "BarCtrl.BwCount")
expr(cut, "NumberIn6", "BarCtrl.BwWidth")
expr(cut, "NumberIn7", "BarCtrl.BwRows")
expr(cut, "NumberIn8", "iif(BarCtrl.BwRows > 1, BarCtrl.BwStagger, 0)")
expr(cut, "PointIn1", "Point(BarCtrl.BwAlt, 0)")
-- i1 along the move (0 where the bars enter, 1 where they leave), i2 across it, both 0..1
cut:SetInput("Intermediate1", "if(n3 == 0, x, if(n3 == 1, 1 - x, if(n3 == 2, y, 1 - y)))")
cut:SetInput("Intermediate2", "if(n3 < 2, y, x)")
-- i3 which row, i4 its delay 0..1
cut:SetInput("Intermediate3", "min(floor(i2*n7), n7 - 1)")
cut:SetInput("Intermediate4", "if(n7 > 1, i3/(n7 - 1), 0)")
-- i5 how much the slant shifts the bars from one edge of the frame to the other
cut:SetInput("Intermediate5", "abs(n4)*if(n3 < 2, h/w, w/h)")
-- i6 the same position with the slant taken out and, in alternate rows, turned round
cut:SetInput("Intermediate6", "if(p1x > 0 && frac(i3/2) > 0.25, 1 - i1, i1) + n4*(i2 - 0.5)*if(n3 < 2, h/w, w/h)")
-- i7 how far the front of the first bar has come in this row. It has to cross the frame, the slant and all the bars.
cut:SetInput("Intermediate7", "min(max(n2*(1 + n8) - n8*i4, 0), 1)*(1 + i5 + n5*n6) - i5*0.5")
-- i8 how far behind the front this pixel is, in bars
cut:SetInput("Intermediate8", "(i7 - i6)/n6")
local function chan(c)
  return string.format("if(n1 <= 0, %s1, if(n1 >= 1, %s2, if(i8 < 0, %s1, if(i8 >= n5, %s2, get%s3b((floor(i8) + 0.5)/5, 0.5)))))", c, c, c, c, c)
end
cut:SetInput("RedExpression", chan("r")); cut:SetInput("GreenExpression", chan("g"))
cut:SetInput("BlueExpression", chan("b")); cut:SetInput("AlphaExpression", "1")

mediaOut.Input = cut.Output
comp:EndUndo(true)
comp:Unlock()
for k = 1, 5 do
  local g = tostring(k + 2)
  spec[#spec + 1] = {"CTL", "ColBar" .. k, "TopLeftRed", "Custom Colour " .. k, g}
  spec[#spec + 1] = {"CTL", "ColBar" .. k, "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", "ColBar" .. k, "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "barwipe", name = "ColourBars", out = cut, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "bw"})
