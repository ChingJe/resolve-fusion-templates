-- Chat Bubbles: a conversation. Messages come from one text box, one per row: a time, then < (the other person,
-- on the left) or > (me, on the right), then the words. Each new message pops in at the bottom and pushes the earlier
-- ones up; the oldest fades away. A message can have more lines: write \n where it breaks. A row whose words are ... shows the three dots of someone typing until the
-- next row arrives. A title, so it has no image input. FX_EXPORT=1 dumps the macro source.
-- FX_TEXTFILE reads the list from a UTF-8 file, FX_CUE="10=1,60=2" keyframes the number of messages for a test.
local L = dofile((debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "") .. "../lib.lua")
local comp = L.comp()
if not comp then return end
comp:Lock()
comp:StartUndo("Build Chat Bubbles")
local mediaIn, mediaOut = L.clear(comp)
local add, expr = L.adder(comp), L.expr
local ASP = "(comp:GetPrefs('Comp.FrameFormat.Width')/comp:GetPrefs('Comp.FrameFormat.Height'))"
local FPS = 'iif(FpsOverride > 0, FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24)'
local SLOTS = 7  -- slot 0 is the newest message; one more than can be kept, for the one that is fading away

-- left bubble, left words, right bubble, right words
local PRESETS = {
  {"Blue And Grey",   {0.91,0.91,0.93, 0.05,0.05,0.07, 0.10,0.52,1.00, 1.00,1.00,1.00}},
  {"Green And White", {1.00,1.00,1.00, 0.05,0.05,0.07, 0.55,0.90,0.45, 0.05,0.08,0.05}},
  {"Dark",            {0.18,0.19,0.22, 0.95,0.95,0.96, 0.38,0.32,0.88, 1.00,1.00,1.00}},
}
local names, prows = {"Custom"}, {}
for _, p in ipairs(PRESETS) do names[#names + 1] = p[1]; prows[#prows + 1] = "{" .. table.concat(p[2], ",") .. "}" end
local TABLE = "({" .. table.concat(prows, ",") .. "})"
local HOLD = {"ColChLeft", "ColChLeftText", "ColChRight", "ColChRightText"}
local function col(k, c)
  local ch = ({"Red", "Green", "Blue"})[c]
  return string.format("iif(ChCtrl.ChPreset == 0, %s.TopLeft%s, %s[max(ChCtrl.ChPreset, 1)][%d])", HOLD[k], ch, TABLE, (k - 1)*3 + c)
end

-- ROWS(txt, timed, fps, len) -> list of {f = frame it appears on, side = "<" or ">", text = words}
local ROWS = [[(function(txt, timed, fps, len)
  local rows = {}
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local f, rest = 0, line
    if timed ~= 0 then
      local stamp, more = line:match("^%s*(%S+)%s*(.-)%s*$")
      f, rest = nil, more
      if stamp then
        local pct, fr = stamp:match("^([%d%.]+)%%$"), stamp:match("^(%d+)[fF]$")
        if pct then f = tonumber(pct) / 100 * len
        elseif fr then f = tonumber(fr)
        elseif stamp:match("^[%d:%.]+$") then
          local sec = 0
          for part in stamp:gmatch("[^:]+") do sec = sec and tonumber(part) and sec * 60 + tonumber(part) end
          if sec then f = math.floor(sec * fps + 0.5) end
        end
      end
    end
    if f and rest and rest:match("%S") then
      local side, words = rest:match("^%s*([<>])%s*(.-)%s*$")
      if not side then side, words = "<", rest:match("^%s*(.-)%s*$") end
      words = words:gsub(string.char(92) .. "n", string.char(10))
      rows[#rows + 1] = {f = f, side = side, text = words}
    end
  end
  return rows
end)]]

local list = {
  {"ChList",  L.text("Messages (0:00 < Text)", "0:00 < Are you on your way?\n0:01.2 > ...\n0:02.2 > Almost there\n0:03 > Five more minutes\n0:04 < You said that an hour ago", nil, 10)},
  {"ChTimed", L.check("Rows Start With A Time (0:02 < Text)", 1)},
  {"ChCue",   L.num("Messages So Far (keyframe 1, 2, 3)", 1, 0, 40)},
  {"FpsOverride", L.num("Frame Rate Override", 0, 0, 120)},
  {"ChPos",   L.point("Position (Bottom Of The Newest Message)", nil, true), {0.5, 0.12}},
  {"ChWidth", L.num("Width Of The Conversation", 0.5, 0.1, 1)},
  {"ChSize",  L.num("Size", 0.035, 0.01, 0.12)},
  {"ChMax",   L.num("Messages Kept On Screen", 5, 1, SLOTS - 1, nil, true)},
  {"ChPad",   L.num("Bubble Padding", 1, 0.3, 2.5)},
  {"ChGap",   L.num("Space Between Messages", 0.35, 0, 2)},
  {"ChRound", L.num("Roundness", 1, 0, 1)},
  {"ChIn",    L.num("Pop Frames", 8, 1, 40)},
  {"ChShadow", L.num("Shadow", 0.25, 0, 1)},
  {"ChOut",   L.num("Fade Out Frames At The End", 6, 0, 60)},
  {"ChPreset", L.combo("Colours", names, 1)},
  {"Cur",   L.point("Cur", "Driver")},
  {"KRepl", L.num("KRepl", 0, 0, 1, "Driver")},
  {"KDots", L.num("KDots", 0, 0, 1, "Driver")},
  {"KAnim", L.num("KAnim", 0, 0, 1, "Driver")},
  {"KPop",  L.num("KPop", 0, 0, 2, "Driver")},
  {"KPush", L.num("KPush", 0, 0, 4, "Driver")},
  {"KGap",  L.num("KGap", 0, 0, 1, "Driver")},
  {"KFade", L.num("KFade", 0, 0, 1, "Driver")},
  {"KH",    L.point("KH", "Driver")},
  {"KO",    L.point("KO", "Driver")},
  {"KW",    L.point("KW", "Driver")},
}
for k = 0, SLOTS - 1 do
  list[#list + 1] = {"M" .. k, L.text("M" .. k, "", "Driver", 1)}
  list[#list + 1] = {"Q" .. k, L.point("Q" .. k, "Driver")}
  list[#list + 1] = {"Y" .. k, L.num("Y" .. k, 0, -4, 4, "Driver")}
  list[#list + 1] = {"V" .. k, L.num("V" .. k, 0, 0, 1, "Driver")}
end
local ctrl, spec = L.panel(comp, "ChCtrl", list)

-- Cur.X: how many rows have appeared, Cur.Y: frames since the last one did
expr(ctrl, "Cur", "(function(rows, timed, cue, t0, now)\n" .. [[
  local idx, since = 0, 0
  if timed == 0 then
    idx = math.min(math.floor(cue + 0.0001), #rows)
    for d = 1, 90 do
      if now - d < t0 or math.min(math.floor(ChCtrl:GetValue("ChCue", now - d) + 0.0001), #rows) ~= idx then break end
      since = d
    end
  else
    for i, r in ipairs(rows) do if r.f <= now - t0 + 0.001 then idx, since = i, now - t0 - r.f end end
  end
  return Point(idx, since)
end)(]] .. ROWS .. "(ChList.Value, ChTimed, " .. FPS .. ", max(comp.RenderEnd - comp.RenderStart, 1)), ChTimed, ChCue, comp.RenderStart, time)")
-- what is on screen: every row so far, without the "typing" rows that something has come after
local function slot(k)
  return "Text((function(rows, idx, k)\n" .. [[
  local vis = {}
  for i = 1, idx do
    local r = rows[i]
    if r and not (r.text == "..." and i < idx) then vis[#vis + 1] = r end
  end
  local r = vis[#vis - k]
  return r and (r.side .. r.text) or ""
end)(]] .. ROWS .. "(ChList.Value, ChTimed, 24, 100), Cur.X, " .. k .. "))"
end
-- KRepl: the newest row took the place of the three dots, so nothing has to move up
expr(ctrl, "KRepl", "(function(rows, idx) local r = rows[idx - 1] return (r and r.text == '...') and 1 or 0 end)(" .. ROWS .. "(ChList.Value, ChTimed, 24, 100), Cur.X)")
expr(ctrl, "KDots", "iif(M0.Value:sub(2) == '...', 1, 0)")
expr(ctrl, "KAnim", "(function(t) return 1 - (1 - t)^3 end)(min(max((Cur.Y + 1)/max(ChIn, 1), 0), 1))")
expr(ctrl, "KPop", "(function(t) t = t - 1 return max(1 + 2.70158*t*t*t + 1.70158*t*t, 0.05) end)(min(max((Cur.Y + 1)/max(ChIn, 1), 0), 1))")
expr(ctrl, "KGap", "ChGap*ChSize")
expr(ctrl, "KPush", "(1 - KAnim)*(KH.X + (Q0.X - 1)*KH.Y + KGap)*(1 - KRepl)")
expr(ctrl, "KFade", "iif(ChOut <= 0, 1, min(max((comp.RenderEnd - time + 1)/ChOut, 0), 1))")

-- A message is one text tool that draws its own bubble, so nothing about the words has to be measured. What has to
-- be known is how tall a bubble with one line is and how much every further line adds, and where the bubble sits
-- around the point the text is put at. Three hidden rulers give that: one line, two lines, and the "typing" bubble.
local function bubble(t)
  t:SetInput("UseFrameFormatSettings", 1)
  -- the inputs of the second shading element only come into being a moment after it is switched on
  comp:Unlock()
  t:SetInput("Enabled2", 1)
  local n = 0
  while t.ExtendHorizontal2 == nil and n < 40 do bmd.wait(0.05); n = n + 1 end
  t:SetInput("ElementShape2", 2); t:SetInput("Level2", 0)
  expr(t, "ExtendHorizontal2", "ChCtrl.ChPad*0.55"); expr(t, "ExtendVertical2", "ChCtrl.ChPad*0.32")
  expr(t, "Round2", "ChCtrl.ChRound")
  comp:Lock()
end
local RTEXT = {"|", "|\n|", "ooo"}
for n = 1, 3 do
  local t = add("TextPlus", "ChRule" .. n, -4, 24 + n)
  bubble(t); t:SetInput("HorizontalLeftCenterRight", -1)
  expr(t, "Font", "ChT0.Font"); expr(t, "Style", "ChT0.Style"); expr(t, "Size", "ChCtrl.ChSize")
  t:SetInput("StyledText", RTEXT[n])
end
local function win(n, pick, none)
  return "(function() local d = ChRule" .. n .. ".Output.DataWindow if not d or d.left < -99999 then return " .. none
    .. " end local w, h = ChRule" .. n .. ".Output.Width, ChRule" .. n .. ".Output.Height return " .. pick .. " end)()"
end
-- KH: height of a one line bubble, and what a further line adds (frame widths)
expr(ctrl, "KH", "(function(a, b) return Point(a, b - a) end)(" .. win(1, "(d.top - d.bottom)/w", "0.05") .. ", " .. win(2, "(d.top - d.bottom)/w", "0.1") .. ")")
-- KO: how far the bottom of a one line bubble is below the point the text is put at, and what a further line adds
-- (fractions of the frame height)
expr(ctrl, "KO", "(function(a, b) return Point(a, b - a) end)(" .. win(1, "0.5 - d.bottom/h", "0.03") .. ", " .. win(2, "0.5 - d.bottom/h", "0.06") .. ")")
-- KW: how far the bubble reaches out sideways past the start of the words, and the width of the "typing" bubble
expr(ctrl, "KW", "Point(" .. win(1, "0.5 - d.left/w", "0.02") .. ", " .. win(3, "(d.right - d.left)/w", "0.1") .. ")")

local C = "ChCtrl."
local last
for k = SLOTS - 1, 0, -1 do
  local row = k*2
  local T, M = "ChT" .. k, "M" .. k
  expr(ctrl, M, slot(k))
  -- Q: lines, side (0 left, 1 right). Y: the bottom of the bubble above the newest one's, in frame widths
  expr(ctrl, "Q" .. k, "(function(m) local _, n = m:gsub('\\n', '') return Point(n + 1, iif(m:sub(1, 1) == '>', 1, 0)) end)(" .. M .. ".Value)")
  local extra = {}
  for j = 0, k - 1 do extra[#extra + 1] = "Q" .. j .. ".X" end
  expr(ctrl, "Y" .. k, k == 0 and "0" or string.format("%d*(KH.X + KGap) + KH.Y*(%s - %d) - KPush", k, table.concat(extra, " + "), k))
  expr(ctrl, "V" .. k, "iif(" .. M .. ".Value == '', 0, iif(" .. k .. " < ChMax, 1, iif(" .. k .. " == ChMax, (1 - KAnim)*(1 - KRepl), 0)))")

  local text = add("TextPlus", T, -3, row)
  bubble(text)
  if k == 0 then text:SetInput("Font", "Microsoft JhengHei"); text:SetInput("Style", "Regular")
  else expr(text, "Font", "ChT0.Font"); expr(text, "Style", "ChT0.Style") end
  local dots = k == 0 and "ChCtrl.KDots > 0" or "false"
  expr(text, "StyledText", "Text(iif(" .. dots .. ", 'ooo', ChCtrl." .. M .. ".Value:sub(2)))")
  expr(text, "Size", "ChCtrl.ChSize" .. (k == 0 and " * ChCtrl.KPop" or ""))
  expr(text, "HorizontalLeftCenterRight", "iif(ChCtrl.Q" .. k .. ".Y == 0, -1, 1)")
  for c, ch in ipairs({"Red", "Green", "Blue"}) do
    local bub = "iif(ChCtrl.Q" .. k .. ".Y == 0, " .. col(1, c) .. ", " .. col(3, c) .. ")"
    local ink = "iif(ChCtrl.Q" .. k .. ".Y == 0, " .. col(2, c) .. ", " .. col(4, c) .. ")"
    expr(text, ch .. "2", bub)
    -- the stand-in letters of the "typing" bubble are painted in the colour of the bubble, so they do not show
    expr(text, ch .. "1", k == 0 and "iif(ChCtrl.KDots > 0, " .. bub .. ", " .. ink .. ")" or ink)
  end
  local YB = string.format("%sChPos.Y + %sY%d*%s", C, C, k, ASP)
  expr(text, "Center", string.format("Point(iif(%sQ%d.Y == 0, %sChPos.X - %sChWidth/2 + %sKW.X, %sChPos.X + %sChWidth/2 - %sKW.X), %s + %sKO.X + (%sQ%d.X - 1)*%sKO.Y)",
    C, k, C, C, C, C, C, C, YB, C, C, k, C))
  local piece = text
  if k == 0 then
    -- three dots that hop one after the other
    local prev
    for i = 1, 3 do
      local e = add("EllipseMask", "ChDot" .. i, -3 + i, row - 2)
      expr(e, "Width", "ChCtrl.ChSize*0.3"); expr(e, "Height", "ChCtrl.ChSize*0.3")
      expr(e, "Center", string.format("Point(iif(%sQ0.Y == 0, %sChPos.X - %sChWidth/2 + %sKW.Y/2, %sChPos.X + %sChWidth/2 - %sKW.Y/2) + %d*0.5*%sChSize, %sChPos.Y + (%sKH.X/2 + 0.16*%sChSize*max(sin(time/(%s)*9 - %d*0.9), 0))*%s)",
        C, C, C, C, C, C, C, i - 2, C, C, C, C, (FPS:gsub("FpsOverride", "ChCtrl.FpsOverride")), i, ASP))
      if prev then e.EffectMask = prev.Mask end
      prev = e
    end
    local body = add("Background", "ChDots", 1, row - 1)
    body:SetInput("UseFrameFormatSettings", 1)
    for c, ch in ipairs({"TopLeftRed", "TopLeftGreen", "TopLeftBlue"}) do
      expr(body, ch, "iif(ChCtrl.Q0.Y == 0, " .. col(2, c) .. ", " .. col(4, c) .. ")")
    end
    body:SetInput("TopLeftAlpha", 1)
    body.EffectMask = prev.Mask
    local with = add("Merge", "ChWithDots", 1, row)
    with.Background = text.Output; with.Foreground = body.Output
    expr(with, "Blend", "ChCtrl.KDots * 0.55 * min(ChCtrl.KAnim*2, 1)")
    piece = with
  end
  local m = add("Merge", "ChStack" .. k, 3, row)
  m.Background = (last or ctrl).Output; m.Foreground = piece.Output
  expr(m, "Blend", "ChCtrl.V" .. k)
  last = m
end

local room = add("SetDomain", "ChRoom", 5, 0)
room.Input = last.Output; room:SetInput("Mode", "Set")
local soft = add("Blur", "ChSoft", 5, 1)
soft.Input = room.Output
expr(soft, "XBlurSize", "ChCtrl.ChSize * 15")
local lit = add("Custom", "ChLit", 6, 0)
lit.Image1 = room.Output; lit.Image2 = soft.Output
expr(lit, "NumberIn1", "ChCtrl.ChShadow")
expr(lit, "NumberIn2", "ChCtrl.ChSize * 0.15")
for _, c in ipairs({"r", "g", "b"}) do L.cx(lit, ({r = "Red", g = "Green", b = "Blue"})[c] .. "Expression", c .. "1") end
L.cx(lit, "AlphaExpression", "a1 + (1 - a1)*n1*geta2b(x, y + n2)")
local out = add("Merge", "ChFinal", 7, 0)
out.Background = ctrl.Output; out.Foreground = lit.Output
expr(out, "Blend", "ChCtrl.KFade")

local colnames = {"Custom Colour Of Their Bubble", "Custom Colour Of Their Words", "Custom Colour Of My Bubble", "Custom Colour Of My Words"}
for i, h in ipairs(HOLD) do
  local b = add("Background", h, -4 + i, -6)
  b:SetInput("UseFrameFormatSettings", 0); b:SetInput("Width", 16); b:SetInput("Height", 16)
  local p = PRESETS[1][2]
  L.color(b, p[i*3 - 2], p[i*3 - 1], p[i*3], 1)
end

mediaOut.Input = out.Output
comp:EndUndo(true)
comp:Unlock()
table.insert(spec, 7, {"CTL", "ChT0", "Font", "Font", "2"})
table.insert(spec, 8, {"CTL", "ChT0", "Style", "", "2"})
for i, h in ipairs(HOLD) do
  local g = tostring(i + 2)
  spec[#spec + 1] = {"CTL", h, "TopLeftRed", colnames[i], g}
  spec[#spec + 1] = {"CTL", h, "TopLeftGreen", "", g}
  spec[#spec + 1] = {"CTL", h, "TopLeftBlue", "", g}
end
L.ship(comp, {slug = "chatbubbles", name = "ChatBubbles", out = out, ctrl = ctrl, spec = spec, prefix = "ch",
  before = function()
    local file = os.getenv("FX_TEXTFILE") and io.open(os.getenv("FX_TEXTFILE"), "r")
    if file then ctrl:SetInput("ChList", file:read("*a")); file:close() end
    L.keys(ctrl, "ChCue", os.getenv("FX_CUE"))
  end})
