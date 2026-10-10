-- Karaoke Caption: the line on screen fills with a second colour from left to right, in step with the speech.
-- Lines come from one text box; each starts with a time ("0:02 Text"), or Line Number is keyframed 1, 2, 3.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2" keyframes Line Number for a test.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Karaoke Caption")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local cur = L.cur("KaCtrl", "KaList", "KaTimed", "KaCue")

local ctrl, spec = L.panel(comp, "KaCtrl", {
  {"KaList",  L.text("Lines (0:00 Text)", "0:00 First the words appear\n0:01.5 then they fill with colour\n0:03.2 in time with the voice", nil, 8)},
  {"KaTimed", L.check("Lines Start With A Time (0:02 Text)", 1)},
  {"KaCue",   L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"KaSpeed", L.num("Characters Per Second (0 = fit the line's time)", 0, 0, 30)},
  {"KaEnd",   L.num("Fill Is Done At", 0.85, 0.1, 1)},
  {"KaStep",  L.check("Fill One Character At A Time", 0)},
  {"KaSize",  L.num("Size", 0.07, 0.02, 0.3)},
  {"KaPos",   L.point("Position", nil, true), {0.5, 0.14}},
  {"KaEdge",  L.num("Outline", 0.005, 0, 0.03)},
  {"KaOuter", L.num("Outer Outline", 0, 0, 0.03)},
  {"KaIn",    L.num("Pop Frames", 5, 1, 40)},
  {"KaOut",   L.num("Fade Out Frames", 3, 0, 40)},
  {"Idx",   L.num("Idx", 0, 0, 100, "Driver")},
  {"Since", L.num("Since", 0, 0, 1e5, "Driver")},
  {"Until", L.num("Until", 0, 0, 1e5, "Driver")},
  {"Cur",   L.text("Cur", "", "Driver", 1)},
  {"Chars", L.num("Chars", 0, 0, 1e4, "Driver")},
  {"Fill",  L.num("Fill", 0, 0, 1, "Driver")},
  {"Fade",  L.num("Fade", 0, 0, 1, "Driver")},
  {"Box",   L.point("Box", "Driver")},
})
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", "min(" .. cur(3) .. ", comp.RenderEnd - time + 1)")
expr(ctrl, "Cur", "Text(" .. cur(4) .. ")")
-- characters, counting a Chinese character (several bytes) as one and leaving spaces out
expr(ctrl, "Chars", [[(function(s) s = s:gsub("%s", "") local _, n = s:gsub("[^\128-\191]", "") return n end)(Cur.Value)]])
expr(ctrl, "Fill", [[(function(since, untl, n, speed, done, step, fps)
  if n < 1 then return 0 end
  local frames = (speed > 0) and n/speed*fps or done*(since + untl)
  local f = math.min(math.max((since + 1)/math.max(frames, 1), 0), 1)
  if step == 1 then f = math.floor(f*n + 0.0001)/n end
  return f
end)(Since, Until, Chars, KaSpeed, KaEnd, KaStep, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24))]])
expr(ctrl, "Fade", "iif(Idx < 1, 0, min((Since + 1)/max(KaIn, 1)*2, 1) * iif(KaOut <= 0, 1, min(max(Until/KaOut, 0), 1)))")

local text = add("TextPlus", "KaText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("Font", "Microsoft JhengHei"); text:SetInput("Style", "Bold")
expr(text, "StyledText", "Text(KaCtrl.Cur.Value)")
expr(text, "Center", "KaCtrl.KaPos")
-- a small pop when the line appears
expr(text, "Size", "KaCtrl.KaSize * (1 + 0.25*max(1 - (KaCtrl.Since + 1)/max(KaCtrl.KaIn, 1), 0)^2)")
-- left edge and width of the words as they came out, as fractions of the frame width
expr(ctrl, "Box", [[(function()
  if KaText.StyledText.Value == "" then return Point(0.5, 0) end
  local d = KaText.Output.DataWindow
  if not d then return Point(0.5, 0) end
  return Point(d.left / KaText.Output.Width, math.max(d.right - d.left, 0) / KaText.Output.Width)
end)()]])

local holders = {{"ColKa", {1, 1, 1}, "Colour"}, {"ColKaFill", {1, 0.85, 0.1}, "Fill Colour"},
                 {"ColKaEdge", {0.05, 0.05, 0.08}, "Outline Colour"}, {"ColKaFillEdge", {0.55, 0.08, 0.05}, "Outline Colour Of The Filled Part"},
                 {"ColKaOuter", {1, 1, 1}, "Outer Outline Colour"}}
for i, h in ipairs(holders) do
  local b = add("Background", h[1], -4 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local function cols(fill, edge)
  local c = {}
  for i, ch in ipairs({"Red", "Green", "Blue"}) do
    c[i] = fill .. ".TopLeft" .. ch; c[i + 3] = edge .. ".TopLeft" .. ch; c[i + 6] = "ColKaOuter.TopLeft" .. ch
  end
  return c
end
local plain = L.inked(comp, "KaPlain", 0, 0, text.Output, "KaCtrl.KaEdge", "KaCtrl.KaOuter", cols("ColKa", "ColKaEdge"))
local filled = L.inked(comp, "KaFilled", 0, 4, text.Output, "KaCtrl.KaEdge", "KaCtrl.KaOuter", cols("ColKaFill", "ColKaFillEdge"))

-- the filled version shows through a rectangle that grows from the left edge of the words
local wipe = add("RectangleMask", "KaWipe", 3, 3)
expr(wipe, "Width", "max(KaCtrl.Box.Y * KaCtrl.Fill + iif(KaCtrl.Fill >= 1, 0.1, 0), 0.00001)")
wipe:SetInput("Height", 2)
expr(wipe, "Center", "Point(KaCtrl.Box.X + KaCtrl.Box.Y * KaCtrl.Fill / 2 + iif(KaCtrl.Fill >= 1, 0.05, 0), 0.5)")
local both = add("Merge", "KaBoth", 3, 0)
both.Background = plain.Output; both.Foreground = filled.Output
both.EffectMask = wipe.Mask
expr(both, "Blend", "iif(KaCtrl.Fill > 0, 1, 0)")
local out = add("Merge", "KaFinal", 5, 0)
out.Background = ctrl.Output; out.Foreground = both.Output
expr(out, "Blend", "KaCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 8, {"CTL", "KaText", "Font", "Font", "2"})
table.insert(spec, 9, {"CTL", "KaText", "Style", "", "2"})
for i, h in ipairs(holders) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h[1], "TopLeftRed", h[3], g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "karaoke", name = "KaraokeCaption", out = out, ctrl = ctrl, spec = spec, prefix = "ka",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("KaList", file:read("*a")); file:close() end
    L.keys(ctrl, "KaCue", os.getenv("FX_CUE"))
  end})
