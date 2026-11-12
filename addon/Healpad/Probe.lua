-- /hp probe: what this client lets Healpad do, for the party frames and the
-- button grid. Two parts, both saved in HealpadDB.probe for a /reload:
--
--   /hp probe keys   20 seconds: every controller button is bound to a
--                    catcher. Each press that reaches it is recorded, so the
--                    log says which buttons Healpad can take over, in
--                    Gamepad Mode too. Out of combat; the buttons do nothing
--                    else while it runs.
--   /hp probe        3 minutes, or until /hp probe stop: once a second, what
--                    the game lets an addon read about each party member, in
--                    and out of combat: health, threat, heals on the way,
--                    debuffs (stacks), your HoTs (their clock), and a party
--                    member by name (Roster.lua's SEAT_BY_NAME rests on it).
local _, ns = ...

local PAD_KEYS = {
  "PAD1",
  "PAD2",
  "PAD3",
  "PAD4",
  "PAD5",
  "PAD6",
  "PADLSHOULDER",
  "PADRSHOULDER",
  "PADLTRIGGER",
  "PADRTRIGGER",
  "PADDUP",
  "PADDDOWN",
  "PADDLEFT",
  "PADDRIGHT",
  "PADBACK",
  "PADFORWARD",
  "PADSYSTEM",
  "PADSOCIAL",
  "PADLSTICK",
  "PADRSTICK",
  "PADPADDLE1",
  "PADPADDLE2",
  "PADPADDLE3",
  "PADPADDLE4",
}
local KEYS_TIME, READ_TIME, EVERY = 20, 180, 1

local function secret(v)
  if not issecretvalue then
    return false
  end
  local ok, s = pcall(issecretvalue, v)
  return ok and s == true
end

-- One value as a short word: "secret", "nil", or the value.
local function word(v)
  if secret(v) then
    return "secret"
  end
  if v == nil then
    return "nil"
  end
  return tostring(v)
end

-- A call: its first result as a word, or "error: ..." when it throws.
local function try(fn, ...)
  if type(fn) ~= "function" then
    return "missing"
  end
  local ok, a = pcall(fn, ...)
  if not ok then
    return "error: " .. tostring(a):gsub("^.-:%d+: ", ""):sub(1, 120)
  end
  return word(a)
end

local function store()
  ns.db.probe = ns.db.probe or {}
  return ns.db.probe
end

---------------------------------------------------------------- keys

local catcher, keyOwner, keysOn

local function stopKeys()
  if not keysOn then
    return
  end
  if InCombatLockdown() then
    C_Timer.After(1, stopKeys)
    return
  end
  ClearOverrideBindings(keyOwner)
  keysOn = false
  local got, missed = {}, {}
  for _, k in ipairs(PAD_KEYS) do
    if store().keys[k] then
      table.insert(got, k)
    else
      table.insert(missed, k)
    end
  end
  store().keysCaught = table.concat(got, " ")
  store().keysNotPressedOrLost = table.concat(missed, " ")
  ns.say("key probe done. Type /reload so it is saved.")
end

local function startKeys()
  if InCombatLockdown() then
    ns.say("out of combat.")
    return
  end
  if not catcher then
    catcher = CreateFrame("Button", "HealpadProbeCatch", UIParent)
    catcher:RegisterForClicks("AnyDown")
    catcher:SetScript("OnClick", function(_, key)
      local k = store().keys
      k[key] = (k[key] or 0) + 1
      ns.say(key)
    end)
    keyOwner = CreateFrame("Frame")
  end
  local p = store()
  p.keys = {}
  p.keysAt = date("%Y-%m-%d %H:%M:%S")
  p.gamepadMode = word(C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled())
  p.emulateShift = try(GetCVar, "GamePadEmulateShift")
  p.emulateCtrl = try(GetCVar, "GamePadEmulateCtrl")
  p.emulateAlt = try(GetCVar, "GamePadEmulateAlt")
  local okState, state = pcall(function()
    return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
  end)
  if okState and type(state) == "table" then
    p.padName = word(state.name)
    p.padLabels = word(state.labelStyle)
    p.padButtons = word(state.buttonCount)
  else
    p.padName = "none"
  end
  -- What each button did before, so the log shows whose binding lost.
  p.before = {}
  for _, k in ipairs(PAD_KEYS) do
    p.before[k] = try(GetBindingAction, k, true)
    SetOverrideBindingClick(keyOwner, true, k, "HealpadProbeCatch", k)
  end
  keysOn = true
  ns.say(
    "press every controller button once, A B X Y, shoulders, triggers, d-pad, Back, Start, stick clicks. "
      .. KEYS_TIME
      .. " seconds."
  )
  C_Timer.After(KEYS_TIME, stopKeys)
end

---------------------------------------------------------------- reads

local readOn, readUntil, ticker

local function units()
  local out = { "player" }
  if IsInRaid and IsInRaid() then
    for i = 1, math.min(GetNumGroupMembers() or 0, 10) do
      table.insert(out, "raid" .. i)
    end
  else
    for i = 1, 4 do
      if UnitExists("party" .. i) then
        table.insert(out, "party" .. i)
      end
    end
  end
  return out
end

local AURA_FILTERS = { "HARMFUL", "HARMFUL|RAID", "HELPFUL|PLAYER" }

local function auraRead(unit, i, filter)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
    return "missing"
  end
  local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
  if not ok then
    return "error: " .. tostring(a):gsub("^.-:%d+: ", ""):sub(1, 120)
  end
  if a == nil then
    return "none"
  end
  if secret(a) then
    return "secret table"
  end
  return string.format(
    "name %s, icon %s, stacks %s, dispel %s, id %s",
    word(a.name),
    word(a.icon),
    word(a.applications),
    word(a.dispelName),
    word(a.auraInstanceID)
  )
end

-- Distinct answers only: each check keeps the set of answers it gave, by
-- combat state, so the saved file stays short.
local function note(sec, key, value)
  local t = sec[key] or {}
  sec[key] = t
  for _, v in ipairs(t) do
    if v == value then
      return
    end
  end
  if #t < 6 then
    table.insert(t, value)
  end
end

local function sample()
  if not readOn then
    return
  end
  if GetTime() > readUntil then
    ns.probeStop()
    return
  end
  local p = store()
  local state = InCombatLockdown() and "combat" or "rest"
  p.reads[state] = p.reads[state] or {}
  local sec = p.reads[state]
  p.samples[state] = (p.samples[state] or 0) + 1
  for _, unit in ipairs(units()) do
    local kind = unit == "player" and "player" or "group"
    local function n(key, value)
      note(sec, kind .. " " .. key, value)
    end
    n("health", try(UnitHealth, unit))
    n("health max", try(UnitHealthMax, unit))
    n("threat", try(UnitThreatSituation, unit))
    n("heals on the way", try(UnitGetIncomingHeals, unit))
    n("dead", try(UnitIsDeadOrGhost, unit))
    n("connected", try(UnitIsConnected, unit))
    n("rez on the way", try(UnitHasIncomingResurrection, unit))
    for _, f in ipairs(AURA_FILTERS) do
      n("aura 1 " .. f, auraRead(unit, 1, f))
      n("aura 2 " .. f, auraRead(unit, 2, f))
    end
    -- The dispel color the game picks, from a secret aura too.
    local okA, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HARMFUL|RAID")
    if okA and a and not secret(a) and C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil then
      n(
        "dispel color",
        try(function()
          local c = C_CurveUtil.CreateColorCurve()
          c:AddPoint(0, CreateColor(0, 0, 0, 0))
          c:AddPoint(4, CreateColor(1, 1, 1, 1))
          local color = C_UnitAuras.GetAuraDispelTypeColor(unit, a.auraInstanceID, c)
          return color and "a color" or "none"
        end)
      )
      n(
        "debuff stacks text",
        try(function()
          return C_UnitAuras.GetAuraApplicationDisplayCount(unit, a.auraInstanceID, 2)
        end)
      )
      n(
        "aura duration",
        try(function()
          return C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit, a.auraInstanceID) and "an object"
            or "none"
        end)
      )
    end
    -- Your HoT: whether its clock can be shown (a duration object).
    local okH, h = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HELPFUL|PLAYER|RAID_IN_COMBAT")
    if okH and h and not secret(h) then
      n(
        "hot duration",
        try(function()
          return C_UnitAuras.GetAuraDuration(unit, h.auraInstanceID) and "an object" or "none"
        end)
      )
    end
    -- A party member by name: what seats that follow the person need.
    if unit ~= "player" then
      local okN, name = pcall(GetUnitName, unit, true)
      if okN and type(name) == "string" and not secret(name) then
        n("by name exists", try(UnitExists, name))
        n("by name is the same", try(UnitIsUnit, name, unit))
        n("by name health", try(UnitHealth, name))
        n("by name [@name,help]", try(SecureCmdOptionParse, "[@" .. name .. ",help] yes; no"))
        -- the check a seat makes before a Buttons heal casts on its person
        n("by name [@name,help,nodead]", try(SecureCmdOptionParse, "[@" .. name .. ",help,nodead] yes; no"))
      else
        n("by name", "name " .. word(name))
      end
    end
  end
end

local function startReads()
  local p = store()
  p.reads, p.samples = {}, {}
  p.readsAt = date("%Y-%m-%d %H:%M:%S")
  p.build = tostring((GetBuildInfo()))
  readOn, readUntil = true, GetTime() + READ_TIME
  if not ticker then
    ticker = C_Timer.NewTicker(EVERY, sample)
  end
  ns.say("probe on for 3 minutes. Fight something with your party, then /hp probe stop and /reload.")
end

function ns.probeStop()
  if not readOn then
    return
  end
  readOn = false
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
  local s = store().samples or {}
  ns.say(string.format("probe done: %d in combat, %d out. Type /reload so it is saved.", s.combat or 0, s.rest or 0))
end

function ns.probe(arg)
  if arg == "keys" then
    startKeys()
  elseif arg == "stop" then
    ns.probeStop()
  else
    startReads()
  end
end
