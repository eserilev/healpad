-- The documented WoW Forever 1.60.1.70450 API that Healpad uses.
-- Written by scripts/wow-api.sh from Blizzard_APIDocumentationGenerated. Do not edit.
-- A patch can change the arguments, returns, or secret flags and keep the name. The diff shows it.
-- The scan does not know the type of each object, so methods has each widget type with a called name.
return {
  build = "1.60.1.70450",
  functions = {
    ["C_CurveUtil.CreateColorCurve"] = {
      Returns = {
        { Name = "curve", Type = "LuaColorCurveObject", Nilable = false },
      },
    },
    ["C_Spell.GetSpellName"] = {
      MayReturnNothing = true,
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
      },
      Returns = {
        { Name = "name", Type = "cstring", Nilable = false },
      },
    },
    ["C_Spell.GetSpellSubtext"] = {
      MayReturnNothing = true,
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
      },
      Returns = {
        { Name = "subtext", Type = "string", Nilable = false },
      },
    },
    ["C_Spell.GetSpellTexture"] = {
      MayReturnNothing = true,
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
      },
      Returns = {
        { Name = "iconID", Type = "fileID", Nilable = false },
        { Name = "originalIconID", Type = "fileID", Nilable = false },
        { Name = "conditionalIconID", Type = "fileID", Nilable = true },
      },
    },
    ["C_Spell.IsSpellInRange"] = {
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "spellIdentifier", Type = "SpellIdentifier", Nilable = false },
        { Name = "targetUnit", Type = "UnitToken", Nilable = true },
      },
      Returns = {
        { Name = "inRange", Type = "bool", Nilable = true },
      },
    },
    ["C_SpellBook.GetNumSpellBookSkillLines"] = {
      Returns = {
        { Name = "numSpellBookSkillLines", Type = "number", Nilable = false },
      },
    },
    ["C_SpellBook.GetSpellBookItemInfo"] = {
      MayReturnNothing = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "spellBookItemSlotIndex", Type = "luaIndex", Nilable = false },
        { Name = "spellBookItemSpellBank", Type = "SpellBookSpellBank", Nilable = false },
      },
      Returns = {
        { Name = "spellBookItemInfo", Type = "SpellBookItemInfo", Nilable = false },
      },
    },
    ["C_SpellBook.GetSpellBookSkillLineInfo"] = {
      MayReturnNothing = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "skillLineIndex", Type = "luaIndex", Nilable = false },
      },
      Returns = {
        { Name = "skillLineInfo", Type = "SpellBookSkillLineInfo", Nilable = false },
      },
    },
    ["C_SpellBook.IsSpellBookItemHelpful"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "spellBookItemSlotIndex", Type = "luaIndex", Nilable = false },
        { Name = "spellBookItemSpellBank", Type = "SpellBookSpellBank", Nilable = false },
      },
      Returns = {
        { Name = "isHelpful", Type = "bool", Nilable = false },
      },
    },
    ["C_UnitAuras.GetAuraDataByIndex"] = {
      RequiresUnitAuraAccess = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretWhenUnitAuraRestricted = true,
      Arguments = {
        { Name = "unit", Type = "UnitTokenRestrictedForAddOns", Nilable = false },
        { Name = "index", Type = "luaIndex", Nilable = false },
        { Name = "filter", Type = "AuraFilters", Nilable = true },
      },
      Returns = {
        { Name = "aura", Type = "AuraData", Nilable = true },
      },
    },
    ["C_UnitAuras.GetAuraDispelTypeColor"] = {
      RequiresUnitAuraAccess = true,
      RequiresValidUnitAuraInstance = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretWhenCurveSecret = true,
      SecretWhenUnitAuraRestricted = true,
      Arguments = {
        { Name = "auraInstanceUnit", Type = "UnitToken", Nilable = false },
        { Name = "auraInstanceID", Type = "number", Nilable = false },
        { Name = "curve", Type = "LuaColorCurveObject", Nilable = false },
      },
      Returns = {
        { Name = "dispelTypeColor", Type = "colorRGBA", Mixin = "ColorMixin", Nilable = false },
      },
    },
  },
  methods = {
    ["FrameAPIModelSceneFrameActorBase:Hide"] = {
      Arguments = {},
    },
    ["FrameAPIModelSceneFrameActorBase:IsShown"] = {
      Arguments = {},
      Returns = {
        { Name = "isShown", Type = "bool", Nilable = false },
      },
    },
    ["FrameAPIModelSceneFrameActorBase:SetAlpha"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Alpha },
      Arguments = {
        { Name = "alpha", Type = "number", Nilable = false },
      },
    },
    ["FrameAPIModelSceneFrameActorBase:SetScale"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scale", Type = "number", Nilable = false },
      },
    },
    ["FrameAPIModelSceneFrameActorBase:SetShown"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "show", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["FrameAPIModelSceneFrameActorBase:Show"] = {
      Arguments = {},
    },
    ["FrameAPITooltip:SetText"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Text },
      Arguments = {
        { Name = "text", Type = "cstring", Nilable = false, ConditionalSecret = true },
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "alpha", Type = "number", Nilable = false, ConditionalSecret = true, Default = 1 },
        { Name = "wrap", Type = "bool", Nilable = false, ConditionalSecret = true, Default = false },
      },
    },
    ["LuaColorCurveObjectAPI:AddPoint"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "x", Type = "number", Nilable = false },
        { Name = "y", Type = "colorRGBA", Mixin = "ColorMixin", Nilable = false },
      },
    },
    ["LuaCurveObjectAPI:AddPoint"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "pointX", Type = "number", Nilable = false },
        { Name = "pointY", Type = "number", Nilable = false },
      },
    },
    ["SimpleAnimAPI:HookScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = false },
        { Name = "bindingType", Type = "ScriptBindingType", Nilable = false, Default = "Extrinsic" },
      },
      Returns = {
        { Name = "success", Type = "bool", Nilable = false },
      },
    },
    ["SimpleAnimAPI:SetScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = true },
      },
    },
    ["SimpleAnimGroupAPI:HookScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = false },
        { Name = "bindingType", Type = "ScriptBindingType", Nilable = false, Default = "Extrinsic" },
      },
      Returns = {
        { Name = "success", Type = "bool", Nilable = false },
      },
    },
    ["SimpleAnimGroupAPI:SetScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = true },
      },
    },
    ["SimpleAnimScaleAPI:SetScale"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scaleX", Type = "number", Nilable = false },
        { Name = "scaleY", Type = "number", Nilable = false },
      },
    },
    ["SimpleButtonAPI:RegisterForClicks"] = {
      IsProtectedFunction = true,
      SecretArguments = "NotAllowed",
      Arguments = {
        { Name = "buttons", Type = "ClickButton", Nilable = false, StrideIndex = 1 },
      },
    },
    ["SimpleButtonAPI:SetText"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Text },
      Arguments = {
        { Name = "text", Type = "cstring", Nilable = false, Default = "" },
      },
    },
    ["SimpleCheckboxAPI:GetChecked"] = {
      Arguments = {},
      Returns = {
        { Name = "checked", Type = "bool", Nilable = false },
      },
    },
    ["SimpleCheckboxAPI:SetChecked"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "checked", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleEditBoxAPI:SetJustifyH"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "justifyH", Type = "JustifyHorizontal", Nilable = false },
      },
    },
    ["SimpleEditBoxAPI:SetText"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Text },
      Arguments = {
        { Name = "text", Type = "cstring", Nilable = false },
      },
    },
    ["SimpleEditBoxAPI:SetTextColor"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleFontAPI:SetAlpha"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "alpha", Type = "SingleColorValue", Nilable = false },
      },
    },
    ["SimpleFontAPI:SetJustifyH"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "justifyH", Type = "JustifyHorizontal", Nilable = false },
      },
    },
    ["SimpleFontAPI:SetTextColor"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleFontStringAPI:SetJustifyH"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "justifyH", Type = "JustifyHorizontal", Nilable = false },
      },
    },
    ["SimpleFontStringAPI:SetText"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Text },
      Arguments = {
        { Name = "text", Type = "cstring", Nilable = false, Default = "" },
      },
    },
    ["SimpleFontStringAPI:SetTextColor"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.VertexColor, Enum.SecretAspect.Alpha },
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleFrameAPI:CreateFontString"] = {
      SecretArguments = "NotAllowed",
      Arguments = {
        { Name = "name", Type = "cstring", Nilable = true },
        { Name = "drawLayer", Type = "DrawLayer", Nilable = true },
        { Name = "templateName", Type = "cstring", Nilable = true },
      },
      Returns = {
        { Name = "line", Type = "SimpleFontString", Nilable = false },
      },
    },
    ["SimpleFrameAPI:CreateTexture"] = {
      SecretArguments = "NotAllowed",
      Arguments = {
        { Name = "name", Type = "cstring", Nilable = true },
        { Name = "drawLayer", Type = "DrawLayer", Nilable = true },
        { Name = "templateName", Type = "cstring", Nilable = true },
        { Name = "subLevel", Type = "number", Nilable = true },
      },
      Returns = {
        { Name = "texture", Type = "SimpleTexture", Nilable = false },
      },
    },
    ["SimpleFrameAPI:EnableKeyboard"] = {
      IsProtectedFunction = true,
      SecretArguments = "NotAllowed",
      Arguments = {
        { Name = "enable", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleFrameAPI:GetAttribute"] = {
      ConstSecretAccessor = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretReturnsForAspect = { Enum.SecretAspect.Attributes },
      Arguments = {
        { Name = "attributeName", Type = "cstring", Nilable = false },
      },
      Returns = {
        { Name = "value", Type = "cstring", Nilable = false },
      },
    },
    ["SimpleFrameAPI:Hide"] = {
      IsProtectedFunction = true,
      Arguments = {},
    },
    ["SimpleFrameAPI:IsShown"] = {
      SecretReturnsForAspect = { Enum.SecretAspect.Shown },
      Arguments = {},
      Returns = {
        { Name = "isShown", Type = "bool", Nilable = false },
      },
    },
    ["SimpleFrameAPI:RegisterForDrag"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "buttons", Type = "MouseButton", Nilable = false, StrideIndex = 1 },
      },
    },
    ["SimpleFrameAPI:SetAlpha"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Alpha },
      Arguments = {
        { Name = "alpha", Type = "SingleColorValue", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetAttribute"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretReturnsForAspect = { Enum.SecretAspect.Attributes },
      Arguments = {
        { Name = "attributeName", Type = "cstring", Nilable = false },
        { Name = "value", Type = "cstring", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetClipsChildren"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "clipsChildren", Type = "bool", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetFrameStrata"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.FrameStrata },
      Arguments = {
        { Name = "strata", Type = "FrameStrata", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetMovable"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "movable", Type = "bool", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetScale"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Scale },
      Arguments = {
        { Name = "scale", Type = "number", Nilable = false },
      },
    },
    ["SimpleFrameAPI:SetShown"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Shown },
      Arguments = {
        { Name = "shown", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleFrameAPI:Show"] = {
      IsProtectedFunction = true,
      Arguments = {},
    },
    ["SimpleFrameScriptObjectAPI:GetName"] = {
      SecretReturnsForAspect = { Enum.SecretAspect.ObjectName },
      Arguments = {},
      Returns = {
        { Name = "name", Type = "cstring", Nilable = false },
      },
    },
    ["SimpleHTMLAPI:SetJustifyH"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "textType", Type = "HTMLTextType", Nilable = false },
        { Name = "justifyH", Type = "JustifyHorizontal", Nilable = false },
      },
    },
    ["SimpleHTMLAPI:SetText"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Text },
      Arguments = {
        { Name = "text", Type = "cstring", Nilable = false },
        { Name = "ignoreMarkup", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleHTMLAPI:SetTextColor"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "textType", Type = "HTMLTextType", Nilable = false },
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleLineAPI:ClearAllPoints"] = {
      IsProtectedFunction = true,
      Arguments = {},
    },
    ["SimpleMessageFrameAPI:SetJustifyH"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "justifyH", Type = "JustifyHorizontal", Nilable = false },
      },
    },
    ["SimpleMessageFrameAPI:SetTextColor"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleRegionAPI:SetAlpha"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Alpha },
      Arguments = {
        { Name = "alpha", Type = "SingleColorValue", Nilable = false },
      },
    },
    ["SimpleRegionAPI:SetScale"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Scale },
      Arguments = {
        { Name = "scale", Type = "number", Nilable = false },
      },
    },
    ["SimpleScriptRegionAPI:EnableMouse"] = {
      IsProtectedFunction = true,
      SecretArguments = "NotAllowed",
      Arguments = {
        { Name = "enable", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleScriptRegionAPI:Hide"] = {
      Arguments = {},
    },
    ["SimpleScriptRegionAPI:HookScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = false },
        { Name = "bindingType", Type = "ScriptBindingType", Nilable = false, Default = "Extrinsic" },
      },
      Returns = {
        { Name = "success", Type = "bool", Nilable = false },
      },
    },
    ["SimpleScriptRegionAPI:IsShown"] = {
      SecretReturnsForAspect = { Enum.SecretAspect.Shown },
      Arguments = {},
      Returns = {
        { Name = "isShown", Type = "bool", Nilable = false },
      },
    },
    ["SimpleScriptRegionAPI:SetScript"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptBindings } },
      RequiresAssignableScript = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "scriptTypeName", Type = "ScriptTypeName", Nilable = false },
        { Name = "script", Type = "LuaFunctionReference", Nilable = true },
      },
    },
    ["SimpleScriptRegionAPI:SetShown"] = {
      SecretArguments = "AllowedWhenUntainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.Shown },
      Arguments = {
        { Name = "show", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleScriptRegionAPI:Show"] = {
      Arguments = {},
    },
    ["SimpleScriptRegionResizingAPI:ClearAllPoints"] = {
      IsProtectedFunction = true,
      Arguments = {},
    },
    ["SimpleScriptRegionResizingAPI:SetAllPoints"] = {
      CheckAllowInheritForbiddenLayoutAspects = true,
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "relativeTo", Type = "ScriptRegion", Nilable = false },
        { Name = "doResize", Type = "bool", Nilable = false, Default = true },
      },
    },
    ["SimpleScriptRegionResizingAPI:SetHeight"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "height", Type = "uiUnit", Nilable = false },
      },
    },
    ["SimpleScriptRegionResizingAPI:SetPoint"] = {
      CheckAllowInheritForbiddenLayoutAspects = true,
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "point", Type = "FramePoint", Nilable = false },
        { Name = "relativeTo", Type = "ScriptRegion", Nilable = false },
        { Name = "relativePoint", Type = "FramePoint", Nilable = false },
        { Name = "offsetX", Type = "uiUnit", Nilable = false },
        { Name = "offsetY", Type = "uiUnit", Nilable = false },
      },
    },
    ["SimpleScriptRegionResizingAPI:SetSize"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "x", Type = "uiUnit", Nilable = false },
        { Name = "y", Type = "uiUnit", Nilable = false },
      },
    },
    ["SimpleScriptRegionResizingAPI:SetWidth"] = {
      IsProtectedFunction = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "width", Type = "uiUnit", Nilable = false },
      },
    },
    ["SimpleSliderAPI:SetMinMaxValues"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "minValue", Type = "number", Nilable = false },
        { Name = "maxValue", Type = "number", Nilable = false },
      },
    },
    ["SimpleSliderAPI:SetValue"] = {
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "value", Type = "number", Nilable = false },
        { Name = "treatAsMouseEvent", Type = "bool", Nilable = false, Default = false },
      },
    },
    ["SimpleStatusBarAPI:GetStatusBarTexture"] = {
      Arguments = {},
      Returns = {
        { Name = "texture", Type = "SimpleTexture", Nilable = false },
      },
    },
    ["SimpleStatusBarAPI:SetMinMaxValues"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.BarValue },
      Arguments = {
        { Name = "minValue", Type = "number", Nilable = false },
        { Name = "maxValue", Type = "number", Nilable = false },
        {
          Name = "interpolation",
          Type = "StatusBarInterpolation",
          Nilable = false,
          NeverSecret = true,
          Default = "Immediate",
        },
      },
    },
    ["SimpleStatusBarAPI:SetStatusBarColor"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.VertexColor, Enum.SecretAspect.Alpha },
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleStatusBarAPI:SetStatusBarTexture"] = {
      CheckAllowChangeParent = true,
      SecretArguments = "AllowedWhenUntainted",
      Arguments = {
        { Name = "asset", Type = "TextureAsset", Nilable = false },
      },
      Returns = {
        { Name = "success", Type = "bool", Nilable = false },
      },
    },
    ["SimpleStatusBarAPI:SetValue"] = {
      SecretArguments = "AllowedWhenTainted",
      SecretArgumentsAddAspect = { Enum.SecretAspect.BarValue },
      Arguments = {
        { Name = "value", Type = "number", Nilable = false },
        {
          Name = "interpolation",
          Type = "StatusBarInterpolation",
          Nilable = false,
          NeverSecret = true,
          Default = "Immediate",
        },
      },
    },
    ["SimpleTextureBaseAPI:SetColorTexture"] = {
      ChecksForbiddenAspects = { { Argument = "self", Aspect = Enum.ForbiddenAspect.SetTexture } },
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "colorR", Type = "number", Nilable = false },
        { Name = "colorG", Type = "number", Nilable = false },
        { Name = "colorB", Type = "number", Nilable = false },
        { Name = "a", Type = "SingleColorValue", Nilable = true },
      },
    },
    ["SimpleTextureBaseAPI:SetTexture"] = {
      SecretArguments = "AllowedWhenTainted",
      Arguments = {
        { Name = "textureAsset", Type = "cstring", Nilable = true },
        { Name = "wrapModeHorizontal", Type = "cstring", Nilable = true },
        { Name = "wrapModeVertical", Type = "cstring", Nilable = true },
        { Name = "filterMode", Type = "cstring", Nilable = true },
      },
      Returns = {
        { Name = "success", Type = "bool", Nilable = false },
      },
    },
  },
  events = {},
  undocumented = {},
}
