-- Chapter Bar: a progress bar that runs for as long as the title clip does, split into named chapters.
-- Chapters come from one text box, one per line, "0:00 Name" like a YouTube description.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXT="0:00 Intro|0:02 Next" overrides the chapter list for a test render (| stands for a new line).
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local SPLITS = 19 -- chapter boundaries the bar can show as gaps; names work for any number of chapters

comp:Lock()
comp:StartUndo("Build Chapter Bar")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- Turns the chapter text into a list of {start as 0..1 of the clip, name}, sorted by start.
-- A line is "<when> <name>". <when> can be:
--   1:25  1:02:03  0:07.5  42     time from the start of the title clip; the last part is seconds
--   120f                          a frame count
--   25%                           a share of the clip length
-- Times are rounded to whole frames. Lines that do not start with one of these are ignored.
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
end)(BarCtrl.ChapterList.Value, iif(BarCtrl.FpsOverride > 0, BarCtrl.FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), max(comp.RenderEnd - comp.RenderStart, 1))]]

local ctrl = add("Background", "BarCtrl", -5, -3)
local uc = {
  ChapterList = L.text("Chapters (0:00 Name)", "0% Intro\n25% Part 1\n50% Part 2\n75% Outro", nil, 8),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  BarY      = L.num("Bar Position", 0.06, 0, 1),
  BarH      = L.num("Bar Height", 0.012, 0.002, 0.05),
  BarMargin = L.num("Side Margin", 0.04, 0, 0.3),
  BarGap    = L.num("Chapter Gap", 0.004, 0, 0.02),
  TrackOpacity = L.num("Track Opacity", 0.35, 0, 1),
  Knob      = L.num("Knob Size", 1.3, 0, 3),
  ShowLabel = L.check("Show Chapter Name", 1),
  LabelSize = L.num("Name Size", 0.035, 0.01, 0.1),
  P         = L.num("P", 0, 0, 1, "Driver"),
  LabelFade = L.num("LabelFade", 1, 0, 1, "Driver"),
  Span = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Span", ICS_ControlPage = "Driver"},
}
for k = 1, SPLITS do uc["S" .. k] = L.num("S" .. k, 2, 0, 2, "Driver") end
ctrl.UserControls = uc
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
-- S1..: the k-th boundary that lies inside the clip, or 2 when there is none
for k = 1, SPLITS do
  expr(ctrl, "S" .. k, string.format([[(function(c)
  local n = 0
  for i = 1, #c do
    if c[i][1] > 0.0001 then n = n + 1; if n == %d then return c[i][1] end end
  end
  return 2
end)(%s)]], k, PARSE))
end
-- Span: where the chapter being played starts and ends (0..1)
expr(ctrl, "Span", string.format([[(function(c, p)
  local a, b = 0, 1
  for i = 1, #c do
    if c[i][1] <= p + 0.000001 then a = c[i][1] elseif c[i][1] < b then b = c[i][1] end
  end
  return Point(max(a, 0), min(b, 1))
end)(%s, P)]], PARSE))
expr(ctrl, "LabelFade",
  "iif(Span.X <= 0, 1, min(max((time - comp.RenderStart - Span.X*(comp.RenderEnd - comp.RenderStart))/10, 0), 1))")

local track = add("Background", "Track", -4, -1)
L.color(track, 1, 1, 1)
local fill = add("Background", "Fill", -4, 1)
L.color(fill, 0.93, 0.16, 0.16)
for _, t in ipairs({track, fill}) do t:SetInput("UseFrameFormatSettings", 1) end

-- A Custom tool only takes sixteen numbers, so the gaps are cut in two passes: nine here, ten more below.
local function nearest(names)
  local e = string.format("abs(i1 - %s)", names[1])
  for i = 2, #names do e = string.format("min(%s, abs(i1 - %s))", e, names[i]) end
  return e
end
local bar = add("Custom", "BarDraw", -3, 0)
bar.Image1 = track.Output
bar.Image2 = fill.Output
expr(bar, "NumberIn1", "BarCtrl.P")
expr(bar, "NumberIn2", "BarCtrl.BarY")
expr(bar, "NumberIn3", "BarCtrl.BarH")
expr(bar, "NumberIn4", "BarCtrl.BarMargin")
expr(bar, "NumberIn5", "BarCtrl.BarGap")
expr(bar, "NumberIn6", "BarCtrl.TrackOpacity")
expr(bar, "NumberIn8", "BarCtrl.S1")
for i = 1, 4 do expr(bar, "PointIn" .. i, string.format("Point(BarCtrl.S%d, BarCtrl.S%d)", 2 * i, 2 * i + 1)) end
bar:SetInput("Intermediate1", "(x - n4)/(1 - 2*n4)")
bar:SetInput("Intermediate2", "if(abs(y - n2) < n3/2, 1, 0) * if(i1 >= 0, 1, 0) * if(i1 <= 1, 1, 0)")
bar:SetInput("Intermediate3", nearest({"n8", "p1x", "p1y", "p2x", "p2y", "p3x", "p3y", "p4x", "p4y"}))
bar:SetInput("Intermediate4", "i2 * if(i3 > n5/2, 1, 0)")
bar:SetInput("Intermediate5", "if(i1 <= n1, 1, 0)")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local l = string.lower(string.sub(c, 1, 1))
  bar:SetInput(c .. "Expression", string.format("i4 * if(i5 > 0, %s2, %s1*n6)", l, l))
end
bar:SetInput("AlphaExpression", "i4 * if(i5 > 0, 1, n6)")

local cut = add("Custom", "BarCut", -2, 0)
cut.Image1 = bar.Output
cut.Image2 = fill.Output
expr(cut, "NumberIn1", "BarCtrl.P")
expr(cut, "NumberIn2", "BarCtrl.BarY")
expr(cut, "NumberIn3", "BarCtrl.BarH")
expr(cut, "NumberIn4", "BarCtrl.BarMargin")
expr(cut, "NumberIn5", "BarCtrl.BarGap")
expr(cut, "NumberIn6", "BarCtrl.Knob")
expr(cut, "NumberIn7", "BarCtrl.S10")
expr(cut, "NumberIn8", "BarCtrl.S11")
for i = 1, 4 do expr(cut, "PointIn" .. i, string.format("Point(BarCtrl.S%d, BarCtrl.S%d)", 10 + 2 * i, 11 + 2 * i)) end
cut:SetInput("Intermediate1", "(x - n4)/(1 - 2*n4)")
cut:SetInput("Intermediate2", nearest({"n7", "n8", "p1x", "p1y", "p2x", "p2y", "p3x", "p3y", "p4x", "p4y"}))
cut:SetInput("Intermediate3", "if(i2 > n5/2, 1, 0)")
cut:SetInput("Intermediate4", "if(sqrt(((x - n4 - n1*(1 - 2*n4))*w/h)^2 + (y - n2)^2) < n3*n6/2, 1, 0)")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local l = string.lower(string.sub(c, 1, 1))
  cut:SetInput(c .. "Expression", string.format("if(i4 > 0, %s2, %s1*i3)", l, l))
end
cut:SetInput("AlphaExpression", "if(i4 > 0, 1, a1*i3)")

-- the name of the chapter being played, centred over its own stretch of the bar
local label = add("TextPlus", "Label", -3, -2)
label:SetInput("Font", "Microsoft JhengHei") -- Open Sans has no Chinese glyphs and Text+ does not fall back
label:SetInput("Style", "Bold")
label:SetInput("UseFrameFormatSettings", 1)
expr(label, "StyledText", string.format([[Text((function(c, p)
  local name = ""
  for i = 1, #c do if c[i][1] <= p + 0.000001 then name = c[i][2] end end
  return name
end)(%s, BarCtrl.P))]], PARSE))
expr(label, "Size", "BarCtrl.LabelSize")
expr(label, "Center",
  "Point(BarCtrl.BarMargin + (BarCtrl.Span.X + BarCtrl.Span.Y)/2*(1 - 2*BarCtrl.BarMargin), BarCtrl.BarY + BarCtrl.BarH/2 + BarCtrl.LabelSize*0.75)")

local out = add("Merge", "BarOut", -1, 0)
out.Background = cut.Output
out.Foreground = label.Output
expr(out, "Blend", "BarCtrl.ShowLabel * BarCtrl.LabelFade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "chapterbar", {
    {"NAME", "ChapterBar"},
    {"OUT", "BarOut", "Output"},
    {"CTL", "BarCtrl", "ChapterList", "Chapters (0:00 Name)"},
    {"CTL", "BarCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "Fill", "TopLeftRed", "Bar Color", "2"}, {"CTL", "Fill", "TopLeftGreen", "", "2"}, {"CTL", "Fill", "TopLeftBlue", "", "2"},
    {"CTL", "Track", "TopLeftRed", "Track Color", "3"}, {"CTL", "Track", "TopLeftGreen", "", "3"}, {"CTL", "Track", "TopLeftBlue", "", "3"},
    {"CTL", "BarCtrl", "TrackOpacity", "Track Opacity"},
    {"CTL", "BarCtrl", "BarY", "Bar Position"},
    {"CTL", "BarCtrl", "BarH", "Bar Height"},
    {"CTL", "BarCtrl", "BarMargin", "Side Margin"},
    {"CTL", "BarCtrl", "BarGap", "Chapter Gap"},
    {"CTL", "BarCtrl", "Knob", "Knob Size"},
    {"CTL", "BarCtrl", "ShowLabel", "Show Chapter Name"},
    {"CTL", "BarCtrl", "LabelSize", "Name Size"},
    {"CTL", "Label", "Font", "Name Font", "4"}, {"CTL", "Label", "Style", "", "4"},
    {"CTL", "Label", "Red1", "Name Color", "5"}, {"CTL", "Label", "Green1", "", "5"}, {"CTL", "Label", "Blue1", "", "5"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local text = os.getenv("FX_TEXT")
  if text then ctrl:SetInput("ChapterList", (string.gsub(text, "|", "\n"))) end
  -- FX_TEXTFILE reads the list from a UTF-8 file instead, for names the shell would mangle
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("ChapterList", file:read("*a")); file:close() end
  if os.getenv("FX_FONT") then label:SetInput("Font", os.getenv("FX_FONT")) end
  local a = comp:GetAttrs()
  local v = {}
  for k = 1, SPLITS do v[#v + 1] = string.format("%.4f", ctrl:GetInput("S" .. k, a.COMPN_RenderStart)) end
  print("fps", comp:GetPrefs("Comp.FrameFormat.Rate"), "length", a.COMPN_RenderEnd - a.COMPN_RenderStart, "splits", table.concat(v, " "))
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 0, 3)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "cb", tonumber(os.getenv("FX_STEPS") or "12"))
end
