-- Healpad: hold a heal button, the party opens as a diamond, aim with the
-- d-pad or a stick, let go to cast on the aimed person.
--
-- Healpad doesn't pick spells. It reads the buttons you already bound (the
-- game's controller setup, or any key), and you switch a heal button to
-- Hold to Aim. While you aim, Healpad borrows the aim and cancel buttons;
-- the rest of the time every button does what you bound it to.
local ADDON, ns = ...

ns.HEALS = 12 -- buttons that can hold to aim at once
ns.TAPS = { "player", "target", "last", "tank", "focus" } -- who a tap with no aim heals
ns.TAP_LABEL = { player = "You", target = "Target", last = "Last healed", tank = "Tank", focus = "Focus" }
ns.DIRS = { "UP", "RIGHT", "DOWN", "LEFT", "SELF" }
ns.AIMERS = { "dpad", "rstick", "lstick" }
ns.AIMER_LABEL = { dpad = "D-pad", rstick = "Right stick", lstick = "Left stick" }
ns.CANCELS = { "PAD1", "PAD2", "PAD3", "PAD4" }

local PREFIX = "|cff7fe3e3Healpad|r: "
function ns.say(msg)
  print(PREFIX .. msg)
end

-- A log kept in the saved variables (written on /reload or logout), for
-- reading what happened in the game afterwards. Errors land here too.
local early = {}
function ns.log(msg)
  local ok, line = pcall(function()
    return string.format(
      "%s %.1f %s%s",
      date("%H:%M:%S"),
      GetTime(),
      InCombatLockdown() and "[combat] " or "",
      tostring(msg)
    )
  end)
  if not ok then
    line = "(unprintable log line)"
  end
  local db = ns.db
  if not db then
    table.insert(early, line)
    return
  end
  db.log = db.log or {}
  table.insert(db.log, line)
  while #db.log > 600 do
    table.remove(db.log, 1)
  end
end

-- Runs fn after combat if combat locks protected changes now.
local pending = {}
function ns.afterCombat(key, fn)
  if InCombatLockdown() then
    pending[key] = fn
  else
    fn()
  end
end

local DEFAULTS = {
  distance = 3,
  scale = 1,
  arrows = true,
  aimWith = "dpad",
  cancel = "PAD2",
  x = 0,
  y = 0,
  look = "classic",
}

function ns.setupDB()
  HealpadDB = HealpadDB or {}
  local db = HealpadDB
  -- 0.1 kept heal keys and picked spells; 0.2 reads your own bindings.
  db.keys, db.spells = nil, nil
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then
      db[k] = v
    end
  end
  -- Glass became Classic; Classic took over from Medallions as the default
  if db.look == "glass" or (db.look == "medallions" and not db.lookV) then
    db.look = "classic"
  end
  db.lookV = 1
  if ns.looks and not ns.looks[db.look] then
    db.look = DEFAULTS.look
  end
  db.aim = db.aim or {} -- [binding key] = { tap = "player" }: that key holds to aim
  db.aimSpell = db.aimSpell or {} -- [KeyBars cast value] = { tap }: that spell holds to aim on KeyBars keys
  db.aimPad = db.aimPad or {} -- [spell id] = { tap }: that spell holds to aim on the controller bar (Gamepad Mode)
  ns.db = db
  for _, line in ipairs(early) do
    ns.log(line)
  end
  wipe(early)
end

-- A thin outline around a frame: four lines, nothing inside, so it never
-- covers what it marks. pad: how far outside (negative: inside).
function ns.outline(parent, anchor, pad, size)
  local o = CreateFrame("Frame", nil, parent)
  o:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
  o:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
  o.lines = {}
  local sides = {
    { "TOPLEFT", "TOPRIGHT", "h" },
    { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" },
    { "TOPRIGHT", "BOTTOMRIGHT", "w" },
  }
  for i, side in ipairs(sides) do
    local t = o:CreateTexture(nil, "OVERLAY")
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "h" then
      t:SetHeight(size)
    else
      t:SetWidth(size)
    end
    o.lines[i] = t
  end
  function o.SetColor(_, r, g, b, a)
    o.color = { r, g, b, a }
    for _, t in ipairs(o.lines) do
      t:SetColorTexture(r, g, b, a or 1)
    end
  end
  o:Hide()
  return o
end

ns.events = CreateFrame("Frame")
local handlers = {}
function ns.on(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    pcall(ns.events.RegisterEvent, ns.events, event)
  end
  table.insert(handlers[event], fn)
end
ns.events:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then
      ns.log("ERROR in " .. event .. ": " .. tostring(err))
      geterrorhandler()(err)
    end
  end
end)

ns.on("ADDON_LOADED", function(name)
  if name ~= ADDON then
    return
  end
  ns.setupDB()
end)

ns.on("PLAYER_REGEN_ENABLED", function()
  local todo = pending
  pending = {}
  for _, fn in pairs(todo) do
    fn()
  end
end)
