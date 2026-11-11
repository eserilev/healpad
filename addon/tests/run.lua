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
  "Options.lua",
  "Test.lua",
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
  eq(last(W).unit, "party2")
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
  eq(last(W).unit, "party2")
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
  W3.key("PAD3", true)
  W3.tap("PADDDOWN")
  W3.key("PAD3", false)
  W3.tap("PAD1")
  eq(last(W3).unit, "party3", "last healed")
  local W4 = game({ tap = "focus" })
  W4.combat = true
  W4.tap("PAD1")
  eq(last(W4).unit, "player", "no focus: you")
  W4.units.focus = W4.units.party1
  W4.tap("PAD1")
  eq(last(W4).unit, "focus")
  clean(W)
  clean(W2)
  clean(W3)
  clean(W4)
end)

test("tap heals the tank: the tank sits in the middle, you in the tank's place", function()
  local W, ns = game({ saved = { aim = { PAD3 = { tap = "tank" } } } })
  W.combat = true
  W.key("PAD3", true)
  eq(ns.ctl:GetAttribute("swap"), "UP", "the tank was up")
  W.update(0.3)
  eq(ns.spots.SELF.name.text, "Brakka", "the tank in the middle")
  eq(ns.spots.UP.name.text, "Me", "you in the tank's place")
  W.key("PAD3", false)
  eq(last(W).unit, "party2", "no aim: the tank")
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).unit, "player", "up is you now")
  W.key("PAD3", true)
  W.tap("PADDUP")
  W.tap("PADDDOWN")
  W.key("PAD3", false)
  eq(last(W).unit, "party2", "back to the middle: the tank")
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.key("PAD3", false)
  eq(last(W).unit, "party1", "the others are where they were")
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
  W.units.party2.role = "DAMAGER"
  W.units.party3.mainTank = true
  local ns = W.load(DIR, FILES, { aim = { PAD3 = { tap = "tank" } } })
  eq(ns.ctl:GetAttribute("tank"), "party3")
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
  eq(last(W).unit, "party4")
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
  eq(last(W).unit, "party2")
  eq(ns.diamond:IsShown(), true, "still open")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "party2")
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
  W.key("PAD3", true)
  W.tap("PADDRIGHT")
  W.key("PAD3", false)
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
  W.update(0.6)
  local up = ns.spots.UP
  eq(Wow.isSecret(up.health.value), true, "health bar got the secret value")
  eq(Wow.isSecret(up.health.incoming.value), true, "incoming bar too")
  eq(Wow.isSecret(up.health.barColor[1]), true, "health color from the curve, secret")
  eq(up.face.portrait, "party2", "portrait")
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
  W.units.party2.debuff = "Magic"
  W.units.party2.hot = true
  W.units.party1.dead = true
  W.units.party4.offline = true
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
      eq(Wow.isSecret(s.DOWN.crit.vertex[4]), combat, "crit pulse from the curve")
      if combat then
        eq(Wow.isSecret(s.DOWN.body.alphaBool[1]), true, "out of range: faded by the game")
      else
        eq(s.DOWN.far, true, "out of range")
        eq(s.DOWN.crit.vertex[4], 1, "under a quarter: the red pulse")
        eq(s.UP.crit.vertex[4], 0, "no pulse at 80%")
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

  test("look " .. name .. ": alone, the Target spot; the Frames tab's sample people", function()
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
    W.tap("PADRSHOULDER")
    W.tap("PADRSHOULDER")
    eq(ns.diamond:IsShown(), true, "preview")
    eq(ns.spots.UP.hot:IsShown(), true, "sample HoT")
    eq(ns.spots.RIGHT.dispel:IsShown(), true, "sample dispel")
    eq(ns.spots.LEFT.far, true, "sample out of range")
    eq(ns.spots.DOWN.crit.vertex[4], 1, "sample critical")
    ns.optionsPanel():Hide()
    clean(W)
  end)
end

test("Frames tab: Look picks one of four, the chosen one in gold, the preview follows", function()
  local W, ns = game({ party = false })
  ns.openOptions()
  W.tap("PADRSHOULDER")
  W.tap("PADRSHOULDER")
  local d = ns.optionsDebug()
  eq(d.st.tab, "frames")
  local looks = d.ui.frames.looks
  eq(#looks, 4)
  eq(looks[1].text, "Classic")
  eq(looks[4].text, "Compass")
  eq(looks[1].gold:IsShown(), true, "Classic chosen")
  eq(looks[2].gold:IsShown(), false)
  for _ = 1, 3 do
    W.tap("PADDDOWN")
  end
  eq(d.st.row, 3, "the Look row")
  W.tap("PADDRIGHT")
  eq(ns.db.look, "medallions")
  eq(ns.look.name, "medallions", "the preview shows it")
  eq(ns.diamond:IsShown(), true)
  eq(looks[2].gold:IsShown(), true)
  eq(looks[1].gold:IsShown(), false)
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  eq(ns.db.look, "compass", "stops at the last")
  looks[3]:GetScript("OnClick")(looks[3])
  eq(ns.db.look, "sigil", "a click picks too")
  eq(ns.spots.UP.name.text, "Party Member", "sample people in the new look")
  W.tap("PADDUP")
  W.tap("PADDUP")
  W.tap("PADDRIGHT")
  eq(ns.db.distance, 4, "Spread still works")
  W.tap("PADDUP")
  W.tap("PADDRIGHT")
  eq(ns.db.scale, 1.1, "Size still works")
  eq(ns.looks.sigil.spots.UP.at[2] > 180, true, "spread moves the gems out")
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
  W.key("PAD1", true)
  W.tap("PADDUP")
  W.key("PAD1", false)
  eq(last(W).spell, 774)
  eq(last(W).unit, "party2")
  W.setBar("p1")
  W.key("PAD3", true)
  W.tap("PADDLEFT")
  W.key("PAD3", false)
  eq(last(W).spell, 5186)
  eq(last(W).unit, "party1")
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
  eq(last(W).unit, "party4")
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
  eq(c:GetAttribute("u1-SELF"), "raid3", "my group first")
  eq(c:GetAttribute("u2-UP"), "raid1", "group 1 next, tank up")
  W.combat = true
  W.key("PAD3", true)
  W.tap("PADRSHOULDER")
  eq(c:GetAttribute("page"), 2)
  W.tap("PADDUP")
  W.key("PAD3", false)
  eq(last(W).unit, "raid1")
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

test("settings: pad drives the tabs; A sets Hold to Aim; nav keys go back on close", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  local p = W.G.HealpadOptions
  eq(p:IsShown(), true)
  eq(W.overrides.PADDDOWN.target, "HealpadNavDOWN", "pad drives the panel")
  -- the list: A (Rejuvenation), B, X, Y, LT+X, 1
  W.tap("PADDDOWN")
  W.tap("PADDDOWN")
  W.tap("PAD1")
  eq(ns.db.aim.PAD3 ~= nil, true, "X holds to aim")
  eq(ns.heals[1]:GetAttribute("hp-key"), "PAD3")
  W.tap("PADDRIGHT")
  W.tap("PADDDOWN")
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  W.tap("PAD1")
  eq(ns.db.aim.PAD3.tap, "tank", "tap to heal: tank")
  W.tap("PAD2") -- back to the list
  W.tap("PADRSHOULDER") -- Aim tab
  W.tap("PADDRIGHT")
  eq(ns.db.aimWith, "rstick")
  W.tap("PADDDOWN")
  W.tap("PADDRIGHT")
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
  eq(last(W).unit, "party2")
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
  eq(last(W).unit, "party4")
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

test("KeyBars: Hold to Aim set in the settings reaches the button", function()
  local W = Wow.new()
  setup(W)
  party(W)
  withKeyBars(W)
  local ns = W.load(DIR, FILES, { aim = {} })
  ns.openOptions()
  local dbg = ns.optionsDebug()
  local li, n = nil, 0
  for _, r in ipairs(dbg.rows) do
    if r.bind then
      n = n + 1
      if r.bind.kb then
        li = n
      end
    end
  end
  dbg.st.li = li
  ns.optionsNav("A")
  eq(ns.db.aimSpell["Healing Touch"] ~= nil, true)
  eq(ns.ctl:GetAttribute("aimspell-Healing Touch"), "player")
  W.G.HealpadOptions:Hide()
  W.combat = true
  W.key("1", true)
  W.tap("UP")
  W.key("1", false)
  eq(last(W).unit, "party2")
  clean(W)
end)

test("Esc closes the whole window from any tab, and the diamond preview with it", function()
  local W, ns = game()
  ns.openOptions()
  W.tap("PADRSHOULDER")
  W.tap("PADRSHOULDER") -- Frames: the diamond shows
  eq(ns.diamond:IsShown(), true)
  W.tap("ESCAPE")
  eq(W.G.HealpadOptions:IsShown(), false, "closed")
  eq(ns.diamond:IsShown(), false, "preview gone")
  eq(W.overrides.ESCAPE, nil, "Esc is the game's again")
  ns.openOptions()
  W.tap("PADDRIGHT") -- into a heal's detail
  W.tap("ESCAPE")
  eq(W.G.HealpadOptions:IsShown(), false, "closed from the detail too")
  clean(W)
end)

test("Frames: Move nudges the diamond with the pad, Reset puts it back; it is saved", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  W.tap("PADRSHOULDER")
  W.tap("PADRSHOULDER") -- Frames
  W.tap("PADDDOWN")
  W.tap("PADDDOWN") -- Position
  W.tap("PAD1") -- Move
  -- a stick glides it too: right at full tilt for half a second
  W.G.C_GamePad = {
    GetActiveDeviceID = function()
      return 1
    end,
    GetDeviceMappedState = function()
      return { sticks = { { x = 1, y = 0 }, { x = 0, y = 0 } } }
    end,
  }
  W.update(0.5)
  eq(ns.db.x, 350, "the stick moved it")
  W.G.C_GamePad = nil
  ns.db.x = 0
  W.tap("PADDRIGHT")
  W.tap("PADDRIGHT")
  W.tap("PADDUP")
  W.tap("PAD1") -- done
  eq(ns.db.x, 40)
  eq(ns.db.y, 20)
  W.tap("PADDUP")
  W.tap("PADDDOWN") -- still on Position after leaving Move
  W.tap("PADDRIGHT")
  W.tap("PAD1") -- Reset
  eq(ns.db.x, 0)
  eq(ns.db.y, 0)
  clean(W)
end)

test("Frames without Move: the d-pad and sticks change settings, never the position", function()
  local W, ns = game({ saved = { aim = {} } })
  ns.openOptions()
  W.tap("PADRSHOULDER")
  W.tap("PADRSHOULDER") -- Frames
  W.G.C_GamePad = {
    GetActiveDeviceID = function()
      return 1
    end,
    GetDeviceMappedState = function()
      return { sticks = { { x = 1, y = 1 }, { x = -1, y = 0 } } }
    end,
  }
  W.update(0.5)
  for _, k in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PADDDOWN", "PADDDOWN", "PADDRIGHT" }) do
    W.tap(k)
  end
  W.update(0.5)
  eq(ns.db.x, 0, "x")
  eq(ns.db.y, 0, "y")
  W.G.C_GamePad = nil
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

test("/hp test runs in the game: tabs, diamond, a hold, an aim, a cancel", function()
  local W, ns = game()
  W.G.SlashCmdList.HEALPAD("test")
  W.runTimers()
  local log = table.concat(ns.db.log, "\n")
  eq(log:find("TEST FAIL") == nil, true, log)
  eq(log:find("LUA ERROR") == nil, true, log)
  eq(log:find("TEST done: %d+ ok, 0 failed") ~= nil, true, log)
  eq(W.shots, 4, "screenshots")
  eq(#W.casts, 0, "nothing cast")
  clean(W)
end)

test("/hp shots stages the diamond and each tab, takes 5 screenshots, puts the UI back", function()
  local W, ns = game({ party = false })
  W.G.SlashCmdList.HEALPAD("shots")
  W.runTimers()
  eq(W.shots, 5, "screenshots")
  eq(W.G.UIParent:IsShown(), true, "the UI is back")
  eq(ns.diamond.parent, W.G.UIParent, "the diamond is back on UIParent")
  eq(ns.diamond:IsShown(), false)
  eq(W.G.HealpadOptions:IsShown(), false)
  eq(ns.stage, nil)
  local log = table.concat(ns.db.log or {}, "\n")
  eq(log:find("SHOTS error") == nil, true, log)
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
  local headers = {}
  for _, r in ipairs(ns.optionsDebug().rows) do
    if r.header then
      headers[#headers + 1] = r.header
    end
  end
  eq(table.concat(headers, ","), "Buttons,Hold LT,Hold RT,Keys")
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
  eq(last(W).unit, "party2")
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
    eq(last(W).unit, "party2", "the tank")
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
  eq(last(W).unit, "party4")
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
  eq(last(W).unit, "party4")
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
  eq(last(W).unit, "party4")
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

test("Gamepad Mode: Hold to Aim set in the settings reaches the controller bar", function()
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
  eq(last(W).unit, "party3")
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
  eq(last(W).unit, "party2")
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
  eq(last(W).unit, "party1")
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

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
