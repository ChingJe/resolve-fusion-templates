-- Word By Word: one sentence per clip, and it happens one character at a time. The sentence is typed out with a
-- cursor after it, or it is all there and fills with a second colour from left to right. The clip is the timing:
-- where it sits is when the sentence starts, how long it is is how long the typing or filling takes.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source. FX_TEXTFILE reads the text from a UTF-8 file,
-- FX_CUE="0=0,60=5" keyframes Characters Done for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Word By Word")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local FPS = '(comp:GetPrefs("Comp.FrameFormat.Rate") or 24)'
-- one character: a lead byte and the bytes that continue it, so a Chinese character counts as one
local CHAR = '"[^" .. string.char(128) .. "-" .. string.char(191) .. "][" .. string.char(128) .. "-" .. string.char(191) .. "]*"'
local X0 = 0.05 -- where the hidden rulers put the start of their text
local K = L.look("WbCtrl", {size = 0.065, edge = 0.005, box = {0, {0.05, 0.06, 0.09}, 0.012, 0.3}})

local list = K.add({
  {"WbSay",   L.text("Text", "One character after another", nil, 1)},
  {"WbMode",  L.combo("The Words", {"Are Typed Out", "Fill With A Second Colour"}, 0)},
  {"WbEnd",   L.num("Done At", 0.75, 0.1, 1)},
  {"WbStep",  L.check("Fill One Character At A Time", 0)},
  {"WbExit",  L.combo("At The End Of A Typed Line", {"It Stays", "It Is Deleted Backwards"}, 0)},
  {"WbDel",   L.num("Deleting Starts At", 0.85, 0.1, 1)},
  {"WbHand",  L.check("Set The Timing By Hand", 0)},
  {"WbDone",  L.num("Characters Done (keyframe this)", 0, 0, 60)},
  {"WbCursor", L.combo("Cursor Of A Typed Line", {"Bar", "Block", "Underline", "None"}, 0)},
  {"WbBlink", L.num("Cursor Blinks Per Second", 1.5, 0, 6)},
  {"WbPos",   L.point("Position", nil, true), {0.5, 0.14}},
  {"WbAlign", L.combo("Position Is", {"Where The Line Starts", "The Middle Of The Line", "The Middle Of What Is Typed So Far"}, 1)},
  {"WbIn",    L.num("Pop Frames", 5, 1, 40)},
  {"WbOut",   L.num("Fade Out Frames", 3, 0, 40)},
})
for _, e in ipairs({
  {spec = {"CTL", "ColWbFill", "TopLeftRed", "Fill Colour", "3"}},
  {spec = {"CTL", "ColWbFill", "TopLeftGreen", "", "3"}}, {spec = {"CTL", "ColWbFill", "TopLeftBlue", "", "3"}},
  {spec = {"CTL", "ColWbFillEdge", "TopLeftRed", "Outline Colour Of The Filled Part", "4"}},
  {spec = {"CTL", "ColWbFillEdge", "TopLeftGreen", "", "4"}}, {spec = {"CTL", "ColWbFillEdge", "TopLeftBlue", "", "4"}},
  {"Since", L.num("Since", 0, 0, 1e5, "Driver")},
  {"Until", L.num("Until", 0, 0, 1e5, "Driver")},
  {"Cur",   L.text("Cur", "", "Driver", 1)},
  {"Total", L.num("Total", 0, 0, 1e4, "Driver")},
  {"Prog",  L.num("Prog", 0, 0, 1, "Driver")},
  {"Count", L.point("Count", "Driver")},
  {"Typed", L.text("Typed", "", "Driver", 1)},
  {"Ahead", L.text("Ahead", "", "Driver", 1)},
  {"Part",  L.num("Part", 0, 0, 1, "Driver")},
  {"WidN",  L.num("WidN", 0, 0, 4, "Driver")},
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
local ctrl, spec = L.panel(comp, "WbCtrl", list)
K.setup(comp)
local SIZE = K.v.size
expr(ctrl, "Since", "time - comp.RenderStart")
expr(ctrl, "Until", "comp.RenderEnd - time + 1")
expr(ctrl, "Cur", "Text(WbCtrl.WbSay.Value)")
expr(ctrl, "Total", "(function(s) local n = 0 for ch in s:gmatch(" .. CHAR .. ") do n = n + 1 end return n end)(WbCtrl.Cur.Value)")
-- Prog: 0..1 through the typing or the filling
expr(ctrl, "Prog", "iif(WbCtrl.Total < 1, 0, iif(WbCtrl.WbHand == 1, min(max(WbCtrl.WbDone/WbCtrl.Total, 0), 1), min(max((WbCtrl.Since + 1)/max(WbCtrl.WbEnd*(WbCtrl.Since + WbCtrl.Until), 1), 0), 1)))")
-- Count.X: how many characters have been typed or filled. Count.Y: 1 while that number is changing (the cursor
-- does not blink then). Deleting backwards runs from Deleting Starts At to the last frame, which is empty.
-- Timed by hand, the number is the keyframed Characters Done, and it may go down as well as up.
expr(ctrl, "Count", [[(function(mode, since, untl, n, prog, exit, del, hand, done, before)
  if n < 1 then return Point(0, 0) end
  if hand == 1 then return Point(math.floor(math.min(math.max(done, 0), n) + 0.0001), (done ~= before) and 1 or 0) end
  local c, busy = math.floor(n*prog + 0.0001), 0
  if prog < 1 then busy = 1 end
  if mode == 0 and exit == 1 then
    local span = math.max((1 - del)*(since + untl), 1)
    if untl - 1 <= span then busy = 1 end
    c = math.min(c, math.floor(n*math.min((untl - 1)/span, 1) + 0.0001))
  end
  return Point(c, busy)
end)(WbCtrl.WbMode, WbCtrl.Since, WbCtrl.Until, WbCtrl.Total, WbCtrl.Prog, WbCtrl.WbExit, WbCtrl.WbDel, WbCtrl.WbHand, WbCtrl.WbDone, WbCtrl:GetValue("WbDone", time - 1))]])
expr(ctrl, "Typed", "Text((function(s, n) local out, k = {}, 0 for ch in s:gmatch(" .. CHAR
  .. ") do if k >= n then break end k = k + 1 out[k] = ch end return table.concat(out) end)(WbCtrl.Cur.Value, WbCtrl.Count.X))")
-- Ahead: one character more than Typed, and Part: how far into that character the filling has got. Timed by hand
-- that comes from Characters Done, otherwise from Prog: either way the filling is counted in characters.
expr(ctrl, "Ahead", "Text((function(s, n) local out, k = {}, 0 for ch in s:gmatch(" .. CHAR
  .. ") do if k >= n then break end k = k + 1 out[k] = ch end return table.concat(out) end)(WbCtrl.Cur.Value, WbCtrl.Count.X + 1))")
expr(ctrl, "Part", "max(min(max(iif(WbCtrl.WbHand == 1, WbCtrl.WbDone, WbCtrl.Total*WbCtrl.Prog), 0), WbCtrl.Total) - WbCtrl.Count.X, 0)")

-- The words. Their left end is always put where the measurements below say, so nothing depends on how the text
-- tool would centre a line that keeps changing length. A typed line shows what is typed so far, a filled one all of it.
local text = add("TextPlus", "WbText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("HorizontalLeftCenterRight", -1)
K.font(text)
expr(text, "StyledText", "Text(iif(WbCtrl.WbMode == 0, WbCtrl.Typed.Value, WbCtrl.Cur.Value))")
expr(text, "Size", SIZE)
expr(text, "Center", "Point(WbCtrl.LineX, WbCtrl.WbPos.Y)")
-- three hidden copies that are only measured: a lone "|" (how tall a line is and where its ink sits), the typed or
-- filled part with a "|" after it (so that a space at the end counts), and the whole line with a "|" after it
local function ruler(name, row, what)
  local t = add("TextPlus", name, -3, row)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("HorizontalLeftCenterRight", -1)
  K.font(t)
  expr(t, "Size", SIZE)
  expr(t, "Center", "Point(" .. X0 .. ", WbCtrl.WbPos.Y)")
  expr(t, "StyledText", what)
  return t
end
ruler("WbRuler", 2, 'Text("|")')
ruler("WbMeasure", 3, 'Text(WbCtrl.Typed.Value .. "|")')
ruler("WbFull", 4, 'Text(WbCtrl.Cur.Value .. "|")')
ruler("WbAhead", 5, 'Text(WbCtrl.Ahead.Value .. "|")')
local function window(tool, pick)
  return "(function() local d = " .. tool .. ".Output.DataWindow if not d then return " .. (pick:match("^Point") and "Point(0, 0)" or "0")
    .. " end local w, h = " .. tool .. ".Output.Width, " .. tool .. ".Output.Height return " .. pick .. " end)()"
end
expr(ctrl, "Rule", window("WbRuler", "Point(d.left/w, d.right/w)"))
expr(ctrl, "RuleY", window("WbRuler", "Point(d.bottom/h, d.top/h)"))
expr(ctrl, "Wid", "max(" .. window("WbMeasure", "d.right/w") .. " - WbCtrl.Rule.Y, 0)")
expr(ctrl, "WidN", "max(" .. window("WbAhead", "d.right/w") .. " - WbCtrl.Rule.Y, 0)")
expr(ctrl, "FullW", "max(" .. window("WbFull", "d.right/w") .. " - WbCtrl.Rule.Y, 0)")
expr(ctrl, "LineX", "iif(WbCtrl.WbAlign == 0, WbCtrl.WbPos.X, WbCtrl.WbPos.X - iif(WbCtrl.WbAlign == 2 and WbCtrl.WbMode == 0, WbCtrl.Wid, WbCtrl.FullW)/2)")
-- Curs: left edge and width of the cursor, as fractions of the frame width
expr(ctrl, "Curs", "Point(WbCtrl.LineX + WbCtrl.Wid + WbCtrl.Rule.X - " .. X0 .. " + " .. SIZE .. "*0.03, iif(WbCtrl.WbCursor == 0, "
  .. SIZE .. "*0.07, iif(WbCtrl.WbCursor == 3, 0, " .. SIZE .. "*0.5)))")
expr(ctrl, "Show", "iif(WbCtrl.WbMode ~= 0 or WbCtrl.WbCursor == 3, 0, iif(WbCtrl.Count.Y > 0 or WbCtrl.WbBlink <= 0, 1, iif((WbCtrl.Since/"
  .. FPS .. "*WbCtrl.WbBlink) % 1 < 0.5, 1, 0)))")
local FADEOUT = "iif(WbCtrl.WbOut <= 0, 1, min(max(WbCtrl.Until/WbCtrl.WbOut, 0), 1))"
expr(ctrl, "Fade", "iif(WbCtrl.WbMode == 0, 1, min((WbCtrl.Since + 1)/max(WbCtrl.WbIn, 1)*2, 1)) * " .. FADEOUT)
-- a small pop when a filled line appears (a typed line has nothing to pop)
expr(ctrl, "Pop", "iif(WbCtrl.WbMode == 0, 1, 1 + 0.25*max(1 - (WbCtrl.Since + 1)/max(WbCtrl.WbIn, 1), 0)^2)")

local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
local cmask = add("RectangleMask", "WbCursorMask", -2, 1)
expr(cmask, "Width", "max(WbCtrl.Curs.Y, 0.00001)")
expr(cmask, "Height", "iif(WbCtrl.WbCursor == 2, " .. SIZE .. "*0.09*" .. ASP .. ", max(WbCtrl.RuleY.Y - WbCtrl.RuleY.X, 0.00001))")
expr(cmask, "Center", "Point(WbCtrl.Curs.X + WbCtrl.Curs.Y/2, iif(WbCtrl.WbCursor == 2, WbCtrl.RuleY.X + Height/2, (WbCtrl.RuleY.X + WbCtrl.RuleY.Y)/2))")
local cbody = add("Background", "WbCursorBody", -1, 1)
cbody:SetInput("UseFrameFormatSettings", 1); L.color(cbody, 1, 1, 1, 1)
cbody.EffectMask = cmask.Mask
local matte = add("Merge", "WbMatte", -1, 0)
matte.Background = text.Output; matte.Foreground = cbody.Output
expr(matte, "Blend", "WbCtrl.Show")

for i, h in ipairs({{"ColWbFill", {1, 0.85, 0.1}}, {"ColWbFillEdge", {0.55, 0.08, 0.05}}}) do
  local b = add("Background", h[1], -2 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local function rgb(holder) return {holder .. ".TopLeftRed", holder .. ".TopLeftGreen", holder .. ".TopLeftBlue"} end
local plain = K.ink(comp, "WbPlain", 0, 0, matte.Output)
local filled = K.ink(comp, "WbFilled", 0, 4, matte.Output, {fill = rgb("ColWbFill"), edge = rgb("ColWbFillEdge")})
-- The filled part is drawn in two pieces. The characters that are filled completely come from a text of just
-- those characters (WbSome below), so their outlines are their own. The character the filling is passing through
-- is the whole filled line seen through a rectangle that ends part of the way through that character.
-- (One rectangle for everything would cut through the outline of the next character, which then takes the fill
-- colours along its left edge whenever the filling stands still between two characters.)
local EDGE = "(WbCtrl.LineX + iif(WbCtrl.Prog >= 1, WbCtrl.FullW + 0.2, WbCtrl.Wid + iif(WbCtrl.WbStep == 1, 0, WbCtrl.Part*(WbCtrl.WidN - WbCtrl.Wid))))"
local wipe = add("RectangleMask", "WbWipe", 3, 3)
wipe:SetInput("Width", 3); wipe:SetInput("Height", 2)
expr(wipe, "Center", "Point(" .. EDGE .. " - 1.5, 0.5)")
local both = add("Merge", "WbBoth", 3, 0)
both.Background = plain.Output; both.Foreground = filled.Output
both.EffectMask = wipe.Mask
expr(both, "Blend", "iif(WbCtrl.WbMode == 1 and WbCtrl.Prog > 0 and ((WbCtrl.WbStep == 0 and WbCtrl.Part > 0.001) or WbCtrl.Prog >= 1), 1, 0)")
local some = add("TextPlus", "WbSome", -3, 6)
some:SetInput("UseFrameFormatSettings", 1)
some:SetInput("HorizontalLeftCenterRight", -1)
K.font(some)
expr(some, "StyledText", "Text(WbCtrl.Typed.Value)")
expr(some, "Size", SIZE)
expr(some, "Center", "Point(WbCtrl.LineX, WbCtrl.WbPos.Y)")
local exact = K.ink(comp, "WbExact", 0, 6, some.Output, {fill = rgb("ColWbFill"), edge = rgb("ColWbFillEdge")})
local whole = add("Merge", "WbWhole", 4, 0)
whole.Background = both.Output; whole.Foreground = exact.Output
expr(whole, "Blend", "iif(WbCtrl.WbMode == 1 and WbCtrl.Count.X > 0 and WbCtrl.Prog < 1, 1, 0)")
local drop = K.drop(comp, "WbDrop", 5, 0, whole.Output)

-- the box behind: the whole line, or for a typed line from its start to the cursor, so it grows with the typing
local plate = K.plate(comp, "WbBox", 4, 2, "WbCtrl.LineX",
  "iif(WbCtrl.WbMode == 0, WbCtrl.Curs.X + WbCtrl.Curs.Y, WbCtrl.LineX + WbCtrl.FullW + 2*(WbCtrl.Rule.X - " .. X0 .. "))",
  "WbCtrl.RuleY.X", "WbCtrl.RuleY.Y")
local boxed = add("Merge", "WbBoxed", 5, 1)
boxed.Background = ctrl.Output; boxed.Foreground = plate.Output
expr(boxed, "Blend", K.v.box)
local all = add("Merge", "WbAll", 5, 0)
all.Background = boxed.Output; all.Foreground = drop.Output
local move = add("Transform", "WbMove", 6, 0)
move.Input = all.Output
expr(move, "Pivot", "Point(WbCtrl.LineX + WbCtrl.FullW/2, WbCtrl.WbPos.Y)")
expr(move, "Size", "WbCtrl.Pop")
local out = add("Merge", "WbFinal", 7, 0)
out.Background = ctrl.Output; out.Foreground = move.Output
expr(out, "Blend", "WbCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "wordbyword", name = "WordByWord", out = out, ctrl = ctrl, spec = spec, prefix = "wb",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("WbSay", (file:read("*a"):gsub("%s+$", ""))); file:close() end
    L.keys(ctrl, "WbDone", os.getenv("FX_CUE"))
  end})
