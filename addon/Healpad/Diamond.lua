-- The aim menu: plain frames that follow the controller's attributes. None of
-- them is secure, so they can show, hide and move in combat. What it looks
-- like is the chosen look's (Looks.lua and Look*.lua); this file says who
-- sits where, who is aimed, and when it opens, redraws and casts.
local _, ns = ...

local root = CreateFrame("Frame", "HealpadDiamond", UIParent)
root:SetSize(1, 1)
root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
root:SetFrameStrata("HIGH")
root:Hide()
ns.diamond = root

-- A little below your character, so it stays in sight.
local CENTER_Y = -70
local stage = CreateFrame("Frame", nil, root)
stage:SetSize(1, 1)
stage:SetPoint("CENTER", root, "CENTER", 0, CENTER_Y)

-- Cast effects: they play where the person sat, after the menu has closed.
local fx = CreateFrame("Frame", nil, UIParent)
fx:SetSize(1, 1)
fx:SetPoint("CENTER")
fx:SetFrameStrata("HIGH")
fx:SetFrameLevel(50)

local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local pageText = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

local look -- the look in use
local previewing = false
local moving = false -- the settings' Move: the menu can be dragged
local dimmed = false -- the settings are on a heal that doesn't hold for the menu
local opening = false -- the entrance plays at the next redraw

---------------------------------------------------------------- the look

-- Dragging the menu while the settings' Move is on.
root:SetMovable(true)
root:SetClampedToScreen(false)
local function startDrag()
  if not previewing or not moving or InCombatLockdown() then
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
local function draggable(f)
  f:SetScript("OnMouseDown", function(_, b)
    if b == "LeftButton" then
      startDrag()
    end
  end)
  f:SetScript("OnMouseUp", stopDrag)
  f:SetScript("OnEnter", function()
    if previewing and moving then
      pcall(SetCursor, "UI_MOVE_CURSOR")
    end
  end)
  f:SetScript("OnLeave", function()
    pcall(ResetCursor)
  end)
end

-- Move mode: a thin gold edge around the whole menu, and it can be dragged.
local bounds = CreateFrame("Frame", nil, root)
local box = ns.outline(bounds, bounds, 0, 1)
box:SetColor(1, 0.82, 0, 1)
local function grabbable()
  for _, f in pairs(ns.spots or {}) do
    f:EnableMouse(previewing and moving)
  end
end
function ns.showMoving(on)
  moving = on == true
  box:SetShown(moving)
  grabbable()
end

-- Where the menu is on the screen, in UIParent's units: left, right, top,
-- bottom; nil when the game can't tell yet.
function ns.menuBox()
  local ok, l, r, t, b = pcall(function()
    return bounds:GetLeft(), bounds:GetRight(), bounds:GetTop(), bounds:GetBottom()
  end)
  if not ok or type(l) ~= "number" or type(r) ~= "number" then
    return nil
  end
  local k = 1
  pcall(function()
    k = bounds:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end)
  return l * k, r * k, (t or 0) * k, (b or 0) * k
end

local function anchorAround(spots)
  bounds:ClearAllPoints()
  bounds:SetPoint("TOP", spots.UP, "TOP", 0, 14)
  bounds:SetPoint("BOTTOM", spots.DOWN, "BOTTOM", 0, -14)
  bounds:SetPoint("LEFT", spots.LEFT, "LEFT", -14, 0)
  bounds:SetPoint("RIGHT", spots.RIGHT, "RIGHT", 14, 0)
  title:ClearAllPoints()
  title:SetPoint("BOTTOM", spots.UP, "TOP", 0, 26)
  pageText:ClearAllPoints()
  pageText:SetPoint("TOP", spots.DOWN, "BOTTOM", 0, -30)
end

-- Puts the saved look in place: built the first time, the old one hidden.
local function applyLook()
  local want = ns.looks[ns.db and ns.db.look] or ns.looks.classic
  if want == look then
    return
  end
  if not want.frame then
    want.build(stage, fx)
    for _, f in pairs(want.spots) do
      draggable(f)
    end
  end
  if look then
    look.frame:Hide()
  end
  look = want
  ns.look = want
  ns.spots = want.spots
  grabbable()
  anchorAround(want.spots)
  want.frame:Show()
  -- the entrance is for a real hold; the settings' preview just shows it
  opening = root:IsShown() and not previewing
  ns.layout()
  ns.redraw()
end

-- Picks a look. Out of combat it shows at once; in combat it waits for the
-- end of the fight. Returns true when it shows now.
function ns.setLook(name)
  if not ns.looks[name] or not ns.db then
    return false
  end
  ns.db.look = name
  if InCombatLockdown() then
    ns.afterCombat("look", applyLook)
    return false
  end
  applyLook()
  return true
end

-- Where you put it: an offset from the middle of the screen, in screen
-- units; a point's offsets count in the frame's own scale.
function ns.layout()
  local scale = ns.db and ns.db.scale or 1
  local x, y = (ns.db and ns.db.x or 0) / scale, (ns.db and ns.db.y or 0) / scale
  if ns.shotsCentered then
    x, y = 0, 0 -- /hp shots page: the middle of the screen
  end
  -- lifted onto WorldFrame for screenshots: the same size as on UIParent
  local lift = 1
  if root:GetParent() == WorldFrame then
    local ok, k = pcall(function()
      return UIParent:GetEffectiveScale() / WorldFrame:GetEffectiveScale()
    end)
    lift = (ok and type(k) == "number" and k > 0) and k or 1
  end
  root:SetScale(scale * lift)
  root:ClearAllPoints()
  root:SetPoint("CENTER", UIParent, "CENTER", x, y)
  fx:SetScale(scale)
  fx:ClearAllPoints()
  fx:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if look then
    look.layout(ns.db and ns.db.spacing or 1)
  end
end

---------------------------------------------------------------- following the controller

local ctl = ns.ctl

-- What the held button keeps for the hold: on itself, or for one of the
-- game's controller bar buttons on the controller.
local function heldAttr(what)
  local held = ctl:GetAttribute("held")
  if not held then
    return nil
  end
  local v = ctl:GetAttribute("gp" .. what .. "-" .. held)
  if v ~= nil then
    return v
  end
  local b = _G[held]
  return b and b.GetAttribute and b:GetAttribute("hp-" .. what)
end

local function heldSpell()
  return heldAttr("lock")
end

-- Example people for the settings' preview when you're not in a group: one of each
-- state the looks show.
local SAMPLE = {
  UP = { name = "Thrain", class = "WARRIOR", hp = 0.46, inc = 0.14, miss = 1620, hot = true },
  RIGHT = { name = "Mirelle", class = "PRIEST", hp = 0.92, miss = 240, dispel = { 0.2, 0.6, 1, 1 } },
  DOWN = { name = "Kesh", class = "ROGUE", hp = 0.3, miss = 2100 },
  LEFT = { name = "Brannoc", class = "MAGE", hp = 0.68, miss = 960, far = true },
  SELF = { name = "Tap to Heal Target", face = "player", hp = 0.84, miss = 480 },
}
for _, p in pairs(SAMPLE) do
  p.kind = "sample"
end

-- Where each tap choice sits among the example people.
local SAMPLE_TAP = { player = "SELF", target = "RIGHT", focus = "LEFT", tank = "UP", last = "DOWN" }

-- Before you aim, the gold is on whoever letting go now would heal: you, or
-- the held button's tap choice when that person is in the menu. In the
-- settings' preview: the tap choice of the heal the settings are on.
local function tapPlace(page, sample)
  local tap = heldAttr("tap")
  if not tap and previewing then
    tap = ns.previewTap
    if sample then
      return SAMPLE_TAP[tap] or "SELF"
    end
  end
  local unit
  if tap == "tank" then
    unit = ctl:GetAttribute("tank")
  elseif tap == "last" then
    unit = ctl:GetAttribute("last")
  elseif tap == "focus" then
    unit = UnitExists("focus") and "focus" or "target"
  elseif tap == "target" then
    unit = "target"
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

-- A look's error is reported once, not every redraw.
local reported = {}
local function run(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not reported[err] then
    reported[err] = true
    ns.log("ERROR in look " .. tostring(look and look.name) .. ": " .. tostring(err))
    geterrorhandler()(err)
  end
end

local drawn = {} -- [dir] = the unit drawn there
local lastSpell
local dirty = false

function ns.redraw()
  dirty = false
  if not look or not root:IsShown() then
    return
  end
  local page = ctl:GetAttribute("page") or 1
  local pages = ctl:GetAttribute("pages") or 1
  -- Who sits where: the tap target in the middle, you in their place.
  local swap = page == 1 and ctl:GetAttribute("swap") or nil
  local sample = previewing and ctl:GetAttribute("state") ~= "aim" and (not IsInGroup() or ns.stage ~= nil)
  local sel = (ns.stage and ns.stage.sel) or ctl:GetAttribute("sel") or (swap and "SELF") or tapPlace(page, sample)
  local spell = heldSpell() or ns.previewSpell
  lastSpell = spell or lastSpell
  title:SetText(spell and ns.spellLabel(spell) or "")
  pageText:SetText(pages > 1 and ("Group " .. page .. " / " .. pages) or "")
  local ctx = { spell = spell, sel = sel }
  for _, d in ipairs(ns.DIRS) do
    local from = d
    if swap and d == "SELF" then
      from = swap
    elseif swap and d == swap then
      from = "SELF"
    end
    local src
    drawn[d] = nil
    if sample and SAMPLE[from] then
      src = SAMPLE[from]
      if src.face then
        local ok, _, class = pcall(UnitClass, "player")
        src.class = ok and class or nil
        local okN, me = pcall(UnitName, "player")
        src.name = okN and me or src.name
      end
      -- screenshots: the sample people get names
      local named = ns.stage and ns.stage.names and ns.stage.names[from]
      if named then
        local copy = {}
        for k, v in pairs(src) do
          copy[k] = v
        end
        copy.name = named
        src = copy
      end
    else
      local unit = ctl:GetAttribute("u" .. page .. "-" .. from)
      if from == "SELF" and swap then
        unit = "player"
      end
      if unit and UnitExists(unit) then
        src = { kind = "unit", unit = unit }
        drawn[d] = unit
      elseif unit == "target" then
        src = { kind = "empty", name = "Target" }
      end
    end
    ctx.aimed = d == sel
    if src then
      run(look.draw, look.spots[d], src, ctx)
    else
      look.spots[d]:Hide()
    end
  end
  run(look.aim, sel, ctx)
  if opening then
    opening = false
    run(look.open)
  end
end

-- Health, auras and the like come as events; range has none, so a slow tick
-- looks again while the menu is up.
local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
  if not root:IsShown() then
    return
  end
  since = since + elapsed
  if dirty or since > 0.5 then
    since = 0
    ns.redraw()
  end
end)
for _, e in ipairs({
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_HEAL_PREDICTION",
  "UNIT_AURA",
  "UNIT_CONNECTION",
  "UNIT_FLAGS",
  "UNIT_NAME_UPDATE",
  "UNIT_PORTRAIT_UPDATE",
}) do
  ns.on(e, function()
    dirty = true
  end)
end

-- It opens with the look's entrance, once the people are drawn.
root:SetScript("OnShow", function()
  opening = not previewing
end)

-- While the settings are open the menu shows where it will be, out of
-- combat, as their preview.
function ns.previewing()
  return previewing
end

-- Faded out while the settings are on a heal that doesn't open the menu; a
-- real hold always shows it.
local function fade(seconds)
  local out = previewing and dimmed and ctl:GetAttribute("state") ~= "aim"
  ns.kit.fadeTo(root, out and 0 or 1, seconds)
end
function ns.previewDim(on)
  dimmed = on == true
  fade(0.2)
end

function ns.preview(on)
  previewing = on and not InCombatLockdown()
  if not previewing then
    moving, dimmed = false, false
    box:Hide()
  end
  grabbable()
  fade(0)
  root:SetShown(previewing or ctl:GetAttribute("state") == "aim")
  ns.redraw()
end

ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name == "state" then
    fade(0)
    root:SetShown(value == "aim" or previewing)
    ns.redraw()
  elseif name == "sel" or name == "page" then
    ns.redraw()
  end
end)

ns.on("PLAYER_LOGIN", applyLook)
