-- Bar Chart: horizontal bars that grow one after another, each with its name and a number that counts up.
-- Rows come from one text box, one per line: "Name 42". The longest bar fills the chart width.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXT="A 10|B 25" overrides the rows for a test render (| stands for a new line), FX_TEXTFILE reads a UTF-8 file.
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local MAX = 8 -- rows the chart can show; the tools for every row exist whether it is used or not

comp:Lock()
comp:StartUndo("Build Bar Chart")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

-- Turns the text into a list of {name, value}. The last word of a line is the value, the rest is the name.
-- Lines without a number at the end are skipped, anything past MAX rows is dropped.
local PARSE = string.format([[(function(txt, sort)
  local out = {}
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local name, v = line:match("^%%s*(.-)%%s*(-?[%%d%%.]+)%%s*$")
    if v and tonumber(v) and #out < %d then out[#out + 1] = {name, math.max(tonumber(v), 0)} end
  end
  if sort == 1 then table.sort(out, function(a, b) return a[2] > b[2] end) end
  return out
end)(BarsCtrl.BcList.Value, BarsCtrl.BcSort)]], MAX)

local ctrl = add("Background", "BarsCtrl", -5, -3)
local uc = {
  BcList   = L.text("Rows (Name 42)", "Apples 42\nBananas 28\nOranges 35\nGrapes 15", nil, 8),
  BcSort   = L.check("Sort Largest First", 0),
  BcHigh   = L.check("Highlight Largest", 1),
  BcGrow   = L.num("Grow Time", 0.3, 0.02, 1),
  BcDone   = L.num("All Done At", 0.7, 0.05, 1),
  BcBounce = L.num("Bounce", 0.6, 0, 2),
  BcDecimals = L.num("Decimals", 0, 0, 3, nil, true),
  BcPrefix = L.text("Prefix", ""),
  BcSuffix = L.text("Suffix", ""),
  BcW      = L.num("Chart Width", 0.7, 0.2, 1),
  BcH      = L.num("Chart Height", 0.5, 0.1, 1),
  BcLabelW = L.num("Name Column Width", 0.16, 0, 0.5),
  BcValueW = L.num("Number Column Width", 0.1, 0, 0.4),
  BcThick  = L.num("Bar Thickness", 0.6, 0.1, 1),
  BcGap    = L.num("Text Gap", 0.012, 0, 0.05),
  BcTextSize = L.num("Text Size", 0.045, 0.01, 0.15),
  BcPos = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Position",
           INPID_PreviewControl = "CrosshairControl", ICS_ControlPage = "Controls"},
  P   = L.num("P", 0, 0, 1, "Driver"),
  N   = L.num("N", 0, 0, MAX, "Driver"),
  Top = L.num("Top", -1, -1, MAX, "Driver"),
  X0  = L.num("X0", 0, 0, 1, "Driver"),
  Len = L.num("Len", 0, 0, 1, "Driver"),
  RowH = L.num("RowH", 0, 0, 1, "Driver"),
}
-- B<k>: X = how long bar k is right now as a share of the full length, Y = how far it has grown (0..1, may overshoot)
for k = 1, MAX do
  uc["B" .. k] = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "B" .. k, ICS_ControlPage = "Driver"}
end
ctrl.UserControls = uc
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("BcPos", {0.5, 0.5})
L.color(ctrl, 0, 0, 0, 0)
expr(ctrl, "P", L.P)
expr(ctrl, "N", string.format("#(%s)", PARSE))
-- Top: which row (1..) holds the largest value, for the highlight colour
expr(ctrl, "Top", string.format([[(function(c)
  local best, at = -1, -1
  for i = 1, #c do if c[i][2] > best then best, at = c[i][2], i end end
  return at
end)(%s)]], PARSE))
expr(ctrl, "X0", "BcPos.X - BcW/2 + BcLabelW")
expr(ctrl, "Len", "max(BcW - BcLabelW - BcValueW, 0.01)")
expr(ctrl, "RowH", "BcH / max(N, 1)")
for k = 1, MAX do
  -- bars start one after another so that the last one finishes at All Done At
  expr(ctrl, "B" .. k, string.format([[(function(c, p, grow, done, bounce)
  if not c[%d] then return Point(0, 0) end
  local big = 0
  for i = 1, #c do big = math.max(big, c[i][2]) end
  local gap = math.max(done - grow, 0) / math.max(#c - 1, 1)
  local t = math.min(math.max((p - %d*gap) / grow, 0), 1) - 1
  local s = 1.70158 * bounce
  local g = 1 + (s + 1)*t*t*t + s*t*t
  return Point(big > 0 and c[%d][2]/big*g or 0, g)
end)(%s, P, BcGrow, BcDone, BcBounce)]], k, k - 1, k, PARSE))
end

local barColor = add("Background", "BarColor", -4, -1)
L.color(barColor, 0.95, 0.95, 0.95)
local topColor = add("Background", "TopColor", -4, 1)
L.color(topColor, 0.93, 0.16, 0.16)
for _, t in ipairs({barColor, topColor}) do t:SetInput("UseFrameFormatSettings", 1) end

-- All bars are drawn by one Custom tool: it works out which row a pixel is in and how long that row's bar is.
local draw = add("Custom", "BarsDraw", -2, 0)
draw.Image1 = barColor.Output
draw.Image2 = topColor.Output
for k = 1, MAX do expr(draw, "NumberIn" .. k, string.format("BarsCtrl.B%d.X", k)) end
expr(draw, "PointIn1", "Point(BarsCtrl.X0, BarsCtrl.Len)")
expr(draw, "PointIn2", "Point(BarsCtrl.BcPos.Y + BarsCtrl.BcH/2, BarsCtrl.RowH)")
expr(draw, "PointIn3", "Point(BarsCtrl.BcThick, BarsCtrl.N)")
expr(draw, "PointIn4", "Point(iif(BarsCtrl.BcHigh == 1, BarsCtrl.Top, -1), 0)")
-- i1 row number counted from the top (0, 1, ..), i2 that row's bar length, i3 inside the bar or not
draw:SetInput("Intermediate1", "floor((p2x - y)/p2y)")
local pick = "0"
for k = MAX, 1, -1 do pick = string.format("if(i1 < %g, n%d, %s)", k - 0.5, k, pick) end
draw:SetInput("Intermediate2", pick)
draw:SetInput("Intermediate3",
  "if(i1 < 0, 0, if(i1 > p3y - 0.5, 0, if(abs(p2x - (i1 + 0.5)*p2y - y) > p2y*p3x/2, 0, if(x < p1x, 0, if(x > p1x + i2*p1y, 0, 1)))))")
draw:SetInput("Intermediate4", "if(abs(i1 + 1 - p4x) < 0.5, 1, 0)")
for _, c in ipairs({"Red", "Green", "Blue"}) do
  local l = string.lower(string.sub(c, 1, 1))
  draw:SetInput(c .. "Expression", string.format("i3 * if(i4 > 0, %s2, %s1)", l, l))
end
draw:SetInput("AlphaExpression", "i3")

-- one name and one number per row; rows that are not in the list are switched off in their Merge
local FORMAT = [[(function(v, d)
  local s = string.format("%." .. d .. "f", v)
  local whole, rest = s:match("^(-?%d+)(.*)$")
  whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1")
  return whole .. rest
end)]]
local last = draw
local names, numbers = {}, {}
for k = 1, MAX do
  local rowY = string.format("BarsCtrl.BcPos.Y + BarsCtrl.BcH/2 - %g*BarsCtrl.RowH", k - 0.5)
  local name = add("TextPlus", "RowName" .. k, k, -2)
  local number = add("TextPlus", "RowValue" .. k, k, 2)
  names[k], numbers[k] = name, number
  for _, t in ipairs({name, number}) do
    t:SetInput("UseFrameFormatSettings", 1)
    expr(t, "Size", "BarsCtrl.BcTextSize")
    if k == 1 then
      t:SetInput("Font", "Microsoft JhengHei") -- Open Sans has no Chinese glyphs and Text+ does not fall back
      t:SetInput("Style", "Bold")
    else
      local first = (t == name) and "RowName1" or "RowValue1"
      for _, id in ipairs({"Font", "Style", "Red1", "Green1", "Blue1"}) do expr(t, id, first .. "." .. id) end
    end
  end
  -- HorizontalLeftCenterRight: 1 puts the end of the text on Center, -1 puts its start there
  name:SetInput("HorizontalLeftCenterRight", 1)
  number:SetInput("HorizontalLeftCenterRight", -1)
  expr(name, "StyledText", string.format("Text((function(c) return c[%d] and c[%d][1] or \"\" end)(%s))", k, k, PARSE))
  expr(name, "Center", string.format("Point(BarsCtrl.X0 - BarsCtrl.BcGap, %s)", rowY))
  expr(number, "StyledText", string.format(
    "Text((function(c) if not c[%d] then return \"\" end return BarsCtrl.BcPrefix.Value .. %s(c[%d][2]*min(BarsCtrl.B%d.Y, 1), BarsCtrl.BcDecimals) .. BarsCtrl.BcSuffix.Value end)(%s))",
    k, FORMAT, k, k, PARSE))
  expr(number, "Center", string.format("Point(BarsCtrl.X0 + BarsCtrl.B%d.X*BarsCtrl.Len + BarsCtrl.BcGap, %s)", k, rowY))
  for _, t in ipairs({name, number}) do
    local m = add("Merge", (t == name and "PutName" or "PutNumber") .. k, k, t == name and -1 or 1)
    m.Background = last.Output
    m.Foreground = t.Output
    expr(m, "Blend", string.format("iif(BarsCtrl.N >= %d, min(max(BarsCtrl.B%d.Y*4, 0), 1), 0)", k, k))
    last = m
  end
end

mediaOut.Input = last.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "barchart", {
    {"NAME", "BarChart"},
    {"OUT", last.Name, "Output"},
    {"CTL", "BarsCtrl", "BcList", "Rows (Name 42)"},
    {"CTL", "BarsCtrl", "BcSort", "Sort Largest First"},
    {"CTL", "BarsCtrl", "BcHigh", "Highlight Largest"},
    {"CTL", "BarColor", "TopLeftRed", "Bar Color", "2"}, {"CTL", "BarColor", "TopLeftGreen", "", "2"}, {"CTL", "BarColor", "TopLeftBlue", "", "2"},
    {"CTL", "TopColor", "TopLeftRed", "Highlight Color", "3"}, {"CTL", "TopColor", "TopLeftGreen", "", "3"}, {"CTL", "TopColor", "TopLeftBlue", "", "3"},
    {"CTL", "BarsCtrl", "BcGrow", "Grow Time"},
    {"CTL", "BarsCtrl", "BcDone", "All Done At"},
    {"CTL", "BarsCtrl", "BcBounce", "Bounce"},
    {"CTL", "BarsCtrl", "BcDecimals", "Decimals"},
    {"CTL", "BarsCtrl", "BcPrefix", "Prefix"},
    {"CTL", "BarsCtrl", "BcSuffix", "Suffix"},
    {"CTL", "BarsCtrl", "BcPos", "Position"},
    {"CTL", "BarsCtrl", "BcW", "Chart Width"},
    {"CTL", "BarsCtrl", "BcH", "Chart Height"},
    {"CTL", "BarsCtrl", "BcLabelW", "Name Column Width"},
    {"CTL", "BarsCtrl", "BcValueW", "Number Column Width"},
    {"CTL", "BarsCtrl", "BcThick", "Bar Thickness"},
    {"CTL", "BarsCtrl", "BcGap", "Text Gap"},
    {"CTL", "BarsCtrl", "BcTextSize", "Text Size"},
    {"CTL", "RowName1", "Font", "Name Font", "4"}, {"CTL", "RowName1", "Style", "", "4"},
    {"CTL", "RowName1", "Red1", "Name Color", "5"}, {"CTL", "RowName1", "Green1", "", "5"}, {"CTL", "RowName1", "Blue1", "", "5"},
    {"CTL", "RowValue1", "Font", "Number Font", "6"}, {"CTL", "RowValue1", "Style", "", "6"},
    {"CTL", "RowValue1", "Red1", "Number Color", "7"}, {"CTL", "RowValue1", "Green1", "", "7"}, {"CTL", "RowValue1", "Blue1", "", "7"},
  })
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local t = os.getenv("FX_TEXT")
  if t then ctrl:SetInput("BcList", (string.gsub(t, "|", "\n"))) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("BcList", file:read("*a")); file:close() end
  if os.getenv("FX_SUFFIX") then ctrl:SetInput("BcSuffix", os.getenv("FX_SUFFIX")) end
  local a = comp:GetAttrs()
  print("rows", ctrl:GetInput("N", a.COMPN_RenderEnd), "largest", ctrl:GetInput("Top", a.COMPN_RenderEnd))
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local dim = add("BrightnessContrast", "PrevDim", -1, 5)
  dim.Input = s.Output; dim:SetInput("Gain", 0.3)
  local pm = add("Merge", "PrevOver", 0, 5)
  pm.Background = dim.Output; pm.Foreground = last.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "bc", tonumber(os.getenv("FX_STEPS") or "12"))
end
