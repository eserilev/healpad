-- Healpad: hold a heal key, the party opens as a diamond, aim with the d-pad
-- or the arrow keys, let go to cast on the aimed person.
local ADDON, ns = ...

ns.KEYS = 8 -- heal keys
ns.TAPS = { "player", "last", "tank", "focus" } -- who a tap with no aim heals
ns.TAP_LABEL = { player = "You", last = "Last", tank = "Tank", focus = "Focus" }
ns.DIRS = { "UP", "RIGHT", "DOWN", "LEFT", "SELF" }

local PREFIX = "|cff7fe3e3Healpad|r: "
function ns.say(msg) print(PREFIX .. msg) end

-- Runs fn after combat if combat locks protected changes now.
local pending = {}
function ns.afterCombat(key, fn)
  if InCombatLockdown() then
    pending[key] = fn
  else
    fn()
  end
end

-- The spec index for the saved spells: the active spec group (dual spec).
function ns.spec()
  local ok, g = pcall(function()
    local info = C_SpecializationInfo
    return info and info.GetActiveSpecGroup and info.GetActiveSpecGroup() or 1
  end)
  return (ok and type(g) == "number") and g or 1
end

local DEFAULTS = { distance = 3, scale = 1, arrows = true }

function ns.setupDB()
  HealpadDB = HealpadDB or {}
  local db = HealpadDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  db.keys = db.keys or {}
  for i = 1, ns.KEYS do
    db.keys[i] = db.keys[i] or {}
    db.keys[i].tap = db.keys[i].tap or "player"
  end
  db.spells = db.spells or {}
  ns.db = db
end

-- The spell id on heal key i in this spec, or nil.
function ns.spellOn(i)
  local s = ns.db.spells[ns.spec()]
  return s and s[i]
end

function ns.setSpell(i, id)
  local spec = ns.spec()
  ns.db.spells[spec] = ns.db.spells[spec] or {}
  ns.db.spells[spec][i] = id
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
    if not ok then geterrorhandler()(err) end
  end
end)

ns.on("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ns.setupDB()
end)

ns.on("PLAYER_REGEN_ENABLED", function()
  local todo = pending
  pending = {}
  for _, fn in pairs(todo) do fn() end
end)
