-- HEALER: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('healer', 'HEALER', 1, false)

-- ==================== GUI / LAYOUT ====================
NexusBot.embeddedUI = NexusBot.embeddedUI or {}
NexusBot.embeddedUI['healer'] = [=[
NexusHealSection < NexusPanel
  height: 209
  NexusSectionLabel
    id: heading
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
  NexusScrollPanel
    id: list
    anchors.top: heading.bottom
    anchors.left: parent.left
    anchors.right: editor.left
    anchors.bottom: buttons.top
    margin-right: 8
    margin-bottom: 5
    layout:
      type: verticalBox
      spacing: 3
  Panel
    id: buttons
    anchors.left: parent.left
    anchors.right: editor.left
    margin-right: 8
    anchors.bottom: parent.bottom
    height: 25
    layout:
      type: horizontalBox
      spacing: 5
    NexusButton
      id: add
      width: 65
      height: 25
      text: + Add
  Panel
    id: editor
    anchors.top: heading.bottom
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 228
    layout:
      type: verticalBox
      spacing: 2

NexusHealRow < UIWidget
  height: 31
  image-source: @NEXUS_ASSETS@/surface
  image-border: 8
  $on:
    image-source: @NEXUS_ASSETS@/selected
  NexusMutedLabel
    id: condition
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 4
    size: 100 20
    background-color: #632636
    color: #ffffff
    text-align: center
    phantom: true
  UIItem
    id: itemIcon
    anchors.left: condition.right
    anchors.verticalCenter: parent.verticalCenter
    size: 26 26
    margin-left: 3
    virtual: true
    phantom: true
    visible: false
  UIWidget
    id: spellIcon
    anchors.left: condition.right
    anchors.verticalCenter: parent.verticalCenter
    size: 26 26
    margin-left: 3
    phantom: true
    visible: false
  NexusMutedLabel
    id: name
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 136
    margin-right: 3
    height: 29
    text-align: left
    text-wrap: false
    phantom: true

NexusWindow
  id: godejroHealer
  size: 580 520
  text: HEALER
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
    NexusButton
      id: basic
      visible: false
      anchors.top: parent.top
      anchors.left: parent.left
      width: 80
      text: Basic
    NexusButton
      id: advanced
      visible: false
      anchors.top: parent.top
      anchors.left: basic.right
      margin-left: 5
      width: 86
      text: Advanced
    NexusComboBox
      id: profile
      anchors.top: parent.top
      anchors.left: parent.left
      width: 140
    NexusButton
      id: profiles
      anchors.top: parent.top
      anchors.left: profile.right
      margin-left: 6
      width: 70
      text: Profiles
    NexusToggle
      id: master
      anchors.right: parent.right
      anchors.top: parent.top
      width: 45
  NexusMutedLabel
    id: status
    visible: false
    anchors.top: toolbar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 5
    height: 0
    text: Higher rules have priority. Closing this window does not stop healing.
  Panel
    id: basicPage
    anchors.top: toolbar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 5
    NexusHealSection
      id: spells
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
    NexusHealSection
      id: items
      anchors.top: spells.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
  Panel
    id: advancedPage
    anchors.top: status.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-top: 5
    NexusScrollPanel
      id: list
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: 195
      layout:
        type: verticalBox
        spacing: 3
    NexusScrollPanel
      id: actionFields
      anchors.top: parent.top
      anchors.left: list.right
      anchors.bottom: parent.bottom
      margin-left: 10
      width: 260
      layout:
        type: verticalBox
        spacing: 4
    NexusScrollPanel
      id: conditionFields
      anchors.top: parent.top
      anchors.left: actionFields.right
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      margin-left: 10
      layout:
        type: verticalBox
        spacing: 4
]=]

do
local U=NexusBot.UI
local metrics={{'Health %','health_percent'},{'Mana %','mana_percent'},{'Current Health','health_value'},{'Current Mana','mana_value'}}
local comparisons={{'Below','<'},{'At most','<='},{'Above','>'},{'At least','>='},{'Equal','='}}
local function compact(widget)
  local p=widget:getParent()
  p:setHeight(28)
  if p.label then p.label:setWidth(80) p.label:setHeight(26) end
  widget:setHeight(26)
  return widget
end
local function primary(rule)
  for _,c in ipairs((rule.conditions or {}).children or {}) do
    for _,metric in ipairs(metrics) do if c.type==metric[2] then return c end end
  end
end
local function kind(rule) return rule.kind=='item' and 'item' or 'spell' end

function U.openHealer(definition)
  local w=NexusBot.loadUI('healer',rootWidget)
  U.scrollbar(w.basicPage.spells.list)
  U.scrollbar(w.basicPage.items.list)
  w.toolbar.master:hide()
  local c={window=w,definition=definition,selectedRule=nil,selected={},tab='basic',rows={},groupExpanded={}}
  U.Controllers.healer=c
  function c:profile() return NexusBot.Profiles.getActive('healer') end
  function c:rules() return definition.getRules(self:profile()) end
  function c:save() NexusBot.Storage.touch() end
  function c:choose(rule)
    self.selectedRule=rule self.selected[kind(rule)]=rule
    -- Keep the clicked widget alive: OTC detects the second click on that instance.
    for _,entry in ipairs(self.rows) do
      entry.widget:setOn((self.tab=='basic' and self.selected[kind(entry.rule)] or self.selectedRule)==entry.rule)
    end
    self:renderInspector()
  end
  function c:remove(rule)
    for index,v in ipairs(self:rules()) do if v==rule then table.remove(self:rules(),index) break end end
    if self.selectedRule==rule then self.selectedRule=nil end
    if self.selected[kind(rule)]==rule then self.selected[kind(rule)]=nil end
    self:save() self:refreshAll()
  end
  function c:move(rule,delta)
    if not rule then return end
    local list=self:rules()
    for i,v in ipairs(list) do if v==rule then
      local j=i+delta
      while list[j] and kind(list[j])~=kind(rule) do j=j+delta end
      if list[j] then list[i],list[j]=list[j],list[i] end
      break
    end end
    for i,v in ipairs(list) do v.priority=i end
    self:save() self:refreshRules()
  end
  function c:row(parent,rule)
    local row=g_ui.createWidget('NexusHealRow',parent)
    local action=definition.describe(rule).action
    if kind(rule)=='item' then
      row.itemIcon:setItemId(tonumber(rule.action.itemId) or 0)
      row.itemIcon:show()
      action=''
    else
      row.spellIcon:setVisible(NexusBot.Spells.applyIcon(row.spellIcon,NexusBot.Spells.get(rule.action.spell))==true)
    end
    local condition=primary(rule)
    local mana=condition and (condition.type=='mana_percent' or condition.type=='mana_value')
    local metric=mana and 'MP' or 'HP'
    local percent=condition and (condition.type=='mana_percent' or condition.type=='health_percent')
    row.condition:setText(condition and (metric..(percent and '%' or '')..' '..condition.operator..' '..tostring(condition.value)) or 'Custom')
    row.condition:setBackgroundColor(mana and '#243f78' or '#632636')
    row.name:setText(action)
    row:setTooltip(nil)
    row:setOn((self.tab=='basic' and self.selected[kind(rule)] or self.selectedRule)==rule)
    row.name:setColor(rule.enabled~=false and '#ffffff' or '#69788b')
    local function toggle()
      rule.enabled=not (rule.enabled~=false)
      row.name:setColor(rule.enabled and '#ffffff' or '#69788b') self:save()
      if self.selectedRule==rule and self.tab=='advanced' then U.refreshAfterInput(self,rule) end
    end
    row.onDoubleClick=function() toggle() return true end
    row.onClick=function() self:choose(rule) end
    row.onMouseRelease=function(_,pos,button)
      if button~=MouseRightButton then return false end
      local menu=g_ui.createWidget('NexusContextMenu')
      menu:addOption('Move up',function() self:move(rule,-1) end)
      menu:addOption('Move down',function() self:move(rule,1) end)
      menu:addOption(rule.enabled~=false and 'Disable' or 'Enable',toggle)
      menu:addOption('Delete',function() self:remove(rule) end)
      menu:display(pos) return true
    end
    self.rows[#self.rows+1]={widget=row,rule=rule}
  end
  function c:refreshRules()
    U.clear(w.basicPage.spells.list) U.clear(w.basicPage.items.list) U.clear(w.advancedPage.list)
    self.rows={}
    local present={}
    for _,rule in ipairs(self:rules()) do present[rule]=true end
    for category,rule in pairs(self.selected) do if not present[rule] or kind(rule)~=category then self.selected[category]=nil end end
    if self.selectedRule and not present[self.selectedRule] then self.selectedRule=nil end
    for _,rule in ipairs(self:rules()) do
      NexusBot.Validation.rule(rule)
      local category=kind(rule)
      if not self.selected[category] then self.selected[category]=rule end
      if not self.selectedRule then self.selectedRule=rule end
      self:row(category=='spell' and w.basicPage.spells.list or w.basicPage.items.list,rule)
      self:row(w.advancedPage.list,rule)
    end
  end
  function c:basicEditor(parent,rule)
    U.clear(parent)
    if not rule then U.label(parent,'Add or select a rule to edit.') return end
    local condition=primary(rule) or {type='health_percent',operator='<',value=50}
    local function changed()
      if not primary(rule) then
        rule.conditions=rule.conditions or {mode='AND',children={}}
        rule.conditions.children=rule.conditions.children or {}
        rule.conditions.children[#rule.conditions.children+1]=condition
      end
      self:save() self:refreshRules()
    end
    compact(U.combo(parent,'Resource',metrics,condition.type,function(v) condition.type=v changed() end))
    compact(U.combo(parent,'Is',comparisons,condition.operator,function(v) condition.operator=v changed() end))
    compact(U.numberInput(parent,'Threshold',condition.value,0,999999,function(v) condition.value=v changed() end))
    if kind(rule)=='spell' then
      local manaField
      compact(U.textInput(parent,'Cast',rule.action.spell or '',function(v)
        rule.action.spell=v
        local spell=NexusBot.Spells.get(v)
        if spell and tonumber(spell.mana) then
          rule.advanced.minimumMana=tonumber(spell.mana)
          if manaField then manaField:setValue(rule.advanced.minimumMana) end
        end
        self:refreshRules()
      end))
      manaField=compact(U.numberInput(parent,'Mana cost',rule.advanced.minimumMana or 0,0,999999,function(v) rule.advanced.minimumMana=v end))
    else
      compact(U.numberInput(parent,'Item ID',rule.action.itemId or 0,0,65535,function(v) rule.action.itemId=v self:refreshRules() end))
    end
    local count=#((rule.conditions or {}).children or {})
    local complex=count>1 or (count>0 and not primary(rule)) or (rule.conditions or {}).mode=='OR' or condition.operator=='between' or condition.operator=='outside'
  end
  function c:renderInspector()
    if self.tab=='basic' then
      self:basicEditor(w.basicPage.spells.editor,self.selected.spell)
      self:basicEditor(w.basicPage.items.editor,self.selected.item)
      return
    end
    local left,right=w.advancedPage.actionFields,w.advancedPage.conditionFields
    U.clear(left) U.clear(right)
    local rule=self.selectedRule
    if not rule then U.label(left,'Select a healing rule.') return end
    U.section(left,'ACTION') definition.renderInspector(self,'action',rule,left)
    U.section(right,'CONDITIONS') NexusBot.Inspector.conditions(self,right,rule)
    U.section(left,'EXECUTION') NexusBot.Inspector.advanced(self,left,rule,left)
  end
  function c:refreshProfiles()
    w.toolbar.profile.onOptionChange=nil w.toolbar.profile:clearOptions()
    local profile=self:profile()
    for _,p in ipairs(NexusBot.Profiles.list('healer')) do w.toolbar.profile:addOption(p.name,p.id) end
    if profile then w.toolbar.profile:setCurrentOption(profile.name,true) end
    w.toolbar.master:setOn(profile and profile.enabled==true)
    w.toolbar.profile.onOptionChange=function(widget)
      local option=widget:getCurrentOption() if not option then return end
      NexusBot.Profiles.select('healer',option.data) self.selected={} self.selectedRule=nil self:refreshAll()
    end
  end
  function c:refreshAll() self:refreshProfiles() self:refreshRules() self:renderInspector() end
  function c:setTab(tab)
    self.tab=tab w.basicPage:setVisible(tab=='basic') w.advancedPage:setVisible(tab=='advanced')
    w.toolbar.basic:setOn(tab=='basic') w.toolbar.advanced:setOn(tab=='advanced')
    w.toolbar:hide() w.toolbar:setHeight(0)
    w:setSize(tab=='basic' and {width=580,height=492} or {width=820,height=556})
    NexusBot.WindowManager.clamp(w) self:refreshAll()
  end
  w.basicPage.spells.heading:setText('SPELL HEALING') w.basicPage.items.heading:setText('ITEM HEALING')
  for _,category in ipairs({'spell','item'}) do
    local section=category=='spell' and w.basicPage.spells or w.basicPage.items
    section.buttons.add.onClick=function()
      local rule=definition.newHealingRule(c:profile(),category)
      rule.enabled=true c:save() c:refreshRules() c:choose(rule)
    end
  end
  w.toolbar.profiles.onClick=function()
    local menu=g_ui.createWidget('NexusContextMenu')
    menu:addOption('New profile',function() U.prompt('New healing profile','Profile name',function(name)
      NexusBot.Profiles.create('healer',name,{rules={}}) c.selected={} c.selectedRule=nil c:refreshAll()
    end) end)
    menu:addOption('Rename',function() local p=c:profile() U.prompt('Rename profile','Profile name',function(name) NexusBot.Profiles.rename('healer',p.id,name) c:refreshProfiles() end,p.name) end)
    menu:addOption('Duplicate',function() NexusBot.Profiles.clone('healer',c:profile().id) c.selected={} c.selectedRule=nil c:refreshAll() end)
    menu:addOption('Delete profile',function()
      if #NexusBot.Profiles.list('healer')<=1 then return end
      NexusBot.Profiles.delete('healer',c:profile().id) c.selected={} c.selectedRule=nil c:refreshAll()
    end)
    menu:display(g_window.getMousePosition())
  end
  w.toolbar.master.onClick=function()
    local p=c:profile() p.enabled=not p.enabled
    if p.enabled then NexusBot.setEnabled(true) end
    c:save() c:refreshProfiles()
  end
  w.toolbar.master:setTooltip(nil)
  w.toolbar.basic.onClick=function() c:setTab('basic') end
  w.toolbar.advanced.onClick=function() c:setTab('advanced') end
  w.closeButton.onClick=function() w:destroy() return true end
  w.closeButton:setTooltip(nil) w.onEscape=w.closeButton.onClick
  w.onDestroy=function() NexusBot.EventBus.offOwner(c) U.Controllers.healer=nil end
  c:setTab('basic') return w
end
end
NexusBot.Features.Healer={id='healer'}

local rules, create, describe
local function renderAction(controller,parent,rule)
  NexusBot.UI.combo(parent,'Healing Type',{{'Spell Healing','spell'},{'Item Healing','item'}},rule.kind,function(value)
    rule.kind=value rule.type=value=='spell' and 'absolute_spell' or 'item' rule.action.target='self' controller:refreshAll()
  end)
  if rule.kind=='spell' then
    NexusBot.UI.spellPicker(parent,'Spell words / Enter to apply',rule.action.spell,function(value,apply)
      rule.action.spell=value
      if apply then
        local spell=NexusBot.Spells.get(value)
        if spell and tonumber(spell.mana) then rule.advanced.minimumMana=tonumber(spell.mana) end
        NexusBot.UI.refreshAfterInput(controller,rule)
      end
    end)
    NexusBot.UI.numberInput(parent,'Mana Cost',rule.advanced.minimumMana or 0,0,999999,function(value) rule.advanced.minimumMana=value end)
  else
    NexusBot.UI.itemPicker(parent,'Healing Item',rule.action.itemId,function(value) rule.action.itemId=value controller:refreshAll() end)
    NexusBot.UI.numberInput(parent,'Delay (ms)',rule.advanced.minimumDelay or 500,50,60000,function(value) rule.advanced.minimumDelay=value end)
  end
end
local definition={id='healer',title='Healer',profileDefaults={rules={}},addText='+ New Healing Rule',
  getRules=function(...) return rules(...) end,describe=function(...) return describe(...) end,newRule=function(profile) return create(profile,'spell') end,
  groupLabel=function(rule) return rule.kind=='spell' and 'SPELL HEALING' or 'ITEM HEALING' end,
  onAdd=function(controller)
    local menu=g_ui.createWidget('NexusContextMenu')
    menu:addOption('New Spell Healing Rule',function() controller.selectedRule=create(controller:profile(),'spell') NexusBot.Storage.touch() controller:refreshAll() end)
    menu:addOption('New Item Healing Rule',function() controller.selectedRule=create(controller:profile(),'item') NexusBot.Storage.touch() controller:refreshAll() end)
    menu:display(g_window.getMousePosition())
  end,
  renderInspector=function(controller,tab,rule,parent)
    if tab=='action' then renderAction(controller,parent,rule)
    elseif tab=='conditions' then NexusBot.Inspector.conditions(controller,parent,rule)
    elseif tab=='pattern' then NexusBot.UI.label(parent,'Healing rules target the local player; no positioning pattern is required.')
    else NexusBot.Inspector.advanced(controller,parent,rule) end
  end}
definition.newHealingRule=function(...) return create(...) end
definition.open=function() NexusBot.Profiles.ensure('healer',{rules={}}) return NexusBot.UI.openHealer(definition) end


-- ==================== LOGIC / RUNTIME ====================
rules=function(profile)
  profile.rules=profile.rules or {}
  return profile.rules
end
create=function(profile,kind)
  local list=rules(profile)
  local rule={id=NexusBot.id('heal'),kind=kind,type=kind=='spell' and 'absolute_spell' or 'item',enabled=true,priority=#list+1,
    action=kind=='spell' and {spell='exura',target='self'} or {itemId=0,target='self'},
    conditions={mode='AND',children={{type='health_percent',operator='<',value=50}}},
    advanced={minimumDelay=kind=='spell' and 250 or 500,onlyIfCooldownReady=true,minimumMana=0,minimumHP=0}}
  if kind=='spell' then
    local spell=NexusBot.Spells.get(rule.action.spell)
    if spell and tonumber(spell.mana) then rule.advanced.minimumMana=tonumber(spell.mana) end
  end
  list[#list+1]=rule return rule
end
describe=function(rule)
  rule.action=type(rule.action)=='table' and rule.action or {}
  rule.kind=rule.kind=='item' and 'item' or 'spell'
  local value=rule.kind=='spell' and (rule.action.spell or 'No spell') or ('Item '..tostring(rule.action.itemId or 0))
  return {type=rule.kind=='spell' and 'Spell Healing' or 'Item Healing',action=value,target='Self'}
end
function NexusBot.Features.Healer.init()
  NexusBot.Profiles.ensure('healer',{rules={}}) NexusBot.registerModule(definition)
  NexusBot.Actions.registerProvider('healer',10,function()
    local profile=NexusBot.Profiles.getActive('healer') return profile and profile.enabled and profile.rules or {}
  end)
end

category.init = NexusBot.Features.Healer.init
NexusBot.Categories.profilePower(category)
