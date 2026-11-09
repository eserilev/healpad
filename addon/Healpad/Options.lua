-- The settings: one row per heal key (key, spell, what a tap heals), then
-- distance, size and arrows. /healpad or /hp opens it.
local _, ns = ...

local panel
local rows = {}
local spells = {}

local MODIFIER_ONLY = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  UNKNOWN = true, LMETA = true, RMETA = true }

local function combo(key)
  local mods = ""
  if IsAltKeyDown() then mods = mods .. "ALT-" end
  if IsControlKeyDown() then mods = mods .. "CTRL-" end
  if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
  return mods .. key
end

local function changed()
  ns.applyKeys()
  if panel and panel:IsShown() then ns.refreshOptions() end
end

local capturing
local function stopCapture()
  if capturing then
    capturing:EnableKeyboard(false)
    pcall(capturing.EnableGamePadButton, capturing, false)
    capturing = nil
  end
  ns.refreshOptions()
end

local function setKey(i, key)
  for j, conf in ipairs(ns.db.keys) do
    if j ~= i and conf.key == key then conf.key = nil end
  end
  ns.db.keys[i].key = key
  stopCapture()
  changed()
end

local function startCapture(row)
  if InCombatLockdown() then ns.say("Change keys after combat.") return end
  stopCapture()
  capturing = row.keyButton
  row.keyButton:SetText("Press a key")
  row.keyButton:EnableKeyboard(true)
  pcall(row.keyButton.EnableGamePadButton, row.keyButton, true)
end

local function cycleSpell(i, step)
  if InCombatLockdown() then ns.say("Change spells after combat.") return end
  local list = spells
  local now = ns.spellOn(i)
  local at = 0
  for n, id in ipairs(list) do
    if id == now then at = n end
  end
  at = (at + step) % (#list + 1)
  ns.setSpell(i, list[at])
  changed()
end

local function cycleTap(i)
  if InCombatLockdown() then ns.say("Change this after combat.") return end
  local conf = ns.db.keys[i]
  local at = 1
  for n, t in ipairs(ns.TAPS) do
    if t == conf.tap then at = n end
  end
  conf.tap = ns.TAPS[at % #ns.TAPS + 1]
  changed()
end

local function button(parent, w, text)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  b:SetText(text)
  return b
end

local function makeRow(i)
  local row = CreateFrame("Frame", nil, panel)
  row:SetSize(500, 32)
  row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * 34)
  row.keyButton = button(row, 110, "")
  row.keyButton:SetPoint("LEFT", 0, 0)
  row.keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.keyButton:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      if InCombatLockdown() then return end
      ns.db.keys[i].key = nil
      changed()
    else
      startCapture(row)
    end
  end)
  row.keyButton:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then stopCapture() return end
    if MODIFIER_ONLY[key] then return end
    setKey(i, combo(key))
  end)
  row.keyButton:SetScript("OnGamePadButtonDown", function(_, key) setKey(i, combo(key)) end)
  row.prev = button(row, 24, "<")
  row.prev:SetPoint("LEFT", row.keyButton, "RIGHT", 8, 0)
  row.prev:SetScript("OnClick", function() cycleSpell(i, -1) end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(24, 24)
  row.icon:SetPoint("LEFT", row.prev, "RIGHT", 6, 0)
  row.spell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spell:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.spell:SetWidth(190)
  row.spell:SetJustifyH("LEFT")
  row.next = button(row, 24, ">")
  row.next:SetPoint("LEFT", row.spell, "RIGHT", 4, 0)
  row.next:SetScript("OnClick", function() cycleSpell(i, 1) end)
  row.tap = button(row, 70, "")
  row.tap:SetPoint("LEFT", row.next, "RIGHT", 8, 0)
  row.tap:SetScript("OnClick", function() cycleTap(i) end)
  rows[i] = row
end

local function stepper(label, x, get, set, lo, hi, step)
  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("BOTTOMLEFT", x, 18)
  t:SetText(label)
  local minus = button(panel, 24, "-")
  minus:SetPoint("LEFT", t, "RIGHT", 6, 0)
  local plus = button(panel, 24, "+")
  plus:SetPoint("LEFT", minus, "RIGHT", 2, 0)
  minus:SetScript("OnClick", function() set(math.max(lo, get() - step)) ns.layout() end)
  plus:SetScript("OnClick", function() set(math.min(hi, get() + step)) ns.layout() end)
end

local function build()
  panel = CreateFrame("Frame", "HealpadOptions", UIParent, "BackdropTemplate")
  panel:SetSize(528, 40 + ns.KEYS * 34 + 50)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  panel:SetBackdropColor(0.03, 0.04, 0.05, 0.96)
  panel:SetBackdropBorderColor(0.16, 0.19, 0.25, 1)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:SetScript("OnHide", stopCapture)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("Healpad")
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)
  for i = 1, ns.KEYS do makeRow(i) end
  stepper("Distance", 14, function() return ns.db.distance end, function(v) ns.db.distance = v end, 1, 5, 1)
  stepper("Size", 150, function() return ns.db.scale end, function(v) ns.db.scale = v end, 0.6, 1.6, 0.1)
  local arrows = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  arrows:SetPoint("BOTTOMLEFT", 270, 12)
  arrows:SetScript("OnClick", function(self) ns.db.arrows = self:GetChecked() and true or false ns.layout() end)
  local at = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  at:SetPoint("LEFT", arrows, "RIGHT", 2, 0)
  at:SetText("Arrows")
  panel.arrows = arrows
  table.insert(UISpecialFrames, "HealpadOptions")
end

function ns.refreshOptions()
  if not panel then return end
  for i, row in ipairs(rows) do
    local conf = ns.db.keys[i]
    if capturing ~= row.keyButton then
      row.keyButton:SetText(conf.key and (GetBindingText and GetBindingText(conf.key) or conf.key) or "Set key")
    end
    local id = ns.spellOn(i)
    row.icon:SetTexture(ns.spellIcon(id))
    row.icon:SetShown(id ~= nil)
    row.spell:SetText(id and ns.spellLabel(id) or "-")
    row.tap:SetText(ns.TAP_LABEL[conf.tap] or "You")
  end
  panel.arrows:SetChecked(ns.db.arrows)
end

function ns.openOptions()
  if not panel then build() end
  spells = ns.scanSpells()
  panel:Show()
  ns.refreshOptions()
end

SLASH_HEALPAD1 = "/healpad"
SLASH_HEALPAD2 = "/hp"
SlashCmdList.HEALPAD = function()
  if panel and panel:IsShown() then panel:Hide() else ns.openOptions() end
end

ns.on("PLAYER_LOGIN", function()
  local any = false
  for i = 1, ns.KEYS do
    if ns.db.keys[i].key and ns.spellOn(i) then any = true end
  end
  if not any then ns.say("type /healpad to pick your heals and keys.") end
end)
