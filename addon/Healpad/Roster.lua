-- Who sits where.
--
-- The menu that shows only while you hold a heal (Radial, Party Frames:
-- Game) is as it always was: tank up, you in the middle, the others by role
-- and name, by unit token, rebuilt out of combat (ns.buildPages).
--
-- The frames that stay on screen (Plus, Buttons) seat people instead: a
-- seat belongs to a person: it is handed out out of combat,
-- in the game's party (or raid) order, and kept. Someone who leaves frees
-- their seat and nobody else moves; someone new takes a free seat. Nothing
-- moves in combat: a seat whose person left goes dark until the fight ends.
--
-- A group's five seats are, in order: the middle (you, in your own group),
-- up, right, down, left. In Buttons mode the same order is rows 1 to 5.
-- A raid has one page per group, your own group first.
local _, ns = ...

-- The secure buttons name a seat's person by name ("Thrain", or
-- "Thrain-Realm" from another realm), so the seat follows them even when
-- the game renumbers party1..party4 or raid1..raid40 mid-fight.
-- UNVERIFIED in game: that the client's secure code accepts a group
-- member's name as a unit (for the cast, the [@unit,help,nodead] check and
-- the unit buttons). /hp probe reads it. If it doesn't, set this to false:
-- seats then hold unit tokens, which the game renumbers when someone leaves
-- in combat (the rest shift until combat ends).
ns.SEAT_BY_NAME = true

ns.SEAT_DIRS = { "SELF", "UP", "RIGHT", "DOWN", "LEFT" }
ns.SEAT_OF_DIR = { SELF = 1, UP = 2, RIGHT = 3, DOWN = 4, LEFT = 5 }

-- What a seat's secure attributes hold for a member: you are "player";
-- someone whose name the game doesn't know yet ("Unknown"), or whose name
-- another member shares, keeps the unit token.
function ns.seatUnit(m)
  if m.me then
    return "player"
  end
  if ns.SEAT_BY_NAME and m.name then
    return m.name
  end
  return m.unit
end

---------------------------------------------------------------- the menu while held

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local AROUND = { "UP", "RIGHT", "DOWN", "LEFT" }

local function before(a, b)
  local ra, rb = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
  if ra ~= rb then
    return ra < rb
  end
  local na, nb = a.name or a.unit, b.name or b.unit
  if na ~= nb then
    return na < nb
  end
  return a.unit < b.unit
end

-- members: { unit, role, name, group, me } for everyone in the group.
-- Returns pages { [dir] = unit token }, and the first tank's unit or nil.
function ns.buildPages(members, solo)
  if solo then
    return { { UP = "target", SELF = "player" } }, nil
  end
  local groups, mine = {}, nil
  local tank
  for _, m in ipairs(members) do
    local g = m.group or 1
    groups[g] = groups[g] or {}
    table.insert(groups[g], m)
    if m.me then
      mine = g
    end
    if m.role == "TANK" and not m.me and (not tank or before(m, tank)) then
      tank = m
    end
  end
  local order = {}
  if mine then
    table.insert(order, mine)
  end
  for g = 1, 8 do
    if groups[g] and g ~= mine then
      table.insert(order, g)
    end
  end
  local pages = {}
  for _, g in ipairs(order) do
    local list, page = {}, {}
    for _, m in ipairs(groups[g]) do
      if m.me then
        page.SELF = m.unit
      else
        table.insert(list, m)
      end
    end
    table.sort(list, before)
    for i, m in ipairs(list) do
      local dir = AROUND[i] or (not page.SELF and "SELF")
      if dir then
        page[dir] = m.unit
      end
    end
    table.insert(pages, page)
  end
  return pages, tank and tank.unit
end

---------------------------------------------------------------- seats that belong to people

-- members: { unit, name, group, me, role } in the game's order.
-- prev: the last seats, { [group] = { [seat] = { name, unit } } } (or nil):
-- a member keeps a seat by name, or by unit token while the game didn't
-- know their name.
-- Returns seats { [group] = { [seat] = member } } and your group.
function ns.buildSeats(members, prev)
  prev = prev or {}
  local groups, mine = {}, nil
  for _, m in ipairs(members) do
    local g = m.group or 1
    groups[g] = groups[g] or {}
    table.insert(groups[g], m)
    if m.me then
      mine = g
    end
  end
  local seats = {}
  for g, list in pairs(groups) do
    local res, placed = {}, {}
    for _, m in ipairs(list) do
      if m.me then
        res[1] = m
        placed[m] = true
      end
    end
    local was = prev[g] or {}
    for i = 1, 5 do
      local w = was[i]
      if w and not res[i] then
        for _, m in ipairs(list) do
          local same = (w.name and m.name == w.name) or (not w.name and m.unit == w.unit)
          if not placed[m] and same then
            res[i] = m
            placed[m] = true
            break
          end
        end
      end
    end
    for _, m in ipairs(list) do
      if not placed[m] then
        for i = 1, 5 do
          if not res[i] then
            res[i] = m
            placed[m] = true
            break
          end
        end
      end
    end
    seats[g] = res
  end
  return seats, mine
end

-- Who is in each seat, to keep them there next time.
function ns.seatNames(seats)
  local out = {}
  for g, res in pairs(seats) do
    out[g] = {}
    for i, m in pairs(res) do
      out[g][i] = { name = m.name, unit = m.unit }
    end
  end
  return out
end

-- The groups as pages: your group first, then the others in order.
function ns.pageGroups(seats, mine)
  local order = {}
  if mine and seats[mine] then
    table.insert(order, mine)
  end
  for g = 1, 8 do
    if seats[g] and g ~= mine then
      table.insert(order, g)
    end
  end
  return order
end

-- The tank: the first one marked (Main Tank or the role) in the game's
-- order who isn't you.
function ns.findTank(members)
  for _, m in ipairs(members) do
    if m.role == "TANK" and not m.me then
      return m
    end
  end
end

-- The raid's Main Tank, else the role from the role check or the dungeon
-- finder. Nobody marked: no tank, and a tap set to Tank heals you.
local function role(unit)
  local okMT, mt = pcall(GetPartyAssignment, "MAINTANK", unit)
  if okMT and mt then
    return "TANK"
  end
  local ok, r = pcall(UnitGroupRolesAssigned, unit)
  if ok and type(r) == "string" then
    return r
  end
  return "NONE"
end

-- The full name ("Name" or "Name-Realm"); nil when the game can't say yet
-- (it says "Unknown" until it has the member's data).
local function name(unit)
  local ok, n = pcall(function()
    return GetUnitName(unit, true) .. ""
  end)
  if ok and n ~= "" and n ~= UNKNOWNOBJECT and n ~= "Unknown" then
    return n
  end
end

-- No two members share a name as a seat's unit: both keep their tokens.
local function unshare(members)
  local count = {}
  for _, m in ipairs(members) do
    if m.name then
      count[m.name] = (count[m.name] or 0) + 1
    end
  end
  for _, m in ipairs(members) do
    if m.name and count[m.name] > 1 then
      m.name = nil
    end
  end
  return members
end

-- The members of the player's group as the game reports them now, and
-- whether you're alone.
function ns.readRoster()
  local members = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      local _, _, group = GetRaidRosterInfo(i)
      table.insert(
        members,
        { unit = unit, role = role(unit), name = name(unit), group = group or 1, me = UnitIsUnit(unit, "player") }
      )
    end
    return unshare(members), false
  end
  if IsInGroup() then
    table.insert(members, { unit = "player", role = role("player"), name = name("player"), group = 1, me = true })
    for i = 1, GetNumSubgroupMembers() do
      local unit = "party" .. i
      if UnitExists(unit) then
        table.insert(members, { unit = unit, role = role(unit), name = name(unit), group = 1 })
      end
    end
    return unshare(members), false
  end
  return members, true
end

---------------------------------------------------------------- drawing by token

-- The secure seats name people; what is drawn reads them through their
-- unit token now (the game's aura and unit reads take tokens), kept up to
-- date as the roster changes, in combat too: addon code only reads.
local tokenOf = {}

local function plainName(unit)
  local ok, n = pcall(GetUnitName, unit, true)
  if not ok or type(n) ~= "string" then
    return nil
  end
  if issecretvalue then
    local okS, s = pcall(issecretvalue, n)
    if not okS or s then
      return nil
    end
  end
  return n
end

function ns.mapTokens()
  local fresh = {}
  local list = {}
  if IsInRaid() then
    for i = 1, 40 do
      list[#list + 1] = "raid" .. i
    end
  else
    for i = 1, 4 do
      list[#list + 1] = "party" .. i
    end
  end
  for _, u in ipairs(list) do
    if UnitExists(u) then
      local n = plainName(u)
      if n then
        fresh[n] = u
      end
    end
  end
  tokenOf = fresh
end

local TOKEN = { player = true, target = true, focus = true }
-- The unit token to draw a seat's unit with: tokens as they are, a name as
-- that person's token now; nil when they're gone.
function ns.displayUnit(unit)
  if type(unit) ~= "string" then
    return nil
  end
  if TOKEN[unit] or unit:match("^party%d$") or unit:match("^raid%d+$") then
    return unit
  end
  return tokenOf[unit]
end

ns.on("GROUP_ROSTER_UPDATE", ns.mapTokens)
ns.on("UNIT_NAME_UPDATE", ns.mapTokens)
ns.on("PLAYER_LOGIN", ns.mapTokens)
