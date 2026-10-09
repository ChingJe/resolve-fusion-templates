local comp = bmd.scriptapp("Resolve"):Fusion():GetCurrentComp()
local S = "D:/davinci/scripts/"
local settings = bmd.readfile(S .. "Comic Intro Video.setting")
if not settings then print("PARSE_FAILED") return end
local before = {}
for _, t in pairs(comp:GetToolList(false)) do before[t.Name] = true end
comp:SetActiveTool(nil); comp.CurrentFrame.FlowView:Select()
comp:Lock(); print("paste", tostring(comp:Paste(settings))); comp:Unlock()
local macro
for _, t in pairs(comp:GetToolList(false)) do if not before[t.Name] and t.ID == "MacroOperator" then macro = t end end
if not macro then print("NO_MACRO") return end
local names = {}
for _, inp in pairs(macro:GetInputList()) do
  local a = inp:GetAttrs()
  if string.find(a.INPS_ID, "Input") and a.INPS_ID ~= "HideInputs" then names[#names + 1] = a.INPS_ID .. "=" .. tostring(a.INPS_Name) end
end
print("macro inputs: " .. table.concat(names, " | "))
macro:FindMainInput(1):ConnectTo(comp:FindTool("MediaIn1").Output)
macro:SetInput("Input1", "MACRO TEST")
comp:Lock()
local small = comp:AddTool("BetterResize", 4, 8); small.Input = macro:FindMainOutput(1)
small:SetInput("Width", 640); small:SetInput("Height", 360)
local saver = comp:AddTool("Saver", 5, 8); saver.Input = small.Output; saver:SetInput("Clip", S .. "out/vm.png")
comp:Unlock()
local a = comp:GetAttrs(); local rs, re = a.COMPN_RenderStart, a.COMPN_RenderEnd
print("render", tostring(comp:Render({Start = rs, End = re, StepRender = true, Steps = 15, Tool = saver, Wait = true})))
comp:SetAttrs({COMPN_RenderStart = rs, COMPN_RenderEnd = re})
comp:Lock(); saver:Delete(); small:Delete(); macro:Delete()
for _, t in pairs(comp:GetToolList(false)) do if not before[t.Name] then print("removing leftover", t.Name); t:Delete() end end
comp:Unlock()
comp:FindTool("MediaOut1").Input = comp:FindTool("FinishGlow").Output
local n = 0; for _ in pairs(comp:GetToolList(false)) do n = n + 1 end
print("tools left", n, "of", (function() local c = 0 for _ in pairs(before) do c = c + 1 end return c end)())
