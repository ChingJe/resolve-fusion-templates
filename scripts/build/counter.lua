-- Number Counter: shows a number that is keyframed, with separators, prefix and suffix. Keyframe it from 0 to 12,500
-- and it counts up; keyframe single steps and it is a tally. It pops when the number on screen stops changing.
-- A title, so it has no image input. FX_EXPORT=1 dumps the macro source. FX_CUE="0=0,160=12500" keyframes Number.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Number Counter")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local K = L.look("CountCtrl", {size = 0.16, edge = 0.006, shadow = 0.5, dist = 0.006, soft = 0.3})

local ctrl, spec = L.panel(comp, "CountCtrl", K.add({
  {"CntNow",      L.num("Number (keyframe this)", 100, 0, 1000)},
  {"CntDecimals", L.num("Decimals", 0, 0, 3, nil, true)},
  {"CntSep",      L.check("Thousands Separator", 1)},
  {"CntPrefix",   L.text("Prefix", "", nil, 1)},
  {"CntSuffix",   L.text("Suffix", "", nil, 1)},
  {"CntPop",      L.num("Pop", 0.15, 0, 0.5)},
  {"CntPopFr",    L.num("Pop Frames", 10, 2, 40)},
  {"CntPos",      L.point("Position", nil, true), {0.5, 0.5}},
  {"Bump",        L.num("Bump", 0, 0, 1, "Driver")},
}))
K.setup(comp)
-- The pop. Since: how many frames ago the number on screen (the keyframed number rounded to Decimals) last changed,
-- found by looking back frame by frame. While the number keeps changing that is 0 and nothing pops; once it holds
-- still the title swells quickly and settles back over Pop Frames. So a count pops when it arrives, a tally at
-- every step.
expr(ctrl, "Bump", [[(function(now, t0, d, pop, fr)
  local function shown(t) return math.floor(CountCtrl:GetValue("CntNow", t) * 10^d + 0.5) end
  local cur, since = shown(now), fr
  for k = 1, fr do
    if now - k < t0 then break end
    if shown(now - k) ~= cur then since = k - 1 break end
  end
  local t = since / fr
  if t >= 1 then return 0 end
  return pop * ((t < 0.2) and t/0.2 or ((1 - t)/0.8)^2)
end)(time, comp.RenderStart, CntDecimals, CntPop, max(floor(CntPopFr), 2))]])

local text = add("TextPlus", "CntText", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
K.font(text)
expr(text, "StyledText", [[Text(CountCtrl.CntPrefix.Value .. (function(v, d, sep)
  local s = string.format("%." .. d .. "f", v)
  local whole, rest = s:match("^(-?%d+)(.*)$")
  if sep == 1 then whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1") end
  return whole .. rest
end)(CountCtrl.CntNow, CountCtrl.CntDecimals, CountCtrl.CntSep) .. CountCtrl.CntSuffix.Value)]])
expr(text, "Size", K.v.size .. " * (1 + CountCtrl.Bump)")
expr(text, "Center", "CountCtrl.CntPos")
local ink = K.ink(comp, "CntInk", 0, 0, text.Output)
local drop = K.drop(comp, "CntDrop", 2, 0, ink.Output)
local out = add("Merge", "CntFinal", 4, 0)
out.Background = ctrl.Output; out.Foreground = drop.Output

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
L.ship(comp, {slug = "counter", name = "NumberCounter", out = out, ctrl = ctrl, spec = spec, prefix = "nc",
  before = function()
    for name, value in string.gmatch(os.getenv("FX_TEXT") or "", "(%w+)=([^;]+)") do ctrl:SetInput(name, value) end
    L.keys(ctrl, "CntNow", os.getenv("FX_CUE"))
  end})
