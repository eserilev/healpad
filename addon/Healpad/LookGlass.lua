-- Gilded Glass: slim see-through bars filled in class colors, edged with a
-- gold hairline. The aimed bar takes a gold border and grows a little; small
-- gold chevrons between the bars light toward the aim.
local _, ns = ...
local K = ns.kit
local look = ns.registerLook("glass", {})

local W, H = 140, 28
local AT = { UP = { 0, 68 }, RIGHT = { 170, 0 }, DOWN = { 0, -68 }, LEFT = { -170, 0 }, SELF = { 0, 0 } }
local GOLD = { 1, 0.83, 0.35, 1 }

local function makeBar(c)
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(W, H)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(W, H)
  med:SetPoint("CENTER")
  f.med = med
  local glass = med:CreateTexture(nil, "BACKGROUND")
  glass:SetAllPoints()
  glass:SetColorTexture(0.03, 0.04, 0.05, 0.55)
  f.edge = ns.outline(med, med, 0, 1)
  f.edge:SetColor(0.79, 0.63, 0.3, 0.55)
  f.edge:Show()
  f.sel = ns.outline(med, med, 0, 2)
  f.sel:SetColor(unpack(GOLD))
  f.health = K.healthBar(med, W - 4, H - 4)
  f.health:SetPoint("CENTER")
  f.health.back:SetColorTexture(0, 0, 0, 0)
  local over = CreateFrame("Frame", nil, med)
  over:SetAllPoints()
  over:SetFrameLevel(f.health:GetFrameLevel() + 2)
  f.crit = over:CreateTexture(nil, "BACKGROUND")
  f.crit:SetAllPoints()
  f.crit:SetColorTexture(1, 1, 1, 1)
  f.crit:SetVertexColor(1, 0.16, 0.1, 0)
  K.pulse(f.crit, 0.15, 0.55, 0.55)
  f.name = over:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.name:SetPoint("LEFT", 9, 0)
  f.name:SetWidth(W - 40)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.hot = K.hotPip(over, 13)
  f.hot:SetPoint("RIGHT", -5, 0)
  f.dispel = K.dispelPip(over, 9)
  f.dispel:SetPoint("RIGHT", -24, 0)
  f.state = K.stateIcon(over, 20)
  f.state:SetPoint("RIGHT", -5, 0)
  f.entrance = K.entrance(f)
  return f
end

function look.build(stage, fx)
  local c = CreateFrame("Frame", nil, stage)
  c:SetAllPoints()
  c:Hide()
  look.frame = c
  look.spots = {}
  for _, d in ipairs(ns.DIRS) do
    look.spots[d] = makeBar(c)
  end
  -- a chevron of two short lines between you and each of the others
  look.chevrons = {}
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT" }) do
    local ch = {}
    for i = 1, 2 do
      local l = c:CreateLine(nil, "ARTWORK")
      l:SetThickness(2)
      l:SetColorTexture(unpack(GOLD))
      l:SetAlpha(0.18)
      l.a = 0.18
      ch[i] = l
    end
    look.chevrons[d] = ch
  end
  local layer = CreateFrame("Frame", nil, fx)
  layer:SetAllPoints()
  local flash = layer:CreateTexture(nil, "OVERLAY")
  flash:SetSize(W + 4, H + 4)
  flash:SetColorTexture(1, 0.94, 0.7, 0.85)
  flash:SetAlpha(0)
  local g = flash:CreateAnimationGroup()
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0)
  a:SetDuration(0.45)
  look.flash = function(bar)
    flash:ClearAllPoints()
    flash:SetPoint("CENTER", bar, "CENTER")
    g:Stop()
    g:Play()
  end
  look.float = K.floater(layer)
end

function look.layout(spread)
  local k = 1 + (spread - 3) * 0.12
  for d, f in pairs(look.spots) do
    f.at = { AT[d][1] * k, AT[d][2] * k }
    f:ClearAllPoints()
    f:SetPoint("CENTER", look.frame, "CENTER", f.at[1], f.at[2])
  end
  for d, ch in pairs(look.chevrons) do
    local v = K.DIR_VEC[d]
    -- halfway out, between the middle bar's edge and the next bar
    local reach = v[1] ~= 0 and (AT[d][1] * k * v[1] + W / 2) / 2 or (AT[d][2] * k * v[2] + H / 2) / 2 + 2
    local mx, my = v[1] * reach, v[2] * reach
    local px, py = -v[2], v[1]
    local tipX, tipY = mx + v[1] * 3, my + v[2] * 3
    for i, side in ipairs({ 1, -1 }) do
      local l = ch[i]
      l:SetStartPoint("CENTER", look.frame, mx - v[1] * 3 + px * 4 * side, my - v[2] * 3 + py * 4 * side)
      l:SetEndPoint("CENTER", look.frame, tipX, tipY)
    end
  end
end

function look.draw(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.38)
  f.far = far
  if status then
    f.health:SetStatusBarColor(0.4, 0.4, 0.4, 0.88)
  else
    local r, g, b = K.classColor(src)
    f.health:SetStatusBarColor(r, g, b, 0.88)
  end
  if status or far then
    f.name:SetTextColor(0.62, 0.6, 0.56)
  else
    f.name:SetTextColor(1, 1, 1)
  end
  f.edge:SetAlpha(far and 0.5 or 1)
end

function look.aim(sel)
  for d, f in pairs(look.spots) do
    local on = d == sel
    K.scaleTo(f.med, on and 1.15 or 1, 0.08)
    K.fadeTo(f.med, on and 1 or (f.far and 0.38 or (sel == "SELF" and 1 or 0.78)), 0.1)
    f.sel:SetShown(on)
    f.edge:SetShown(not on)
    f:SetFrameLevel(on and 20 or 5)
  end
  for d, ch in pairs(look.chevrons) do
    for _, l in ipairs(ch) do
      K.fadeTo(l, d == sel and 1 or 0.18, 0.1)
    end
  end
end

function look.open()
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.entrance(v[1] * 40, v[2] * 24, 0.8, 0.8, 0.14)
  end
end

function look.cast(dir, text)
  local f = look.spots[dir]
  look.flash(f)
  look.float(f, text, 6)
end
