-- Kinetic Lines: lines of text that pop in one after another.
-- Lines come from one text box. Either every line starts with a time ("0:02 Text", the notation Chapter Bar uses),
-- or the lines are plain text and Line Number is keyframed 1, 2, 3. A | inside a line is a line break.
-- With Earlier Lines set to stay, the lines build up a list instead: the current one bright, the others dimmed.
-- A title, so it has no image input. FX_SRC=media previews it over the clip. FX_EXPORT=1 dumps the macro source.
-- FX_TEXT="0% One|50% Two" overrides the list for a test render (| stands for a new line there),
-- FX_TEXTFILE reads it from a UTF-8 file, FX_CUE="10=1,60=2" keyframes Line Number.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end

comp:Lock()
comp:StartUndo("Build Kinetic Lines")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr

local cur = L.cur("KinCtrl", "LineList", "KinTimed", "KinCue")
local K = L.look("KinCtrl", {size = 0.11, edge = 0, box = {0, {0.93, 0.16, 0.16}, 0.02, 0.2}})

local ctrl = add("Background", "KinCtrl", -5, -3)
ctrl.UserControls = K.controls({
  LineList    = L.text("Lines (0:00 Text)", "0% FIRST LINE\n25% THEN THIS\n50% TWO LINES|IN ONE\n75% LAST ONE", nil, 8),
  KinTimed    = L.check("Lines Start With A Time (0:02 Text)", 1),
  KinCue      = L.num("Line Number (keyframe 1, 2, 3)", 1, 0, 20),
  FpsOverride = L.num("Frame Rate Override", 0, 0, 120),
  KinKeep   = L.combo("Earlier Lines", {"Are Replaced", "Stay On Screen (A List)"}, 0),
  KinDim    = L.num("Earlier Lines Brightness", 0.45, 0, 1),
  KinAlign  = L.combo("Alignment", {"Centre", "Left", "Right"}, 0),
  KinIn     = L.num("Pop Frames", 8, 1, 40),
  KinOut    = L.num("Fade Out Frames", 3, 0, 40),
  KinBounce = L.num("Bounce", 1, 0, 3),
  KinGrow   = L.num("Grow From", 0.6, 0, 1.5),
  KinRise   = L.num("Rise", 0.04, -0.3, 0.3),
  KinTilt   = L.num("Tilt", 0, -30, 30),
  KinPos = {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = "Position",
            INPID_PreviewControl = "CrosshairControl", ICS_ControlPage = "Controls"},
  T    = L.num("T", 0, 0, 1, "Driver"),
  Back = L.num("Back", 0, 0, 2, "Driver"),
  Fade = L.num("Fade", 0, 0, 1, "Driver"),
  Idx   = L.num("Idx", 0, 0, 100, "Driver"),
  Since = L.num("Since", 0, 0, 100, "Driver"),
  Until = L.num("Until", 0, 0, 100, "Driver"),
})
ctrl = ctrl:Refresh()
ctrl:SetInput("UseFrameFormatSettings", 1)
ctrl:SetInput("KinPos", {0.5, 0.5})
L.color(ctrl, 0, 0, 0, 0)
K.setup(comp)
-- Idx: which line is on screen (0 for none). Since, Until: frames since it appeared and until the next one.
expr(ctrl, "Idx", cur(1))
expr(ctrl, "Since", cur(2))
expr(ctrl, "Until", cur(3))
-- T: 0..1 through the pop of the current line. Back: the same with an overshoot. Fade: opacity.
expr(ctrl, "T", "iif(Idx < 1, 0, min(max((Since + 1)/max(KinIn, 1), 0), 1))")
expr(ctrl, "Back", "(function(t, s) t = t - 1 return 1 + (s + 1)*t*t*t + s*t*t end)(T, 1.70158*KinBounce)")
expr(ctrl, "Fade", "iif(Idx < 1, 0, min(T*3, 1) * iif(KinOut <= 0, 1, min(max(Until/KinOut, 0), 1)))")

local LINE = "Text((function(s) return (s:gsub('%s*|%s*', '\\n')) end)(" .. cur(4) .. "))"
-- The whole list as one block of text, for the list mode. Every row keeps its place: a row that is not shown
-- is replaced by a no-break space (Text+ drops lines that are completely empty). mode 1 = only the current row, 2 = the rows up to `upto`, 3 = every row.
local function LIST(mode, upto)
  return ([[Text((function(txt, timed, idx, mode, upto)
  local out, n = {}, 0
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    n = n + 1
    if line:match("%S") then
      local s = line
      if timed == 1 then s = line:match("^%s*%S+%s*(.-)%s*$") or "" end
      if not (mode == 3 or (mode == 1 and n == idx) or (mode == 2 and n <= upto)) then s = s:gsub("[^|]+", string.char(194, 160)) if s == "" then s = string.char(194, 160) end end
      out[#out + 1] = s
    end
  end
  return (table.concat(out, "\n"):gsub("%s*|%s*", "\n"))
end)(KinCtrl.LineList.Value, KinCtrl.KinTimed, KinCtrl.Idx, MODE, UPTO))]]):gsub("MODE", mode):gsub("UPTO", upto or "0")
end

local text = add("TextPlus", "Line", -3, 0)
text:SetInput("UseFrameFormatSettings", 1)
K.font(text)
-- two expressions cannot share one input, so the mode is chosen inside: a list keeps the text the same size
expr(text, "StyledText", "iif(KinCtrl.KinKeep == 1, " .. LIST("1") .. ", " .. LINE .. ")")
expr(text, "Size", K.v.size .. " * iif(KinCtrl.KinKeep == 1, 1, KinCtrl.KinGrow + (1 - KinCtrl.KinGrow)*KinCtrl.Back)")
expr(text, "HorizontalLeftCenterRight", "({0, -1, 1})[KinCtrl.KinAlign + 1]")
expr(text, "Center", "Point(KinCtrl.KinPos.X, KinCtrl.KinPos.Y - KinCtrl.KinRise*(1 - KinCtrl.Back))")
-- odd lines lean one way, even lines the other
expr(text, "AngleZ", "iif(KinCtrl.KinKeep == 1, 0, KinCtrl.KinTilt * iif(KinCtrl.Idx % 2 == 1, 1, -1))")

-- the list mode: the rows already shown, dimmed. The current row joins them once it has arrived, so that it
-- is still there, dimmed, when the bright copy fades out.
local earlier = add("TextPlus", "Earlier", -3, 4)
earlier:SetInput("UseFrameFormatSettings", 1)
expr(earlier, "StyledText", LIST("2", "KinCtrl.Idx - iif(KinCtrl.T < 1, 1, 0)"))
K.font(earlier)
expr(earlier, "HorizontalLeftCenterRight", "Line.HorizontalLeftCenterRight")
expr(earlier, "Size", K.v.size)
expr(earlier, "Center", "KinCtrl.KinPos")

-- optional box behind the text: a second Text+ that only draws its border fill, so it always fits the words
local box = add("TextPlus", "Box", -3, 2)
box:SetInput("UseFrameFormatSettings", 1)
expr(box, "StyledText", "iif(KinCtrl.KinKeep == 1, " .. LIST("3") .. ", Line.StyledText)")
expr(box, "HorizontalLeftCenterRight", "Line.HorizontalLeftCenterRight")
K.font(box)
expr(box, "Size", "Line.Size")
expr(box, "Center", "iif(KinCtrl.KinKeep == 1, KinCtrl.KinPos, Line.Center)")
expr(box, "AngleZ", "Line.AngleZ")
box:SetInput("ElementShape1", 2)
box:SetInput("Level1", 0)
for i, ch in ipairs({"Red", "Green", "Blue"}) do expr(box, ch .. "1", K.c("box", i)) end
-- the text tool measures this padding in text sizes; the look gives it in frame widths
expr(box, "ExtendHorizontal1", K.v.pad .. "/max(Size, 0.001)")
expr(box, "ExtendVertical1", K.v.pad .. "/max(Size, 0.001)")
expr(box, "Round1", K.v.round)

local boxed = add("Merge", "Boxed", -1, 2)
boxed.Background = ctrl.Output
boxed.Foreground = box.Output
-- in a list the box holds the whole list, and comes in with the first row
expr(boxed, "Blend", K.v.box .. " * iif(KinCtrl.KinKeep == 1, iif(KinCtrl.Idx < 1, 0, iif(KinCtrl.Idx < 2, min(KinCtrl.T*3, 1), 1)), KinCtrl.Fade)")
local earlierInk = K.ink(comp, "EarlierInk", -1, 5, earlier.Output)
local listed = add("Merge", "Listed", 2, 5)
listed.Background = ctrl.Output
listed.Foreground = earlierInk.Output
expr(listed, "Blend", "iif(KinCtrl.KinKeep == 1, KinCtrl.KinDim, 0)")
local lineInk = K.ink(comp, "LineInk", -1, 9, text.Output)
local words = add("Merge", "Words", 3, 5)
words.Background = listed.Output
words.Foreground = lineInk.Output
expr(words, "Blend", "KinCtrl.Fade")
local drop = K.drop(comp, "KinDrop", 4, 5, words.Output)
local out = add("Merge", "KinFinal", 5, 2)
out.Background = boxed.Output
out.Foreground = drop.Output

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()

if os.getenv("FX_EXPORT") == "1" then
  L.export(comp, "kinetic", K.rows({
    {"NAME", "KineticLines"},
    {"OUT", "KinFinal", "Output"},
    {"CTL", "KinCtrl", "LineList", "Lines (0:00 Text)"},
    {"CTL", "KinCtrl", "KinTimed", "Lines Start With A Time (0:02 Text)"},
    {"CTL", "KinCtrl", "KinCue", "Line Number (keyframe 1, 2, 3)"},
    {"CTL", "KinCtrl", "FpsOverride", "Frame Rate Override"},
    {"CTL", "KinCtrl", "KinKeep", "Earlier Lines"},
    {"CTL", "KinCtrl", "KinDim", "Earlier Lines Brightness"},
    {"CTL", "KinCtrl", "KinAlign", "Alignment"},
    {"CTL", "KinCtrl", "KinPos", "Position"},
    {"CTL", "KinCtrl", "KinIn", "Pop Frames"},
    {"CTL", "KinCtrl", "KinOut", "Fade Out Frames"},
    {"CTL", "KinCtrl", "KinBounce", "Bounce"},
    {"CTL", "KinCtrl", "KinGrow", "Grow From"},
    {"CTL", "KinCtrl", "KinRise", "Rise"},
    {"CTL", "KinCtrl", "KinTilt", "Tilt"},
  }))
else
  for name, value in string.gmatch(os.getenv("FX_SET") or "", "(%w+)=([%d%.%-]+)") do ctrl:SetInput(name, tonumber(value)) end
  for name, a, b in string.gmatch(os.getenv("FX_PT") or "", "(%w+)=([%d%.]+):([%d%.]+)") do ctrl:SetInput(name, {tonumber(a), tonumber(b)}) end
  local t = os.getenv("FX_TEXT")
  if t then ctrl:SetInput("LineList", (string.gsub(t, "|", "\n"))) end
  local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
  if file then ctrl:SetInput("LineList", file:read("*a")); file:close() end
  local cue = os.getenv("FX_CUE")
  if cue then
    ctrl:AddModifier("KinCue", "BezierSpline")
    local sp = ctrl.KinCue:GetConnectedOutput():GetTool()
    local mine = {}
    for f, v in string.gmatch(cue, "(%d+)=([%d%.]+)") do ctrl.KinCue[tonumber(f)] = tonumber(v); mine[tonumber(f)] = true end
    for f in pairs(sp:GetKeyFrames()) do if not mine[f] then sp:DeleteKeyFrames(f) end end
  end
  comp:Lock()
  local s = os.getenv("FX_SRC") == "media" and mediaIn or L.testsource(comp)
  local dim = add("BrightnessContrast", "PrevDim", -1, 4)
  dim.Input = s.Output; dim:SetInput("Gain", 0.35)
  local pm = add("Merge", "PrevOver", 0, 4)
  pm.Background = dim.Output; pm.Foreground = out.Output
  comp:Unlock()
  L.render(comp, pm.Output, os.getenv("FX_PREFIX") or "kl", tonumber(os.getenv("FX_STEPS") or "12"))
end
