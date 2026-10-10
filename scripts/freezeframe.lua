-- Freeze Frame: at each listed moment the picture stops, flashes, pushes in and changes colour, the way a film
-- stops to introduce a character. Put a Text Label on the track above for the name.
-- One freeze per line: "0:02 1.5" is a freeze two seconds in that lasts a second and a half.
-- FX_EXPORT=1 dumps the macro source. FX_TEXT="0:01 1|0:03 0.5" overrides the list.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Freeze Frame")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local ctrl, spec = L.panel(comp, "FrzCtrl", {
  {"FrzList",  L.text("Freezes (0:00 seconds)", "0:01.5 1.5", nil, 5)},
  {"FrzAfter", L.combo("After A Freeze", {"Jump Ahead (stays with the sound)", "Carry On From The Frozen Frame (picture runs late)"}, 0)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"FrzLook",  L.combo("Colour", {"Unchanged", "Black And White", "Tinted", "High Contrast"}, 1)},
  {"FrzZoom",  L.num("Push In", 0.15, 0, 1)},
  {"FrzCenter", L.point("Push In Towards", nil, true), {0.5, 0.5}},
  {"FrzFlash", L.num("Flash", 0.6, 0, 3)},
  {"FrzEdge",  L.num("Dark Corners", 0.4, 0, 1)},
  {"FrzIn",    L.num("Settle Time (seconds)", 0.25, 0.02, 2)},
  {"State", L.point("State", "Driver")},
  {"Src",   L.num("Src", 0, -1e6, 1e6, "Driver")},
})
local srcs, ins = L.feeds(comp, ctrl, 1)

-- One pass over the list gives three things: the source frame to show, how long the current freeze has been
-- on (seconds, -1 when none), and how much of it is left.
local BODY = [[(function(txt, fps, len, now, t0, after, pick)
  local list = {}
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local stamp, d = line:match("^%s*(%S+)%s*([%d%.]*)")
    if stamp then
      local sec
      local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
      if pct then sec = tonumber(pct) / 100 * len / fps
      elseif fr then sec = tonumber(fr) / fps
      elseif stamp:match("^[%d:%.]+$") then
        sec = 0
        for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
      end
      if sec then list[#list + 1] = {sec, tonumber(d) or 1} end
    end
  end
  table.sort(list, function(a, b) return a[1] < b[1] end)
  local ts = (now - t0) / fps
  local late, since, left, src = 0, -1, 0, ts
  for _, f in ipairs(list) do
    -- in "carry on" mode every earlier freeze pushes the later ones back
    local start = f[1] + (after == 1 and late or 0)
    if ts >= start and ts < start + f[2] then since, left, src = ts - start, start + f[2] - ts, f[1] break end
    if ts >= start + f[2] then late = late + f[2] end
  end
  if since < 0 then src = (after == 1) and ts - late or ts end
  if pick == 1 then return t0 + math.floor(src * fps + 0.5) end
  return Point(since, left)
end)(FrzList.Value, iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24),
  max(comp.RenderEnd - comp.RenderStart, 1), time, comp.RenderStart, FrzAfter, PICK)]]
expr(ctrl, "Src", (BODY:gsub("PICK", "1")))
expr(ctrl, "State", (BODY:gsub("PICK", "2")))

local hold = add("TimeStretcher", "FrzHold", -3, 1)
hold.Input = srcs[1].Output
hold:SetInput("InterpolateBetweenFrames", 0)
expr(hold, "SourceTime", "FrzCtrl.Src")

local tint = add("Background", "ColFrzTint", -3, -5)
tint:SetInput("UseFrameFormatSettings", 0); tint:SetInput("Width", 16); tint:SetInput("Height", 16)
L.color(tint, 1, 0.82, 0.25, 1)

local look = add("Custom", "FrzFinal", 1, 1)
look.Image1 = hold.Output; look.Image2 = tint.Output
-- n1: 0 outside a freeze, rises to 1 over the settle time and drops back just before the freeze ends
expr(look, "NumberIn1", "iif(FrzCtrl.State.X < 0, 0, " .. L.SMOOTH .. "(min(FrzCtrl.State.X/FrzCtrl.FrzIn, FrzCtrl.State.Y/min(FrzCtrl.FrzIn, 0.12), 1)))")
expr(look, "NumberIn2", "FrzCtrl.FrzLook")
expr(look, "NumberIn3", "FrzCtrl.FrzZoom")
expr(look, "NumberIn4", "iif(FrzCtrl.State.X < 0, 0, FrzCtrl.FrzFlash * max(1 - FrzCtrl.State.X/0.25, 0)^2)")
expr(look, "NumberIn5", "FrzCtrl.FrzEdge")
expr(look, "PointIn1", "FrzCtrl.FrzCenter")
look:SetInput("Intermediate1", "p1x + (x - p1x)/(1 + n3*n1)")
look:SetInput("Intermediate2", "p1y + (y - p1y)/(1 + n3*n1)")
look:SetInput("Intermediate3", "0.299*getr1b(i1, i2) + 0.587*getg1b(i1, i2) + 0.114*getb1b(i1, i2)")
-- i4 the grey value pushed towards black and white, for High Contrast
look:SetInput("Intermediate4", "min(max((i3 - 0.45)*6 + 0.5, 0), 1)")
look:SetInput("Intermediate5", "1 - n5*n1*min(((x - 0.5)^2 + (y - 0.5)^2)*2.2, 1)")
for _, c in ipairs({"r", "g", "b"}) do
  local pic = string.format("get%s1b(i1, i2)", c)
  local styled = string.format("if(n2 == 0, %s, if(n2 == 1, i3, if(n2 == 2, i3*get%s2b(0.5, 0.5)*1.2, i4*(0.35 + 0.65*get%s2b(0.5, 0.5)) + (1 - i4)*0.06)))", pic, c, c)
  look:SetInput(({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression",
    string.format("if(n1 <= 0 && n4 <= 0, %s1, (%s + (%s - %s)*n1)*i5 + n4)", c, pic, styled, pic))
end
look:SetInput("AlphaExpression", "a1")

mediaOut.Input = look.Output
comp:EndUndo(true)
comp:Unlock()
spec[#spec + 1] = {"CTL", "ColFrzTint", "TopLeftRed", "Tint Colour", "3"}
spec[#spec + 1] = {"CTL", "ColFrzTint", "TopLeftGreen", "", "3"}
spec[#spec + 1] = {"CTL", "ColFrzTint", "TopLeftBlue", "", "3"}
L.ship(comp, {slug = "freezeframe", name = "FreezeFrame", out = look, ctrl = ctrl, srcs = srcs, ins = ins, spec = spec, prefix = "ff",
  before = function()
    local t = os.getenv("FX_TEXT")
    if t then ctrl:SetInput("FrzList", (string.gsub(t, "|", "\n"))) end
  end})
