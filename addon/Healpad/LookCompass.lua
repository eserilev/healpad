-- Spellbook Compass: parchment cards in a diamond, each with a class-color
-- stripe, a name and the missing health in big numbers. A compass rose in
-- the middle swings its needle to the aim; the aimed card lifts in gold.
local _, ns = ...
local K = ns.kit
local look = ns.registerLook("compass", {})

local W, H = 168, 62
local AT = { UP = { 0, 158 }, RIGHT = { 200, 0 }, DOWN = { 0, -160 }, LEFT = { -200, 0 }, SELF = { 0, 0 } }
local INK = { 0.23, 0.13, 0.05 }
local PAPER_LO, PAPER_HI = { 0.79, 0.68, 0.45, 1 }, { 0.96, 0.9, 0.76, 1 }

-- Missing health on dark ground, under the rose: light ink.
K.POINTS.missLight = {
  { 0, 1, 0.35, 0.3, 1 },
  { 0.25, 1, 0.35, 0.3, 1 },
  { 0.2501, 1, 0.7, 0.3, 1 },
  { 0.6, 1, 0.7, 0.3, 1 },
  { 0.6001, 0.79, 0.71, 0.54, 1 },
  { 0.995, 0.79, 0.71, 0.54, 1 },
  { 1, 0.79, 0.71, 0.54, 0 },
}

local function flat(fs)
  fs:SetShadowOffset(0, 0)
  fs:SetTextColor(unpack(INK))
end

local function makeCard(c)
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(W, H)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(W, H)
  med:SetPoint("CENTER")
  f.med = med
  local edge = med:CreateTexture(nil, "BACKGROUND", nil, 0)
  edge:SetAllPoints()
  edge:SetColorTexture(0.1, 0.06, 0.02, 1)
  local border = med:CreateTexture(nil, "BACKGROUND", nil, 1)
  border:SetPoint("TOPLEFT", 1, -1)
  border:SetPoint("BOTTOMRIGHT", -1, 1)
  border:SetColorTexture(0.35, 0.26, 0.13, 1)
  f.paper = med:CreateTexture(nil, "BORDER")
  f.paper:SetPoint("TOPLEFT", 2, -2)
  f.paper:SetPoint("BOTTOMRIGHT", -2, 2)
  K.gradient(f.paper, "VERTICAL", PAPER_LO, PAPER_HI)
  f.stripe = med:CreateTexture(nil, "ARTWORK", nil, 0)
  f.stripe:SetPoint("TOPLEFT", 2, -2)
  f.stripe:SetPoint("BOTTOMLEFT", 2, 2)
  f.stripe:SetWidth(6)
  f.name = med:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPLEFT", 16, -8)
  f.name:SetWidth(84)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  flat(f.name)
  f.miss = med:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  f.miss:SetPoint("RIGHT", -12, 7)
  f.miss:SetJustifyH("RIGHT")
  flat(f.miss)
  f.health = K.healthBar(med, W - 28, 5)
  f.health:ClearAllPoints()
  f.health:SetPoint("BOTTOMLEFT", 16, 9)
  f.health:SetPoint("BOTTOMRIGHT", -12, 9)
  f.health.back:SetColorTexture(0.24, 0.14, 0.05, 0.25)
  f.state = K.stateIcon(med, 30)
  f.state:SetPoint("RIGHT", -16, 5)
  f.hot = K.hotPip(med, 14)
  f.hot:SetPoint("TOPLEFT", 16, -30)
  f.dispel = K.dispelPip(med, 11)
  f.dispel:SetPoint("TOPLEFT", 36, -31)
  f.sel = ns.outline(med, med, 0, 2)
  f.sel:SetColor(1, 0.83, 0.35, 1)
  -- the shine that sweeps over a card when it is aimed
  f.shine = med:CreateTexture(nil, "OVERLAY", nil, 2)
  f.shine:SetSize(40, H - 4)
  f.shine:SetPoint("LEFT", 2, 0)
  f.shine:SetTexture(K.SHINE)
  f.shine:SetBlendMode("ADD")
  f.shine:SetVertexColor(1, 0.98, 0.86, 1)
  f.shine:SetAlpha(0)
  local g = f.shine:CreateAnimationGroup()
  local t = g:CreateAnimation("Translation")
  t:SetOffset(W - 44, 0)
  t:SetDuration(0.5)
  t:SetSmoothing("OUT")
  local a1 = g:CreateAnimation("Alpha")
  a1:SetFromAlpha(0)
  a1:SetToAlpha(0.8)
  a1:SetDuration(0.15)
  local a2 = g:CreateAnimation("Alpha")
  a2:SetFromAlpha(0.8)
  a2:SetToAlpha(0)
  a2:SetStartDelay(0.15)
  a2:SetDuration(0.35)
  f.sweep = g
  f.entrance = K.entrance(f)
  return f
end

-- You (or the tap target) in the middle: the compass rose.
local function makeRose(c)
  local S = 130
  local f = CreateFrame("Frame", nil, c)
  f:SetSize(S, S)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  local med = CreateFrame("Frame", nil, f.body)
  med:SetSize(S, S)
  med:SetPoint("CENTER")
  f.med = med
  local edge = K.disc(med, S, "BACKGROUND", 0)
  edge:SetPoint("CENTER")
  edge:SetColorTexture(0.23, 0.16, 0.08, 1)
  local paper = K.disc(med, S - 8, "BACKGROUND", 1)
  paper:SetPoint("CENTER")
  K.gradient(paper, "VERTICAL", { 0.72, 0.6, 0.38, 1 }, { 0.94, 0.88, 0.72, 1 })
  for i = 1, 32 do
    local a = (i - 1) / 32 * 2 * math.pi
    local t = med:CreateTexture(nil, "BORDER", nil, 0)
    t:SetSize(2, 2)
    t:SetColorTexture(0.42, 0.32, 0.19, 1)
    t:SetPoint("CENTER", 52 * math.sin(a), 52 * math.cos(a))
  end
  for i, size in ipairs({ { 7, 106 }, { 106, 7 } }) do
    local t = med:CreateTexture(nil, "BORDER", nil, i)
    t:SetSize(size[1], size[2])
    t:SetPoint("CENTER")
    t:SetColorTexture(i == 1 and 0.35 or 0.48, i == 1 and 0.24 or 0.35, i == 1 and 0.11 or 0.19, 1)
  end
  local mid = K.diamond(med, 20, "BORDER", 3)
  mid:SetPoint("CENTER")
  mid:SetVertexColor(0.35, 0.24, 0.11, 1)
  -- the needle: red toward the aim, dark behind
  f.needle = {}
  for i, spec in ipairs({ { 2, 0.2, 0.12, 0.05 }, { 4, 0.69, 0.08, 0.05 } }) do
    local l = med:CreateLine(nil, "ARTWORK", nil, i)
    l:SetThickness(spec[1])
    l:SetColorTexture(spec[2], spec[3], spec[4], 1)
    f.needle[i] = l
  end
  f.pinGlow = K.glow(med, 64, "ARTWORK", 3, 1, 0.82, 0.31, 1)
  f.pinGlow:SetPoint("CENTER")
  local pin = K.disc(med, 20, "OVERLAY", 0)
  pin:SetPoint("CENTER")
  K.gradient(pin, "VERTICAL", { 0.45, 0.28, 0.06, 1 }, { 1, 0.9, 0.6, 1 })
  f.state = K.stateIcon(med, 34)
  f.state:SetPoint("CENTER", 0, 26)
  f.hot = K.hotPip(med, 18)
  f.hot:SetPoint("BOTTOMRIGHT", -8, 8)
  f.dispel = K.dispelPip(med, 13)
  f.dispel:SetPoint("TOPRIGHT", -12, -12)
  f.name = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPRIGHT", f, "BOTTOM", -6, -6)
  f.name:SetJustifyH("RIGHT")
  f.name:SetWidth(110)
  f.name:SetWordWrap(false)
  f.dot = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.dot:SetPoint("TOP", f, "BOTTOM", 0, -6)
  f.dot:SetText("·")
  f.miss = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.miss:SetPoint("TOPLEFT", f, "BOTTOM", 6, -6)
  f.miss:SetJustifyH("LEFT")
  f.entrance = K.entrance(f)
  return f
end

local function pointNeedle(deg)
  local rad = math.rad(deg)
  local s, c = math.sin(rad), math.cos(rad)
  local rose = look.spots.SELF
  local tip, tail = rose.needle[2], rose.needle[1]
  tip:SetStartPoint("CENTER", rose.med, 0, 0)
  tip:SetEndPoint("CENTER", rose.med, 47 * s, 47 * c)
  tail:SetStartPoint("CENTER", rose.med, 0, 0)
  tail:SetEndPoint("CENTER", rose.med, -30 * s, -30 * c)
end

function look.build(stage, fx)
  local c = CreateFrame("Frame", nil, stage)
  c:SetAllPoints()
  c:Hide()
  look.frame = c
  -- every look takes about the same room on screen at the same Size
  c:SetScale(0.95)
  look.spots = {}
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT" }) do
    look.spots[d] = makeCard(c)
  end
  look.spots.SELF = makeRose(c)
  look.angle = 0
  look.swing = K.tweener(c)
  pointNeedle(0)
  local layer = CreateFrame("Frame", nil, fx)
  layer:SetAllPoints()
  -- the stamp a heal leaves on a card
  local stamp = CreateFrame("Frame", nil, layer)
  stamp:SetSize(W, H)
  stamp:SetAlpha(0)
  local wash = stamp:CreateTexture(nil, "ARTWORK")
  wash:SetAllPoints()
  wash:SetColorTexture(0.96, 0.9, 0.76, 0.6)
  stamp.text = stamp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  stamp.text:SetPoint("CENTER")
  stamp.text:SetShadowOffset(0, 0)
  stamp.text:SetTextColor(0.18, 0.48, 0.11)
  local g = stamp:CreateAnimationGroup()
  local thump = g:CreateAnimation("Scale")
  thump:SetScaleFrom(1.35, 1.35)
  thump:SetScaleTo(1, 1)
  thump:SetDuration(0.15)
  local fade = g:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0)
  fade:SetDuration(0.9)
  fade:SetSmoothing("IN")
  look.stamp = function(card, text)
    stamp:ClearAllPoints()
    stamp:SetPoint("CENTER", card, "CENTER")
    stamp.text:SetText(text or "")
    g:Stop()
    g:Play()
  end
  look.float = K.floater(layer)
end

-- how near a card may come to the rose in the middle (130 across)
local TOUCH = { UP = { 0, 65 + H / 2 }, RIGHT = { 65 + W / 2, 0 }, DOWN = { 0, -(65 + H / 2) }, SELF = { 0, 0 } }
TOUCH.LEFT = { -TOUCH.RIGHT[1], 0 }

function look.layout(spacing)
  for d, f in pairs(look.spots) do
    f.at = { K.space(AT[d][1], TOUCH[d][1], spacing), K.space(AT[d][2], TOUCH[d][2], spacing) }
    f:ClearAllPoints()
    f:SetPoint("CENTER", look.frame, "CENTER", f.at[1], f.at[2])
  end
end

function look.draw(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.55)
  f.far = far
  local rose = f == look.spots.SELF
  if status then
    f.miss:SetText("")
  else
    K.missing(f.miss, src)
    if rose then
      K.byHealth(src, "missLight", function(r, g, b, a)
        f.miss:SetTextColor(r, g, b, a)
      end)
    end
  end
  if rose then
    f.dot:SetShown(not status)
    return
  end
  f.dim = status ~= nil or far
  f.name:SetTextColor(INK[1], INK[2], INK[3], f.dim and 0.55 or 1)
  local r, g, b = K.classColor(src)
  f.stripe:SetColorTexture(r, g, b, 1)
  pcall(f.paper.SetDesaturated, f.paper, f.dim)
  K.byHealth(src, "hp", function(hr, hg, hb, ha)
    f.health:SetStatusBarColor(hr, hg, hb, ha)
  end)
end

function look.aim(sel)
  for d, f in pairs(look.spots) do
    if d ~= "SELF" then
      local on = d == sel
      local k = on and 1.12 or (f.far and 0.9 or 1)
      K.scaleTo(f.med, k, 0.12)
      -- sel nil: the plus at rest, nobody dimmed
      K.fadeTo(f.med, on and 1 or (f.far and 0.55 or (sel == nil and 1 or 0.86)), 0.12)
      f.med:ClearAllPoints()
      f.med:SetPoint("CENTER", f, "CENTER", 0, on and 5 / k or 0)
      f.sel:SetShown(on)
      f:SetFrameLevel(on and 20 or 5)
    end
  end
  local rose = look.spots.SELF
  rose.pinGlow:SetAlpha(sel == "SELF" and 1 or 0)
  rose.name:SetTextColor(sel == "SELF" and 1 or 0.79, sel == "SELF" and 0.83 or 0.71, sel == "SELF" and 0.35 or 0.54)
  rose.dot:SetTextColor(0.79, 0.71, 0.54)
  if sel ~= "SELF" and K.DIR_DEG[sel] and look.aimed ~= sel then
    local from = look.angle
    local to = K.turn(from, K.DIR_DEG[sel])
    look.swing(0.22, function(p)
      look.angle = from + (to - from) * p
      pointNeedle(look.angle)
    end, K.easeBack)
  end
  look.aimed = sel
end

function look.open()
  local delay = { UP = 0, RIGHT = 0.04, DOWN = 0.08, LEFT = 0.12, SELF = 0 }
  for d, f in pairs(look.spots) do
    if d == "SELF" then
      f.entrance(0, 0, 0.6, 0.6, 0.18)
    else
      f.entrance(0, 0, 1, 0.1, 0.22, delay[d])
    end
  end
end

function look.cast(dir, text)
  local f = look.spots[dir]
  if dir == "SELF" then
    look.float(f, text, -40)
  else
    look.stamp(f, text)
  end
end
