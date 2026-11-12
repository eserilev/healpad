-- Classic: the game's own party frames, portrait and all, five of them in a
-- plus with you in the middle. Health and mana bars as the party frames draw
-- them. The aimed one glows gold with the party frame's own flash and grows a
-- little; under a quarter health the flash pulses red.
local _, ns = ...
local K = ns.kit
local look = ns.registerLook("classic", {})

local W, H = 128, 53
local FRAME = "Interface\\TargetingFrame\\UI-PartyFrame"
local FLASH = "Interface\\TargetingFrame\\UI-PartyFrame-Flash"
local SAMPLE_POWER = { WARRIOR = { 1, 0, 0, 0.3 }, ROGUE = { 1, 1, 0, 0.8 } }

local function makeFrame(c)
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(W, H)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(W, H)
  med:SetPoint("CENTER")
  f.med = med
  -- the aimed one's glow, and the red one when they're low
  f.sel = med:CreateTexture(nil, "BACKGROUND", nil, 0)
  f.sel:SetSize(128, 64)
  f.sel:SetPoint("TOPLEFT", -3, 1)
  f.sel:SetTexture(FLASH)
  f.sel:SetVertexColor(1, 0.82, 0, 1)
  f.sel:Hide()
  f.face = med:CreateTexture(nil, "BACKGROUND", nil, 2)
  f.face:SetSize(37, 37)
  f.face:SetPoint("TOPLEFT", 7, -6)
  -- round, like the hole in the frame: nothing square shows at its edge
  local mask = med:CreateMaskTexture()
  mask:SetTexture(K.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(f.face)
  f.face:AddMaskTexture(mask)
  f.health = K.healthBar(med, 70, 10)
  f.health:SetPoint("TOPLEFT", 47, -12)
  f.health.back:SetColorTexture(0, 0, 0, 0.5)
  f.power = CreateFrame("StatusBar", nil, med)
  f.power:SetSize(70, 10)
  f.power:SetPoint("TOPLEFT", 47, -20)
  f.power:SetStatusBarTexture(K.BAR)
  f.power:SetMinMaxValues(0, 1)
  local pb = f.power:CreateTexture(nil, "BACKGROUND")
  pb:SetAllPoints()
  pb:SetColorTexture(0, 0, 0, 0.5)
  -- the frame's art over the bars and portrait
  local art = CreateFrame("Frame", nil, med)
  art:SetAllPoints()
  art:SetFrameLevel(f.health:GetFrameLevel() + 3)
  local tex = art:CreateTexture(nil, "ARTWORK")
  tex:SetSize(128, 64)
  tex:SetPoint("TOPLEFT", 0, -2)
  tex:SetTexture(FRAME)
  f.name = art:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.name:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, 2)
  f.name:SetWidth(76)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.state = K.stateIcon(art, 26)
  f.state:SetPoint("CENTER", f.face, "CENTER")
  f.hot = K.hotPip(art, 16)
  f.hot:SetPoint("TOPLEFT", f.power, "BOTTOMLEFT", 0, -3)
  f.dispel = K.dispelPip(art, 11)
  f.dispel:SetPoint("LEFT", f.hot, "RIGHT", 6, 0)
  f.entrance = K.entrance(f)
  return f
end

local function setPower(bar, src)
  if src.unit then
    local unit = src.unit
    local ok = pcall(function()
      local kind = UnitPowerType(unit)
      local c = PowerBarColor[kind]
      bar:SetStatusBarColor(c.r, c.g, c.b)
      bar:SetMinMaxValues(0, UnitPowerMax(unit, kind))
      bar:SetValue(UnitPower(unit, kind))
    end)
    if not ok then
      bar:SetStatusBarColor(0, 0, 1)
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(0)
    end
    return
  end
  local p = SAMPLE_POWER[src.class] or { 0, 0, 1, 0.7 }
  bar:SetStatusBarColor(p[1], p[2], p[3])
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(src.kind == "empty" and 0 or p[4])
end

function look.build(stage)
  local c = CreateFrame("Frame", nil, stage)
  c:SetAllPoints()
  c:Hide()
  look.frame = c
  -- every look takes about the same room on screen at the same Size
  c:SetScale(1.3)
  look.spots = {}
  for _, d in ipairs(ns.DIRS) do
    look.spots[d] = makeFrame(c)
  end
  look.spots.SELF:SetScale(1.15)
end

function look.layout(spacing)
  -- the middle frame is bigger; the gaps grow with Spacing and never close
  local tx, ty = W * 1.15 / 2 + W / 2, H * 1.15 / 2 + H / 2
  local hx = K.space(tx + 32, tx, spacing)
  local vy = K.space(ty + 45, ty, spacing)
  local off = { UP = { 0, vy }, RIGHT = { hx, 0 }, DOWN = { 0, -vy }, LEFT = { -hx, 0 }, SELF = { 0, 0 } }
  for d, f in pairs(look.spots) do
    f.at = off[d]
    local k = f:GetScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", look.frame, "CENTER", f.at[1] / k, f.at[2] / k)
  end
end

function look.draw(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.45)
  f.far = far
  K.byHealth(src, "hp", function(r, g, b, a)
    f.health:SetStatusBarColor(r, g, b, a)
  end)
  setPower(f.power, src)
  if status then
    f.name:SetTextColor(0.5, 0.5, 0.5)
  elseif far then
    f.name:SetTextColor(0.6, 0.55, 0.4)
  else
    f.name:SetTextColor(1, 0.82, 0)
  end
end

function look.aim(sel)
  for d, f in pairs(look.spots) do
    local on = d == sel
    K.scaleTo(f.med, on and 1.1 or 1, 0.08)
    -- sel nil: the plus at rest, nobody dimmed
    K.fadeTo(f.med, on and 1 or (f.far and 0.45 or ((sel == "SELF" or sel == nil) and 1 or 0.75)), 0.1)
    f.sel:SetShown(on)
    f:SetFrameLevel(on and 20 or 5)
  end
end

function look.open()
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.entrance(v[1] * 30, v[2] * 20, 0.9, 0.9, 0.12)
  end
end

function look.cast() end
