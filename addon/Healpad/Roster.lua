-- Who sits where. A seat belongs to a person: it is handed out out of combat,
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

-- What a seat's secure attributes hold for a member.
function ns.seatUnit(m)
  if m.me then
    return "player"
  end
  if ns.SEAT_BY_NAME and m.name then
    return m.name
  end
  return m.unit
end

-- members: { unit, name, group, me, role } in the game's order.
-- prev: the last seats, { [group] = { [seat] = name } } (or nil).
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
      local name = was[i]
      if name and not res[i] then
        for _, m in ipairs(list) do
          if not placed[m] and m.name == name then
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

-- The names in seats, to keep them next time.
function ns.seatNames(seats)
  local out = {}
  for g, res in pairs(seats) do
    out[g] = {}
    for i, m in pairs(res) do
      out[g][i] = m.name
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

-- The full name ("Name" or "Name-Realm"); nil when the game can't say.
local function name(unit)
  local ok, n = pcall(function()
    return GetUnitName(unit, true) .. ""
  end)
  if ok and n ~= "" then
    return n
  end
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
    return members, false
  end
  if IsInGroup() then
    table.insert(members, { unit = "player", role = role("player"), name = name("player"), group = 1, me = true })
    for i = 1, GetNumSubgroupMembers() do
      local unit = "party" .. i
      if UnitExists(unit) then
        table.insert(members, { unit = unit, role = role(unit), name = name(unit), group = 1 })
      end
    end
    return members, false
  end
  return members, true
end
