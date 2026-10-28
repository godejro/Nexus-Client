-- ALARMS: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('alarms', 'ALARMS', 3, false)

-- ==================== GUI / LAYOUT ====================
local M=NexusBot.Features.Modern
local U=NexusBot.UI
local R=M.bindings
local H=M.shared
local safe=H.safe
local alarmSound
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

local function alarmsWindow()
  local c=M.alarms
  local w,p=formWindow('ALARMS',590)
  w:setWidth(330) U.scrollbar(p)
  U.numberInput(p,'Repeat ms',c.delay,1500,60000,function(v) c.delay=v M.lastAlarm={} NexusBot.Storage.touch() end)
  local function threshold(label,key,metric)
    local toggle=U.toggle(p,label,c[key],function(v) c[key]=v end)
    local input=g_ui.createWidget('NexusNumberInput',toggle.container)
    input:setWidth(48) input:setHeight(24)
    input:addAnchor(AnchorRight,'toggle',AnchorLeft) input:setMarginRight(6)
    input:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
    input:setMinimum(0) input:setMaximum(100) input:setValue(c[metric])
    input.onValueChange=function(_,value) c[metric]=value NexusBot.Storage.touch() end
  end
  threshold('Low health','lowHealth','hp')
  threshold('Low mana','lowMana','mana')
  for _,entry in ipairs({{'disconnected','Disconnected'},{'playerSeen','Player detected'},{'playerAttack','Player attack'}}) do
    local key=entry[1] U.toggle(p,entry[2],c[key],function(v) c[key]=v end)
  end
  local gm=U.toggle(p,'GM detected',c.gmSeen,function(v) c.gmSeen=v end)
  local edit=U.button(gm.container,'Edit',function()
    U.editNames('GM detected',c.gmNames,function(value) c.gmNames=value end)
  end)
  edit:setWidth(48) edit:setHeight(24)
  edit:addAnchor(AnchorRight,'toggle',AnchorLeft) edit:setMarginRight(6)
  edit:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  for _,entry in ipairs({{'damage','Damage taken'},{'creatureSeen','Creature detected'},{'enemySeen','Enemy guild'},{'skullSeen','Skull detected'},
    {'privateMessage','Private message'},{'localMessage','Local chat'},{'walkerStuck','Walker stuck'},{'unjustified','Unjustified points increased'},{'ignoreAllies','Ignore party / guild'}}) do
    local key=entry[1] U.toggle(p,entry[2],c[key],function(v) c[key]=v end)
  end
  U.button(p,'Creature names',function() U.editNames('Creature names',c.creatures,function(v) c.creatures=v end) end)
  U.button(p,'Friend List',function() U.editNames('Friend List',c.friends,function(v) c.friends=v end) end)
  scheduleEvent(function()
    if w:isDestroyed() then return end
    local required=w:getHeight()+p:getChildrenRect().height-p:getPaddingRect().height
    w:setHeight(math.min(required,rootWidget:getHeight()-20))
    NexusBot.WindowManager.dockBesideLauncher(w)
  end,1)
  return w
end

M.windows.alarmsWindow=alarmsWindow
category.open = alarmsWindow
category.getEnabled=function() return M.alarms.enabled==true end
category.setEnabled=function(v)
  M.alarms.enabled=v
  if v and R.storage and R.storage.alarms then R.storage.alarms.enabled=false end
end

-- ==================== LOGIC / RUNTIME ====================
alarmSound=function(key)
  local sounds={creatureSeen='damage',enemySeen='playerAttack',skullSeen='playerAttack',privateMessage='damage',localMessage='damage',walkerStuck='damage',unjustified='playerAttack'}
  key=sounds[key] or key
  local path=(NexusBot.resourceRoot or '/nexus_bot')..'/assets/sounds/'..(key or 'playerSeen')..'.ogg'
  if g_sounds and g_sounds.play and g_resources.fileExists(path) then
    pcall(g_sounds.play,path)
  else NexusBot.Logger.warn('Alarm','Voice recording unavailable: '..tostring(key)) end
end
function M.alert(key,message)
  local c=M.alarms
  if not NexusBot.enabled or not c.enabled or not c[key] then return end
  local now=NexusBot.now()
  if now<(M.lastAlarm[key] or 0) then return end
  -- Do not consume this alarm's repeat interval if another voice is playing.
  if now<(M.nextAlarmSound or 0) then return end
  M.lastAlarm[key]=now+math.max(1500,tonumber(c.delay) or 5000)
  M.lastAlert=message
  NexusBot.Logger.warn('Alarm',message)
  if now>=(M.nextAlarmSound or 0) then
    M.nextAlarmSound=now+2000
    alarmSound(key)
  end
end
local function listed(name,list,prefix)
  name=tostring(name or ''):lower()
  for token in tostring(list or ''):gmatch('[^,;\n]+') do
    token=token:match('^%s*(.-)%s*$'):lower()
    if token~='' and (name==token or (prefix and name:sub(1,#token)==token)) then return true end
  end
  return false
end
function M.alarmTick(context)
  local c=M.alarms
  if not c.enabled then M.lastHealth=context.health return end
  -- This category owns its enabled state; a stale legacy flag cannot silence it.
  local candidates={}
  local function add(key,text,priority)
    if c[key] and (M.lastAlarm[key] or 0)<=context.now then candidates[#candidates+1]={key=key,text=text,priority=priority or 10,last=M.lastAlarm[key] or 0} end
  end
  if context.healthPercent<c.hp then add('lowHealth','Low health: '..context.healthPercent..'%',2) end
  if context.manaPercent<c.mana then add('lowMana','Low mana: '..context.manaPercent..'%',3) end
  if M.lastHealth and context.health<M.lastHealth then M.alarmEvent('damage','Damage taken') end
  M.lastHealth=context.health
  for key,event in pairs(M.alarmEvents or {}) do
    if event.expires>context.now then add(key,event.message) else M.alarmEvents[key]=nil end
  end
  for _,creature in ipairs(context.spectators) do
    local name=creature:getName()
    if creature:isMonster() and listed(name,c.creatures) then add('creatureSeen','Creature detected: '..name) end
    if creature~=context.player and creature:isPlayer() then
      local shield=safe(function() return creature:getShield() end,0)
      local emblem=safe(function() return creature:getEmblem() end,0)
      local ally=(shield>=3 and shield<=10) or emblem==1
      if listed(name,c.gmNames,true) then add('gmSeen','GM detected: '..name,1) end
      if not listed(name,c.friends) and not (c.ignoreAllies and ally) then
        if safe(function() return creature:isTimedSquareVisible() end,false) then add('playerAttack','Attacked by '..name,2) end
        if emblem==2 then add('enemySeen','Enemy guild: '..name) end
        if safe(function() return creature:getSkull() end,0)>0 then add('skullSeen','Skull detected: '..name) end
        add('playerSeen','Player detected: '..name)
      end
    end
  end
  local A=NexusBot.Automation
  local walker=A and A.Walker
  local moving=A and A.CaveBot and A.CaveBot.isOn() and walker and walker.state and walker.state.entry
  local expected=moving and (moving.action=='goto' or moving.action=='walk') and not (A.Targeting and A.Targeting.current)
  local pos=context.position and A.key(context.position)
  if not expected or pos~=M.alarmPosition then M.alarmPosition=pos M.alarmMovedAt=context.now end
  if expected and context.now-(M.alarmMovedAt or context.now)>=c.stuckSeconds*1000 then add('walkerStuck','Walker has not moved') end
  table.sort(candidates,function(a,b) if a.last~=b.last then return a.last<b.last end return a.priority<b.priority end)
  local selected=candidates[1]
  if selected and context.now>=(M.nextAlarmSound or 0) then
    M.alert(selected.key,selected.text)
    M.alarmEvents[selected.key]=nil
  end
end

function M.alarmEvent(key,message)
  if not NexusBot.enabled or not M.alarms or not M.alarms.enabled or not M.alarms[key] then return end
  M.alarmEvents=M.alarmEvents or {}
  M.alarmEvents[key]={message=message,expires=NexusBot.now()+15000}
end




category.init = function()
  local saved=NexusBot.Storage.get()
  saved.integrations=saved.integrations or {}
  if not saved.integrations.alarms and R.storage and type(R.storage.alarms)=='table' then
    local old=R.storage.alarms
    local imported={enabled=false}
    for key,legacy in pairs({lowHealth='lowHealth',lowMana='lowMana',playerAttack='playerAttack',playerSeen='playerDetected',damage='damageTaken',ignoreFriends='ignoreFriends',flash='flashClient'}) do
      if type(old[legacy])=='table' then imported[key]=old[legacy].enabled==true end
    end
    imported.hp=type(old.lowHealth)=='table' and tonumber(old.lowHealth.value) or nil
    imported.mana=type(old.lowMana)=='table' and tonumber(old.lowMana.value) or nil
    saved.integrations.alarms=imported
  end
  M.alarms=config('alarms',{enabled=false,lowHealth=true,lowMana=true,hp=20,mana=15,disconnected=true,playerSeen=false,playerAttack=true,gmSeen=true,gmNames='[GM], [GOD]',friends='',delay=5000,
    damage=false,creatureSeen=false,enemySeen=false,skullSeen=false,privateMessage=false,localMessage=false,walkerStuck=false,unjustified=false,ignoreAllies=false,creatures='',stuckSeconds=10})
  M.alarms.sound=true M.alarms.flash=false
  if category.handlers then disconnect(g_game,category.handlers) end
  M.alarmEvents={} M.lastHealth=nil M.lastAlarm={} M.nextAlarmSound=0 category.points=nil
  category.handlers={
    onGameStart=function() category.points=nil M.alarmEvents={} M.lastHealth=nil end,
    onGameEnd=function() category.points=nil M.alarmEvents={} M.lastHealth=nil end,
    onTalk=function(name,level,mode,text)
      local player=g_game.getLocalPlayer()
      if not player or name==player:getName() or listed(name,M.alarms.friends) then return end
      if MessageModes and (mode==MessageModes.PrivateFrom or mode==MessageModes.GamemasterPrivateFrom) then M.alarmEvent('privateMessage','Private message from '..name)
      elseif MessageModes and (mode==MessageModes.Say or mode==MessageModes.Whisper or mode==MessageModes.Yell) then M.alarmEvent('localMessage','Local message from '..name) end
    end,
    onUnjustifiedPointsChange=function(points)
      local value=tonumber(points and points.killsDay)
      if value and category.points and value>category.points then M.alarmEvent('unjustified','Unjustified points increased') end
      category.points=value
    end
  }
  connect(g_game,category.handlers)
end
category.terminate=function()
  if category.handlers then disconnect(g_game,category.handlers) category.handlers=nil end
  M.alarmEvents={} M.lastHealth=nil
end
