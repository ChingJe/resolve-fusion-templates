-- Punch Zoom: at each listed moment the picture punches in and springs back, optionally with the colour
-- channels pulled apart, a zoom blur, a shake, a twist and a flash. Hits can also come from a tempo.
-- Hits come from one text box, one per line: "0:01.5" or "0:01.5 1.4" (the second number scales that hit).
-- FX_SRC=media uses the clip. FX_EXPORT=1 dumps the macro source. FX_TEXT="0:01|0:02 1.5" overrides the list.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Punch Zoom")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl = add("Background", "PunchCtrl", -5, -3)
ctrl.UserControls = {
  PzList    = L.text("Hits (0:00 or 0:00 strength)", "0:00.5\n0:01.5\n0:02.5\n0:03.5 1.5", nil, 8),
  PzBpm     = L.num("Tempo (BPM, 0 = off)", 0, 0, 200),
  PzEvery   = L.num("Every N Beats", 1, 1, 8, nil, true),
  PzBeatOff = L.num("First Beat At (seconds)", 0, 0, 5),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  PzAmount  = L.num("Zoom", 0.15, 0, 1),
  PzAttack  = L.num("Punch In (seconds)", 0.05, 0.01, 0.5),
  PzRelease = L.num("Spring Back (seconds)", 0.35, 0.02, 2),
  PzHold    = L.check("Stay Zoomed Until Next Hit", 0),
  PzSplit   = L.num("RGB Split", 0.015, 0, 0.08),
  PzBlur    = L.num("Zoom Blur", 0.02, 0, 0.3),
  PzShake   = L.num("Shake", 0, 0, 0.05),
  PzTwist   = L.num("Twist", 0, -15, 15),
  PzFlash   = L.num("Flash", 0, 0, 2),
  PzCenter = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Zoom Center",
              INPID_PreviewControl = "CrosshairControl", ICS_ControlPage = "Controls"},
  Hit   = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Hit", ICS_ControlPage = "Driver"},
  Shift = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Shift", ICS_ControlPage = "Driver"},
}
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("PzCenter", {0.5, 0.5})

-- Hit.X: the kick, a short pulse at every hit (drives split, blur, shake, twist, flash).
-- Hit.Y: the zoom, the same pulse, or with Stay Zoomed a level that flips at every hit.
-- A line is "<when> [strength]". <when> is 1:25 / 0:07.5 / 42 (seconds from the start of the clip), 120f or 25%.
expr(ctrl, "Hit", [[(function(txt, fps, len, ts, bpm, every, off, atk, rel, hold)
  local hits = {}
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local stamp, s = line:match("^%s*(%S+)%s*([%d%.]*)")
    if stamp then
      local sec
      local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
      if pct then sec = tonumber(pct) / 100 * len / fps
      elseif fr then sec = tonumber(fr) / fps
      elseif stamp:match("^[%d:%.]+$") then
        sec = 0
        for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
      end
      if sec then hits[#hits + 1] = {sec, tonumber(s) or 1} end
    end
  end
  local beats = 0
  if bpm > 0 then
    local iv = 60 / bpm * every
    beats = math.floor((ts - off) / iv) + 1
    for k = math.max(beats - 3, 0), beats - 1 do hits[#hits + 1] = {off + k * iv, 1} end
    beats = math.max(beats - 3, 0)
  end
  local kick, passed, last, strength = 0, beats, -1, 1
  for i = 1, #hits do
    local dt, s = ts - hits[i][1], hits[i][2]
    if dt >= 0 then
      passed = passed + 1
      if hits[i][1] > last then last, strength = hits[i][1], s end
      local v = 0
      if dt < atk then v = 1 - (1 - dt/atk)^2
      elseif dt < atk + rel then v = (1 - (dt - atk)/rel)^3 end
      kick = math.max(kick, v * s)
    end
  end
  if hold == 0 then return Point(kick, kick) end
  if passed == 0 then return Point(0, 0) end
  local u = math.min((ts - last) / (atk * 2), 1)
  u = u*u*(3 - 2*u)
  return Point(kick, passed % 2 == 1 and u * strength or 1 - u)
end)(PzList.Value, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24),
  max(comp.RenderEnd - comp.RenderStart, 1),
  (time - comp.RenderStart) / iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24),
  PzBpm, PzEvery, PzBeatOff, PzAttack, PzRelease, PzHold)]])
-- a different random nudge on every frame, as strong as the kick
expr(ctrl, "Shift", [[(function(t, a)
  local function r(s) local v = math.sin(t*12.9898 + s)*43758.5453 return (v - math.floor(v))*2 - 1 end
  return Point(a*r(1.3), a*r(7.7))
end)(time, PzShake * Hit.X)]])

local src = add("BrightnessContrast", "Src", -5, 0)
local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
src.Input = s.Output

-- Every pixel looks up a spot nearer the centre. Red is zoomed a little more than green and green more
-- than blue, which pulls the channels apart towards the edges. The extra zoom also hides the shake.
local cam = add("Custom", "PunchCam", -2, 0)
cam.Image1 = src.Output
expr(cam, "NumberIn1", "1 + PunchCtrl.PzAmount*PunchCtrl.Hit.Y + 2*PunchCtrl.PzShake*PunchCtrl.Hit.X")
expr(cam, "NumberIn2", "PunchCtrl.PzSplit * PunchCtrl.Hit.X")
expr(cam, "NumberIn3", "PunchCtrl.PzTwist * PunchCtrl.Hit.X")
expr(cam, "NumberIn4", "1 + PunchCtrl.PzFlash * PunchCtrl.Hit.X")
expr(cam, "PointIn1", "PunchCtrl.PzCenter")
expr(cam, "PointIn2", "PunchCtrl.Shift")
cam:SetInput("Intermediate1", "(x - p1x)*cos(n3) - (y - p1y)*(h/w)*sin(n3)")
cam:SetInput("Intermediate2", "(x - p1x)*(w/h)*sin(n3) + (y - p1y)*cos(n3)")
cam:SetInput("Intermediate3", "p1x + p2x")
cam:SetInput("Intermediate4", "p1y + p2y")
local function chan(c, k)
  local z = string.format("(n1*(1 + %d*n2))", k)
  return string.format("get%s1b(i3 + i1/%s, i4 + i2/%s)*n4", c, z, z)
end
cam:SetInput("RedExpression", chan("r", 2))
cam:SetInput("GreenExpression", chan("g", 1))
cam:SetInput("BlueExpression", chan("b", 0))
cam:SetInput("AlphaExpression", "a1")

local blur = add("DirectionalBlur", "PunchBlur", 0, 0)
blur.Input = cam.Output
blur:SetInput("Type", "Zoom")
expr(blur, "Center", "PunchCtrl.PzCenter")
expr(blur, "Length", "PunchCtrl.PzBlur * PunchCtrl.Hit.X")

mediaOut.Input = blur.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  src.Input = nil
  L.export(comp, "punchzoom", {
    {"NAME", "PunchZoom"},
    {"MAIN", "Src", "Input"},
    {"OUT", "PunchBlur", "Output"},
    {"CTL", "PunchCtrl", "PzList", "Hits (0:00 or 0:00 strength)"},
    {"CTL", "PunchCtrl", "PzBpm", "Tempo (BPM, 0 = off)"},
    {"CTL", "PunchCtrl", "PzEvery", "Every N Beats"},
    {"CTL", "PunchCtrl", "PzBeatOff", "First Beat At (seconds)"},
    {"CTL", "PunchCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "PunchCtrl", "PzAmount", "Zoom"},
    {"CTL", "PunchCtrl", "PzCenter", "Zoom Center"},
    {"CTL", "PunchCtrl", "PzAttack", "Punch In (seconds)"},
    {"CTL", "PunchCtrl", "PzRelease", "Spring Back (seconds)"},
    {"CTL", "PunchCtrl", "PzHold", "Stay Zoomed Until Next Hit"},
    {"CTL", "PunchCtrl", "PzSplit", "RGB Split"},
    {"CTL", "PunchCtrl", "PzBlur", "Zoom Blur"},
    {"CTL", "PunchCtrl", "PzShake", "Shake"},
    {"CTL", "PunchCtrl", "PzTwist", "Twist"},
    {"CTL", "PunchCtrl", "PzFlash", "Flash"},
  })
  src.Input = s.Output
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  local t = os.getenv("FX_TEXT")
  if t then ctrl:SetInput("PzList", (string.gsub(t, "|", "\n"))) end
  local a = comp:GetAttrs()
  local v = {}
  for f = a.COMPN_RenderStart, a.COMPN_RenderEnd, 4 do
    local p = ctrl:GetInput("Hit", f)
    v[#v + 1] = string.format("%d:%.2f/%.2f", f, p[1] or p.X or -1, p[2] or p.Y or -1)
  end
  print("fps", comp:GetPrefs("Comp.FrameFormat.Rate"), table.concat(v, " "))
  L.render(comp, blur.Output, os.getenv("FX_PREFIX") or "pz", tonumber(os.getenv("FX_STEPS") or "12"))
end
