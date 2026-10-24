-- TARGETING: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('targeting', 'TARGETING', 4, false)
category.getEnabled=function() return NexusBot.Automation.TargetBot.isOn() end
category.setEnabled=function(v)
  local engine=NexusBot.Automation.TargetBot
  if v then engine.setOn() else engine.setOff() end
end

-- ==================== GUI / LAYOUT ====================
NexusBot.embeddedUI = NexusBot.embeddedUI or {}
NexusBot.embeddedUI['targeting'] = [=[
NexusWindow
  id: cwelTargeting
  text: TARGETING
  size: 800 570
  NexusIconButton
    id: closeButton
    anchors.top: parent.top
    anchors.right: parent.right
    margin-top: -32
    text: X
    color: #fa6275
  Panel
    id: toolbar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 28
    layout:
      type: horizontalBox
      spacing: 8
  NexusPanel
    id: sidebar
    anchors.top: toolbar.bottom
    anchors.left: parent.left
    anchors.bottom: footer.top
    width: 220
    margin-top: 8
    margin-bottom: 8
    layout:
      type: verticalBox
      spacing: 4
    NexusSectionLabel
      text: CREATURE RULES
    NexusSearchBox
      id: search
      placeholder: Search creatures...
      height: 0
      visible: false
    NexusScrollPanel
      id: rules
      height: 330
      layout:
        type: verticalBox
        spacing: 3
    Panel
      id: ruleButtons
      height: 26
      layout:
        type: horizontalBox
        spacing: 4
    NexusSectionLabel
      text: LOOTING
    Panel
      id: loot
      height: 28
      layout:
        type: verticalBox
        spacing: 4
  NexusPanel
    id: editor
    anchors.top: sidebar.top
    anchors.left: sidebar.right
    anchors.right: parent.right
    anchors.bottom: sidebar.bottom
    margin-left: 8
    Panel
      id: nameRow
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 30
      layout:
        type: verticalBox
    Panel
      id: numbers
      anchors.top: nameRow.bottom
      anchors.left: parent.left
      anchors.bottom: editButtons.top
      width: 245
      margin-top: 8
      margin-bottom: 6
      layout:
        type: verticalBox
        spacing: 4
    Panel
      id: switches
      anchors.top: numbers.top
      anchors.left: numbers.right
      anchors.right: parent.right
      anchors.bottom: editButtons.top
      margin-left: 8
      margin-bottom: 6
      layout:
        type: verticalBox
        spacing: 4
    Panel
      id: editButtons
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 0
      layout:
        type: horizontalBox
        spacing: 6
  Panel
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 42
    NexusMutedLabel
      id: status
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 20
    NexusMutedLabel
      id: hint
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 18
      text: Save rule to apply changes. Right-click a creature for copy, order or delete.
  NexusPanel
    id: transfer
    anchors.top: sidebar.top
    anchors.left: sidebar.left
    anchors.right: editor.right
    anchors.bottom: editor.bottom
    visible: false
    padding: 14
    NexusHeader
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      text: PROFILE IMPORT / EXPORT
    NexusTextInputMulti
      id: text
      anchors.top: title.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: buttons.top
      margin-top: 10
      margin-bottom: 10
    Panel
      id: buttons
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 28
      layout:
        type: horizontalBox
        spacing: 8
]=]

do
NexusBot.Features.TargetTools={}
local T=NexusBot.Features.TargetTools
local U=NexusBot.UI
T.chaseSuspended=true
T.groups={
  {name='Combat',numbers={{'priority','Priority',0,10,1},{'danger','Danger',0,10,1},{'maxDistance','Maximum distance',1,10,10}},flags={{'chase','Chase',false},{'dontLoot','Do not loot',false},{'faceMonster','Face monsters',false},{'avoidAttacks','Avoid waves',false},{'diamondArrows','Diamond arrow priority',false},{'rpSafe','RP PvP safe',false}}},
  {name='Movement',numbers={{'keepDistanceRange','Keep distance range',1,5,1},{'anchorRange','Anchor range',1,10,3},{'rePositionAmount','Min free tiles to reposition',0,7,5},{'closeLureAmount','Close pull count',0,8,3}},flags={{'keepDistance','Keep distance',false},{'anchor','Anchor',false},{'rePosition','Reposition',false},{'closeLure','Close pulling',false}}},
  {name='Luring',numbers={{'lureCount','Classic lure count',0,5,1},{'lureMin','Dynamic lure minimum',0,29,1},{'lureMax','Dynamic lure maximum',1,30,3},{'lureDelay','Dynamic delay (ms)',100,1000,250},{'delayFrom','Delay from count',1,29,2}},flags={{'lure','Classic lure',false},{'lureCavebot','Lure using CaveBot',false},{'dynamicLure','Dynamic lure',false},{'dynamicLureDelay','Dynamic lure delay',false}}}
}
T.defaults={name='*'}
for _,group in ipairs(T.groups) do
  for _,field in ipairs(group.numbers) do T.defaults[field[1]]=field[5] end
  for _,field in ipairs(group.flags) do T.defaults[field[1]]=field[3] end
end
function T.editor(parent,engine,entry,refresh)
  U.clear(parent)
  local profile=engine.getCurrentProfile()
  local draft=NexusBot.merge(T.defaults,entry and entry.value)
  U.textInput(parent,'Creature(s)',draft.name,function(v) draft.name=v end)
  local status=U.label(parent,'Comma-separated names; * and ? wildcards. Saving stops targeting.')
  status:setHeight(36) status:setTextWrap(true)
  U.button(parent,'Save creature rule',function()
    local ok,err=T.apply(engine,entry,draft,profile)
    if ok then refresh() else status:setText(err) status:setTooltip(nil) end
  end,true)
  local groups=T.groups
  if engine.independent then
    groups={
      {name='Combat',numbers=T.groups[1].numbers,flags={{'chase','Chase',true},{'dontLoot','Do not loot',false},{'faceMonster','Face monsters',false},{'avoidAttacks','Avoid wave lines',false}}},
      {name='Movement',numbers={{'keepDistanceRange','Keep distance range',1,5,1},{'anchorRange','Anchor range',1,10,3}},flags={{'keepDistance','Keep distance',false},{'anchor','Stay near anchor',false}}}
    }
    status:setText('Independent engine. Legacy luring / special arrow options are not executed.')
  end
  local options={} for i,group in ipairs(groups) do options[#options+1]={group.name,i} end
  if not engine.independent then options[#options+1]={'Other saved fields',#groups+1} end
  local fields
  local function render(index)
    U.clear(fields)
    local group=groups[index]
    if group then
      for _,field in ipairs(group.numbers) do U.numberInput(fields,field[2],draft[field[1]],field[3],field[4],function(v) draft[field[1]]=v end) end
      for _,field in ipairs(group.flags) do
        local suspended=field[1]=='chase' and T.chaseSuspended
        if suspended then draft.chase=false end
        local toggle=U.toggle(fields,field[2],draft[field[1]],function(v) draft[field[1]]=v end)
        if suspended then toggle:setEnabled(false) toggle:setTooltip(nil) end
      end
    else
      local found=false
      local keys={} for key in pairs(draft) do if T.defaults[key]==nil and key~='regex' then keys[#keys+1]=key end end table.sort(keys)
      for _,key in ipairs(keys) do
        local value=draft[key]
        if type(value)=='boolean' then U.toggle(fields,key,value,function(v) draft[key]=v end)
        elseif type(value)=='number' then U.numberInput(fields,key,value,-999999,999999,function(v) draft[key]=v end)
        elseif type(value)=='string' then U.textInput(fields,key,value,function(v) draft[key]=v end)
        else U.label(fields,key..' (preserved unchanged)') end
        found=true
      end
      if not found then U.label(fields,'No additional saved fields.') end
    end
  end
  U.combo(parent,'Settings',options,1,render)
  fields=g_ui.createWidget('NexusConditionGroup',parent) render(1)
end
function T.profiles(left,right,runtime)
  U.clear(left) U.clear(right)
  local engine,config=runtime.TargetBot,runtime.Config
  if not config or not config.list or not config.save then U.label(left,'Profile API is not loaded.') return end
  local status=U.label(right,'Load/save operations keep targeting OFF.')
  if engine.independent then U.button(left,'Import active legacy profile',function()
    local ok,message=NexusBot.Automation.importLegacy('targetbot_configs',NexusBot.Features.Modern.getRuntime())
    if ok then T.profiles(left,right,runtime) else status:setText(message) status:setTooltip(nil) end
  end) end
  local function protected(fn)
    return function()
      local ok,err=pcall(fn)
      if not ok then pcall(engine.setOff) if not status:isDestroyed() then status:setText('Failed. See tooltip.') status:setTooltip(nil) end end
    end
  end
  local profiles=config.list('targetbot_configs') or {}
  for _,name in ipairs(profiles) do
    local b=U.button(left,name,protected(function() engine.setOff() engine.setCurrentProfile(name) engine.setOff() T.profiles(left,right,runtime) end))
    b:setOn(engine.getCurrentProfile()==name)
  end
  local name=U.textInput(right,'New name','',function() end)
  local function write(data)
    local n=name:getText()
    if not NexusBot.Features.CaveTools.validName(n) then status:setText('Use letters, numbers, _ or - (max 48).') return end
    for _,existing in ipairs(config.list('targetbot_configs') or {}) do if existing:lower()==n:lower() then status:setText('Profile already exists. Choose another name.') return end end
    local ok,err=T.validateProfile(data) if not ok then status:setText(err) return end
    for _,rule in ipairs(data.targeting) do if not rule.regex or rule.regex=='' then rule.regex=T.pattern(rule.name) end end
    engine.setOff()
    if not config.save('targetbot_configs',n,data,'json') then status:setText('Could not save profile.') return end
    engine.setCurrentProfile(n) engine.setOff() T.profiles(left,right,runtime)
  end
  U.button(right,'New empty profile',protected(function() write({targeting={},looting={}}) end))
  U.button(right,'Duplicate current profile',protected(function() write(T.snapshot(engine)) end))
  local text=g_ui.createWidget('NexusTextInputMulti',right) text:setHeight(130)
  U.button(right,'Export JSON',protected(function() text:setText(json.encode(T.snapshot(engine),2)) end))
  U.button(right,'Import as new profile',protected(function()
    local ok,data=pcall(json.decode,text:getText()) if not ok then status:setText('Invalid JSON.') return end write(data)
  end))
end
end

do
NexusBot.UI.Targeting={}
local UI=NexusBot.UI.Targeting
local U=NexusBot.UI
UI.numbers={
  {'priority','Priority',0,10,'Base priority; close, wounded and current targets gain bonuses.'},
  {'danger','Danger',0,10,'Adds to the danger total used by looting.'},
  {'maxDistance','Max distance',1,10,'Maximum reachable path distance to attack.'},
  {'keepDistanceRange','Keep distance',1,5,'Maintain this distance or one tile farther.'},
  {'anchorRange','Anchoring range',1,10,'Limit distance movement around the anchor.'},
  {'lureCount','Classic lure count',0,5,'Keep gathering until this many targets are present.'},
  {'lureMin','Dynamic lure min',0,29,'Resume gathering at or below this count.'},
  {'lureMax','Dynamic lure max',1,30,'Stop gathering at or above this count. Max wins if min = max.'},
  {'lureDelay','Dynamic lure delay (ms)',100,1000,'Pause CaveBot after a confirmed movement step.'},
  {'delayFrom','Start delay at monsters',1,29,'Apply step delay starting from this target count.'},
  {'rePositionAmount','Min free tiles to reposition',0,7,'Look for a better adjacent tile if surroundings are this tight.'},
  {'closeLureAmount','Close pull until',0,8,'Allow CaveBot to continue once this many monsters are adjacent.'}
}
UI.flags={
  {'chase','Chase','Walk toward the target; movement avoids fields and transitions.'},
  {'keepDistance','Keep distance','Maintain the configured ranged fighting distance.'},
  {'anchor','Anchoring','Keep ranged movement near the original anchor.'},
  {'dontLoot',"Don't loot",'Do not queue corpses for this rule.'},
  {'lure','Lure','Retreat to 5-6 tiles while gathering a small group.'},
  {'lureCavebot','Lure using CaveBot','Let your enabled CWELBOT route gather monsters.'},
  {'faceMonster','Face monsters','Step from diagonal to cardinal adjacency and face the monster.'},
  {'avoidAttacks','Avoid wave attacks','Sidestep adjacent frontal lines. Takes precedence over Face monsters.'},
  {'dynamicLure','Dynamic lure','Gather to max, fight down to min, then gather again. Requires a running route.'},
  {'dynamicLureDelay','Dynamic lure delay','Delay route movement after a step when enough targets are present.'},
  {'diamondArrows','D-Arrows priority','Prefer targets whose diamond-arrow area covers more monsters.'},
  {'rePosition','Reposition to better tile','Choose an adjacent tile with more open neighbours. Not a retreat distance.'},
  {'closeLure','Close pulling monsters','Continue your route after the adjacent-monster threshold is reached.'},
  {'rpSafe','RP PVP SAFE (DA)','With D-Arrows, reject targets near other players. Not a server-side PvP guarantee.'}
}
local function compactNumber(parent,label,value,min,max,callback,tooltip)
  local input=U.numberInput(parent,label,value,min,max,callback)
  local row=input:getParent() row:setHeight(27) row.label:setWidth(177) row.label:setTooltip(nil)
  input:setHeight(25) input:setWidth(55) return input
end
function UI.create()
  local A=NexusBot.Automation local engine=A.TargetBot local T=NexusBot.Features.TargetTools
  local w=NexusBot.loadUI('targeting',rootWidget)
  w.footer:hide() w.footer:setHeight(0)
  local selected,draft,profile,dirty=nil,nil,engine.getCurrentProfile(),false
  local message=''
  local function info(text)
    message=tostring(text or '')
    w.footer:hide() w.footer:setHeight(0)
  end
  local function protected(fn)
    return function(...) local ok,err=pcall(fn,...) if not ok then displayErrorBox('Targeting',tostring(err)) end end
  end
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
  local master=U.toggle(w.toolbar,'Targeting',engine.isOn(),function(on)
    if on then NexusBot.setEnabled(true) engine.setOn() else engine.setOff() end
  end) master.container:setWidth(126)
  master.container:hide() master.container:setWidth(0)
  local profiles
  local refreshList,edit,refreshProfiles,renderLoot
  local name=U.textInput(w.toolbar,'New','',function() end) name:getParent():setWidth(180) name:getParent().label:setWidth(36)
  name:getParent():hide() name:getParent():setWidth(0)
  local function newProfile(copy)
    local value=name:getText()
    if not NexusBot.Features.CaveTools.validName(value) then info('Profile name: letters, numbers, _ or -; maximum 48.') return end
    for existing in pairs(A.data().targetProfiles) do if existing:lower()==value:lower() then info('This profile already exists.') return end end
    local data=copy and T.snapshot(engine) or {targeting={},looting={}}
    A.saveProfile('targetbot_configs',value,data) engine.setCurrentProfile(value) profile=value selected=nil dirty=false
    refreshProfiles() refreshList() edit() renderLoot() info('Profile '..value..' created; Targeting OFF.')
  end
  U.button(w.toolbar,'Profiles',function()
    local menu=g_ui.createWidget('NexusContextMenu')
    local function create(copy)
      U.prompt(copy and 'Duplicate profile' or 'New profile','Profile name',function(value) name:setText(value) newProfile(copy) end)
    end
    menu:addOption('New profile',function() create(false) end)
    menu:addOption('Duplicate',function() create(true) end)
    menu:addOption('Import / Export',function() w.transfer:show() w.transfer:raise() end)
    menu:display(g_window.getMousePosition())
  end):setWidth(80)
  refreshProfiles=function()
    if profiles then profiles:getParent():destroy() end
    local options={} for _,value in ipairs(A.runtime.Config.list('targetbot_configs')) do options[#options+1]={value,value} end
    profiles=U.combo(w.toolbar,'',options,engine.getCurrentProfile(),function(value)
      if dirty then profiles:setCurrentOption(engine.getCurrentProfile(),true) info('Save or Discard the edited rule before switching profiles.') return end
      local ok,err=pcall(engine.setCurrentProfile,value) if not ok then info(err) return end
      profile=value selected=nil refreshList() edit() renderLoot()
    end)
    local row=profiles:getParent() row:setWidth(140) row.label:setWidth(0) w.toolbar:moveChildToIndex(row,1)
  end
  local ruleControls=w.sidebar.ruleButtons
  U.button(ruleControls,'+ Add',function() edit(nil,{name='*'}) end):setWidth(60)
  U.button(ruleControls,'Copy',function()
    if not selected then info('Select a creature first.') return end
    if dirty then info('Save or Discard changes first.') return end
    local value=NexusBot.copy(selected.value) edit(nil,value)
  end):setWidth(60)
  U.button(ruleControls,'Remove',function()
    if not selected then return end engine.setOff() selected:destroy() engine.Creature.resetConfigsCache() engine.save() selected=nil dirty=false refreshList() edit()
  end):setWidth(66)
  refreshList=function()
    U.clear(w.sidebar.rules)
    local query=w.sidebar.search:getText():lower()
    for _,entry in ipairs(engine.targetList:getChildren()) do
      if entry.value.name:lower():find(query,1,true) then
        local button=U.button(w.sidebar.rules,entry.value.name=='*' and 'All creatures' or entry.value.name,function()
          if dirty then info('Save or Discard changes before selecting another rule.') return end edit(entry)
        end)
        button:setHeight(25) button:setOn(selected==entry)
        button.onMouseRelease=function(_,pos,mouse)
          if mouse~=MouseRightButton then return false end
          local menu=g_ui.createWidget('NexusContextMenu')
          for _,move in ipairs({{'Move up',-1},{'Move down',1}}) do menu:addOption(move[1],function()
            engine.setOff() local i=engine.targetList:getChildIndex(entry)
            if i then engine.targetList:moveChildToIndex(entry,math.max(1,math.min(engine.targetList:getChildCount(),i+move[2]))) engine.Creature.resetConfigsCache() engine.save() refreshList() end
          end) end
          menu:addOption('Copy',function() if dirty then info('Save or Discard changes first.') else edit(nil,NexusBot.copy(entry.value)) end end)
          menu:addOption('Delete',function() engine.setOff() entry:destroy() engine.Creature.resetConfigsCache() engine.save() selected=nil dirty=false refreshList() edit() end)
          menu:display(pos) return true
        end
      end
    end
  end
  edit=function(entry,value)
    selected=entry profile=engine.getCurrentProfile() dirty=false
    if not entry and not value then w.editor:hide() refreshList() return end
    if not entry then
      local ok,err=T.apply(engine,nil,NexusBot.merge(T.defaults,value),profile)
      if not ok then displayErrorBox('Targeting',err) return end
      entry=engine.targetList.entries[#engine.targetList.entries] selected=entry
    end
    w.editor:show()
    draft=NexusBot.merge(T.defaults,value or (entry and entry.value) or {name=''})
    if T.chaseSuspended then draft.chase=false end
    U.clear(w.editor.nameRow) U.clear(w.editor.numbers) U.clear(w.editor.switches) U.clear(w.editor.editButtons)
    local function change(key,v)
      draft[key]=(key=='name' and v=='All creatures') and '*' or v
      local valid=T.validate(draft)
      if not valid then return end
      local ok,err=T.apply(engine,selected,draft,profile)
      if not ok then displayErrorBox('Targeting',err) return end
      refreshList()
    end
    local input=U.textInput(w.editor.nameRow,'Target name',draft.name=='*' and 'All creatures' or draft.name,function(v) change('name',v) end)
    input:getParent():setHeight(30) input:getParent().label:setWidth(90) input:setTooltip(nil)
    for _,field in ipairs(UI.numbers) do compactNumber(w.editor.numbers,field[2],draft[field[1]],field[3],field[4],function(v) change(field[1],v) end,field[5]) end
    for _,field in ipairs(UI.flags) do
      local toggle=U.toggle(w.editor.switches,field[2],draft[field[1]],function(v) change(field[1],v) end,field[3]) toggle.container:setHeight(25)
      if field[1]=='chase' and T.chaseSuspended then
        toggle:setEnabled(false) toggle:setTooltip(nil)
      end
    end
    compactNumber(w.editor.numbers,'Finish target below HP%',A.data().killUnder or 30,0,100,function(v) A.data().killUnder=v NexusBot.Storage.touch() end,'Global: finish wounded targets instead of continuing lure. 0 disables this override.')
    refreshList()
  end
  renderLoot=function()
    U.clear(w.sidebar.loot)
    U.button(w.sidebar.loot,'Edit',function()
    NexusBot.WindowManager.close('target_loot')
    local popup,p=NexusBot.Features.Modern.shared.formWindow('LOOTING',310) popup:setWidth(340)
    local cfg={} engine.Looting.save(cfg)
    U.toggle(p,'Loot all / ignore list',cfg.everyItem,function(v) cfg.everyItem=v end)
    local function number(label,key,min,max)
      local input=U.numberInput(p,label,cfg[key],min,max,function(v) cfg[key]=v end)
      input:getParent():setHeight(26) input:getParent().label:setWidth(130) input:setHeight(24)
    end
    number('Max danger','maxDanger',0,999) number('Minimum capacity','minCapacity',0,999999)
    local function itemList(label,list)
      U.label(p,label):setHeight(16)
      local ids={} for _,item in ipairs(list or {}) do ids[#ids+1]=item.id end
      local input=g_ui.createWidget('NexusTextInput',p) input:setText(table.concat(ids,',')) input:setHeight(25) return input
    end
    local items=itemList('Loot item IDs (comma separated)',cfg.items)
    local bags=itemList('Destination container IDs',cfg.containers)
    U.button(p,'Save loot',protected(function()
      local parsed,err=NexusBot.Features.CaveTools.parseItems(items:getText()) if not parsed then info(err) return end
      local containers,bagErr=NexusBot.Features.CaveTools.parseItems(bags:getText()) if not containers then info(bagErr) return end
      engine.setOff() cfg.items=parsed cfg.containers=containers engine.Looting.update(cfg) engine.save() popup:hide()
    end)):setHeight(25)
    NexusBot.WindowManager.attach('target_loot',popup)
    end)
  end
  local transfer=w.transfer
  U.button(transfer.buttons,'Export current',function() transfer.text:setText(json.encode(T.snapshot(engine),2)) end):setWidth(140)
  U.button(transfer.buttons,'Import as new profile',protected(function()
    local data=json.decode(transfer.text:getText())
    U.prompt('Import profile','Profile name',protected(function(value)
      if not NexusBot.Features.CaveTools.validName(value) then info('Use letters, numbers, _ or - (maximum 48).') return end
      for existing in pairs(A.data().targetProfiles) do if existing:lower()==value:lower() then info('Choose a different profile name.') return end end
      local valid,err=T.validateProfile(data) if not valid then info(err) return end
      A.saveProfile('targetbot_configs',value,data) engine.setCurrentProfile(value) selected=nil dirty=false
      refreshProfiles() refreshList() edit() renderLoot() transfer:hide()
    end))
  end)):setWidth(160)
  U.button(transfer.buttons,'Import legacy',protected(function()
    local ok,err=A.importLegacy('targetbot_configs',NexusBot.Features.Modern.getRuntime())
    if ok then selected=nil dirty=false refreshProfiles() refreshList() edit() renderLoot() transfer:hide() end info(err)
  end)):setWidth(120)
  U.button(transfer.buttons,'Back to targeting',function() transfer:hide() end):setWidth(145)
  w.sidebar.search.onTextChange=refreshList
  refreshProfiles() refreshList() edit(engine.targetList:getFirstChild()) renderLoot()
  local timer=NexusBot.Scheduler.every(250,function()
    if w:isDestroyed() or not w:isVisible() then return end
    master:setOn(engine.isOn())
    w.footer.status:setText((engine.status or 'OFF')..'  |  Profile: '..engine.getCurrentProfile()..'  |  Danger: '..engine.Danger()..'  |  '..tostring(#(A.Targeting.nearby or {}))..' visible creatures')
    if profile~=engine.getCurrentProfile() then dirty=false selected=nil refreshProfiles() edit(engine.targetList:getFirstChild()) renderLoot() info('Profile changed externally; editor refreshed.') end
  end,'Targeting UI')
  w.onDestroy=function() NexusBot.Scheduler.cancel(timer) end
  w.controller={edit=edit,refresh=refreshList,renderLoot=renderLoot}
  return w
end
end

do
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

local function targetingWindow()
  if NexusBot.UI.Targeting then return NexusBot.UI.Targeting.create() end
  local w,left,right=engineWindow('TARGETING')
  local runtime=NexusBot.Automation.runtime
  local engine=runtime.TargetBot
  local T=NexusBot.Features.TargetTools
  if not engine or not engine.targetList or not engine.Creature then
    U.label(left,'Independent Targeting initialization failed. Check the log.')
    U.label(right,'Check the CWELBOT initialization error before enabling automation.')
    return w
  end
  local state=managedToggle(w.toolbar,'Targeting',engine,'targeting') state.container:setWidth(150)
  local page='rules'
  local selected,refresh
  local function edit(entry) selected=entry T.editor(right,engine,entry,refresh) end
  refresh=function()
    U.clear(left) U.clear(right)
    U.button(left,'+ Creature rule',function() edit() end,true)
    local search=U.textInput(left,'Search','',function() end)
    local list=g_ui.createWidget('NexusConditionGroup',left)
    local function render()
      U.clear(list)
      for _,entry in ipairs(engine.targetList:getChildren()) do
        local rule=entry.value
        if rule.name:lower():find(search:getText():lower(),1,true) then
          local button=U.button(list,rule.name..'  /  P'..tostring(rule.priority or 1)..'  D'..tostring(rule.danger or 1),function() edit(entry) end)
          button:setTooltip(nil)
          button.onMouseRelease=function(_,pos,mouse)
            if mouse~=MouseRightButton then return false end
            local menu=g_ui.createWidget('NexusContextMenu')
            menu:addOption('Edit',function() if isAlive(entry) then edit(entry) end end)
            menu:addOption('Duplicate',function()
              if not isAlive(entry) then return end
              local draft=NexusBot.copy(entry.value)
              local ok,err=T.apply(engine,nil,draft,engine.getCurrentProfile())
              if ok then refresh() else U.label(right,err) end
            end)
            for _,move in ipairs({{'Move up',-1},{'Move down',1}}) do menu:addOption(move[1],function()
              if not isAlive(entry) then return end
              engine.setOff()
              local index=engine.targetList:getChildIndex(entry)+move[2]
              if index>=1 and index<=engine.targetList:getChildCount() then engine.targetList:moveChildToIndex(entry,index) engine.Creature.resetConfigsCache() engine.save() refresh() end
            end) end
            menu:addOption('Delete',function()
              if isAlive(entry) then engine.setOff() entry:destroy() engine.Creature.resetConfigsCache() engine.save() refresh() end
            end)
            menu:display(pos) return true
          end
        end
      end
    end
    search.onTextChange=render render()
    U.label(right,'Select a creature to edit. Right click: duplicate, move or delete.')
    U.label(right,'Priority selects targets. Movement/luring uses the existing engine.')
    selected=nil
  end
  local choice=U.combo(w.toolbar,'Page',{{'Creature rules','rules'},{'Profiles / Import / Export','profiles'},{'Looting','loot'}},'rules',function(value)
    page=value selected=nil
    if value=='rules' then refresh()
    elseif value=='profiles' then T.profiles(left,right,runtime)
    elseif engine.Looting then NexusBot.Features.CaveTools.loot(left,right,runtime)
    else U.clear(left) U.clear(right) U.label(left,'Looting API is not loaded.') end
  end)
  choice:getParent():setWidth(340) choice:getParent().label:setWidth(42)
  local current=U.label(w.toolbar,'') current:setWidth(285) current:setHeight(28)
  local previousProfile=engine.getCurrentProfile()
  refresh()
  ownTimer(w,function()
    state:setOn(engine.isOn())
    state:setTooltip(nil)
    local profile=engine.getCurrentProfile()
    local status='Profile: '..tostring(profile or '-')
    if engine.Danger then status=status..' / danger: '..tostring(engine.Danger()) end
    current:setText(engine.status or status) current:setTooltip(nil)
    if profile~=previousProfile then
      previousProfile=profile selected=nil
      if page=='rules' then refresh()
      elseif page=='profiles' then T.profiles(left,right,runtime)
      elseif engine.Looting then NexusBot.Features.CaveTools.loot(left,right,runtime) end
    end
  end)
  return w
end


M.windows.targetingWindow=targetingWindow
end

do
local C=NexusBot.Features.CaveTools
local U=NexusBot.UI
local function itemText(items) local values={} for _,entry in ipairs(items or {}) do values[#values+1]=tostring(entry.id) end return table.concat(values,', ') end
function C.loot(left,right,runtime)
  U.clear(left) U.clear(right)
  local target=runtime.TargetBot
  if not target or not target.Looting or not target.Looting.save then U.label(left,'TargetBot Looting is not loaded.') return end
  local data={} target.Looting.save(data)
  U.section(left,'LOOTING')
  U.toggle(left,'Loot all (list = ignore)',data.everyItem,function(v) data.everyItem=v end)
  U.numberInput(left,'Max danger',data.maxDanger or 10,0,999,function(v) data.maxDanger=v end)
  U.numberInput(left,'Minimum capacity',data.minCapacity or 100,0,999999,function(v) data.minCapacity=v end)
  U.section(right,'ITEM IDS (COMMA SEPARATED)')
  local note=U.label(right,'Loot list; ignored items when Loot all is ON') note:setTextWrap(true) note:setHeight(32)
  local items=g_ui.createWidget('NexusTextInputMulti',right) items:setHeight(120) items:setText(itemText(data.items))
  U.label(right,'Destination backpack / container IDs')
  local bags=g_ui.createWidget('NexusTextInputMulti',right) bags:setHeight(75) bags:setText(itemText(data.containers))
  local status=U.label(left,'Saving pauses CaveBot and TargetBot.')
  U.button(left,'Save loot settings',function()
    local parsed,err=C.parseItems(items:getText()) if not parsed then status:setText(err) return end
    local containers,bagError=C.parseItems(bags:getText()) if not containers then status:setText(bagError) return end
    if runtime.CaveBot and runtime.CaveBot.setOff then runtime.CaveBot.setOff() end
    target.setOff()
    data.items=parsed data.containers=containers target.Looting.update(data) target.save()
    status:setText('Saved in the active target profile.')
  end,true)
end
end

category.open = function() return NexusBot.Features.Modern.windows.targetingWindow() end

-- Reference-style presentation uses the existing independent TargetBot data, not a second engine.
do
local U=NexusBot.UI
local legacyCreate=U.Targeting.create
function U.Targeting.create()
  local A=NexusBot.Automation local engine=A.TargetBot local T=NexusBot.Features.TargetTools
  local API={}
  function API.getActive() local name=engine.getCurrentProfile() return {id=name,name=name,enabled=engine.isOn()} end
  function API.list()
    local out={} for name in pairs(A.data().targetProfiles) do out[#out+1]={id=name,name=name} end
    table.sort(out,function(a,b) return a.name:lower()<b.name:lower() end) return out
  end
  function API.select(_,name) engine.setCurrentProfile(name) return true end
  local function checkedName(name)
    if not NexusBot.Features.CaveTools.validName(name) then error('Use letters, numbers, _ or -; max 48 characters.') end
    for existing in pairs(A.data().targetProfiles) do if existing:lower()==name:lower() then error('Profile already exists.') end end
    return name
  end
  function API.create(_,name)
    checkedName(name) A.saveProfile('targetbot_configs',name,{targeting={},looting={}})
    engine.setCurrentProfile(name) return API.getActive()
  end
  function API.rename(_,old,name)
    if old==name then return true end checkedName(name)
    local store=A.data().targetProfiles
    A.saveProfile('targetbot_configs',name,store[old]) store[old]=nil
    if engine.getCurrentProfile()==old then engine.setCurrentProfile(name) end NexusBot.Storage.touch() return true
  end
  function API.clone(_,name)
    local base=name:sub(1,36) local copy=base..'_copy' local i=1
    while A.data().targetProfiles[copy] do i=i+1 copy=base..'_copy'..i end
    A.saveProfile('targetbot_configs',copy,A.data().targetProfiles[name]) engine.setCurrentProfile(copy)
  end
  function API.delete(_,name)
    if #API.list()<=1 then return false,'Keep at least one profile.' end
    engine.setOff() A.data().targetProfiles[name]=nil
    if engine.getCurrentProfile()==name then engine.setCurrentProfile(API.list()[1].name) end NexusBot.Storage.touch() return true
  end
  local function save() engine.Creature.resetConfigsCache() engine.save() end
  local definition={id='targeting',title='Targeting',profileAPI=API,columns={'Monster','Priority','Attack','Range'},addText='+ New Monster',
    setEnabled=function(enabled) if enabled then NexusBot.setEnabled(true) engine.setOn() else engine.setOff() end end,
    tabs={{'Action','action'},{'Conditions','conditions'},{'Movement','movement'}},changed=save,
    getRules=function()
      local out={} for _,entry in ipairs(engine.targetList.entries) do out[#out+1]=entry.value end return out
    end,
    newRule=function()
      local entry=engine.Creature.addConfig(NexusBot.merge(T.defaults,{name='*',enabled=false,dontLoot=true,requireShootable=true,requireReachable=true,hpMin=0,hpMax=100}))
      save() return entry.value
    end,
    describe=function(r) return {type='Monster',action=r.name,target=r.keepDistance and 'Keep distance' or r.explicitChase and 'Chase' or 'Stand'} end,
    rowValues=function(r) return {r.name=='*' and 'All creatures' or r.name,tostring(r.priority or 1),r.keepDistance and 'Keep distance' or r.explicitChase and 'Chase' or 'Stand',tostring(r.maxDistance or 10)} end}
  definition.renderInspector=function(c,tab,r,p)
    local function set(key,v) r[key]=v save() c:refreshRules() end
    if tab=='action' then
      U.textInput(p,'Monster name',r.name,function(v) if v~='' and #v<=160 then set('name',v) end end)
      U.button(p,'Monsters ignore list',function() U.editNames('TARGET IGNORE LIST',r.ignoreNames or '',function(v) set('ignoreNames',v:gsub('\n',',')) end) end)
      U.numberInput(p,'Priority',r.priority or 1,0,10,function(v) set('priority',v) end)
      U.combo(p,'Attack option',{{'Stand','stand'},{'Chase','chase'},{'Keep distance','distance'}},r.keepDistance and 'distance' or r.explicitChase and 'chase' or 'stand',function(v)
        r.explicitChase=v=='chase' r.chase=r.explicitChase set('keepDistance',v=='distance') c:renderInspector()
      end)
      U.numberInput(p,'Attacking range',r.maxDistance or 10,1,10,function(v) set('maxDistance',v) end)
      if r.keepDistance then
        U.numberInput(p,'Keep distance range',r.keepDistanceRange or 2,1,5,function(v) set('keepDistanceRange',v) end)
        U.toggle(p,'Anchor',r.anchor==true,function(v) set('anchor',v) c:renderInspector() end)
        if r.anchor then U.numberInput(p,'Anchor range',r.anchorRange or 3,1,10,function(v) set('anchorRange',v) end) end
      end
      U.rangeBar(p,'Monster HP% range',r.hpMin or 0,r.hpMax or 100,function(lo,hi) r.hpMin=lo r.hpMax=hi save() end,'#ba4050')
    elseif tab=='conditions' then
      U.toggle(p,'Target has to be shootable',r.requireShootable~=false,function(v) set('requireShootable',v) end)
      U.toggle(p,'Target has to be reachable',r.requireReachable~=false,function(v) set('requireReachable',v) end)
      U.toggle(p,'Loot monster',not r.dontLoot,function(v) set('dontLoot',not v) end)
      U.numberInput(p,'Danger',r.danger or 1,0,10,function(v) set('danger',v) end)
      U.toggle(p,'Diamond arrow priority',r.diamondArrows==true,function(v) set('diamondArrows',v) end)
      U.toggle(p,'PVP safe for diamond arrows',r.rpSafe==true,function(v) set('rpSafe',v) end)
    else
      for _,group in ipairs(T.groups) do if group.name~='Combat' then
        U.section(p,group.name:upper())
        for _,field in ipairs(group.numbers) do U.numberInput(p,field[2],r[field[1]] or field[5],field[3],field[4],function(v) set(field[1],v) end) end
        for _,field in ipairs(group.flags) do U.toggle(p,field[2],r[field[1]]==true,function(v) set(field[1],v) end) end
      end end
      U.toggle(p,'Face monsters',r.faceMonster==true,function(v) set('faceMonster',v) end)
      U.toggle(p,'Avoid wave attacks',r.avoidAttacks==true,function(v) set('avoidAttacks',v) end)
      U.section(p,'TARGET SELECTION')
      local options=engine.profileOptions or {} engine.profileOptions=options
      U.combo(p,'Health priority',{{'Legacy','legacy'},{'Ignore','ignore'},{'Lowest','lowest'},{'Highest','highest'}},options.healthPriority or 'legacy',function(v) options.healthPriority=v~='legacy' and v or nil save() end)
      U.combo(p,'Distance priority',{{'Legacy','legacy'},{'Ignore','ignore'},{'Nearest','nearest'},{'Farthest','farthest'}},options.distancePriority or 'legacy',function(v) options.distancePriority=v~='legacy' and v or nil save() end)
      U.toggle(p,'Retarget monster',options.retarget~=false,function(v) options.retarget=v save() end)
      local loot={} engine.Looting.save(loot)
      local function saveLoot() engine.Looting.update(loot) save() end
      U.section(p,'LOOTING')
      U.toggle(p,'Loot all (list = ignore)',loot.everyItem==true,function(v) loot.everyItem=v saveLoot() end)
      U.numberInput(p,'Max danger',loot.maxDanger or 10,0,999,function(v) loot.maxDanger=v saveLoot() end)
      U.numberInput(p,'Minimum capacity',loot.minCapacity or 100,0,999999,function(v) loot.minCapacity=v saveLoot() end)
      for _,field in ipairs({{'items','Item IDs'},{'containers','Backpack IDs'}}) do
        local values={} for _,item in ipairs(loot[field[1]] or {}) do values[#values+1]=item.id end
        U.textInput(p,field[2],table.concat(values,','),function(text)
          local parsed=NexusBot.Features.CaveTools.parseItems(text)
          if parsed then loot[field[1]]=parsed saveLoot() end
        end)
      end
    end
  end
  local w,c=U.openReference(definition)
  local function find(r) for _,entry in ipairs(engine.targetList.entries) do if entry.value==r then return entry end end end
  c.move=function(self,r,delta)
    local entry=find(r) if not entry then return end
    engine.targetList:moveChildToIndex(entry,engine.targetList:getChildIndex(entry)+delta) save() self:refreshRules()
  end
  c.remove=function(self,r)
    local entry=find(r) if entry then entry:destroy() end self.selectedRule=nil save() self:refreshRules()
  end
  return w
end
end

-- ==================== LOGIC / RUNTIME ====================

do
local T=NexusBot.Features.TargetTools
local U=NexusBot.UI
function T.pattern(name)
  local parts={}
  for part in name:gmatch('[^,]+') do
    part=part:gsub('^%s+',''):gsub('%s+$',''):lower()
    if part~='' then
      local escaped=part:gsub('.',function(ch)
        if ch=='*' then return '.*' elseif ch=='?' then return '.?' end
        if ('.^$+()[]{}|\\'):find(ch,1,true) then return '\\'..ch end
        return ch
      end)
      parts[#parts+1]='^'..escaped..'$'
    end
  end
  return table.concat(parts,'|')
end
function T.validate(rule)
  if type(rule)~='table' or type(rule.name)~='string' or #rule.name>160 or T.pattern(rule.name)=='' then return false,'Enter a creature name (max 160 characters).' end
  if rule.regex~=nil and (type(rule.regex)~='string' or #rule.regex>4096) then return false,'Invalid saved name pattern.' end
  for _,group in ipairs(T.groups) do
    for _,field in ipairs(group.numbers) do
      local value=rule[field[1]]
      if value~=nil and (type(value)~='number' or value~=value or value<field[3] or value>field[4] or value%1~=0) then return false,field[2]..' must be '..field[3]..' - '..field[4]..'.' end
    end
    for _,field in ipairs(group.flags) do if rule[field[1]]~=nil and type(rule[field[1]])~='boolean' then return false,'Invalid switch: '..field[2] end end
  end
  if (rule.lureMin or 1)>(rule.lureMax or 3) then return false,'Lure minimum must not exceed maximum.' end
  for _,key in ipairs({'hpMin','hpMax'}) do if rule[key]~=nil and (type(rule[key])~='number' or rule[key]~=rule[key] or rule[key]<0 or rule[key]>100) then return false,'Invalid HP range.' end end
  if (rule.hpMin or 0)>(rule.hpMax or 100) then return false,'Invalid HP range.' end
  for _,key in ipairs({'enabled','requireShootable','requireReachable'}) do if rule[key]~=nil and type(rule[key])~='boolean' then return false,'Invalid flag: '..key end end
  if rule.ignoreNames~=nil and (type(rule.ignoreNames)~='string' or #rule.ignoreNames>4096) then return false,'Invalid ignore list.' end
  return true
end
function T.snapshot(engine)
  local data={targeting={},looting={},options=NexusBot.copy(engine.profileOptions or {})}
  for _,entry in ipairs(engine.targetList:getChildren()) do data.targeting[#data.targeting+1]=NexusBot.copy(entry.value) end
  if engine.Looting and engine.Looting.save then engine.Looting.save(data.looting) end
  return data
end
function T.validateProfile(data)
  if type(data)~='table' or type(data.targeting)~='table' or type(data.looting)~='table' then return false,'Expected targeting and looting objects.' end
  if data.options~=nil then
    if type(data.options)~='table' then return false,'Invalid targeting options.' end
    local o=data.options
    if o.healthPriority~=nil and o.healthPriority~='ignore' and o.healthPriority~='lowest' and o.healthPriority~='highest' then return false,'Invalid health priority.' end
    if o.distancePriority~=nil and o.distancePriority~='ignore' and o.distancePriority~='nearest' and o.distancePriority~='farthest' then return false,'Invalid distance priority.' end
    if o.retarget~=nil and type(o.retarget)~='boolean' then return false,'Invalid retarget switch.' end
  end
  if #data.targeting>1000 then return false,'Too many creature rules.' end
  local count=0
  for key in pairs(data.targeting) do
    if type(key)~='number' or key%1~=0 or key<1 or key>#data.targeting then return false,'Expected a consecutive list of creature rules.' end
    count=count+1
  end
  if count~=#data.targeting then return false,'Creature list contains missing entries.' end
  for _,rule in ipairs(data.targeting) do local ok,err=T.validate(rule) if not ok then return false,err end end
  for _,key in ipairs({'maxDanger','minCapacity'}) do
    local value=data.looting[key]
    if value~=nil and (type(value)~='number' or value~=value or value<0 or value>999999) then return false,'Invalid loot limit: '..key end
  end
  if data.looting.everyItem~=nil and type(data.looting.everyItem)~='boolean' then return false,'Invalid loot-all switch.' end
  for _,key in ipairs({'items','containers'}) do
    if data.looting[key]~=nil then
      if type(data.looting[key])~='table' then return false,'Invalid loot list.' end
      for _,item in pairs(data.looting[key]) do if type(item)~='table' or type(item.id)~='number' or item.id%1~=0 or item.id<100 or item.id>65535 then return false,'Invalid loot item ID.' end end
    end
  end
  return true
end
function T.apply(engine,entry,draft,profile)
  if profile~=engine.getCurrentProfile() then return false,'Profile changed. Select the rule again.' end
  if entry and entry:isDestroyed() then return false,'Rule no longer exists.' end
  local ok,err=T.validate(draft) if not ok then return false,err end
  local value=NexusBot.copy(draft)
  if T.chaseSuspended and not value.explicitChase then value.chase=false end
  value.name=value.name:gsub('^%s+',''):gsub('%s+$','')
  if not entry or value.name~=entry.value.name then value.regex=T.pattern(value.name) end
  engine.setOff()
  local before=entry and NexusBot.copy(entry.value)
  local created
  ok,err=pcall(function()
    if entry then entry.value=value entry:setText(value.name) else created=engine.Creature.addConfig(value,false) end
    engine.Creature.resetConfigsCache() engine.save()
  end)
  if not ok then
    if entry then entry.value=before entry:setText(before.name) elseif created and not created:isDestroyed() then created:destroy() end
    engine.Creature.resetConfigsCache()
    return false,'Save failed: '..tostring(err)
  end
  return true
end
end

do
local A=NexusBot.Automation
A.Targeting={seen={},corpses={},nextAttack=0,nextLoot=0,danger=0}
local T=A.Targeting
local N=A.Navigation
T.supported={name=true,regex=true}
for _,group in ipairs(NexusBot.Features.TargetTools.groups) do
  for _,field in ipairs(group.numbers) do T.supported[field[1]]=true end
  for _,field in ipairs(group.flags) do T.supported[field[1]]=true end
end
function T.matches(names,name)
  name=tostring(name):lower()
  for part in tostring(names):lower():gmatch('[^,]+') do
    part=part:gsub('^%s+',''):gsub('%s+$','')
    local pattern='^'..part:gsub('.',function(c)
      if c=='*' then return '.*' elseif c=='?' then return '.' end
      if c:find('[%^%$%(%)%%%.%[%]%+%-%?]') then return '%'..c end
      return c
    end)..'$'
    if name:match(pattern) then return true end
  end
  return false
end
function T.rules(creature)
  local name=creature:getName():lower()
  if T.ruleCache[name] then return T.ruleCache[name] end
  local rules={}
  for _,entry in ipairs(A.TargetBot.targetList.entries) do
    if entry.value.enabled~=false and T.matches(entry.value.name,name) and not T.matches(entry.value.ignoreNames or '',name) then rules[#rules+1]=entry.value end
  end
  if (T.ruleCacheSize or 0)>500 then T.ruleCache={} T.ruleCacheSize=0 end
  T.ruleCacheSize=(T.ruleCacheSize or 0)+1 T.ruleCache[name]=rules return rules
end
function T.reset()
  T.seen={} T.corpses={} T.lootOpened={} T.pendingOpen=nil T.movePending=nil T.current=nil T.danger=0 T.blockCave=false T.anchor=nil
  T.ruleCache={} T.ruleCacheSize=0 T.pathCache={} T.lureState=false T.lureRule=nil T.lastPosition=nil T.caveDelayUntil=0 T.allowCave=false T.nearby={} T.nextReposition=0
end
function T.init()
  local engine={independent=true,targetList=A.newList(),Creature={},Looting={},status='OFF',enabled=false}
  A.TargetBot=engine
  engine.isOn=function() return engine.enabled end
  engine.isOff=function() return not engine.enabled end
  engine.setOff=function()
    local wasEnabled=engine.enabled
    engine.enabled=false engine.status='OFF'
    local current=g_game.getAttackingCreature and g_game.getAttackingCreature()
    if current and T.ownedAttack==A.call(current,'getId') and g_game.cancelAttack then g_game.cancelAttack() end
    T.ownedAttack=nil
    if wasEnabled and g_game.setChaseMode and g_game.getChaseMode()~=(DontChase or 0) then g_game.setChaseMode(DontChase or 0) end
    T.reset() N.reset()
  end
  engine.setOn=function()
    A.legacyConflict('TargetBot')
    if #engine.targetList.entries==0 then engine.status='Add a creature rule first.' return end
    if not NexusBot.enabled then NexusBot.setEnabled(true) end
    if engine.enabled then return end
    T.reset()
    if g_game.setChaseMode then g_game.setChaseMode(DontChase or 0) end
    engine.enabled=true engine.status='Searching' T.nextAttack=0
  end
  engine.Danger=function() return T.danger end
  engine.getCurrentProfile=function() return A.data().activeTarget end
  engine.Creature.resetConfigsCache=function() T.anchor=nil T.ruleCache={} T.pathCache={} T.lureRule=nil end
  engine.Creature.addConfig=function(value)
    local ok,err=NexusBot.Features.TargetTools.validate(value) if not ok then error(err) end
    engine.Creature.resetConfigsCache()
    return engine.targetList:add({value=NexusBot.copy(value),text=value.name})
  end
  engine.Looting.save=function(data) for k,v in pairs(T.loot or {}) do data[k]=NexusBot.copy(v) end end
  engine.Looting.update=function(data)
    T.loot=NexusBot.merge({items={},containers={},maxDanger=10,minCapacity=100,everyItem=false},data)
    T.corpses={} T.lootOpened={} T.pendingOpen=nil
  end
  engine.save=function() return A.saveProfile('targetbot_configs',engine.getCurrentProfile(),NexusBot.Features.TargetTools.snapshot(engine)) end
  engine.setCurrentProfile=function(name)
    local data=A.data().targetProfiles[name] if not data then error('Targeting profile does not exist') end
    local ok,err=NexusBot.Features.TargetTools.validateProfile(data) if not ok then error(err) end
    engine.setOff() engine.targetList:clear()
    engine.profileOptions=NexusBot.copy(data.options or {})
    for _,rule in ipairs(data.targeting) do engine.Creature.addConfig(rule) end
    engine.Looting.update(data.looting) A.data().activeTarget=name NexusBot.Storage.touch()
  end
  engine.setCurrentProfile(A.data().activeTarget)
end
local function contains(items,id) for _,item in ipairs(items or {}) do if item.id==id then return true end end return false end
function T.corpseAt(pos)
  local tile=g_map.getTile(pos)
  for _,item in ipairs(A.call(tile,'getItems',{})) do if A.call(item,'isContainer',false) and A.call(item,'isLyingCorpse',false) then return item end end
end
function T.scan(pos)
  local candidates,visible={},{} local danger=0 local now=NexusBot.now()
  T.nearby=g_map.getSpectators(pos,false) or {}
  local current=g_game.getAttackingCreature()
  for _,creature in ipairs(T.nearby) do
    if A.call(creature,'isMonster',false) and A.call(creature,'getType',0)<3 and A.call(creature,'getHealthPercent',100)>0 then
      local p=creature:getPosition() local id=creature:getId() local rules=T.rules(creature)
      visible[id]=true
      if #rules>0 and p and p.z==pos.z and A.distance(pos,p)<=10 then
        local d=A.distance(pos,p) local pathDistance
        local key=A.key(pos)..'>'..A.key(p)
        local cache=T.pathCache[id]
        if cache and cache.key==key and cache.expires>now then pathDistance=cache.distance else
          local path=N.path(pos,p,1,false)
          pathDistance=path and #path+1
          if N.lastBudgetHit and cache and cache.key==key then pathDistance=cache.distance end
          T.pathCache[id]={key=key,distance=pathDistance,expires=now+250}
        end
        local best
        local unsafe=false
        for _,rule in ipairs(rules) do if not T.pvpSafe(creature,rule) then unsafe=true break end end
        if unsafe and current and current:getId()==id and T.ownedAttack==id then g_game.cancelAttack() T.ownedAttack=nil current=nil end
        if not unsafe then for _,rule in ipairs(rules) do
          local safe=T.pvpSafe(creature,rule)
          local hp=A.call(creature,'getHealthPercent',100)
          local reachable=rule.requireReachable==false or pathDistance~=nil
          local shootable=rule.requireShootable==false or A.call(creature,'canShoot',true)
          if reachable and (pathDistance or d)<=(rule.maxDistance or 10) and safe and shootable and hp>=(rule.hpMin or 0) and hp<=(rule.hpMax or 100) then
            local score=T.priority(creature,rule,pathDistance or d,current)
            if score>0 and (not best or score>best.score) then best={creature=creature,rule=rule,distance=d,pathDistance=pathDistance or d,score=score} end
          elseif current and current:getId()==id and T.ownedAttack==id and rule.rpSafe then
            g_game.cancelAttack() T.ownedAttack=nil current=nil
          end
        end end
        if best then candidates[#candidates+1]=best danger=danger+(best.rule.danger or 1) T.seen[id]={pos=NexusBot.copy(p),expires=now+5000,dontLoot=best.rule.dontLoot} end
      end
    end
  end
  for id in pairs(T.pathCache) do if not visible[id] then T.pathCache[id]=nil end end
  for id,seen in pairs(T.seen) do
    if not visible[id] then
      local corpse=not seen.dontLoot and T.corpseAt(seen.pos)
      if corpse and #T.corpses<20 then
        local duplicate=false for _,queued in ipairs(T.corpses) do if A.key(queued.pos)==A.key(seen.pos) then duplicate=true end end
        if not duplicate then T.corpses[#T.corpses+1]={pos=seen.pos,id=corpse:getId(),expires=now+12000,attempts=0} end
        T.seen[id]=nil
      elseif now>seen.expires then T.seen[id]=nil end
    end
  end
  table.sort(candidates,function(a,b) if a.score==b.score then return a.creature:getId()<b.creature:getId() end return a.score>b.score end)
  T.danger=danger return candidates
end
function T.area(center,kind)
  local count=0
  for _,creature in ipairs(T.nearby) do
    local p=creature:getPosition()
    if p and p.z==center.z then
      local x,y=math.abs(p.x-center.x),math.abs(p.y-center.y)
      if kind=='diamond' and x<=2 and y<=2 and x+y<=3 and A.call(creature,'isMonster',false) then count=count+1 end
      if kind=='players' and x<=3 and y<=3 and x+y<=4 and A.call(creature,'isPlayer',false) and not A.call(creature,'isLocalPlayer',false) and creature~=g_game.getLocalPlayer() then count=count+1 end
    end
  end
  return count
end
function T.pvpSafe(creature,rule)
  return not (rule.rpSafe and rule.diamondArrows) or T.area(creature:getPosition(),'players')==0
end
function T.priority(creature,rule,distance,current)
  local options=A.TargetBot.profileOptions or {}
  if options.healthPriority or options.distancePriority then
    -- Row priority is primary; global choices are tie-breakers, not eligibility overrides.
    local score=(rule.priority or 1)*10000+1
    local hp=A.call(creature,'getHealthPercent',100)
    if options.healthPriority=='lowest' then score=score+(100-hp)*10 elseif options.healthPriority=='highest' then score=score+hp*10 end
    if options.distancePriority=='nearest' then score=score+(100-distance) elseif options.distancePriority=='farthest' then score=score+distance end
    if rule.diamondArrows then score=score+T.area(creature:getPosition(),'diamond')*100 end
    return score
  end
  local score=(rule.priority or 1)+(current and current:getId()==creature:getId() and 1 or 0)
  score=score+(distance==1 and 10 or distance<=3 and 5 or 0)
  if rule.diamondArrows then score=score+T.area(creature:getPosition(),'diamond')*4 end
  local hp=A.call(creature,'getHealthPercent',100)
  if rule.chase and hp<30 then score=score+5
  elseif hp<20 then score=score+2.5 elseif hp<40 then score=score+1.5 elseif hp<60 then score=score+0.5 elseif hp<80 then score=score+0.2 end
  return score
end
function T.freeNeighbours(pos)
  local count=0
  for _,d in ipairs(N.directions) do
    local p={x=pos.x+d[1],y=pos.y+d[2],z=pos.z} local tile=g_map.getTile(p)
    if tile and not N.hazard(tile) and (N.safeTile(p) or A.call(tile,'hasCreatures',false)) then count=count+1 end
  end return count
end
function T.reposition(rule,pos)
  if NexusBot.now()<T.nextReposition then return false end
  local current=T.freeNeighbours(pos)
  if current>(rule.rePositionAmount or 5) then return false end
  local best,bestCount=nil,current
  for _,d in ipairs(N.directions) do
    local p={x=pos.x+d[1],y=pos.y+d[2],z=pos.z}
    if N.safeTile(p) then local count=T.freeNeighbours(p)
      if count>bestCount and N.path(pos,p,0,false) then best,bestCount=p,count end
    end
  end
  if best then N.walk(best,0,false) T.nextReposition=NexusBot.now()+500 return true end
  return false
end
function T.luring(candidate,pos,count)
  local rule=candidate.rule local now=NexusBot.now()
  if T.lureRule~=rule then T.lureRule=rule T.lureState=false T.anchor=nil T.caveDelayUntil=0 end
  if rule.dynamicLure then
    if count>=(rule.lureMax or 3) then T.lureState=false
    elseif count<=(rule.lureMin or 1) then T.lureState=true end
  else T.lureState=false end
  local close=0 for _,creature in ipairs(T.nearby) do if A.call(creature,'isMonster',false) and A.distance(pos,creature:getPosition())<=1 then close=close+1 end end
  local pull=rule.closeLure and close>=(rule.closeLureAmount or 3)
  local killUnder=A.data().killUnder or 30
  local trapped=true for _,d in ipairs(N.directions) do if N.safeTile({x=pos.x+d[1],y=pos.y+d[2],z=pos.z}) then trapped=false break end end
  local healthy=A.call(candidate.creature,'getHealthPercent',100)>=killUnder
  local wants=(rule.lure or rule.lureCavebot or rule.dynamicLure) and healthy and not trapped
  local route=pull or (wants and (T.lureState or (count<(rule.lureCount or 1) and rule.lureCavebot)))
  local moved=T.lastPosition and A.key(T.lastPosition)~=A.key(pos)
  if moved and rule.dynamicLureDelay and count>=(rule.delayFrom or 2) then T.caveDelayUntil=now+(rule.lureDelay or 250) end
  T.lastPosition=NexusBot.copy(pos)
  if route and A.CaveBot and A.CaveBot.isOn() then
    T.anchor=nil T.allowCave=true T.blockCave=false
    A.TargetBot.status=(now<T.caveDelayUntil and 'Lure step delay' or 'Luring using CaveBot')..' / '..count
    return true
  end
  if wants and rule.lure and not rule.lureCavebot and not T.lureState and count<(rule.lureCount or 1) then
    if candidate.pathDistance<=5 then T.moveToBand(candidate,pos,5,6,false) A.TargetBot.status='Classic lure / '..count return true end
  end
  return false
end
function T.moveToBand(candidate,pos,minimum,maximum,anchor)
  if NexusBot.now()<N.nextWalk or A.call(g_game.getLocalPlayer(),'isWalking',false) then return end
  if N.pending and A.key(pos)==N.pending.from and NexusBot.now()<N.pending.untilTime then return end
  local rule,target=candidate.rule,candidate.creature:getPosition()
  local routeBounds
  if A.CaveBot.isOn() then
    for _,entry in ipairs(A.CaveBot.actionList.entries) do
      if entry.action=='goto' or entry.action=='walk' or entry.action=='stairs' then
        local p=A.parsePosition(entry.value)
        if p and p.z==pos.z and A.distance(pos,p)<=18 then
          if not routeBounds then routeBounds={x1=p.x,x2=p.x,y1=p.y,y2=p.y}
          else routeBounds.x1=math.min(routeBounds.x1,p.x) routeBounds.x2=math.max(routeBounds.x2,p.x)
            routeBounds.y1=math.min(routeBounds.y1,p.y) routeBounds.y2=math.max(routeBounds.y2,p.y) end
        end
      end
    end
  end
  local function allowed(p)
    return not routeBounds or (p.x>=routeBounds.x1-1 and p.x<=routeBounds.x2+1 and p.y>=routeBounds.y1-1 and p.y<=routeBounds.y2+1)
  end
  local destinations={}
  for dx=-maximum,maximum do for dy=-maximum,maximum do
    local p={x=target.x+dx,y=target.y+dy,z=pos.z} local d=A.distance(p,target)
    if d>=minimum and d<=maximum and allowed(p) and N.safeTile(p) and (not anchor or A.distance(p,T.anchor)<=(rule.anchorRange or 3)) then
      destinations[#destinations+1]={p=p,score=A.distance(pos,p)*10+math.abs(d-minimum)}
    end
  end end
  table.sort(destinations,function(a,b) if a.score==b.score then return A.key(a.p)<A.key(b.p) end return a.score<b.score end)
  for i=1,math.min(8,#destinations) do local goal=destinations[i].p if N.path(pos,goal,0,false,allowed) then N.walk(goal,0,false,false,allowed) return true end end
  N.nextWalk=NexusBot.now()+400 return false
end
function T.move(candidate,pos)
  local rule,creature=candidate.rule,candidate.creature local target=creature:getPosition()
  if NexusBot.now()<N.nextWalk or A.call(g_game.getLocalPlayer(),'isWalking',false) then return end
  if N.pending and A.key(pos)==N.pending.from and NexusBot.now()<N.pending.untilTime then return end
  local low=A.call(creature,'getHealthPercent',100)<(A.data().killUnder or 30)
  if rule.rePosition and (not rule.chase or candidate.pathDistance==1) and not rule.avoidAttacks and not rule.keepDistance and not low then
    if T.reposition(rule,pos) then return end
  end
  if rule.keepDistance then
    if not T.anchor or A.distance(pos,T.anchor)>(rule.anchorRange or 3) then T.anchor=NexusBot.copy(pos) end
    local distance=rule.keepDistanceRange or 1
    if A.distance(pos,target)~=distance then return T.moveToBand(candidate,pos,distance,distance,rule.anchor) end
  elseif (not NexusBot.Features.TargetTools.chaseSuspended or rule.explicitChase) and rule.chase==true and A.distance(pos,target)>1 then return T.moveToBand(candidate,pos,1,1,false) end
  local dx,dy=target.x-pos.x,target.y-pos.y
  local options={}
  if rule.avoidAttacks then
    if math.abs(dx)==1 and dy==0 then options={{x=pos.x,y=pos.y-1,z=pos.z},{x=pos.x,y=pos.y+1,z=pos.z}}
    elseif dx==0 and math.abs(dy)==1 then options={{x=pos.x-1,y=pos.y,z=pos.z},{x=pos.x+1,y=pos.y,z=pos.z}} end
  elseif rule.faceMonster then
    if math.abs(dx)==1 and math.abs(dy)==1 then options={{x=pos.x+dx,y=pos.y,z=pos.z},{x=pos.x,y=pos.y+dy,z=pos.z}}
    elseif candidate.distance==1 and g_game.turn then
      local direction=dx==1 and 1 or dx==-1 and 3 or dy==1 and 2 or 0
      if A.call(g_game.getLocalPlayer(),'getDirection')~=direction and NexusBot.now()>=(T.nextTurn or 0) then g_game.turn(direction) T.nextTurn=NexusBot.now()+300 end
    end
  end
  for _,p in ipairs(options) do if N.safeTile(p) and N.path(pos,p,0,false) then return N.walk(p,0,false) end end
end
function T.lootTick(pos,nearbyOnly)
  local cfg=T.loot local now=NexusBot.now()
  if not cfg or T.danger>cfg.maxDanger then return false end
  local canMove=(cfg.everyItem or #cfg.items>0) and #cfg.containers>0 and A.call(g_game.getLocalPlayer(),'getFreeCapacity',0)>=cfg.minCapacity
  local bags=g_game.getContainers() or {}
  if T.pendingOpen then
    local pending=T.pendingOpen
    for id,bag in pairs(bags) do
      local item=bag:getContainerItem()
      if not pending.existing[id] and item and item:getId()==pending.id then
        T.lootOpened[id]=true T.pendingOpen=nil break
      end
    end
    if T.pendingOpen and now>pending.untilTime then
      if pending.queued and pending.queued.attempts<3 and now<pending.queued.expires then table.insert(T.corpses,1,pending.queued) end
      T.pendingOpen=nil
    end
    if T.pendingOpen then return true end
  end
  local destination
  for id,bag in pairs(bags) do
    local item=bag:getContainerItem()
    if canMove and not T.lootOpened[id] and item and contains(cfg.containers,item:getId()) and #bag:getItems()<bag:getCapacity() then destination=bag break end
  end
  for id in pairs(T.lootOpened) do
    local bag=bags[id]
    -- Opening a corpse does not require a loot filter or destination bag.
    -- Leave it open for the player when automatic item transfer is unavailable.
    if not bag or not destination then T.lootOpened[id]=nil else
      for _,item in ipairs(bag:getItems()) do
        local listed=contains(cfg.items,item:getId())
        if (cfg.everyItem and not listed) or (not cfg.everyItem and listed) then
          local signature=id..':'..A.key(item:getPosition())..':'..item:getId()..':'..A.call(item,'getCount',1)
          if not T.movePending or T.movePending.signature~=signature then T.movePending={signature=signature,tries=0} end
          if T.movePending.tries>=3 then T.lootOpened[id]=nil return false end
          if now<T.nextLoot then return true end
          g_game.move(item,destination:getSlotPosition(#destination:getItems()),A.call(item,'getCount',1))
          T.movePending.tries=T.movePending.tries+1 T.nextLoot=now+400 return true
        end
      end
      T.lootOpened[id]=nil T.movePending=nil
      if g_game.close then g_game.close(bag) end
      return true
    end
  end
  local index=1
  if nearbyOnly then
    index=nil
    for i,entry in ipairs(T.corpses) do if entry.pos.z==pos.z and A.distance(pos,entry.pos)<=1 then index=i break end end
  end
  local queued=index and T.corpses[index]
  if not queued then return false end
  if now>queued.expires or queued.pos.z~=pos.z or queued.attempts>=3 then table.remove(T.corpses,index) return false end
  if A.distance(pos,queued.pos)>1 then N.walk(queued.pos,1,false) return true end
  local corpse=T.corpseAt(queued.pos)
  if not corpse then table.remove(T.corpses,index) return false end
  if now<T.nextLoot then return true end
  local existing={} for id in pairs(bags) do existing[id]=true end
  local sent=g_game.open(corpse) queued.attempts=queued.attempts+1 T.nextLoot=now+400
  if sent==false then return true end
  T.pendingOpen={id=corpse:getId(),existing=existing,queued=queued,untilTime=now+1200}
  table.remove(T.corpses,index) return true
end
function T.tick()
  local engine=A.TargetBot T.blockCave=false T.allowCave=false
  if not engine.enabled then return end
  local pos=A.position() if not pos then return end
  local player=g_game.getLocalPlayer()
  if PlayerStates and PlayerStates.Pz and A.call(player,'hasState',false,PlayerStates.Pz) then
    T.current=nil T.anchor=nil T.lureState=false T.lureRule=nil T.caveDelayUntil=0
    engine.status='Protection zone'
    local current=g_game.getAttackingCreature()
    if current and T.ownedAttack==current:getId() then g_game.cancelAttack() end
    T.ownedAttack=nil
    return
  end
  A.legacyConflict('TargetBot')
  local candidates=T.scan(pos) local candidate=candidates[1]
  local currentTarget=g_game.getAttackingCreature()
  if engine.profileOptions and engine.profileOptions.retarget==false and currentTarget then
    for _,eligible in ipairs(candidates) do if eligible.creature:getId()==currentTarget:getId() then candidate=eligible break end end
  end
  T.current=candidate and candidate.creature
  if candidate then
    T.blockCave=true engine.status='Attacking '..candidate.creature:getName()
    local current=g_game.getAttackingCreature()
    if (not current or current:getId()~=candidate.creature:getId()) and NexusBot.now()>=T.nextAttack then
      g_game.attack(candidate.creature) T.ownedAttack=candidate.creature:getId() T.nextAttack=NexusBot.now()+350
    end
    if T.lootTick(pos,true) then T.blockCave=true engine.status='Looting / attacking' return end
    local route=A.CaveBot and A.CaveBot.actionList:getFocusedChild()
    if A.CaveBot and A.CaveBot.isOn() and route and route.action=='rushlure' then T.blockCave=false engine.status='Rush lure / attacking' return end
    if not T.luring(candidate,pos,#candidates) then T.move(candidate,pos) end
  elseif T.lootTick(pos) then T.blockCave=true engine.status='Looting'
  else
    engine.status='Searching' T.anchor=nil T.lureState=false T.lureRule=nil T.caveDelayUntil=0
    local current=g_game.getAttackingCreature()
    if current and T.ownedAttack==current:getId() then g_game.cancelAttack() T.ownedAttack=nil end
  end
end
end
