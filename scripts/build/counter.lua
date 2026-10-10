-- Number Counter: counts from one value to another over the title clip, with separators, prefix and suffix.
-- Or a tally: with Counts set to the second choice the number goes up by one step at each time in a list.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Number Counter")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "CountCtrl", -5, -3)
ctrl.UserControls = {
  CntMode     = L.combo("Counts", {"Smoothly To The End Value", "One Step At Each Listed Time"}, 0),
  CntStart    = L.num("Start Value", 0, 0, 1000),
  CntEnd      = L.num("End Value", 12500, 0, 100000),
  CntDecimals = L.num("Decimals", 0, 0, 3, nil, true),
  CntSep      = L.check("Thousands Separator", 1),
  CntPrefix   = L.text("Prefix", ""),
  CntSuffix   = L.text("Suffix", ""),
  CntFinish   = L.num("Count Finishes At", 0.7, 0.05, 1),
  CntTimes    = L.text("Step Times (0:02, one per line)", "20%\n40%\n60%\n80%", nil, 6),
  CntStep     = L.num("Each Step Adds", 1, -10, 10),
  CntPopTime  = L.num("Step Pop (seconds)", 0.25, 0.02, 1),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  CntPop      = L.num("Pop", 0.12, 0, 0.5),
  CntSize     = L.num("Size", 0.18, 0.02, 0.5),
  P = L.num("P", 0, 0, 1, "Driver"),
  V = L.num("V", 0, 0, 100000, "Driver"),
  Bump = L.num("Bump", 0, 0, 1, "Driver"),
  Tal = L.point("Tal", "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
-- fast at first, settling on the end value exactly when P reaches Count Finishes At
-- Tal: how many of the listed times have passed, and the seconds since the latest one. Times are separated by
-- new lines, spaces or commas, each written the way docs/time-list.md describes.
expr(ctrl, "Tal", [[(function(txt, fps, len, ts)
  local n, last = 0, -1
  for stamp in txt:gmatch("[^%s,]+") do
    local sec
    local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
    if pct then sec = tonumber(pct) / 100 * len / fps
    elseif fr then sec = tonumber(fr) / fps
    elseif stamp:match("^[%d:%.]+$") then
      sec = 0
      for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
    end
    if sec and sec <= ts + 0.0001 then n = n + 1 if sec > last then last = sec end end
  end
  return Point(n, last < 0 and 999 or ts - last)
end)(CntTimes.Value, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24),
  max(comp.RenderEnd - comp.RenderStart, 1),
  (time - comp.RenderStart) / iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24))]])
expr(ctrl, "V", "iif(CntMode == 1, CntStart + CntStep*Tal.X, CntStart + (CntEnd - CntStart) * (1 - (1 - min(P/CntFinish, 1))^3))")
-- a tally jumps up in size on each step and settles back
expr(ctrl, "Bump", "iif(CntMode == 1, CntPop * (1 - min(Tal.Y/max(CntPopTime, 0.01), 1))^2, CntPop * sin(3.14159265 * min(max((P - CntFinish)/0.06, 0), 1)))")

local text = add("TextPlus", "Number", -3, 0)
text:SetInput("Font", "Open Sans")
text:SetInput("Style", "Bold")
text:SetInput("UseFrameFormatSettings", 1)
expr(text, "StyledText", [[Text(CountCtrl.CntPrefix.Value .. (function(v, d, sep)
  local s = string.format("%." .. d .. "f", v)
  local whole, rest = s:match("^(-?%d+)(.*)$")
  if sep == 1 then whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1") end
  return whole .. rest
end)(CountCtrl.V, CountCtrl.CntDecimals, CountCtrl.CntSep) .. CountCtrl.CntSuffix.Value)]])
expr(text, "Size", "CountCtrl.CntSize * (1 + CountCtrl.Bump)")

mediaOut.Input = text.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "counter", {
    {"NAME", "NumberCounter"},
    {"OUT", "Number", "Output"},
    {"CTL", "CountCtrl", "CntMode", "Counts"},
    {"CTL", "CountCtrl", "CntStart", "Start Value"},
    {"CTL", "CountCtrl", "CntEnd", "End Value"},
    {"CTL", "CountCtrl", "CntDecimals", "Decimals"},
    {"CTL", "CountCtrl", "CntSep", "Thousands Separator"},
    {"CTL", "CountCtrl", "CntPrefix", "Prefix"},
    {"CTL", "CountCtrl", "CntSuffix", "Suffix"},
    {"CTL", "CountCtrl", "CntFinish", "Count Finishes At"},
    {"CTL", "CountCtrl", "CntTimes", "Step Times (0:02, one per line)"},
    {"CTL", "CountCtrl", "CntStep", "Each Step Adds"},
    {"CTL", "CountCtrl", "CntPopTime", "Step Pop (seconds)"},
    {"CTL", "CountCtrl", "CntPop", "Pop"},
    {"CTL", "CountCtrl", "CntSize", "Size"},
    {"CTL", "Number", "Font", "Font", "2"}, {"CTL", "Number", "Style", "", "2"},
    {"CTL", "Number", "Red1", "Color", "3"}, {"CTL", "Number", "Green1", "", "3"}, {"CTL", "Number", "Blue1", "", "3"},
    {"CTL", "Number", "Center", "Position"},
    {"CTL", "CountCtrl", "FpsOverride", "Frame Rate Override"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  for name, value in string.gmatch(os.getenv("FX_TEXT") or "", "(%w+)=([^;]+)") do ctrl:SetInput(name, value) end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local dim = add("BrightnessContrast", "PrevDim", -1, 3)
  dim.Input = s.Output; dim:SetInput("Gain", 0.35)
  local pm = add("Merge", "PrevOver", 0, 3)
  pm.Background = dim.Output; pm.Foreground = text.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "nc", tonumber(os.getenv("FX_STEPS") or "12"))
end
