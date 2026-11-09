-- Who sits where in the diamond. Set out of combat only, so the places never
-- move under your thumb mid-fight: tank up, you in the middle, the others
-- right, down and left by role, then name. A raid has one page per group,
-- your own group first.
local _, ns = ...

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local AROUND = { "UP", "RIGHT", "DOWN", "LEFT" }

local function before(a, b)
  local ra, rb = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
  if ra ~= rb then
    return ra < rb
  end
  if a.name ~= b.name then
    return a.name < b.name
  end
  return a.unit < b.unit
end

-- members: { unit, role, name, group, me } for everyone in the group.
-- Returns pages { [dir] = unit }, and the first tank's unit or nil.
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

-- The tank: the raid's Main Tank, else the role from the role check or the
-- dungeon finder. Nobody marked: no tank, and a tap set to Tank heals you.
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

local function name(unit)
  local ok, n = pcall(function()
    return UnitName(unit) .. ""
  end)
  return ok and n or unit
end

-- The members of the player's group as the game reports them now.
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
      table.insert(members, { unit = unit, role = role(unit), name = name(unit), group = 1 })
    end
    return members, false
  end
  return members, true
end
