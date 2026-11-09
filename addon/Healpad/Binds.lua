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
  if kind == "p" then return (k - 1) * 12 + n end
  if kind == "b" then return (5 + k) * 12 + n end
end

local MULTI = {
  [1] = { "MultiBarBottomLeftButton", 60 }, [2] = { "MultiBarBottomRightButton", 48 },
  [3] = { "MultiBarRightButton", 24 }, [4] = { "MultiBarLeftButton", 36 },
  [5] = { "MultiBar5Button", 144 }, [6] = { "MultiBar6Button", 156 }, [7] = { "MultiBar7Button", 168 },
}

local function spellOfSlot(slot)
  if not slot then return nil end
  local ok, kind, id = pcall(GetActionInfo, slot)
  if not ok then return nil end
  if kind == "spell" then return id end
  if kind == "macro" then
    local ok2, s = pcall(GetMacroSpell, id)
    return ok2 and s or nil
  end
end

local function spellId(v)
  if type(v) == "number" then return v end
  if type(v) ~= "string" then return nil end
  local ok, info = pcall(C_Spell.GetSpellInfo, v)
  return ok and info and info.spellID or nil
end

-- The spell a secure button casts now: a KeyBars slot, a macro button, etc.
local function spellOfButton(f)
  if not f or not f.GetAttribute then return nil end
  local kind = f:GetAttribute("type")
  if kind == "spell" then return spellId(f:GetAttribute("spell")) end
  if kind == "action" then return spellOfSlot(f:GetAttribute("action")) end
  if kind == "macro" then
    local ok, s = pcall(GetMacroSpell, f:GetAttribute("macro"))
    return ok and s or nil
  end
end

local function allStates()
  local t = {}
  for _, s in ipairs(ns.BAR_STATES) do t[s] = true end
  return t
end

-- What a binding command casts: the spell id, and the bar states in which
-- it casts that same spell. nil when it casts no spell.
function ns.resolve(command)
  if type(command) ~= "string" then return nil end
  local now = ns.barState()
  local n = tonumber(command:match("^ACTIONBUTTON(%d+)$"))
  if n then
    if now == "x" then return nil end
    local spell = spellOfSlot(mainSlot(n, now))
    if not spell then return nil end
    local states = {}
    for _, s in ipairs(ns.BAR_STATES) do
      if spellOfSlot(mainSlot(n, s)) == spell then states[s] = true end
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
  local name = command:match("^CLICK (.-):") or command:match("^CLICK (.+)$")
  if name then
    local spell = spellOfButton(_G[name])
    -- A button that changes with forms (KeyBars layers): this state only.
    return spell and { spell = spell, states = { [now] = true } } or nil
  end
  return nil
end

function ns.isHeal(spell)
  local ok, yes = pcall(C_Spell.IsSpellHelpful, spell)
  return ok and yes == true
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
  if rank ~= "" then return ns.spellName(id) .. " (" .. rank .. ")" end
  return ns.spellName(id)
end
function ns.spellIcon(id)
  return id and C_Spell.GetSpellTexture(id) or 134400
end

---------------------------------------------------------------- key names

local PAD = {
  PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PAD5 = "P5", PAD6 = "P6",
  PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
  PADLSTICK = "L3", PADRSTICK = "R3", PADDUP = "Up", PADDRIGHT = "Right", PADDDOWN = "Down", PADDLEFT = "Left",
  PADFORWARD = "Menu", PADBACK = "View", PADPADDLE1 = "P1", PADPADDLE2 = "P2", PADPADDLE3 = "P3", PADPADDLE4 = "P4",
}
local PAD_ORDER = { "PAD1", "PAD2", "PAD3", "PAD4", "PADRSHOULDER", "PADLSHOULDER", "PADRTRIGGER", "PADLTRIGGER",
  "PAD5", "PAD6", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PADLSTICK", "PADRSTICK",
  "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PADFORWARD", "PADBACK" }
local PAD_RANK = {}
for i, k in ipairs(PAD_ORDER) do PAD_RANK[k] = i end
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
    if ok and PAD[v] then return PAD[v] end
  end
  return mod:sub(1, 1) .. mod:sub(2):lower()
end

-- The group a key sits in: "" for plain buttons, "LT" for LT combos, etc.
function ns.keyGroup(key)
  local mods = ns.splitKey(key)
  if mods == "" then return "" end
  local out = {}
  for m in mods:gmatch("[^%-]+") do table.insert(out, modName(m, ns.isPad(key))) end
  return table.concat(out, "+")
end

function ns.keyLabel(key)
  if not key then return "" end
  local _, base = ns.splitKey(key)
  local name = PAD[base]
  if not name then
    local ok, t = pcall(GetBindingText, base)
    name = (ok and t and t ~= "") and t or base
  end
  local group = ns.keyGroup(key)
  return group ~= "" and (group .. "+" .. name) or name
end

local function before(a, b)
  if a.pad ~= b.pad then return a.pad end
  local ma, ba = ns.splitKey(a.key)
  local mb, bb = ns.splitKey(b.key)
  local oa, ob = MOD_ORDER[ma] or 9, MOD_ORDER[mb] or 9
  if oa ~= ob then return oa < ob end
  if ma ~= mb then return ma < mb end
  local ra, rb = PAD_RANK[ba] or 99, PAD_RANK[bb] or 99
  if ra ~= rb then return ra < rb end
  return a.key < b.key
end

-- Every bound button that casts a spell: { key, command, spell, states, heal,
-- pad }. Pad buttons first, then keys; a key on the keyboard shows only when
-- it casts a heal.
function ns.readBinds()
  local list, seen = {}, {}
  local ok, n = pcall(GetNumBindings)
  n = ok and n or 0
  for i = 1, n do
    local got = { pcall(GetBinding, i) }
    if got[1] then
      local command = got[2]
      for j = 4, #got do
        local key = got[j]
        if type(key) == "string" and key ~= "" and not seen[key] then
          seen[key] = true
          local r = ns.resolve(command)
          if r then
            local heal = ns.isHeal(r.spell)
            local pad = ns.isPad(key)
            if pad or heal then
              table.insert(list, { key = key, command = command, spell = r.spell, states = r.states,
                heal = heal, pad = pad })
            end
          end
        end
      end
    end
  end
  table.sort(list, before)
  return list
end
