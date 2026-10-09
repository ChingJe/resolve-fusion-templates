-- paste the packaged macro next to the original graph, render it, then remove it again
local resolve = bmd.scriptapp("Resolve")
local comp = resolve:Fusion():GetCurrentComp()
local S = "D:/davinci/scripts/"
local settings = bmd.readfile(S .. "Comic Intro.setting")
if not settings then print("PARSE_FAILED") return end

local before = {}
for _, t in pairs(comp:GetToolList(false)) do before[t.Name] = true end
comp:SetActiveTool(nil)
comp.CurrentFrame.FlowView:Select()
comp:Lock()
local ok = comp:Paste(settings)
comp:Unlock()
print("paste", tostring(ok))
local macro
for _, t in pairs(comp:GetToolList(false)) do
  if not before[t.Name] then print("new tool:", t.Name, t.ID); if t.ID == "MacroOperator" then macro = t end end
end
if not macro then print("NO_MACRO") return end
local names = {}
for _, inp in pairs(macro:GetInputList()) do
  local a = inp:GetAttrs()
  if a.INPS_Name and not string.find(a.INPS_ID, "^Comments") and not string.find(a.INPS_ID, "Script") then names[#names + 1] = a.INPS_ID .. "=" .. a.INPS_Name end
end
print("macro inputs: " .. table.concat(names, " | "))
macro:SetInput("Input1", os.getenv("COMIC_TEXT") or "SECOND COPY")
if os.getenv("COMIC_PX") then macro:SetInput("Input18", tonumber(os.getenv("COMIC_PX"))); macro:SetInput("Input19", tonumber(os.getenv("COMIC_PY"))) end

comp:Lock()
local small = comp:AddTool("BetterResize", 4, 6)
small.Input = macro:FindMainOutput(1)
small:SetInput("Width", 640); small:SetInput("Height", 360)
local saver = comp:AddTool("Saver", 5, 6)
saver.Input = small.Output
saver:SetInput("Clip", S .. "out/m.png")
comp:Unlock()
comp:SetAttrs({COMPN_RenderStart = 0, COMPN_RenderEnd = 119})
print("render", tostring(comp:Render({Start = 0, End = 119, Tool = saver, Wait = true})))
comp:SetAttrs({COMPN_RenderStart = 0, COMPN_RenderEnd = 119})
comp:Lock(); saver:Delete(); small:Delete(); macro:Delete()
for _, t in pairs(comp:GetToolList(false)) do if not before[t.Name] then print("removing leftover", t.Name); t:Delete() end end
comp:Unlock()
local o = comp:FindTool("MediaOut1"); o.Input = comp:FindTool("FinishGlow").Output
local n = 0
for _, t in pairs(comp:GetToolList(false)) do n = n + 1 end
print("tools left", n)
