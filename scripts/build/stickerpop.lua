-- Sticker Pop: a picture with a clear background (a PNG, a logo, a cut-out) pops in, keeps moving a little while
-- it stays, and pops out again. Optional outline around its shape, the way a sticker is cut, and a shadow.
-- The clear parts of the picture stay clear. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Sticker Pop")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "StkCtrl", {
  {"StkSize",   L.num("Size", 0.7, 0.05, 1.5)},
  {"StkTilt",   L.num("Tilt (degrees)", 0, -45, 45)},
  {"StkFlip",   L.check("Mirror", 0)},
  {"StkEnter",  L.combo("Entrance", {"Pop", "Spin In", "Drop In", "Fade", "None"}, 0)},
  {"StkIn",     L.num("Entrance Frames", 10, 1, 60)},
  {"StkOut",    L.num("Exit Frames", 6, 0, 60)},
  {"StkBounce", L.num("Bounce", 1, 0, 3)},
  {"StkIdle",   L.combo("While It Stays", {"Still", "Wobble", "Float", "Pulse", "Shake"}, 1)},
  {"StkAmount", L.num("Movement Amount", 1, 0, 4)},
  {"StkSpeed",  L.num("Movements Per Second", 1.5, 0.1, 8)},
  {"StkOutline", L.num("Outline Width", 0.012, 0, 0.05)},
  {"StkShadow", L.num("Shadow", 0.4, 0, 1)},
  {"StkShadowOff", L.num("Shadow Distance", 0.012, 0, 0.08)},
  {"StkShadowSoft", L.num("Shadow Softness", 0.012, 0, 0.08)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"T",     L.num("T", 0, 0, 1, "Driver")},
  {"Gone",  L.num("Gone", 0, 0, 1, "Driver")},
  {"Wave",  L.num("Wave", 0, -1, 1, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Ang",   L.num("Ang", 0, -360, 360, "Driver")},
  {"Fade",  L.num("Fade", 1, 0, 1, "Driver")},
  {"At",    L.point("At", "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
expr(ctrl, "T", "min(max((time - comp.RenderStart + 1)/max(StkIn, 1), 0), 1)")
expr(ctrl, "Gone", "iif(StkOut <= 0, 0, 1 - min(max((comp.RenderEnd - time + 1)/StkOut, 0), 1))")
-- Wave: the idle movement, a sine that swings StkSpeed times a second, held still until the sticker has arrived
expr(ctrl, "Wave", "T * StkAmount * sin(6.2831853 * StkSpeed * (time - comp.RenderStart) / iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24))")
expr(ctrl, "Scale", [[(function(e, t, g, b, idle, wave)
  local s = 1
  if e <= 1 then local u = t - 1 s = 1 + (1.70158*b + 1)*u*u*u + 1.70158*b*u*u end
  if e <= 2 then s = s*(1 - g*g) end
  if idle == 3 then s = s*(1 + 0.06*wave) end
  return math.max(s, 0)
end)(StkEnter, T, Gone, StkBounce, StkIdle, Wave) * StkSize]])
expr(ctrl, "Ang", [[(function(e, t, idle, wave, amt)
  local a = 0
  if e == 1 then a = -220*(1 - t)^3 end
  if idle == 1 then a = a + 6*wave end
  if idle == 4 then a = a + 3*amt*t*(math.sin(time*91.7)*43758.5453 % 1 - 0.5) end
  return a
end)(StkEnter, T, StkIdle, Wave, StkAmount) + StkTilt]])
-- Drop In falls from above the frame and bounces where it lands
expr(ctrl, "At", [[(function(e, t, idle, wave, amt, b)
  local x, y = 0.5, 0.5
  if e == 2 then
    local u, k = t, 1
    if u < 0.3636 then k = 7.5625*u*u
    elseif u < 0.7273 then u = u - 0.5455 k = 1 - b*(0.25 - 7.5625*u*u)
    elseif u < 0.9091 then u = u - 0.8182 k = 1 - b*(0.0625 - 7.5625*u*u)
    else u = u - 0.9545 k = 1 - b*(0.015625 - 7.5625*u*u) end
    y = y + (t < 0.3636 and 1.1 or 0.4)*(1 - k)
  end
  if idle == 2 then y = y + 0.025*wave end
  if idle == 4 then
    x = x + 0.008*amt*t*(math.sin(time*12.9898)*43758.5453 % 1 - 0.5)
    y = y + 0.008*amt*t*(math.sin(time*78.233)*43758.5453 % 1 - 0.5)
  end
  return Point(x, y)
end)(StkEnter, T, StkIdle, Wave, StkAmount, StkBounce)]])
expr(ctrl, "Fade", "iif(StkEnter == 3, T*(1 - Gone), iif(StkEnter == 4, 1, min(T*4, 1)))")

local move = add("Transform", "StkMove", -3, 0)
move.Input = srcs[1].Output
expr(move, "Center", "StkCtrl.At")
expr(move, "Size", "StkCtrl.Scale")
expr(move, "Angle", "StkCtrl.Ang")
expr(move, "FlipHoriz", "StkCtrl.StkFlip")

-- the outline: the shape of the picture grown outwards, filled with one colour, behind the picture
local grow = add("ErodeDilate", "StkGrow", -1, 1)
grow.Input = move.Output; grow:SetInput("Filter", 3)
expr(grow, "XAmount", "StkCtrl.StkOutline * StkCtrl.Scale")
local col = add("Background", "ColStkOutline", -3, -5)
col:SetInput("UseFrameFormatSettings", 0); col:SetInput("Width", 16); col:SetInput("Height", 16)
L.color(col, 1, 1, 1, 1)
local ink = add("Custom", "StkInk", 0, 0)
ink.Image1 = move.Output; ink.Image2 = grow.Output; ink.Image3 = col.Output
expr(ink, "NumberIn1", "iif(StkCtrl.StkOutline > 0, 1, 0)")
L.cx(ink, "Intermediate1", "(1 - a1)*a2*n1")
for _, c in ipairs({"r", "g", "b"}) do
  L.cx(ink, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", string.format("%s1 + i1*get%s3b(0.5, 0.5)", c, c))
end
L.cx(ink, "AlphaExpression", "a1 + i1")

-- the shadow: the same shape, blurred and moved down to the right
local soft = add("Blur", "StkSoft", 0, 1)
soft.Input = ink.Output
expr(soft, "XBlurSize", "StkCtrl.StkShadowSoft * 60")
local out = add("Custom", "StkFinal", 1, 0)
out.Image1 = ink.Output; out.Image2 = soft.Output
expr(out, "NumberIn1", "StkCtrl.StkShadow")
expr(out, "NumberIn2", "StkCtrl.StkShadowOff")
expr(out, "NumberIn3", "StkCtrl.Fade")
for _, c in ipairs({"r", "g", "b"}) do L.cx(out, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", c .. "1*n3") end
L.cx(out, "AlphaExpression", "n3*(a1 + (1 - a1)*n1*geta2b(x - n2*h/w, y + n2))")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColStkOutline", "TopLeftRed", "Outline Colour", "3"}
spec[#spec + 1] = {"CTL", "ColStkOutline", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColStkOutline", "TopLeftBlue", "", "3"}

-- the test feeds it a drawn sticker with a clear background (a tilted block with a word on it), over the stand-in
if not L.DRY then
  comp:Lock()
  local mask = add("RectangleMask", "PrevStkMask", -9, -4)
  mask:SetInput("Width", 0.5); mask:SetInput("Height", 0.42); mask:SetInput("CornerRadius", 0.5); mask:SetInput("Angle", 8)
  local body = add("Background", "PrevStkBody", -9, -3)
  body:SetInput("UseFrameFormatSettings", 1)
  L.color(body, 1.0, 0.33, 0.42, 1)
  body.EffectMask = mask.Mask
  local word = add("TextPlus", "PrevStkWord", -8, -4)
  word:SetInput("UseFrameFormatSettings", 1)
  word:SetInput("Font", "Arial"); word:SetInput("Style", "Bold"); word:SetInput("Size", 0.2)
  word:SetInput("StyledText", "WOW!"); word:SetInput("AngleZ", 8)
  local stk = add("Merge", "PrevStk", -8, -3)
  stk.Background = body.Output; stk.Foreground = word.Output
  srcs[1].Input = stk.Output; ins[1] = stk
  comp:Unlock()
end
L.ship(comp, {slug = "stickerpop", name = "StickerPop", out = out, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "stk",
  show = function()
    comp:Lock()
    local base = L.testsource(comp, "B", 1)
    local over = add("Merge", "PrevUnder", 4, 4)
    over.Background = base.Output; over.Foreground = out.Output
    comp:Unlock()
    return over.Output
  end})
