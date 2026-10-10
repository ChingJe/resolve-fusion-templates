-- Open the lab: the clip on the lab timeline whose Fusion comp the build scripts work in, shown on the Fusion page.
-- The project and the timeline name come from scripts/local.lua (see local.example.lua).
-- The lab clip is whatever clip on that timeline already has a Fusion comp. When there is none yet, one is made:
-- from the media pool clip named in local.lua if that is set and can be found (in any bin), otherwise an empty
-- Fusion composition, which needs no media at all.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "lib.lua")
local resolve = L.resolve
local proj = resolve:GetProjectManager():GetCurrentProject()
if not L.PROJECT then print("NOT_SET copy scripts/local.example.lua to scripts/local.lua and fill it in") return end
if not proj or proj:GetName() ~= L.PROJECT then print("WRONG_PROJECT", proj and proj:GetName()) return end
local mp = proj:GetMediaPool()

local tl
for i = 1, proj:GetTimelineCount() do
  local t = proj:GetTimelineByIndex(i)
  if t:GetName() == L.TIMELINE then tl = t end
end
if not tl then
  -- a timeline cannot be made while Resolve is on the Fusion page
  resolve:OpenPage("edit"); bmd.wait(1)
  tl = mp:CreateEmptyTimeline(L.TIMELINE)
end
if not tl then print("NO_TIMELINE") return end
proj:SetCurrentTimeline(tl)

local function labItem()
  for track = 1, tl:GetTrackCount("video") do
    for _, it in ipairs(tl:GetItemListInTrack("video", track) or {}) do
      if it:GetFusionCompCount() > 0 then return it end
    end
  end
end
local function poolClip(folder, name)
  for _, c in ipairs(folder:GetClipList() or {}) do if c:GetName() == name then return c end end
  for _, sub in ipairs(folder:GetSubFolderList() or {}) do
    local c = poolClip(sub, name)
    if c then return c end
  end
end
local it = labItem()
if not it then
  local clip = L.MEDIA and poolClip(mp:GetRootFolder(), L.MEDIA)
  if clip then
    mp:AppendToTimeline({{mediaPoolItem = clip, startFrame = 480, endFrame = 480 + 239, mediaType = 1}})
    local items = tl:GetItemListInTrack("video", 1) or {}
    it = items[#items]
    if it then it:AddFusionComp() end
    print("made the lab clip from", L.MEDIA)
  else
    it = tl:InsertFusionCompositionIntoTimeline()
    print("made the lab clip as an empty Fusion composition")
  end
end
if not it then print("NO_LAB_CLIP") return end

-- the Fusion page shows the comp of the clip under the playhead, so the playhead goes onto the lab clip
local fps = math.floor(tonumber(tl:GetSetting("timelineFrameRate")) + 0.5)
local f = math.floor((it:GetStart() + it:GetEnd()) / 2)
tl:SetCurrentTimecode(string.format("%02d:%02d:%02d:%02d", math.floor(f / fps / 3600), math.floor(f / fps / 60) % 60, math.floor(f / fps) % 60, f % fps))
resolve:OpenPage("fusion"); bmd.wait(3)
local comp = resolve:Fusion():GetCurrentComp()
if not comp then print("NO_COMP") return end
for i = 1, 20 do if not comp:GetAttrs().COMPB_Locked then break end comp:Unlock() end
local a = comp:GetAttrs()
print("lab clip", it:GetName(), "comp", a.COMPS_Name, "render", a.COMPN_RenderStart, a.COMPN_RenderEnd, "global", a.COMPN_GlobalStart, a.COMPN_GlobalEnd)
local n = 0
for _, t in pairs(comp:GetToolList(false)) do n = n + 1 end
local p = comp:GetPrefs("Comp.FrameFormat")
print("tools", n, "format", p.Width, p.Height, p.Rate)
if a.COMPN_RenderEnd - a.COMPN_RenderStart ~= 235 then
  print("NOTE the test commands and previews.sh assume a comp of 236 frames (0 to 235); this one is different, so the frames they sample will be too")
end
