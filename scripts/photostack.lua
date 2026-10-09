-- Photo Stack intro: stills from the clip slide onto a table one by one, the last photo is the live clip
-- and grows until it fills the frame. FX_SRC=media uses the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local useMedia = os.getenv("FX_SRC") == "media"

-- every photo: resting offset from the centre (x, y), resting angle, and the direction it slides in from
local PHOTOS = {
  {-0.22, 0.13, -9, -0.9, 0.3}, {0.21, 0.15, 7, 0.9, 0.35}, {-0.17, -0.14, 5, -0.85, -0.5},
  {0.23, -0.11, -6, 0.9, -0.4}, {-0.04, 0.06, 11, 0.15, 1.0}, {0.02, -0.01, -3, -0.1, -1.0},
}
local N = #PHOTOS
local SLIDE, STAGGER = 0.2, 0.085 -- how long one photo takes to arrive, and the gap between photos (in P)

comp:Lock()
comp:StartUndo("Build Photo Stack")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "StackCtrl", -5, -3)
ctrl.UserControls = {
  PhotoSize  = L.num("Photo Size", 0.42, 0.2, 0.7),
  Spread     = L.num("Spread", 1, 0, 1.6),
  Tilt       = L.num("Tilt", 1, 0, 3),
  Border     = L.num("Border", 0.022, 0, 0.06),
  Corner     = L.num("Corner Roundness", 0.012, 0, 0.1),
  Blur       = L.check("Motion Blur", 1),
  ShadowAmt  = L.num("Shadow", 0.6, 0, 1),
  ShadowSoft = L.num("Shadow Softness", 1, 0, 3),
  ShadowDist = L.num("Shadow Distance", 1, 0, 3),
  TableGain  = L.num("Backdrop Brightness", 0.3, 0, 1),
  TableBlur  = L.num("Backdrop Blur", 30, 0, 80),
  StillsFrom = L.num("Stills From", 0.05, 0, 1),
  StillsTo   = L.num("Stills To", 0.95, 0, 1),
  P = L.num("P", 0, 0, 1, "Driver"),
  Z = L.num("Z", 0, 0, 1, "Driver"),
  Aspect = L.num("Aspect", 1.7778, 0.2, 5, "Driver"),
  Inner = L.num("Inner", 0.9, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
expr(ctrl, "P", L.P)
-- Z: the live photo growing to full frame at the end, eased at both ends
expr(ctrl, "Z", "(function(t) return t*t*t*(t*(6*t - 15) + 10) end)(min(max((P - 0.67)/0.28, 0), 1))")
expr(ctrl, "Aspect", "Width/Height")
-- Inner: how much of the card the picture takes up; the paper border is the same width on all four sides
expr(ctrl, "Inner", "1 - 2*Border*Aspect")

local src = add("BrightnessContrast", "Src", -5, 0)
local source = useMedia and mediaIn.Output or L.testsource(comp).Output
src.Input = source

-- table: the clip itself, blurred and darkened
local blur = add("Blur", "TableBlur", -4, 5)
blur.Input = src.Output
expr(blur, "XBlurSize", "StackCtrl.TableBlur")
local table_ = add("BrightnessContrast", "Table", -3, 5)
table_.Input = blur.Output
expr(table_, "Gain", "StackCtrl.TableGain")

local paperMask = add("RectangleMask", "PaperShape", -4, 2)
expr(paperMask, "Width", "StackCtrl.Inner + 2*StackCtrl.Border")
paperMask:SetInput("Height", 1)
expr(paperMask, "CornerRadius", "StackCtrl.Corner")
local paper = add("Background", "Paper", -4, 3)
L.color(paper, 0.97, 0.96, 0.93)
paper:SetInput("UseFrameFormatSettings", 1)
paper.EffectMask = paperMask.Mask

local last = table_
for k, ph in ipairs(PHOTOS) do
  local live = (k == N)
  local image = src
  if not live then
    image = add("TimeStretcher", "Still" .. k, -4 + k, 0)
    image.Input = src.Output
    image:SetInput("InterpolateBetweenFrames", 0)
    expr(image, "SourceTime", string.format(
      "floor(comp.GlobalStart + (StackCtrl.StillsFrom + (StackCtrl.StillsTo - StackCtrl.StillsFrom) * %g) * (comp.GlobalEnd - comp.GlobalStart))",
      (k - 1) / (N - 2)))
  end
  local card = add("Merge", "Card" .. k, -4 + k, 1)
  card.Background = paper.Output
  card.Foreground = image.Output
  expr(card, "Size", "StackCtrl.Inner")

  -- fall: 1 while the photo is still outside the frame, easing down to 0 once it has come to rest
  local t0 = 0.02 + (k - 1) * STAGGER
  local fall = string.format("((1 - min(max((StackCtrl.P - %g)/%g, 0), 1))^4)", t0, SLIDE)
  local drop = add("Transform", "Drop" .. k, -4 + k, 2)
  drop.Input = card.Output
  local size = string.format("StackCtrl.PhotoSize * (1 + 0.25*%s)", fall)
  local angle = string.format("%g*StackCtrl.Tilt + %g*%s", ph[3], ph[3] > 0 and 38 or -38, fall)
  local cx = string.format("0.5 + %g*StackCtrl.Spread + %g*%s", ph[1], ph[4], fall)
  local cy = string.format("0.5 + %g*StackCtrl.Spread + %g*%s", ph[2], ph[5], fall)
  local lift = fall -- how far above the table the photo is, for the shadow
  if live then
    -- grow until the picture area (not the paper border) covers the frame exactly
    size = string.format("(%s) + (1/StackCtrl.Inner - (%s))*StackCtrl.Z", size, size)
    angle = string.format("(%s)*(1 - StackCtrl.Z)", angle)
    cx = string.format("(%s) + (0.5 - (%s))*StackCtrl.Z", cx, cx)
    cy = string.format("(%s) + (0.5 - (%s))*StackCtrl.Z", cy, cy)
    lift = string.format("(%s + 2*StackCtrl.Z)", fall)
  end
  expr(drop, "Size", size)
  expr(drop, "Angle", angle)
  expr(drop, "Center", string.format("Point(%s, %s)", cx, cy))
  expr(drop, "MotionBlur", "StackCtrl.Blur")
  drop:SetInput("Quality", 4)

  -- the higher the photo, the further away and the softer its shadow
  local shadow = add("Shadow", "Shade" .. k, -4 + k, 3)
  shadow.Input = drop.Output
  expr(shadow, "ShadowOffset", string.format(
    "Point(0.5 + 0.004*StackCtrl.ShadowDist*(1 + 5*%s), 0.5 - 0.007*StackCtrl.ShadowDist*(1 + 5*%s))", lift, lift))
  expr(shadow, "Softness", string.format("0.04*StackCtrl.ShadowSoft*(1 + 2*%s)", lift))
  expr(shadow, "Alpha", live and "StackCtrl.ShadowAmt*(1 - StackCtrl.Z)" or "StackCtrl.ShadowAmt")

  local lay = add("Merge", "Lay" .. k, -4 + k, 5)
  lay.Background = last.Output
  lay.Foreground = shadow.Output
  expr(lay, "Blend", string.format("iif(StackCtrl.P >= %g, 1, 0)", t0))
  last = lay
end

-- hand over to the untouched clip at the very end so the cut to the next clip is seamless
local finish = add("Merge", "Finish", 4, 5)
finish.Background = last.Output
finish.Foreground = src.Output
expr(finish, "Blend", "min(max((StackCtrl.P - 0.95)/0.04, 0), 1)")

mediaOut.Input = finish.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  src.Input = nil
  L.export(comp, "photostack", {
    {"NAME", "PhotoStack"},
    {"MAIN", "Src", "Input"},
    {"OUT", "Finish", "Output"},
    {"CTL", "StackCtrl", "PhotoSize", "Photo Size"},
    {"CTL", "StackCtrl", "Spread", "Spread"},
    {"CTL", "StackCtrl", "Tilt", "Tilt"},
    {"CTL", "StackCtrl", "Border", "Border"},
    {"CTL", "StackCtrl", "Corner", "Corner Roundness"},
    {"CTL", "Paper", "TopLeftRed", "Paper Color", "2"},
    {"CTL", "Paper", "TopLeftGreen", "", "2"},
    {"CTL", "Paper", "TopLeftBlue", "", "2"},
    {"CTL", "StackCtrl", "ShadowAmt", "Shadow"},
    {"CTL", "StackCtrl", "ShadowSoft", "Shadow Softness"},
    {"CTL", "StackCtrl", "ShadowDist", "Shadow Distance"},
    {"CTL", "StackCtrl", "Blur", "Motion Blur"},
    {"CTL", "StackCtrl", "TableGain", "Backdrop Brightness"},
    {"CTL", "StackCtrl", "TableBlur", "Backdrop Blur"},
    {"CTL", "StackCtrl", "StillsFrom", "Stills From"},
    {"CTL", "StackCtrl", "StillsTo", "Stills To"},
  })
  src.Input = source
else
  L.render(comp, finish.Output, os.getenv("FX_PREFIX") or "ps", tonumber(os.getenv("FX_STEPS") or "12"))
end
