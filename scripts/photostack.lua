-- Photo Stack intro: stills from the clip land on a table one by one, the last photo is the live clip
-- and grows until it fills the frame. FX_SRC=media uses the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local useMedia = os.getenv("FX_SRC") == "media"

-- offset from the centre (x, y) and resting angle of every photo; the last one is the live clip
local PHOTOS = {
  {-0.22, 0.13, -9}, {0.21, 0.15, 7}, {-0.17, -0.14, 5}, {0.23, -0.11, -6}, {-0.04, 0.06, 11}, {0.02, -0.01, -3},
}
local N = #PHOTOS

comp:Lock()
comp:StartUndo("Build Photo Stack")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "StackCtrl", -5, -3)
ctrl.UserControls = {
  PhotoSize  = L.num("Photo Size", 0.42, 0.2, 0.7),
  Spread     = L.num("Spread", 1, 0, 1.6),
  Tilt       = L.num("Tilt", 1, 0, 3),
  Border     = L.num("Border", 0.04, 0, 0.1),
  ShadowAmt  = L.num("Shadow", 0.55, 0, 1),
  TableGain  = L.num("Backdrop Brightness", 0.3, 0, 1),
  TableBlur  = L.num("Backdrop Blur", 30, 0, 80),
  StillsFrom = L.num("Stills From", 0.05, 0, 1),
  StillsTo   = L.num("Stills To", 0.95, 0, 1),
  P = L.num("P", 0, 0, 1, "Driver"),
  Z = L.num("Z", 0, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
expr(ctrl, "P", L.P)
-- Z: the live photo growing to full frame over the last third
expr(ctrl, "Z", "(function(t) return t*t*(3 - 2*t) end)(min(max((P - 0.66)/0.29, 0), 1))")

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

local paper = add("Background", "Paper", -4, 3)
L.color(paper, 0.96, 0.95, 0.92)
paper:SetInput("UseFrameFormatSettings", 1)

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
  expr(card, "Size", "1 - 2*StackCtrl.Border")
  expr(card, "Center", "Point(0.5, 0.5 + 0.5*StackCtrl.Border)")

  -- e: 0..1 while the photo drops, q: the same eased out
  local t0 = 0.04 + (k - 1) * 0.09
  local e = string.format("min(max((StackCtrl.P - %g)/0.08, 0), 1)", t0)
  local fall = string.format("((1 - %s)^3)", e) -- 1 in the air, 0 landed
  local drop = add("Transform", "Drop" .. k, -4 + k, 2)
  drop.Input = card.Output
  local size = string.format("StackCtrl.PhotoSize * (1 + 0.9*%s)", fall)
  local angle = string.format("%g*StackCtrl.Tilt + %g*%s", ph[3], ph[3] > 0 and 16 or -16, fall)
  local cx = string.format("0.5 + %g*StackCtrl.Spread", ph[1])
  local cy = string.format("0.5 + %g*StackCtrl.Spread", ph[2])
  if live then
    -- grow until the picture area (not the paper border) covers the frame exactly
    local full = "(1/(1 - 2*StackCtrl.Border))"
    size = string.format("(%s) + (%s - (%s))*StackCtrl.Z", size, full, size)
    angle = string.format("(%s)*(1 - StackCtrl.Z)", angle)
    cx = string.format("(%s) + (0.5 - (%s))*StackCtrl.Z", cx, cx)
    cy = string.format("(%s) + (0.5 - 0.5*StackCtrl.Border*%s - (%s))*StackCtrl.Z", cy, full, cy)
  end
  expr(drop, "Size", size)
  expr(drop, "Angle", angle)
  expr(drop, "Center", string.format("Point(%s, %s)", cx, cy))

  local shadow = add("Shadow", "Shade" .. k, -4 + k, 3)
  shadow.Input = drop.Output
  shadow:SetInput("ShadowOffset", {0.506, 0.488})
  shadow:SetInput("Softness", 0.02)
  expr(shadow, "Alpha", "StackCtrl.ShadowAmt")

  local lay = add("Merge", "Lay" .. k, -4 + k, 5)
  lay.Background = last.Output
  lay.Foreground = shadow.Output
  expr(lay, "Blend", string.format("min(%s*3, 1)", e))
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
    {"CTL", "Paper", "TopLeftRed", "Paper Color", "2"},
    {"CTL", "Paper", "TopLeftGreen", "", "2"},
    {"CTL", "Paper", "TopLeftBlue", "", "2"},
    {"CTL", "StackCtrl", "ShadowAmt", "Shadow"},
    {"CTL", "StackCtrl", "TableGain", "Backdrop Brightness"},
    {"CTL", "StackCtrl", "TableBlur", "Backdrop Blur"},
    {"CTL", "StackCtrl", "StillsFrom", "Stills From"},
    {"CTL", "StackCtrl", "StillsTo", "Stills To"},
  })
  src.Input = source
else
  L.render(comp, finish.Output, os.getenv("FX_PREFIX") or "ps", tonumber(os.getenv("FX_STEPS") or "12"))
end
