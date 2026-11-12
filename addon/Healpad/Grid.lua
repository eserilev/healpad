-- Buttons mode's frames: your party as a column of five, a raid as all
-- eight groups in two blocks of four columns, in the old party and raid
-- frames' place. Rows and groups read as they press: row 1 is A, a group's
-- column is its shoulder, trigger or d-pad direction.
--
-- A tapped heal lights every frame gold, puts the heal's name above them
-- and each frame's button on it (Labels: just the row, or the whole combo).
-- A group held lights its column and dims the rest. Plain frames: they show,
-- hide and change in combat. Clicks go to the secure seat buttons laid over
-- them (Seats.lua), placed out of combat only.
local _, ns = ...
local K = ns.kit

local CELL_W, CELL_H, GAP = 132, 36, 4
local HEAD_H, BLOCK_GAP = 16, 10
local GOLD = { 1, 0.82, 0 }

local grid = CreateFrame("Frame", "HealpadGrid", UIParent)
grid:SetSize(1, 1)
grid:SetFrameStrata("MEDIUM")
grid:Hide()
ns.grid = grid

local title = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("BOTTOMLEFT", grid, "TOPLEFT", 22, 6)
title:SetWordWrap(false)
local lock = grid:CreateTexture(nil, "OVERLAY")
lock:SetSize(14, 18)
lock:SetPoint("RIGHT", title, "LEFT", -6, 0)
if not pcall(lock.SetAtlas, lock, "AdventureMapIcon-Lock") then
  lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
end
lock:Hide()

-- The edge while moving it in the settings.
local box = ns.outline(grid, grid, 4, 1)
box:SetColor(1, 0.82, 0, 1)
local moving = false

---------------------------------------------------------------- a frame

local function makeCell(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(CELL_W, CELL_H)
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetAllPoints()
  f.med = f.body
  local bg = f.body:CreateTexture(nil, "BACKGROUND", nil, 0)
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.05, 0.06, 0.85)
  f.health = K.healthBar(f.body, CELL_W - 2, CELL_H - 2)
  f.health:SetPoint("TOPLEFT", 1, -1)
  f.health.back:SetColorTexture(0.12, 0.12, 0.13, 1)
  f.stripe = f.body:CreateTexture(nil, "ARTWORK", nil, 3)
  f.stripe:SetPoint("TOPLEFT", 1, -1)
  f.stripe:SetPoint("BOTTOMLEFT", 1, 1)
  f.stripe:SetWidth(4)
  local over = CreateFrame("Frame", nil, f.body)
  over:SetAllPoints()
  over:SetFrameLevel(f.health:GetFrameLevel() + 3)
  f.over = over
  f.name = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.name:SetPoint("TOPLEFT", 8, -4)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.miss = over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.miss:SetPoint("BOTTOMLEFT", 8, 4)
  f.miss:SetJustifyH("LEFT")
  f.label = over:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.label:SetPoint("TOPRIGHT", -4, -3)
  f.label:SetJustifyH("RIGHT")
  f.label:SetWordWrap(false)
  f.state = K.stateIcon(over, 22)
  f.state:SetPoint("CENTER")
  f.gold = ns.outline(over, f, 0, 2)
  f.gold:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
  K.indicators(f, {
    host = over,
    edge = f,
    pad = 2,
    size = 12,
    debuffs = { "BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3 },
    debuffsGrow = -1,
    hots = { "BOTTOMRIGHT", f, "BOTTOMRIGHT", -33, 3 },
    hotsGrow = -1,
    top = f,
    rez = f,
    rezSize = 22,
    buff = { "TOPLEFT", f, "TOPLEFT", -3, 3 },
    buffSize = 9,
  })
  f:Hide()
  return f
end

local cells = {} -- [group][row]
local heads = {} -- [group] = { frame, key, num }
for g = 1, 8 do
  cells[g] = {}
  for r = 1, 5 do
    cells[g][r] = makeCell(grid)
  end
  local h = CreateFrame("Frame", nil, grid)
  h:SetSize(CELL_W, HEAD_H)
  h.num = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h.num:SetPoint("LEFT", 2, 0)
  h.key = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h.key:SetPoint("LEFT", h.num, "RIGHT", 6, 0)
  h.key:SetWordWrap(false)
  h.num:SetText(tostring(g))
  h:Hide()
  heads[g] = h
end
ns.gridCells = cells
ns.gridHeads = heads

-- Where group g's row r sits from the grid's top left: { x, y }.
local function cellAt(raid, g, r)
  if not raid then
    return 0, -(r - 1) * (CELL_H + GAP)
  end
  local col = (g - 1) % 4
  local block = math.floor((g - 1) / 4)
  local blockH = HEAD_H + 5 * (CELL_H + GAP)
  return col * (CELL_W + GAP), -(block * (blockH + BLOCK_GAP) + HEAD_H + (r - 1) * (CELL_H + GAP))
end
local function headAt(g)
  local col = (g - 1) % 4
  local block = math.floor((g - 1) / 4)
  local blockH = HEAD_H + 5 * (CELL_H + GAP)
  return col * (CELL_W + GAP), -(block * (blockH + BLOCK_GAP))
end

local laidRaid -- the shape laid out last: raid or not

local function arrange(raid)
  laidRaid = raid
  for g = 1, 8 do
    for r = 1, 5 do
      local f = cells[g][r]
      local x, y = cellAt(raid, g, r)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", grid, "TOPLEFT", x, y)
    end
    local hx, hy = headAt(g)
    heads[g]:ClearAllPoints()
    heads[g]:SetPoint("TOPLEFT", grid, "TOPLEFT", hx, hy)
  end
  if raid then
    grid:SetSize(4 * CELL_W + 3 * GAP, 2 * (HEAD_H + 5 * (CELL_H + GAP)) + BLOCK_GAP)
  else
    grid:SetSize(CELL_W, 5 * (CELL_H + GAP) - GAP)
  end
end
arrange(false)

---------------------------------------------------------------- labels

-- The words (or the controller's button art) a frame shows while a heal
-- waits: its row, or its group and row.
function ns.seatLabel(raid, g, r, style)
  if not raid then
    return ns.padIcon(ns.PARTY_ROW_KEYS[r])
  end
  local row = ns.padIcon(ns.RAID_ROW_KEYS[r])
  if style == "row" then
    return row
  end
  return ns.padIcon(ns.GROUP_KEYS[g]) .. " + " .. row
end

local function textWidth(fs)
  local ok, w = pcall(fs.GetStringWidth, fs)
  return ok and tonumber(w) or 0
end

---------------------------------------------------------------- placing

-- Out of combat: where the grid sits and its size.
function ns.layoutGrid()
  local scale, x, y = ns.place("grid")
  grid:SetScale(scale)
  grid:ClearAllPoints()
  grid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
end

-- Example people for the settings' preview when you're not in a group.
local SAMPLE = {
  { name = nil, class = nil, hp = 0.84 },
  { name = "Thrain", class = "WARRIOR", hp = 0.46, inc = 0.14, miss = 1620, hot = true },
  { name = "Mirelle", class = "PRIEST", hp = 0.92, miss = 240, dispel = { 0.2, 0.6, 1, 1 } },
  { name = "Kesh", class = "ROGUE", hp = 0.3, miss = 2100 },
  { name = "Brannoc", class = "MAGE", hp = 0.68, miss = 960, far = true },
}

local function previewing()
  return ns.previewing and ns.previewing() or false
end

-- The unit in group g's row r: the controller's attributes, as the secure
-- code reads them.
local function unitAt(raid, g, r)
  if raid then
    return ns.ctl:GetAttribute("g" .. g .. "-" .. r)
  end
  if g ~= 1 then
    return nil
  end
  return ns.ctl:GetAttribute("p" .. r)
end

-- The secure seat buttons over the cells, out of combat.
local seats = CreateFrame("Frame", "HealpadGridSeats", UIParent, "SecureFrameTemplate")
seats:SetSize(1, 1)
seats:Hide()
ns.gridSeats = {}
for g = 1, 8 do
  ns.gridSeats[g] = {}
  for r = 1, 5 do
    ns.gridSeats[g][r] = ns.seatButton("HealpadGridSeat" .. g .. "x" .. r, seats)
  end
end

function ns.placeGrid()
  if not ns.isButtons() then
    seats:Hide()
    return
  end
  local raid = ns.ctl:GetAttribute("raid") == true
  local scale, x, y = ns.place("grid")
  seats:SetScale(scale)
  seats:ClearAllPoints()
  seats:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
  for g = 1, 8 do
    for r = 1, 5 do
      local b = ns.gridSeats[g][r]
      local unit = unitAt(raid, g, r)
      if unit then
        local cx, cy = cellAt(raid, g, r)
        b:SetAttribute("unit", unit)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", seats, "TOPLEFT", cx, cy)
        b:SetSize(CELL_W, CELL_H)
        b:Show()
      else
        b:Hide()
        b:SetAttribute("unit", nil)
      end
    end
  end
  seats:Show()
end

---------------------------------------------------------------- drawing

local function drawCell(f, src, ctx)
  f:Show()
  local status, far = K.person(f, src, ctx, 0.45)
  local r, g, b = K.classColor(src)
  f.stripe:SetColorTexture(r, g, b, 1)
  K.byHealth(src, "hp", function(hr, hg, hb, ha)
    f.health:SetStatusBarColor(hr, hg, hb, ha)
  end)
  if status then
    f.miss:SetText("")
    f.name:SetTextColor(0.5, 0.5, 0.5)
  else
    K.missing(f.miss, src)
    -- light ink on the dark frame
    K.byHealth(src, "missLight", function(mr, mg, mb, ma)
      f.miss:SetTextColor(mr, mg, mb, ma)
    end)
    f.name:SetTextColor(1, 1, 1)
  end
  if far then
    f.body:SetAlpha(0.45)
  end
  -- the label while a heal waits, and the name in the room beside it
  local label = ctx.armed and ctx.label or ""
  f.label:SetText(label)
  f.label:SetShown(label ~= "")
  local room = CELL_W - 12 - (label ~= "" and (textWidth(f.label) + 6) or 0)
  f.name:SetWidth(math.max(10, room))
  f.gold:SetShown(ctx.armed == true)
end

local dirty = false
local function heldSpell()
  return ns.ctl:GetAttribute("armed")
end

function ns.redrawGrid()
  dirty = false
  if not grid:IsShown() then
    return
  end
  local ctl = ns.ctl
  local raid = ctl:GetAttribute("raid") == true
  local preview = previewing() and not IsInGroup()
  if raid ~= laidRaid then
    arrange(raid)
  end
  local spell = heldSpell()
  local armed = spell ~= nil or preview
  local shown = spell or (preview and ns.previewSpell)
  title:SetText(shown and ns.spellLabel(shown) or "")
  lock:SetShown(spell ~= nil and ctl:GetAttribute("lockmode") == true)
  local held = ctl:GetAttribute("grp")
  local style = ns.db and ns.db.labels or "full"
  for g = 1, 8 do
    local inUse = raid or g == 1
    local h = heads[g]
    h:SetShown(raid)
    if raid then
      h.key:SetText(armed and ns.padIcon(ns.GROUP_KEYS[g], 14) or "")
      local c = held == g and GOLD or { 0.8, 0.8, 0.8 }
      h.num:SetTextColor(c[1], c[2], c[3])
    end
    local dim = raid and held ~= nil and held ~= g
    for r = 1, 5 do
      local f = cells[g][r]
      local src
      if preview and g == 1 then
        src = SAMPLE[r]
        src.kind = "sample"
        if r == 1 then
          local okN, me = pcall(UnitName, "player")
          local okC, _, class = pcall(UnitClass, "player")
          src.name = okN and me or "You"
          src.class = okC and class or nil
        end
      elseif inUse then
        local unit = unitAt(raid, g, r)
        if unit and UnitExists(unit) then
          src = { kind = "unit", unit = unit }
        elseif unit or raid then
          -- an empty place in a raid's group, or someone gone mid-fight
          src = { kind = "empty", name = (unit and ns.SEAT_BY_NAME) and unit or "" }
        end
      end
      if src then
        local ok, err = pcall(drawCell, f, src, {
          spell = spell or (preview and ns.previewSpell) or nil,
          armed = armed,
          label = ns.seatLabel(raid, g, r, style),
        })
        if not ok then
          ns.log("ERROR in grid: " .. tostring(err))
        end
        f:SetAlpha(dim and 0.55 or 1)
      else
        f:Hide()
      end
    end
  end
end

---------------------------------------------------------------- showing

-- Shown while Buttons mode is on.
function ns.applyGrid()
  local on = ns.isButtons()
  grid:SetShown(on)
  ns.layoutGrid()
  ns.redrawGrid()
end

-- The settings' Move: the grid can be dragged, a thin gold edge round it.
function ns.gridMoving(on)
  moving = on == true and ns.isButtons()
  box:SetShown(moving)
  grid:EnableMouse(moving)
end
grid:SetMovable(true)
grid:SetScript("OnMouseDown", function(_, b)
  if moving and b == "LeftButton" and not InCombatLockdown() then
    grid:StartMoving()
  end
end)
grid:SetScript("OnMouseUp", function()
  grid:StopMovingOrSizing()
  if not ns.db then
    return
  end
  local l, t = grid:GetLeft(), grid:GetTop()
  local top = UIParent:GetTop()
  if l and t and top then
    local k = grid:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local _, _, _, p = ns.place("grid")
    ns.db[p.x] = math.floor(l * k + 0.5)
    ns.db[p.y] = math.floor(t * k - top + 0.5)
  end
  ns.layoutGrid()
  ns.placeSeats()
  if ns.refreshOptions then
    ns.refreshOptions()
  end
end)

-- Where the grid is on the screen, for the settings to keep clear of it.
function ns.gridBox()
  local ok, l, r, t, b = pcall(function()
    return grid:GetLeft(), grid:GetRight(), grid:GetTop(), grid:GetBottom()
  end)
  if not ok or type(l) ~= "number" or type(r) ~= "number" then
    return nil
  end
  local k = 1
  pcall(function()
    k = grid:GetEffectiveScale() / UIParent:GetEffectiveScale()
  end)
  return l * k, r * k, (t or 0) * k, (b or 0) * k
end

ns.ctl:HookScript("OnAttributeChanged", function(_, name)
  if name == "state" or name == "armed" or name == "grp" or name == "lockmode" then
    ns.redrawGrid()
  end
end)

local ticker = CreateFrame("Frame")
local since = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
  if not grid:IsShown() then
    return
  end
  since = since + elapsed
  if (dirty and since > 0.1) or since > 0.5 then
    since = 0
    ns.redrawGrid()
  end
end)
for _, e in ipairs({
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_HEAL_PREDICTION",
  "UNIT_AURA",
  "UNIT_CONNECTION",
  "UNIT_FLAGS",
  "UNIT_NAME_UPDATE",
  "UNIT_THREAT_SITUATION_UPDATE",
  "INCOMING_RESURRECT_CHANGED",
}) do
  ns.on(e, function()
    dirty = true
  end)
end
