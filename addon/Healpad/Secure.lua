-- The secure parts: one controller, the heal buttons, the aim buttons, and a
-- key owner that follows the bar.
--
-- Press a Hold to Aim button: its spell is locked, the controller takes the
-- aim, cancel and page buttons, and nothing casts. Release it: the locked
-- spell casts on the aimed person, or with no aim on its tap choice. All of
-- it runs in secure snippets, so it works in combat. Addon code only sets
-- things up out of combat and draws the plain diamond frames.
--
-- A heal button owns its key only in the bar states where that key casts
-- the same spell: shift into cat form and the key is Claw again.
--
-- In the game's Gamepad Mode the controller presses the game's own
-- controller bar, so Healpad sits in that bar's buttons instead (GP_PRE).
local _, ns = ...

local ctl = CreateFrame("Frame", "HealpadCtl", UIParent, "SecureHandlerBaseTemplate")
ns.ctl = ctl
local keys = CreateFrame("Frame", "HealpadKeys", UIParent, "SecureHandlerStateTemplate")
ns.keys = keys

-- The press of a Hold to Aim heal, shared by every kind of heal button. It
-- runs with self (the button), owner (the controller), name (self's name),
-- tap (who a tap heals) and skip (a prefix of keys this hold leaves alone:
-- the heal's own button) set.
local OPEN = [[
    local held = owner:GetAttribute("held")
    if held and held ~= name then
      return false
    end
    owner:SetAttribute("held", name)
    -- The menu shown only while you hold (Party Frames: Game): the middle is
    -- whoever a tap heals; when that's someone in it, they trade places with
    -- you for this hold. Seats that belong to people (Plus) never move.
    local swap
    if not owner:GetAttribute("personseats") then
      local tu
      if tap == "tank" then
        tu = owner:GetAttribute("tank")
      elseif tap == "last" then
        tu = owner:GetAttribute("last")
      elseif tap == "focus" then
        tu = "focus"
      elseif tap == "target" then
        tu = "target"
      end
      if tu and tu ~= "player" then
        if owner:GetAttribute("u1-UP") == tu then swap = "UP"
        elseif owner:GetAttribute("u1-RIGHT") == tu then swap = "RIGHT"
        elseif owner:GetAttribute("u1-DOWN") == tu then swap = "DOWN"
        elseif owner:GetAttribute("u1-LEFT") == tu then swap = "LEFT" end
      end
    end
    owner:SetAttribute("swap", swap)
    owner:SetAttribute("sel", nil)
    owner:SetAttribute("page", 1)
    owner:ClearBindings()
    for i = 1, owner:GetAttribute("ak-n") or 0 do
      local k = owner:GetAttribute("ak" .. i)
      if not owner:GetAttribute("skip-" .. k) and not (skip and owner:GetAttribute(skip .. k)) then
        owner:SetBindingClick(true, k, owner:GetAttribute("ab" .. i))
      end
    end
    owner:SetAttribute("state", "aim")
    return false
]]

-- The release closes the diamond when this button opened it.
local CLOSE = [[
  if owner:GetAttribute("held") == name then
    owner:ClearBindings()
    owner:SetAttribute("held", nil)
    owner:SetAttribute("state", "idle")
    -- the plus's seat buttons back (a page other than yours hid them)
    local ps = owner:GetFrameRef("plusseats")
    if ps and owner:GetAttribute("plusmode") then
      ps:Show()
    end
  end
]]
-- Who a tap heals (tap is the heal's choice): sets unit, you at worst.
local TAP_UNIT = [[
    if tap == "last" then
      unit = owner:GetAttribute("last")
    elseif tap == "tank" then
      unit = owner:GetAttribute("tank")
    elseif tap == "focus" then
      -- no friendly focus: your target, if that's a friend
      unit = "focus"
      if SecureCmdOptionParse("[@focus,help,nodead] yes; no") ~= "yes" then
        unit = "target"
      end
    elseif tap == "target" then
      unit = "target"
    end
    -- A tap only heals a friend who's alive: an enemy focus, or nobody
    -- there, and it's you.
    if unit and unit ~= "player" and SecureCmdOptionParse("[@" .. unit .. ",help,nodead] yes; no") ~= "yes" then
      unit = nil
    end
    if not unit or not UnitExists(unit) then
      unit = "player"
    end
]]

-- The heal goes to unit: returns false when nobody is there, else notes it.
local CAST_NOTE = [[
  if not unit or not UnitExists(unit) then
    return false
  end
  if unit == "target" and SecureCmdOptionParse("[@target,help,nodead] yes; no") ~= "yes" then
    return false
  end
  -- "Last healed" is a person: your target changes, so it's never "target".
  if unit ~= "target" then owner:SetAttribute("last", unit) end
  owner:SetAttribute("castunit", unit)
  owner:SetAttribute("castn", (owner:GetAttribute("castn") or 0) + 1)
]]

-- Then who the locked spell heals: sets unit, or returns false.
local PICK = [[
  local unit
  local sel = owner:GetAttribute("sel")
  local swap = owner:GetAttribute("swap")
  owner:SetAttribute("swap", nil)
  if sel and swap and (owner:GetAttribute("page") or 1) == 1 then
    if sel == swap then
      sel = nil
      unit = "player"
    elseif sel == "SELF" then
      sel = nil
    end
  end
  if unit then
    -- you, from your traded place
  elseif sel then
    unit = owner:GetAttribute("u" .. (owner:GetAttribute("page") or 1) .. "-" .. sel)
  else
]] .. TAP_UNIT .. [[
  end
]] .. CAST_NOTE

---------------------------------------------------------------- Buttons mode
-- Tap a heal: it waits (armed). The next press is the person: a row, or in
-- a raid a group held and a row. All of it in the controller's attributes:
--   armed      the spell waiting, armtap who a tap of it heals
--   grp        the group held (raid), grpkey the button that holds it
--   raid, solo, lockmode (After a heal: Locked), bmode (Buttons is on)
--   p1..p5     the party's rows; g1-1..g8-5 the raid's groups and rows

-- The heal waits no more: the controller's keys go back.
local DISARM = [[
    owner:ClearBindings()
    owner:SetAttribute("armtap", nil)
    owner:SetAttribute("grp", nil)
    owner:SetAttribute("grpkey", nil)
    owner:SetAttribute("armed", nil)
    owner:SetAttribute("state", "idle")
]]

-- The heal spell (with tap) waits: the controller takes the grid's keys,
-- the cancel button and every other controller button (they do nothing);
-- a heal's own key stays a heal unless the grid needs it.
-- Dead, mounted, or the bar taken by a vehicle or possession.
ns.STOP_DRIVER = "[dead][mounted][possessbar][vehicleui] 1; 0"

-- The keys a waiting heal takes, bound again (newest wins).
local ARM_BINDS = [[
    owner:ClearBindings()
    local list = owner:GetAttribute("raid") and "br" or "bp"
    for i = 1, owner:GetAttribute(list .. "-n") or 0 do
      local k = owner:GetAttribute(list .. "k" .. i)
      if not (owner:GetAttribute(list .. "s" .. i) and owner:GetAttribute("skip-" .. k)) then
        owner:SetBindingClick(true, k, owner:GetAttribute(list .. "b" .. i))
      end
    end
]]

-- Dead, mounted or possessed: nothing waits. A heal tapped from rest
-- forgets any group held; switching heals keeps the group you hold.
local ARM = [[
    if SecureCmdOptionParse("]] .. ns.STOP_DRIVER .. [[") == "1" then
      return false
    end
    if not owner:GetAttribute("armed") then
      owner:SetAttribute("grp", nil)
      owner:SetAttribute("grpkey", nil)
    end
    owner:SetAttribute("armtap", tap)
    owner:SetAttribute("armed", spell)
]] .. ARM_BINDS .. [[
    owner:SetAttribute("state", "armed")
]]

ns.ARM_SNIPPET = ARM
-- Run on the controller (RunAttribute) after the heal keys were bound
-- again while a heal waits, so the grid's keys are newest and win.
ns.REARM_SNIPPET = [[
  local owner = self
  if owner:GetAttribute("armed") then
]] .. ARM_BINDS .. [[
  end
]]

-- The release of a heal in Buttons mode (spell, tap set): alone it heals
-- you; the same heal again heals its tap choice; else it waits. Sets unit,
-- or returns false.
local BTAP = [[
  local unit
  if owner:GetAttribute("solo") then
    unit = "player"
  elseif owner:GetAttribute("armed") == spell then
]] .. TAP_UNIT .. [[
    if not owner:GetAttribute("lockmode") then
]] .. DISARM .. [[
    end
  else
]] .. ARM .. [[
    return false
  end
]] .. CAST_NOTE

-- The person of a row press, while a heal waits: sets unit or returns
-- false (and the heal keeps waiting: nobody there, dead or an enemy).
-- r: the row; g: the group the press says (a trigger held as a modifier,
-- or the controller bar it reached), used when no group key is held.
local ROW_UNIT = [[
  local unit
  if owner:GetAttribute("raid") then
    local grp = owner:GetAttribute("grp") or g
    if not grp then
      return false
    end
    unit = owner:GetAttribute("g" .. grp .. "-" .. r)
  else
    unit = owner:GetAttribute("p" .. r)
  end
  if not unit or SecureCmdOptionParse("[@" .. unit .. ",help,nodead] yes; no") ~= "yes" then
    return false
  end
]] .. CAST_NOTE .. [[
  if not owner:GetAttribute("lockmode") then
]] .. DISARM .. [[
  end
]]

-- A row button: casts the waiting heal on the row's person.
ns.ROW_SNIPPET = [[
  if not down then
    return false
  end
  local spell = owner:GetAttribute("armed")
  if not spell then
    return false
  end
  local r = self:GetAttribute("row")
  local g = self:GetAttribute("modgrp")
]] .. ROW_UNIT .. [[
  self:SetAttribute("spell", spell)
  self:SetAttribute("unit", unit)
]]

-- A group button: held, it picks the group; the first one held wins.
ns.GROUP_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  if not c:GetAttribute("armed") then
    return
  end
  local me = self:GetName()
  if down then
    if not c:GetAttribute("grp") then
      c:SetAttribute("grpkey", me)
      c:SetAttribute("grp", self:GetAttribute("group"))
    end
  elseif c:GetAttribute("grpkey") == me then
    c:SetAttribute("grp", nil)
    c:SetAttribute("grpkey", nil)
  end
]]

-- A Healpad heal button: the key is Healpad's while its bar state casts it.
ns.HEAL_SNIPPET = [[
  if owner:GetAttribute("bmode") then
    if down then
      return false
    end
    local spell = self:GetAttribute("hp-spell")
    local tap = self:GetAttribute("hp-tap")
    if not spell then
      return false
    end
]] .. BTAP .. [[
    self:SetAttribute("spell", spell)
    self:SetAttribute("unit", unit)
    return
  end
  local name = self:GetName()
  local gen = owner:GetAttribute("gen") or 0
  local tap = self:GetAttribute("hp-tap")
  local skip
  if down then
    self:SetAttribute("hp-lock", self:GetAttribute("hp-spell"))
    self:SetAttribute("hp-gen", gen)
]] .. OPEN .. [[
  end
  local lock = self:GetAttribute("hp-lock")
  local mygen = self:GetAttribute("hp-gen")
  self:SetAttribute("hp-lock", nil)
]] .. CLOSE .. [[
  if not lock or mygen ~= gen then
    return false
  end
]] .. PICK .. [[
  self:SetAttribute("spell", lock)
  self:SetAttribute("unit", unit)
]]

-- The same hold, aim and release, inside a KeyBars button. KeyBars keeps its
-- keys and layers; when the spell the button holds now is a Hold to Aim heal,
-- the press opens the diamond instead of casting, and the release casts it
-- on the aimed person. Any other spell casts as it always did.
ns.KB_PRE = [[
  if owner:GetAttribute("bmode") then
    local spell = self:GetAttribute("spell")
    local tap = spell and owner:GetAttribute("aimspell-" .. spell)
    if not tap then
      return
    end
    if down then
      return false
    end
]] .. BTAP .. [[
    self:SetAttribute("useOnKeyDown", false)
    self:SetAttribute("unit", unit)
    return nil, "hp"
  end
  local name = self:GetName()
  local gen = owner:GetAttribute("gen") or 0
  local skip
  if down then
    local spell = self:GetAttribute("spell")
    local tap = spell and owner:GetAttribute("aimspell-" .. spell)
    if not tap then return end
    self:SetAttribute("hp-lock", spell)
    self:SetAttribute("hp-gen", gen)
    self:SetAttribute("hp-tap", tap)
]] .. OPEN .. [[
  end
  local lock = self:GetAttribute("hp-lock")
  if not lock then return end
  local tap = self:GetAttribute("hp-tap")
  self:SetAttribute("hp-lock", nil)
]] .. CLOSE .. [[
  if self:GetAttribute("hp-gen") ~= gen or self:GetAttribute("spell") ~= lock then
    return false
  end
]] .. PICK .. [[
  self:SetAttribute("useOnKeyDown", false)
  self:SetAttribute("unit", unit)
  return nil, "hp"
]]

-- After a Healpad cast from a KeyBars button: the button as KeyBars left it.
ns.KB_POST = [[
  self:SetAttribute("useOnKeyDown", nil)
  self:SetAttribute("unit", nil)
]]

-- Buttons mode in a button of the game's controller bar (Gamepad Mode). A
-- heal on the bar waits on its release as anywhere else. While a heal
-- waits, the controller's presses that reach the bar are the grid's: the
-- game's Gamepad Mode bindings may beat Healpad's (UNVERIFIED: /hp probe
-- keys tells), and then A, B, X, Y and the d-pad press this button (n: its
-- place on the bar, gpkey<n>: the key that presses it). A row casts the
-- waiting heal from this button: its type is the spell for this one click
-- (GP_POST puts the action back). The trigger held picks the bar, so the
-- bar a row reaches says the group (gpbargrp).
--
-- What the fallback can't do: with no trigger held, A, B, X and Y press
-- the top bar's face buttons, which are the game's own (interact, inspect,
-- back, jump) with their own click scripts: no spell can be cast from
-- them, so a waiting heal only swallows those presses. Without Healpad's
-- bindings winning, a party's rows on A, B, X and Y with no trigger held
-- are therefore not reachable in Gamepad Mode (rows with LT or RT held
-- are), and neither are LB, RB and Start (groups 1-2, row 5 in a raid) or
-- Back (cancel): they aren't bar buttons at all.
local GP_BUTTONS = [[
    local armed = owner:GetAttribute("armed")
    -- the game's own buttons (interact, inspect, back, jump): never a cast;
    -- while a heal waits their press does nothing
    if owner:GetAttribute("gpown-" .. name) then
      if not armed then
        return
      end
      if down then
        owner:SetAttribute("gpflip-" .. name, true)
      end
      return false
    end
    local key = n and owner:GetAttribute("gpkey" .. n)
    if armed and key then
      local raid = owner:GetAttribute("raid")
      local hold = raid and owner:GetAttribute("gridg-" .. key)
      if hold then
        -- held; its release comes back through the flip and lets go
        if down then
          owner:SetAttribute("gpflip-" .. name, true)
          if not owner:GetAttribute("grp") then
            owner:SetAttribute("grpkey", name)
            owner:SetAttribute("grp", hold)
          end
        end
        return false
      end
      local r = owner:GetAttribute((raid and "gridr-" or "gridp-") .. key)
      if r then
        if not down then
          return false
        end
        owner:SetAttribute("gpflip-" .. name, true)
        -- only a plain action button (a spell or nothing in its slot) casts
        -- the heal; a flyout or anything else: the press does nothing
        if self:GetAttribute("type") ~= "action" or (kind ~= nil and kind ~= "spell") then
          return false
        end
        local g = owner:GetAttribute("gpbargrp-" .. name)
]] .. ROW_UNIT .. [[
        owner:SetAttribute("gptype-" .. name, self:GetAttribute("type"))
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", armed)
        self:SetAttribute("unit", unit)
        self:SetAttribute("useOnKeyDown", true)
        return nil, "row"
      end
    end
    local tap = spell and owner:GetAttribute("gpaim-" .. spell)
    if tap then
      if down then
        return false
      end
]] .. BTAP .. [[
      self:SetAttribute("useOnKeyDown", false)
      self:SetAttribute("unit", unit)
      return nil, "hp"
    end
    if armed then
      if down then
        owner:SetAttribute("gpflip-" .. name, true)
      end
      return false
    end
    return
]]

-- The same again, inside a button of the game's controller bar (Gamepad
-- Mode). The game picks the bar (the triggers), the page and the stance and
-- clicks the button; Healpad reads the spell its action slot holds, the way
-- the button itself does (its id, then the bar page). When that spell is a
-- Hold to Aim heal the press opens the diamond, and the release (the game
-- sends it to the same button) casts it on the aimed person. What Healpad
-- keeps for the hold sits on the controller, not on the game's button.
ns.GP_PRE = [[
  local name = self:GetName() or ""
  local gen = owner:GetAttribute("gen") or 0
  local n = strmatch(name, "ActionButton(%d)$")
  if owner:GetAttribute("gpflip-" .. name) then
    if not down then
      owner:SetAttribute("gpflip-" .. name, nil)
      -- a group held through this button lets go with it
      if owner:GetAttribute("grpkey") == name then
        owner:SetAttribute("grp", nil)
        owner:SetAttribute("grpkey", nil)
      end
    end
    return false
  end
  local spell, kind
  local id = self:GetID() or 0
  if id > 0 and self:GetAttribute("type") == "action" then
    local page = self:GetAttribute("actionpage") or GetActionBarPage() or 1
    local sid
    kind, sid = GetActionInfo(id + (page - 1) * 12)
    if kind == "spell" then
      spell = sid
    end
  end
  if owner:GetAttribute("bmode") then
]] .. GP_BUTTONS .. [[
  end
  -- While aiming, the d-pad picks a person even when Gamepad Mode's own
  -- bindings beat Healpad's: its press reaches this button, and the press
  -- and its release cast nothing.
  local held = owner:GetAttribute("held")
  if held and held ~= name and down and owner:GetAttribute("gpdpad") then
    local d
    if n == "1" then d = "LEFT" elseif n == "2" then d = "UP" elseif n == "3" then d = "RIGHT" elseif n == "4" then d = "DOWN" end
    if d then
      owner:SetAttribute("gpflip-" .. name, true)
      local cur = owner:GetAttribute("sel")
      local back = (d == "UP" and "DOWN") or (d == "DOWN" and "UP") or (d == "LEFT" and "RIGHT") or (d == "RIGHT" and "LEFT")
      if cur and cur == back then
        owner:SetAttribute("sel", "SELF")
      elseif owner:GetAttribute("u" .. (owner:GetAttribute("page") or 1) .. "-" .. d) then
        owner:SetAttribute("sel", d)
      end
      return false
    end
  end
  local skip = n and ("gpskip" .. n .. "-")
  if down then
    local tap = spell and owner:GetAttribute("gpaim-" .. spell)
    if not tap then return end
    owner:SetAttribute("gplock-" .. name, spell)
    owner:SetAttribute("gpgen-" .. name, gen)
    owner:SetAttribute("gptap-" .. name, tap)
]] .. OPEN .. [[
  end
  local lock = owner:GetAttribute("gplock-" .. name)
  if not lock then return end
  local tap = owner:GetAttribute("gptap-" .. name)
  owner:SetAttribute("gplock-" .. name, nil)
]] .. CLOSE .. [[
  if owner:GetAttribute("gpgen-" .. name) ~= gen or spell ~= lock then
    return false
  end
]] .. PICK .. [[
  self:SetAttribute("useOnKeyDown", false)
  self:SetAttribute("unit", unit)
  return nil, "hp"
]]

-- After a Healpad cast from the game's button: as the game set it up.
ns.GP_POST = [[
  if message == "row" then
    local name = self:GetName() or ""
    self:SetAttribute("type", owner:GetAttribute("gptype-" .. name))
    self:SetAttribute("spell", nil)
    owner:SetAttribute("gptype-" .. name, nil)
  end
  self:SetAttribute("unit", nil)
  self:SetAttribute("useOnKeyDown", true)
]]

ns.DIR_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  if c:GetAttribute("held") then
    local d = self:GetAttribute("dir")
    local cur = c:GetAttribute("sel")
    local back = (d == "UP" and "DOWN") or (d == "DOWN" and "UP") or (d == "LEFT" and "RIGHT") or (d == "RIGHT" and "LEFT")
    if cur and cur == back then
      c:SetAttribute("sel", "SELF")
    elseif c:GetAttribute("u" .. (c:GetAttribute("page") or 1) .. "-" .. d) then
      c:SetAttribute("sel", d)
    end
  end
]]

-- Everything back to rest: a hold, a waiting heal, a group held.
local RESET = [[
  c:SetAttribute("gen", (c:GetAttribute("gen") or 0) + 1)
  c:ClearBindings()
  c:SetAttribute("held", nil)
  c:SetAttribute("sel", nil)
  c:SetAttribute("swap", nil)
  c:SetAttribute("armtap", nil)
  c:SetAttribute("grp", nil)
  c:SetAttribute("grpkey", nil)
  c:SetAttribute("armed", nil)
  c:SetAttribute("state", "idle")
  local ps = c:GetFrameRef("plusseats")
  if ps and c:GetAttribute("plusmode") then
    ps:Show()
  end
]]

ns.CANCEL_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
]] .. RESET

-- Dead, mounted, or the bar taken by a vehicle or possession: a waiting
-- heal stops waiting (and Locked unlocks).
ns.STOP_SNIPPET = [[
  if newstate == "1" then
    local c = self:GetFrameRef("ctl")
    if c:GetAttribute("armed") then
]] .. RESET .. [[
    end
  end
]]

ns.PAGE_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  if not c:GetAttribute("held") then return end
  local n = c:GetAttribute("pages") or 1
  local p = (c:GetAttribute("page") or 1) + self:GetAttribute("step")
  if p > n then p = 1 elseif p < 1 then p = n end
  c:SetAttribute("page", p)
  c:SetAttribute("sel", nil)
  -- The plus's seat buttons are your own group's: on another group's page
  -- a click there would reach the wrong person, so they go until page 1.
  local ps = self:GetFrameRef("plusseats")
  if ps and c:GetAttribute("plusmode") then
    if p == 1 then
      ps:Show()
    else
      ps:Hide()
    end
  end
]]

-- Binds each heal button's key in the bar states where it casts that spell.
ns.KEYS_SNIPPET = [[
  local cur = self:GetAttribute("state-bar") or "p1"
  local c = self:GetFrameRef("ctl")
  self:ClearBindings()
  for i = 1, 12 do
    local b = self:GetFrameRef("heal" .. i)
    local key = b and b:GetAttribute("hp-key")
    if key then
      if b:GetAttribute("hp-ok-" .. cur) then
        self:SetBindingClick(true, key, b:GetName())
        c:SetAttribute("skip-" .. key, true)
      else
        c:SetAttribute("skip-" .. key, nil)
      end
    end
  end
  -- a heal waiting: its keys bound again over the heal keys just bound
  if c:GetAttribute("armed") then
    c:RunAttribute("_rearm")
  end
]]

ctl:SetAttribute("_rearm", ns.REARM_SNIPPET)

local function clicker(name, snippet)
  local b = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
  b:RegisterForClicks("AnyDown")
  SecureHandlerSetFrameRef(b, "ctl", ctl)
  b:SetAttribute("_onclick", snippet)
  return b
end

for _, d in ipairs(ns.DIRS) do
  clicker("HealpadDir" .. d, ns.DIR_SNIPPET):SetAttribute("dir", d)
end
clicker("HealpadCancel", ns.CANCEL_SNIPPET)
clicker("HealpadPageNext", ns.PAGE_SNIPPET):SetAttribute("step", 1)
clicker("HealpadPagePrev", ns.PAGE_SNIPPET):SetAttribute("step", -1)

ns.heals = {}
for i = 1, ns.HEALS do
  local b = CreateFrame("Button", "HealpadHeal" .. i, UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("useOnKeyDown", false)
  b:SetAttribute("type", "spell")
  b:SetAttribute("unit", "player")
  SecureHandlerWrapScript(b, "OnClick", ctl, ns.HEAL_SNIPPET)
  SecureHandlerSetFrameRef(keys, "heal" .. i, b)
  ns.heals[i] = b
end
SecureHandlerSetFrameRef(keys, "ctl", ctl)
keys:SetAttribute("_onstate-bar", ns.KEYS_SNIPPET)
RegisterStateDriver(keys, "bar", ns.BAR_DRIVER)

-- Buttons mode's buttons. A row button for each row (1-5) and each group a
-- trigger may say by being held as a modifier (0: none): HealpadRow3x0 is
-- row 3, HealpadRow3x4 row 3 with RT held as Ctrl.
ns.rows = {}
for r = 1, 5 do
  for g = 0, 8 do
    local b = CreateFrame("Button", "HealpadRow" .. r .. "x" .. g, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown")
    b:SetAttribute("useOnKeyDown", true)
    b:SetAttribute("type", "spell")
    b:SetAttribute("row", r)
    b:SetAttribute("modgrp", g > 0 and g or nil)
    SecureHandlerWrapScript(b, "OnClick", ctl, ns.ROW_SNIPPET)
    ns.rows[r .. "x" .. g] = b
  end
end
for g = 1, 8 do
  local b = CreateFrame("Button", "HealpadGroup" .. g, UIParent, "SecureHandlerClickTemplate")
  b:RegisterForClicks("AnyDown", "AnyUp")
  SecureHandlerSetFrameRef(b, "ctl", ctl)
  b:SetAttribute("group", g)
  b:SetAttribute("_onclick", ns.GROUP_SNIPPET)
end
-- The other controller buttons while a heal waits: nothing.
local noop = CreateFrame("Button", "HealpadNoop", UIParent)
noop:RegisterForClicks("AnyDown")

local stop = CreateFrame("Frame", "HealpadStop", UIParent, "SecureHandlerStateTemplate")
SecureHandlerSetFrameRef(stop, "ctl", ctl)
stop:SetAttribute("_onstate-stop", ns.STOP_SNIPPET)
RegisterStateDriver(stop, "stop", ns.STOP_DRIVER)

---------------------------------------------------------------- setup, out of combat

-- A key as it comes with modifiers held. A controller's triggers can hold
-- Shift and Ctrl; Gamepad Mode's bottom bar is both triggers (Ctrl-Shift).
ns.MODS = { "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-" }

-- The buttons the controller takes while you aim, and what each one clicks.
function ns.aimKeys()
  local db = ns.db
  local list = {}
  local function add(key, target, mods)
    table.insert(list, { key, target })
    if mods then
      for _, m in ipairs(ns.MODS) do
        table.insert(list, { m .. key, target })
      end
    end
  end
  local stick = ({ dpad = "PADD", rstick = "PADRSTICK", lstick = "PADLSTICK" })[db.aimWith] or "PADD"
  for _, d in ipairs({ "UP", "RIGHT", "DOWN", "LEFT" }) do
    add(stick .. d, "HealpadDir" .. d, true)
    add(d, "HealpadDir" .. d, true)
  end
  add("PADLSTICK", "HealpadDirSELF", true)
  add("PADRSTICK", "HealpadDirSELF", true)
  add("HOME", "HealpadDirSELF")
  add(db.cancel or "PAD2", "HealpadCancel", true)
  add("BACKSPACE", "HealpadCancel")
  add("PADRSHOULDER", "HealpadPageNext", true)
  add("PADLSHOULDER", "HealpadPagePrev", true)
  add("PAGEDOWN", "HealpadPageNext")
  add("PAGEUP", "HealpadPagePrev")
  return list
end

---------------------------------------------------------------- Buttons mode, out of combat

-- The grid: a party's rows, a raid's rows and groups.
ns.PARTY_ROWS = { PAD1 = 1, PAD2 = 2, PAD3 = 3, PAD4 = 4, PADDDOWN = 5 }
ns.RAID_ROWS = { PAD1 = 1, PAD2 = 2, PAD3 = 3, PAD4 = 4, PADFORWARD = 5 }
ns.RAID_GROUPS = {
  PADLSHOULDER = 1,
  PADRSHOULDER = 2,
  PADLTRIGGER = 3,
  PADRTRIGGER = 4,
  PADDUP = 5,
  PADDRIGHT = 6,
  PADDDOWN = 7,
  PADDLEFT = 8,
}
-- In order, for the labels: the group keys and the row keys.
ns.GROUP_KEYS =
  { "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT" }
ns.PARTY_ROW_KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "PADDDOWN" }
ns.RAID_ROW_KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "PADFORWARD" }

-- The group a trigger (or any group key) says when the game holds it as a
-- modifier (GamePadEmulateShift and the like): SHIFT -> 3 when LT holds
-- Shift. CTRL-SHIFT (both) says none.
function ns.modGroups()
  local out = {}
  for mod, cvar in pairs({ SHIFT = "GamePadEmulateShift", CTRL = "GamePadEmulateCtrl", ALT = "GamePadEmulateAlt" }) do
    local ok, v = pcall(C_CVar.GetCVar, cvar)
    if ok and ns.RAID_GROUPS[v] then
      out[mod .. "-"] = ns.RAID_GROUPS[v]
    end
  end
  return out
end

-- Keys a waiting heal leaves alone though they're controller buttons: in
-- Gamepad Mode the controller bar's (they reach Healpad in the bar's
-- buttons), and KeyBars keys with a heal set to Healpad on them.
local function freeKeys()
  local free = {}
  if ns.gamepadMode() then
    for n = 1, 8 do
      for _, k in ipairs(ns.keysOf("GAMEPADACTIONBUTTON" .. n)) do
        free[k] = true
      end
    end
  end
  for _, b in ipairs(ns.binds or {}) do
    if b.kb and ns.db.aimSpell[b.cast] then
      free[b.key] = true
    end
  end
  return free
end

-- The keys a waiting heal takes, for a party ("bp") or a raid ("br"): each
-- { key, button, soft }; a soft one stays a heal when it is one.
function ns.armKeys(raid)
  local list, seen = {}, {}
  local function add(key, button, soft)
    if not seen[key] then
      seen[key] = true
      table.insert(list, { key, button, soft or nil })
    end
  end
  local mods = ns.modGroups()
  local cancel = ns.db.btnCancel
  add(cancel, "HealpadCancel")
  for _, m in ipairs(ns.MODS) do
    add(m .. cancel, "HealpadCancel")
  end
  local grid = {}
  if raid then
    for _, k in ipairs(ns.RAID_ROW_KEYS) do
      local r = ns.RAID_ROWS[k]
      grid[k] = true
      add(k, "HealpadRow" .. r .. "x0")
      for _, m in ipairs(ns.MODS) do
        local g = mods[m]
        if g then
          add(m .. k, "HealpadRow" .. r .. "x" .. g)
        else
          add(m .. k, "HealpadNoop", true)
        end
      end
    end
    for _, k in ipairs(ns.GROUP_KEYS) do
      local g = ns.RAID_GROUPS[k]
      grid[k] = true
      add(k, "HealpadGroup" .. g)
      for _, m in ipairs(ns.MODS) do
        -- a trigger held as a modifier was held first: this group waits
        add(m .. k, mods[m] and "HealpadNoop" or ("HealpadGroup" .. g))
      end
    end
  else
    for _, k in ipairs(ns.PARTY_ROW_KEYS) do
      local r = ns.PARTY_ROWS[k]
      grid[k] = true
      add(k, "HealpadRow" .. r .. "x0")
      for _, m in ipairs(ns.MODS) do
        add(m .. k, "HealpadRow" .. r .. "x0", true)
      end
    end
  end
  local free = freeKeys()
  for _, k in ipairs(ns.PAD_ORDER) do
    if not grid[k] and k ~= cancel and not free[k] then
      add(k, "HealpadNoop", true)
      for _, m in ipairs(ns.MODS) do
        add(m .. k, "HealpadNoop", true)
      end
    end
  end
  return list
end

-- Tells the controller whether Buttons is on, and the keys a waiting heal
-- takes. Any heal waiting or held stops first.
local function applyButtons()
  local db = ns.db
  local on = ns.isButtons()
  if (ctl:GetAttribute("bmode") or false) ~= on or ctl:GetAttribute("armed") then
    SecureHandlerExecute(_G.HealpadCancel, ns.CANCEL_SNIPPET)
  end
  ctl:SetAttribute("bmode", on or nil)
  ctl:SetAttribute("lockmode", (on and db.after == "locked") or nil)
  for _, which in ipairs({ "bp", "br" }) do
    local list = ns.armKeys(which == "br")
    for i, e in ipairs(list) do
      ctl:SetAttribute(which .. "k" .. i, e[1])
      ctl:SetAttribute(which .. "b" .. i, e[2])
      ctl:SetAttribute(which .. "s" .. i, e[3])
    end
    ctl:SetAttribute(which .. "-n", #list)
  end
  for k, r in pairs(ns.PARTY_ROWS) do
    ctl:SetAttribute("gridp-" .. k, r)
  end
  for k, r in pairs(ns.RAID_ROWS) do
    ctl:SetAttribute("gridr-" .. k, r)
  end
  for k, g in pairs(ns.RAID_GROUPS) do
    ctl:SetAttribute("gridg-" .. k, g)
  end
end
ns.applyButtons = applyButtons

-- Who sits in each seat, kept from one roster change to the next.
local seatNames

-- Who sits in each place of each page (Radial), each row (Buttons), and
-- who the seat buttons are. Out of combat only.
function ns.applyRoster()
  ns.afterCombat("roster", function()
    local members, solo = ns.readRoster()
    ns.mapTokens()
    local seats, mine = ns.buildSeats(members, seatNames)
    seatNames = ns.seatNames(seats)
    local order = ns.pageGroups(seats, mine)
    -- Plus and Buttons: seats that belong to people; the menu while held
    -- (Game): as it always was, by role, with unit tokens, the tap's person
    -- trading places with you.
    local person = ns.plusOn() or ns.isButtons()
    ctl:SetAttribute("personseats", person or nil)
    local pages, tankUnit = {}, nil
    if not person then
      pages, tankUnit = ns.buildPages(members, solo)
    elseif solo then
      pages[1] = { SELF = "player" }
    else
      for p, g in ipairs(order) do
        local page = {}
        for i, d in ipairs(ns.SEAT_DIRS) do
          local m = seats[g][i]
          page[d] = m and ns.seatUnit(m) or nil
        end
        pages[p] = page
      end
      local tank = ns.findTank(members)
      tankUnit = tank and ns.seatUnit(tank) or nil
    end
    for p = 1, 8 do
      for _, d in ipairs(ns.DIRS) do
        ctl:SetAttribute("u" .. p .. "-" .. d, pages[p] and pages[p][d] or nil)
      end
    end
    ctl:SetAttribute("pages", #pages)
    ctl:SetAttribute("tank", tankUnit)
    -- Buttons: the party's rows, and every group's rows in a raid
    local raid = IsInRaid()
    local own = solo and { "player" } or {}
    if not solo and not raid and seats[mine] then
      for i = 1, 5 do
        own[i] = seats[mine][i] and ns.seatUnit(seats[mine][i]) or nil
      end
    end
    for r = 1, 5 do
      ctl:SetAttribute("p" .. r, own[r])
    end
    for g = 1, 8 do
      for r = 1, 5 do
        local m = raid and seats[g] and seats[g][r]
        ctl:SetAttribute("g" .. g .. "-" .. r, m and ns.seatUnit(m) or nil)
      end
    end
    ctl:SetAttribute("raid", raid or nil)
    ctl:SetAttribute("solo", solo or nil)
    ns.seats = { list = seats, mine = mine, order = order, raid = raid, solo = solo }
    if ns.placeSeats then
      ns.placeSeats()
    end
    if ns.redraw then
      ns.redraw()
    end
    if ns.redrawGrid then
      ns.redrawGrid()
    end
  end)
end

-- What applyKeys last set up. Binding and bar events come often (and our own
-- override bindings fire UPDATE_BINDINGS), so the same setup is not redone.
local lastSig

-- Whether a listed button holds to aim, and its settings.
function ns.aimConf(b)
  if not b then
    return nil
  end
  if b.kb then
    return ns.db.aimSpell[b.cast]
  end
  if b.gp then
    return ns.db.aimPad[b.spell]
  end
  return ns.db.aim[b.key]
end

local wrapped = {} -- KeyBars buttons Healpad sits in
local spellAttrs = {} -- aimspell-* attributes set on the controller

-- Out of combat: sit in each KeyBars button once, and tell the controller
-- which spells hold to aim and who their tap heals.
local function applyKeyBars(binds)
  for _, a in ipairs(spellAttrs) do
    ctl:SetAttribute(a, nil)
  end
  wipe(spellAttrs)
  for _, b in ipairs(binds) do
    if b.kb then
      local btn = _G[b.button]
      if btn and not wrapped[b.button] then
        SecureHandlerWrapScript(btn, "OnClick", ctl, ns.KB_PRE, ns.KB_POST)
        wrapped[b.button] = true
      end
      local conf = ns.db.aimSpell[b.cast]
      if conf then
        local a = "aimspell-" .. b.cast
        ctl:SetAttribute(a, conf.tap or "player")
        table.insert(spellAttrs, a)
      end
    end
  end
end

-- Gamepad Mode: sit in each of the controller bar's buttons once (never in
-- combat), and tell the controller which spells hold to aim there and which
-- keys press each button. Healpad never sets anything on the game's buttons
-- from addon code: that would taint them.
local gpWrapped = {}
local gpAttrs = {}
-- Sits in every button of the controller bar (out of combat). The game
-- sets the top bar's face buttons' own click scripts after it loads
-- (MainActionBarFrame.lua SetupNonbindableActions), which drops a wrap made
-- before: each time, a button whose click script isn't Healpad's wrap any
-- more is wrapped again.
local function wrapGamepad()
  if not ns.gamepadMode() then
    return
  end
  local bars = {}
  for _, bar in ipairs(ns.GP_BARS) do
    table.insert(bars, bar)
  end
  table.insert(bars, { id = "stance", frame = "stanceBar", offset = 32 })
  for _, bar in ipairs(bars) do
    for n = 1, 8 do
      local f, name = ns.gamepadButton(bar, n)
      local now
      if f then
        local okS, script = pcall(f.GetScript, f, "OnClick")
        now = okS and script or nil
      end
      if f and name and (not gpWrapped[f] or gpWrapped[f] ~= now) then
        local ok, err = pcall(SecureHandlerWrapScript, f, "OnClick", ctl, ns.GP_PRE, ns.GP_POST)
        if ok then
          local okW, wrapper = pcall(f.GetScript, f, "OnClick")
          gpWrapped[f] = okW and wrapper or true
        else
          ns.log("gamepad wrap " .. name .. ": " .. tostring(err))
        end
      end
    end
  end
end

local function applyGamepad()
  for _, a in ipairs(gpAttrs) do
    ctl:SetAttribute(a, nil)
  end
  wipe(gpAttrs)
  if not ns.gamepadMode() then
    return
  end
  local function set(a, v)
    ctl:SetAttribute(a, v)
    table.insert(gpAttrs, a)
  end
  -- the game's own top-bar face buttons (interact, inspect, back, jump):
  -- a waiting heal swallows their presses (they never cast)
  for n = 5, 8 do
    local _, name = ns.gamepadButton(ns.GP_BARS[1], n)
    if name then
      set("gpown-" .. name, true)
    end
  end
  set("gpdpad", (ns.db.aimWith or "dpad") == "dpad" or nil)
  -- Buttons mode: the key that presses each place of the bar, and the group
  -- the bar says (its trigger: the left bar is the one LT picks)
  for n = 1, 8 do
    set("gpkey" .. n, ns.keysOf("GAMEPADACTIONBUTTON" .. n)[1])
  end
  local barGroup = {
    left = ns.RAID_GROUPS[ns.keysOf("GAMEPADLEFTMOD")[1] or ""],
    right = ns.RAID_GROUPS[ns.keysOf("GAMEPADRIGHTMOD")[1] or ""],
  }
  for _, bar in ipairs(ns.GP_BARS) do
    for n = 1, 8 do
      local _, name = ns.gamepadButton(bar, n)
      if name and barGroup[bar.id] then
        set("gpbargrp-" .. name, barGroup[bar.id])
      end
    end
  end
  for spell, conf in pairs(ns.db.aimPad) do
    set("gpaim-" .. tostring(spell), conf.tap or "player")
  end
  -- A hold leaves the button it came from alone: you can't press it again,
  -- and its release must reach the game.
  for n = 1, 8 do
    for _, k in ipairs(ns.keysOf("GAMEPADACTIONBUTTON" .. n)) do
      set("gpskip" .. n .. "-" .. k, true)
      for _, m in ipairs(ns.MODS) do
        set("gpskip" .. n .. "-" .. m .. k, true)
      end
    end
  end
end

local function signature(binds)
  local db = ns.db
  local parts = {
    db.aimWith or "",
    db.cancel or "",
    tostring(ns.gamepadMode()),
    db.mode or "",
    db.after or "",
    db.btnCancel or "",
  }
  for _, k in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
    local ok, v = pcall(C_CVar.GetCVar, k)
    table.insert(parts, ok and tostring(v) or "")
  end
  if ns.gamepadMode() then
    local pad = {}
    for spell, conf in pairs(db.aimPad) do
      table.insert(pad, tostring(spell) .. "=" .. tostring(conf.tap))
    end
    for n = 1, 8 do
      table.insert(pad, n .. "=" .. table.concat(ns.keysOf("GAMEPADACTIONBUTTON" .. n), ","))
    end
    table.sort(pad)
    table.insert(parts, table.concat(pad, ","))
  end
  for _, b in ipairs(binds) do
    local conf = ns.aimConf(b)
    local states = {}
    for _, s in ipairs(ns.BAR_STATES) do
      if b.states[s] then
        table.insert(states, s)
      end
    end
    table.insert(
      parts,
      (b.kb and ("kb:" .. b.button .. ":" .. b.layer .. ":" .. b.cast .. "=") or "")
        .. (b.gp and ("gp:" .. b.gp .. b.n .. "=") or "")
        .. b.key
        .. "="
        .. tostring(b.spell)
        .. ":"
        .. table.concat(states, ",")
        .. (conf and (":" .. (conf.tap or "")) or "")
    )
  end
  return table.concat(parts, "|")
end

-- Reads your bindings and gives each Hold to Aim heal a heal button.
-- force: redo it even when nothing seems to have changed.
function ns.applyKeys(force)
  ns.afterCombat("keys", function()
    wrapGamepad()
    local binds = ns.readBinds()
    local sig = signature(binds)
    ns.binds = binds
    if sig == lastSig and force ~= true then
      return
    end
    lastSig = sig
    local used = 0
    applyKeyBars(ns.binds)
    applyGamepad()
    for _, bind in ipairs(ns.binds) do
      local conf = not bind.kb and ns.db.aim[bind.key]
      if conf and bind.heal and used < ns.HEALS then
        used = used + 1
        local b = ns.heals[used]
        b:SetAttribute("hp-spell", bind.spell)
        b:SetAttribute("spell", bind.spell)
        b:SetAttribute("hp-tap", conf.tap or "player")
        b:SetAttribute("hp-key", bind.key)
        for _, s in ipairs(ns.BAR_STATES) do
          b:SetAttribute("hp-ok-" .. s, bind.states[s] or nil)
        end
      end
    end
    for i = used + 1, ns.HEALS do
      local b = ns.heals[i]
      local old = b:GetAttribute("hp-key")
      if old then
        ctl:SetAttribute("skip-" .. old, nil)
      end
      b:SetAttribute("hp-key", nil)
      b:SetAttribute("hp-spell", nil)
    end
    local aim = ns.aimKeys()
    for i, k in ipairs(aim) do
      ctl:SetAttribute("ak" .. i, k[1])
      ctl:SetAttribute("ab" .. i, k[2])
    end
    ctl:SetAttribute("ak-n", #aim)
    -- The sticks send Up, Down, Left and Right only with this game setting.
    if ns.db.aimWith == "rstick" or ns.db.aimWith == "lstick" then
      local okc, v = pcall(C_CVar.GetCVar, "GamePadStickAxisButtons")
      if okc and v ~= "1" then
        pcall(C_CVar.SetCVar, "GamePadStickAxisButtons", "1")
        ns.log("turned on GamePadStickAxisButtons for stick aiming")
      end
    end
    SecureHandlerExecute(keys, ns.KEYS_SNIPPET)
    applyButtons()
    if ns.refreshOptions then
      ns.refreshOptions()
    end
  end)
end

ns.on("PLAYER_LOGIN", function()
  ns.applyRoster()
  ns.applyKeys(true)
  if KeyBarsAPI and KeyBarsAPI.onChange then
    KeyBarsAPI.onChange(function()
      ns.applyKeys()
    end)
  end
end)
ns.on("GROUP_ROSTER_UPDATE", ns.applyRoster)
-- A member's name arrives late ("Unknown" until then): seat them by it.
ns.on("UNIT_NAME_UPDATE", function(unit)
  if type(unit) == "string" and (unit:match("^party%d$") or unit:match("^raid%d+$")) then
    ns.applyRoster()
  end
end)
ns.on("PLAYER_ROLES_ASSIGNED", ns.applyRoster)
ns.on("PLAYER_REGEN_ENABLED", ns.applyRoster)
for _, e in ipairs({
  "UPDATE_BINDINGS",
  "INPUT_DEVICE_INTERFACE_TRANSITION",
  "PLAYER_ENTERING_WORLD",
  "ACTIONBAR_SLOT_CHANGED",
  "UPDATE_BONUS_ACTIONBAR",
  "ACTIONBAR_PAGE_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "SPELLS_CHANGED",
}) do
  ns.on(e, function()
    ns.applyKeys()
  end)
end
