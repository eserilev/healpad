-- Medallions: round gold-rimmed portraits on a circle, you in the middle.
-- Name and health under each. The aimed one grows inside a gold ring,
-- the others dim, and a gold spoke points from the middle to it.
local _, ns = ...
local K = ns.kit
local look = ns.registerLook("medallions", {})

local R = 160
local GOLD_LINE, CLEAR = { 1, 0.84, 0.35, 0.95 }, { 1, 0.82, 0, 0 }

local function makeSpot(c, dir)
  local S = dir == "SELF" and 76 or 84
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(S, S)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(S, S)
  med:SetPoint("CENTER")
  f.med = med
  -- the aimed one's ring of gold
  f.ring = K.disc(med, S + 12, "BACKGROUND", 0)
  f.ring:SetPoint("CENTER")
  f.ring:SetColorTexture(1, 0.82, 0.2, 1)
  f.ring:Hide()
  local shadow = K.disc(med, S + 4, "BACKGROUND", 2)
  shadow:SetPoint("CENTER")
  shadow:SetColorTexture(0.11, 0.08, 0.02, 1)
  local rim = K.disc(med, S, "BORDER", 0)
  rim:SetPoint("CENTER")
  K.gradient(rim, "VERTICAL", { 0.36, 0.25, 0.09, 1 }, { 0.95, 0.82, 0.48, 1 })
  f.face = K.disc(med, S - 10, "ARTWORK", 0)
  f.face:SetPoint("CENTER")
  f.state = K.stateIcon(med, S * 0.5)
  f.state:SetPoint("CENTER")
  if dir == "SELF" then
    -- the held heal's icon, on the bottom of your medallion
    f.badge = CreateFrame("Frame", nil, med)
    f.badge:SetSize(30, 30)
    f.badge:SetPoint("CENTER", med, "BOTTOM", 0, 1)
    local edge = f.badge:CreateTexture(nil, "ARTWORK", nil, 0)
    edge:SetAllPoints()
    edge:SetColorTexture(0.79, 0.63, 0.3, 1)
    f.badge.icon = f.badge:CreateTexture(nil, "ARTWORK", nil, 1)
    f.badge.icon:SetPoint("TOPLEFT", 2, -2)
    f.badge.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    f.badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  f.name = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOP", f, "BOTTOM", 0, dir == "SELF" and -17 or -6)
  f.name:SetWidth(130)
  f.name:SetWordWrap(false)
  f.health = K.healthBar(f.body, 96, 8)
  f.health:SetPoint("TOP", f.name, "BOTTOM", 0, -5)
  f.health.back:SetColorTexture(0.07, 0.05, 0.03, 0.95)
  local edge = f.body:CreateTexture(nil, "BACKGROUND", nil, 1)
  edge:SetPoint("TOPLEFT", f.health, -1, 1)
  edge:SetPoint("BOTTOMRIGHT", f.health, 1, -1)
  edge:SetColorTexture(0.29, 0.23, 0.12, 1)
  local outer = f.body:CreateTexture(nil, "BACKGROUND", nil, 0)
  outer:SetPoint("TOPLEFT", f.health, -2, 2)
  outer:SetPoint("BOTTOMRIGHT", f.health, 2, -2)
  outer:SetColorTexture(0, 0, 0, 1)
  local shine = f.health:CreateTexture(nil, "OVERLAY")
  shine:SetPoint("TOPLEFT")
  shine:SetPoint("TOPRIGHT")
  shine:SetHeight(3)
  shine:SetColorTexture(1, 1, 1, 0.18)
  K.indicators(f, {
    host = med,
    edge = f.health,
    pad = 3,
    size = 18,
    debuffs = { "TOPLEFT", med, "TOPRIGHT", -10, 2 },
    hots = { "BOTTOMLEFT", med, "BOTTOMRIGHT", -10, -2 },
    top = med,
    rez = f.face,
    rezSize = 40,
    buff = { "TOPLEFT", med, "TOPLEFT", 4, -4 },
  })
  f.entrance = K.entrance(f)
  return f
end

-- A gold line from the middle to the one aimed at, brightest at their end.
local function makeSpoke(c, dir, mid, to)
  local s = {}
  for i, w in ipairs({ 10, 3 }) do
    local t = c:CreateTexture(nil, "BACKGROUND", nil, i)
    local glow = i == 1 and { 1, 0.75, 0.2, 0.3 } or GOLD_LINE
    if dir == "UP" or dir == "DOWN" then
      t:SetWidth(w)
      t:SetPoint(dir == "UP" and "BOTTOM" or "TOP", mid, "CENTER")
      t:SetPoint(dir == "UP" and "TOP" or "BOTTOM", to, "CENTER")
      K.gradient(t, "VERTICAL", dir == "UP" and CLEAR or glow, dir == "UP" and glow or CLEAR)
    else
      t:SetHeight(w)
      t:SetPoint(dir == "RIGHT" and "LEFT" or "RIGHT", mid, "CENTER")
      t:SetPoint(dir == "RIGHT" and "RIGHT" or "LEFT", to, "CENTER")
      K.gradient(t, "HORIZONTAL", dir == "RIGHT" and CLEAR or glow, dir == "RIGHT" and glow or CLEAR)
    end
    if i == 1 then
      t:SetBlendMode("ADD")
    end
    t:SetAlpha(0)
    t.a = 0
    s[i] = t
  end
  return s
end

function look.build(stage, fx)
  local c = CreateFrame("Frame", nil, stage)
  c:SetAllPoints()
  c:Hide()
  look.frame = c
  -- every look takes about the same room on screen at the same Size
  c:SetScale(0.85)
  look.spots = {}
  for _, d in ipairs(ns.DIRS) do
    look.spots[d] = makeSpot(c, d)
  end
  look.spokes = {}
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT" }) do
    look.spokes[d] = makeSpoke(c, d, look.spots.SELF, look.spots[d])
  end
  local layer = CreateFrame("Frame", nil, fx)
  layer:SetAllPoints()
  look.burst = K.burst(layer, K.STAR, 150, { 1, 0.86, 0.4, 1 }, 0.3, 1.9, 45, 0.7)
  look.float = K.floater(layer)
end

function look.layout(spacing)
  -- you are 76 across, the others 84
  local r = K.space(R, (76 + 84) / 2, spacing)
  look.r = r
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.at = { v[1] * r, v[2] * r }
    f:ClearAllPoints()
    f:SetPoint("CENTER", look.frame, "CENTER", f.at[1], f.at[2])
  end
end

function look.draw(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.62)
  f.far = far
  if status or far then
    f.name:SetTextColor(0.6, 0.58, 0.55)
  else
    f.name:SetTextColor(1, 0.82, 0)
  end
  K.byHealth(src, "hp", function(r, g, b, a)
    f.health:SetStatusBarColor(r, g, b, a)
  end)
  if f.badge then
    f.badge:SetShown(ctx.spell ~= nil)
    f.badge.icon:SetTexture(ns.spellIcon(ctx.spell))
  end
end

function look.aim(sel)
  for d, f in pairs(look.spots) do
    local on = d == sel
    K.scaleTo(f.med, on and 1.24 or (f.far and 0.86 or 1), 0.09)
    -- sel nil: the plus at rest, nobody dimmed
    K.fadeTo(f.med, on and 1 or (f.far and 0.62 or (sel == nil and 1 or sel == "SELF" and 0.92 or 0.72)), 0.12)
    f.ring:SetShown(on)
    f:SetFrameLevel(on and 20 or 5)
  end
  for d, s in pairs(look.spokes) do
    for _, t in ipairs(s) do
      K.fadeTo(t, d == sel and 1 or 0, 0.12)
    end
  end
end

function look.open()
  local r = (look.r or R) * 0.94
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.entrance(v[1] * r, v[2] * r, 0.5, 0.5, 0.16)
  end
end

function look.cast(dir, text)
  local f = look.spots[dir]
  look.burst(f)
  look.float(f, text, 8)
end
