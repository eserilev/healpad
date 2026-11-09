-- The diamond: plain frames that follow the controller's attributes. None of
-- them is secure, so they can show, hide and move in combat. Health and the
-- like are secret in combat: the game draws them into bars, and Healpad
-- never compares them. Every read that may be secret is guarded.
local _, ns = ...

local PLATE_EDGE = { 0.62, 0.5, 0.24, 1 } -- old gold
local AIMED = { 1, 0.82, 0, 1 }
local SPOT_W, SPOT_H, FACE = 214, 58, 52

local root = CreateFrame("Frame", "HealpadDiamond", UIParent)
root:SetSize(1, 1)
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:SetFrameStrata("HIGH")
root:Hide()
ns.diamond = root

local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local pageText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

-- The gold arrow over the aimed person.
local aimArrow = root:CreateTexture(nil, "OVERLAY")
aimArrow:SetSize(22, 22)
aimArrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
pcall(aimArrow.SetRotation, aimArrow, math.pi)
aimArrow:SetVertexColor(1, 0.82, 0)

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
  f.plate:SetBackdrop({ bgFile = "Interface\\Tooltip\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltip\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f.plate:SetBackdropColor(0.02, 0.02, 0.02, 0.9)
  f.plate:SetBackdropBorderColor(unpack(PLATE_EDGE))
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
for _, d in ipairs(ns.DIRS) do makeSpot(d) end
ns.spots = spots

-- Around your character: you just below, the others up, right, down, left.
function ns.layout()
  local d = ns.db and ns.db.distance or 3
  local v, h = 90 + 30 * d, 150 + 40 * d
  local at = { UP = { 0, v }, RIGHT = { h, 0 }, DOWN = { 0, -v }, LEFT = { -h, 0 }, SELF = { 0, -80 } }
  for dir, f in pairs(spots) do
    f:ClearAllPoints()
    f:SetPoint("CENTER", root, "CENTER", at[dir][1], at[dir][2])
  end
  title:ClearAllPoints()
  title:SetPoint("BOTTOM", spots.UP, "TOP", 0, 26)
  pageText:ClearAllPoints()
  pageText:SetPoint("TOP", spots.DOWN, "BOTTOM", 0, -6)
  root:SetScale(ns.db and ns.db.scale or 1)
end

---------------------------------------------------------------- reads that may be secret

local curve
local function dispelCurve()
  if curve ~= nil then return curve end
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
    if not aura then error("none") end
    local c = dispelCurve()
    local color
    if c then
      color = C_UnitAuras.GetAuraDispelTypeColor(unit, aura.auraInstanceID, c)
    elseif DebuffTypeColor and aura.dispelName then
      local t = DebuffTypeColor[aura.dispelName]
      color = t and CreateColor(t.r, t.g, t.b, 1)
    end
    if not color then error("none") end
    f:SetBackdropBorderColor(color:GetRGBA())
  end)
end

local function outOfRange(spell, unit)
  if not spell then return false end
  local ok, res = pcall(function() return C_Spell.IsSpellInRange(spell, unit) == false end)
  return ok and res
end

local function status(unit)
  local ok, res = pcall(function()
    if UnitIsConnected(unit) == false then return "Offline" end
    if UnitIsDeadOrGhost(unit) then return "Dead" end
    return nil
  end)
  return ok and res or nil
end

local function setPower(f, unit)
  local ok = pcall(function()
    local _, token = UnitPowerType(unit)
    local c = PowerBarColor and PowerBarColor[token]
    if c then f.power:SetStatusBarColor(c.r, c.g, c.b) end
  end)
  if not ok then f.power:SetStatusBarColor(0, 0, 1) end
  if not (pcall(f.power.SetMinMaxValues, f.power, 0, UnitPowerMax(unit))
    and pcall(f.power.SetValue, f.power, UnitPower(unit))) then
    f.power:SetMinMaxValues(0, 1)
    f.power:SetValue(0)
  end
end

-- "1240 / 3010" from values that may be secret: the font string takes them.
local function setHealthText(f, unit)
  if pcall(f.hpText.SetFormattedText, f.hpText, "%d / %d", UnitHealth(unit), UnitHealthMax(unit)) then return end
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
      f.plate:SetBackdropBorderColor(unpack(aimed and AIMED or PLATE_EDGE))
      f:SetAlpha(0.45)
      return
    end
    f:Hide()
    return
  end
  f:Show()
  pcall(SetPortraitTexture, f.face, unit)
  local dead = status(unit)
  pcall(f.face.SetDesaturated, f.face, dead ~= nil)
  if not pcall(f.name.SetText, f.name, UnitName(unit)) then f.name:SetText("") end
  if dead then f.name:SetTextColor(0.55, 0.55, 0.55) else f.name:SetTextColor(1, 0.82, 0) end
  local okLevel, lvl = pcall(function() local l = UnitLevel(unit) return (l and l > 0) and tostring(l) or "??" end)
  f.level:SetText(okLevel and lvl or "")
  if not (pcall(f.health.SetMinMaxValues, f.health, 0, UnitHealthMax(unit))
    and pcall(f.health.SetValue, f.health, UnitHealth(unit))) then
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
  end
  if not (pcall(f.incoming.SetMinMaxValues, f.incoming, 0, UnitHealthMax(unit))
    and pcall(function() f.incoming:SetValue(UnitGetIncomingHeals(unit)) end)) then
    f.incoming:SetValue(0)
  end
  if dead then f.hpText:SetText(dead) else setHealthText(f, unit) end
  setPower(f, unit)
  if aimed then
    f.plate:SetBackdropBorderColor(unpack(AIMED))
  elseif not dispelBorder(f.plate, unit) then
    f.plate:SetBackdropBorderColor(unpack(PLATE_EDGE))
  end
  f:SetAlpha(outOfRange(spell, unit) and 0.45 or 1)
end

---------------------------------------------------------------- following the controller

local ctl = ns.ctl

local function heldSpell()
  local held = ctl:GetAttribute("held")
  local b = held and _G[held]
  return b and b:GetAttribute("hp-lock")
end

function ns.redraw()
  if not root:IsShown() then return end
  local page = ctl:GetAttribute("page") or 1
  local pages = ctl:GetAttribute("pages") or 1
  local sel = ctl:GetAttribute("sel") or "SELF"
  local spell = heldSpell() or ns.previewSpell
  title:SetText(spell and ns.spellLabel(spell) or "")
  pageText:SetText(pages > 1 and ("Group " .. page .. " / " .. pages) or "")
  for _, d in ipairs(ns.DIRS) do
    drawSpot(spots[d], d, ctl:GetAttribute("u" .. page .. "-" .. d), sel, spell)
  end
  local at = spots[sel]
  aimArrow:ClearAllPoints()
  aimArrow:SetPoint("BOTTOM", at, "TOP", FACE / 4, -2)
  aimArrow:SetShown(at:IsShown())
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
    if ctl:GetAttribute("u" .. page .. "-" .. d) == unit then at = spots[d] end
  end
  flash:ClearAllPoints()
  flash:SetPoint("BOTTOM", at, "TOP", 0, 4)
  if not pcall(flash.SetText, flash, UnitName(unit)) then flash:SetText("") end
  flash:SetAlpha(1)
  flash:Show()
  flashUntil = GetTime() + 0.8
end

local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
  if flash:IsShown() then
    local left = flashUntil - GetTime()
    if left <= 0 then flash:Hide() else flash:SetAlpha(math.min(1, left / 0.4)) end
  end
  since = since + elapsed
  if since > 0.2 and root:IsShown() then
    since = 0
    ns.redraw()
  end
end)

-- The settings' Frames tab shows the diamond as it is now, out of combat.
local previewing = false
function ns.preview(on)
  previewing = on and not InCombatLockdown()
  root:SetShown(previewing or ctl:GetAttribute("state") == "aim")
  ns.redraw()
end

ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name == "state" then
    root:SetShown(value == "aim" or previewing)
    ns.redraw()
  elseif name == "castn" then
    local unit = ctl:GetAttribute("castunit")
    if unit then showCast(unit) end
  elseif name == "sel" or name == "page" then
    ns.redraw()
  end
end)

ns.on("PLAYER_LOGIN", ns.layout)
