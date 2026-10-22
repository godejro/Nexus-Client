-- SUPPORT: GUI first; implementation and initialization below.
local category=NexusBot.Categories.define('support','SUPPORT',2,false)
local M=NexusBot.Features.Modern
local U=NexusBot.UI
local advancedWindow

-- ==================== GUI / LAYOUT ====================
category.open=function()
  local c=M.support
  local w,p=M.shared.formWindow('SUPPORT',490) w:setWidth(360)
  U.toggle(p,'Hold haste',c.holdHaste,function(v) c.holdHaste=v end)
  U.textInput(p,'Haste spell',c.hasteSpell,function(v) c.hasteSpell=v end)
  U.numberInput(p,'Haste cost',c.hasteCost,0,99999,function(v) c.hasteCost=v end)
  U.toggle(p,'Cure paralyse',c.cureParalyse,function(v) c.cureParalyse=v end)
  U.textInput(p,'Paralyse spell',c.paralyseSpell,function(v) c.paralyseSpell=v end)
  U.numberInput(p,'Paralyse cost',c.paralyseCost,0,99999,function(v) c.paralyseCost=v end)
  U.toggle(p,'Ignore in PZ',c.ignoreInPz,function(v) c.ignoreInPz=v end)
  U.toggle(p,'Utamo Vita',c.utamo,function(v) c.utamo=v end)
  U.combo(p,'Mode',{{'Cast only',1},{'Cast / remove',2},{'Cast / remove + potion',3}},c.mode,function(v) c.mode=v end)
  U.numberInput(p,'Cast at HP% <=',c.castHp,0,100,function(v) c.castHp=v end)
  U.numberInput(p,'Remove at HP% >=',c.removeHp,0,100,function(v) c.removeHp=v end)
  U.numberInput(p,'Potion ID',c.potionId,0,65535,function(v) c.potionId=v end)
  U.button(p,'Additional conditions',advancedWindow)
  return w
end
advancedWindow=function()
  NexusBot.WindowManager.close('support_advanced')
  local c=M.support local w,p=M.shared.formWindow('ADDITIONAL CONDITIONS',500) w:setWidth(380)
  U.toggle(p,'Hold invisibility',c.invisibility,function(v) c.invisibility=v end)
  U.textInput(p,'Invisibility spell',c.invisibilitySpell,function(v) c.invisibilitySpell=v end)
  U.numberInput(p,'Invisibility mana',c.invisibilityMana,0,99999,function(v) c.invisibilityMana=v end)
  U.toggle(p,'Recovery on timer',c.recovery,function(v) c.recovery=v end)
  U.textInput(p,'Recovery spell',c.recoverySpell,function(v) c.recoverySpell=v end)
  U.numberInput(p,'Recovery mana',c.recoveryMana,0,99999,function(v) c.recoveryMana=v end)
  U.numberInput(p,'Recovery seconds',c.recoverySeconds,1,3600,function(v) c.recoverySeconds=v end)
  U.numberInput(p,'Shield min MP%',c.shieldMinMana,0,100,function(v) c.shieldMinMana=v end)
  U.toggle(p,'Cancel only if shield ready',c.cancelOnlyReady,function(v) c.cancelOnlyReady=v end)
  U.numberInput(p,'Cancel below MP%',c.cancelMana,0,100,function(v) c.cancelMana=v end)
  U.textInput(p,'Cancel spell',c.cancelSpell,function(v) c.cancelSpell=v end)
  U.numberInput(p,'Cancel mana cost',c.cancelCost,0,99999,function(v) c.cancelCost=v end)
  U.toggle(p,'Potion only while feared',c.potionFeared,function(v) c.potionFeared=v end)
  U.numberInput(p,'Potion cooldown ms',c.potionDelay,500,60000,function(v) c.potionDelay=v end)
  NexusBot.WindowManager.attach('support_advanced',w) return w
end
M.windows.supportWindow=category.open
category.getEnabled=function() return M.support and M.support.enabled==true end
category.setEnabled=function(value)
  M.support.enabled=value
  if value then
    local cfg=M.bindings.HealBotConfig and M.bindings.HealBotConfig.ConditionPanel
    if cfg then cfg.enabled=false end
  end
  NexusBot.Storage.touch()
end

-- ==================== LOGIC / RUNTIME ====================
local function spellRule(key,words,cost)
  return {id='support:'..key,enabled=true,priority=1,type='absolute_spell',
    action={spell=words,target='self'},conditions={mode='AND',children={}},
    advanced={minimumDelay=1000,minimumMana=cost or 0,onlyIfCooldownReady=false}}
end
function category.rules(context)
  local c=M.support
  if not c or not c.enabled then return {} end
  local player=context.player
  local function state(flag) return flag and player:hasState(flag) end
  local inPz=state(PlayerStates.Pz)
  local rules={}
  if c.cureParalyse and state(PlayerStates.Paralyze) then
    rules[#rules+1]=spellRule('paralyse',c.paralyseSpell,c.paralyseCost)
  end
  if c.utamo and not (c.ignoreInPz and inPz) then
    local shield=state(PlayerStates.ManaShield) or state(PlayerStates.NewManaShield) or (player.getManaShield and player:getManaShield()>0)
    local valid=c.mode==1 or c.removeHp>c.castHp
    local spell=NexusBot.Spells.get('utamo vita')
    local cooldown=spell and (NexusBot.Actions.serverSpells[tonumber(spell.id) or -1] or 0)>context.now
    local lowMana=(tonumber(c.cancelMana) or 0)>0 and (context.manaPercent or 100)<c.cancelMana
    if valid and shield and c.mode>1 and (context.healthPercent>=c.removeHp or lowMana) then
      if lowMana or not c.cancelOnlyReady or not cooldown then rules[#rules+1]=spellRule('cancelUtamo',c.cancelSpell or 'exana vita',c.cancelCost or 50) end
    elseif valid and not shield and context.healthPercent<=c.castHp and (context.manaPercent or 100)>=(c.shieldMinMana or 0) then
      if cooldown and c.mode==3 and c.potionId>0 and (not c.potionFeared or state(PlayerStates.Feared)) then
        rules[#rules+1]={id='support:shieldPotion',enabled=true,priority=1,type='item',
          action={itemId=c.potionId,target='self'},conditions={mode='AND',children={}},
          advanced={minimumDelay=c.potionDelay or 2000,onlyIfCooldownReady=false}}
      elseif not cooldown then
        rules[#rules+1]=spellRule('utamo','utamo vita',50)
      end
    end
  end
  -- Hold haste explicitly covers standing still and protection zones.
  if c.holdHaste and not state(PlayerStates.Haste) then
    rules[#rules+1]=spellRule('holdHaste',c.hasteSpell,c.hasteCost)
  end
  if not (c.ignoreInPz and inPz) then
    if c.invisibility and player.isInvisible and not player:isInvisible() then
      rules[#rules+1]=spellRule('invisibility',c.invisibilitySpell,c.invisibilityMana)
    end
    if c.recovery then
      local rule=spellRule('recovery',c.recoverySpell,c.recoveryMana)
      rule.advanced.minimumDelay=NexusBot.Validation.number(c.recoverySeconds,60,1,3600)*1000
      rules[#rules+1]=rule
    end
  end
  return rules
end
category.init=function()
  local data=NexusBot.Storage.get() data.integrations=data.integrations or {}
  if not data.integrations.support then
    local old=M.bindings.HealBotConfig and M.bindings.HealBotConfig.ConditionPanel or {}
    data.integrations.support={enabled=false}
    for _,key in ipairs({'holdHaste','hasteSpell','hasteCost','cureParalyse','paralyseSpell','paralyseCost','ignoreInPz'}) do
      data.integrations.support[key]=old[key]
    end
  end
  M.support=M.shared.config('support',{enabled=false,holdHaste=false,hasteSpell='utani hur',hasteCost=60,
    cureParalyse=false,paralyseSpell='exura',paralyseCost=20,ignoreInPz=true,
    utamo=false,mode=1,castHp=60,removeHp=90,potionId=0,
    invisibility=false,invisibilitySpell='utana vid',invisibilityMana=440,recovery=false,recoverySpell='utura',recoveryMana=75,recoverySeconds=60,
    shieldMinMana=0,cancelOnlyReady=false,cancelMana=0,cancelSpell='exana vita',cancelCost=50,potionFeared=false,potionDelay=2000})
  if M.support.potionId==0 then
    for _,item in ipairs(NexusBot.Items.search('magic shield potion',10)) do
      if item.name:lower()=='magic shield potion' then M.support.potionId=item.id break end
    end
  end
  NexusBot.Actions.registerProvider('support',15,category.rules)
end
category.terminate=function() NexusBot.Actions.unregisterProvider('support') end
