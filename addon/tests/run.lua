-- The Healpad tests. Run from the repo root: luajit addon/tests/run.lua
package.path = "addon/tests/?.lua;" .. package.path
local Wow = require("wow")

local FILES = { "Core.lua", "Spells.lua", "Roster.lua", "Secure.lua", "Diamond.lua", "Options.lua" }
local DIR = "addon/Healpad"

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n  " .. tostring(err))
  end
end
local function eq(a, b, what)
  if a ~= b then error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function clean(W)
  eq(#W.blocked, 0, "blocked: " .. table.concat(W.blocked, ", "))
  eq(#W.errors, 0, "errors: " .. table.concat(W.errors, " | "))
end

local BOOK = {
  { id = 5185, name = "Healing Touch", sub = "Rank 1", helpful = true },
  { id = 5186, name = "Healing Touch", sub = "Rank 2", helpful = true },
  { id = 774, name = "Rejuvenation", sub = "Rank 1", helpful = true },
  { id = 5176, name = "Wrath", sub = "Rank 1", helpful = false },
  { id = 9999, name = "Some Flyout", helpful = true, kind = 4 },
}

local function party(W)
  W.units.player = { name = "Me", hp = 90, max = 100, role = "HEALER" }
  W.units.party1 = { name = "Zed", hp = 50, max = 100, role = "DAMAGER" }
  W.units.party2 = { name = "Brakka", hp = 80, max = 100, role = "TANK" }
  W.units.party3 = { name = "Ann", hp = 70, max = 100, role = "DAMAGER" }
  W.units.party4 = { name = "Kira", hp = 60, max = 100, role = "HEALER" }
end

-- A game with a party, two heal keys set: X = Healing Touch 2 (tap: you),
-- A = Rejuvenation (tap: given).
local function game(opts)
  opts = opts or {}
  local W = Wow.new()
  W.book = BOOK
  if opts.party ~= false then party(W) else W.units.player = { name = "Me", hp = 90, max = 100 } end
  local saved = {
    keys = { { key = "PAD3", tap = "player" }, { key = "PAD1", tap = opts.tap or "player" } },
    spells = { [1] = { 5186, 774 } },
  }
  local ns = W.load(DIR, FILES, saved)
  return W, ns
end

local function last(W) return W.casts[#W.casts] end

test("spell scan keeps friendly spells, each rank by id, no flyouts", function()
  local W, ns = game()
  local list = ns.scanSpells()
  eq(#list, 3, "count")
  eq(list[1], 5185) eq(list[2], 5186) eq(list[3], 774)
  eq(ns.spellLabel(5186), "Healing Touch (Rank 2)")
  clean(W)
end)

test("roster: tank up, you in the middle, then by role and name", function()
  local W, ns = game()
  local c = ns.ctl
  eq(c:GetAttribute("u1-UP"), "party2", "tank up")
  eq(c:GetAttribute("u1-SELF"), "player")
  eq(c:GetAttribute("u1-RIGHT"), "party4", "healer next")
  eq(c:GetAttribute("u1-DOWN"), "party3", "Ann before Zed")
  eq(c:GetAttribute("u1-LEFT"), "party1")
  eq(c:GetAttribute("tank"), "party2")
  eq(c:GetAttribute("pages"), 1)
  clean(W)
end)

test("solo: up is your target", function()
  local W, ns = game({ party = false })
  eq(ns.ctl:GetAttribute("u1-UP"), "target")
  W.units.target = { name = "Friend", hp = 1, max = 2, friendly = true }
  W.combat = true
  W.key("PAD3", true) W.tap("UP") W.key("PAD3", false)
  eq(last(W).unit, "target")
  W.units.target = { name = "Wolf", hp = 1, max = 2, friendly = false }
  local n = #W.casts
  W.key("PAD3", true) W.tap("UP") W.key("PAD3", false)
  eq(#W.casts, n, "no heal on an enemy")
  clean(W)
end)

test("press casts nothing, aim, release casts the locked spell on the aimed one", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true)
  eq(#W.casts, 0, "press casts nothing")
  eq(ns.diamond:IsShown(), true, "diamond open")
  W.tap("PADDUP")
  eq(ns.ctl:GetAttribute("sel"), "UP")
  W.key("PAD3", false)
  eq(last(W).spell, 5186) eq(last(W).unit, "party2") eq(last(W).combat, true)
  eq(ns.diamond:IsShown(), false, "closed after")
  eq(W.secureBinds.PADDUP, nil, "d-pad given back")
  clean(W)
end)

test("the opposite way comes back to you", function()
  local W, ns = game({ party = false })
  W.units.target = { name = "Friend", hp = 1, max = 2, friendly = true }
  W.combat = true
  W.key("PAD3", true) W.tap("UP") W.tap("DOWN")
  eq(ns.ctl:GetAttribute("sel"), "SELF")
  W.key("PAD3", false)
  eq(last(W).unit, "player")
  local W2, ns2 = game()
  W2.combat = true
  W2.key("PAD3", true) W2.tap("PADDLEFT") W2.tap("PADDRIGHT")
  eq(ns2.ctl:GetAttribute("sel"), "SELF")
  W2.tap("PADDRIGHT")
  eq(ns2.ctl:GetAttribute("sel"), "RIGHT", "a second press goes on")
  W2.key("PAD3", false)
  clean(W2)
end)

test("arrow keys aim too", function()
  local W = game()
  W.combat = true
  W.key("PAD3", true) W.tap("LEFT") W.key("PAD3", false)
  eq(last(W).unit, "party1")
  clean(W)
end)

test("tap with no aim heals you; other tap choices", function()
  local W = game()
  W.combat = true
  W.tap("PAD3")
  eq(last(W).unit, "player")
  W.combat = false
  local W2 = game({ tap = "tank" })
  W2.combat = true
  W2.tap("PAD1")
  eq(last(W2).unit, "party2", "tank")
  eq(last(W2).spell, 774)
  local W3 = game({ tap = "last" })
  W3.combat = true
  W3.key("PAD3", true) W3.tap("PADDDOWN") W3.key("PAD3", false)
  W3.tap("PAD1")
  eq(last(W3).unit, "party3", "last healed")
  local W4 = game({ tap = "focus" })
  W4.combat = true
  W4.tap("PAD1")
  eq(last(W4).unit, "player", "no focus: you")
  W4.units.focus = W4.units.party1
  W4.tap("PAD1")
  eq(last(W4).unit, "focus")
  clean(W) clean(W2) clean(W3) clean(W4)
end)

test("cancel: nothing casts, keys come back", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true) W.tap("PADDUP") W.tap("PAD2") W.key("PAD3", false)
  eq(#W.casts, 0)
  eq(ns.diamond:IsShown(), false)
  eq(W.secureBinds.PADDUP, nil)
  W.key("PAD3", true) W.tap("BACKSPACE") W.key("PAD3", false)
  eq(#W.casts, 0, "backspace cancels")
  clean(W)
end)

test("a lost release: the next press of that key starts over", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true)
  W.downTarget.PAD3 = nil -- the release never comes
  W.key("PAD3", true)
  eq(ns.ctl:GetAttribute("held"), "HealpadHeal1")
  W.tap("PADDRIGHT")
  W.key("PAD3", false)
  eq(last(W).unit, "party4")
  eq(ns.diamond:IsShown(), false)
  clean(W)
end)

test("a second heal key casts on the aimed one, the diamond stays open", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true) W.tap("PADDUP")
  W.key("PAD1", true) W.key("PAD1", false)
  eq(last(W).spell, 774) eq(last(W).unit, "party2")
  eq(ns.diamond:IsShown(), true, "still open")
  W.key("PAD3", false)
  eq(last(W).spell, 5186) eq(last(W).unit, "party2")
  eq(#W.casts, 2)
  clean(W)
end)

test("the spell is locked at the press", function()
  local W, ns = game()
  W.key("PAD3", true)
  ns.heals[1]:SetAttribute("hp-spell", 5185) -- a layer change mid-hold
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  clean(W)
end)

test("a heal key that is also an aim key stays a heal key", function()
  local W = Wow.new()
  W.book = BOOK
  party(W)
  W.load(DIR, FILES, { keys = { { key = "PADRSHOULDER", tap = "player" }, { key = "PAD1", tap = "player" } },
    spells = { [1] = { 5186, 774 } } })
  W.combat = true
  W.key("PAD1", true) W.tap("PADDUP") W.tap("PADRSHOULDER")
  eq(last(W).spell, 5186, "RB cast its heal")
  eq(last(W).unit, "party2")
  W.key("PAD1", false)
  clean(W)
end)

test("raid: your group first, LB/RB flip groups", function()
  local W = Wow.new()
  W.book = BOOK
  W.raid = {}
  local function add(i, name, group, role, me)
    W.raid[i] = { name = name, group = group }
    W.units["raid" .. i] = { name = name, hp = 50, max = 100, role = role }
    if me then W.units.player = W.units["raid" .. i] end
  end
  add(1, "Tanky", 1, "TANK") add(2, "Bob", 1, "DAMAGER")
  add(3, "Me", 2, "HEALER", true) add(4, "Cat", 2, "DAMAGER")
  add(5, "Dee", 3, "DAMAGER")
  local ns = W.load(DIR, FILES, { keys = { { key = "PAD3", tap = "player" } }, spells = { [1] = { 5186 } } })
  local c = ns.ctl
  eq(c:GetAttribute("pages"), 3)
  eq(c:GetAttribute("u1-SELF"), "raid3", "my group first")
  eq(c:GetAttribute("u1-UP"), "raid4")
  eq(c:GetAttribute("u2-UP"), "raid1", "group 1 next, tank up")
  eq(c:GetAttribute("tank"), "raid1")
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADRSHOULDER")
  eq(c:GetAttribute("page"), 2)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).unit, "raid1")
  W.key("PAD3", true) W.tap("PADLSHOULDER")
  eq(c:GetAttribute("page"), 3, "back wraps")
  W.tap("PAGEDOWN")
  eq(c:GetAttribute("page"), 1, "keyboard page key")
  W.key("PAD3", false)
  clean(W)
end)

test("roster changes in combat wait for the end of combat", function()
  local W, ns = game()
  W.combat = true
  W.units.party4 = nil
  W.fire("GROUP_ROSTER_UPDATE")
  eq(ns.ctl:GetAttribute("u1-RIGHT"), "party4", "unchanged in combat")
  W.key("PAD3", true) W.tap("PADDRIGHT") W.key("PAD3", false)
  eq(#W.casts, 0, "the gone person is not healed")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(ns.ctl:GetAttribute("u1-RIGHT"), "party3")
  clean(W)
end)

test("drawing in combat: bars get the secret values, nothing compares them", function()
  local W, ns = game()
  W.units.party2.debuff = "Magic"
  W.units.party1.dead = true
  W.rangeOut.party3 = true
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.update(0.3)
  local up = ns.spots.UP
  eq(Wow.isSecret(up.health.value), true, "health bar got the secret value")
  eq(Wow.isSecret(up.incoming.value), true, "incoming bar too")
  eq(up.border[1], 0.2, "dispel border")
  eq(ns.spots.LEFT.border[1], 0.95, "gold wins")
  eq(ns.spots.LEFT.name.text, "Zed · Dead")
  W.key("PAD3", false)
  clean(W)
end)

test("keys are set out of combat only; a KeyBars clash warns", function()
  local W = Wow.new()
  W.book = BOOK
  party(W)
  W.normalBinds.PAD3 = "CLICK KeyBarsSlot12:LeftButton"
  local ns = W.load(DIR, FILES, { keys = { { key = "PAD3", tap = "player" } }, spells = { [1] = { 5186 } } })
  local warned = false
  for _, p in ipairs(W.printed) do if p:find("KeyBars") then warned = true end end
  eq(warned, true, "warned")
  W.combat = true
  ns.db.keys[1].key = "PAD4"
  ns.applyKeys()
  eq(W.overrides.PAD3 ~= nil, true, "unchanged in combat")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(W.overrides.PAD4 and W.overrides.PAD4.target, "HealpadHeal1")
  eq(W.overrides.PAD3, nil)
  clean(W)
end)

test("spells are saved per talent group", function()
  local W, ns = game()
  W.talentGroup = 2
  eq(ns.spellOn(1), nil)
  ns.setSpell(1, 774)
  W.talentGroup = 1
  eq(ns.spellOn(1), 5186)
  clean(W)
end)

test("options open, cycle a spell and a tap choice, capture a key", function()
  local W, ns = game()
  ns.openOptions()
  local p = W.G.HealpadOptions
  eq(p:IsShown(), true)
  clean(W)
  ns.db.keys[3].tap = "player"
  ns.openOptions()
  eq(ns.spellOn(3), nil)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
