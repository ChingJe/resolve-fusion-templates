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

-- progress 0..1 over the clip, for a user control named P on the controller
L.P = "min(max((time - comp.RenderStart) / max(comp.RenderEnd - comp.RenderStart, 1), 0), 1)"

-- Procedural stand-in for a video clip: moving shapes and a frame counter, so time offsets are visible
-- and nothing private ends up in a preview. All tool names start with Prev and are skipped on export.
function L.testsource(comp, tag, hue)
  local add = L.adder(comp)
  tag = tag or "A"
  hue = hue or 0
  local bg = add("Background", "PrevBG" .. tag, -12, -8)
  bg:SetInput("Type", "Corner")
  local c = hue == 0 and {{0.10, 0.25, 0.55}, {0.15, 0.55, 0.60}, {0.45, 0.15, 0.50}, {0.85, 0.45, 0.20}}
                      or {{0.55, 0.20, 0.10}, {0.75, 0.60, 0.15}, {0.20, 0.45, 0.20}, {0.15, 0.30, 0.45}}
  local names = {"TopLeft", "TopRight", "BottomLeft", "BottomRight"}
  for i, n in ipairs(names) do
    bg[n .. "Red"] = c[i][1]; bg[n .. "Green"] = c[i][2]; bg[n .. "Blue"] = c[i][3]; bg[n .. "Alpha"] = 1
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
