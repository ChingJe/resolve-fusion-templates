-- Glitch Hits: at each listed moment the picture breaks up for a fraction of a second, like a bad digital signal.
-- Hits come from one text box, one per line: "0:01.5" or "0:01.5 1.4" (the second number scales that hit).
-- Random bursts can be added on top. FX_EXPORT=1 dumps the macro source. FX_TEXT="0:01|0:02 1.5" overrides the list.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Glitch Hits")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "GhCtrl", {
  {"GhList",   L.text("Hits (0:00 or 0:00 strength)", "0:00.5\n0:01.5\n0:02.5 1.5\n0:03.5", nil, 8)},
  {"GhDur",    L.num("Hit Length (seconds)", 0.3, 0.03, 3)},
  {"GhRandom", L.num("Random Bursts Per 10 Seconds", 0, 0, 30)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"GhAmount", L.num("Strength", 1, 0, 2)},
  {"GhShift",  L.num("Sideways Jump", 0.15, 0, 1)},
  {"GhSplit",  L.num("RGB Split", 0.02, 0, 0.1)},
  {"GhBands",  L.num("Bands", 14, 2, 60, nil, true)},
  {"GhBlocks", L.num("Misplaced Blocks", 0.12, 0, 1)},
  {"GhLines",  L.num("Scan Lines", 0.3, 0, 1)},
  {"GhHold",   L.num("Frames Per Change", 2, 1, 12, nil, true)},
  {"GhSeed",   L.num("Pattern", 0, 0, 50)},
  {"Hit",  L.point("Hit", "Driver")},
  {"Rand", L.num("Rand", 0, 0, 2, "Driver")},
  {"Level", L.num("Level", 0, 0, 4, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
expr(ctrl, "Hit", L.hits("GhList", "GhDur", "0.7"))
-- Random bursts: time is cut into slots of a third of a second and a slot is on when its random number is low enough
expr(ctrl, "Rand", [[(function(ts, per10)
  if per10 <= 0 then return 0 end
  local slot = math.floor(ts*3)
  local v = math.sin(slot*91.17 + GhSeed*7.3)*43758.5453
  v = v - math.floor(v)
  return v < per10/30 and (0.5 + v*30/per10*0.5) or 0
end)((time - comp.RenderStart) / iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), GhRandom)]])
expr(ctrl, "Level", "GhAmount * max(Hit.X, Rand)")

local g = L.glitch(comp, "GhFinal", 1, 1, srcs[1].Output, nil, {
  amount = "GhCtrl.Level", bands = "GhCtrl.GhBands", shift = "GhCtrl.GhShift", split = "GhCtrl.GhSplit",
  step = "floor(time/max(GhCtrl.GhHold, 1))", blocks = "GhCtrl.GhBlocks", lines = "GhCtrl.GhLines", seed = "GhCtrl.GhSeed",
})
mediaOut.Input = g.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "glitchhits", name = "GlitchHits", out = g, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "gh",
  before = function()
    local t = os.getenv("FX_TEXT")
    if t then ctrl:SetInput("GhList", (string.gsub(t, "|", "\n"))) end
  end})
