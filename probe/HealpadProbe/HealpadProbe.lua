-- Healpad Probe: tests hold-to-aim heals on the real client.
-- Hold the heal key, tap an arrow key to aim, let go: the spell casts on that person.
-- Every press, release, cast and error goes to chat and to HealpadProbeDB.log.

local PREFIX = "|cff7fe3e3Healpad probe|r: "
local DIRS = { "UP", "RIGHT", "DOWN", "LEFT" }
local db

local function safe(v)
  local ok, s = pcall(function() return tostring(v) end)
  if not ok then return "(secret)" end
  local ok2 = pcall(function() return s .. "" end)
  return ok2 and s or "(secret)"
end

local function log(msg)
  local line = string.format("%.2f %s%s", GetTime(), InCombatLockdown() and "[combat] " or "", msg)
  print(PREFIX .. line)
  if db then
    db.log = db.log or {}
    table.insert(db.log, date("%H:%M:%S ") .. line)
    while #db.log > 400 do table.remove(db.log, 1) end
  end
end

---------------------------------------------------------------- secure parts

local ctl = CreateFrame("Frame", "HealpadProbeCtl", UIParent, "SecureHandlerBaseTemplate")
local keyOwner = CreateFrame("Frame", "HealpadProbeKeys", UIParent)

-- Press: lock the spell, take the arrows, cast nothing. Release: cast on the aimed unit.
local PRE = [[
  if down then
    local was = owner:GetAttribute("held")
    if was == self:GetName() then
      owner:SetAttribute("note", "lost-release-reset:" .. was)
    elseif was then
      owner:SetAttribute("note", "second-press:" .. self:GetName())
      return false
    end
    owner:SetAttribute("held", self:GetName())
    owner:SetAttribute("sel", nil)
    owner:ClearBindings()
    owner:SetBindingClick(true, "UP", "HealpadProbeDirUP")
    owner:SetBindingClick(true, "RIGHT", "HealpadProbeDirRIGHT")
    owner:SetBindingClick(true, "DOWN", "HealpadProbeDirDOWN")
    owner:SetBindingClick(true, "LEFT", "HealpadProbeDirLEFT")
    owner:SetBindingClick(true, "BACKSPACE", "HealpadProbeCancel")
    owner:SetBindingClick(true, "PADLSTICKUP", "HealpadProbeStickPADLSTICKUP")
    owner:SetBindingClick(true, "PADLSTICKRIGHT", "HealpadProbeStickPADLSTICKRIGHT")
    owner:SetBindingClick(true, "PADLSTICKDOWN", "HealpadProbeStickPADLSTICKDOWN")
    owner:SetBindingClick(true, "PADLSTICKLEFT", "HealpadProbeStickPADLSTICKLEFT")
    owner:SetBindingClick(true, "PADRSTICKUP", "HealpadProbeStickPADRSTICKUP")
    owner:SetBindingClick(true, "PADRSTICKRIGHT", "HealpadProbeStickPADRSTICKRIGHT")
    owner:SetBindingClick(true, "PADRSTICKDOWN", "HealpadProbeStickPADRSTICKDOWN")
    owner:SetBindingClick(true, "PADRSTICKLEFT", "HealpadProbeStickPADRSTICKLEFT")
    owner:SetBindingClick(true, "PADDUP", "HealpadProbeStickPADDUP")
    owner:SetBindingClick(true, "PADDRIGHT", "HealpadProbeStickPADDRIGHT")
    owner:SetBindingClick(true, "PADDDOWN", "HealpadProbeStickPADDDOWN")
    owner:SetBindingClick(true, "PADDLEFT", "HealpadProbeStickPADDLEFT")
    owner:SetAttribute("state", "aim")
    return false
  end
  local held = owner:GetAttribute("held")
  if held ~= self:GetName() then
    owner:SetAttribute("note", "release-not-held:" .. self:GetName() .. ":" .. tostring(held))
    return false
  end
  owner:ClearBindings()
  owner:SetAttribute("held", nil)
  local sel = owner:GetAttribute("sel")
  local unit = sel and owner:GetAttribute("unit-" .. sel) or "player"
  self:SetAttribute("unit", unit)
  owner:SetAttribute("state", "idle")
  owner:SetAttribute("note", "cast:" .. self:GetName() .. ":" .. unit)
]]

local DIR = [[
  local c = self:GetFrameRef("ctl")
  if c:GetAttribute("held") then c:SetAttribute("sel", self:GetAttribute("dir")) end
]]

local CANCEL = [[
  local c = self:GetFrameRef("ctl")
  c:ClearBindings()
  c:SetAttribute("held", nil)
  c:SetAttribute("sel", nil)
  c:SetAttribute("state", "idle")
  c:SetAttribute("note", "cancel")
]]

for _, d in ipairs(DIRS) do
  local b = CreateFrame("Button", "HealpadProbeDir" .. d, UIParent, "SecureHandlerClickTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("dir", d)
  SecureHandlerSetFrameRef(b, "ctl", ctl)
  b:SetAttribute("_onclick", DIR)
end
-- Stick and d-pad directions, bound only while a heal is held: which ones reach us?
local STICKS = { { "PADLSTICKUP", "UP" }, { "PADLSTICKRIGHT", "RIGHT" }, { "PADLSTICKDOWN", "DOWN" }, { "PADLSTICKLEFT", "LEFT" }, { "PADRSTICKUP", "UP" }, { "PADRSTICKRIGHT", "RIGHT" }, { "PADRSTICKDOWN", "DOWN" }, { "PADRSTICKLEFT", "LEFT" }, { "PADDUP", "UP" }, { "PADDRIGHT", "RIGHT" }, { "PADDDOWN", "DOWN" }, { "PADDLEFT", "LEFT" } }
local STICK = [[
  local c = self:GetFrameRef("ctl")
  c:SetAttribute("note", "pad-dir:" .. self:GetAttribute("key"))
  if c:GetAttribute("held") then c:SetAttribute("sel", self:GetAttribute("dir")) end
]]
for _, k in ipairs(STICKS) do
  local b = CreateFrame("Button", "HealpadProbeStick" .. k[1], UIParent, "SecureHandlerClickTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("key", k[1])
  b:SetAttribute("dir", k[2])
  SecureHandlerSetFrameRef(b, "ctl", ctl)
  b:SetAttribute("_onclick", STICK)
end

do
  local b = CreateFrame("Button", "HealpadProbeCancel", UIParent, "SecureHandlerClickTemplate")
  b:RegisterForClicks("AnyDown")
  SecureHandlerSetFrameRef(b, "ctl", ctl)
  b:SetAttribute("_onclick", CANCEL)
end

local heals = {}
for _, id in ipairs({ "A", "B" }) do
  local b = CreateFrame("Button", "HealpadProbeHeal" .. id, UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("useOnKeyDown", false)
  b:SetAttribute("type", "spell")
  b:SetAttribute("unit", "player")
  SecureHandlerWrapScript(b, "OnClick", ctl, PRE)
  b:HookScript("OnClick", function(self, button, down)
    log((down and "press " or "release ") .. id .. " (" .. tostring(button) .. ")")
  end)
  heals[id] = b
end

---------------------------------------------------------------- the diamond (plain frames)

local diamond = CreateFrame("Frame", nil, UIParent)
diamond:SetAllPoints()
diamond:Hide()
local spots = {}
local OFFS = { UP = { 0, 150 }, RIGHT = { 220, 0 }, DOWN = { 0, -150 }, LEFT = { -220, 0 }, SELF = { 0, -60 } }
for key, o in pairs(OFFS) do
  local f = CreateFrame("Frame", nil, diamond, "BackdropTemplate")
  f:SetSize(key == "SELF" and 90 or 140, 28)
  f:SetPoint("CENTER", UIParent, "CENTER", o[1], o[2])
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  f:SetBackdropColor(0.06, 0.08, 0.11, 0.85)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER")
  spots[key] = f
end

local function unitFor(key)
  if key == "SELF" then return "player" end
  return ctl:GetAttribute("unit-" .. key)
end

local function drawDiamond()
  local sel = ctl:GetAttribute("sel") or "SELF"
  for key, f in pairs(spots) do
    local unit = unitFor(key)
    if unit and UnitExists(unit) then
      f.text:SetText(UnitName(unit))
    else
      f.text:SetText(key == "UP" and not IsInGroup() and "(your target)" or "-")
    end
    if key == sel then f:SetBackdropBorderColor(0.95, 0.76, 0.31, 1) else f:SetBackdropBorderColor(0.16, 0.19, 0.25, 1) end
  end
end

local poller = CreateFrame("Frame")
local lastDir = {}
local function stickDir(x, y)
  if not x or not y then return nil end
  if math.abs(x) < 0.6 and math.abs(y) < 0.6 then return "center" end
  if math.abs(x) > math.abs(y) then return x > 0 and "RIGHT" or "LEFT" end
  return y > 0 and "UP" or "DOWN"
end
poller:SetScript("OnUpdate", function()
  if not diamond:IsShown() then lastDir = {} return end
  local ok, st = pcall(function()
    local id = C_GamePad.GetActiveDeviceID()
    return id and C_GamePad.GetDeviceMappedState(id)
  end)
  if not ok or not st or not st.sticks then return end
  for i, stick in ipairs(st.sticks) do
    local d = stickDir(stick.x, stick.y)
    if d ~= lastDir[i] then
      lastDir[i] = d
      log("analog stick " .. i .. " " .. tostring(d))
    end
  end
end)

local function padReport()
  for _, k in ipairs({ "PADLSTICKUP", "PADRSTICKUP", "PADDUP" }) do
    local ok, a = pcall(GetBindingAction, k, true)
    log(k .. " is bound to: " .. safe(ok and a))
  end
  for _, cv in ipairs({ "GamePadStickAxisButtons", "GamePadEnable", "GamePadCameraYawSpeed" }) do
    local ok, v = pcall(C_CVar.GetCVar, cv)
    log("cvar " .. cv .. " = " .. safe(ok and v))
  end
end

ctl:HookScript("OnAttributeChanged", function(_, name, value)
  if name == "state" then
    diamond:SetShown(value == "aim")
    if value == "aim" then drawDiamond() end
    log("state " .. tostring(value))
  elseif name == "sel" then
    if value then log("aim " .. tostring(value) .. " -> " .. tostring(unitFor(value))) end
    if diamond:IsShown() then drawDiamond() end
  elseif name == "note" and value then
    log("snippet: " .. tostring(value))
  end
end)

---------------------------------------------------------------- setup (out of combat only)

local function setUnits()
  if InCombatLockdown() then return end
  if IsInGroup() then
    ctl:SetAttribute("unit-UP", "party1")
    ctl:SetAttribute("unit-RIGHT", "party2")
    ctl:SetAttribute("unit-DOWN", "party3")
    ctl:SetAttribute("unit-LEFT", "party4")
  else
    ctl:SetAttribute("unit-UP", "target")
    ctl:SetAttribute("unit-RIGHT", "party2")
    ctl:SetAttribute("unit-DOWN", "party3")
    ctl:SetAttribute("unit-LEFT", "party4")
  end
end

local function spellLabel(id)
  if not id then return "none" end
  local name = C_Spell.GetSpellName(id) or ("spell " .. id)
  local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
  return name .. ((sub and sub ~= "") and (" (" .. sub .. ")") or "") .. " #" .. id
end

local function applySpells()
  if InCombatLockdown() then return end
  heals.A:SetAttribute("spell", db.a)
  heals.B:SetAttribute("spell", db.b)
end

local function applyKeys()
  if InCombatLockdown() then return end
  ClearOverrideBindings(keyOwner)
  SetOverrideBindingClick(keyOwner, true, db.key, "HealpadProbeHealA", "LeftButton")
  SetOverrideBindingClick(keyOwner, true, "SHIFT-" .. db.key, "HealpadProbeHealB", "LeftButton")
end

local helpful = {}
local function scan()
  wipe(helpful)
  local bank = Enum.SpellBookSpellBank.Player
  for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
    if line and not line.shouldHide then
      for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if item and item.itemType == Enum.SpellBookItemType.Spell and C_SpellBook.IsSpellBookItemHelpful(slot, bank) then
          table.insert(helpful, item.spellID or item.actionID)
        end
      end
    end
  end
end

local function help()
  print(PREFIX .. "hold " .. db.key .. " = spell A, hold Shift-" .. db.key .. " = spell B.")
  print(PREFIX .. "While holding: arrow keys aim (Up = party1, or your target when solo), Backspace cancels. Let go to cast; no arrow = you.")
  print(PREFIX .. "A: " .. spellLabel(db.a) .. "   B: " .. spellLabel(db.b))
  print(PREFIX .. "/hpp list · /hpp a N · /hpp b N · /hpp key KEY · /hpp pad · /hpp axis · /hpp clear")
end

SLASH_HEALPADPROBE1 = "/hpp"
SlashCmdList.HEALPADPROBE = function(msg)
  local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "list" then
    scan()
    for i, id in ipairs(helpful) do print(PREFIX .. i .. ". " .. spellLabel(id)) end
    if #helpful == 0 then print(PREFIX .. "no friendly spells found in your spellbook") end
  elseif cmd == "a" or cmd == "b" then
    if InCombatLockdown() then print(PREFIX .. "leave combat first") return end
    scan()
    local n = tonumber(arg)
    local id = n and (helpful[n] or (n > 1000 and n)) or nil
    if not id then print(PREFIX .. "pick a number from /hpp list") return end
    db[cmd] = id
    applySpells()
    log("spell " .. cmd:upper() .. " = " .. spellLabel(id))
  elseif cmd == "key" then
    if InCombatLockdown() then print(PREFIX .. "leave combat first") return end
    if arg == "" then print(PREFIX .. "key is " .. db.key) return end
    db.key = arg:upper()
    applyKeys()
    log("key = " .. db.key)
  elseif cmd == "pad" then
    padReport()
  elseif cmd == "axis" then
    if InCombatLockdown() then print(PREFIX .. "leave combat first") return end
    local now = C_CVar.GetCVar("GamePadStickAxisButtons")
    local ok = pcall(C_CVar.SetCVar, "GamePadStickAxisButtons", now == "1" and "0" or "1")
    log("GamePadStickAxisButtons " .. safe(now) .. " -> " .. safe(C_CVar.GetCVar("GamePadStickAxisButtons")) .. (ok and "" or " (set failed)"))
  elseif cmd == "clear" then
    db.log = {}
    print(PREFIX .. "log cleared")
  else
    help()
  end
end

---------------------------------------------------------------- what happened

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
  "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "CURRENT_SPELL_CAST_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, a1, a2, a3, a4)
  if e == "ADDON_LOADED" and a1 == "HealpadProbe" then
    HealpadProbeDB = HealpadProbeDB or {}
    db = HealpadProbeDB
    db.key = db.key or "BACKQUOTE"
  elseif e == "PLAYER_LOGIN" then
    setUnits()
    applySpells()
    applyKeys()
    padReport()
    log("ready, client " .. safe((GetBuildInfo())) .. ", gamepad " .. safe(C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()))
    help()
  elseif e == "GROUP_ROSTER_UPDATE" or e == "PLAYER_REGEN_ENABLED" then
    setUnits()
  elseif e == "UNIT_SPELLCAST_SENT" and a1 == "player" then
    log("SENT " .. spellLabel(a4) .. " -> " .. safe(a2))
  elseif (e == "UNIT_SPELLCAST_SUCCEEDED" or e == "UNIT_SPELLCAST_FAILED" or e == "UNIT_SPELLCAST_INTERRUPTED") and a1 == "player" then
    log(e:gsub("UNIT_SPELLCAST_", "") .. " " .. spellLabel(a3))
  elseif e == "UI_ERROR_MESSAGE" then
    log("error: " .. safe(a2))
  elseif e == "ADDON_ACTION_BLOCKED" or e == "ADDON_ACTION_FORBIDDEN" then
    log(e .. " " .. safe(a1) .. " " .. safe(a2))
  elseif e == "CURRENT_SPELL_CAST_CHANGED" then
    if SpellIsTargeting() then log("the game wants a ground target (cursor)") end
  end
end)
