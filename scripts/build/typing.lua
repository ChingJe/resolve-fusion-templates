-- Typing: the line on screen is typed out one character at a time, with a cursor after it.
-- Lines come from one text box; each starts with a time ("0:02 Text"), or Line Number is keyframed 1, 2, 3.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2" keyframes Line Number for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Typing")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local cur = L.cur("TyCtrl", "TyList", "TyTimed", "TyCue")
local FPS = 'iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24)'
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
-- one character: a lead byte and the bytes that continue it, so a Chinese character counts as one
local CHAR = '"[^" .. string.char(128) .. "-" .. string.char(191) .. "][" .. string.char(128) .. "-" .. string.char(191) .. "]*"'
local X0 = 0.05 -- where the hidden rulers put the start of their text

local ctrl, spec = L.panel(comp, "TyCtrl", {
  {"TyList",  L.text("Lines (0:00 Text)", "0:00 Hello, is anyone there?\n0:02.5 Typing one letter at a time\n0:05 with a cursor that blinks", nil, 8)},
  {"TyTimed", L.check("Lines Start With A Time (0:02 Text)", 1)},
  {"TyCue",   L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"TySpeed", L.num("Characters Per Second (0: fit the line's time)", 12, 0, 40)},
  {"TyEnd",   L.num("Typing Is Done At", 0.6, 0.1, 1)},
  {"TyExit",  L.combo("At The End Of A Line", {"It Stays Until The Next One", "It Is Deleted Backwards"}, 0)},
  {"TyDel",   L.num("Deleted Characters Per Second", 40, 1, 120)},
  {"TyCursor", L.combo("Cursor", {"Bar", "Block", "Underline", "None"}, 0)},
  {"TyBlink", L.num("Cursor Blinks Per Second", 1.5, 0, 6)},
  {"TySize",  L.num("Size", 0.06, 0.02, 0.3)},
  {"TyPos",   L.point("Position", nil, true), {0.5, 0.14}},
  {"TyAlign", L.combo("Position Is", {"Where The Line Starts", "The Middle Of The Finished Line", "The Middle Of What Is Typed So Far"}, 1)},
  {"TyEdge",  L.num("Outline", 0.004, 0, 0.03)},
  {"TyBox",   L.num("Box Opacity", 0, 0, 1)},
  {"TyPad",   L.num("Box Padding", 0.012, 0, 0.06)},
  {"TyRound", L.num("Box Roundness", 0.3, 0, 1)},
  {"Idx",   L.num("Idx", 0, 0, 100, "Driver")},
  {"Since", L.num("Since", 0, 0, 1e5, "Driver")},
  {"Until", L.num("Until", 0, 0, 1e5, "Driver")},
  {"Cur",   L.text("Cur", "", "Driver", 1)},
  {"Total", L.num("Total", 0, 0, 1e4, "Driver")},
  {"Count", L.point("Count", "Driver")},
  {"Typed", L.text("Typed", "", "Driver", 1)},
  {"Rule",  L.point("Rule", "Driver")},
  {"RuleY", L.point("RuleY", "Driver")},
  {"Wid",   L.num("Wid", 0, 0, 4, "Driver")},
  {"FullW", L.num("FullW", 0, 0, 4, "Driver")},
  {"LineX", L.num("LineX", 0, -4, 4, "Driver")},
  {"Curs",  L.point("Curs", "Driver")},
  {"Show",  L.num("Show", 0, 0, 1, "Driver")},
})
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", "min(" .. cur(3) .. ", comp.RenderEnd - time + 1)")
expr(ctrl, "Cur", "Text(" .. cur(4) .. ")")
expr(ctrl, "Total", "(function(s) local n = 0 for ch in s:gmatch(" .. CHAR .. ") do n = n + 1 end return n end)(Cur.Value)")
-- Count.X: how many characters are on screen. Count.Y: 1 while that number is changing (the cursor does not blink then)
expr(ctrl, "Count", [[(function(since, untl, n, speed, done, fps, exit, del)
  if n < 1 then return Point(0, 0) end
  local frames = (speed > 0) and n/speed*fps or done*(since + untl)
  local c, busy = math.floor(n*math.min((since + 1)/math.max(frames, 1), 1) + 0.0001), 0
  if since + 1 < frames then busy = 1 end
  if exit == 1 then
    local left = math.floor(math.max(untl - 1, 0)*del/fps)
    if left <= n then busy = 1 end
    c = math.min(c, left)
  end
  return Point(c, busy)
end)(Since, Until, Total, TySpeed, TyEnd, ]] .. FPS .. ", TyExit, TyDel)")
expr(ctrl, "Typed", "Text((function(s, n) local out, k = {}, 0 for ch in s:gmatch(" .. CHAR
  .. ") do if k >= n then break end k = k + 1 out[k] = ch end return table.concat(out) end)(Cur.Value, Count.X))")

-- The words. Their left end is always put where the measurements below say, so nothing depends on how the text
-- tool would centre a line that keeps changing length.
local text = add("TextPlus", "TyText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("Font", "Microsoft JhengHei"); text:SetInput("Style", "Bold")
text:SetInput("HorizontalLeftCenterRight", -1)
expr(text, "StyledText", "Text(TyCtrl.Typed.Value)")
expr(text, "Size", "TyCtrl.TySize")
expr(text, "Center", "Point(TyCtrl.LineX, TyCtrl.TyPos.Y)")
-- three hidden copies that are only measured: a lone "|" (how tall a line is and where its ink sits), what is typed
-- so far with a "|" after it (so that a space at the end counts), and the whole line with a "|" after it
local function ruler(name, row, what)
  local t = add("TextPlus", name, -3, row)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("HorizontalLeftCenterRight", -1)
  expr(t, "Font", "TyText.Font"); expr(t, "Style", "TyText.Style")
  expr(t, "Size", "TyCtrl.TySize")
  expr(t, "Center", "Point(" .. X0 .. ", TyCtrl.TyPos.Y)")
  expr(t, "StyledText", what)
  return t
end
local r1 = ruler("TyRuler", 2, 'Text("|")')
local r2 = ruler("TyMeasure", 3, 'Text(TyCtrl.Typed.Value .. "|")')
local r3 = ruler("TyFull", 4, 'Text(TyCtrl.Cur.Value .. "|")')
local function window(tool, pick)
  return "(function() local d = " .. tool .. ".Output.DataWindow if not d then return " .. (pick:match("^Point") and "Point(0, 0)" or "0")
    .. " end local w, h = " .. tool .. ".Output.Width, " .. tool .. ".Output.Height return " .. pick .. " end)()"
end
expr(ctrl, "Rule", window("TyRuler", "Point(d.left/w, d.right/w)"))
expr(ctrl, "RuleY", window("TyRuler", "Point(d.bottom/h, d.top/h)"))
expr(ctrl, "Wid", "max(" .. window("TyMeasure", "d.right/w") .. " - Rule.Y, 0)")
expr(ctrl, "FullW", "max(" .. window("TyFull", "d.right/w") .. " - Rule.Y, 0)")
expr(ctrl, "LineX", "iif(TyAlign == 0, TyPos.X, iif(TyAlign == 1, TyPos.X - FullW/2, TyPos.X - Wid/2))")
-- Curs: left edge and width of the cursor, as fractions of the frame width
expr(ctrl, "Curs", "Point(LineX + Wid + Rule.X - " .. X0 .. " + TySize*0.03, iif(TyCursor == 0, TySize*0.07, iif(TyCursor == 3, 0, TySize*0.5)))")
expr(ctrl, "Show", "iif(TyCursor == 3 or Idx < 1, 0, iif(Count.Y > 0 or TyBlink <= 0, 1, iif((Since/" .. FPS .. "*TyBlink) % 1 < 0.5, 1, 0)))")

local cmask = add("RectangleMask", "TyCursorMask", -2, 1)
expr(cmask, "Width", "max(TyCtrl.Curs.Y, 0.00001)")
expr(cmask, "Height", "iif(TyCtrl.TyCursor == 2, TyCtrl.TySize*0.09*" .. ASP .. ", max(TyCtrl.RuleY.Y - TyCtrl.RuleY.X, 0.00001))")
expr(cmask, "Center", "Point(TyCtrl.Curs.X + TyCtrl.Curs.Y/2, iif(TyCtrl.TyCursor == 2, TyCtrl.RuleY.X + Height/2, (TyCtrl.RuleY.X + TyCtrl.RuleY.Y)/2))")
local cbody = add("Background", "TyCursorBody", -1, 1)
cbody:SetInput("UseFrameFormatSettings", 1); L.color(cbody, 1, 1, 1, 1)
cbody.EffectMask = cmask.Mask
local matte = add("Merge", "TyMatte", -1, 0)
matte.Background = text.Output; matte.Foreground = cbody.Output
expr(matte, "Blend", "TyCtrl.Show")

local holders = {{"ColTy", {1, 1, 1}, "Colour"}, {"ColTyEdge", {0.05, 0.05, 0.08}, "Outline Colour"}}
for i, h in ipairs(holders) do
  local b = add("Background", h[1], -4 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local c = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  c[i] = "ColTy.TopLeft" .. ch; c[i + 3] = "ColTyEdge.TopLeft" .. ch; c[i + 6] = "ColTyEdge.TopLeft" .. ch
end
local inked = L.inked(comp, "TyInk", 0, 0, matte.Output, "TyCtrl.TyEdge", "0", c)

-- the box behind: from the start of the line to the cursor, so it grows with the typing
local bmask = add("RectangleMask", "TyBoxMask", 2, 2)
expr(bmask, "Width", "TyCtrl.Curs.X + TyCtrl.Curs.Y - TyCtrl.LineX + 2*TyCtrl.TyPad")
expr(bmask, "Height", "TyCtrl.RuleY.Y - TyCtrl.RuleY.X + 2*TyCtrl.TyPad*" .. ASP)
expr(bmask, "Center", "Point(TyCtrl.LineX - TyCtrl.TyPad + Width/2, (TyCtrl.RuleY.X + TyCtrl.RuleY.Y)/2)")
expr(bmask, "CornerRadius", "TyCtrl.TyRound")
local box = add("Background", "ColTyBox", 2, 1)
box:SetInput("UseFrameFormatSettings", 1); L.color(box, 0.05, 0.06, 0.09, 1)
box.EffectMask = bmask.Mask
local boxed = add("Merge", "TyBoxed", 2, 0)
boxed.Background = ctrl.Output; boxed.Foreground = box.Output
expr(boxed, "Blend", "TyCtrl.TyBox")
local both = add("Merge", "TyBoth", 3, 0)
both.Background = boxed.Output; both.Foreground = inked.Output
local out = add("Merge", "TyFinal", 5, 0)
out.Background = ctrl.Output; out.Foreground = both.Output
expr(out, "Blend", "iif(TyCtrl.Idx < 1, 0, 1)")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 11, {"CTL", "TyText", "Font", "Font", "2"})
table.insert(spec, 12, {"CTL", "TyText", "Style", "", "2"})
holders[3] = {"ColTyBox", nil, "Box Colour"}
for i, h in ipairs(holders) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h[1], "TopLeftRed", h[3], g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "typing", name = "Typing", out = out, ctrl = ctrl, spec = spec, prefix = "ty",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("TyList", file:read("*a")); file:close() end
    L.keys(ctrl, "TyCue", os.getenv("FX_CUE"))
  end})
