-- Number Counter: counts from one value to another over the title clip, with separators, prefix and suffix.
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
  CntStart    = L.num("Start Value", 0, 0, 1000),
  CntEnd      = L.num("End Value", 12500, 0, 100000),
  CntDecimals = L.num("Decimals", 0, 0, 3, nil, true),
  CntSep      = L.check("Thousands Separator", 1),
  CntPrefix   = L.text("Prefix", ""),
  CntSuffix   = L.text("Suffix", ""),
  CntFinish   = L.num("Count Finishes At", 0.7, 0.05, 1),
  CntPop      = L.num("Pop", 0.12, 0, 0.5),
  CntSize     = L.num("Size", 0.18, 0.02, 0.5),
  P = L.num("P", 0, 0, 1, "Driver"),
  V = L.num("V", 0, 0, 100000, "Driver"),
  Bump = L.num("Bump", 0, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
-- fast at first, settling on the end value exactly when P reaches Count Finishes At
expr(ctrl, "V", "CntStart + (CntEnd - CntStart) * (1 - (1 - min(P/CntFinish, 1))^3)")
expr(ctrl, "Bump", "CntPop * sin(3.14159265 * min(max((P - CntFinish)/0.06, 0), 1))")

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
    {"CTL", "CountCtrl", "CntStart", "Start Value"},
    {"CTL", "CountCtrl", "CntEnd", "End Value"},
    {"CTL", "CountCtrl", "CntDecimals", "Decimals"},
    {"CTL", "CountCtrl", "CntSep", "Thousands Separator"},
    {"CTL", "CountCtrl", "CntPrefix", "Prefix"},
    {"CTL", "CountCtrl", "CntSuffix", "Suffix"},
    {"CTL", "CountCtrl", "CntFinish", "Count Finishes At"},
    {"CTL", "CountCtrl", "CntPop", "Pop"},
    {"CTL", "CountCtrl", "CntSize", "Size"},
    {"CTL", "Number", "Font", "Font", "2"}, {"CTL", "Number", "Style", "", "2"},
    {"CTL", "Number", "Red1", "Color", "3"}, {"CTL", "Number", "Green1", "", "3"}, {"CTL", "Number", "Blue1", "", "3"},
    {"CTL", "Number", "Center", "Position"},
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
