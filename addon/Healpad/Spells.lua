-- The spells a heal key can hold: every friendly spell in the spellbook, read
-- at run time. WoW Forever classes have their own spells, so none is built in.
-- Each rank is its own spell id, so a key can hold Rank 1 and another Rank 7.
local _, ns = ...

function ns.scanSpells()
  local out, seen = {}, {}
  local bank = Enum.SpellBookSpellBank.Player
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if info and not info.shouldHide then
      for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if item and item.itemType == Enum.SpellBookItemType.Spell
          and C_SpellBook.IsSpellBookItemHelpful(slot, bank) then
          local id = item.spellID or item.actionID
          if id and not seen[id] then
            seen[id] = true
            table.insert(out, id)
          end
        end
      end
    end
  end
  return out
end

-- "Healing Touch (Rank 3)", or the name alone.
function ns.spellLabel(id)
  if not id then return "-" end
  local name = C_Spell.GetSpellName(id) or ("#" .. id)
  local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
  if sub and sub ~= "" then return name .. " (" .. sub .. ")" end
  return name
end

function ns.spellIcon(id)
  return id and C_Spell.GetSpellTexture(id) or 134400
end
