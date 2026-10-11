-- Paste one template several times with different settings and stack the copies over the test picture,
-- to see how instances combine. FX_TEMPLATE = the .setting, FX_SPEC = a UTF-8 text file: one block per copy,
-- blocks separated by an empty line, each line "Control Name=value" (a number, "x,y" for a point, or text; | is a new line;
-- "KEYS 0=0,40=3" keyframes a number: frame=value).
-- Lines that start with @ are about how the copy is shown, not controls: @At=x,y and @Scale=s place the copy
-- (for a template that has no position of its own), @Word=TEXT is the word on its stand-in sticker.
-- @Delay=frames shows the copy that many frames late, as if its clip sat further along the timeline.
-- FX_INPUTS=1: an effect, every copy gets its own stand-in clip, stacked over black; FX_BACK=1 puts a dimmed
-- stand-in behind them instead of black. FX_DIM=0.3 darkens the picture behind titles. FX_INPUTS=sticker: every copy gets a stand-in picture with a clear background.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
local settings = bmd.readfile(os.getenv("FX_TEMPLATE"))
local f = io.open(os.getenv("FX_SPEC"), "r"); local spec = f:read("*a"); f:close()
comp:Lock(); local mediaIn, mediaOut = L.clear(comp); comp:Unlock()
local seen, macros, stage = {}, {}, {}
for block in (spec .. "\n\n"):gmatch("(.-)\n\n") do
  if block:match("%S") then
    comp:SetActiveTool(nil); comp.CurrentFrame.FlowView:Select()
    comp:Lock(); comp:Paste(settings); comp:Unlock()
    local macro
    for _, t in pairs(comp:GetToolList(false)) do if t.ID == "MacroOperator" and not seen[t.Name] then macro = t end end
    seen[macro.Name] = true; macros[#macros + 1] = macro
    stage[#macros] = {}
    local ids = {}
    for _, inp in pairs(macro:GetInputList()) do local a = inp:GetAttrs(); if a.INPS_Name then ids[a.INPS_Name] = a.INPS_ID end end
    for line in (block .. "\n"):gmatch("(.-)\n") do
      local k, v = line:match("^(.-)=(.*)$")
      if k and k:sub(1, 1) == "@" then stage[#macros][k:sub(2)] = v
      elseif k and ids[k] then
        local x, y = v:match("^([%d%.%-]+),([%d%.%-]+)$")
        if v:match("^KEYS ") then L.keys(macro, ids[k], v)
        elseif x then macro:SetInput(ids[k], {tonumber(x), tonumber(y)})
        elseif tonumber(v) then macro:SetInput(ids[k], tonumber(v))
        else macro:SetInput(ids[k], (v:gsub("|", "\n"))) end
      elseif k then print("no control", k) end
    end
  end
end
comp:Lock()
local last
local inputs = os.getenv("FX_INPUTS")
if inputs == "sticker" then
  last = L.testsource(comp)
  for i, m in ipairs(macros) do m:FindMainInput(1):ConnectTo(L.sticker(comp, string.char(64 + i), stage[i].Word, i).Output) end
elseif inputs == "1" and os.getenv("FX_BACK") == "1" then
  local back = L.testsource(comp, "Z", 1)
  last = comp:AddTool("BrightnessContrast", -12, -3); last:SetAttrs({TOOLS_Name = "PrevDim"})
  last.Input = back.Output; last:SetInput("Gain", 0.45)
  for i, m in ipairs(macros) do m:FindMainInput(1):ConnectTo(L.testsource(comp, string.char(64 + i), (i - 1) % 2).Output) end
elseif inputs == "1" then
  -- effects: every copy gets its own stand-in clip, and they are stacked over black like clips on tracks
  last = comp:AddTool("Background", -12, -3); last:SetAttrs({TOOLS_Name = "PrevBlack"})
  last:SetInput("UseFrameFormatSettings", 1)
  for i, m in ipairs(macros) do m:FindMainInput(1):ConnectTo(L.testsource(comp, string.char(64 + i), (i - 1) % 2).Output) end
else
  last = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  if os.getenv("FX_DIM") then -- a darker picture behind, for light titles
    local dim = comp:AddTool("BrightnessContrast", -12, -3); dim:SetAttrs({TOOLS_Name = "PrevDim"})
    dim.Input = last.Output; dim:SetInput("Gain", tonumber(os.getenv("FX_DIM")))
    last = dim
  end
end
for i, m in ipairs(macros) do
  local mg = comp:AddTool("Merge", 2 + i, 6); mg:SetAttrs({TOOLS_Name = "PrevStack" .. string.char(64 + i)})
  mg.Background = last.Output; mg.Foreground = m:FindMainOutput(1)
  if stage[i].Delay then
    -- show the copy this many frames late, as if its clip sat further along the timeline
    local late = comp:AddTool("TimeStretcher", 2 + i, 5); late:SetAttrs({TOOLS_Name = "PrevLate" .. string.char(64 + i)})
    late.Input = m:FindMainOutput(1); late:SetInput("InterpolateBetweenFrames", 0)
    late.SourceTime:SetExpression("time - " .. tonumber(stage[i].Delay))
    mg.Foreground = late.Output
  end
  local x, y = (stage[i].At or ""):match("^([%d%.]+),([%d%.]+)$")
  if x then mg:SetInput("Center", {tonumber(x), tonumber(y)}) end
  if stage[i].Scale then mg:SetInput("Size", tonumber(stage[i].Scale)) end
  last = mg
end
comp:Unlock()
mediaOut.Input = last.Output
print("labels", #macros)
L.render(comp, last.Output, os.getenv("FX_PREFIX") or "cp", tonumber(os.getenv("FX_STEPS") or "12"))
