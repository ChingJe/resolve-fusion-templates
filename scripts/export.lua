-- dump the current node graph (minus MediaOut) as settings text
local resolve = bmd.scriptapp("Resolve")
local comp = resolve:Fusion():GetCurrentComp()
local S = "D:/davinci/scripts/"
local tools = {}
for _, t in pairs(comp:GetToolList(false)) do
  if t.ID ~= "MediaOut" then tools[#tools + 1] = t end
end
local settings = comp:CopySettings(tools)
local text = bmd.writestring(settings)
local f = io.open(S .. "raw.setting", "w"); f:write(text); f:close()
print("tools", #tools, "chars", #text)
