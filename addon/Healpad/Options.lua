-- The settings: /healpad or /hp. A narrow window with two tabs.
--   Heals: one row per heal on your buttons. Ticked, holding the button
--          opens the menu; not ticked, it casts as it always did. On the
--          right, who a quick tap heals.
--   Menu:  the mode (Radial or Buttons), and for it: the look, size and
--          spacing, the party frames, what happens after a heal, the
--          labels, what selects a person, what cancels, and where it sits.
--          Settings that don't apply to the mode don't show.
-- While the window is open the real menu is its preview: where it will be,
-- as big and in the look it will have. The window keeps to the side of the
-- screen the menu leaves free.
-- The pad (d-pad, A, B, LB, RB), the keys (arrows, Enter, Esc, Q, E) and the
-- mouse all work: Up and Down pick a row, Left and Right change its value, A
-- ticks, steps or presses, B closes. Out of combat only; it closes in combat.
local _, ns = ...

local W = 392
local PAD = 6 -- inside the window's inset
local INSET_X, INSET_TOP, INSET_BOTTOM = 4, 24, 4
local ROW_W = W - INSET_X - 6 - 2 * PAD
local ROW_H, HEAD_H, RP = 44, 22, 8 -- a row, the headings over the heals, a row's own margin
local TILE_ROW_H = 70 -- a row of picture tiles
local TILE_W, TILE_H, TILE_GAP = 96, 62, 8
local MAX_ROWS = 7 -- heals shown at once; the rest scroll
local ARROW = 22
local TAP_W = 94 -- the tap choice between its arrows
local CYCLER_W = 2 * ARROW + TAP_W
local CTL_W = 200 -- every control on the Menu tab
local LABEL_W = ROW_W - 2 * RP - CTL_W - 8
local CHECK = 26
local ICON = 34
local NAME_X = RP + CHECK + 8 + ICON + 10
local NAME_W = ROW_W - RP - CYCLER_W - 8 - NAME_X
local BTN_W, BTN_GAP = 96, 8
local EDGE = 12 -- the window's gap from the screen's edge
local TABS = { "heals", "menu" }
local TAB_LABEL = { heals = "Heals", menu = "Menu" }
local MENU_ROWS = { "mode", "look", "size", "spacing", "frames", "after", "labels", "pick", "cancel", "pos" }
local MENU_LABEL = {
  mode = "Mode",
  look = "Look",
  size = "Size",
  spacing = "Spacing",
  frames = "Party Frames",
  after = "After a heal",
  labels = "Labels",
  pick = "Select person with",
  cancel = "Cancel heal with",
  pos = "Position",
}
-- Rows that only one mode has.
local ONLY =
  { look = "radial", spacing = "radial", frames = "radial", pick = "radial", after = "buttons", labels = "buttons" }
-- Rows picked by two picture tiles: the setting, its choices, their words.
local TILES = {
  mode = { db = "mode", list = ns.MODES, label = { radial = "Radial", buttons = "Buttons" } },
  frames = { db = "frames", list = ns.FRAMES, label = { plus = "Plus", game = "Game" } },
  after = { db = "after", list = ns.AFTERS, label = { once = "Once", locked = "Locked" } },
  labels = { db = "labels", list = ns.LABELS, label = { row = "Row", full = "Full" } },
}
local SIZE_MIN, SIZE_MAX = 0.6, 1.6
local GOLD = { 1, 0.82, 0 }
local GOLD_SOFT = { 0.79, 0.65, 0.29 }
local PAD_COLOR = { A = { 0.37, 0.89, 0.37 }, B = { 1, 0.35, 0.3 }, X = { 0.36, 0.61, 1 }, Y = { 1, 0.82, 0.23 } }
local CANCEL_NAME = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y" }
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local HILIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local panel
local ui = {}
-- li: the heal row, top: the first heal shown, mi: the Menu row, sub: Move (1)
-- or Reset (2); keys: driven by the pad or keys (the focus shows)
local st = { tab = "heals", li = 1, top = 1, mkey = "mode", sub = 1, keys = false, moving = false, side = "left" }
local rows = {} -- the heals: { bind = b }
local fitted = {} -- every label that steps its font down to fit: { fs, room }

---------------------------------------------------------------- small parts

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function wrap(list, v, d)
  local i = 1
  for n, x in ipairs(list) do
    if x == v then
      i = n
    end
  end
  return list[(i - 1 + d) % #list + 1]
end

local function textWidth(fs)
  local ok, w = pcall(fs.GetStringWidth, fs)
  return ok and tonumber(w) or 0
end

-- A label at a size of its font; it keeps that as its own size.
local function text(parent, font, size, color)
  local t = parent:CreateFontString(nil, "OVERLAY", font)
  t:SetWordWrap(false)
  if color then
    t:SetTextColor(unpack(color))
  end
  local ok, file, base, flags = pcall(t.GetFont, t)
  if ok and file then
    size = size or base
    pcall(t.SetFont, t, file, size, flags)
    t.base = { file, size, flags }
  end
  return t
end

-- Sets the words; too wide for room, the font steps down until they fit.
local function setText(t, s, room)
  t:SetText(s)
  local b = t.base
  if b then
    local size = b[2]
    pcall(t.SetFont, t, b[1], size, b[3])
    while room and size > 7 and textWidth(t) > room do
      size = size - 0.5
      pcall(t.SetFont, t, b[1], size, b[3])
    end
  end
  if room and not fitted[t] then
    fitted[t] = true
    table.insert(fitted, { fs = t, room = room })
  end
end

local function keyText(label)
  local c = PAD_COLOR[label]
  if not c then
    return label
  end
  return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, label)
end

-- A plain button with nothing drawn: clicks and the mouse only.
local function hit(parent)
  local b = CreateFrame("Button", nil, parent)
  b:RegisterForClicks("LeftButtonUp")
  return b
end

-- The game's page arrows: left and right.
local function arrow(parent, dir)
  local b = hit(parent)
  b:SetSize(ARROW, ARROW)
  local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. (dir < 0 and "Prev" or "Next") .. "Page-"
  b:SetNormalTexture(base .. "Up")
  b:SetPushedTexture(base .. "Down")
  b:SetDisabledTexture(base .. "Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b.dir = dir
  return b
end

-- Left arrow, value, right arrow, w wide; mid is the clickable middle.
local function cycler(parent, w)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(w, ARROW + 4)
  c.left = arrow(c, -1)
  c.left:SetPoint("LEFT", c, "LEFT", 0, 0)
  c.right = arrow(c, 1)
  c.right:SetPoint("RIGHT", c, "RIGHT", 0, 0)
  c.mid = hit(c)
  c.mid:SetPoint("TOPLEFT", c.left, "TOPRIGHT", 0, 0)
  c.mid:SetPoint("BOTTOMRIGHT", c.right, "BOTTOMLEFT", 0, 0)
  c.midW = w - 2 * ARROW
  return c
end

-- A thin bar with a gold fill and the percent beside it.
local function meter(c)
  local track = CreateFrame("Frame", nil, c.mid)
  track:SetSize(90, 9)
  track:SetPoint("CENTER", c.mid, "CENTER", -25, 0)
  local bg = track:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.035, 0.03, 1)
  local edge = ns.outline(track, track, 0, 1)
  edge:SetColor(0.37, 0.35, 0.32, 1)
  edge:Show()
  c.fill = track:CreateTexture(nil, "ARTWORK")
  c.fill:SetTexture(BAR)
  c.fill:SetVertexColor(unpack(GOLD))
  c.fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
  c.fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
  c.trackW = 88
  c.track = track
  c.value = text(c.mid, "GameFontHighlight", 14)
  c.value:SetJustifyH("RIGHT")
  c.value:SetPoint("RIGHT", track, "RIGHT", 50, 0)
  c.valueRoom = 44
end

local function setMeter(c, v, lo, hi)
  local w = c.trackW * (v - lo) / (hi - lo)
  c.fill:SetWidth(math.max(1, w))
  c.fill:SetShown(w >= 1)
  c.fillW = w
  setText(c.value, math.floor(v * 100 + 0.5) .. "%", c.valueRoom)
  c.left:SetEnabled(v > lo + 0.001)
  c.right:SetEnabled(v < hi - 0.001)
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

local function isOn(b)
  return ns.aimConf(b) ~= nil
end

-- Ticked: holding the button opens the menu. Not ticked: it casts as it
-- always did.
local function setOn(b, on)
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

-- Cancel can't be a plain pad button that holds for the menu.
local function cancelTaken(key)
  return ns.db.aim[key] ~= nil
end

-- The Menu rows the mode has, in order.
local function menuRows()
  local mode = ns.db and ns.db.mode or "radial"
  local list = {}
  for _, key in ipairs(MENU_ROWS) do
    if not ONLY[key] or ONLY[key] == mode then
      table.insert(list, key)
    end
  end
  return list
end
local function menuIndex()
  local list = menuRows()
  for i, key in ipairs(list) do
    if key == st.mkey then
      return i, list
    end
  end
  return 1, list
end

-- Where the frames in use sit and their size: the menu, the plus or the
-- Buttons frames each have their own.
local function placeKeys()
  local _, _, _, p = ns.place()
  return p
end
local function atDefault()
  local p = placeKeys()
  local x, y = ns.db[p.x] or p.dx, ns.db[p.y] or p.dy
  return math.floor(x - p.dx + 0.5) == 0 and math.floor(y - p.dy + 0.5) == 0
end
local function nudge(dx, dy)
  local p = placeKeys()
  ns.db[p.x] = (ns.db[p.x] or p.dx) + dx
  ns.db[p.y] = (ns.db[p.y] or p.dy) + dy
end

---------------------------------------------------------------- what the controls do

local refresh, takeKeys

local function toggle(i)
  local r = rows[i]
  if not r or InCombatLockdown() then
    return
  end
  st.li = i
  setOn(r.bind, not isOn(r.bind))
end

local function stepTap(i, d)
  local r = rows[i]
  if not r or InCombatLockdown() then
    return
  end
  st.li = i
  local conf = ns.aimConf(r.bind)
  if not conf then
    return
  end
  conf.tap = wrap(ns.TAPS, conf.tap or "player", d)
  ns.applyKeys(true)
end

-- A tile row: d -1 is the left tile, 1 the right; 0 the other one.
local function pick(key, d)
  local t = TILES[key]
  local db = ns.db
  local v
  if d == 0 then
    v = db[t.db] == t.list[1] and t.list[2] or t.list[1]
  else
    v = d < 0 and t.list[1] or t.list[2]
  end
  if db[t.db] == v then
    return
  end
  db[t.db] = v
  if key == "mode" or key == "frames" then
    st.moving = false
    if ns.showMoving then
      ns.showMoving(false)
    end
    ns.applyMode()
  elseif key == "after" then
    ns.applyKeys(true)
  elseif key == "labels" and ns.redrawGrid then
    ns.redrawGrid()
  end
end

local function step(key, d)
  if InCombatLockdown() then
    return
  end
  local db = ns.db
  if TILES[key] then
    pick(key, d)
  elseif key == "look" then
    ns.setLook(wrap(ns.LOOKS, db.look, d))
  elseif key == "size" then
    local p = placeKeys()
    db[p.scale] = clamp(ns.tenth((db[p.scale] or p.size) + d * 0.1), SIZE_MIN, SIZE_MAX)
    ns.layout()
  elseif key == "spacing" then
    db.spacing = clamp(ns.tenth((db.spacing or 1) + d * 0.1), ns.SPACING_MIN, ns.SPACING_MAX)
    ns.layout()
  elseif key == "pick" then
    db.aimWith = wrap(ns.AIMERS, db.aimWith, d)
    ns.applyKeys(true)
  elseif key == "cancel" then
    -- a pad button that holds for the menu can't cancel: skipped
    local list = ns.cancels()
    local field = ns.isButtons() and "btnCancel" or "cancel"
    local c = db[field]
    for _ = 1, #list do
      c = wrap(list, c, d)
      if not cancelTaken(c) then
        break
      end
    end
    if not cancelTaken(c) then
      db[field] = c
      ns.applyKeys(true)
    end
  end
end

local function setMoving(on)
  st.moving = on == true
  if ns.showMoving then
    ns.showMoving(st.moving)
  end
end

-- Menu position: 1 is Move (Done while moving), 2 is Reset.
local function press(which)
  if InCombatLockdown() then
    return
  end
  if which == 1 then
    setMoving(not st.moving)
  elseif not atDefault() then
    local p = placeKeys()
    ns.db[p.x], ns.db[p.y] = p.dx, p.dy
    setMoving(false)
    st.sub = 1
    ns.layout()
  end
end

-- A click: the mouse drives now.
local function clicked(fn)
  return function()
    if InCombatLockdown() or not panel then
      return
    end
    st.keys = false
    fn()
    refresh()
  end
end

---------------------------------------------------------------- the window's place

-- The side of the screen the menu leaves free for the window: left when
-- there is room left of it, else right when there is room there, else
-- where it was. left, right: the menu's edges; screen: the screen's width.
local function sideFor(left, right, screen, was)
  if not left or not right or not screen then
    return was
  end
  if left >= EDGE + W + 2 then
    return "left"
  elseif right <= screen - EDGE - W - 2 then
    return "right"
  end
  return was
end

local function dock()
  if not panel then
    return
  end
  local l, r
  if ns.menuBox then
    l, r = ns.menuBox()
  end
  local okW, screen = pcall(UIParent.GetWidth, UIParent)
  st.side = sideFor(l, r, okW and tonumber(screen) or nil, st.side)
  panel:ClearAllPoints()
  if st.side == "right" then
    panel:SetPoint("RIGHT", UIParent, "RIGHT", -EDGE, 0)
  else
    panel:SetPoint("LEFT", UIParent, "LEFT", EDGE, 0)
  end
end

---------------------------------------------------------------- drawing

local function visibleRows()
  return math.min(#rows, MAX_ROWS)
end

local function drawTabs()
  if PanelTemplates_SetTab then
    PanelTemplates_SetTab(panel, st.tab == "menu" and 2 or 1)
  end
  ui.heals:SetShown(st.tab == "heals")
  ui.menu:SetShown(st.tab == "menu")
  -- the Menu rows the mode has, one under another
  local y = PAD
  local shown = {}
  for _, key in ipairs(menuRows()) do
    shown[key] = true
  end
  for _, f in ipairs(ui.mlist) do
    f:SetShown(shown[f.key] == true)
    if shown[f.key] then
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", ui.menu, "TOPLEFT", PAD, -y)
      y = y + f.h
    end
  end
  local inset = 2 * PAD + math.max(HEAD_H + math.max(1, visibleRows()) * ROW_H, y - PAD)
  panel:SetSize(W, inset + INSET_TOP + INSET_BOTTOM)
end

local function drawHeals()
  local visible = visibleRows()
  if st.li < st.top then
    st.top = st.li
  end
  if st.li > st.top + visible - 1 then
    st.top = st.li - visible + 1
  end
  st.top = clamp(st.top, 1, math.max(1, #rows - visible + 1))
  for i, f in ipairs(ui.rows) do
    local r = i <= visible and rows[st.top + i - 1]
    f.li = r and st.top + i - 1 or nil
    f:SetShown(r and true or false)
    if r then
      local b = r.bind
      local on = isOn(b)
      f.on = on
      f.check:SetChecked(on)
      f.icon:SetTexture(ns.spellIcon(b.spell))
      f.icon:SetDesaturated(not on)
      local v = on and 1 or 0.6
      f.icon:SetVertexColor(v, v, v)
      setText(f.hotkey, ns.bindLabel(b), ICON - 3)
      setText(f.name, ns.spellName(b.spell), NAME_W)
      setText(f.rank, ns.spellRank(b.spell), NAME_W)
      if on then
        f.name:SetTextColor(unpack(GOLD))
        f.rank:SetTextColor(0.74, 0.7, 0.6)
      else
        f.name:SetTextColor(0.56, 0.54, 0.49)
        f.rank:SetTextColor(0.44, 0.42, 0.38)
      end
      f.cycler:SetShown(on)
      if on then
        setText(f.cycler.value, ns.TAP_LABEL[ns.aimConf(b).tap] or ns.TAP_LABEL.player, TAP_W - 4)
      end
    end
  end
  ui.empty:SetShown(#rows == 0)
  setText(ui.headLeft, ns.isButtons() and "Buttons" or "Hold for menu", ROW_W - 2 * RP - CYCLER_W - 8)
  ui.headLeft:SetShown(#rows > 0)
  ui.headRight:SetShown(#rows > 0)
end

-- The words a cancel choice shows: A, B, X, Y in their colors, or the
-- controller's own button art.
local function cancelText(key)
  if CANCEL_NAME[key] then
    return keyText(CANCEL_NAME[key])
  end
  return ns.padIcon(key, 18)
end

local function drawTiles(f)
  local t = TILES[f.key]
  local v = ns.db[t.db]
  for i, tile in ipairs(f.tiles) do
    local on = t.list[i] == v
    tile.edge:SetShown(on)
    tile.word:SetTextColor(unpack(on and GOLD or { 0.75, 0.73, 0.68 }))
    tile.pic:SetAlpha(on and 1 or 0.55)
    if tile.draw then
      tile.draw(tile)
    end
  end
end

local function drawMenu()
  local db = ns.db
  local m = ui.mrows
  for key in pairs(TILES) do
    drawTiles(m[key])
  end
  setText(m.look.ctl.value, ns.LOOK_LABEL[db.look] or db.look, m.look.ctl.midW - 4)
  local scale = ns.place()
  setMeter(m.size.ctl, scale, SIZE_MIN, SIZE_MAX)
  setMeter(m.spacing.ctl, db.spacing or 1, ns.SPACING_MIN, ns.SPACING_MAX)
  setText(m.pick.ctl.value, ns.AIMER_LABEL[db.aimWith] or db.aimWith, m.pick.ctl.midW - 4)
  setText(m.cancel.ctl.value, cancelText(ns.cancelKey()), m.cancel.ctl.midW - 4)
  local move, reset = m.pos.move, m.pos.reset
  move:SetText(st.moving and "Done" or "Move")
  if st.moving then
    move:LockHighlight()
  else
    move:UnlockHighlight()
  end
  reset:SetEnabled(not atDefault())
  local okF, fs = pcall(move.GetFontString, move)
  if okF and type(fs) == "table" and fs.SetTextColor then
    fs:SetTextColor(unpack(st.moving and { 1, 1, 1 } or GOLD))
  end
end

-- What the pad is on: the lit row (on Menu position, the button) with a
-- gold edge, only while you drive with the pad or keys; otherwise the row
-- under the mouse is lit.
local function drawFocus()
  local focusHeal
  for _, f in ipairs(ui.rows) do
    if f:IsShown() and f.li == st.li then
      focusHeal = f
    end
  end
  local focusMenu = ui.mrows[st.mkey]
  local function light(list, focus)
    for _, f in ipairs(list) do
      f.lit:SetShown(st.keys and f == focus and f.key ~= "pos")
      f.hover:SetShown(not st.keys and st.hover == f)
    end
  end
  light(ui.rows, st.tab == "heals" and focusHeal or nil)
  light(ui.mlist, st.tab == "menu" and focusMenu or nil)
  local target
  if st.keys then
    if st.tab == "heals" then
      target = focusHeal
    elseif focusMenu then
      target = focusMenu.key == "pos" and (st.sub == 2 and focusMenu.reset or focusMenu.move) or focusMenu
    end
  end
  local r = ui.ring
  r.target = target
  if not target then
    r:Hide()
    return
  end
  local pad = target.isRow and 0 or 3
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
  r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
  r:Show()
end

-- The menu as the preview: titled with the heal the window is on, its tap
-- person in gold; faded out while that heal doesn't hold for the menu.
local function drawPreview()
  local b = current()
  local dim = false
  if st.tab == "heals" then
    local conf = b and ns.aimConf(b)
    ns.previewSpell = b and b.spell
    ns.previewTap = conf and conf.tap or "player"
    dim = b ~= nil and conf == nil
  else
    local first
    for _, r in ipairs(rows) do
      if not first and isOn(r.bind) then
        first = r.bind
      end
    end
    first = first or b
    ns.previewSpell = first and first.spell
    ns.previewTap = "target"
  end
  if ns.preview then
    ns.preview(true)
  end
  if ns.showMoving then
    ns.showMoving(st.moving)
  end
  if ns.previewDim then
    ns.previewDim(dim)
  end
end

refresh = function()
  if not panel or not panel:IsShown() then
    return
  end
  if st.tab ~= "menu" and st.moving then
    setMoving(false)
  end
  -- the row the pad was on went with the mode: back to Mode
  if ONLY[st.mkey] and ONLY[st.mkey] ~= ns.db.mode then
    st.mkey = "mode"
  end
  if st.sub == 2 and atDefault() then
    st.sub = 1
  end
  st.li = clamp(st.li, 1, math.max(1, #rows))
  drawTabs()
  drawHeals()
  drawMenu()
  drawFocus()
  drawPreview()
  dock()
end

-- After applyKeys: your bindings may have changed. The nav keys are taken
-- again, so a heal on A or B, just bound again, doesn't take them.
function ns.refreshOptions()
  if panel and panel:IsShown() then
    takeKeys()
    buildRows()
    refresh()
  end
end

---------------------------------------------------------------- input

local function cursor()
  local ok, x, y = pcall(GetCursorPosition)
  if ok then
    return x, y
  end
end

-- fromKeys false: the mouse. Otherwise a pad button or key, and the focus
-- shows.
local function nav(btn, fromKeys)
  if InCombatLockdown() or not panel or not panel:IsShown() then
    return
  end
  if fromKeys ~= false then
    st.keys = true
    st.cx, st.cy = cursor()
  end
  if btn == "ESC" then
    panel:Hide()
    return
  end
  -- Moving: the d-pad or arrows nudge the menu; A or B is done.
  if st.moving and btn ~= "LB" and btn ~= "RB" then
    local by = 20
    if btn == "UP" then
      nudge(0, by)
    elseif btn == "DOWN" then
      nudge(0, -by)
    elseif btn == "LEFT" then
      nudge(-by, 0)
    elseif btn == "RIGHT" then
      nudge(by, 0)
    elseif btn == "A" or btn == "B" then
      setMoving(false)
    end
    ns.layout()
    return refresh()
  end
  if btn == "LB" or btn == "RB" then
    local tab = btn == "RB" and "menu" or "heals"
    if tab ~= st.tab then
      st.tab = tab
      setMoving(false)
      if PlaySound and SOUNDKIT then
        pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
      end
    end
    return refresh()
  end
  if btn == "B" then
    panel:Hide()
    return
  end
  if btn == "UP" or btn == "DOWN" then
    local d = btn == "UP" and -1 or 1
    if st.tab == "heals" then
      st.li = clamp(st.li + d, 1, math.max(1, #rows))
    else
      local i, list = menuIndex()
      st.mkey = list[clamp(i + d, 1, #list)]
      st.sub = 1
    end
    return refresh()
  end
  local d = (btn == "LEFT" and -1) or (btn == "RIGHT" and 1) or nil
  if st.tab == "heals" then
    if d then
      stepTap(st.li, d)
    elseif btn == "A" then
      toggle(st.li)
    end
  else
    local key = st.mkey
    if key == "pos" then
      if d then
        st.sub = clamp(st.sub + d, 1, 2)
      elseif btn == "A" then
        press(st.sub)
      end
    elseif d then
      step(key, d)
    elseif btn == "A" then
      step(key, TILES[key] and 0 or 1)
    end
  end
  refresh()
end
ns.optionsNav = nav

-- While moving, either stick glides the menu. And while the focus shows, a
-- moving mouse hands the window back to the mouse.
local SPEED = 700 -- screen units a second at full tilt
local glide = CreateFrame("Frame")
glide:SetScript("OnUpdate", function(_, elapsed)
  if not panel or not panel:IsShown() then
    return
  end
  if st.keys then
    local x, y = cursor()
    if x and st.cx and (x ~= st.cx or y ~= st.cy) then
      st.keys = false
      refresh()
    end
  end
  if not st.moving then
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
  nudge(dx * SPEED * elapsed, dy * SPEED * elapsed)
  ns.layout()
  dock()
end)

-- While the window is open these keys drive it; they go back when it closes.
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

-- A row: the mouse lights it softly; the pad lights it and edges it in gold.
local function row(parent, y)
  local f = hit(parent)
  f:SetSize(ROW_W, ROW_H)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
  f.isRow = true
  f.hover = f:CreateTexture(nil, "BACKGROUND")
  f.hover:SetTexture(HILIGHT)
  f.hover:SetBlendMode("ADD")
  f.hover:SetVertexColor(1, 0.82, 0, 0.35)
  f.hover:SetAllPoints()
  f.hover:Hide()
  f.lit = f:CreateTexture(nil, "BACKGROUND")
  f.lit:SetTexture(HILIGHT)
  f.lit:SetBlendMode("ADD")
  f.lit:SetVertexColor(1, 0.82, 0, 0.8)
  f.lit:SetAllPoints()
  f.lit:Hide()
  return f
end

-- The mouse over a row or anything in it lights the row; on Heals the
-- preview follows it.
local function hovers(f, part)
  part:SetScript("OnEnter", function()
    if st.keys then
      return
    end
    st.hover = f
    if f.li and not InCombatLockdown() then
      st.li = f.li
    end
    refresh()
  end)
  part:SetScript("OnLeave", function()
    if st.hover == f then
      st.hover = nil
      f.hover:Hide()
    end
  end)
end

local function checkbox(parent)
  local ok, check = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
  if ok and check then
    return check
  end
  -- the same art, by hand
  check = CreateFrame("CheckButton", nil, parent)
  check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return check
end

local function buildHeals(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  ui.headLeft = text(t, "GameFontNormal", 13, GOLD_SOFT)
  ui.headLeft:SetPoint("LEFT", t, "TOPLEFT", PAD + RP, -(PAD + HEAD_H / 2))
  ui.headLeft:SetJustifyH("LEFT")
  setText(ui.headLeft, "Hold for menu", ROW_W - 2 * RP - CYCLER_W - 8)
  ui.headRight = text(t, "GameFontNormal", 13, GOLD_SOFT)
  ui.headRight:SetPoint("CENTER", t, "TOPRIGHT", -(PAD + RP + CYCLER_W / 2), -(PAD + HEAD_H / 2))
  setText(ui.headRight, "Quick tap heals", CYCLER_W)
  ui.rows = {}
  for i = 1, MAX_ROWS do
    local f = row(t, PAD + HEAD_H + (i - 1) * ROW_H)
    local check = checkbox(f)
    check:SetSize(CHECK, CHECK)
    check:SetPoint("LEFT", f, "LEFT", RP - 2, 0)
    f.check = check
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(ICON, ICON)
    f.icon:SetPoint("LEFT", f, "LEFT", RP + CHECK + 8, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local edge = ns.outline(f, f.icon, 1, 1)
    edge:SetColor(0.36, 0.33, 0.27, 1)
    edge:Show()
    -- the key in the corner, as on an action button
    f.hotkey = text(f, "NumberFontNormalSmallGray", nil, { 0.9, 0.9, 0.9 })
    f.hotkey:SetPoint("TOPRIGHT", f.icon, "TOPRIGHT", -1, -2)
    f.hotkey:SetJustifyH("RIGHT")
    f.hotkey:SetDrawLayer("OVERLAY", 2)
    f.name = text(f, "GameFontNormal", 14)
    f.name:SetPoint("BOTTOMLEFT", f, "LEFT", NAME_X, 0)
    f.name:SetJustifyH("LEFT")
    f.rank = text(f, "GameFontHighlightSmall", 11)
    f.rank:SetPoint("TOPLEFT", f, "LEFT", NAME_X, -2)
    f.rank:SetJustifyH("LEFT")
    f.cycler = cycler(f, CYCLER_W)
    f.cycler:SetPoint("RIGHT", f, "RIGHT", -RP, 0)
    f.cycler.value = text(f.cycler.mid, "GameFontHighlight", 13)
    f.cycler.value:SetPoint("CENTER")
    local function tick()
      toggle(f.li)
    end
    f:SetScript("OnClick", clicked(tick))
    check:SetScript("OnClick", clicked(tick))
    for _, part in ipairs({ { f.cycler.left, -1 }, { f.cycler.right, 1 }, { f.cycler.mid, 1 } }) do
      part[1]:SetScript(
        "OnClick",
        clicked(function()
          stepTap(f.li, part[2])
        end)
      )
    end
    for _, part in ipairs({ f, check, f.cycler.left, f.cycler.right, f.cycler.mid }) do
      hovers(f, part)
    end
    ui.rows[i] = f
  end
  ui.empty = text(t, "GameFontDisable", nil)
  ui.empty:SetPoint("TOPLEFT", t, "TOPLEFT", PAD + RP, -(PAD + 10))
  setText(ui.empty, "No heals on your buttons", ROW_W - 2 * RP)
  -- the wheel scrolls a long list
  t:EnableMouseWheel(true)
  t:SetScript("OnMouseWheel", function(_, delta)
    st.keys = false
    st.top = clamp(st.top - (delta > 0 and 1 or -1), 1, math.max(1, #rows - visibleRows() + 1))
    st.li = clamp(st.li, st.top, st.top + math.max(1, visibleRows()) - 1)
    refresh()
  end)
  return t
end

-- Pictures on the tiles: small shapes, nothing that moves.
local function shape(pic, x, y, w, h, color, layer)
  local t = pic:CreateTexture(nil, layer or "ARTWORK")
  t:SetPoint("TOPLEFT", pic, "TOPLEFT", x, -y)
  t:SetSize(w, h)
  t:SetColorTexture(unpack(color))
  return t
end
local DARK, GREEN, FRAME = { 0.16, 0.15, 0.13, 1 }, { 0.27, 0.75, 0.24, 1 }, { 0.42, 0.39, 0.33, 1 }
-- A little party frame: a dark box with a green bar.
local function miniFrame(pic, x, y, w, h)
  shape(pic, x, y, w, h, FRAME)
  shape(pic, x + 1, y + 1, w - 2, h - 2, DARK, "ARTWORK")
  shape(pic, x + 2, y + h - 4, (w - 4) * 0.7, 2, GREEN, "OVERLAY")
end
local PICTURES = {
  radial = function(pic)
    for _, at in ipairs({ { 41, 2 }, { 25, 15 }, { 57, 15 }, { 41, 28 } }) do
      shape(pic, at[1], at[2], 14, 10, FRAME)
    end
    shape(pic, 41, 15, 14, 10, { GOLD[1], GOLD[2], GOLD[3], 1 })
  end,
  buttons = function(pic)
    for i = 0, 2 do
      shape(pic, 24, 4 + i * 11, 40, 8, FRAME)
      shape(pic, 68, 5 + i * 11, 6, 6, { GOLD[1], GOLD[2], GOLD[3], 1 })
    end
  end,
  plus = function(pic)
    for _, at in ipairs({ { 36, 1 }, { 14, 14 }, { 36, 14 }, { 58, 14 }, { 36, 27 } }) do
      miniFrame(pic, at[1], at[2], 22, 11)
    end
  end,
  game = function(pic)
    for i = 0, 3 do
      miniFrame(pic, 10, 1 + i * 10, 26, 9)
    end
  end,
  once = function(pic)
    for i = 0, 2 do
      shape(pic, 28, 4 + i * 11, 40, 8, i == 1 and { GOLD[1], GOLD[2], GOLD[3], 1 } or FRAME)
    end
  end,
  locked = function(pic)
    for i = 0, 2 do
      shape(pic, 22, 4 + i * 11, 40, 8, { GOLD[1], GOLD[2], GOLD[3], 1 })
    end
    local l = pic:CreateTexture(nil, "ARTWORK")
    l:SetPoint("TOPLEFT", pic, "TOPLEFT", 66, -10)
    l:SetSize(14, 18)
    if not pcall(l.SetAtlas, l, "AdventureMapIcon-Lock") then
      l:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    end
  end,
}
-- Labels: the picture is the label itself, in the controller's button art.
local LABEL_TEXT = {
  row = function()
    return ns.padIcon("PAD1", 20)
  end,
  full = function()
    return ns.padIcon("PADLSHOULDER", 20) .. " + " .. ns.padIcon("PAD1", 20)
  end,
}

local function tile(f, key, i)
  local t = TILES[key]
  local v = t.list[i]
  local b = hit(f)
  b:SetSize(TILE_W, TILE_H)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.06, 0.055, 0.05, 0.9)
  b.edge = ns.outline(b, b, 0, 2)
  b.edge:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
  b.pic = CreateFrame("Frame", nil, b)
  b.pic:SetSize(TILE_W, 40)
  b.pic:SetPoint("TOP", b, "TOP", 0, -2)
  if PICTURES[v] then
    PICTURES[v](b.pic)
  elseif LABEL_TEXT[v] then
    local fs = text(b.pic, "GameFontHighlight", 14)
    fs:SetPoint("CENTER")
    b.draw = function()
      setText(fs, LABEL_TEXT[v](), TILE_W - 8)
    end
  end
  b.word = text(b, "GameFontNormal", 13)
  b.word:SetPoint("BOTTOM", b, "BOTTOM", 0, 5)
  setText(b.word, t.label[v], TILE_W - 8)
  b.value = v
  return b
end

local function buildMenu(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetAllPoints()
  ui.mrows, ui.mlist = {}, {}
  for i, key in ipairs(MENU_ROWS) do
    local f = row(t, PAD + (i - 1) * ROW_H)
    f.key = key
    f.h = TILES[key] and TILE_ROW_H or ROW_H
    f:SetHeight(f.h)
    f.label = text(f, "GameFontNormal", 15)
    f.label:SetPoint("LEFT", f, "LEFT", RP, 0)
    f.label:SetJustifyH("LEFT")
    local room = TILES[key] and (ROW_W - 2 * RP - (2 * TILE_W + TILE_GAP) - 8) or LABEL_W
    setText(f.label, MENU_LABEL[key], room)
    local function focusHere()
      st.mkey = key
    end
    if TILES[key] then
      f.tiles = {}
      for n = 1, 2 do
        local b = tile(f, key, n)
        b:SetPoint("RIGHT", f, "RIGHT", -RP - (2 - n) * (TILE_W + TILE_GAP), 0)
        b:SetScript(
          "OnClick",
          clicked(function()
            focusHere()
            step(key, n == 1 and -1 or 1)
          end)
        )
        hovers(f, b)
        f.tiles[n] = b
      end
    elseif key == "pos" then
      f.move = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      f.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      for n, b in ipairs({ f.move, f.reset }) do
        b:SetSize(BTN_W, 24)
        b:SetPoint("RIGHT", f, "RIGHT", -RP - (2 - n) * (BTN_W + BTN_GAP), 0)
        b:SetScript(
          "OnClick",
          clicked(function()
            focusHere()
            st.sub = n
            press(n)
          end)
        )
        hovers(f, b)
      end
      f.move:SetText("Move")
      f.reset:SetText("Reset")
    else
      local c = cycler(f, CTL_W)
      c:SetPoint("RIGHT", f, "RIGHT", -RP, 0)
      f.ctl = c
      if key == "size" or key == "spacing" then
        meter(c)
      else
        c.value = text(c.mid, "GameFontHighlight", key == "cancel" and 16 or 14)
        c.value:SetPoint("CENTER")
      end
      for _, part in ipairs({ { c.left, -1 }, { c.right, 1 }, { c.mid, 1 } }) do
        part[1]:SetScript(
          "OnClick",
          clicked(function()
            focusHere()
            step(key, part[2])
          end)
        )
        hovers(f, part[1])
      end
    end
    f:SetScript("OnClick", clicked(focusHere))
    hovers(f, f)
    ui.mrows[key] = f
    ui.mlist[i] = f
  end
  return t
end

local function build()
  panel = CreateFrame("Frame", "HealpadOptions", UIParent, "ButtonFrameTemplate")
  panel:SetSize(W, 400)
  panel:SetPoint("LEFT", UIParent, "LEFT", EDGE, 0)
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
    inset:SetPoint("TOPLEFT", INSET_X, -INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", -6, INSET_BOTTOM)
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
    tab:SetScript(
      "OnClick",
      clicked(function()
        if st.tab ~= t then
          st.tab = t
          setMoving(false)
          if PlaySound and SOUNDKIT then
            pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
          end
        end
      end)
    )
    ui.tabs[i] = tab
  end
  if PanelTemplates_SetNumTabs then
    PanelTemplates_SetNumTabs(panel, #TABS)
  end

  ui.heals = buildHeals(body)
  ui.menu = buildMenu(body)

  ui.ring = ns.outline(panel, panel, 0, 2)
  ui.ring:SetColor(1, 0.82, 0, 1)
  ui.ring:SetFrameLevel((panel:GetFrameLevel() or 0) + 30)

  panel:SetScript("OnShow", function()
    st.keys, st.hover = false, nil
    setMoving(false)
    takeKeys()
    -- a short fade in
    panel.a = 0
    ns.kit.fadeTo(panel, 1, 0.15)
  end)
  panel:SetScript("OnHide", function()
    giveKeys()
    setMoving(false)
    ns.previewSpell, ns.previewTap = nil, nil
    if ns.preview then
      ns.preview(false)
    end
    if ns.db then
      for _, p in pairs(ns.PLACES) do
        for _, k in ipairs({ p.x, p.y }) do
          if type(ns.db[k]) == "number" then
            ns.db[k] = math.floor(ns.db[k] + 0.5)
          end
        end
      end
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
  panel:Show()
  refresh()
  -- the menu's place on the screen is known once the game has laid it out
  if C_Timer and C_Timer.After then
    C_Timer.After(0, dock)
  end
end
function ns.optionsPanel()
  return panel
end
-- For /hp test, /hp shots and the tests: the parts and the state.
function ns.optionsDebug()
  return {
    panel = panel,
    ui = ui,
    st = st,
    rows = rows,
    fitted = fitted,
    sideFor = sideFor,
    -- the heal row's number, or the Menu row's name (move or reset on Menu position)
    focus = function()
      if st.tab == "heals" then
        return st.li
      end
      local key = st.mkey
      if key == "pos" then
        return st.sub == 2 and "reset" or "move"
      end
      return key
    end,
    layout = { W = W, ROW_W = ROW_W, CTL_W = CTL_W, LABEL_W = LABEL_W, NAME_W = NAME_W, TAP_W = TAP_W },
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
  if cmd == "probe" then
    if ns.probe then
      ns.probe(msg:lower():match("^%s*probe%s+(%S+)"))
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
