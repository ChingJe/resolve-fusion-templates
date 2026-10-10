-- Handmade: makes the clip look animated by hand. It moves in steps like stop motion, every step sits a little
-- differently on the table, the outlines wobble, colours are cut down to a few flat steps and paper grain shows through.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Handmade")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "HandCtrl", {
  {"HmHold",   L.num("Frames Per Step", 4, 1, 24, nil, true)},
  {"HmShift",  L.num("Jitter", 0.004, 0, 0.03)},
  {"HmTurn",   L.num("Jitter Rotation", 0.4, 0, 5)},
  {"HmBoil",   L.num("Wobbly Outlines", 0.003, 0, 0.02)},
  {"HmBoilSize", L.num("Wobble Size", 8, 1, 40)},
  {"HmSteps",  L.num("Colour Steps (0 = off)", 0, 0, 16, nil, true)},
  {"HmGrain",  L.num("Paper Grain", 0.25, 0, 1)},
  {"HmFlicker", L.num("Light Flicker", 0.05, 0, 0.5)},
  {"HmEdge",   L.num("Dark Corners", 0.25, 0, 1)},
  {"Step", L.num("Step", 0, 0, 1e6, "Driver")},
  {"Nudge", L.point("Nudge", "Driver")},
  {"Twist", L.num("Twist", 0, -10, 10, "Driver")},
  {"Light", L.num("Light", 1, 0, 2, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
expr(ctrl, "Step", "floor((time - comp.RenderStart)/max(HmHold, 1))")
local RAND = "(function(s) local v = math.sin(Step*12.9898 + s)*43758.5453 return (v - math.floor(v))*2 - 1 end)"
expr(ctrl, "Nudge", "Point(HmShift*" .. RAND .. "(1.3), HmShift*" .. RAND .. "(7.7))")
expr(ctrl, "Twist", "HmTurn*" .. RAND .. "(4.1)")
expr(ctrl, "Light", "1 + HmFlicker*" .. RAND .. "(9.9)")

local hold = add("TimeStretcher", "HandHold", -3, 1)
hold.Input = srcs[1].Output
hold:SetInput("InterpolateBetweenFrames", 0)
expr(hold, "SourceTime", "comp.RenderStart + HandCtrl.Step*max(HandCtrl.HmHold, 1)")

-- one noise picture for the wobble (it changes with every step) and one for the paper (it never changes)
local function noise(name, y, detail, scale)
  local n = add("FastNoise", name, -3, y)
  n:SetInput("UseFrameFormatSettings", 0); n:SetInput("Width", 960); n:SetInput("Height", 540); n:SetInput("Depth", 4)
  n:SetInput("Detail", detail); n:SetInput("Contrast", 1.5); n:SetInput("SeetheRate", 0)
  if scale then n:SetInput("XScale", scale) end
  return n
end
local boil = noise("HandBoil", 3, 2)
expr(boil, "XScale", "HandCtrl.HmBoilSize")
expr(boil, "Seethe", "HandCtrl.Step*0.37")
local paper = noise("HandPaper", 4, 10, 60)

local look = add("Custom", "HandFinal", 1, 1)
look.Image1 = hold.Output; look.Image2 = boil.Output; look.Image3 = paper.Output
expr(look, "NumberIn1", "HandCtrl.HmBoil")
expr(look, "NumberIn2", "HandCtrl.Twist")
expr(look, "NumberIn3", "HandCtrl.HmSteps")
expr(look, "NumberIn4", "HandCtrl.HmGrain")
expr(look, "NumberIn5", "HandCtrl.Light")
expr(look, "NumberIn6", "HandCtrl.HmEdge")
-- a little extra zoom so that the jitter never shows the edge of the picture
expr(look, "NumberIn7", "1 + 2*HandCtrl.HmShift + 0.02*HandCtrl.HmTurn + 2*HandCtrl.HmBoil")
expr(look, "PointIn1", "HandCtrl.Nudge")
-- i1, i2: the wobble, read from two different places of the noise so x and y differ
look:SetInput("Intermediate1", "(getr2b(x, y) - 0.5)*2*n1")
look:SetInput("Intermediate2", "(getr2b(frac(x + 0.37), frac(y + 0.61)) - 0.5)*2*n1*w/h")
look:SetInput("Intermediate3", "0.5 + ((x - 0.5)*cos(n2) - (y - 0.5)*(h/w)*sin(n2))/n7 + p1x + i1")
look:SetInput("Intermediate4", "0.5 + ((x - 0.5)*(w/h)*sin(n2) + (y - 0.5)*cos(n2))/n7 + p1y + i2")
look:SetInput("Intermediate5", "(1 - n4*0.5 + n4*getr3b(x, y))*n5*(1 - n6*min(((x - 0.5)^2 + (y - 0.5)^2)*2.2, 1))")
for _, c in ipairs({"r", "g", "b"}) do
  local pic = string.format("get%s1d(i3, i4)", c)
  look:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("if(n3 >= 2, floor(%s*n3 + 0.5)/n3, %s)*i5", pic, pic))
end
look:SetInput("AlphaExpression", "a1")

mediaOut.Input = look.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "handmade", name = "Handmade", out = look, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "hm"})
