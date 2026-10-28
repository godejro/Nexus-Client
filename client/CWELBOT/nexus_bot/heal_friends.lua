-- HEAL FRIENDS: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('heal_friends', 'HEAL FRIENDS', 9, false)

-- ==================== GUI / LAYOUT ====================
local M=NexusBot.Features.Modern
local U=NexusBot.UI
local R=M.bindings
local H=M.shared
local safe=H.safe
local alarmSound=H.alarmSound
local config=H.config
local isAlive=H.isAlive
local ownTimer=H.ownTimer
local engineWindow=H.engineWindow
local formWindow=H.formWindow
local sortedKeys=H.sortedKeys
local title=H.title
local fields=H.fields
local managedToggle=H.managedToggle
local bindRuntime=H.bindRuntime

local function friendsWindow()
  local c=M.friends
  local w,left,right=engineWindow('HEAL FRIENDS')
  w:setSize({width=580,height=390})
  w.left:setWidth(268)
  w.toolbar:hide() w.left:setMarginTop(-30)
  U.scrollbar(left) U.scrollbar(right)
  U.section(left,'HEALING')
  local spellField,itemField
  local function updateMethod()
    if spellField then spellField:getParent():setVisible(c.method=='spell') end
    if itemField then itemField:getParent():setVisible(c.method=='item') end
  end
  U.combo(left,'Method',{{'Sio / custom spell','spell'},{'UH / healing item','item'}},c.method,function(v) c.method=v updateMethod() end)
  spellField=U.combo(left,'Spell',{{'exura sio','exura sio'},{'exura gran sio','exura gran sio'}},c.spell,function(v) c.spell=v end)
  itemField=U.numberInput(left,'Item ID',c.itemId,1,65535,function(v) c.itemId=v end)
  updateMethod()
  U.numberInput(left,'Heal below HP%',c.hp,1,100,function(v) c.hp=v end)
  U.numberInput(left,'My min MP%',c.mana,0,100,function(v) c.mana=v end)
  U.numberInput(left,'My safe HP%',c.safeHp or 0,0,100,function(v) c.safeHp=v end)
  U.numberInput(left,'Max distance',c.distance,1,10,function(v) c.distance=v end)
  U.numberInput(left,'Delay (ms)',c.delay,200,60000,function(v) c.delay=v end)
  U.section(right,'ELIGIBLE PLAYERS')
  U.toggle(right,'Friend list',c.useList,function(v) c.useList=v end)
  U.toggle(right,'Party members',c.party,function(v) c.party=v end)
  U.toggle(right,'Guild members',c.guild,function(v) c.guild=v end)
  U.button(right,'Edit Friend List',function()
    U.editNames('Friend List',c.names,function(value) c.names=value end)
  end)
  return w
end

M.windows.friendsWindow=friendsWindow
category.open = friendsWindow
category.getEnabled=function() return M.friends.enabled==true end
category.setEnabled=function(v)
  M.friends.enabled=v
  if v and R.storage and R.storage.advancedFriendHealer then R.storage.advancedFriendHealer.enabled=false end
end

-- ==================== LOGIC / RUNTIME ====================
local function eligible(creature,c)
  local name=creature:getName():lower()
  if c.useList then for entry in c.names:gmatch('[^\n,;]+') do if entry:lower():gsub('^%s+',''):gsub('%s+$','')==name then return true end end end
  if c.useList and R.isFriend and safe(function() return R.isFriend(creature) end,false) then return true end
  local shield=safe(function() return creature:getShield() end,0)
  if c.party and shield>=3 and shield<=10 then return true end
  if c.guild and safe(function() return creature:getEmblem() end,0)==1 then return true end
  return false
end
function M.friendTick(context)
  local c=M.friends
  if not c.enabled or context.now<(M.nextHeal or 0) or context.manaPercent<c.mana or context.healthPercent<(tonumber(c.safeHp) or 0) then return end
  if R.storage and R.storage.advancedFriendHealer and R.storage.advancedFriendHealer.enabled then return end
  local best
  for _,creature in ipairs(context.spectators) do
    local p=creature:getPosition()
    if creature~=context.player and creature:isPlayer() and p and p.z==context.position.z and
      math.max(math.abs(p.x-context.position.x),math.abs(p.y-context.position.y))<=c.distance and
      creature:getHealthPercent()>0 and creature:getHealthPercent()<c.hp and creature:canShoot() and eligible(creature,c) then
      if not best or creature:getHealthPercent()<best:getHealthPercent() then best=creature end
    end
  end
  if not best then return end
  local cooldownApi=modules.game_cooldown
  if c.method=='spell' then
    if cooldownApi and cooldownApi.isGroupCooldownIconActive and cooldownApi.isGroupCooldownIconActive(2) then return end
    local spell=tostring(c.spell):gsub('^%s+',''):gsub('%s+$','')
    if spell=='' then return end
    local metadata=NexusBot.Spells.get(spell)
    local actions=NexusBot.Actions
    if metadata then
      if context.mana and context.mana<(tonumber(metadata.mana) or 0) then return end
      if (actions.serverSpells[tonumber(metadata.id) or -1] or 0)>context.now then return end
      for group in pairs(metadata.groups or {}) do
        if (actions.serverGroups[tonumber(group)] or 0)>context.now or
          (actions.sentGroups[tonumber(group)] or 0)>context.now then return end
      end
    end
    g_game.talk(spell..' "'..best:getName()..'"')
    for group in pairs(metadata and metadata.groups or {[2]=1000}) do
      actions.sentGroups[tonumber(group)]=context.now+250
    end
  elseif tonumber(c.itemId) and c.itemId>0 then
    local delays=NexusBot.Features.Delays
    local action={type='item'}
    context.providerId='heal_friends'
    if delays and not delays.allows(action,context) then return end
    if g_game.useInventoryItemWith(c.itemId,best)==false then return end
    if delays then delays.executed(action,context) end
  else return end
  M.nextHeal=context.now+math.max(200,c.delay)
end




category.init = function()
  local saved=NexusBot.Storage.get()
  saved.integrations=saved.integrations or {}
  if not saved.integrations.healFriends and R.storage and type(R.storage.advancedFriendHealer)=='table' then
    local old=R.storage.advancedFriendHealer
    saved.integrations.healFriends={enabled=false,hp=tonumber(old.minFriendHp),mana=tonumber(old.minMana),distance=tonumber(old.distance),itemId=tonumber(old.id),method=old.itemHeal and 'item' or 'spell',spell=old.customSpell and old.customSpellName or (old.exuraGranSio and 'exura gran sio' or 'exura sio')}
  end
  M.friends=config('healFriends',{enabled=false,method='spell',spell='exura sio',itemId=3160,hp=60,mana=30,safeHp=0,distance=7,delay=1000,names='',useNames=true,useList=true,party=false,guild=false})
end
