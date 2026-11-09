-- The diamond: plain frames that follow the controller's attributes. None of
-- them is secure, so they can show, hide and move in combat. Health and the
-- like are secret in combat: the game draws them into bars, and Healpad
-- never compares them. Every read that may be secret is guarded.
local _, ns = ...

local GOLD = { 0.95, 0.76, 0.31, 1 }
local EDGE = { 0.16, 0.19, 0.25, 1 }
local ROLE_TEXT = { TANK = "TANK", HEALER = "HEAL", DAMAGER = "" }
local ARROW_TURN = { UP = 0, LEFT = math.pi / 2, DOWN = math.pi, RIGHT = -math.pi / 2 }

local root = CreateFrame("Frame", "HealpadDiamond", UIParent)
root:SetSize(1, 1)
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:SetFrameStrata("HIGH")
root:Hide()
ns.diamond = root

local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local pageText = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

local spots = {}
local function makeSpot(dir)
  local f = CreateFrame("Frame", nil, root, "BackdropTemplate")
  f:SetSize(dir == "SELF" and 96 or 132, 34)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  f:SetBackdropColor(0.06, 0.08, 0.11, 0.9)
  f:SetClipsChildren(true)
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.name:SetPoint("TOPLEFT", 18, -5)
  f.name:SetPoint("TOPRIGHT", -30, -5)
  f.name:SetJustifyH("LEFT")
  f.role = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.role:SetPoint("TOPRIGHT", -5, -5)
  f.arrow = f:CreateTexture(nil, "OVERLAY")
  f.arrow:SetSize(10, 10)
  f.arrow:SetPoint("TOPLEFT", 5, -6)
  f.arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
  pcall(f.arrow.SetRotation, f.arrow, ARROW_TURN[dir] or 0)
  f.health = CreateFrame("StatusBar", nil, f)
  f.health:SetPoint("BOTTOMLEFT", 5, 5)
  f.health:SetPoint("BOTTOMRIGHT", -5, 5)
  f.health:SetHeight(7)
  f.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  f.health:SetStatusBarColor(0.25, 0.75, 0.37)
  local back = f.health:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.16, 0.08, 0.09)
  -- Incoming heals start where health ends, at the same scale.
  f.incoming = CreateFrame("StatusBar", nil, f)
  f.incoming:SetPoint("TOPLEFT", f.health:GetStatusBarTexture(), "TOPRIGHT")
  f.incoming:SetPoint("BOTTOMLEFT", f.health:GetStatusBarTexture(), "BOTTOMRIGHT")
  f.incoming:SetWidth(122)
  f.incoming:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  f.incoming:SetStatusBarColor(0.61, 0.89, 0.66, 0.7)
  f.incoming:SetMinMaxValues(0, 1)
  f.incoming:SetValue(0)
  spots[dir] = f
  return f
end
for _, d in ipairs(ns.DIRS) do makeSpot(d) end
ns.spots = spots

function ns.layout()
  local r = 70 + 30 * (ns.db and ns.db.distance or 3)
  local w = r * 1.4
  local at = { UP = { 0, r }, RIGHT = { w, 0 }, DOWN = { 0, -r }, LEFT = { -w, 0 }, SELF = { 0, -70 } }
  for d, f in pairs(spots) do
    f:ClearAllPoints()
    f:SetPoint("CENTER", root, "CENTER", at[d][1], at[d][2])
    f.arrow:SetShown(ns.db == nil or ns.db.arrows ~= false)
  end
  title:ClearAllPoints()
  title:SetPoint("BOTTOM", spots.UP, "TOP", 0, 8)
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

local function drawSpot(f, dir, unit, sel, spell)
  if not unit or not UnitExists(unit) then
    if unit == "target" then
      f:Show()
      f.name:SetText("Target")
      f.role:SetText("")
      f.health:SetMinMaxValues(0, 1)
      f.health:SetValue(0)
      f.incoming:SetValue(0)
      f:SetBackdropBorderColor(unpack(dir == sel and GOLD or EDGE))
      f:SetAlpha(0.45)
      return
    end
    f:Hide()
    return
  end
  f:Show()
  local dead = status(unit)
  if not pcall(f.name.SetText, f.name, dead and (UnitName(unit) .. " · " .. dead) or UnitName(unit)) then
    pcall(f.name.SetText, f.name, UnitName(unit))
  end
  local okRole, roleText = pcall(function() return ROLE_TEXT[UnitGroupRolesAssigned(unit)] or "" end)
  f.role:SetText(okRole and roleText or "")
  if not (pcall(f.health.SetMinMaxValues, f.health, 0, UnitHealthMax(unit))
    and pcall(f.health.SetValue, f.health, UnitHealth(unit))) then
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(1)
  end
  if not (pcall(f.incoming.SetMinMaxValues, f.incoming, 0, UnitHealthMax(unit))
    and pcall(function() f.incoming:SetValue(UnitGetIncomingHeals(unit)) end)) then
    f.incoming:SetValue(0)
  end
  if dir == sel then
    f:SetBackdropBorderColor(unpack(GOLD))
  elseif not dispelBorder(f, unit) then
    f:SetBackdropBorderColor(unpack(EDGE))
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
  local spell = heldSpell()
  title:SetText(spell and ns.spellLabel(spell) or "")
  pageText:SetText(pages > 1 and ("Group " .. page .. " / " .. pages) or "")
  for _, d in ipairs(ns.DIRS) do
    drawSpot(spots[d], d, ctl:GetAttribute("u" .. page .. "-" .. d), sel, spell)
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

ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name == "state" then
    root:SetShown(value == "aim")
    ns.redraw()
  elseif name == "castn" then
    local unit = ctl:GetAttribute("castunit")
    if unit then showCast(unit) end
  elseif name == "sel" or name == "page" then
    ns.redraw()
  end
end)

ns.on("PLAYER_LOGIN", ns.layout)
