-- Wheel of Destiny per protocol version.
--
-- The wheel data in bonus.lua / icons.lua / wheelclass.lua is the layout of
-- protocol 15.11 up to 15.24. Protocol 15.25 (Vocation Adjustments, June 2026)
-- replaced or changed several conviction perks, revelation perks and the
-- mitigation values; 15.30 keeps that layout. This file applies those changes
-- on top of the base data while the connected server uses 15.25 or newer, and
-- restores the base data for older servers. Slice positions do not change
-- (except the Knight's Groundshaker / Shield Slam swap), so the points the
-- server stores per slice stay where they are.
--
-- Source: CipSoft, "Vocation Adjustments Release State" (tibia.com news 8833)
-- and the 15.25 update notes.

WheelVersion = WheelVersion or {}

local MODERN_PROTOCOL = 1525
local ICON_PATH = "/modules/game_wheel/images/spells/"
local MARK = "\239\191\189" -- the augment bullet used by the base data

-- Conviction slots that differ from the base data (15.25+). aug1/aug2 are
-- the Stage I / Stage II effects; icon replaces the slice icon.
local SPELLS = {
  [KNIGHT] = {
    spell_1 = { name = "Front Sweep", aug1 = "+40% Base Power", aug2 = "Hits 2 more squares to the\nsides (5 in total)" },
    -- Shield Slam replaces Chivalrous Challenge and swapped places with Groundshaker.
    spell_2 = { name = "Shield Slam", aug1 = "+15% Life Leech", aug2 = "+25% Damage Reduction\n(75% in total)", icon = "shield_slam" },
    spell_3 = { name = "Groundshaker", aug1 = "-2s Cooldown", aug2 = "+12.5% Base Damage", iconFrom = "spell_2" },
  },
  [PALADIN] = {
    spell_1 = { name = "Ethereal Barrage", aug1 = "+10% Life Leech", aug2 = "+10% Critical Hit Chance", icon = "ethereal_barrage" },
    spell_3 = { name = "Divine Dazzle", aug1 = "Jumps to +2 additional\ntargets", aug2 = "-8s Cooldown" },
    spell_4 = { name = "Divine Barrage", aug1 = "+10% Base Damage", aug2 = "+15% Base Damage", icon = "divine_barrage" },
  },
  [SORCERER] = {
    spell_2 = { name = "Special Spells", aug1 = "-4s Cooldown", aug2 = "+50% Base Damage" },
    spell_3 = { name = "Death Echo", aug1 = "-2s Cooldown", aug2 = "+8% Base Damage", icon = "death_echo" },
    spell_4 = { name = "Energy Wave", aug1 = "Affected area enlarged", aug2 = "+10% Base Damage" },
  },
  [DRUID] = {
    spell_1 = { name = "Strong Ice Wave", aug1 = "+6% Base Damage", aug2 = "Affected area enlarged" },
    spell_3 = { name = "Forked Spells", aug1 = "-2s Cooldown", aug2 = "Hits +1 additional target", icon = "forked_glacier",
      note = "Improves Forked Glacier and\nForked Thorns" },
    spell_4 = { name = "Terra Wave", aug1 = "+5% Base Damage", aug2 = "Adds 10% life leech to this\nspell" },
    spell_5 = { name = "Heal Friend", aug1 = "+4% Base Healing", aug2 = "+6% Base Healing" },
  },
  [MONK] = {
    spell_2 = { name = "Mass Spirit Mend", aug1 = "+8% Base Healing", aug2 = "-4s Cooldown" },
    spell_3 = { name = "Mystic Repulse", aug1 = "-6s Cooldown", aug2 = "+40% Base Damage" },
    spell_4 = { name = "Flurry of Blows", aug1 = "Affected area enlarged", aug2 = "+15% Base Damage" },
    spell_5 = { name = "Thousand Fist Blows", aug1 = "+40% Critical Extra Damage", aug2 = "-6s Cooldown", icon = "thousand_fist_blows" },
  },
}

-- Vocation passive conviction perks (WheelConsts special_1 / special_2).
local SPECIALS = {
  special_1 = {
    [DRUID] = { "Healing Link", "If you heal someone with Nature's Embrace or Heal Friend, you\nalso heal yourself for 25% of the applied healing." },
    [MONK] = { "Guiding Presence", "Gain an aura that shares 100% of your mantra with members of\nyour group." },
  },
  special_2 = {
    [KNIGHT] = { "Battle Healing", "Increases the effect of your healing spells by 10%.\nThe bonus is tripled while you wear a shield." },
    [SORCERER] = { "Focus Mastery", "Increases the damage of your next damage spell by 35% within 12\nseconds after casting a focus spell. Also reduces the cooldown of\nfocus spells by 2 seconds." },
    [MONK] = { "Sanctuary", "Consuming Harmony creates a field lasting 5 seconds, increasing your\ndamage and healing done by 2% for each Harmony consumed. The field\nalso adds 10% damage against adjacent enemies and 10% healing to\nadjacent allies." },
  },
}

-- Revelation perks per domain that differ (title, then description parts:
-- plain strings, or {a, b, c} values for stage 1/2/3).
local REVELATIONS = {
  [KNIGHT] = {
    [3] = { title = "Combat Mastery\nImprove your combat\nprowess based on the\nequipment you use.",
      text = { "Reduces the damage you take based on your missing hit points;\ndoubled while you wear a shield. Increases the damage you deal\nbased on your target's missing hit points; doubled while you wield\na two-handed weapon." } },
  },
  [SORCERER] = {
    [2] = { title = "Beam Mastery\nBoosts all of your beam spells\nand unlocks a beam spell that\ndeals death damage.",
      text = { "Your beam spells also hit the squares next to the beam for ", { "40%", "60%", "80%" },
        "\nof the initial damage. The damage still scales with the number of\ntargets hit." } },
    [3] = { title = "Lord of Destruction\nStrengthens the buffs of\nyour elemental stances.",
      text = { "Master of Flames: +", { "2%", "3%", "4%" }, " fire base power.\nMaster of Thunder: +",
        { "2%", "3%", "4%" }, " energy critical hit chance.\nMaster of Decay: +", { "15%", "22.5%", "30%" },
        " death critical extra damage." } },
  },
  [DRUID] = {
    [2] = { title = "Blessing of the Grove\nYour healing spells can heal\ncritically and heal more on\nwounded targets.",
      text = { "Healing spells can critically heal, using your critical hit chance\nand critical extra damage. They heal ", { "5%", "7.5%", "10%" },
        " more on targets below\n60% of their hit points; doubled below 30%." } },
  },
}

-- Names shown elsewhere (summary, revelation list, gem mods).
local RENAMES = { ["Drain Body"] = "Lord of Destruction" }

local function protocolVersion()
  if g_game.getProtocolVersion then
    local version = g_game.getProtocolVersion()
    if version and version > 0 then
      return version
    end
  end
  return g_game.getClientVersion()
end

function WheelVersion.isModern()
  return protocolVersion() >= MODERN_PROTOCOL
end

function WheelVersion.rename(name)
  if WheelVersion.active and RENAMES[name] then
    return RENAMES[name]
  end
  return name
end

local function spellOverride(index)
  if not WheelVersion.active then
    return nil
  end
  local bonus = WheelBonus[index - 1]
  local list = bonus and SPELLS[WheelOfDestiny.vocationId]
  return list and list[bonus.conviction] or nil, bonus
end

-- Slice icon for 15.25+: {source, clip} or nil to keep the base icon.
function WheelVersion.sliceIcon(index)
  local override = spellOverride(index)
  if not override then
    return nil
  end
  if override.icon then
    return ICON_PATH .. override.icon, "0 0 32 32"
  end
  if override.iconFrom then
    local icons = WheelIcons[WheelOfDestiny.vocationId]
    for id, bonus in pairs(WheelBonus) do
      if bonus.conviction == override.iconFrom and icons[id + 1] then
        return "/images/game/wheel/icons-skillwheel-mediumperks", icons[id + 1].iconRect
      end
    end
  end
  return nil
end

------------------------------------------------------------------------------
-- Data that is a plain value: swapped in and out with the version.
------------------------------------------------------------------------------
local saved = nil

local function swapValue(tbl, key, value)
  saved[#saved + 1] = { tbl, key, tbl[key] }
  tbl[key] = value
end

local function renameStrings(tbl)
  for _, entry in pairs(tbl) do
    if type(entry) == "table" then
      for field, value in pairs(entry) do
        if type(value) == "string" then
          for old, new in pairs(RENAMES) do
            if value:find(old, 1, true) then
              swapValue(entry, field, (value:gsub(old, new)))
            end
          end
        elseif type(value) == "table" and field ~= "domain" then
          renameStrings({ value })
        end
      end
    end
  end
end

local function applyModernData()
  saved = {}
  -- Dedication perks: 0.075% mitigation multiplier per promotion point (was 0.03%).
  swapValue(WheelConsts, "mitigation", 0.075)
  -- Mitigation gem mod: 20/22/24/30% (was 5/5.5/6/7.5%), i.e. 4x the base value.
  if RegularGemDescription[30] then swapValue(RegularGemDescription[30], "bonus1", 20) end
  if BasicMods[30] then swapValue(BasicMods[30], "baseI", 20) end
  -- Vocation passives
  for key, byVocation in pairs(SPECIALS) do
    for vocation, data in pairs(byVocation) do
      if WheelConsts[key] and WheelConsts[key][vocation] then
        swapValue(WheelConsts[key], vocation, data)
      end
    end
  end
  renameStrings(SupremeGemDescription)
  for _, mods in pairs(VocationSupremeMods) do
    renameStrings(mods)
  end
end

local function restoreBaseData()
  if not saved then
    return
  end
  for i = #saved, 1, -1 do
    local entry = saved[i]
    entry[1][entry[2]] = entry[3]
  end
  saved = nil
end

-- Called whenever the wheel opens: follows the protocol of the current server.
function WheelVersion.apply()
  local modern = WheelVersion.isModern()
  if modern == WheelVersion.active then
    return
  end
  if modern then
    applyModernData()
  else
    restoreBaseData()
  end
  WheelVersion.active = modern
end

------------------------------------------------------------------------------
-- Text builders in the same style as bonus.lua
------------------------------------------------------------------------------
-- attribute = {sliceA, sliceB}: both slices of the same augment (WheelConsts).
local function stageUnlocked(attribute, stage)
  if type(attribute) ~= "table" then
    return false
  end
  local a, b = WheelOfDestiny.isLitFull(attribute[1]), WheelOfDestiny.isLitFull(attribute[2])
  if stage == 1 then
    return a or b
  end
  return a and b
end

local function buildSlotText(override, points, maxPoints, attribute)
  local t = {}
  -- Long names use the short prefix, like the base data ("Aug. Sweeping Takedown").
  local prefix = #override.name > 16 and "Aug. " or "Augmented "
  setStringColor(t, prefix .. override.name .. "\n", (points >= maxPoints and "#C0C0C0" or "#707070"))
  setStringColor(t, MARK, "white")
  setStringColor(t, ": " .. override.aug1 .. "\n", stageUnlocked(attribute, 1) and "#C0C0C0" or "#707070")
  setStringColor(t, MARK, "white")
  setStringColor(t, ": " .. override.aug2, stageUnlocked(attribute, 2) and "#C0C0C0" or "#707070")
  if override.note then
    setStringColor(t, "\n" .. override.note, "#707070")
  end
  return t
end

local function buildPerkTooltip(override)
  local message = {}
  setStringColor(message, MARK, "white")
  setStringColor(message, override.aug1:gsub("\n", " ") .. "\n", "#3F3F3F")
  setStringColor(message, MARK, "white")
  setStringColor(message, override.aug2:gsub("\n", " "), "#3F3F3F")
  if override.note then
    setStringColor(message, "\n" .. override.note:gsub("\n", " "), "#3F3F3F")
  end
  return message
end

------------------------------------------------------------------------------
-- Hooks on the base functions (installed once, when the module loads)
------------------------------------------------------------------------------
local function specialOverride(index)
  if not WheelVersion.active then
    return nil
  end
  local bonus = WheelBonus[index - 1]
  local byVocation = bonus and SPECIALS[bonus.conviction]
  return byVocation and byVocation[WheelOfDestiny.vocationId] or nil
end

-- Slice text of a passive: name, then the description wrapped to the slice
-- width (about 30 characters per line); shortened unless fullMessage.
local function wrapText(text, width)
  local lines, line = {}, ""
  for word in text:gsub("\n", " "):gmatch("%S+") do
    if #line + #word + 1 > width and #line > 0 then
      lines[#lines + 1] = line
      line = word
    else
      line = #line > 0 and (line .. " " .. word) or word
    end
  end
  if #line > 0 then lines[#lines + 1] = line end
  return lines
end

local function buildSpecialText(special, fullMessage)
  local lines = wrapText(special[2], 30)
  if not fullMessage and #lines > 4 then
    lines = { lines[1], lines[2], lines[3], lines[4]:sub(1, 26) .. "..." }
  end
  return special[1] .. "\n" .. table.concat(lines, "\n")
end

local baseConvictionBonus = getConvictionBonus
function getConvictionBonus(index, fullMessage)
  local special = specialOverride(index)
  if special then
    return buildSpecialText(special, fullMessage)
  end
  local override, bonus = spellOverride(index)
  if override then
    local points = WheelOfDestiny.pointInvested[index] or 0
    return buildSlotText(override, points, bonus.maxPoints, WheelConsts[bonus.conviction])
  end
  return baseConvictionBonus(index, fullMessage)
end

local baseConvictionTooltip = getConvictionBonusTooltip
function getConvictionBonusTooltip(index)
  local special = specialOverride(index)
  if special then
    return special[2]
  end
  local override = spellOverride(index)
  if override then
    return buildPerkTooltip(override)
  end
  return baseConvictionTooltip(index)
end

-- Summary rows are keyed like getConvictionPerks' order table.
local PERK_ORDER = { special_1 = 1, special_2 = 2, spell_1 = 8, spell_2 = 9, spell_3 = 10, spell_4 = 11, spell_5 = 12 }

local baseConvictionPerks = getConvictionPerks
function getConvictionPerks()
  local convictions = baseConvictionPerks()
  if not WheelVersion.active then
    return convictions
  end
  local list = SPELLS[WheelOfDestiny.vocationId]
  if list then
    for key, override in pairs(list) do
      local row = convictions[PERK_ORDER[key]]
      if row then
        row.perk = "Aug. " .. override.name
        row.tooltip = buildPerkTooltip(override)
      end
    end
  end
  return convictions
end

local basePassiveInfo = getPassiveInfo
function getPassiveInfo(domain)
  local byVocation = WheelVersion.active and REVELATIONS[WheelOfDestiny.vocationId]
  local revelation = byVocation and byVocation[domain]
  if not revelation then
    return basePassiveInfo(domain)
  end
  local extraPoints = WheelOfDestiny.extraPassivePoints[domain] or 0
  local passive = (WheelOfDestiny.passivePoints[domain] or 0) + extraPoints
  local stage = passive >= 1000 and 3 or passive >= 500 and 2 or passive >= 250 and 1 or 0
  local message = {}
  for _, part in ipairs(revelation.text) do
    if type(part) == "table" then
      for i = 1, 3 do
        setStringColor(message, part[i], stage == i and "#ffffff" or "#3F3F3F")
        if i < 3 then setStringColor(message, "/", "#3F3F3F") end
      end
    else
      setStringColor(message, part, "#3F3F3F")
    end
  end
  return revelation.title, message
end
