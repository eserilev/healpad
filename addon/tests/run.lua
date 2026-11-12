-- The Healpad tests. Run from the repo root: luajit addon/tests/run.lua
package.path = "addon/tests/?.lua;" .. package.path
local Wow = require("wow")

local FILES = {
  "Core.lua",
  "Binds.lua",
  "Roster.lua",
  "Secure.lua",
  "Looks.lua",
  "LookMedallions.lua",
  "LookSigil.lua",
  "LookCompass.lua",
  "LookClassic.lua",
  "Diamond.lua",
  "Seats.lua",
  "Options.lua",
  "Test.lua",
  "Probe.lua",
  "Showcase.lua",
}
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
  if a ~= b then
    error((what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
  end
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
  { id = 7777, name = "Walk on Air", sub = "Racial", helpful = true, selfOnly = true },
  { id = 6807, name = "Maul", sub = "Rank 1", helpful = false },
}

local function party(W)
  W.units.player = { name = "Me", hp = 90, max = 100, role = "HEALER" }
  W.units.party1 = { name = "Brakka", hp = 80, max = 100, role = "TANK" }
  W.units.party2 = { name = "Kira", hp = 60, max = 100, role = "HEALER" }
  W.units.party3 = { name = "Ann", hp = 70, max = 100, role = "DAMAGER" }
  W.units.party4 = { name = "Zed", hp = 50, max = 100, role = "DAMAGER" }
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
  if opts.party ~= false then
    party(W)
  else
    W.units.player = { name = "Me", hp = 90, max = 100 }
  end
  local saved = opts.saved or { aim = { PAD3 = { tap = "player" }, PAD1 = { tap = opts.tap or "player" } } }
  local ns = W.load(DIR, FILES, saved)
  return W, ns
end

local function last(W)
  return W.casts[#W.casts]
end

test("your bindings: pad buttons with spells, keyboard heals only, LT combos named", function()
  local W, ns = game()
  local keys = {}
  for _, b in ipairs(ns.binds) do
    keys[#keys + 1] = b.key
  end
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

test("a heal bound straight to a button (no bar slot) shows and aims", function()
  local W = Wow.new()
  setup(W)
  party(W)
  W.bind("SPELL Rejuvenation", "PADLSHOULDER")
  W.bind("SPELL Healing Touch(Rank 2)", "SHIFT-PADLSHOULDER")
  local ns = W.load(DIR, FILES, { aim = { PADLSHOULDER = { tap = "player" } } })
  local found = {}
  for _, b in ipairs(ns.binds) do
    found[b.key] = b
  end
  eq(found.PADLSHOULDER and found.PADLSHOULDER.spell, 774, "LB listed")
  eq(found.PADLSHOULDER.heal, true)
  eq(found["SHIFT-PADLSHOULDER"] and found["SHIFT-PADLSHOULDER"].spell, 5185, "rank text dropped")
  W.combat = true
  W.key("PADLSHOULDER", true)
  W.tap("PADDUP")
  W.key("PADLSHOULDER", false)
  eq(last(W).spell, 774, "LB cast its heal")
  eq(last(W).unit, "Brakka")
  clean(W)
end)

test("roster: you in the middle, the party clockwise from the top in the game's order, by name", function()
  local W, ns = game()
  local c = ns.ctl
  eq(c:GetAttribute("u1-UP"), "Brakka", "party1 up")
  eq(c:GetAttribute("u1-SELF"), "player")
  eq(c:GetAttribute("u1-RIGHT"), "Kira", "party2 right")
  eq(c:GetAttribute("u1-DOWN"), "Ann", "party3 down")
  eq(c:GetAttribute("u1-LEFT"), "Zed", "party4 left")
  eq(c:GetAttribute("tank"), "Brakka")
  eq(c:GetAttribute("pages"), 1)
  clean(W)
end)

test("solo: up is your target", function()
  local W, ns = game({ party = false })
  eq(ns.ctl:GetAttribute("u1-UP"), "target")
  W.units.target = { name = "Friend", hp = 1, max = 2, friendly = true }
  W.combat = true
  W.key("PAD3", true)
  W.tap("UP")
  W.key("PAD3", false)
  eq(last(W).unit, "target")
  W.units.target = { name = "Wolf", hp = 1, max = 2, friendly = false }
  local n = #W.casts
  W.key("PAD3", true)
  W.tap("UP")
  W.key("PAD3", false)
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
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka")
  eq(last(W).combat, true)
  eq(ns.diamond:IsShown(), false, "closed after")
  eq(W.secureBinds.PADDUP, nil, "d-pad given back")
  clean(W)
end)

test("the opposite way comes back to you", function()
  local W, ns = game({ party = false })
  W.units.target = { name = "Friend", hp = 1, max = 2, friendly = true }
  W.combat = true
  W.key("PAD3", true)
  W.tap("UP")
  W.tap("DOWN")
  eq(ns.ctl:GetAttribute("sel"), "SELF")
  W.key("PAD3", false)
  eq(last(W).unit, "player")
  local W2, ns2 = game()
  W2.combat = true
  W2.key("PAD3", true)
  W2.tap("PADDLEFT")
  W2.tap("PADDRIGHT")
  eq(ns2.ctl:GetAttribute("sel"), "SELF")
  W2.tap("PADDRIGHT")
  eq(ns2.ctl:GetAttribute("sel"), "RIGHT", "a second press goes on")
  W2.key("PAD3", false)
  clean(W2)
end)

test("arrow keys aim too", function()
  local W = game()
  W.combat = true
  W.key("PAD3", true)
  W.tap("LEFT")
  W.key("PAD3", false)
  eq(last(W).unit, "Zed")
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
  eq(last(W2).unit, "Brakka", "tank")
  eq(last(W2).spell, 774)
  local W3 = game({ tap = "last" })
  W3.combat = true
  W3.key("PAD3", true)
  W3.tap("PADDDOWN")
  W3.key("PAD3", false)
  W3.tap("PAD1")
  eq(last(W3).unit, "Ann", "last healed")
  local W4 = game({ tap = "focus" })
  W4.combat = true
  W4.tap("PAD1")
  eq(last(W4).unit, "player", "no focus: you")
  W4.units.focus = W4.units.party4
  W4.tap("PAD1")
  eq(last(W4).unit, "focus")
  clean(W)
  clean(W2)
  clean(W3)
  clean(W4)
end)

test("tap heals the tank: nobody trades places, the tank stays in their seat", function()
  local W, ns = game({ saved = { aim = { PAD3 = { tap = "tank" } } } })
  W.combat = true
  W.key("PAD3", true)
  eq(ns.ctl:GetAttribute("swap"), nil, "no swap")
  W.update(0.3)
  eq(ns.spots.SELF.name.text, "Me", "you in the middle")
  eq(ns.spots.UP.name.text, "Brakka", "the tank where they sit")
  eq(ns.spots.UP.sel:IsShown(), true, "the tank lit: a tap heals them")
  W.key("PAD3", false)
  eq(last(W).unit, "Brakka", "no aim: the tank")
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.tap("PADDDOWN")
  W.key("PAD3", false)
  eq(last(W).unit, "player", "up and back: you")
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.key("PAD3", false)
  eq(last(W).unit, "Zed", "the others are where they were")
  clean(W)
end)

test("a tap set to Target heals your target if it's a friend, else you", function()
  local W = game({ party = false, saved = { aim = { PAD3 = { tap = "target" } } } })
  W.combat = true
  W.units.target = { name = "Pal", hp = 1, max = 2, friendly = true }
  W.tap("PAD3")
  eq(last(W).unit, "target", "a friendly target")
  W.units.target = { name = "Wolf", hp = 1, max = 2, friendly = false }
  W.tap("PAD3")
  eq(last(W).unit, "player", "an enemy target: you")
  W.units.target = nil
  W.tap("PAD3")
  eq(last(W).unit, "player", "no target: you")
  clean(W)
end)

test("solo: a tap set to Focus heals your focus if it's a friend, else you; Tank and Last healed heal you", function()
  local W = game({ party = false, saved = { aim = { PAD3 = { tap = "focus" }, PAD1 = { tap = "tank" } } } })
  W.combat = true
  W.units.focus = { name = "Pal", hp = 1, max = 2 }
  W.tap("PAD3")
  eq(last(W).unit, "focus", "a friendly focus")
  W.units.focus = { name = "Wolf", hp = 1, max = 2, friendly = false }
  W.tap("PAD3")
  eq(last(W).unit, "player", "an enemy focus: you")
  W.units.focus = nil
  W.tap("PAD3")
  eq(last(W).unit, "player", "no focus: you")
  W.units.target = { name = "Pal", hp = 1, max = 2, friendly = true }
  W.tap("PAD3")
  eq(last(W).unit, "target", "no focus: your friendly target")
  W.units.target = nil
  W.tap("PAD1")
  eq(last(W).unit, "player", "no tank: you")
  clean(W)
end)

test("Last healed never means your target, which may have changed", function()
  local W = game({ party = false, saved = { aim = { PAD3 = { tap = "last" } } } })
  W.units.target = { name = "Friend", hp = 1, max = 2, friendly = true }
  W.combat = true
  W.key("PAD3", true)
  W.tap("UP")
  W.key("PAD3", false)
  eq(last(W).unit, "target")
  W.units.target = { name = "Wolf", hp = 1, max = 2, friendly = false }
  W.tap("PAD3")
  eq(last(W).unit, "player", "not the wolf you target now")
  clean(W)
end)

test("the raid's Main Tank counts as the tank when nobody has the role", function()
  local W = Wow.new()
  setup(W)
  party(W)
  W.units.party1.role = "DAMAGER"
  W.units.party3.mainTank = true
  local ns = W.load(DIR, FILES, { aim = { PAD3 = { tap = "tank" } } })
  eq(ns.ctl:GetAttribute("tank"), "Ann")
  clean(W)
end)

test("cancel: nothing casts, keys come back", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.tap("PAD2")
  W.key("PAD3", false)
  eq(#W.casts, 0)
  eq(ns.diamond:IsShown(), false)
  eq(W.secureBinds.PADDUP, nil)
  W.key("PAD3", true)
  W.tap("BACKSPACE")
  W.key("PAD3", false)
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
  eq(last(W).unit, "Kira")
  eq(ns.diamond:IsShown(), false)
  clean(W)
end)

test("a second heal key casts on the aimed one, the diamond stays open", function()
  local W, ns = game()
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.key("PAD1", true)
  W.key("PAD1", false)
  eq(last(W).spell, 774)
  eq(last(W).unit, "Brakka")
  eq(ns.diamond:IsShown(), true, "still open")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka")
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
  W.units.party2 = nil
  W.fire("GROUP_ROSTER_UPDATE")
  eq(ns.ctl:GetAttribute("u1-RIGHT"), "Kira", "unchanged in combat")
  W.key("PAD3", true)
  W.tap("PADDRIGHT")
  W.key("PAD3", false)
  eq(#W.casts, 0, "the gone person is not healed")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(ns.ctl:GetAttribute("u1-RIGHT"), nil, "a free seat: nobody moves into it")
  eq(ns.ctl:GetAttribute("u1-DOWN"), "Ann", "the rest stay")
  eq(ns.ctl:GetAttribute("u1-LEFT"), "Zed")
  W.units.party2 = { name = "Newt", hp = 1, max = 2 }
  W.fire("GROUP_ROSTER_UPDATE")
  eq(ns.ctl:GetAttribute("u1-RIGHT"), "Newt", "someone new takes the free seat")
  eq(ns.ctl:GetAttribute("u1-LEFT"), "Zed")
  clean(W)
end)

test("drawing in combat: bars get the secret values, nothing compares them", function()
  local W, ns = game()
  W.units.party1.debuff = "Magic"
  W.units.party4.dead = true
  W.rangeOut.party3 = true
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.update(0.6)
  local up = ns.spots.UP
  eq(Wow.isSecret(up.health.value), true, "health bar got the secret value")
  eq(Wow.isSecret(up.health.incoming.value), true, "incoming bar too")
  eq(Wow.isSecret(up.health.barColor[1]), true, "health color from the curve, secret")
  eq(up.face.portrait, "Brakka", "portrait")
  eq(up.dispel:IsShown(), true, "dispel pip")
  eq(up.glow, nil, "no outline for a dispel any more")
  eq(ns.spots.LEFT.name.text, "Zed")
  eq(ns.spots.LEFT.state:IsShown(), true, "dead: the skull")
  eq(ns.spots.LEFT.state.texture, ns.kit.SKULL)
  eq(Wow.isSecret(ns.spots.DOWN.body.alphaBool[1]), true, "range: the game fades it from the secret answer")
  W.key("PAD3", false)
  clean(W)
end)

---------------------------------------------------------------- looks

local function lookNames(ns)
  local names = {}
  for _, n in ipairs(ns.LOOKS) do
    names[#names + 1] = n
  end
  return table.concat(names, " ")
end

test("looks: four in the registry, Classic by default, each with its parts", function()
  local W, ns = game()
  eq(lookNames(ns), "classic medallions sigil compass")
  eq(ns.db.look, "classic", "default")
  eq(ns.look.name, "classic")
  eq(ns.spots, ns.looks.classic.spots)
  for _, name in ipairs(ns.LOOKS) do
    local look = ns.looks[name]
    eq(type(ns.LOOK_LABEL[name]), "string", name .. " label")
    for _, fn in ipairs({ "build", "layout", "draw", "aim", "open", "cast" }) do
      eq(type(look[fn]), "function", name .. "." .. fn)
    end
  end
  eq(ns.looks.sigil.frame, nil, "a look is built only when chosen")
  clean(W)
end)

test("looks: a saved look comes back; an unknown one falls back to Classic", function()
  local W, ns = game({ saved = { look = "compass", aim = { PAD3 = { tap = "player" } } } })
  eq(ns.look.name, "compass")
  eq(ns.spots.UP.miss ~= nil, true, "compass cards")
  clean(W)
  local W2, ns2 = game({ saved = { look = "gone", aim = { PAD3 = { tap = "player" } } } })
  eq(ns2.db.look, "classic")
  eq(ns2.look.name, "classic")
  clean(W2)
end)

test("looks: switching shows the new one at once; in combat it waits for the fight to end", function()
  local W, ns = game()
  eq(ns.setLook("sigil"), true)
  eq(ns.look.name, "sigil")
  eq(ns.spots, ns.looks.sigil.spots)
  eq(ns.looks.sigil.frame:IsShown(), true)
  eq(ns.looks.classic.frame:IsShown(), false, "the old one hidden")
  eq(ns.setLook("nope"), false, "no such look")
  eq(ns.db.look, "sigil")
  W.combat = true
  W.key("PAD3", true)
  eq(ns.setLook("medallions"), false, "not in combat")
  eq(ns.db.look, "medallions", "saved")
  eq(ns.look.name, "sigil", "still the old look")
  eq(ns.looks.medallions.frame, nil, "nothing built in combat")
  W.tap("PADDUP")
  W.key("PAD3", false)
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(ns.look.name, "medallions", "after the fight")
  eq(ns.looks.sigil.frame:IsShown(), false)
  clean(W)
end)

-- Everyone in every state: a dispel and your HoT up, dead left, offline
-- right, out of range and nearly dead down.
local function troubled(W)
  W.units.party1.debuff = "Magic"
  W.units.party1.hot = true
  W.units.party4.dead = true
  W.units.party2.offline = true
  W.units.party3.hp = 10
  W.rangeOut.party3 = true
end

-- Holds X, aims all round (up, right, down, left, back to you) and lets go.
local function aimAround(W, ns, combat)
  W.combat = combat
  W.key("PAD3", true)
  eq(ns.diamond:IsShown(), true)
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT", "RIGHT" }) do
    W.tap("PADD" .. d)
    W.update(0.6)
  end
  eq(ns.ctl:GetAttribute("sel"), "SELF", "the opposite way: back to you")
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(ns.diamond:IsShown(), false)
  W.combat = false
end

for _, name in ipairs({ "medallions", "sigil", "compass", "classic" }) do
  test("look " .. name .. ": draws everyone in every state, in and out of combat", function()
    local W, ns = game()
    troubled(W)
    eq(ns.setLook(name), true)
    local s = ns.spots
    for _, combat in ipairs({ false, true }) do
      W.combat = combat
      W.key("PAD3", true)
      W.update(0.6)
      eq(s.UP.name.text, "Brakka", "name")
      eq(s.SELF.name.text, "Me")
      eq(Wow.isSecret(s.UP.health.value), combat, "health bar value secret in combat")
      eq(s.UP.dispel:IsShown(), true, "dispel pip")
      eq(s.UP.hot:IsShown(), true, "HoT pip")
      eq(s.UP.hot.icon.texture, 136081, "your HoT's icon")
      eq(s.LEFT.state.texture, ns.kit.SKULL, "dead: skull")
      eq(s.LEFT.state:IsShown(), true)
      eq(s.LEFT.dispel:IsShown(), false)
      eq(s.RIGHT.state.texture, ns.kit.PLUG, "offline: unplugged")
      eq(s.RIGHT.state:IsShown(), true)
      eq(s.SELF.state:IsShown(), false, "you are fine")
      eq(s.DOWN.crit, nil, "no red pulse")
      if combat then
        eq(Wow.isSecret(s.DOWN.body.alphaBool[1]), true, "out of range: faded by the game")
      else
        eq(s.DOWN.far, true, "out of range")
      end
      if name == "compass" then
        eq(s.UP.miss.text, "-20", "missing health")
        eq(s.DOWN.miss.text, "-90")
      end
      W.key("PAD3", false)
      W.combat = false
      aimAround(W, ns, combat)
    end
    -- The cast landed on you last: the look's cast ran without an error.
    clean(W)
  end)

  test("look " .. name .. ": alone, the Target spot; the settings' example people", function()
    local W, ns = game({ party = false })
    ns.setLook(name)
    W.key("PAD3", true)
    W.update(0.6)
    eq(ns.spots.UP.name.text, "Target", "nobody targeted: the empty Target spot")
    eq(ns.spots.UP.body.alpha, 0.45)
    eq(ns.spots.RIGHT:IsShown(), false)
    W.tap("PADDUP")
    W.key("PAD3", false)
    ns.openOptions()
    eq(ns.diamond:IsShown(), true, "preview")
    eq(ns.spots.UP.hot:IsShown(), true, "sample HoT")
    eq(ns.spots.RIGHT.dispel:IsShown(), true, "sample dispel")
    eq(ns.spots.LEFT.far, true, "sample out of range")
    eq(ns.spots.DOWN.crit, nil, "no red pulse in the preview")
    ns.optionsPanel():Hide()
    clean(W)
  end)
end

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
  W.key("PAD1", true)
  W.tap("PADDUP")
  W.key("PAD1", false)
  eq(last(W).spell, 774)
  eq(last(W).unit, "Brakka")
  W.setBar("p1")
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Zed")
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
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.tap("PAD2")
  W.key("PAD3", false)
  eq(#W.casts, 0, "B cancelled the aim")
  eq(#W.barPresses, 1, "and did not cast its spell")
  clean(W)
end)

test("cancel with Y, aim with the right stick", function()
  local W, ns = game({ saved = { aim = { PAD3 = { tap = "player" } }, cancel = "PAD4", aimWith = "rstick" } })
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDUP")
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
  W.key("SHIFT-PAD3", true)
  W.tap("SHIFT-PADDRIGHT")
  W.key("SHIFT-PAD3", false)
  eq(last(W).spell, 5185)
  eq(last(W).unit, "Kira")
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
  W.key("PAD1", true)
  W.tap("PADDUP")
  W.tap("PADRSHOULDER")
  eq(last(W).spell, 5185, "RB cast its heal")
  eq(last(W).unit, "Brakka")
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
    if me then
      W.units.player = W.units["raid" .. i]
    end
  end
  add(1, "Tanky", 1, "TANK")
  add(2, "Bob", 1, "DAMAGER")
  add(3, "Me", 2, "HEALER", true)
  add(4, "Cat", 2, "DAMAGER")
  add(5, "Dee", 3, "DAMAGER")
  local ns = W.load(DIR, FILES, { aim = { PAD3 = { tap = "player" } } })
  local c = ns.ctl
  eq(c:GetAttribute("pages"), 3)
  eq(c:GetAttribute("u1-SELF"), "player", "my group first, me in the middle")
  eq(c:GetAttribute("u1-UP"), "Cat")
  eq(c:GetAttribute("u2-SELF"), "Tanky", "group 1 next, in raid order")
  eq(c:GetAttribute("u2-UP"), "Bob")
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADRSHOULDER")
  eq(c:GetAttribute("page"), 2)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).unit, "Bob")
  W.key("PAD3", true)
  W.tap("PADLSHOULDER")
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
  W.G.SecureHandlerExecute = function(...)
    n = n + 1
    return old(...)
  end
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

test("a KeyBars key is read through its override; self-only spells aren't heals", function()
  local W = Wow.new()
  setup(W)
  party(W)
  W.actions[9] = { "spell", 7777 }
  W.bind("ACTIONBUTTON9", "9")
  local kb = W.G.CreateFrame("Button", "KeyBarsSlot1", W.G.UIParent, "SecureActionButtonTemplate")
  kb.attrs.type, kb.attrs.spell = "spell", 5186
  W.overrides["2"] = { owner = kb, target = "KeyBarsSlot1", priority = true }
  local ns = W.load(DIR, FILES, { aim = { ["2"] = { tap = "player" } } })
  local found, walk = nil, nil
  for _, b in ipairs(ns.binds) do
    if b.key == "2" then
      found = b
    end
    if b.key == "9" then
      walk = b
    end
  end
  eq(found and found.spell, 5186, "KeyBars key 2 casts Healing Touch")
  eq(walk, nil, "Walk on Air is no heal")
  eq(W.secureBinds["2"] and W.secureBinds["2"].target, "HealpadHeal1", "Healpad holds 2")
  ns.applyKeys(true)
  local again
  for _, b in ipairs(ns.binds) do
    if b.key == "2" then
      again = b
    end
  end
  eq(again and again.spell, 5186, "still read beneath Healpad's own binding")
  W.combat = true
  W.key("2", true)
  W.tap("UP")
  W.key("2", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka")
  clean(W)
end)

-- KeyBars with key 1: Healing Touch on Normal, Maul on the Bear layer.
local function withKeyBars(W)
  local kb = W.G.CreateFrame("Button", "KeyBarsButton1", W.G.UIParent, "SecureActionButtonTemplate")
  kb.attrs.type, kb.attrs.spell = "spell", "Healing Touch"
  W.overrides["1"] = { owner = kb, target = "KeyBarsButton1", priority = true }
  local listeners = {}
  W.G.KeyBarsAPI = {
    version = 1,
    slots = function()
      return {
        {
          key = "1",
          button = "KeyBarsButton1",
          layers = {
            { id = 1, name = "Normal", spell = 5185, cast = "Healing Touch" },
            { id = 11, name = "Bear", spell = 6807, cast = "Maul" },
          },
        },
      }
    end,
    onChange = function(fn)
      table.insert(listeners, fn)
    end,
  }
  return kb, listeners
end

-- Settings helpers: what the window shows, without color codes.
local function plainText(t)
  return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function under(f, p)
  while f do
    if f == p then
      return true
    end
    f = f.parent
  end
end
-- Every word in the settings window, shown or not.
local function panelTexts(W)
  local p, out = W.G.HealpadOptions, {}
  for _, fs in ipairs(W.fontStrings) do
    if fs.text and fs.text ~= "" and under(fs, p) then
      table.insert(out, plainText(fs.text))
    end
  end
  for _, f in ipairs(W.frames) do
    if type(f.text) == "string" and f.text ~= "" and under(f, p) then
      table.insert(out, plainText(f.text))
    end
  end
  return out
end
local function rowKeys(ns)
  local got = {}
  for _, r in ipairs(ns.optionsDebug().rows) do
    got[#got + 1] = ns.bindLabel(r.bind)
  end
  return table.concat(got, " ")
end

local function tabNames(d)
  local tabs = {}
  for _, t in ipairs(d.ui.tabs) do
    tabs[#tabs + 1] = t.text
  end
  return table.concat(tabs, ",")
end
-- The title over the menu.
local function menuTitle(W, ns)
  for _, fs in ipairs(W.fontStrings) do
    if fs.parent == ns.diamond and fs.font == "GameFontNormalLarge" then
      return fs.text
    end
  end
end
local function click(f)
  f:GetScript("OnClick")(f)
end

test("settings: a narrow window, no portrait or band; Heals and Menu tabs; LB and RB switch", function()
  local W, ns = game()
  ns.openOptions()
  local p = W.G.HealpadOptions
  local d = ns.optionsDebug()
  eq(p.noPortrait, true, "portrait hidden")
  eq(p.noAttic, true, "no band under the title")
  eq(tabNames(d), "Heals,Menu")
  eq(p:GetWidth(), 392)
  eq(d.st.tab, "heals")
  eq(d.ui.heals:IsShown() and not d.ui.menu:IsShown(), true, "Heals first")
  local h = p:GetHeight()
  W.tap("PADRSHOULDER")
  eq(d.st.tab, "menu", "RB")
  eq(d.ui.menu:IsShown() and not d.ui.heals:IsShown(), true)
  eq(p:GetHeight(), h, "the same height on both tabs")
  W.tap("PADRSHOULDER")
  eq(d.st.tab, "menu", "RB stays on the last tab")
  W.tap("PADLSHOULDER")
  eq(d.st.tab, "heals", "LB")
  W.tap("E")
  eq(d.st.tab, "menu", "E")
  W.tap("Q")
  eq(d.st.tab, "heals", "Q")
  click(d.ui.tabs[2])
  eq(d.st.tab, "menu", "a click on a tab")
  click(d.ui.tabs[1])
  eq(d.st.tab, "heals")
  clean(W)
end)

test("settings: no word with aim or KeyBars, and no layer names", function()
  local W = Wow.new()
  setup(W)
  party(W)
  withKeyBars(W)
  local ns = W.load(DIR, FILES, { aim = { PAD3 = { tap = "player" } } })
  ns.openOptions()
  local d = ns.optionsDebug()
  for _, r in ipairs(d.rows) do
    eq(r.bind.heal, true, "a heal: " .. ns.bindLabel(r.bind))
  end
  eq(rowKeys(ns):find("Y") == nil, true, "Y (Wrath) is not listed")
  local kb = 0
  for _, r in ipairs(d.rows) do
    if r.bind.kb then
      kb = kb + 1
    end
  end
  eq(kb, 1, "the KeyBars key is listed once")
  -- every tab drawn, Move on, every tap choice shown; then every word
  W.tap("PADRSHOULDER")
  for _ = 1, 5 do
    W.tap("PADDDOWN")
  end
  W.tap("PAD1")
  W.tap("PAD1")
  W.tap("PADLSHOULDER")
  local words = panelTexts(W)
  for _ = 1, 5 do
    W.tap("PADDRIGHT")
    for _, t in ipairs(panelTexts(W)) do
      table.insert(words, t)
    end
  end
  for _, t in ipairs(words) do
    eq(t:find("KeyBars") == nil, true, "no KeyBars: " .. t)
    eq(t:find("Normal") == nil and t:find("Bear") == nil, true, "no layer name: " .. t)
    eq(t:lower():find("aim") == nil, true, "no aim: " .. t)
  end
  ns.optionsPanel():Hide()
  clean(W)
end)

test("settings: Heals: a checkbox, the icon with its key, name and rank, who a tap heals", function()
  local W, ns = game()
  ns.openOptions()
  local d = ns.optionsDebug()
  eq(rowKeys(ns), "A B X LT+X 1", "heals, Wrath left out")
  local words = table.concat(panelTexts(W), "|")
  eq(words:find("Hold for menu", 1, true) ~= nil, true, "left heading")
  eq(words:find("Quick tap heals", 1, true) ~= nil, true, "right heading")
  local on, off = d.ui.rows[1], d.ui.rows[2]
  eq(on.check:GetChecked(), true, "A holds for the menu: ticked")
  eq(on.hotkey:GetText(), "A", "the key on the icon")
  eq(on.icon.texture, ns.spellIcon(774), "the spell's icon")
  eq(on.icon:IsDesaturated(), false)
  eq(on.name:GetText(), "Rejuvenation")
  eq(on.rank:GetText(), "Rank 1")
  eq(on.name.textColor[1], 1, "gold name")
  eq(on.cycler:IsShown(), true)
  eq(on.cycler.value:GetText(), "You")
  eq(off.check:GetChecked(), false, "B: not ticked")
  eq(off.hotkey:GetText(), "B")
  eq(off.name:GetText(), "Healing Touch")
  eq(off.icon:IsDesaturated(), true, "grey icon")
  eq(off.name.textColor[1] < 0.6, true, "grey name")
  eq(off.cycler:IsShown(), false, "no tap choice while off")
  eq(d.ui.rows[3].check:GetChecked(), true, "X")
  eq(d.ui.rows[5].hotkey:GetText(), "1")
  clean(W)
end)

test("settings: A, a click on the row or on its checkbox: holds for the menu, or casts as before", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  local p = W.G.HealpadOptions
  local d = ns.optionsDebug()
  eq(W.overrides.PADDDOWN.target, "HealpadNavDOWN", "the pad drives the window")
  W.tap("PADDDOWN")
  W.tap("PADDDOWN") -- X
  eq(d.focus(), 3)
  W.tap("PAD1")
  eq(ns.db.aim.PAD3 ~= nil, true, "A ticks it: X holds for the menu")
  eq(ns.db.aim.PAD3.tap, "player")
  eq(ns.heals[1]:GetAttribute("hp-key"), "PAD3")
  eq(d.ui.rows[3].check:GetChecked(), true)
  eq(d.ui.rows[3].cycler:IsShown(), true, "the tap choice shows")
  W.tap("ENTER")
  eq(ns.db.aim.PAD3, nil, "Enter: off again")
  eq(ns.heals[1]:GetAttribute("hp-key"), nil)
  eq(d.ui.rows[3].check:GetChecked(), false)
  click(d.ui.rows[3])
  eq(ns.db.aim.PAD3 ~= nil, true, "a click on the row")
  click(d.ui.rows[3].check)
  eq(ns.db.aim.PAD3, nil, "a click on the checkbox")
  click(d.ui.rows[2].check)
  eq(ns.db.aim.PAD2 ~= nil, true, "another row's checkbox")
  eq(d.st.li, 2, "and the window is on it")
  click(d.ui.rows[2])
  click(d.ui.rows[3].check)
  p:Hide()
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka", "it holds for the menu")
  W.tap("PAD2")
  eq(W.barPresses[#W.barPresses].command, "ACTIONBUTTON4", "B, off again, casts as bound")
  clean(W)
end)

test("settings: Left and Right change who a quick tap heals, only on a ticked heal", function()
  local W, ns = game()
  ns.openOptions()
  local d = ns.optionsDebug()
  W.tap("PADDDOWN")
  W.tap("PADDDOWN") -- X, ticked
  local seen = {}
  for _ = 1, 5 do
    W.tap("PADDRIGHT")
    seen[#seen + 1] = ns.db.aim.PAD3.tap .. "=" .. d.ui.rows[3].cycler.value:GetText()
  end
  eq(table.concat(seen, ","), "target=Target,focus=Focus,tank=Tank,last=Last healed,player=You")
  eq(ns.heals[1]:GetAttribute("hp-tap") ~= nil, true)
  W.tap("PADDLEFT")
  eq(ns.db.aim.PAD3.tap, "last", "left goes back round")
  eq(d.ui.rows[3].cycler.value:GetText(), "Last healed", "whole")
  W.tap("PADDUP") -- B, off
  W.tap("PADDRIGHT")
  eq(ns.db.aim.PAD2, nil, "an off heal has no tap choice")
  local c = d.ui.rows[1].cycler
  click(c.right)
  eq(ns.db.aim.PAD1.tap, "target", "a click on the right arrow")
  click(c.mid)
  eq(ns.db.aim.PAD1.tap, "focus", "a click on the value steps on")
  click(c.left)
  click(c.left)
  eq(ns.db.aim.PAD1.tap, "player", "the left arrow steps back")
  eq(d.st.li, 1)
  clean(W)
end)

test(
  "settings: the real menu is the preview: titled with the heal, its tap person lit, gone for an off heal",
  function()
    local W, ns = game({ party = false })
    ns.openOptions()
    local d = ns.optionsDebug()
    eq(ns.diamond:IsShown(), true, "the menu shows with the window")
    eq(ns.diamond:GetAlpha(), 1)
    eq(menuTitle(W, ns), "Rejuvenation (Rank 1)", "the heal the window is on")
    eq(ns.spots.UP.name.text, "Thrain", "the example party")
    eq(ns.spots.SELF.sel:IsShown(), true, "a tap heals you: you lit")
    W.tap("PADDRIGHT")
    eq(ns.spots.RIGHT.sel:IsShown(), true, "Target: the one on the right")
    eq(ns.spots.SELF.sel:IsShown(), false)
    W.tap("PADDRIGHT")
    eq(ns.spots.LEFT.sel:IsShown(), true, "Focus")
    W.tap("PADDRIGHT")
    eq(ns.spots.UP.sel:IsShown(), true, "Tank")
    W.tap("PADDRIGHT")
    eq(ns.spots.DOWN.sel:IsShown(), true, "Last healed")
    W.tap("PADDDOWN") -- B, off
    eq(menuTitle(W, ns), "Healing Touch (Rank 1)")
    eq(ns.diamond:GetAlpha(), 0, "faded out: B doesn't hold for the menu")
    eq(ns.diamond:IsShown(), true)
    W.tap("PADDDOWN") -- X
    eq(ns.diamond:GetAlpha(), 1, "back")
    eq(menuTitle(W, ns), "Healing Touch (Rank 2)")
    W.tap("PADDUP")
    W.tap("PADRSHOULDER")
    eq(ns.diamond:GetAlpha(), 1, "on Menu it always shows")
    eq(ns.spots.RIGHT.sel:IsShown(), true)
    W.G.HealpadOptions:Hide()
    eq(ns.diamond:IsShown(), false, "gone with the window")
    eq(ns.diamond:GetAlpha(), 1)
    clean(W)
  end
)

test("settings: Menu: the labels; every control as wide, arrows in two columns", function()
  local W, ns = game()
  ns.openOptions()
  W.tap("PADRSHOULDER")
  local d = ns.optionsDebug()
  local labels, values = {}, {}
  for i, f in ipairs(d.ui.mlist) do
    labels[i] = f.label:GetText()
    if f.ctl then
      eq(f.ctl:GetWidth(), d.layout.CTL_W, f.key .. " as wide as the rest")
      eq(f.ctl.left:GetWidth(), f.ctl.right:GetWidth())
      values[#values + 1] = plainText(f.ctl.value:GetText())
    end
  end
  eq(table.concat(labels, ","), "Style,Size,Spacing,Select person with,Cancel heal with,Menu position")
  eq(table.concat(values, ","), "Classic,100%,100%,D-pad,B")
  local pos = d.ui.mrows.pos
  eq(pos.move:GetWidth() * 2 + 8, d.layout.CTL_W, "Move and Reset as wide as a control")
  eq(pos.move:GetText(), "Move")
  eq(pos.reset:GetText(), "Reset")
  eq(pos.move.template, "UIPanelButtonTemplate", "red buttons")
  eq(d.ui.rows[1].check.template, "UICheckButtonTemplate", "the game's checkbox")
  eq(d.ui.mrows.cancel.ctl.value:GetText():find("|c") ~= nil, true, "B in its color")
  clean(W)
end)

test("settings: Menu: Left and Right change each row, A steps on, clicks too", function()
  local W, ns = game({ party = false })
  ns.openOptions()
  W.tap("PADRSHOULDER")
  local d = ns.optionsDebug()
  local m = d.ui.mrows
  eq(d.focus(), "look")
  W.tap("PADDRIGHT")
  eq(ns.db.look, "medallions", "Style")
  eq(ns.look.name, "medallions", "the menu shows it")
  eq(m.look.ctl.value:GetText(), "Medallions")
  W.tap("PADDLEFT")
  W.tap("PADDLEFT")
  eq(ns.db.look, "compass", "round the end")
  W.tap("ENTER")
  eq(ns.db.look, "classic", "A steps on")
  click(m.look.ctl.right)
  eq(ns.db.look, "medallions", "a click")
  eq(ns.spots.UP.name.text, "Thrain", "the example party in the new look")
  W.tap("PADDDOWN")
  eq(d.focus(), "size")
  W.tap("PADDRIGHT")
  eq(ns.db.scale, 1.1, "Size")
  eq(m.size.ctl.value:GetText(), "110%")
  eq(ns.diamond.scale, 1.1, "the menu grows")
  for _ = 1, 8 do
    W.tap("PADDLEFT")
  end
  eq(ns.db.scale, 0.6, "stops at 60%")
  eq(m.size.ctl.left:IsEnabled(), false, "no further left")
  for _ = 1, 12 do
    W.tap("ENTER")
  end
  eq(ns.db.scale, 1.6, "and at 160%")
  eq(m.size.ctl.right:IsEnabled(), false)
  W.tap("PADDDOWN")
  eq(d.focus(), "spacing")
  local r = ns.looks.medallions.r
  W.tap("PADDRIGHT")
  eq(ns.db.spacing, 1.1, "Spacing")
  eq(m.spacing.ctl.value:GetText(), "110%")
  eq(ns.looks.medallions.r > r, true, "the people move apart")
  for _ = 1, 9 do
    W.tap("PADDLEFT")
  end
  eq(ns.db.spacing, 0.6, "stops at 60%")
  click(m.spacing.ctl.mid)
  eq(ns.db.spacing, 0.7, "a click on the bar steps on")
  W.tap("PADDDOWN")
  eq(d.focus(), "pick")
  W.tap("PADDRIGHT")
  eq(ns.db.aimWith, "lstick")
  eq(m.pick.ctl.value:GetText(), "Left stick")
  W.tap("ENTER")
  eq(ns.db.aimWith, "rstick")
  W.tap("PADDRIGHT")
  eq(ns.db.aimWith, "dpad", "round the end")
  W.tap("PADDDOWN")
  eq(d.focus(), "cancel")
  W.tap("PADDRIGHT")
  eq(ns.db.cancel, "PAD4", "B to Y: X holds for the menu, skipped")
  eq(plainText(m.cancel.ctl.value:GetText()), "Y")
  W.tap("PADDRIGHT")
  eq(ns.db.cancel, "PAD2", "A is skipped too")
  click(m.cancel.ctl.left)
  eq(ns.db.cancel, "PAD4")
  clean(W)
end)

test("settings: Spacing: a saved Spread becomes the nearest tenth once; every look uses it", function()
  local want = { [1] = 0.8, [2] = 0.9, [3] = 1, [4] = 1.1, [5] = 1.2 }
  for d, v in pairs(want) do
    local W, ns = game({ saved = { distance = d, aim = {} } })
    eq(ns.db.spacing, v, "Spread " .. d)
    clean(W)
  end
  local W, ns = game({ saved = { aim = {} } })
  eq(ns.db.spacing, 1, "new: the usual")
  eq(ns.db.distance, nil)
  clean(W)
  W, ns = game({ saved = { spacing = 1.3, distance = 1, aim = {} } })
  eq(ns.db.spacing, 1.3, "converted once, then kept")
  clean(W)
  -- the usual spacing is where the old Spread 3 put everyone
  W, ns = game({ saved = { aim = {} } })
  eq(math.abs(ns.looks.classic.spots.RIGHT.at[1] - (128 * 1.15 / 2 + 64 + 32)) < 0.01, true, "Classic as before")
  for _, name in ipairs(ns.LOOKS) do
    ns.setLook(name)
    local at = {}
    for _, v in ipairs({ 0.6, 1, 1.4 }) do
      ns.db.spacing = v
      ns.layout()
      at[#at + 1] = ns.spots.RIGHT.at[1]
    end
    eq(at[1] < at[2] and at[2] < at[3], true, name .. ": farther apart as it grows")
  end
  ns.db.spacing = 1
  ns.setLook("sigil")
  eq(ns.looks.sigil.r, 180, "Sigil as before")
  ns.setLook("medallions")
  eq(ns.looks.medallions.r, 160, "Medallions as before")
  ns.setLook("compass")
  eq(ns.looks.compass.spots.UP.at[2], 158, "Compass as before")
  ns.db.spacing = 1.4
  ns.setLook("sigil")
  eq(ns.looks.sigil.r, 92 + 88 * 1.4, "Sigil at 140%")
  clean(W)
end)

test("settings: Menu position: Move becomes Done, the d-pad and sticks nudge, Reset puts it back", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  W.tap("PADRSHOULDER")
  local d = ns.optionsDebug()
  local pos = d.ui.mrows.pos
  -- not moving: the sticks and the d-pad never move it
  W.G.C_GamePad = {
    GetActiveDeviceID = function()
      return 1
    end,
    GetDeviceMappedState = function()
      return { sticks = { { x = 1, y = 0 }, { x = 0, y = 0 } } }
    end,
  }
  W.update(0.5)
  eq(ns.db.x, 0, "no Move, no moving")
  for _ = 1, 5 do
    W.tap("PADDDOWN")
  end
  eq(d.focus(), "move")
  eq(pos.reset:IsEnabled(), false, "Reset off: already in the middle")
  W.tap("PADDRIGHT")
  eq(d.focus(), "move", "the focus skips Reset while it's off")
  eq(d.ui.ring.target, pos.move, "the gold edge on Move")
  W.tap("PAD1")
  eq(pos.move:GetText(), "Done", "Move becomes Done")
  W.update(0.5)
  eq(ns.db.x, 350, "a stick glides it")
  W.G.C_GamePad = nil
  ns.db.x = 0
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  W.tap("PADDUP")
  eq(ns.db.x, 40, "the d-pad nudges")
  eq(ns.db.y, 20)
  W.tap("PAD2")
  eq(W.G.HealpadOptions:IsShown(), true, "B leaves Move, the window stays")
  eq(pos.move:GetText(), "Move")
  eq(pos.reset:IsEnabled(), true)
  W.tap("PADDRIGHT")
  eq(d.focus(), "reset")
  eq(d.ui.ring.target, pos.reset)
  W.tap("PAD1")
  eq(ns.db.x, 0, "Reset")
  eq(ns.db.y, 0)
  eq(d.focus(), "move", "back to Move")
  click(pos.move)
  eq(pos.move:GetText(), "Done", "a click")
  W.tap("PADDLEFT")
  click(pos.move)
  eq(pos.move:GetText(), "Move")
  eq(ns.db.x, -20, "it is kept")
  W.tap("PADLSHOULDER")
  W.tap("PADRSHOULDER")
  click(pos.reset)
  eq(ns.db.x, 0, "Reset with a click")
  clean(W)
end)

test("settings: B closes, Esc too, from either tab; the keys and the menu go with it", function()
  local W, ns = game()
  local p = W.G.HealpadOptions
  for _, key in ipairs({ "PAD2", "ESCAPE" }) do
    for _, tab in ipairs({ "PADLSHOULDER", "PADRSHOULDER" }) do
      ns.openOptions()
      p = W.G.HealpadOptions
      W.tap(tab)
      eq(ns.diamond:IsShown(), true)
      W.tap(key)
      eq(p:IsShown(), false, key .. " closes")
      eq(ns.diamond:IsShown(), false, "the menu goes too")
      eq(W.overrides.PADDDOWN, nil, "nav keys given back")
      eq(W.overrides.ESCAPE, nil, "Esc is the game's again")
    end
  end
  clean(W)
end)

test("settings: the gold edge only while you drive with the pad; the mouse lights the row it is on", function()
  local W, ns = game()
  ns.openOptions()
  local d = ns.optionsDebug()
  eq(d.ui.ring:IsShown(), false, "no edge at first")
  W.tap("PADDDOWN")
  eq(d.ui.ring:IsShown(), true, "the pad: an edge")
  eq(d.ui.ring.target, d.ui.rows[2])
  eq(d.ui.rows[2].lit:IsShown(), true, "and the row lit")
  W.cursor = { 10, 10 }
  W.update(0.1)
  eq(d.ui.ring:IsShown(), false, "the mouse moved: no edge")
  eq(d.ui.rows[2].lit:IsShown(), false)
  local row = d.ui.rows[3]
  row:GetScript("OnEnter")(row)
  eq(d.st.li, 3, "the mouse over a heal: the menu shows it")
  eq(row.hover:IsShown(), true)
  eq(ns.previewSpell, 5186)
  row:GetScript("OnLeave")(row)
  eq(row.hover:IsShown(), false)
  clean(W)
end)

test("settings: every label fits; a long one steps its font down; Last healed stays whole", function()
  local W, ns = game({ saved = { aim = { PAD3 = { tap = "last" } } } })
  W.book = {}
  for i, b in ipairs(BOOK) do
    W.book[i] = { id = b.id, name = b.name, sub = b.sub, helpful = b.helpful, selfOnly = b.selfOnly }
  end
  W.book[2].name = "Healing Touch of the Ancient Grove"
  ns.openOptions()
  local d = ns.optionsDebug()
  W.tap("PADRSHOULDER")
  W.tap("PADLSHOULDER")
  eq(#d.fitted > 10, true, "labels are fitted")
  for _, f in ipairs(d.fitted) do
    eq(f.fs:GetStringWidth() <= f.room, true, tostring(f.fs:GetText()) .. " fits " .. f.room)
  end
  local x = d.ui.rows[3]
  eq(x.name:GetText(), "Healing Touch of the Ancient Grove", "the whole name")
  eq(x.name.fontSize < 14, true, "in a smaller font")
  eq(d.ui.rows[1].name.fontSize, 14, "a short one keeps its size")
  eq(x.cycler.value:GetText(), "Last healed")
  eq(d.ui.mrows.pick.label:GetText(), "Select person with")
  eq(d.layout.NAME_W > 100 and d.layout.LABEL_W > 100, true)
  clean(W)
end)

test("settings: the window keeps to the side of the screen the menu leaves free", function()
  local W, ns = game()
  ns.openOptions()
  local side = ns.optionsDebug().sideFor
  eq(side(440, 840, 1280, "right"), "left", "menu in the middle: left")
  eq(side(80, 500, 1280, "left"), "right", "menu on the left: right")
  eq(side(300, 1100, 1280, "right"), "right", "no room either side: stays")
  eq(side(300, 1100, 1280, "left"), "left")
  eq(side(nil, nil, 1280, "left"), "left", "unknown: stays")
  clean(W)
end)

test("KeyBars: its layers are listed; Healpad sits in its button and leaves the key alone", function()
  local W = Wow.new()
  setup(W)
  party(W)
  local kb = withKeyBars(W)
  local ns = W.load(DIR, FILES, { aim = {}, aimSpell = { ["Healing Touch"] = { tap = "player" } } })
  local found
  for _, b in ipairs(ns.binds) do
    if b.kb then
      found = b
    end
  end
  eq(found and found.layer, "Normal", "Healing Touch on Normal is listed")
  eq(found.cast, "Healing Touch")
  eq(W.overrides["1"].target, "KeyBarsButton1", "KeyBars keeps key 1")
  W.combat = true
  W.key("1", true)
  eq(#W.casts, 0, "the press casts nothing")
  eq(ns.diamond:IsShown(), true)
  W.tap("PADDRIGHT")
  W.key("1", false)
  eq(last(W).spell, "Healing Touch")
  eq(last(W).unit, "Kira")
  eq(kb.attrs.unit, nil, "the button is as KeyBars left it")
  eq(kb.attrs.useOnKeyDown, nil)
  eq(ns.diamond:IsShown(), false)
  -- bear form: KeyBars puts Maul on the key; it casts on the press as always
  kb.attrs.spell = "Maul"
  W.key("1", true)
  eq(last(W).spell, "Maul")
  eq(ns.diamond:IsShown(), false)
  W.key("1", false)
  eq(#W.casts, 2)
  clean(W)
end)

test("KeyBars: a tap set to Target heals your friendly target, alone and in a party", function()
  for _, grouped in ipairs({ false, true }) do
    local W = Wow.new()
    setup(W)
    if grouped then
      party(W)
    end
    withKeyBars(W)
    local ns = W.load(DIR, FILES, { aim = {}, aimSpell = { ["Healing Touch"] = { tap = "target" } } })
    W.combat = true
    W.units.target = { name = "Pal", hp = 1, max = 2, friendly = true }
    W.key("1", true)
    eq(ns.diamond:IsShown(), true)
    W.key("1", false)
    eq(last(W).unit, "target", grouped and "in a party" or "alone")
    clean(W)
  end
end)

test("KeyBars: ticking the heal in the settings reaches the button", function()
  local W = Wow.new()
  setup(W)
  party(W)
  withKeyBars(W)
  local ns = W.load(DIR, FILES, { aim = {} })
  ns.openOptions()
  local dbg = ns.optionsDebug()
  local li
  for n, r in ipairs(dbg.rows) do
    if r.bind.kb then
      li = n
    end
  end
  dbg.st.li = li
  ns.optionsNav("A")
  eq(ns.db.aimSpell["Healing Touch"] ~= nil, true)
  eq(ns.ctl:GetAttribute("aimspell-Healing Touch"), "player")
  ns.optionsNav("RIGHT")
  eq(ns.db.aimSpell["Healing Touch"].tap, "target", "Right: the tap choice")
  eq(ns.ctl:GetAttribute("aimspell-Healing Touch"), "target")
  ns.optionsNav("LEFT")
  W.G.HealpadOptions:Hide()
  W.combat = true
  W.key("1", true)
  W.tap("UP")
  W.key("1", false)
  eq(last(W).unit, "Brakka")
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

test("/hp test runs in the game: both tabs, the menu, a hold, an aim, a cancel", function()
  local W, ns = game()
  W.G.SlashCmdList.HEALPAD("test")
  W.runTimers()
  local log = table.concat(ns.db.log, "\n")
  eq(log:find("TEST FAIL") == nil, true, log)
  eq(log:find("LUA ERROR") == nil, true, log)
  eq(log:find("TEST done: %d+ ok, 0 failed") ~= nil, true, log)
  eq(W.shots, 3, "screenshots: Heals, Menu, a hold")
  eq(#W.casts, 0, "nothing cast")
  clean(W)
end)

test("/hp shots page stages every look and both tabs, takes 10 screenshots, puts everything back", function()
  local W, ns = game({ party = false })
  local look = ns.db.look
  W.G.SlashCmdList.HEALPAD("shots page")
  W.runTimers()
  eq(W.shots, 10, "screenshots")
  eq(ns.db.look, look, "the look you had")
  eq(W.G.UIParent:IsShown(), true, "the UI is back")
  eq(ns.diamond.parent, W.G.UIParent, "the diamond is back on UIParent")
  eq(ns.diamond:IsShown(), false)
  eq(W.G.HealpadOptions:IsShown(), false)
  eq(ns.stage, nil)
  local log = table.concat(ns.db.log or {}, "\n")
  eq(log:find("SHOTS error") == nil, true, log)
  clean(W)
end)

test("/hp shots: screenshots while you play, the interface hidden out of combat", function()
  local W, ns = game()
  W.G.SlashCmdList.HEALPAD("shots")
  W.key("PAD3", true)
  W.runTimers()
  eq(W.shots, 1, "the menu opening")
  eq(W.G.UIParent:IsShown(), false, "the rest hidden")
  W.tap("PADDRIGHT")
  W.runTimers()
  eq(W.shots, 2, "a pick")
  W.key("PAD3", false)
  W.runTimers()
  eq(W.G.UIParent:IsShown(), true, "back on letting go")
  eq(ns.diamond.parent, W.G.UIParent)
  W.combat = true
  W.key("PAD3", true)
  W.runTimers()
  eq(W.shots, 3, "in combat too")
  eq(W.G.UIParent:IsShown(), true, "the interface stays in combat")
  W.key("PAD3", false)
  W.combat = false
  W.G.SlashCmdList.HEALPAD("shots")
  W.key("PAD3", true)
  W.runTimers()
  eq(W.shots, 3, "off again")
  W.key("PAD3", false)
  clean(W)
end)

-- Gamepad Mode, as the friend plays it: the game's controller bar, on an
-- Xbox pad. The heal is on action bar slot 3 (key 3) and on the controller
-- bar's left bar (LT) under A.
--   Up        top bar, slot 2:   Rejuvenation
--   LT+A      left bar, slot 16: Healing Touch r2 on pages 1 and 2, Wrath on 3
--   RT+X      right bar, slot 21: Wrath
local function gamepad(saved, opts)
  opts = opts or {}
  local W = Wow.new()
  setup(W)
  party(W)
  W.bind("ACTIONBUTTON3", "3")
  W.bind("SPELL Rejuvenation", "F")
  W.gamepad()
  if opts.off then
    W.gamepadMode = false
  end
  W.actions[W.gpStorage(1, 2)] = { "spell", 774 }
  W.actions[W.gpStorage(1, 16)] = { "spell", 5186 }
  W.actions[W.gpStorage(2, 16)] = { "spell", 5186 }
  W.actions[W.gpStorage(3, 16)] = { "spell", 5176 }
  W.actions[W.gpStorage(1, 21)] = { "spell", 5176 }
  local ns = W.load(DIR, FILES, saved or { aim = {}, aimPad = { [5186] = { tap = "player" } } })
  return W, ns
end
local function leftA(W)
  return W.G.GamepadMainActionBarFrame.PageUnit.actionBars.leftBar.actionButtons[8]
end

test("Gamepad Mode: the controller bar is listed with its triggers; the action bars' keys are not", function()
  local W, ns = gamepad()
  local got = {}
  for _, b in ipairs(ns.binds) do
    got[#got + 1] = ns.bindLabel(b) .. "=" .. tostring(b.spell)
    eq(b.command:match("^ACTIONBUTTON") or b.command:match("^MULTIACTIONBAR"), nil, "action bar key " .. b.key)
  end
  eq(table.concat(got, " "), "Up=774 LT+A=5186 RT+X=5176 F=774")
  local lt = ns.binds[2]
  eq(lt.gp, "left")
  eq(lt.key, "PAD1")
  eq(lt.group, "LT")
  eq(lt.heal, true)
  eq(lt.pages[1] and lt.pages[2] and not lt.pages[3], true, "Healing Touch on pages 1 and 2")
  eq(ns.binds[3].heal, false, "Wrath is no heal")
  ns.openOptions()
  eq(rowKeys(ns), "Up LT+A F", "the settings list the heals, no groups")
  W.G.HealpadOptions:Hide()
  clean(W)
end)

test("Gamepad Mode: hold LT+A, aim, let go: the heal casts on the aimed one in combat", function()
  local W, ns = gamepad()
  local b = leftA(W)
  eq(b.wrap ~= nil, true, "Healpad sits in the game's button")
  W.combat = true
  W.key("PADLTRIGGER", true)
  W.key("SHIFT-PAD1", true) -- LT holds Shift: the game's binding for A runs
  eq(#W.casts, 0, "the press casts nothing")
  eq(ns.diamond:IsShown(), true, "diamond open")
  W.update(0.3) -- the diamond draws the held spell
  W.tap("SHIFT-PADDUP")
  eq(ns.ctl:GetAttribute("sel"), "UP", "the d-pad aims, not the controller bar")
  W.key("PADLTRIGGER", false) -- LT let go first: the release still reaches A's button
  W.key("SHIFT-PAD1", false)
  eq(#W.casts, 1)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka")
  eq(last(W).combat, true)
  eq(ns.diamond:IsShown(), false)
  eq(W.secureBinds.PADDUP, nil, "d-pad given back")
  eq(b.attrs.unit, nil, "the button as the game set it")
  eq(b.attrs.useOnKeyDown, true)
  clean(W)
end)

test(
  "Gamepad Mode: a tap heals the tap choice; B cancels; a spell not set to aim casts as the game casts it",
  function()
    local W, ns = gamepad({ aim = {}, aimPad = { [5186] = { tap = "tank" } } })
    W.combat = true
    W.key("PADLTRIGGER", true)
    W.tap("SHIFT-PAD1")
    eq(last(W).unit, "Brakka", "the tank")
    eq(last(W).spell, 5186)
    W.key("SHIFT-PAD1", true)
    W.tap("SHIFT-PADDLEFT")
    W.tap("SHIFT-PAD2")
    W.key("SHIFT-PAD1", false)
    eq(#W.casts, 1, "B cancelled")
    W.key("PADLTRIGGER", false)
    W.key("PADDUP", true)
    eq(#W.casts, 2, "Rejuvenation casts on the press")
    eq(last(W).spell, 774)
    eq(last(W).unit, nil, "on whoever the game picks")
    eq(ns.diamond:IsShown(), false)
    W.key("PADDUP", false)
    clean(W)
  end
)

test("Gamepad Mode: the d-pad aims even when Gamepad Mode's bindings beat Healpad's", function()
  local W, ns = gamepad()
  W.contextFirst = true
  W.actions[W.gpStorage(1, 10)] = { "spell", 5176 } -- LT+Up: Wrath
  W.combat = true
  W.key("PADLTRIGGER", true)
  W.key("SHIFT-PAD1", true)
  eq(ns.diamond:IsShown(), true)
  W.tap("SHIFT-PADDUP")
  eq(ns.ctl:GetAttribute("sel"), "UP", "up picked through the game's button")
  W.tap("SHIFT-PADDDOWN")
  eq(ns.ctl:GetAttribute("sel"), "SELF", "the opposite way comes back to you")
  W.tap("SHIFT-PADDRIGHT")
  eq(#W.casts, 0, "the d-pad's own spells cast nothing")
  W.key("PADLTRIGGER", false)
  W.key("SHIFT-PAD1", false)
  eq(#W.casts, 1)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Kira")
  W.key("PADDUP", true)
  eq(last(W).spell, 774, "after the hold the d-pad is the game's again")
  W.key("PADDUP", false)
  clean(W)
end)

test("stick aiming turns on the game's stick buttons", function()
  local W = Wow.new()
  setup(W)
  party(W)
  W.cvars.GamePadStickAxisButtons = "0"
  W.load(DIR, FILES, { aimWith = "rstick", aim = { PAD3 = { tap = "player" } } })
  eq(W.cvars.GamePadStickAxisButtons, "1")
  clean(W)
end)

test("Gamepad Mode: a d-pad heal leaves its own button alone and aims with the others", function()
  local W, ns = gamepad({ aim = {}, aimPad = { [774] = { tap = "player" } } })
  W.combat = true
  W.key("PADDUP", true)
  eq(ns.diamond:IsShown(), true)
  eq(W.secureBinds.PADDUP, nil, "up stays the game's")
  eq(W.secureBinds.PADDRIGHT and W.secureBinds.PADDRIGHT.target, "HealpadDirRIGHT")
  W.tap("PADDRIGHT")
  W.key("PADDUP", false)
  eq(last(W).spell, 774)
  eq(last(W).unit, "Kira")
  clean(W)
end)

test("Gamepad Mode: the page and the stance decide what a button casts", function()
  local W, ns = gamepad()
  W.combat = true
  W.setGamepadPage(3)
  W.key("PADLTRIGGER", true)
  W.key("SHIFT-PAD1", true)
  eq(last(W).spell, 5176, "page 3: Wrath, cast on the press")
  eq(ns.diamond:IsShown(), false)
  W.key("SHIFT-PAD1", false)
  W.setGamepadPage(2)
  W.key("SHIFT-PAD1", true)
  W.tap("SHIFT-PADDRIGHT")
  W.key("SHIFT-PAD1", false)
  eq(last(W).spell, 5186, "page 2 has the heal too")
  eq(last(W).unit, "Kira")
  W.setGamepadPage(1)
  W.actions[507] = { "spell", 6807 }
  W.setGamepadStance(500, 1, "leftBar", "2") -- bear form's bar on page 1's LT bar
  W.key("SHIFT-PAD1", true)
  eq(last(W).spell, 6807, "Maul")
  eq(ns.diamond:IsShown(), false)
  W.key("SHIFT-PAD1", false)
  W.key("PADLTRIGGER", false)
  W.combat = false
  ns.applyKeys(true)
  eq(ns.binds[2].label .. "=" .. ns.binds[2].spell, "LT+A=6807", "the list shows the stance's spell")
  clean(W)
end)

test("Gamepad Mode: ticking the heal in the settings reaches the controller bar", function()
  local W, ns = gamepad({ aim = {} })
  ns.openOptions()
  local dbg = ns.optionsDebug()
  dbg.st.li = 2 -- LT+A
  ns.optionsNav("A")
  eq(ns.db.aimPad[5186] ~= nil, true)
  eq(ns.ctl:GetAttribute("gpaim-5186"), "player")
  W.G.HealpadOptions:Hide()
  W.combat = true
  W.key("PADLTRIGGER", true)
  W.key("SHIFT-PAD1", true)
  W.tap("SHIFT-PADDDOWN")
  W.key("SHIFT-PAD1", false)
  eq(last(W).unit, "Ann")
  clean(W)
end)

test("out of Gamepad Mode the controller bar is left alone and your keys work as before", function()
  local W, ns = gamepad(
    { aim = { PAD3 = { tap = "player" } }, aimPad = { [5186] = { tap = "player" } } },
    { off = true }
  )
  local keys = {}
  for _, b in ipairs(ns.binds) do
    keys[#keys + 1] = b.key
    eq(b.gp, nil)
  end
  eq(table.concat(keys, " "), "PAD1 PAD2 PAD3 PAD4 SHIFT-PAD3 1 F")
  eq(leftA(W).wrap, nil, "the game's button is untouched")
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka")
  -- Gamepad Mode turned on: the controller bar instead
  W.combat = false
  W.gamepadMode = true
  W.fire("INPUT_DEVICE_INTERFACE_TRANSITION")
  eq(ns.binds[1].gp, "top", "the controller bar now")
  eq(ns.heals[1]:GetAttribute("hp-key"), nil, "X is the controller bar's again")
  eq(W.secureBinds.PAD3, nil)
  W.combat = true
  W.key("PADLTRIGGER", true)
  W.key("SHIFT-PAD1", true)
  W.tap("SHIFT-PADDLEFT")
  W.key("SHIFT-PAD1", false)
  eq(last(W).unit, "Zed")
  clean(W)
end)

test("/hp test in Gamepad Mode reports the controller bar", function()
  local W, ns = gamepad()
  W.G.SlashCmdList.HEALPAD("test")
  W.runTimers()
  local log = table.concat(ns.db.log, "\n")
  eq(log:find("TEST FAIL") == nil, true, log)
  eq(log:find("LUA ERROR") == nil, true, log)
  eq(log:find("REPORT gamepad mode on, page 1") ~= nil, true, log)
  eq(
    log:find("REPORT bind PAD1 = left bar 8 -> Healing Touch (Rank 2) heal=true pages=1,2 AIM", 1, true) ~= nil,
    true,
    log
  )
  eq(#W.casts, 0, "nothing cast")
  clean(W)
end)

---------------------------------------------------------------- Party Frames: Plus

-- The game's party frames, as this client makes them.
local function gameFrames(W)
  local pf = W.G.CreateFrame("Frame", "PartyFrame", W.G.UIParent)
  pf:RegisterEvent("GROUP_ROSTER_UPDATE")
  pf:RegisterEvent("VARIABLES_LOADED")
  local raid = W.G.CreateFrame("Frame", "CompactRaidFrameManager", W.G.UIParent)
  raid:RegisterEvent("GROUP_ROSTER_UPDATE")
  return pf, raid
end

local function plusGame(opts)
  opts = opts or {}
  local W = Wow.new()
  setup(W)
  party(W)
  local pf, raid = gameFrames(W)
  local refreshed = 0
  W.G.KeyBarsAPI = {
    refreshFrames = function()
      refreshed = refreshed + 1
    end,
  }
  local saved = { frames = "plus", aim = { PAD3 = { tap = opts.tap or "player" } } }
  local ns = W.load(DIR, FILES, saved)
  return W, ns, pf, raid, function()
    return refreshed
  end
end

test("Plus: the plus is your party frames, always on, nobody lit at rest; the game's party frames away", function()
  local W, ns, pf, raid, refreshed = plusGame()
  eq(ns.diamond:IsShown(), true, "on at rest")
  W.update(0.6)
  for _, d in ipairs(ns.DIRS) do
    eq(ns.spots[d].sel:IsShown(), false, d .. " not lit at rest")
    eq(ns.spots[d].med.a or 1, 1, d .. " full color at rest")
  end
  eq(ns.spots.UP.name.text, "Brakka")
  eq(pf:GetParent(), W.G.HealpadHiddenFrames, "the game's party frames put away")
  eq(pf:IsEventRegistered("GROUP_ROSTER_UPDATE"), false, "and quiet")
  eq(raid:GetParent(), W.G.UIParent, "raid frames left alone")
  local up = W.G.HealpadPlusSeatUP
  eq(up:GetAttribute("unit"), "Brakka", "the seat button is the person, by name")
  eq(up:GetAttribute("*type1"), "target", "click targets")
  eq(up:GetAttribute("*type2"), "togglemenu", "right click: the menu")
  eq(up:IsShown(), true)
  eq(W.G.HealpadPlusSeatSELF:GetAttribute("unit"), "player")
  eq(W.G.ClickCastFrames[up], true, "click casting can use it")
  eq(refreshed() > 0, true, "KeyBars told")
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.update(0.3)
  eq(ns.spots.LEFT.sel:IsShown(), true, "the picked one lit")
  eq(ns.spots.UP.med.a, 0.75, "the others dimmed")
  W.key("PAD3", false)
  eq(last(W).unit, "Zed")
  eq(ns.diamond:IsShown(), true, "still on after the heal")
  W.update(0.3)
  eq(ns.spots.LEFT.sel:IsShown(), false, "at rest again")
  clean(W)
end)

test("Plus: someone leaves in combat: their seat goes dark, nothing secure is touched, nobody moves", function()
  local W, ns = plusGame()
  W.combat = true
  W.units.party2 = nil
  W.fire("GROUP_ROSTER_UPDATE")
  W.update(0.6)
  eq(W.G.HealpadPlusSeatRIGHT:GetAttribute("unit"), "Kira", "the seat keeps its person in combat")
  eq(ns.spots.RIGHT:IsShown(), true, "the seat stays")
  eq(ns.spots.RIGHT.body.alpha, 0.45, "dark")
  eq(ns.spots.DOWN.name.text, "Ann", "nobody moved")
  eq(#W.blocked, 0, "nothing protected changed in combat")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(W.G.HealpadPlusSeatRIGHT:IsShown(), false, "after combat the free seat's button goes")
  eq(W.G.HealpadPlusSeatDOWN:GetAttribute("unit"), "Ann")
  clean(W)
end)

test("Plus: alone, only you", function()
  local W = Wow.new()
  setup(W)
  W.units.player = { name = "Me", hp = 90, max = 100 }
  local ns = W.load(DIR, FILES, { frames = "plus", aim = { PAD3 = { tap = "player" } } })
  W.update(0.6)
  eq(ns.ctl:GetAttribute("u1-UP"), nil, "no target seat")
  eq(ns.spots.SELF:IsShown(), true)
  eq(ns.spots.UP:IsShown(), false)
  eq(W.G.HealpadPlusSeatUP:IsShown(), false)
  eq(W.G.HealpadPlusSeatSELF:IsShown(), true)
  clean(W)
end)

test("Plus back to Game: the plus shows only while you hold, the game's party frames come back", function()
  local W, ns, pf = plusGame()
  ns.db.frames = "game"
  ns.applyMode()
  eq(ns.diamond:IsShown(), false, "hidden at rest")
  eq(pf:GetParent(), W.G.UIParent, "the game's frames back")
  eq(pf:IsEventRegistered("GROUP_ROSTER_UPDATE"), true)
  eq(pf:IsEventRegistered("VARIABLES_LOADED"), true)
  eq(W.G.HealpadPlusSeats:IsShown(), false, "no seat buttons")
  W.combat = true
  W.key("PAD3", true)
  eq(ns.diamond:IsShown(), true, "a hold shows it")
  W.key("PAD3", false)
  eq(ns.diamond:IsShown(), false)
  clean(W)
end)

test("Plus: a mode change in combat waits for the end of combat", function()
  local W, ns, pf = plusGame()
  W.combat = true
  ns.db.frames = "game"
  ns.applyMode()
  eq(pf:GetParent(), W.G.HealpadHiddenFrames, "nothing moves in combat")
  eq(#W.blocked, 0)
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(pf:GetParent(), W.G.UIParent)
  clean(W)
end)

---------------------------------------------------------------- Buttons mode

-- Buttons mode: X (PAD3, Healing Touch r2), A (PAD1, Rejuvenation) and the
-- keyboard 1 (Healing Touch r1) set to Healpad; 1's tap heals opts.tap.
local function buttons(opts)
  opts = opts or {}
  local W = Wow.new()
  setup(W)
  W.bind("ACTIONBUTTON5", "PAD5")
  if opts.solo then
    W.units.player = { name = "Me", hp = 90, max = 100 }
  elseif opts.raid then
    W.raid = {}
    local people = {
      { "Me", 1 },
      { "Odo", 1 },
      { "Pim", 1 },
      { "Rusk", 2 },
      { "Sef", 2 },
      { "Tamsin", 3 },
      { "Ulla", 3 },
      { "Vashi", 1 },
      { "Wenn", 1 },
      { "Yara", 2 },
    }
    for i, p in ipairs(people) do
      W.raid[i] = { name = p[1], group = p[2] }
      W.units["raid" .. i] = { name = p[1], hp = 50, max = 100 }
    end
    W.units.player = W.units.raid1
  else
    party(W)
  end
  local saved = {
    mode = "buttons",
    after = opts.after,
    aim = { PAD3 = { tap = "player" }, PAD1 = { tap = "player" }, ["1"] = { tap = opts.tap or "player" } },
  }
  local ns = W.load(DIR, FILES, saved)
  return W, ns
end

test("Buttons: a tap of a heal waits; the next press is the person; Once clears", function()
  local W, ns = buttons()
  local c = ns.ctl
  eq(c:GetAttribute("p1"), "player", "you are row 1")
  eq(c:GetAttribute("p2"), "Brakka", "rows in seat order")
  eq(c:GetAttribute("p5"), "Zed")
  W.combat = true
  W.tap("PAD3")
  eq(#W.casts, 0, "a tap casts nothing")
  eq(c:GetAttribute("armed"), 5186, "the heal waits")
  eq(c:GetAttribute("state"), "armed")
  eq(W.secureBinds.PAD2.target, "HealpadRow2x0", "B is row 2")
  eq(W.secureBinds.PADDDOWN.target, "HealpadRow5x0", "d-pad down is row 5")
  eq(W.secureBinds.PAD5.target, "HealpadNoop", "another controller button does nothing")
  eq(W.secureBinds.PADBACK.target, "HealpadCancel", "Back cancels")
  eq(W.secureBinds.SPACE, nil, "keyboard keys untouched")
  W.tap("PAD2")
  eq(#W.casts, 1)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "Brakka", "B: row 2")
  eq(last(W).combat, true)
  eq(c:GetAttribute("armed"), nil, "Once: cleared")
  eq(W.secureBinds.PAD2, nil, "B given back")
  eq(W.secureBinds.PAD5, nil)
  eq(W.secureBinds.PAD3.target:match("^HealpadHeal") ~= nil, true, "X is the heal again")
  W.tap("PAD2")
  eq(#W.casts, 1, "B as you bound it: no heal")
  eq(W.barPresses[#W.barPresses].command, "ACTIONBUTTON4")
  W.tap("PAD1")
  W.tap("PADDDOWN")
  eq(last(W).unit, "Zed", "d-pad down: row 5")
  eq(last(W).spell, 774, "A's heal")
  clean(W)
end)

test("Buttons: Locked stays armed; another heal switches; cancel unlocks and gives the keys back", function()
  local W, ns = buttons({ after = "locked" })
  local c = ns.ctl
  W.combat = true
  W.tap("PAD3")
  W.tap("PAD1")
  eq(last(W).unit, "player", "A: row 1, you (the grid wins over A's heal)")
  eq(last(W).spell, 5186)
  W.tap("PAD4")
  eq(last(W).unit, "Ann", "still armed: Y, row 4")
  eq(c:GetAttribute("armed"), 5186)
  W.tap("1")
  eq(c:GetAttribute("armed"), 5185, "a heal off the grid switches heals")
  W.tap("PAD3")
  eq(last(W).spell, 5185)
  eq(last(W).unit, "Kira", "X: row 3")
  W.tap("PADBACK")
  eq(c:GetAttribute("armed"), nil, "cancel unlocks")
  eq(c:GetAttribute("state"), "idle")
  eq(W.secureBinds.PAD2, nil, "keys given back")
  eq(W.secureBinds.PADBACK, nil)
  eq(W.secureBinds.PAD3.target:match("^HealpadHeal") ~= nil, true, "X is the heal again")
  local n = #W.casts
  W.tap("PAD2")
  eq(#W.casts, n, "nothing waits")
  clean(W)
end)

test("Buttons: the same heal again heals its tap choice, unless its key is on the grid", function()
  local W, ns = buttons({ tap = "tank" })
  local c = ns.ctl
  W.combat = true
  W.tap("1")
  eq(c:GetAttribute("armed"), 5185)
  W.tap("1")
  eq(last(W).unit, "Brakka", "the tank")
  eq(last(W).spell, 5185)
  eq(c:GetAttribute("armed"), nil, "Once: cleared")
  W.tap("PAD3")
  W.tap("PAD3")
  eq(last(W).unit, "Kira", "X is row 3: the grid wins")
  eq(last(W).spell, 5186)
  clean(W)
end)

test("Buttons: alone, a tap heals you at once", function()
  local W, ns = buttons({ solo = true })
  W.combat = true
  W.tap("PAD3")
  eq(last(W).unit, "player")
  eq(last(W).spell, 5186)
  eq(ns.ctl:GetAttribute("armed"), nil, "nothing waits")
  clean(W)
end)

test("Buttons: nobody there, dead or an enemy: the heal keeps waiting", function()
  local W, ns = buttons()
  local c = ns.ctl
  W.combat = true
  W.units.party3.dead = true
  W.units.party2 = nil -- Kira leaves mid-fight: her seat goes dark
  W.fire("GROUP_ROSTER_UPDATE")
  W.tap("PAD3")
  W.tap("PAD3")
  eq(#W.casts, 0, "row 3 is empty")
  eq(c:GetAttribute("armed"), 5186, "still waiting")
  W.tap("PAD4")
  eq(#W.casts, 0, "row 4 is dead")
  eq(c:GetAttribute("p4"), "Ann", "nobody moved")
  W.tap("PAD2")
  eq(last(W).unit, "Brakka")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  eq(c:GetAttribute("p3"), nil, "after combat: the seat is free")
  eq(c:GetAttribute("p5"), "Zed", "the rest stay")
  clean(W)
end)

test("Buttons: dying or mounting stops a waiting heal", function()
  local W, ns = buttons({ after = "locked" })
  W.combat = true
  W.tap("PAD3")
  eq(ns.ctl:GetAttribute("armed"), 5186)
  W.setStop(true)
  eq(ns.ctl:GetAttribute("armed"), nil)
  eq(W.secureBinds.PAD2, nil, "keys given back")
  W.setStop(false)
  clean(W)
end)

test(
  "Buttons raid: hold a group, press a row; Start is row 5; no group does nothing; the first group held wins",
  function()
    local W, ns = buttons({ raid = true, after = "locked" })
    local c = ns.ctl
    eq(c:GetAttribute("raid"), true)
    eq(c:GetAttribute("g1-1"), "player", "you lead your group")
    eq(c:GetAttribute("g1-2"), "Odo")
    eq(c:GetAttribute("g1-5"), "Wenn")
    eq(c:GetAttribute("g2-1"), "Rusk")
    W.combat = true
    W.tap("PAD3")
    eq(W.secureBinds.PADLSHOULDER.target, "HealpadGroup1")
    eq(W.secureBinds.PADDUP.target, "HealpadGroup5")
    eq(W.secureBinds.PADFORWARD.target, "HealpadRow5x0")
    W.tap("PAD1")
    eq(#W.casts, 0, "A with no group held: nothing")
    eq(c:GetAttribute("armed"), 5186, "still waiting")
    W.key("PADRSHOULDER", true)
    eq(c:GetAttribute("grp"), 2)
    W.tap("PAD2")
    eq(last(W).unit, "Sef", "RB + B: group 2, row 2")
    W.key("PADDUP", true)
    eq(c:GetAttribute("grp"), 2, "the first group held wins")
    W.tap("PAD1")
    eq(last(W).unit, "Rusk")
    W.key("PADRSHOULDER", false)
    eq(c:GetAttribute("grp"), nil, "let go: no group")
    W.key("PADDUP", false)
    W.key("PADLSHOULDER", true)
    W.tap("PADFORWARD")
    eq(last(W).unit, "Wenn", "LB + Start: group 1, row 5")
    W.key("PADLSHOULDER", false)
    -- LT holds Shift: LT + A is group 3, row 1
    W.tap("SHIFT-PAD1")
    eq(last(W).unit, "Tamsin", "LT (as Shift) + A")
    W.key("PADLSHOULDER", true)
    W.tap("SHIFT-PAD2")
    eq(last(W).unit, "Odo", "LB held first: group 1")
    W.key("PADLSHOULDER", false)
    eq(W.secureBinds["SHIFT-PADRSHOULDER"].target, "HealpadNoop", "LT held first: a later group waits")
    local n = #W.casts
    W.key("PADDLEFT", true)
    W.tap("PAD1")
    eq(#W.casts, n, "group 8 is empty")
    W.key("PADDLEFT", false)
    W.tap("PADBACK")
    eq(c:GetAttribute("grp"), nil)
    eq(W.secureBinds.PADLSHOULDER, nil, "keys given back")
    clean(W)
  end
)

test("Buttons raid: arming forgets a group held before", function()
  local W, ns = buttons({ raid = true })
  local c = ns.ctl
  W.combat = true
  W.tap("PAD3")
  W.key("PADLSHOULDER", true)
  W.tap("PADBACK")
  W.key("PADLSHOULDER", false)
  W.tap("PAD3")
  eq(c:GetAttribute("grp"), nil, "a new heal: no group held")
  clean(W)
end)

test("Buttons in Gamepad Mode: a bar heal waits; rows reach Healpad through the bar too", function()
  local W, ns = gamepad({ mode = "buttons", aim = {}, aimPad = { [5186] = { tap = "player" } } })
  local c = ns.ctl
  W.combat = true
  W.key("PADLTRIGGER", true)
  W.tap("SHIFT-PAD1")
  W.key("PADLTRIGGER", false)
  eq(#W.casts, 0)
  eq(c:GetAttribute("armed"), 5186, "LT+A's heal waits")
  -- Healpad's bindings win: B is row 2
  W.tap("PAD2")
  eq(last(W).unit, "Brakka")
  eq(c:GetAttribute("armed"), nil)
  -- Gamepad Mode's bindings win: B reaches the bar's button, still row 2
  W.contextFirst = true
  W.key("PADLTRIGGER", true)
  W.tap("SHIFT-PAD1")
  W.key("PADLTRIGGER", false)
  eq(c:GetAttribute("armed"), 5186)
  W.tap("PAD2")
  eq(#W.casts, 2)
  eq(last(W).unit, "Brakka", "through the bar's button")
  eq(last(W).spell, 5186)
  local top = W.G.GamepadMainActionBarFrame.PageUnit.actionBars.topBar.actionButtons[7]
  eq(top.attrs.type, "action", "the game's button as it was")
  eq(top.attrs.spell, nil)
  eq(top.attrs.unit, nil)
  -- a press that is no row, while waiting: nothing
  W.key("PADLTRIGGER", true)
  W.tap("SHIFT-PAD1")
  W.key("PADLTRIGGER", false)
  W.tap("PADDUP")
  eq(#W.casts, 2, "d-pad up does nothing")
  W.tap("PAD1")
  eq(last(W).unit, "player", "A: row 1")
  clean(W)
end)

test("probe: reads the party in and out of combat, and the key catcher comes and goes", function()
  local W, ns = game()
  ns.probe()
  W.tick()
  W.combat = true
  W.tick()
  W.combat = false
  ns.probe("stop")
  local p = ns.db.probe
  eq(p.samples.rest, 1, "a sample out of combat")
  eq(p.samples.combat, 1, "a sample in combat")
  assert(p.reads.combat["group health"], "group health read in combat")
  assert(p.reads.rest["group by name exists"] or p.reads.rest["group by name"], "a party member read by name")
  ns.probe("keys")
  eq(p.before.PAD1 ~= nil, true, "PAD1's own binding noted")
  W.runTimers()
  assert(p.keysNotPressedOrLost:find("PAD1"), "nothing pressed")
  clean(W)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
