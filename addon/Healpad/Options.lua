-- The settings: /healpad or /hp. Three tabs.
--   Buttons: what you already bound; switch a heal to Hold to Aim, and pick
--            who a quick tap heals.
--   Aim:     what aims (d-pad or a stick) and what cancels.
--   Frames:  how big the diamond's frames are, how far apart, and its look.
-- Works with the pad (d-pad, A, B, LB, RB), the keyboard (arrows, Enter) and
-- the mouse. Settings change out of combat only; the panel closes in combat.
local _, ns = ...

local W, H = 680, 460
local LIST_W, ROW_H = 290, 32
local PAD = 16 -- space inside the window's inset
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
  if color then
    t:SetTextColor(unpack(color))
  end
  return t
end

local function keyText(label)
  local last = (label or ""):match("([^+]+)$")
  local c = PAD_COLOR[last]
  if not c then
    return label
  end
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
  -- the chosen one is edged in gold
  if on and not b.chosenEdge then
    b.chosenEdge = ns.outline(b, b, 1, 2)
    b.chosenEdge:SetColor(1, 0.82, 0, 1)
  end
  if b.chosenEdge then
    b.chosenEdge:SetShown(on)
  end
  if on then
    b:LockHighlight()
  else
    b:UnlockHighlight()
  end
  local fs = b.GetFontString and b:GetFontString()
  if fs then
    fs:SetTextColor(unpack(on and WHITE or GOLD))
  end
  b.chosen = on
end

---------------------------------------------------------------- the data

local function buildRows()
  wipe(rows)
  local last
  for _, b in ipairs(ns.binds or {}) do
    local group = b.kb and ("kb:" .. b.layer)
      or (b.gp and ("gp:" .. b.group))
      or (b.pad and ns.keyGroup(b.key) or "keys")
    if group ~= last then
      last = group
      local label
      if b.kb then
        label = "KeyBars · " .. b.layer
      elseif b.gp then
        label = b.group == "" and "Buttons" or ("Hold " .. b.group)
      elseif group == "keys" then
        label = "Keys"
      elseif group == "" then
        label = "Buttons"
      else
        label = "Hold " .. group
      end
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
      if n == li then
        return r.bind
      end
    end
  end
end
local function bindCount()
  local n = 0
  for _, r in ipairs(rows) do
    if r.bind then
      n = n + 1
    end
  end
  return n
end

local function aimed(b)
  return ns.aimConf(b) ~= nil
end

local function setAim(b, on)
  if not b or not b.heal or InCombatLockdown() then
    return
  end
  local t, k = ns.db.aim, b.key
  if b.kb then
    t, k = ns.db.aimSpell, b.cast
  elseif b.gp then
    t, k = ns.db.aimPad, b.spell
  end
  if on then
    t[k] = t[k] or { tap = "player" }
  else
    t[k] = nil
  end
  ns.applyKeys(true)
end

-- Cancel can't be a plain pad button that holds to aim.
local function cancelTaken(key)
  return ns.db.aim[key] ~= nil
end

---------------------------------------------------------------- drawing

local refresh

-- The outline around what the pad is on: inside a list row, just outside a
-- button.
local function ring(target)
  local r = ui.ring
  if not target then
    r:Hide()
    return
  end
  local pad = target.ringInside and -1 or 3
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
  r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
  r:Show()
end

local function drawTabs()
  local index = 1
  for i, t in ipairs(TABS) do
    if t == st.tab then
      index = i
    end
  end
  if PanelTemplates_SetTab then
    PanelTemplates_SetTab(panel, index)
  end
  ui.buttons:SetShown(st.tab == "buttons")
  ui.aim:SetShown(st.tab == "aim")
  ui.frames:SetShown(st.tab == "frames")
  -- The preview puts the first Hold to Aim button's tap target in the middle.
  ns.previewTap = nil
  for _, b in ipairs(ns.binds or {}) do
    local conf = ns.aimConf(b)
    if conf and not ns.previewTap then
      ns.previewTap = conf.tap
    end
  end
  if ns.preview then
    ns.preview(st.tab == "frames")
  end
  panel:ClearAllPoints()
  -- On Frames the window gets narrow and steps aside so the diamond shows.
  if st.tab == "frames" then
    panel:SetWidth(400)
    panel:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
  else
    panel:SetWidth(W)
    panel:SetPoint("CENTER")
  end
end

local function drawList()
  local visible = #ui.rows
  local at, n = 0, 0
  for i, r in ipairs(rows) do
    if r.bind then
      n = n + 1
      if n == st.li then
        at = i
      end
    end
  end
  if at > 0 then
    if at < st.top then
      st.top = math.max(1, at - 1)
    end
    if at > st.top + visible - 1 then
      st.top = at - visible + 1
    end
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
      f.key:SetText(keyText(ns.bindLabel(b)))
      f.icon:SetTexture(ns.spellIcon(b.spell))
      f.icon:SetDesaturated(not b.heal)
      f.name:SetText(ns.spellName(b.spell))
      f.name:SetTextColor(unpack(b.heal and GOLD or GREY))
      f.check:SetShown(b.heal)
      f.check:SetChecked(aimed(b))
      f.selected:SetShown(b == current)
      if b == current and st.zone == "list" then
        focus = f.line
      end
    end
  end
  ui.empty:SetShown(#rows == 0)
  return focus
end

local function drawDetail()
  local b = bindAt(st.li)
  local d = ui.detail
  d:SetShown(b ~= nil)
  if not b then
    return
  end
  d.key:SetText(keyText(ns.bindLabel(b)) .. (b.kb and ("  |cff9a9a9a·  KeyBars " .. b.layer .. "|r") or ""))
  d.icon:SetTexture(ns.spellIcon(b.spell))
  d.name:SetText(ns.spellName(b.spell))
  d.rank:SetText(ns.spellRank(b.spell))
  local on = aimed(b)
  d.modes:SetShown(b.heal)
  setChosen(d.cast, not on)
  setChosen(d.hold, on)
  d.tapBox:SetShown(b.heal and on)
  local tap = on and ns.aimConf(b).tap or "player"
  for i, t in ipairs(ns.TAPS) do
    setChosen(d.taps[i], tap == t)
  end
  if st.zone == "detail" then
    if st.row == 0 then
      return st.col == 0 and d.cast or d.hold
    end
    return d.taps[st.col + 1]
  end
end

local function drawAim()
  local a = ui.aim
  local focus
  for i, k in ipairs(ns.AIMERS) do
    setChosen(a.aimers[i], ns.db.aimWith == k)
    if st.row == 0 and ns.db.aimWith == k then
      focus = a.aimers[i]
    end
  end
  for i, key in ipairs(ns.CANCELS) do
    local b = a.cancels[i]
    b:SetEnabled(not cancelTaken(key))
    setChosen(b, ns.db.cancel == key)
    if st.row == 1 and ns.db.cancel == key then
      focus = b
    end
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
  setChosen(f.move, st.moving)
  local lookFocus
  for i, name in ipairs(ns.LOOKS) do
    local on = ns.db.look == name
    setChosen(f.looks[i], on)
    f.looks[i].gold:SetShown(on)
    if on then
      lookFocus = f.looks[i]
    end
  end
  if st.row == 3 then
    return lookFocus
  end
  if st.row == 2 then
    return st.col == 0 and f.move or f.reset
  end
  return st.row == 0 and f.size or f.spread
end

refresh = function()
  if not panel or not panel:IsShown() then
    return
  end
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
  ring((st.keys or st.moving) and focus or nil)
  if ns.showMoving then
    ns.showMoving(st.moving == true and st.tab == "frames")
  end
  if ui.ring and st.moving then
    ui.ring:SetColor(1, 0.82, 0, 1)
  elseif ui.ring then
    ui.ring:SetColor(0.45, 0.8, 1, 1)
  end
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

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

-- fromKeys: a pad button or key, not the mouse. The focus line shows only
-- while you drive with keys or the pad.
local function nav(btn, fromKeys)
  if InCombatLockdown() or not panel then
    return
  end
  st.keys = fromKeys == true
  if btn == "LB" or btn == "RB" then
    local i = 1
    for n, t in ipairs(TABS) do
      if t == st.tab then
        i = n
      end
    end
    i = (i + (btn == "RB" and 1 or -1) - 1) % #TABS + 1
    st.tab, st.zone, st.row, st.col = TABS[i], "list", 0, 0
    return refresh()
  end
  if btn == "ESC" or (btn == "B" and (st.tab ~= "buttons" or st.zone == "list")) then
    panel:Hide()
    return
  end

  if st.tab == "aim" then
    if btn == "UP" or btn == "DOWN" then
      st.row = btn == "UP" and 0 or 1
    end
    local d = btn == "RIGHT" and 1 or btn == "LEFT" and -1 or 0
    if d ~= 0 and st.row == 0 then
      local i = 1
      for n, k in ipairs(ns.AIMERS) do
        if k == ns.db.aimWith then
          i = n
        end
      end
      ns.db.aimWith = ns.AIMERS[clamp(i + d, 1, #ns.AIMERS)]
      ns.applyKeys(true)
    elseif d ~= 0 then
      local free = {}
      for _, key in ipairs(ns.CANCELS) do
        if not cancelTaken(key) then
          table.insert(free, key)
        end
      end
      local i = 1
      for n, key in ipairs(free) do
        if key == ns.db.cancel then
          i = n
        end
      end
      if free[1] then
        ns.db.cancel = free[clamp(i + d, 1, #free)]
        ns.applyKeys(true)
      end
    end
    return refresh()
  end

  if st.tab == "frames" then
    -- Moving: the d-pad or arrows nudge the diamond; A or B is done.
    if st.moving then
      local step = 20
      if btn == "UP" then
        ns.db.y = ns.db.y + step
      elseif btn == "DOWN" then
        ns.db.y = ns.db.y - step
      elseif btn == "LEFT" then
        ns.db.x = ns.db.x - step
      elseif btn == "RIGHT" then
        ns.db.x = ns.db.x + step
      elseif btn == "A" or btn == "B" then
        st.moving = false
      end
      ns.layout()
      return refresh()
    end
    if btn == "UP" then
      st.row, st.col = math.max(0, st.row - 1), 0
    end
    if btn == "DOWN" then
      st.row, st.col = math.min(3, st.row + 1), 0
    end
    local d = btn == "RIGHT" and 1 or btn == "LEFT" and -1 or 0
    if st.row == 3 then
      if d ~= 0 then
        local i = 1
        for n, name in ipairs(ns.LOOKS) do
          if name == ns.db.look then
            i = n
          end
        end
        ns.setLook(ns.LOOKS[clamp(i + d, 1, #ns.LOOKS)])
      end
      return refresh()
    end
    if st.row == 2 then
      if d ~= 0 then
        st.col = clamp(st.col + d, 0, 1)
      end
      if btn == "A" then
        if st.col == 0 then
          st.moving = true
        else
          ns.db.x, ns.db.y = 0, 0
          ns.layout()
        end
      end
      return refresh()
    end
    if d ~= 0 and st.row == 0 then
      ns.db.scale = clamp(math.floor((ns.db.scale + d * 0.1) * 10 + 0.5) / 10, 0.6, 1.6)
    elseif d ~= 0 then
      ns.db.distance = clamp(ns.db.distance + d, 1, 5)
    end
    if d ~= 0 then
      ns.layout()
    end
    return refresh()
  end

  local b = bindAt(st.li)
  if st.zone == "list" then
    if btn == "UP" then
      st.li = math.max(1, st.li - 1)
    end
    if btn == "DOWN" then
      st.li = math.max(1, math.min(bindCount(), st.li + 1))
    end
    if btn == "A" and b then
      setAim(b, not aimed(b))
    end
    if btn == "RIGHT" and b and b.heal then
      st.zone, st.row, st.col = "detail", 0, aimed(b) and 1 or 0
    end
    return refresh()
  end
  if btn == "B" then
    st.zone = "list"
    return refresh()
  end
  if btn == "UP" then
    st.row, st.col = 0, aimed(b) and 1 or 0
  end
  if btn == "DOWN" and aimed(b) then
    st.row = 1
    for i, t in ipairs(ns.TAPS) do
      if t == ns.aimConf(b).tap then
        st.col = i - 1
      end
    end
  end
  if btn == "LEFT" then
    if st.col == 0 then
      st.zone = "list"
    else
      st.col = st.col - 1
    end
  end
  if btn == "RIGHT" then
    st.col = math.min(st.row == 0 and 1 or #ns.TAPS - 1, st.col + 1)
  end
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

-- Move with a stick: either stick glides the diamond while Move is on.
local SPEED = 700 -- screen units a second at full tilt
local glide = CreateFrame("Frame")
glide:SetScript("OnUpdate", function(_, elapsed)
  if not st.moving or not panel or not panel:IsShown() then
    return
  end
  local ok, state = pcall(function()
    return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
  end)
  if not ok or type(state) ~= "table" or type(state.sticks) ~= "table" then
    return
  end
  local dx, dy = 0, 0
  for _, stick in ipairs(state.sticks) do
    local x, y = tonumber(stick.x) or 0, tonumber(stick.y) or 0
    if math.abs(x) > math.abs(dx) then
      dx = x
    end
    if math.abs(y) > math.abs(dy) then
      dy = y
    end
  end
  local function dead(v)
    return math.abs(v) < 0.2 and 0 or v
  end
  dx, dy = dead(dx), dead(dy)
  if dx == 0 and dy == 0 then
    return
  end
  ns.db.x = ns.db.x + dx * SPEED * elapsed
  ns.db.y = ns.db.y + dy * SPEED * elapsed
  ns.layout()
end)

-- While the panel is open these keys drive it; they go back when it closes.
local NAV_KEYS = {
  PADDUP = "UP",
  PADDDOWN = "DOWN",
  PADDLEFT = "LEFT",
  PADDRIGHT = "RIGHT",
  UP = "UP",
  DOWN = "DOWN",
  LEFT = "LEFT",
  RIGHT = "RIGHT",
  PAD1 = "A",
  ENTER = "A",
  SPACE = "A",
  PAD2 = "B",
  PADLSHOULDER = "LB",
  PADRSHOULDER = "RB",
  Q = "LB",
  E = "RB",
  ESCAPE = "ESC",
}
for _, btn in ipairs({ "UP", "DOWN", "LEFT", "RIGHT", "A", "B", "LB", "RB", "ESC" }) do
  local f = CreateFrame("Button", "HealpadNav" .. btn, UIParent)
  f:SetScript("OnClick", function()
    nav(btn, true)
  end)
end

local function takeKeys()
  if InCombatLockdown() then
    return
  end
  for key, btn in pairs(NAV_KEYS) do
    SetOverrideBindingClick(panel, true, key, "HealpadNav" .. btn)
  end
end
local function giveKeys()
  if InCombatLockdown() then
    return
  end
  ClearOverrideBindings(panel)
end

---------------------------------------------------------------- building

-- Finds the list position of a row, for a mouse click.
local function liOf(entry)
  local n = 0
  for _, r in ipairs(rows) do
    if r.bind then
      n = n + 1
      if r == entry then
        return n
      end
    end
  end
end

local function buildButtonsTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local list = CreateFrame("Frame", nil, t)
  list:SetPoint("TOPLEFT", PAD - 6, -PAD)
  list:SetPoint("BOTTOMLEFT", PAD - 6, PAD)
  list:SetWidth(LIST_W)
  local divider = t:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.35, 0.3, 0.2, 0.6)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
  divider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
  ui.rows = {}
  for i = 1, math.floor((H - 60 - 2 * PAD - 8) / ROW_H) do
    local f = CreateFrame("Frame", nil, list)
    f:SetSize(LIST_W, ROW_H)
    f:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    f.header = text(f, "GameFontHighlightSmall", { 0.7, 0.7, 0.7 })
    f.header:SetPoint("BOTTOMLEFT", 8, 6)
    local line = CreateFrame("Button", nil, f)
    line:SetAllPoints()
    line.ringInside = true
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
    f.key:SetPoint("LEFT", 8, 0)
    f.key:SetWidth(40)
    f.key:SetJustifyH("LEFT")
    f.icon = line:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(22, 22)
    f.icon:SetPoint("LEFT", 52, 0)
    f.name = text(line, "GameFontNormal")
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.name:SetPoint("RIGHT", -40, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.check = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
    f.check:SetSize(24, 24)
    f.check:SetPoint("RIGHT", -8, 0)
    local function pick(flip)
      if InCombatLockdown() or not f.entry or not f.entry.bind then
        return
      end
      st.li, st.zone = liOf(f.entry) or st.li, "list"
      if flip then
        setAim(f.entry.bind, not aimed(f.entry.bind))
      end
      refresh()
    end
    line:SetScript("OnClick", function()
      pick(false)
    end)
    f.check:SetScript("OnClick", function()
      pick(true)
    end)
    ui.rows[i] = f
  end
  ui.empty = text(list, "GameFontDisable")
  ui.empty:SetPoint("CENTER")
  ui.empty:SetText("No heals on your buttons")

  local d = CreateFrame("Frame", nil, t)
  d:SetPoint("TOPLEFT", list, "TOPRIGHT", PAD + 8, -4)
  d:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  ui.detail = d
  d.icon = d:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(40, 40)
  d.icon:SetPoint("TOPLEFT", 0, 0)
  d.name = text(d, "GameFontNormalLarge")
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
  d.rank = text(d, "GameFontHighlightSmall")
  d.rank:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
  d.key = text(d, "GameFontHighlight")
  d.key:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)

  d.modes = CreateFrame("Frame", nil, d)
  d.modes:SetPoint("TOPLEFT", 0, -88)
  d.modes:SetPoint("RIGHT")
  d.modes:SetHeight(36)
  local detailW = W - 10 - (PAD - 6) - LIST_W - (PAD + 8) - PAD
  local half = (detailW - 8) / 2
  d.cast = redButton(d.modes, half, 34, "Cast")
  d.cast:SetPoint("TOPLEFT")
  d.hold = redButton(d.modes, half, 34, "Hold to Aim")
  d.hold:SetPoint("TOPLEFT", d.cast, "TOPRIGHT", 8, 0)
  d.cast:SetScript("OnClick", function()
    st.zone, st.row, st.col = "detail", 0, 0
    ns.optionsNav("A")
  end)
  d.hold:SetScript("OnClick", function()
    st.zone, st.row, st.col = "detail", 0, 1
    ns.optionsNav("A")
  end)

  d.tapBox = CreateFrame("Frame", nil, d)
  d.tapBox:SetPoint("TOPLEFT", d.modes, "BOTTOMLEFT", 0, -24)
  d.tapBox:SetPoint("RIGHT")
  d.tapBox:SetHeight(64)
  local tapLabel = text(d.tapBox, "GameFontNormal")
  tapLabel:SetText("Tap to heal")
  tapLabel:SetPoint("TOPLEFT")
  d.taps = {}
  -- each button as wide as its word, the row filling the pane
  local widths, total = {}, 0
  for i, tap in ipairs(ns.TAPS) do
    local probe = redButton(d.tapBox, 10, 28, ns.TAP_LABEL[tap])
    local fs = probe:GetFontString()
    widths[i] = (fs and fs:GetStringWidth() or 40) + 24
    total = total + widths[i]
    probe:Hide()
  end
  local gap = 6
  local extra = (detailW - total - gap * (#ns.TAPS - 1)) / #ns.TAPS
  local x = 0
  for i, tap in ipairs(ns.TAPS) do
    local w = widths[i] + math.max(0, extra)
    local b = redButton(d.tapBox, w, 28, ns.TAP_LABEL[tap])
    b:SetPoint("TOPLEFT", x, -20)
    x = x + w + gap
    b:SetScript("OnClick", function()
      st.zone, st.row, st.col = "detail", 1, i - 1
      ns.optionsNav("A")
    end)
    d.taps[i] = b
  end
  return t
end

local function buildAimTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local h1 = text(t, "GameFontNormalLarge")
  h1:SetText("Aim with")
  h1:SetPoint("TOPLEFT", PAD, -PAD)
  t.aimers = {}
  local w = (W - 10 - 2 * PAD - 24) / 3
  for i, k in ipairs(ns.AIMERS) do
    local b = redButton(t, w, 44, ns.AIMER_LABEL[k])
    b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 12), -PAD - 30)
    b:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      st.row = 0
      ns.db.aimWith = k
      ns.applyKeys(true)
      refresh()
    end)
    t.aimers[i] = b
  end
  local h2 = text(t, "GameFontNormalLarge")
  h2:SetText("Cancel with")
  h2:SetPoint("TOPLEFT", PAD, -PAD - 110)
  t.cancels = {}
  local NAMES = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
  for i, key in ipairs(ns.CANCELS) do
    local b = redButton(t, 60, 34, keyText(NAMES[key]))
    b:SetPoint("TOPLEFT", PAD + (i - 1) * 68, -PAD - 140)
    b:SetScript("OnClick", function()
      if InCombatLockdown() or cancelTaken(key) then
        return
      end
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
  s:SetPoint("TOPLEFT", PAD, y)
  s:SetPoint("RIGHT", -PAD, 0)
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
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true,
    tileEdge = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  s.bar = CreateFrame("StatusBar", nil, frame)
  s.bar:SetPoint("TOPLEFT", 4, -6)
  s.bar:SetPoint("BOTTOMRIGHT", -4, 6)
  s.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  s.bar:SetStatusBarColor(1, 0.82, 0)
  s.bar:SetMinMaxValues(lo, hi)
  minus:SetScript("OnClick", function()
    st.row = row
    ns.optionsNav("LEFT")
  end)
  plus:SetScript("OnClick", function()
    st.row = row
    ns.optionsNav("RIGHT")
  end)
  return s
end

local function buildFramesTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  t.size = slider(t, "Size", -PAD - 4, 0, 0.6, 1.6)
  t.spread = slider(t, "Spread", -PAD - 100, 1, 1, 5)
  -- Position: drag the diamond with the mouse, or Move with the pad.
  local pos = text(t, "GameFontNormalLarge")
  pos:SetText("Position")
  pos:SetPoint("TOPLEFT", PAD, -PAD - 196)
  t.move = redButton(t, 120, 30, "Move")
  t.move:SetPoint("TOPLEFT", PAD, -PAD - 224)
  t.reset = redButton(t, 120, 30, "Reset")
  t.reset:SetPoint("LEFT", t.move, "RIGHT", 10, 0)
  t.move:SetScript("OnClick", function()
    st.row, st.col = 2, 0
    nav("A")
  end)
  t.reset:SetScript("OnClick", function()
    st.row, st.col = 2, 1
    nav("A")
  end)
  local look = text(t, "GameFontNormalLarge")
  look:SetText("Look")
  look:SetPoint("TOPLEFT", PAD, -PAD - 270)
  t.looks = {}
  local w = (400 - 10 - 2 * PAD - 3 * 6) / #ns.LOOKS
  for i, name in ipairs(ns.LOOKS) do
    local b = redButton(t, w, 30, ns.LOOK_LABEL[name])
    b:SetPoint("TOPLEFT", PAD + (i - 1) * (w + 6), -PAD - 298)
    b.gold = ns.outline(b, b, 1, 2)
    b.gold:SetColor(1, 0.82, 0, 1)
    b:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      st.row = 3
      ns.setLook(name)
      refresh()
    end)
    t.looks[i] = b
  end
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
  if ButtonFrameTemplate_HideButtonBar then
    ButtonFrameTemplate_HideButtonBar(panel)
  end
  if panel.SetTitle then
    panel:SetTitle("Healpad")
  end
  if panel.SetPortraitToUnit then
    panel:SetPortraitToUnit("player")
  end
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
    if PanelTemplates_TabResize then
      PanelTemplates_TabResize(tab, 0)
    end
    if i == 1 then
      tab:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 12, 2)
    end
    tab:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      st.tab, st.zone, st.row, st.col = t, "list", 0, 0
      if PlaySound and SOUNDKIT then
        pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
      end
      refresh()
    end)
    ui.tabs[i] = tab
  end
  if PanelTemplates_SetNumTabs then
    PanelTemplates_SetNumTabs(panel, #TABS)
  end

  ui.buttons = buildButtonsTab(body)
  ui.aim = buildAimTab(body)
  ui.frames = buildFramesTab(body)

  ui.ring = ns.outline(panel, panel, 0, 2)
  ui.ring:SetColor(0.45, 0.8, 1, 1)
  ui.ring:SetFrameLevel((panel:GetFrameLevel() or 0) + 30)

  panel:SetScript("OnShow", function()
    st.keys, st.moving = false, false
    takeKeys()
  end)
  panel:SetScript("OnHide", function()
    giveKeys()
    if ns.preview then
      ns.preview(false)
    end
    st.moving = false
    if ns.showMoving then
      ns.showMoving(false)
    end
    if ns.db then
      ns.db.x, ns.db.y = math.floor(ns.db.x + 0.5), math.floor(ns.db.y + 0.5)
    end
  end)
  table.insert(UISpecialFrames, "HealpadOptions")
end

function ns.openOptions()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  if not panel then
    build()
  end
  ns.binds = ns.readBinds()
  buildRows()
  st.li = math.max(1, math.min(st.li, bindCount()))
  panel:Show()
  refresh()
end
function ns.optionsPanel()
  return panel
end
-- For /hp test: the parts and the focus.
function ns.optionsDebug()
  return { panel = panel, ui = ui, st = st, rows = rows }
end

SLASH_HEALPAD1 = "/healpad"
SLASH_HEALPAD2 = "/hp"
SlashCmdList.HEALPAD = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "test" then
    if ns.selfTest then
      ns.selfTest()
    end
    return
  end
  if cmd == "shots" then
    if ns.showcase then
      ns.showcase()
    end
    return
  end
  if panel and panel:IsShown() then
    panel:Hide()
  else
    ns.openOptions()
  end
end

ns.on("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then
    panel:Hide()
  end
end)

ns.on("PLAYER_LOGIN", function()
  if next(ns.db.aim) == nil and next(ns.db.aimSpell) == nil and next(ns.db.aimPad) == nil then
    ns.say("type /hp to choose which heals hold to aim.")
  end
end)
