NexusBot.Inspector = {}

local conditionOptions
local function getConditionOptions()
  if conditionOptions then return conditionOptions end
  conditionOptions = {}
  for _, definition in ipairs(NexusBot.ConditionRegistry.all()) do
    conditionOptions[#conditionOptions + 1] = { text=definition.name, data=definition.id }
  end
  return conditionOptions
end

local operatorOptions = {
  {'Below','<'},{'At most','<='},{'Equal','='},{'At least','>='},{'Above','>'},{'Between','between'},{'Outside','outside'}
}

local function removeChild(group, child)
  for index, current in ipairs(group.children or {}) do
    if current == child then table.remove(group.children, index) return end
  end
end

local function renderCondition(controller, parent, group, condition)
  local row = g_ui.createWidget('NexusConditionRow', parent)
  local definition = NexusBot.ConditionRegistry.get(condition.type)
  for _, option in ipairs(getConditionOptions()) do row.type:addOption(option.text, option.data) end
  for _, option in ipairs(operatorOptions) do row.operator:addOption(option[1], option[2]) end
  if definition then row.type:setCurrentOption(definition.name, true) end
  for _, option in ipairs(operatorOptions) do if option[2] == condition.operator then row.operator:setCurrentOption(option[1], true) end end
  row.value:setValue(tonumber(condition.value) or 0)
  row.value2:setValue(tonumber(condition.value2) or 100)
  if definition and definition.boolean then
    row.operator:hide() row.value:hide() row.value2:hide()
  elseif condition.operator ~= 'between' and condition.operator ~= 'outside' then
    row.value2:hide()
  end
  local arranging=false
  local function arrange()
    if arranging then return end
    arranging=true
    local width=row:getWidth()
    local range=condition.operator=='between' or condition.operator=='outside'
    if definition and definition.boolean then
      row:setHeight(28)
    elseif range and width<210 then
      row:setHeight(92)
      row.operator:setWidth(math.max(70,width))
      row.value:breakAnchors()
      row.value:addAnchor(AnchorLeft,'parent',AnchorLeft)
      row.value:addAnchor(AnchorTop,'operator',AnchorBottom)
      row.value:setMarginLeft(0) row.value:setMarginTop(3)
      row.value:setWidth(math.max(42,math.floor((width-4)/2)))
      row.value2:breakAnchors()
      row.value2:addAnchor(AnchorLeft,'value',AnchorRight)
      row.value2:addAnchor(AnchorRight,'parent',AnchorRight)
      row.value2:addAnchor(AnchorTop,'value',AnchorTop)
      row.value2:setMarginLeft(4)
    else
      row:setHeight(60) row.operator:setWidth(math.min(94,math.floor(width*0.45)))
      row.value:breakAnchors()
      row.value:addAnchor(AnchorLeft,'operator',AnchorRight)
      row.value:addAnchor(AnchorTop,'operator',AnchorTop)
      row.value:setMarginLeft(4) row.value:setMarginTop(0)
      row.value:setWidth(math.max(42,range and math.floor((width-row.operator:getWidth()-8)/2) or width-row.operator:getWidth()-4))
      row.value2:breakAnchors()
      row.value2:addAnchor(AnchorLeft,'value',AnchorRight)
      row.value2:addAnchor(AnchorRight,'parent',AnchorRight)
      row.value2:addAnchor(AnchorTop,'value',AnchorTop)
      row.value2:setMarginLeft(4)
    end
    arranging=false
  end
  row.onGeometryChange=arrange
  arrange()
  row.type.onOptionChange=function(widget)
    local option=widget:getCurrentOption() if not option then return end
    condition.type=option.data
    local selected=NexusBot.ConditionRegistry.get(condition.type)
    condition.value=selected and selected.boolean and true or (tonumber(condition.value) or 50)
    if condition.type=='cooldown_ready' then condition.actionId=controller.selectedRule and controller.selectedRule.id end
    NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules()
  end
  row.operator.onOptionChange=function(widget)
    local option=widget:getCurrentOption()
    if option then condition.operator=option.data NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules() end
  end
  row.value.onValueChange=function(_,value) condition.value=value NexusBot.Storage.touch() controller:refreshRules() end
  row.value2.onValueChange=function(_,value) condition.value2=value NexusBot.Storage.touch() controller:refreshRules() end
  row.remove.onClick=function() removeChild(group,condition) NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules() end
  if condition.type=='monster_count' or condition.type=='player_count' or condition.type=='creature_count' then
    NexusBot.UI.numberInput(parent,'Count radius',condition.radius or 5,1,10,function(value) condition.radius=value end)
  end
end

local function renderGroup(controller, parent, group, owner, depth)
  depth=depth or 0
  controller.groupExpanded=controller.groupExpanded or {}
  if owner then
    local box=g_ui.createWidget('NexusConditionGroup',parent)
    parent=box
    local expanded=controller.groupExpanded[group]==true
    NexusBot.UI.button(parent,(expanded and '- ' or '+ ')..'Group '..tostring(depth)..' / '..(group.mode or 'AND')..' / '..#(group.children or {})..' conditions',function()
      controller.groupExpanded[group]=not expanded controller:renderInspector()
    end)
    NexusBot.UI.button(parent,'Remove this group',function()
      removeChild(owner,group) controller.groupExpanded[group]=nil NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules()
    end)
    if not expanded then return end
  end
  NexusBot.UI.combo(parent, 'Match', {{'ALL (AND)','AND'},{'ANY (OR)','OR'}}, group.mode or 'AND', function(value)
    group.mode=value controller:refreshRules()
  end)
  for _, child in ipairs(group.children or {}) do
    if child.type == 'group' then renderGroup(controller,parent,child,group,depth+1) else renderCondition(controller,parent,group,child) end
  end
  NexusBot.UI.button(parent,'+ Add Condition',function()
    group.children=group.children or {}
    group.children[#group.children+1]={type='health_percent',operator='<',value=50}
    NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules()
  end,true)
  if depth>=3 then return end
  NexusBot.UI.button(parent,'+ Add Nested Group',function()
    group.children=group.children or {}
    group.children[#group.children+1]={type='group',mode='AND',children={}}
    NexusBot.Storage.touch() controller:renderInspector() controller:refreshRules()
  end)
end

function NexusBot.Inspector.conditions(controller, parent, rule)
  rule.conditions=rule.conditions or {mode='AND',children={}}
  renderGroup(controller,parent,rule.conditions,nil,0)
end

function NexusBot.Inspector.pattern(controller, parent, rule)
  rule.pattern=rule.pattern or {mode='target',direction=North,x=0,y=0,z=0}
  if rule.type=='directional_spell' then
    rule.pattern.mode='direction'
    if rule.pattern.autoFace==nil then rule.pattern.autoFace=true end
    NexusBot.UI.toggle(parent,'Automatically face target',rule.pattern.autoFace~=false,function(value) rule.pattern.autoFace=value end)
    NexusBot.UI.combo(parent,'Direction',{{'North',North},{'East',East},{'South',South},{'West',West}},rule.pattern.direction,function(value) rule.pattern.direction=value rule.action.direction=value end)
    NexusBot.UI.numberInput(parent,'Monster detection radius',rule.pattern.radius or rule.advanced.range or 5,1,10,function(value)
      rule.pattern.radius=value
      for _,condition in ipairs((rule.conditions and rule.conditions.children) or {}) do if condition.autoSpellPreset then condition.radius=value end end
    end)
  elseif rule.type=='area_spell' then
    rule.pattern.mode='area_pattern'
    NexusBot.UI.numberInput(parent,'Monster detection radius',rule.pattern.radius or rule.advanced.range or 5,1,10,function(value)
      rule.pattern.radius=value
      for _,condition in ipairs((rule.conditions and rule.conditions.children) or {}) do if condition.autoSpellPreset then condition.radius=value end end
    end)
    NexusBot.UI.label(parent,'The radius is used by the automatic monster-count condition.')
  elseif rule.type=='rune' or rule.type=='item' then
    NexusBot.UI.combo(parent,'Targeting mode',{{'Current target','target'},{'Self','self'}},rule.action.target or 'target',function(value)
      rule.pattern.mode=value rule.action.target=value controller:refreshRules()
    end)
  else
    rule.pattern.mode='target'
    NexusBot.UI.label(parent,'This spell is cast through its words; targeting behavior is defined by the server spell.')
  end
end

function NexusBot.Inspector.advanced(controller,parent,rule,secondary)
  rule.advanced=rule.advanced or {}
  secondary=secondary or parent
  NexusBot.UI.toggle(parent,'Enabled',rule.enabled~=false,function(value) rule.enabled=value controller:refreshRules() end)
  NexusBot.UI.numberInput(secondary,'Priority / order',rule.priority or 100,1,9999,function(value) rule.priority=value controller:refreshRules() end)
  NexusBot.UI.numberInput(parent,'Delay (ms)',rule.advanced.minimumDelay or 250,50,60000,function(value) rule.advanced.minimumDelay=value end)
  NexusBot.UI.numberInput(secondary,'Extra delay (ms)',rule.advanced.customDelay or 0,0,60000,function(value) rule.advanced.customDelay=value end)
  NexusBot.UI.toggle(parent,'Requires target',rule.advanced.requiresTarget==true,function(value) rule.advanced.requiresTarget=value end,'Skipped when there is no attack target.')
  NexusBot.UI.toggle(secondary,'Stop without target',rule.advanced.stopWhenNoTarget==true,function(value) rule.advanced.stopWhenNoTarget=value end)
  NexusBot.UI.toggle(parent,'Only if cooldown ready',rule.advanced.onlyIfCooldownReady~=false,function(value) rule.advanced.onlyIfCooldownReady=value end)
  NexusBot.UI.numberInput(parent,'Target range',rule.advanced.range or 99,0,99,function(value) rule.advanced.range=value end)
  NexusBot.UI.numberInput(parent,'Minimum mana',rule.advanced.minimumMana or 0,0,999999,function(value) rule.advanced.minimumMana=value end)
  NexusBot.UI.numberInput(secondary,'Minimum HP',rule.advanced.minimumHP or 0,0,999999,function(value) rule.advanced.minimumHP=value end)
  if controller.definition.id~='magic_shooter' then
    NexusBot.UI.textInput(secondary,'Vocation IDs',rule.advanced.vocations or '',function(value) rule.advanced.vocations=value end)
    NexusBot.UI.toggle(secondary,'Debug this action',rule.advanced.debug==true,function(value) rule.advanced.debug=value end)
  end
end
