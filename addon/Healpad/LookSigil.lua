-- Arcane Sigil: a faint blue rune circle turning slowly; each person a gem
-- with their health as a ring around it; the held heal in a gold diamond in
-- the middle. A beam of light turns to whoever is aimed.
local _, ns = ...
local K = ns.kit
local look = ns.registerLook("sigil", {})

local R = 180
local G = 92 -- a gem with its ring
local RIM, RIM_ON = { 0.59, 0.67, 1, 0.25 }, { 0.78, 0.84, 1, 0.9 }
local NAME, NAME_ON, NAME_FAR = { 0.78, 0.81, 0.94 }, { 1, 0.91, 0.65 }, { 0.54, 0.56, 0.66 }

local function makeGem(c, dir)
  local hub = dir == "SELF"
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(G, G)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(G, G)
  med:SetPoint("CENTER")
  f.med = med
  f.crit = K.glow(med, G + 56, "BACKGROUND", 0, 1, 0.25, 0.15, 0)
  f.crit:SetPoint("CENTER")
  K.pulse(f.crit, 0.35, 1, 0.55)
  if hub then
    f.halo = K.glow(med, 140, "BACKGROUND", 1, 0.67, 0.76, 1, 1)
    f.halo:SetPoint("CENTER")
  end
  f.rim = K.disc(med, G, "BACKGROUND", 2)
  f.rim:SetPoint("CENTER")
  f.rim:SetColorTexture(unpack(RIM))
  local track = K.disc(med, G - 6, "BACKGROUND", 3)
  track:SetPoint("CENTER")
  track:SetColorTexture(0.08, 0.09, 0.2, 0.95)
  -- health fills the ring from the bottom up
  local bar = CreateFrame("StatusBar", nil, med)
  bar:SetSize(G - 6, G - 6)
  bar:SetPoint("CENTER")
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture(K.BAR)
  bar:SetMinMaxValues(0, 1)
  local m = bar:CreateMaskTexture()
  m:SetTexture(K.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(bar)
  bar:GetStatusBarTexture():AddMaskTexture(m)
  f.health = bar
  local core = CreateFrame("Frame", nil, med)
  core:SetAllPoints()
  core:SetFrameLevel(bar:GetFrameLevel() + 2)
  local inner = K.disc(core, G - 16, "BACKGROUND", 0)
  inner:SetPoint("CENTER")
  inner:SetColorTexture(0.06, 0.06, 0.13, 1)
  if hub then
    local edge = K.diamond(core, 46, "ARTWORK", 0)
    edge:SetPoint("CENTER")
    edge:SetVertexColor(0.79, 0.63, 0.3, 1)
    local fill = K.diamond(core, 42, "ARTWORK", 1)
    fill:SetPoint("CENTER")
    fill:SetVertexColor(0.04, 0.04, 0.09, 1)
    f.icon = core:CreateTexture(nil, "ARTWORK", nil, 2)
    f.icon:SetSize(30, 30)
    f.icon:SetPoint("CENTER")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    f.shine = K.glow(core, 84, "BORDER", 0, 1, 1, 1, 0.35)
    f.shine:SetPoint("CENTER")
    f.edge = K.diamond(core, 34, "ARTWORK", 0)
    f.edge:SetPoint("CENTER")
    f.stone = K.diamond(core, 30, "ARTWORK", 1)
    f.stone:SetPoint("CENTER")
    f.spark = K.diamond(core, 10, "ARTWORK", 2)
    f.spark:SetPoint("CENTER", -5, 5)
    f.spark:SetVertexColor(1, 1, 1, 0.35)
  end
  f.state = K.stateIcon(core, 30)
  f.state:SetPoint("CENTER")
  f.hot = K.hotPip(core, 18)
  f.hot:SetPoint("BOTTOMRIGHT", -2, 2)
  f.dispel = K.dispelPip(core, 13)
  f.dispel:SetPoint("TOPRIGHT", -6, -6)
  f.name = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOP", f, "BOTTOM", 0, -2)
  f.name:SetWidth(140)
  f.name:SetWordWrap(false)
  f.entrance = K.entrance(f)
  return f
end

function look.build(stage, fx)
  local c = CreateFrame("Frame", nil, stage)
  c:SetAllPoints()
  c:Hide()
  look.frame = c
  -- the rune circle: two rings turning opposite ways, a ring of dots, four
  -- points at the compass marks
  look.runes = CreateFrame("Frame", nil, c)
  look.runes:SetAllPoints()
  look.outer = look.runes:CreateTexture(nil, "BACKGROUND", nil, 0)
  look.outer:SetTexture(K.RING)
  look.outer:SetBlendMode("ADD")
  look.outer:SetVertexColor(0.55, 0.62, 1, 0.4)
  look.outer:SetPoint("CENTER")
  K.spin(look.outer, 60)
  look.inner = look.runes:CreateTexture(nil, "BACKGROUND", nil, 1)
  look.inner:SetTexture(K.RING)
  look.inner:SetBlendMode("ADD")
  look.inner:SetVertexColor(0.55, 0.62, 1, 0.28)
  look.inner:SetPoint("CENTER")
  K.spin(look.inner, 90, true)
  look.dots = {}
  for i = 1, 40 do
    local t = look.runes:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetSize(2, 2)
    t:SetColorTexture(0.59, 0.67, 1, 0.4)
    look.dots[i] = t
  end
  look.marks = {}
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT" }) do
    local t = K.diamond(look.runes, 6, "BACKGROUND", 3)
    t:SetVertexColor(0.67, 0.75, 1, 0.55)
    look.marks[d] = t
  end
  -- the beam: a soft wide band and a bright thread
  look.beam = {}
  for i, w in ipairs({ 30, 4 }) do
    local l = c:CreateLine(nil, "BACKGROUND", nil, 4 + i)
    l:SetThickness(w)
    l:SetColorTexture(0.63, 0.75, 1, i == 1 and 0.3 or 0.75)
    l:SetBlendMode("ADD")
    l:SetAlpha(0)
    l.a = 0
    look.beam[i] = l
  end
  look.angle = 0
  look.turn = K.tweener(c)
  look.spots = {}
  for _, d in ipairs(ns.DIRS) do
    look.spots[d] = makeGem(c, d)
  end
  local layer = CreateFrame("Frame", nil, fx)
  layer:SetAllPoints()
  look.ripple = K.burst(layer, K.RIPPLE, G, { 0.75, 0.82, 1, 1 }, 0.4, 2.6, 0, 0.7)
  look.ripple2 = K.burst(layer, K.RIPPLE, G - 20, { 0.63, 1, 0.75, 0.9 }, 0.4, 2.6, 0, 0.7, 0.08)
  look.float = K.floater(layer)
end

local function pointBeam(deg)
  local rad = math.rad(deg)
  local s, c = math.sin(rad), math.cos(rad)
  local from, to = 50, (look.r or R) - 40
  for _, l in ipairs(look.beam) do
    l:SetStartPoint("CENTER", look.frame, from * s, from * c)
    l:SetEndPoint("CENTER", look.frame, to * s, to * c)
  end
end

function look.layout(spread)
  local r = R * (1 + (spread - 3) * 0.12)
  look.r = r
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.at = { v[1] * r, v[2] * r }
    f:ClearAllPoints()
    f:SetPoint("CENTER", look.frame, "CENTER", f.at[1], f.at[2])
  end
  local ring = r + 34
  look.outer:SetSize(ring * 2 + 12, ring * 2 + 12)
  look.inner:SetSize(r * 1.3, r * 1.3)
  for i, t in ipairs(look.dots) do
    local a = (i - 1) / #look.dots * 2 * math.pi
    t:ClearAllPoints()
    t:SetPoint("CENTER", look.runes, "CENTER", ring * math.sin(a), ring * math.cos(a))
  end
  for d, t in pairs(look.marks) do
    local v = K.DIR_VEC[d]
    t:ClearAllPoints()
    t:SetPoint("CENTER", look.runes, "CENTER", v[1] * (ring + 10), v[2] * (ring + 10))
  end
  pointBeam(look.angle)
end

function look.draw(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.5)
  f.far, f.dim = far, status ~= nil or far
  K.byHealth(src, "hp", function(r, g, b, a)
    f.health:SetStatusBarColor(r, g, b, a)
  end)
  if f.icon then
    f.icon:SetShown(ctx.spell ~= nil)
    f.icon:SetTexture(ns.spellIcon(ctx.spell))
  end
  if f.stone then
    local r, g, b = K.classColor(src)
    f.stone:SetVertexColor(r, g, b, 1)
    f.shine:SetVertexColor(r, g, b, f.shine.on and 0.9 or 0.35)
    pcall(f.stone.SetDesaturated, f.stone, f.dim)
  end
end

function look.aim(sel)
  for d, f in pairs(look.spots) do
    local on = d == sel
    K.scaleTo(f.med, on and 1.2 or (f.far and 0.86 or 1), 0.1)
    if d ~= "SELF" then
      K.fadeTo(f.med, on and 1 or (f.far and 0.5 or 0.8), 0.12)
    end
    f.rim:SetColorTexture(unpack(on and RIM_ON or RIM))
    f.name:SetTextColor(unpack(f.dim and NAME_FAR or (on and NAME_ON or NAME)))
    if f.edge then
      f.shine.on = on
      f.edge:SetVertexColor(on and 1 or 0.54, on and 0.88 or 0.45, on and 0.48 or 0.25, 1)
    end
  end
  look.spots.SELF.halo:SetAlpha(sel == "SELF" and 1 or 0.2)
  for _, l in ipairs(look.beam) do
    K.fadeTo(l, sel == "SELF" and 0 or 1, 0.15)
  end
  if sel ~= "SELF" and K.DIR_DEG[sel] and look.aimed ~= sel then
    local from = look.angle
    local to = K.turn(from, K.DIR_DEG[sel])
    look.turn(0.16, function(p)
      look.angle = from + (to - from) * p
      pointBeam(look.angle)
    end, K.easeOut)
  end
  look.aimed = sel
end

function look.open()
  local r = (look.r or R) * 0.3
  for d, f in pairs(look.spots) do
    local v = K.DIR_VEC[d]
    f.entrance(v[1] * r, v[2] * r, 0.3, 0.3, 0.18)
  end
end

function look.cast(dir, text)
  local f = look.spots[dir]
  look.ripple(f)
  look.ripple2(f)
  look.float(f, text, 4)
end
