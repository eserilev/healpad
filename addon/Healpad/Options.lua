-- The settings: /healpad or /hp. Three tabs.
--   Buttons: what you already bound; switch a heal to Hold to Aim, and pick
--            who a quick tap heals.
--   Aim:     what aims (d-pad or a stick) and what cancels.
--   Frames:  how big the diamond's frames are and how far apart.
-- Works with the pad (d-pad, A, B, LB, RB), the keyboard (arrows, Enter) and
-- the mouse. Settings change out of combat only; the panel closes in combat.
local _, ns = ...

local W, H = 660, 480
local LIST_W, ROW_H = 270, 30
local TABS = { "buttons", "aim", "frames" }
local TAB_LABEL = { buttons = "Buttons", aim = "Aim", frames = "Frames" }
local GOLD, WHITE, GREY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 }
local PAD_COLOR = { A = { 0.4, 0.9, 0.4 }, B = { 1, 0.35, 0.3 }, X = { 0.35, 0.6, 1 }, Y = { 1, 0.85, 0.2 } }

local panel
local ui = {}
local st = { tab = "buttons", zone = "list", li = 1, row = 0, col = 0, top = 1 }
local rows = {} -- the Buttons list: { header = "Hold LT" } or { bind = b }

---------------------------------------------------------------- small parts
-- The game's own pieces: the window frame, its tabs, the red buttons and
-- the checkboxes, so Healpad looks like the rest of the UI.

local function text(parent, font, color)
  local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if color then t:SetTextColor(unpack(color)) end
  return t
end

local function keyText(label)
  local last = (label or ""):match("([^+]+)$")
  local c = PAD_COLOR[last]
  if not c then return label end
  return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, label)
end

-- A red button that can be the chosen one: chosen stays lit with white text.
local function redButton(parent, w, h, label)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(label)
  return b
end
local function setChosen(b, on)
  if on then b:LockHighlight() else b:UnlockHighlight() end
  local fs = b.GetFontString and b:GetFontString()
  if fs then fs:SetTextColor(unpack(on and WHITE or GOLD)) end
  b.chosen = on
end

---------------------------------------------------------------- the data

local function buildRows()
  wipe(rows)
  local last
  for _, b in ipairs(ns.binds or {}) do
    local group = b.kb and ("kb:" .. b.layer) or (b.pad and ns.keyGroup(b.key) or "keys")
    if group ~= last then
      last = group
      local label
      if b.kb then label = "KeyBars · " .. b.layer
      elseif group == "keys" then label = "Keys"
      elseif group == "" then label = "Buttons"
      else label = "Hold " .. group end
      table.insert(rows, { header = label })
    end
    table.insert(rows, { bind = b })
  end
end

-- The li-th bind in list order, headers skipped.
local function bindAt(li)
  local n = 0
  for _, r in ipairs(rows) do
    if r.bind then
      n = n + 1
      if n == li then return r.bind end
    end
  end
end
local function bindCount()
  local n = 0
  for _, r in ipairs(rows) do if r.bind then n = n + 1 end end
  return n
end

local function aimed(b) return ns.aimConf(b) ~= nil end

local function setAim(b, on)
  if not b or not b.heal or InCombatLockdown() then return end
  local t, k = ns.db.aim, b.key
  if b.kb then t, k = ns.db.aimSpell, b.cast end
  if on then
    t[k] = t[k] or { tap = "player" }
  else
    t[k] = nil
  end
  ns.applyKeys(true)
end

-- Cancel can't be a plain pad button that holds to aim.
local function cancelTaken(key) return ns.db.aim[key] ~= nil end

---------------------------------------------------------------- drawing

local refresh

-- The glow around what the pad is on.
local function ring(target)
  local r = ui.ring
  if not target then r:Hide() return end
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
  r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
  r:Show()
end

local function drawTabs()
  local index = 1
  for i, t in ipairs(TABS) do if t == st.tab then index = i end end
  if PanelTemplates_SetTab then PanelTemplates_SetTab(panel, index) end
  ui.buttons:SetShown(st.tab == "buttons")
  ui.aim:SetShown(st.tab == "aim")
  ui.frames:SetShown(st.tab == "frames")
  if ns.preview then ns.preview(st.tab == "frames") end
  panel:ClearAllPoints()
  if st.tab == "frames" then panel:SetPoint("LEFT", UIParent, "LEFT", 40, 0) else panel:SetPoint("CENTER") end
end

local function drawList()
  local visible = #ui.rows
  local at, n = 0, 0
  for i, r in ipairs(rows) do
    if r.bind then
      n = n + 1
      if n == st.li then at = i end
    end
  end
  if at > 0 then
    if at < st.top then st.top = math.max(1, at - 1) end
    if at > st.top + visible - 1 then st.top = at - visible + 1 end
  end
  local current = bindAt(st.li)
  local focus
  for i, f in ipairs(ui.rows) do
    local r = rows[st.top + i - 1]
    f.entry = r
    if not r then
      f:Hide()
    elseif r.header then
      f:Show()
      f.header:SetText(r.header)
      f.header:Show()
      f.line:Hide()
    else
      f:Show()
      f.header:Hide()
      f.line:Show()
      local b = r.bind
      f.key:SetText(keyText(ns.keyLabel(b.key)))
      f.icon:SetTexture(ns.spellIcon(b.spell))
      f.icon:SetDesaturated(not b.heal)
      f.name:SetText(ns.spellName(b.spell))
      f.name:SetTextColor(unpack(b.heal and GOLD or GREY))
      f.check:SetShown(b.heal)
      f.check:SetChecked(aimed(b))
      f.selected:SetShown(b == current)
      if b == current and st.zone == "list" then focus = f.line end
    end
  end
  ui.empty:SetShown(#rows == 0)
  return focus
end

local function drawDetail()
  local b = bindAt(st.li)
  local d = ui.detail
  d:SetShown(b ~= nil)
  if not b then return end
  d.key:SetText(keyText(ns.keyLabel(b.key)) .. (b.kb and ("  |cffaaaaaa" .. b.layer .. "|r") or ""))
  d.icon:SetTexture(ns.spellIcon(b.spell))
  d.name:SetText(ns.spellName(b.spell))
  d.rank:SetText(ns.spellRank(b.spell))
  local on = aimed(b)
  d.modes:SetShown(b.heal)
  setChosen(d.cast, not on)
  setChosen(d.hold, on)
  d.tapBox:SetShown(b.heal and on)
  local tap = on and ns.aimConf(b).tap or "player"
  for i, t in ipairs(ns.TAPS) do setChosen(d.taps[i], tap == t) end
  if st.zone == "detail" then
    if st.row == 0 then return st.col == 0 and d.cast or d.hold end
    return d.taps[st.col + 1]
  end
end

local function drawAim()
  local a = ui.aim
  local focus
  for i, k in ipairs(ns.AIMERS) do
    setChosen(a.aimers[i], ns.db.aimWith == k)
    if st.row == 0 and ns.db.aimWith == k then focus = a.aimers[i] end
  end
  for i, key in ipairs(ns.CANCELS) do
    local b = a.cancels[i]
    b:SetEnabled(not cancelTaken(key))
    setChosen(b, ns.db.cancel == key)
    if st.row == 1 and ns.db.cancel == key then focus = b end
  end
  return focus
end

local function drawFrames()
  local f = ui.frames
  local size, spread = ns.db.scale or 1, ns.db.distance or 3
  f.size.value:SetText(math.floor(size * 100 + 0.5) .. "%")
  f.size.bar:SetValue(size)
  f.spread.value:SetText(tostring(spread))
  f.spread.bar:SetValue(spread)
  return st.row == 0 and f.size or f.spread
end

refresh = function()
  if not panel or not panel:IsShown() then return end
  drawTabs()
  local focus
  if st.tab == "buttons" then
    local listFocus = drawList()
    local detailFocus = drawDetail()
    focus = st.zone == "list" and listFocus or detailFocus
  elseif st.tab == "aim" then
    focus = drawAim()
  else
    focus = drawFrames()
  end
  ring(focus)
end

-- After applyKeys: your bindings may have changed.
function ns.refreshOptions()
  if panel and panel:IsShown() then
    buildRows()
    st.li = math.max(1, math.min(st.li, bindCount()))
    refresh()
  end
end

---------------------------------------------------------------- input

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function nav(btn)
  if InCombatLockdown() or not panel then return end
  if btn == "LB" or btn == "RB" then
    local i = 1
    for n, t in ipairs(TABS) do if t == st.tab then i = n end end
    i = (i + (btn == "RB" and 1 or -1) - 1) % #TABS + 1
    st.tab, st.zone, st.row, st.col = TABS[i], "list", 0, 0
    return refresh()
  end
  if btn == "ESC" or (btn == "B" and (st.tab ~= "buttons" or st.zone == "list")) then
    panel:Hide()
    return
  end

  if st.tab == "aim" then
    if btn == "UP" or btn == "DOWN" then st.row = btn == "UP" and 0 or 1 end
    local d = btn == "RIGHT" and 1 or btn == "LEFT" and -1 or 0
    if d ~= 0 and st.row == 0 then
      local i = 1
      for n, k in ipairs(ns.AIMERS) do if k == ns.db.aimWith then i = n end end
      ns.db.aimWith = ns.AIMERS[clamp(i + d, 1, #ns.AIMERS)]
      ns.applyKeys(true)
    elseif d ~= 0 then
      local free = {}
      for _, key in ipairs(ns.CANCELS) do if not cancelTaken(key) then table.insert(free, key) end end
      local i = 1
      for n, key in ipairs(free) do if key == ns.db.cancel then i = n end end
      if free[1] then
        ns.db.cancel = free[clamp(i + d, 1, #free)]
        ns.applyKeys(true)
      end
    end
    return refresh()
  end

  if st.tab == "frames" then
    if btn == "UP" or btn == "DOWN" then st.row = btn == "UP" and 0 or 1 end
    local d = btn == "RIGHT" and 1 or btn == "LEFT" and -1 or 0
    if d ~= 0 and st.row == 0 then
      ns.db.scale = clamp(math.floor((ns.db.scale + d * 0.1) * 10 + 0.5) / 10, 0.6, 1.6)
    elseif d ~= 0 then
      ns.db.distance = clamp(ns.db.distance + d, 1, 5)
    end
    if d ~= 0 then ns.layout() end
    return refresh()
  end

  local b = bindAt(st.li)
  if st.zone == "list" then
    if btn == "UP" then st.li = math.max(1, st.li - 1) end
    if btn == "DOWN" then st.li = math.max(1, math.min(bindCount(), st.li + 1)) end
    if btn == "A" and b then setAim(b, not aimed(b)) end
    if btn == "RIGHT" and b and b.heal then
      st.zone, st.row, st.col = "detail", 0, aimed(b) and 1 or 0
    end
    return refresh()
  end
  if btn == "B" then
    st.zone = "list"
    return refresh()
  end
  if btn == "UP" then st.row, st.col = 0, aimed(b) and 1 or 0 end
  if btn == "DOWN" and aimed(b) then
    st.row = 1
    for i, t in ipairs(ns.TAPS) do if t == ns.aimConf(b).tap then st.col = i - 1 end end
  end
  if btn == "LEFT" then
    if st.col == 0 then st.zone = "list" else st.col = st.col - 1 end
  end
  if btn == "RIGHT" then st.col = math.min(st.row == 0 and 1 or #ns.TAPS - 1, st.col + 1) end
  if btn == "A" then
    if st.row == 0 then
      setAim(b, st.col == 1)
    elseif aimed(b) then
      ns.aimConf(b).tap = ns.TAPS[st.col + 1]
      ns.applyKeys(true)
    end
  end
  refresh()
end
ns.optionsNav = nav

-- While the panel is open these keys drive it; they go back when it closes.
local NAV_KEYS = {
  PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
  UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT",
  PAD1 = "A", ENTER = "A", SPACE = "A", PAD2 = "B",
  PADLSHOULDER = "LB", PADRSHOULDER = "RB", Q = "LB", E = "RB", ESCAPE = "ESC",
}
for _, btn in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "A", "B", "LB", "RB", "ESC" }) do
  local f = CreateFrame("Button", "HealpadNav" .. btn, UIParent)
  f:SetScript("OnClick", function() nav(btn) end)
end

local function takeKeys()
  if InCombatLockdown() then return end
  for key, btn in pairs(NAV_KEYS) do
    SetOverrideBindingClick(panel, true, key, "HealpadNav" .. btn)
  end
end
local function giveKeys()
  if InCombatLockdown() then return end
  ClearOverrideBindings(panel)
end

---------------------------------------------------------------- building

-- Finds the list position of a row, for a mouse click.
local function liOf(entry)
  local n = 0
  for _, r in ipairs(rows) do
    if r.bind then
      n = n + 1
      if r == entry then return n end
    end
  end
end

local function buildButtonsTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local list = CreateFrame("Frame", nil, t)
  list:SetPoint("TOPLEFT", 8, -8)
  list:SetPoint("BOTTOMLEFT", 8, 8)
  list:SetWidth(LIST_W)
  local divider = t:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.35, 0.3, 0.2, 0.6)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
  divider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
  ui.rows = {}
  for i = 1, math.floor((H - 100) / ROW_H) do
    local f = CreateFrame("Frame", nil, list)
    f:SetSize(LIST_W, ROW_H)
    f:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    f.header = text(f, "GameFontHighlightSmall", { 0.7, 0.7, 0.7 })
    f.header:SetPoint("BOTTOMLEFT", 4, 5)
    local line = CreateFrame("Button", nil, f)
    line:SetAllPoints()
    f.line = line
    local hl = line:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    f.selected = line:CreateTexture(nil, "BACKGROUND")
    f.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    f.selected:SetBlendMode("ADD")
    f.selected:SetVertexColor(1, 0.82, 0, 0.6)
    f.selected:SetAllPoints()
    f.key = text(line, "GameFontHighlightSmall")
    f.key:SetPoint("LEFT", 4, 0)
    f.key:SetWidth(44)
    f.key:SetJustifyH("LEFT")
    f.icon = line:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(22, 22)
    f.icon:SetPoint("LEFT", 50, 0)
    f.name = text(line, "GameFontNormal")
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.name:SetPoint("RIGHT", -30, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.check = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
    f.check:SetSize(24, 24)
    f.check:SetPoint("RIGHT", -2, 0)
    local function pick(flip)
      if InCombatLockdown() or not f.entry or not f.entry.bind then return end
      st.li, st.zone = liOf(f.entry) or st.li, "list"
      if flip then setAim(f.entry.bind, not aimed(f.entry.bind)) end
      refresh()
    end
    line:SetScript("OnClick", function() pick(false) end)
    f.check:SetScript("OnClick", function() pick(true) end)
    ui.rows[i] = f
  end
  ui.empty = text(list, "GameFontDisable")
  ui.empty:SetPoint("CENTER")
  ui.empty:SetText("No heals on your buttons")

  local d = CreateFrame("Frame", nil, t)
  d:SetPoint("TOPLEFT", list, "TOPRIGHT", 22, -6)
  d:SetPoint("BOTTOMRIGHT", -14, 12)
  ui.detail = d
  d.icon = d:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(40, 40)
  d.icon:SetPoint("TOPLEFT", 0, 0)
  d.name = text(d, "GameFontNormalLarge")
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
  d.rank = text(d, "GameFontHighlightSmall")
  d.rank:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
  d.key = text(d, "GameFontHighlightLarge")
  d.key:SetPoint("TOPRIGHT", 0, -10)

  d.modes = CreateFrame("Frame", nil, d)
  d.modes:SetPoint("TOPLEFT", 0, -64)
  d.modes:SetPoint("RIGHT")
  d.modes:SetHeight(36)
  local half = (W - LIST_W - 56) / 2 - 4
  d.cast = redButton(d.modes, half, 34, "Cast")
  d.cast:SetPoint("TOPLEFT")
  d.hold = redButton(d.modes, half, 34, "Hold to Aim")
  d.hold:SetPoint("TOPLEFT", d.cast, "TOPRIGHT", 8, 0)
  d.cast:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 0, 0 ns.optionsNav("A") end)
  d.hold:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 0, 1 ns.optionsNav("A") end)

  d.tapBox = CreateFrame("Frame", nil, d)
  d.tapBox:SetPoint("TOPLEFT", d.modes, "BOTTOMLEFT", 0, -24)
  d.tapBox:SetPoint("RIGHT")
  d.tapBox:SetHeight(64)
  local tapLabel = text(d.tapBox, "GameFontNormal")
  tapLabel:SetText("Tap to heal")
  tapLabel:SetPoint("TOPLEFT")
  d.taps = {}
  local tw = (W - LIST_W - 56 - 18) / 4
  for i, tap in ipairs(ns.TAPS) do
    local b = redButton(d.tapBox, tw, 28, ns.TAP_LABEL[tap])
    b:SetPoint("TOPLEFT", (i - 1) * (tw + 6), -20)
    b:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 1, i - 1 ns.optionsNav("A") end)
    d.taps[i] = b
  end
  return t
end

local function buildAimTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local h1 = text(t, "GameFontNormalLarge")
  h1:SetText("Aim with")
  h1:SetPoint("TOPLEFT", 20, -20)
  t.aimers = {}
  local w = (W - 40 - 24) / 3
  for i, k in ipairs(ns.AIMERS) do
    local b = redButton(t, w, 44, ns.AIMER_LABEL[k])
    b:SetPoint("TOPLEFT", 20 + (i - 1) * (w + 12), -48)
    b:SetScript("OnClick", function()
      if InCombatLockdown() then return end
      st.row = 0
      ns.db.aimWith = k
      ns.applyKeys(true)
      refresh()
    end)
    t.aimers[i] = b
  end
  local h2 = text(t, "GameFontNormalLarge")
  h2:SetText("Cancel with")
  h2:SetPoint("TOPLEFT", 20, -130)
  t.cancels = {}
  local NAMES = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
  for i, key in ipairs(ns.CANCELS) do
    local b = redButton(t, 60, 34, keyText(NAMES[key]))
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 68, -158)
    b:SetScript("OnClick", function()
      if InCombatLockdown() or cancelTaken(key) then return end
      st.row = 1
      ns.db.cancel = key
      ns.applyKeys(true)
      refresh()
    end)
    t.cancels[i] = b
  end
  return t
end

local function slider(parent, label, y, row, lo, hi)
  local s = CreateFrame("Frame", nil, parent)
  s:SetPoint("TOPLEFT", 20, y)
  s:SetPoint("RIGHT", -20, 0)
  s:SetHeight(64)
  local name = text(s, "GameFontNormalLarge")
  name:SetText(label)
  name:SetPoint("TOPLEFT")
  s.value = text(s, "GameFontHighlightLarge")
  s.value:SetPoint("TOPRIGHT")
  local minus = redButton(s, 32, 26, "<")
  minus:SetPoint("BOTTOMLEFT", 0, 4)
  local plus = redButton(s, 32, 26, ">")
  plus:SetPoint("BOTTOMRIGHT", 0, 4)
  local frame = CreateFrame("Frame", nil, s, "BackdropTemplate")
  frame:SetPoint("LEFT", minus, "RIGHT", 8, 0)
  frame:SetPoint("RIGHT", plus, "LEFT", -8, 0)
  frame:SetHeight(20)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileEdge = true,
    tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s.bar = CreateFrame("StatusBar", nil, frame)
  s.bar:SetPoint("TOPLEFT", 4, -6)
  s.bar:SetPoint("BOTTOMRIGHT", -4, 6)
  s.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  s.bar:SetStatusBarColor(1, 0.82, 0)
  s.bar:SetMinMaxValues(lo, hi)
  minus:SetScript("OnClick", function() st.row = row ns.optionsNav("LEFT") end)
  plus:SetScript("OnClick", function() st.row = row ns.optionsNav("RIGHT") end)
  return s
end

local function buildFramesTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  t.size = slider(t, "Size", -20, 0, 0.6, 1.6)
  t.spread = slider(t, "Spread", -110, 1, 1, 5)
  return t
end

local function build()
  panel = CreateFrame("Frame", "HealpadOptions", UIParent, "ButtonFrameTemplate")
  panel:SetSize(W, H)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:Hide()
  if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(panel) end
  if panel.SetTitle then panel:SetTitle("Healpad") end
  if panel.SetPortraitToUnit then panel:SetPortraitToUnit("player") end
  local inset = type(panel.Inset) == "table" and panel.Inset or nil
  local body = inset or panel
  if inset then
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -6, 6)
  end

  -- tabs hang off the bottom edge, like the character window's
  ui.tabs = {}
  for i, t in ipairs(TABS) do
    local tab = CreateFrame("Button", "HealpadOptionsTab" .. i, panel, "PanelTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(TAB_LABEL[t])
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
    if i == 1 then tab:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 12, 2) end
    tab:SetScript("OnClick", function()
      if InCombatLockdown() then return end
      st.tab, st.zone, st.row, st.col = t, "list", 0, 0
      if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      refresh()
    end)
    ui.tabs[i] = tab
  end
  if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(panel, #TABS) end

  ui.buttons = buildButtonsTab(body)
  ui.aim = buildAimTab(body)
  ui.frames = buildFramesTab(body)

  ui.ring = ns.outline(panel, panel, 0, 2)
  ui.ring:SetColor(0.45, 0.8, 1, 1)
  ui.ring:SetFrameLevel((panel:GetFrameLevel() or 0) + 30)

  panel:SetScript("OnShow", takeKeys)
  panel:SetScript("OnHide", function()
    giveKeys()
    if ns.preview then ns.preview(false) end
  end)
  table.insert(UISpecialFrames, "HealpadOptions")
end

function ns.openOptions()
  if InCombatLockdown() then ns.say("after combat.") return end
  if not panel then build() end
  ns.binds = ns.readBinds()
  buildRows()
  st.li = math.max(1, math.min(st.li, bindCount()))
  panel:Show()
  refresh()
end
function ns.optionsPanel() return panel end
-- For /hp test: the parts and the focus.
function ns.optionsDebug() return { panel = panel, ui = ui, st = st, rows = rows } end

SLASH_HEALPAD1 = "/healpad"
SLASH_HEALPAD2 = "/hp"
SlashCmdList.HEALPAD = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "test" then
    if ns.selfTest then ns.selfTest() end
    return
  end
  if cmd == "shots" then
    if ns.showcase then ns.showcase() end
    return
  end
  if panel and panel:IsShown() then panel:Hide() else ns.openOptions() end
end

ns.on("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then panel:Hide() end
end)

ns.on("PLAYER_LOGIN", function()
  if next(ns.db.aim) == nil then ns.say("type /hp to choose which heals hold to aim.") end
end)
