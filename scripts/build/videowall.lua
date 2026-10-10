-- Video Wall transition: pull back from clip A to a wall of screens, travel across, push into clip B.
-- The screens have rounded corners, a frame and a shadow on the wall; the other screens play other parts of the two clips.
-- FX_EXPORT=1 dumps the macro source, FX_DRY=1 only measures the Custom expressions.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Video Wall")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "WallCtrl", {
  {"VwPull",   L.num("Pull Back", 1, 0.4, 2)},
  {"VwDir",    L.combo("Camera Moves", {"Right", "Left", "Up", "Down", "Diagonally Up", "Diagonally Down"}, 0)},
  {"VwSnap",   L.num("Camera Snap", 2, 1, 5)},
  {"VwTilt",   L.num("Camera Tilt (degrees)", 3, -20, 20)},
  {"VwBlur",   L.num("Motion Blur", 0.4, 0, 2)},
  {"VwGap",    L.num("Gap", 0.04, 0, 0.1)},
  {"VwRound",  L.num("Corner Roundness", 0.04, 0, 0.2)},
  {"VwFrame",  L.num("Screen Frame Width", 0.008, 0, 0.04)},
  {"VwDepth",  L.num("Depth", 1, 0, 2)},
  {"VwShow",   L.combo("Other Screens Show", {"Other Parts Of The Clips", "Moments Just Before And After"}, 0)},
  {"VwOffset", L.num("Before And After: Seconds Apart", 0.5, 0, 5)},
  {"VwDim",    L.num("Other Screens Brightness", 0.75, 0, 1)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"P",     L.num("P", 0, 0, 1, "Driver")},
  {"S",     L.num("S", 0, 0, 1, "Driver")},
  {"V",     L.num("V", 0, 0, 1, "Driver")},
  {"ViewS", L.num("ViewS", 0.33, 0, 2, "Driver")},
  {"Off",   L.num("Off", 0, 0, 500, "Driver")},
  {"Edge",  L.num("Edge", 0, 0, 1, "Driver")},
  {"From",  L.point("From", "Driver")},
  {"To",    L.point("To", "Driver")},
  {"Cam",   L.point("Cam", "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 2)
-- S: how far along the camera is, V: its speed (1 at the fastest moment, 0 at both ends)
expr(ctrl, "S", "iif(P < 0.5, 0.5*(2*P)^VwSnap, 1 - 0.5*(2 - 2*P)^VwSnap)")
expr(ctrl, "V", "iif(P <= 0 or P >= 1, 0, (1 - abs(2*P - 1))^(VwSnap - 1))")
-- the view is exactly one screen at both ends. In between it widens at an even rate (even in zoom factor, not in size).
expr(ctrl, "ViewS", "(1 - 2*VwGap)/3 * (VwPull*3/(1 - 2*VwGap)) ^ (sin(3.14159265*P)^2)")
-- the wall is 3 x 3 screens that repeat for ever. From, To: column and row (0..2, row 0 at the bottom) of clip A and clip B.
expr(ctrl, "From", "Point(({0, 2, 1, 1, 0, 0})[VwDir + 1], ({1, 1, 0, 2, 0, 2})[VwDir + 1])")
expr(ctrl, "To",   "Point(({2, 0, 1, 1, 2, 2})[VwDir + 1], ({1, 1, 2, 0, 2, 0})[VwDir + 1])")
expr(ctrl, "Cam", "Point((From.X + (To.X - From.X)*S + 0.5)/3, (From.Y + (To.Y - From.Y)*S + 0.5)/3)")
expr(ctrl, "Off", "VwOffset * iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)")
-- the round corners and the tilt come in over the first moments, so the first and last frame are the plain clips
expr(ctrl, "Edge", L.SMOOTH .. "(min(min(P, 1 - P)/0.12, 1))")

local colWall = add("Background", "ColWall", -5, -5)
L.color(colWall, 0.20, 0.21, 0.25)
local colFrame = add("Background", "ColFrame", -4, -5)
L.color(colFrame, 0.02, 0.02, 0.025)
for _, c in ipairs({colWall, colFrame}) do
  c:SetInput("UseFrameFormatSettings", 0); c:SetInput("Width", 16); c:SetInput("Height", 16)
end

-- the other screens: small copies of the two clips at other moments, laid out as a 3 x 3 sheet
local TW, TH = 960, 540
local small = {}
for i = 1, 2 do
  small[i] = add("BetterResize", "Small" .. string.char(64 + i), -4, (i - 1)*2)
  small[i].Input = srcs[i].Output
  small[i]:SetInput("Width", TW); small[i]:SetInput("Height", TH); small[i]:SetInput("KeepAspect", 0)
end
local sheet = add("Background", "WallBase", -4, 6)
L.color(sheet, 0, 0, 0)
sheet:SetInput("UseFrameFormatSettings", 0)
sheet:SetInput("Width", TW*3); sheet:SetInput("Height", TH*3)
local last, count = sheet, {0, 0}
for id = 0, 8 do
  local which = id % 2 + 1 -- clip A on the even screens, clip B on the odd ones
  count[which] = count[which] + 1
  local j = count[which]
  local ts = add("TimeStretcher", "Screen" .. id, -3 + id, which == 1 and 0 or 2)
  ts.Input = small[which].Output
  ts:SetInput("InterpolateBetweenFrames", 0)
  -- either a different part of the whole clip on every screen (wrapping at its end), or a little earlier (A) / later (B)
  expr(ts, "SourceTime", string.format(
    "iif(WallCtrl.VwShow == 0, comp.GlobalStart + floor((time - comp.GlobalStart) + %d*(comp.GlobalEnd - comp.GlobalStart + 1)/%d) %% (comp.GlobalEnd - comp.GlobalStart + 1), time %s floor(%d*WallCtrl.Off))",
    j, which == 1 and 6 or 5, which == 1 and "-" or "+", j))
  local m = add("Merge", "Place" .. id, -3 + id, 6)
  m.Background = last.Output; m.Foreground = ts.Output
  m:SetInput("Center", {(id % 3 + 0.5)/3, (math.floor(id/3) + 0.5)/3})
  last = m
end

-- pass 1, the camera: for every pixel, where on the wall it looks.
-- R, G = position inside the screen (0..1), B = number of the screen, A = distance to the edge of the screen
-- in screen widths (negative inside), with round corners.
local float = add("Background", "WallFloat", 2, 3)
L.color(float, 0, 0, 0)
float:SetInput("Depth", 4)
float:SetInput("UseFrameFormatSettings", 1)
local map = add("Custom", "WallMap", 3, 3)
map.Image1 = float.Output
expr(map, "NumberIn1", "WallCtrl.ViewS")
expr(map, "NumberIn2", "WallCtrl.VwGap")
expr(map, "NumberIn3", "WallCtrl.VwRound * WallCtrl.Edge")
expr(map, "NumberIn4", "WallCtrl.VwTilt * WallCtrl.V * WallCtrl.Edge")
expr(map, "PointIn1", "WallCtrl.Cam")
L.cx(map, "Intermediate1", "10 + p1x + ((x - 0.5)*cos(n4) - (y - 0.5)*(h/w)*sin(n4))*n1")
L.cx(map, "Intermediate2", "10 + p1y + ((x - 0.5)*(w/h)*sin(n4) + (y - 0.5)*cos(n4))*n1")
L.cx(map, "Intermediate3", "frac(i1)*3")
L.cx(map, "Intermediate4", "frac(i2)*3")
L.cx(map, "Intermediate5", "abs(frac(i3) - 0.5) - (0.5 - n2) + n3")
L.cx(map, "Intermediate6", "(abs(frac(i4) - 0.5) - (0.5 - n2))*h/w + n3")
L.cx(map, "RedExpression", "(frac(i3) - n2)/(1 - 2*n2)")
L.cx(map, "GreenExpression", "(frac(i4) - n2)/(1 - 2*n2)")
L.cx(map, "BlueExpression", "floor(i3) + floor(i4)*3")
L.cx(map, "AlphaExpression", "sqrt(max(i5, 0)^2 + max(i6, 0)^2) + min(max(i5, i6), 0) - n3")

-- pass 2: the two screens that show the clips themselves, at full sharpness
local main = add("Custom", "WallMain", 4, 2)
main.Image1 = map.Output; main.Image2 = srcs[1].Output; main.Image3 = srcs[2].Output
expr(main, "NumberIn1", "WallCtrl.From.X + WallCtrl.From.Y*3")
expr(main, "NumberIn2", "WallCtrl.To.X + WallCtrl.To.Y*3")
expr(main, "NumberIn3", "WallCtrl.P")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local k = c:sub(1, 1):lower()
  L.cx(main, c .. "Expression", string.format(
    "if(n3 <= 0, %s2, if(n3 >= 1, %s3, if(abs(b1 - n1) < 0.5, get%s2d(r1, g1), if(abs(b1 - n2) < 0.5, get%s3d(r1, g1), 0))))", k, k, k, k))
end
L.cx(main, "AlphaExpression", "if(n3*(1 - n3) <= 0, 1, if(min(abs(b1 - n1), abs(b1 - n2)) < 0.5, 1, 0))")

-- pass 3: the other screens, the frames around them, the wall and the shadows on it
local cam = add("Custom", "WallCam", 5, 3)
cam.Image1 = map.Output; cam.Image2 = main.Output; cam.Image3 = last.Output
expr(cam, "NumberIn1", "WallCtrl.P")
expr(cam, "NumberIn2", "WallCtrl.VwDim")
expr(cam, "NumberIn3", "WallCtrl.VwFrame")
expr(cam, "NumberIn4", "min(0.85*WallCtrl.VwDepth, 1)")
expr(cam, "NumberIn5", "0.004 + 0.022*WallCtrl.VwDepth")
expr(cam, "NumberIn6", "WallCtrl.ViewS")
-- how far the shadow is thrown (to the lower right), as a part of the picture
expr(cam, "PointIn1", "Point(0.006*WallCtrl.VwDepth/WallCtrl.ViewS, 0.012*WallCtrl.VwDepth/WallCtrl.ViewS)")
expr(cam, "PointIn2", "Point(ColWall.TopLeftRed, ColWall.TopLeftGreen)")
expr(cam, "PointIn3", "Point(ColWall.TopLeftBlue, ColFrame.TopLeftRed)")
expr(cam, "PointIn4", "Point(ColFrame.TopLeftGreen, ColFrame.TopLeftBlue)")
L.cx(cam, "Intermediate1", "3*n6/w") -- one pixel, in screen widths
L.cx(cam, "Intermediate2", "n4*min(max(0.5 - geta1d(x - p1x, y + p1y)/(2*n5), 0), 1)") -- shadow
L.cx(cam, "Intermediate3", "min(max(0.5 - a1/i1, 0), 1)")        -- 1 inside the screen
L.cx(cam, "Intermediate4", "min(max(0.5 - (a1 - n3)/i1, 0), 1)") -- 1 inside the screen and its frame
L.cx(cam, "Intermediate5", "(b1 - 3*floor(b1/3) + min(max(r1, 0.003), 0.997))/3")
L.cx(cam, "Intermediate6", "(floor(b1/3) + min(max(g1, 0.003), 0.997))/3")
local function chan(k, wall, frame)
  return string.format("if(n1*(1 - n1) <= 0, %s2, %s*(1 - i2)*(1 - i4) + %s*(i4 - i3) + i3*if(a2 > 0.5, %s2, get%s3b(i5, i6)*n2))", k, wall, frame, k, k)
end
L.cx(cam, "RedExpression", chan("r", "p2x", "p3y"))
L.cx(cam, "GreenExpression", chan("g", "p2y", "p4x"))
L.cx(cam, "BlueExpression", chan("b", "p3x", "p4y"))
L.cx(cam, "AlphaExpression", "1")

local blur = add("DirectionalBlur", "WallFinal", 6, 3)
blur.Input = cam.Output
blur:SetInput("Type", "Linear")
expr(blur, "Angle", "math.deg(math.atan2((WallCtrl.To.Y - WallCtrl.From.Y)*(comp:GetPrefs('Comp.FrameFormat.Height') or 9), (WallCtrl.To.X - WallCtrl.From.X)*(comp:GetPrefs('Comp.FrameFormat.Width') or 16)))")
expr(blur, "Length", "0.06 * WallCtrl.VwBlur * WallCtrl.V^2")

mediaOut.Input = blur.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColWall", "TopLeftRed", "Wall Colour", "3"}
spec[#spec + 1] = {"CTL", "ColWall", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColWall", "TopLeftBlue", "", "3"}
spec[#spec + 1] = {"CTL", "ColFrame", "TopLeftRed", "Screen Frame Colour", "4"}
spec[#spec + 1] = {"CTL", "ColFrame", "TopLeftGreen", "", "4"}
spec[#spec + 1] = {"CTL", "ColFrame", "TopLeftBlue", "", "4"}
L.ship(comp, {slug = "videowall", name = "VideoWall", out = blur, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "vw"})
