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
    -- The middle of the diamond is whoever a tap heals: when that's someone
    -- in it, they trade places with you for this hold.
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
    local swap
    if tu and tu ~= "player" then
      if owner:GetAttribute("u1-UP") == tu then swap = "UP"
      elseif owner:GetAttribute("u1-RIGHT") == tu then swap = "RIGHT"
      elseif owner:GetAttribute("u1-DOWN") == tu then swap = "DOWN"
      elseif owner:GetAttribute("u1-LEFT") == tu then swap = "LEFT" end
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
  end
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
    if tap == "last" then
      unit = owner:GetAttribute("last")
    elseif tap == "tank" then
      unit = owner:GetAttribute("tank")
    elseif tap == "focus" then
      unit = "focus"
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
  end
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

-- A Healpad heal button: the key is Healpad's while its bar state casts it.
ns.HEAL_SNIPPET = [[
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
  -- While aiming, the d-pad picks a person even when Gamepad Mode's own
  -- bindings beat Healpad's: its press reaches this button, and the press
  -- and its release cast nothing.
  local held = owner:GetAttribute("held")
  if owner:GetAttribute("gpflip-" .. name) then
    if not down then
      owner:SetAttribute("gpflip-" .. name, nil)
    end
    return false
  end
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
  local spell
  local id = self:GetID() or 0
  if id > 0 and self:GetAttribute("type") == "action" then
    local page = self:GetAttribute("actionpage") or GetActionBarPage() or 1
    local kind, sid = GetActionInfo(id + (page - 1) * 12)
    if kind == "spell" then
      spell = sid
    end
  end
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

ns.CANCEL_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  c:SetAttribute("gen", (c:GetAttribute("gen") or 0) + 1)
  c:ClearBindings()
  c:SetAttribute("held", nil)
  c:SetAttribute("sel", nil)
  c:SetAttribute("swap", nil)
  c:SetAttribute("state", "idle")
]]

ns.PAGE_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  if not c:GetAttribute("held") then return end
  local n = c:GetAttribute("pages") or 1
  local p = (c:GetAttribute("page") or 1) + self:GetAttribute("step")
  if p > n then p = 1 elseif p < 1 then p = n end
  c:SetAttribute("page", p)
  c:SetAttribute("sel", nil)
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
]]

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

-- Who sits in each place of each page.
function ns.applyRoster()
  ns.afterCombat("roster", function()
    local members, solo = ns.readRoster()
    local pages, tank = ns.buildPages(members, solo)
    for p = 1, 8 do
      for _, d in ipairs(ns.DIRS) do
        ctl:SetAttribute("u" .. p .. "-" .. d, pages[p] and pages[p][d] or nil)
      end
    end
    ctl:SetAttribute("pages", #pages)
    ctl:SetAttribute("tank", tank)
    if ns.redraw then
      ns.redraw()
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
  local bars = {}
  for _, bar in ipairs(ns.GP_BARS) do
    table.insert(bars, bar)
  end
  table.insert(bars, { id = "stance", frame = "stanceBar", offset = 32 })
  for _, bar in ipairs(bars) do
    for n = 1, 8 do
      -- The top bar's face buttons are the game's own (interact, jump...).
      local own = bar.id == "top" and n >= 5
      local f, name = ns.gamepadButton(bar, n)
      if f and name and not own and not gpWrapped[f] then
        local ok, err = pcall(SecureHandlerWrapScript, f, "OnClick", ctl, ns.GP_PRE, ns.GP_POST)
        if ok then
          gpWrapped[f] = true
        else
          ns.log("gamepad wrap " .. name .. ": " .. tostring(err))
        end
      end
    end
  end
  set("gpdpad", (ns.db.aimWith or "dpad") == "dpad" or nil)
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
  local parts = { db.aimWith or "", db.cancel or "", tostring(ns.gamepadMode()) }
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
