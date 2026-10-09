local comp = bmd.scriptapp("Resolve"):Fusion():GetCurrentComp()
local S = "D:/davinci/scripts/"
local skip = {MediaIn = true, MediaOut = true, AudioDisplay = true}
local tools = {}
for _, t in pairs(comp:GetToolList(false)) do if not skip[t.ID] then tools[#tools + 1] = t end end
local text = bmd.writestring(comp:CopySettings(tools))
local f = io.open(S .. "vraw.setting", "w"); f:write(text); f:close()
print("tools", #tools, "chars", #text)
