-- /hp test: checks Healpad inside the real game, out of combat.
-- Opens each settings tab and the diamond and takes a screenshot of each,
-- runs a hold, an aim and a cancel through the real secure snippets (nothing
-- is cast), and records what it found and any Lua error in the saved log.
-- The game writes the log on /reload; an addon can't reload by itself.
local _, ns = ...

local results
local function check(name, ok, detail)
  table.insert(results, { name = name, ok = ok and true or false })
  ns.log(
    string.format("TEST %s: %s%s", ok and "ok  " or "FAIL", name, detail and (" (" .. tostring(detail) .. ")") or "")
  )
end

local function bound(key)
  local ok, action = pcall(GetBindingAction, key, true)
  return ok and action or "?"
end

local function snap(label)
  ns.log("SCREENSHOT " .. label)
  pcall(Screenshot)
end

local function report()
  local db = ns.db
  ns.log(
    "REPORT build "
      .. tostring((GetBuildInfo()))
      .. ", gamepad "
      .. tostring(C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled())
      .. ", aimWith "
      .. tostring(db.aimWith)
      .. ", cancel "
      .. tostring(db.cancel)
      .. ", bar state "
      .. tostring(ns.barState())
  )
  local ok, n = pcall(GetNumBindings)
  ns.log("REPORT bindings in the game: " .. tostring(ok and n))
  -- Every controller button: what it does, plain and with overrides.
  for _, m in ipairs({ "", "SHIFT-", "CTRL-", "ALT-" }) do
    for _, base in ipairs(ns.PAD_ORDER) do
      local key = m .. base
      local ok1, plain = pcall(GetBindingAction, key)
      local ok2, over = pcall(GetBindingAction, key, true)
      plain, over = ok1 and plain or "?", ok2 and over or "?"
      if plain ~= "" or over ~= "" then
        local r = ns.resolve(over ~= "" and over or plain)
        ns.log(
          string.format(
            "REPORT pad %s = %s | override %s -> %s",
            key,
            plain,
            over,
            r and ns.spellLabel(r.spell) or "no spell"
          )
        )
      end
    end
  end
  for _, cv in ipairs({ "GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
    local okc, v = pcall(C_CVar.GetCVar, cv)
    ns.log("REPORT cvar " .. cv .. " = " .. tostring(okc and v))
  end
  -- Any game API about controllers or bindings, in case this client keeps
  -- controller bindings apart from the key bindings.
  local apis = {}
  for name, t in pairs(_G) do
    if type(name) == "string" and type(t) == "table" and name:match("^C_") then
      local low = name:lower()
      if low:find("pad") or low:find("controller") or low:find("bind") or low:find("console") then
        local fns = {}
        for fname, f in pairs(t) do
          if type(f) == "function" then
            table.insert(fns, fname)
          end
        end
        table.sort(fns)
        table.insert(apis, name .. "{" .. table.concat(fns, ",") .. "}")
      end
    end
  end
  table.sort(apis)
  for _, a in ipairs(apis) do
    ns.log("REPORT api " .. a)
  end
  for _, b in ipairs(ns.binds or {}) do
    local states = {}
    for _, s in ipairs(ns.BAR_STATES) do
      if b.states[s] then
        table.insert(states, s)
      end
    end
    ns.log(
      string.format(
        "REPORT bind %s = %s -> %s%s heal=%s states=%s%s",
        b.key,
        b.kb and ("KeyBars " .. b.layer) or b.command,
        ns.spellLabel(b.spell),
        "",
        tostring(b.heal),
        table.concat(states, ","),
        ns.aimConf(b) and (" AIM tap=" .. tostring(ns.aimConf(b).tap)) or ""
      )
    )
  end
  for i, h in ipairs(ns.heals) do
    local key = h:GetAttribute("hp-key")
    if key then
      ns.log(
        string.format(
          "REPORT heal%d key=%s spell=%s now bound to %s",
          i,
          key,
          tostring(h:GetAttribute("hp-spell")),
          bound(key)
        )
      )
    end
  end
end

-- The steps, one after another with a pause so each screen is drawn.
local function steps()
  local list = {}
  local function add(fn)
    table.insert(list, fn)
  end
  local dbg

  add(function()
    report()
    ns.openOptions()
    dbg = ns.optionsDebug()
    check("settings open", dbg.panel and dbg.panel:IsShown())
    check(
      "pad and arrows drive the panel",
      bound("PADDDOWN"):find("HealpadNavDOWN") and bound("DOWN"):find("HealpadNavDOWN"),
      bound("DOWN")
    )
  end)
  add(function()
    check("Buttons tab shows", dbg.ui.buttons:IsShown() and not dbg.ui.aim:IsShown(), "rows " .. #dbg.rows)
    snap("buttons")
  end)
  for _, tab in ipairs({ "aim", "frames" }) do
    add(function()
      ns.optionsNav("RB")
      check(
        tab .. " tab after RB",
        dbg.st.tab == tab and dbg.ui[tab]:IsShown() and not dbg.ui.buttons:IsShown(),
        "tab=" .. tostring(dbg.st.tab)
      )
    end)
    add(function()
      snap(tab)
    end)
  end
  add(function()
    check("diamond shows on Frames", ns.diamond:IsShown())
    for _, d in ipairs(ns.DIRS) do
      local f = ns.spots[d]
      local x, y = f:GetCenter()
      local okName, name = pcall(function()
        return f.name:GetText() .. ""
      end)
      ns.log(
        string.format(
          "REPORT spot %s shown=%s at %s,%s name=%s",
          d,
          tostring(f:IsVisible()),
          tostring(x and math.floor(x)),
          tostring(y and math.floor(y)),
          okName and name or "(secret)"
        )
      )
    end
  end)
  add(function()
    ns.optionsNav("RB")
    check("back to Buttons", dbg.st.tab == "buttons" and dbg.ui.buttons:IsShown())
    dbg.panel:Hide()
    check("closing gives the pad and arrows back", not bound("DOWN"):find("HealpadNav"), bound("DOWN"))
  end)

  -- A hold, an aim and a cancel, through the real secure buttons.
  add(function()
    local heal
    for _, h in ipairs(ns.heals) do
      if h:GetAttribute("hp-key") and not heal then
        heal = h
      end
    end
    for _, b in ipairs(ns.binds or {}) do
      if not heal and b.kb and ns.aimConf(b) then
        heal = _G[b.button]
      end
    end
    if not heal then
      ns.log("TEST skip: no Hold to Aim spell set up, so no hold was tried (set one in /hp)")
      return
    end
    local ctl = ns.ctl
    -- An addon can't click a secure button, so this runs the press part of
    -- the heal snippet as the controller, the way the game would.
    SecureHandlerExecute(ctl, ns.TEST_PRESS:format(heal:GetName()))
    check("press opens the diamond", ctl:GetAttribute("state") == "aim" and ns.diamond:IsShown())
    local cancel = ns.db.cancel or "PAD2"
    check("while aiming, arrows aim", bound("UP"):find("HealpadDirUP"), bound("UP"))
    check(
      "while aiming, the d-pad aims",
      bound("PADDUP"):find("HealpadDir") or ns.db.aimWith ~= "dpad",
      bound("PADDUP")
    )
    check(
      "while aiming, the cancel button cancels",
      bound(cancel):find("HealpadCancel"),
      cancel .. "=" .. bound(cancel)
    )
    SecureHandlerExecute(_G.HealpadDirUP, ns.DIR_SNIPPET)
    local up = ctl:GetAttribute("sel")
    check("up aims at someone (or nobody up there)", up == "UP" or not ctl:GetAttribute("u1-UP"), tostring(up))
    snap("aiming")
  end)
  add(function()
    local ctl = ns.ctl
    if ctl:GetAttribute("state") ~= "aim" then
      return
    end
    SecureHandlerExecute(_G.HealpadDirDOWN, ns.DIR_SNIPPET)
    check(
      "the opposite way comes back to you",
      ctl:GetAttribute("sel") == "SELF" or ctl:GetAttribute("sel") == nil,
      tostring(ctl:GetAttribute("sel"))
    )
    SecureHandlerExecute(_G.HealpadCancel, ns.CANCEL_SNIPPET)
    check("cancel closes the diamond", ctl:GetAttribute("state") == "idle" and not ns.diamond:IsShown())
    check("aim keys given back", not bound("UP"):find("HealpadDir"), bound("UP"))
  end)
  return list
end

-- The press half of the heal snippet, run as the controller (self).
ns.TEST_PRESS = [[
  local owner = self
  owner:SetAttribute("held", "%s")
  owner:SetAttribute("sel", nil)
  owner:SetAttribute("page", 1)
  owner:ClearBindings()
  for i = 1, owner:GetAttribute("ak-n") or 0 do
    local k = owner:GetAttribute("ak" .. i)
    if not owner:GetAttribute("skip-" .. k) then
      owner:SetBindingClick(true, k, owner:GetAttribute("ab" .. i))
    end
  end
  owner:SetAttribute("state", "aim")
]]

function ns.selfTest()
  if InCombatLockdown() then
    ns.say("after combat.")
    return
  end
  results = {}
  ns.db.log = {}
  ns.log(
    "TEST start, Healpad "
      .. tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Healpad", "Version"))
  )
  local oldHandler = geterrorhandler()
  seterrorhandler(function(err)
    ns.log("LUA ERROR " .. tostring(err))
    return oldHandler(err)
  end)
  ns.say("testing…")
  local list = steps()
  local i = 0
  local function nextStep()
    i = i + 1
    local fn = list[i]
    if not fn then
      seterrorhandler(oldHandler)
      local bad = 0
      for _, r in ipairs(results) do
        if not r.ok then
          bad = bad + 1
        end
      end
      ns.log(string.format("TEST done: %d ok, %d failed", #results - bad, bad))
      ns.say(string.format("test done: %d ok, %d failed. Type /reload so the log is saved.", #results - bad, bad))
      return
    end
    local ok, err = pcall(fn)
    if not ok then
      ns.log("LUA ERROR in step " .. i .. ": " .. tostring(err))
    end
    C_Timer.After(0.8, nextStep)
  end
  nextStep()
end
