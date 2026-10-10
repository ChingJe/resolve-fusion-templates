-- Sub Window: shrinks the clip into a small framed window in a corner, the reaction window of a variety show.
-- Put the clip on a track above the main picture and drop this on it. Everything outside the window is clear.
-- FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Sub Window")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "WinCtrl", {
  {"WinShape",  L.combo("Shape", {"Circle", "Rounded", "Rectangle"}, 1)},
  {"WinPos",    L.point("Position", nil, true), {0.82, 0.76}},
  {"WinSize",   L.num("Size", 0.34, 0.05, 1)},
  {"WinAspect", L.num("Width / Height", 1.5, 0.3, 3)},
  {"WinRound",  L.num("Corner Roundness", 0.25, 0, 1)},
  {"WinZoom",   L.num("Zoom Into The Clip", 1, 1, 6)},
  {"WinLook",   L.point("Part Of The Clip Shown", nil, true), {0.5, 0.5}},
  {"WinFlip",   L.check("Mirror", 0)},
  {"WinBorder", L.num("Border", 0.008, 0, 0.05)},
  {"WinShadow", L.num("Shadow", 0.5, 0, 1)},
  {"WinShadowOff", L.num("Shadow Distance", 0.012, 0, 0.08)},
  {"WinShadowSoft", L.num("Shadow Softness", 0.012, 0, 0.08)},
  {"WinEnter",  L.combo("Entrance", {"Pop", "Grow", "From The Nearest Edge", "Fade", "None"}, 0)},
  {"WinIn",     L.num("Entrance Frames", 8, 1, 60)},
  {"WinOut",    L.num("Exit Frames", 6, 0, 60)},
  {"T",     L.num("T", 0, 0, 1, "Driver")},
  {"Gone",  L.num("Gone", 0, 0, 1, "Driver")},
  {"Scale", L.num("Scale", 1, 0, 3, "Driver")},
  {"Fade",  L.num("Fade", 1, 0, 1, "Driver")},
  {"At",    L.point("At", "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)
expr(ctrl, "T", "min(max((time - comp.RenderStart + 1)/max(WinIn, 1), 0), 1)")
expr(ctrl, "Gone", "iif(WinOut <= 0, 0, 1 - min(max((comp.RenderEnd - time + 1)/WinOut, 0), 1))")
expr(ctrl, "Scale", [[(function(e, t, g)
  local s = 1
  if e == 0 then local u = t - 1 s = 1 + 2.70158*u*u*u + 1.70158*u*u
  elseif e == 1 then s = 1 - (1 - t)^3 end
  if e <= 1 then s = s*(1 - g*g) end
  return math.max(s, 0)
end)(WinEnter, T, Gone)]])
expr(ctrl, "Fade", "iif(WinEnter == 3, T*(1 - Gone), iif(WinEnter == 2 or WinEnter == 4, 1, min(T*4, 1)))")
-- From The Nearest Edge: starts outside the frame on the side it is closest to
expr(ctrl, "At", [[(function(e, t, g, px, py, sz)
  if e ~= 2 then return Point(px, py) end
  local u = (1 - t)^3 + g*g*g
  local dx = (px < 0.5) and -(px + sz) or (1 - px + sz)
  local dy = (py < 0.5) and -(py + sz) or (1 - py + sz)
  if math.min(px, 1 - px) < math.min(py, 1 - py) then return Point(px + dx*u, py) end
  return Point(px, py + dy*u)
end)(WinEnter, T, Gone, WinPos.X, WinPos.Y, WinSize)]])

local edge = add("Background", "ColWinBorder", -3, -5)
edge:SetInput("UseFrameFormatSettings", 0); edge:SetInput("Width", 16); edge:SetInput("Height", 16)
L.color(edge, 1, 1, 1, 1)

local win = add("Custom", "WinFinal", 1, 1)
win.Image1 = srcs[1].Output; win.Image2 = edge.Output
expr(win, "NumberIn1", "WinCtrl.WinSize * WinCtrl.Scale / 2")
expr(win, "NumberIn2", "iif(WinCtrl.WinShape == 0, 1, WinCtrl.WinAspect)")
expr(win, "NumberIn3", "iif(WinCtrl.WinShape == 0, 1, iif(WinCtrl.WinShape == 2, 0, WinCtrl.WinRound))")
expr(win, "NumberIn4", "WinCtrl.WinBorder * WinCtrl.Scale")
expr(win, "NumberIn5", "WinCtrl.WinZoom")
expr(win, "NumberIn6", "WinCtrl.Fade")
expr(win, "NumberIn7", "WinCtrl.WinShadow")
expr(win, "NumberIn8", "max(WinCtrl.WinShadowSoft, 0.0005)")
expr(win, "PointIn1", "WinCtrl.At")
expr(win, "PointIn2", "WinCtrl.WinLook")
expr(win, "PointIn3", "Point(WinCtrl.WinShadowOff, iif(WinCtrl.WinFlip == 1, -1, 1))")
-- i1, i2: this pixel seen from the middle of the window, in units of the frame height
win:SetInput("Intermediate1", "(x - p1x)*w/h")
win:SetInput("Intermediate2", "y - p1y")
-- i3 half the width, i4 the corner radius
win:SetInput("Intermediate3", "n1*n2")
win:SetInput("Intermediate4", "n3*min(n1, i3)")
-- distance to the outline of a rounded box (negative inside), for the window and for its shadow
local function box(qx, qy)
  local ax, ay = "(abs(" .. qx .. ") - i3 + i4)", "(abs(" .. qy .. ") - n1 + i4)"
  return string.format("sqrt(max(%s, 0)^2 + max(%s, 0)^2) + min(max(%s, %s), 0) - i4", ax, ay, ax, ay)
end
win:SetInput("Intermediate5", box("i1", "i2"))
win:SetInput("Intermediate6", box("(i1 - p3x)", "(i2 + p3x)"))
-- i7 how much of this pixel the whole window covers, i8 how much the picture inside the border covers
win:SetInput("Intermediate7", "if(n1 <= 0.0005, 0, min(max(-i5*h + 0.5, 0), 1))")
win:SetInput("Intermediate8", "if(n1 <= 0.0005, 0, min(max((-i5 - n4)*h + 0.5, 0), 1))")
-- the window shows a part of the clip with the same proportions as itself
local u = "p2x + p3y*i1/(2*i3)*(n2*h/w)/n5"
local v = "p2y + i2/(2*n1)/n5"
local shade = "if(n1 <= 0.0005, 0, n7*min(max(0.5 - i6/n8*0.5, 0), 1))"
for _, c in ipairs({"r", "g", "b"}) do
  win:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("n6*(get%s1d(%s, %s)*i8 + get%s2b(0.5, 0.5)*(i7 - i8))", c, u, v, c))
end
win:SetInput("AlphaExpression", "n6*(i7 + (1 - i7)*" .. shade .. ")")

mediaOut.Input = win.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColWinBorder", "TopLeftRed", "Border Colour", "3"}
spec[#spec + 1] = {"CTL", "ColWinBorder", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColWinBorder", "TopLeftBlue", "", "3"}
-- the test shows the window over a second stand-in, the way it sits over the main picture
L.ship(comp, {slug = "subwindow", name = "SubWindow", out = win, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "sw",
  show = function()
    comp:Lock()
    local base = L.testsource(comp, "B", 1)
    local over = add("Merge", "PrevUnder", 4, 4)
    over.Background = base.Output; over.Foreground = win.Output
    comp:Unlock()
    return over.Output
  end})
