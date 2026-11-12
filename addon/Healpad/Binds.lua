-- Your buttons: what you already bound, read at run time. WoW Forever classes
-- have their own spells, so Healpad knows none; it reads the spell on the bar
-- slot (or the button) each binding presses, rank and all.
local _, ns = ...

-- The bar state, as a secure state driver reports it: "x" in a vehicle or an
-- override bar, "p2".."p6" on a paged bar, "b1".."b5" on a bonus bar (forms
-- and stances), else "p1".
ns.BAR_DRIVER = "[vehicleui][possessbar][overridebar] x; [actionbar:2] p2; [actionbar:3] p3; "
  .. "[actionbar:4] p4; [actionbar:5] p5; [actionbar:6] p6; [bonusbar:1] b1; [bonusbar:2] b2; "
  .. "[bonusbar:3] b3; [bonusbar:4] b4; [bonusbar:5] b5; p1"
ns.BAR_STATES = { "p1", "p2", "p3", "p4", "p5", "p6", "b1", "b2", "b3", "b4", "b5" }

function ns.barState()
  local ok, s = pcall(SecureCmdOptionParse, ns.BAR_DRIVER)
  return ok and s or "p1"
end

-- The slot the main bar's button n presses in a bar state.
local function mainSlot(n, state)
  local kind, k = state:sub(1, 1), tonumber(state:sub(2))
  if kind == "p" then
    return (k - 1) * 12 + n
  end
  if kind == "b" then
    return (5 + k) * 12 + n
  end
end

local MULTI = {
  [1] = { "MultiBarBottomLeftButton", 60 },
  [2] = { "MultiBarBottomRightButton", 48 },
  [3] = { "MultiBarRightButton", 24 },
  [4] = { "MultiBarLeftButton", 36 },
  [5] = { "MultiBar5Button", 144 },
  [6] = { "MultiBar6Button", 156 },
  [7] = { "MultiBar7Button", 168 },
}

local function spellOfSlot(slot)
  if not slot then
    return nil
  end
  local ok, kind, id = pcall(GetActionInfo, slot)
  if not ok then
    return nil
  end
  if kind == "spell" then
    return id
  end
  if kind == "macro" then
    local ok2, s = pcall(GetMacroSpell, id)
    return ok2 and s or nil
  end
end

local function spellId(v)
  if type(v) == "number" then
    return v
  end
  if type(v) ~= "string" then
    return nil
  end
  local ok, info = pcall(C_Spell.GetSpellInfo, v)
  return ok and info and info.spellID or nil
end

-- The spell a secure button casts now: a KeyBars slot, a macro button, etc.
local function spellOfButton(f)
  if not f or not f.GetAttribute then
    return nil
  end
  local kind = f:GetAttribute("type")
  if kind == "spell" then
    return spellId(f:GetAttribute("spell"))
  end
  if kind == "action" then
    return spellOfSlot(f:GetAttribute("action"))
  end
  if kind == "macro" then
    local ok, s = pcall(GetMacroSpell, f:GetAttribute("macro"))
    return ok and s or nil
  end
end

local function allStates()
  local t = {}
  for _, s in ipairs(ns.BAR_STATES) do
    t[s] = true
  end
  return t
end

-- What a binding command casts: the spell id, and the bar states in which
-- it casts that same spell. nil when it casts no spell.
function ns.resolve(command)
  if type(command) ~= "string" then
    return nil
  end
  local now = ns.barState()
  local n = tonumber(command:match("^ACTIONBUTTON(%d+)$"))
  if n then
    if now == "x" then
      return nil
    end
    local spell = spellOfSlot(mainSlot(n, now))
    if not spell then
      return nil
    end
    local states = {}
    for _, s in ipairs(ns.BAR_STATES) do
      if spellOfSlot(mainSlot(n, s)) == spell then
        states[s] = true
      end
    end
    return { spell = spell, states = states }
  end
  local bar, b = command:match("^MULTIACTIONBAR(%d)BUTTON(%d+)$")
  bar, b = tonumber(bar), tonumber(b)
  if bar and MULTI[bar] then
    local f = _G[MULTI[bar][1] .. b]
    local slot = (f and type(f.action) == "number") and f.action or (MULTI[bar][2] + b)
    local spell = spellOfSlot(slot)
    return spell and { spell = spell, states = allStates() } or nil
  end
  -- A spell bound straight to a key or button (no bar slot): every state.
  local spellName = command:match("^SPELL (.+)$")
  if spellName then
    local spell = spellId(spellName) or spellId(spellName:gsub("%s*%(.-%)%s*$", ""))
    return spell and { spell = spell, states = allStates() } or nil
  end
  local macro = command:match("^MACRO (.+)$")
  if macro then
    local ok, spell = pcall(GetMacroSpell, tonumber(macro) or macro)
    return (ok and spell) and { spell = spell, states = allStates() } or nil
  end
  local name = command:match("^CLICK (.-):") or command:match("^CLICK (.+)$")
  if name then
    local spell = spellOfButton(_G[name])
    -- A button that changes with forms (KeyBars layers): this state only.
    return spell and { spell = spell, states = { [now] = true } } or nil
  end
  return nil
end

-- A heal you can aim: friendly and cast at someone. Self-only spells
-- (Walk on Air, a teleport) are friendly too but have no range.
function ns.isHeal(spell)
  local ok, yes = pcall(C_Spell.IsSpellHelpful, spell)
  if not (ok and yes == true) then
    return false
  end
  local ok2, ranged = pcall(C_Spell.SpellHasRange, spell)
  return ok2 and ranged == true
end

-- "Healing Touch" and "Rank 4" (or "").
function ns.spellName(id)
  return id and C_Spell.GetSpellName(id) or ""
end
function ns.spellRank(id)
  local ok, sub = pcall(C_Spell.GetSpellSubtext, id)
  return ok and sub or ""
end
function ns.spellLabel(id)
  local rank = ns.spellRank(id)
  if rank ~= "" then
    return ns.spellName(id) .. " (" .. rank .. ")"
  end
  return ns.spellName(id)
end
function ns.spellIcon(id)
  return id and C_Spell.GetSpellTexture(id) or 134400
end

---------------------------------------------------------------- key names

local PAD = {
  PAD1 = "A",
  PAD2 = "B",
  PAD3 = "X",
  PAD4 = "Y",
  PAD5 = "P5",
  PAD6 = "P6",
  PADLSHOULDER = "LB",
  PADRSHOULDER = "RB",
  PADLTRIGGER = "LT",
  PADRTRIGGER = "RT",
  PADLSTICK = "L3",
  PADRSTICK = "R3",
  PADDUP = "Up",
  PADDRIGHT = "Right",
  PADDDOWN = "Down",
  PADDLEFT = "Left",
  PADFORWARD = "Menu",
  PADBACK = "View",
  PADPADDLE1 = "P1",
  PADPADDLE2 = "P2",
  PADPADDLE3 = "P3",
  PADPADDLE4 = "P4",
}
local PAD_ORDER = {
  "PAD1",
  "PAD2",
  "PAD3",
  "PAD4",
  "PADRSHOULDER",
  "PADLSHOULDER",
  "PADRTRIGGER",
  "PADLTRIGGER",
  "PAD5",
  "PAD6",
  "PADPADDLE1",
  "PADPADDLE2",
  "PADPADDLE3",
  "PADPADDLE4",
  "PADLSTICK",
  "PADRSTICK",
  "PADDUP",
  "PADDRIGHT",
  "PADDDOWN",
  "PADDLEFT",
  "PADFORWARD",
  "PADBACK",
}
ns.PAD_ORDER = PAD_ORDER
local PAD_RANK = {}
for i, k in ipairs(PAD_ORDER) do
  PAD_RANK[k] = i
end
local MOD_ORDER = { [""] = 1, SHIFT = 2, CTRL = 3, ALT = 4 }
local EMULATE = { SHIFT = "GamePadEmulateShift", CTRL = "GamePadEmulateCtrl", ALT = "GamePadEmulateAlt" }

-- "SHIFT-PAD3" -> "SHIFT", "PAD3"
function ns.splitKey(key)
  local mods, base = key:match("^(.-%-?)([^%-]+)$")
  mods = (mods or ""):gsub("%-$", "")
  return mods, base or key
end

function ns.isPad(key)
  local _, base = ns.splitKey(key)
  return base:sub(1, 3) == "PAD"
end

-- The name of a modifier: the pad button that holds it (LT), else Shift.
local function modName(mod, pad)
  if pad and EMULATE[mod] then
    local ok, v = pcall(C_CVar.GetCVar, EMULATE[mod])
    if ok and PAD[v] then
      return PAD[v]
    end
  end
  return mod:sub(1, 1) .. mod:sub(2):lower()
end

-- The group a key sits in: "" for plain buttons, "LT" for LT combos, etc.
function ns.keyGroup(key)
  local mods = ns.splitKey(key)
  if mods == "" then
    return ""
  end
  local out = {}
  for m in mods:gmatch("[^%-]+") do
    table.insert(out, modName(m, ns.isPad(key)))
  end
  return table.concat(out, "+")
end

-- The game draws pad buttons as icons that match the controller in use
-- (Xbox, PlayStation, Switch, Steam Deck); letters are the fallback.
local function padGlyph(base)
  local ok, t = pcall(GetBindingText, base)
  if ok and type(t) == "string" and (t:find("|A:", 1, true) or t:find("|T", 1, true)) then
    return t
  end
end

-- A controller button as the game draws it for the controller in use (its
-- own button art: Xbox, PlayStation or Switch), as text markup at size;
-- the button's short name when the game has no art for it.
local SHORT = {
  PADDUP = "Up",
  PADDRIGHT = "Right",
  PADDDOWN = "Down",
  PADDLEFT = "Left",
  PADFORWARD = "Start",
  PADBACK = "Back",
  PADLSTICK = "L3",
  PADRSTICK = "R3",
}
function ns.padIcon(key, size)
  size = size or 16
  local ok, atlas = pcall(function()
    return InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(key)
  end)
  if ok and type(atlas) == "string" and atlas ~= "" then
    return string.format("|A:%s:%d:%d|a", atlas, size, size)
  end
  return padGlyph(key) or SHORT[key] or PAD[key] or key
end

function ns.keyLabel(key)
  if not key then
    return ""
  end
  local _, base = ns.splitKey(key)
  local name = padGlyph(base) or PAD[base]
  if not name then
    local ok, t = pcall(GetBindingText, base)
    name = (ok and t and t ~= "") and t or base
  end
  local group = ns.keyGroup(key)
  return group ~= "" and (group .. "+" .. name) or name
end

local function before(a, b)
  if a.pad ~= b.pad then
    return a.pad
  end
  local ma, ba = ns.splitKey(a.key)
  local mb, bb = ns.splitKey(b.key)
  local oa, ob = MOD_ORDER[ma] or 9, MOD_ORDER[mb] or 9
  if oa ~= ob then
    return oa < ob
  end
  if ma ~= mb then
    return ma < mb
  end
  local ra, rb = PAD_RANK[ba] or 99, PAD_RANK[bb] or 99
  if ra ~= rb then
    return ra < rb
  end
  return a.key < b.key
end

-- Keys worth asking about: every key in the game's binding list, plus the
-- usual keys with modifiers, since addons like KeyBars bind keys as override
-- bindings that the list doesn't have.
local EXTRA = {}
do
  local bases = {
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
    "-",
    "=",
    "`",
    "[",
    "]",
    ";",
    "'",
    ",",
    ".",
    "/",
    "BUTTON3",
    "BUTTON4",
    "BUTTON5",
    "MOUSEWHEELUP",
    "MOUSEWHEELDOWN",
    "TAB",
    "SPACE",
  }
  for c = string.byte("A"), string.byte("Z") do
    table.insert(bases, string.char(c))
  end
  for i = 1, 12 do
    table.insert(bases, "F" .. i)
  end
  for i = 0, 9 do
    table.insert(bases, "NUMPAD" .. i)
  end
  for _, k in ipairs(PAD_ORDER) do
    table.insert(bases, k)
  end
  for _, m in ipairs({ "", "SHIFT-", "CTRL-", "ALT-" }) do
    for _, b in ipairs(bases) do
      table.insert(EXTRA, m .. b)
    end
  end
end

-- What a key does when Healpad isn't holding it. Healpad's own override
-- bindings (heal buttons, the settings' nav keys) hide the one beneath, so
-- the last one seen is kept.
local beneath = {}
local function commandOf(key)
  local ok, action = pcall(GetBindingAction, key, true)
  action = ok and action or ""
  if action:match("^CLICK Healpad") then
    if beneath[key] then
      return beneath[key]
    end
    local ok2, plain = pcall(GetBindingAction, key)
    return ok2 and plain or ""
  end
  beneath[key] = action
  return action
end

---------------------------------------------------------------- Gamepad Mode
-- In the game's Gamepad Mode a controller button presses no key binding of
-- yours. The binding context GamepadModeInGameCore binds the face buttons
-- and the d-pad to GAMEPADACTIONBUTTON1..8, which press button n of the
-- controller bar in front (Blizzard_GamepadActionBars, Bindings.xml and
-- MainActionBarFrame.lua PressActionButton). The triggers (GAMEPADLEFTMOD,
-- GAMEPADRIGHTMOD) pick that bar: none the top bar, LT the left, RT the
-- right, both the bottom (PageUnit.lua ActionBarModKeyDownStateCheck). Each
-- bar has 8 buttons on each of 3 pages, kept in the controller's own action
-- slots (ActionBindingUtil.lua); a stance can put its own bar in place of
-- one (StanceBar.lua). The top bar's face buttons are the game's own
-- (interact, inspect, back, jump) and cast nothing.

local GP_CONTEXT = 9 -- Enum.BindingContext.GamepadModeInGameCore
local GP_PAGES = 3 -- standard pages; page 4 is the possess bar's
local GP_SLOTS = 32 -- slots of one page: 4 bars of 8
local GP_RESERVED = 4 -- the top bar's face buttons, slots 5..8, have no storage
ns.GP_BARS = {
  { id = "top", frame = "topBar", offset = 0 },
  { id = "left", frame = "leftBar", offset = 8 },
  { id = "right", frame = "rightBar", offset = 16 },
  { id = "bottom", frame = "bottomBar", offset = 24 },
}
-- GamepadStanceBarOverride: the page and bar a stance's bar takes the place of.
local STANCE_OVER = {
  [2] = { 1, "left" },
  [3] = { 1, "right" },
  [4] = { 1, "bottom" },
  [5] = { 2, "top" },
  [6] = { 2, "left" },
  [7] = { 2, "right" },
  [8] = { 2, "bottom" },
  [9] = { 3, "top" },
  [10] = { 3, "left" },
  [11] = { 3, "right" },
  [12] = { 3, "bottom" },
}

local function call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b = pcall(fn, ...)
  if ok then
    return a, b
  end
end

-- Whether the game's Gamepad Mode runs: its binding context is on.
function ns.gamepadMode()
  if not (C_KeyBindings and GamepadMainActionBarFrame) then
    return false
  end
  local ctx = Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore or GP_CONTEXT
  return call(C_KeyBindings.IsBindingContextActive, ctx) == true
end

-- The keys bound to a command, gamepad keys included.
function ns.keysOf(command)
  local ok, keys = pcall(function(c)
    return { GetBindingKey(c, true) }
  end, command)
  local out = {}
  for _, k in ipairs(ok and keys or {}) do
    if type(k) == "string" and k ~= "" then
      table.insert(out, k)
    end
  end
  return out
end

-- The controller bar page in front: 1..3, or 4 for the possess bar's.
function ns.gamepadPage()
  local pu = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
  local p = pu and call(pu.GetCurrentPage, pu)
  return type(p) == "number" and p or 1
end

-- The action slot button n of a bar presses on a page, as the game's
-- gamepad buttons work it out (their id, then CalculateAction's page).
local function gpSlot(page, bar, n)
  local id
  if call(C_ActionBar and C_ActionBar.HasBonusActionBar) then
    local o = STANCE_OVER[tonumber((call(C_CVar.GetCVar, "GamepadStanceBarOverride")))]
    if o and o[1] == page and o[2] == bar.id then
      local first = call(C_GamepadUI and C_GamepadUI.GetFirstGamepadActionBarStorageSlotIndexForActiveStance)
      id = first and (first + n - 1)
    end
  end
  if not id then
    local s = bar.offset + n
    if s >= 5 and s < 5 + GP_RESERVED then
      return nil
    end
    local first = call(C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
    if type(first) ~= "number" then
      return nil
    end
    id = first + (GP_SLOTS - GP_RESERVED) * (page - 1) + (s - 1)
    if s >= 5 then
      id = id - GP_RESERVED
    end
  end
  local barPage = call(C_ActionBar and C_ActionBar.GetActionBarPage)
  return id + ((type(barPage) == "number" and barPage or 1) - 1) * 12
end

-- The game's button frame for a bar's button n, and its name.
function ns.gamepadButton(bar, n)
  local pu = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
  local bars = pu and pu.actionBars
  local b = bars and bars[bar.frame]
  local f = b and b.actionButtons and b.actionButtons[n]
  if not f then
    return nil
  end
  local ok, name = pcall(f.GetName, f)
  return f, ok and name or nil
end

-- The controller bar's buttons that cast a spell now: { key, gp (the bar),
-- n, group (the triggers held: "", "LT", "RT", "LT+RT"), label, spell,
-- pages (where that button casts that same spell), heal, pad }.
function ns.readGamepad()
  local out = {}
  if not ns.gamepadMode() then
    return out
  end
  local now = ns.gamepadPage()
  if now > GP_PAGES then
    return out
  end
  local lk, rk = ns.keysOf("GAMEPADLEFTMOD")[1], ns.keysOf("GAMEPADRIGHTMOD")[1]
  local l = lk and ns.keyLabel(lk) or "LT"
  local r = rk and ns.keyLabel(rk) or "RT"
  local groups = { top = "", left = l, right = r, bottom = l .. "+" .. r }
  for bi, bar in ipairs(ns.GP_BARS) do
    for n = 1, 8 do
      local key = ns.keysOf("GAMEPADACTIONBUTTON" .. n)[1]
      local slot = key and gpSlot(now, bar, n)
      local spell = spellOfSlot(slot)
      if spell then
        local pages = {}
        for p = 1, GP_PAGES do
          if spellOfSlot(gpSlot(p, bar, n)) == spell then
            pages[p] = true
          end
        end
        local group = groups[bar.id]
        local _, name = ns.gamepadButton(bar, n)
        table.insert(out, {
          key = key,
          gp = bar.id,
          gpOrder = bi,
          n = n,
          slot = slot,
          button = name,
          command = "GAMEPADACTIONBUTTON" .. n,
          group = group,
          label = group ~= "" and (group .. "+" .. ns.keyLabel(key)) or ns.keyLabel(key),
          spell = spell,
          pages = pages,
          states = {},
          heal = ns.isHeal(spell),
          pad = true,
        })
      end
    end
  end
  table.sort(out, function(a, b)
    if a.gpOrder ~= b.gpOrder then
      return a.gpOrder < b.gpOrder
    end
    local ra, rb = PAD_RANK[a.key] or 99, PAD_RANK[b.key] or 99
    if ra ~= rb then
      return ra < rb
    end
    return a.n < b.n
  end)
  return out
end

-- The keys Gamepad Mode's own bindings hold: in that mode your bindings on
-- them don't run.
local GP_COMMANDS = {
  "GAMEPADLEFTMOD",
  "GAMEPADRIGHTMOD",
  "GAMEPADLEFTTARGETMODIFIER",
  "GAMEPADRIGHTTARGETMODIFIER",
  "OPENRADIAL",
  "TOGGLEUIFOCUS",
  "TOGGLEPINGSYSTEM",
}
for n = 1, 8 do
  table.insert(GP_COMMANDS, "GAMEPADACTIONBUTTON" .. n)
end
local function gamepadKeys()
  local t = {}
  for _, c in ipairs(GP_COMMANDS) do
    for _, k in ipairs(ns.keysOf(c)) do
      t[k] = true
    end
  end
  return t
end

-- The label a list shows for a bind.
function ns.bindLabel(b)
  return b.label or ns.keyLabel(b.key)
end

-- Every bound button that casts a spell: { key, command, spell, states, heal,
-- pad }. Pad buttons first, then keys; a key on the keyboard shows only when
-- it casts a heal. In Gamepad Mode the controller bar comes first, and the
-- action bars' bindings are left out: the controller doesn't press them.
function ns.readBinds()
  local gamepad = ns.gamepadMode()
  local taken = gamepad and gamepadKeys() or {}
  local list, seen = {}, {}
  local keys = {}
  local ok, n = pcall(GetNumBindings)
  n = ok and n or 0
  for i = 1, n do
    local got = { pcall(GetBinding, i) }
    if got[1] then
      for j = 4, #got do
        if type(got[j]) == "string" and got[j] ~= "" then
          table.insert(keys, got[j])
        end
      end
    end
  end
  for _, k in ipairs(EXTRA) do
    table.insert(keys, k)
  end
  for _, key in ipairs(keys) do
    if not seen[key] then
      seen[key] = true
      local command = commandOf(key)
      -- KeyBars keys come from KeyBars itself, every layer at once.
      if KeyBarsAPI and command:match("^CLICK KeyBarsButton") then
        command = ""
      end
      if gamepad and (taken[key] or command:match("^ACTIONBUTTON") or command:match("^MULTIACTIONBAR")) then
        command = ""
      end
      local r = command ~= "" and ns.resolve(command) or nil
      if r then
        local heal = ns.isHeal(r.spell)
        local pad = ns.isPad(key)
        if pad or heal then
          table.insert(
            list,
            { key = key, command = command, spell = r.spell, states = r.states, heal = heal, pad = pad }
          )
        end
      end
    end
  end
  table.sort(list, before)
  if gamepad then
    local gp = ns.readGamepad()
    for i, e in ipairs(list) do
      gp[#gp + 1] = e
      list[i] = nil
    end
    list = gp
  end
  for _, e in ipairs(ns.readKeyBars()) do
    table.insert(list, e)
  end
  return list
end

-- KeyBars keys, one entry per layer with a heal: { key, kb = true, button,
-- layer (its name), spell, cast (what the button's "spell" attribute holds
-- on that layer) }. Hold to Aim follows the spell: Healing Touch aims on
-- every key and layer that casts it.
function ns.readKeyBars()
  local out = {}
  if not (KeyBarsAPI and KeyBarsAPI.slots) then
    return out
  end
  local ok, slots = pcall(KeyBarsAPI.slots)
  if not ok or type(slots) ~= "table" then
    return out
  end
  for _, slot in ipairs(slots) do
    for _, L in ipairs(slot.layers or {}) do
      local id = spellId(L.spell) or spellId(L.cast)
      if id and ns.isHeal(id) then
        table.insert(out, {
          key = slot.key,
          kb = true,
          button = slot.button,
          layer = L.name or "",
          layerId = tonumber(L.id) or 0,
          order = #out,
          spell = id,
          cast = tostring(L.cast),
          heal = true,
          states = {},
        })
      end
    end
  end
  -- One group per layer, in KeyBars' layer order; keys in KeyBars' order.
  table.sort(out, function(a, b)
    if a.layerId ~= b.layerId then
      return a.layerId < b.layerId
    end
    return a.order < b.order
  end)
  return out
end
