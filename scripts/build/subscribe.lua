-- Subscribe Reminder: "like, subscribe, and turn on the bell". A row the way a video site lays it out: a pill with a
-- thumb up, a number and a thumb down, and next to it the subscribe button. Three clicks, one after the other: the
-- thumb fills in, the button turns grey and gets a bell and its second label, the bell fills in and rings.
-- Everything is drawn by the template, there is no logo in it. A title, so it has no image input.
-- FX_EXPORT=1 dumps the macro source. FX_TEXTFILE: label, label after the click, number, number after the click.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Subscribe Reminder")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"

-- subscribe button, its label, the grey pills, what is written and drawn on them
local PRESETS = {
  {"Dark",  {0.95,0.95,0.95, 0.06,0.06,0.06, 0.16,0.16,0.16, 0.95,0.95,0.95}},
  {"Light", {0.06,0.06,0.06, 1.00,1.00,1.00, 0.95,0.95,0.95, 0.06,0.06,0.06}},
  {"Red Button", {0.90,0.10,0.12, 1.00,1.00,1.00, 0.95,0.95,0.95, 0.06,0.06,0.06}},
}
local names, prows = {"Custom"}, {}
for _, p in ipairs(PRESETS) do names[#names + 1] = p[1]; prows[#prows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
local TABLE = "({" .. table.concat(prows, ",") .. "})"
local HOLD = {"ColSubA", "ColSubInkA", "ColSubB", "ColSubInkB"}
local function col(k, c)
  local ch = ({"Red", "Green", "Blue"})[c]
  return string.format("iif(SubCtrl.SubPreset == 0, %s.TopLeft%s, %s[max(SubCtrl.SubPreset, 1)][%d])", HOLD[k], ch, TABLE, (k - 1)*3 + c)
end

local ctrl, spec = L.panel(comp, "SubCtrl", {
  {"SubLike", L.check("Like Button", 1)},
  {"SubCount", L.text("Number Of Likes", "1.2萬", nil, 1)},
  {"SubCountB", L.text("Number Of Likes After The Click", "1.2萬", nil, 1)},
  {"SubLikeAt", L.num("Like Is Clicked At (0 to 1 of the clip)", 0.22, 0, 1)},
  {"SubText", L.text("Label", "訂閱", nil, 1)},
  {"SubDone", L.text("Label After The Click", "已訂閱", nil, 1)},
  {"SubPress", L.num("Subscribe Is Clicked At (0 to 1 of the clip)", 0.45, 0, 1)},
  {"SubBell", L.check("Bell", 1)},
  {"SubBellAt", L.num("Bell Is Clicked At (0 to 1 of the clip)", 0.68, 0, 1)},
  {"SubFirst", L.check("Subscribe Button On The Left", 0)},
  {"SubRing", L.check("Ring Around Each Click", 1)},
  {"SubPos",  L.point("Position", nil, true), {0.5, 0.2}},
  {"SubSize", L.num("Size", 0.04, 0.01, 0.2)},
  {"SubShadow", L.num("Shadow", 0.35, 0, 1)},
  {"SubIn",   L.num("Entrance Frames", 10, 1, 60)},
  {"SubOut",  L.num("Leave Frames", 8, 0, 60)},
  {"SubPreset", L.combo("Colours", names, 1)},
  {"Show",  L.num("Show", 0, 0, 1, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Ta",    L.num("Ta", 0, -1e5, 1e5, "Driver")},
  {"Tb",    L.num("Tb", 0, -1e5, 1e5, "Driver")},
  {"Tc",    L.num("Tc", 0, -1e5, 1e5, "Driver")},
  {"KH",    L.point("KH", "Driver")},
  {"KWid",  L.point("KWid", "Driver")},
  {"KWc",   L.num("KWc", 0, 0, 4, "Driver")},
  {"KL",    L.point("KL", "Driver")},
  {"KS",    L.point("KS", "Driver")},
  {"KXa",   L.point("KXa", "Driver")},
  {"KXb",   L.point("KXb", "Driver")},
  {"KXc",   L.point("KXc", "Driver")},
  {"KXd",   L.point("KXd", "Driver")},
  {"KRing", L.point("KRing", "Driver")},
})
expr(ctrl, "Show", "min(min(max((time - comp.RenderStart + 1)/max(SubIn, 1), 0), 1), iif(SubOut > 0, min(max((comp.RenderEnd - time + 1)/SubOut, 0), 1), 1))")
expr(ctrl, "Scale", "(function(t) t = t - 1 return max(1 + 2.70158*t*t*t + 1.70158*t*t, 0) end)(Show)")
-- Ta, Tb, Tc: frames since the thumb, the button and the bell were clicked, negative before
local SPAN = "(comp.RenderEnd - comp.RenderStart)"
expr(ctrl, "Ta", "iif(SubLike > 0, time - comp.RenderStart - SubLikeAt*" .. SPAN .. ", -1)")
expr(ctrl, "Tb", "time - comp.RenderStart - SubPress*" .. SPAN)
expr(ctrl, "Tc", "iif(SubBell > 0 and Tb >= 0, time - comp.RenderStart - SubBellAt*" .. SPAN .. ", -1)")

-- the words, and hidden rulers that are only measured: both labels, both numbers, and a "|" for the height of a line
local function window(tool, pick, none)
  return "(function() local d = " .. tool .. ".Output.DataWindow if not d or d.left < -99999 or " .. tool .. ".StyledText.Value == '' then return " .. none
    .. " end local w, h = " .. tool .. ".Output.Width, " .. tool .. ".Output.Height return " .. pick .. " end)()"
end
local label = add("TextPlus", "SubLabel", -3, 0)
label:SetInput("UseFrameFormatSettings", 1)
label:SetInput("Font", "Microsoft JhengHei"); label:SetInput("Style", "Bold")
expr(label, "StyledText", "Text(iif(SubCtrl.Tb >= 0, SubCtrl.SubDone.Value, SubCtrl.SubText.Value))")
expr(label, "Size", "SubCtrl.SubSize")
local count = add("TextPlus", "SubNumber", -3, 1)
count:SetInput("UseFrameFormatSettings", 1); count:SetInput("HorizontalLeftCenterRight", -1)
expr(count, "Font", "SubLabel.Font"); expr(count, "Style", "SubLabel.Style"); expr(count, "Size", "SubCtrl.SubSize")
expr(count, "StyledText", "Text(iif(SubCtrl.Ta >= 0 and SubCtrl.SubCountB.Value ~= '', SubCtrl.SubCountB.Value, SubCtrl.SubCount.Value))")
for i, what in ipairs({"Text(SubCtrl.SubText.Value)", "Text(SubCtrl.SubDone.Value)", 'Text("|")', "Text(SubCtrl.SubCount.Value)", "Text(SubCtrl.SubCountB.Value)"}) do
  local t = add("TextPlus", "SubRule" .. i, -3, 3 + i)
  t:SetInput("UseFrameFormatSettings", 1)
  expr(t, "Font", "SubLabel.Font"); expr(t, "Style", "SubLabel.Style"); expr(t, "Size", "SubCtrl.SubSize")
  expr(t, "StyledText", what)
end
local WIDE = "(d.right - d.left)/w"
-- KH: height of a pill (frame widths), and how far the middle of a line's ink is above the point the text is put
-- at (fraction of the frame height). KWid: width of the two labels. KWc: width of the wider number.
expr(ctrl, "KH", "Point(" .. window("SubRule3", "(d.top - d.bottom)/w", "0.03") .. " + 1.0*SubSize, " .. window("SubRule3", "(d.top + d.bottom)/2/h - 0.5", "0") .. ")")
expr(ctrl, "KWid", "Point(" .. window("SubRule1", WIDE, "0") .. ", " .. window("SubRule2", WIDE, "0") .. ")")
expr(ctrl, "KWc", "max(" .. window("SubRule4", WIDE, "0") .. ", " .. window("SubRule5", WIDE, "0") .. ")")
-- The row, left to right: [thumb number | thumb down]  [label]  or after the click  [bell label v]
-- KL: left end of the like pill, its width. KS: left end of the subscribe button, its width right now.
-- KXa: thumb, start of the number. KXb: the dividing line, thumb down. KXc: bell, the little v.
-- KXd: where the label is put, and how it is lined up there (0 its middle, -1 its start).
local LAY = [[(function(s, h, w1, w2, wc, like, bell, done, first, pick)
  local pad, a, gi, g = 0.68*s, 0.5*h, 0.32*s, 0.45*s
  local wl = like > 0 and (pad + a + gi + wc + 0.5*s + 0.5*s + a + pad) or 0
  local ws1 = w1 + 2.0*s
  local ws2 = bell > 0 and (pad + a + gi + w2 + gi + 0.5*a + pad) or (w2 + 2.0*s)
  local x0 = SubPos.X - (wl + (like > 0 and g or 0) + math.max(ws1, ws2))/2
  local xs = x0 + wl + (like > 0 and g or 0)
  if first > 0 then xs, x0 = x0, x0 + (done > 0 and ws2 or ws1) + g end
  if pick == 1 then return Point(x0, wl) end
  if pick == 2 then return Point(xs, done > 0 and ws2 or ws1) end
  if pick == 3 then return Point(x0 + pad + a/2, x0 + pad + a + gi) end
  if pick == 4 then return Point(x0 + pad + a + gi + wc + 0.5*s, x0 + pad + a + gi + wc + 1.0*s + a/2) end
  if pick == 5 then return Point(xs + pad + a/2, xs + ws2 - pad - 0.25*a) end
  if done > 0 and bell > 0 then return Point(xs + pad + a + gi, -1) end
  return Point(xs + (done > 0 and ws2 or ws1)/2, 0)
end)(SubSize, KH.X, KWid.X, KWid.Y, KWc, SubLike, SubBell, iif(Tb >= 0, 1, 0), SubFirst, PICK)]]
for i, id in ipairs({"KL", "KS", "KXa", "KXb", "KXc", "KXd"}) do expr(ctrl, id, (LAY:gsub("PICK", tostring(i)))) end
-- KRing: the click ring, its middle and how far it has grown (0..1, 0 = none)
expr(ctrl, "KRing", [[(function(a, b, c)
  local t, x = -1, 0
  if a >= 0 then t, x = a, KXa.X end
  if b >= 0 then t, x = b, KS.X + KS.Y/2 end
  if c >= 0 then t, x = c, KXc.X end
  if t < 0 or t > 14 or SubRing < 1 then return Point(x, 0) end
  return Point(x, (t + 1)/15)
end)(Ta, Tb, Tc)]])

for i, h in ipairs(HOLD) do
  local b = add("Background", h, -4 + i, -6)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  local p = PRESETS[1][2]
  L.color(b, p[i*3 - 2], p[i*3 - 1], p[i*3], 1)
end
local BG = {"TopLeftRed", "TopLeftGreen", "TopLeftBlue"}
local function plate(name, x, y, mask)
  local b = add("Background", name, x, y)
  b:SetInput("UseFrameFormatSettings", 1); L.color(b, 1, 1, 1, 1)
  b.EffectMask = mask.Mask
  return b
end
local function tint(tool, ids, k) for c = 1, 3 do expr(tool, ids[c], col(k, c)) end end
local Y = "SubCtrl.SubPos.Y"
-- a dip when clicked: down fast, back with a little bounce
local function dip(t, deep) return "(function(t) if t < 0 or t > 12 then return 1 end return 1 - " .. deep .. "*math.exp(-t/3)*math.cos(t*0.9) end)(SubCtrl." .. t .. ")" end
local function over(name, x, y, bg, fg, blend)
  local m = add("Merge", name, x, y)
  m.Background = bg.Output; m.Foreground = fg.Output
  if blend then expr(m, "Blend", blend) end
  return m
end

-- An icon is put together from masks, in units of half the pill height, around (cx, y). It is drawn as a line
-- drawing until `on` says it is filled in: the outline is the shape minus a slightly smaller copy of itself.
local A = "(SubCtrl.KH.X*0.5)"
local function shape(name, x, y, cx, parts, flip)
  local prev
  for i, p in ipairs(parts) do -- kind, width, height, x, y, corner, angle
    local m = add(p[1], name .. "Part" .. i, x + i - 1, y - 1)
    expr(m, "Center", string.format("Point(%s + %g*%s, %s + %g*%s*%s)", cx, p[4], A, Y, p[5]*(flip and -1 or 1), A, ASP))
    expr(m, "Width", p[2] .. "*" .. A)
    -- an ellipse mask measures its height in frame widths, a rectangle mask in frame heights
    expr(m, "Height", p[3] .. "*" .. A .. (p[1] == "RectangleMask" and "*" .. ASP or ""))
    if p[6] then m:SetInput("CornerRadius", p[6]) end
    if p[7] then m:SetInput("Angle", p[7]*(flip and -1 or 1)) end
    if prev then m.EffectMask = prev.Mask end
    prev = m
  end
  return plate(name .. "Shape", x, y, prev)
end
local function icon(name, x, y, cx, parts, on, k, flip)
  local s = shape(name, x, y, cx, parts, flip)
  local thin = add("ErodeDilate", name .. "Thin", x + 1, y + 1)
  thin.Input = s.Output; thin:SetInput("Filter", 3)
  expr(thin, "XAmount", "-0.1*" .. A)
  local c = add("Custom", name, x + 2, y)
  c.Image1 = s.Output; c.Image2 = thin.Output
  expr(c, "NumberIn1", on)
  for i = 1, 3 do expr(c, "NumberIn" .. (i + 1), col(k, i)) end
  L.cx(c, "Intermediate1", "if(n1 > 0, a1, max(a1 - a2, 0))")
  L.cx(c, "RedExpression", "n2*i1"); L.cx(c, "GreenExpression", "n3*i1"); L.cx(c, "BlueExpression", "n4*i1")
  L.cx(c, "AlphaExpression", "i1")
  return c
end
local THUMB = {{"RectangleMask", 0.26, 0.60, -0.40, -0.14, 0.3}, {"RectangleMask", 0.70, 0.60, 0.13, -0.14, 0.45},
               {"RectangleMask", 0.30, 0.74, -0.03, 0.20, 1, -14}}
local BELL = {{"EllipseMask", 0.72, 0.72, 0, 0.09}, {"RectangleMask", 0.72, 0.40, 0, -0.12, 0}, {"RectangleMask", 0.98, 0.14, 0, -0.33, 1},
              {"EllipseMask", 0.22, 0.22, 0, -0.46}, {"EllipseMask", 0.13, 0.13, 0, 0.49}}

-- the like pill
local lmask = add("RectangleMask", "SubLikeMask", -1, -1)
expr(lmask, "Center", "Point(SubCtrl.KL.X + SubCtrl.KL.Y/2, " .. Y .. ")")
expr(lmask, "Width", "max(SubCtrl.KL.Y, 0.00001)"); expr(lmask, "Height", "SubCtrl.KH.X*" .. ASP)
lmask:SetInput("CornerRadius", 1)
local lpill = plate("SubLikePill", -1, 0, lmask)
tint(lpill, BG, 3)
tint(count, {"Red1", "Green1", "Blue1"}, 4)
expr(count, "Center", "Point(SubCtrl.KXa.Y, " .. Y .. " - SubCtrl.KH.Y)")
local up = icon("SubUp", 0, -4, "SubCtrl.KXa.X", THUMB, "iif(SubCtrl.Ta >= 0, 1, 0)", 4)
-- the thumb jumps and tips when it is clicked
local upGo = add("Transform", "SubUpGo", 3, -4)
upGo.Input = up.Output
expr(upGo, "Pivot", "Point(SubCtrl.KXa.X, " .. Y .. ")")
expr(upGo, "Size", "(function(t) if t < 0 or t > 14 then return 1 end return 1 + 0.45*math.exp(-t/4)*math.sin(t*0.7) end)(SubCtrl.Ta)")
expr(upGo, "Angle", "(function(t) if t < 0 or t > 14 then return 0 end return -22*math.exp(-t/4)*math.sin(t*0.7) end)(SubCtrl.Ta)")
local down = icon("SubDown", 0, -8, "SubCtrl.KXb.Y", THUMB, "0", 4, true)
local dmask = add("RectangleMask", "SubDividerMask", 4, -9)
expr(dmask, "Center", "Point(SubCtrl.KXb.X, " .. Y .. ")")
expr(dmask, "Width", "SubCtrl.SubSize*0.04"); expr(dmask, "Height", "SubCtrl.KH.X*0.55*" .. ASP)
local divider = plate("SubDivider", 4, -8, dmask)
tint(divider, BG, 4)
local l1 = over("SubLike1", 0, 0, lpill, count)
local l2 = over("SubLike2", 1, 0, l1, upGo)
local l3 = over("SubLike3", 2, 0, l2, down)
local l4 = over("SubLike4", 3, 0, l3, divider, "0.3")
local lgo = add("Transform", "SubLikeDip", 4, 0)
lgo.Input = l4.Output
expr(lgo, "Pivot", "Point(SubCtrl.KXa.X, " .. Y .. ")"); expr(lgo, "Size", dip("Ta", "0.08"))

-- the subscribe button
local smask = add("RectangleMask", "SubButtonMask", -1, 3)
expr(smask, "Center", "Point(SubCtrl.KS.X + SubCtrl.KS.Y/2, " .. Y .. ")")
expr(smask, "Width", "SubCtrl.KS.Y"); expr(smask, "Height", "SubCtrl.KH.X*" .. ASP)
smask:SetInput("CornerRadius", 1)
local spill = plate("SubButton", -1, 4, smask)
for c = 1, 3 do
  expr(spill, BG[c], "iif(SubCtrl.Tb >= 0, " .. col(3, c) .. ", " .. col(1, c) .. ")")
  expr(label, ({"Red1", "Green1", "Blue1"})[c], "iif(SubCtrl.Tb >= 0, " .. col(4, c) .. ", " .. col(2, c) .. ")")
end
expr(label, "HorizontalLeftCenterRight", "SubCtrl.KXd.Y")
expr(label, "Center", "Point(SubCtrl.KXd.X, " .. Y .. " - SubCtrl.KH.Y)")
local bell = icon("SubBellIcon", 0, 7, "SubCtrl.KXc.X", BELL, "iif(SubCtrl.Tc >= 0, 1, 0)", 4)
local swing = add("Transform", "SubBellSwing", 3, 7)
swing.Input = bell.Output
expr(swing, "Pivot", string.format("Point(SubCtrl.KXc.X, %s + 0.49*%s*%s)", Y, A, ASP))
expr(swing, "Angle", "(function(t) if t < 0 then return 0 end return 30*math.sin(t*0.85)*math.exp(-t/9) end)(SubCtrl.Tc)")
expr(swing, "Size", "(function(t) if t < 0 or t > 14 then return 1 end return 1 + 0.3*math.exp(-t/4)*math.sin(t*0.7) end)(SubCtrl.Tc)")
local vee = shape("SubVee", 0, 11, "SubCtrl.KXc.Y", {{"RectangleMask", 0.30, 0.075, -0.09, 0, 1, -42}, {"RectangleMask", 0.30, 0.075, 0.09, 0, 1, 42}})
tint(vee, BG, 4)
local EXTRA = "iif(SubCtrl.Tb >= 0 and SubCtrl.SubBell > 0, 1, 0)"
local s1 = over("SubButton1", 0, 4, spill, label)
local s2 = over("SubButton2", 1, 4, s1, swing, EXTRA)
local s3 = over("SubButton3", 2, 4, s2, vee, EXTRA)
local sgo = add("Transform", "SubButtonDip", 3, 4)
sgo.Input = s3.Output
expr(sgo, "Pivot", "Point(SubCtrl.KS.X + SubCtrl.KS.Y/2, " .. Y .. ")"); expr(sgo, "Size", dip("Tb", "0.12"))

local both = over("SubBoth", 5, 2, sgo, lgo, "SubCtrl.SubLike")
local room = add("SetDomain", "SubRoom", 6, 2)
room.Input = both.Output; room:SetInput("Mode", "Set")
local soft = add("Blur", "SubSoft", 6, 3)
soft.Input = room.Output
expr(soft, "XBlurSize", "SubCtrl.SubSize * 18")
local lit = add("Custom", "SubLit", 7, 2)
lit.Image1 = room.Output; lit.Image2 = soft.Output
expr(lit, "NumberIn1", "SubCtrl.SubShadow")
expr(lit, "NumberIn2", "SubCtrl.SubSize * 0.2")
for _, c in ipairs({"r", "g", "b"}) do L.cx(lit, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", c .. "1") end
L.cx(lit, "AlphaExpression", "a1 + (1 - a1)*n1*geta2b(x, y + n2)")
-- the ring that spreads from a click
local rmask = add("EllipseMask", "SubRingMask", 7, 4)
rmask:SetInput("Solid", 0)
expr(rmask, "BorderWidth", "SubCtrl.SubSize*0.12*(1 - SubCtrl.KRing.Y)")
expr(rmask, "Center", "Point(SubCtrl.KRing.X, " .. Y .. ")")
expr(rmask, "Width", "SubCtrl.KH.X*(0.5 + 1.6*SubCtrl.KRing.Y)"); expr(rmask, "Height", "Width")
local ring = plate("SubRingBody", 8, 4, rmask)
local ringed = over("SubRinged", 8, 2, lit, ring, "iif(SubCtrl.KRing.Y > 0, 1 - SubCtrl.KRing.Y, 0)")
local enter = add("Transform", "SubEnter", 9, 2)
enter.Input = ringed.Output
expr(enter, "Pivot", "SubCtrl.SubPos"); expr(enter, "Size", "SubCtrl.Scale")
local out = add("Merge", "SubFinal", 10, 2)
out.Background = ctrl.Output; out.Foreground = enter.Output
expr(out, "Blend", "iif(SubCtrl.Show > 0, 1, 0)")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 13, {"CTL", "SubLabel", "Font", "Font", "2"})
table.insert(spec, 14, {"CTL", "SubLabel", "Style", "", "2"})
local colnames = {"Custom Colour Of The Subscribe Button", "Custom Colour Of Its Label", "Custom Colour Of The Grey Pills", "Custom Colour Of What Is On Them"}
for i, h in ipairs(HOLD) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h, "TopLeftRed", colnames[i], g}
  spec[#spec + 1] = {"CTL", h, "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h, "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "subscribe", name = "SubscribeReminder", out = out, ctrl = ctrl, spec = spec, prefix = "sub",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then
      for _, id in ipairs({"SubText", "SubDone", "SubCount", "SubCountB"}) do ctrl:SetInput(id, file:read("*l") or "") end
      file:close()
    end
  end})
