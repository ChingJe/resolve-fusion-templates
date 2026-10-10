-- Side Note: a small tilted remark with a hand drawn arrow pointing at something in the picture.
-- Remarks come from one text box, picked by keyframing Line Number or by a time in front of every line.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2" keyframes Line Number for a test.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Side Note")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local cur = L.cur("NoteCtrl", "NoteList", "NoteTimed", "NoteCue")

local ctrl = add("Background", "NoteCtrl", -6, -3)
ctrl.UserControls = {
  NoteList  = L.text("Remarks", "其實超怕的\n根本沒在聽", nil, 6),
  NoteCue   = L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20),
  NoteTimed = L.check("Lines Start With A Time (0:02 Text)", 0),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  NoteSize  = L.num("Size", 0.05, 0.01, 0.2),
  NoteTilt  = L.num("Tilt", -6, -45, 45),
  NotePos    = L.point("Text Position", nil, true),
  NoteTarget = L.point("Arrow Points At", nil, true),
  NoteArrow = L.check("Arrow", 1),
  NoteBend  = L.num("Arrow Bend", 0.18, -0.6, 0.6),
  NoteThick = L.num("Arrow Thickness", 0.007, 0.001, 0.03),
  NoteHead  = L.num("Arrow Head", 0.035, 0, 0.15),
  NoteShort = L.num("Arrow Stops Short", 0.02, 0, 0.2),
  NoteEdge  = L.num("Outline", 0.003, 0, 0.02),
  NoteIn    = L.num("Pop Frames", 6, 1, 40),
  NoteDraw  = L.num("Arrow Draw Frames", 8, 1, 60),
  NoteOut   = L.num("Fade Out Frames", 3, 0, 40),
  Idx   = L.num("Idx", 0, 0, 100, "Driver"),
  Since = L.num("Since", 0, 0, 100, "Driver"),
  Until = L.num("Until", 0, 0, 100, "Driver"),
  T     = L.num("T", 0, 0, 1, "Driver"),
  Back  = L.num("Back", 0, 0, 2, "Driver"),
  Fade  = L.num("Fade", 0, 0, 1, "Driver"),
  Draw  = L.num("Draw", 0, 0, 1, "Driver"),
  From = L.point("From", "Driver"), To = L.point("To", "Driver"),
  HeadA = L.point("HeadA", "Driver"), HeadB = L.point("HeadB", "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("NotePos", {0.74, 0.72})
ctrl:SetInput("NoteTarget", {0.5, 0.5})
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", cur(3))
expr(ctrl, "T", "iif(Idx < 1, 0, min(max((Since + 1)/max(NoteIn, 1), 0), 1))")
expr(ctrl, "Back", "(function(t) t = t - 1 return 1 + 2.70158*t*t*t + 1.70158*t*t end)(T)")
expr(ctrl, "Fade", "iif(Idx < 1, 0, min(T*3, 1) * iif(NoteOut <= 0, 1, min(max(Until/NoteOut, 0), 1)))")
-- the arrow starts drawing when the text has popped
expr(ctrl, "Draw", "iif(Idx < 1, 0, min(max((Since + 1 - NoteIn)/max(NoteDraw, 1), 0), 1))")

local text = add("TextPlus", "NoteText", -4, 0)
text:SetInput("UseFrameFormatSettings", 1)
text:SetInput("Font", "Microsoft JhengHei"); text:SetInput("Style", "Bold")
expr(text, "StyledText", "Text((function(s) return (s:gsub('%s*|%s*', '\\n')) end)(" .. cur(4) .. "))")
expr(text, "Size", "NoteCtrl.NoteSize * (0.6 + 0.4*NoteCtrl.Back)")
expr(text, "Center", "NoteCtrl.NotePos")
expr(text, "AngleZ", "NoteCtrl.NoteTilt")

-- From: where the arrow leaves, just outside the box around the text on the side facing the target.
-- Lengths are in units of the frame height, so x differences are multiplied by the aspect ratio.
local BOX = [[(function(pick)
  local asp = NoteText.Output.Width / NoteText.Output.Height
  local px, py, tx, ty = NoteCtrl.NotePos.X, NoteCtrl.NotePos.Y, NoteCtrl.NoteTarget.X, NoteCtrl.NoteTarget.Y
  local hw, hh = 0, 0
  local d = NoteText.StyledText.Value ~= "" and NoteText.Output.DataWindow
  if d then hw, hh = (d.right - d.left)/NoteText.Output.Width/2*asp, (d.top - d.bottom)/NoteText.Output.Height/2 end
  local dx, dy = (tx - px)*asp, ty - py
  local len = math.max(math.sqrt(dx*dx + dy*dy), 0.0001)
  local pad = NoteCtrl.NoteSize*0.5
  local k = math.min((hw + pad)/math.max(math.abs(dx), 0.0001), (hh + pad)/math.max(math.abs(dy), 0.0001), 0.8)
  local ax, ay = px + dx*k/asp, py + dy*k
  local bx, by = tx - dx/len*NoteCtrl.NoteShort/asp, ty - dy/len*NoteCtrl.NoteShort
  if pick == 1 then return Point(ax, ay) elseif pick == 2 then return Point(bx, by) end
  -- direction the arrow arrives from, then turned 28 degrees either way for the two strokes of the head
  local ex, ey = (bx - ax)*asp, by - ay
  local el = math.max(math.sqrt(ex*ex + ey*ey), 0.0001)
  ex, ey = ex/el, ey/el
  local s = NoteCtrl.NoteBend*math.pi
  local vx, vy = -(ex - s*ey), -(ey + s*ex)
  local vl = math.sqrt(vx*vx + vy*vy)
  vx, vy = vx/vl, vy/vl
  local a = math.rad(pick == 3 and 28 or -28)
  return Point(vx*math.cos(a) - vy*math.sin(a), vx*math.sin(a) + vy*math.cos(a))
end)(%d)]]
expr(ctrl, "From", string.format(BOX, 1))
expr(ctrl, "To", string.format(BOX, 2))
expr(ctrl, "HeadA", string.format(BOX, 3))
expr(ctrl, "HeadB", string.format(BOX, 4))

local arrow = add("Custom", "NoteArrowDraw", -2, 2)
arrow.Image1 = ctrl.Output
expr(arrow, "PointIn1", "NoteCtrl.From")
expr(arrow, "PointIn2", "NoteCtrl.To")
expr(arrow, "PointIn3", "NoteCtrl.HeadA")
expr(arrow, "PointIn4", "NoteCtrl.HeadB")
expr(arrow, "NumberIn1", "NoteCtrl.NoteBend")
expr(arrow, "NumberIn2", "NoteCtrl.NoteThick")
expr(arrow, "NumberIn3", "NoteCtrl.Draw")
expr(arrow, "NumberIn4", "NoteCtrl.NoteHead")
expr(arrow, "NumberIn5", "iif(NoteCtrl.NoteArrow > 0 and NoteCtrl.Idx >= 1, 1, 0)")
-- i1, i2: this pixel seen from the start of the arrow. i3, i4: the whole arrow. i5: its length.
arrow:SetInput("Intermediate1", "(x - p1x)*w/h")
arrow:SetInput("Intermediate2", "y - p1y")
arrow:SetInput("Intermediate3", "(p2x - p1x)*w/h")
arrow:SetInput("Intermediate4", "p2y - p1y")
arrow:SetInput("Intermediate5", "max(sqrt(i3*i3 + i4*i4), 0.0001)")
-- i6: how far along the arrow (0..1). i7: how far off the bent line, with a slight wobble like a pen stroke.
arrow:SetInput("Intermediate6", "(i1*i3 + i2*i4)/(i5*i5)")
arrow:SetInput("Intermediate7", "(i1*i4 - i2*i3)/i5 - i5*(n1*sin(180*i6) + 0.006*sin(i6*800))")
-- i8: the two strokes of the head, which appear once the line has arrived
arrow:SetInput("Intermediate8", "if(n3 < 1, 0, max(" ..
  "if(((i1 - i3)*p3x + (i2 - i4)*p3y) >= 0 && ((i1 - i3)*p3x + (i2 - i4)*p3y) <= n4, min(max((n2/2 - abs((i1 - i3)*p3y - (i2 - i4)*p3x))*h + 0.5, 0), 1), 0), " ..
  "if(((i1 - i3)*p4x + (i2 - i4)*p4y) >= 0 && ((i1 - i3)*p4x + (i2 - i4)*p4y) <= n4, min(max((n2/2 - abs((i1 - i3)*p4y - (i2 - i4)*p4x))*h + 0.5, 0), 1), 0)))")
local A = "n5*max(i8, if(i6 >= 0 && i6 <= n3, min(max((n2/2 - abs(i7))*h + 0.5, 0), 1), 0))"
arrow:SetInput("RedExpression", A); arrow:SetInput("GreenExpression", A)
arrow:SetInput("BlueExpression", A); arrow:SetInput("AlphaExpression", A)

local ink = add("Merge", "NoteInk", 0, 0)
ink.Background = arrow.Output; ink.Foreground = text.Output

local inkCol = add("Background", "ColInk", -3, -5)
local edgeCol = add("Background", "ColEdge", -2, -5)
for _, h in ipairs({inkCol, edgeCol}) do h:SetInput("UseFrameFormatSettings", 0); h:SetInput("Width", 16); h:SetInput("Height", 16) end
L.color(inkCol, 1, 1, 1, 1); L.color(edgeCol, 0.08, 0.08, 0.1, 1)
local painted = L.inked(comp, "NotePaint", 1, 0, ink.Output, "NoteCtrl.NoteEdge", "0", {
  "ColInk.TopLeftRed", "ColInk.TopLeftGreen", "ColInk.TopLeftBlue",
  "ColEdge.TopLeftRed", "ColEdge.TopLeftGreen", "ColEdge.TopLeftBlue", "0", "0", "0"})
local out = add("Merge", "NoteOut", 4, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "NoteCtrl.Fade")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "sidenote", {
    {"NAME", "SideNote"},
    {"OUT", "NoteOut", "Output"},
    {"CTL", "NoteCtrl", "NoteList", "Remarks"},
    {"CTL", "NoteCtrl", "NoteCue", "Line Number (keyframe 1, 2, 3)"},
    {"CTL", "NoteCtrl", "NoteTimed", "Lines Start With A Time (0:02 Text)"},
    {"CTL", "NoteCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "NoteText", "Font", "Font", "2"}, {"CTL", "NoteText", "Style", "", "2"},
    {"CTL", "NoteCtrl", "NoteSize", "Size"},
    {"CTL", "NoteCtrl", "NoteTilt", "Tilt"},
    {"CTL", "NoteCtrl", "NotePos", "Text Position"},
    {"CTL", "NoteCtrl", "NoteTarget", "Arrow Points At"},
    {"CTL", "NoteCtrl", "NoteArrow", "Arrow"},
    {"CTL", "NoteCtrl", "NoteBend", "Arrow Bend"},
    {"CTL", "NoteCtrl", "NoteThick", "Arrow Thickness"},
    {"CTL", "NoteCtrl", "NoteHead", "Arrow Head"},
    {"CTL", "NoteCtrl", "NoteShort", "Arrow Stops Short"},
    {"CTL", "ColInk", "TopLeftRed", "Color", "3"}, {"CTL", "ColInk", "TopLeftGreen", "", "3"}, {"CTL", "ColInk", "TopLeftBlue", "", "3"},
    {"CTL", "ColEdge", "TopLeftRed", "Outline Color", "4"}, {"CTL", "ColEdge", "TopLeftGreen", "", "4"}, {"CTL", "ColEdge", "TopLeftBlue", "", "4"},
    {"CTL", "NoteCtrl", "NoteEdge", "Outline"},
    {"CTL", "NoteCtrl", "NoteIn", "Pop Frames"},
    {"CTL", "NoteCtrl", "NoteDraw", "Arrow Draw Frames"},
    {"CTL", "NoteCtrl", "NoteOut", "Fade Out Frames"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("NoteList", file:read("*a")); file:close() end
  L.keys(ctrl, "NoteCue", os.getenv("FX_CUE"))
  local tgt = os.getenv("FX_TARGET")
  if tgt then local a, b = tgt:match("([%d%.]+),([%d%.]+)"); ctrl:SetInput("NoteTarget", {tonumber(a), tonumber(b)}) end
  local pos = os.getenv("FX_POS")
  if pos then local a, b = pos:match("([%d%.]+),([%d%.]+)"); ctrl:SetInput("NotePos", {tonumber(a), tonumber(b)}) end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 5, 2)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  local f = ctrl:GetInput("From", 30); local t = ctrl:GetInput("To", 30); local hd = ctrl:GetInput("HeadA", 30)
  print("from", f and f[1], f and f[2], "to", t and t[1], t and t[2], "head", hd and hd[1], hd and hd[2])
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "sn", tonumber(os.getenv("FX_STEPS") or "12"))
end
