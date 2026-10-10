-- Sub Window: shrinks the clip into a small framed window, the reaction window of a variety show. The frame
-- can be a plain border, a polaroid, an app window, a phone, a taped photo, a film frame or a double line.
-- The window can drift while it stays, and can grow to fill the frame (or start out filling it).
-- Put the clip on a track above the main picture and drop this on it. Everything outside the window is clear.
-- FX_EXPORT=1 dumps the macro source. FX_TEXT sets the caption for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Sub Window")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- styles, in the order of the Frame Style list
local PLAIN, POLAROID, WINDOW, PHONE, TAPE, FILM, DOUBLE = 0, 1, 2, 3, 4, 5, 6
local ctrl, spec = L.panel(comp, "WinCtrl", {
  {"WinStyle",  L.combo("Frame Style", {"Plain", "Polaroid", "App Window", "Phone", "Taped Photo", "Film", "Double Line"}, 0)},
  {"WinShape",  L.combo("Shape", {"Circle", "Rounded", "Rectangle"}, 1)},
  {"WinPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"WinSize",   L.num("Size", 0.5, 0.05, 1)},
  {"WinAspect", L.num("Width / Height", 1.5, 0.3, 3)},
  {"WinRound",  L.num("Corner Roundness", 0.25, 0, 1)},
  {"WinTilt",   L.num("Tilt (degrees)", 0, -45, 45)},
  {"WinBorder", L.num("Border", 0.008, 0, 0.05)},
  {"WinCaption", L.text("Caption", "")},
  {"WinZoom",   L.num("Zoom Into The Clip", 1, 1, 6)},
  {"WinLook",   L.point("Part Of The Clip Shown", nil, true), {0.5, 0.5}},
  {"WinFlip",   L.check("Mirror", 0)},
  {"WinShadow", L.num("Shadow", 0.5, 0, 1)},
  {"WinShadowOff", L.num("Shadow Distance", 0.012, 0, 0.08)},
  {"WinShadowSoft", L.num("Shadow Softness", 0.012, 0, 0.08)},
  {"WinEnter",  L.combo("Entrance", {"Pop", "Grow", "From The Nearest Edge", "Fade", "None"}, 0)},
  {"WinIn",     L.num("Entrance Frames", 8, 1, 60)},
  {"WinOut",    L.num("Exit Frames", 6, 0, 60)},
  {"WinIdle",   L.combo("While It Stays", {"Still", "Float", "Wobble"}, 0)},
  {"WinIdleAmount", L.num("Movement Amount", 1, 0, 4)},
  {"WinIdleSpeed",  L.num("Movements Per Second", 0.5, 0.05, 4)},
  {"WinFull",   L.combo("Fills The Whole Frame", {"Never", "At The Start, Then Shrinks Into The Window", "At The End, Growing Out Of The Window"}, 0)},
  {"WinFullFrames", L.num("Shrink / Grow Frames", 18, 2, 90)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"T",     L.num("T", 0, 0, 1, "Driver")},
  {"Gone",  L.num("Gone", 0, 0, 1, "Driver")},
  {"E",     L.num("E", 0, 0, 1, "Driver")},
  {"Wave",  L.num("Wave", 0, -4, 4, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Fade",  L.num("Fade", 1, 0, 1, "Driver")},
  {"Ang",   L.num("Ang", 0, -90, 90, "Driver")},
  {"Hh",    L.num("Hh", 0, 0, 1, "Driver")},
  {"Bd",    L.num("Bd", 0, 0, 1, "Driver")},
  {"MS",    L.num("MS", 0, 0, 1, "Driver")},
  {"MT",    L.num("MT", 0, 0, 1, "Driver")},
  {"MB",    L.num("MB", 0, 0, 1, "Driver")},
  {"Zm",    L.num("Zm", 1, 1, 6, "Driver")},
  {"At0",   L.point("At0", "Driver")},
  {"At",    L.point("At", "Driver")},
  {"Box",   L.point("Box", "Driver")},
  {"Rad",   L.point("Rad", "Driver")},
  {"Lk",    L.point("Lk", "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
-- E: 0 = the window, 1 = the clip fills the whole frame. Exactly 1 on the first (or last) frame, so that the
-- clip can be cut against itself there.
expr(ctrl, "E", L.SMOOTH .. "(iif(WinFull == 1, 1 - min((time - comp.RenderStart)/WinFullFrames, 1), iif(WinFull == 2, 1 - min((comp.RenderEnd - time)/WinFullFrames, 1), 0)))")
-- no entrance on the side where it fills the frame
expr(ctrl, "T", "iif(WinFull == 1, 1, min(max((time - comp.RenderStart + 1)/max(WinIn, 1), 0), 1))")
expr(ctrl, "Gone", "iif(WinOut <= 0 or WinFull == 2, 0, 1 - min(max((comp.RenderEnd - time + 1)/WinOut, 0), 1))")
expr(ctrl, "Wave", "iif(WinIdle == 0, 0, T * (1 - E) * WinIdleAmount * sin(6.2831853 * WinIdleSpeed * (time - comp.RenderStart) / iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)))")
expr(ctrl, "Scale", [[(function(e, t, g)
  local s = 1
  if e == 0 then local u = t - 1 s = 1 + 2.70158*u*u*u + 1.70158*u*u
  elseif e == 1 then s = 1 - (1 - t)^3 end
  if e <= 1 then s = s*(1 - g*g) end
  return math.max(s, 0)
end)(WinEnter, T, Gone)]])
expr(ctrl, "Fade", "iif(WinEnter == 3, T*(1 - Gone), iif(WinEnter == 2 or WinEnter == 4, 1, min(T*4, 1)))")
-- At0: where the window is. From The Nearest Edge starts outside the frame on the side it is closest to.
expr(ctrl, "At0", [[(function(e, t, g, px, py, sz)
  if e ~= 2 then return Point(px, py) end
  local u = (1 - t)^3 + g*g*g
  local dx = (px < 0.5) and -(px + sz) or (1 - px + sz)
  local dy = (py < 0.5) and -(py + sz) or (1 - py + sz)
  if math.min(px, 1 - px) < math.min(py, 1 - py) then return Point(px + dx*u, py) end
  return Point(px, py + dy*u)
end)(WinEnter, T, Gone, WinPos.X, WinPos.Y, WinSize)]])
expr(ctrl, "At", "Point(At0.X + (0.5 - At0.X)*E, At0.Y + iif(WinIdle == 1, 0.02*Wave, 0) + (0.5 - At0.Y)*E)")
expr(ctrl, "Ang", "(WinTilt + iif(WinIdle == 2, 4*Wave, 0)) * (1 - E)")
-- Hh: half the height of the whole thing, frame included. Box: half its width and height.
expr(ctrl, "Hh", "WinSize*Scale/2 + (0.5 - WinSize*Scale/2)*E")
expr(ctrl, "Box", [[(function(a, full, e, hh) return Point(hh*(a + (full - a)*e), hh) end)(
  iif(WinStyle == 3, 0.48, iif(WinShape == 0 and (WinStyle == 0 or WinStyle == 4 or WinStyle == 6), 1, WinAspect)),
  SrcA.Output.Width / SrcA.Output.Height, E, Hh)]])
expr(ctrl, "Bd", "WinBorder * Scale")
-- MS, MT, MB: how wide the frame is at the sides, the top and the bottom. A part that belongs to the style
-- (a share of the size) plus the Border control. All of it shrinks away as the clip fills the frame.
local function margin(shares)
  return "(1 - E) * (({" .. table.concat(shares, ", ") .. "})[WinStyle + 1]*2*Hh + Bd*({1, 1, 1, 1, 1, 0, 3})[WinStyle + 1])"
end
expr(ctrl, "MS", margin({0, 0.045, 0, 0.035, 0, 0, 0}))
expr(ctrl, "MT", margin({0, 0.045, 0.1, 0.035, 0, 0.12, 0}))
expr(ctrl, "MB", margin({0, 0.2, 0, 0.035, 0, 0.12, 0}))
-- Rad: corner radius of the frame and of the picture inside it
expr(ctrl, "Rad", [[(function(st, m, k, ms, round)
  local R = m * k * (({round, 0.04, 0.08, 0.36, round, 0, round})[st + 1])
  local r = 0
  if st == 0 or st == 3 or st == 4 or st == 6 then r = math.max(R - ms, 0) end
  if st == 5 then r = m * k * 0.06 end
  return Point(R, r)
end)(WinStyle, min(Box.X, Box.Y), 1 - E, MS, iif(WinShape == 0, 1, iif(WinShape == 2, 0, WinRound)))]])
expr(ctrl, "Zm", "WinZoom + (1 - WinZoom)*E")
expr(ctrl, "Lk", "Point(WinLook.X + (0.5 - WinLook.X)*E, WinLook.Y + (0.5 - WinLook.Y)*E)")

-- distance to the outline of a rounded box (negative inside): half size a x b, corner radius r
local function box(qx, qy, a, b, r)
  local ax, ay = "(abs(" .. qx .. ") - " .. a .. " + " .. r .. ")", "(abs(" .. qy .. ") - " .. b .. " + " .. r .. ")"
  return string.format("sqrt(max(%s, 0)^2 + max(%s, 0)^2) + min(max(%s, %s), 0) - %s", ax, ay, ax, ay, r)
end
local RGB = {r = "Red", g = "Green", b = "Blue"}
local COVER = "min(max(0.5 - h*(%s), 0), 1)"

-- WinPic: the clip, cut to the picture area of the frame
local pic = add("Custom", "WinPic", 0, 0)
pic.Image1 = srcs[1].Output
expr(pic, "PointIn1", "WinCtrl.At")
expr(pic, "PointIn2", "Point(WinCtrl.Box.X - WinCtrl.MS, WinCtrl.Box.Y - (WinCtrl.MT + WinCtrl.MB)/2)")
expr(pic, "PointIn3", "Point(0, (WinCtrl.MB - WinCtrl.MT)/2)")
expr(pic, "PointIn4", "WinCtrl.Lk")
expr(pic, "NumberIn1", "WinCtrl.Ang")
expr(pic, "NumberIn2", "WinCtrl.Rad.Y")
expr(pic, "NumberIn3", "WinCtrl.Zm")
expr(pic, "NumberIn4", "iif(WinCtrl.WinFlip == 1, -1, 1)")
expr(pic, "NumberIn5", "WinCtrl.E")
-- i1, i2: this pixel seen from the middle of the picture area, in units of the frame height, turned by the tilt
L.cx(pic, "Intermediate1", "(x - p1x)*w/h*cos(n1) + (y - p1y)*sin(n1) - p3x")
L.cx(pic, "Intermediate2", "(y - p1y)*cos(n1) - (x - p1x)*w/h*sin(n1) - p3y")
L.cx(pic, "Intermediate3", "if(p2y <= 0.0005, 0, " .. COVER:format(box("i1", "i2", "p2x", "p2y", "n2")) .. ")")
-- the picture area shows a part of the clip with the same proportions as itself
for c, name in pairs(RGB) do
  L.cx(pic, name .. "Expression", string.format("if(n5 >= 1, %s1, i3*get%s1d(p4x + n4*i1/(2*p2y)*(h/w)/n3, p4y + i2/(2*p2y)/n3))", c, c))
end
L.cx(pic, "AlphaExpression", "if(n5 >= 1, 1, i3)")

local edge = add("Background", "ColWinBorder", -3, -5)
edge:SetInput("UseFrameFormatSettings", 0); edge:SetInput("Width", 16); edge:SetInput("Height", 16)
L.color(edge, 1, 1, 1, 1)

-- WinFinal: the frame around the picture, what the style draws on it or cuts out of it, and the shadow
local win = add("Custom", "WinFinal", 1, 1)
win.Image1 = pic.Output; win.Image2 = edge.Output
expr(win, "PointIn1", "WinCtrl.At")
expr(win, "PointIn2", "WinCtrl.Box")
expr(win, "PointIn3", "Point(max(WinCtrl.MT, 0.0001), WinCtrl.MB)")
expr(win, "PointIn4", "Point(WinCtrl.WinShadowOff, max(WinCtrl.WinShadowSoft, 0.0005))")
expr(win, "NumberIn1", "WinCtrl.Ang")
expr(win, "NumberIn2", "WinCtrl.Rad.X")
expr(win, "NumberIn3", "WinCtrl.WinStyle")
expr(win, "NumberIn4", "WinCtrl.Bd")
expr(win, "NumberIn5", "WinCtrl.WinShadow")
expr(win, "NumberIn6", "WinCtrl.Fade")
expr(win, "NumberIn8", "1 - WinCtrl.E")
L.cx(win, "Intermediate1", "(x - p1x)*w/h*cos(n1) + (y - p1y)*sin(n1)")
L.cx(win, "Intermediate2", "(y - p1y)*cos(n1) - (x - p1x)*w/h*sin(n1)")
L.cx(win, "Intermediate3", box("i1", "i2", "p2x", "p2y", "n2"))
-- i4: what is cut out of the frame. Film: a row of holes in the band above and below. Double Line: the gap between the two lines.
local filmHole = "max(abs(frac(i1/(p3x*1.1) + 100.5) - 0.5)*p3x*1.1 - p3x*0.3, abs(abs(i2) - p2y + p3x*0.5) - p3x*0.26)"
L.cx(win, "Intermediate4", COVER:format("if(n3 == 5, " .. filmHole .. ", if(n3 == 6, if(n4 > 0, max(i3 + n4, -i3 - 2*n4), 1), 1))"))
-- i5: how much of this pixel the frame covers
L.cx(win, "Intermediate5", "if(p2y <= 0.0005, 0, " .. COVER:format("i3") .. "*(1 - i4))")
-- i6: App Window has three dots in its title bar, this is which of them is nearest (0, 1, 2)
L.cx(win, "Intermediate6", "min(max(floor((i1 + p2x - p3x*0.6)/(p3x*0.42) + 0.5), 0), 2)")
-- i7: what the style paints on top. The three dots, the camera pill of a phone, a strip of tape across the top edge.
local dot = "sqrt((i1 + p2x - p3x*(0.6 + i6*0.42))^2 + (i2 - p2y + p3x*0.5)^2) - p3x*0.15"
local pill = "sqrt(max(abs(i1) - p2x*0.26, 0)^2 + (i2 - p2y + p3x + p2x*0.2)^2) - p2x*0.07"
local tape = "max(abs(i1*0.996 - (i2 - p2y)*0.087) - p2y*0.42, abs((i2 - p2y)*0.996 + i1*0.087) - p2y*0.1)"
L.cx(win, "Intermediate7", "n8*if(n3 == 4, 0.72, 1)*" .. COVER:format("if(n3 == 2, " .. dot .. ", if(n3 == 3, " .. pill .. ", if(n3 == 4, " .. tape .. ", 1)))"))
-- i8: the shadow, from the same outline read a little to the side
L.cx(win, "Intermediate8", "if(p2y <= 0.0005, 0, n5*min(max(0.5 - (" .. box("(i1 - p4x)", "(i2 + p4x)", "p2x", "p2y", "n2") .. ")/p4y*0.5, 0), 1))")
-- the frame of a phone and of a film is black whatever the border colour is
local painted = {r = "if(n3 == 2, if(i6 < 1.5, 1, 0.15), if(n3 == 4, 0.93, 0.03))",
                 g = "if(n3 == 2, if(i6 < 0.5, 0.37, if(i6 < 1.5, 0.74, 0.79)), if(n3 == 4, 0.87, 0.03))",
                 b = "if(n3 == 2, if(i6 < 0.5, 0.34, if(i6 < 1.5, 0.18, 0.25)), if(n3 == 4, 0.66, 0.03))"}
for c, name in pairs(RGB) do
  L.cx(win, name .. "Expression", string.format("n6*((%s1 + max(i5 - a1, 0)*if(abs(n3 - 4) == 1, 0.03, get%s2b(0.5, 0.5)))*(1 - i7) + i7*%s)", c, c, painted[c]))
end
L.cx(win, "AlphaExpression", "n6*(i5 + (1 - i5)*i7 + (1 - i5)*(1 - i7)*i8)")

-- Caption: on the wide bottom edge of a polaroid, or in the title bar of an app window. It moves and turns with the frame.
local cap = add("TextPlus", "WinText", 1, 3)
cap:SetInput("UseFrameFormatSettings", 0)
expr(cap, "Width", "SrcA.Output.Width"); expr(cap, "Height", "SrcA.Output.Height")
cap:SetInput("Font", "Microsoft JhengHei"); cap:SetInput("Style", "Bold")
cap:SetInput("Red1", 0.13); cap:SetInput("Green1", 0.13); cap:SetInput("Blue1", 0.15)
expr(cap, "StyledText", "Text(WinCtrl.WinCaption.Value)")
expr(cap, "HorizontalLeftCenterRight", "iif(WinCtrl.WinStyle == 2, -1, 0)")
expr(cap, "AngleZ", "WinCtrl.Ang")
expr(cap, "Size", "iif(WinCtrl.WinStyle == 2, WinCtrl.MT*0.75, WinCtrl.MB*0.42) * Height / Width")
-- lx, ly: where the caption sits, seen from the middle of the frame; then turned and moved like the frame
expr(cap, "Center", [[(function(st, bx, by, mt, mb, ang, ax, ay, asp)
  local lx, ly = 0, -by + mb*0.5
  if st == 2 then lx, ly = -bx + mt*1.9, by - mt*0.5 end
  local c, s = math.cos(math.rad(ang)), math.sin(math.rad(ang))
  return Point(ax + (lx*c - ly*s)/asp, ay + lx*s + ly*c)
end)(WinCtrl.WinStyle, WinCtrl.Box.X, WinCtrl.Box.Y, WinCtrl.MT, WinCtrl.MB, WinCtrl.Ang, WinCtrl.At.X, WinCtrl.At.Y, Width/Height)]])
local out = add("Merge", "WinTitled", 2, 1)
out.Background = win.Output; out.Foreground = cap.Output
expr(out, "Blend", "iif(WinCtrl.WinStyle == 1 or WinCtrl.WinStyle == 2, WinCtrl.Fade * (1 - WinCtrl.E), 0)")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
local function colour(tool, id, label, group)
  for i, ch in ipairs({"Red", "Green", "Blue"}) do
    spec[#spec + 1] = {"CTL", tool, id:format(ch), i == 1 and label or "", group}
  end
end
colour("ColWinBorder", "TopLeft%s", "Border Colour", "3")
spec[#spec + 1] = {"CTL", "WinText", "Font", "Caption Font", "4"}
spec[#spec + 1] = {"CTL", "WinText", "Style", "", "4"}
colour("WinText", "%s1", "Caption Colour", "5")
-- the test shows the window over a second stand-in, the way it sits over the main picture
L.ship(comp, {slug = "subwindow", name = "SubWindow", out = out, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "sw",
  before = function()
    local t = os.getenv("FX_TEXT")
    if t then ctrl:SetInput("WinCaption", t) end
  end,
  show = function()
    comp:Lock()
    local base = L.testsource(comp, "B", 1)
    local over = add("Merge", "PrevUnder", 4, 4)
    over.Background = base.Output; over.Foreground = out.Output
    comp:Unlock()
    return over.Output
  end})
