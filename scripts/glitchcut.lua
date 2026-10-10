-- Glitch Cut transition: the picture breaks up like a bad digital signal and what comes back is the next clip.
-- Bands of lines jump sideways and flicker over to the second clip one after another.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Glitch Cut")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "GcCtrl", {
  {"GcAmount", L.num("Strength", 1, 0, 2)},
  {"GcShift",  L.num("Sideways Jump", 0.25, 0, 1)},
  {"GcSplit",  L.num("RGB Split", 0.02, 0, 0.1)},
  {"GcBands",  L.num("Bands", 14, 2, 60, nil, true)},
  {"GcBlocks", L.num("Misplaced Blocks", 0.15, 0, 1)},
  {"GcLines",  L.num("Scan Lines", 0.3, 0, 1)},
  {"GcHold",   L.num("Frames Per Change", 2, 1, 12, nil, true)},
  {"GcSeed",   L.num("Pattern", 0, 0, 50)},
  {"P", L.num("P", 0, 0, 1, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 2)
-- strongest in the middle, nothing at either end, so the frames next to the cut are untouched
local g = L.glitch(comp, "GcFinal", 1, 1, srcs[1].Output, srcs[2].Output, {
  amount = "iif(GcCtrl.P <= 0 or GcCtrl.P >= 1, 0, GcCtrl.GcAmount * sin(GcCtrl.P*pi)^0.6)",
  mix = "GcCtrl.P", bands = "GcCtrl.GcBands", shift = "GcCtrl.GcShift", split = "GcCtrl.GcSplit",
  step = "floor(time/max(GcCtrl.GcHold, 1))", blocks = "GcCtrl.GcBlocks", lines = "GcCtrl.GcLines", seed = "GcCtrl.GcSeed",
})
mediaOut.Input = g.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "glitchcut", name = "GlitchCut", out = g, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "gc"})
