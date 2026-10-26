-- EQUIPMENT MANAGER: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('equipment_manager', 'EQUIPMENT MANAGER', 8, false)
NexusBot.Categories.profilePower(category)

-- ==================== GUI / LAYOUT ====================
NexusBot.Features.EquipmentManager={id='equipment_manager'}
local slots={
  {'Head',InventorySlotHead},{'Amulet',InventorySlotNeck},{'Backpack',InventorySlotBack},{'Armor',InventorySlotBody},
  {'Right Hand',InventorySlotRight},{'Left Hand',InventorySlotLeft},{'Legs',InventorySlotLeg},{'Feet',InventorySlotFeet},
  {'Ring',InventorySlotFinger},{'Ammo',InventorySlotAmmo}
}
local rules, create, describe
local F=NexusBot.Features.EquipmentManager
local definition={id='equipment_manager',title='Equipment Manager',profileDefaults={rules={}},addText='+ New Equipment Rule',
  columns={'Condition','Action','Slot','Item'},getRules=function(...) return rules(...) end,newRule=function(...) return create(...) end,describe=function(...) return describe(...) end,
  rowValues=function(r) local d=describe(r) return {'',d.type,d.target,d.action} end}
local function limits(rule)
  for _,c in ipairs((rule.conditions or {}).children or {}) do if c.uiResources then return c end end
end
local function resources(rule)
  local group=limits(rule)
  if not group then
    group={type='group',mode='AND',uiResources=true,children={
      {type='health_percent',operator='between',value=0,value2=100},
      {type='mana_percent',operator='between',value=0,value2=100}}}
    rule.conditions=rule.conditions or {mode='AND',children={}}
    rule.conditions.children=rule.conditions.children or {}
    if rule.conditions.mode=='OR' then
      -- Adding an always-true range to an OR would bypass the saved conditions.
      -- Nest the original expression intact, then apply the new ranges with AND.
      rule.conditions={mode='AND',children={rule.conditions}}
    end
    -- Migrate only the two known simple resource fields; retain arbitrary legacy conditions.
    for _,kind in ipairs({'health_percent','mana_percent'}) do
      for i=#rule.conditions.children,1,-1 do
        local c=rule.conditions.children[i]
        if c.type==kind and c.operator=='between' and rule.conditions.mode~='OR' then
          group.children[kind=='health_percent' and 1 or 2]=c table.remove(rule.conditions.children,i)
        end
      end
    end
    rule.conditions.children[#rule.conditions.children+1]=group
  end
  return group
end
definition.decorateRow=function(row,labels,rule)
  if rule.action.itemId then NexusBot.UI.ruleIcon(labels[4],rule.action) end
  local group=limits(rule)
  local function find(kind)
    for _,c in ipairs((group or rule.conditions or {}).children or {}) do if c.type==kind and c.operator=='between' and c.enabled~=false then return c end end
  end
  local hp,mp=find('health_percent'),find('mana_percent')
  labels[1]:setText('')
  for index,entry in ipairs({{hp,'HP','#b83c51'},{mp,'MP','#3676ce'}}) do
    local bar=g_ui.createWidget('UIWidget',labels[1]) bar:setHeight(14) bar:setBackgroundColor(entry[3]) bar:setPhantom(true)
    bar:addAnchor(AnchorLeft,'parent',AnchorLeft) bar:addAnchor(AnchorRight,'parent',AnchorRight)
    bar:addAnchor(AnchorTop,'parent',AnchorTop) bar:setMarginTop(index==1 and -7 or 10)
    local fill=g_ui.createWidget('UIWidget',bar) fill:setBackgroundColor(entry[3]) fill:setPhantom(true)
    bar:setBackgroundColor('#232c39')
    fill:addAnchor(AnchorTop,'parent',AnchorTop) fill:addAnchor(AnchorBottom,'parent',AnchorBottom) fill:addAnchor(AnchorLeft,'parent',AnchorLeft)
    local function paint()
      local lo,hi=entry[1] and entry[1].value or 0,entry[1] and entry[1].value2 or 0
      fill:setMarginLeft(math.floor(bar:getWidth()*lo/100)) fill:setWidth(math.max(0,math.floor(bar:getWidth()*(hi-lo)/100)))
    end
    bar.onGeometryChange=paint paint()
    local text=NexusBot.UI.label(bar,entry[2]..'% '..(entry[1] and (entry[1].value..'-'..entry[1].value2) or 'OFF'),'NexusHeader')
    text:fill('parent') text:setTextAlign(AlignCenter)
  end
end
definition.renderInspector=function(c,tab,r,p)
  local U=NexusBot.UI local a=r.action r.advanced=r.advanced or {}
  if tab=='action' then
    U.combo(p,'Action',{{'Equip','equip'},{'Dequip','unequip'},{'Ammo refill','ammo_refill'},{'Supplies sorter','supplies_sorter'}},r.type,function(v) r.type=v r.enabled=false c:refreshRules() c:renderInspector() end)
    if r.type=='ammo_refill' or r.type=='supplies_sorter' then
      local choices={{'Choose container',-2}}
      for id,bag in pairs(g_game.getContainers() or {}) do choices[#choices+1]={tostring(id)..': '..bag:getName(),id} end
      local function bag(label,key)
        U.combo(p,label,choices,a[key] or -2,function(v)
          a[key]=v local container=g_game.getContainers()[v]
          local item=container and container:getContainerItem() a[key..'Type']=item and item:getId() or nil
        end)
      end
      bag('Source','sourceContainer')
      if r.type=='supplies_sorter' then
        U.textInput(p,'Item IDs',a.itemIds or '',function(v) a.itemIds=v end)
        U.toggle(p,'Ordered destinations',type(a.destinations)=='table',function(v)
          a.destinations=v and F.destinationSpecs(a) or nil
          r.enabled=false c:refreshRules() c:renderInspector()
        end)
        if type(a.destinations)=='table' then
          a.destinations=F.destinationSpecs(a)
          local selected=-2
          U.combo(p,'Destination',choices,selected,function(v) selected=v end)
          U.button(p,'+ Add destination',function()
            local container=(g_game.getContainers() or {})[selected]
            if not container or selected==tonumber(a.sourceContainer) or #a.destinations>=32 then return end
            for _,entry in ipairs(a.destinations) do if entry.container==selected then return end end
            local item=container:getContainerItem()
            a.destinations[#a.destinations+1]={container=selected,typeId=item and item:getId() or nil}
            r.enabled=false NexusBot.Storage.touch() c:refreshRules() c:renderInspector()
          end)
          local list=U.compactList(p,100)
          for index,entry in ipairs(a.destinations) do
            local row=g_ui.createWidget('NexusIntegrationRow',list)
            local container=(g_game.getContainers() or {})[entry.container]
            row.name:setText(index..'. '..entry.container..': '..(container and container:getName() or 'Closed'))
            row.enabled:hide() row.edit:setText('X')
            local function change(delta)
              if delta then
                local target=index+delta if target<1 or target>#a.destinations then return end
                a.destinations[index],a.destinations[target]=a.destinations[target],a.destinations[index]
              else table.remove(a.destinations,index) end
              r.enabled=false NexusBot.Storage.touch() c:refreshRules() c:renderInspector()
            end
            row.edit.onClick=function() change() end
            row.onMousePress=function(_,_,button)
              if button~=MouseRightButton then return false end
              local menu=g_ui.createWidget('NexusContextMenu')
              menu:addOption('Move up',function() change(-1) end)
              menu:addOption('Move down',function() change(1) end)
              menu:display(g_window.getMousePosition()) return true
            end
          end
        else bag('Destination','destinationContainer') end
      else
        U.numberInput(p,'Item ID',a.itemId or 0,0,65535,function(v) a.itemId=v c:refreshRules() end)
        U.combo(p,'Refill to',{{'Ammo slot','slot'},{'Container','container'}},a.destination or 'slot',function(v) a.destination=v c:renderInspector() end)
        if a.destination=='container' then bag('Destination','destinationContainer') end
        U.numberInput(p,'Below count',a.threshold or 30,1,10000,function(v) a.threshold=v end)
        U.numberInput(p,'Refill count',a.refillTo or 100,1,10000,function(v) a.refillTo=v end)
      end
      U.numberInput(p,'Stack limit',a.stackLimit or 100,1,10000,function(v) a.stackLimit=v end)
      return
    end
    local iconRow=g_ui.createWidget('Panel',p) iconRow:setHeight(38)
    local icon=g_ui.createWidget('Item',iconRow) icon:setSize({width=36,height=36}) icon:setVirtual(true) icon:setItemId(a.itemId or 0)
    icon:addAnchor(AnchorLeft,'parent',AnchorLeft) icon:addAnchor(AnchorTop,'parent',AnchorTop)
    icon.onDrop=function(_,dragged)
      local item=dragged and dragged.currentDragThing if not item or not item:isItem() then return false end
      a.itemId=item:getId() a.tier=item.getTier and item:getTier() or 0
      NexusBot.Storage.touch() c:refreshRules() c:renderInspector() return true
    end
    U.numberInput(p,'Item ID',a.itemId or 0,0,65535,function(v) a.itemId=v icon:setItemId(v) c:refreshRules() end)
    U.combo(p,'Equipment slot',slots,a.slot,function(v) a.slot=v c:refreshRules() end)
    U.toggle(p,'Match item tier',a.tier~=nil,function(v) a.tier=v and 0 or nil c:renderInspector() end)
    if a.tier~=nil then U.numberInput(p,'Item tier level',a.tier,0,10,function(v) a.tier=v end) end
    U.combo(p,'Equip source',{{'Move item action','move'},{'Equip action','equip'}},a.source or 'move',function(v) a.source=v end)
    U.button(p,'+ Add item to set',function()
      if not tonumber(a.itemId) or a.itemId<=0 then return end
      a.items=a.items or {}
      local entry={itemId=a.itemId,slot=a.slot,tier=a.tier,source=a.source}
      local found=false
      for i,item in ipairs(a.items) do if item.slot==a.slot then a.items[i]=entry found=true break end end
      if not found then a.items[#a.items+1]=entry end
      NexusBot.Storage.touch() c:refreshRules() c:renderInspector()
    end)
    for index,item in ipairs(a.items or {}) do
      local row=g_ui.createWidget('NexusIntegrationRow',p) row.enabled:hide()
      row.name:setText((slots[item.slot] and slots[item.slot][1] or '?')..': '..item.itemId)
      row.edit:setText('X') row.edit.onClick=function()
        table.remove(a.items,index) NexusBot.Storage.touch() c:refreshRules() c:renderInspector()
      end
    end
    -- The visual set remains available, including drag/drop of custom items.
    local set=g_ui.createWidget('Panel',p) set:setHeight(152)
    local placement={{1,0},{0,0.5},{2,0.5},{1,1},{2,1.5},{0,1.5},{1,2},{1,3},{0,2.5},{2,2.5}}
    for slot=1,10 do
      local cell=g_ui.createWidget('Item',set) cell:setVirtual(true) cell:setSize({width=32,height=32})
      cell:addAnchor(AnchorTop,'parent',AnchorTop) cell:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter)
      cell:setMarginLeft((placement[slot][1]-1)*38) cell:setMarginTop(placement[slot][2]*36)
      if slot==a.slot then cell:setItemId(a.itemId or 0) end
      for _,item in ipairs(a.items or {}) do if item.slot==slot then cell:setItemId(item.itemId) end end
      cell.onClick=function() a.slot=slot NexusBot.Storage.touch() c:refreshRules() c:renderInspector() end
      cell.onDrop=function(_,dragged) a.slot=slot return icon.onDrop(icon,dragged) end
    end
  elseif tab=='conditions' then
    local group=resources(r)
    U.toggle(p,'Extra conditions',a.extraEnabled==true,function(v) a.extraEnabled=v c:renderInspector() end)
    if a.extraEnabled then
      local options={{'Is Drunk','Drunk'},{'Is Rooted','Rooted'},{'Is Feared','Feared'},{'Is Paralyzed','Paralyze'},{'Is In Protection Zone','Pz'}}
      U.combo(p,'First condition',options,a.extraFirst or 'Drunk',function(v) a.extraFirst=v end)
      U.combo(p,'Condition operator',{{'None','NONE'},{'AND','AND'},{'OR','OR'}},a.extraOperator or 'NONE',function(v) a.extraOperator=v c:renderInspector() end)
      if a.extraOperator and a.extraOperator~='NONE' then U.combo(p,'Second condition',options,a.extraSecond or 'Pz',function(v) a.extraSecond=v end) end
    end
    U.toggle(p,"Don't execute if equipped",a.skipEnabled==true or (a.skipEnabled==nil and (a.skipIds or '')~=''),function(v) a.skipEnabled=v c:renderInspector() end)
    if a.skipEnabled or (a.skipEnabled==nil and (a.skipIds or '')~='') then U.textInput(p,'Excluded item IDs',a.skipIds or '',function(v) a.skipIds=v end) end
    for index,label in ipairs({'HP% Range','MP% Range'}) do
      local condition=group.children[index]
      U.toggle(p,label,condition.enabled~=false,function(v) condition.enabled=v c:refreshRules() end)
      U.rangeBar(p,label,condition.value,condition.value2,function(lo,hi) condition.value=lo condition.value2=hi c:refreshRules() end,index==1 and '#ba4050' or '#3676ce')
      if index==1 then U.combo(p,'HP / MP Compare',{{'AND','AND'},{'OR','OR'}},group.mode,function(v) group.mode=v c:refreshRules() end) end
    end
    U.button(p,'Additional saved conditions',function() c:showTab('custom') end)
  elseif tab=='custom' then NexusBot.Inspector.conditions(c,p,r)
  else
    U.numberInput(p,'Equip delay (ms)',r.advanced.minimumDelay or 300,50,60000,function(v) r.advanced.minimumDelay=v end)
    U.toggle(p,'Keep equipped',a.keepEnabled==true,function(v) a.keepEnabled=v c:renderInspector() end)
    if a.keepEnabled then U.numberInput(p,'Keep equipped for (ms)',a.keepMs or 1000,50,60000,function(v) a.keepMs=v end) end
  end
end
definition.open=function()
  NexusBot.Profiles.ensure('equipment_manager',{rules={}})
  return NexusBot.UI.openReference(definition)
end
F.resources=resources


-- ==================== LOGIC / RUNTIME ====================
rules=function(profile) profile.rules=profile.rules or {} return profile.rules end
create=function(profile)
  local list=rules(profile)
  local rule={id=NexusBot.id('equipment'),type='equip',enabled=true,priority=#list+1,
    action={itemId=0,tier=0,slot=InventorySlotFinger},conditions={mode='AND',children={{type='health_percent',operator='between',value=0,value2=100},{type='mana_percent',operator='between',value=0,value2=100}}},
    advanced={minimumDelay=300,customDelay=0,onlyIfCooldownReady=false}}
  list[#list+1]=rule return rule
end
local function slotName(value)
  for _,slot in ipairs(slots) do if slot[2]==tonumber(value) then return slot[1] end end return '?'
end
describe=function(rule)
  if rule.action and rule.action.items and #rule.action.items>0 then
    local names={} for _,item in ipairs(rule.action.items) do names[#names+1]=slotName(item.slot)..' '..item.itemId end
    return {type=rule.type=='unequip' and 'Unequip set' or 'Equip set',action=table.concat(names,', '),target=#names..' slots'}
  end
  if rule.type=='ammo_refill' then return {type='Ammo refill',action='Item '..tostring(rule.action.itemId or 0),target='Below '..tostring(rule.action.threshold or 30)} end
  if rule.type=='supplies_sorter' then
    local targets={} for _,entry in ipairs(F.destinationSpecs(rule.action)) do targets[#targets+1]=entry.container end
    return {type='Supplies sorter',action=rule.action.itemIds or '',target=tostring(rule.action.sourceContainer or '?')..' > '..table.concat(targets,',')}
  end
  local item=NexusBot.Items.get(rule.action and rule.action.itemId)
  return {type=rule.type=='unequip' and 'Unequip' or 'Equip',action=item and item.name or ('Item '..tostring(rule.action and rule.action.itemId or 0)),target=slotName(rule.action and rule.action.slot)}
end
function NexusBot.Features.EquipmentManager.init()
  NexusBot.Profiles.ensure('equipment_manager',{rules={}}) NexusBot.registerModule(definition)
  local manager=NexusBot.Features.EquipmentManager
  manager.filterDirty=true manager.filterProfile=nil
  NexusBot.EventBus.offOwner(manager)
  NexusBot.EventBus.on('storageChanged',manager,function() manager.filterDirty=true end)
  NexusBot.EventBus.on('profileChanged',manager,function(id) if id=='equipment_manager' then manager.slotLocks={} end end)
  NexusBot.Actions.registerProvider('equipment_manager',20,function()
    local profile=NexusBot.Profiles.getActive('equipment_manager')
    local result={}
    if profile and profile.enabled then
      if manager.filterDirty or manager.filterProfile~=profile or NexusBot.now()>=(manager.filterExpires or 0) then
        manager.blockedRules={}
        for _,rule in ipairs(profile.rules) do
          if rule.type=='supplies_sorter' and manager.hasCycle(profile,rule) then manager.blockedRules[rule]=true end
        end
        manager.filterDirty=false manager.filterProfile=profile manager.filterExpires=NexusBot.now()+1000
      end
      for _,rule in ipairs(profile.rules) do
        if not manager.blockedRules[rule] then result[#result+1]=rule end
      end
    end
    return result
  end)
end

category.init = NexusBot.Features.EquipmentManager.init

local F=NexusBot.Features.EquipmentManager
F.slotLocks={}
local setProfileEnabled=category.setEnabled
category.setEnabled=function(value) F.slotLocks={} setProfileEnabled(value) end
function F.matchesItem(item,id,tier)
  if not item or item:getId()~=id then return false end
  if tier==nil then return true end
  if not item.getTier then return false end
  return tonumber(item:getTier())==tonumber(tier)
end
function F.extraAllows(a,context)
  if a.extraEnabled then
    local function state(key)
      local flag=PlayerStates and PlayerStates[key]
      return flag~=nil and context.player.hasState and context.player:hasState(flag)==true
    end
    local first=state(a.extraFirst or 'Drunk')
    if a.extraOperator=='AND' then first=first and state(a.extraSecond or 'Pz')
    elseif a.extraOperator=='OR' then first=first or state(a.extraSecond or 'Pz') end
    if not first then return false end
  end
  if a.skipEnabled~=false then
    local skip={}
    for id in tostring(a.skipIds or ''):gmatch('%d+') do skip[tonumber(id)]=true end
    if next(skip) then for slot=1,10 do local item=context.player:getInventoryItem(slot) if item and skip[item:getId()] then return false end end end
  end
  return true
end
function F.execute(context,a,rule,remove,batch)
  if type(a.items)=='table' and #a.items>0 then
    if not F.extraAllows(a,context) then return false end
    local sent,seen=false,{}
    batch=batch or {destinations={},sources={}}
    for _,item in ipairs(a.items) do
      if not seen[item.slot] then
        seen[item.slot]=true
        local single=NexusBot.copy(a) single.items=nil
        single.slot=item.slot single.itemId=item.itemId single.tier=item.tier single.source=item.source or a.source
        if F.execute(context,single,rule,remove,batch) then sent=true end
      end
    end
    return sent
  end
  local slot=tonumber(a.slot) local id=tonumber(a.itemId)
  if not slot or slot<1 or slot>10 or slot%1~=0 or not F.extraAllows(a,context) then return false end
  local now=context.now or NexusBot.now()
  local lock=F.slotLocks[slot]
  if lock and lock.untilTime>now then return false end
  local worn=context.player:getInventoryItem(slot)
  local function sent(result)
    if result==false then return false end
    local keep=not remove and a.keepEnabled and math.max(50,math.min(60000,tonumber(a.keepMs) or 1000)) or 0
    F.slotLocks[slot]={untilTime=now+math.max(300,keep)}
    return true
  end
  if remove then
    if not worn or (id and id>0 and not F.matchesItem(worn,id,a.tier)) then return false end
    for _,bag in pairs(g_game.getContainers() or {}) do
      local reserved=batch and (batch.destinations[bag] or 0) or 0
      local index=#bag:getItems()+reserved
      if index<bag:getCapacity() then
        local result=sent(g_game.move(worn,bag:getSlotPosition(index),worn:getCount()))
        if result and batch then batch.destinations[bag]=reserved+1 end
        return result
      end
    end
    return false
  end
  if not id or id<=0 or id>65535 or F.matchesItem(worn,id,a.tier) then return false end
  for _,bag in pairs(g_game.getContainers() or {}) do
    for _,item in ipairs(bag:getItems()) do if F.matchesItem(item,id,a.tier) and not (batch and batch.sources[item]) then
      local result
      if a.source=='equip' then
        if not g_game.equipItem then return false end
        result=sent(g_game.equipItem(item))
      else
        result=sent(g_game.move(item,{x=65535,y=slot,z=0},item:getCount()))
      end
      if result and batch then batch.sources[item]=true end
      return result
    end end
  end
  return false
end
function F.ids(text)
  local ids={} for value in tostring(text or ''):gmatch('%d+') do local id=tonumber(value) if id>0 and id<=65535 then ids[id]=true end end return ids
end
function F.destinationSpecs(a)
  local entries=a.destinations
  if entries==nil then entries=a.destinationContainer~=nil and {{container=a.destinationContainer,typeId=a.destinationContainerType}} or {} end
  if type(entries)~='table' then return {} end
  local result,count={},0
  for index,entry in pairs(entries) do
    if type(index)~='number' or index%1~=0 or index<1 or index>32 or type(entry)~='table' then return {} end
    local id,typeId=tonumber(entry.container),tonumber(entry.typeId)
    if not id or id%1~=0 or id<0 or id>255 then return {} end
    if entry.typeId~=nil and (not typeId or typeId%1~=0 or typeId<1 or typeId>65535) then return {} end
    result[index]={container=id,typeId=typeId} count=count+1
  end
  for index=1,count do if not result[index] then return {} end end
  return result
end
function F.hasCycle(profile,rule)
  local a=rule.action or {}
  for item in pairs(F.ids(a.itemIds)) do
    local graph={}
    for _,r in ipairs(profile.rules or {}) do
      local b=r.action or {}
      local source=tonumber(b.sourceContainer)
      if r.enabled and r.type=='supplies_sorter' and F.ids(b.itemIds)[item] and source then
        graph[source]=graph[source] or {}
        for _,entry in ipairs(F.destinationSpecs(b)) do
          if entry.container then graph[source][entry.container]=true end
        end
      end
    end
    local seen={}
    local function reaches(node)
      if node==tonumber(a.sourceContainer) then return true end
      if seen[node] then return false end seen[node]=true
      for target in pairs(graph[node] or {}) do if reaches(target) then return true end end
      return false
    end
    for _,entry in ipairs(F.destinationSpecs(a)) do if entry.container and reaches(entry.container) then return true end end
  end
  return false
end
local function selectedBag(a,key)
  local id=tonumber(a[key])
  local bag=id and (g_game.getContainers() or {})[id]
  if not bag then return nil end
  local typeId=tonumber(a[key..'Type'])
  if typeId and (not bag:getContainerItem() or bag:getContainerItem():getId()~=typeId) then return nil end
  return bag
end
local function transferTo(context,a,sort,source,bag)
  local ids=sort and F.ids(a.itemIds) or {[tonumber(a.itemId) or 0]=true}
  local limit=NexusBot.Validation.number(a.stackLimit,100,1,10000)
  for _,item in ipairs(source:getItems()) do
    local id=item:getId()
    if ids[id] and id>0 then
      local count,position,room=0,nil,limit
      if bag then
        local items=bag:getItems()
        for index,existing in ipairs(items) do
          if existing:getId()==id and (not existing.getTier or not item.getTier or existing:getTier()==item:getTier()) then
            count=count+existing:getCount()
            if not position and (not existing.isStackable or existing:isStackable()) and existing:getCount()<limit then
              position=bag:getSlotPosition(index-1) room=limit-existing:getCount()
            end
          end
        end
        if not position and #items<bag:getCapacity() then position=bag:getSlotPosition(#items) end
      else
        local existing=context.player:getInventoryItem(InventorySlotAmmo)
        if existing and existing:getId()~=id then return false end
        count=existing and existing:getCount() or 0
        room=limit-count position={x=65535,y=InventorySlotAmmo,z=0}
      end
      local threshold=NexusBot.Validation.number(a.threshold,30,1,10000)
      local refill=NexusBot.Validation.number(a.refillTo,100,threshold,10000)
      if position and room>0 and (sort or count<threshold) then
        local amount=math.floor(math.min(item:getCount(),room,sort and room or refill-count))
        if amount>0 and g_game.move(item,position,amount)~=false then F.nextMove=context.now+600 return true end
      end
    end
  end
  return false
end
local function transfer(context,a,sort)
  if context.now<(F.nextMove or 0) then return false end
  local source=selectedBag(a,'sourceContainer')
  if not source then return false end
  if sort then
    local specs=F.destinationSpecs(a)
    if #specs>32 then return false end
    -- Fail closed for self destinations; profile-level validation also rejects longer cycles.
    for _,entry in ipairs(specs) do if tonumber(entry.container)==tonumber(a.sourceContainer) then return false end end
    for _,entry in ipairs(specs) do
      local bag=selectedBag({destinationContainer=entry.container,destinationContainerType=entry.typeId},'destinationContainer')
      if bag and bag~=source and transferTo(context,a,true,source,bag) then return true end
    end
    return false
  end
  local bag=a.destination=='container' and selectedBag(a,'destinationContainer')
  if a.destination=='container' and (not bag or bag==source) then return false end
  return transferTo(context,a,false,source,bag)
end
NexusBot.registerAction({id='ammo_refill',name='Ammo refill',execute=function(c,a) return transfer(c,a,false) end})
NexusBot.registerAction({id='supplies_sorter',name='Supplies sorter',execute=function(c,a) return transfer(c,a,true) end})
category.terminate=function()
  F.nextMove=nil F.filterProfile=nil F.blockedRules=nil F.slotLocks={}
  NexusBot.EventBus.offOwner(F) NexusBot.Actions.unregisterProvider('equipment_manager')
end
