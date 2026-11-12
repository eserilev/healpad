-- A fake WoW Forever client for the Healpad tests. Run with LuaJIT (Lua 5.1).
--
-- It runs the secure snippets in a restricted table that has only the
-- names the real restricted environment gives, and it enforces the combat
-- rule: addon code must not change a secure frame in combat (W.blocked).
-- Health and the like are secret in combat: a compare or a sum with one is
-- an error, as in the client.

local M = {}

local Secret = {}
local function refuse()
  error("attempt to use a secret value", 2)
end
for _, mm in ipairs({
  "__lt",
  "__le",
  "__add",
  "__sub",
  "__mul",
  "__div",
  "__mod",
  "__unm",
  "__concat",
  "__len",
  "__eq",
}) do
  Secret[mm] = refuse
end
local function secret(v)
  return setmetatable({ value = v }, Secret)
end
function M.isSecret(v)
  return type(v) == "table" and getmetatable(v) == Secret
end
local function plain(v)
  if M.isSecret(v) then
    return v.value
  end
  return v
end

function M.new()
  local W = {
    combat = false,
    blocked = {},
    errors = {},
    printed = {},
    casts = {},
    secureBinds = {},
    overrides = {},
    downTarget = {},
    frames = {},
    fontStrings = {},
    textures = {},
    mods = { shift = false, ctrl = false, alt = false },
    units = {},
    raid = nil,
    book = {},
    talentGroup = 1,
    inSecure = false,
    rangeOut = {},
    now = 100,
    bar = "p1",
    drivers = {},
    actions = {},
    bindList = {},
    barPresses = {},
    cvars = {},
  }
  local G = {}
  W.G = G
  setmetatable(G, { __index = _G })

  local function protectedChange(f, what)
    if W.combat and f.protected and not W.inSecure then
      table.insert(W.blocked, (f.name or "?") .. ":" .. what)
    end
  end

  -- Frames ------------------------------------------------------------
  local Frame = {}
  Frame.__index = function(t, k)
    local m = Frame[k]
    if m then
      return m
    end
    -- A widget method this fake doesn't model is a no-op; fields are nil.
    if type(k) == "string" and k:match("^%u") then
      return function() end
    end
    return nil
  end

  local function newRegion(parent)
    local r = setmetatable({ shown = true, alpha = 1, attrs = {}, scripts = {}, hooks = {}, parent = parent }, Frame)
    return r
  end

  function Frame:GetName()
    return self.name
  end
  function Frame:GetID()
    return self.id or 0
  end
  function Frame:SetID(id)
    self.id = id
  end
  function Frame:GetFrameLevel()
    return self._level or 1
  end
  function Frame:SetFrameLevel(l)
    self._level = l
  end
  function Frame:CreateMaskTexture()
    return newRegion(self)
  end
  function Frame:CreateLine()
    return newRegion(self)
  end
  -- Animations: groups and animations take any setting and never run, so
  -- what they end on must also be set without them.
  function Frame:CreateAnimationGroup()
    local g = newRegion(self)
    g.anims = {}
    return g
  end
  function Frame:CreateAnimation(kind)
    local a = newRegion(self)
    a.kind = kind
    table.insert(self.anims, a)
    return a
  end
  function Frame:Play()
    self.played = (self.played or 0) + 1
  end
  -- Setters that take secret values: they keep what they got.
  function Frame:SetAlphaFromBoolean(v, yes, no)
    self.alphaBool = { v, yes, no }
  end
  function Frame:SetVertexColor(r, g, b, a)
    self.vertex = { r, g, b, a }
  end
  function Frame:SetStatusBarColor(r, g, b, a)
    self.barColor = { r, g, b, a }
  end
  function Frame:SetTextColor(r, g, b, a)
    self.textColor = { r, g, b, a }
  end
  function Frame:SetDesaturation(v)
    self.desat = v
  end
  function Frame:SetTexture(t)
    self.texture = t
  end
  function Frame:SetAtlas(a)
    self.atlas = a
  end
  function Frame:SetFormattedText(fmt, ...)
    local args = {}
    for i = 1, select("#", ...) do
      args[i] = plain((select(i, ...)))
    end
    self.text = fmt:format(unpack(args))
  end
  function Frame:Show()
    protectedChange(self, "Show")
    local was = self.shown
    self.shown = true
    if not was then
      self:RunScript("OnShow")
    end
  end
  function Frame:Hide()
    protectedChange(self, "Hide")
    local was = self.shown
    self.shown = false
    if was then
      self:RunScript("OnHide")
    end
  end
  function Frame:SetShown(v)
    if v then
      self:Show()
    else
      self:Hide()
    end
  end
  function Frame:IsShown()
    return self.shown
  end
  function Frame:IsVisible()
    return self.shown
  end
  function Frame:Click(_, down)
    W.click(self, down)
  end
  function Frame:SetAlpha(a)
    self.alpha = plain(a)
  end
  function Frame:GetAlpha()
    return self.alpha
  end
  function Frame:SetText(t)
    self.text = t
  end
  function Frame:GetText()
    return self.text
  end
  -- Sizes are kept as set. A font string's text is 6 wide a letter, 8 in a
  -- large font; color codes take no room.
  function Frame:SetWidth(w)
    self.width = w
  end
  function Frame:SetHeight(h)
    self.height = h
  end
  function Frame:SetSize(w, h)
    self.width, self.height = w, h
  end
  function Frame:GetWidth()
    return self.width or 0
  end
  function Frame:GetHeight()
    return self.height or 0
  end
  -- A font's size comes from its name (Large 16, Small 10, else 12) until
  -- SetFont; a letter is half the size wide.
  local function fontSize(f)
    if f.fontSize then
      return f.fontSize
    end
    local name = f.font or ""
    return name:find("Large") and 16 or name:find("Small") and 10 or 12
  end
  function Frame:GetStringWidth()
    local s = tostring(self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #s * fontSize(self) / 2
  end
  function Frame:GetFont()
    return "Fonts\\FRIZQT__.TTF", fontSize(self), ""
  end
  function Frame:SetFont(_, size)
    self.fontSize = size
  end
  function Frame:SetDesaturated(v)
    self.desaturated = v and true or false
  end
  function Frame:IsDesaturated()
    return self.desaturated == true
  end
  function Frame:SetEnabled(v)
    self.enabled = v and true or false
  end
  function Frame:IsEnabled()
    return self.enabled ~= false
  end
  function Frame:SetChecked(v)
    self.checked = v
  end
  function Frame:GetChecked()
    return self.checked
  end
  function Frame:SetPoint(...)
    protectedChange(self, "SetPoint")
  end
  function Frame:ClearAllPoints()
    protectedChange(self, "ClearAllPoints")
  end
  function Frame:SetScale(s)
    self.scale = s
  end
  function Frame:SetBackdropBorderColor(r, g, b, a)
    self.border = { r, g, b, a }
  end
  function Frame:SetMinMaxValues(lo, hi)
    self.min, self.max = lo, hi
  end
  function Frame:SetValue(v)
    self.value = v
  end
  function Frame:GetStatusBarTexture()
    self.tex = self.tex or newRegion(self)
    return self.tex
  end
  function Frame:CreateFontString(_, _, font)
    local fs = newRegion(self)
    fs.font = font
    table.insert(W.fontStrings, fs)
    return fs
  end
  function Frame:CreateTexture()
    local t = newRegion(self)
    table.insert(W.textures, t)
    return t
  end
  function Frame:SetScript(name, fn)
    self.scripts[name] = fn
  end
  function Frame:GetScript(name)
    return self.scripts[name]
  end
  function Frame:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
  end
  function Frame:RegisterEvent(e)
    self.events = self.events or {}
    self.events[e] = true
  end
  function Frame:UnregisterEvent(e)
    if self.events then
      self.events[e] = nil
    end
  end
  function Frame:IsEventRegistered(e)
    return self.events ~= nil and self.events[e] == true
  end
  function Frame:GetParent()
    return self.parent
  end
  function Frame:RegisterForClicks(...)
    self.clicks = { ... }
  end
  function Frame:EnableKeyboard(v)
    self.keyboard = v
  end
  function Frame:RunScript(name, ...)
    if self.scripts[name] then
      self.scripts[name](self, ...)
    end
    for _, fn in ipairs(self.hooks[name] or {}) do
      fn(self, ...)
    end
  end
  function Frame:SetAttribute(k, v)
    protectedChange(self, "SetAttribute " .. tostring(k))
    -- The game's own buttons run its code when an attribute changes: addon
    -- code setting one taints them, in combat or not.
    if self.blizzard and not W.inSecure then
      table.insert(W.blocked, "taint " .. (self.name or "?") .. ":" .. tostring(k))
    end
    self.attrs[k] = v
    self:RunScript("OnAttributeChanged", k, v)
  end
  function Frame:GetAttribute(k)
    return self.attrs[k]
  end
  -- Restricted handle methods, used only from snippets.
  function Frame:GetFrameRef(label)
    return self.refs and self.refs[label]
  end
  -- Override bindings stack by owner: each owner has at most one binding on
  -- a key, the most recent one wins, and clearing an owner's bindings
  -- uncovers what another owner bound there. W.secureBinds is the winner.
  W.bindStack = {}
  local function restack(key)
    local list = W.bindStack[key] or {}
    W.secureBinds[key] = list[#list]
  end
  local function unbind(owner, key)
    local list = W.bindStack[key]
    if not list then
      return
    end
    for i = #list, 1, -1 do
      if list[i].owner == owner then
        table.remove(list, i)
      end
    end
    restack(key)
  end
  function Frame:ClearBindings()
    for key in pairs(W.bindStack) do
      unbind(self, key)
    end
  end
  function Frame:ClearBinding(key)
    assert(W.inSecure, "ClearBinding outside a snippet")
    unbind(self, key)
  end
  function Frame:SetBindingClick(priority, key, name, button)
    assert(W.inSecure, "SetBindingClick outside a snippet")
    unbind(self, key)
    W.bindStack[key] = W.bindStack[key] or {}
    table.insert(W.bindStack[key], { owner = self, target = name, priority = priority, button = button })
    restack(key)
  end

  G.CreateFrame = function(kind, name, parent, template)
    local f = newRegion(parent)
    f.kind, f.name, f.template = kind, name, template or ""
    f.protected = f.template:find("Secure") ~= nil
    if name then
      G[name] = f
    end
    table.insert(W.frames, f)
    return f
  end
  G.UIParent = G.CreateFrame("Frame", "UIParent")
  G.WorldFrame = G.CreateFrame("Frame", "WorldFrame")
  function Frame:SetParent(p)
    protectedChange(self, "SetParent")
    self.parent = p
  end
  function Frame:GetScale()
    return self.scale or 1
  end
  G.UISpecialFrames = {}
  W.cursor = { 0, 0 }
  G.GetCursorPosition = function()
    return W.cursor[1], W.cursor[2]
  end
  G.ButtonFrameTemplate_HidePortrait = function(f)
    f.noPortrait = true
  end
  G.ButtonFrameTemplate_HideAttic = function(f)
    f.noAttic = true
  end
  G.SlashCmdList = {}

  -- Snippets -------------------------------------------------------------
  local RESTRICTED = {
    tostring = tostring,
    tonumber = tonumber,
    type = type,
    strmatch = string.match,
    GetActionInfo = function(slot)
      return G.GetActionInfo(slot)
    end,
    GetActionBarPage = function()
      return G.C_ActionBar.GetActionBarPage()
    end,
    UnitExists = function(u)
      return G.UnitExists(u)
    end,
    UnitIsDead = function(u)
      return G.UnitIsDeadOrGhost(u)
    end,
    SecureCmdOptionParse = function(s)
      if s:find("bonusbar", 1, true) then
        return W.bar
      end
      if s:find("[dead]", 1, true) then
        return W.stop and "1" or "0"
      end
      local u = s:match("^%[@([^,%]]+),help,nodead%] yes; no$")
      if u then
        local t = W.units[u]
        if u == "target" then
          return (t and t.friendly and not t.dead) and "yes" or "no"
        end
        return (t and t.friendly ~= false and not t.dead) and "yes" or "no"
      end
      error("fake SecureCmdOptionParse doesn't know " .. s)
    end,
  }
  G.SecureCmdOptionParse = function(s)
    return RESTRICTED.SecureCmdOptionParse(s)
  end
  local function runSnippetAs(args, body, env, ...)
    local fn = assert(loadstring("local " .. args .. " = ...\n" .. body))
    setfenv(
      fn,
      setmetatable(env, {
        __index = function(_, k)
          if RESTRICTED[k] ~= nil then
            return RESTRICTED[k]
          end
          error("snippet uses " .. tostring(k) .. ", which the restricted environment lacks", 2)
        end,
        __newindex = function(_, k)
          error("snippet sets global " .. tostring(k), 2)
        end,
      })
    )
    W.inSecure = true
    local out = (function(...)
      return { n = select("#", ...), ... }
    end)(pcall(fn, ...))
    W.inSecure = false
    if not out[1] then
      error(out[2], 0)
    end
    return unpack(out, 2, out.n)
  end
  local function runSnippet(body, env, ...)
    return runSnippetAs("self, button, down", body, env, ...)
  end
  W.runSnippet = runSnippet

  G.SecureHandlerWrapScript = function(frame, script, header, pre, post)
    assert(script == "OnClick")
    if W.combat then
      table.insert(W.blocked, "SecureHandlerWrapScript")
    end
    frame.wrap = { header = header, pre = pre, post = post }
  end
  G.SecureHandlerExecute = function(frame, body)
    if W.combat then
      table.insert(W.blocked, "SecureHandlerExecute")
    end
    runSnippet(body, {}, frame)
  end
  G.RegisterStateDriver = function(frame, name, cond)
    table.insert(W.drivers, { frame = frame, name = name, cond = cond })
    W.inSecure = true
    frame:SetAttribute("state-" .. name, G.SecureCmdOptionParse(cond))
    W.inSecure = false
  end
  -- The bar changes (a form, a page): drivers update and their snippets run.
  function W.setBar(state)
    W.bar = state
    W.drive()
  end
  -- Dead, mounted or on a possess bar (true), or back (false).
  function W.setStop(on)
    W.stop = on
    W.drive()
  end
  function W.drive()
    for _, d in ipairs(W.drivers) do
      W.inSecure = true
      d.frame:SetAttribute("state-" .. d.name, G.SecureCmdOptionParse(d.cond))
      W.inSecure = false
      local body = d.frame.attrs["_onstate-" .. d.name]
      if body then
        runSnippetAs("self, stateid, newstate", body, {}, d.frame, d.name, d.frame.attrs["state-" .. d.name])
      end
    end
  end
  G.SecureHandlerSetFrameRef = function(frame, label, ref)
    frame.refs = frame.refs or {}
    frame.refs[label] = ref
  end

  local function registered(f, what)
    for _, c in ipairs(f.clicks or {}) do
      if c == what then
        return true
      end
    end
    return false
  end
  W.registered = registered

  -- A click from a binding: the wrap, the template action, then the hooks.
  W.keyDownCvar = true -- the game's ActionButtonUseKeyDown
  function W.click(f, down)
    local message
    if f.wrap then
      local res, msg = runSnippet(f.wrap.pre, { owner = f.wrap.header }, f, "LeftButton", down)
      if res == false then
        for _, fn in ipairs(f.hooks.OnClick or {}) do
          fn(f, "LeftButton", down)
        end
        return
      end
      message = msg
    end
    if f.template:find("SecureActionButtonTemplate") then
      local onDown = f.attrs.useOnKeyDown
      if onDown == nil then
        onDown = W.keyDownCvar
      end
      if (down and onDown) or (not down and not onDown) then
        local unit = f.attrs.unit
        if unit and unit ~= "none" and not G.UnitExists(unit) then
          return
        end
        local spell = f.attrs.spell
        if f.attrs.type == "action" then -- the spell in its slot; an empty slot casts nothing
          local a = W.actions[f:GetID() + (G.C_ActionBar.GetActionBarPage() - 1) * 12]
          spell = a and a[2]
        end
        if spell then
          table.insert(W.casts, { spell = spell, unit = unit, combat = W.combat })
        end
      end
    elseif f.template:find("SecureHandlerClickTemplate") and (down or registered(f, "AnyUp")) then
      runSnippet(f.attrs._onclick, {}, f, "LeftButton", down)
    elseif f.template == "" and down and f.scripts.OnClick then
      f.scripts.OnClick(f, "LeftButton", down) -- a plain button: clicks on the press
    end
    if f.wrap and f.wrap.post and message ~= nil then
      runSnippetAs(
        "self, message, button, down",
        f.wrap.post,
        { owner = f.wrap.header },
        f,
        message,
        "LeftButton",
        down
      )
    end
    for _, fn in ipairs(f.hooks.OnClick or {}) do
      fn(f, "LeftButton", down)
    end
  end

  -- A key press: the controller's bindings first, then the override bindings.
  -- The release goes where the press went.
  -- What a key press runs: an override binding, Gamepad Mode's binding,
  -- then yours. A chord with nothing bound runs the key without modifiers.
  local function lookup(key)
    -- contextFirst: Gamepad Mode's bindings beat override bindings.
    if W.contextFirst and W.gamepadMode and W.contextBinds[key] then
      return { context = W.contextBinds[key] }
    end
    local b = W.secureBinds[key] or W.overrides[key]
    if b then
      return b.target
    end
    if W.gamepadMode and W.contextBinds[key] then
      return { context = W.contextBinds[key] }
    end
    if W.normalBinds[key] then
      return { normal = W.normalBinds[key] }
    end
  end
  function W.key(key, down)
    local target
    if down then
      target = lookup(key)
      if target == nil then
        target = lookup((key:gsub("^.*%-", "")))
      end
      W.downTarget[key] = target
    else
      target = W.downTarget[key]
      W.downTarget[key] = nil
    end
    if type(target) == "string" then
      W.click(G[target], down)
    elseif target and target.context then
      W.runContext(target.context, down)
    elseif target and down then
      table.insert(W.barPresses, { key = key, command = target.normal })
    end
    return type(target) == "string" and target or nil
  end
  function W.tap(key)
    W.key(key, true)
    W.key(key, false)
  end

  G.SetOverrideBindingClick = function(owner, priority, key, name)
    if W.combat then
      table.insert(W.blocked, "SetOverrideBindingClick " .. key)
    end
    W.overrides[key] = { owner = owner, target = name, priority = priority }
  end
  G.ClearOverrideBindings = function(owner)
    if W.combat then
      table.insert(W.blocked, "ClearOverrideBindings")
    end
    for key, b in pairs(W.overrides) do
      if b.owner == owner then
        W.overrides[key] = nil
      end
    end
  end
  W.normalBinds = {}
  W.contextBinds = {} -- Gamepad Mode's bindings (GamepadModeInGameCore): key -> command
  G.GetBindingKey = function(command)
    local keys = {}
    for _, b in ipairs(W.bindList) do
      if b[1] == command then
        for i = 2, #b do
          table.insert(keys, b[i])
        end
      end
    end
    local ctx = {}
    for k, c in pairs(W.contextBinds) do
      if c == command then
        table.insert(ctx, k)
      end
    end
    table.sort(ctx)
    for _, k in ipairs(ctx) do
      table.insert(keys, k)
    end
    return unpack(keys)
  end
  G.GetBindingAction = function(key, override)
    local o = override and (W.secureBinds[key] or W.overrides[key])
    if o then
      return "CLICK " .. o.target .. ":LeftButton"
    end
    return W.normalBinds[key] or ""
  end
  G.GetBindingText = function(key)
    return key
  end
  -- W.bindList: { { command, key1, key2 } }; W.normalBinds follows it.
  function W.bind(command, ...)
    table.insert(W.bindList, { command, ... })
    for _, k in ipairs({ ... }) do
      W.normalBinds[k] = command
    end
  end
  G.GetNumBindings = function()
    return #W.bindList
  end
  G.GetBinding = function(i)
    local b = W.bindList[i]
    return b[1], "BINDING_HEADER_X", unpack(b, 2)
  end
  G.GetActionInfo = function(slot)
    local a = W.actions[slot]
    if a then
      return a[1], a[2]
    end
  end
  G.GetMacroSpell = function()
    return nil
  end
  G.C_CVar = {
    GetCVar = function(k)
      return W.cvars[k]
    end,
    SetCVar = function(k, v)
      W.cvars[k] = tostring(v)
      return true
    end,
  }
  W.actionBarPage = 1
  W.bonusBar = false
  G.C_ActionBar = {
    GetActionBarPage = function()
      return W.actionBarPage
    end,
    HasBonusActionBar = function()
      return W.bonusBar
    end,
  }
  G.C_KeyBindings = {
    IsBindingContextActive = function(ctx)
      return ctx == G.Enum.BindingContext.GamepadModeInGameCore and W.gamepadMode == true
    end,
  }

  -- Gamepad Mode ---------------------------------------------------------------
  -- The game's controller bar (Blizzard_GamepadActionBars): four bars of 8
  -- buttons, 3 pages, its own action slots from W.gpFirst; the triggers
  -- pick the bar; GAMEPADACTIONBUTTONn presses button n of the bar in front.
  W.gpFirst = 361
  W.gpPage = 1
  W.gpMods = { left = false, right = false }
  G.C_GamepadUI = {
    GetFirstGamepadActionStorageSlotIndex = function()
      return W.gpFirst
    end,
    GetFirstGamepadActionBarStorageSlotIndexForActiveStance = function()
      return W.gpStanceFirst
    end,
  }
  -- ActionBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID
  local function storage(page, slotID)
    if slotID >= 5 and slotID < 9 then
      return nil
    end
    local id = (32 * (page - 1)) + W.gpFirst + (slotID - 1) - 4 * (page - 1)
    if slotID >= 5 then
      id = id - 4
    end
    return id
  end
  W.gpStorage = storage
  local BARS = { "topBar", "leftBar", "rightBar", "bottomBar" }
  local function refreshIds()
    local pu = G.GamepadMainActionBarFrame.PageUnit
    for bi, key in ipairs(BARS) do
      for n, b in ipairs(pu.actionBars[key].actionButtons) do
        b:SetID(storage(W.gpPage, (bi - 1) * 8 + n) or 0)
      end
    end
    for n, b in ipairs(pu.actionBars.stanceBar.actionButtons) do
      b:SetID(W.gpStanceFirst and (W.gpStanceFirst + n - 1) or 0)
    end
  end
  -- Turns on Gamepad Mode: the bar, and its bindings on an Xbox pad.
  function W.gamepad()
    W.gamepadMode = true
    local main = G.CreateFrame("Frame", "GamepadMainActionBarFrame", G.UIParent)
    local pu = G.CreateFrame("Frame", "GamepadMainActionBarFramePageUnit", main)
    main.PageUnit = pu
    main.buttonOwners = {}
    pu.actionBars = {}
    local anchors = {
      topBar = "TopCenteredAnchorTopBar",
      leftBar = "LeftCenteredAnchorLeftBar",
      rightBar = "RightCenteredAnchorRightBar",
      bottomBar = "BottomCenteredAnchorBottomBar",
      stanceBar = "TopCenteredAnchorStanceBar",
    }
    for key, path in pairs(anchors) do
      local bar = { actionButtons = {} }
      for n = 1, 8 do
        local b = G.CreateFrame(
          "CheckButton",
          "GamepadMainActionBarFramePageUnit" .. path .. "ActionButton" .. n,
          pu,
          "SecureActionButtonTemplate, GamepadActionBarButtonTemplate"
        )
        b.blizzard = true
        b.attrs.type = "action"
        b.attrs.useOnKeyDown = true
        bar.actionButtons[n] = b
      end
      pu.actionBars[key] = bar
    end
    function pu.GetCurrentPage()
      return W.gpPage
    end
    refreshIds()
    -- MainActionBarFrame.lua PressActionButton, with PageUnit's bar choice.
    function main.PressActionButton(self, n, button, down)
      local owners = self.buttonOwners
      if down then
        local bar = "topBar"
        if W.gpMods.left and W.gpMods.right then
          bar = "bottomBar"
        elseif W.gpMods.left then
          bar = "leftBar"
        elseif W.gpMods.right then
          bar = "rightBar"
        end
        if W.gpStanceOver and W.gpStanceOver[1] == W.gpPage and W.gpStanceOver[2] == bar then
          bar = "stanceBar"
        end
        local b = pu.actionBars[bar].actionButtons[n]
        if owners[n] then
          self:PressActionButton(n, button, false)
        end
        owners[n] = b
        b:Click(button, true)
      elseif owners[n] then
        local b = owners[n]
        owners[n] = nil
        b:Click(button, false)
      end
    end
    local keys = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
    for n, k in ipairs(keys) do
      W.contextBinds[k] = "GAMEPADACTIONBUTTON" .. n
    end
    W.contextBinds.PADLTRIGGER = "GAMEPADLEFTMOD"
    W.contextBinds.PADRTRIGGER = "GAMEPADRIGHTMOD"
    W.contextBinds.PADLSHOULDER = "GAMEPADLEFTTARGETMODIFIER"
    W.contextBinds.PADRSHOULDER = "GAMEPADRIGHTTARGETMODIFIER"
    return main
  end
  -- A Gamepad Mode binding runs.
  W.gpRan = {}
  function W.runContext(command, down)
    local n = tonumber(command:match("^GAMEPADACTIONBUTTON(%d)$"))
    if n then
      G.GamepadMainActionBarFrame:PressActionButton(n, "LeftButton", down)
    elseif command == "GAMEPADLEFTMOD" then
      W.gpMods.left = down
    elseif command == "GAMEPADRIGHTMOD" then
      W.gpMods.right = down
    elseif down then
      table.insert(W.gpRan, command)
    end
  end
  -- Page n of the controller bar (the game's page tracker).
  function W.setGamepadPage(p)
    W.gpPage = p
    refreshIds()
  end
  -- A stance whose controller bar starts at slot first takes the place of
  -- bar on page.
  function W.setGamepadStance(first, page, bar, override)
    W.gpStanceFirst = first
    W.bonusBar = first ~= nil
    W.gpStanceOver = first and { page, bar } or nil
    W.cvars.GamepadStanceBarOverride = override
    refreshIds()
  end

  -- Units ---------------------------------------------------------------
  local function hidden(v)
    if W.combat then
      return secret(v)
    end
    return v
  end
  -- A group member can be named in place of a unit token.
  setmetatable(W.units, {
    __index = function(t, k)
      if type(k) ~= "string" then
        return nil
      end
      for _, x in pairs(t) do
        if type(x) == "table" and x.name == k then
          return x
        end
      end
    end,
  })
  G.GetUnitName = function(u)
    return G.UnitName(u)
  end
  G.UnitExists = function(u)
    return u ~= nil and W.units[u] ~= nil
  end
  G.UnitName = function(u)
    local x = W.units[u]
    return x and x.name
  end
  G.UnitIsUnit = function(a, b)
    return W.units[a] ~= nil and W.units[a] == W.units[b]
  end
  G.UnitHealth = function(u)
    return hidden(W.units[u] and W.units[u].hp or 0)
  end
  G.UnitHealthMax = function(u)
    return hidden(W.units[u] and W.units[u].max or 1)
  end
  G.UnitHealthMissing = function(u)
    local x = W.units[u]
    return hidden(x and (x.max - x.hp) or 0)
  end
  -- A fraction, or with a curve the color there; secret in combat.
  G.UnitHealthPercent = function(u, _, curve)
    local x = W.units[u]
    local pct = x and x.hp / x.max or 0
    if curve then
      local r, g, b, a = curve:Evaluate(pct):GetRGBA()
      return {
        GetRGBA = function()
          return hidden(r), hidden(g), hidden(b), hidden(a)
        end,
      }
    end
    return hidden(pct)
  end
  G.issecretvalue = M.isSecret
  G.BreakUpLargeNumbers = function(n)
    local s = tostring(plain(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return M.isSecret(n) and secret(s) or s
  end
  G.UnitClass = function(u)
    local c = W.units[u] and W.units[u].class or "PRIEST"
    return c:sub(1, 1) .. c:sub(2):lower(), c
  end
  G.RAID_CLASS_COLORS = {
    PRIEST = { r = 1, g = 1, b = 1 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 },
    DRUID = { r = 1, g = 0.49, b = 0.04 },
  }
  G.UnitGetIncomingHeals = function(u)
    return hidden(W.units[u] and W.units[u].incoming or 0)
  end
  G.UnitGroupRolesAssigned = function(u)
    return W.units[u] and W.units[u].role or "NONE"
  end
  G.UnitIsConnected = function(u)
    return not (W.units[u] and W.units[u].offline)
  end
  G.UnitIsDeadOrGhost = function(u)
    return W.units[u] and W.units[u].dead or false
  end
  G.GetPartyAssignment = function(what, u)
    return what == "MAINTANK" and W.units[u] and W.units[u].mainTank or false
  end
  G.UnitLevel = function(u)
    return W.units[u] and (W.units[u].level or 60) or 0
  end
  G.UnitPower = function(u)
    return hidden(W.units[u] and W.units[u].power or 50)
  end
  G.UnitPowerMax = function(u)
    return hidden(100)
  end
  G.UnitPowerType = function()
    return 0, "MANA"
  end
  G.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
  G.SetPortraitTexture = function(tex, unit)
    tex.portrait = unit
  end
  G.IsInRaid = function()
    return W.raid ~= nil
  end
  G.IsInGroup = function()
    return W.raid ~= nil or W.units.party1 ~= nil
  end
  G.GetNumGroupMembers = function()
    return W.raid and #W.raid or 0
  end
  G.GetNumSubgroupMembers = function()
    local n = 0
    for i = 1, 4 do
      if W.units["party" .. i] then
        n = i
      end
    end
    return n
  end
  G.GetRaidRosterInfo = function(i)
    local r = W.raid[i]
    return r.name, 0, r.group
  end

  -- Spells ----------------------------------------------------------------
  G.Enum = {
    SpellBookSpellBank = { Player = 0 },
    SpellBookItemType = { Spell = 1, Flyout = 4 },
    LuaCurveType = { Step = 1 },
    BindingContext = { None = 0, GamepadModeInGameCore = 9 },
  }
  G.C_SpellBook = {
    GetNumSpellBookSkillLines = function()
      return 1
    end,
    GetSpellBookSkillLineInfo = function()
      return { itemIndexOffset = 0, numSpellBookItems = #W.book, shouldHide = false }
    end,
    GetSpellBookItemInfo = function(slot)
      local s = W.book[slot]
      return { spellID = s.id, actionID = s.id, itemType = s.kind or 1, name = s.name, subName = s.sub or "" }
    end,
    IsSpellBookItemHelpful = function(slot)
      return W.book[slot].helpful == true
    end,
  }
  local function spell(id)
    for _, s in ipairs(W.book) do
      if s.id == id then
        return s
      end
    end
  end
  G.C_Spell = {
    GetSpellName = function(id)
      local s = spell(id)
      return s and s.name
    end,
    GetSpellSubtext = function(id)
      local s = spell(id)
      return s and s.sub
    end,
    GetSpellTexture = function()
      return 136041
    end,
    IsSpellHelpful = function(id)
      local s = spell(id)
      return s and s.helpful or false
    end,
    SpellHasRange = function(id)
      local s = spell(id)
      return s ~= nil and s.selfOnly ~= true
    end,
    GetSpellInfo = function(name)
      for _, s in ipairs(W.book) do
        if s.name == name then
          return { spellID = s.id }
        end
      end
    end,
    IsSpellInRange = function(_, unit)
      for k, out in pairs(W.rangeOut) do
        if out and W.units[k] ~= nil and W.units[k] == W.units[unit] then
          return hidden(false)
        end
      end
      return hidden(true)
    end,
  }
  -- A unit's auras: hot (true) or hots (a list) for your HoTs, debuff (a
  -- dispel type) or debuffs (a list of { type, stacks }), mine (a list of
  -- your own buffs on you: { name, id, duration }), has[name] for any buff.
  -- In combat the stacks and times are secret.
  local function auras(x, filter)
    if filter:find("HARMFUL") then
      if x.debuffs then
        return x.debuffs
      end
      return x.debuff and { { x.debuff, 1 } } or {}
    end
    if filter:find("RAID_IN_COMBAT") then
      if x.hots then
        return x.hots
      end
      return x.hot and { {} } or {}
    end
    return x.mine or {}
  end
  W.auraReads = 0
  G.C_UnitAuras = {
    GetAuraDataByIndex = function(unit, n, filter)
      W.auraReads = W.auraReads + 1
      if W.aurasRefused and W.combat then
        error("auras are hidden in combat")
      end
      local x = W.units[unit]
      if not x then
        return nil
      end
      local a = auras(x, filter or "HELPFUL")[n]
      if not a then
        return nil
      end
      if filter and filter:find("HARMFUL") then
        return { auraInstanceID = 70 + n, dispelName = a[1], applications = hidden(a[2] or 1), icon = 136066 }
      end
      if filter and filter:find("RAID_IN_COMBAT") then
        return { auraInstanceID = 80 + n, icon = 136081, duration = hidden(12), expirationTime = hidden(110) }
      end
      return {
        auraInstanceID = 90 + n,
        name = a.name,
        spellId = a.id,
        icon = 136078,
        duration = a.duration,
        sourceUnit = "player",
      }
    end,
    GetAuraDataBySpellName = function(unit, name)
      local x = W.units[unit]
      if x and ((x.has and x.has[name]) or x == W.units.player) then
        return { name = name }
      end
      return nil
    end,
    GetAuraDispelTypeColor = function()
      return {
        GetRGBA = function()
          return hidden(0.2), hidden(0.6), hidden(1), hidden(1)
        end,
      }
    end,
    GetAuraApplicationDisplayCount = function(unit, id)
      local x = W.units[unit]
      local list = x and auras(x, id < 80 and "HARMFUL" or "RAID_IN_COMBAT") or {}
      local a = list[id - (id < 80 and 70 or 80)]
      local n = a and a[2] or 1
      return hidden(n > 1 and tostring(n) or "")
    end,
    GetAuraDuration = function()
      return { duration = true }
    end,
  }
  G.UnitThreatSituation = function(u)
    local x = W.units[u]
    if W.threatSecret then
      return secret(x and x.threat or 0)
    end
    return x and x.threat or 0
  end
  G.UnitHasIncomingResurrection = function(u)
    local x = W.units[u]
    return hidden(x and x.rez or false)
  end
  G.C_CurveUtil = {
    CreateColorCurve = function()
      local c = { points = {} }
      function c.SetType() end
      function c.AddPoint(_, x, color)
        assert(not M.isSecret(x), "a curve point from a secret")
        table.insert(c.points, { x, color })
      end
      -- linear between points
      function c.Evaluate(_, x)
        local p = c.points
        local lo, hi = p[1], p[#p]
        for i = 2, #p do
          if x <= p[i][1] then
            lo, hi = p[i - 1], p[i]
            break
          end
        end
        local t = hi[1] == lo[1] and 0 or math.max(0, math.min(1, (x - lo[1]) / (hi[1] - lo[1])))
        local a, b = { lo[2].GetRGBA() }, { hi[2].GetRGBA() }
        local out = {}
        for i = 1, 4 do
          out[i] = a[i] + (b[i] - a[i]) * t
        end
        return G.CreateColor(unpack(out))
      end
      return c
    end,
    EvaluateColorValueFromBoolean = function(v, yes, no)
      local r = plain(v) and yes or no
      return M.isSecret(v) and secret(r) or r
    end,
  }
  G.CreateVector2D = function(x, y)
    return { x = x, y = y }
  end
  G.CreateColor = function(r, g, b, a)
    return {
      GetRGBA = function()
        return r, g, b, a
      end,
    }
  end

  -- The rest -----------------------------------------------------------------
  G.InCombatLockdown = function()
    return W.combat
  end
  G.GetTime = function()
    return W.now
  end
  G.C_SpecializationInfo = {
    GetActiveSpecGroup = function()
      return W.talentGroup
    end,
  }
  G.IsShiftKeyDown = function()
    return W.mods.shift
  end
  G.IsControlKeyDown = function()
    return W.mods.ctrl
  end
  G.IsAltKeyDown = function()
    return W.mods.alt
  end
  G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    table.insert(W.printed, table.concat(parts, " "))
  end
  G._G = G
  W.timers, W.shots, W.reloaded = {}, 0, false
  W.tickers = {}
  G.C_Timer = {
    After = function(_, fn)
      table.insert(W.timers, fn)
    end,
    -- A ticker: W.tick() runs each live one once.
    NewTicker = function(_, fn)
      local t = { fn = fn }
      function t.Cancel()
        t.dead = true
      end
      table.insert(W.tickers, t)
      return t
    end,
  }
  function W.tick()
    for _, t in ipairs(W.tickers) do
      if not t.dead then
        t.fn()
      end
    end
  end
  function W.runTimers()
    while #W.timers > 0 do
      table.remove(W.timers, 1)()
    end
  end
  G.Screenshot = function()
    W.shots = W.shots + 1
  end
  G.ReloadUI = function()
    W.reloaded = true
  end
  G.GetBuildInfo = function()
    return "1.60.1"
  end
  G.date = os.date
  local handler = function(e)
    table.insert(W.errors, e)
  end
  G.geterrorhandler = function()
    return handler
  end
  G.seterrorhandler = function(fn)
    handler = fn
  end
  G.wipe = function(t)
    for k in pairs(t) do
      t[k] = nil
    end
    return t
  end

  function W.fire(event, ...)
    for _, f in ipairs(W.frames) do
      if f.events and f.events[event] and f.scripts.OnEvent then
        f.scripts.OnEvent(f, event, ...)
      end
    end
  end
  function W.update(elapsed)
    W.now = W.now + elapsed
    for _, f in ipairs(W.frames) do
      if f.scripts.OnUpdate then
        f.scripts.OnUpdate(f, elapsed)
      end
    end
  end

  function W.load(dir, files, saved)
    local ns = {}
    G.HealpadDB = saved
    for _, file in ipairs(files) do
      local fn = assert(loadfile(dir .. "/" .. file))
      setfenv(fn, G)
      fn("Healpad", ns)
    end
    W.ns = ns
    W.fire("ADDON_LOADED", "Healpad")
    W.fire("PLAYER_LOGIN")
    return ns
  end
  return W
end

return M
