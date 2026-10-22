NexusBot.Spells = { entries = {}, list = {}, custom = {} }

local realTibiaPresets={
  ['exori gran ico']={name='Annihilation',actionType='targeted_spell',minimumMonsters=1,range=1,mana=300},
  ['exori ico']={name='Brutal Strike',actionType='targeted_spell',minimumMonsters=1,range=1,mana=30},
  ['exori hur']={name='Whirlwind Throw',actionType='targeted_spell',minimumMonsters=1,range=5,mana=40},
  ['exori san']={name='Divine Missile',actionType='targeted_spell',minimumMonsters=1,range=4,mana=20},
  ['exori con']={name='Ethereal Spear',actionType='targeted_spell',minimumMonsters=1,range=5,mana=25},
  ['exori gran con']={name='Strong Ethereal Spear',actionType='targeted_spell',minimumMonsters=1,range=5,mana=55},
  ['exori infir con']={name='Lesser Ethereal Spear',actionType='targeted_spell',minimumMonsters=1,range=5,mana=6},
  ['exori vis']={name='Energy Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=20},
  ['exori flam']={name='Flame Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=20},
  ['exori frigo']={name='Ice Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=20},
  ['exori tera']={name='Terra Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=20},
  ['exori gran vis']={name='Strong Energy Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=60},
  ['exori gran flam']={name='Strong Flame Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=60},
  ['exori gran frigo']={name='Strong Ice Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=60},
  ['exori gran tera']={name='Strong Terra Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=60},
  ['exori max vis']={name='Ultimate Energy Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=100},
  ['exori max flam']={name='Ultimate Flame Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=100},
  ['exori max frigo']={name='Ultimate Ice Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=100},
  ['exori max tera']={name='Ultimate Terra Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=100},
  ['exori pug']={name='Double Jab',actionType='targeted_spell',minimumMonsters=1,range=1,mana=30},
  ['exori infir pug']={name='Swift Jab',actionType='targeted_spell',minimumMonsters=1,range=1,mana=3},
  ['exori med pug']={name='Chained Penance',actionType='targeted_spell',minimumMonsters=1,range=1,mana=180},
  ['exori gran pug']={name='Forceful Uppercut',actionType='targeted_spell',minimumMonsters=1,range=1,mana=325},
  ['exori amp pug']={name='Mystic Repulse',actionType='targeted_spell',minimumMonsters=1,range=3,mana=150},
  ['exori infir amp pug']={name='Lesser Mystic Repulse',actionType='targeted_spell',minimumMonsters=1,range=3,mana=30},
  ['exori nia']={name='Greater Tiger Clash',actionType='targeted_spell',minimumMonsters=1,range=1,mana=50},
  ['exori infir nia']={name='Tiger Clash',actionType='targeted_spell',minimumMonsters=1,range=1,mana=18},
  ['exori moe ico']={name='Physical Strike',actionType='targeted_spell',minimumMonsters=1,range=3,mana=20},
  ['exori ico scu']={name='Shield Bash',actionType='targeted_spell',minimumMonsters=1,range=1,mana=30},
  ['exori scu']={name='Shield Slam',actionType='targeted_spell',minimumMonsters=1,range=1,mana=110},
  ['exori amp vis']={name='Lightning',actionType='targeted_spell',minimumMonsters=1,range=4,mana=60},
  ['exori amp kor']={name="Executioner's Throw",actionType='targeted_spell',minimumMonsters=1,range=5,mana=225},
  ['exori']={name='Berserk',actionType='area_spell',minimumMonsters=2,range=1,radius=1,mana=125},
  ['exori gran']={name='Fierce Berserk',actionType='area_spell',minimumMonsters=3,range=1,radius=1,mana=360},
  ['exori mas']={name='Groundshaker',actionType='area_spell',minimumMonsters=2,range=3,radius=3,mana=200},
  ['exori min']={name='Front Sweep',actionType='directional_spell',minimumMonsters=2,range=1,radius=2,mana=200},
  ['exori dir moe']={name='Ethereal Barrage',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=135},
  ['exori mas pug']={name='Flurry of Blows',actionType='area_spell',minimumMonsters=2,range=2,radius=2,mana=110},
  ['exori gran mas pug']={name='Greater Flurry of Blows',actionType='area_spell',minimumMonsters=3,range=2,radius=2,mana=300},
  ['exori mas amp pug']={name='Thousand Fist Blows',actionType='area_spell',minimumMonsters=3,range=3,radius=3,mana=145},
  ['exori mas nia']={name='Sweeping Takedown',actionType='area_spell',minimumMonsters=2,range=2,radius=2,mana=195},
  ['exori gran mas nia']={name='Spiritual Outburst',actionType='area_spell',minimumMonsters=3,range=3,radius=3,mana=425},
  ['exevo vis lux']={name='Energy Beam',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=40},
  ['exevo gran vis lux']={name='Great Energy Beam',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=110},
  ['exevo max mort']={name='Great Death Beam',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=140},
  ['exevo fur frigo']={name='Forked Glacier',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=180},
  ['exevo fur tera']={name='Forked Thorns',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=180},
  ['exevo vis hur']={name='Energy Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=170},
  ['exevo flam hur']={name='Fire Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=25},
  ['exevo frigo hur']={name='Ice Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=25},
  ['exevo tera hur']={name='Terra Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=170},
  ['exevo gran flam hur']={name='Great Fire Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=120},
  ['exevo gran frigo hur']={name='Strong Ice Wave',actionType='directional_spell',minimumMonsters=2,range=5,radius=5,mana=170},
  ['exevo gran mas vis']={name='Rage of the Skies',actionType='area_spell',minimumMonsters=3,range=5,radius=5,mana=600},
  ['exevo gran mas flam']={name="Hell's Core",actionType='area_spell',minimumMonsters=3,range=5,radius=5,mana=1100},
  ['exevo gran mas frigo']={name='Eternal Winter',actionType='area_spell',minimumMonsters=3,range=5,radius=5,mana=1050},
  ['exevo gran mas tera']={name="Wrath of Nature",actionType='area_spell',minimumMonsters=3,range=5,radius=5,mana=700},
  ['exevo mas san']={name='Divine Caldera',actionType='area_spell',minimumMonsters=3,range=4,radius=4,mana=160},
  ['exevo tempo mas san']={name='Divine Grenade',actionType='area_spell',minimumMonsters=3,range=4,radius=4,mana=160},
  ['exevo ulus frigo']={name='Ice Burst',actionType='area_spell',minimumMonsters=3,range=4,radius=4,mana=230},
  ['exevo ulus tera']={name='Terra Burst',actionType='area_spell',minimumMonsters=3,range=4,radius=4,mana=230},
  ['utito tempo']={name='Blood Rage',actionType='empowerment',minimumMonsters=3,range=3,radius=3,mana=20}
}

local function normalizedWords(words)
  return tostring(words or ''):lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
end

function NexusBot.Spells.getPreset(words)
  local key=normalizedWords(words)
  local preset=realTibiaPresets[key]
  if preset then
    local copy=NexusBot.copy(preset)
    copy.words=key copy.source='Real Tibia preset'
    copy.baselineMana=preset.mana
    if NexusBot.Geometry and NexusBot.Geometry.directional[key] then copy.actionType='directional_spell' end
    local entry=NexusBot.Spells.entries[key]
    if entry and entry.source~='Real Tibia preset' then
      if tonumber(entry.mana) then copy.mana=tonumber(entry.mana) end
      if tonumber(entry.range) and tonumber(entry.range)>0 then copy.range=tonumber(entry.range) end
      copy.source=entry.source
    end
    return copy
  end
  local spell=NexusBot.Spells.entries[key]
  if spell and spell.category=='attack' then
    local targeted=spell.requiresTarget==true
    return {words=key,name=spell.name,source='Client SpellInfo',actionType=targeted and 'targeted_spell' or 'absolute_spell',
      minimumMonsters=targeted and 1 or 2,range=tonumber(spell.range) or (targeted and 5 or 3),radius=tonumber(spell.range) or 3,
      mana=tonumber(spell.mana),requiresTarget=true}
  end
  return nil
end

function NexusBot.Spells.defaultFootprint(words,actionType)
  return actionType=='targeted_spell' and 'target' or (NexusBot.Geometry and NexusBot.Geometry.spells[normalizedWords(words)]) or 'unknown'
end

function NexusBot.Spells.direction(rule,context)
  local direction=context.player and context.player.getDirection and context.player:getDirection() or tonumber((rule.action or {}).direction) or North
  if (rule.pattern or {}).autoFace~=false and context.target then
    local p=context.target:getPosition()
    local a=context.position
    if p and a and p.z==a.z then
      local dx,dy=p.x-a.x,p.y-a.y
      if math.abs(dx)>=math.abs(dy) and dx~=0 then direction=dx>0 and East or West
      elseif dy~=0 then direction=dy>0 and South or North end
    end
  end
  return direction
end

function NexusBot.Spells.countAffected(rule,context,radius)
  if rule.type=='empowerment' then return context.count('monster',radius) end
  return (context.areaPlan or NexusBot.Geometry.best(rule,context)).count
end

local function category(info)
  local spellType = tostring(info.type or ''):lower()
  local words = tostring(info.words or ''):lower()
  local name = tostring(info.name or ''):lower()
  if name:find('heal') or words:find('exura') then return 'healing' end
  if name:find('haste') or name:find('buff') or words:find('utito') or words:find('utamo') then return 'buff' end
  if spellType == 'conjure' or name:find('light') or name:find('support') then return 'support' end
  return 'attack'
end

function NexusBot.Spells.init()
  NexusBot.Spells.entries, NexusBot.Spells.list = {}, {}
  local spellInfo = SpellInfo or (modules.gamelib and modules.gamelib.SpellInfo) or {}
  for profileName, spells in pairs(spellInfo) do
    for displayName, info in pairs(spells) do
      local words = tostring(info.words or '')
      local key = words:lower()
      if key ~= '' and not NexusBot.Spells.entries[key] then
        local entry = {
          id = tostring(info.id or key), name = info.name or displayName, words = words,
          type = info.type, category = category(info), mana = info.mana, soul = info.soul,
            cooldown = info.exhaustion, groups = NexusBot.copy(info.group or {}),
            range = info.range, requiresTarget = info.needTarget,
          vocations = NexusBot.copy(info.vocations or {}), clientId = info.clientId,
          profile = profileName, source = 'SpellInfo'
        }
        NexusBot.Spells.entries[key] = entry
        NexusBot.Spells.list[#NexusBot.Spells.list + 1] = entry
      end
    end
  end
  for words,preset in pairs(realTibiaPresets) do
    if not NexusBot.Spells.entries[words] then
      local entry={id=words,name=preset.name or words,words=words,type='instant',category=preset.actionType=='empowerment' and 'buff' or 'attack',mana=preset.mana,
        range=preset.range,requiresTarget=preset.actionType=='targeted_spell',source='Real Tibia preset'}
      NexusBot.Spells.entries[words]=entry
      NexusBot.Spells.list[#NexusBot.Spells.list+1]=entry
    end
  end
  for _, custom in ipairs(NexusBot.Storage.get().customSpells or {}) do NexusBot.Spells.addCustom(custom, false) end
  table.sort(NexusBot.Spells.list, function(a, b) return a.name:lower() < b.name:lower() end)
end

function NexusBot.Spells.addCustom(custom, save)
  if type(custom) ~= 'table' or not custom.words or custom.words == '' then return end
  local entry = NexusBot.merge({ id=NexusBot.id('spell'), name=custom.words, category='custom', source='custom' }, custom)
  NexusBot.Spells.entries[entry.words:lower()] = entry
  NexusBot.Spells.list[#NexusBot.Spells.list + 1] = entry
  if save ~= false then
    NexusBot.Storage.get().customSpells[#NexusBot.Storage.get().customSpells + 1] = NexusBot.copy(entry)
    NexusBot.Storage.touch()
  end
  return entry
end

function NexusBot.Spells.get(words) return words and NexusBot.Spells.entries[normalizedWords(words)] or nil end

function NexusBot.Spells.search(query, filter, limit)
  query, filter, limit = tostring(query or ''):lower(), filter or 'all', limit or 80
  local result = {}
  for _, spell in ipairs(NexusBot.Spells.list) do
    if (filter == 'all' or spell.category == filter) and
       (query == '' or spell.name:lower():find(query, 1, true) or spell.words:lower():find(query, 1, true)) then
      result[#result + 1] = spell
      if #result >= limit then break end
    end
  end
  return result
end

function NexusBot.Spells.applyIcon(widget, spell)
  local settings = SpelllistSettings or (modules.gamelib and modules.gamelib.SpelllistSettings)
  local spellApi = Spells or (modules.gamelib and modules.gamelib.Spells)
  if not widget or not spell or not spell.clientId or not settings or not settings[spell.profile] or not spellApi then return false end
  widget:setImageSource(spellApi.getIconFileByProfile(spell.profile))
  widget:setImageClip(spellApi.getImageClip(spell.clientId, spell.profile))
  widget:setImageSize({ width = 24, height = 24 })
  return true
end
