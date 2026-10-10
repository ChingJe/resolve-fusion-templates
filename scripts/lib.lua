-- Shared helpers for the build scripts. Load with: local L = dofile("D:/davinci/scripts/lib.lua")
local L = {}
L.S = "D:/davinci/scripts/"
L.OUT = L.S .. "out/"
L.PROJECT = os.getenv("FX_PROJECT") or "testsss"
L.TIMELINE = os.getenv("FX_TIMELINE") or "FX Lab"
L.resolve = bmd.scriptapp("Resolve")

-- Returns the Fusion comp of the lab clip, or nil when Resolve is not where we expect it to be.
function L.comp()
  local proj = L.resolve:GetProjectManager():GetCurrentProject()
  local pn = proj and proj:GetName()
  local tl = proj and proj:GetCurrentTimeline()
  local tn = tl and tl:GetName()
  if pn ~= L.PROJECT or tn ~= L.TIMELINE then
    print("WRONG_PLACE project=" .. tostring(pn) .. " timeline=" .. tostring(tn))
    return nil
  end
  local comp = L.resolve:Fusion():GetCurrentComp()
  if not comp then print("NO_COMP") end
  return comp
end

local keep = {MediaIn = true, MediaOut = true, AudioDisplay = true}
function L.clear(comp)
  local mi, mo
  for _, t in pairs(comp:GetToolList(false)) do
    if t.ID == "MediaIn" then mi = t elseif t.ID == "MediaOut" then mo = t end
    if not keep[t.ID] then t:Delete() end
  end
  return mi, mo
end

function L.adder(comp)
  return function(id, name, x, y)
    local t = comp:AddTool(id, x or 0, y or 0)
    t:SetAttrs({TOOLS_Name = name})
    return t
  end
end

function L.expr(tool, input, e) tool[input]:SetExpression(e) end

function L.color(bg, r, g, b, a)
  bg.TopLeftRed = r; bg.TopLeftGreen = g; bg.TopLeftBlue = b; bg.TopLeftAlpha = a or 1
end

function L.num(label, def, lo, hi, page, int)
  return {LINKID_DataType = "Number", INPID_InputControl = "SliderControl", LINKS_Name = label,
          INP_Default = def, INP_MinScale = lo, INP_MaxScale = hi, INP_Integer = int and true or false,
          ICS_ControlPage = page or "Controls"}
end
function L.check(label, def, page)
  return {LINKID_DataType = "Number", INPID_InputControl = "CheckboxControl", LINKS_Name = label,
          INP_Default = def, INP_Integer = true, ICS_ControlPage = page or "Controls"}
end
function L.text(label, def, page, lines)
  return {LINKID_DataType = "Text", INPID_InputControl = "TextEditControl", LINKS_Name = label,
          INPS_DefaultText = def, TEC_Lines = lines or 1, ICS_ControlPage = page or "Controls"}
end

-- Which line of a list is on screen. Returns a function that gives the expression (as text) for one thing to pick:
-- 1 the line number (0 when nothing shows), 2 frames since it appeared, 3 frames until the next one, 4 its text.
-- The list is a text control with one line per row. With the checkbox <timed> on, every row starts with a time
-- ("0:02 Text", see docs/time-list.md). With it off the rows are plain text and the number control <cue>
-- says which row shows: keyframe it 1, 2, 3 and each row appears on its keyframe.
function L.cur(ctrl, list, timed, cue)
  local body = [[(function(txt, timed, cue, fps, t0, t1, now, pick)
  local idx, since, untl, text = 0, 0, 9999, ""
  if timed == 0 then
    idx = math.floor(cue + 0.0001)
    for d = 1, 90 do
      if now - d < t0 or math.floor(CTRL:GetValue("CUE", now - d) + 0.0001) ~= idx then break end
      since = d
    end
    for d = 1, 60 do
      if now + d > t1 then break end
      if math.floor(CTRL:GetValue("CUE", now + d) + 0.0001) ~= idx then untl = d break end
    end
    local n = 0
    for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
      n = n + 1
      if n == idx then text = line end
    end
  else
    local rel, len, best, nxt, n = now - t0, math.max(t1 - t0, 1), -1, 1e9, 0
    for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
      n = n + 1
      local stamp, name = line:match("^%s*(%S+)%s*(.-)%s*$")
      local f
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
      if f then
        if f <= rel + 0.001 then
          if f >= best then best, idx, text = f, n, name end
        elseif f < nxt then nxt = f end
      end
    end
    if best < 0 then idx, text = 0, "" else since, untl = rel - best, nxt - rel end
  end
  if pick == 1 then return idx elseif pick == 2 then return since elseif pick == 3 then return untl end
  return text
end)(CTRL.LIST.Value, CTRL.TIMED, CTRL.CUE, iif(CTRL.FpsOverride > 0, CTRL.FpsOverride, comp:GetPrefs("Comp.FrameFormat.Rate") or 24), comp.RenderStart, comp.RenderEnd, time, PICK)]]
  body = body:gsub("CTRL", ctrl):gsub("LIST", list):gsub("TIMED", timed):gsub("CUE", cue)
  return function(pick) return (body:gsub("PICK", tostring(pick))) end
end
function L.combo(label, items, def, page)
  local c = {LINKID_DataType = "Number", INPID_InputControl = "ComboControl", LINKS_Name = label,
             INP_Default = def or 0, INP_Integer = true, ICS_ControlPage = page or "Controls"}
  for i, s in ipairs(items) do c[i] = {CCS_AddString = s} end
  return c
end

-- Colours a white-on-clear shape and puts two outlines around it. w1, w2 are expressions for the outline widths
-- (fractions of the frame width), c is nine expressions: fill r g b, inner outline r g b, outer outline r g b.
-- Makes <name> (a Custom) plus two ErodeDilate tools and returns the Custom.
function L.inked(comp, name, x, y, matte, w1, w2, c)
  local add = L.adder(comp)
  local g1 = add("ErodeDilate", name .. "GrowA", x, y + 1)
  g1.Input = matte; g1:SetInput("Filter", 3); L.expr(g1, "XAmount", w1)
  local g2 = add("ErodeDilate", name .. "GrowB", x, y + 2)
  g2.Input = matte; g2:SetInput("Filter", 3); L.expr(g2, "XAmount", "(" .. w1 .. ") + (" .. w2 .. ")")
  local p = add("Custom", name, x + 1, y)
  p.Image1 = matte; p.Image2 = g1.Output; p.Image3 = g2.Output
  for i = 1, 6 do L.expr(p, "NumberIn" .. i, c[i]) end
  L.expr(p, "PointIn1", "Point(" .. c[7] .. ", " .. c[8] .. ")")
  L.expr(p, "PointIn2", "Point(" .. c[9] .. ", 0)")
  -- an outline of zero width is left out, otherwise it would cover the one inside it
  L.expr(p, "NumberIn7", "iif((" .. w1 .. ") > 0, 1, 0)")
  L.expr(p, "NumberIn8", "iif((" .. w2 .. ") > 0, 1, 0)")
  p:SetInput("Intermediate1", "a2*n7")
  p:SetInput("Intermediate2", "a3*n8")
  p:SetInput("RedExpression",   "n1*a1 + (1 - a1)*(n4*i1 + (1 - i1)*p1x*i2)")
  p:SetInput("GreenExpression", "n2*a1 + (1 - a1)*(n5*i1 + (1 - i1)*p1y*i2)")
  p:SetInput("BlueExpression",  "n3*a1 + (1 - a1)*(n6*i1 + (1 - i1)*p2x*i2)")
  p:SetInput("AlphaExpression", "a1 + (1 - a1)*(i1 + (1 - i1)*i2)")
  return p
end
-- test helper: FX_<env>="10=1,60=2" keyframes a number control on those frames
function L.keys(tool, id, spec)
  if not spec then return end
  tool:AddModifier(id, "BezierSpline")
  local sp = tool[id]:GetConnectedOutput():GetTool()
  local mine = {}
  for f, v in string.gmatch(spec, "(%d+)=([%d%.]+)") do tool[id][tonumber(f)] = tonumber(v); mine[tonumber(f)] = true end
  for f in pairs(sp:GetKeyFrames()) do if not mine[f] then sp:DeleteKeyFrames(f) end end
end
function L.point(label, page, cross)
  return {LINKID_DataType = "Point", INPID_InputControl = "OffsetControl", LINKS_Name = label,
          INPID_PreviewControl = cross and "CrosshairControl" or nil, ICS_ControlPage = page or "Controls"}
end

-- progress 0..1 over the clip, for a user control named P on the controller
L.P = "min(max((time - comp.RenderStart) / max(comp.RenderEnd - comp.RenderStart, 1), 0), 1)"

-- Procedural stand-in for a video clip: moving shapes and a frame counter, so time offsets are visible
-- and nothing private ends up in a preview. All tool names start with Prev and are skipped on export.
-- FX_SRC=scenes makes it a clip with cuts: every FX_SCENE frames (40 by default) the colours, the size of
-- the ball and the path it takes all change, so a template that shows several moments at once shows several pictures.
local SCENES = { -- corner colour, opposite corner colour, ball, bar
  {{0.08, 0.20, 0.55}, {0.15, 0.55, 0.70}, {1.00, 0.85, 0.15}, {0.95, 0.95, 0.95}},
  {{0.70, 0.12, 0.10}, {0.95, 0.50, 0.15}, {0.15, 0.90, 0.95}, {0.10, 0.10, 0.12}},
  {{0.08, 0.40, 0.18}, {0.60, 0.80, 0.20}, {0.95, 0.25, 0.55}, {1.00, 1.00, 1.00}},
  {{0.35, 0.10, 0.55}, {0.85, 0.35, 0.70}, {0.40, 1.00, 0.40}, {1.00, 0.90, 0.30}},
  {{0.85, 0.65, 0.10}, {0.98, 0.90, 0.55}, {0.15, 0.25, 0.75}, {0.75, 0.10, 0.10}},
  {{0.05, 0.08, 0.12}, {0.20, 0.35, 0.45}, {1.00, 0.45, 0.10}, {0.30, 0.90, 0.85}},
}
function L.testsource(comp, tag, hue)
  local add = L.adder(comp)
  tag = tag or "A"
  hue = hue or 0
  local scenes = os.getenv("FX_SRC") == "scenes"
  -- SC: which scene this frame belongs to, 1..6. The second stand-in starts three scenes later.
  local SC = string.format("((floor(time/%d) + %d) %% %d + 1)", tonumber(os.getenv("FX_SCENE") or "40"), hue*3, #SCENES)
  local function pick(set, ch, mix)
    local rows = {}
    for i, s in ipairs(SCENES) do
      rows[i] = mix and string.format("%.3f", s[1][ch]*(1 - mix) + s[2][ch]*mix) or string.format("%.3f", s[set][ch])
    end
    return "({" .. table.concat(rows, ",") .. "})[" .. SC .. "]"
  end
  local function paint(tool, set)
    for ch, n in ipairs({"TopLeftRed", "TopLeftGreen", "TopLeftBlue"}) do L.expr(tool, n, pick(set, ch)) end
  end
  local bg = add("Background", "PrevBG" .. tag, -12, -8)
  bg:SetInput("Type", "Corner")
  local c = hue == 0 and {{0.10, 0.25, 0.55}, {0.15, 0.55, 0.60}, {0.45, 0.15, 0.50}, {0.85, 0.45, 0.20}}
                      or {{0.55, 0.20, 0.10}, {0.75, 0.60, 0.15}, {0.20, 0.45, 0.20}, {0.15, 0.30, 0.45}}
  local names = {"TopLeft", "TopRight", "BottomLeft", "BottomRight"}
  for i, n in ipairs(names) do
    bg[n .. "Red"] = c[i][1]; bg[n .. "Green"] = c[i][2]; bg[n .. "Blue"] = c[i][3]; bg[n .. "Alpha"] = 1
    if scenes then
      for ch, col in ipairs({"Red", "Green", "Blue"}) do L.expr(bg, n .. col, pick(1, ch, ({0, 0.45, 0.55, 1})[i])) end
    end
  end
  local ballMask = add("EllipseMask", "PrevBallMask" .. tag, -11, -9)
  ballMask:SetInput("Width", 0.22); ballMask:SetInput("Height", 0.22)
  L.expr(ballMask, "Center", "Point(0.5 + 0.36*sin(time*0.07), 0.5 + 0.30*cos(time*0.10))")
  local ball = add("Background", "PrevBall" .. tag, -11, -8)
  L.color(ball, 1.0, 0.85, 0.15)
  ball.EffectMask = ballMask.Mask
  local m1 = add("Merge", "PrevM1" .. tag, -10, -8)
  m1.Background = bg.Output; m1.Foreground = ball.Output
  local barMask = add("RectangleMask", "PrevBarMask" .. tag, -10, -9)
  barMask:SetInput("Width", 0.5); barMask:SetInput("Height", 0.06)
  L.expr(barMask, "Angle", "time*2.5")
  local bar = add("Background", "PrevBar" .. tag, -9, -9)
  L.color(bar, 0.95, 0.95, 0.95)
  bar.EffectMask = barMask.Mask
  local m2 = add("Merge", "PrevM2" .. tag, -9, -8)
  m2.Background = m1.Output; m2.Foreground = bar.Output
  if scenes then
    paint(ball, 3); paint(bar, 4)
    -- each scene has its own ball size, its own path, and the bar sits somewhere else
    L.expr(ballMask, "Width", "0.14 + 0.05*(" .. SC .. " % 4)"); L.expr(ballMask, "Height", "Width")
    L.expr(ballMask, "Center", string.format("Point(0.5 + 0.36*sin(time*0.07 + %s*1.9), 0.5 + 0.30*cos(time*0.10 + %s*2.7))", SC, SC))
    L.expr(barMask, "Center", string.format("Point(0.5 + 0.25*sin(%s*2.4), 0.5 + 0.2*cos(%s*1.3))", SC, SC))
    L.expr(barMask, "Width", "0.3 + 0.1*(" .. SC .. " % 3)")
    L.expr(barMask, "Angle", "time*2.5 + " .. SC .. "*50")
  end
  local txt = add("TextPlus", "PrevText" .. tag, -8, -9)
  txt:SetInput("Font", "Arial"); txt:SetInput("Style", "Bold"); txt:SetInput("Size", 0.16)
  txt:SetInput("Center", {0.5, 0.2})
  L.expr(txt, "StyledText", 'Text("' .. tag .. ' " .. string.format("%03d", time))')
  local m3 = add("Merge", "PrevM3" .. tag, -8, -8)
  m3.Background = m2.Output; m3.Foreground = txt.Output
  for _, t in ipairs({bg, ball, bar, txt}) do t:SetInput("UseFrameFormatSettings", 1) end
  return m3
end

-- Render the whole range through a temporary small saver (FX_WIDTH wide, 640 by default).
-- Frames land in scripts/out/<prefix>NNNN.png
function L.render(comp, output, prefix, steps)
  local a = comp:GetAttrs()
  local rs, re = a.COMPN_RenderStart, a.COMPN_RenderEnd
  comp:Lock()
  local small = comp:AddTool("BetterResize", 6, 6)
  small.Input = output
  local width = tonumber(os.getenv("FX_WIDTH") or "640")
  small:SetInput("Width", width); small:SetInput("Height", math.floor(width * 9 / 16)); small:SetInput("KeepAspect", 0)
  local saver = comp:AddTool("Saver", 7, 6)
  saver.Input = small.Output
  saver:SetInput("Clip", L.OUT .. prefix .. ".png")
  comp:Unlock()
  local t0 = os.time()
  local ok = comp:Render({Start = rs, End = re, StepRender = true, Steps = steps or 8, Tool = saver, Wait = true})
  comp:SetAttrs({COMPN_RenderStart = rs, COMPN_RenderEnd = re})
  comp:Lock(); saver:Delete(); small:Delete(); comp:Unlock()
  print("render", tostring(ok), "range", rs, re, "seconds", os.time() - t0)
  return rs, re
end

-- Dump every tool that is not media or a Prev* stand-in, plus a tab separated spec for macro.py
function L.export(comp, slug, spec)
  local tools = {}
  for _, t in pairs(comp:GetToolList(false)) do
    if not keep[t.ID] and string.sub(t.Name, 1, 4) ~= "Prev" then tools[#tools + 1] = t end
  end
  local text = bmd.writestring(comp:CopySettings(tools))
  local f = io.open(L.OUT .. slug .. ".raw", "w"); f:write(text); f:close()
  f = io.open(L.OUT .. slug .. ".spec", "w")
  for _, row in ipairs(spec) do f:write(table.concat(row, "\t") .. "\n") end
  f:close()
  print("exported", slug, "tools", #tools, "chars", #text)
end

return L
