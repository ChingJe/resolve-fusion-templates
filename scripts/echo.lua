-- Echo: anything that moves drags fading copies of itself behind it. The copies are earlier frames of the clip
-- laid over the current one. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
local MAX = 8
comp:Lock()
comp:StartUndo("Build Echo")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "EchoCtrl", {
  {"EcCount", L.num("Echoes", 5, 1, MAX, nil, true)},
  {"EcGap",   L.num("Frames Apart", 3, 1, 20, nil, true)},
  {"EcBlend", L.combo("Echoes Show Where They Are", {"Brighter", "Darker", "Anywhere (plain mix)", "Added On Top"}, 0)},
  {"EcStrength", L.num("Strength", 0.8, 0, 1)},
  {"EcDecay", L.num("Each Echo Weaker By", 0.25, 0, 0.9)},
  {"EcAhead", L.check("Echoes Lead Instead Of Trail", 0)},
})
local srcs, ins = L.feeds(comp, ctrl, 1)

-- the oldest echo goes on first, so the newer ones and finally the picture itself end up on top
local last = srcs[1]
for k = MAX, 1, -1 do
  local ts = add("TimeStretcher", "EchoLag" .. k, -4 + k, 2)
  ts.Input = srcs[1].Output
  ts:SetInput("InterpolateBetweenFrames", 0)
  expr(ts, "SourceTime", string.format("min(max(time + iif(EchoCtrl.EcAhead == 1, 1, -1)*%d*EchoCtrl.EcGap, comp.GlobalStart), comp.GlobalEnd)", k))
  local mix = add("Custom", k == 1 and "EchoFinal" or ("EchoMix" .. k), -4 + k, 3)
  mix.Image1 = last.Output; mix.Image2 = ts.Output
  expr(mix, "NumberIn1", string.format("iif(%d <= EchoCtrl.EcCount, EchoCtrl.EcStrength * (1 - EchoCtrl.EcDecay)^%d, 0)", k, k - 1))
  expr(mix, "NumberIn2", "EchoCtrl.EcBlend")
  for _, c in ipairs({"r", "g", "b"}) do
    mix:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
      string.format("if(n2 == 0, max(%s1, %s2*n1), if(n2 == 1, %s1 + (min(%s1, %s2) - %s1)*n1, if(n2 == 2, %s1 + (%s2 - %s1)*n1*0.5, %s1 + %s2*n1*0.5)))",
        c, c, c, c, c, c, c, c, c, c, c))
  end
  mix:SetInput("AlphaExpression", "a1")
  last = mix
end
-- Brighter, Darker and Added start from the picture itself. The plain mix needs the picture on top again.
mediaOut.Input = last.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "echo", name = "Echo", out = last, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "ec"})
