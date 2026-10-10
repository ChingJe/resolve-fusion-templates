-- Kinetic Lines: lines of text that pop in one after another at the times written in front of them.
-- Lines come from one text box, "0:02 Text", the same notation Chapter Bar uses. A | inside a line is a line break.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXT="0% One|50% Two" overrides the list for a test render (| stands for a new line there),
-- FX_TEXTFILE reads it from a UTF-8 file.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Kinetic Lines")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- Same parser as Chapter Bar: a list of {start as 0..1 of the clip, text}, sorted by start.
local PARSE = [[(function(txt, fps, len)
  local out = {}
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local stamp, name = line:match("^%s*(%S+)%s*(.-)%s*$")
    if stamp then
      local f
      local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
      if pct then f = tonumber(pct) / 100 * len
      elseif fr then f = tonumber(fr)
      elseif stamp:match("^[%d:%.]+$") then
        local sec = 0
        for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
        if sec then f = math.floor(sec * fps + 0.5) end
      end
      if f then out[#out + 1] = {f / len, name} end
    end
  end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end)(KinCtrl.LineList.Value, iif(KinCtrl.FpsOverride > 0, KinCtrl.FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), max(comp.RenderEnd - comp.RenderStart, 1))]]

local ctrl = add("Background", "KinCtrl", -5, -3)
ctrl.UserControls = {
  LineList    = L.text("Lines (0:00 Text)", "0% FIRST LINE\n25% THEN THIS\n50% TWO LINES|IN ONE\n75% LAST ONE", nil, 8),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  KinSize   = L.num("Size", 0.11, 0.02, 0.4),
  KinIn     = L.num("Pop Frames", 8, 1, 40),
  KinOut    = L.num("Fade Out Frames", 3, 0, 40),
  KinBounce = L.num("Bounce", 1, 0, 3),
  KinGrow   = L.num("Grow From", 0.6, 0, 1.5),
  KinRise   = L.num("Rise", 0.04, -0.3, 0.3),
  KinTilt   = L.num("Tilt", 0, -30, 30),
  KinBox    = L.num("Box Opacity", 0, 0, 1),
  KinPadX   = L.num("Box Padding X", 0.25, 0, 1),
  KinPadY   = L.num("Box Padding Y", 0.15, 0, 1),
  KinPos = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Position",
            INPID_PreviewControl = "CrosshairControl", ICS_ControlPage = "Controls"},
  P    = L.num("P", 0, 0, 1, "Driver"),
  T    = L.num("T", 0, 0, 1, "Driver"),
  Back = L.num("Back", 0, 0, 2, "Driver"),
  Fade = L.num("Fade", 0, 0, 1, "Driver"),
  Span = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Span", ICS_ControlPage = "Driver"},
  Idx  = L.num("Idx", 0, 0, 100, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("KinPos", {0.5, 0.5})
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
-- Span: where the line on screen starts and where the next one takes over (-1 before the first line)
expr(ctrl, "Span", string.format([[(function(c, p)
  local a, b = -1, 2
  for i = 1, #c do
    if c[i][1] <= p + 0.000001 then a = c[i][1] elseif c[i][1] < b then b = c[i][1] end
  end
  return Point(a, b)
end)(%s, P)]], PARSE))
expr(ctrl, "Idx", string.format([[(function(c, p)
  local n = 0
  for i = 1, #c do if c[i][1] <= p + 0.000001 then n = i end end
  return n
end)(%s, P)]], PARSE))
-- T: 0..1 through the pop of the current line. Back: the same with an overshoot. Fade: opacity.
expr(ctrl, "T", "iif(Span.X < 0, 0, min(max((P - Span.X)*max(comp.RenderEnd - comp.RenderStart, 1)/max(KinIn, 1), 0), 1))")
expr(ctrl, "Back", "(function(t, s) t = t - 1 return 1 + (s + 1)*t*t*t + s*t*t end)(T, 1.70158*KinBounce)")
expr(ctrl, "Fade", "iif(Span.X < 0, 0, min(T*3, 1) * iif(KinOut <= 0, 1, min(max((Span.Y - P)*max(comp.RenderEnd - comp.RenderStart, 1)/KinOut, 0), 1)))")

local LINE = string.format([[Text((function(c, p)
  local s = ""
  for i = 1, #c do if c[i][1] <= p + 0.000001 then s = c[i][2] end end
  return (s:gsub("%%s*|%%s*", "\n"))
end)(%s, KinCtrl.P))]], PARSE)

local text = add("TextPlus", "Line", -3, 0)
text:SetInput("Font", "Microsoft JhengHei") -- Open Sans has no Chinese glyphs and Text+ does not fall back
text:SetInput("Style", "Bold")
text:SetInput("UseFrameFormatSettings", 1)
expr(text, "StyledText", LINE)
expr(text, "Size", "KinCtrl.KinSize * (KinCtrl.KinGrow + (1 - KinCtrl.KinGrow)*KinCtrl.Back)")
expr(text, "Center", "Point(KinCtrl.KinPos.X, KinCtrl.KinPos.Y - KinCtrl.KinRise*(1 - KinCtrl.Back))")
-- odd lines lean one way, even lines the other
expr(text, "AngleZ", "KinCtrl.KinTilt * iif(KinCtrl.Idx % 2 == 1, 1, -1)")

-- optional box behind the text: a second Text+ that only draws its border fill, so it always fits the words
local box = add("TextPlus", "Box", -3, 2)
box:SetInput("UseFrameFormatSettings", 1)
expr(box, "StyledText", "Line.StyledText")
expr(box, "Font", "Line.Font")
expr(box, "Style", "Line.Style")
expr(box, "Size", "Line.Size")
expr(box, "Center", "Line.Center")
expr(box, "AngleZ", "Line.AngleZ")
box:SetInput("ElementShape1", 2)
box:SetInput("Level1", 0)
box:SetInput("Red1", 0.93); box:SetInput("Green1", 0.16); box:SetInput("Blue1", 0.16)
expr(box, "ExtendHorizontal1", "KinCtrl.KinPadX")
expr(box, "ExtendVertical1", "KinCtrl.KinPadY")

local boxed = add("Merge", "Boxed", -1, 2)
boxed.Background = ctrl.Output
boxed.Foreground = box.Output
expr(boxed, "Blend", "KinCtrl.KinBox * KinCtrl.Fade")
local out = add("Merge", "KinOut", 0, 2)
out.Background = boxed.Output
out.Foreground = text.Output
expr(out, "Blend", "KinCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "kinetic", {
    {"NAME", "KineticLines"},
    {"OUT", "KinOut", "Output"},
    {"CTL", "KinCtrl", "LineList", "Lines (0:00 Text)"},
    {"CTL", "KinCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "Line", "Font", "Font", "2"}, {"CTL", "Line", "Style", "", "2"},
    {"CTL", "KinCtrl", "KinSize", "Size"},
    {"CTL", "Line", "Red1", "Color", "3"}, {"CTL", "Line", "Green1", "", "3"}, {"CTL", "Line", "Blue1", "", "3"},
    {"CTL", "KinCtrl", "KinPos", "Position"},
    {"CTL", "KinCtrl", "KinIn", "Pop Frames"},
    {"CTL", "KinCtrl", "KinOut", "Fade Out Frames"},
    {"CTL", "KinCtrl", "KinBounce", "Bounce"},
    {"CTL", "KinCtrl", "KinGrow", "Grow From"},
    {"CTL", "KinCtrl", "KinRise", "Rise"},
    {"CTL", "KinCtrl", "KinTilt", "Tilt"},
    {"CTL", "KinCtrl", "KinBox", "Box Opacity"},
    {"CTL", "Box", "Red1", "Box Color", "4"}, {"CTL", "Box", "Green1", "", "4"}, {"CTL", "Box", "Blue1", "", "4"},
    {"CTL", "KinCtrl", "KinPadX", "Box Padding X"},
    {"CTL", "KinCtrl", "KinPadY", "Box Padding Y"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local t = os.getenv("FX_TEXT")
  if t then ctrl:SetInput("LineList", (string.gsub(t, "|", "\n"))) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("LineList", file:read("*a")); file:close() end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local dim = add("BrightnessContrast", "PrevDim", -1, 4)
  dim.Input = s.Output; dim:SetInput("Gain", 0.35)
  local pm = add("Merge", "PrevOver", 0, 4)
  pm.Background = dim.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "kl", tonumber(os.getenv("FX_STEPS") or "12"))
end
