-- Countdown: a clock that runs down to zero in real seconds, with an optional ring that empties around it.
-- In the last few seconds it changes colour and throbs once a second. It can also count up.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Countdown")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "CdCtrl", {
  {"CdFrom",   L.num("Seconds (0 = length of this clip)", 0, 0, 3600)},
  {"CdUp",     L.check("Count Up", 0)},
  {"CdFormat", L.combo("Format", {"0:10", "10", "10.0", "00:10.00"}, 0)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"CdPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"CdSize",   L.num("Size", 0.1, 0.02, 0.6)},
  {"CdRing",   L.num("Ring Thickness (0 = no ring)", 0.012, 0, 0.06)},
  {"CdRingSize", L.num("Ring Size", 0.5, 0.05, 1)},
  {"CdTrack",  L.num("Ring Track Opacity", 0.25, 0, 1)},
  {"CdEdge",   L.num("Outline", 0.004, 0, 0.02)},
  {"CdWarn",   L.num("Warn In The Last (seconds)", 3, 0, 60)},
  {"CdPulse",  L.num("Throb", 1, 0, 3)},
  {"Left",  L.num("Left", 0, 0, 1e5, "Driver")},
  {"Total", L.num("Total", 0, 0, 1e5, "Driver")},
  {"Hot",   L.num("Hot", 0, 0, 1, "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
expr(ctrl, "Total", "iif(CdFrom > 0, CdFrom, (comp.RenderEnd - comp.RenderStart + 1)/" .. FPS .. ")")
expr(ctrl, "Left", "max(Total - (time - comp.RenderStart)/" .. FPS .. ", 0)")
expr(ctrl, "Hot", "iif(CdWarn > 0 and Left <= CdWarn, 1, 0)")

local text = add("TextPlus", "CdText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("Font", "Arial"); text:SetInput("Style", "Bold")
-- whole seconds are rounded up, so "10" shows for the whole first second and "0" only at the very end
expr(text, "StyledText", [[Text((function(left, total, up, f)
  local v = (up == 1) and (total - left) or left
  if f == 2 then return string.format("%.1f", v) end
  if f == 3 then return string.format("%02d:%05.2f", math.floor(v/60), v % 60) end
  local s = (up == 1) and math.floor(v + 0.0001) or math.ceil(v - 0.0001)
  if f == 1 then return tostring(s) end
  return string.format("%d:%02d", math.floor(s/60), s % 60)
end)(CdCtrl.Left, CdCtrl.Total, CdCtrl.CdUp, CdCtrl.CdFormat))]])
expr(text, "Center", "CdCtrl.CdPos")
-- one throb per second while the warning is on
expr(text, "Size", "CdCtrl.CdSize * (1 + iif(CdCtrl.Hot == 1, 0.18*CdCtrl.CdPulse*(CdCtrl.Left - floor(CdCtrl.Left))^3, 0))")

-- the ring: full opacity for the part that is left, faint for the part that is gone
local ring = add("Custom", "CdRingDraw", -3, 1)
ring.Image1 = ctrl.Output
expr(ring, "NumberIn1", "CdCtrl.CdRingSize / 2")
expr(ring, "NumberIn2", "CdCtrl.CdRing")
expr(ring, "NumberIn3", "iif(CdCtrl.Total > 0, CdCtrl.Left/CdCtrl.Total, 0)")
expr(ring, "NumberIn4", "CdCtrl.CdTrack")
expr(ring, "NumberIn5", "CdCtrl.CdUp")
expr(ring, "PointIn1", "CdCtrl.CdPos")
ring:SetInput("Intermediate1", "(x - p1x)*w/h")
ring:SetInput("Intermediate2", "y - p1y")
ring:SetInput("Intermediate3", "if(n2 > 0, min(max((n2/2 - abs(sqrt(i1*i1 + i2*i2) - n1))*h + 0.5, 0), 1), 0)")
-- i4: how far round the ring this pixel is, 0 at the top, going clockwise to 1
ring:SetInput("Intermediate4", "frac(atan2(i1, i2)/360 + 1)")
ring:SetInput("Intermediate5", "i3*if(if(n5 > 0, i4 <= 1 - n3, i4 >= 1 - n3), 1, n4)")
for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do ring:SetInput(c .. "Expression", "i5") end

local matte = add("Merge", "CdMatte", -1, 0)
matte.Background = ring.Output; matte.Foreground = text.Output

local holders = {{"ColCd", {1, 1, 1}}, {"ColCdWarn", {1, 0.2, 0.15}}, {"ColCdEdge", {0.05, 0.05, 0.08}}}
for i, h in ipairs(holders) do
  local b = add("Background", h[1], -4 + i, -5)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  L.color(b, h[2][1], h[2][2], h[2][3], 1)
end
local cols = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  cols[i] = string.format("iif(CdCtrl.Hot == 1, ColCdWarn.TopLeft%s, ColCd.TopLeft%s)", ch, ch)
  cols[i + 3] = "ColCdEdge.TopLeft" .. ch
  cols[i + 6] = "0"
end
local painted = L.inked(comp, "CdPaint", 1, 0, matte.Output, "CdCtrl.CdEdge", "0", cols)
local out = add("Merge", "CdFinal", 4, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 5, {"CTL", "CdText", "Font", "Font", "2"})
table.insert(spec, 6, {"CTL", "CdText", "Style", "", "2"})
for i, h in ipairs({{"ColCd", "Colour"}, {"ColCdWarn", "Warning Colour"}, {"ColCdEdge", "Outline Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h[1], "TopLeftRed", h[2], g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "countdown", name = "Countdown", out = out, ctrl = ctrl, spec = spec, prefix = "cd"})
