-- MAGIC SHOOTER: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('magic_shooter', 'MAGIC SHOOTER', 7, false)
NexusBot.Categories.profilePower(category)

-- ==================== GUI / LAYOUT ====================
NexusBot.Features.MagicShooter = { id='magic_shooter' }

local actionTypes={
  {'Absolute Spell','absolute_spell'},{'Targeted Spell','targeted_spell'},{'Directional Spell','directional_spell'},
  {'Area Spell','area_spell'},{'Empowerment','empowerment'},{'Rune','rune'},{'Item','item'},{'Custom Spell','custom_action'}
}

local applySpellPreset, newRule, describe
local function clearPreset(rule)
  rule.autoPreset=nil
  rule.action=rule.action or {}
  rule.action.footprint=nil rule.action.geometryPreset=nil rule.action.customMask=nil
  rule.pattern={}
  rule.advanced=rule.advanced or {}
  rule.advanced.minimumMana=0 rule.advanced.requiresTarget=false rule.advanced.stopWhenNoTarget=false
  local kept={}
  for _,c in ipairs((rule.conditions or {}).children or {}) do if not c.autoSpellPreset then kept[#kept+1]=c end end
  rule.conditions=rule.conditions or {mode='AND'} rule.conditions.children=kept
end
local function changeType(rule,value)
  clearPreset(rule)
  rule.type=value rule.action={target='target'} rule.advanced.range=5
end
local function renderPattern(c,p,r)
  local U=NexusBot.UI local G=NexusBot.Geometry local a=r.action
  local shape=G.shape(r)
  if shape=='target' or shape=='chain' or r.type=='custom_action' or r.type=='empowerment' or r.type=='item' then
    U.label(p,shape=='target' and 'Single target' or 'No damage footprint')
    return
  end
  local options={{'Automatic','auto'}}
  for _,id in ipairs({'adjacent','wave4','squarewave5','wave7','shortwave3','sweep','beam5','beam6','beam7','beam8','circle2','circle3','diamond5','diamond6','flurry','greater_flurry','sweeping','burst'}) do options[#options+1]={id,id} end
  U.combo(p,'Area mask',options,a.geometryPreset or 'auto',function(v) a.geometryPreset=v=='auto' and nil or v a.customMask=nil c:renderInspector() end)
  if r.type=='directional_spell' then
    U.toggle(p,'Best direction',not r.pattern or r.pattern.autoFace~=false,function(v) r.pattern=r.pattern or {} r.pattern.autoFace=v end)
  end
  local source=a.customMask
  if not source or source=='' then source=G.masks[shape] and table.concat(G.masks[shape],'/') or '00000/00000/00300/00000/00000' end
  local rows={} for row in source:gmatch('[^/\r\n]+') do rows[#rows+1]=row end
  if G.parse(source) then
    local grid=g_ui.createWidget('Panel',p) grid:setHeight(#rows*24+4)
    for y,row in ipairs(rows) do for x=1,#row do
      local value=row:sub(x,x)
      local cell=g_ui.createWidget('UIButton',grid) cell:setSize({width=21,height=21})
      cell:addAnchor(AnchorTop,'parent',AnchorTop) cell:addAnchor(AnchorLeft,'parent',AnchorLeft)
      cell:setMarginTop((y-1)*24) cell:setMarginLeft((x-1)*24)
      cell:setBackgroundColor((value=='3' or value=='2') and '#d6a843' or value=='1' and '#3676ce' or '#232934')
      cell:setText((value=='3' or value=='2') and 'P' or '')
      cell.onClick=function()
        local nextValue=value=='3' and '2' or value=='2' and '3' or value=='1' and '0' or '1'
        rows[y]=rows[y]:sub(1,x-1)..nextValue..rows[y]:sub(x+1)
        a.customMask=table.concat(rows,'/') NexusBot.Storage.touch() c:renderInspector()
      end
    end end
  end
  U.textInput(p,'Custom mask',a.customMask or '',function(v) a.customMask=v end)
  U.button(p,'Use automatic footprint',function() a.customMask=nil a.geometryPreset=nil NexusBot.Storage.touch() c:renderInspector() end)
end
local definition={
  id='magic_shooter',title='Magic Shooter',profileDefaults={actions={}},addText='+ New Action',
  tabs={{'Action','action'},{'Conditions','conditions'},{'Pattern','pattern'},{'Advanced','advanced'}},
  getRules=function(profile) profile.actions=profile.actions or {} return profile.actions end,
  decorateRow=function(_,labels,rule) NexusBot.UI.ruleIcon(labels[2],rule.action) end,
  newRule=function(...) return newRule(...) end,describe=function(...) return describe(...) end,
  rowValues=function(r)
    local d=describe(r) local a=r.action
    return {d.type,d.action,a.monsterNames or '*',(a.countOperator or '>=')..' '..tostring(a.minimumHits or 1)}
  end,
  renderInspector=function(c,tab,r,p)
    local U=NexusBot.UI local a=r.action r.advanced=r.advanced or {} local v=r.advanced
    if tab=='action' then
      U.combo(p,'Action template',actionTypes,r.type,function(value) changeType(r,value) c:refreshRules() c:renderInspector() end)
      if r.type=='rune' or r.type=='item' then
        U.itemPicker(p,r.type=='rune' and 'Rune' or 'Item',a.itemId,function(id) a.itemId=id c:refreshRules() c:renderInspector() end)
        U.numberInput(p,'Item ID',a.itemId or 0,0,65535,function(id) a.itemId=id c:refreshRules() end)
        U.combo(p,'Use on',{{'Current target','target'},{'Self','self'}},a.target or 'target',function(value) a.target=value end)
        if r.type=='rune' then
          U.toggle(p,'Area rune',a.areaRune==true,function(value) a.areaRune=value c:renderInspector() end)
          if a.areaRune then U.combo(p,'Target selection',{{'Current target','target'},{'Best tile','best_tile'}},a.aim or 'target',function(value) a.aim=value end) end
        end
      else
        U.spellPicker(p,'Spell words',a.spell,function(words,commit)
          a.spell=words applySpellPreset(r,words) c:refreshRules()
          if commit then U.refreshAfterInput(c,r) end
        end)
      end
      U.numberInput(p,'Range',v.range or 5,1,99,function(value) v.range=value end)
      U.numberInput(p,'Required mana',v.minimumMana or 0,0,999999,function(value) v.minimumMana=value end)
      U.toggle(p,'Require current target',v.requiresTarget==true,function(value) v.requiresTarget=value end)
      U.numberInput(p,'Required equipment ID',a.requiredEquipment or 0,0,65535,function(value) a.requiredEquipment=value end)
    elseif tab=='conditions' then
      U.textInput(p,'Monster names',a.monsterNames or '*',function(value) a.monsterNames=value c:refreshRules() end)
      U.button(p,'Monsters ignore list',function() U.editNames('MONSTERS IGNORE LIST',a.ignoreNames or '',function(value) a.ignoreNames=value end) end)
      U.combo(p,'Creatures condition',{{'Equal (=)','='},{'At least (>=)','>='},{'At most (<=)','<='}},a.countOperator or '>=',function(value)
        a.countOperator=value
        for _,condition in ipairs((r.conditions or {}).children or {}) do if condition.autoSpellPreset then condition.enabled=false end end
        c:refreshRules()
      end)
      U.numberInput(p,'Creatures count',a.minimumHits or 1,0,50,function(value)
        a.minimumHits=value
        for _,condition in ipairs((r.conditions or {}).children or {}) do if condition.autoSpellPreset then condition.enabled=false end end
        c:refreshRules()
      end)
      U.rangeBar(p,'Creature HP% range',a.targetHpMin or 0,a.targetHpMax or 100,function(lo,hi) a.targetHpMin=lo a.targetHpMax=hi end,'#ba4050')
      U.rangeBar(p,'Self HP% range',v.selfHpMin or 0,v.selfHpMax or 100,function(lo,hi) v.selfHpMin=lo v.selfHpMax=hi end,'#ba4050')
      U.rangeBar(p,'Self MP% range',v.selfMpMin or 0,v.selfMpMax or 100,function(lo,hi) v.selfMpMin=lo v.selfMpMax=hi end,'#3676ce')
      U.toggle(p,'Self harmony condition',v.harmonyEnabled==true,function(value) v.harmonyEnabled=value c:renderInspector() end)
      if v.harmonyEnabled then
        U.combo(p,'Harmony condition',{{'Below','<'},{'At most','<='},{'Equal','='},{'At least','>='},{'Above','>'}},v.harmonyOperator or '>=',function(value) v.harmonyOperator=value end)
        U.numberInput(p,'Self harmony',v.harmonyValue or 1,0,5,function(value) v.harmonyValue=value end)
      end
      U.button(p,'Additional saved conditions',function() c:showTab('custom') end)
    elseif tab=='pattern' then renderPattern(c,p,r)
    elseif tab=='custom' then NexusBot.Inspector.conditions(c,p,r)
    else
      U.numberInput(p,'Minimum delay (ms)',v.minimumDelay or 250,50,60000,function(value) v.minimumDelay=value end)
      U.numberInput(p,'Extra cooldown (ms)',v.customDelay or 0,0,60000,function(value) v.customDelay=value end)
      U.toggle(p,'PVP Safe Mode',a.avoidPlayers~=false,function(value) a.avoidPlayers=value end)
      U.toggle(p,"Don't cast while walking",v.dontCastWhileWalking==true,function(value) v.dontCastWhileWalking=value end)
      if r.type=='empowerment' then U.numberInput(p,'Buff interval (ms)',v.buffDuration or 10000,1000,600000,function(value) v.buffDuration=value end) end
    end
  end
}
definition.open=function()
  NexusBot.Profiles.ensure('magic_shooter',{actions={}})
  return NexusBot.UI.openReference(definition)
end


-- ==================== LOGIC / RUNTIME ====================
applySpellPreset=function(rule,words)
  -- Custom means literal text, including text which happens to be a known spell.
  -- Keep manual conditions, but never inject a monster count or an area preset.
  if rule.type=='custom_action' then return false end
  local preset=NexusBot.Spells.getPreset(words)
  if not preset then
    clearPreset(rule)
    rule.advanced.range=5
    NexusBot.Storage.touch()
    return false
  end
  if rule.autoPreset and rule.autoPreset.words==preset.words then return true end
  clearPreset(rule)
  rule.action=rule.action or {}
  rule.action.footprint=NexusBot.Spells.defaultFootprint(words,preset.actionType)
  rule.advanced=rule.advanced or {}
  rule.conditions=rule.conditions or {mode='AND',children={}}
  rule.conditions.children=rule.conditions.children or {}
  rule.type=preset.actionType or rule.type
  rule.action.target='target'
  if rule.type=='directional_spell' then
    rule.action.direction=rule.action.direction or North
    rule.pattern={mode='direction',direction=rule.action.direction,autoFace=true,radius=tonumber(preset.radius) or tonumber(preset.range) or 5}
  elseif rule.type=='area_spell' then
    rule.pattern={mode='area_pattern',radius=tonumber(preset.radius) or tonumber(preset.range) or 5}
  else
    rule.pattern={mode='target'}
  end
  rule.advanced.requiresTarget=rule.type=='targeted_spell'
  rule.advanced.stopWhenNoTarget=rule.advanced.requiresTarget
  rule.advanced.range=tonumber(preset.range) or rule.advanced.range or 99
  if tonumber(preset.mana) then rule.advanced.minimumMana=tonumber(preset.mana) end
  local kept={}
  for _,condition in ipairs(rule.conditions.children) do
    if condition.autoSpellPreset~=true then kept[#kept+1]=condition end
  end
  if tonumber(preset.minimumMonsters) and not (NexusBot.Geometry.chain[preset.words] or NexusBot.Geometry.centered[preset.words]) then
    kept[#kept+1]={type='monster_count',operator='>=',value=tonumber(preset.minimumMonsters),radius=tonumber(preset.radius) or tonumber(preset.range) or 5,autoSpellPreset=true}
  end
  rule.conditions.children=kept
  rule.autoPreset={words=preset.words,name=preset.name,source=preset.source,minimumMonsters=preset.minimumMonsters}
  NexusBot.Storage.touch()
  return true
end

newRule=function(profile)
  profile.actions=profile.actions or {}
  local rule={id=NexusBot.id('action'),type='absolute_spell',enabled=false,priority=#profile.actions+1,
    action={spell='exori',target='target'},conditions={mode='AND',children={}},pattern={mode='target'},
    advanced={minimumDelay=250,customDelay=0,onlyIfCooldownReady=true,range=99,minimumMana=0,minimumHP=0}}
  applySpellPreset(rule,rule.action.spell)
  profile.actions[#profile.actions+1]=rule
  return rule
end

describe=function(rule)
  local action=rule.action or {}
  local definition=NexusBot.ActionRegistry.get(rule.type)
  local value=action.spell or (action.itemId and ('Item '..action.itemId)) or 'Not configured'
  return {type=definition and definition.name or rule.type,action=tostring(value),target=action.target or '-'}
end

function NexusBot.Features.MagicShooter.init()
  NexusBot.Profiles.ensure('magic_shooter',{actions={}})
  -- Upgrade only generated legacy fields, retaining hand-written conditions.
  for _,profile in ipairs(NexusBot.Profiles.list('magic_shooter')) do
    for _,rule in ipairs(profile.actions or {}) do
      local words=(rule.action or {}).spell
      if rule.type~='custom_action' and rule.autoPreset and (rule.autoPreset.geometryVersion or 0)<3
        and (NexusBot.Geometry.chain[words] or NexusBot.Geometry.centered[words] or words=='exori scu') then
        local preset=NexusBot.Spells.getPreset(words)
        if preset then
          rule.type=preset.actionType
          rule.advanced=rule.advanced or {}
          rule.advanced.range=preset.range
          rule.advanced.requiresTarget=false rule.advanced.stopWhenNoTarget=false
          rule.pattern={mode='area_pattern'}
          rule.action.footprint=NexusBot.Spells.defaultFootprint(words,preset.actionType)
          local kept={}
          for _,condition in ipairs((rule.conditions or {}).children or {}) do
            if not condition.autoSpellPreset then kept[#kept+1]=condition end
          end
          rule.conditions=rule.conditions or {mode='AND'} rule.conditions.children=kept
          rule.autoPreset.geometryVersion=3 NexusBot.Storage.touch()
        end
      end
      if rule.autoPreset and not rule.autoPreset.geometryVersion then
        local action=rule.action or {}
        if rule.type=='rune' or rule.type=='item' then
          local itemId,target=action.itemId,action.target
          changeType(rule,rule.type) rule.action.itemId=itemId rule.action.target=target or 'target'
        else
          local spell=NexusBot.Spells.get(action.spell)
          local preset=NexusBot.Spells.getPreset(action.spell)
          if spell and preset and tonumber((rule.advanced or {}).minimumMana)==tonumber(preset.baselineMana)
            and spell.source~='Real Tibia preset' and tonumber(spell.mana) then
            rule.advanced=rule.advanced or {} rule.advanced.minimumMana=tonumber(spell.mana)
          end
          if NexusBot.Geometry.directional[action.spell] and rule.type=='area_spell' then rule.type='directional_spell' end
          rule.autoPreset.geometryVersion=2
        end
        NexusBot.Storage.touch()
      end
    end
  end
  NexusBot.registerModule(definition)
  NexusBot.Actions.registerProvider('magic_shooter',30,function()
    local profile=NexusBot.Profiles.getActive('magic_shooter')
    return profile and profile.enabled and profile.actions or {}
  end)
end
NexusBot.Features.MagicShooter.applyPreset=applySpellPreset
NexusBot.Features.MagicShooter.changeType=changeType

category.init = NexusBot.Features.MagicShooter.init
