-- Photo Stack intro: moments from the clip slide onto a table one by one, the last photo is the clip itself
-- and grows until it fills the frame. That last photo can wait on the first frame, so that the clip which
-- follows on the timeline starts from its beginning, or play along. FX_SRC=media uses the clip. FX_EXPORT=1 dumps the macro source.
-- FX_SET="PsCount=9 PsSlide=0.3" overrides controls for a test render.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
local useMedia = os.getenv("FX_SRC") == "media"
local MAX = 12 -- most photos the node graph can show, the live one included

comp:Lock()
comp:StartUndo("Build Photo Stack")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "StackCtrl", -5, -3)
ctrl.UserControls = {
  PsCount    = L.num("Photo Count", 6, 1, MAX, nil, true),
  PsSlide    = L.num("Slide Time", 0.2, 0.03, 0.6),
  PsDone     = L.num("Stack Complete At", 0.67, 0.2, 0.9),
  PsSeed     = L.num("Layout Seed", 1, 0, 50, nil, true),
  PsPlay     = L.check("Photos Play As Video", 1),
  PsStart    = L.text("Last Photo Arrives After (2, 0:02.5, 48f or 40%)", "2"),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  Arrive = L.num("Arrive", 0, -1, 1, "Driver"),
  PsLive     = L.combo("Last Photo", {"Plays Along", "Plays, Then Rewinds To The First Frame",
                                      "Waits On The First Frame", "Waits On The Last Frame"}, 0),
  Land = L.num("Land", 0, 0, 1, "Driver"),
  Done = L.num("Done", 0, 0, 1, "Driver"),
  PhotoSize  = L.num("Photo Size", 0.36, 0.15, 0.7),
  Spread     = L.num("Spread", 1, 0, 1.6),
  Tilt       = L.num("Tilt", 1, 0, 3),
  Border     = L.num("Border", 0.022, 0, 0.06),
  Corner     = L.num("Corner Roundness", 0.012, 0, 0.1),
  Blur       = L.check("Motion Blur", 1),
  ShadowAmt  = L.num("Shadow", 0.6, 0, 1),
  ShadowSoft = L.num("Shadow Softness", 1, 0, 3),
  ShadowDist = L.num("Shadow Distance", 1, 0, 3),
  TableMode  = L.combo("Backdrop", {"This Clip, Playing", "This Clip, Frozen", "This Clip, Slowed Down", "Colours"}, 0),
  TableAt    = L.num("Backdrop: Frozen At (0 = start of the clip, 1 = end)", 0, 0, 1),
  TableSpeed = L.num("Backdrop: Slowed Down To", 0.3, 0.02, 1),
  TableGain  = L.num("Backdrop Brightness", 0.3, 0, 1),
  TableBlur  = L.num("Backdrop Blur", 30, 0, 80),
  StillsFrom = L.num("Stills From", 0.05, 0, 1),
  StillsTo   = L.num("Stills To", 0.95, 0, 1),
  P = L.num("P", 0, 0, 1, "Driver"),
  Z = L.num("Z", 0, 0, 1, "Driver"),
  Gap = L.num("Gap", 0.085, 0, 1, "Driver"),
  Aspect = L.num("Aspect", 1.7778, 0.2, 5, "Driver"),
  Inner = L.num("Inner", 0.9, 0, 1, "Driver"),
  Fit = L.num("Fit", 0.36, 0, 1, "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
expr(ctrl, "P", L.P)
-- Z: the live photo growing to full frame at the end, eased at both ends
-- Land: when the last photo sets off, as a part of the clip. Given in seconds it is the one moment the user
-- can count on: cut the piece that many seconds before the first frame they want to see in that photo.
-- With 0 seconds it follows from Stack Complete At instead. Done: when the last photo has come to rest.
-- Arrive: the time the user wrote, as a part of the clip, or -1 when the box is empty, zero or unreadable.
-- Same notation as the time lists (docs/time-list.md): seconds, m:ss, a frame count with f, or a percentage.
expr(ctrl, "Arrive", [[(function(txt, fps, len)
  local stamp = txt:match("^%s*(%S+)")
  if not stamp then return -1 end
  local f
  local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^([%d%.]+)[fF]$")
  if pct then f = tonumber(pct) / 100 * len
  elseif fr then f = tonumber(fr)
  elseif stamp:match("^[%d:%.]+$") then
    local sec = 0
    for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
    if sec then f = math.floor(sec * fps + 0.5) end
  end
  if not f or f <= 0 then return -1 end
  return math.min(f / len, 0.6)
end)(PsStart.Value, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), max(comp.RenderEnd - comp.RenderStart, 1))]])
expr(ctrl, "Land", "iif(Arrive > 0, Arrive, max(PsDone - 0.01 - PsSlide, 0.02))")
expr(ctrl, "Done", "iif(Arrive > 0, min(Land + PsSlide + 0.01, 0.9), PsDone)")
expr(ctrl, "Z", "(function(t) return t*t*t*(t*(6*t - 15) + 10) end)(min(max((P - Done)/max(0.95 - Done, 0.01), 0), 1))")
-- Gap: time between two photos setting off, so that the last one has landed when the stack is complete.
-- A long Slide Time with many photos leaves no room and everything sets off at once.
expr(ctrl, "Gap", "max(Land - 0.02, 0) / max(PsCount - 1, 1)")
-- Fit: the photo size actually used; beyond six photos they shrink a little so the pile stays readable
expr(ctrl, "Fit", "PhotoSize * (6/max(PsCount, 6))^0.4")
expr(ctrl, "Aspect", "Width/Height")
-- Inner: how much of the card the picture takes up; the paper border is the same width on all four sides
expr(ctrl, "Inner", "1 - 2*Border*Aspect")

local src = add("BrightnessContrast", "Src", -5, 0)
local source = useMedia and mediaIn.Output or L.testsource(comp).Output
src.Input = source

-- the photos are shown small, so they are cut from a half size copy to keep playback bearable
local SMALL = 960
local small = add("BetterResize", "SmallSrc", -5, 1)
small.Input = src.Output
small:SetInput("Width", SMALL); small:SetInput("Height", SMALL * 9 / 16); small:SetInput("KeepAspect", 0)

-- table: the clip itself, blurred and darkened. It can run along with the clip, hold one frame, or run slowly
-- (the last photo covers it when it grows to full frame, so it does not matter that it is out of step by then).
-- Or it is no picture at all, just two colours running into each other from top to bottom.
local tableTime = add("TimeStretcher", "TableTime", -5, 5)
tableTime.Input = src.Output
tableTime:SetInput("InterpolateBetweenFrames", 1)
expr(tableTime, "SourceTime", [[(function(m, rs, re, at, speed)
  if m == 1 then return rs + floor(at*(re - rs) + 0.5)
  elseif m == 2 then return rs + (time - rs)*speed end
  return time
end)(StackCtrl.TableMode, comp.RenderStart, comp.RenderEnd, StackCtrl.TableAt, StackCtrl.TableSpeed)]])
local blur = add("Blur", "TableBlur", -4, 5)
blur.Input = tableTime.Output
expr(blur, "XBlurSize", "StackCtrl.TableBlur")
local dimmed = add("BrightnessContrast", "TableDim", -3, 5)
dimmed.Input = blur.Output
expr(dimmed, "Gain", "StackCtrl.TableGain")
local plain = add("Background", "TableColours", -3, 6)
plain:SetInput("UseFrameFormatSettings", 1)
plain:SetInput("Type", "Vertical")
plain.TopLeftRed = 0.16; plain.TopLeftGreen = 0.17; plain.TopLeftBlue = 0.22; plain.TopLeftAlpha = 1
plain.BottomLeftRed = 0.05; plain.BottomLeftGreen = 0.05; plain.BottomLeftBlue = 0.07; plain.BottomLeftAlpha = 1
-- a Dissolve at 0 or 1 only asks for the side it shows, so the unused backdrop costs nothing
local table_ = add("Dissolve", "Table", -2, 5)
table_.Background = dimmed.Output; table_.Foreground = plain.Output
expr(table_, "Mix", "iif(StackCtrl.TableMode == 3, 1, 0)")

local paperMask = add("RectangleMask", "PaperShape", -4, 2)
expr(paperMask, "Width", "StackCtrl.Inner + 2*StackCtrl.Border")
paperMask:SetInput("Height", 1)
expr(paperMask, "CornerRadius", "StackCtrl.Corner")
local paper = add("Background", "Paper", -4, 3)
L.color(paper, 0.97, 0.96, 0.93)
paper:SetInput("UseFrameFormatSettings", 1)
paper.EffectMask = paperMask.Mask

-- What the last photo shows. It is not on screen before it sets off (Land), so playing along with the clip
-- means the viewer first sees the clip at that moment and it runs on unbroken into whatever follows.
--   0 plays along with the clip
--   1 starts on the first frame when it sets off, plays, then winds back to the first frame as it grows
--   2 stays on the first frame   3 stays on the last frame
-- 1 and 2 are for a piece placed in front of a clip that has no spare footage before its start.
local liveSrc = add("TimeStretcher", "LiveFrame", -5, 2)
liveSrc.Input = src.Output
liveSrc:SetInput("InterpolateBetweenFrames", 0)
expr(liveSrc, "SourceTime", [[(function(m, rs, re, p, z, land, done)
  if m == 0 then return time
  elseif m == 1 then return rs + floor(max(min(p, done) - land, 0)*(re - rs)*(1 - z) + 0.5)
  elseif m == 2 then return rs end
  return re
end)(StackCtrl.PsLive, comp.RenderStart, comp.RenderEnd, StackCtrl.P, StackCtrl.Z, StackCtrl.Land, StackCtrl.Done)]])

-- Layers 1..MAX-1 are stills and only the first PsCount-1 of them are used; the last layer is the live clip.
local last = table_
for k = 1, MAX do
  local live = (k == MAX)
  local image = liveSrc
  local slot = tostring(k - 1) -- position in the arrival order (the last photo uses Land instead)
  if not live then
    image = add("TimeStretcher", "Still" .. k, -4 + k, 0)
    image.Input = small.Output
    image:SetInput("InterpolateBetweenFrames", 0)
    -- each photo starts from its own spot in the source; it either stays there or plays on from it, wrapping at the end
    expr(image, "SourceTime", string.format([[(function(first, len, at)
  local start = floor(at * (len - 1))
  return first + iif(StackCtrl.PsPlay == 1, (start + time - comp.RenderStart) %% len, start)
end)(comp.GlobalStart, comp.GlobalEnd - comp.GlobalStart + 1,
  StackCtrl.StillsFrom + (StackCtrl.StillsTo - StackCtrl.StillsFrom) * min(%d/max(StackCtrl.PsCount - 2, 1), 1))]], k - 1))
  end
  local card = add("Merge", "Card" .. k, -4 + k, 1)
  card.Background = paper.Output
  card.Foreground = image.Output
  expr(card, "Size", live and "StackCtrl.Inner" or string.format("StackCtrl.Inner * StackCtrl.Width/%d", SMALL))

  -- Resting place. Stills sit on a sunflower spiral that reaches close to the frame edges, outer ones
  -- first so later photos pile up towards the middle; the seed turns the whole spiral. The live photo rests just off centre.
  local px, py, tilt, fx, fy
  if live then
    px, py, tilt, fx, fy = "0.02", "-0.01", "-3", "-0.1", "-1.1"
  else
    local th = string.format("(%d*2.39996 + StackCtrl.PsSeed*1.7)", k)
    -- radius runs from 1 (first photo, outer edge) down to about 0.45: the middle is left for the live photo
    local r = string.format("sqrt(0.2 + 0.8*max(StackCtrl.PsCount - %d - 0.5, 0)/max(StackCtrl.PsCount - 1, 1))", k)
    px = string.format("0.40*%s*cos(%s)", r, th)
    py = string.format("0.31*%s*sin(%s)", r, th)
    tilt = string.format("13*sin(%d*7.31 + StackCtrl.PsSeed*3.1)", k)
    fx = string.format("1.1*cos(%s)", th)
    fy = string.format("1.1*sin(%s)", th)
  end

  -- fall: 1 while the photo is still outside the frame, easing down to 0 once it has come to rest
  local t0 = live and "StackCtrl.Land" or string.format("(0.02 + %s*StackCtrl.Gap)", slot)
  local fall = string.format("((1 - min(max((StackCtrl.P - %s)/StackCtrl.PsSlide, 0), 1))^4)", t0)
  local drop = add("Transform", "Drop" .. k, -4 + k, 2)
  drop.Input = card.Output
  local size = string.format("StackCtrl.Fit * (1 + 0.25*%s)", fall)
  local angle = string.format("(%s)*StackCtrl.Tilt + %d*%s", tilt, (k % 2 == 0) and 38 or -38, fall)
  local cx = string.format("0.5 + (%s)*StackCtrl.Spread + (%s)*%s", px, fx, fall)
  local cy = string.format("0.5 + (%s)*StackCtrl.Spread + (%s)*%s", py, fy, fall)
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
  local used = live and "1" or string.format("iif(%d <= StackCtrl.PsCount - 1, 1, 0)", k)
  expr(lay, "Blend", string.format("%s * iif(StackCtrl.P >= %s, 1, 0)", used, t0))
  last = lay
end

-- hand over to the untouched clip at the very end so the cut to the next clip is seamless
local finish = add("Merge", "Finish", 4, 5)
finish.Background = last.Output
finish.Foreground = liveSrc.Output
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
    {"CTL", "StackCtrl", "PsStart", "Last Photo Arrives After (2, 0:02.5, 48f or 40%)"},
    {"CTL", "StackCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "StackCtrl", "PsLive", "Last Photo"},
    {"CTL", "StackCtrl", "PsCount", "Photo Count"},
    {"CTL", "StackCtrl", "PsSlide", "Slide Time"},
    {"CTL", "StackCtrl", "PsDone", "Stack Complete At"},
    {"CTL", "StackCtrl", "PsSeed", "Layout Seed"},
    {"CTL", "StackCtrl", "PsPlay", "Photos Play As Video"},
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
    {"CTL", "StackCtrl", "TableMode", "Backdrop"},
    {"CTL", "StackCtrl", "TableAt", "Backdrop: Frozen At (0 = start of the clip, 1 = end)"},
    {"CTL", "StackCtrl", "TableSpeed", "Backdrop: Slowed Down To"},
    {"CTL", "StackCtrl", "TableGain", "Backdrop Brightness"},
    {"CTL", "StackCtrl", "TableBlur", "Backdrop Blur"},
    {"CTL", "TableColours", "TopLeftRed", "Backdrop Colour: Top", "3"},
    {"CTL", "TableColours", "TopLeftGreen", "", "3"},
    {"CTL", "TableColours", "TopLeftBlue", "", "3"},
    {"CTL", "TableColours", "BottomLeftRed", "Backdrop Colour: Bottom", "4"},
    {"CTL", "TableColours", "BottomLeftGreen", "", "4"},
    {"CTL", "TableColours", "BottomLeftBlue", "", "4"},
    {"CTL", "StackCtrl", "StillsFrom", "Stills From"},
    {"CTL", "StackCtrl", "StillsTo", "Stills To"},
  })
  src.Input = source
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  if os.getenv("FX_ARRIVE") then ctrl:SetInput("PsStart", os.getenv("FX_ARRIVE")) end
  local v = {}
  for _, id in ipairs({"Arrive", "Land", "Done"}) do v[#v + 1] = id .. "=" .. tostring((ctrl:GetInput(id, 10))) end
  print(table.concat(v, " "))
  L.render(comp, finish.Output, os.getenv("FX_PREFIX") or "ps", tonumber(os.getenv("FX_STEPS") or "12"))
end
