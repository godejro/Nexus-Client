NexusBot.Actions = { providers = {}, lastUse = {}, lastSignature = {}, loop = nil, interval = 75 }
local A=NexusBot.Actions
A.serverSpells, A.serverGroups, A.sentGroups = {}, {}, {}
A.turns={}
A.receivesCooldowns=false
A.predictedSpells={}

function A.init()
  if A.connections then return end
  A.connections={
    onSpellCooldown=function(id,duration) A.receivesCooldowns=true A.serverSpells[tonumber(id)]=NexusBot.now()+duration A.predictedSpells[tonumber(id)]=nil end,
    onSpellGroupCooldown=function(id,duration) A.receivesCooldowns=true A.serverGroups[tonumber(id)]=NexusBot.now()+duration A.sentGroups[tonumber(id)]=nil end,
    onGameEnd=function()
      A.serverSpells={} A.serverGroups={} A.sentGroups={} A.predictedSpells={} A.lastUse={} A.lastSignature={} A.turns={} A.receivesCooldowns=false
      if NexusBot.Features and NexusBot.Features.EquipmentManager then NexusBot.Features.EquipmentManager.slotLocks={} end
    end
  }
  connect(g_game,A.connections)
end

function A.terminate()
  A.stop()
  if A.connections then disconnect(g_game,A.connections) A.connections=nil end
end

function NexusBot.Actions.registerProvider(id, order, callback)
  NexusBot.Actions.providers[id] = { id=id, order=order or 100, callback=callback }
  NexusBot.Actions.orderedProviders = nil
end

function NexusBot.Actions.unregisterProvider(id)
  NexusBot.Actions.providers[id] = nil
  NexusBot.Actions.orderedProviders = nil
end

function NexusBot.Actions.isReady(actionId, now)
  return (NexusBot.Actions.lastUse[actionId or ''] or 0) <= (now or NexusBot.now())
end

local function cooldown(rule)
  local advanced = rule.advanced or {}
  local delay = (tonumber(advanced.minimumDelay) or 0) + (tonumber(advanced.customDelay) or 0)
  if rule.type=='empowerment' then delay=math.max(delay,tonumber(advanced.buffDuration) or 10000) end
  local spell = rule.action and NexusBot.Spells.get(rule.action.spell)
  if advanced.onlyIfCooldownReady ~= false and spell and spell.cooldown then
    -- Sending speech is not confirmation that the server accepted the cast.
    -- Cooldown packets gate accepted casts; a rejected request must remain retryable.
    local serverTimers=A.receivesCooldowns or (GameSpellList and g_game.getFeature and g_game.getFeature(GameSpellList))
    delay=math.max(delay,serverTimers and 250 or (tonumber(spell.cooldown) or 0))
  end
  return math.max(50, delay)
end

local function advancedAllows(rule, context)
  local advanced = rule.advanced or {}
  if advanced.dontCastWhileWalking and context.player.isWalking and context.player:isWalking() then return false end
  if advanced.harmonyEnabled then
    if not context.player.getHarmony or not NexusBot.Conditions.compare(context.player:getHarmony(),advanced.harmonyOperator or '>=',advanced.harmonyValue or 1) then return false end
  end
  if context.healthPercent and (context.healthPercent<(tonumber(advanced.selfHpMin) or 0) or context.healthPercent>(tonumber(advanced.selfHpMax) or 100)) then return false end
  if context.manaPercent and (context.manaPercent<(tonumber(advanced.selfMpMin) or 0) or context.manaPercent>(tonumber(advanced.selfMpMax) or 100)) then return false end
  local required=tonumber((rule.action or {}).requiredEquipment) or 0
  if required>0 then
    local found=false
    for slot=1,10 do local item=context.player:getInventoryItem(slot) if item and item:getId()==required then found=true break end end
    if not found then return false end
  end
  if rule.type == 'targeted_spell' and not context.target then return false end
  if (rule.type == 'rune' or rule.type == 'item') and rule.action and rule.action.target == 'target' and not context.target then return false end
  if (advanced.requiresTarget or advanced.stopWhenNoTarget) and not context.target then return false end
  if tonumber(advanced.minimumMana) and context.mana < tonumber(advanced.minimumMana) then return false end
  if tonumber(advanced.minimumHP) and context.health < tonumber(advanced.minimumHP) then return false end
  local onTarget=(rule.type=='rune' or rule.type=='item') and (rule.action or {}).target=='target' and not (rule.action or {}).areaRune
  if (rule.type=='targeted_spell' or onTarget or advanced.requiresTarget or advanced.stopWhenNoTarget) and tonumber(advanced.range) and context.targetDistance > tonumber(advanced.range) then return false end
  if (rule.type=='targeted_spell' or onTarget) and context.target and not context.target:canShoot() then return false end
  if type(advanced.vocations) == 'string' and advanced.vocations ~= '' then
    local allowed = false
    for value in advanced.vocations:gmatch('%d+') do if tonumber(value) == tonumber(context.vocation) then allowed = true break end end
    if not allowed then return false end
  end
  return true
end

function NexusBot.Actions.execute(rule, context)
  local definition = NexusBot.ActionRegistry.get(rule.type)
  if not definition or type(definition.execute) ~= 'function' then return false end
  if not NexusBot.Actions.isReady(rule.id, context.now) then return false end
  local delays=NexusBot.Features and NexusBot.Features.Delays
  if delays and not delays.allows(rule,context) then return false end
  local action = rule.action or {}
  local signature = table.concat({rule.type or '', action.spell or '', tostring(action.itemId or ''), action.target or ''}, ':')
  if rule.type=='channel_message' then
    signature=signature..':'..tostring(action.mode or 'Say')..':'..tostring(action.channelName or action.channel or '')
  end
  if (NexusBot.Actions.lastSignature[signature] or 0) > context.now then return false end
  if not advancedAllows(rule, context) then return false end
  context.areaPlan=nil
  local offensive=context.providerId=='magic_shooter' or context.providerId=='combo'
  if offensive then
    if PlayerStates and PlayerStates.Pz and context.player:hasState(PlayerStates.Pz) then return false end
    if rule.type~='empowerment' and rule.type~='item' and rule.type~='custom_action' then
      context.areaPlan=NexusBot.Geometry.best(rule,context)
      if not context.areaPlan.valid then return false end
      if context.providerId=='magic_shooter' and not NexusBot.Conditions.compare(context.areaPlan.count,action.countOperator or '>=',tonumber(action.minimumHits) or 1) then return false end
    end
  end
  context.currentRuleId=rule.id
  context.currentRule=rule
  local conditionsPassed=NexusBot.Conditions.evaluate(rule.conditions, context)
  context.currentRuleId=nil
  context.currentRule=nil
  if not conditionsPassed then return false end
  local ok, result = pcall(definition.execute, context, rule.action or {}, rule)
  if not ok then
    NexusBot.Logger.error('ActionEngine', result)
    return false
  end
  if result then
    if delays then delays.executed(rule,context) end
    local readyAt = context.now + cooldown(rule)
    NexusBot.Actions.lastUse[rule.id] = readyAt
    NexusBot.Actions.lastSignature[signature] = readyAt
    if rule.advanced and rule.advanced.debug then NexusBot.Logger.debug('ActionEngine', 'Executed ' .. rule.id) end
    NexusBot.EventBus.emit('actionExecuted', rule)
    return true
  end
  return false
end

function NexusBot.Actions.tick()
  if not NexusBot.enabled or not g_game.isOnline() then return end
  local context = NexusBot.Conditions.buildContext()
  if not context then return end
  local providers = NexusBot.Actions.orderedProviders
  if not providers then
    providers = {}
    for _, provider in pairs(NexusBot.Actions.providers) do providers[#providers + 1] = provider end
    table.sort(providers, function(a, b) return a.order < b.order end)
    NexusBot.Actions.orderedProviders = providers
  end
  for _, provider in ipairs(providers) do
    context.providerId=provider.id
    local ok, rules = pcall(provider.callback, context)
    if not ok then
      NexusBot.Logger.error(provider.id, rules)
    elseif type(rules) == 'table' then
      local validRules={}
      for _,rawRule in ipairs(rules) do
        local valid,errorMessage=NexusBot.Validation.rule(rawRule)
        if valid then validRules[#validRules+1]=valid else NexusBot.Logger.warn(provider.id,errorMessage) end
      end
      local order={} for index,rule in ipairs(validRules) do order[rule]=index end
      table.sort(validRules, function(a, b)
        if a.priority==b.priority then return order[a]<order[b] end
        return (a.priority or 100)<(b.priority or 100)
      end)
      for _, rule in ipairs(validRules) do
        if rule.enabled and NexusBot.Actions.execute(rule, context) then return end
      end
    end
  end
end

local function speak(context, action, rule)
  local words = tostring(action.spell or action.words or '')
  if words == '' then return false end
  local spell=NexusBot.Spells.get(words)
  if spell then
    local cost=tonumber((rule.advanced or {}).minimumMana)
    if not cost or cost<=0 then cost=tonumber(spell.mana) or 0 end
    if context.mana<cost then return false end
    local id=tonumber(spell.id) or -1
    if (A.serverSpells[id] or 0)>context.now or (A.predictedSpells[id] or 0)>context.now then return false end
    for group in pairs(spell.groups or {}) do
      group=tonumber(group)
      if (A.serverGroups[group] or 0)>context.now or (A.sentGroups[group] or 0)>context.now then return false end
    end
  end
  if (rule.type == 'targeted_spell' or rule.type == 'empowerment') and (rule.advanced or {}).requiresTarget and not context.target then return false end
  if rule.type == 'directional_spell' then
    local direction=context.areaPlan and context.areaPlan.direction or NexusBot.Spells.direction(rule,context)
    local pending=A.turns[rule.id]
    if context.player:getDirection()~=direction then
      if not pending or pending.direction~=direction or context.now-pending.at>=500 then
        g_game.turn(direction) A.turns[rule.id]={direction=direction,at=context.now}
      end
      return false
    end
    if pending and context.now-pending.at<75 then return false end
    A.turns[rule.id]=nil
  end
  if g_game.talk(words)==false then return false end
  -- Brief prediction bridges network latency; server cooldown events then win.
  -- No UI visibility dependency and no extra loop per healing rule.
  local offensive=context.providerId=='magic_shooter' or context.providerId=='combo'
  if offensive and spell and tonumber(spell.id) then
    -- Bridge missing/delayed packets with this spell's own known cooldown.
    -- A real server cooldown replaces this prediction immediately, even if shorter.
    A.predictedSpells[tonumber(spell.id)]=context.now+math.max(250,tonumber(spell.cooldown) or 250)
  end
  for group,duration in pairs(spell and spell.groups or {}) do
    A.sentGroups[tonumber(group)]=context.now+(offensive and (tonumber(duration) or 250) or math.min(250,tonumber(duration) or 250))
  end
  return true
end

local spellActions={
  {'absolute_spell','Absolute Spell'},{'targeted_spell','Targeted Spell'},{'directional_spell','Directional Spell'},
  {'area_spell','Area Spell'},{'empowerment','Empowerment'},{'custom_action','Custom Spell'}
}
for _, entry in ipairs(spellActions) do
  NexusBot.registerAction({ id=entry[1], name=entry[2], fields={{key='spell',type='spell',label='Spell'}}, execute=speak })
end
NexusBot.registerAction({ id='rune', name='Rune', fields={{key='itemId',type='item',label='Rune'},{key='target',type='enum',label='Use on'}}, execute=function(context, action)
  local target = action.target == 'self' and context.player or context.target
  if action.areaRune then
    local plan=context.areaPlan
    if not plan or not plan.valid or not plan.center then return false end
    local tile=g_map.getTile(plan.center)
    target=tile and tile:getTopUseThing()
  end
  local itemId=tonumber(action.itemId)
  if not target or not itemId or itemId <= 0 then return false end
  return g_game.useInventoryItemWith(itemId, target)~=false
end })
NexusBot.registerAction({ id='item', name='Item', fields={{key='itemId',type='item',label='Item'},{key='target',type='enum',label='Use on'}}, execute=function(context, action)
  local target = action.target == 'target' and context.target or context.player
  local itemId=tonumber(action.itemId)
  if not target or not itemId or itemId <= 0 then return false end
  return g_game.useInventoryItemWith(itemId, target)~=false
end })
NexusBot.registerAction({ id='equip', name='Equip', fields={{key='itemId',type='item',label='Item'},{key='slot',type='enum',label='Slot'}}, execute=function(context, action, rule)
  local manager=NexusBot.Features and NexusBot.Features.EquipmentManager
  if manager and manager.execute then return manager.execute(context,action,rule,false) end
  local id = tonumber(action.itemId)
  if not id or id <= 0 then return false end
  local slot = tonumber(action.slot)
  if not slot or slot<1 or slot>10 then return false end
  local equipped = slot and context.player:getInventoryItem(slot) or nil
  if equipped and equipped:getId() == id then return false end
  local skip={}
  for value in tostring(action.skipIds or ''):gmatch('%d+') do skip[tonumber(value)]=true end
  if next(skip) then
    for index=1,10 do local current=context.player:getInventoryItem(index) if current and skip[current:getId()] then return false end end
  end
  -- Explicit inventory destinations preserve custom items and left/right hand choice.
  for _,container in pairs(g_game.getContainers()) do
    for _,item in ipairs(container:getItems()) do
      if item:getId()==id then
        return g_game.move(item,{x=65535,y=slot,z=0},item:getCount())~=false
      end
    end
  end
  return false
end })
NexusBot.registerAction({ id='unequip', name='Unequip', fields={{key='slot',type='enum',label='Slot'}}, execute=function(context, action, rule)
  local manager=NexusBot.Features and NexusBot.Features.EquipmentManager
  if manager and manager.execute then return manager.execute(context,action,rule,true) end
  local slot = tonumber(action.slot)
  local equipped = slot and context.player:getInventoryItem(slot) or nil
  if not equipped then return false end
  for _,container in pairs(g_game.getContainers()) do
    if #container:getItems()<container:getCapacity() then
      return g_game.move(equipped,container:getSlotPosition(#container:getItems()),equipped:getCount())~=false
    end
  end
  return false
end })

function NexusBot.Actions.start()
  NexusBot.Actions.stop()
  NexusBot.Actions.loop = NexusBot.Scheduler.every(NexusBot.Actions.interval, NexusBot.Actions.tick, 'ActionEngine')
end

function NexusBot.Actions.stop()
  if NexusBot.Actions.loop then NexusBot.Scheduler.cancel(NexusBot.Actions.loop) NexusBot.Actions.loop = nil end
  A.turns={}
  if NexusBot.Features and NexusBot.Features.EquipmentManager then NexusBot.Features.EquipmentManager.slotLocks={} end
  if NexusBot.Features and NexusBot.Features.Combo then NexusBot.Features.Combo.stop() end
end
