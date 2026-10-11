-- Caption: one line of words at a time. The line appears at once, is typed out one character at a time with a
-- cursor after it, or fills with a second colour from left to right in step with the speech.
-- Lines come from one text box; each starts with a time ("0:02 Text"), or Line Number is keyframed 1, 2, 3.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2" keyframes Line Number for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Caption")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local cur = L.cur("CpCtrl", "CpList", "CpTimed", "CpCue")
local FPS = 'iif(CpCtrl.FpsOverride > 0, CpCtrl.FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24)'
-- one character: a lead byte and the bytes that continue it, so a Chinese character counts as one
local CHAR = '"[^" .. string.char(128) .. "-" .. string.char(191) .. "][" .. string.char(128) .. "-" .. string.char(191) .. "]*"'
local X0 = 0.05 -- where the hidden rulers put the start of their text
local K = L.look("CpCtrl", {size = 0.065, edge = 0.005, box = {0, {0.05, 0.06, 0.09}, 0.012, 0.3}})

local list = K.add({
  {"CpList",  L.text("Lines (0:00 Text)", "0:00 First the words appear\n0:01.5 then the next line takes over\n0:03.2 in time with the voice", nil, 8)},
  {"CpTimed", L.check("Lines Start With A Time (0:02 Text)", 1)},
  {"CpCue",   L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"CpMode",  L.combo("The Words", {"Appear At Once", "Are Typed Out", "Fill With A Second Colour"}, 0)},
  {"CpSpeed", L.num("Characters Per Second (0: fit the line's time)", 0, 0, 40)},
  {"CpEnd",   L.num("Typing Or Filling Is Done At", 0.75, 0.1, 1)},
  {"CpStep",  L.check("Fill One Character At A Time", 0)},
  {"CpExit",  L.combo("At The End Of A Typed Line", {"It Stays Until The Next One", "It Is Deleted Backwards"}, 0)},
  {"CpDel",   L.num("Deleted Characters Per Second", 40, 1, 120)},
  {"CpCursor", L.combo("Cursor Of A Typed Line", {"Bar", "Block", "Underline", "None"}, 0)},
  {"CpBlink", L.num("Cursor Blinks Per Second", 1.5, 0, 6)},
  {"CpPos",   L.point("Position", nil, true), {0.5, 0.14}},
  {"CpAlign", L.combo("Position Is", {"Where The Line Starts", "The Middle Of The Line", "The Middle Of What Is Typed So Far"}, 1)},
  {"CpIn",    L.num("Pop Frames", 5, 1, 40)},
  {"CpOut",   L.num("Fade Out Frames", 3, 0, 40)},
})
for _, e in ipairs({
  {spec = {"CTL", "ColCpFill", "TopLeftRed", "Fill Colour", "3"}},
  {spec = {"CTL", "ColCpFill", "TopLeftGreen", "", "3"}}, {spec = {"CTL", "ColCpFill", "TopLeftBlue", "", "3"}},
  {spec = {"CTL", "ColCpFillEdge", "TopLeftRed", "Outline Colour Of The Filled Part", "4"}},
  {spec = {"CTL", "ColCpFillEdge", "TopLeftGreen", "", "4"}}, {spec = {"CTL", "ColCpFillEdge", "TopLeftBlue", "", "4"}},
  {"Idx",   L.num("Idx", 0, 0, 100, "Driver")},
  {"Since", L.num("Since", 0, 0, 1e5, "Driver")},
  {"Until", L.num("Until", 0, 0, 1e5, "Driver")},
  {"Cur",   L.text("Cur", "", "Driver", 1)},
  {"Total", L.num("Total", 0, 0, 1e4, "Driver")},
  {"Prog",  L.num("Prog", 0, 0, 1, "Driver")},
  {"Count", L.point("Count", "Driver")},
  {"Typed", L.text("Typed", "", "Driver", 1)},
  {"Rule",  L.point("Rule", "Driver")},
  {"RuleY", L.point("RuleY", "Driver")},
  {"Wid",   L.num("Wid", 0, 0, 4, "Driver")},
  {"FullW", L.num("FullW", 0, 0, 4, "Driver")},
  {"LineX", L.num("LineX", 0, -4, 4, "Driver")},
  {"Curs",  L.point("Curs", "Driver")},
  {"Show",  L.num("Show", 0, 0, 1, "Driver")},
  {"Fade",  L.num("Fade", 0, 0, 1, "Driver")},
  {"Pop",   L.num("Pop", 1, 0, 3, "Driver")},
}) do list[#list + 1] = e end
local ctrl, spec = L.panel(comp, "CpCtrl", list)
K.setup(comp)
local SIZE = K.v.size
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", "min(" .. cur(3) .. ", comp.RenderEnd - time + 1)")
expr(ctrl, "Cur", "Text(" .. cur(4) .. ")")
expr(ctrl, "Total", "(function(s) local n = 0 for ch in s:gmatch(" .. CHAR .. ") do n = n + 1 end return n end)(CpCtrl.Cur.Value)")
-- Prog: 0..1 through the typing or the filling of this line
expr(ctrl, "Prog", [[(function(since, untl, n, speed, done, fps)
  if n < 1 then return 0 end
  local frames = (speed > 0) and n/speed*fps or done*(since + untl)
  return math.min(math.max((since + 1)/math.max(frames, 1), 0), 1)
end)(CpCtrl.Since, CpCtrl.Until, CpCtrl.Total, CpCtrl.CpSpeed, CpCtrl.CpEnd, ]] .. FPS .. ")")
-- Count.X: how many characters have been typed or filled. Count.Y: 1 while that number is changing (the cursor
-- does not blink then)
expr(ctrl, "Count", [[(function(mode, untl, n, prog, fps, exit, del)
  if n < 1 then return Point(0, 0) end
  if mode == 0 then return Point(n, 0) end
  local c, busy = math.floor(n*prog + 0.0001), 0
  if prog < 1 then busy = 1 end
  if mode == 1 and exit == 1 then
    local left = math.floor(math.max(untl - 1, 0)*del/fps)
    if left <= n then busy = 1 end
    c = math.min(c, left)
  end
  return Point(c, busy)
end)(CpCtrl.CpMode, CpCtrl.Until, CpCtrl.Total, CpCtrl.Prog, ]] .. FPS .. ", CpCtrl.CpExit, CpCtrl.CpDel)")
expr(ctrl, "Typed", "Text((function(s, n) local out, k = {}, 0 for ch in s:gmatch(" .. CHAR
  .. ") do if k >= n then break end k = k + 1 out[k] = ch end return table.concat(out) end)(CpCtrl.Cur.Value, CpCtrl.Count.X))")

-- The words. Their left end is always put where the measurements below say, so nothing depends on how the text
-- tool would centre a line that keeps changing length. A typed line shows what is typed so far, the others all of it.
local text = add("TextPlus", "CpText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("HorizontalLeftCenterRight", -1)
K.font(text)
expr(text, "StyledText", "Text(iif(CpCtrl.CpMode == 1, CpCtrl.Typed.Value, CpCtrl.Cur.Value))")
expr(text, "Size", SIZE)
expr(text, "Center", "Point(CpCtrl.LineX, CpCtrl.CpPos.Y)")
-- three hidden copies that are only measured: a lone "|" (how tall a line is and where its ink sits), the typed or
-- filled part with a "|" after it (so that a space at the end counts), and the whole line with a "|" after it
local function ruler(name, row, what)
  local t = add("TextPlus", name, -3, row)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("HorizontalLeftCenterRight", -1)
  K.font(t)
  expr(t, "Size", SIZE)
  expr(t, "Center", "Point(" .. X0 .. ", CpCtrl.CpPos.Y)")
  expr(t, "StyledText", what)
  return t
end
ruler("CpRuler", 2, 'Text("|")')
ruler("CpMeasure", 3, 'Text(CpCtrl.Typed.Value .. "|")')
ruler("CpFull", 4, 'Text(CpCtrl.Cur.Value .. "|")')
local function window(tool, pick)
  return "(function() local d = " .. tool .. ".Output.DataWindow if not d then return " .. (pick:match("^Point") and "Point(0, 0)" or "0")
    .. " end local w, h = " .. tool .. ".Output.Width, " .. tool .. ".Output.Height return " .. pick .. " end)()"
end
expr(ctrl, "Rule", window("CpRuler", "Point(d.left/w, d.right/w)"))
expr(ctrl, "RuleY", window("CpRuler", "Point(d.bottom/h, d.top/h)"))
expr(ctrl, "Wid", "max(" .. window("CpMeasure", "d.right/w") .. " - CpCtrl.Rule.Y, 0)")
expr(ctrl, "FullW", "max(" .. window("CpFull", "d.right/w") .. " - CpCtrl.Rule.Y, 0)")
expr(ctrl, "LineX", "iif(CpCtrl.CpAlign == 0, CpCtrl.CpPos.X, CpCtrl.CpPos.X - iif(CpCtrl.CpAlign == 2 and CpCtrl.CpMode == 1, CpCtrl.Wid, CpCtrl.FullW)/2)")
-- Curs: left edge and width of the cursor, as fractions of the frame width
expr(ctrl, "Curs", "Point(CpCtrl.LineX + CpCtrl.Wid + CpCtrl.Rule.X - " .. X0 .. " + " .. SIZE .. "*0.03, iif(CpCtrl.CpCursor == 0, "
  .. SIZE .. "*0.07, iif(CpCtrl.CpCursor == 3, 0, " .. SIZE .. "*0.5)))")
expr(ctrl, "Show", "iif(CpCtrl.CpMode ~= 1 or CpCtrl.CpCursor == 3 or CpCtrl.Idx < 1, 0, iif(CpCtrl.Count.Y > 0 or CpCtrl.CpBlink <= 0, 1, iif((CpCtrl.Since/"
  .. FPS .. "*CpCtrl.CpBlink) % 1 < 0.5, 1, 0)))")
local FADEOUT = "iif(CpCtrl.CpOut <= 0, 1, min(max(CpCtrl.Until/CpCtrl.CpOut, 0), 1))"
expr(ctrl, "Fade", "iif(CpCtrl.Idx < 1, 0, iif(CpCtrl.CpMode == 1, 1, min((CpCtrl.Since + 1)/max(CpCtrl.CpIn, 1)*2, 1)) * " .. FADEOUT .. ")")
-- a small pop when a line appears (a typed line has nothing to pop)
expr(ctrl, "Pop", "iif(CpCtrl.CpMode == 1, 1, 1 + 0.25*max(1 - (CpCtrl.Since + 1)/max(CpCtrl.CpIn, 1), 0)^2)")

local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
local cmask = add("RectangleMask", "CpCursorMask", -2, 1)
expr(cmask, "Width", "max(CpCtrl.Curs.Y, 0.00001)")
expr(cmask, "Height", "iif(CpCtrl.CpCursor == 2, " .. SIZE .. "*0.09*" .. ASP .. ", max(CpCtrl.RuleY.Y - CpCtrl.RuleY.X, 0.00001))")
expr(cmask, "Center", "Point(CpCtrl.Curs.X + CpCtrl.Curs.Y/2, iif(CpCtrl.CpCursor == 2, CpCtrl.RuleY.X + Height/2, (CpCtrl.RuleY.X + CpCtrl.RuleY.Y)/2))")
local cbody = add("Background", "CpCursorBody", -1, 1)
cbody:SetInput("UseFrameFormatSettings", 1); L.color(cbody, 1, 1, 1, 1)
cbody.EffectMask = cmask.Mask
local matte = add("Merge", "CpMatte", -1, 0)
matte.Background = text.Output; matte.Foreground = cbody.Output
expr(matte, "Blend", "CpCtrl.Show")

for i, h in ipairs({{"ColCpFill", {1, 0.85, 0.1}}, {"ColCpFillEdge", {0.55, 0.08, 0.05}}}) do
  local b = add("Background", h[1], -2 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local function rgb(holder) return {holder .. ".TopLeftRed", holder .. ".TopLeftGreen", holder .. ".TopLeftBlue"} end
local plain = K.ink(comp, "CpPlain", 0, 0, matte.Output)
local filled = K.ink(comp, "CpFilled", 0, 4, matte.Output, {fill = rgb("ColCpFill"), edge = rgb("ColCpFillEdge")})
-- the filled version shows through a rectangle that ends where the filling has got to: at the end of the
-- characters filled so far, or (filling smoothly) that share of the width of the line
local EDGE = "(CpCtrl.LineX + CpCtrl.Rule.X - " .. X0 .. " + iif(CpCtrl.Prog >= 1, CpCtrl.FullW + 0.2, iif(CpCtrl.CpStep == 1, CpCtrl.Wid, CpCtrl.FullW*CpCtrl.Prog)))"
local wipe = add("RectangleMask", "CpWipe", 3, 3)
wipe:SetInput("Width", 3); wipe:SetInput("Height", 2)
expr(wipe, "Center", "Point(" .. EDGE .. " - 1.5, 0.5)")
local both = add("Merge", "CpBoth", 3, 0)
both.Background = plain.Output; both.Foreground = filled.Output
both.EffectMask = wipe.Mask
expr(both, "Blend", "iif(CpCtrl.CpMode == 2 and CpCtrl.Prog > 0, 1, 0)")
local drop = K.drop(comp, "CpDrop", 4, 0, both.Output)

-- the box behind: the whole line, or for a typed line from its start to the cursor, so it grows with the typing
local plate = K.plate(comp, "CpBox", 4, 2, "CpCtrl.LineX",
  "iif(CpCtrl.CpMode == 1, CpCtrl.Curs.X + CpCtrl.Curs.Y, CpCtrl.LineX + CpCtrl.FullW + 2*(CpCtrl.Rule.X - " .. X0 .. "))",
  "CpCtrl.RuleY.X", "CpCtrl.RuleY.Y")
local boxed = add("Merge", "CpBoxed", 5, 1)
boxed.Background = ctrl.Output; boxed.Foreground = plate.Output
expr(boxed, "Blend", K.v.box)
local all = add("Merge", "CpAll", 5, 0)
all.Background = boxed.Output; all.Foreground = drop.Output
local move = add("Transform", "CpMove", 6, 0)
move.Input = all.Output
expr(move, "Pivot", "Point(CpCtrl.LineX + CpCtrl.FullW/2, CpCtrl.CpPos.Y)")
expr(move, "Size", "CpCtrl.Pop")
local out = add("Merge", "CpFinal", 7, 0)
out.Background = ctrl.Output; out.Foreground = move.Output
expr(out, "Blend", "CpCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "caption", name = "Caption", out = out, ctrl = ctrl, spec = spec, prefix = "cp",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("CpList", file:read("*a")); file:close() end
    L.keys(ctrl, "CpCue", os.getenv("FX_CUE"))
  end})
