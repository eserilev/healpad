-- The looks of the aim menu: four ways to draw the same people. A look is a
-- table registered here and built the first time it is chosen:
--   build(root, fx)     makes its frames: look.frame holds them, look.spots[dir]
--                       the people (each with .name, and .med, the part that grows)
--   layout(spacing)     puts the people in place; spacing (0.6 to 1.4, 1 the
--                       usual) scales the room between them, never below 0
--   draw(f, src, ctx)   one person; src is a unit, a sample or the empty Target
--   aim(sel, ctx)       who is aimed: sizes, dimming, pointers
--   open()              the menu opens
--   cast(dir, text)     a heal went to the person at dir (drawn on fx, which
--                       stays up after the menu closes)
-- The kit below is what the four share. Health and the like are secret in
-- combat: every read that may be secret goes straight to the game's widgets
-- or through a curve, and nothing here compares or adds one.
local _, ns = ...

local K = {}
ns.kit = K
ns.looks = {}
ns.LOOKS = { "classic", "medallions", "sigil", "compass" }
ns.LOOK_LABEL = { medallions = "Medallions", sigil = "Sigil", compass = "Compass", classic = "Classic" }

-- Where a person sits with that spacing: touch is the distance at which
-- they would touch the middle one, at the usual one; spacing scales the gap.
function K.space(at, touch, spacing)
  return touch + (at - touch) * spacing
end

function ns.registerLook(name, look)
  look.name = name
  ns.looks[name] = look
  return look
end

-- Textures the game's own UI uses.
K.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
K.SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
K.PLUG = "Interface\\CharacterFrame\\Disconnect-Icon"
K.STAR = "Interface\\Cooldown\\star4"
K.RING = "Interface\\minimap\\UI-Minimap-Ping-Rotate"
K.RIPPLE = "Interface\\minimap\\UI-Minimap-Ping-Expand"
K.GLOW = "Interface\\minimap\\UI-Minimap-Ping-Center"
K.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
K.SHINE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
K.CLASSES = "Interface\\TargetingFrame\\UI-Classes-Circles"

K.GOLD = { 1, 0.82, 0 }
K.DIR_DEG = { UP = 0, RIGHT = 90, DOWN = 180, LEFT = 270 }
K.DIR_VEC = { UP = { 0, 1 }, RIGHT = { 1, 0 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, SELF = { 0, 0 } }

---------------------------------------------------------------- colors by health

-- Linear points { x, r, g, b, a }: the same numbers go to the game's curves
-- (secret health) and to K.eval (the sample people).
K.POINTS = {
  -- green, yellow, red
  hp = {
    { 0, 0.84, 0.19, 0.14, 1 },
    { 0.25, 0.84, 0.19, 0.14, 1 },
    { 0.6, 0.9, 0.77, 0.16, 1 },
    { 1, 0.27, 0.75, 0.24, 1 },
  },
  -- under a quarter: the red pulse shows
  crit = {
    { 0, 1, 0.16, 0.1, 1 },
    { 0.25, 1, 0.16, 0.1, 1 },
    { 0.2501, 0, 0, 0, 0 },
    { 1, 0, 0, 0, 0 },
  },
  -- the Compass's missing health: red, brown, ink, gone at full health
  miss = {
    { 0, 0.56, 0.07, 0.03, 1 },
    { 0.25, 0.56, 0.07, 0.03, 1 },
    { 0.2501, 0.42, 0.23, 0.05, 1 },
    { 0.6, 0.42, 0.23, 0.05, 1 },
    { 0.6001, 0.23, 0.13, 0.05, 0.6 },
    { 0.995, 0.23, 0.13, 0.05, 0.6 },
    { 1, 0.23, 0.13, 0.05, 0 },
  },
}

function K.eval(points, x)
  if x <= points[1][1] then
    return points[1][2], points[1][3], points[1][4], points[1][5]
  end
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if x <= b[1] then
      local t = (x - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t, a[5] + (b[5] - a[5]) * t
    end
  end
  local p = points[#points]
  return p[2], p[3], p[4], p[5]
end

local curves
local function curves_()
  if curves then
    return curves
  end
  curves = {}
  for name, points in pairs(K.POINTS) do
    pcall(function()
      local c = C_CurveUtil.CreateColorCurve()
      pcall(c.SetType, c, Enum.LuaCurveType.Linear)
      for _, p in ipairs(points) do
        c:AddPoint(p[1], CreateColor(p[2], p[3], p[4], p[5]))
      end
      curves[name] = c
    end)
  end
  return curves
end

function K.secret(v)
  if not issecretvalue then
    return false
  end
  local ok, s = pcall(issecretvalue, v)
  return not ok or s == true
end

-- Health as a plain fraction when it can be known, else nil.
function K.percent(src)
  if not src.unit then
    return src.hp
  end
  local ok, h, m = pcall(UnitHealth, src.unit)
  if ok then
    ok, m = pcall(UnitHealthMax, src.unit)
  end
  if not ok or K.secret(h) or K.secret(m) or type(h) ~= "number" or type(m) ~= "number" or m <= 0 then
    return nil
  end
  return h / m
end

-- fn(r, g, b, a): this person's health on the curve `which`. The values may
-- be secret; fn only hands them to the game. Unknown health counts as full.
function K.byHealth(src, which, fn)
  local points = K.POINTS[which]
  if src.unit then
    local c = curves_()[which]
    if
      c
      and UnitHealthPercent
      and pcall(function()
        fn(UnitHealthPercent(src.unit, true, c):GetRGBA())
      end)
    then
      return
    end
    return fn(K.eval(points, K.percent(src) or 1))
  end
  return fn(K.eval(points, src.hp or 0))
end

---------------------------------------------------------------- reads

-- "dead", "offline", "empty" (the Target spot with nobody) or nil.
function K.status(src)
  if src.kind == "empty" then
    return "empty"
  end
  if not src.unit then
    return src.status
  end
  local ok, res = pcall(function()
    if UnitIsConnected(src.unit) == false then
      return "offline"
    end
    if UnitIsDeadOrGhost(src.unit) then
      return "dead"
    end
    return nil
  end)
  return ok and res or nil
end

function K.name(fs, src)
  if src.unit then
    if not pcall(fs.SetText, fs, UnitName(src.unit)) then
      fs:SetText("")
    end
  else
    fs:SetText(src.name or "")
  end
end

function K.classFile(src)
  if not src.unit then
    return src.class
  end
  local ok, _, file = pcall(UnitClass, src.unit)
  if ok and not K.secret(file) then
    return file
  end
end

function K.classColor(src)
  local ok, r, g, b = pcall(function()
    local c = RAID_CLASS_COLORS[K.classFile(src)]
    return c.r, c.g, c.b
  end)
  if ok and r then
    return r, g, b
  end
  return 0.62, 0.6, 0.56
end

-- A round class icon, for people with no portrait to show.
function K.classFace(tex, class)
  local ok = pcall(function()
    local c = CLASS_ICON_TCOORDS[class]
    tex:SetTexture(K.CLASSES)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  end)
  if not ok then
    tex:SetColorTexture(0.25, 0.22, 0.18, 1)
  end
end

function K.face(tex, src)
  tex:SetTexCoord(0, 1, 0, 1)
  if src.kind == "empty" then
    tex:SetColorTexture(0.1, 0.1, 0.1, 1)
  elseif src.unit or src.face then
    pcall(SetPortraitTexture, tex, src.unit or src.face)
  else
    K.classFace(tex, src.class)
  end
end

function K.health(bar, src)
  if src.unit then
    if
      pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(src.unit))
      and pcall(bar.SetValue, bar, UnitHealth(src.unit))
    then
      return
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(src.kind == "empty" and 0 or src.hp or 0)
end

-- Incoming heals, at the health bar's scale.
function K.incoming(bar, src)
  if src.unit then
    if
      not (
        pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(src.unit))
        and pcall(function()
          bar:SetValue(UnitGetIncomingHeals(src.unit))
        end)
      )
    then
      bar:SetValue(0)
    end
    return
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(src.inc or 0)
end

function K.commas(n)
  local s = tostring(math.floor(n + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

-- "-2,580": missing health. In combat the game breaks up the secret number
-- itself; the color curve hides it at full health.
function K.missing(fs, src)
  if src.unit then
    local unit = src.unit
    local ok = pcall(function()
      fs:SetFormattedText("-%s", BreakUpLargeNumbers(UnitHealthMissing(unit, true)))
    end) or pcall(function()
      fs:SetFormattedText("-%d", UnitHealthMissing(unit, true))
    end)
    if not ok then
      fs:SetText("")
    end
  else
    fs:SetText("-" .. K.commas(src.miss or 0))
  end
  K.byHealth(src, "miss", function(r, g, b, a)
    fs:SetTextColor(r, g, b, a)
  end)
end

-- The colors of the debuff types, as the curve below gives them.
local DISPEL = {
  Magic = { 0.2, 0.6, 1 },
  Curse = { 0.6, 0, 1 },
  Disease = { 0.6, 0.4, 0 },
  Poison = { 0, 0.6, 0 },
}

local dispelCurve
local function dispelColors()
  if dispelCurve ~= nil then
    return dispelCurve
  end
  dispelCurve = false
  pcall(function()
    local c = C_CurveUtil.CreateColorCurve()
    pcall(c.SetType, c, Enum.LuaCurveType.Step)
    c:AddPoint(0, CreateColor(0, 0, 0, 0))
    c:AddPoint(1, CreateColor(0.2, 0.6, 1, 1)) -- magic
    c:AddPoint(2, CreateColor(0.6, 0, 1, 1)) -- curse
    c:AddPoint(3, CreateColor(0.6, 0.4, 0, 1)) -- disease
    c:AddPoint(4, CreateColor(0, 0.6, 0, 1)) -- poison
    dispelCurve = c
  end)
  return dispelCurve
end

-- Aura n of a filter on a unit, or nil. Every read is guarded: the game
-- may refuse a party member's auras to addons in combat.
local function aura(unit, n, filter)
  local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, n, filter)
  if ok and type(a) == "table" then
    return a
  end
end

-- An aura's icon on a little square (debuff and HoT icons).
local function setIcon(icon, a)
  if not pcall(icon.tex.SetTexture, icon.tex, a.icon) then
    icon.tex:SetColorTexture(0.3, 0.3, 0.3, 1)
  end
end

-- The stack count: the game's own words for it (secret-safe), else the
-- number when it's plain and more than one.
local function setCount(fs, unit, a)
  local ok = pcall(function()
    fs:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, a.auraInstanceID, 2))
  end)
  if not ok then
    local n = a.applications
    fs:SetText((type(n) == "number" and not K.secret(n) and n > 1) and tostring(n) or "")
  end
end

-- The clock on a HoT: from the aura's duration object, which may be set
-- while secret; else from plain times; else no clock.
local function setClock(cd, unit, a)
  local ok = pcall(function()
    cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, a.auraInstanceID))
  end)
  if not ok then
    ok = pcall(function()
      local d, e = a.duration, a.expirationTime
      if K.secret(d) or K.secret(e) or type(d) ~= "number" or d <= 0 then
        error("no time")
      end
      cd:SetCooldown(e - d, d)
    end)
  end
  cd:SetShown(ok)
end

-- Shown or hidden by a yes or no that may be secret: a secret one goes to
-- the game as the region's alpha.
function K.showIf(region, v)
  if K.secret(v) then
    region:Show()
    if not pcall(region.SetAlphaFromBoolean, region, v, 1, 0) then
      region:Hide()
    end
    return
  end
  region:SetAlpha(1)
  region:SetShown(v == true)
end

-- Your own long buffs (an hour's Mark of the Wild, Fortitude...), learned
-- from what you cast on yourself: classes here have their own spells, so
-- none is named. { [name] = icon }, kept in the saved settings.
function K.learnBuffs()
  if InCombatLockdown() or not ns.db then
    return
  end
  ns.db.buffs = ns.db.buffs or {}
  for i = 1, 40 do
    local a = aura("player", i, "HELPFUL|PLAYER")
    if not a then
      break
    end
    pcall(function()
      if K.secret(a.duration) or K.secret(a.spellId) then
        return
      end
      local mine = a.sourceUnit == "player"
      if mine and type(a.duration) == "number" and a.duration >= 600 and ns.isHeal(a.spellId) then
        local name = C_Spell.GetSpellName(a.spellId)
        if name and not ns.db.buffs[name] then
          ns.db.buffs[name] = a.icon or 136243
        end
      end
    end)
  end
end

local function has(unit, name)
  local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
  if not ok then
    return nil -- the game won't say
  end
  return a ~= nil
end

-- Your buffs someone else in the group has right now: the ones you keep
-- up on the party (Fortitude, Mark of the Wild), not ones you put on one
-- person (Fear Ward, Thorns). Looked at twice a second at most.
local kept, keptAt
local function keptBuffs()
  local now = GetTime()
  if kept and keptAt and now - keptAt < 0.5 then
    return kept
  end
  kept, keptAt = {}, now
  local units = {}
  if IsInRaid() then
    for i = 1, 40 do
      units[#units + 1] = "raid" .. i
    end
  else
    for i = 1, 4 do
      units[#units + 1] = "party" .. i
    end
  end
  for name, icon in pairs(ns.db.buffs) do
    for _, u in ipairs(units) do
      if not kept[name] and UnitExists(u) and not UnitIsUnit(u, "player") and has(u, name) then
        kept[name] = icon
      end
    end
  end
  return kept
end

-- The icon of a buff you keep up on the group that this person lacks, out
-- of combat; nil when they have them all (or in combat, or when the game
-- won't say).
function K.missingBuff(unit)
  if InCombatLockdown() or not (ns.db and ns.db.buffs) then
    return nil
  end
  for name, icon in pairs(keptBuffs()) do
    if has(unit, name) == false then
      return icon
    end
  end
end

-- Out of range of the held spell. Returns far (true when it is known), and
-- when the answer is secret (in combat) true and the secret answer, for
-- K.fade to hand to the game.
function K.range(src, spell)
  if not src.unit then
    return src.far == true, false
  end
  if not spell then
    return false, false
  end
  local ok, r = pcall(C_Spell.IsSpellInRange, spell, src.unit)
  if not ok then
    return false, false
  end
  if K.secret(r) then
    return false, true, r
  end
  return r == false, false
end

-- Faded and grey while out of range, from a secret answer: the game picks.
function K.fade(frame, inRange, low, texs)
  pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, low)
  for _, t in ipairs(texs or {}) do
    pcall(function()
      t:SetDesaturation(C_CurveUtil.EvaluateColorValueFromBoolean(inRange, 0, 1))
    end)
  end
end

---------------------------------------------------------------- parts

function K.disc(parent, size, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  t:SetSize(size, size)
  local m = parent:CreateMaskTexture()
  m:SetTexture(K.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(t)
  t:AddMaskTexture(m)
  return t
end

function K.gradient(tex, orient, a, b)
  tex:SetColorTexture(1, 1, 1, 1)
  if not pcall(tex.SetGradient, tex, orient, CreateColor(unpack(a)), CreateColor(unpack(b))) then
    tex:SetColorTexture(unpack(b))
  end
end

-- A square turned on its point.
function K.diamond(parent, size, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
  t:SetSize(size, size)
  t:SetColorTexture(1, 1, 1, 1)
  pcall(t.SetRotation, t, math.pi / 4)
  return t
end

function K.glow(parent, size, layer, sub, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetSize(size, size)
  t:SetTexture(K.GLOW)
  t:SetBlendMode("ADD")
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

-- A thin edge around a region, colored by vertex color so a secret
-- color can go straight to it. Hidden until shown.
function K.edge(parent, region, pad, size)
  local o = CreateFrame("Frame", nil, parent)
  o:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad)
  o:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad)
  o.lines = {}
  for i, side in ipairs({
    { "TOPLEFT", "TOPRIGHT", "h" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" },
    { "TOPRIGHT", "BOTTOMRIGHT", "w" },
  }) do
    local t = o:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "h" then
      t:SetHeight(size)
    else
      t:SetWidth(size)
    end
    t:SetColorTexture(1, 1, 1, 1)
    o.lines[i] = t
  end
  function o.SetColor(_, r, g, b, a)
    for _, t in ipairs(o.lines) do
      t:SetVertexColor(r, g, b, a)
    end
  end
  o:Hide()
  return o
end

-- A little aura icon: a dark rim, the icon, a stack count, and for a HoT a
-- clock that empties as it runs out (no edge, no flash).
local function auraIcon(parent, size, clock)
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(size, size)
  local rim = p:CreateTexture(nil, "OVERLAY", nil, 4)
  rim:SetAllPoints()
  rim:SetColorTexture(0, 0, 0, 1)
  p.tex = p:CreateTexture(nil, "OVERLAY", nil, 5)
  p.tex:SetPoint("TOPLEFT", 1, -1)
  p.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if clock then
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, p, "CooldownFrameTemplate")
    if ok and cd then
      cd:SetAllPoints(p.tex)
      pcall(cd.SetDrawEdge, cd, false)
      pcall(cd.SetDrawBling, cd, false)
      pcall(cd.SetHideCountdownNumbers, cd, true)
      pcall(cd.SetReverse, cd, true)
      cd:Hide()
      p.clock = cd
    end
  end
  p.count = p:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  p.count:SetPoint("BOTTOMRIGHT", 2, -2)
  p:Hide()
  return p
end

-- Everything a person's frame shows besides health and name, on f:
--   edge      the frame's edge in a removable debuff's color
--   tint      the health bar's back in that color
--   debuffs   two removable debuffs with their stacks
--   hots      two of your HoTs with their clocks
--   aggro     a red bar along the top while a mob is on them
--   rez       a resurrection on the way, over the portrait
--   buff      one of your buffs they lack (out of combat)
-- spec: edge (the region to edge; default f.med), pad and line size; size
-- of the icons; debuffs and hots ({ point, relative, relativePoint, x, y }
-- of the first icon, the second beside it; debuffsGrow or hotsGrow -1: to
-- its left); top (the
-- region the aggro bar sits on), rez (the region it covers), buff (anchor).
function K.indicators(f, spec)
  local host = spec.host or f.med or f
  local size = spec.size or 14
  f.edge = K.edge(host, spec.edge or host, spec.pad or 1, spec.line or 2)
  if f.health and f.health.back then
    local tint = f.health:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetColorTexture(1, 1, 1, 1)
    tint:SetAlpha(0.6)
    tint:Hide()
    f.tint = tint
  end
  local function row(anchor, clock, grow)
    grow = grow or 1
    local list = {}
    for i = 1, 2 do
      local icon = auraIcon(host, size, clock)
      if i == 1 then
        icon:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
      else
        icon:SetPoint(grow > 0 and "LEFT" or "RIGHT", list[1], grow > 0 and "RIGHT" or "LEFT", 2 * grow, 0)
      end
      list[i] = icon
    end
    return list
  end
  f.debuffs = row(spec.debuffs, false, spec.debuffsGrow)
  f.hots = row(spec.hots, true, spec.hotsGrow)
  local top = spec.top or host
  f.aggro = host:CreateTexture(nil, "OVERLAY", nil, 7)
  f.aggro:SetPoint("BOTTOMLEFT", top, "TOPLEFT", 0, 1)
  f.aggro:SetPoint("BOTTOMRIGHT", top, "TOPRIGHT", 0, 1)
  f.aggro:SetHeight(3)
  f.aggro:SetColorTexture(0.9, 0.08, 0.05, 1)
  f.aggro:Hide()
  local over = spec.rez or host
  f.rez = host:CreateTexture(nil, "OVERLAY", nil, 7)
  f.rez:SetSize(spec.rezSize or 22, spec.rezSize or 22)
  f.rez:SetPoint("CENTER", over, "CENTER")
  if not pcall(f.rez.SetAtlas, f.rez, "RaidFrame-Icon-Rez") then
    f.rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
  end
  f.rez:Hide()
  f.buff = K.disc(host, spec.buffSize or 10, "OVERLAY", 7)
  local b = spec.buff or { "TOPRIGHT", host, "TOPRIGHT", -2, -2 }
  f.buff:SetPoint(b[1], b[2], b[3], b[4], b[5])
  f.buff:Hide()
end

local function hideAll(f)
  f.edge:Hide()
  if f.tint then
    f.tint:Hide()
  end
  for _, icon in ipairs(f.debuffs) do
    icon:Hide()
  end
  for _, icon in ipairs(f.hots) do
    icon:Hide()
  end
  f.aggro:Hide()
  f.rez:Hide()
  f.buff:Hide()
end

-- An example person's markers (the settings' preview).
local SAMPLE_ICON = "Interface\\Icons\\Spell_Holy_Renew"
local function sampleMarkers(f, src, status)
  local dispel = src.dispel ~= nil and (not ns.stage or ns.stage.dispel ~= false) and status == nil
  if dispel then
    f.edge:SetColor(unpack(src.dispel))
    f.edge:Show()
    if f.tint then
      f.tint:SetVertexColor(unpack(src.dispel))
      f.tint:Show()
    end
    local d = f.debuffs[1]
    d.tex:SetTexture("Interface\\Icons\\Spell_Holy_DispelMagic")
    d.count:SetText("")
    d:Show()
  end
  if src.hot and status == nil then
    local icon = ns.previewSpell and ns.spellIcon(ns.previewSpell)
    local h = f.hots[1]
    h.tex:SetTexture((icon and icon ~= 134400) and icon or SAMPLE_ICON)
    h.count:SetText("")
    h:Show()
  end
end

-- Draws f's markers for src. status: K.status's word, nil when alive.
function K.markers(f, src, status)
  if not f.edge then
    return
  end
  hideAll(f)
  if not src.unit then
    return sampleMarkers(f, src, status)
  end
  local unit = src.unit
  if status == "dead" then
    local ok, v = pcall(UnitHasIncomingResurrection, unit)
    if ok then
      K.showIf(f.rez, v)
    end
    return
  end
  if status then
    return
  end
  -- debuffs you can remove: the first one's color on the edge and the bar
  for i = 1, 2 do
    local a = aura(unit, i, "HARMFUL|RAID")
    if not a then
      break
    end
    local icon = f.debuffs[i]
    setIcon(icon, a)
    setCount(icon.count, unit, a)
    icon:Show()
    if i == 1 then
      local ok = pcall(function()
        local color = C_UnitAuras.GetAuraDispelTypeColor(unit, a.auraInstanceID, dispelColors())
        f.edge:SetColor(color:GetRGBA())
        f.edge:Show()
        if f.tint then
          f.tint:SetVertexColor(color:GetRGBA())
          f.tint:Show()
        end
      end)
      -- no color from the game: out of combat the debuff's type says it
      local c = not ok and not InCombatLockdown() and not K.secret(a.dispelName) and DISPEL[a.dispelName]
      if c then
        f.edge:SetColor(c[1], c[2], c[3], 1)
        f.edge:Show()
        if f.tint then
          f.tint:SetVertexColor(c[1], c[2], c[3], 1)
          f.tint:Show()
        end
      end
    end
  end
  -- your heals over time
  for i = 1, 2 do
    local a = aura(unit, i, "HELPFUL|PLAYER|RAID_IN_COMBAT")
    if not a then
      break
    end
    local icon = f.hots[i]
    setIcon(icon, a)
    setCount(icon.count, unit, a)
    if icon.clock then
      setClock(icon.clock, unit, a)
    end
    icon:Show()
  end
  -- aggro: only from a plain answer; a secret one can't become a yes or no
  -- outside the game's own code, so in that case no bar.
  local okT, threat = pcall(UnitThreatSituation, unit)
  if okT and type(threat) == "number" and not K.secret(threat) then
    f.aggro:SetShown(threat >= 2)
  end
  local missing = K.missingBuff(unit)
  if missing then
    f.buff:SetTexture(missing)
    f.buff:Show()
  end
end

-- The skull or the unplugged cable.
function K.stateIcon(parent, size, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, 7)
  t:SetSize(size, size)
  t:Hide()
  return t
end
function K.setState(t, status)
  if status == "dead" then
    t:SetTexture(K.SKULL)
    t:Show()
  elseif status == "offline" then
    t:SetTexture(K.PLUG)
    t:Show()
  else
    t:Hide()
  end
end

-- A horizontal health bar, incoming heals after it.
function K.healthBar(parent, w, h)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(K.BAR)
  bar:SetMinMaxValues(0, 1)
  bar.back = bar:CreateTexture(nil, "BACKGROUND")
  bar.back:SetAllPoints()
  bar.incoming = CreateFrame("StatusBar", nil, bar)
  bar.incoming:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
  bar.incoming:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
  bar.incoming:SetWidth(w)
  bar.incoming:SetStatusBarTexture(K.BAR)
  bar.incoming:SetStatusBarColor(0.6, 1, 0.6, 0.4)
  bar.incoming:SetMinMaxValues(0, 1)
  bar.incoming:SetValue(0)
  return bar
end

-- What every look shows of a person, on the parts its spot has: name, health
-- (bar and incoming), face, markers (K.indicators), state (icon), crit and body
-- (the frame that fades out of range). Returns the status and far.
function K.person(f, src, ctx, farAlpha)
  local status = K.status(src)
  if f.name then
    K.name(f.name, src)
  end
  if f.health then
    K.health(f.health, src)
    if f.health.incoming then
      K.incoming(f.health.incoming, src)
    end
  end
  if f.face then
    K.face(f.face, src)
    pcall(f.face.SetDesaturated, f.face, status ~= nil)
  end
  local alive = status == nil
  -- dead or offline: the bar empties
  if f.health and (status == "dead" or status == "offline") then
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(0)
    if f.health.incoming then
      f.health.incoming:SetValue(0)
    end
  end
  K.markers(f, src, status)
  if f.state then
    K.setState(f.state, status)
  end
  if f.crit then
    if alive then
      K.byHealth(src, "crit", function(r, g, b, a)
        f.crit:SetVertexColor(r, g, b, a)
      end)
    else
      f.crit:SetVertexColor(1, 0.16, 0.1, 0)
    end
  end
  local far, hidden, inRange = K.range(src, ctx.spell)
  f.body:SetAlpha(status == "empty" and 0.45 or 1)
  if f.face then
    pcall(f.face.SetDesaturation, f.face, (status or far) and 1 or 0)
  end
  if hidden then
    K.fade(f.body, inRange, farAlpha or 0.6, { f.face })
  end
  return status, far
end

---------------------------------------------------------------- motion

function K.spin(region, seconds, backwards)
  local g = region:CreateAnimationGroup()
  g:SetLooping("REPEAT")
  local r = g:CreateAnimation("Rotation")
  r:SetDegrees(backwards and 360 or -360)
  r:SetDuration(seconds)
  g:Play()
  return g
end

function K.pulse(region, lo, hi, seconds)
  local g = region:CreateAnimationGroup()
  g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(lo)
  a:SetToAlpha(hi)
  a:SetDuration(seconds)
  a:SetSmoothing("IN_OUT")
  g:Play()
  return g
end

-- Grows or shrinks a frame anchored by its center: it is set to the new size
-- at once and an animation runs from the old size to it.
function K.scaleTo(frame, k, seconds)
  local from = frame.k or 1
  if from == k then
    return
  end
  frame.k = k
  frame:SetScale(k)
  if not frame.grow then
    local g = frame:CreateAnimationGroup()
    local s = g:CreateAnimation("Scale")
    s:SetOrigin("CENTER", 0, 0)
    s:SetSmoothing("OUT")
    frame.grow = { g = g, s = s }
  end
  local a = frame.grow
  a.g:Stop()
  a.s:SetScaleFrom(from / k, from / k)
  a.s:SetScaleTo(1, 1)
  a.s:SetDuration(seconds or 0.1)
  a.g:Play()
end

-- Fades a frame from where it is to alpha a.
function K.fadeTo(frame, a, seconds)
  local from = frame.a or 1
  if from == a then
    return
  end
  frame.a = a
  frame:SetAlpha(a)
  if not frame.fading then
    local g = frame:CreateAnimationGroup()
    g:SetToFinalAlpha(true)
    local an = g:CreateAnimation("Alpha")
    frame.fading = { g = g, a = an }
  end
  local f = frame.fading
  f.g:Stop()
  f.a:SetFromAlpha(from)
  f.a:SetToAlpha(a)
  f.a:SetDuration(seconds or 0.12)
  f.g:Play()
end

-- tween(seconds, fn, ease): fn(p) every frame while p goes from 0 to 1,
-- driven by an animation; fn(1) at the end. Without animations, fn(1) now.
function K.tweener(owner)
  local g = owner:CreateAnimationGroup()
  local a = g:CreateAnimation("Translation")
  a:SetOffset(0, 0)
  local fn, ease
  a:SetScript("OnUpdate", function()
    local p = a:GetProgress() or 0
    if fn then
      fn(ease and ease(p) or p)
    end
  end)
  g:SetScript("OnFinished", function()
    if fn then
      fn(1)
    end
  end)
  return function(seconds, f, e)
    g:Stop()
    fn, ease = f, e
    a:SetDuration(seconds)
    g:Play()
    if not g:IsPlaying() then
      f(1)
    end
  end
end

function K.easeOut(p)
  return 1 - (1 - p) * (1 - p)
end
-- Overshoots a little and settles, like a compass needle.
function K.easeBack(p)
  local c = 2.2
  return 1 + (c + 1) * (p - 1) ^ 3 + c * (p - 1) ^ 2
end

-- The shortest turn from the angle cur to the direction want (degrees).
function K.turn(cur, want)
  local d = ((want - (cur % 360)) % 360 + 540) % 360 - 180
  return cur + d
end

-- Floating green text over a person, rising and fading.
function K.floater(parent)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  fs:SetTextColor(0.43, 1, 0.43)
  fs:Hide()
  local g = fs:CreateAnimationGroup()
  local t = g:CreateAnimation("Translation")
  t:SetOffset(0, 46)
  t:SetDuration(0.9)
  t:SetSmoothing("OUT")
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0)
  a:SetDuration(0.9)
  a:SetSmoothing("IN")
  g:SetScript("OnFinished", function()
    fs:Hide()
  end)
  return function(anchor, text, dy)
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM", anchor, "TOP", 0, dy or 0)
    fs:SetText(text or "")
    fs:Show()
    g:Stop()
    g:Play()
  end,
    fs
end

-- A texture that flashes once: grows from `from` to `to`, turns `deg`
-- degrees and fades, in `seconds` after `delay`.
function K.burst(parent, texture, size, color, from, to, deg, seconds, delay)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size, size)
  t:SetTexture(texture)
  t:SetBlendMode("ADD")
  t:SetVertexColor(unpack(color))
  t:SetAlpha(0)
  local g = t:CreateAnimationGroup()
  local s = g:CreateAnimation("Scale")
  s:SetScaleFrom(from, from)
  s:SetScaleTo(to, to)
  s:SetDuration(seconds)
  s:SetStartDelay(delay or 0)
  s:SetSmoothing("OUT")
  if deg and deg ~= 0 then
    local r = g:CreateAnimation("Rotation")
    r:SetDegrees(-deg)
    r:SetDuration(seconds)
    r:SetStartDelay(delay or 0)
  end
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(color[4] or 1)
  a:SetToAlpha(0)
  a:SetDuration(seconds)
  a:SetStartDelay(delay or 0)
  g:SetScript("OnFinished", function()
    t:SetAlpha(0)
  end)
  return function(anchor)
    t:ClearAllPoints()
    t:SetPoint("CENTER", anchor, "CENTER")
    t:SetAlpha(1)
    g:Stop()
    g:Play()
  end
end

-- The open animation of one spot: from an offset (dx, dy) toward the middle
-- to its place, growing from (scaleX, scaleY) and fading in, after delay.
function K.entrance(f)
  local g = f:CreateAnimationGroup()
  local jump = g:CreateAnimation("Translation")
  jump:SetDuration(0)
  jump:SetOrder(1)
  local hold = g:CreateAnimation("Alpha")
  hold:SetFromAlpha(0)
  hold:SetToAlpha(0)
  hold:SetOrder(1)
  local move = g:CreateAnimation("Translation")
  move:SetOrder(2)
  move:SetSmoothing("OUT")
  local grow = g:CreateAnimation("Scale")
  grow:SetOrder(2)
  grow:SetOrigin("CENTER", 0, 0)
  grow:SetSmoothing("OUT")
  local fade = g:CreateAnimation("Alpha")
  fade:SetOrder(2)
  fade:SetFromAlpha(0)
  fade:SetToAlpha(1)
  return function(dx, dy, scaleX, scaleY, seconds, delay)
    g:Stop()
    jump:SetOffset(-dx, -dy)
    hold:SetDuration(delay or 0)
    move:SetOffset(dx, dy)
    grow:SetScaleFrom(scaleX, scaleY)
    grow:SetScaleTo(1, 1)
    for _, an in ipairs({ move, grow, fade }) do
      an:SetDuration(seconds)
    end
    g:Play()
  end
end

-- Your long buffs are learned out of combat, as they land on you.
ns.on("PLAYER_LOGIN", K.learnBuffs)
ns.on("PLAYER_REGEN_ENABLED", K.learnBuffs)
ns.on("UNIT_AURA", function(unit)
  if unit == "player" then
    K.learnBuffs()
  end
end)
