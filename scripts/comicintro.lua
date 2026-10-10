-- Comic Intro: comic pages flip past while the camera keeps pulling back, until the pages turn out to be
-- inside the letters of a title, which then settles as white letters on a coloured box.
-- Every comic panel plays a different part of the clip. FX_SRC=media uses the clip, FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
-- the camera pulls back out of this point, which has to lie inside a stroke of a letter
local PIVOT_X = tonumber(os.getenv("COMIC_PX") or "0.5482")
local PIVOT_Y = tonumber(os.getenv("COMIC_PY") or "0.4995")

comp:Lock()
comp:StartUndo("Build Comic Intro")
local mediaIn, mediaOut = L.clear(comp)
local add, expr, color = L.adder(comp), L.expr, L.color
local src = add("BrightnessContrast", "Src", -9, 4)
local feed = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
src.Input = feed.Output

---------------------------------------------------------------- controller
local ctrl = add("Background", "ComicCtrl", -5, -3)
local function num(label, def, lo, hi, page)
  return {LINKID_DataType = "Number", INPID_InputControl = "SliderControl", LINKS_Name = label,
          INP_Default = def, INP_MinScale = lo, INP_MaxScale = hi, ICS_ControlPage = page or "Comic"}
end
ctrl.UserControls = {
  PageCount = num("Page Count", 30, 5, 80),
  MaxZoom   = num("Start Zoom", 60, 2, 120),
  PivotX    = num("Zoom Pivot X", PIVOT_X, 0, 1),
  PivotY    = num("Zoom Pivot Y", PIVOT_Y, 0, 1),
  TextSize  = num("Text Size", 0.2, 0.02, 0.5),
  PageStart = num("Pages Start Size", 2.4, 0.3, 6),
  PageEnd   = num("Pages End Size", 0.5, 0.1, 3),
  PScale = num("PScale", 1, 0, 6, "Driver"),
  P      = num("P", 0, 0, 1, "Driver"),
  K      = num("K", 0, 0, 100, "Driver"),
  E      = num("E", 0, 0, 1, "Driver"),
  Scroll = num("Scroll", 0, 0, 100, "Driver"),
  BlurLen= num("BlurLen", 0, 0, 1, "Driver"),
  ZT     = num("ZT", 0, 0, 1, "Driver"),
  ZE     = num("ZE", 0, 0, 1, "Driver"),
  Zoom   = num("Zoom", 1, 0, 120, "Driver"),
  WinSize = num("WinSize", 0, 0, 3, "Driver"),
  WinFade = num("WinFade", 0, 0, 1, "Driver"),
  White  = num("White", 0, 0, 1, "Driver"),
  Flash  = num("Flash", 0, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
expr(ctrl, "P", "min(max((time - comp.RenderStart) / max(comp.RenderEnd - comp.RenderStart, 1), 0), 1)")
expr(ctrl, "K", "P * PageCount")
-- the pages shrink at a steady rate all the way through, so the camera never seems to stand still;
-- the letters shrink much faster on top of that, which reads as the pages lying further away
expr(ctrl, "PScale", "PageStart * (PageEnd/max(PageStart, 0.001)) ^ min(P/0.8, 1)")
expr(ctrl, "E", "min((K - floor(K)) / 0.55, 1)")
expr(ctrl, "Scroll", "floor(K) + E*E*(3 - 2*E)")
expr(ctrl, "BlurLen", "0.10 * sin(3.14159265 * E)")
expr(ctrl, "ZT", "min(max((P - 0.06) / 0.68, 0), 1)")
expr(ctrl, "ZE", "ZT*ZT*(3 - 2*ZT)")
expr(ctrl, "Zoom", "MaxZoom ^ (1 - ZE) * (1 + 0.05*(1 - P))")
expr(ctrl, "WinSize", "(2*max(max(PivotX, 1 - PivotX), max(PivotY, 1 - PivotY)) + 0.05) * Zoom / (MaxZoom*1.05)")
expr(ctrl, "WinFade", "1 - min(max((ZE - 0.40) / 0.22, 0), 1)")
expr(ctrl, "White", "min(max((P - 0.76) / 0.08, 0), 1)")
expr(ctrl, "Flash", "max(1 - abs(P - 0.83) / 0.07, 0)")

---------------------------------------------------------------- video atlas: 3x3 tiles, each a different part of the clip
local TW, TH = 960, 540
local tile = add("BetterResize", "TileSize", -8, 4)
tile.Input = src.Output
tile:SetInput("Width", TW); tile:SetInput("Height", TH)
tile:SetInput("KeepAspect", 0)

local atlas = add("Background", "AtlasBase", -8, 6)
color(atlas, 0, 0, 0)
atlas:SetInput("UseFrameFormatSettings", 0)
atlas:SetInput("Width", TW * 3); atlas:SetInput("Height", TH * 3)
local last = atlas
for k = 0, 8 do
  local ts = add("TimeStretcher", "Part" .. (k + 1), -7 + k, 4)
  ts.Input = tile.Output
  ts:SetInput("InterpolateBetweenFrames", 0)
  -- play from k/9 of the way through the whole source, wrapping at the end
  expr(ts, "SourceTime", string.format(
    "comp.GlobalStart + floor((time - comp.GlobalStart) + %d * (comp.GlobalEnd - comp.GlobalStart + 1) / 9) %% (comp.GlobalEnd - comp.GlobalStart + 1)", k))
  local m = add("Merge", "Tile" .. (k + 1), -7 + k, 6)
  m.Background = last.Output
  m.Foreground = ts.Output
  m:SetInput("Center", {(k % 3 + 0.5) / 3, (math.floor(k / 3) + 0.5) / 3})
  last = m
end

---------------------------------------------------------------- comic pages
local pgBG = add("Background", "PageBase", -5, 0)
color(pgBG, 0, 0, 0)
pgBG:SetInput("Depth", 4) -- float32, the next node stores coordinates in the channels
pgBG:SetInput("UseFrameFormatSettings", 1)

-- pass 1: panel layout. R,G = position inside the panel, B = panel random id, A = distance to panel edge
local cells = add("Custom", "PageCells", -4, 0)
cells.Image1 = pgBG.Output
expr(cells, "NumberIn1", "ComicCtrl.Scroll")
-- the page is looked up through the page zoom: XS, YS are page coordinates (+8 keeps them positive)
expr(cells, "NumberIn2", "max(ComicCtrl.PScale, 0.001)")
expr(cells, "PointIn1", "Point(ComicCtrl.PivotX, ComicCtrl.PivotY)")
local XS, YS = "((x - p1x)/n2 + p1x + 8)", "((y - p1y)/n2 + p1y + 8)"
cells:SetInput("Intermediate1", YS .. " + n1")
cells:SetInput("Intermediate2", "floor(frac(i1)*3) + floor(i1)*3")
cells:SetInput("Intermediate3", "2 + floor(frac(abs(sin(i2*12.9898)*43758.5453))*2)")
cells:SetInput("Intermediate4", XS .. "*i3")
cells:SetInput("RedExpression", "frac(i4)")
cells:SetInput("GreenExpression", "frac(frac(i1)*3)")
cells:SetInput("BlueExpression", "frac(abs(sin((floor(i4) + i2*7.13)*78.233)*43758.5453))")
cells:SetInput("AlphaExpression", "min(min(frac(i4), 1-frac(i4))/i3, min(frac(frac(i1)*3), 1-frac(frac(i1)*3))*h/(3*w))")

-- pass 2: fill every panel with one atlas tile, add gutters, ink border and a light halftone
local pages = add("Custom", "PageInk", -3, 0)
pages.Image1 = cells.Output
pages.Image2 = last.Output
expr(pages, "NumberIn1", "ComicCtrl.Scroll")
expr(pages, "NumberIn2", "max(ComicCtrl.PScale, 0.001)")
expr(pages, "PointIn1", "Point(ComicCtrl.PivotX, ComicCtrl.PivotY)")
pages:SetInput("NumberIn3", 150)  -- halftone dots across the frame width
pages:SetInput("NumberIn4", 0.14) -- halftone strength
pages:SetInput("Intermediate1", YS .. " + n1")
pages:SetInput("Intermediate2", "floor(frac(i1)*3) + floor(i1)*3")
pages:SetInput("Intermediate3", "2 + floor(frac(abs(sin(i2*12.9898)*43758.5453))*2)")
pages:SetInput("Intermediate4", "floor(b1*8.999)")
pages:SetInput("Intermediate5", "(i4 - 3*floor(i4/3) + 0.004 + 0.992*r1) / 3")
pages:SetInput("Intermediate6", "(floor(i4/3) + 0.5 + (g1 - 0.5)*0.992*i3/3) / 3")
pages:SetInput("Intermediate7", "if(dist(frac(" .. XS .. "*n3), frac(i1*n3*h/w), 0.5, 0.5) < 0.3, 1, 0)")
local function chan(c)
  return "if(a1 < 0.006, 0.95, if(a1 < 0.0095, 0.05, get" .. c .. "2d(i5, i6) * (1 - n4*i7)))"
end
pages:SetInput("RedExpression", chan("r"))
pages:SetInput("GreenExpression", chan("g"))
pages:SetInput("BlueExpression", chan("b"))
pages:SetInput("AlphaExpression", "1")

local blur = add("DirectionalBlur", "FlipBlur", -2, 0)
blur.Input = pages.Output
blur:SetInput("Angle", 90)
expr(blur, "Length", "ComicCtrl.BlurLen")

---------------------------------------------------------------- title + plate
local CENTER = "Point(0.5 + (0.5 - ComicCtrl.PivotX)*(ComicCtrl.Zoom - 1), 0.5 + (0.5 - ComicCtrl.PivotY)*(ComicCtrl.Zoom - 1))"

local text = add("TextPlus", "TitleText", -2, -2)
text:SetInput("StyledText", "YOUR TITLE")
text:SetInput("Font", "Impact")
text:SetInput("Style", "Regular")
expr(text, "Size", "ComicCtrl.TextSize * ComicCtrl.Zoom")
expr(text, "Center", CENTER)

local black = add("Background", "Backdrop", -2, 2)
color(black, 0.02, 0.02, 0.025)

local red = add("TextPlus", "BoxText", -2, 3)
expr(red, "StyledText", "TitleText.StyledText.Value")
expr(red, "Font", "TitleText.Font")
expr(red, "Style", "TitleText.Style")
expr(red, "Size", "TitleText.Size")
expr(red, "Center", "TitleText.Center")
red:SetInput("ElementShape1", 2) -- border fill
red:SetInput("Level1", 0)        -- one box around the whole text
red:SetInput("ExtendHorizontal1", 0.25)
red:SetInput("ExtendVertical1", 0.2)
red:SetInput("Red1", 0.84); red:SetInput("Green1", 0.07); red:SetInput("Blue1", 0.09)

local plate = add("Merge", "Plate", -1, 2)
plate.Background = black.Output
plate.Foreground = red.Output

local cover = add("Merge", "CoverMerge", 0, 0)
cover.Background = blur.Output
cover.Foreground = plate.Output
cover.EffectMask = text.Output
cover:SetInput("ApplyMaskInverted", 1)

local win = add("RectangleMask", "PageWindow", 0, -1)
expr(win, "Center", "Point(ComicCtrl.PivotX, ComicCtrl.PivotY)")
expr(win, "Width", "ComicCtrl.WinSize")
expr(win, "Height", "ComicCtrl.WinSize")

local winMerge = add("Merge", "WindowMerge", 1, 0)
winMerge.Background = cover.Output
winMerge.Foreground = blur.Output
winMerge.EffectMask = win.Mask
expr(winMerge, "Blend", "ComicCtrl.WinFade")

local white = add("Merge", "WhiteFill", 2, 0)
white.Background = winMerge.Output
white.Foreground = text.Output
expr(white, "Blend", "ComicCtrl.White")

local glow = add("SoftGlow", "FinishGlow", 3, 0)
glow.Input = white.Output
glow:SetInput("Threshold", 0.7)
glow:SetInput("XGlowSize", 14)
expr(glow, "Gain", "0.12 + 0.9*ComicCtrl.Flash")

for _, t in ipairs({ctrl, text, black, win, red}) do
  if t.UseFrameFormatSettings then t:SetInput("UseFrameFormatSettings", 1) end
end
mediaOut.Input = glow.Output

comp:EndUndo(true)
comp:Unlock()


if os.getenv("FX_EXPORT") == "1" then
  src.Input = nil
  L.export(comp, "comicintro", {
    {"NAME", "ComicIntro"},
    {"MAIN", "Src", "Input"},
    {"OUT", "FinishGlow", "Output"},
    {"CTL", "TitleText", "StyledText", "Text"},
    {"CTL", "TitleText", "Font", "Font", "2"}, {"CTL", "TitleText", "Style", "Style", "2"},
    {"CTL", "ComicCtrl", "TextSize", "Text Size"},
    {"CTL", "TitleText", "Red1", "Text Color", "3"}, {"CTL", "TitleText", "Green1", "", "3"}, {"CTL", "TitleText", "Blue1", "", "3"},
    {"CTL", "BoxText", "ExtendHorizontal1", "Box Padding X"},
    {"CTL", "BoxText", "ExtendVertical1", "Box Padding Y"},
    {"CTL", "BoxText", "Red1", "Box Color", "4"}, {"CTL", "BoxText", "Green1", "", "4"}, {"CTL", "BoxText", "Blue1", "", "4"},
    {"CTL", "Backdrop", "TopLeftRed", "Background Color", "5"}, {"CTL", "Backdrop", "TopLeftGreen", "", "5"}, {"CTL", "Backdrop", "TopLeftBlue", "", "5"},
    {"CTL", "ComicCtrl", "PageCount", "Page Count"},
    {"CTL", "ComicCtrl", "PageStart", "Pages Start Size"},
    {"CTL", "ComicCtrl", "PageEnd", "Pages End Size"},
    {"CTL", "PageInk", "NumberIn4", "Halftone"},
    {"CTL", "ComicCtrl", "MaxZoom", "Start Zoom"},
    {"CTL", "ComicCtrl", "PivotX", "Zoom Pivot X"},
    {"CTL", "ComicCtrl", "PivotY", "Zoom Pivot Y"},
  })
  src.Input = feed.Output
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  L.render(comp, glow.Output, os.getenv("FX_PREFIX") or "ci", tonumber(os.getenv("FX_STEPS") or "12"))
end
