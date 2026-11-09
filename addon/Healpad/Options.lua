-- The settings: /healpad or /hp. Three tabs.
--   Buttons: what you already bound; switch a heal to Hold to Aim, and pick
--            who a quick tap heals.
--   Aim:     what aims (d-pad or a stick) and what cancels.
--   Frames:  how big the diamond's frames are and how far apart.
-- Works with the pad (d-pad, A, B, LB, RB), the keyboard (arrows, Enter) and
-- the mouse. Settings change out of combat only; the panel closes in combat.
local _, ns = ...

local C = {
  bg = { 0.027, 0.035, 0.047, 0.97 }, head = { 0.05, 0.067, 0.09, 1 }, line = { 0.12, 0.145, 0.19, 1 },
  card = { 0.06, 0.08, 0.105, 1 }, cardOn = { 0.085, 0.105, 0.14, 1 }, edge = { 0.16, 0.19, 0.25, 1 },
  gold = { 0.95, 0.76, 0.31, 1 }, goldBg = { 0.23, 0.18, 0.07, 1 }, cyan = { 0.5, 0.89, 0.89, 1 },
  sel = { 0.17, 0.23, 0.3, 1 }, selEdge = { 0.3, 0.4, 0.53, 1 }, text = { 0.91, 0.89, 0.85, 1 },
  dim = { 0.6, 0.64, 0.68, 1 }, faint = { 0.44, 0.47, 0.51, 1 }, red = { 1, 0.54, 0.5, 1 }, redBg = { 0.23, 0.1, 0.09, 1 },
}
local PAD_COLOR = { A = { 0.56, 0.88, 0.64, 1 }, B = { 1, 0.54, 0.5, 1 }, X = { 0.61, 0.76, 1, 1 }, Y = { 1, 0.88, 0.54, 1 } }
local function padColor(label)
  local last = (label or ""):match("([^+]+)$")
  return PAD_COLOR[last] or C.cyan
end

local W, H = 820, 520
local LIST_W, ROW_H = 330, 36
local TABS = { "buttons", "aim", "frames" }
local TAB_LABEL = { buttons = "Buttons", aim = "Aim", frames = "Frames" }

local panel
local ui = {}
local st = { tab = "buttons", zone = "list", li = 1, row = 0, col = 0, top = 1 }
local rows = {} -- the Buttons list: { header = "HOLD LT" } or { bind = b }

---------------------------------------------------------------- small parts

local SOLID = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function box(parent, w, h)
  local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetBackdrop(SOLID)
  return f
end
local function paint(f, bg, edge)
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(edge or bg))
end
local function text(parent, font, color)
  local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if color then t:SetTextColor(unpack(color)) end
  return t
end
local function caps(parent, label)
  local t = text(parent, "GameFontNormalSmall", C.faint)
  t:SetText(label)
  return t
end

-- A choice button: a box with a centered label.
local function choice(parent, w, h, font)
  local b = box(parent, w, h)
  b.label = text(b, font or "GameFontHighlight")
  b.label:SetPoint("CENTER")
  return b
end
local function paintChoice(b, on, onBg, onEdge, onText)
  paint(b, on and (onBg or C.sel) or C.card, on and (onEdge or C.selEdge) or C.line)
  b.label:SetTextColor(unpack(on and (onText or C.text) or C.dim))
end

-- The pill with a button's name in its color.
local function pill(parent)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  p:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  p.label = text(p, "GameFontNormalSmall")
  p.label:SetPoint("CENTER")
  return p
end
local function setPill(p, label, h)
  p.label:SetText(label)
  local c = padColor(label)
  p.label:SetTextColor(unpack(c))
  p:SetBackdropBorderColor(unpack(c))
  p:SetSize(math.max(h, (p.label:GetStringWidth() or 0) + 14), h)
end

---------------------------------------------------------------- the data

local function buildRows()
  wipe(rows)
  local last
  for _, b in ipairs(ns.binds or {}) do
    local group = b.pad and ns.keyGroup(b.key) or "keys"
    if group ~= last then
      last = group
      local label = group == "keys" and "KEYS" or (group == "" and "BUTTONS" or ("HOLD " .. group:upper()))
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

local function aimed(b) return b ~= nil and ns.db.aim[b.key] ~= nil end

local function setAim(b, on)
  if not b or not b.heal or InCombatLockdown() then return end
  if on then
    ns.db.aim[b.key] = ns.db.aim[b.key] or { tap = "player" }
  else
    ns.db.aim[b.key] = nil
  end
  ns.applyKeys(true)
end

-- Cancel can't be a plain pad button that holds to aim.
local function cancelTaken(key) return ns.db.aim[key] ~= nil end

---------------------------------------------------------------- drawing

local refresh

local function ring(target)
  local r = ui.ring
  if not target then r:Hide() return end
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
  r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
  r:Show()
end

local function drawTabs()
  for _, t in ipairs(TABS) do
    paintChoice(ui.tab[t], st.tab == t, C.sel, C.sel, C.text)
  end
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
      f.card:Hide()
    else
      f:Show()
      f.header:Hide()
      f.card:Show()
      local b = r.bind
      local on = aimed(b)
      setPill(f.pill, ns.keyLabel(b.key), 24)
      f.icon:SetTexture(ns.spellIcon(b.spell))
      f.name:SetText(ns.spellName(b.spell))
      f.card:SetAlpha(b.heal and 1 or 0.45)
      paint(f.card, b == current and C.cardOn or C.card, on and C.goldBg or C.line)
      f.switch:SetShown(b.heal)
      f.switch:SetBackdropColor(unpack(on and { 0.72, 0.56, 0.18, 1 } or { 0.16, 0.2, 0.26, 1 }))
      f.knob:ClearAllPoints()
      f.knob:SetPoint("LEFT", f.switch, "LEFT", on and 18 or 2, 0)
      if b == current and st.zone == "list" then focus = f.card end
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
  setPill(d.pill, ns.keyLabel(b.key), 44)
  d.icon:SetTexture(ns.spellIcon(b.spell))
  d.name:SetText(ns.spellName(b.spell))
  d.rank:SetText(ns.spellRank(b.spell))
  local on = aimed(b)
  d.modes:SetShown(b.heal)
  paintChoice(d.cast, not on, C.sel, C.selEdge, C.text)
  paintChoice(d.hold, on, C.goldBg, C.gold, C.gold)
  d.tapBox:SetShown(b.heal and on)
  local tap = on and ns.db.aim[b.key].tap or "player"
  for i, t in ipairs(ns.TAPS) do paintChoice(d.taps[i], tap == t) end
  if st.zone == "detail" then
    if st.row == 0 then return st.col == 0 and d.cast or d.hold end
    return d.taps[st.col + 1]
  end
end

local function drawAim()
  local a = ui.aim
  for i, k in ipairs(ns.AIMERS) do
    paintChoice(a.aimers[i], ns.db.aimWith == k, C.goldBg, C.gold, C.gold)
  end
  for i, key in ipairs(ns.CANCELS) do
    local b = a.cancels[i]
    local taken = cancelTaken(key)
    local on = ns.db.cancel == key
    paint(b, on and C.redBg or C.card, on and C.red or C.line)
    b.label:SetTextColor(unpack(taken and C.faint or padColor(b.label:GetText())))
    b:SetAlpha(taken and 0.35 or 1)
  end
  if st.row == 0 then
    for i, k in ipairs(ns.AIMERS) do if ns.db.aimWith == k then return a.aimers[i] end end
  end
  for i, key in ipairs(ns.CANCELS) do if ns.db.cancel == key then return a.cancels[i] end end
end

local function drawFrames()
  local f = ui.frames
  local size, spread = ns.db.scale or 1, ns.db.distance or 3
  f.size.value:SetText(math.floor(size * 100 + 0.5) .. "%")
  f.size.fill:SetWidth(math.max(1, (f.size.track:GetWidth() or 0) * (size - 0.6)))
  f.spread.value:SetText(tostring(spread))
  f.spread.fill:SetWidth(math.max(1, (f.spread.track:GetWidth() or 0) * (spread - 1) / 4))
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
  if btn == "B" and (st.tab ~= "buttons" or st.zone == "list") then
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
    for i, t in ipairs(ns.TAPS) do if t == ns.db.aim[b.key].tap then st.col = i - 1 end end
  end
  if btn == "LEFT" then
    if st.col == 0 then st.zone = "list" else st.col = st.col - 1 end
  end
  if btn == "RIGHT" then st.col = math.min(st.row == 0 and 1 or #ns.TAPS - 1, st.col + 1) end
  if btn == "A" then
    if st.row == 0 then
      setAim(b, st.col == 1)
    elseif aimed(b) then
      ns.db.aim[b.key].tap = ns.TAPS[st.col + 1]
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
  PADLSHOULDER = "LB", PADRSHOULDER = "RB", Q = "LB", E = "RB",
}
for _, btn in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "A", "B", "LB", "RB" }) do
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
  local list = CreateFrame("Frame", nil, t, "BackdropTemplate")
  list:SetPoint("TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMLEFT", 0, 0)
  list:SetWidth(LIST_W)
  list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  list:SetBackdropColor(0.04, 0.05, 0.07, 1)
  ui.rows = {}
  for i = 1, math.floor((H - 76) / (ROW_H + 4)) do
    local f = CreateFrame("Frame", nil, list)
    f:SetSize(LIST_W - 24, ROW_H)
    f:SetPoint("TOPLEFT", 12, -10 - (i - 1) * (ROW_H + 4))
    f.header = caps(f, "")
    f.header:SetPoint("BOTTOMLEFT", 4, 6)
    local card = box(f, LIST_W - 24, ROW_H)
    card:SetPoint("TOPLEFT")
    f.card = card
    f.pill = pill(card)
    f.pill:SetPoint("LEFT", 8, 0)
    f.icon = card:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("LEFT", 72, 0)
    f.name = text(card)
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.name:SetPoint("RIGHT", -52, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.switch = CreateFrame("Frame", nil, card, "BackdropTemplate")
    f.switch:SetSize(34, 18)
    f.switch:SetPoint("RIGHT", -10, 0)
    f.switch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f.knob = f.switch:CreateTexture(nil, "OVERLAY")
    f.knob:SetSize(14, 14)
    f.knob:SetColorTexture(unpack(C.text))
    card:SetScript("OnClick", function()
      if InCombatLockdown() or not f.entry or not f.entry.bind then return end
      local li = liOf(f.entry)
      -- a click on the focused heal flips it; elsewhere it just moves there
      if st.zone == "list" and li == st.li and f.entry.bind.heal then
        setAim(f.entry.bind, not aimed(f.entry.bind))
      end
      st.li, st.zone = li or st.li, "list"
      refresh()
    end)
    ui.rows[i] = f
  end
  ui.empty = text(list, "GameFontDisable")
  ui.empty:SetPoint("CENTER")
  ui.empty:SetText("No heals on your buttons")

  local d = CreateFrame("Frame", nil, t)
  d:SetPoint("TOPLEFT", list, "TOPRIGHT", 26, -22)
  d:SetPoint("BOTTOMRIGHT", -26, 20)
  ui.detail = d
  d.pill = pill(d)
  d.pill:SetPoint("TOPLEFT", 0, 0)
  d.icon = d:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(44, 44)
  d.icon:SetPoint("LEFT", d.pill, "RIGHT", 14, 0)
  d.name = text(d, "GameFontHighlightLarge")
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 12, -4)
  d.rank = text(d, "GameFontHighlightSmall", C.dim)
  d.rank:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -5)

  d.modes = CreateFrame("Frame", nil, d)
  d.modes:SetPoint("TOPLEFT", 0, -74)
  d.modes:SetPoint("RIGHT")
  d.modes:SetHeight(56)
  local half = (W - LIST_W - 52 - 8) / 2
  d.cast = choice(d.modes, half, 56, "GameFontHighlightLarge")
  d.cast:SetPoint("TOPLEFT")
  d.cast.label:SetText("Cast")
  d.hold = choice(d.modes, half, 56, "GameFontHighlightLarge")
  d.hold:SetPoint("TOPLEFT", d.cast, "TOPRIGHT", 8, 0)
  d.hold.label:SetText("Hold to Aim")
  d.cast:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 0, 0 nav("A") end)
  d.hold:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 0, 1 nav("A") end)

  d.tapBox = CreateFrame("Frame", nil, d)
  d.tapBox:SetPoint("TOPLEFT", d.modes, "BOTTOMLEFT", 0, -26)
  d.tapBox:SetPoint("RIGHT")
  d.tapBox:SetHeight(70)
  caps(d.tapBox, "TAP TO HEAL"):SetPoint("TOPLEFT")
  d.taps = {}
  for i, tap in ipairs(ns.TAPS) do
    local b = choice(d.tapBox, 86, 38)
    b:SetPoint("TOPLEFT", (i - 1) * 92, -20)
    b.label:SetText(ns.TAP_LABEL[tap])
    b:SetScript("OnClick", function() st.zone, st.row, st.col = "detail", 1, i - 1 nav("A") end)
    d.taps[i] = b
  end
  return t
end

local function buildAimTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  caps(t, "AIM WITH"):SetPoint("TOPLEFT", 26, -24)
  t.aimers = {}
  local w = (W - 52 - 24) / 3
  for i, k in ipairs(ns.AIMERS) do
    local b = choice(t, w, 150, "GameFontHighlightLarge")
    b:SetPoint("TOPLEFT", 26 + (i - 1) * (w + 12), -44)
    b.label:SetText(ns.AIMER_LABEL[k])
    b:SetScript("OnClick", function()
      if InCombatLockdown() then return end
      st.row = 0
      ns.db.aimWith = k
      ns.applyKeys(true)
      refresh()
    end)
    t.aimers[i] = b
  end
  caps(t, "CANCEL WITH"):SetPoint("TOPLEFT", 26, -224)
  t.cancels = {}
  local NAMES = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
  for i, key in ipairs(ns.CANCELS) do
    local b = choice(t, 54, 44, "GameFontNormalLarge")
    b:SetPoint("TOPLEFT", 26 + (i - 1) * 62, -244)
    b.label:SetText(NAMES[key])
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

local function slider(parent, label, y, row)
  local s = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  s:SetPoint("TOPLEFT", 26, y)
  s:SetPoint("RIGHT", -26, 0)
  s:SetHeight(84)
  s:SetBackdrop(SOLID)
  paint(s, C.card, C.line)
  caps(s, label):SetPoint("TOPLEFT", 14, -14)
  s.value = text(s, "GameFontHighlightLarge")
  s.value:SetPoint("TOPRIGHT", -14, -12)
  local minus = choice(s, 34, 30)
  minus:SetPoint("BOTTOMLEFT", 14, 12)
  minus.label:SetText("<")
  paintChoice(minus, false)
  local plus = choice(s, 34, 30)
  plus:SetPoint("BOTTOMRIGHT", -14, 12)
  plus.label:SetText(">")
  paintChoice(plus, false)
  s.track = s:CreateTexture(nil, "ARTWORK")
  s.track:SetHeight(8)
  s.track:SetPoint("LEFT", minus, "RIGHT", 12, 0)
  s.track:SetPoint("RIGHT", plus, "LEFT", -12, 0)
  s.track:SetColorTexture(0.11, 0.14, 0.19, 1)
  s.fill = s:CreateTexture(nil, "OVERLAY")
  s.fill:SetHeight(8)
  s.fill:SetPoint("LEFT", s.track, "LEFT")
  s.fill:SetColorTexture(unpack(C.cyan))
  minus:SetScript("OnClick", function() st.row = row nav("LEFT") end)
  plus:SetScript("OnClick", function() st.row = row nav("RIGHT") end)
  return s
end

local function buildFramesTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  t.size = slider(t, "SIZE", -24, 0)
  t.spread = slider(t, "SPREAD", -122, 1)
  return t
end

local function build()
  panel = CreateFrame("Frame", "HealpadOptions", UIParent, "BackdropTemplate")
  panel:SetSize(W, H)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetBackdrop(SOLID)
  paint(panel, C.bg, C.edge)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:Hide()

  local head = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(56)
  head:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  head:SetBackdropColor(unpack(C.head))
  local title = text(head, "GameFontNormalLarge", C.cyan)
  title:SetText("Healpad")
  title:SetPoint("LEFT", 20, 0)
  ui.tab = {}
  local x = 120
  for _, t in ipairs(TABS) do
    local b = choice(head, 92, 32)
    b:SetPoint("LEFT", x, 0)
    b.label:SetText(TAB_LABEL[t])
    b:SetScript("OnClick", function()
      if InCombatLockdown() then return end
      st.tab, st.zone, st.row, st.col = t, "list", 0, 0
      refresh()
    end)
    ui.tab[t] = b
    x = x + 96
  end
  local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
  close:SetPoint("RIGHT", -6, 0)

  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", 1, -57)
  body:SetPoint("BOTTOMRIGHT", -1, 1)
  ui.buttons = buildButtonsTab(body)
  ui.aim = buildAimTab(body)
  ui.frames = buildFramesTab(body)

  ui.ring = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  ui.ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  ui.ring:SetBackdropBorderColor(unpack(C.cyan))
  ui.ring:SetFrameLevel((panel:GetFrameLevel() or 0) + 20)

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

SLASH_HEALPAD1 = "/healpad"
SLASH_HEALPAD2 = "/hp"
SlashCmdList.HEALPAD = function()
  if panel and panel:IsShown() then panel:Hide() else ns.openOptions() end
end

ns.on("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then panel:Hide() end
end)

ns.on("PLAYER_LOGIN", function()
  if next(ns.db.aim) == nil then ns.say("type /hp to choose which heals hold to aim.") end
end)
