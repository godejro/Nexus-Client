-- EXTRAS: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('extras', 'EXTRAS', 6, false)

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
local timerWindow,timerEditor
local E={due={},pmOpened={}}
NexusBot.Features.Extras=E

timerEditor=function(rule,refresh)
  NexusBot.WindowManager.close('timer_action_editor')
  local channel=rule.type=='channel_message'
  local w,p=formWindow(channel and 'CHANNEL MESSAGE' or 'TIMER ACTION',channel and 270 or 350) w:setWidth(390)
  U.scrollbar(p)
  local c=rule.action
  U.toggle(p,'Enabled',rule.enabled,function(v) rule.enabled=v if v then E.setTool(E.timerGroup(rule),true) end end)
  if not channel then
  U.combo(p,'Action',{{'Spell','absolute_spell'},{'Item on self','item'},{'Item on target','rune'},{'Use item','use_item'}},rule.type,function(v) rule.type=v c.target=v=='rune' and 'target' or 'self' end)
  end
  U.textInput(p,'Spell / message',c.spell or '',function(v) c.spell=v end)
  if not channel then U.itemPicker(p,'Item ID',c.itemId or 0,function(v) c.itemId=v end) end
  U.numberInput(p,'Interval',rule.interval or 60,1,86400000,function(v) rule.interval=v end)
  U.combo(p,'Unit',{{'Milliseconds',1},{'Seconds',1000},{'Minutes',60000}},rule.unit or 1000,function(v) rule.unit=v end)
  if not channel then U.numberInput(p,'Minimum mana',rule.advanced.minimumMana or 0,0,999999,function(v) rule.advanced.minimumMana=v end) end
  U.toggle(p,'Allow in PZ',rule.allowPz==true,function(v) rule.allowPz=v end)
  if channel then
  local channelField
  U.combo(p,'Chat mode',{{'Say','Say'},{'Whisper','Whisper'},{'Yell','Yell'},{'Open channel','Channel'}},c.mode or 'Say',function(v)
    c.mode=v if channelField then channelField:getParent():setVisible(v=='Channel') end
  end)
  local channels={{'Choose open channel',-1}}
  local console=modules.game_console
  for id,name in pairs(console and console.channels or {}) do if tonumber(id) then channels[#channels+1]={tostring(name),tonumber(id)} end end
  channelField=U.combo(p,'Channel',channels,tonumber(c.channel) or -1,function(v)
    c.channel=v c.channelName=console and console.channels and (console.channels[v] or console.channels[tostring(v)]) or nil
  end)
  channelField:getParent():setVisible(c.mode=='Channel')
  end
  local old=w.onDestroy
  w.onDestroy=function() if old then old(w) end M.timerDue[rule.id]=nil refresh() end
  NexusBot.WindowManager.attach('timer_action_editor',w)
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
end
timerWindow=function(channel)
  local key=channel and 'channels_manager' or 'timer_actions'
  NexusBot.WindowManager.close(key)
  local w,p=formWindow(channel and 'CHANNELS MANAGER' or 'TIMER ACTIONS',channel and 420 or 370) w:setWidth(460)
  U.scrollbar(p)
  local group=channel and 'channels' or 'timers'
  local enabled=U.toggle(p,'Enabled',E.cfg[group].enabled,function(v) E.setTool(group,v) end)
  if channel then U.numberInput(p,'Global delay (seconds)',E.cfg.channelDelay/1000,10,3600,function(v) E.cfg.channelDelay=v*1000 end) end
  local query=''
  local refresh,visibleRows
  U.textInput(p,'Search','',function(v) query=v:lower() if refresh then refresh() end end)
  local list=U.compactList(p,240)
  refresh=function()
    if w:isDestroyed() then return end U.clear(list) visibleRows={}
    for index,rule in ipairs(M.extraTimers.rules) do
      if (rule.type=='channel_message')==(channel==true) and (query=='' or tostring(rule.action.spell or rule.action.itemId or ''):lower():find(query,1,true)) then
      local row=g_ui.createWidget('NexusIntegrationRow',list)
      local label=(rule.action.spell and rule.action.spell~='' and rule.action.spell or ('Item '..(rule.action.itemId or 0)))
      visibleRows[#visibleRows+1]={row=row,rule=rule,label=label}
      row.name:setText(label..' / '..E.timerStatus(rule))
      row.enabled:setOn(rule.enabled==true)
      row.enabled.onClick=function()
        rule.enabled=not rule.enabled M.timerDue[rule.id]=nil
        if rule.enabled then E.setTool(group,true) end
        NexusBot.Storage.touch() refresh()
      end
      row.edit.onClick=function() timerEditor(rule,refresh) end
      row.onMousePress=function(_,_,button)
        if button~=MouseRightButton then return false end
        local menu=g_ui.createWidget('NexusContextMenu')
        menu:addOption('Delete',function() table.remove(M.extraTimers.rules,index) M.timerDue[rule.id]=nil NexusBot.Storage.touch() refresh() end)
        menu:display(g_window.getMousePosition()) return true
      end
      end
    end
  end
  U.button(p,'+ Add',function()
    local rule={id=NexusBot.id('timer'),enabled=false,type=channel and 'channel_message' or 'absolute_spell',interval=60,unit=1000,allowPz=channel==true,
      action={spell='',itemId=0,target='self',mode=channel and 'Channel' or nil},advanced={minimumMana=0,onlyIfCooldownReady=true}}
    M.extraTimers.rules[#M.extraTimers.rules+1]=rule NexusBot.Storage.touch() refresh() timerEditor(rule,refresh)
  end)
  refresh()
  ownTimer(w,function()
    enabled:setOn(E.cfg[group].enabled==true)
    for _,entry in ipairs(visibleRows) do
      entry.row.name:setText(entry.label..' / '..E.timerStatus(entry.rule))
      entry.row.enabled:setOn(entry.rule.enabled==true)
    end
  end,500)
  NexusBot.WindowManager.attach(key,w) return w
end

local function extrasWindow()
  local w,left,right=engineWindow('EXTRAS')
  w:setSize({width=460,height=280})
  w.right:hide() w.left:setWidth(420)
  w.toolbar:hide() w.left:setMarginTop(-30)
  local runtime=M.getRuntime()
  local cfg=runtime.storage and runtime.storage.extras
  U.button(left,'Timer actions / Channels',timerWindow)
  if type(cfg)~='table' then U.label(left,'Legacy Extras require the classic bot profile.') return w end
  local a=g_ui.createWidget('NexusConditionGroup',left)
  local b=g_ui.createWidget('NexusConditionGroup',right)
  local live={}
  local names={rope='Rope item ID',shovel='Shovel item ID',machete='Machete item ID',scythe='Scythe item ID',
    pathfinding='CaveBot pathfinding',talkDelay='NPC talk delay (ms)',looting='Maximum loot distance',lootDelay='Loot delay (ms)',
    huntRoutes='Hunting rounds limit',killUnder='Kill monsters below HP%',gotoMaxDistance='Maximum GoTo distance',
    lootLast='Loot last corpse first',joinBot='Join Cave / Target tabs',reachable='Only reachable targets',title='Custom client title',
    separatePm='Separate PM windows',useAll='Use all hotkey',timers='MW / WG timers',antiKick='Anti kick',stake='Skin monsters',
    oberon='Reply to Oberon',autoOpenDoors='Open doors',bless='Buy bless at login',reUse='Keep crosshair',
    suppliesControl='Stop targeting on low supply',holdMwall='Hold MW / WG',holdMwHot='Hold MW hotkey',holdWgHot='Hold WG hotkey',
    checkPlayer='Check players',nextBackpack='Next loot backpack',highlightTarget='Highlight target'}
  local ranges={rope={0,65535},shovel={0,65535},machete={0,65535},scythe={0,65535},talkDelay={1,2000},looting={1,50},
    lootDelay={1,1000},huntRoutes={1,300},killUnder={1,100},gotoMaxDistance={1,127}}
  local automation={antiKick=true,stake=true,oberon=true,autoOpenDoors=true,bless=true,holdMwall=true,checkPlayer=true,nextBackpack=true}
  local function save() if runtime.saveConfig then runtime.saveConfig() end end
  local function render()
    U.clear(a) U.clear(b) live={}
    local index=0
    for _,key in ipairs(sortedKeys(cfg)) do
      local value=cfg[key]
      local label=names[key] or title(key)
      if key=='antiKick' or key=='bless' or key=='stake' then
        index=index+1
        local dest=a
        local function change(v)
          cfg[key]=v
          if automation[key] and v==true then
            NexusBot.setEnabled(true)
            NexusBot.Storage.get().settings.extrasMaster=true
            M.managed['extras:'..key]={setOff=function() cfg[key]=false save() end}
          end
          save()
        end
        if type(value)=='boolean' then live[#live+1]={key=key,widget=U.toggle(dest,label,value,change)}
        elseif type(value)=='number' then local range=ranges[key] or {-999999,999999} U.numberInput(dest,label,value,range[1],range[2],change)
        else U.textInput(dest,label,value,change) end
      end
    end
  end
  render()
  ownTimer(w,function() for _,entry in ipairs(live) do entry.widget:setOn(cfg[entry.key]==true) end end)
  return w
end




-- Native Extras use the same saved setup and master switch as the other categories.
local function itemList(parent,label,object,key)
  U.section(parent,label)
  local selected=0
  local picker
  local number=U.numberInput(parent,'Item ID',0,0,65535,function(id)
    selected=id
    if picker then picker:getChildById('selectedItem'):setItemId(id) end
  end)
  picker=U.itemPicker(parent,'',0,function(id) number:setValue(id) end)
  -- The numeric value and preview remain live after selector or drag/drop changes.
  for _,child in ipairs(picker:getChildren()) do
    if child:getId()~='selectedItem' and child:getId()~='pickButton' then child:hide() end
  end
  local preview=picker:getChildById('selectedItem')
  preview.onDrop=function(_,widget)
    local item=widget and widget.getItem and widget:getItem()
    if not item then return false end
    number:setValue(item:getId()) return true
  end
  local list,refresh
  U.button(parent,'+ Add',function()
    local id=tonumber(selected)
    if not id or id<1 or id>65535 then return end
    local ids=E.ids(object[key]) if ids[id] then return end
    object[key]=tostring(object[key] or '')..' '..id NexusBot.Storage.touch() refresh()
  end)
  list=U.compactList(parent,105)
  refresh=function()
    U.clear(list)
    for _,id in ipairs(E.orderedIds(object[key])) do
      local value=id
      local row=g_ui.createWidget('NexusIntegrationRow',list)
      row.enabled:hide() row.name:setText('      '..value)
      local icon=g_ui.createWidget('UIItem',row)
      icon:setSize({width=24,height=24}) icon:setVirtual(true) icon:setItemId(value)
      icon:addAnchor(AnchorLeft,'parent',AnchorLeft) icon:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
      row.edit:setText('X')
      row.edit.onClick=function()
        local keep={} for _,current in ipairs(E.orderedIds(object[key])) do if current~=value then keep[#keep+1]=current end end
        object[key]=table.concat(keep,' ') NexusBot.Storage.touch() refresh()
      end
    end
  end
  refresh()
  return refresh
end

function E.openSettings(key)
  local c=E.cfg[key]
  local names={food='EAT FOOD',gold='CHANGE GOLD',effects='MAGIC EFFECTS',idle='ANTI IDLE',training='AUTO TRAINING',follow='AUTO FOLLOW PLAYER',bless='BUY BLESS AT LOGIN',skin='SKIN MONSTERS'}
  local heights={food=350,gold=335,effects=140,idle=135,training=590,follow=235,bless=140,skin=400}
  NexusBot.WindowManager.close('extras_'..key)
  local w,p=formWindow(names[key],heights[key]) w:setWidth(390)
  U.scrollbar(p)
  if key=='food' then
    U.numberInput(p,'Eat below food seconds',c.below,0,1200,function(v) c.below=v end)
    U.numberInput(p,'Check delay (ms)',c.delay,1000,60000,function(v) c.delay=v end)
    local refresh=itemList(p,'FOOD IDS',c,'ids')
    U.button(p,'Import Foods from Items.json',function()
      local ok,err=E.importFoods()
      if not ok then displayErrorBox('Food database',err) else refresh() end
    end)
  elseif key=='gold' then
    U.combo(p,'Action',{{'Use item','use'},{'Use with itself','with'}},c.mode,function(v) c.mode=v end)
    U.numberInput(p,'Stack count',c.count,2,10000,function(v) c.count=v end)
    U.numberInput(p,'Delay (ms)',c.delay,500,60000,function(v) c.delay=v end)
    itemList(p,'COIN IDS',c,'ids')
  elseif key=='effects' then
    U.combo(p,'Hide',{{'All effects','all'},{'Keep missiles','keepMissiles'}},c.mode,function(v) c.mode=v E.updateEffects() end)
  elseif key=='idle' then
    U.numberInput(p,'Interval (seconds)',c.delay/1000,1,840,function(v) c.delay=v*1000 E.due.idle=nil end)
  elseif key=='training' then
    U.combo(p,'Trigger',{{'On timer','timer'},{'When training stops','stopped'}},c.mode,function(v) c.mode=v E.trainingPending=true end)
    U.numberInput(p,'Delay (ms)',c.delay,5000,86400000,function(v) c.delay=v end)
    U.textInput(p,'Stop text',c.stopText,function(v) c.stopText=v end)
    U.button(p,'Capture next weapon use on dummy',function() E.captureTraining=true end)
    U.textInput(p,'Dummy creature name',c.dummyName or '',function(v) c.dummyName=v end)
    itemList(p,'EXERCISE WEAPONS',c,'weaponIds')
    itemList(p,'TRAINING DUMMIES',c,'dummyIds')
  elseif key=='follow' then
    U.textInput(p,'Player name',c.name,function(v) c.name=v E.stopFollow() E.followTrail={} E.followVisited={} E.leaderLast=nil end)
    U.combo(p,'Mode',{{'Normal','normal'},{'Distance','distance'}},c.mode,function(v) c.mode=v end)
    U.numberInput(p,'Distance (SQM)',c.distance,1,5,function(v) c.distance=v E.stopFollow() end)
    U.toggle(p,'Stand in line',c.inLine,function(v) c.inLine=v end)
    U.numberInput(p,'Check delay (ms)',c.delay,0,10000,function(v) c.delay=v E.due.follow=nil end)
  elseif key=='bless' then
    U.textInput(p,'Command',c.command,function(v) c.command=v end)
  elseif key=='skin' then
    U.numberInput(p,'Tool ID',c.toolId,1,65535,function(v) c.toolId=v end)
    U.numberInput(p,'Delay (ms)',c.delay,0,10000,function(v) c.delay=v end)
    itemList(p,'CORPSE IDS',c,'ids')
  end
  return NexusBot.WindowManager.attach('extras_'..key,w)
end

local function nativeExtrasWindow()
  local w,p=formWindow('EXTRAS',510) w:setWidth(430)
  U.scrollbar(p)
  local toggles={}
  for _,entry in ipairs({{'food','Eat Food'},{'gold','Change Gold'},{'effects','Disable Magic Effects'},
    {'mount','Auto Mount'},{'idle','Anti Idle'},{'look','Display Item IDs On Look'},
    {'pm','Open Private Channel On PM'},{'training','Auto Training'},{'follow','Auto Follow Player'},
    {'bless','Buy bless at login'},{'skin','Skin monsters'}}) do
    local key,label=entry[1],entry[2]
    local row=g_ui.createWidget('NexusIntegrationRow',p)
    row.name:setText(label) row.enabled:setOn(E.cfg[key].enabled)
    row.enabled.onClick=function() E.setTool(key,not E.cfg[key].enabled) row.enabled:setOn(E.cfg[key].enabled) end
    toggles[#toggles+1]={key=key,widget=row.enabled}
    if key=='mount' or key=='look' or key=='pm' then row.edit:hide()
    else row.edit.onClick=function() E.openSettings(key) end end
  end
  U.button(p,'Channels Manager',function() return timerWindow(true) end)
  U.button(p,'Timer Actions',function() return timerWindow(false) end)
  U.button(p,'Show MW/WG Timers',function() E.WallTimers.open() end)
  ownTimer(w,function() for _,entry in ipairs(toggles) do entry.widget:setOn(E.cfg[entry.key].enabled==true) end end)
  return w
end
E.openTimers=timerWindow
M.windows.extrasWindow=nativeExtrasWindow
category.open = nativeExtrasWindow

-- ==================== LOGIC / RUNTIME ====================
local automationKeys={'antiKick','stake','oberon','autoOpenDoors','bless','holdMwall','checkPlayer','nextBackpack'}
category.getEnabled=function()
  return NexusBot.Storage.get().settings.extrasMaster==true
end
category.setEnabled=function(value)
  local runtime=M.getRuntime()
  local cfg=runtime and runtime.storage and runtime.storage.extras
  cfg=type(cfg)=='table' and cfg or {}
  local settings=NexusBot.Storage.get().settings
  if value then
    for key,saved in pairs(settings.pausedExtras or {}) do cfg[key]=saved end
    settings.pausedExtras=nil
    M.managed.extrasMaster={setOff=function() category.setEnabled(false) end}
  elseif settings.extrasMaster~=false then
    settings.pausedExtras={}
    for _,key in ipairs(automationKeys) do
      if type(cfg[key])=='boolean' then settings.pausedExtras[key]=cfg[key] cfg[key]=false end
    end
  end
  settings.extrasMaster=value==true
  if not value and E.reset then E.reset() end
  if runtime.saveConfig then runtime.saveConfig() end
  NexusBot.Storage.touch()
end

function category.timerRules(context)
  if not category.getEnabled() then M.timerDue={} return {} end
  local result={}
  local pz=PlayerStates and PlayerStates.Pz and context.player:hasState(PlayerStates.Pz)
  for _,rule in ipairs(M.extraTimers.rules) do
    if rule.enabled and E.active(E.timerGroup(rule)) then
      local interval=E.timerInterval(rule)
      M.timerDue[rule.id]=M.timerDue[rule.id] or (context.now+interval)
      if context.now>=M.timerDue[rule.id] and (rule.allowPz or not pz) then
        rule.advanced=rule.advanced or {} rule.advanced.minimumDelay=interval
        result[#result+1]=rule
      end
    else M.timerDue[rule.id]=nil end
  end
  if E.rules then for _,rule in ipairs(E.rules(context)) do result[#result+1]=rule end end
  return result
end
NexusBot.registerAction({id='use_item',name='Use item',execute=function(context,action)
  local id=tonumber(action.itemId) if not id or id<=0 then return false end
  return g_game.useInventoryItem(id)~=false
end})
NexusBot.registerAction({id='channel_message',name='Channel message',execute=function(context,action)
  if not E.active('channels') then return false end
  if context.now<(M.nextChannelMessage or 0) then return false end
  local text=tostring(action.spell or ''):match('^%s*(.-)%s*$')
  if text=='' or #text>255 then return false end
  local mode=action.mode or 'Say'
  if mode=='Channel' then
    local console=modules.game_console
    local id=tonumber(action.channel)
    if action.channelName and console and console.channels then
      id=nil
      for candidate,name in pairs(console.channels) do
        if name==action.channelName and tonumber(candidate) then id=tonumber(candidate) break end
      end
    end
    if not id or not console or not console.getChannelTab or not console.getChannelTab(id) then return false end
    if g_game.talkChannel(MessageModes.Channel,id,text)==false then return false end
  elseif mode=='Say' or mode=='Whisper' or mode=='Yell' then
    if g_game.talkChannel(MessageModes[mode],0,text)==false then return false end
  else return false end
  M.nextChannelMessage=context.now+NexusBot.Validation.number(E.cfg and E.cfg.channelDelay,10000,10000,3600000) return true
end})
-- The utility actions share the priority engine with healing: no second item-use loop.
local A=NexusBot.Automation
local V=NexusBot.Validation
E.tools={{'food','Eat Food'},{'gold','Change Gold'},{'effects','Disable Magic Effects'},
  {'mount','Auto Mount'},{'idle','Anti Idle'},{'look','Display Item IDs On Look'},
  {'pm','Open Private Channel On PM'},{'training','Auto Training'},{'follow','Auto Follow Player'},
  {'channels','Channels Manager'},{'timers','Timer Actions'},{'bless','Buy bless at login'},{'skin','Skin monsters'}}
function E.timerGroup(rule) return rule.type=='channel_message' and 'channels' or 'timers' end
function E.timerInterval(rule)
  local unit=({[1]=true,[1000]=true,[60000]=true})[rule.unit] and rule.unit or 1000
  return math.max(rule.type=='channel_message' and 10000 or 100,math.min(86400000,V.number(rule.interval,60,1,86400000)*unit))
end
function E.timerStatus(rule)
  if not rule.enabled then return 'OFF' end
  if not E.active(E.timerGroup(rule)) or not g_game.isOnline() then return 'PAUSED' end
  local due=M.timerDue[rule.id]
  if not due then return tostring(math.ceil(E.timerInterval(rule)/1000))..'s' end
  if due<=NexusBot.now() then return 'WAIT' end
  return tostring(math.ceil((due-NexusBot.now())/1000))..'s'
end
-- Import is explicit and transactional; never scan an external application's data each tick.
function E.parseFoods(document)
  if type(document)~='table' or type(document.Foods)~='table' then return nil,'Items.json must contain a Foods array.' end
  local ids,seen={},{}
  for index,entry in pairs(document.Foods) do
    if type(index)~='number' or index<1 or index%1~=0 or index>4096 then return nil,'Invalid Foods array.' end
    local id=type(entry)=='table' and entry.food_item_id
    if type(id)~='number' or id<1 or id>65535 or id%1~=0 then return nil,'Invalid food_item_id at entry '..index..'.' end
    if not seen[id] then seen[id]=true ids[#ids+1]=id end
  end
  if #ids==0 then return nil,'Foods is empty; existing IDs were preserved.' end
  table.sort(ids)
  return table.concat(ids,' ')
end
function E.importFoods()
  local path=(NexusBot.resourceRoot or '/nexus_bot')..'/Items.json'
  local ok,result=pcall(function()
    assert(g_resources.fileExists(path),'Put Items.json in CWELBOT/nexus_bot first.')
    local text=g_resources.readFileContents(path)
    assert(type(text)=='string' and #text<=4*1024*1024,'Items.json exceeds 4 MB.')
    local ids,err=E.parseFoods(json.decode(text))
    assert(ids,err) return ids
  end)
  if not ok then return false,tostring(result) end
  E.cfg.food.ids=result
  E.setTool('food',false) -- Review imported server-specific IDs before enabling.
  return true
end
function E.orderedIds(value)
  local list,seen={},{}
  for word in tostring(value or ''):gmatch('%d+') do
    local id=tonumber(word)
    if id>0 and id<=65535 and not seen[id] then seen[id]=true list[#list+1]=id end
  end
  return list
end
function E.ids(value)
  local ids={} for _,id in ipairs(E.orderedIds(value)) do ids[id]=true end return ids
end
function E.active(key)
  return NexusBot.enabled and category.getEnabled() and E.cfg and E.cfg[key] and E.cfg[key].enabled==true
end
function E.setTool(key,value)
  if not E.cfg[key] then return end
  E.cfg[key].enabled=value==true E.due[key]=nil
  if key=='channels' or key=='timers' then
    for _,rule in ipairs(M.extraTimers.rules) do if E.timerGroup(rule)==key then M.timerDue[rule.id]=nil end end
  end
  if key=='training' then E.trainingPending=true end
  if key=='bless' and value then E.blessPending=true end
  if value and (key=='skin' or key=='bless') then
    local runtime=M.getRuntime()
    local legacy=runtime and runtime.storage and runtime.storage.extras
    if legacy then
      legacy[key=='skin' and 'stake' or 'bless']=false
      if runtime.saveConfig then runtime.saveConfig() end
    end
  end
  if key=='follow' and not value then E.stopFollow() end
  if value then NexusBot.Categories.setEnabled(category,true) end
  E.updateEffects() NexusBot.Storage.touch()
end
local function findItem(ids,minimum)
  local player=g_game.getLocalPlayer()
  for slot=1,10 do
    local item=A.call(player,'getInventoryItem',nil,slot)
    if item and ids[item:getId()] and A.call(item,'getCount',1)>=(minimum or 1) then return item end
  end
  for _,bag in pairs(g_game.getContainers and g_game.getContainers() or {}) do
    for _,item in ipairs(bag:getItems()) do
      if ids[item:getId()] and A.call(item,'getCount',1)>=(minimum or 1) then return item end
    end
  end
end
local function pz(player) return PlayerStates and PlayerStates.Pz and A.call(player,'hasState',false,PlayerStates.Pz) end
local function use(item) return item and g_game.use and g_game.use(item)~=false or false end
local function useWith(item,target)
  if not item or not target or not g_game.useWith then return false end
  return g_game.useWith(item,target)~=false
end
function E.execute(context,action)
  local key=action.kind
  if not E.active(key) then return false end
  local c=E.cfg[key]
  if context.now<(E.due[key] or 0) then return false end
  -- Failed attempts are throttled as well (empty bags, unavailable mount, missing dummy).
  local minimum=key=='idle' and 1000 or key=='training' and 5000 or key=='mount' and 3000 or 500
  E.due[key]=context.now+V.number(c.delay,5000,minimum,86400000)
  if key=='food' then
    local remaining=A.call(context.player,'getRegenerationTime')
    if type(remaining)~='number' or remaining>V.number(c.below,60,0,1200) then return false end
    return use(findItem(E.ids(c.ids)))
  elseif key=='gold' then
    local item=findItem(E.ids(c.ids),V.number(c.count,100,2,10000))
    return c.mode=='with' and useWith(item,item) or (c.mode~='with' and use(item))
  elseif key=='mount' then
    local outfit=A.call(context.player,'getOutfit',{})
    if pz(context.player) or not g_game.mount or (tonumber(outfit.mount) or 0)>0 then return false end
    return g_game.mount(true)~=false
  elseif key=='idle' then
    local runtime=M.getRuntime() or {}
    if runtime.storage and runtime.storage.extras and runtime.storage.extras.antiKick then return false end
    if context.target or A.call(context.player,'isWalking',false) or A.call(context.player,'isAutoWalking',false) then return false end
    if not g_game.turn then return false end
    return g_game.turn((A.call(context.player,'getDirection',0)+1)%4)~=false
  elseif key=='training' then
    if context.target or A.call(context.player,'isWalking',false) or (c.mode=='stopped' and not E.trainingPending) then return false end
    local weapon=findItem(E.ids(c.weaponIds)) if not weapon then return false end
    local dummyIds=E.ids(c.dummyIds)
    local pos=context.position
    if not pos or not g_map then return false end
    if c.dummyName and c.dummyName~='' then
      for _,creature in ipairs(g_map.getSpectators(pos,false) or {}) do
        if creature~=context.player and not creature:isPlayer() and creature:getName():lower()==c.dummyName:lower() and A.distance(pos,creature:getPosition())<=1 then
          if useWith(weapon,creature) then E.trainingPending=false return true end
        end
      end
    end
    for dx=-1,1 do for dy=-1,1 do
      local tile=g_map.getTile({x=pos.x+dx,y=pos.y+dy,z=pos.z})
      for _,item in ipairs(A.call(tile,'getItems',{})) do
        if dummyIds[item:getId()] and useWith(weapon,item) then E.trainingPending=false return true end
      end
    end end
  elseif key=='bless' then
    if not E.blessPending then return false end
    local command=tostring(c.command or ''):match('^%s*(.-)%s*$')
    if command=='' or #command>255 then return false end
    if A.call(context.player,'getBlessings',0)>0 then E.blessPending=false return false end
    if g_game.talk(command)==false then return false end
    E.blessPending=false return true
  elseif key=='skin' then
    if context.target or A.call(context.player,'isWalking',false) then return false end
    local tool=findItem({[c.toolId]=true}) if not tool then return false end
    local ids=E.ids(c.ids) local pos=context.position
    if not pos then return false end
    for dx=-1,1 do for dy=-1,1 do
      local tile=g_map.getTile({x=pos.x+dx,y=pos.y+dy,z=pos.z})
      for _,item in ipairs(A.call(tile,'getItems',{})) do
        local signature=A.key(A.call(item,'getPosition'))..':'..item:getId()
        if ids[item:getId()] and (E.skinned[signature] or 0)<context.now and useWith(tool,item) then
          E.skinned[signature]=context.now+60000 return true
        end
      end
    end end
  end
  return false
end
NexusBot.registerAction({id='extras_tool',name='Extras utility',execute=E.execute})
function E.rules(context)
  local result={}
  for _,key in ipairs({'food','gold','mount','idle','training','bless','skin'}) do
    if E.active(key) then
      -- Anti-idle must never turn the player immediately upon enabling.
      if key=='idle' and not E.due[key] then E.due[key]=context.now+V.number(E.cfg.idle.delay,60000,1000,840000) end
      if context.now>=(E.due[key] or 0) then
        result[#result+1]={id='extras:'..key,enabled=true,type='extras_tool',priority=110,
          action={kind=key,spell=key},advanced={minimumDelay=100}}
      end
    else E.due[key]=nil end
  end
  return result
end
function E.onText(mode,text)
  if MessageModes and mode==MessageModes.Look and E.active('look') and E.looked and NexusBot.now()-E.looked.at<3000 then
    local message=tostring(text)..'\nItem ID: '..E.looked.id
    E.looked=nil
    if E.lookEvent then NexusBot.Scheduler.cancel(E.lookEvent) end
    E.lookEvent=NexusBot.Scheduler.after(1,function()
      E.lookEvent=nil
      if E.active('look') and modules.game_textmessage and modules.game_textmessage.displayMessage then
        modules.game_textmessage.displayMessage(MessageModes.Look,message)
      end
    end,'Look item ID')
  end
  if not E.active('training') or E.cfg.training.mode~='stopped' then return end
  -- Never react to player chat. Only the client's server text-message event reaches here.
  local needle=tostring(E.cfg.training.stopText or ''):lower()
  if #needle>=5 and tostring(text):lower():find(needle,1,true) then
    E.trainingPending=true E.due.training=math.max(E.due.training or 0,NexusBot.now()+1000)
  end
end
function E.onTalk(name,level,mode)
  if not E.active('pm') or not MessageModes then return end
  if mode~=MessageModes.PrivateFrom and mode~=MessageModes.GamemasterPrivateFrom then return end
  if type(name)~='string' or name=='' then return end
  local console=modules.game_console
  if not console or not console.addPrivateChannel then return end
  local exists=console.getTab and console.getTab(name) or (not console.getTab and E.pmOpened[name])
  if not exists then console.addPrivateChannel(name) end
  E.pmOpened[name]=true
end
function E.onLook(thing)
  if not E.active('look') or not thing or not A.call(thing,'isItem',false) then return end
  E.looked={id=thing:getId(),at=NexusBot.now()}
  local messages=modules.game_textmessage
  if messages and messages.displayStatusMessage then messages.displayStatusMessage('Item ID: '..tostring(thing:getId())) end
end
local function effectValues()
  local options=modules.client_options
  if not options or not options.getOption then return end
  local effect=options.getOption('setEffectAlphaScroll')
  local missile=options.getOption('setMissileAlphaScroll')
  if type(effect)=='number' and type(missile)=='number' then return effect/100,missile/100 end
end
function E.updateEffects()
  if not g_client or not g_client.setEffectAlpha or not g_client.setMissileAlpha then return end
  local enabled=E.active('effects') and g_game.isOnline()
  local mode=enabled and E.cfg.effects.mode or nil
  if not enabled then
    if E.effectsApplied then
      local effect,missile=effectValues()
      g_client.setEffectAlpha(effect or E.savedEffect or 1) g_client.setMissileAlpha(missile or E.savedMissile or 1)
      E.effectsApplied=nil E.effectMode=nil
    end
    return
  end
  if not E.effectsApplied then
    local effect,missile=effectValues()
    -- Do not overwrite graphics settings unless their restore values are known.
    if not effect then return end
    E.savedEffect,E.savedMissile=effect,missile
  end
  if not E.effectsApplied or E.effectMode~=mode then
    g_client.setEffectAlpha(0) g_client.setMissileAlpha(mode=='keepMissiles' and E.savedMissile or 0)
    E.effectsApplied=true E.effectMode=mode
  end
end
function E.stopFollow()
  -- Another movement engine may have replaced the pending step since our last tick.
  if E.followOwned and A.Navigation.pending==E.followPending then A.Navigation.reset() end
  E.followOwned=nil E.followPending=nil E.followGoal=nil
end
function E.rememberLeader(creature,pos,old)
  if not E.active('follow') or not A.call(creature,'isPlayer',false) then return end
  local function valid(p) return p and p.x and p.y and p.z and p.x<65535 and p.y<65535 and p.z>=0 and p.z<=15 end
  if not valid(pos) then return end
  if not valid(old) then old=nil end
  local wanted=tostring(E.cfg.follow.name or ''):match('^%s*(.-)%s*$'):lower()
  if wanted=='' or A.call(creature,'getName',''):lower()~=wanted then return end
  E.followTrail=E.followTrail or {}
  E.followVisited=E.followVisited or {}
  local oldestKey,oldestTime,count=nil,math.huge,0
  for key,entry in pairs(E.followVisited) do
    if NexusBot.now()-entry.at>30000 then E.followVisited[key]=nil
    else
      count=count+1
      if entry.at<oldestTime then oldestKey,oldestTime=key,entry.at end
    end
  end
  if count>=128 and oldestKey then E.followVisited[oldestKey]=nil end
  if pos then
    local tile=g_map.getTile(pos)
    if tile and A.call(tile,'isWalkable',false,false) then
      E.followVisited[A.key(pos)]={pos=NexusBot.copy(pos),at=NexusBot.now(),id=A.call(A.call(tile,'getTopUseThing'),'getId')}
    end
  end
  if old and pos and A.distance(old,pos)>1 then
    -- Only enter an observed transition tile, never arbitrary doors/stairs near a lost player.
    local entry
    local oldTile=g_map.getTile(old)
    if oldTile and A.Navigation.transition(oldTile) then entry=old end
    local d=A.Navigation.directions[(A.call(creature,'getDirection',0))+1]
    if not entry and d then
      local candidate={x=old.x+d[1],y=old.y+d[2],z=old.z}
      local tile=g_map.getTile(candidate)
      if tile and A.Navigation.transition(tile) then entry=candidate end
    end
    if entry then
      E.followTrail[#E.followTrail+1]={entry=NexusBot.copy(entry),landing=NexusBot.copy(pos),at=NexusBot.now()}
      if #E.followTrail>16 then table.remove(E.followTrail,1) end
    end
  end
  E.leaderLast=pos and NexusBot.copy(pos) or E.leaderLast
end
function E.followDoor(pos)
  if NexusBot.now()<(E.followDoorDue or 0) then return end
  for key,entry in pairs(E.followVisited or {}) do
    if NexusBot.now()-entry.at>30000 then E.followVisited[key]=nil
    elseif A.distance(pos,entry.pos)==1 then
      local tile=g_map.getTile(entry.pos) local thing=A.call(tile,'getTopUseThing')
      if tile and not A.call(tile,'isWalkable',false,false) and thing and
          A.call(thing,'getId')~=entry.id and not A.call(thing,'isPickupable',true) and A.call(thing,'isUsable',false) then
        if g_game.use(thing)~=false then E.followDoorDue=NexusBot.now()+1000 return true end
      end
    end
  end
end
function E.followTransition(pos)
  local trail=E.followTrail or {}
  while trail[1] and (NexusBot.now()-trail[1].at>30000 or A.distance(pos,trail[1].landing)<=1) do table.remove(trail,1) end
  local step=trail[1]
  if not step or step.entry.z~=pos.z then return false end
  local N=A.Navigation N.beginTick()
  E.followOwned=true N.walkRoute(step.entry,0,true) E.followPending=N.pending
  return true
end
function E.followTick()
  if not E.active('follow') or not g_game.isOnline() then E.stopFollow() return end
  local cfg=E.cfg.follow
  if A.CaveBot.isOn() or A.TargetBot.isOn() or (g_game.getAttackingCreature and g_game.getAttackingCreature()) then E.stopFollow() return end
  local now=NexusBot.now() if now<(E.due.follow or 0) then return end
  E.due.follow=now+V.number(cfg.delay,300,0,10000)
  local player=g_game.getLocalPlayer() local pos=A.position()
  local name=tostring(cfg.name or ''):match('^%s*(.-)%s*$'):lower()
  if not pos or name=='' then E.stopFollow() return end
  local leader
  for _,creature in ipairs(g_map.getSpectators(pos,false) or {}) do
    if creature~=player and A.call(creature,'isPlayer',false) and A.call(creature,'getName',''):lower()==name then leader=creature break end
  end
  local target=A.call(leader,'getPosition')
  if target and E.leaderLast and A.key(target)~=A.key(E.leaderLast) then E.rememberLeader(leader,target,E.leaderLast) end
  if target then E.leaderLast=NexusBot.copy(target) end
  if E.followTransition(pos) then return end
  if not target or target.z~=pos.z then E.stopFollow() return end
  local distance=cfg.mode=='distance' and V.number(cfg.distance,3,1,5) or 1
  if A.distance(pos,target)==distance and (not cfg.inLine or pos.x==target.x or pos.y==target.y) then E.stopFollow() return end
  if A.call(player,'isAutoWalking',false) and not E.followOwned then return end
  local N=A.Navigation N.beginTick()
  local goal,range=target,distance
  if cfg.inLine or A.distance(pos,target)<distance then
    local best
    for dx=-distance,distance do for dy=-distance,distance do
      local tile={x=target.x+dx,y=target.y+dy,z=target.z}
      if A.distance(tile,target)==distance and (not cfg.inLine or dx==0 or dy==0) and N.safeTile(tile,false) then
        local path=N.path(pos,tile,0,false)
        if path and (not best or #path<best) then goal,range,best=tile,0,#path end
      end
    end end
    if not best then return end
  end
  E.followOwned=true
  -- Keep the current short route until acknowledged instead of STOP/reissuing
  -- each time the leader changes tile. The next chunk follows their new position.
  if E.followGoal and N.pending and N.pending.route then goal,range=E.followGoal,0
  else
    local path=N.path(pos,goal,range,false)
    if path and #path>0 then
      goal=NexusBot.copy(pos)
      for i=1,math.min(3,#path) do local d=N.directions[path[i]+1] goal.x=goal.x+d[1] goal.y=goal.y+d[2] end
      range=0 E.followGoal=goal N.nextWalk=0
    else E.followGoal=nil end
  end
  local arrived,reason=N.walkRoute(goal,range,false)
  if arrived then E.followGoal=nil end
  E.followPending=N.pending
  if not arrived and reason~='waiting' and reason~='walking' then E.followDoor(pos) end
end
function E.reset()
  E.stopFollow() E.due={} E.pmOpened={} E.trainingPending=true M.timerDue={}
  E.looked=nil E.skinned={} E.blessPending=true E.followGoal=nil E.captureTraining=nil
  E.followTrail={} E.followVisited={} E.leaderLast=nil E.followDoorDue=nil
  if E.lookEvent then NexusBot.Scheduler.cancel(E.lookEvent) E.lookEvent=nil end
  if E.effectsApplied and g_client then
    local effect,missile=effectValues()
    g_client.setEffectAlpha(effect or E.savedEffect or 1) g_client.setMissileAlpha(missile or E.savedMissile or 1)
    E.effectsApplied=nil E.effectMode=nil
  end
end
function E.init()
  E.terminate()
  local previous=NexusBot.Storage.get().integrations.extraTools or {}
  local migrate={channels=previous.channels==nil,timers=previous.timers==nil}
  E.cfg=config('extraTools',{
    food={enabled=false,ids='',below=60,delay=5000},gold={enabled=false,ids='3031 3035',count=100,mode='use',delay=1000},
    effects={enabled=false,mode='all'},mount={enabled=false,delay=5000},idle={enabled=false,delay=60000},
    look={enabled=false},pm={enabled=false},training={enabled=false,weaponIds='',dummyIds='',mode='stopped',delay=60000,stopText='you have stopped training'},
    follow={enabled=false,name='',mode='normal',distance=3,inLine=false,delay=300},
    channels={enabled=false},timers={enabled=false},channelDelay=10000})
  E.cfg.bless=E.cfg.bless or {enabled=false,command='!bless',delay=5000}
  E.cfg.skin=E.cfg.skin or {enabled=false,toolId=5908,delay=500,ids='4286 4272 4173 4011 4025 4047 4052 4057 4062 4112 4212 4321 4324 4327 10352 10356 10360 10364'}
  -- Existing explicitly enabled rules keep working when an older setup is loaded.
  for _,rule in ipairs(M.extraTimers.rules) do
    local group=E.timerGroup(rule)
    if migrate[group] and rule.enabled==true then E.cfg[group].enabled=true end
  end
  E.due={} E.pmOpened={} E.trainingPending=true
  E.connections={onTextMessage=E.onText,onTalk=E.onTalk,onLook=E.onLook,onGameEnd=E.reset,onGameStart=E.reset,
    onUseWith=function(_,itemId,target)
      if not E.captureTraining or not target then return end
      E.captureTraining=nil
      E.cfg.training.weaponIds=tostring(itemId)
      if A.call(target,'isCreature',false) then E.cfg.training.dummyName=target:getName()
      else E.cfg.training.dummyIds=tostring(target:getId()) end
      E.trainingPending=true E.due.training=nil NexusBot.Storage.touch()
    end}
  connect(g_game,E.connections)
  if Creature then E.creatureConnections={onPositionChange=E.rememberLeader} connect(Creature,E.creatureConnections) end
  -- OTC has no Look signal: one owned wrapper, restored only if still ours.
  if type(g_game.look)=='function' then
    local original=g_game.look
    E.originalLook=original
    E.lookWrapper=function(thing,...)
      local result=original(thing,...)
      NexusBot.safeCall('Extras:look',E.onLook,thing)
      return result
    end
    g_game.look=E.lookWrapper
  end
  NexusBot.EventBus.on('actionExecuted',E,function(rule)
    for _,timer in ipairs(M.extraTimers.rules) do if timer.id==rule.id then
      M.timerDue[rule.id]=NexusBot.now()+E.timerInterval(timer) break
    end end
  end)
  E.loop=NexusBot.Scheduler.every(20,function() E.updateEffects() E.followTick() end,'Extras presentation/follow')
end
function E.terminate()
  if E.loop then NexusBot.Scheduler.cancel(E.loop) E.loop=nil end
  if E.connections then disconnect(g_game,E.connections) E.connections=nil end
  if E.creatureConnections then disconnect(Creature,E.creatureConnections) E.creatureConnections=nil end
  if E.lookWrapper and g_game.look==E.lookWrapper then g_game.look=E.originalLook end
  E.lookWrapper=nil E.originalLook=nil
  NexusBot.EventBus.offOwner(E) E.reset()
end
category.init=function()
  M.extraTimers=config('extraTimers',{rules={}}) M.timerDue={} M.nextChannelMessage=0
  E.init()
  E.WallTimers.init()
  NexusBot.Actions.registerProvider('extraTimers',40,category.timerRules)
end
category.terminate=function()
  E.WallTimers.terminate()
  E.terminate()
  NexusBot.Actions.unregisterProvider('extraTimers') M.timerDue={} M.nextChannelMessage=0
end

-- Server-authoritative per-instance wall lifetimes. No guessed standard TTL.
E.WallTimers={entries={}}
local WT=E.WallTimers
function WT.config()
  local data=NexusBot.Storage.get() data.integrations=data.integrations or {}
  data.integrations.wallTimers=data.integrations.wallTimers or {enabled=false,opcode=0,ids='2128,2129,2130,2131,2132'}
  return data.integrations.wallTimers
end
function WT.clear()
  for _,entry in pairs(WT.entries) do
    local tile=g_map and g_map.getTile(entry.position)
    if tile and entry.text and tile:getText()==entry.text then tile:setText('') end
  end
  WT.entries={} WT.sequence=nil
end
function WT.receive(message)
  local cfg=WT.config()
  if not cfg.enabled or type(message)~='table' or message.protocol~='nexus.walls.v1' then return false end
  local stamp,sequence=tonumber(message.serverNowMs),tonumber(message.sequence)
  if not stamp or stamp~=stamp or not sequence or sequence~=sequence or sequence%1~=0 then return false end
  if WT.sequence and sequence<=WT.sequence then return false end
  if type(message.walls)~='table' or #message.walls>256 then return false end
  WT.sequence=sequence
  local ids=E.ids(cfg.ids) local now=NexusBot.now()
  for _,data in ipairs(message.walls) do
    if type(data)~='table' then return false end
    local p=data.position local id=tonumber(data.itemId)
    local valid=type(p)=='table' and type(data.instance)=='string' and #data.instance<=64
    for _,key in ipairs({'x','y','z'}) do
      local n=valid and tonumber(p[key])
      if not n or n%1~=0 or n<0 or n>(key=='z' and 15 or 65534) then valid=false end
    end
    if valid then
      local key=A.key(p) local previous=WT.entries[key]
      if data.remove==true then
        if previous and previous.instance==data.instance then previous.expires=0 end
      elseif ids[id] then
        local ttl=tonumber(data.expiresAtMs) and tonumber(data.expiresAtMs)-stamp
        if ttl and ttl==ttl and ttl>0 and ttl<=600000 then
          local count=0 for _ in pairs(WT.entries) do count=count+1 end
          if previous or count<512 then
            WT.entries[key]={position={x=tonumber(p.x),y=tonumber(p.y),z=tonumber(p.z)},instance=data.instance,itemId=id,
              expires=now+ttl-math.max(0,tonumber(g_game.getPing and g_game.getPing()) or 0)/2,
              received=now,text=previous and previous.text}
          end
        end
      end
    end
  end
  return true
end
function WT.tick()
  if not WT.config().enabled or not g_game.isOnline() then WT.clear() return end
  local now=NexusBot.now()
  for key,entry in pairs(WT.entries) do
    local tile=g_map.getTile(entry.position) local exists=false
    for _,item in ipairs(A.call(tile,'getItems',{})) do if item:getId()==entry.itemId then exists=true break end end
    if exists then entry.seen=true end
    if entry.expires<=now or (not exists and (entry.seen or now-entry.received>2000)) then
      if tile and entry.text and tile:getText()==entry.text then tile:setText('') end
      WT.entries[key]=nil
    elseif exists and (tile:getText()=='' or tile:getText()==entry.text) then
      entry.text=string.format('%.1f s',math.max(0,entry.expires-now)/1000) tile:setText(entry.text)
    end
  end
end
function WT.register()
  if WT.opcode then ProtocolGame.unregisterExtendedOpcode(WT.opcode) WT.opcode=nil end
  WT.clear()
  local cfg=WT.config() local opcode=tonumber(cfg.opcode)
  if not cfg.enabled or not opcode or opcode<1 or opcode>255 then return end
  local ok,err=pcall(ProtocolGame.registerExtendedOpcode,opcode,function(_,_,buffer)
    if #buffer>64000 then return end
    local parsed,data=pcall(json.decode,buffer)
    if parsed then WT.receive(data) end
  end)
  if ok then WT.opcode=opcode else cfg.enabled=false NexusBot.Logger.warn('Wall timers','Opcode unavailable: '..tostring(err)) end
end
function WT.open()
  local w,p=formWindow('SHOW MW/WG TIMERS',180) w:setWidth(360) U.scrollbar(p)
  local cfg=WT.config()
  U.toggle(p,'Server timers',cfg.enabled,function(v) cfg.enabled=v WT.register() end)
  U.numberInput(p,'Server opcode (0 = unset)',cfg.opcode,0,255,function(v) cfg.opcode=v WT.register() end)
  U.textInput(p,'Wall item IDs',cfg.ids,function(v) cfg.ids=v WT.clear() end)
  return NexusBot.WindowManager.attach('extras_wall_timers',w)
end
function WT.init()
  if WT.loop or WT.connection then WT.terminate() end
  WT.register()
  WT.connection={onGameEnd=WT.clear,onGameStart=WT.clear} connect(g_game,WT.connection)
  WT.loop=NexusBot.Scheduler.every(100,WT.tick,'Server wall timers')
end
function WT.terminate()
  NexusBot.Scheduler.cancel(WT.loop) WT.loop=nil
  if WT.connection then disconnect(g_game,WT.connection) WT.connection=nil end
  if WT.opcode then ProtocolGame.unregisterExtendedOpcode(WT.opcode) WT.opcode=nil end
  WT.clear()
end
