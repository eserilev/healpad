-- The Healpad tests. Run from the repo root: luajit addon/tests/run.lua
package.path = "addon/tests/?.lua;" .. package.path
local Wow = require("wow")

local FILES = { "Core.lua", "Binds.lua", "Roster.lua", "Secure.lua", "Diamond.lua", "Options.lua" }
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
  { id = 1082, name = "Claw", sub = "Rank 1", helpful = false },
}

local function party(W)
  W.units.player = { name = "Me", hp = 90, max = 100, role = "HEALER" }
  W.units.party1 = { name = "Zed", hp = 50, max = 100, role = "DAMAGER" }
  W.units.party2 = { name = "Brakka", hp = 80, max = 100, role = "TANK" }
  W.units.party3 = { name = "Ann", hp = 70, max = 100, role = "DAMAGER" }
  W.units.party4 = { name = "Kira", hp = 60, max = 100, role = "HEALER" }
end

-- A druid's bars and bindings, as Blizzard's controller setup leaves them:
--   X (PAD3) -> main bar 1: Healing Touch r2 (cat form: Claw)
--   A (PAD1) -> main bar 2: Rejuvenation (cat form too)
--   Y (PAD4) -> main bar 3: Wrath
--   B (PAD2) -> main bar 4: Healing Touch r1, cast as normal
--   LT+X (SHIFT-PAD3) and the 1 key -> bottom-left bar 1: Healing Touch r1
local function setup(W)
  W.book = BOOK
  W.actions[1] = { "spell", 5186 }
  W.actions[2] = { "spell", 774 }
  W.actions[3] = { "spell", 5176 }
  W.actions[4] = { "spell", 5185 }
  W.actions[61] = { "spell", 5185 }
  W.actions[73] = { "spell", 1082 } -- cat form, bonus bar 1
  W.actions[74] = { "spell", 774 }
  W.bind("ACTIONBUTTON1", "PAD3")
  W.bind("ACTIONBUTTON2", "PAD1")
  W.bind("ACTIONBUTTON3", "PAD4")
  W.bind("ACTIONBUTTON4", "PAD2")
  W.bind("MULTIACTIONBAR1BUTTON1", "SHIFT-PAD3", "1")
  W.bind("JUMP", "SPACE")
  W.cvars.GamePadEmulateShift = "PADLTRIGGER"
end

-- X and A hold to aim. X's tap heals you, A's tap is opts.tap.
local function game(opts)
  opts = opts or {}
  local W = Wow.new()
  setup(W)
  if opts.party ~= false then party(W) else W.units.player = { name = "Me", hp = 90, max = 100 } end
  local saved = opts.saved or { aim = { PAD3 = { tap = "player" }, PAD1 = { tap = opts.tap or "player" } } }
  local ns = W.load(DIR, FILES, saved)
  return W, ns
end

local function last(W) return W.casts[#W.casts] end

test("your bindings: pad buttons with spells, keyboard heals only, LT combos named", function()
  local W, ns = game()
  local keys = {}
  for _, b in ipairs(ns.binds) do keys[#keys + 1] = b.key end
  eq(table.concat(keys, " "), "PAD1 PAD2 PAD3 PAD4 SHIFT-PAD3 1")
  eq(ns.binds[4].heal, false, "Wrath is no heal")
  eq(ns.keyLabel("SHIFT-PAD3"), "LT+X")
  eq(ns.keyGroup("SHIFT-PAD3"), "LT")
  eq(ns.binds[3].states.p1, true)
  eq(ns.binds[3].states.b1, nil, "cat form has Claw there")
  eq(ns.binds[1].states.b1, true, "Rejuvenation in cat form too")
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
  eq(ns.ctl:GetAttribute("held"), "HealpadHeal2", "X is the second bound heal")
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
  W.inSecure = true
  ns.heals[1]:SetAttribute("hp-spell", 5185) -- a rebind mid-hold
  W.inSecure = false
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
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
  eq(Wow.isSecret(up.power.value), true, "power bar too")
  eq(up.hpText.text, "80 / 100", "numbers from secrets, by the font string")
  eq(up.face.portrait, "party2", "portrait")
  eq(up.plate.border[1], 0.2, "dispel border")
  eq(ns.spots.LEFT.plate.border[1], 1, "aimed gold wins")
  eq(ns.spots.LEFT.name.text, "Zed")
  eq(ns.spots.LEFT.hpText.text, "Dead")
  W.key("PAD3", false)
  clean(W)
end)

test("a heal you didn't set to aim, and a non-heal, cast as you bound them", function()
  local W = game()
  W.combat = true
  W.tap("PAD4")
  W.tap("PAD2")
  eq(#W.casts, 0)
  eq(W.barPresses[1].command, "ACTIONBUTTON3")
  eq(W.barPresses[2].command, "ACTIONBUTTON4")
  clean(W)
end)

test("cat form: X is Claw again, A still aims; back in caster form X aims", function()
  local W = game()
  W.combat = true
  W.setBar("b1")
  W.tap("PAD3")
  eq(#W.casts, 0, "X did not heal")
  eq(W.barPresses[1].command, "ACTIONBUTTON1", "Claw")
  W.key("PAD1", true) W.tap("PADDUP") W.key("PAD1", false)
  eq(last(W).spell, 774) eq(last(W).unit, "party2")
  W.setBar("p1")
  W.key("PAD3", true) W.tap("PADDLEFT") W.key("PAD3", false)
  eq(last(W).spell, 5186) eq(last(W).unit, "party1")
  clean(W)
end)

test("a vehicle takes every heal button away", function()
  local W = game()
  W.combat = true
  W.setBar("x")
  W.tap("PAD1")
  eq(#W.casts, 0)
  clean(W)
end)

test("B cancels only while aiming; your B spell works the rest of the time", function()
  local W = game()
  W.combat = true
  W.tap("PAD2")
  eq(W.barPresses[1].command, "ACTIONBUTTON4", "B casts its spell")
  W.key("PAD3", true) W.tap("PADDUP") W.tap("PAD2") W.key("PAD3", false)
  eq(#W.casts, 0, "B cancelled the aim")
  eq(#W.barPresses, 1, "and did not cast its spell")
  clean(W)
end)

test("cancel with Y, aim with the right stick", function()
  local W, ns = game({ saved = { aim = { PAD3 = { tap = "player" } }, cancel = "PAD4", aimWith = "rstick" } })
  W.combat = true
  W.key("PAD3", true) W.tap("PADDUP")
  eq(ns.ctl:GetAttribute("sel"), nil, "the d-pad doesn't aim now")
  W.tap("PADRSTICKUP")
  eq(ns.ctl:GetAttribute("sel"), "UP")
  W.tap("PAD4")
  W.key("PAD3", false)
  eq(#W.casts, 0, "Y cancelled")
  clean(W)
end)

test("an LT combo holds to aim; aiming works with LT still down", function()
  local W = game({ saved = { aim = { ["SHIFT-PAD3"] = { tap = "player" } } } })
  W.combat = true
  W.key("SHIFT-PAD3", true) W.tap("SHIFT-PADDRIGHT") W.key("SHIFT-PAD3", false)
  eq(last(W).spell, 5185) eq(last(W).unit, "party4")
  clean(W)
end)

test("a heal button that is also an aim button stays a heal button", function()
  local W = Wow.new()
  setup(W)
  party(W)
  W.bind("ACTIONBUTTON5", "PADRSHOULDER")
  W.actions[5] = { "spell", 5185 }
  W.load(DIR, FILES, { aim = { PADRSHOULDER = { tap = "player" }, PAD1 = { tap = "player" } } })
  W.combat = true
  W.key("PAD1", true) W.tap("PADDUP") W.tap("PADRSHOULDER")
  eq(last(W).spell, 5185, "RB cast its heal")
  eq(last(W).unit, "party2")
  W.key("PAD1", false)
  clean(W)
end)

test("raid: your group first, LB/RB flip groups", function()
  local W = Wow.new()
  setup(W)
  W.raid = {}
  local function add(i, name, group, role, me)
    W.raid[i] = { name = name, group = group }
    W.units["raid" .. i] = { name = name, hp = 50, max = 100, role = role }
    if me then W.units.player = W.units["raid" .. i] end
  end
  add(1, "Tanky", 1, "TANK") add(2, "Bob", 1, "DAMAGER")
  add(3, "Me", 2, "HEALER", true) add(4, "Cat", 2, "DAMAGER")
  add(5, "Dee", 3, "DAMAGER")
  local ns = W.load(DIR, FILES, { aim = { PAD3 = { tap = "player" } } })
  local c = ns.ctl
  eq(c:GetAttribute("pages"), 3)
  eq(c:GetAttribute("u1-SELF"), "raid3", "my group first")
  eq(c:GetAttribute("u2-UP"), "raid1", "group 1 next, tank up")
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

test("binding events don't redo an unchanged setup; a rebind is picked up after combat", function()
  local W, ns = game()
  local n = 0
  local old = W.G.SecureHandlerExecute
  W.G.SecureHandlerExecute = function(...) n = n + 1 return old(...) end
  W.fire("UPDATE_BINDINGS")
  W.fire("ACTIONBAR_SLOT_CHANGED")
  eq(n, 0, "nothing changed")
  W.combat = true
  W.actions[1] = { "spell", 5185 }
  W.fire("ACTIONBAR_SLOT_CHANGED")
  eq(n, 0, "waits for the end of combat")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(n, 1)
  eq(ns.heals[2]:GetAttribute("hp-spell"), 5185)
  clean(W)
end)

test("settings: pad drives the tabs; A sets Hold to Aim; nav keys go back on close", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  local p = W.G.HealpadOptions
  eq(p:IsShown(), true)
  eq(W.overrides.PADDDOWN.target, "HealpadNavDOWN", "pad drives the panel")
  -- the list: A (Rejuvenation), B, X, Y, LT+X, 1
  W.tap("PADDDOWN") W.tap("PADDDOWN")
  W.tap("PAD1")
  eq(ns.db.aim.PAD3 ~= nil, true, "X holds to aim")
  eq(ns.heals[1]:GetAttribute("hp-key"), "PAD3")
  W.tap("PADDRIGHT") W.tap("PADDDOWN") W.tap("PADDRIGHT") W.tap("PADDRIGHT") W.tap("PAD1")
  eq(ns.db.aim.PAD3.tap, "tank", "tap to heal: tank")
  W.tap("PAD2") -- back to the list
  W.tap("PADRSHOULDER") -- Aim tab
  W.tap("PADDRIGHT")
  eq(ns.db.aimWith, "rstick")
  W.tap("PADDDOWN") W.tap("PADDRIGHT")
  eq(ns.db.cancel, "PAD4", "cancel moved on from B to Y, skipping X")
  W.tap("PADRSHOULDER") -- Frames tab
  W.tap("PADDRIGHT")
  eq(ns.db.scale, 1.1)
  eq(ns.diamond:IsShown(), true, "the diamond shows while on Frames")
  W.tap("PAD2")
  eq(p:IsShown(), false, "B closes")
  eq(W.overrides.PADDDOWN, nil, "nav keys given back")
  eq(ns.diamond:IsShown(), false)
  clean(W)
end)

test("the settings close when combat starts", function()
  local W, ns = game()
  ns.openOptions()
  W.fire("PLAYER_REGEN_DISABLED")
  eq(W.G.HealpadOptions:IsShown(), false)
  eq(W.overrides.PADDUP, nil)
  W.combat = true
  ns.openOptions()
  eq(W.G.HealpadOptions:IsShown(), false, "not in combat")
  clean(W)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
