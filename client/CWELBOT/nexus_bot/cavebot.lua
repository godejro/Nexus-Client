-- CAVEBOT: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('cavebot', 'CAVEBOT', 5, false)
category.getEnabled=function() return NexusBot.Automation.CaveBot.isOn() end
category.setEnabled=function(v)
  local engine=NexusBot.Automation.CaveBot
  if v then engine.setOn() else engine.setOff() engine.Recorder.disable() end
end

-- ==================== GUI / LAYOUT ====================
NexusBot.embeddedUI = NexusBot.embeddedUI or {}
NexusBot.embeddedUI['cavebot'] = [=[
NexusWindow
  id: cwelCavebot
  text: CAVEBOT
  size: 940 650
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
    id: route
    anchors.top: toolbar.bottom
    anchors.left: parent.left
    anchors.bottom: footer.top
    margin-top: 8
    margin-bottom: 8
    width: 316
    NexusHeader
      id: heading
      anchors.top: parent.top
      anchors.left: parent.left
      text: WAYPOINTS
    NexusScrollPanel
      id: list
      anchors.top: heading.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: position.top
      margin-top: 6
      margin-bottom: 8
      layout:
        type: verticalBox
        spacing: 2
    NexusMutedLabel
      id: position
      text-align: center
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: controls.top
      height: 24
    Panel
      id: controls
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 108
      layout:
        type: grid
        cell-size: 143 24
        cell-spacing: 4
        num-columns: 2
  NexusPanel
    id: settings
    anchors.top: route.top
    anchors.left: route.right
    anchors.right: parent.right
    anchors.bottom: route.bottom
    margin-left: 8
    Panel
      id: tabs
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 26
      layout:
        type: horizontalBox
        spacing: 3
    Panel
      id: content
      anchors.top: tabs.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-top: 8
  Panel
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 42
    NexusMutedLabel
      id: status
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 20
    NexusMutedLabel
      id: hint
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: 20
]=]
NexusBot.Features.CaveTools={}

do
NexusBot.UI.CaveBot={}
local UI=NexusBot.UI.CaveBot local U=NexusBot.UI
function UI.create()
  local A=NexusBot.Automation local C=A.CaveBot local W=A.Walker local tools=NexusBot.Features.CaveTools
  local w=NexusBot.loadUI('cavebot',rootWidget) local selected,tab=nil,'Actions'
  local contentTarget=w.settings.content
  w.footer:hide() w.footer:setHeight(0)
  local refresh,show,edit local rows={} local buttons={} local draftAction='goto'
  local function info(message)
    w.footer:hide() w.footer:setHeight(0)
  end
  local function protected(fn) return function() local ok,err=pcall(fn) if not ok then displayErrorBox('CaveBot',tostring(err)) end end end
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
  local master=U.toggle(w.toolbar,'CaveBot',C.isOn(),function(on) if on then NexusBot.setEnabled(true) C.setOn() else C.setOff() end end) master.container:setWidth(126)
  master.container:hide() master.container:setWidth(0)
  local options={} for _,name in ipairs(A.runtime.Config.list('cavebot_configs')) do options[#options+1]={name,name} end
  local profiles=U.combo(w.toolbar,'',options,C.getCurrentProfile(),function(name)
    C.setCurrentProfile(name) selected=nil refresh() show(tab)
  end) profiles:getParent():setWidth(160) profiles:getParent().label:setWidth(0)
  U.button(w.toolbar,'Profiles',function() show('Profiles') end):setWidth(80)
  local pos=w.route.position
  local routeScroll=U.scrollbar(w.route.list)
  local function selectedEntry() return type(selected)=='table' and not selected:isDestroyed() and selected or C.actionList:getFocusedChild() end
  local function move(delta)
    local entry=selectedEntry() if not entry then return end
    local index=C.actionList:getChildIndex(entry) C.actionList:moveChildToIndex(entry,math.max(1,math.min(C.actionList:getChildCount(),index+delta))) C.save() refresh()
  end
  local function remove()
    local entry=selectedEntry() if not entry then return end
    local index=C.actionList:getChildIndex(entry)
    local wasCurrent=entry==C.actionList:getFocusedChild()
    entry:destroy()
    selected=C.actionList.entries[math.min(index,#C.actionList.entries)]
    if not C.isOn() or wasCurrent then C.actionList:focusChild(selected) end
    C.save() refresh()
  end
  local function routeTo(label)
    C.setOff() if not W.gotoLabel(label) then info('Add route label: '..label) return end
    NexusBot.setEnabled(true) C.setOn(true) info('Following route from '..label)
  end
  for _,spec in ipairs({
    {'Add',function() edit(nil,'goto') end},{'Edit',function() edit(selectedEntry()) end},
    {'Move up',function() move(-1) end},{'Move down',function() move(1) end},
    {'Remove',remove},{'Clear',function()
      C.setOff() C.Recorder.disable() C.actionList:clear() selected=nil C.save() refresh()
    end}
  }) do U.button(w.route.controls,spec[1],protected(spec[2])) end
  U.button(w.route.controls,'Auto explore',function() NexusBot.Features.AutoExplore.open() end)
  local recorder=U.button(w.route.controls,'Auto record',function()
    if not C.Recorder.isOn() then NexusBot.setEnabled(true) C.Recorder.enable() else C.Recorder.disable() end
  end)
  local function columns()
    local parent=contentTarget
    local left=g_ui.createWidget('Panel',parent) local right=g_ui.createWidget('Panel',parent)
    left:addAnchor(AnchorTop,'parent',AnchorTop) left:addAnchor(AnchorLeft,'parent',AnchorLeft) left:addAnchor(AnchorBottom,'parent',AnchorBottom) left:setWidth(math.max(160,math.floor((parent:getWidth()-10)/2)))
    left:setId('leftColumn')
    right:addAnchor(AnchorTop,'parent',AnchorTop) right:addAnchor(AnchorLeft,'leftColumn',AnchorRight) right:addAnchor(AnchorRight,'parent',AnchorRight) right:addAnchor(AnchorBottom,'parent',AnchorBottom) right:setMarginLeft(10)
    for _,p in ipairs({left,right}) do p:setLayout(UIVerticalLayout.create(p)) p:getLayout():setSpacing(3) end
    return left,right
  end
  local function actionPalette()
    local left,right=columns() local names={}
    for name in pairs(C.Actions) do names[#names+1]=name end
    local order={'label','delay','gotolabel','goto','use','usewith','say','follow','npcsay','function','travel','buysupplies','rushlure','imbuing','supplycheck','poscheck','cleartile','inwithdraw','opendoors','tasker','withdraw','bank','depositor','lure','dpwithdraw','sellall','walk','stairs','rope','shovel','waitz','deposit','buy','sell','stop'}
    local known={} for _,name in ipairs(order) do known[name]=true end
    table.sort(names) for _,name in ipairs(names) do if not known[name] then order[#order+1]=name end end
    local captions={gotolabel='Go to label',usewith='Use with',npcsay='NPC say',buysupplies='Buy supplies',rushlure='Rush lure',supplycheck='Supply check',poscheck='Position check',cleartile='Clear tile',opendoors='Open doors',sellall='Sell all',inwithdraw='Inbox withdraw',dpwithdraw='Depot withdraw'}
    captions['goto']='Node'
    local hidden={rushlure=true,cleartile=true,withdraw=true,walk=true,waitz=true,buy=true,stop=true,lure=true,stairs=true,depositor=true}
    local visible=0
    for _,name in ipairs(order) do if C.Actions[name] and not hidden[name] then
      visible=visible+1
      local button=U.button(visible%2==1 and left or right,captions[name] or name:gsub('^%l',string.upper),function() edit(nil,name) end)
      button:setHeight(22) U.actionColor(button,A.CaveExtensions.colors[name] or '#c9d9ed') button:setTooltip(nil)
    end end
    info('Choose an action. Double-click a waypoint to edit. No vBot required.')
  end
  edit=function(entry,action)
    local insertionAnchor=selectedEntry()
    if entry then selected=entry end
    draftAction=entry and entry.action or action or 'goto'
    NexusBot.WindowManager.close('cavebot:edit')
    local meta=C.Editor.Actions[draftAction]
    local dialog,list=NexusBot.Features.Modern.shared.formWindow(draftAction=='goto' and 'NODE' or draftAction:upper(),260)
    dialog:setWidth(380)
    local value=entry and entry.value or meta.value or ''
    local coordinates=(draftAction=='goto' or draftAction=='walk' or draftAction=='stairs' or draftAction=='use' or draftAction=='rope' or draftAction=='shovel')
    local input
    if coordinates then
      local p=(entry and A.parsePosition(value)) or A.position() or {x=100,y=100,z=7}
      input=U.textInput(list,'Position:',entry and value or A.key(p),function() end)
      input:getParent().label:setWidth(70)
    elseif draftAction=='function' then
      dialog:setHeight(340)
      input=g_ui.createWidget('NexusTextInputMulti',list) input:setHeight(190) input:setText(value)
    else
      if not entry and draftAction=='poscheck' then value=A.key(A.position())..',hunt' end
      if not entry and draftAction=='usewith' then value=C.Config.values.ropeId..','..A.key(A.position()) end
      local caption=draftAction=='label' and 'Label' or draftAction=='follow' and 'Name' or draftAction=='supplycheck' and 'Label' or 'Value'
      input=U.textInput(list,caption,value,function() end)
      input:getParent().label:setWidth(55)
    end
    U.button(list,entry and 'Save' or 'Add',protected(function()
      if entry and entry:isDestroyed() then return end
      local text=input:getText()
      local valid,err=W.validate(draftAction,text) if not valid then displayErrorBox('CaveBot',tostring(err)) return end
      if entry then C.editAction(entry,draftAction,text) else
        local current=insertionAnchor
        local index=current and not current:isDestroyed() and C.actionList:getChildIndex(current)
        entry=C.addAction(draftAction,text) if index then C.actionList:moveChildToIndex(entry,index+1) end
      end
      C.save() selected=entry refresh() dialog:destroy()
    end),true)
    NexusBot.WindowManager.attach('cavebot:edit',dialog)
    return dialog
  end
  show=function(name)
    if name=='Actions' then
      tab=name contentTarget=w.settings.content U.clear(contentTarget) actionPalette() return
    end
    if name=='Edit' then return edit(selectedEntry()) end
    NexusBot.WindowManager.close('cavebot:'..name)
    local dialog=NexusBot.loadUI('integration',rootWidget)
    dialog:setText(name:upper()) dialog:setSize({width=620,height=480})
    dialog.content.heading:hide() dialog.content.status:hide() dialog.content.list:hide()
    dialog.closeButton.onClick=function() dialog:destroy() return true end dialog.onEscape=dialog.closeButton.onClick
    contentTarget=dialog.content
    local left,right=columns()
    contentTarget=w.settings.content
    NexusBot.WindowManager.attach('cavebot:'..name,dialog)
    if name=='Profiles' then tools.profiles(left,right,A.runtime)
    elseif name=='Loot' then tools.loot(left,right,A.runtime)
    elseif name=='Supplies' then NexusBot.Features.Modern.suppliesEditor(left,right)
    elseif name=='Stash' then
      A.data().stashing=A.data().stashing or {}
      U.section(left,'STASH DESTINATIONS')
      local id=U.numberInput(left,'Item ID',3031,100,65535,function() end) id:getParent().label:setWidth(130)
      local dest=U.numberInput(left,'Container ID',2854,100,65535,function() end) dest:getParent().label:setWidth(130)
      U.button(left,'Add / update destination',function()
        C.setOff() local found=false
        for _,entry in ipairs(A.data().stashing) do if entry.id==id:getValue() then entry.container=dest:getValue() found=true end end
        if not found then table.insert(A.data().stashing,{id=id:getValue(),container=dest:getValue()}) end NexusBot.Storage.touch() show('Stash')
      end)
      local stashList=U.compactList(left,275)
      for index,entry in ipairs(A.data().stashing) do local b=U.button(stashList,entry.id..' -> '..entry.container,function() id:setValue(entry.id) dest:setValue(entry.container) end)
        b:setHeight(24) b:setTooltip(nil) b.onMouseRelease=function(_,p,mouse) if mouse==MouseRightButton then C.setOff() table.remove(A.data().stashing,index) NexusBot.Storage.touch() show('Stash') return true end return false end
      end
      U.section(right,'SELL EXCEPTIONS') local values={} for _,v in ipairs(A.data().sellExceptions or {}) do values[#values+1]=v end
      local input=g_ui.createWidget('NexusTextInputMulti',right) input:setHeight(125) input:setText(table.concat(values,','))
      U.button(right,'Save exceptions',function() local parsed,err=tools.parseItems(input:getText()) if not parsed then info(err) return end
        C.setOff() A.data().sellExceptions={} for _,v in ipairs(parsed) do table.insert(A.data().sellExceptions,v.id) end NexusBot.Storage.touch() info('Exceptions saved.')
      end)
      local note=U.label(right,'Depositor uses OPEN destination containers. Supplies are also protected from Sell all.') note:setTextWrap(true) note:setHeight(90)
    else
      U.section(left,'WALKING / RETRIES') U.section(right,'TOOLS / EXECUTION')
      for i,field in ipairs({{'stepDelay','Walk delay',0,2000},{'actionTimeout','Timeout (ms)',1000,120000},{'useDelay','Use delay',300,10000},{'maxUseRetries','Use retries',1,10},{'recordDistance','Record distance',1,8},{'ropeId','Rope ID',100,65535},{'shovelId','Shovel ID',100,65535},{'talkDelay','NPC delay',300,5000}}) do
        local key=field[1]
        local input=U.numberInput(i<=4 and left or right,field[2],C.Config.values[key],field[3],field[4],function(value)
          C.Config.values[key]=value C.save()
        end)
        input:getParent().label:setWidth(135) input:getParent():setHeight(29)
      end
      U.toggle(right,'Auto navigate',C.Config.values.autoNavigate==true,function(v) C.Config.values.autoNavigate=v C.save() end)
      U.toggle(left,'Debug Cave',C.Config.values.debugCave==true,function(v) C.Config.values.debugCave=v C.save() A.Walker.drawDebug() end)
      U.toggle(left,'Show shortest path',C.Config.values.debugPath==true,function(v) C.Config.values.debugPath=v C.save() A.Walker.drawDebug() end)
    end
  end
  U.section(w.settings.tabs,'ACTIONS')
  for _,name in ipairs({'Config','Supplies'}) do
    local b=U.button(w.toolbar,name,function() show(name) end) b:setWidth(name=='Supplies' and 76 or 58) b:setHeight(25)
  end
  refresh=function()
    local scroll=routeScroll:getValue()
    U.clear(w.route.list) rows={}
    for i,entry in ipairs(C.actionList:getChildren()) do
      local button=U.button(w.route.list,string.format('%02d  %s: %s',i,entry.action=='goto' and 'Node' or entry.action,entry.value:gsub('\n.*','')),function() selected=entry for _,r in ipairs(rows) do r.widget:setOn(r.entry==entry) end end)
      button:setHeight(24) button:setTextAlign(AlignLeft or 1) U.actionColor(button,A.CaveExtensions.colors[entry.action] or '#c9d9ed') button:setTooltip(nil)
      local actionColor=A.CaveExtensions.colors[entry.action] or '#c9d9ed'
      button:setOn(entry==(C.isOn() and C.actionList:getFocusedChild() or selected or C.actionList:getFocusedChild()))
      button.onDoubleClick=function() edit(entry) return true end
      rows[#rows+1]={widget=button,entry=entry}
    end
    w.route.list:updateScrollBars()
    routeScroll:setValue(math.min(scroll,routeScroll:getMaximum()))
  end
  refresh() show('Actions')
  local previousProfile=C.getCurrentProfile()
  local timer=NexusBot.Scheduler.every(250,function()
    if w:isDestroyed() or not w:isVisible() then return end
    master:setOn(C.isOn())
    U.actionColor(recorder,C.Recorder.isOn() and '#72e5c4' or '#fa6275')
    pos:setText('Position: '..A.key(A.position()))
    w.footer.status:setText((C.status or 'OFF')..'  |  Route: '..C.getCurrentProfile()) w.footer.status:setTooltip(nil)
    if #rows~=C.actionList:getChildCount() or previousProfile~=C.getCurrentProfile() then
      local added=C.actionList:getChildCount()>#rows and C.Recorder.isOn()
      if previousProfile~=C.getCurrentProfile() then
        previousProfile=C.getCurrentProfile()
        local changed=profiles.onOptionChange profiles.onOptionChange=nil
        profiles:clearOptions()
        for _,name in ipairs(A.runtime.Config.list('cavebot_configs')) do profiles:addOption(name,name) end
        profiles:setCurrentOption(previousProfile,true) profiles.onOptionChange=changed
      end
      refresh()
      if added then
        w.route.list:updateScrollBars()
        routeScroll:setValue(routeScroll:getMaximum())
      end
    end
    if selected and selected:isDestroyed() then selected=nil end
    local current=C.isOn() and C.actionList:getFocusedChild() or selected or C.actionList:getFocusedChild()
    for _,row in ipairs(rows) do row.widget:setOn(row.entry==current) end
    if C.isOn() and current~=w.lastRunningWaypoint then
      w.lastRunningWaypoint=current
      for _,row in ipairs(rows) do if row.entry==current then w.route.list:ensureChildVisible(row.widget) break end end
    end
  end,'CaveBot UI')
  w.onDestroy=function() NexusBot.Scheduler.cancel(timer) end
  w.controller={show=show,edit=edit,refresh=refresh}
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

local function saveSupplies()
  if R.SuppliesWindow and R.SuppliesWindow.onVisibilityChange then R.SuppliesWindow.onVisibilityChange(R.SuppliesWindow,false) end
end
local function suppliesEditor(left,right)
  U.clear(left) U.clear(right)
  if NexusBot.Automation and NexusBot.Automation.runtime then
    local A=NexusBot.Automation local cfg=A.data().supplies
    U.section(left,'SUPPLIES')
    U.numberInput(left,'Capacity',cfg.minCapacity,0,999999,function(v) cfg.minCapacity=v NexusBot.Storage.touch() end)
    local function edit(id,data)
      U.clear(right)
      local draft={id=tonumber(id) or 0,min=data and data.min or 0,max=data and data.max or 100}
      U.numberInput(right,'Item ID',draft.id,100,65535,function(v) draft.id=v end)
      U.numberInput(right,'Min',draft.min,0,65535,function(v) draft.min=v end)
      U.numberInput(right,'Max',draft.max,0,65535,function(v) draft.max=v end)
      U.button(right,'Save supply',function()
        if draft.id<100 or draft.min>draft.max then displayErrorBox('Supplies','Set an item ID and Min <= Max.') return end
        if id then cfg.items[tostring(id)]=nil end
        cfg.items[tostring(draft.id)]={min=draft.min,max=draft.max} NexusBot.Storage.touch() suppliesEditor(left,right)
      end)
      if id then U.button(right,'Remove',function() cfg.items[tostring(id)]=nil NexusBot.Storage.touch() suppliesEditor(left,right) end) end
    end
    U.button(left,'+ Supply item',function() edit() end)
    local itemList=U.compactList(left,320)
    for _,id in ipairs(sortedKeys(cfg.items)) do
      local item=cfg.items[id]
      local row=U.button(itemList,'Min '..item.min..'   Max '..item.max,function() edit(id,item) end)
      row:setHeight(34) row:setTextOffset({x=18,y=0})
      local icon=g_ui.createWidget('UIItem',row)
      icon:setVirtual(true) icon:setPhantom(true) icon:setItemId(tonumber(id))
      icon:setSize({width=30,height=30}) icon:addAnchor(AnchorLeft,'parent',AnchorLeft)
      icon:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
    end
    return
  end
  if not R.Supplies or not R.Supplies.getItemsData or not R.SuppliesWindow then U.label(left,'Supplies engine is not loaded.') return end
  U.section(left,'SUPPLY ITEMS')
  local function edit(id,data)
    U.clear(right) U.section(right,'SUPPLY LIMITS')
    local draft={id=tonumber(id) or 0,min=data and data.min or 0,max=data and data.max or 0,avg=data and data.avg or 0}
    U.numberInput(right,'Item ID',draft.id,1,65535,function(v) draft.id=v end)
    for _,key in ipairs({'min','max','avg'}) do U.numberInput(right,title(key),draft[key],0,999999,function(v) draft[key]=v end) end
    local status=U.label(right,'')
    U.button(right,'Save supply',function()
      if draft.id<=0 or draft.min>draft.max then status:setText('Set a valid item ID and Min <= Max.') return end
      local existing=R.SuppliesWindow.items:getChildById(tostring(draft.id))
      if existing then existing.min:setText(draft.min) existing.max:setText(draft.max) existing.avg:setText(draft.avg)
      else R.Supplies.addSupplyItem(draft.id,draft.min,draft.max,draft.avg) end
      saveSupplies() suppliesEditor(left,right)
    end,true)
    if id then U.button(right,'Remove supply',function()
      local existing=R.SuppliesWindow.items:getChildById(tostring(id)) if existing then existing:destroy() end
      saveSupplies() suppliesEditor(left,right)
    end) end
  end
  U.button(left,'+ Supply item',function() edit() end,true)
  for _,id in ipairs(sortedKeys(R.Supplies.getItemsData())) do
    local data=R.Supplies.getItemsData()[id]
    U.button(left,'Item '..id..'   '..data.min..' / '..data.max,function() edit(id,data) end)
  end
  local extra=R.Supplies.getAdditionalData and R.Supplies.getAdditionalData()
  if extra then
    U.section(right,'SUPPLY CHECKS')
    local profiles=R.SuppliesConfig and R.SuppliesConfig.supplies
    local active=profiles and profiles[profiles.currentProfile]
    if active then fields(right,active,function() if R.vBotConfigSave then R.vBotConfigSave('supply') end end,{items=true})
    else for _,key in ipairs(sortedKeys(extra)) do
      local value=extra[key] U.label(right,title(key)..': '..(value.enabled and 'ON' or 'OFF')..(value.value and (' / '..value.value) or ''))
    end end
  end
end

M.suppliesEditor=suppliesEditor
local function caveWindow()
  if NexusBot.UI.CaveBot then return NexusBot.UI.CaveBot.create() end
  local w,left,right=engineWindow('CAVEBOT')
  if not R.CaveBot or not R.CaveBot.actionList then
    U.label(left,'Independent CaveBot initialization failed. Check the log.')
    return w
  end
  local runtime=NexusBot.Automation.runtime
  local state=managedToggle(w.toolbar,'CaveBot',R.CaveBot,'cavebot')
  state.container:setWidth(165)
  local currentPage='waypoints'
  local selected
  local rows={}
  local function save() R.CaveBot.save() end
  local function stop() R.CaveBot.setOff() end
  local renderWaypoints
  local function edit(entry,actionName)
    selected=entry U.clear(right)
    local draft={action=entry and entry.action or actionName or 'goto',value=entry and entry.value or ''}
    local options={} for _,name in ipairs(sortedKeys(R.CaveBot.Actions)) do options[#options+1]={name,name} end
    U.section(right,entry and 'EDIT WAYPOINT / FUNCTION' or 'NEW WAYPOINT / FUNCTION')
    local input,description
    local function applyTemplate()
      local metadata=R.CaveBot.Editor and R.CaveBot.Editor.Actions[draft.action]
      description:setText(type(metadata)=='table' and (metadata.description or metadata.title or draft.action) or draft.action)
      if type(metadata)=='table' and metadata.value then
        local value=type(metadata.value)=='function' and safe(metadata.value,'') or metadata.value
        input:setText(tostring(value or ''))
      else input:setText('') end
    end
    U.combo(right,'Action',options,draft.action,function(v) draft.action=v applyTemplate() end)
    description=U.label(right,'') description:setHeight(40) description:setTextWrap(true)
    U.label(right,'Value / Lua function body')
    input=g_ui.createWidget('NexusTextInputMulti',right) input:setHeight(150)
    applyTemplate() if entry then input:setText(draft.value) end
    U.button(right,'Use current position',function()
      local p=g_game.getLocalPlayer() and g_game.getLocalPlayer():getPosition()
      if p then input:setText(p.x..','..p.y..','..p.z) end
    end)
    local status=U.label(right,'Saving pauses CaveBot. Start it when ready.')
    U.button(right,'Save waypoint',function()
      local value=input:getText()
      if R.CaveBot.independent then
        local valid,err=NexusBot.Automation.Walker.validate(draft.action,value)
        if not valid then status:setText(err) return end
      end
      if draft.action=='function' and runtime.load then
        local valid,err=pcall(runtime.load,'return function()\n'..value..'\nend')
        if not valid then status:setText('Lua syntax error. See tooltip.') status:setTooltip(nil) return end
      end
      local definition=R.CaveBot.Editor and R.CaveBot.Editor.Actions[draft.action]
      if type(definition)=='table' and definition.validation and regexMatch then
        local valid=safe(function() return #regexMatch(value,definition.validation)>0 end,false)
        if not valid then status:setText('Value does not match this action format.') return end
      end
      if entry and not isAlive(entry) then status:setText('Entry changed. Reload the waypoint list.') return end
      stop()
      if entry then R.CaveBot.editAction(entry,draft.action,value) else
        local focused=R.CaveBot.actionList:getFocusedChild()
        local index=focused and R.CaveBot.actionList:getChildIndex(focused)
        local created=R.CaveBot.addAction(draft.action,value)
        if created and index then R.CaveBot.actionList:moveChildToIndex(created,index+1) end
      end
      save() renderWaypoints()
    end,true)
  end
  renderWaypoints=function()
    currentPage='waypoints' U.clear(left) U.clear(right) rows={}
    U.button(left,'+ Waypoint / Function',function() edit() end,true)
    U.button(left,'Refresh list',renderWaypoints)
    for index,entry in ipairs(R.CaveBot.actionList:getChildren()) do
      local row=U.button(left,index..'  '..entry.action..'  '..entry.value:gsub('\n.*',''),function() edit(entry) end)
      row:setTooltip(nil)
      row.onMouseRelease=function(_,pos,button)
        if button~=MouseRightButton then return false end
        local menu=g_ui.createWidget('NexusContextMenu')
        menu:addOption('Set current waypoint',function() stop() R.CaveBot.actionList:focusChild(entry) end)
        for _,delta in ipairs({-1,1}) do menu:addOption(delta<0 and 'Move up' or 'Move down',function()
          if not isAlive(entry) then return end
          stop() local idx=R.CaveBot.actionList:getChildIndex(entry)
          R.CaveBot.actionList:moveChildToIndex(entry,math.max(1,math.min(R.CaveBot.actionList:getChildCount(),idx+delta))) save() renderWaypoints()
        end) end
        menu:addOption('Delete',function() if isAlive(entry) then stop() entry:destroy() save() renderWaypoints() end end)
        menu:display(pos) return true
      end
      rows[#rows+1]={widget=row,entry=entry}
    end
    U.label(right,'Click a waypoint to edit. Right-click to reorder.')
    if R.CaveBot.getCurrentProfile then U.label(right,'Profile: '..tostring(R.CaveBot.getCurrentProfile())) end
  end
  local function configPage()
    currentPage='config' U.clear(left) U.clear(right) rows={}
    U.section(left,'WALKING / EXECUTION')
    if R.CaveBot.independent then
      local cfg=R.CaveBot.Config.values
      for _,field in ipairs({{'stepDelay','Step delay (ms)',0,2000},{'actionTimeout','Waypoint timeout (ms)',1000,120000},{'useDelay','Use retry (ms)',300,10000},{'maxUseRetries','Use retry limit',1,10},{'recordDistance','Record every tiles',1,8},{'ropeId','Rope ID',100,65535},{'shovelId','Shovel ID',100,65535}}) do
        U.numberInput(left,field[2],cfg[field[1]],field[3],field[4],function(v) stop() cfg[field[1]]=v save() end)
      end
      U.toggle(left,'Allow reviewed Lua',cfg.allowLua,function(v) stop() cfg.allowLua=v save() end)
    elseif R.CaveBot.Config then fields(left,R.CaveBot.Config.values,function(key,value)
      local setter=R.CaveBot.Config.value_setters[key] if setter then setter(value) end save()
    end) end
    U.section(right,'PROFILE')
    local name=R.CaveBot.getCurrentProfile and R.CaveBot.getCurrentProfile() or ''
    local input=U.textInput(right,'Profile name',name,function() end)
    local status=U.label(right,'Load an existing CaveBot profile by name.')
    U.button(right,'Load profile',function()
      if not R.CaveBot.setCurrentProfile then status:setText('Profile API unavailable.') return end
      stop() R.CaveBot.setCurrentProfile(input:getText()) stop()
      status:setText('Current: '..tostring(R.CaveBot.getCurrentProfile()))
    end)
    if R.CaveBot.Recorder and R.CaveBot.Recorder.isOn then
      U.toggle(right,'Record waypoints',R.CaveBot.Recorder.isOn(),function(v)
        if v then stop() NexusBot.setEnabled(true) R.CaveBot.Recorder.enable() M.managed.recorder={independent=R.CaveBot.independent,setOff=R.CaveBot.Recorder.disable} else R.CaveBot.Recorder.disable() end
      end)
    end
  end
  local tools=NexusBot.Features.CaveTools
  local page=U.combo(w.toolbar,'Page',{{'Waypoints','waypoints'},{'All actions / Functions','actions'},{'Profiles / Import / Export','profiles'},{'Supply settings','supplies'},{'Looting','loot'},{'Depot / Sell exceptions','depot'},{'Walking / Recorder','config'}},'waypoints',function(value)
    currentPage=value rows={}
    if value=='waypoints' then renderWaypoints()
    elseif value=='actions' then tools.actions(left,right,runtime,edit)
    elseif value=='profiles' then tools.profiles(left,right,runtime)
    elseif value=='supplies' then suppliesEditor(left,right)
    elseif value=='loot' then tools.loot(left,right,runtime)
    elseif value=='depot' then tools.depot(left,right,runtime)
    else configPage() end
  end)
  page:getParent():setWidth(350) page:getParent().label:setWidth(45)
  local b=U.button(w.toolbar,'Save route',function() stop() save() end) b:setWidth(90)
  b=U.button(w.toolbar,'First waypoint',function() stop() R.CaveBot.actionList:focusChild(R.CaveBot.actionList:getFirstChild()) end) b:setWidth(115)
  renderWaypoints()
  local status=U.label(right,R.CaveBot.status or 'OFF')
  ownTimer(w,function()
    state:setOn(R.CaveBot.isOn())
    state:setTooltip(nil)
    if status and not status:isDestroyed() then status:setText(R.CaveBot.status or 'OFF') end
    if currentPage=='waypoints' and #rows~=R.CaveBot.actionList:getChildCount() then renderWaypoints() end
    if currentPage=='waypoints' then
      local current=R.CaveBot.actionList:getFocusedChild()
      for _,row in ipairs(rows) do row.widget:setOn(row.entry==current) end
    end
  end)
  return w
end


M.windows.caveWindow=caveWindow
end

do
local C=NexusBot.Features.CaveTools
local U=NexusBot.UI
local function itemText(items) local values={} for _,entry in ipairs(items or {}) do values[#values+1]=tostring(entry.id) end return table.concat(values,', ') end
function C.profiles(left,right,runtime)
  U.clear(left) U.clear(right)
  local engine,config=runtime.CaveBot,runtime.Config
  if not config or not config.list or not config.save then U.label(left,'This engine has no profile API.') return end
  U.section(left,'SAVED ROUTES')
  local status=U.label(right,'New names: letters, numbers, _ or -')
  if engine.independent then U.button(left,'Import active legacy route',function()
    local ok,message=NexusBot.Automation.importLegacy('cavebot_configs',NexusBot.Features.Modern.getRuntime())
    if ok then C.profiles(left,right,runtime) else status:setText('Import stopped. See tooltip.') status:setTooltip(nil) end
  end) end
  local function protected(callback)
    return function()
      local ok,err=pcall(callback)
      if not ok then
        pcall(engine.setOff)
        if not status:isDestroyed() then status:setText('Operation failed. See tooltip.') status:setTooltip(nil) end
        NexusBot.Logger.warn('CaveBot config',tostring(err))
      end
    end
  end
  local name=U.textInput(right,'New name','',function() end)
  local function exists(n) for _,v in ipairs(config.list('cavebot_configs') or {}) do if v:lower()==n:lower() then return true end end end
  local function write(data)
    local n=name:getText()
    if not C.validName(n) then status:setText('Invalid profile name.') return false end
    if exists(n) then status:setText('Name exists. Choose a new name.') return false end
    local valid,err=C.validateRoute(data,engine)
    if not valid then status:setText(err) return false end
    engine.setOff()
    if engine.Recorder and engine.Recorder.isOn() then engine.Recorder.disable() end
    if config.save('cavebot_configs',n,data,'cfg') then engine.setCurrentProfile(n) engine.setOff() C.profiles(left,right,runtime) return true end
    status:setText('Could not save profile.') return false
  end
  local profileList=engine.independent and U.compactList(left,320) or left
  for _,profile in ipairs(config.list('cavebot_configs') or {}) do
    local button=U.button(profileList,profile,protected(function()
      engine.setOff() if engine.Recorder and engine.Recorder.isOn() then engine.Recorder.disable() end
      engine.setCurrentProfile(profile) engine.setOff() C.profiles(left,right,runtime)
    end))
    button:setOn(engine.getCurrentProfile()==profile)
  end
  U.button(right,'Create empty route',protected(function() write({}) end))
  U.button(right,'Save current route as new profile',protected(function() write(C.snapshot(engine)) end))
  U.section(right,'IMPORT / EXPORT JSON')
  local text=g_ui.createWidget('NexusTextInputMulti',right) text:setHeight(170)
  U.button(right,'Export to text box',protected(function() text:setText(json.encode(C.snapshot(engine),2)) end))
  local note=U.label(right,'Import creates a stopped route. Review Lua first.') note:setTextWrap(true) note:setHeight(34)
  U.button(right,'Import as new profile',protected(function()
    local ok,data=pcall(json.decode,text:getText())
    if not ok then status:setText('Invalid JSON.') return end
    write(data)
  end))
end
function C.actions(left,right,runtime,edit)
  U.clear(left) U.clear(right)
  U.section(left,'ALL REGISTERED ACTIONS')
  local search=U.textInput(left,'Search','',function() end)
  local list=g_ui.createWidget('NexusConditionGroup',left)
  local function refresh()
    U.clear(list)
    local names={} for name in pairs(runtime.CaveBot.Actions or {}) do names[#names+1]=name end table.sort(names)
    for _,name in ipairs(names) do if name:lower():find(search:getText():lower(),1,true) then
      U.button(list,name,function() edit(nil,name) end)
    end end
  end
  search.onTextChange=refresh refresh()
  U.label(right,runtime.independent and 'Native CWELBOT actions. No vBot required.' or 'Includes loaded extensions, not just basic movement.')
  U.label(right,'Select an action for its format, defaults and editor.')
end
function C.depot(left,right,runtime)
  U.clear(left) U.clear(right)
  if runtime.independent then
    U.section(left,'DEPOSIT / NPC SELL')
    U.label(left,'Use deposit: itemId,containerId')
    U.label(left,'Destination container must already be open.')
    U.label(left,'Use sell: itemId,amountToKeep')
    U.label(left,'NPC trade must already be open.')
    local ids={} for _,id in ipairs(NexusBot.Automation.data().sellExceptions or {}) do ids[#ids+1]={id=id} end
    U.label(right,'Never sell these item IDs')
    local input=g_ui.createWidget('NexusTextInputMulti',right) input:setHeight(120) input:setText(itemText(ids))
    local status=U.label(right,'No automatic depot discovery or bank transactions.')
    U.button(right,'Save sell exceptions',function()
      local parsed,err=C.parseItems(input:getText()) if not parsed then status:setText(err) return end
      runtime.CaveBot.setOff() local values={} for _,item in ipairs(parsed) do values[#values+1]=item.id end
      NexusBot.Automation.data().sellExceptions=values NexusBot.Storage.touch() status:setText('Saved.')
    end)
    return
  end
  local storage=runtime.storage
  if not storage then U.label(left,'Bot storage unavailable.') return end
  storage.specialDeposit=storage.specialDeposit or {items={}}
  storage.specialDeposit.items=storage.specialDeposit.items or {}
  U.section(left,'STASH DESTINATIONS')
  local function edit(entry)
    U.clear(right)
    local id=U.numberInput(right,'Item ID',entry and entry.id or 0,0,65535,function() end)
    local depot=U.numberInput(right,'Depot (3-17)',entry and entry.index or 3,3,17,function() end)
    local status=U.label(right,'Used by the existing depositor extension.')
    U.button(right,'Save destination',function()
      if id:getValue()<100 then status:setText('Set a valid item ID.') return end
      for _,other in ipairs(storage.specialDeposit.items) do if other~=entry and other.id==id:getValue() then status:setText('This item already has a destination.') return end end
      runtime.CaveBot.setOff()
      local value=entry or {} value.id=id:getValue() value.index=depot:getValue()
      if not entry then storage.specialDeposit.items[#storage.specialDeposit.items+1]=value end
      if runtime.saveConfig then runtime.saveConfig() end C.depot(left,right,runtime)
    end)
  end
  U.button(left,'+ Stash destination',function() edit() end)
  for index,entry in ipairs(storage.specialDeposit.items) do
    local b=U.button(left,'Item '..entry.id..' -> depot '..entry.index,function() edit(entry) end)
    b.onMouseRelease=function(_,pos,button)
      if button~=MouseRightButton then return false end
      local menu=g_ui.createWidget('NexusContextMenu') menu:addOption('Remove',function()
        runtime.CaveBot.setOff() table.remove(storage.specialDeposit.items,index) if runtime.saveConfig then runtime.saveConfig() end C.depot(left,right,runtime)
      end) menu:display(pos) return true
    end
  end
  U.section(right,'SELL EXCEPTIONS')
  local ids={} for _,id in ipairs(storage.cavebotSell or {}) do ids[#ids+1]={id=id} end
  local input=g_ui.createWidget('NexusTextInputMulti',right) input:setHeight(120) input:setText(itemText(ids))
  local status=U.label(right,'Items that Sell All must keep.')
  U.button(right,'Save exceptions',function()
    local parsed,err=C.parseItems(input:getText()) if not parsed then status:setText(err) return end
    runtime.CaveBot.setOff() storage.cavebotSell={} for _,entry in ipairs(parsed) do storage.cavebotSell[#storage.cavebotSell+1]=entry.id end
    if runtime.saveConfig then runtime.saveConfig() end status:setText('Saved.')
  end)
end
end

category.open = function() return NexusBot.Features.Modern.windows.caveWindow() end

-- ==================== LOGIC / RUNTIME ====================

do
local C=NexusBot.Features.CaveTools
local U=NexusBot.UI
function C.validName(name) return type(name)=='string' and #name>0 and #name<=48 and name:match('^[%w_%-]+$')~=nil end
function C.validateRoute(data,engine)
  if type(data)~='table' or #data>10000 then return false,'Invalid route or too many entries.' end
  local count=0
  for key in pairs(data) do
    if type(key)~='number' or key%1~=0 or key<1 or key>#data then return false,'Expected a consecutive list of actions.' end
    count=count+1
  end
  if count~=#data then return false,'Route contains missing entries.' end
  for _,entry in ipairs(data) do
    if type(entry)~='table' or type(entry[1])~='string' or type(entry[2])~='string' then return false,'Expected pairs: action, value.' end
    if #entry[2]>100000 then return false,'Action is too large.' end
    if entry[1]~='config' and entry[1]~='extensions' and not engine.Actions[entry[1]] then return false,'Unknown action: '..entry[1] end
    if entry[1]=='config' or entry[1]=='extensions' then local ok,value=pcall(json.decode,entry[2]) if not ok or type(value)~='table' then return false,'Invalid '..entry[1]..' data.' end end
    if engine.independent then
      if entry[1]=='config' then
        local ok,err=pcall(NexusBot.Automation.Walker.config,json.decode(entry[2])) if not ok then return false,tostring(err) end
      elseif entry[1]=='extensions' then
        if next(json.decode(entry[2])) then return false,'Legacy extensions require conversion; remove extensions from a COPY before import.' end
      else
        local ok,err=NexusBot.Automation.Walker.validate(entry[1],entry[2]) if not ok then return false,err end
      end
    end
  end
  return true
end
function C.snapshot(engine)
  local result={}
  for _,entry in ipairs(engine.actionList:getChildren()) do result[#result+1]={entry.action,entry.value} end
  if engine.Config then result[#result+1]={'config',json.encode(engine.Config.save())} end
  local extra={}
  for name,extension in pairs(engine.Extensions or {}) do if extension.onSave then extra[name]=extension.onSave() end end
  result[#result+1]={'extensions',json.encode(extra)} return result
end
function C.parseItems(text)
  local items,seen={},{}
  for token in tostring(text):gmatch('[^,%s;]+') do
    local id=tonumber(token)
    if not id or id%1~=0 or id<100 or id>65535 then return nil,'Invalid item ID: '..token end
    if not seen[id] then items[#items+1]={id=id} seen[id]=true end
  end
  return items
end
end

do
local A=NexusBot.Automation
local N=A.Navigation
A.Walker={state=nil,recording=false,trade={}}
local W=A.Walker
W.defaults={loop=true,stepDelay=0,actionTimeout=15000,useDelay=900,maxUseRetries=4,recordDistance=3,ropeId=3003,shovelId=3457,allowLua=false,talkDelay=700,debugCave=false,debugPath=false,autoNavigate=false}

function W.clearDebug()
  for tile,text in pairs(W.debugTiles or {}) do
    if tile:getText()==text then tile:setText('') if tile.setTextCentered then tile:setTextCentered(false) end end
    if tile.setFill then tile:setFill('#00000000') end
  end
  W.debugTiles={}
end
function W.drawDebug()
  W.clearDebug()
  local C=A.CaveBot local pos=A.position()
  if not g_game.isOnline() or not pos or not C.Config.values.debugCave then return end
  local function mark(p,text)
    if not p or p.z~=pos.z or A.distance(p,pos)>18 then return end
    local tile=g_map.getTile(p)
    if tile and (tile:getText()=='' or W.debugTiles[tile]) then
      tile:setText(text)
      if tile.setTextCentered then tile:setTextCentered(true) end
      if tile.setFill then tile:setFill('#368dda80') end
      W.debugTiles[tile]=text
    end
  end
  local current=C.actionList:getFocusedChild()
  local goal=current and A.parsePosition(current.value)
  if C.Config.values.debugPath and goal and goal.z==pos.z then
    local budget,cache=N.budget,N.tileCache
    N.beginTick()
    local path=N.path(pos,goal,0,true)
    N.budget,N.tileCache=budget,cache
    local point=NexusBot.copy(pos)
    for _,direction in ipairs(path or {}) do
      local delta=N.directions[direction+1] point={x=point.x+delta[1],y=point.y+delta[2],z=point.z}
      mark(point,'')
    end
  end
  for i,entry in ipairs(C.actionList.entries) do mark(A.parsePosition(entry.value),(entry==current and '> ' or '')..i..' '..(entry.action=='goto' and 'Node' or entry.action)) end
end
local function stop(message)
  A.CaveBot.setOff() A.CaveBot.status=message or 'Stopped'
end
local function parseNumbers(value,count)
  local out={}
  for token in tostring(value):gmatch('[^,]+') do
    local n=tonumber(token) if not n or n~=n or n%1~=0 or n<0 or n>65535 then return nil end out[#out+1]=n
  end
  if #out~=count then return nil end return out
end
local function register(name,description,example,validate,run)
  local C=A.CaveBot
  C.Actions[name]={callback=run,validate=validate}
  C.Editor.Actions[name]={description=description,value=example}
end
W.register=register
function W.validate(action,value)
  local definition=A.CaveBot.Actions[action]
  if not definition then return false,'Unsupported independent action: '..tostring(action) end
  if type(value)~='string' or #value>16000 then return false,'Invalid action value.' end
  if definition.validate and not definition.validate(value) then return false,'Invalid '..action..' value. See the action format.' end
  return true
end
function W.config(data)
  local result=NexusBot.merge(W.defaults,data)
  local limits={stepDelay={0,2000},actionTimeout={1000,120000},useDelay={300,10000},maxUseRetries={1,10},recordDistance={1,8},ropeId={100,65535},shovelId={100,65535},talkDelay={300,5000}}
  for key,range in pairs(limits) do
    local value=result[key]
    if type(value)~='number' or value~=value or value%1~=0 or value<range[1] or value>range[2] then error('Invalid walking setting: '..key) end
  end
  result.loop=true
  if type(result.allowLua)~='boolean' then error('Invalid walking switches') end
  return result
end
function W.next()
  local C=A.CaveBot local list=C.actionList local index=list:getChildIndex(list:getFocusedChild()) or 0
  if index>=#list.entries then
    if #list.entries>0 then list:focusChild(list.entries[1]) else stop('Route finished') end
  else list:focusChild(list.entries[index+1]) end
end
function W.gotoLabel(name)
  for _,entry in ipairs(A.CaveBot.actionList.entries) do if entry.action=='label' and entry.value==name then A.CaveBot.actionList:focusChild(entry) return true end end
  return false
end
function W.nearestReachable(pos,exclude)
  local candidates={}
  for _,entry in ipairs(A.CaveBot.actionList.entries) do
    if entry~=exclude and (entry.action=='goto' or entry.action=='walk' or entry.action=='stairs') then
      local goal=A.parsePosition(entry.value)
      if goal and goal.z==pos.z and A.distance(pos,goal)<=64 then
        candidates[#candidates+1]={entry=entry,goal=goal,distance=A.distance(pos,goal)}
      end
    end
  end
  table.sort(candidates,function(a,b) return a.distance<b.distance end)
  N.beginTick()
  local best,bestCost
  for _,candidate in ipairs(candidates) do
    if N.budget and N.budget<=0 then break end
    local path=N.path(pos,candidate.goal,candidate.goal.radius or 0,candidate.goal.radius==0)
    if not path and A.CaveBot.Config.values.autoNavigate then path=N.mappedPath(pos,candidate.goal,candidate.goal.radius==0,false) end
    if path then
      local cost=0 for _,direction in ipairs(path) do cost=cost+(direction>=4 and 3 or 1) end
      if not bestCost or cost<bestCost then best,bestCost=candidate.entry,cost end
    end
  end
  return best
end
function W.pauseFailure(message,now)
  local C=A.CaveBot
  C.status='Waiting: '..tostring(message)
  W.nextTick=now+math.max(1000,C.Config.values.useDelay)
  -- Preserve action evidence (especially already-sent NPC words/item uses).
  -- Clearing it here could repeat a purchase or close a door again.
  if W.state then W.state.started=now end
  N.reset()
end
function W.suppliesLow()
  local cfg=A.data().supplies local player=g_game.getLocalPlayer()
  if A.call(player,'getFreeCapacity',0)<(cfg.minCapacity or 0) then return true end
  local hp=A.call(player,'getHealthPercent',100)
  local mana=A.call(player,'getMana',0) local maxMana=A.call(player,'getMaxMana',0)
  for id,item in pairs(cfg.items or {}) do if A.countItem(tonumber(id))<(item.min or 0) then return true end end
  return false
end
function W.useAt(state,pos,itemId,transition,requireWalkable)
  local C=A.CaveBot local current=A.position()
  if state.uses and current.z~=state.startZ then return true end
  local now=NexusBot.now()
  if state.nextUse and now<state.nextUse then return 'retry' end
  -- A plain use is a one-shot action. Waiting for the top item's ID to change
  -- re-closed doors and tried walking back after the player had passed them.
  if state.uses and not transition and not requireWalkable then return true end
  if current.z~=pos.z then return false,'Wrong floor for item use.' end
  if A.distance(current,pos)>1 then N.walk(pos,1,false) return 'retry' end
  local tile=g_map.getTile(pos) local thing=A.call(tile,'getTopUseThing')
  if not thing then return false,'No usable object at waypoint.' end
  if state.uses and not transition then
    if (not requireWalkable and state.thingId~=thing:getId()) or A.call(tile,'isWalkable',false,false) then return true end
    if state.uses>=2 and not requireWalkable then return false,'Object did not change after use.' end
  end
  if (state.uses or 0)>=C.Config.values.maxUseRetries then return false,'Item use retry limit reached.' end
  local sent
  if itemId then
    if A.countItem(itemId)==0 then return false,'Missing tool: '..itemId end
    sent=g_game.useInventoryItemWith(itemId,thing)
  else sent=g_game.use(thing) end
  if sent==false then return false,'Client rejected item use.' end
  state.thingId=thing:getId() state.uses=(state.uses or 0)+1 state.nextUse=now+C.Config.values.useDelay
  return 'retry'
end
function W.registerActions()
  local position=function(v) return A.parsePosition(v)~=nil end
  local nonempty=function(v) return v:match('%S')~=nil and #v<=200 end
  local C=A.CaveBot
  register('goto','Position x,y,z[,distance]. Add ,0 to explicitly enter stairs or teleport.','100,100,7',position,function(v,s)
    local goal=A.parsePosition(v)
    local transition=goal.radius==0
    if transition and (A.position().z~=s.startZ or (s.lastPos and A.distance(s.lastPos,A.position())>2 and A.distance(s.lastPos,goal)<=1)) then return true end
    s.lastPos=NexusBot.copy(A.position())
    local arrived,why=N.walkRoute(goal,goal.radius or 0,transition)
    if why~='waiting' and why~='walking' and not arrived then C.status=why end
    return arrived or 'retry'
  end)
  register('walk','Explicit transition tile x,y,z. Allows entering this destination only.','100,100,7',position,function(v,s)
    if A.position().z~=s.startZ then return true end
    if s.lastPos and A.distance(s.lastPos,A.position())>2 and A.distance(s.lastPos,A.parsePosition(v))<=1 then return true end
    s.lastPos=NexusBot.copy(A.position())
    local arrived=N.walkRoute(A.parsePosition(v),0,true) return arrived or 'retry'
  end)
  register('stairs','Enter transition tile x,y,z and confirm a floor change.','100,100,7',position,function(v,s)
    if A.position().z~=s.startZ then return true end
    N.walkRoute(A.parsePosition(v),0,true) return 'retry'
  end)
  register('use','Use door/ladder/object at x,y,z. Retries are bounded.','100,100,7',position,function(v,s) return W.useAt(s,A.parsePosition(v)) end)
  register('usewith','Use item on tile: itemId,x,y,z.','3003,100,100,7',function(v) local n=parseNumbers(v,4) return n and n[1]>=100 and n[4]<=15 end,function(v,s)
    local n=parseNumbers(v,4) return W.useAt(s,{x=n[2],y=n[3],z=n[4]},n[1],false)
  end)
  for _,tool in ipairs({'rope','shovel'}) do local kind=tool
    register(kind,'Use configured '..kind..' at x,y,z. Rope confirms floor change.','100,100,7',position,function(v,s)
      return W.useAt(s,A.parsePosition(v),C.Config.values[kind..'Id'],kind=='rope')
    end)
  end
  register('waitz','Wait until the player reaches this floor (0-15).','7',function(v) local n=tonumber(v) return n and n%1==0 and n>=0 and n<=15 end,function(v) return A.position().z==tonumber(v) or 'retry' end)
  register('label','Route label.','hunt',nonempty,function() return true end)
  register('gotolabel','Jump to an existing label.','hunt',nonempty,function(v)
    if not W.gotoLabel(v) then return false,'Label not found: '..v end return 'jump'
  end)
  register('delay','Wait in milliseconds (0-120000).','1000',function(v) local n=tonumber(v) return n and n>=0 and n<=120000 and n%1==0 end,function(v,s)
    return NexusBot.now()-s.started>=tonumber(v) or 'retry'
  end)
  register('say','Say exact words once.','hi',nonempty,function(v) g_game.talk(v) return true end)
  register('npcsay','Say words in the NPC channel once.','trade',nonempty,function(v)
    if not MessageModes or not MessageModes.NpcTo then return false,'NPC message mode unavailable.' end
    g_game.talkChannel(MessageModes.NpcTo,0,v) return true
  end)
  register('supplycheck','Enough supplies: jump to label. Low supplies: continue route.','hunt',function(v) return #v<=200 end,function(v)
    if W.suppliesLow() or v=='' then return true end
    if W.gotoLabel(v) then return 'jump' end
    return false,'Supply check label not found: '..v
  end)
  for _,action in ipairs({'buy','sell'}) do local kind=action
    register(kind,kind=='buy' and 'itemId,totalToKeep (0 = supply refill target). Requires open NPC trade.' or 'Item ID. Sell all unequipped items of this type in the open NPC trade.',kind=='sell' and '3031' or '3031,100',function(v)
      local n=parseNumbers(v,2) or (kind=='sell' and parseNumbers(v,1)) return n and n[1]>=100
    end,function(v,s)
      local n=parseNumbers(v,2) or parseNumbers(v,1) local id,limit=n[1],n[2] or 0
      if kind=='buy' and limit==0 then
        local supply=A.data().supplies.items[tostring(id)]
        if not supply then return false,'No refill target configured for this item.' end limit=supply.max
      end
      local count=A.countItem(id)
      if kind=='sell' then
        for slot=1,10 do local item=A.call(g_game.getLocalPlayer(),'getInventoryItem',nil,slot) if item and item:getId()==id then count=count-A.call(item,'getCount',1) end end
      end
      local amount=kind=='buy' and limit-count or count-limit
      if amount<=0 then return true end
      local offer=W.trade[id]
      if not offer or (kind=='buy' and offer.buy<=0) or (kind=='sell' and offer.sell<=0) then return false,'No matching offer in the open NPC trade window.' end
      if kind=='sell' then for _,keep in ipairs(A.data().sellExceptions or {}) do if keep==id then return true end end end
      if s.count~=count then s.count=count s.attempts=0 end
      if (s.attempts or 0)>=3 then return false,'Trade was not confirmed by inventory changes.' end
      if NexusBot.now()<(s.nextUse or 0) then return 'retry' end
      if kind=='buy' then g_game.buyItem(offer.item,math.min(100,amount),false,false)
      else g_game.sellItem(offer.item,math.min(100,amount),true) end
      s.attempts=(s.attempts or 0)+1 s.nextUse=NexusBot.now()+1000 return 'retry'
    end)
  end
  register('deposit','Move item into an OPEN destination container: itemId,containerId.','3031,2854',function(v) local n=parseNumbers(v,2) return n and n[1]>=100 and n[2]>=100 end,function(v,s)
    local n=parseNumbers(v,2) local bags=g_game.getContainers() or {} local destination
    for _,bag in pairs(bags) do if bag:getContainerItem():getId()==n[2] and #bag:getItems()<bag:getCapacity() then destination=bag break end end
    if not destination then return false,'Open the configured destination container with free space.' end
    for _,bag in pairs(bags) do if bag~=destination then for _,item in ipairs(bag:getItems()) do if item:getId()==n[1] then
      local signature=A.key(item:getPosition())..':'..item:getId()..':'..A.call(item,'getCount',1)
      if s.signature~=signature then s.signature=signature s.attempts=0 end
      if (s.attempts or 0)>=3 then return false,'Deposit not confirmed.' end
      if NexusBot.now()<(s.nextUse or 0) then return 'retry' end
      g_game.move(item,destination:getSlotPosition(#destination:getItems()),A.call(item,'getCount',1))
      s.attempts=(s.attempts or 0)+1 s.nextUse=NexusBot.now()+600 return 'retry'
    end end end end return true
  end)
  register('function','Sandboxed Lua. Helpers: pos, countItem, suppliesLow, gotoLabel, delay, say; return true or "retry".','return true',function(v) return #v<=16000 end,function(v,s)
    if not debug or not debug.sethook or not setfenv or not loadstring then return false,'Client cannot safely limit Lua actions.' end
    if NexusBot.now()<(s.nextUse or 0) then return 'retry' end
    local fn,err=loadstring(v,'CWELBOT route') if not fn then return false,err end
    if jit and jit.off then jit.off(fn,true) end
    local jumped=false
    local env={math=NexusBot.copy(math),string=NexusBot.copy(string),table=NexusBot.copy(table),tonumber=tonumber,tostring=tostring,pairs=pairs,ipairs=ipairs,type=type,
      retries=s.retries,pos=A.position,countItem=A.countItem,suppliesLow=W.suppliesLow,
      gotoLabel=function(label) jumped=W.gotoLabel(label) return jumped end,
      delay=function(ms) s.nextUse=NexusBot.now()+math.max(100,math.min(120000,tonumber(ms) or 100)) end,
      say=function(words) if s.spoken then return false end g_game.talk(tostring(words):sub(1,200)) s.spoken=true return true end}
    env.string.rep=nil env.string.gsub=nil env.table.sort=nil
    setfenv(fn,env)
    local oldHook,oldMask,oldCount=debug.gethook()
    debug.sethook(function() error('Lua instruction budget exceeded') end,'',20000)
    local ok,result=pcall(fn)
    debug.sethook(oldHook,oldMask,oldCount)
    if not ok then return false,tostring(result) end
    if jumped then return 'jump' end
    if result==true or result=='retry' then return result end
    return false,'Lua action must return true or "retry".'
  end)
  register('stop','Stop the route.','',function() return true end,function() stop('Stopped by route') return 'jump' end)
end
function W.init()
  local C={independent=true,enabled=false,status='OFF',actionList=A.newList(),Actions={},Editor={Actions={}},Extensions={},Config={values={},value_setters={}},Recorder={}}
  A.CaveBot=C
  C.isOn=function() return C.enabled end C.isOff=function() return not C.enabled end
  C.setOff=function() C.enabled=false C.status='OFF' W.state=nil N.reset()
    if NexusBot.Features.AutoExplore then NexusBot.Features.AutoExplore.reset() end
  end
  C.setOn=function(fromCurrent)
    if NexusBot.Features.AutoExplore then NexusBot.Features.AutoExplore.reset() end
    A.legacyConflict('CaveBot')
    if #C.actionList.entries==0 then C.status='Add waypoints first.' return end
    if not NexusBot.enabled then NexusBot.setEnabled(true) end
    C.Recorder.disable() C.enabled=true C.status='Running' W.state=nil W.nextTick=0 N.reset()
    local pos=A.position() local nearest,best
    for _,entry in ipairs(C.actionList.entries) do
      if entry.action=='goto' or entry.action=='walk' or entry.action=='stairs' then
        local distance=A.distance(pos,A.parsePosition(entry.value))
        if distance<math.huge and (not best or distance<best) then nearest,best=entry,distance end
      end
    end
    if C.Config.values.autoNavigate then nearest=W.nearestReachable(pos) or nearest end
    C.actionList:focusChild((fromCurrent and C.actionList:getFocusedChild()) or nearest or C.actionList:getFocusedChild() or C.actionList.entries[1])
  end
  C.actionList.onFocus=function() W.state=nil end
  C.Config.get=function(key) return C.Config.values[key] end
  C.Config.save=function() return NexusBot.copy(C.Config.values) end
  C.getCurrentProfile=function() return A.data().activeCave end
  C.addAction=function(action,value,focus)
    local ok,err=W.validate(action,value) if not ok then error(err) end
    local entry=C.actionList:add({action=action,value=value}) if focus then C.actionList:focusChild(entry) end return entry
  end
  C.editAction=function(entry,action,value)
    local ok,err=W.validate(action,value) if not ok then error(err) end
    entry.action=action entry.value=value
    if entry==C.actionList:getFocusedChild() then W.state=nil end
  end
  C.save=function() return A.saveProfile('cavebot_configs',C.getCurrentProfile(),NexusBot.Features.CaveTools.snapshot(C)) end
  C.setCurrentProfile=function(name)
    local data=A.data().caveProfiles[name] if not data then error('CaveBot profile does not exist') end
    local ok,err=NexusBot.Features.CaveTools.validateRoute(data,C) if not ok then error(err) end
    local cfg={} for _,entry in ipairs(data) do if entry[1]=='config' then cfg=json.decode(entry[2]) end end
    cfg=W.config(cfg)
    C.setOff() C.Recorder.disable() C.actionList:clear() C.Config.values=cfg
    for _,entry in ipairs(data) do if C.Actions[entry[1]] then C.addAction(entry[1],entry[2]) end end
    C.actionList:focusChild(C.actionList.entries[1]) A.data().activeCave=name NexusBot.Storage.touch()
  end
  C.gotoLabel=W.gotoLabel
  C.delay=function(ms) if W.state then W.state.nextUse=NexusBot.now()+(tonumber(ms) or 100) end end
  C.Recorder.isOn=function() return W.recording end
  C.Recorder.disable=function() W.recording=false W.recordLast=nil W.recordObserved=nil W.recordIntents={} W.recordTool=nil W.recordPrediction=nil end
  C.Recorder.enable=function()
    C.setOff() W.recording=true W.recordLast=nil W.recordObserved=nil W.recordIntents={} W.recordTool=nil W.recordPrediction=nil C.status='Recording'
    W.recordPosition(A.position())
  end
  W.registerActions()
  if A.CaveExtensions then A.CaveExtensions.register() end
  C.setCurrentProfile(A.data().activeCave)
  A.connections={onOpenNpcTrade=function(items)
    W.trade={} for _,offer in ipairs(items or {}) do local item=offer[1] if item then W.trade[item:getId()]={item=item,buy=tonumber(offer[4]) or 0,sell=tonumber(offer[5]) or 0} end end
  end,onCloseNpcTrade=function() W.trade={} end}
  A.connections.onWalk=function(direction)
    local prediction=W.recordPrediction W.recordPrediction=nil
    local d=N.directions[direction+1]
    local from=prediction and NexusBot.now()-prediction.at<100 and d and prediction.from
    if from and (prediction.to.x~=from.x+d[1] or prediction.to.y~=from.y+d[2]) then from=nil end
    W.recordWalk({direction},from)
  end
  A.connections.onAutoWalk=function(player,dirs) if player==g_game.getLocalPlayer() then W.recordWalk(dirs) end end
  A.connections.onUse=function(pos) W.recordUse(pos) end
  A.connections.onUseWith=function(pos,id,target)
    if not A.call(target,'isCreature',false) then W.recordUse(A.call(target,'getPosition'),id) end
  end
  if A.CaveExtensions then A.CaveExtensions.events(A.connections) end
  if connect then connect(g_game,A.connections) end
  W.installRecorderHooks()
end
function W.tick()
  local C=A.CaveBot local pos=A.position() local now=NexusBot.now() if not pos then return end
  if W.recording then
    W.recordPosition(pos,W.recordObserved)
  end
  if not C.enabled then return end
  if A.Targeting.allowCave and now<(A.Targeting.caveDelayUntil or 0) then
    if NexusBot.Features.AutoExplore.running then NexusBot.Features.AutoExplore.pause(now) end
    if N.pending and N.pending.route then N.reset() end
    if W.state then W.state.started=W.state.started+math.max(0,now-(W.lastTick or now)) end
    W.lastTick=now C.status='Dynamic lure: waiting after step' return
  end
  A.legacyConflict('CaveBot')
  if NexusBot.Features.AutoExplore.running then
    if A.Targeting.blockCave then NexusBot.Features.AutoExplore.pause(now) N.reset() C.status='Explore: waiting for Targeting / loot' return end
    NexusBot.Features.AutoExplore.tick(pos,now) return
  end
  local entry=C.actionList:getFocusedChild()
  if not entry or entry:isDestroyed() then stop('No active waypoint') return end
  if A.Targeting.blockCave and entry.action~='rushlure' and entry.action~='lure' then
    if N.pending and N.pending.route then N.reset() end
    if W.state then W.state.started=W.state.started+math.max(0,now-(W.lastTick or now)) end
    W.lastTick=now C.status='Waiting for Targeting / loot' return
  end
  W.lastTick=now
  if not W.state or W.state.entry~=entry then W.state={entry=entry,started=now,startZ=pos.z,retries=0} end
  local state=W.state
  local timeout=entry.action=='imbuing' and 120000 or C.Config.values.actionTimeout
  if entry.action=='follow' then
    local seconds=tonumber(entry.value:match('^[^,]+,([^,]+),')) or 0
    timeout=math.max(timeout,seconds*1000+2000)
  end
  if entry.action~='delay' and now-state.started>timeout then
    if C.Config.values.autoNavigate and (entry.action=='goto' or entry.action=='walk') then
      local nearest=W.nearestReachable(pos,entry)
      if nearest then N.reset() C.actionList:focusChild(nearest) C.status='Auto navigate' return end
    end
    W.pauseFailure('Waypoint timed out: '..entry.action..' '..entry.value,now) return
  end
  if now<(W.nextTick or 0) then return end
  W.nextTick=now+math.max(0,C.Config.values.stepDelay)
  C.status='Waypoint '..(C.actionList:getChildIndex(entry) or 0)..': '..entry.action
  local ok,result,err=pcall(C.Actions[entry.action].callback,entry.value,state)
  if not ok then W.pauseFailure('Action error: '..tostring(result),now) return end
  if result==true then W.next()
  elseif result=='retry' then state.retries=state.retries+1
  elseif result~='jump' then W.pauseFailure(err or 'Action failed: '..entry.action,now) end
end
function W.recordAppend(action,value)
  local C=A.CaveBot local last=C.actionList.entries[#C.actionList.entries]
  if last and last.action==action and last.value==value then return end
  if last and action=='goto' and last.action=='goto' and value==last.value..',0' then
    -- Upgrade the entrance node: a normal node would avoid this hazard tile.
    C.editAction(last,action,value) C.save() return
  end
  C.addAction(action,value) C.save()
end
function W.removeRecorderHooks()
  for key,hook in pairs(W.recorderHooks or {}) do if g_game[key]==hook.wrapper then g_game[key]=hook.original end end
  W.recorderHooks={}
end
function W.installRecorderHooks()
  W.removeRecorderHooks()
  local handlers={
    talk=function(words) return 'say',tostring(words) end,
    talkChannel=function(mode,channel,words)
      if mode==MessageModes.NpcTo then return 'npcsay',tostring(words) end
      if mode==MessageModes.Say then return 'say',tostring(words) end
    end,
    buyItem=function(item,count)
      local id=A.call(item,'getId') if id and tonumber(count) then return 'buy',id..','..(A.countItem(id)+count) end
    end,
    sellItem=function(item,count)
      local id=A.call(item,'getId') if id and tonumber(count) then return 'sell',id..','..math.max(0,A.countItem(id)-count) end
    end}
  for key,capture in pairs(handlers) do
    if type(g_game[key])=='function' then
      local original=g_game[key]
      local wrapper=function(...)
        local action,value
        if W.recording and g_app and g_app.isOnInputEvent and g_app.isOnInputEvent() then action,value=capture(...) end
        local result=original(...)
        if action and result~=false then W.recordAppend(action,value) end
        return result
      end
      W.recorderHooks[key]={original=original,wrapper=wrapper} g_game[key]=wrapper
    end
  end
end
function W.recordWalk(directions,origin)
  if not W.recording then return end
  W.recordTool=nil -- A subsequent walk is not a floor change caused by the previous tool.
  local pos=origin or A.position() if not pos then return end
  W.recordIntents=W.recordIntents or {}
  local count=0
  for key,intent in pairs(W.recordIntents) do
    if NexusBot.now()-intent.at>10000 then W.recordIntents[key]=nil else count=count+1 end
  end
  if count>256 then W.recordIntents={} end
  for _,direction in ipairs(directions or {}) do
    local d=N.directions[direction+1] if not d then break end
    local nextPos={x=pos.x+d[1],y=pos.y+d[2],z=pos.z}
    W.recordIntents[A.key(pos)]={to=nextPos,at=NexusBot.now()}
    pos=nextPos
  end
end
function W.recordUse(pos,itemId)
  if not W.recording or not pos or pos.x==65535 then return end
  local current=A.position() if not current then return end
  local cfg=A.CaveBot.Config.values
  W.recordAppend('goto',A.key(current))
  local action=itemId==cfg.ropeId and 'rope' or itemId==cfg.shovelId and 'shovel' or itemId and 'usewith' or 'use'
  W.recordAppend(action,(action=='usewith' and (itemId..',') or '')..A.key(pos))
  W.recordTool={at=NexusBot.now(),from=NexusBot.copy(current)}
  W.recordLast=NexusBot.copy(current)
end
function W.recordPosition(pos,oldPos)
  if not W.recording or not pos then return end
  oldPos=oldPos or W.recordObserved
  W.recordObserved=NexusBot.copy(pos)
  local transition=oldPos and (pos.z~=oldPos.z or A.distance(pos,oldPos)>1)
  if transition then
    local tool=W.recordTool
    if not (tool and NexusBot.now()-tool.at<5000 and A.distance(oldPos,tool.from)<=1) then
      local intent=(W.recordIntents or {})[A.key(oldPos)]
      -- OTCv8 records oldPos as the exact entrance. Some servers instead jump
      -- straight from the adjacent tile; use its known intention in that case.
      local entrance=oldPos
      if not N.transition(g_map.getTile(oldPos)) and intent and NexusBot.now()-intent.at<10000 then entrance=intent.to end
      W.recordAppend('goto',A.key(entrance)..',0')
    end
    W.recordTool=nil
    W.recordAppend('goto',A.key(pos)) W.recordLast=NexusBot.copy(pos)
  elseif not W.recordLast or A.distance(pos,W.recordLast)>=A.CaveBot.Config.values.recordDistance then
    W.recordAppend('goto',A.key(pos)) W.recordLast=NexusBot.copy(pos)
  end
end
end

-- AUTO EXPLORE: controls and runtime live with the CaveBot category.
NexusBot.Features.AutoExplore={running=false,visited={},failures={}}
do
local E=NexusBot.Features.AutoExplore
local A=NexusBot.Automation local N=A.Navigation local U=NexusBot.UI
function E.config()
  local data=A.data() data.exploreProfiles=data.exploreProfiles or {}
  local key=data.activeCave or 'Default'
  if not data.exploreProfiles[key] then data.exploreProfiles[key]={mode='terrain',style='natural',revisit=90,up=0,down=0,regions={},connectors={}} end
  return data.exploreProfiles[key]
end
function E.open()
  NexusBot.WindowManager.close('cavebot:explore')
  local w,list=NexusBot.Features.Modern.shared.formWindow('AUTO EXPLORE',590) w:setWidth(420)
  U.scrollbar(list)
  local cfg=E.config()
  local function changed(key,value) A.CaveBot.setOff() cfg[key]=value NexusBot.Storage.touch() end
  local power=U.toggle(list,'Auto Explore',E.running,function(v)
    if v then local ok,err=E.start() if not ok then displayErrorBox('Auto Explore',err) end else A.CaveBot.setOff() end
  end)
  U.combo(list,'Area',{{'Connected terrain','terrain'},{'Defined rectangles','regions'}},cfg.mode,function(v) changed('mode',v) end)
  U.combo(list,'Style',{{'Natural','natural'},{'Thorough','thorough'},{'Wide roam','wide'}},cfg.style,function(v) changed('style',v) end)
  U.numberInput(list,'Revisit (seconds)',cfg.revisit,15,3600,function(v) changed('revisit',v) end)
  U.numberInput(list,'Floors up',cfg.up,0,7,function(v) changed('up',v) end)
  U.numberInput(list,'Floors down',cfg.down,0,7,function(v) changed('down',v) end)
  U.section(list,'ALLOWED RECTANGLES')
  local p=A.position() or {x=100,y=100,z=7}
  local first=U.textInput(list,'Corner 1: x,y,z',A.key(p),function() end)
  local last=U.textInput(list,'Corner 2: x,y,z',A.key(p),function() end)
  U.button(list,'Add rectangle',function()
    local a,b=A.parsePosition(first:getText()),A.parsePosition(last:getText())
    if not a or not b or a.z~=b.z then displayErrorBox('Auto Explore','Both corners must be on the same floor.') return end
    A.CaveBot.setOff() cfg.regions[#cfg.regions+1]={x1=math.min(a.x,b.x),x2=math.max(a.x,b.x),y1=math.min(a.y,b.y),y2=math.max(a.y,b.y),z=a.z}
    NexusBot.Storage.touch() E.open()
  end)
  local regions=U.compactList(list,70)
  for i,r in ipairs(cfg.regions) do U.button(regions,string.format('%d,%d - %d,%d (%d)  X',r.x1,r.y1,r.x2,r.y2,r.z),function()
    A.CaveBot.setOff() table.remove(cfg.regions,i) NexusBot.Storage.touch() E.open()
  end) end
  U.section(list,'REVIEWED FLOOR / TELEPORT CONNECTIONS')
  local from=U.textInput(list,'Entry: x,y,z',A.key(p),function() end)
  local to=U.textInput(list,'Exit: x,y,z','',function() end)
  local kind='walk' local itemId=3003
  U.combo(list,'Method',{{'Walk on','walk'},{'Use tile','use'},{'Use item (rope)','item'}},kind,function(v) kind=v end)
  U.numberInput(list,'Tool ID',itemId,100,65535,function(v) itemId=v end)
  U.button(list,'Add connection',function()
    local a,b=A.parsePosition(from:getText()),A.parsePosition(to:getText())
    if not a or not b or A.key(a)==A.key(b) then displayErrorBox('Auto Explore','Provide different valid entry and exit positions.') return end
    A.CaveBot.setOff() cfg.connectors[#cfg.connectors+1]={from=a,to=b,kind=kind,itemId=itemId}
    NexusBot.Storage.touch() E.open()
  end)
  local connections=U.compactList(list,70)
  for i,c in ipairs(cfg.connectors) do U.button(connections,A.key(c.from)..' > '..A.key(c.to)..'  X',function()
    A.CaveBot.setOff() table.remove(cfg.connectors,i) NexusBot.Storage.touch() E.open()
  end) end
  local status=U.label(list,'')
  NexusBot.Features.Modern.shared.ownTimer(w,function() power:setOn(E.running) status:setText(A.CaveBot.status or '') end,300)
  NexusBot.WindowManager.attach('cavebot:explore',w)
  NexusBot.Scheduler.after(25,function() NexusBot.WindowManager.clamp(w) end,'Explore window layout')
  return w
end
function E.reset()
  E.running=false E.goal=nil E.connector=nil E.nextScan=0 E.visited={} E.failures={} E.visitedCount=0 E.lastTick=nil
end
function E.pause(now)
  if E.started then E.started=E.started+math.max(0,now-(E.lastTick or now)) end
  E.lastTick=now
end
function E.allowed(p)
  local cfg=E.config()
  if not p or not E.startFloor or p.z<E.startFloor-cfg.up or p.z>E.startFloor+cfg.down then return false end
  if cfg.mode~='regions' then return true end
  for _,r in ipairs(cfg.regions) do
    if p.z==r.z and p.x>=r.x1 and p.x<=r.x2 and p.y>=r.y1 and p.y<=r.y2 then return true end
  end
  return false
end
function E.start()
  local p=A.position() if not p then return false,'Log in first.' end
  A.CaveBot.setOff() E.startFloor=p.z
  if not E.allowed(p) then return false,'Current tile is outside the allowed area.' end
  if not NexusBot.enabled then NexusBot.setEnabled(true) end
  A.legacyConflict('CaveBot') A.CaveBot.Recorder.disable()
  A.CaveBot.enabled=true E.running=true E.lastPosition=NexusBot.copy(p)
  A.CaveBot.status='Exploring' return true
end
function E.choose(pos,now)
  local cfg=E.config() local queue={{p=pos,depth=0}} local head=1
  local seen={[A.key(pos)]=true} local best,bestScore local expanded=0
  while queue[head] and expanded<450 do
    local node=queue[head] head=head+1 expanded=expanded+1
    local key=A.key(node.p) local visited=E.visited[key]
    if node.depth>0 and (not visited or now-visited>=cfg.revisit*1000) and (E.failures[key] or 0)<=now then
      local frontier=0
      for _,d in ipairs(N.directions) do if not g_map.getTile({x=node.p.x+d[1],y=node.p.y+d[2],z=pos.z}) then frontier=frontier+1 end end
      local score=cfg.style=='thorough' and -node.depth or cfg.style=='wide' and node.depth+frontier*3 or frontier*4-node.depth*0.3
      if not bestScore or score>bestScore then best,bestScore=node.p,score end
    end
    for _,d in ipairs(N.directions) do
      local p={x=node.p.x+d[1],y=node.p.y+d[2],z=pos.z} local k=A.key(p)
      if not seen[k] and math.abs(p.x-pos.x)<=8 and math.abs(p.y-pos.y)<=6 and E.allowed(p) and N.safeTile(p,false) then
        seen[k]=true queue[#queue+1]={p=p,depth=node.depth+1}
      end
    end
  end
  E.lastExpanded=expanded return best
end
function E.tick(pos,now)
  E.lastTick=now
  if not E.allowed(pos) then A.CaveBot.setOff() A.CaveBot.status='Explore stopped: outside allowed area / floors' return end
  local key=A.key(pos)
  if not E.visited[key] then E.visitedCount=(E.visitedCount or 0)+1 end
  E.visited[key]=now
  if E.visitedCount>4096 then
    for k,t in pairs(E.visited) do if now-t>E.config().revisit*1000 then E.visited[k]=nil E.visitedCount=E.visitedCount-1 end end
    if E.visitedCount>4096 then E.visited={[key]=now} E.visitedCount=1 end
  end
  local c=E.connector
  if c then
    if A.distance(pos,c.to)==0 then E.connector=nil E.goal=nil N.reset() E.nextScan=0 return end
    if now-E.started>10000 then E.failures['connector:'..A.key(c.from)]=now+30000 E.connector=nil N.reset() return end
    if pos.z~=c.from.z then A.CaveBot.setOff() A.CaveBot.status='Unexpected connector exit; review connection.' return end
    if c.kind=='walk' then N.walkRoute(c.from,0,true,E.allowed)
    elseif A.distance(pos,c.from)>1 then N.walkRoute(c.from,1,false,E.allowed)
    elseif now>=(E.nextUse or 0) then
      local tile=g_map.getTile(c.from) local thing=tile and tile:getTopUseThing()
      if thing then
        if c.kind=='item' then g_game.useInventoryItemWith(c.itemId,thing) else g_game.use(thing) end
        E.nextUse=now+1000
      end
    end
    A.CaveBot.status='Explore: connection '..A.key(c.to) return
  end
  if E.lastPosition and pos.z~=E.lastPosition.z then E.goal=nil N.reset() end
  E.lastPosition=NexusBot.copy(pos)
  if E.goal then
    if A.distance(pos,E.goal)==0 then E.goal=nil E.nextScan=0
    elseif now-E.started>8000 then E.failures[A.key(E.goal)]=now+15000 E.goal=nil N.reset()
    else
      N.walkRoute(E.goal,0,false,E.allowed) A.CaveBot.status='Explore '..A.key(E.goal)..' / visited '..E.visitedCount return
    end
  end
  if now<(E.nextScan or 0) then return end E.nextScan=now+500
  E.goal=E.choose(pos,now) E.started=now
  if not E.goal then
    for _,entry in ipairs(E.config().connectors) do
      if entry.from.z==pos.z and E.allowed(entry.from) and E.allowed(entry.to) and (E.failures['connector:'..A.key(entry.from)] or 0)<=now then
        local path=N.path(pos,entry.from,entry.kind=='walk' and 0 or 1,true,E.allowed)
        if path then E.connector=entry E.nextUse=0 break end
      end
    end
    A.CaveBot.status='Explore: waiting for new / revisit tiles'
  end
end
end

do
local A=NexusBot.Automation local W=A.Walker local N=A.Navigation
A.CaveExtensions={}
local E=A.CaveExtensions
E.colors={goto='#65df91',walk='#65df91',stairs='#65df91',waitz='#65df91',label='#e9d366',gotolabel='#e9d366',delay='#a8b6c8',use='#eab176',usewith='#eab176',rope='#eab176',shovel='#eab176',say='#df92ef',npcsay='#df92ef',follow='#f3a94e',['function']='#f17b7b',travel='#ec8585',bank='#ec8585',buysupplies='#c989ef',buy='#c989ef',sell='#c989ef',sellall='#c989ef',rushlure='#e984c1',lure='#e984c1',tasker='#e984c1',imbuing='#f17b7b',supplycheck='#ec8585',poscheck='#62d9de',cleartile='#62d9de',opendoors='#62d9de',withdraw='#7da9f4',inwithdraw='#7da9f4',dpwithdraw='#7da9f4',deposit='#7da9f4',depositor='#7da9f4',stop='#f17b7b'}
function E.split(value)
  local out={} for token in tostring(value):gmatch('[^,]+') do out[#out+1]=token:gsub('^%s+',''):gsub('%s+$','') end return out
end
local function name(value) return #value>0 and #value<=200 end
function E.npc(name)
  for _,c in ipairs(g_map.getSpectators(A.position(),false) or {}) do if A.call(c,'isNpc',false) and (name=='' or c:getName():lower()==name:lower()) then return c end end
end
function E.dialog(state,npcName,words)
  local npc=E.npc(npcName) if not npc then return false,'NPC not visible: '..npcName end
  if A.distance(A.position(),npc:getPosition())>3 then N.walk(npc:getPosition(),3,false) return 'retry' end
  local now=NexusBot.now() state.chatIndex=state.chatIndex or 1
  if now<(state.nextChat or 0) then return 'retry' end
  if state.chatIndex>#words then return true end
  local word=words[state.chatIndex]
  if state.chatIndex==1 then g_game.talk(word)
  elseif MessageModes and MessageModes.NpcTo then g_game.talkChannel(MessageModes.NpcTo,0,word)
  else return false,'NPC channel API unavailable.' end
  state.chatIndex=state.chatIndex+1 state.nextChat=now+A.CaveBot.Config.values.talkDelay
  return 'retry'
end
function E.openTrade(state,npc)
  if not state.tradeStarted then W.trade={} state.tradeStarted=true end
  if next(W.trade) then return true end
  local result,err=E.dialog(state,npc,{'hi','trade'})
  if result==false then return false,err end return 'retry'
end
function E.container(id)
  for _,bag in pairs(g_game.getContainers() or {}) do if bag:getContainerItem():getId()==tonumber(id) then return bag end end
end
function E.transfer(source,destination,id,needed,state)
  if not source or not destination or source==destination then return false,'Open separate source and destination containers.' end
  if #destination:getItems()>=destination:getCapacity() then return false,'Destination is full.' end
  for _,item in ipairs(source:getItems()) do if not id or item:getId()==id then
    local signature=A.key(item:getPosition())..':'..item:getId()..':'..A.call(item,'getCount',1)
    -- Removing the first stack shifts the next identical stack into the same
    -- slot. Its signature is identical, but it is a NEW acknowledged transfer.
    if state.signature~=signature or state.pendingItem~=item then state.signature=signature state.attempts=0 end
    if (state.attempts or 0)>=3 then return false,'Item transfer was not acknowledged.' end
    if NexusBot.now()<(state.nextMove or 0) then return 'retry' end
    g_game.move(item,destination:getSlotPosition(#destination:getItems()),math.min(needed or 100000,A.call(item,'getCount',1)))
    state.pendingItem=item state.attempts=(state.attempts or 0)+1 state.nextMove=NexusBot.now()+600 return 'retry'
  end end
  return false,'Source has no matching items.'
end
function E.register()
  local reg=W.register local C=A.CaveBot
  reg('follow','Approach the named visible NPC/creature, then continue.','NPC name',function(v) local d=E.split(v) return (#d==1 and name(d[1])) or (#d==3 and tonumber(d[2]) and tonumber(d[3])) end,function(v,s)
    local d=E.split(v)
    -- Existing timed routes retain their format; new actions only take a name.
    if #d==3 and NexusBot.now()-s.started>=tonumber(d[2])*1000 then return true end
    for _,c in ipairs(g_map.getSpectators(A.position(),false) or {}) do if c:getName():lower()==d[1]:lower() then
      local arrived=N.walk(c:getPosition(),tonumber(d[3]) or 1,false)
      if #d==1 and arrived then return true end
      return 'retry'
    end end
    return false,'Follow target lost; no safe transition evidence.'
  end)
  reg('travel','NPC name,destination. Confirms travel by a position/floor change.','Captain,Thais',function(v) local d=E.split(v) return #d==2 end,function(v,s)
    local d=E.split(v) s.origin=s.origin or NexusBot.copy(A.position())
    if A.distance(s.origin,A.position())>5 then return true end
    local result,err=E.dialog(s,d[1],{'hi',d[2],'yes'})
    if result==false then return false,err end return 'retry'
  end)
  reg('buysupplies','NPC name. Buys configured Supply items to refill targets; needs standard NPC trade.','NPC name',name,function(v,s)
    local ready,err=E.openTrade(s,v) if ready~=true then return ready,err end
    for id,cfg in pairs(A.data().supplies.items or {}) do if A.countItem(tonumber(id))<cfg.max then
      s.itemStates=s.itemStates or {} s.itemStates[id]=s.itemStates[id] or {}
      local result,message=C.Actions.buy.callback(id..','..cfg.max,s.itemStates[id])
      if result~=true then return result,message end
      return 'retry'
    end end return true
  end)
  reg('sellall','NPC name. Sell offered unequipped loot; keep supplies and Sell exceptions.','NPC name',name,function(v,s)
    local ready,err=E.openTrade(s,v) if ready~=true then return ready,err end
    local protected={} for _,id in ipairs(A.data().sellExceptions or {}) do protected[id]=true end
    for id in pairs(A.data().supplies.items or {}) do protected[tonumber(id)]=true end
    for _,bag in pairs(g_game.getContainers() or {}) do for _,item in ipairs(bag:getItems()) do
      local id=item:getId() local offer=W.trade[id]
      if offer and offer.sell>0 and not protected[id] and not A.call(item,'isContainer',false) then
        s.items=s.items or {} s.items[id]=s.items[id] or {}
        local result,message=C.Actions.sell.callback(id..',0',s.items[id])
        if result~=true then return result,message end
      end
    end end return true
  end)
  reg('lure','start = suspend Targeting; stop = enable it; toggle = invert.','toggle',function(v) return v=='start' or v=='stop' or v=='toggle' end,function(v)
    if v=='start' or (v=='toggle' and A.TargetBot.isOn()) then A.TargetBot.setOff() else A.TargetBot.setOn() end return true
  end)
  reg('rushlure','x,y,z,waitMs. Walk to the gathering tile; wait, then fight.','100,100,7,1000',function(v) local d=E.split(v) return #d==4 and A.parsePosition(table.concat(d,',',1,3)) and tonumber(d[4]) and tonumber(d[4])>=0 and tonumber(d[4])<=10000 end,function(v,s)
    if W.suppliesLow() then return false,'Supplies low; rush lure stopped.' end
    local d=E.split(v) local p=A.parsePosition(table.concat(d,',',1,3))
    if A.distance(A.position(),p)>0 then N.walk(p,0,false) return 'retry' end
    s.arrived=s.arrived or NexusBot.now()
    if NexusBot.now()-s.arrived<tonumber(d[4]) then return 'retry' end A.TargetBot.setOn() return true
  end)
  reg('poscheck','x,y,z,label. Jump on an exact match; otherwise continue.','100,100,7,hunt',function(v)
    local d=E.split(v)
    if #d==4 then return A.parsePosition(table.concat(d,',',1,3)) and name(d[4]) end
    return #d==6 and tonumber(d[2]) and tonumber(d[2])>=0 and tonumber(d[2])<=30 and A.parsePosition(table.concat(d,',',3,5)) and tonumber(d[6]) and tonumber(d[6])>=1 and tonumber(d[6])<=100
  end,function(v,s)
    local d=E.split(v) W.posRetries=W.posRetries or {}
    if #d==4 then
      if A.distance(A.position(),A.parsePosition(table.concat(d,',',1,3)))~=0 then return true end
      if W.gotoLabel(d[4]) then return 'jump' end
      return false,'Position check label not found: '..d[4]
    end
    if A.distance(A.position(),A.parsePosition(table.concat(d,',',3,5)))<=tonumber(d[2]) then W.posRetries[v]=nil return true end
    W.posRetries[v]=(W.posRetries[v] or 0)+1
    if W.posRetries[v]>tonumber(d[6]) then return false,'Position check retry limit reached.' end
    if W.gotoLabel(d[1]) then return 'jump' end return false,'Position check label not found.'
  end)
  reg('opendoors','Use door at exact x,y,z. Does not guess nearby doors.','100,100,7',function(v) return A.parsePosition(v)~=nil end,function(v,s)
    local p=A.parsePosition(v) local tile=g_map.getTile(p)
    if A.call(tile,'isWalkable',false,false) then return true end return W.useAt(s,p)
  end)
  reg('cleartile','x,y,z,runeId. Use configured clearing rune, never push a player.','100,100,7,3197',function(v) local d=E.split(v) return #d==4 and A.parsePosition(table.concat(d,',',1,3)) and tonumber(d[4]) and tonumber(d[4])>=100 and tonumber(d[4])<=65535 end,function(v,s)
    local d=E.split(v) local p=A.parsePosition(table.concat(d,',',1,3)) local tile=g_map.getTile(p)
    if not tile then return false,'Tile is not visible.' end
    if A.call(tile,'hasCreatures',false) then return false,'A creature occupies the tile.' end
    if A.call(tile,'isWalkable',false,false) then return true end
    return W.useAt(s,p,tonumber(d[4]),false,true)
  end)
  for _,key in ipairs({'withdraw','inwithdraw','dpwithdraw'}) do
    reg(key,'OPEN sourceContainerId,itemId,totalToKeep,destinationContainerId. Inbox/depot must be open.','2854,3031,100,2853',function(v) local d=E.split(v) if #d~=4 then return false end for _,n in ipairs(d) do if not tonumber(n) or tonumber(n)<0 or tonumber(n)>65535 then return false end end return true end,function(v,s)
      local d=E.split(v) local source,destination=E.container(d[1]),E.container(d[4])
      if not source or not destination then return false,'Open the selected inbox/depot and backpack first.' end
      local count=0 for _,bag in pairs(g_game.getContainers() or {}) do if bag~=source then for _,item in ipairs(bag:getItems()) do if item:getId()==tonumber(d[2]) then count=count+A.call(item,'getCount',1) end end end end
      if count>=tonumber(d[3]) then return true end
      return E.transfer(source,destination,tonumber(d[2]),tonumber(d[3])-count,s)
    end)
  end
  for _,key in ipairs({'inwithdraw','dpwithdraw'}) do
    local legacy=C.Actions[key]
    reg(key,'Open source container item ID,item ID[,backpack item ID]. Move all matching items.','2854,3031',function(v)
      local d=E.split(v)
      if #d==4 then return legacy.validate(v) end
      if #d~=2 and #d~=3 then return false end
      for _,n in ipairs(d) do local id=tonumber(n) if not id or id%1~=0 or id<100 or id>65535 then return false end end
      return true
    end,function(v,s)
      local d=E.split(v)
      if #d==4 then return legacy.callback(v,s) end
      local source=E.container(d[1]) local id=tonumber(d[2])
      if not source then return false,'Open the selected depot/inbox first.' end
      local found=false
      for _,item in ipairs(source:getItems()) do if item:getId()==id then found=true break end end
      if not found then
        local nextIndex=A.call(source,'getFirstIndex',0)+A.call(source,'getCapacity',0)
        if A.call(source,'hasPages',false) and nextIndex<A.call(source,'getSize',0) then
          if NexusBot.now()<(s.nextMove or 0) then return 'retry' end
          if g_game.seekInContainer then g_game.seekInContainer(source:getId(),nextIndex) s.nextMove=NexusBot.now()+600 return 'retry' end
          return false,'Container paging is unavailable.'
        end
        return true
      end
      local backpack=A.call(g_game.getLocalPlayer(),'getInventoryItem',nil,InventorySlotBack or 3)
      local destinationId=tonumber(d[3]) or A.call(backpack,'getId')
      local destination
      for _,bag in pairs(g_game.getContainers() or {}) do
        if bag~=source and A.call(bag:getContainerItem(),'getId')==destinationId and #bag:getItems()<bag:getCapacity() then
          if destination then return false,'Multiple matching backpacks. Use a distinct destination backpack item ID.' end
          destination=bag
        end
      end
      if not destination then return false,'Open a backpack with free space (optional third value = backpack item ID).' end
      return E.transfer(source,destination,id,nil,s)
    end)
  end
  reg('depositor','Run all configured Stashing item -> OPEN container mappings.','',function(v) return v=='' end,function(v,s)
    for _,entry in ipairs(A.data().stashing or {}) do
      local destination=E.container(entry.container)
      if not destination then return false,'Open stash destination '..entry.container end
      for _,bag in pairs(g_game.getContainers() or {}) do if bag~=destination then for _,item in ipairs(bag:getItems()) do if item:getId()==entry.id then return E.transfer(bag,destination,entry.id,nil,s) end end end end
    end return true
  end)
  reg('bank','deposit,NPC or withdraw,NPC,amount. Standard English dialogue; review server reply.','deposit,Banker',function(v) local d=E.split(v) return (d[1]=='deposit' and #d==2) or (d[1]=='withdraw' and #d==3 and tonumber(d[3]) and tonumber(d[3])>=1 and tonumber(d[3])<=10000000) end,function(v,s)
    local d=E.split(v) local words=d[1]=='deposit' and {'hi','deposit all','yes'} or {'hi','withdraw '..d[3],'yes'}
    local result,err=E.dialog(s,d[2],words) if result~=true then return result,err end
    local reply=W.lastNpcTalk
    if reply and reply.name:lower()==d[2]:lower() and reply.time>=s.started and reply.text:lower():find(d[1],1,true) then return true end
    return 'retry'
  end)
  reg('imbuing','Comma-separated item IDs. Opens shrine UI; finish each item manually and close it to continue.','3081',function(v) return NexusBot.Features.CaveTools.parseItems(v)~=nil and #v>0 end,function(v,s)
    local ids=NexusBot.Features.CaveTools.parseItems(v) s.index=s.index or 1
    if s.opened and not W.imbuingOpen and W.imbuingClosedAt and W.imbuingClosedAt>=s.opened then s.index=s.index+1 s.opened=nil s.sent=nil end
    if s.index>#ids then return true end
    if W.imbuingOpen then s.opened=s.opened or NexusBot.now() C.status='Finish imbuing in the client, then close its window.' return 'retry' end
    if s.sent then return 'retry' end
    local shrine local pos=A.position()
    for x=-1,1 do for y=-1,1 do local tile=g_map.getTile({x=pos.x+x,y=pos.y+y,z=pos.z})
      for _,item in ipairs(A.call(tile,'getItems',{})) do local id=item:getId() if id==25060 or id==25061 or id==25182 or id==25183 then shrine=item end end
    end end
    if not shrine then return false,'Stand next to a supported imbuing shrine.' end
    local target
    for _,bag in pairs(g_game.getContainers() or {}) do for _,item in ipairs(bag:getItems()) do if item:getId()==ids[s.index].id then target=item break end end end
    if not target then return false,'Place imbuing item '..ids[s.index].id..' in an open backpack.' end
    if not g_game.useWith then return false,'Shrine use API unavailable.' end
    g_game.useWith(shrine,target) s.sent=true return 'retry'
  end)
  reg('tasker','NPC tasks: 1,taskName,count,monster[,monster2] / 2,huntLabel,reportLabel / 3. Local loot-message estimate, not !task UI.','2,hunt,report',function(v)
    local d=E.split(v) return (d[1]=='1' and (#d==4 or #d==5) and tonumber(d[3]) and tonumber(d[3])>=1) or (d[1]=='2' and #d==3) or (d[1]=='3' and #d==1)
  end,function(v,s)
    local d=E.split(v) local task=A.data().task or {}
    if d[1]=='2' then local label=(task.active and (task.count or 0)<task.max) and d[2] or d[3] if W.gotoLabel(label) then return 'jump' end return false,'Task route label missing.' end
    local npc=E.npc('') if not npc or A.distance(A.position(),npc:getPosition())>3 then return false,'Stand within 3 tiles of the task NPC.' end
    local words=d[1]=='1' and {'hi','task',d[2],'yes'} or {'hi','report','task'}
    local result,err=E.dialog(s,npc:getName(),words) if result~=true then return result,err end
    if d[1]=='1' then A.data().task={active=true,name=d[2],max=tonumber(d[3]),count=0,monster=d[4]:lower(),monster2=d[5] and d[5]:lower()}
    else A.data().task={active=false} end NexusBot.Storage.touch() return true
  end)
end
function E.events(handlers)
  handlers.onTalk=function(name,level,mode,text) if mode==51 or (MessageModes and mode==MessageModes.NpcFrom) then W.lastNpcTalk={name=name,text=text,time=NexusBot.now()} end end
  handlers.onOpenImbuementWindow=function() W.imbuingOpen=true end
  handlers.onImbuementItem=function() W.imbuingOpen=true end
  handlers.onCloseImbuementWindow=function() W.imbuingOpen=false W.imbuingClosedAt=NexusBot.now() end
  handlers.onTextMessage=function(mode,text)
    if not NexusBot.enabled then return end
    local task=A.data().task if not task or not task.active then return end
    local monster=text:lower():match('loot of (.-):') if not monster then return end
    monster=monster:gsub('^an? ','')
    if monster==task.monster or monster==task.monster2 then task.count=(task.count or 0)+1 NexusBot.Storage.touch() end
  end
end
end
