-- Chapter Bar: a progress bar that runs for as long as the title clip does, split into named chapters.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local MAXCH = 6

comp:Lock()
comp:StartUndo("Build Chapter Bar")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "BarCtrl", -5, -3)
local uc = {
  Chapters  = L.num("Chapters", 4, 1, MAXCH, nil, true),
  EvenSplit = L.check("Even Chapters", 1),
  BarY      = L.num("Bar Position", 0.06, 0, 1),
  BarH      = L.num("Bar Height", 0.012, 0.002, 0.05),
  BarMargin = L.num("Side Margin", 0.04, 0, 0.3),
  BarGap    = L.num("Chapter Gap", 0.004, 0, 0.02),
  TrackOpacity = L.num("Track Opacity", 0.35, 0, 1),
  Knob      = L.num("Knob Size", 1.3, 0, 3),
  ShowLabel = L.check("Show Chapter Name", 1),
  LabelSize = L.num("Name Size", 0.035, 0.01, 0.1),
  P        = L.num("P", 0, 0, 1, "Driver"),
  Cur      = L.num("Cur", 1, 1, MAXCH, "Driver"),
  CurStart = L.num("CurStart", 0, 0, 1, "Driver"),
  CurEnd   = L.num("CurEnd", 1, 0, 1, "Driver"),
  LabelFade = L.num("LabelFade", 1, 0, 1, "Driver"),
}
local defaults = {"Intro", "Part 1", "Part 2", "Part 3", "Part 4", "Outro"}
for k = 1, MAXCH do
  uc["Name" .. k] = L.text("Chapter " .. k .. " Name", defaults[k])
  if k > 1 then uc["Start" .. k] = L.num("Chapter " .. k .. " Start", (k - 1) / MAXCH, 0, 1) end
  if k < MAXCH then uc["S" .. k] = L.num("S" .. k, 2, 0, 2, "Driver") end
end
ctrl.UserControls = uc
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
-- the name sits centred over its own chapter; Text+ alignment inputs did not respond to scripting
-- S1..S5: where chapter 2..6 begins (0..1), or 2 when that chapter does not exist
local cur, start = "1", "0"
for j = 1, MAXCH - 1 do
  expr(ctrl, "S" .. j, string.format("iif(%d < Chapters, iif(EvenSplit == 1, %d/Chapters, Start%d), 2)", j, j, j + 1))
  cur = cur .. string.format(" + iif(P >= S%d, 1, 0)", j)
end
expr(ctrl, "Cur", cur)
for j = MAXCH - 1, 1, -1 do start = string.format("iif(Cur == %d, S%d, %s)", j + 1, j, start) end
expr(ctrl, "CurStart", start)
local stop = "1"
for j = MAXCH - 1, 1, -1 do stop = string.format("iif(Cur == %d, min(S%d, 1), %s)", j, j, stop) end
expr(ctrl, "CurEnd", stop)
expr(ctrl, "LabelFade",
  "iif(Cur <= 1, 1, min(max((time - (comp.RenderStart + CurStart*(comp.RenderEnd - comp.RenderStart)))/10, 0), 1))")

local track = add("Background", "Track", -4, -1)
L.color(track, 1, 1, 1)
local fill = add("Background", "Fill", -4, 1)
L.color(fill, 0.93, 0.16, 0.16)
for _, t in ipairs({track, fill}) do t:SetInput("UseFrameFormatSettings", 1) end

local bar = add("Custom", "BarDraw", -3, 0)
bar.Image1 = track.Output
bar.Image2 = fill.Output
expr(bar, "NumberIn1", "BarCtrl.P")
expr(bar, "NumberIn2", "BarCtrl.BarY")
expr(bar, "NumberIn3", "BarCtrl.BarH")
expr(bar, "NumberIn4", "BarCtrl.BarMargin")
expr(bar, "NumberIn5", "BarCtrl.BarGap")
expr(bar, "NumberIn6", "BarCtrl.TrackOpacity")
expr(bar, "NumberIn7", "BarCtrl.Knob")
expr(bar, "PointIn1", "Point(BarCtrl.S1, BarCtrl.S2)")
expr(bar, "PointIn2", "Point(BarCtrl.S3, BarCtrl.S4)")
expr(bar, "PointIn3", "Point(BarCtrl.S5, 2)")
bar:SetInput("Intermediate1", "(x - n4)/(1 - 2*n4)")
bar:SetInput("Intermediate2", "if(abs(y - n2) < n3/2, 1, 0) * if(i1 >= 0, 1, 0) * if(i1 <= 1, 1, 0)")
bar:SetInput("Intermediate3", "min(min(abs(i1 - p1x), abs(i1 - p1y)), min(min(abs(i1 - p2x), abs(i1 - p2y)), abs(i1 - p3x)))")
bar:SetInput("Intermediate4", "i2 * if(i3 > n5/2, 1, 0)")
bar:SetInput("Intermediate5", "if(i1 <= n1, 1, 0)")
bar:SetInput("Intermediate6", "if(sqrt(((x - n4 - n1*(1 - 2*n4))*w/h)^2 + (y - n2)^2) < n3*n7/2, 1, 0)")
local function chan(c)
  return string.format("if(i6 > 0, %s2, i4 * if(i5 > 0, %s2, %s1*n6))", c, c, c)
end
bar:SetInput("RedExpression", chan("r"))
bar:SetInput("GreenExpression", chan("g"))
bar:SetInput("BlueExpression", chan("b"))
bar:SetInput("AlphaExpression", "if(i6 > 0, 1, i4 * if(i5 > 0, 1, n6))")

local label = add("TextPlus", "Label", -3, -2)
label:SetInput("Font", "Open Sans")
label:SetInput("Style", "Bold")
label:SetInput("UseFrameFormatSettings", 1)
-- built inside out: the innermost alternative is chapter 1
local nested = "BarCtrl.Name1.Value"
for k = 2, MAXCH do nested = string.format("iif(BarCtrl.Cur == %d, BarCtrl.Name%d.Value, %s)", k, k, nested) end
expr(label, "StyledText", "Text(" .. nested .. ")")
expr(label, "Size", "BarCtrl.LabelSize")
expr(label, "Center",
  "Point(BarCtrl.BarMargin + (BarCtrl.CurStart + BarCtrl.CurEnd)/2*(1 - 2*BarCtrl.BarMargin), BarCtrl.BarY + BarCtrl.BarH/2 + BarCtrl.LabelSize*0.75)")

local out = add("Merge", "BarOut", -2, 0)
out.Background = bar.Output
out.Foreground = label.Output
expr(out, "Blend", "BarCtrl.ShowLabel * BarCtrl.LabelFade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  local spec = {
    {"NAME", "ChapterBar"},
    {"OUT", "BarOut", "Output"},
    {"CTL", "BarCtrl", "Chapters", "Chapters"},
    {"CTL", "BarCtrl", "EvenSplit", "Even Chapters"},
  }
  for k = 1, MAXCH do
    spec[#spec + 1] = {"CTL", "BarCtrl", "Name" .. k, "Chapter " .. k .. " Name"}
    if k > 1 then spec[#spec + 1] = {"CTL", "BarCtrl", "Start" .. k, "Chapter " .. k .. " Start"} end
  end
  for _, row in ipairs({
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
  }) do spec[#spec + 1] = row end
  L.export(comp, "chapterbar", spec)
else
  -- preview over the procedural stand-in so the bar is seen in context
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 0, 3)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "cb", tonumber(os.getenv("FX_STEPS") or "12"))
end
