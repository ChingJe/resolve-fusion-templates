-- Paste a finished template into an otherwise empty lab comp, feed it the procedural stand-in, render, clean up.
-- FX_TEMPLATE = path of the .setting, FX_PREFIX = frame name prefix, FX_INPUTS = number of image inputs (0..2)
local L = dofile("D:/davinci/scripts/lib.lua")
local comp = L.comp()
if not comp then return end
local settings = bmd.readfile(os.getenv("FX_TEMPLATE"))
if not settings then print("PARSE_FAILED") return end
local nin = tonumber(os.getenv("FX_INPUTS") or "1")

comp:Lock()
local _, mediaOut = L.clear(comp)
comp:Unlock()
comp:SetActiveTool(nil); comp.CurrentFrame.FlowView:Select()
comp:Lock(); print("paste", tostring(comp:Paste(settings))); comp:Unlock()
local macro, extra = nil, 0
for _, t in pairs(comp:GetToolList(false)) do
  if t.ID == "MacroOperator" or t.ID == "GroupOperator" then macro = t
  elseif not t.ParentTool and t.ID ~= "MediaIn" and t.ID ~= "MediaOut" and t.ID ~= "AudioDisplay" then extra = extra + 1; print("unexpected tool", t.Name, t.ID) end
end
if not macro then print("NO_MACRO") return end
local names = {}
for _, inp in pairs(macro:GetInputList()) do
  local a = inp:GetAttrs()
  if string.find(a.INPS_ID, "^Input%d") then names[#names + 1] = tostring(a.INPS_Name) end
end
print("macro", macro.Name, "controls: " .. table.concat(names, " | "))
comp:Lock()
for n = 1, nin do
  local s = L.testsource(comp, n == 1 and "A" or "B", n - 1)
  macro:FindMainInput(n):ConnectTo(s.Output)
end
comp:Unlock()
local out = macro:FindMainOutput(1)
mediaOut.Input = out
L.render(comp, out, os.getenv("FX_PREFIX") or "chk", tonumber(os.getenv("FX_STEPS") or "24"))
