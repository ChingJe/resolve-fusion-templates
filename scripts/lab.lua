-- Create (or reopen) the lab timeline: one 5 second clip with an empty Fusion comp to build in.
-- The project, the timeline name and the media pool clip to use come from scripts/local.lua (see local.example.lua).
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local resolve = L.resolve
local proj = resolve:GetProjectManager():GetCurrentProject()
local want = L.PROJECT
if not want or not L.MEDIA then print("NOT_SET copy scripts/local.example.lua to scripts/local.lua and fill it in") return end
if not proj or proj:GetName() ~= want then print("WRONG_PROJECT", proj and proj:GetName()) return end
local media = L.MEDIA
local name = L.TIMELINE
local mp = proj:GetMediaPool()
local clip
for _, c in ipairs(mp:GetRootFolder():GetClipList()) do if c:GetName() == media then clip = c end end
if not clip then print("NO_CLIP") return end
local tl
for i = 1, proj:GetTimelineCount() do
  local t = proj:GetTimelineByIndex(i)
  if t:GetName() == name then tl = t end
end
if not tl then tl = mp:CreateEmptyTimeline(name) end
if not tl then print("NO_TIMELINE") return end
proj:SetCurrentTimeline(tl)
local items = tl:GetItemListInTrack("video", 1)
if not items or #items == 0 then
  mp:AppendToTimeline({{mediaPoolItem = clip, startFrame = 480, endFrame = 480 + 239, mediaType = 1}})
  items = tl:GetItemListInTrack("video", 1)
end
local it = items[1]
if it:GetFusionCompCount() == 0 then it:AddFusionComp() end
resolve:OpenPage("fusion"); bmd.wait(3)
local comp = resolve:Fusion():GetCurrentComp()
if not comp then print("NO_COMP") return end
local a = comp:GetAttrs()
print("comp", a.COMPS_Name, "render", a.COMPN_RenderStart, a.COMPN_RenderEnd, "global", a.COMPN_GlobalStart, a.COMPN_GlobalEnd)
for _, t in pairs(comp:GetToolList(false)) do print("tool", t.Name, t.ID) end
local p = comp:GetPrefs("Comp.FrameFormat")
print("format", p.Width, p.Height, p.Rate)
