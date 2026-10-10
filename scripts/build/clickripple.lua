-- Click Ripple: rings spread out from a point, the way screen recordings show a mouse click or a tap.
-- With the list empty it clicks once when the title starts. With times in the list it clicks at each of them,
-- at wherever Position is at that moment, so one long title can mark every click of a recording.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Click Ripple")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "RipCtrl", {
  {"RipPos",    L.point("Position", nil, true), {0.5, 0.5}},
  {"RipList",   L.text("Click Times (one per line, empty = once at the start)", "", nil, 4)},
  {"RipClicks", L.num("Clicks Each Time", 1, 1, 3, nil, true)},
  {"RipGap",    L.num("Seconds Between Those Clicks", 0.18, 0.05, 1)},
  {"RipSize",   L.num("Size", 0.14, 0.02, 1)},
  {"RipLife",   L.num("Ripple Lasts (seconds)", 0.5, 0.1, 3)},
  {"RipRings",  L.num("Rings", 2, 0, 3, nil, true)},
  {"RipThick",  L.num("Ring Thickness", 0.008, 0.001, 0.05)},
  {"RipFill",   L.num("Filled Disc", 0.25, 0, 1)},
  {"RipDot",    L.num("Centre Dot", 0.025, 0, 0.2)},
  {"RipOpacity", L.num("Opacity", 1, 0, 1)},
  {"RipEdge",   L.num("Outline", 0, 0, 0.01)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"Hit",  L.point("Hit", "Driver")},
})
local FPS = "iif(FpsOverride > 0, FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24)"
-- Hit: seconds since the latest click and since the one before it (-1 = none), so two ripples can overlap
expr(ctrl, "Hit", [[(function(txt, fps, len, ts, n, gap, life)
  local a, b, any = -1, -1, false
  local function hit(sec)
    for k = 0, n - 1 do
      local dt = ts - (sec + k*gap)
      if dt >= 0 and dt < life then
        if a < 0 or dt < a then a, b = dt, a elseif b < 0 or dt < b then b = dt end
      end
    end
  end
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local stamp = line:match("^%s*(%S+)")
    if stamp then
      local sec
      local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
      if pct then sec = tonumber(pct) / 100 * len / fps
      elseif fr then sec = tonumber(fr) / fps
      elseif stamp:match("^[%d:%.]+$") then
        sec = 0
        for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
      end
      if sec then any = true; hit(sec) end
    end
  end
  if not any then hit(0) end
  return Point(a, b)
end)(RipList.Value, ]] .. FPS .. [[, max(comp.RenderEnd - comp.RenderStart, 1), (time - comp.RenderStart)/]] .. FPS .. [[, RipClicks, RipGap, RipLife)]])
-- One node per ripple (an expression may not get long, see L.cx), so two ripples can be on screen at once.
-- Each ripple stays where Position was when it was clicked, even if Position has moved on since. That is asked
-- from the drawing node and not from RipCtrl itself, and never for the frame being worked on.
local function at(since)
  return "(function(s) if s <= 0 then return Point(RipCtrl.RipPos.X, RipCtrl.RipPos.Y) end "
    .. "local v = RipCtrl:GetValue('RipPos', math.floor(time - s*iif(RipCtrl.FpsOverride > 0, RipCtrl.FpsOverride, comp:GetPrefs('Comp.FrameFormat.Rate') or 24) + 0.5)) "
    .. "return Point(v.X or v[1], v.Y or v[2]) end)(RipCtrl.Hit." .. since .. ")"
end
local function ripple(name, since, row)
  local r = add("Custom", name, -2, row)
  r.Image1 = ctrl.Output
  expr(r, "PointIn1", at(since))
  expr(r, "NumberIn1", "RipCtrl.RipSize/2")
  expr(r, "NumberIn2", "RipCtrl.RipThick")
  expr(r, "NumberIn3", "RipCtrl.RipRings")
  expr(r, "NumberIn4", "RipCtrl.RipFill")
  expr(r, "NumberIn5", "RipCtrl.RipDot/2")
  expr(r, "NumberIn6", "RipCtrl.Hit." .. since .. "/RipCtrl.RipLife") -- how far through its life, negative = not there
  L.cx(r, "Intermediate1", "sqrt(((x - p1x)*w/h)^2 + (y - p1y)^2)")
  -- i2..i4: the rings, each one starting a little after the one before
  for j = 0, 2 do
    local q = string.format("min(max(n6*(1 + 0.25*(n3 - 1)) - %g, 0), 1)", 0.25*j)
    L.cx(r, "Intermediate" .. (j + 2), string.format("if(n3 > %d && %s > 0, min(max((n2*(1 - 0.6*%s)/2 - abs(i1 - n1*(1 - (1 - %s)^3)))*h + 0.5, 0), 1)*(1 - %s)^1.2, 0)", j, q, q, q, q))
  end
  L.cx(r, "Intermediate5", "n4*(1 - n6)*min(max((n1*(1 - (1 - n6)^3) - i1)*h + 0.5, 0), 1)")          -- the disc
  L.cx(r, "Intermediate6", "min(max(1 - n6/0.6, 0), 1)*min(max((n5*min(n6*12, 1) - i1)*h + 0.5, 0), 1)") -- the dot
  L.cx(r, "Intermediate7", "if(n6 < 0, 0, max(max(max(i2, i3), max(i4, i5)), i6))")
  for _, c in ipairs({"Red", "Green", "Blue", "Alpha"}) do L.cx(r, c .. "Expression", "i7") end
  return r
end
local ra, rb = ripple("RipDrawA", "X", 0), ripple("RipDrawB", "Y", 1)
local rip = add("Merge", "RipBoth", -1, 0)
rip.Background = ra.Output; rip.Foreground = rb.Output

local c1 = add("Background", "ColRip", -3, -5)
local c2 = add("Background", "ColRipEdge", -2, -5)
for _, hd in ipairs({c1, c2}) do hd:SetInput("UseFrameFormatSettings", 0); hd:SetInput("Width", 16); hd:SetInput("Height", 16) end
L.color(c1, 1, 0.85, 0.1, 1); L.color(c2, 0.1, 0.08, 0.02, 1)
local cols = {}
for i, ch in ipairs({"Red", "Green", "Blue"}) do
  cols[i] = "ColRip.TopLeft" .. ch; cols[i + 3] = "ColRipEdge.TopLeft" .. ch; cols[i + 6] = "0"
end
local painted = L.inked(comp, "RipPaint", 0, 0, rip.Output, "RipCtrl.RipEdge", "0", cols)
local out = add("Merge", "RipFinal", 3, 0)
out.Background = ctrl.Output; out.Foreground = painted.Output
expr(out, "Blend", "RipCtrl.RipOpacity")

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
for i, hd in ipairs({{"ColRip", "Colour"}, {"ColRipEdge", "Outline Colour"}}) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftRed", hd[2], g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", hd[1], "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "clickripple", name = "ClickRipple", out = out, ctrl = ctrl, spec = spec, prefix = "cr",
  before = function()
    -- test: FX_TEXTFILE holds the list, and Position wanders so each click lands somewhere else
    local tf = os.getenv("FX_TEXTFILE")
    if tf then
      local f = io.open(tf, "r"); ctrl:SetInput("RipList", f:read("*a")); f:close()
      -- real keyframes, so that asking for Position at an earlier frame is tested the way it will be used
      ctrl:AddModifier("RipPos", "PolyPath")
      local a = comp:GetAttrs()
      ctrl.RipPos[a.COMPN_RenderStart] = {0.2, 0.3, 0}
      ctrl.RipPos[a.COMPN_RenderEnd] = {0.8, 0.7, 0}
    end
  end})
