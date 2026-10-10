-- Corner Tag: the topic of the episode pinned in a corner of the screen, a small label above a bigger line,
-- each on its own box. It slides in from the side at the start and can slide out again at the end.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Corner Tag")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "TagCtrl", -6, -3)
ctrl.UserControls = {
  TagLabel  = L.text("Label", "本集主題"),
  TagText   = L.text("Text", "挑戰超辣火鍋", nil, 2),
  TagCorner = L.combo("Corner", {"Top Left", "Top Right", "Bottom Left", "Bottom Right"}, 1),
  TagMarginX = L.num("Margin X", 0.04, 0, 0.3),
  TagMarginY = L.num("Margin Y", 0.07, 0, 0.3),
  TagSize   = L.num("Size", 0.045, 0.01, 0.2),
  TagLabelSize = L.num("Label Size", 0.6, 0.2, 1.5),
  TagPadX   = L.num("Box Padding X", 0.35, 0, 1.5),
  TagPadY   = L.num("Box Padding Y", 0.25, 0, 1.5),
  TagRound  = L.num("Box Roundness", 0.3, 0, 1),
  TagShadow = L.num("Shadow", 0.5, 0, 1),
  TagIn     = L.num("Slide In Frames", 12, 1, 60),
  TagLeave  = L.check("Slide Out At The End", 1),
  TagOut    = L.num("Slide Out Frames", 10, 1, 60),
  Side  = L.num("Side", 1, -1, 1, "Driver"),
  Up    = L.num("Up", 1, -1, 1, "Driver"),
  Slide = L.num("Slide", 0, 0, 1, "Driver"),
  Main  = L.point("Main", "Driver"), Small = L.point("Small", "Driver"),
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
L.color(ctrl, 0, 0, 0, 0)
-- Side: 1 for the right hand corners, -1 for the left. Up: 1 for the top corners, -1 for the bottom.
expr(ctrl, "Side", "iif(TagCorner % 2 == 1, 1, -1)")
expr(ctrl, "Up", "iif(TagCorner < 2, 1, -1)")
-- Slide: 1 when fully off screen, 0 when in place
expr(ctrl, "Slide", [[(function(tin, tout)
  local a = 1 - tin
  return a*a*a + tout*tout*tout
end)(min(max((time - comp.RenderStart + 1)/max(TagIn, 1), 0), 1),
     iif(TagLeave > 0, min(max((time - (comp.RenderEnd - TagOut))/max(TagOut, 1), 0), 1), 0))]])
-- where the two lines sit: the edge of the text is Margin away from the edge of the frame,
-- and the label is always the upper line
local ASPECT = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
local STEP = "TagSize*" .. ASPECT .. "*(0.62 + 0.5*TagLabelSize + 1.1*TagPadY*0.5)"
expr(ctrl, "Main", "Point(iif(Side > 0, 1 - TagMarginX, TagMarginX), iif(Up > 0, 1 - TagMarginY - " .. STEP .. ", TagMarginY))")
expr(ctrl, "Small", "Point(Main.X, Main.Y + " .. STEP .. ")")

local function line(name, y, textExpr, sizeExpr, posExpr, r, g, b)
  local t = add("TextPlus", name, -4, y)
  t:SetInput("UseFrameFormatSettings", 1)
  t:SetInput("Font", "Microsoft JhengHei"); t:SetInput("Style", "Bold")
  expr(t, "StyledText", textExpr)
  expr(t, "Size", sizeExpr)
  expr(t, "Center", posExpr)
  -- on the right the text ends at its position, on the left it starts there
  expr(t, "HorizontalLeftCenterRight", "TagCtrl.Side")
  t:SetInput("Red1", r); t:SetInput("Green1", g); t:SetInput("Blue1", b)
  return t
end
-- a box that always fits the words: a second Text+ that only draws its border fill
local function box(name, y, of, r, g, b)
  local t = add("TextPlus", name, -4, y)
  t:SetInput("UseFrameFormatSettings", 1)
  for _, id in ipairs({"StyledText", "Font", "Style", "Size", "Center", "HorizontalLeftCenterRight"}) do expr(t, id, of .. "." .. id) end
  t:SetInput("ElementShape1", 2); t:SetInput("Level1", 0)
  expr(t, "ExtendHorizontal1", "TagCtrl.TagPadX")
  expr(t, "ExtendVertical1", "TagCtrl.TagPadY")
  expr(t, "Round1", "TagCtrl.TagRound")
  t:SetInput("Red1", r); t:SetInput("Green1", g); t:SetInput("Blue1", b)
  return t
end
local main = line("TagMain", 0, "Text(TagCtrl.TagText.Value)", "TagCtrl.TagSize", "TagCtrl.Main", 1, 1, 1)
local mainBox = box("TagMainBox", 1, "TagMain", 0.86, 0.10, 0.16)
local small = line("TagSmall", 2, "Text(TagCtrl.TagLabel.Value)", "TagCtrl.TagSize * TagCtrl.TagLabelSize", "TagCtrl.Small", 0.1, 0.08, 0.02)
expr(small, "Font", "TagMain.Font"); expr(small, "Style", "TagMain.Style")
local smallBox = box("TagSmallBox", 3, "TagSmall", 1.0, 0.86, 0.12)

local last = ctrl
for i, t in ipairs({mainBox, main, smallBox, small}) do
  local m = add("Merge", "TagLayer" .. ({"A", "B", "C", "D"})[i], -2 + i, 1)
  m.Background = last.Output; m.Foreground = t.Output
  -- no label text, no label box
  if i >= 3 then expr(m, "Blend", "iif(TagCtrl.TagLabel.Value == '', 0, 1)") end
  last = m
end
local shadow = add("Shadow", "TagDrop", 3, 1)
shadow.Input = last.Output
shadow:SetInput("ShadowOffset", {0.504, 0.493})
shadow:SetInput("Softness", 2)
expr(shadow, "Alpha", "TagCtrl.TagShadow")
local move = add("Transform", "TagMove", 4, 1)
move.Input = shadow.Output
expr(move, "Center", "Point(0.5 + TagCtrl.Side*TagCtrl.Slide*0.7, 0.5)")
local out = add("Merge", "TagOut", 5, 1)
out.Background = ctrl.Output; out.Foreground = move.Output

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
print("round", tostring((mainBox:GetInput("Round1"))), "align", tostring((main:GetInput("HorizontalLeftCenterRight", 10))))

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "cornertag", {
    {"NAME", "CornerTag"},
    {"OUT", "TagOut", "Output"},
    {"CTL", "TagCtrl", "TagLabel", "Label"},
    {"CTL", "TagCtrl", "TagText", "Text"},
    {"CTL", "TagCtrl", "TagCorner", "Corner"},
    {"CTL", "TagCtrl", "TagMarginX", "Margin X"},
    {"CTL", "TagCtrl", "TagMarginY", "Margin Y"},
    {"CTL", "TagMain", "Font", "Font", "2"}, {"CTL", "TagMain", "Style", "", "2"},
    {"CTL", "TagCtrl", "TagSize", "Size"},
    {"CTL", "TagCtrl", "TagLabelSize", "Label Size"},
    {"CTL", "TagMain", "Red1", "Text Color", "3"}, {"CTL", "TagMain", "Green1", "", "3"}, {"CTL", "TagMain", "Blue1", "", "3"},
    {"CTL", "TagMainBox", "Red1", "Box Color", "4"}, {"CTL", "TagMainBox", "Green1", "", "4"}, {"CTL", "TagMainBox", "Blue1", "", "4"},
    {"CTL", "TagSmall", "Red1", "Label Text Color", "5"}, {"CTL", "TagSmall", "Green1", "", "5"}, {"CTL", "TagSmall", "Blue1", "", "5"},
    {"CTL", "TagSmallBox", "Red1", "Label Box Color", "6"}, {"CTL", "TagSmallBox", "Green1", "", "6"}, {"CTL", "TagSmallBox", "Blue1", "", "6"},
    {"CTL", "TagCtrl", "TagPadX", "Box Padding X"},
    {"CTL", "TagCtrl", "TagPadY", "Box Padding Y"},
    {"CTL", "TagCtrl", "TagRound", "Box Roundness"},
    {"CTL", "TagCtrl", "TagShadow", "Shadow"},
    {"CTL", "TagCtrl", "TagIn", "Slide In Frames"},
    {"CTL", "TagCtrl", "TagLeave", "Slide Out At The End"},
    {"CTL", "TagCtrl", "TagOut", "Slide Out Frames"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local pm = add("Merge", "PrevOver", 6, 3)
  pm.Background = s.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "ct", tonumber(os.getenv("FX_STEPS") or "12"))
end
