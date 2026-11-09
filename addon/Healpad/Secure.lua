-- The secure parts: one controller, the heal keys, and the aim keys.
--
-- Press a heal key: its spell is locked, the controller takes the d-pad and
-- arrow keys, and nothing casts. Release it: the locked spell casts on the
-- aimed person, or with no aim on the key's tap choice. All of it runs in
-- secure snippets, so it works in combat. Addon code only sets things up out
-- of combat and draws the plain diamond frames.
local _, ns = ...

local ctl = CreateFrame("Frame", "HealpadCtl", UIParent, "SecureHandlerBaseTemplate")
ns.ctl = ctl
local keyOwner = CreateFrame("Frame", "HealpadKeys", UIParent)

-- Keys the controller takes while aiming, and the button each one clicks.
ns.AIM_KEYS = {
  { "PADDUP", "HealpadDirUP" }, { "UP", "HealpadDirUP" },
  { "PADDRIGHT", "HealpadDirRIGHT" }, { "RIGHT", "HealpadDirRIGHT" },
  { "PADDDOWN", "HealpadDirDOWN" }, { "DOWN", "HealpadDirDOWN" },
  { "PADDLEFT", "HealpadDirLEFT" }, { "LEFT", "HealpadDirLEFT" },
  { "PADLSTICK", "HealpadDirSELF" }, { "HOME", "HealpadDirSELF" },
  { "PAD2", "HealpadCancel" }, { "BACKSPACE", "HealpadCancel" },
  { "PADRSHOULDER", "HealpadPageNext" }, { "PAGEDOWN", "HealpadPageNext" },
  { "PADLSHOULDER", "HealpadPagePrev" }, { "PAGEUP", "HealpadPagePrev" },
}

-- A heal key the player chose wins over an aim key: "skip-<key>" is set for it.
local binds = {}
for _, k in ipairs(ns.AIM_KEYS) do
  table.insert(binds, ('    if not owner:GetAttribute("skip-%s") then owner:SetBindingClick(true, "%s", "%s") end')
    :format(k[1], k[1], k[2]))
end

ns.HEAL_SNIPPET = [[
  local name = self:GetName()
  local gen = owner:GetAttribute("gen") or 0
  if down then
    local held = owner:GetAttribute("held")
    self:SetAttribute("hp-lock", self:GetAttribute("hp-spell"))
    self:SetAttribute("hp-gen", gen)
    if held and held ~= name then
      return false
    end
    owner:SetAttribute("held", name)
    owner:SetAttribute("sel", nil)
    owner:SetAttribute("page", 1)
    owner:ClearBindings()
]] .. table.concat(binds, "\n") .. [[

    owner:SetAttribute("state", "aim")
    return false
  end
  local lock = self:GetAttribute("hp-lock")
  local mygen = self:GetAttribute("hp-gen")
  self:SetAttribute("hp-lock", nil)
  if owner:GetAttribute("held") == name then
    owner:ClearBindings()
    owner:SetAttribute("held", nil)
    owner:SetAttribute("state", "idle")
  end
  if not lock or mygen ~= gen then
    return false
  end
  local unit
  local sel = owner:GetAttribute("sel")
  if sel then
    unit = owner:GetAttribute("u" .. (owner:GetAttribute("page") or 1) .. "-" .. sel)
  else
    local tap = self:GetAttribute("hp-tap")
    if tap == "last" then
      unit = owner:GetAttribute("last")
    elseif tap == "tank" then
      unit = owner:GetAttribute("tank")
    elseif tap == "focus" then
      unit = "focus"
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
  self:SetAttribute("spell", lock)
  self:SetAttribute("unit", unit)
  owner:SetAttribute("last", unit)
  owner:SetAttribute("castunit", unit)
  owner:SetAttribute("castn", (owner:GetAttribute("castn") or 0) + 1)
]]

ns.DIR_SNIPPET = [[
  local c = self:GetFrameRef("ctl")
  if c:GetAttribute("held") then
    local d = self:GetAttribute("dir")
    if c:GetAttribute("u" .. (c:GetAttribute("page") or 1) .. "-" .. d) then
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
for i = 1, ns.KEYS do
  local b = CreateFrame("Button", "HealpadHeal" .. i, UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("useOnKeyDown", false)
  b:SetAttribute("type", "spell")
  b:SetAttribute("unit", "player")
  SecureHandlerWrapScript(b, "OnClick", ctl, ns.HEAL_SNIPPET)
  ns.heals[i] = b
end

---------------------------------------------------------------- setup, out of combat

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
    if ns.redraw then ns.redraw() end
  end)
end

-- A key that KeyBars binds, for a warning: Healpad's binding wins while set.
local function clash(key)
  local ok, action = pcall(GetBindingAction, key, true)
  return ok and type(action) == "string" and action:match("^CLICK KeyBars") ~= nil
end

local warned = {}
function ns.applyKeys()
  ns.afterCombat("keys", function()
    ClearOverrideBindings(keyOwner)
    for _, k in ipairs(ns.AIM_KEYS) do ctl:SetAttribute("skip-" .. k[1], nil) end
    for i, b in ipairs(ns.heals) do
      local conf = ns.db.keys[i]
      local spell = ns.spellOn(i)
      b:SetAttribute("hp-spell", spell)
      b:SetAttribute("spell", spell)
      b:SetAttribute("hp-tap", conf.tap)
      if conf.key and spell then
        if clash(conf.key) and not warned[conf.key] then
          warned[conf.key] = true
          ns.say(conf.key .. " is also a KeyBars key. Healpad uses it while Healpad is on.")
        end
        SetOverrideBindingClick(keyOwner, true, conf.key, b:GetName(), "LeftButton")
        ctl:SetAttribute("skip-" .. conf.key, true)
      end
    end
  end)
end

ns.on("PLAYER_LOGIN", function()
  ns.applyRoster()
  ns.applyKeys()
end)
ns.on("GROUP_ROSTER_UPDATE", ns.applyRoster)
ns.on("PLAYER_ROLES_ASSIGNED", ns.applyRoster)
ns.on("PLAYER_REGEN_ENABLED", ns.applyRoster)
ns.on("ACTIVE_TALENT_GROUP_CHANGED", ns.applyKeys)
ns.on("PLAYER_SPECIALIZATION_CHANGED", ns.applyKeys)
