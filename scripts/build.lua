local resolve = bmd.scriptapp("Resolve")
local fu = resolve:Fusion()
local comp = fu:GetCurrentComp()
if not comp then print("NO_COMP") return end
local OUT = "D:/davinci/scripts/out/"
local PIVOT_X = tonumber(os.getenv("COMIC_PX") or "0.5")
local PIVOT_Y = tonumber(os.getenv("COMIC_PY") or "0.5")

comp:SetAttrs({COMPN_RenderStart = 0, COMPN_RenderEnd = 119})
comp:Lock()
comp:StartUndo("Build Comic Intro")

-- clean slate (keep MediaOut)
local mediaOut
for _, t in pairs(comp:GetToolList(false)) do
  if t.ID == "MediaOut" then mediaOut = t else t:Delete() end
end

local function add(id, name, x, y)
  local t = comp:AddTool(id, x, y)
  t:SetAttrs({TOOLS_Name = name})
  return t
end
local function expr(tool, input, e) tool[input]:SetExpression(e) end
local function color(bg, r, g, b)
  bg.TopLeftRed = r; bg.TopLeftGreen = g; bg.TopLeftBlue = b; bg.TopLeftAlpha = 1
end

---------------------------------------------------------------- controller
local ctrl = add("Background", "ComicCtrl", -5, -3)
local function num(label, def, lo, hi, page)
  return {LINKID_DataType = "Number", INPID_InputControl = "SliderControl", LINKS_Name = label,
          INP_Default = def, INP_MinScale = lo, INP_MaxScale = hi, ICS_ControlPage = page or "Comic"}
end
ctrl.UserControls = {
  FramesPerPage = num("Frames Per Page", 4, 2, 12),
  MaxZoom       = num("Start Zoom", 60, 2, 120),
  PivotX        = num("Zoom Pivot X", PIVOT_X, 0, 1),
  PivotY        = num("Zoom Pivot Y", PIVOT_Y, 0, 1),
  TextSize      = num("Text Size", 0.2, 0.02, 0.5),
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
expr(ctrl, "K", "time / FramesPerPage")
expr(ctrl, "E", "min((K - floor(K)) / 0.55, 1)")
expr(ctrl, "Scroll", "floor(K) + E*E*(3 - 2*E)")
expr(ctrl, "BlurLen", "0.10 * sin(3.14159265 * E)")
expr(ctrl, "ZT", "min(max((P - 0.12) / 0.62, 0), 1)")
expr(ctrl, "ZE", "ZT*ZT*(3 - 2*ZT)")
expr(ctrl, "Zoom", "MaxZoom ^ (1 - ZE) * (1 + 0.05*(1 - P))")
-- full-screen page "window" anchored at the pivot: it recedes with the pull-back, so the opening
-- is full-frame comic pages even when the pivot is not inside a letter
expr(ctrl, "WinSize", "(2*max(max(PivotX, 1 - PivotX), max(PivotY, 1 - PivotY)) + 0.05) * Zoom / (MaxZoom*1.05)")
expr(ctrl, "WinFade", "1 - min(max((ZE - 0.40) / 0.22, 0), 1)")
expr(ctrl, "White", "min(max((P - 0.76) / 0.08, 0), 1)")
expr(ctrl, "Flash", "max(1 - abs(P - 0.83) / 0.07, 0)")

---------------------------------------------------------------- comic pages
local pgBG = add("Background", "PageBase", -5, 0)
color(pgBG, 0, 0, 0)
pgBG:SetInput("Depth", 4) -- float32, the next node stores coordinates in the channels

-- pass 1: panel layout. R,G = position inside the panel, B = panel random id, A = distance to panel edge
local cells = add("Custom", "PageCells", -4, 0)
cells.Image1 = pgBG.Output
expr(cells, "NumberIn1", "ComicCtrl.Scroll")
cells:SetInput("Intermediate1", "y + n1")
cells:SetInput("Intermediate2", "floor(frac(i1)*3) + floor(i1)*3")
cells:SetInput("Intermediate3", "2 + floor(frac(abs(sin(i2*12.9898)*43758.5453))*2)")
cells:SetInput("RedExpression", "frac(x*i3)")
cells:SetInput("GreenExpression", "frac(frac(i1)*3)")
cells:SetInput("BlueExpression", "frac(abs(sin((floor(x*i3) + i2*7.13)*78.233)*43758.5453))")
cells:SetInput("AlphaExpression", "min(min(frac(x*i3), 1-frac(x*i3))/i3, min(frac(frac(i1)*3), 1-frac(frac(i1)*3))*h/(3*w))")

-- pass 2: ink and colour
local pages = add("Custom", "PageInk", -3, 0)
pages.Image1 = cells.Output
expr(pages, "NumberIn1", "ComicCtrl.Scroll")
pages:SetInput("NumberIn3", 110) -- halftone dots across the frame width
pages:SetInput("Intermediate1", "y + n1")
pages:SetInput("Intermediate2", "floor(b1*7)")
pages:SetInput("Intermediate3", "frac(b1*91.7)")
pages:SetInput("Intermediate4", "if(dist(frac(x*n3), frac(i1*n3*h/w), 0.5, 0.5) < 0.12 + 0.34*g1, 1, 0)")
pages:SetInput("Intermediate5", "if(i3 < 0.4, if(sin(atan2(g1 - 0.5, (r1 - 0.5)*1.5)*(8 + floor(b1*8))) > 0.1, 1, 0), 0)")
pages:SetInput("Intermediate6", "if(i3 > 0.55, (r1 - 0.3 - 0.4*floor(b1*2))*(r1 - 0.3 - 0.4*floor(b1*2))/0.05 + (g1 - 0.74)*(g1 - 0.74)/0.022, 9)")
pages:SetInput("Intermediate7", "if(i3 >= 0.4, if(g1 < 0.12 + 0.34*frac(abs(sin((floor(r1*11) + floor(b1*50)*3.7)*78.233)*43758.5453)), 1, 0), 0)")
local function pal(a, b, c, d, e, f, g)
  return string.format("if(i2<1,%g, if(i2<2,%g, if(i2<3,%g, if(i2<4,%g, if(i2<5,%g, if(i2<6,%g,%g))))))", a, b, c, d, e, f, g)
end
local function chan(p)
  return "if(a1 < 0.006, 0.95, if(a1 < 0.0095, 0.05, " ..
         "if(i6 < 1, if(i6 < 0.5, if(sin(g1*6200) > 0.35, 0.18, 0.97), 0.97), if(i6 < 1.28, 0.05, " ..
         "if(i7 > 0.5, 0.07, ((" .. p .. ") + (1 - (" .. p .. "))*0.42*i5) * (1 - 0.30*i4))))))"
end
--                         red   yellow blue  cyan  orange cream purple
pages:SetInput("RedExpression",   chan(pal(0.86, 0.98, 0.13, 0.25, 0.95, 0.95, 0.47)))
pages:SetInput("GreenExpression", chan(pal(0.13, 0.82, 0.30, 0.70, 0.52, 0.91, 0.20)))
pages:SetInput("BlueExpression",  chan(pal(0.13, 0.16, 0.75, 0.90, 0.22, 0.80, 0.62)))
pages:SetInput("AlphaExpression", "1")

local blur = add("DirectionalBlur", "FlipBlur", -2, 0)
blur.Input = pages.Output
blur:SetInput("Angle", 90)
expr(blur, "Length", "ComicCtrl.BlurLen")

---------------------------------------------------------------- title + plate
-- everything scales around the pivot, so the pull-back starts from inside one letter stroke
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

-- follow the timeline resolution when used as a template
for _, t in ipairs({ctrl, pgBG, text, black, win, red}) do
  if t.UseFrameFormatSettings then t:SetInput("UseFrameFormatSettings", 1) end
end

if mediaOut then mediaOut.Input = glow.Output end

comp:EndUndo(true)
comp:Unlock()

for _, f in ipairs({0, 30, 60, 90, 119}) do
  print(string.format("f%3d  P=%.3f Scroll=%.3f Blur=%.3f Zoom=%.3f Win=%.2f White=%.2f", f,
    ctrl:GetInput("P", f), ctrl:GetInput("Scroll", f), ctrl:GetInput("BlurLen", f),
    ctrl:GetInput("Zoom", f), ctrl:GetInput("WinSize", f), ctrl:GetInput("White", f)))
end

---------------------------------------------------------------- test render (temporary nodes)
comp:Lock()
local small = comp:AddTool("BetterResize", 4, 2)
small.Input = glow.Output
small:SetInput("Width", 640); small:SetInput("Height", 360)
local saver = comp:AddTool("Saver", 5, 2)
saver.Input = small.Output
saver:SetInput("Clip", OUT .. "f.png")
-- full-res title at its resting size, used to pick a zoom pivot inside a letter
local saver2 = comp:AddTool("Saver", 3, -2)
saver2.Input = text.Output
saver2:SetInput("Clip", OUT .. "title.png")
comp:Unlock()
print("render", tostring(comp:Render({Start = 0, End = 119, Wait = true})))
comp:SetAttrs({COMPN_RenderStart = 0, COMPN_RenderEnd = 119})
comp:Lock(); saver:Delete(); saver2:Delete(); small:Delete(); comp:Unlock()
