-- Hidden Word: a caption in which one *marked* word is covered by a sticker until the reveal, the quiz-show
-- way of holding back an answer. At the reveal the sticker comes off and the word pops out in another colour.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source. FX_TEXTFILE reads the text from a UTF-8 file.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Hidden Word")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "HidCtrl", {
  {"HidText",   L.text("Text (hide one word with *stars*)", "正確答案是*香蕉*", nil, 2)},
  {"HidAt",     L.text("Reveal After (2, 0:02.5, 48f or 40%)", "50%")},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"HidCover",  L.text("Sticker Text", "？？？")},
  {"HidLeave",  L.combo("Sticker Leaves By", {"Flipping Over", "Flying Up", "Bursting", "Sliding Off To The Right"}, 0)},
  {"HidFrames", L.num("Reveal Frames", 8, 1, 60)},
  {"HidSize",   L.num("Size", 0.08, 0.02, 0.3)},
  {"HidMark",   L.num("Hidden Word Size", 1.3, 0.5, 3)},
  {"HidGap",    L.num("Hidden Word Gap", 0.2, 0, 1)},
  {"HidPos",    L.point("Position", nil, true), {0.5, 0.2}},
  {"HidPad",    L.num("Sticker Padding", 0.25, 0, 1)},
  {"HidRound",  L.num("Sticker Roundness", 0.3, 0, 1)},
  {"HidTilt",   L.num("Sticker Tilt", -3, -30, 30)},
  {"HidEdge",   L.num("Outline", 0.005, 0, 0.03)},
  {"HidOuter",  L.num("Outer Outline", 0.003, 0, 0.03)},
  {"HidIn",     L.num("Entrance Frames", 6, 1, 40)},
  {"HidOut",    L.num("Fade Out Frames", 3, 0, 40)},
  {"At",   L.num("At", 0, 0, 1e6, "Driver")},
  {"R",    L.num("R", 0, 0, 1, "Driver")},
  {"Pop",  L.num("Pop", 1, 0, 3, "Driver")},
  {"Fade", L.num("Fade", 1, 0, 1, "Driver")},
  {"WA", L.num("WA", 0, 0, 2, "Driver")}, {"WB", L.num("WB", 0, 0, 2, "Driver")}, {"WC", L.num("WC", 0, 0, 2, "Driver")},
  {"WQ", L.num("WQ", 0, 0, 2, "Driver")},
  {"Gap", L.point("Gap", "Driver")},
  {"MarkAt", L.point("MarkAt", "Driver")},
})
-- At: frames from the start of the clip to the reveal
expr(ctrl, "At", [[(function(s, fps, len)
  s = s:gsub("%s", "")
  local pct, fr = s:match("^([%d%.]+)%%$"), s:match("^(%d+)[fF]$")
  if pct then return tonumber(pct)/100*len end
  if fr then return tonumber(fr) end
  if s:match("^[%d:%.]+$") then
    local sec = 0
    for part in s:gmatch("[^:]+") do sec = sec and tonumber(part) and sec*60 + tonumber(part) end
    if sec then return sec*fps end
  end
  return len/2
end)(HidAt.Value, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), max(comp.RenderEnd - comp.RenderStart, 1))]])
-- R: 0 until the reveal, then up to 1 over Reveal Frames
expr(ctrl, "R", "min(max((time - comp.RenderStart - At + 1)/max(HidFrames, 1), 0), 1)")
expr(ctrl, "Pop", "iif(R <= 0, 0, (function(t) t = t - 1 return 1 + 3.2*t*t*t + 2.2*t*t end)(R))")
expr(ctrl, "Fade", "min((time - comp.RenderStart + 1)/max(HidIn, 1)*2, 1) * iif(HidOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/HidOut, 0), 1))")

-- the text is cut into three pieces: before the hidden word, the hidden word, after it
local function piece(n)
  return string.format([[Text((function(s, n)
  local a, b, c = s:match("^(.-)%%*(.-)%%*(.*)$")
  if not a then a, b, c = s, "", "" end
  return (({a, b, c})[n]:gsub("%%*", ""):gsub("^%%s+", ""):gsub("%%s+$", ""))
end)(HidCtrl.HidText.Value, %d))]], n)
end
local seg = {}
for n, tag in ipairs({"A", "B", "C"}) do
  local t = add("TextPlus", "Hid" .. tag, -4, n - 1)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("Font", "Microsoft JhengHei"); t:SetInput("Style", "Bold")
  expr(t, "StyledText", piece(n))
  expr(t, "Size", n == 2 and "HidCtrl.HidSize * HidCtrl.HidMark" or "HidCtrl.HidSize")
  if n > 1 then expr(t, "Font", "HidA.Font"); expr(t, "Style", "HidA.Style") end
  seg[n] = t
  expr(ctrl, "W" .. tag, string.format([[(function()
  if Hid%s.StyledText.Value == "" then return 0 end
  local d = Hid%s.Output.DataWindow
  if not d then return 0 end
  return math.max(d.right - d.left, 0) / Hid%s.Output.Width
end)()]], tag, tag, tag))
end
expr(ctrl, "Gap", "Point(iif(WA > 0 and WB > 0, HidGap*HidSize, 0), iif(WB > 0 and WC > 0, HidGap*HidSize, 0))")
local X0 = "(HidCtrl.HidPos.X - (HidCtrl.WA + HidCtrl.WB + HidCtrl.WC + HidCtrl.Gap.X + HidCtrl.Gap.Y)/2)"
local ASPECT = "HidCtrl.Output.Width/HidCtrl.Output.Height"
-- (inside the controller's own expressions a bare "Gap" does not find the control, so everything carries the tool name)
expr(ctrl, "MarkAt", "Point(" .. X0 .. " + HidCtrl.WA + HidCtrl.Gap.X + HidCtrl.WB/2, HidCtrl.HidPos.Y + 0.28*HidCtrl.HidSize*(HidCtrl.HidMark - 1)*comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))")

local putA = add("Merge", "HidPutA", -2, 0)
putA.Background = ctrl.Output; putA.Foreground = seg[1].Output
expr(putA, "Center", "Point(" .. X0 .. " + HidCtrl.WA/2, HidCtrl.HidPos.Y)")
local rest = add("Merge", "HidRest", -1, 0)
rest.Background = putA.Output; rest.Foreground = seg[3].Output
expr(rest, "Center", "Point(" .. X0 .. " + HidCtrl.WA + HidCtrl.Gap.X + HidCtrl.WB + HidCtrl.Gap.Y + HidCtrl.WC/2, HidCtrl.HidPos.Y)")
local word = add("Merge", "HidWord", -1, 1)
word.Background = ctrl.Output; word.Foreground = seg[2].Output
expr(word, "Center", "HidCtrl.MarkAt")

local holders = {{"ColHid", {1, 1, 1}, "Colour"}, {"ColHidWord", {1, 0.9, 0.15}, "Hidden Word Colour"},
                 {"ColHidEdge", {0.8, 0.05, 0.1}, "Outline Colour"}, {"ColHidOuter", {1, 1, 1}, "Outer Outline Colour"},
                 {"ColHidCover", {0.1, 0.1, 0.12}, "Sticker Colour"}, {"ColHidCoverText", {1, 0.9, 0.15}, "Sticker Text Colour"}}
for i, h in ipairs(holders) do
  local b = add("Background", h[1], -5 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local function cols(a, b, c)
  local t = {}
  for i, ch in ipairs({"Red", "Green", "Blue"}) do
    t[i] = a .. ".TopLeft" .. ch; t[i + 3] = b .. ".TopLeft" .. ch; t[i + 6] = c .. ".TopLeft" .. ch
  end
  return t
end
local restInk = L.inked(comp, "HidRestInk", 0, 0, rest.Output, "HidCtrl.HidEdge", "HidCtrl.HidOuter", cols("ColHid", "ColHidEdge", "ColHidOuter"))
local wordInk = L.inked(comp, "HidWordInk", 0, 4, word.Output, "HidCtrl.HidEdge", "HidCtrl.HidOuter", cols("ColHidWord", "ColHidEdge", "ColHidOuter"))
-- the word pops out from behind the sticker
local wordMove = add("Transform", "HidWordPop", 3, 4)
wordMove.Input = wordInk.Output
expr(wordMove, "Pivot", "HidCtrl.MarkAt")
expr(wordMove, "Size", "max(HidCtrl.Pop, 0.001)")
local m1 = add("Merge", "HidBoth", 4, 0)
m1.Background = restInk.Output; m1.Foreground = wordMove.Output
expr(m1, "Blend", "iif(HidCtrl.R > 0, 1, 0)")

-- the sticker: a rounded box as wide as the hidden word, with its own text
local box = add("Custom", "HidBox", 0, 8)
box.Image1 = ctrl.Output; box.Image2 = comp:FindTool("ColHidCover").Output
-- as wide as the hidden word or as its own text, whichever is wider
expr(box, "NumberIn1", "max(HidCtrl.WB, HidCtrl.WQ*1.15)/2 + HidCtrl.HidPad*HidCtrl.HidSize*0.5")
expr(box, "NumberIn2", "HidCtrl.HidSize*HidCtrl.HidMark*0.45*" .. ASPECT .. " + HidCtrl.HidPad*HidCtrl.HidSize*0.35*" .. ASPECT)
expr(box, "NumberIn3", "HidCtrl.HidRound")
expr(box, "PointIn1", "HidCtrl.MarkAt")
box:SetInput("Intermediate1", "abs(x - p1x)*w/h")
box:SetInput("Intermediate2", "abs(y - p1y)")
box:SetInput("Intermediate3", "n1*w/h")
box:SetInput("Intermediate4", "n3*min(i3, n2)")
box:SetInput("Intermediate5", "sqrt(max(i1 - i3 + i4, 0)^2 + max(i2 - n2 + i4, 0)^2) + min(max(i1 - i3 + i4, i2 - n2 + i4), 0) - i4")
box:SetInput("Intermediate6", "if(n1 <= 0, 0, min(max(-i5*h + 0.5, 0), 1))")
for _, c in ipairs({"r", "g", "b"}) do
  box:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", "get" .. c .. "2b(0.5, 0.5)*i6")
end
box:SetInput("AlphaExpression", "i6")
local q = add("TextPlus", "HidQ", 0, 9)
q:SetInput("UseFrameFormatSettings", 1)
expr(q, "Font", "HidA.Font"); expr(q, "Style", "HidA.Style")
expr(q, "StyledText", "Text(iif(HidCtrl.WB > 0, HidCtrl.HidCover.Value, ''))")
expr(q, "Center", "HidCtrl.MarkAt")
expr(q, "Size", "HidCtrl.HidSize * HidCtrl.HidMark * 0.8")
for i, ch in ipairs({"Red", "Green", "Blue"}) do expr(q, ch .. "1", "ColHidCoverText.TopLeft" .. ch) end
expr(ctrl, "WQ", [[(function()
  if HidQ.StyledText.Value == "" then return 0 end
  local d = HidQ.Output.DataWindow
  if not d then return 0 end
  return math.max(d.right - d.left, 0) / HidQ.Output.Width
end)()]])
local cover = add("Merge", "HidCoverAll", 2, 8)
cover.Background = box.Output; cover.Foreground = q.Output
local coverMove = add("Transform", "HidCoverMove", 3, 8)
coverMove.Input = cover.Output
expr(coverMove, "Pivot", "HidCtrl.MarkAt")
coverMove:SetInput("UseSizeAndAspect", 0)
local EASE = "(HidCtrl.R^2)"
expr(coverMove, "Angle", "HidCtrl.HidTilt + iif(HidCtrl.HidLeave == 1, 25*" .. EASE .. ", 0)")
expr(coverMove, "XSize", "iif(HidCtrl.HidLeave == 2, 1 + 1.5*HidCtrl.R, 1)")
expr(coverMove, "YSize", "iif(HidCtrl.HidLeave == 0, max(1 - HidCtrl.R*2, 0.001), iif(HidCtrl.HidLeave == 2, 1 + 1.5*HidCtrl.R, 1))")
expr(coverMove, "Center", "Point(0.5 + iif(HidCtrl.HidLeave == 3, 1.2*" .. EASE .. ", 0), 0.5 + iif(HidCtrl.HidLeave == 1, 0.5*" .. EASE .. ", 0))")
local m2 = add("Merge", "HidCovered", 5, 0)
m2.Background = m1.Output; m2.Foreground = coverMove.Output
expr(m2, "Blend", "iif(HidCtrl.HidLeave == 0, iif(HidCtrl.R >= 0.5, 0, 1), iif(HidCtrl.HidLeave == 2, 1 - HidCtrl.R, iif(HidCtrl.R >= 1, 0, 1)))")
local out = add("Merge", "HidFinal", 6, 0)
out.Background = ctrl.Output; out.Foreground = m2.Output
expr(out, "Blend", "HidCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 7, {"CTL", "HidA", "Font", "Font", "2"})
table.insert(spec, 8, {"CTL", "HidA", "Style", "", "2"})
for i, h in ipairs(holders) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h[1], "TopLeftRed", h[3], g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "hiddenword", name = "HiddenWord", out = out, ctrl = ctrl, spec = spec, prefix = "hw",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("HidText", file:read("*a")); file:close() end
  end})
