-- The settings: /healpad or /hp. Three tabs.
--   Buttons:  your heal buttons in a list; the one you are on shows on the
--             right: Enable (hold to aim, else it casts as before) and who a
--             quick tap heals.
--   Controls: what picks who to heal (d-pad or a stick) and what cancels.
--   Frames:   how big the diamond's frames are, how far apart, its look and
--             where it sits.
-- Works with the pad (d-pad, A, B, LB, RB), the keyboard (arrows, Enter) and
-- the mouse, all by one rule: the d-pad moves the focus to what is next to it
-- on the screen, A picks; only a slider takes Left and Right to change. B goes
-- back one step. Settings change out of combat only; the panel closes in
-- combat.
local _, ns = ...

local W, FRAMES_W = 620, 440 -- Frames is narrow and steps aside for the diamond
local TOP_Y = 120 -- the window's top edge, the same on every tab
local PAD = 12 -- space inside the window's inset
local INSET_W = W - 10
local LIST_X, LIST_W, ROW_H, MAX_ROWS = 8, 262, 34, 12
local DET_X = LIST_X + LIST_W + 12 + 1 + 16
local DET_W = INSET_W - DET_X - 14
local BTN_H = 28
-- the detail, from its top
local DET_TOP = PAD + 4
local DET_KEY = DET_TOP + 40 + 10
local DET_ENABLE = DET_KEY + 14 + 16
local DET_TAPLABEL = DET_ENABLE + BTN_H + 16
local DET_STACK = DET_TAPLABEL + 14 + 8
local STACK_GAP = 4
local FORM_ROW_GAP = 14
local TABS = { "buttons", "controls", "frames" }
local TAB_LABEL = { buttons = "Buttons", controls = "Controls", frames = "Frames" }
local GOLD, WHITE = { 1, 0.82, 0 }, { 1, 1, 1 }
local SOFT = { 0.85, 0.78, 0.6 } -- a choice not chosen
local PAD_COLOR = { A = { 0.4, 0.9, 0.4 }, B = { 1, 0.35, 0.3 }, X = { 0.35, 0.6, 1 }, Y = { 1, 0.85, 0.2 } }
local CANCEL_NAME = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }

local panel
local ui = {}
-- focus: what the pad is on, per tab ("row", "enable", "tap2", "size", ...)
local st = { tab = "buttons", li = 1, top = 1, focus = {} }
local rows = {} -- the Buttons list: { bind = b }, heals only
local items = {} -- what the focus can be on in the shown tab

---------------------------------------------------------------- small parts
-- The game's own pieces where they fit: the window frame, its tabs and the
-- red buttons for actions. Choices are dark buttons; the chosen one is edged
-- in gold.

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

local function textWidth(fs)
  local ok, w = pcall(fs.GetStringWidth, fs)
  return ok and tonumber(w) or 0
end

local function fill(tex, top, bottom)
  if ns.kit and ns.kit.gradient then
    ns.kit.gradient(tex, "VERTICAL", bottom, top)
  else
    tex:SetColorTexture(unpack(top))
  end
end

-- A dark choice button. w = nil: as wide as its words.
local function choice(parent, w, h, label, font, left)
  local b = CreateFrame("Button", nil, parent)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.edge = ns.outline(b, b, 0, 1)
  b.edge:SetColor(0.29, 0.25, 0.17, 1)
  b.edge:Show()
  b.gold = ns.outline(b, b, 0, 2)
  b.gold:SetColor(1, 0.82, 0, 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.08)
  b.label = text(b, font or "GameFontNormal", SOFT)
  b.label:SetText(label)
  b.label:SetWordWrap(false)
  if left then
    b.label:SetPoint("LEFT", 12, 0)
    b.label:SetJustifyH("LEFT")
  else
    b.label:SetPoint("CENTER")
  end
  b.pad = 24
  b:SetSize(w or math.max(64, textWidth(b.label) + b.pad), h)
  fill(b.bg, { 0.13, 0.11, 0.08, 1 }, { 0.07, 0.07, 0.05, 1 })
  return b
end

local function setChosen(b, on)
  b.chosen = on
  if b.gold then
    b.gold:SetShown(on)
    fill(
      b.bg,
      on and { 0.27, 0.22, 0.06, 1 } or { 0.13, 0.11, 0.08, 1 },
      on and { 0.15, 0.11, 0.03, 1 } or { 0.07, 0.07, 0.05, 1 }
    )
    b.label:SetTextColor(unpack(on and WHITE or SOFT))
  else
    -- a red button: lit while chosen
    if on then
      b:LockHighlight()
    else
      b:UnlockHighlight()
    end
    local fs = b.GetFontString and b:GetFontString()
    if fs then
      fs:SetTextColor(unpack(on and WHITE or GOLD))
    end
  end
end

-- Dimmed: still there, but not picked and skipped by the pad.
local function setDim(b, dim)
  b.dim = dim
  b:SetAlpha(dim and 0.32 or 1)
  b:SetEnabled(not dim)
end

-- A red button, for actions.
local function redButton(parent, w, h, label)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(label)
  return b
end

-- Placed by its top left, y down from the tab's top; the pad finds it by
-- this box.
local function place(f, parent, x, y, w, h)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  f.box = { x = x, y = y, w = w, h = h }
end

---------------------------------------------------------------- the data

local function settingOf(b)
  if b.kb then
    return ns.db.aimSpell, b.cast
  elseif b.gp then
    return ns.db.aimPad, b.spell
  end
  return ns.db.aim, b.key
end

local function buildRows()
  wipe(rows)
  local seen = {}
  for _, b in ipairs(ns.binds or {}) do
    if b.heal then
      -- KeyBars lists a key once per layer: the same key and spell is one row
      local _, k = settingOf(b)
      local id = (b.kb and "kb" or b.gp and "gp" or "key") .. ":" .. ns.bindLabel(b) .. ":" .. tostring(k)
      if not seen[id] then
        seen[id] = true
        table.insert(rows, { bind = b })
      end
    end
  end
end

local function current()
  return rows[st.li] and rows[st.li].bind
end

local function aimed(b)
  return ns.aimConf(b) ~= nil
end

-- Enable: the button holds to aim. Off, it casts as it always did.
local function setAim(b, on)
  if not b or not b.heal or InCombatLockdown() then
    return
  end
  local t, k = settingOf(b)
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

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

---------------------------------------------------------------- what A does

local refresh, takeKeys

local function pick(key, fromMouse)
  if InCombatLockdown() then
    return
  end
  local b = current()
  if key == "row" then
    if not fromMouse and b then
      st.focus.buttons = "enable"
    end
  elseif key == "enable" then
    setAim(b, not aimed(b))
  elseif key:match("^tap%d$") then
    local conf = ns.aimConf(b)
    if conf then
      conf.tap = ns.TAPS[tonumber(key:sub(4))]
      ns.applyKeys(true)
    end
  elseif key:match("^aimer%d$") then
    ns.db.aimWith = ns.AIMERS[tonumber(key:sub(6))]
    ns.applyKeys(true)
  elseif key:match("^cancel%d$") then
    local c = ns.CANCELS[tonumber(key:sub(7))]
    if not cancelTaken(c) then
      ns.db.cancel = c
      ns.applyKeys(true)
    end
  elseif key:match("^look%d$") then
    ns.setLook(ns.LOOKS[tonumber(key:sub(5))])
  elseif key == "move" then
    st.moving = not st.moving
  elseif key == "reset" then
    ns.db.x, ns.db.y = 0, 0
    ns.layout()
  end
end

local function adjust(which, d)
  if which == "size" then
    ns.db.scale = clamp(math.floor(((ns.db.scale or 1) + d * 0.1) * 10 + 0.5) / 10, 0.6, 1.6)
  else
    ns.db.distance = clamp((ns.db.distance or 3) + d, 1, 5)
  end
  ns.layout()
end

-- A click: the focus goes there too, and the ring hides.
local function click(key)
  if InCombatLockdown() then
    return
  end
  st.keys = false
  st.focus[st.tab] = key
  pick(key, true)
  refresh()
end

---------------------------------------------------------------- drawing

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

local function visibleRows()
  return math.min(#rows, MAX_ROWS)
end

-- The tab's height: what it holds, and no more.
local function insetHeight()
  if st.tab == "buttons" then
    local detail = DET_STACK + #ns.TAPS * (BTN_H + STACK_GAP) - STACK_GAP + PAD
    if #rows == 0 then
      return 2 * PAD + 60
    end
    return math.max(detail, 2 * PAD + visibleRows() * ROW_H)
  elseif st.tab == "controls" then
    return ui.controls.bottom + PAD
  end
  return ui.frames.bottom + PAD
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
  for _, t in ipairs(TABS) do
    ui[t]:SetShown(st.tab == t)
  end
  -- The preview puts the first enabled button's tap target in the middle.
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
  local h = insetHeight() + 24 + 4
  panel:ClearAllPoints()
  -- On Frames the window is narrow and steps aside so the diamond shows.
  if st.tab == "frames" then
    panel:SetSize(FRAMES_W, h)
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -TOP_Y)
  else
    panel:SetSize(W, h)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -TOP_Y)
  end
end

local function drawList()
  local visible = visibleRows()
  if st.li < st.top then
    st.top = st.li
  end
  if st.li > st.top + visible - 1 then
    st.top = st.li - visible + 1
  end
  st.top = clamp(st.top, 1, math.max(1, #rows - visible + 1))
  -- the key column as wide as the widest key
  local kw = 22
  for i = 1, visible do
    local r = rows[st.top + i - 1]
    local f = ui.rows[i]
    f.key:SetText(keyText(ns.bindLabel(r.bind)))
    kw = math.max(kw, textWidth(f.key) + 2)
  end
  kw = math.min(kw, 64)
  local b = current()
  for i, f in ipairs(ui.rows) do
    local r = i <= visible and rows[st.top + i - 1]
    f.li = r and st.top + i - 1
    if not r then
      f:Hide()
    else
      f:Show()
      local rb = r.bind
      f.key:SetWidth(kw)
      f.icon:ClearAllPoints()
      f.icon:SetPoint("LEFT", 8 + kw + 6, 0)
      f.icon:SetTexture(ns.spellIcon(rb.spell))
      f.name:SetText(ns.spellName(rb.spell))
      f.on:SetShown(aimed(rb))
      f.selected:SetShown(rb == b)
    end
  end
  ui.empty:SetShown(#rows == 0)
end

local function drawDetail()
  local b = current()
  local d = ui.detail
  d:SetShown(b ~= nil)
  if not b then
    return
  end
  d.key:SetText(keyText(ns.bindLabel(b)))
  d.icon:SetTexture(ns.spellIcon(b.spell))
  d.name:SetText(ns.spellName(b.spell))
  d.rank:SetText(ns.spellRank(b.spell))
  local on = aimed(b)
  setChosen(d.enable, on)
  d.tapLabel:SetAlpha(on and 1 or 0.35)
  local tap = on and ns.aimConf(b).tap
  for i, t in ipairs(ns.TAPS) do
    setChosen(d.taps[i], tap == t)
    setDim(d.taps[i], not on)
  end
end

local function drawControls()
  local c = ui.controls
  for i, k in ipairs(ns.AIMERS) do
    setChosen(c.aimers[i], ns.db.aimWith == k)
  end
  for i, key in ipairs(ns.CANCELS) do
    setChosen(c.cancels[i], ns.db.cancel == key)
    setDim(c.cancels[i], cancelTaken(key))
  end
end

local function drawSlider(s, v, lo, hi, label)
  s.drawing = true
  s.bar:SetValue(v)
  s.drawing = false
  s.value:SetText(label)
  local w = (s.trackW - 8) * (v - lo) / (hi - lo)
  s.fill:SetWidth(math.max(1, w))
  s.fill:SetShown(w > 0.5)
end

local function drawFrames()
  local f = ui.frames
  local size, spread = ns.db.scale or 1, ns.db.distance or 3
  drawSlider(f.size, size, 0.6, 1.6, math.floor(size * 100 + 0.5) .. "%")
  drawSlider(f.spread, spread, 1, 5, tostring(spread))
  for i, name in ipairs(ns.LOOKS) do
    setChosen(f.looks[i], ns.db.look == name)
  end
  f.move:SetText(st.moving and "Done" or "Move")
  setChosen(f.move, st.moving == true)
end

-- What the focus can be on, in the shown tab.
local function collect()
  wipe(items)
  local function add(key, frame, skip)
    table.insert(items, { key = key, frame = frame, box = frame.box, skip = skip })
  end
  if st.tab == "buttons" then
    for _, f in ipairs(ui.rows) do
      if f:IsShown() and f.li == st.li then
        add("row", f.line)
      end
    end
    if current() then
      local d = ui.detail
      add("enable", d.enable)
      for i, b in ipairs(d.taps) do
        add("tap" .. i, b, b.dim)
      end
    end
  elseif st.tab == "controls" then
    for i, b in ipairs(ui.controls.aimers) do
      add("aimer" .. i, b)
    end
    for i, b in ipairs(ui.controls.cancels) do
      add("cancel" .. i, b, b.dim)
    end
  else
    local f = ui.frames
    add("size", f.size.focus)
    add("spread", f.spread.focus)
    for i, b in ipairs(f.looks) do
      add("look" .. i, b)
    end
    add("move", f.move)
    add("reset", f.reset)
  end
end

local function itemOf(key)
  for _, it in ipairs(items) do
    if it.key == key and not it.skip then
      return it
    end
  end
end

-- Keeps the focus on something there: a tap goes back to Enable, Enable to
-- its row, the rest to the first thing in the tab.
local function settleFocus()
  local key = st.focus[st.tab]
  if key and itemOf(key) then
    return itemOf(key)
  end
  local alt = key and (key:match("^tap") and "enable" or key == "enable" and "row")
  if alt and itemOf(alt) then
    st.focus[st.tab] = alt
    return itemOf(alt)
  end
  for _, it in ipairs(items) do
    if not it.skip then
      st.focus[st.tab] = it.key
      return it
    end
  end
  st.focus[st.tab] = nil
end

refresh = function()
  if not panel or not panel:IsShown() then
    return
  end
  if st.tab ~= "frames" then
    st.moving = false
  end
  drawTabs()
  if st.tab == "buttons" then
    drawList()
    drawDetail()
  elseif st.tab == "controls" then
    drawControls()
  else
    drawFrames()
  end
  collect()
  local it = settleFocus()
  ring((st.keys or st.moving) and it and it.frame or nil)
  if ns.showMoving then
    ns.showMoving(st.moving == true and st.tab == "frames")
  end
  if st.moving then
    ui.ring:SetColor(1, 0.82, 0, 1)
  else
    ui.ring:SetColor(0.45, 0.8, 1, 1)
  end
end

-- After applyKeys: your bindings may have changed. The nav keys are taken
-- again, so a heal on A or B, just bound again, doesn't take them.
function ns.refreshOptions()
  if panel and panel:IsShown() then
    takeKeys()
    buildRows()
    st.li = clamp(st.li, 1, math.max(1, #rows))
    refresh()
  end
end

---------------------------------------------------------------- input

-- The nearest thing that way, by where it is on the screen. Boxes are y down.
local function nearest(from, dir, list)
  local a = from.box
  local best, bestScore
  for _, it in ipairs(list) do
    local r = it.box
    if it ~= from and not it.skip and r then
      local p, s, off
      local vertical = dir == "UP" or dir == "DOWN"
      if dir == "DOWN" then
        p = r.y - (a.y + a.h)
      elseif dir == "UP" then
        p = a.y - (r.y + r.h)
      elseif dir == "RIGHT" then
        p = r.x - (a.x + a.w)
      else
        p = a.x - (r.x + r.w)
      end
      -- side: how far off to the side; lined up, the nearer start wins
      if vertical then
        s = math.max(0, r.x - (a.x + a.w), a.x - (r.x + r.w))
        off = s > 0 and math.abs((r.x + r.w / 2) - (a.x + a.w / 2)) or math.abs(r.x - a.x)
      else
        s = math.max(0, r.y - (a.y + a.h), a.y - (r.y + r.h))
        off = s > 0 and math.abs((r.y + r.h / 2) - (a.y + a.h / 2)) or math.abs(r.y - a.y)
      end
      if p >= -4 then
        local score = p + s * 4 + off * 0.15
        if not bestScore or score < bestScore then
          best, bestScore = it, score
        end
      end
    end
  end
  return best
end

local function move(dir)
  local key = st.focus[st.tab]
  local from = key and itemOf(key)
  if not from then
    return
  end
  if st.tab == "buttons" then
    if key == "row" then
      if dir == "UP" or dir == "DOWN" then
        st.li = clamp(st.li + (dir == "UP" and -1 or 1), 1, math.max(1, #rows))
        return
      end
    elseif dir == "LEFT" then
      -- out of the detail: back to the row it belongs to
      st.focus.buttons = "row"
      return
    end
    local detail = {}
    for _, it in ipairs(items) do
      if it.key ~= "row" then
        table.insert(detail, it)
      end
    end
    local to = nearest(from, dir, detail)
    if to then
      st.focus.buttons = to.key
    end
    return
  end
  local to = nearest(from, dir, items)
  if to then
    st.focus[st.tab] = to.key
  end
end

-- fromKeys: a pad button or key, not the mouse. The focus ring shows only
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
    st.tab, st.moving = TABS[i], false
    return refresh()
  end
  if btn == "ESC" then
    panel:Hide()
    return
  end
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
  local key = st.focus[st.tab]
  if btn == "B" then
    if st.tab == "buttons" and key and key ~= "row" and current() then
      st.focus.buttons = "row"
      return refresh()
    end
    panel:Hide()
    return
  end
  if (btn == "LEFT" or btn == "RIGHT") and (key == "size" or key == "spread") then
    adjust(key, btn == "LEFT" and -1 or 1)
    return refresh()
  end
  if btn == "A" then
    if key then
      pick(key, false)
    end
    return refresh()
  end
  move(btn)
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

takeKeys = function()
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

local function onClick(b, key)
  b:SetScript("OnClick", function()
    click(key)
  end)
end

local function buildButtonsTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local divider = t:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.47, 0.39, 0.24, 0.45)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", LIST_X + LIST_W + 12, -PAD)
  divider:SetPoint("BOTTOMLEFT", LIST_X + LIST_W + 12, PAD)
  ui.rows = {}
  for i = 1, MAX_ROWS do
    local f = CreateFrame("Frame", nil, t)
    f:SetSize(LIST_W, ROW_H)
    f:SetPoint("TOPLEFT", LIST_X, -(PAD + (i - 1) * ROW_H))
    local line = CreateFrame("Button", nil, f)
    line:SetAllPoints()
    line.ringInside = true
    line.box = { x = LIST_X, y = PAD + (i - 1) * ROW_H, w = LIST_W, h = ROW_H }
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
    f.key = text(line, "GameFontHighlight")
    f.key:SetPoint("LEFT", 8, 0)
    f.key:SetJustifyH("LEFT")
    f.key:SetWordWrap(false)
    f.icon = line:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("LEFT", 46, 0)
    f.on = text(line, "GameFontNormal", { 0.91, 0.76, 0.35 })
    f.on:SetText("On")
    f.on:SetPoint("RIGHT", -8, 0)
    f.name = text(line, "GameFontNormal")
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.name:SetPoint("RIGHT", -36, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    line:SetScript("OnClick", function()
      if InCombatLockdown() or not f.li then
        return
      end
      st.li = f.li
      click("row")
    end)
    ui.rows[i] = f
  end
  ui.empty = text(t, "GameFontDisable")
  ui.empty:SetPoint("TOPLEFT", LIST_X + 8, -PAD - 10)
  ui.empty:SetText("No heals on your buttons")

  local d = CreateFrame("Frame", nil, t)
  d:SetAllPoints()
  ui.detail = d
  d.icon = d:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(40, 40)
  d.icon:SetPoint("TOPLEFT", DET_X, -DET_TOP)
  d.name = text(d, "GameFontNormalLarge")
  d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 12, -2)
  d.name:SetWidth(DET_W - 52)
  d.name:SetJustifyH("LEFT")
  d.name:SetWordWrap(false)
  d.rank = text(d, "GameFontHighlightSmall")
  d.rank:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
  d.key = text(d, "GameFontHighlight")
  d.key:SetPoint("TOPLEFT", DET_X, -DET_KEY)

  d.enable = choice(d, nil, BTN_H, "Enable")
  d.enable:SetWidth(math.max(96, textWidth(d.enable.label) + 32))
  place(d.enable, d, DET_X, DET_ENABLE, d.enable:GetWidth() or 96, BTN_H)
  onClick(d.enable, "enable")

  d.tapLabel = text(d, "GameFontNormal")
  d.tapLabel:SetText("Tap to heal")
  d.tapLabel:SetPoint("TOPLEFT", DET_X, -DET_TAPLABEL)
  d.taps = {}
  for i, tap in ipairs(ns.TAPS) do
    local b = choice(d, DET_W, BTN_H, ns.TAP_LABEL[tap], nil, true)
    place(b, d, DET_X, DET_STACK + (i - 1) * (BTN_H + STACK_GAP), DET_W, BTN_H)
    onClick(b, "tap" .. i)
    d.taps[i] = b
  end
  return t
end

-- A label and a row of choices beside it; returns the row's bottom.
local function choiceRow(t, label, y, labelW, buttons)
  local l = text(t, "GameFontNormalLarge")
  l:SetText(label)
  l:SetPoint("LEFT", t, "TOPLEFT", PAD, -(y + BTN_H / 2))
  local x = PAD + labelW
  for _, b in ipairs(buttons) do
    local w = b:GetWidth() or 64
    place(b, t, x, y, w, BTN_H)
    x = x + w + 6
  end
  t.right = math.max(t.right or 0, x - 6)
  return y + BTN_H
end

local function buildControlsTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  t.aimers, t.cancels = {}, {}
  for i, k in ipairs(ns.AIMERS) do
    t.aimers[i] = choice(t, nil, BTN_H, ns.AIMER_LABEL[k])
    onClick(t.aimers[i], "aimer" .. i)
  end
  for i, key in ipairs(ns.CANCELS) do
    t.cancels[i] = choice(t, 40, BTN_H, keyText(CANCEL_NAME[key]), "GameFontNormalLarge")
    onClick(t.cancels[i], "cancel" .. i)
  end
  local y = choiceRow(t, "Select with", PAD + 4, 116, t.aimers)
  t.bottom = choiceRow(t, "Cancel with", y + FORM_ROW_GAP, 116, t.cancels)
  return t
end

local FRAMES_LABEL_W, TRACK_W, STEP_W, VALUE_W = 96, 170, 28, 44

-- Size and Spread: - and + either side of a slider, the value at the right.
local function slider(t, label, y, which, lo, hi, step)
  local s = {}
  local l = text(t, "GameFontNormalLarge")
  l:SetText(label)
  l:SetPoint("LEFT", t, "TOPLEFT", PAD, -(y + 15))
  local x = PAD + FRAMES_LABEL_W
  local w = STEP_W * 2 + TRACK_W + VALUE_W + 3 * 6
  s.focus = CreateFrame("Frame", nil, t)
  place(s.focus, t, x - 2, y, w + 4, 30)
  s.focus:SetSize(w + 4, 30)
  local minus = choice(t, STEP_W, 26, "-", "GameFontNormalLarge")
  place(minus, t, x, y + 2, STEP_W, 26)
  minus.label:SetTextColor(unpack(GOLD))
  local bar = CreateFrame("Slider", nil, t, "BackdropTemplate")
  s.bar, s.trackW = bar, TRACK_W
  bar:SetOrientation("HORIZONTAL")
  bar:SetSize(TRACK_W, 17)
  place(bar, t, x + STEP_W + 6, y + 6.5, TRACK_W, 17)
  if bar.SetBackdrop then
    bar:SetBackdrop({
      bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
      edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
      tile = true,
      tileEdge = true,
      tileSize = 8,
      edgeSize = 8,
      insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
  end
  bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  bar:SetMinMaxValues(lo, hi)
  bar:SetValueStep(step)
  if bar.SetObeyStepOnDrag then
    bar:SetObeyStepOnDrag(true)
  end
  s.fill = bar:CreateTexture(nil, "ARTWORK")
  s.fill:SetPoint("LEFT", 4, 0)
  s.fill:SetHeight(5)
  s.fill:SetColorTexture(1, 0.82, 0, 0.85)
  bar:SetScript("OnValueChanged", function(_, v)
    if s.drawing or InCombatLockdown() then
      return
    end
    st.keys = false
    st.focus.frames = which
    if which == "size" then
      ns.db.scale = clamp(math.floor(v * 10 + 0.5) / 10, lo, hi)
    else
      ns.db.distance = clamp(math.floor(v + 0.5), lo, hi)
    end
    ns.layout()
    refresh()
  end)
  local plus = choice(t, STEP_W, 26, "+", "GameFontNormalLarge")
  place(plus, t, x + STEP_W + 6 + TRACK_W + 6, y + 2, STEP_W, 26)
  plus.label:SetTextColor(unpack(GOLD))
  local function stepper(b, d)
    b:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      st.keys = false
      st.focus.frames = which
      adjust(which, d)
      refresh()
    end)
  end
  stepper(minus, -1)
  stepper(plus, 1)
  s.minus, s.plus = minus, plus
  s.value = text(t, "GameFontHighlightLarge")
  s.value:SetPoint("RIGHT", t, "TOPLEFT", x + w, -(y + 15))
  s.value:SetJustifyH("RIGHT")
  s.right = x + w
  return s
end

local function buildFramesTab(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  local y = PAD + 4
  t.size = slider(t, "Size", y, "size", 0.6, 1.6, 0.1)
  y = y + 30 + FORM_ROW_GAP
  t.spread = slider(t, "Spread", y, "spread", 1, 5, 1)
  y = y + 30 + FORM_ROW_GAP
  t.right = t.size.right
  t.looks = {}
  for i, name in ipairs(ns.LOOKS) do
    t.looks[i] = choice(t, nil, BTN_H, ns.LOOK_LABEL[name])
    onClick(t.looks[i], "look" .. i)
  end
  y = choiceRow(t, "Look", y, FRAMES_LABEL_W, t.looks) + FORM_ROW_GAP
  -- Position: drag the diamond with the mouse, or Move with the pad.
  t.move = redButton(t, 104, BTN_H, "Move")
  t.reset = redButton(t, 104, BTN_H, "Reset")
  onClick(t.move, "move")
  onClick(t.reset, "reset")
  t.bottom = choiceRow(t, "Position", y, FRAMES_LABEL_W, { t.move, t.reset })
  return t
end

local function build()
  panel = CreateFrame("Frame", "HealpadOptions", UIParent, "ButtonFrameTemplate")
  panel:SetSize(W, 400)
  panel:SetPoint("TOP", UIParent, "TOP", 0, -TOP_Y)
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:Hide()
  -- no portrait, no band under the title, no button bar
  if not (ButtonFrameTemplate_HidePortrait and pcall(ButtonFrameTemplate_HidePortrait, panel)) then
    for _, k in ipairs({ "portrait", "PortraitContainer" }) do
      if type(panel[k]) == "table" and panel[k].Hide then
        panel[k]:Hide()
      end
    end
  end
  if ButtonFrameTemplate_HideAttic then
    pcall(ButtonFrameTemplate_HideAttic, panel)
  end
  if ButtonFrameTemplate_HideButtonBar then
    pcall(ButtonFrameTemplate_HideButtonBar, panel)
  end
  if panel.SetTitle then
    panel:SetTitle("Healpad")
  elseif type(panel.TitleText) == "table" then
    panel.TitleText:SetText("Healpad")
  end
  local inset = type(panel.Inset) == "table" and panel.Inset or nil
  local body = inset or panel
  if inset then
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 4, -24)
    inset:SetPoint("BOTTOMRIGHT", -6, 4)
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
    elseif not PanelTemplates_SetNumTabs then
      -- the game lines up the rest itself
      tab:SetPoint("TOPLEFT", ui.tabs[i - 1], "TOPRIGHT", 3, 0)
    end
    tab:SetScript("OnClick", function()
      if InCombatLockdown() then
        return
      end
      st.tab, st.keys = t, false
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
  ui.controls = buildControlsTab(body)
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
  st.li = clamp(st.li, 1, math.max(1, #rows))
  panel:Show()
  refresh()
end
function ns.optionsPanel()
  return panel
end
-- For /hp test and the tests: the parts and the focus.
function ns.optionsDebug()
  return {
    panel = panel,
    ui = ui,
    st = st,
    rows = rows,
    items = items,
    focus = function()
      return st.focus[st.tab]
    end,
    layout = {
      W = W,
      FRAMES_W = FRAMES_W,
      INSET_W = INSET_W,
      LIST_W = LIST_W,
      DET_X = DET_X,
      DET_W = DET_W,
    },
  }
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
    if msg:lower():match("page") then
      if ns.showcase then
        ns.showcase()
      end
    elseif ns.actionShots then
      ns.actionShots()
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
    ns.say("type /hp to set up your heals.")
  end
end)
