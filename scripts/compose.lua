-- Paste one template several times with different settings and stack the copies over the test picture,
-- to see how instances combine. FX_TEMPLATE = the .setting, FX_SPEC = a UTF-8 text file: one block per copy,
-- blocks separated by an empty line, each line "Control Name=value" (a number, "x,y" for a point, or text; | is a new line).
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local comp = L.comp()
if not comp then return end
local settings = bmd.readfile(os.getenv("FX_TEMPLATE"))
local f = io.open(os.getenv("FX_SPEC"), "r"); local spec = f:read("*a"); f:close()
comp:Lock(); local mediaIn, mediaOut = L.clear(comp); comp:Unlock()
local seen, macros = {}, {}
for block in (spec .. "\n\n"):gmatch("(.-)\n\n") do
  if block:match("%S") then
    comp:SetActiveTool(nil); comp.CurrentFrame.FlowView:Select()
    comp:Lock(); comp:Paste(settings); comp:Unlock()
    local macro
    for _, t in pairs(comp:GetToolList(false)) do if t.ID == "MacroOperator" and not seen[t.Name] then macro = t end end
    seen[macro.Name] = true; macros[#macros + 1] = macro
    local ids = {}
    for _, inp in pairs(macro:GetInputList()) do local a = inp:GetAttrs(); if a.INPS_Name then ids[a.INPS_Name] = a.INPS_ID end end
    for line in (block .. "\n"):gmatch("(.-)\n") do
      local k, v = line:match("^(.-)=(.*)$")
      if k and ids[k] then
        local x, y = v:match("^([%d%.%-]+),([%d%.%-]+)$")
        if x then macro:SetInput(ids[k], {tonumber(x), tonumber(y)})
        elseif tonumber(v) then macro:SetInput(ids[k], tonumber(v))
        else macro:SetInput(ids[k], (v:gsub("|", "\n"))) end
      elseif k then print("no control", k) end
    end
  end
end
comp:Lock()
local last
if os.getenv("FX_INPUTS") == "1" then
  -- effects: every copy gets its own stand-in clip, and they are stacked over black like clips on tracks
  last = comp:AddTool("Background", -12, -3); last:SetAttrs({TOOLS_Name = "PrevBlack"})
  last:SetInput("UseFrameFormatSettings", 1)
  for i, m in ipairs(macros) do m:FindMainInput(1):ConnectTo(L.testsource(comp, string.char(64 + i), (i - 1) % 2).Output) end
else
  last = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
end
for i, m in ipairs(macros) do
  local mg = comp:AddTool("Merge", 2 + i, 6); mg:SetAttrs({TOOLS_Name = "PrevStack" .. string.char(64 + i)})
  mg.Background = last.Output; mg.Foreground = m:FindMainOutput(1)
  last = mg
end
comp:Unlock()
mediaOut.Input = last.Output
print("labels", #macros)
L.render(comp, last.Output, os.getenv("FX_PREFIX") or "cp", tonumber(os.getenv("FX_STEPS") or "12"))
