-- /hp shots: screenshots for the addon's page. Hides the game's interface,
-- stages the diamond (example party, a heal aimed, an incoming heal, a debuff
-- to cleanse) and each settings tab over the game world, takes a screenshot
-- of each, then puts everything back. Out of combat; stand somewhere pretty.
local _, ns = ...

local function eff(f)
  local ok, v = pcall(f.GetEffectiveScale, f)
  return (ok and type(v) == "number" and v > 0) and v or 1
end

-- Our frames live on UIParent; while it is hidden they sit on WorldFrame at
-- the same size.
local moved = {}
local function lift(f)
  if not f then
    return
  end
  moved[f] = f:GetScale() or 1
  local k = eff(UIParent) / eff(WorldFrame)
  f:SetParent(WorldFrame)
  f:SetScale(moved[f] * k)
end
local function restore()
  for f, scale in pairs(moved) do
    f:SetParent(UIParent)
    f:SetScale(scale)
  end
  wipe(moved)
  ns.stage, ns.previewSpell = nil, nil
  local panel = ns.optionsPanel and ns.optionsPanel()
  if panel then
    panel:Hide()
  end
  if ns.preview then
    ns.preview(false)
  end
  UIParent:Show()
end

function ns.showcase()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  local spell
  for _, b in ipairs(ns.readBinds()) do
    if b.heal and not spell then
      spell = b.spell
    end
  end
  local function shot()
    pcall(Screenshot)
  end
  local scenes = {
    function()
      ns.openOptions()
      ns.optionsPanel():Hide()
      lift(ns.diamond)
      lift(ns.optionsPanel())
      UIParent:Hide()
      ns.previewSpell = spell
      ns.stage = { sel = "RIGHT" }
      ns.preview(true)
    end,
    shot,
    function()
      ns.stage = { sel = "UP", dispel = true }
      ns.redraw()
    end,
    shot,
    function()
      ns.stage = nil
      ns.preview(false)
      ns.openOptions()
      local d = ns.optionsDebug()
      d.st.tab, d.st.focus.buttons = "buttons", "row"
      ns.refreshOptions()
    end,
    shot,
    function()
      ns.optionsNav("RB")
    end,
    shot,
    function()
      ns.optionsNav("RB")
      ns.stage = { sel = "RIGHT" }
      ns.redraw()
    end,
    shot,
  }
  ns.say("taking screenshots… hands off for a few seconds.")
  local i = 0
  local function step()
    i = i + 1
    local fn = scenes[i]
    if not fn then
      restore()
      ns.say("done: " .. 5 .. " screenshots in your Screenshots folder.")
      return
    end
    local ok, err = pcall(fn)
    if not ok then
      ns.log("SHOTS error: " .. tostring(err))
      restore()
      ns.say("screenshots stopped: " .. tostring(err))
      return
    end
    C_Timer.After(1.2, step)
  end
  step()
end

-- /hp shots: screenshots of Healpad in use, taken while you play. After it,
-- each time you hold a heal the game takes a screenshot as the menu opens and
-- another each time you pick someone, up to 30. Out of combat the rest of
-- the interface is hidden while you hold; in combat it stays (the game
-- doesn't let addons hide it then). /hp shots again stops.
local armed, count, pending = false, 0, 0
local MAX = 30

local function snapSoon()
  if count >= MAX then
    return
  end
  pending = pending + 1
  local mine = pending
  -- a moment after the change, so the menu is drawn where it now is
  C_Timer.After(0.25, function()
    if armed and mine == pending and ns.ctl:GetAttribute("state") == "aim" then
      count = count + 1
      pcall(Screenshot)
    end
  end)
end

local hidden = false
local function showAll()
  if hidden then
    hidden = false
    for f, scale in pairs(moved) do
      f:SetParent(UIParent)
      f:SetScale(scale)
    end
    wipe(moved)
    UIParent:Show()
  end
end

function ns.actionShots()
  armed = not armed
  if not armed then
    showAll()
    ns.say("screenshots off: " .. count .. " taken.")
    return
  end
  count = 0
  ns.say("screenshots on: hold a heal and pick people. /hp shots again to stop.")
end

ns.ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if not armed then
    return
  end
  if name == "state" then
    if value == "aim" then
      if not InCombatLockdown() and pcall(function()
        lift(ns.diamond)
        UIParent:Hide()
      end) then
        hidden = true
      end
      snapSoon()
    else
      showAll()
    end
  elseif name == "sel" and value then
    snapSoon()
  end
end)

-- Combat coming: the interface back at once.
ns.on("PLAYER_REGEN_DISABLED", showAll)
