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

-- A secure unit button: left click targets, right click the menu (with a
-- modifier held too: *type1).
function ns.seatButton(name, parent)
  local b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
  b:RegisterForClicks("AnyUp")
  b:SetAttribute("type1", "target")
  b:SetAttribute("type2", "togglemenu")
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

-- Under the drawn frames (which take no clicks), so a click reaches them;
-- while the settings move the frames, the drawn ones take the mouse.
local plus = CreateFrame("Frame", "HealpadPlusSeats", UIParent, "SecureFrameTemplate")
plus:SetFrameStrata("MEDIUM")
plus:SetFrameLevel(100) -- above the game's see-through party frames
plus:SetSize(1, 1)
plus:Hide()
ns.plusSeats = {}
for _, d in ipairs(ns.SEAT_DIRS) do
  ns.plusSeats[d] = ns.seatButton("HealpadPlusSeat" .. d, plus)
end

SecureHandlerSetFrameRef(ns.ctl, "plusseats", plus)
SecureHandlerSetFrameRef(_G.HealpadPageNext, "plusseats", plus)
SecureHandlerSetFrameRef(_G.HealpadPagePrev, "plusseats", plus)

local function placePlus()
  local on = ns.plusOn()
  ns.ctl:SetAttribute("plusmode", on or nil)
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

-- Frames are put away by making them see-through (alpha 0), nothing else.
-- Healpad never reparents them, calls their scripts or touches their
-- events: any of that runs the game's frame code as Healpad, which taints
-- those frames until a /reload (secret-value errors on every health update).
-- The seats sit above them, so clicks still reach the seats.
local PARTY = {
  "PartyFrame",
  "CompactPartyFrame",
  "PartyMemberFrame1",
  "PartyMemberFrame2",
  "PartyMemberFrame3",
  "PartyMemberFrame4",
}
local RAID = { "CompactRaidFrameManager", "CompactRaidFrameContainer" }
local taken = {} -- [name] = the frame's alpha before

local function take(name)
  local f = _G[name]
  if type(f) ~= "table" or taken[name] or not f.SetAlpha then
    return
  end
  local ok, a = pcall(f.GetAlpha, f)
  taken[name] = (ok and type(a) == "number") and a or 1
  pcall(f.SetAlpha, f, 0)
end

local function give(name)
  local a = taken[name]
  if not a then
    return
  end
  taken[name] = nil
  local f = _G[name]
  if type(f) == "table" and f.SetAlpha then
    pcall(f.SetAlpha, f, a)
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
