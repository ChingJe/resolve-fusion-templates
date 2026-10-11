-- Variety Caption: TV variety show style captions. Thick layered outlines, a gradient fill, one *marked* word
-- per line bigger and in another colour, and a loud entrance. Lines come from one text box; which one shows is
-- set by keyframing Line Number, or by a time in front of every line.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2,120=3" keyframes Line Number for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Variety Caption")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local cur = L.cur("VarCtrl", "CapList", "CapTimed", "CapCue")

-- fill top, fill bottom, marked word top, marked word bottom, inner outline, middle outline, outer outline
local PRESETS = {
  {"Yellow / Red",  {1.00,0.96,0.30, 1.00,0.70,0.05, 1.00,1.00,1.00, 1.00,0.82,0.86, 0.85,0.05,0.10, 1.00,1.00,1.00, 0.10,0.02,0.02}},
  {"White / Blue",  {1.00,1.00,1.00, 0.78,0.90,1.00, 1.00,0.96,0.30, 1.00,0.70,0.10, 0.05,0.30,0.85, 1.00,1.00,1.00, 0.02,0.05,0.20}},
  {"White / Pink",  {1.00,1.00,1.00, 1.00,0.84,0.92, 1.00,0.96,0.40, 1.00,0.78,0.20, 0.95,0.20,0.55, 1.00,1.00,1.00, 0.35,0.02,0.20}},
  {"Lime / Green",  {0.96,1.00,0.60, 0.60,0.95,0.20, 1.00,1.00,1.00, 1.00,0.95,0.70, 0.05,0.42,0.15, 1.00,1.00,1.00, 0.02,0.15,0.05}},
  {"White / Black", {1.00,1.00,1.00, 0.76,0.76,0.76, 1.00,0.25,0.20, 0.72,0.00,0.00, 0.00,0.00,0.00, 1.00,1.00,1.00, 0.00,0.00,0.00}},
}
local names, rows = {"Custom"}, {}
for _, p in ipairs(PRESETS) do names[#names + 1] = p[1]; rows[#rows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
local TABLE = "({" .. table.concat(rows, ",") .. "})"
-- The fill at the top and the two inner outlines are the colours of the shared look (LkCol, LkColEdge,
-- LkColOuter); the other four are this template's own.
local HOLD = {"LkCol", "ColFillBottom", "ColMarkTop", "ColMarkBottom", "LkColEdge", "LkColOuter", "ColOuter"}
-- colour number k (1..7), channel c (1..3): from the preset, or from the colour holder when Custom is chosen
local function preset(k, c)
  local ch = ({"Red", "Green", "Blue"})[c]
  return string.format("iif(VarCtrl.CapPreset == 0, %s.TopLeft%s, %s[max(VarCtrl.CapPreset, 1)][%d])", HOLD[k], ch, TABLE, (k - 1)*3 + c)
end
local D = PRESETS[1][2]
local K = L.look("VarCtrl", {size = 0.09, edge = 0.006, outer = 0.004, shadow = 0.6, dist = 0.006,
  col = {D[1], D[2], D[3]}, colEdge = {D[13], D[14], D[15]}, colOuter = {D[16], D[17], D[18]},
  pre = function(key, c) return preset(({col = 1, edge = 5, outer = 6})[key], c) end})
local function col(k, c)
  if k == 1 then return K.c("col", c) elseif k == 5 then return K.c("edge", c) elseif k == 6 then return K.c("outer", c) end
  return preset(k, c)
end

local ctrl = add("Background", "VarCtrl", -6, -3)
ctrl.UserControls = K.controls({
  CapList  = L.text("Lines (mark one word with *stars*)", "今天要挑戰\n*超級*辣的火鍋\n結果*完全*不行", nil, 8),
  CapCue   = L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20),
  CapTimed = L.check("Lines Start With A Time (0:02 Text)", 0),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  CapPreset = L.combo("Colours", names, 1),
  CapMark  = L.num("Marked Word Size", 1.35, 0.5, 3),
  CapGap   = L.num("Marked Word Gap", 0.12, 0, 1),
  CapOuter = L.num("Third Outline", 0.003, 0, 0.03),
  CapEnter = L.combo("Entrance", {"Pop", "Slam", "Shake", "Slide Up", "None"}, 0),
  CapIn    = L.num("Entrance Frames", 8, 1, 40),
  CapOut   = L.num("Fade Out Frames", 2, 0, 40),
  CapPower = L.num("Entrance Strength", 1, 0, 3),
  CapTilt  = L.num("Tilt", 3, -30, 30),
  CapSway  = L.num("Sway", 0, 0, 10),
  CapPos = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Position",
            INPID_PreviewControl = "CrosshairControl", ICS_ControlPage = "Controls"},
  Idx   = L.num("Idx", 0, 0, 100, "Driver"),
  Since = L.num("Since", 0, 0, 100, "Driver"),
  Until = L.num("Until", 0, 0, 100, "Driver"),
  T     = L.num("T", 0, 0, 1, "Driver"),
  Fade  = L.num("Fade", 0, 0, 1, "Driver"),
  Scale = L.num("Scale", 1, 0, 4, "Driver"),
  Rot   = L.num("Rot", 0, -90, 90, "Driver"),
  Cur   = L.text("Cur", "", "Driver", 1),
  Off = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Off", ICS_ControlPage = "Driver"},
  WA = L.num("WA", 0, 0, 2, "Driver"), WB = L.num("WB", 0, 0, 2, "Driver"), WC = L.num("WC", 0, 0, 2, "Driver"),
  Gap = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Gap", ICS_ControlPage = "Driver"},
})
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("CapPos", {0.5, 0.2})
L.color(ctrl, 0, 0, 0, 0)
K.setup(comp)
local SIZE = K.v.size
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", cur(3))
expr(ctrl, "Cur", "Text(" .. cur(4) .. ")")
expr(ctrl, "T", "iif(Idx < 1, 0, min(max((Since + 1)/max(CapIn, 1), 0), 1))")
expr(ctrl, "Fade", "iif(Idx < 1, 0, min(T*3, 1) * iif(CapOut <= 0, 1, min(max(Until/CapOut, 0), 1)))")
-- Pop grows with an overshoot, Slam drops from very big, the others keep their size
expr(ctrl, "Scale", [[(function(e, t, s)
  if e == 0 then local u = t - 1 local k = 1.70158*s return 0.5 + 0.5*(1 + (k + 1)*u*u*u + k*u*u) end
  if e == 1 then return 1 + 1.6*s*(1 - t)^3 end
  return 1
end)(CapEnter, T, CapPower)]])
-- Slam shakes for a moment after it lands, Shake rattles while it comes in, Slide Up rises
expr(ctrl, "Off", [[(function(e, t, s, n, dur, now)
  local function r(k) local v = math.sin(now*12.9898 + k)*43758.5453 return (v - math.floor(v))*2 - 1 end
  if e == 1 then
    local a = 0
    if n >= dur*0.8 then a = 0.012*s*math.max(0, 1 - (n - dur*0.8)/dur) end
    return Point(a*r(1.3), a*r(7.7))
  elseif e == 2 then
    local a = 0.014*s*math.max(0, 1 - n/(dur*2))
    return Point(a*r(1.3), a*r(7.7))
  elseif e == 3 then
    local u = 1 - t
    return Point(0, -0.08*s*u*u*u)
  end
  return Point(0, 0)
end)(CapEnter, T, CapPower, Since, max(CapIn, 1), time)]])
-- odd lines lean one way, even lines the other
expr(ctrl, "Rot", "CapTilt * iif(Idx % 2 == 1, 1, -1) + CapSway*sin(time*14)")

-- the line is cut into three pieces: before the marked word, the marked word, after it
local function piece(n)
  return string.format([[Text((function(s, n)
  local a, b, c = s:match("^(.-)%%*(.-)%%*(.*)$")
  if not a then a, b, c = s, "", "" end
  local t = ({a, b, c})[n]:gsub("%%*", ""):gsub("^%%s+", ""):gsub("%%s+$", "")
  if b == "" then t = t:gsub("%%s*|%%s*", "\n") end
  return t
end)(VarCtrl.Cur.Value, %d))]], n)
end
local seg = {}
for n, tag in ipairs({"A", "B", "C"}) do
  local t = add("TextPlus", "Seg" .. tag, -4, n - 1)
  t:SetInput("UseFrameFormatSettings", 1)
  K.font(t)
  expr(t, "StyledText", piece(n))
  expr(t, "Size", n == 2 and SIZE .. " * VarCtrl.CapMark" or SIZE)
  seg[n] = t
  -- how wide the piece came out, as a fraction of the frame width
  expr(ctrl, "W" .. tag, string.format([[(function()
  if Seg%s.StyledText.Value == "" then return 0 end
  local d = Seg%s.Output.DataWindow
  if not d then return 0 end
  return math.max(d.right - d.left, 0) / Seg%s.Output.Width
end)()]], tag, tag, tag))
end
-- gaps left and right of the marked word, only where there is something next to it
expr(ctrl, "Gap", "Point(iif(WA > 0 and WB > 0, CapGap*" .. SIZE .. ", 0), iif(WB > 0 and WC > 0, CapGap*" .. SIZE .. ", 0))")

local X0 = "(VarCtrl.CapPos.X - (VarCtrl.WA + VarCtrl.WB + VarCtrl.WC + VarCtrl.Gap.X + VarCtrl.Gap.Y)/2)"
local ASPECT = "VarCtrl.Output.Width/VarCtrl.Output.Height"
local putA = add("Merge", "PutA", -2, 0)
putA.Background = ctrl.Output; putA.Foreground = seg[1].Output
expr(putA, "Center", "Point(" .. X0 .. " + VarCtrl.WA/2, VarCtrl.CapPos.Y)")
-- the marked word sits on the same baseline as the rest, so it is lifted by part of what it gained in height
local mark = add("Merge", "MarkOnly", -2, 1)
mark.Background = ctrl.Output; mark.Foreground = seg[2].Output
expr(mark, "Center", "Point(" .. X0 .. " + VarCtrl.WA + VarCtrl.Gap.X + VarCtrl.WB/2, VarCtrl.CapPos.Y + 0.28*" .. SIZE .. "*(VarCtrl.CapMark - 1)*" .. ASPECT .. ")")
local putB = add("Merge", "PutB", -1, 0)
putB.Background = putA.Output; putB.Foreground = mark.Output
local glyph = add("Merge", "Glyphs", 0, 0)
glyph.Background = putB.Output; glyph.Foreground = seg[3].Output
expr(glyph, "Center", "Point(" .. X0 .. " + VarCtrl.WA + VarCtrl.Gap.X + VarCtrl.WB + VarCtrl.Gap.Y + VarCtrl.WC/2, VarCtrl.CapPos.Y)")

-- colour holders for the Custom preset
for i, name in ipairs(HOLD) do
  if name:sub(1, 2) ~= "Lk" then
    local h = add("Background", name, -6 + i, -5)
    h:SetInput("UseFrameFormatSettings", 0); h:SetInput("Width", 16); h:SetInput("Height", 16)
    L.color(h, D[(i - 1)*3 + 1], D[(i - 1)*3 + 2], D[(i - 1)*3 + 3], 1)
  end
end

-- a vertical gradient cut out by the letters
local function paint(name, src, k, x, y)
  local c = add("Custom", name, x, y)
  c.Image1 = src
  for ch = 1, 3 do
    expr(c, "NumberIn" .. ch, col(k, ch))
    expr(c, "NumberIn" .. (ch + 3), col(k + 1, ch))
  end
  -- bottom and top of the letters
  expr(c, "PointIn1", "Point(VarCtrl.CapPos.Y - 0.3*" .. SIZE .. "*" .. ASPECT .. ", VarCtrl.CapPos.Y + 0.3*" .. SIZE .. "*" .. ASPECT .. ")")
  c:SetInput("Intermediate1", "min(max((y - p1x)/max(p1y - p1x, 0.0001), 0), 1)")
  c:SetInput("RedExpression", "(n4 + (n1 - n4)*i1)*a1")
  c:SetInput("GreenExpression", "(n5 + (n2 - n5)*i1)*a1")
  c:SetInput("BlueExpression", "(n6 + (n3 - n6)*i1)*a1")
  c:SetInput("AlphaExpression", "a1")
  return c
end
local fill = paint("FillPaint", glyph.Output, 1, 2, 0)
local markFill = paint("MarkPaint", mark.Output, 3, 2, 1)

-- three outlines, each one the letters grown a bit further
local grown = {}
local INNER, MIDDLE = K.v.edge, K.v.outer
local widths = {INNER, INNER .. " + " .. MIDDLE, INNER .. " + " .. MIDDLE .. " + VarCtrl.CapOuter"}
for i = 1, 3 do
  local g = add("ErodeDilate", "Grow" .. ({"Inner", "Middle", "Outer"})[i], 1, 2 + i)
  g.Input = glyph.Output
  g:SetInput("Filter", 3)
  expr(g, "XAmount", widths[i])
  grown[i] = g
end
local stroke = add("Custom", "StrokePaint", 3, 4)
stroke.Image1 = grown[1].Output; stroke.Image2 = grown[2].Output; stroke.Image3 = grown[3].Output
for ch = 1, 3 do
  expr(stroke, "NumberIn" .. ch, col(5, ch))
  expr(stroke, "NumberIn" .. (ch + 3), col(6, ch))
end
expr(stroke, "PointIn1", "Point(" .. col(7, 1) .. ", " .. col(7, 2) .. ")")
expr(stroke, "PointIn2", "Point(" .. col(7, 3) .. ", 0)")
-- an outline of zero width is left out, otherwise it would cover the one inside it
expr(stroke, "NumberIn7", "iif(" .. MIDDLE .. " > 0, 1, 0)")
expr(stroke, "NumberIn8", "iif(VarCtrl.CapOuter > 0, 1, 0)")
expr(stroke, "PointIn3", "Point(iif(" .. INNER .. " > 0, 1, 0), 0)")
stroke:SetInput("Intermediate1", "a1*p3x")
stroke:SetInput("Intermediate2", "a2*n7")
stroke:SetInput("Intermediate3", "a3*n8")
stroke:SetInput("RedExpression",   "n1*i1 + (1 - i1)*(n4*i2 + (1 - i2)*p1x*i3)")
stroke:SetInput("GreenExpression", "n2*i1 + (1 - i1)*(n5*i2 + (1 - i2)*p1y*i3)")
stroke:SetInput("BlueExpression",  "n3*i1 + (1 - i1)*(n6*i2 + (1 - i2)*p2x*i3)")
stroke:SetInput("AlphaExpression", "i1 + (1 - i1)*(i2 + (1 - i2)*i3)")

local m1 = add("Merge", "OverStroke", 4, 2)
m1.Background = stroke.Output; m1.Foreground = fill.Output
local m2 = add("Merge", "OverMark", 5, 2)
m2.Background = m1.Output; m2.Foreground = markFill.Output
local shadow = K.drop(comp, "CapDrop", 6, 2, m2.Output)
local move = add("Transform", "CapMove", 7, 2)
move.Input = shadow.Output
expr(move, "Pivot", "VarCtrl.CapPos")
expr(move, "Center", "Point(0.5 + VarCtrl.Off.X, 0.5 + VarCtrl.Off.Y)")
expr(move, "Size", "VarCtrl.Scale")
expr(move, "Angle", "VarCtrl.Rot")
local out = add("Merge", "CapFinal", 8, 2)
out.Background = ctrl.Output; out.Foreground = move.Output
expr(out, "Blend", "VarCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  local spec = {
    {"NAME", "VarietyCaption"},
    {"OUT", "CapFinal", "Output"},
    {"CTL", "VarCtrl", "CapList", "Lines (mark one word with *stars*)"},
    {"CTL", "VarCtrl", "CapCue", "Line Number (keyframe 1, 2, 3)"},
    {"CTL", "VarCtrl", "CapTimed", "Lines Start With A Time (0:02 Text)"},
    {"CTL", "VarCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "VarCtrl", "CapMark", "Marked Word Size"},
    {"CTL", "VarCtrl", "CapGap", "Marked Word Gap"},
    {"CTL", "VarCtrl", "CapPos", "Position"},
    {"CTL", "VarCtrl", "CapTilt", "Tilt"},
    {"CTL", "VarCtrl", "CapSway", "Sway"},
    {"CTL", "VarCtrl", "CapEnter", "Entrance"},
    {"CTL", "VarCtrl", "CapIn", "Entrance Frames"},
    {"CTL", "VarCtrl", "CapPower", "Entrance Strength"},
    {"CTL", "VarCtrl", "CapOut", "Fade Out Frames"},
    {"CTL", "VarCtrl", "CapPreset", "Colours"},
  }
  K.rows(spec)
  spec[#spec + 1] = {"CTL", "VarCtrl", "CapOuter", "Third Outline"}
  local labels = {[2] = "Custom Fill At The Bottom", [3] = "Custom Marked Top", [4] = "Custom Marked Bottom", [7] = "Custom Third Outline"}
  for i, name in ipairs(HOLD) do
    if labels[i] then
      local g = tostring(10 + i)
      spec[#spec + 1] = {"CTL", name, "TopLeftRed", labels[i], g}
      spec[#spec + 1] = {"CTL", name, "TopLeftGreen", "", g}
      spec[#spec + 1] = {"CTL", name, "TopLeftBlue", "", g}
    end
  end
  L.export(comp, "variety", spec)
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("CapList", file:read("*a")); file:close() end
  local py = tonumber(os.getenv("FX_POSY") or "")
  if py then ctrl:SetInput("CapPos", {0.5, py}) end
  local cue = os.getenv("FX_CUE")
  if cue then
    ctrl:AddModifier("CapCue", "BezierSpline")
    local sp = ctrl.CapCue:GetConnectedOutput():GetTool()
    local mine = {}
    for f, v in string.gmatch(cue, "(%d+)=([%d%.]+)") do ctrl.CapCue[tonumber(f)] = tonumber(v); mine[tonumber(f)] = true end
    for f in pairs(sp:GetKeyFrames()) do if not mine[f] then sp:DeleteKeyFrames(f) end end
  end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 9, 4)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  local v = {}
  for _, f in ipairs({0, 10, 12, 30, 60, 64, 120, 200}) do
    local i, n, w = ctrl:GetInput("Idx", f), ctrl:GetInput("Since", f), ctrl:GetInput("WB", f)
    v[#v + 1] = string.format("%d:%s/%s/%s", f, tostring(i), tostring(n), tostring(w))
  end
  print(table.concat(v, " "))
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "vc", tonumber(os.getenv("FX_STEPS") or "12"))
end
