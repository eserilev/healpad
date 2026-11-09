-- The diamond: plain frames that follow the controller's attributes. None of
-- them is secure, so they can show, hide and move in combat. Health and the
-- like are secret in combat: the game draws them into bars, and Healpad
-- never compares them. Every read that may be secret is guarded.
local _, ns = ...

local AIMED = { 1, 0.82, 0, 1 }
-- Textures the game itself uses (its tooltip art isn't in this client).
local PLATE = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
  tile = true,
  tileEdge = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local SPOT_W, SPOT_H, FACE = 214, 58, 52

local root = CreateFrame("Frame", "HealpadDiamond", UIParent)
root:SetSize(1, 1)
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:SetFrameStrata("HIGH")
root:Hide()
ns.diamond = root

local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local pageText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function disc(f, anchor, size, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub)
  t:SetSize(size, size)
  t:SetPoint("CENTER", anchor, "CENTER")
  local m = f:CreateMaskTexture()
  m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(t)
  t:AddMaskTexture(m)
  return t
end

local spots = {}
-- One person, like the old party frames: a round portrait in a gold ring, a
-- level badge, a gold name, health with numbers, and mana, rage or energy.
local function makeSpot(dir)
  local f = CreateFrame("Frame", nil, root)
  f:SetSize(SPOT_W, SPOT_H)
  f.plate = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.plate:SetPoint("TOPLEFT", FACE / 2, -3)
  f.plate:SetPoint("BOTTOMRIGHT", 0, 3)
  f.plate:SetBackdrop(PLATE)
  f.plate:SetBackdropColor(1, 1, 1, 0.92)
  -- A thin line around the plate: gold on the aimed person (with a shine),
  -- the debuff's color on someone you can cleanse.
  f.glow = ns.outline(f, f.plate, 1, 3)
  f.glow:SetFrameLevel(f.plate:GetFrameLevel() + 1)
  f.shine = f.plate:CreateTexture(nil, "ARTWORK")
  f.shine:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  f.shine:SetBlendMode("ADD")
  f.shine:SetVertexColor(1, 0.82, 0, 0.35)
  f.shine:SetPoint("TOPLEFT", 4, -4)
  f.shine:SetPoint("BOTTOMRIGHT", -4, 4)
  f.shine:Hide()
  function f.plate.SetBackdropBorderColor(_, r, g, b, a)
    f.glow.border = { r, g, b, a }
    if r then
      f.glow:SetColor(r, g, b, a or 1)
      f.glow:Show()
    else
      f.glow:Hide()
    end
    f.shine:SetShown(r ~= nil and r == AIMED[1] and g == AIMED[2] and b == AIMED[3])
  end
  -- portrait in a ring, drawn over the plate
  local top = CreateFrame("Frame", nil, f)
  top:SetAllPoints()
  top:SetFrameLevel(f.plate:GetFrameLevel() + 2)
  f.face = top:CreateTexture(nil, "ARTWORK", nil, 2)
  f.face:SetSize(FACE - 8, FACE - 8)
  f.face:SetPoint("LEFT", 4, 0)
  f.ring = disc(top, f.face, FACE, "ARTWORK", 0)
  f.ring:SetColorTexture(0.78, 0.64, 0.3, 1)
  f.ringIn = disc(top, f.face, FACE - 4, "ARTWORK", 1)
  f.ringIn:SetColorTexture(0, 0, 0, 1)
  local fm = top:CreateMaskTexture()
  fm:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  fm:SetAllPoints(f.face)
  f.face:AddMaskTexture(fm)
  f.levelRing = disc(top, f.face, 20, "OVERLAY", 0)
  f.levelRing:ClearAllPoints()
  f.levelRing:SetPoint("CENTER", f.face, "BOTTOMRIGHT", -4, 4)
  f.levelRing:SetColorTexture(0.78, 0.64, 0.3, 1)
  f.levelIn = disc(top, f.face, 16, "OVERLAY", 1)
  f.levelIn:ClearAllPoints()
  f.levelIn:SetPoint("CENTER", f.levelRing, "CENTER")
  f.levelIn:SetColorTexture(0.1, 0.07, 0.02, 1)
  f.level = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.level:SetPoint("CENTER", f.levelRing, "CENTER", 0, 0)
  local left = FACE + 6
  f.name = top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("TOPLEFT", left, -9)
  f.name:SetPoint("TOPRIGHT", -10, -9)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.health = CreateFrame("StatusBar", nil, f.plate)
  f.health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -25)
  f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", -9, -25)
  f.health:SetHeight(13)
  f.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.health:SetStatusBarColor(0, 0.8, 0)
  local back = f.health:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.12, 0.02, 0.02, 0.9)
  -- Incoming heals start where health ends, at the same scale.
  f.incoming = CreateFrame("StatusBar", nil, f.health)
  f.incoming:SetPoint("TOPLEFT", f.health:GetStatusBarTexture(), "TOPRIGHT")
  f.incoming:SetPoint("BOTTOMLEFT", f.health:GetStatusBarTexture(), "BOTTOMRIGHT")
  f.incoming:SetWidth(SPOT_W - left - 9)
  f.incoming:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.incoming:SetStatusBarColor(0.55, 1, 0.55, 0.55)
  f.incoming:SetMinMaxValues(0, 1)
  f.incoming:SetValue(0)
  f.hpText = top:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
  f.hpText:SetPoint("CENTER", f.health, "CENTER", 0, 0)
  f.power = CreateFrame("StatusBar", nil, f.plate)
  f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
  f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -1)
  f.power:SetHeight(7)
  f.power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.power:SetStatusBarColor(0, 0, 1)
  local pback = f.power:CreateTexture(nil, "BACKGROUND")
  pback:SetAllPoints()
  pback:SetColorTexture(0.02, 0.02, 0.08, 0.9)
  spots[dir] = f
  return f
end
for _, d in ipairs(ns.DIRS) do
  makeSpot(d)
end
ns.spots = spots

-- A diamond: you in the middle, the others up, right, down and left of you,
-- a little below your character so it stays in sight.
local CENTER_Y = -70
function ns.layout()
  local d = ns.db and ns.db.distance or 3
  local v, h = 62 + 14 * d, 214 + 24 * d
  local at = { UP = { 0, v }, RIGHT = { h, 0 }, DOWN = { 0, -v }, LEFT = { -h, 0 }, SELF = { 0, 0 } }
  for dir, f in pairs(spots) do
    f.at = { at[dir][1], at[dir][2] + CENTER_Y }
    f:ClearAllPoints()
    f:SetPoint("CENTER", root, "CENTER", f.at[1], f.at[2])
  end
  title:ClearAllPoints()
  title:SetPoint("BOTTOM", spots.UP, "TOP", 0, 26)
  pageText:ClearAllPoints()
  pageText:SetPoint("TOP", spots.DOWN, "BOTTOM", 0, -6)
  local scale = ns.db and ns.db.scale or 1
  root:SetScale(scale)
  -- Where you put it: an offset from the middle of the screen, in screen
  -- units; a point's offsets count in the frame's own scale.
  root:ClearAllPoints()
  root:SetPoint("CENTER", UIParent, "CENTER", (ns.db and ns.db.x or 0) / scale, (ns.db and ns.db.y or 0) / scale)
end

-- Dragging the diamond while the Frames tab shows it.
root:SetMovable(true)
root:SetClampedToScreen(false)
local function startDrag()
  if not ns.previewing() or InCombatLockdown() then
    return
  end
  root:StartMoving()
end
local function stopDrag()
  root:StopMovingOrSizing()
  if not ns.db then
    return
  end
  local x, y = root:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if x and ux then
    local k = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.x = math.floor(x * k - ux + 0.5)
    ns.db.y = math.floor(y * k - uy + 0.5)
  end
  ns.layout()
  if ns.refreshOptions then
    ns.refreshOptions()
  end
end
for _, f in pairs(spots) do
  f:SetScript("OnMouseDown", function(_, b)
    if b == "LeftButton" then
      startDrag()
    end
  end)
  f:SetScript("OnMouseUp", stopDrag)
  f:SetScript("OnEnter", function()
    if ns.previewing() then
      pcall(SetCursor, "UI_MOVE_CURSOR")
    end
  end)
  f:SetScript("OnLeave", function()
    pcall(ResetCursor)
  end)
end

-- Move mode: a pulsing gold box around the whole diamond, with the move icon.
local bounds = CreateFrame("Frame", nil, root)
bounds:SetPoint("TOP", spots.UP, "TOP", 0, 14)
bounds:SetPoint("BOTTOM", spots.DOWN, "BOTTOM", 0, -14)
bounds:SetPoint("LEFT", spots.LEFT, "LEFT", -14, 0)
bounds:SetPoint("RIGHT", spots.RIGHT, "RIGHT", 14, 0)
local box = ns.outline(bounds, bounds, 0, 3)
box:SetColor(1, 0.82, 0, 1)
local moveIcon = bounds:CreateTexture(nil, "OVERLAY")
moveIcon:SetSize(40, 40)
moveIcon:SetPoint("CENTER", bounds, "TOP", 0, 0)
moveIcon:SetTexture("Interface\\CURSOR\\UI-Cursor-Move")
moveIcon:Hide()
local pulse = 0
bounds:SetScript("OnUpdate", function(_, elapsed)
  if not box:IsShown() then
    return
  end
  pulse = pulse + elapsed
  box:SetAlpha(0.55 + 0.45 * math.abs(math.sin(pulse * 3)))
end)
function ns.showMoving(on)
  box:SetShown(on)
  moveIcon:SetShown(on)
end

---------------------------------------------------------------- reads that may be secret

local curve
local function dispelCurve()
  if curve ~= nil then
    return curve
  end
  curve = false
  pcall(function()
    local c = C_CurveUtil.CreateColorCurve()
    pcall(c.SetType, c, Enum.LuaCurveType.Step)
    c:AddPoint(0, CreateColor(0, 0, 0, 0))
    c:AddPoint(1, CreateColor(0.2, 0.6, 1, 1)) -- magic
    c:AddPoint(2, CreateColor(0.6, 0, 1, 1)) -- curse
    c:AddPoint(3, CreateColor(0.6, 0.4, 0, 1)) -- disease
    c:AddPoint(4, CreateColor(0, 0.6, 0, 1)) -- poison
    curve = c
  end)
  return curve
end

-- Sets the border to the color of a debuff that the player can remove.
local function dispelBorder(f, unit)
  return pcall(function()
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, 1, "HARMFUL|RAID")
    if not aura then
      error("none")
    end
    local c = dispelCurve()
    local color
    if c then
      color = C_UnitAuras.GetAuraDispelTypeColor(unit, aura.auraInstanceID, c)
    end
    if not color then
      error("none")
    end
    f:SetBackdropBorderColor(color:GetRGBA())
  end)
end

local function outOfRange(spell, unit)
  if not spell then
    return false
  end
  local ok, res = pcall(function()
    return C_Spell.IsSpellInRange(spell, unit) == false
  end)
  return ok and res
end

local function status(unit)
  local ok, res = pcall(function()
    if UnitIsConnected(unit) == false then
      return "Offline"
    end
    if UnitIsDeadOrGhost(unit) then
      return "Dead"
    end
    return nil
  end)
  return ok and res or nil
end

local function setPower(f, unit)
  local ok = pcall(function()
    local _, token = UnitPowerType(unit)
    local c = PowerBarColor and PowerBarColor[token]
    if c then
      f.power:SetStatusBarColor(c.r, c.g, c.b)
    end
  end)
  if not ok then
    f.power:SetStatusBarColor(0, 0, 1)
  end
  if
    not (
      pcall(f.power.SetMinMaxValues, f.power, 0, UnitPowerMax(unit))
      and pcall(f.power.SetValue, f.power, UnitPower(unit))
    )
  then
    f.power:SetMinMaxValues(0, 1)
    f.power:SetValue(0)
  end
end

-- "1240 / 3010" from values that may be secret: the font string takes them.
local function setHealthText(f, unit)
  if pcall(f.hpText.SetFormattedText, f.hpText, "%d / %d", UnitHealth(unit), UnitHealthMax(unit)) then
    return
  end
  f.hpText:SetText("")
end

local function drawSpot(f, dir, unit, sel, spell)
  local aimed = dir == sel
  if not unit or not UnitExists(unit) then
    if unit == "target" then
      f:Show()
      f.name:SetText("Target")
      f.name:SetTextColor(0.6, 0.6, 0.6)
      f.level:SetText("")
      f.hpText:SetText("")
      f.face:SetColorTexture(0.1, 0.1, 0.1, 1)
      f.health:SetMinMaxValues(0, 1)
      f.health:SetValue(0)
      f.incoming:SetValue(0)
      f.power:SetValue(0)
      if aimed then
        f.plate:SetBackdropBorderColor(unpack(AIMED))
      else
        f.plate:SetBackdropBorderColor()
      end
      f:SetAlpha(0.45)
      return
    end
    f:Hide()
    return
  end
  f:Show()
  f.face:SetTexCoord(0, 1, 0, 1)
  pcall(SetPortraitTexture, f.face, unit)
  local dead = status(unit)
  pcall(f.face.SetDesaturated, f.face, dead ~= nil)
  if not pcall(f.name.SetText, f.name, UnitName(unit)) then
    f.name:SetText("")
  end
  if dead then
    f.name:SetTextColor(0.55, 0.55, 0.55)
  else
    f.name:SetTextColor(1, 0.82, 0)
  end
  local okLevel, lvl = pcall(function()
    local l = UnitLevel(unit)
    return (l and l > 0) and tostring(l) or "??"
  end)
  f.level:SetText(okLevel and lvl or "")
  if
    not (
      pcall(f.health.SetMinMaxValues, f.health, 0, UnitHealthMax(unit))
      and pcall(f.health.SetValue, f.health, UnitHealth(unit))
    )
  then
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
  end
  if
    not (
      pcall(f.incoming.SetMinMaxValues, f.incoming, 0, UnitHealthMax(unit))
      and pcall(function()
        f.incoming:SetValue(UnitGetIncomingHeals(unit))
      end)
    )
  then
    f.incoming:SetValue(0)
  end
  if dead then
    f.hpText:SetText(dead)
  else
    setHealthText(f, unit)
  end
  setPower(f, unit)
  if aimed then
    f.plate:SetBackdropBorderColor(unpack(AIMED))
  elseif not dispelBorder(f.plate, unit) then
    f.plate:SetBackdropBorderColor()
  end
  f:SetAlpha(outOfRange(spell, unit) and 0.45 or 1)
end

---------------------------------------------------------------- following the controller

local ctl = ns.ctl

local previewing = false

local function heldSpell()
  local held = ctl:GetAttribute("held")
  local b = held and _G[held]
  return b and b:GetAttribute("hp-lock")
end

-- Example people for the Frames tab when you're not in a group.
local SAMPLE = {
  UP = { name = "Party Member", class = "WARRIOR", level = 60, hp = 0.82, power = 0.35, color = { 1, 0, 0 } },
  RIGHT = {
    name = "Party Member",
    class = "PRIEST",
    level = 60,
    hp = 0.41,
    inc = 0.22,
    power = 0.64,
    color = { 0, 0, 1 },
  },
  DOWN = { name = "Party Member", class = "ROGUE", level = 60, hp = 1, power = 0.8, color = { 1, 1, 0 } },
  SELF = { name = "Tap to Heal Target", face = "player", level = 60, hp = 0.9, power = 0.7, color = { 0, 0, 1 } },
  LEFT = {
    name = "Party Member",
    class = "MAGE",
    level = 60,
    hp = 0.63,
    power = 0.5,
    color = { 0, 0, 1 },
    dispel = { 0.2, 0.6, 1, 1 },
  },
}

-- A round class icon, for people with no portrait to show.
local function classFace(tex, class)
  local ok = pcall(function()
    local c = CLASS_ICON_TCOORDS[class]
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  end)
  if not ok then
    tex:SetColorTexture(0.25, 0.22, 0.18, 1)
  end
end

local function drawSample(f, dir, sel, from)
  local p = SAMPLE[from or dir]
  f:Show()
  f:SetAlpha(1)
  if p.face then
    f.face:SetTexCoord(0, 1, 0, 1)
    pcall(SetPortraitTexture, f.face, p.face)
  else
    classFace(f.face, p.class)
  end
  pcall(f.face.SetDesaturated, f.face, false)
  f.name:SetText(p.name)
  f.name:SetTextColor(1, 0.82, 0)
  f.level:SetText(tostring(p.level))
  f.health:SetMinMaxValues(0, 1)
  f.health:SetValue(p.hp)
  f.incoming:SetMinMaxValues(0, 1)
  f.incoming:SetValue(p.inc or 0)
  f.hpText:SetText(string.format("%d / %d", p.hp * 3000, 3000))
  f.power:SetStatusBarColor(unpack(p.color))
  f.power:SetMinMaxValues(0, 1)
  f.power:SetValue(p.power)
  if dir == sel then
    f.plate:SetBackdropBorderColor(unpack(AIMED))
  elseif p.dispel and ns.stage and ns.stage.dispel then
    f.plate:SetBackdropBorderColor(unpack(p.dispel))
  else
    f.plate:SetBackdropBorderColor()
  end
end

-- Before you aim, the gold is on whoever letting go now would heal: you, or
-- the held button's Tap to heal choice when that person is in the diamond.
local function tapPlace(page)
  local held = ctl:GetAttribute("held")
  local b = held and _G[held]
  local tap = b and b:GetAttribute("hp-tap")
  local unit
  if tap == "tank" then
    unit = ctl:GetAttribute("tank")
  elseif tap == "last" then
    unit = ctl:GetAttribute("last")
  elseif tap == "focus" then
    unit = "focus"
  end
  if unit and UnitExists(unit) then
    for _, d in ipairs(ns.DIRS) do
      local u = ctl:GetAttribute("u" .. page .. "-" .. d)
      if u and (u == unit or UnitIsUnit(u, unit)) then
        return d
      end
    end
  end
  return "SELF"
end

function ns.redraw()
  if not root:IsShown() then
    return
  end
  local page = ctl:GetAttribute("page") or 1
  local pages = ctl:GetAttribute("pages") or 1
  -- Who sits where: the tap target in the middle, you in their place.
  local swap = page == 1 and ctl:GetAttribute("swap") or nil
  local sel = (ns.stage and ns.stage.sel) or ctl:GetAttribute("sel") or (swap and "SELF") or tapPlace(page)
  local spell = heldSpell() or ns.previewSpell
  title:SetText(spell and ns.spellLabel(spell) or "")
  pageText:SetText(pages > 1 and ("Group " .. page .. " / " .. pages) or "")
  local sample = previewing and ctl:GetAttribute("state") ~= "aim" and (not IsInGroup() or ns.stage ~= nil)
  for _, d in ipairs(ns.DIRS) do
    local from = d
    if swap and d == "SELF" then
      from = swap
    elseif swap and d == swap then
      from = "SELF"
    end
    if sample and SAMPLE[from] then
      drawSample(spots[d], d, sel, from)
    else
      local unit = ctl:GetAttribute("u" .. page .. "-" .. from)
      if from == "SELF" and swap then
        unit = "player"
      end
      drawSpot(spots[d], d, unit, sel, spell)
    end
  end
  -- The aimed person stands out: a gold glow, a touch larger, on top.
  -- A frame's offsets count in its own scale, so a grown frame's point is
  -- divided by its scale to stay in its place.
  for _, d in ipairs(ns.DIRS) do
    local f = spots[d]
    local k = d == sel and 1.1 or 1
    f:SetScale(k)
    if f.at then
      f:ClearAllPoints()
      f:SetPoint("CENTER", root, "CENTER", f.at[1] / k, f.at[2] / k)
    end
    f:SetFrameLevel(d == sel and 20 or 5)
  end
end

-- The name of the person a cast went to, shown for a moment where they sit.
local flash = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
flash:SetTextColor(0.49, 1, 0.6)
flash:Hide()
local flashUntil = 0
local function showCast(unit)
  local page = ctl:GetAttribute("page") or 1
  local at = spots.SELF
  for _, d in ipairs(ns.DIRS) do
    if ctl:GetAttribute("u" .. page .. "-" .. d) == unit then
      at = spots[d]
    end
  end
  flash:ClearAllPoints()
  flash:SetPoint("BOTTOM", at, "TOP", 0, 4)
  if not pcall(flash.SetText, flash, UnitName(unit)) then
    flash:SetText("")
  end
  flash:SetAlpha(1)
  flash:Show()
  flashUntil = GetTime() + 0.8
end

local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
  if flash:IsShown() then
    local left = flashUntil - GetTime()
    if left <= 0 then
      flash:Hide()
    else
      flash:SetAlpha(math.min(1, left / 0.4))
    end
  end
  since = since + elapsed
  if since > 0.2 and root:IsShown() then
    since = 0
    ns.redraw()
  end
end)

-- The settings' Frames tab shows the diamond where it will be, out of
-- combat; then it can be dragged.
function ns.previewing()
  return previewing
end
function ns.preview(on)
  previewing = on and not InCombatLockdown()
  for _, f in pairs(spots) do
    f:EnableMouse(previewing)
  end
  root:SetShown(previewing or ctl:GetAttribute("state") == "aim")
  ns.redraw()
end

ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name == "state" then
    root:SetShown(value == "aim" or previewing)
    ns.redraw()
  elseif name == "castn" then
    local unit = ctl:GetAttribute("castunit")
    if unit then
      showCast(unit)
    end
  elseif name == "sel" or name == "page" then
    ns.redraw()
  end
end)

ns.on("PLAYER_LOGIN", ns.layout)
