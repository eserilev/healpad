-- Healpad: hold a heal button, the party opens as a diamond, aim with the
-- d-pad or a stick, let go to cast on the aimed person.
--
-- Healpad doesn't pick spells. It reads the buttons you already bound (the
-- game's controller setup, or any key), and you switch a heal button to
-- Hold to Aim. While you aim, Healpad borrows the aim and cancel buttons;
-- the rest of the time every button does what you bound it to.
local ADDON, ns = ...

ns.HEALS = 12 -- buttons that can hold to aim at once
ns.TAPS = { "player", "target", "focus", "tank", "last" } -- who a tap with no aim heals, in the settings' order
ns.TAP_LABEL = { player = "You", target = "Target", last = "Last healed", tank = "Tank", focus = "Focus" }
ns.DIRS = { "UP", "RIGHT", "DOWN", "LEFT", "SELF" }
ns.AIMERS = { "dpad", "lstick", "rstick" }
ns.AIMER_LABEL = { dpad = "D-pad", rstick = "Right stick", lstick = "Left stick" }
ns.CANCELS = { "PAD1", "PAD2", "PAD3", "PAD4" }
-- Buttons mode: the grid takes A, B, X, Y, the shoulders, triggers, d-pad
-- and Start, so its cancel is one of the buttons left.
ns.BTN_CANCELS = { "PADBACK", "PADLSTICK", "PADRSTICK", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }

-- The settings picked by tiles: Mode, Party Frames (Radial), After a heal
-- and Labels (Buttons). The first of each is the left tile.
ns.MODES = { "radial", "buttons" }
ns.FRAMES = { "plus", "game" }
ns.AFTERS = { "once", "locked" }
ns.LABELS = { "row", "full" }

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
  scale = 1,
  arrows = true,
  aimWith = "dpad",
  cancel = "PAD2",
  x = 0,
  y = 0,
  look = "classic",
  mode = "radial",
  frames = "game",
  after = "once",
  labels = "full",
  btnCancel = "PADBACK",
}
-- Where the always-on frames sit, from the screen's top left corner, and
-- their size: the plus (its middle) and the Buttons grid (its top left),
-- each in the old party frames' place.
ns.PLACES = {
  plus = { scale = "pscale", x = "px", y = "py", dx = 250, dy = -310, size = 0.7 },
  grid = { scale = "gscale", x = "gx", y = "gy", dx = 24, dy = -150, size = 1 },
  menu = { scale = "scale", x = "x", y = "y", dx = 0, dy = 0, size = 1 },
}

local function oneOf(list, v)
  for _, x in ipairs(list) do
    if x == v then
      return true
    end
  end
  return false
end
ns.oneOf = oneOf

-- Buttons mode: tap a heal, then press the person.
function ns.isButtons()
  return ns.db ~= nil and ns.db.mode == "buttons"
end
-- Radial with Party Frames on Plus: the plus is always on screen.
function ns.plusOn()
  return ns.db ~= nil and ns.db.mode ~= "buttons" and ns.db.frames == "plus"
end
-- Which frames are on screen all the time: "plus", "grid" or nil (the
-- menu shows only while you hold a heal).
function ns.placeName()
  if ns.isButtons() then
    return "grid"
  end
  return ns.plusOn() and "plus" or "menu"
end
-- The place in use: its scale, and its x and y as saved.
function ns.place(name)
  local p = ns.PLACES[name or ns.placeName()]
  local db = ns.db or {}
  return db[p.scale] or p.size, db[p.x] or p.dx, db[p.y] or p.dy, p
end

-- The cancel choices of the mode in use, and the cancel button now.
function ns.cancels()
  return ns.isButtons() and ns.BTN_CANCELS or ns.CANCELS
end
function ns.cancelKey()
  if ns.isButtons() then
    return ns.db.btnCancel
  end
  return ns.db.cancel
end

-- Spacing: how far apart the people sit, 0.6 to 1.4 of the usual room
-- between them. Before 0.4 it was Spread, 1 to 5 (3 the usual); a saved
-- Spread becomes the nearest tenth once: 1 is 0.8, 3 is 1, 5 is 1.2.
ns.SPACING_MIN, ns.SPACING_MAX = 0.6, 1.4
function ns.tenth(v)
  return math.floor(v * 10 + 0.5) / 10
end
function ns.spacingOf(db)
  local v = tonumber(db.spacing)
  if not v then
    local d = tonumber(db.distance)
    v = d and 1 + (d - 3) * 0.12 or 1
  end
  return math.max(ns.SPACING_MIN, math.min(ns.SPACING_MAX, ns.tenth(v)))
end

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
  db.spacing = ns.spacingOf(db)
  if ns.looks and not ns.looks[db.look] then
    db.look = DEFAULTS.look
  end
  if not oneOf(ns.MODES, db.mode) then
    db.mode = DEFAULTS.mode
  end
  if not oneOf(ns.FRAMES, db.frames) then
    db.frames = DEFAULTS.frames
  end
  if not oneOf(ns.AFTERS, db.after) then
    db.after = DEFAULTS.after
  end
  if not oneOf(ns.LABELS, db.labels) then
    db.labels = DEFAULTS.labels
  end
  -- A cancel that isn't one of its mode's choices is that mode's default;
  -- each mode keeps its own.
  if not oneOf(ns.CANCELS, db.cancel) then
    db.cancel = DEFAULTS.cancel
  end
  if not oneOf(ns.BTN_CANCELS, db.btnCancel) then
    db.btnCancel = DEFAULTS.btnCancel
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
