-- Time Slice: the frame is cut into strips and every strip lags a few frames behind its neighbour.
-- FX_SRC=media uses the clip, anything else uses the procedural stand-in. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
local MAX = 16
local useMedia = os.getenv("FX_SRC") == "media"

comp:Lock()
comp:StartUndo("Build Time Slice")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "SliceCtrl", -5, -3)
ctrl.UserControls = {
  Slices     = L.num("Slices", 12, 2, MAX, nil, true),
  Delay      = L.num("Delay Per Slice", 3, 0, 12),
  Horizontal = L.check("Horizontal Strips", 0),
  FromCenter = L.check("From Center", 0),
  Reverse    = L.check("Reverse", 0),
  Soft       = L.num("Edge Softness", 0, 0, 0.05),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)

-- single entry point for the clip so the macro has one input to publish
local src = add("BrightnessContrast", "Src", -5, 0)
local source = useMedia and mediaIn.Output or L.testsource(comp).Output
src.Input = source

local last
for k = 0, MAX - 1 do
  local ts = add("TimeStretcher", "Lag" .. (k + 1), -4 + k, 0)
  ts.Input = src.Output
  ts:SetInput("InterpolateBetweenFrames", 0)
  local order = string.format("iif(SliceCtrl.FromCenter == 1, abs(%d - (SliceCtrl.Slices - 1)/2), %d)", k, k)
  local top = "iif(SliceCtrl.FromCenter == 1, (SliceCtrl.Slices - 1)/2, SliceCtrl.Slices - 1)"
  expr(ts, "SourceTime", string.format(
    "max(comp.GlobalStart, time - floor(iif(SliceCtrl.Reverse == 1, %s - %s, %s) * SliceCtrl.Delay))", top, order, order))
  if k == 0 then
    last = ts
  else
    local mask = add("RectangleMask", "Strip" .. (k + 1), -4 + k, 1)
    expr(mask, "Center", string.format(
      "iif(SliceCtrl.Horizontal == 1, Point(0.5, 1 - %g/SliceCtrl.Slices), Point(%g/SliceCtrl.Slices, 0.5))", k + 0.5, k + 0.5))
    expr(mask, "Width", "iif(SliceCtrl.Horizontal == 1, 2, 1/SliceCtrl.Slices + 0.001)")
    expr(mask, "Height", "iif(SliceCtrl.Horizontal == 1, 1/SliceCtrl.Slices + 0.001, 2)")
    expr(mask, "SoftEdge", "SliceCtrl.Soft")
    local m = add("Merge", "Slice" .. (k + 1), -4 + k, 2)
    m.Background = last.Output
    m.Foreground = ts.Output
    m.EffectMask = mask.Mask
    expr(m, "Blend", string.format("iif(%d < SliceCtrl.Slices, 1, 0)", k))
    last = m
  end
end
mediaOut.Input = last.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  src.Input = nil
  L.export(comp, "timeslice", {
    {"NAME", "TimeSlice"},
    {"MAIN", "Src", "Input"},
    {"OUT", last.Name, "Output"},
    {"CTL", "SliceCtrl", "Slices", "Slices"},
    {"CTL", "SliceCtrl", "Delay", "Delay Per Slice"},
    {"CTL", "SliceCtrl", "Horizontal", "Horizontal Strips"},
    {"CTL", "SliceCtrl", "FromCenter", "From Center"},
    {"CTL", "SliceCtrl", "Reverse", "Reverse"},
    {"CTL", "SliceCtrl", "Soft", "Edge Softness"},
  })
  src.Input = source
else
  for _, kv in ipairs({os.getenv("FX_SET") or ""}) do
    for name, value in string.gmatch(kv, "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  end
  L.render(comp, last.Output, os.getenv("FX_PREFIX") or "ts", tonumber(os.getenv("FX_STEPS") or "24"))
end
