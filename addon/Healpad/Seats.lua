-- The secure side of the frames that stay on screen: a unit button over
-- each seat, so a click targets the person and a right click opens their
-- menu, as on the game's party frames (and other addons' click casting can
-- use them). What you see is drawn by plain frames beneath (Diamond.lua,
-- Grid.lua); these buttons draw nothing.
--
-- The game locks secure frames in combat: these are placed, shown, hidden
-- and given their person only out of combat. Someone who leaves mid-fight
-- keeps their seat (it goes dark) until the fight ends.
--
-- While Healpad's frames are on, the game's own party (and in Buttons mode
-- raid) frames are put away out of combat, and come back when they're off.
local _, ns = ...

-- Hover and click casting addons (KeyBars among them) look for unit frames
-- in ClickCastFrames.
local function clickCast(b)
  ClickCastFrames = ClickCastFrames or {}
  ClickCastFrames[b] = true
end

-- A secure unit button: left click targets, right click the menu.
function ns.seatButton(name, parent)
  local b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
  b:RegisterForClicks("AnyUp")
  b:SetAttribute("*type1", "target")
  b:SetAttribute("*type2", "togglemenu")
  b:Hide()
  clickCast(b)
  return b
end

-- Tells KeyBars (when it runs) that the seat buttons changed.
local function refreshKeyBars()
  if KeyBarsAPI and type(KeyBarsAPI.refreshFrames) == "function" then
    local ok, err = pcall(KeyBarsAPI.refreshFrames)
    if not ok then
      ns.log("KeyBarsAPI.refreshFrames: " .. tostring(err))
    end
  end
end

---------------------------------------------------------------- the plus

local plus = CreateFrame("Frame", "HealpadPlusSeats", UIParent, "SecureFrameTemplate")
plus:SetSize(1, 1)
plus:Hide()
ns.plusSeats = {}
for _, d in ipairs(ns.SEAT_DIRS) do
  ns.plusSeats[d] = ns.seatButton("HealpadPlusSeat" .. d, plus)
end

local function placePlus()
  local on = ns.plusOn()
  if not on then
    plus:Hide()
    return
  end
  local from, x, y, scale = ns.rootPoint()
  plus:SetScale(scale)
  plus:ClearAllPoints()
  plus:SetPoint("CENTER", UIParent, from, x, y)
  local places = ns.spotPlaces()
  for _, d in ipairs(ns.SEAT_DIRS) do
    local b = ns.plusSeats[d]
    local unit = ns.ctl:GetAttribute("u1-" .. d)
    local at = places[d]
    if unit and unit ~= "target" and at then
      b:SetAttribute("unit", unit)
      b:ClearAllPoints()
      b:SetPoint("CENTER", plus, "CENTER", at[1], at[2])
      b:SetSize(math.max(1, at[3]), math.max(1, at[4]))
      b:Show()
    else
      b:Hide()
      b:SetAttribute("unit", nil)
    end
  end
  plus:Show()
end

-- Out of combat: every seat button where its seat is, with its person.
function ns.placeSeats()
  ns.afterCombat("seats", function()
    placePlus()
    if ns.placeGrid then
      ns.placeGrid()
    end
    refreshKeyBars()
  end)
end

---------------------------------------------------------------- the game's frames

-- Frames are put away by moving them under a hidden frame, and their own
-- events (the ones that would lay them out again) are turned off; both
-- come back as they were. Nothing of theirs is hooked or replaced.
local hider = CreateFrame("Frame", "HealpadHiddenFrames", UIParent)
hider:Hide()
local PARTY = {
  "PartyFrame",
  "CompactPartyFrame",
  "PartyMemberFrame1",
  "PartyMemberFrame2",
  "PartyMemberFrame3",
  "PartyMemberFrame4",
}
local RAID = { "CompactRaidFrameManager", "CompactRaidFrameContainer" }
local EVENTS = {
  "GROUP_ROSTER_UPDATE",
  "VARIABLES_LOADED",
  "PLAYER_ENTERING_WORLD",
  "UNIT_PET",
  "LFG_UPDATE",
  "DISPLAY_SIZE_CHANGED",
  "UI_SCALE_CHANGED",
  "UPDATE_ACTIVE_BATTLEFIELD",
  "UNIT_FLAGS",
  "PLAYER_FLAGS_CHANGED",
  "PARTY_LEADER_CHANGED",
  "RAID_TARGET_UPDATE",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_DIFFICULTY_CHANGED",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_MEMBER_ENABLE",
  "PARTY_MEMBER_DISABLE",
}
local taken = {} -- [name] = { frame, parent, events }

local function take(name)
  local f = _G[name]
  if type(f) ~= "table" or taken[name] or not f.SetParent then
    return
  end
  local ok, parent = pcall(f.GetParent, f)
  local rec = { frame = f, parent = ok and parent or UIParent, events = {} }
  for _, e in ipairs(EVENTS) do
    local okE, on = pcall(f.IsEventRegistered, f, e)
    if okE and on then
      pcall(f.UnregisterEvent, f, e)
      table.insert(rec.events, e)
    end
  end
  if pcall(f.SetParent, f, hider) then
    taken[name] = rec
  else
    for _, e in ipairs(rec.events) do
      pcall(f.RegisterEvent, f, e)
    end
  end
end

local function give(name)
  local rec = taken[name]
  if not rec then
    return
  end
  taken[name] = nil
  pcall(rec.frame.SetParent, rec.frame, rec.parent)
  for _, e in ipairs(rec.events) do
    pcall(rec.frame.RegisterEvent, rec.frame, e)
  end
end

-- Whether the game's party and raid frames are put away now.
function ns.blizzardHidden()
  return taken.PartyFrame ~= nil or taken.PartyMemberFrame1 ~= nil, taken.CompactRaidFrameManager ~= nil
end

-- Out of combat: the game's party frames away while the plus or the
-- Buttons frames are on; its raid frames away while Buttons is on.
function ns.applyBlizzard()
  ns.afterCombat("blizzard", function()
    local party = ns.plusOn() or ns.isButtons()
    local raid = ns.isButtons()
    for _, name in ipairs(PARTY) do
      if party then
        take(name)
      else
        give(name)
      end
    end
    for _, name in ipairs(RAID) do
      if raid then
        take(name)
      else
        give(name)
      end
    end
  end)
end

---------------------------------------------------------------- the mode

-- After Mode or Party Frames changed (and at login): the secure setup, who
-- sits where, which frames show and where, the game's frames. Out of
-- combat; in combat it waits.
function ns.applyMode()
  ns.afterCombat("mode", function()
    ns.applyKeys(true)
    ns.applyRoster()
    if ns.applyMenu then
      ns.applyMenu()
    end
    if ns.applyGrid then
      ns.applyGrid()
    end
    ns.placeSeats()
    ns.applyBlizzard()
  end)
end

ns.on("PLAYER_LOGIN", ns.applyMode)
-- Frames the game makes late (CompactPartyFrame) are put away too.
ns.on("GROUP_ROSTER_UPDATE", ns.applyBlizzard)
