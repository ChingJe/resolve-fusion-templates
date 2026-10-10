-- Comment Card: one comment the way a video site or a social feed shows it: a round picture with the first letter
-- of the name, the name, when it was written, the words, a heart with a number. Or a notification: a square icon,
-- a title, "now" at the far end, the words. The card always fits what is written on it.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source. FX_TEXTFILE: name, when, then the words.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Comment Card")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"

-- card, words, dimmer words, heart
local PRESETS = {
  {"Light", {1.00,1.00,1.00, 0.08,0.08,0.10, 0.45,0.47,0.50, 0.93,0.20,0.30}},
  {"Dark",  {0.13,0.14,0.17, 0.95,0.95,0.96, 0.60,0.62,0.66, 1.00,0.35,0.45}},
}
local names, rows = {"Custom"}, {}
for _, p in ipairs(PRESETS) do names[#names + 1] = p[1]; rows[#rows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
local TABLE = "({" .. table.concat(rows, ",") .. "})"
local HOLD = {"ColCcCard", "ColCcText", "ColCcDim", "ColCcHeart"}
local function col(k, c)
  local ch = ({"Red", "Green", "Blue"})[c]
  return string.format("iif(CcCtrl.CcPreset == 0, %s.TopLeft%s, %s[max(CcCtrl.CcPreset, 1)][%d])", HOLD[k], ch, TABLE, (k - 1)*3 + c)
end

local TEXTS = {"Name", "Meta", "Body", "Foot", "Init"}
local list = {
  {"CcStyle", L.combo("Kind", {"Comment", "Notification"}, 0)},
  {"CcName",  L.text("Name", "小明", nil, 1)},
  {"CcMeta",  L.text("When", "2 小時前", nil, 1)},
  {"CcBody",  L.text("Words", "這段也太好笑了吧\n我已經看了十次", nil, 4)},
  {"CcLikesOn", L.check("Heart And Number", 1)},
  {"CcLikes", L.num("Likes", 128, 0, 100000, nil, true)},
  {"CcLikesEnd", L.num("Likes Grow To (0: they stay)", 0, 0, 100000, nil, true)},
  {"CcFoot",  L.text("After The Number", "回覆", nil, 1)},
  {"CcPos",   L.point("Position", nil, true), {0.5, 0.5}},
  {"CcSize",  L.num("Size", 0.035, 0.01, 0.12)},
  {"CcMinW",  L.num("Narrowest Card", 0.3, 0, 1)},
  {"CcPad",   L.num("Padding", 0.8, 0.2, 2)},
  {"CcRound", L.num("Roundness", 0.35, 0, 1)},
  {"CcShadow", L.num("Shadow", 0.35, 0, 1)},
  {"CcEnter", L.combo("Entrance", {"Pop", "From Left", "From Right", "From Below", "From Above", "Fade", "None"}, 0)},
  {"CcIn",    L.num("Entrance Frames", 10, 1, 60)},
  {"CcLeave", L.check("Leave The Same Way At The End", 1)},
  {"CcOut",   L.num("Leave Frames", 8, 1, 60)},
  {"CcPreset", L.combo("Colours", names, 1)},
  {"Show",  L.num("Show", 0, 0, 1, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Move",  L.point("Move", "Driver")},
  {"Fade",  L.num("Fade", 1, 0, 1, "Driver")},
  {"KFoot", L.num("KFoot", 0, 0, 1, "Driver")},
  {"KNameH", L.num("KNameH", 0, 0, 1, "Driver")},
  {"KText", L.num("KText", 0, 0, 4, "Driver")},
  {"KCard", L.point("KCard", "Driver")},
  {"KLeft", L.num("KLeft", 0, -4, 4, "Driver")},
  {"KTop",  L.num("KTop", 0, -4, 4, "Driver")},
  {"KCol",  L.num("KCol", 0, -4, 4, "Driver")},
  {"KRowY", L.num("KRowY", 0, 0, 4, "Driver")},
}
-- for every piece of text: <id>A where its ink starts (left, top, as fractions of the frame), <id>S how big it is
-- (width, height, both in frame widths)
for _, t in ipairs(TEXTS) do
  list[#list + 1] = {t .. "A", L.point(t .. "A", "Driver")}
  list[#list + 1] = {t .. "S", L.point(t .. "S", "Driver")}
end
local ctrl, spec = L.panel(comp, "CcCtrl", list)

expr(ctrl, "Show", [[min(min(max((time - comp.RenderStart + 1)/max(CcIn, 1), 0), 1),
  iif(CcLeave > 0, min(max((comp.RenderEnd - time + 1)/max(CcOut, 1), 0), 1), 1))]])
expr(ctrl, "Scale", "iif(CcEnter == 0, (function(t) t = t - 1 return max(1 + 2.70158*t*t*t + 1.70158*t*t, 0) end)(Show), 1)")
expr(ctrl, "Move", [[(function(e, asp)
  local u = (1 - Show)^3
  if e == 1 then return Point(-0.2*u, 0) elseif e == 2 then return Point(0.2*u, 0)
  elseif e == 3 then return Point(0, -u*(CcPos.Y + KCard.Y*asp/2 + 0.05))
  elseif e == 4 then return Point(0, u*(1 - CcPos.Y + KCard.Y*asp/2 + 0.05)) end
  return Point(0, 0)
end)(CcEnter, ]] .. ASP .. ")")
expr(ctrl, "Fade", "iif(CcEnter == 6 or CcEnter == 3 or CcEnter == 4, iif(Show > 0, 1, 0), iif(CcEnter == 5, Show, min(Show*3, 1)))")

-- the pieces of text, each made in the middle of the frame, measured, and then moved to its place
local SIZES = {Name = 0.8, Meta = 0.7, Body = 1, Foot = 0.75, Init = 1.05}
local WHAT = {
  Name = "Text(CcCtrl.CcName.Value)", Meta = "Text(CcCtrl.CcMeta.Value)", Body = "Text(CcCtrl.CcBody.Value)",
  -- the number (growing over the clip when asked to), then the word after it
  Foot = [[Text((function(a, b, word, p)
    local n = a
    if b > a then p = min(max(p, 0), 1) n = a + (b - a)*p*p*(3 - 2*p) end
    local s = string.format("%d", math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    if word ~= "" then s = s .. string.rep(string.char(194, 160), 4) .. word end
    return s
  end)(CcCtrl.CcLikes, CcCtrl.CcLikesEnd, CcCtrl.CcFoot.Value, (time - comp.RenderStart - CcCtrl.CcIn)/max(comp.RenderEnd - comp.RenderStart - CcCtrl.CcIn - CcCtrl.CcOut - 12, 1)))]],
  Init = 'Text((CcCtrl.CcName.Value:match("^%s*([^" .. string.char(128) .. "-" .. string.char(191) .. "][" .. string.char(128) .. "-" .. string.char(191) .. "]*)") or ""):upper())',
}
local COLS = {Name = 2, Meta = 3, Body = 2, Foot = 3}
local made = {}
for i, t in ipairs(TEXTS) do
  local x = add("TextPlus", "Cc" .. t .. "T", -3, i*2 - 2)
  x:SetInput("UseFrameFormatSettings", 1)
  x:SetInput("HorizontalLeftCenterRight", -1)
  if t == "Body" then x:SetInput("Font", "Microsoft JhengHei"); x:SetInput("Style", "Regular")
  else expr(x, "Font", "CcBodyT.Font"); x:SetInput("Style", (t == "Name" or t == "Init") and "Bold" or "Regular") end
  expr(x, "Size", "CcCtrl.CcSize * " .. SIZES[t])
  expr(x, "StyledText", WHAT[t])
  for c, ch in ipairs({"Red1", "Green1", "Blue1"}) do
    if COLS[t] then expr(x, ch, col(COLS[t], c)) else x:SetInput(ch, 1) end
  end
  local n = "Cc" .. t .. "T"
  expr(ctrl, t .. "A", "(function() local d = " .. n .. ".Output.DataWindow if not d or " .. n .. ".StyledText.Value == '' then return Point(0.5, 0.5) end return Point(d.left/"
    .. n .. ".Output.Width, d.top/" .. n .. ".Output.Height) end)()")
  expr(ctrl, t .. "S", "(function() local d = " .. n .. ".Output.DataWindow if not d or " .. n .. ".StyledText.Value == '' then return Point(0, 0) end local w = "
    .. n .. ".Output.Width return Point(max(d.right - d.left, 0)/w, max(d.top - d.bottom, 0)/w) end)()")
  local m = add("Transform", "Cc" .. t .. "M", -2, i*2 - 2)
  m.Input = x.Output
  made[t] = m
end

-- the layout, in frame widths, measured from the top left corner of the card
local S = "CcSize"
expr(ctrl, "KFoot", "iif(CcLikesOn > 0 and CcStyle == 0, 1, 0)")
expr(ctrl, "KNameH", "max(NameS.Y, MetaS.Y)")
expr(ctrl, "KText", "max(max(NameS.X + iif(MetaS.X > 0, 0.6*CcSize + MetaS.X, 0), BodyS.X), KFoot*(1.1*CcSize + FootS.X))")
expr(ctrl, "KRowY", "CcPad*CcSize + KNameH + iif(BodyS.Y > 0, 0.45*CcSize + BodyS.Y, 0) + 0.6*CcSize")
expr(ctrl, "KCard", "Point(max(CcPad*CcSize*2 + 2.5*CcSize + KText, CcMinW), CcPad*CcSize*2 + max(2*CcSize, KRowY - CcPad*CcSize - 0.6*CcSize + KFoot*(0.6*CcSize + max(FootS.Y, 0.75*CcSize))))")
expr(ctrl, "KLeft", "CcPos.X - KCard.X/2")
expr(ctrl, "KTop", "CcPos.Y + KCard.Y/2*" .. ASP)
expr(ctrl, "KCol", "KLeft + CcPad*CcSize + 2.5*CcSize")
local C = "CcCtrl."
local function place(t, tx, ty) -- left and top of the ink
  expr(made[t], "Center", string.format("Point(0.5 + (%s) - %s%sA.X, 0.5 + (%s) - %s%sA.Y)", tx, C, t, ty, C, t))
end
local PAD = "CcCtrl.CcPad*CcCtrl.CcSize"
place("Name", C .. "KCol", C .. "KTop - " .. PAD .. "*" .. ASP)
place("Meta", "iif(CcCtrl.CcStyle == 0, CcCtrl.KCol + CcCtrl.NameS.X + 0.6*CcCtrl.CcSize, CcCtrl.KLeft + CcCtrl.KCard.X - " .. PAD .. " - CcCtrl.MetaS.X)",
  C .. "KTop - (" .. PAD .. " + max(CcCtrl.NameS.Y - CcCtrl.MetaS.Y, 0))*" .. ASP)
place("Body", C .. "KCol", C .. "KTop - (" .. PAD .. " + CcCtrl.KNameH + 0.45*CcCtrl.CcSize)*" .. ASP)
place("Foot", C .. "KCol + 1.1*CcCtrl.CcSize", C .. "KTop - (CcCtrl.KRowY + max(0.75*CcCtrl.CcSize - CcCtrl.FootS.Y, 0)/2)*" .. ASP)
local AVX = "CcCtrl.KLeft + " .. PAD .. " + CcCtrl.CcSize"
local AVY = "CcCtrl.KTop - (" .. PAD .. " + CcCtrl.CcSize)*" .. ASP
expr(made.Init, "Center", string.format("Point(0.5 + (%s) - CcCtrl.InitA.X - CcCtrl.InitS.X/2, 0.5 + (%s) - CcCtrl.InitA.Y + CcCtrl.InitS.Y*%s/2)", AVX, AVY, ASP))

local function plate(name, row, mask)
  local b = add("Background", name, 0, row)
  b:SetInput("UseFrameFormatSettings", 1)
  b.EffectMask = mask.Mask
  return b
end
local cardMask = add("RectangleMask", "CcCardMask", 0, -3)
expr(cardMask, "Center", "CcCtrl.CcPos")
expr(cardMask, "Width", "CcCtrl.KCard.X"); expr(cardMask, "Height", "CcCtrl.KCard.Y*" .. ASP)
expr(cardMask, "CornerRadius", "CcCtrl.CcRound")
local card = plate("CcCard", -2, cardMask)
for c, ch in ipairs({"TopLeftRed", "TopLeftGreen", "TopLeftBlue"}) do expr(card, ch, col(1, c)) end
card:SetInput("TopLeftAlpha", 1)
-- the picture: a circle on a comment, a square with round corners on a notification
local avMask = add("RectangleMask", "CcAvatarMask", 1, -3)
expr(avMask, "Center", "Point(" .. AVX .. ", " .. AVY .. ")")
expr(avMask, "Width", "CcCtrl.CcSize*2"); expr(avMask, "Height", "CcCtrl.CcSize*2*" .. ASP)
expr(avMask, "CornerRadius", "iif(CcCtrl.CcStyle == 0, 1, 0.45)")
local avatar = plate("ColCcAvatar", -1, avMask)
L.color(avatar, 0.20, 0.55, 0.95, 1)
-- the heart: a square standing on its corner with a circle on each of its two upper sides
local HX = "CcCtrl.KCol + 0.375*CcCtrl.CcSize"
local HY = "CcCtrl.KTop - (CcCtrl.KRowY + 0.375*CcCtrl.CcSize)*" .. ASP
local A = "(CcCtrl.CcSize*0.75/1.707)"
local h1 = add("RectangleMask", "CcHeartA", 2, -3)
expr(h1, "Center", string.format("Point(%s, %s - 0.073*%s*%s)", HX, HY, A, ASP))
expr(h1, "Width", A); expr(h1, "Height", A .. "*" .. ASP); h1:SetInput("Angle", 45)
local prev = h1
for i, sign in ipairs({"-", "+"}) do
  local e = add("EllipseMask", "CcHeart" .. (i == 1 and "B" or "C"), 2 + i, -3)
  expr(e, "Center", string.format("Point(%s %s 0.3536*%s, %s + (0.3536 - 0.073)*%s*%s)", HX, sign, A, HY, A, ASP))
  expr(e, "Width", A); expr(e, "Height", A) -- an ellipse mask measures its height in frame widths, a rectangle mask does not
  e.EffectMask = prev.Mask
  prev = e
end
local heart = plate("CcHeart", 0, prev)
for c, ch in ipairs({"TopLeftRed", "TopLeftGreen", "TopLeftBlue"}) do expr(heart, ch, col(4, c)) end
heart:SetInput("TopLeftAlpha", 1)

local layers = {{avatar, "1"}, {made.Init, "1"}, {made.Name, "1"}, {made.Meta, "1"}, {made.Body, "1"},
                {heart, "CcCtrl.KFoot"}, {made.Foot, "CcCtrl.KFoot"}}
local last = card
for i, l in ipairs(layers) do
  local m = add("Merge", "CcOver" .. i, 2 + i, 2)
  m.Background = last.Output; m.Foreground = l[1].Output
  expr(m, "Blend", l[2])
  last = m
end
local room = add("SetDomain", "CcRoom", 10, 2)
room.Input = last.Output; room:SetInput("Mode", "Set")
local soft = add("Blur", "CcSoft", 10, 3)
soft.Input = room.Output
expr(soft, "XBlurSize", "CcCtrl.CcSize * 25")
local lit = add("Custom", "CcLit", 11, 2)
lit.Image1 = room.Output; lit.Image2 = soft.Output
expr(lit, "NumberIn1", "CcCtrl.CcShadow")
expr(lit, "NumberIn2", "CcCtrl.CcSize * 0.25")
for _, c in ipairs({"r", "g", "b"}) do L.cx(lit, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", c .. "1") end
L.cx(lit, "AlphaExpression", "a1 + (1 - a1)*n1*geta2b(x, y + n2)")
local enter = add("Transform", "CcEnterM", 12, 2)
enter.Input = lit.Output
expr(enter, "Pivot", "CcCtrl.CcPos")
expr(enter, "Size", "CcCtrl.Scale")
expr(enter, "Center", "Point(0.5 + CcCtrl.Move.X, 0.5 + CcCtrl.Move.Y)")
local out = add("Merge", "CcFinal", 13, 2)
out.Background = ctrl.Output; out.Foreground = enter.Output
expr(out, "Blend", "CcCtrl.Fade")

for i, h in ipairs(HOLD) do
  local b = add("Background", h, -4 + i, -6)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  local p = PRESETS[1][2]
  L.color(b, p[i*3 - 2], p[i*3 - 1], p[i*3], 1)
end

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 10, {"CTL", "CcBodyT", "Font", "Font"})
local groups = {{"ColCcAvatar", "Picture Colour"}, {"ColCcCard", "Custom Card Colour"}, {"ColCcText", "Custom Words Colour"},
                {"ColCcDim", "Custom Colour Of The Small Words"}, {"ColCcHeart", "Custom Heart Colour"}}
for i, h in ipairs(groups) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h[1], "TopLeftRed", h[2], g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "commentcard", name = "CommentCard", out = out, ctrl = ctrl, spec = spec, prefix = "cc",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then
      ctrl:SetInput("CcName", file:read("*l")); ctrl:SetInput("CcMeta", file:read("*l")); ctrl:SetInput("CcBody", file:read("*a"))
      file:close()
    end
  end})
