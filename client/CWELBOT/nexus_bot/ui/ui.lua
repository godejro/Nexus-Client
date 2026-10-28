-- All category and rule switches share the same solid, accessible capsule.
function NexusBot.UI.configureSwitch(widget)
  local nativeSetOn=widget.setOn
  local nativeSetText=widget.setText
  local function refresh(self)
    if self:isDestroyed() or not self.dot then return end
    local on=self:isOn()
    self.dot:setImageColor(on and '#53cfff' or '#899bb1')
    self.dot:setMarginLeft(on and math.max(2,self:getWidth()-16) or 2)
  end
  widget.setOn=function(self,value) nativeSetOn(self,value==true) refresh(self) end
  widget.setText=function(self,text) nativeSetText(self,(text=='ON' or text=='OFF') and '' or text) end
  widget.onGeometryChange=refresh
  widget.onStyleApply=refresh
  refresh(widget)
end

NexusBot.UI.Controllers = {}

function NexusBot.UI.prompt(title, label, callback, defaultValue)
  NexusBot.WindowManager.close('input_prompt')
  local window=NexusBot.loadUI('prompt',rootWidget)
  window:setText(title or 'Input')
  window.message:setText(label or '')
  window.value:setText(defaultValue or '')
  local function accept()
    local value=window.value:getText()
    if value=='' then return end
    window:destroy()
    callback(value)
  end
  window.buttons.ok.onClick=accept
  window.buttons.cancel.onClick=function() window:destroy() end
  window.value.onEnter=accept
  window.value.onKeyPress=function(_,key)
    if key==(KeyEnter or 5) then accept() return true end
    return false
  end
  window:show()
  window:raise()
  window:focus()
  window.value:focus()
  NexusBot.WindowManager.attach('input_prompt',window)
  return window
end

local function clear(widget)
  if not widget then return end
  local children = widget:getChildren()
  for _, child in ipairs(children) do child:destroy() end
end
NexusBot.UI.clear = clear

function NexusBot.UI.scrollbar(list)
  if list.verticalScrollBar then return list.verticalScrollBar end
  local bar=g_ui.createWidget('NexusVerticalScrollBar',list:getParent())
  if list:getId()=='' then list:setId(NexusBot.id('scrollList')) end
  bar:addAnchor(AnchorTop,list:getId(),AnchorTop)
  bar:addAnchor(AnchorBottom,list:getId(),AnchorBottom)
  bar:addAnchor(AnchorRight,list:getId(),AnchorRight)
  bar:setWidth(8) bar:setStep(32) bar.pixelsScroll=true
  list:setPaddingRight(12)
  list:setVerticalScrollBar(bar)
  list.onMouseWheel=UIScrollArea.onMouseWheel
  local previousHeightChange=list.onScrollHeightChange
  list.onScrollHeightChange=function(self)
    if previousHeightChange then previousHeightChange(self) end
    if not bar:isDestroyed() then bar:setVisible(bar:getMaximum()>bar:getMinimum()) end
  end
  connect(list,{onDestroy=function()
    local parent=bar:getParent()
    if not bar:isDestroyed() and (not parent or not parent:isDestroyed()) then bar:destroy() end
  end})
  bar:setVisible(bar:getMaximum()>bar:getMinimum())
  return bar
end

function NexusBot.UI.label(parent, text, style)
  local widget = g_ui.createWidget(style or 'NexusMutedLabel', parent)
  widget:setText(text or '')
  widget:setHeight(18)
  return widget
end

-- One name per row; the persisted string remains compatible with old configs.
function NexusBot.UI.nameList(parent,value,callback,height)
  local U=NexusBot.UI
  local names,seen={},{}
  for name in tostring(value or ''):gmatch('[^,;\n]+') do
    name=name:match('^%s*(.-)%s*$')
    if name~='' and not seen[name:lower()] then names[#names+1]=name seen[name:lower()]=true end
  end
  local input=U.textInput(parent,'Name','',function() end)
  local render,list
  local function save() callback(table.concat(names,'\n')) NexusBot.Storage.touch() end
  local function add()
    local name=input:getText():match('^%s*(.-)%s*$')
    if name=='' or #name>80 or name:find('[,;\r\n]') then return end
    for _,existing in ipairs(names) do if existing:lower()==name:lower() then return end end
    names[#names+1]=name input:setText('') save() render()
  end
  U.button(parent,'+ Add',add)
  input.onEnter=add
  list=U.compactList(parent,height or 170)
  render=function()
    U.clear(list)
    for index,name in ipairs(names) do
      local row=g_ui.createWidget('Panel',list) row:setHeight(26)
      local remove=U.button(row,'X',function() table.remove(names,index) save() render() end)
      remove:setId('remove') remove:setSize({width=24,height=24})
      remove:addAnchor(AnchorRight,'parent',AnchorRight) remove:addAnchor(AnchorTop,'parent',AnchorTop)
      local label=U.label(row,name)
      label:addAnchor(AnchorLeft,'parent',AnchorLeft) label:addAnchor(AnchorRight,'remove',AnchorLeft)
      label:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter) label:setTextAlign(AlignLeft)
    end
  end
  render() return list
end

function NexusBot.UI.editNames(title,value,callback)
  local key='names_'..title:gsub('%W','_')
  NexusBot.WindowManager.close(key)
  local w,p=NexusBot.Features.Modern.shared.formWindow(title,310)
  w:setWidth(310)
  NexusBot.UI.nameList(p,value,callback,170)
  return NexusBot.WindowManager.attach(key,w)
end

function NexusBot.UI.section(parent, text)
  local widget = g_ui.createWidget('NexusSectionLabel', parent)
  widget:setText(text)
  return widget
end

function NexusBot.UI.compactList(parent, height)
  local frame=g_ui.createWidget('Panel',parent)
  frame:setHeight(height)
  local list=g_ui.createWidget('NexusScrollPanel',frame)
  list:setId('list') list:fill('parent')
  list:setLayout(UIVerticalLayout.create(list))
  list:getLayout():setSpacing(3)
  list:setTooltip(nil)
  NexusBot.UI.scrollbar(list)
  return list
end

function NexusBot.UI.button(parent, text, callback, accent)
  local widget = g_ui.createWidget(accent and 'NexusAccentButton' or 'NexusButton', parent)
  widget:setText(text)
  widget.onClick = callback
  return widget
end

function NexusBot.UI.actionColor(widget,color)
  widget:mergeStyle({color=color,['$hover !disabled']={color=color},['$on']={color=color},['$focus']={color=color},['$!focus']={color=color}})
end

function NexusBot.UI.textInput(parent, label, value, callback)
  local panel = g_ui.createWidget('NexusFieldRow', parent)
  panel.label:setText(label) panel.label:setTooltip(nil)
  local widget = g_ui.createWidget('NexusTextInput', panel)
  widget:addAnchor(AnchorLeft,'label',AnchorRight) widget:addAnchor(AnchorRight,'parent',AnchorRight)
  widget:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  widget:setText(tostring(value or ''))
  widget.onTextChange = function(_, text) callback(text) NexusBot.Storage.touch() end
  return widget
end

function NexusBot.UI.configureNumber(w)
  w:setFocusable(true) w:setValidCharacters('0123456789-')
  w.nexusMinimum=0 w.nexusMaximum=999999 w.nexusValue=0
  w.setMinimum=function(self,v) self.nexusMinimum=tonumber(v) or 0 end
  w.setMaximum=function(self,v) self.nexusMaximum=tonumber(v) or 999999 end
  w.getValue=function(self) return self.nexusValue end
  local function commit(self,value)
    value=math.max(self.nexusMinimum,math.min(self.nexusMaximum,value))
    if value==self.nexusValue then return end
    self.nexusValue=value
    if self.onValueChange then self:onValueChange(value) end
  end
  w.setValue=function(self,v)
    local value=math.max(self.nexusMinimum,math.min(self.nexusMaximum,tonumber(v) or self.nexusMinimum))
    self:setText(tostring(value)) commit(self,value)
  end
  w.onTextChange=function(self,text)
    local value=tonumber(text)
    -- Keep intermediate text/cursor untouched. Every numeric edit commits immediately.
    if value and value==value and value%1==0 then commit(self,value) end
  end
  w.onFocusChange=function(self,focused)
    if not focused then self:setValue(tonumber(self:getText()) or self.nexusValue) end
  end
end

function NexusBot.UI.numberInput(parent, label, value, minimum, maximum, callback)
  local panel = g_ui.createWidget('NexusFieldRow', parent)
  panel.label:setText(label) panel.label:setTooltip(nil)
  local widget = g_ui.createWidget('NexusNumberInput', panel)
  widget:setId('number')
  widget:addAnchor(AnchorRight,'parent',AnchorRight) widget:setWidth(84)
  widget:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  panel.label:addAnchor(AnchorRight,'number',AnchorLeft) panel.label:setMarginRight(6)
  widget:setMinimum(minimum or 0)
  widget:setMaximum(maximum or 999999)
  widget:setValue(tonumber(value) or minimum or 0)
  widget.onValueChange = function(_, current) callback(current) NexusBot.Storage.touch() end
  return widget
end

function NexusBot.UI.combo(parent, label, options, selected, callback)
  local panel = g_ui.createWidget('NexusFieldRow', parent)
  panel.label:setText(label) panel.label:setTooltip(nil)
  local widget = g_ui.createWidget('NexusComboBox', panel)
  widget:addAnchor(AnchorLeft,'label',AnchorRight) widget:addAnchor(AnchorRight,'parent',AnchorRight)
  widget:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  local selectedText
  for _, option in ipairs(options) do
    local text, data = option.text or option[1] or tostring(option), option.data or option[2] or option
    widget:addOption(text, data)
    if data == selected then selectedText = text end
  end
  if selectedText then widget:setCurrentOption(selectedText, true) end
  widget.onOptionChange = function(current)
    local option = current:getCurrentOption()
    if option then callback(option.data) NexusBot.Storage.touch() end
  end
  return widget
end

function NexusBot.UI.toggle(parent, label, value, callback, tooltip)
  local state=value==true
  local panel = g_ui.createWidget('Panel', parent)
  panel:setHeight(25)
  local text = g_ui.createWidget('NexusMutedLabel', panel)
  text:setText(label)
  text:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  text:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  local widget = g_ui.createWidget('NexusToggle', panel)
  widget:setId('toggle')
  text:addAnchor(AnchorRight,'toggle',AnchorLeft)
  text:setMarginRight(5)
  text:setTooltip(nil)
  widget:addAnchor(AnchorRight, 'parent', AnchorRight)
  widget:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  widget:setOn(state)
  if tooltip then widget:setTooltip(nil) end
  widget.onClick = function(current)
    state=not current:isOn()
    current:setOn(state)
    callback(state)
    NexusBot.Storage.touch()
  end
  widget.container=panel
  return widget
end

function NexusBot.UI.itemPicker(parent, label, itemId, callback)
  NexusBot.UI.label(parent, label)
  local panel = g_ui.createWidget('Panel', parent)
  panel:setHeight(38)
  local item = g_ui.createWidget('Item', panel)
  item:setId('selectedItem')
  item:setVirtual(true) item:setItemId(tonumber(itemId) or 0) item:setSize({width=32,height=32})
  item:addAnchor(AnchorLeft, 'parent', AnchorLeft) item:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  local selected = NexusBot.Items.get(itemId)
  local name = g_ui.createWidget('NexusMutedLabel', panel)
  name:setText(selected and (selected.name .. ' [' .. selected.id .. ']') or 'No item selected')
  name:addAnchor(AnchorLeft, item:getId(), AnchorRight) name:setMarginLeft(7)
  name:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  local button = g_ui.createWidget('NexusButton', panel)
  button:setText('SELECT') button:setWidth(58)
  button:addAnchor(AnchorRight, 'parent', AnchorRight) button:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  button:setId('pickButton') name:addAnchor(AnchorRight,'pickButton',AnchorLeft) name:setMarginRight(4)
  name:setTooltip(nil)
  button.onClick = function()
    NexusBot.UI.openItemSelector(itemId, function(entry) callback(entry.id) NexusBot.Storage.touch() end)
  end
  return panel
end

function NexusBot.UI.spellPicker(parent, label, words, callback)
  NexusBot.UI.label(parent, label)
  local panel = g_ui.createWidget('NexusSpellPickerRow', parent)
  local spell = NexusBot.Spells.get(words)
  local input=panel.words
  input:setText(tostring(words or ''))
  input:setTooltip(nil)
  local lastValue=tostring(words or '')
  local function commit()
    if input:isDestroyed() then return end
    local value=input:getText():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' '):lower()
    if value=='' or value==lastValue then return end
    lastValue=value callback(value,true) NexusBot.Storage.touch()
  end
  input.onTextChange=function(_,value) callback(value,false) NexusBot.Storage.touch() end
  input.onEnter=commit
  input.onKeyPress=function(_,key)
    if key==(KeyEnter or 5) then commit() return true end
    return false
  end
  input.onFocusChange=function(_,focused)
    if not focused then commit() end
  end
  input:setTooltip(nil)
  return panel
end

function NexusBot.UI.refreshAfterInput(controller,rule)
  NexusBot.Scheduler.after(25,function()
    if controller.window:isDestroyed() then return end
    controller:refreshRules()
    if controller.selectedRule==rule then controller:renderInspector() end
  end,'Spell editor')
end

local function profileMenu(controller, profile)
  local Profiles=controller.definition.profileAPI or NexusBot.Profiles
  local function run(callback)
    local ok,err=pcall(callback)
    if not ok then displayErrorBox('Profiles',tostring(err)) end
    return ok
  end
  local menu = g_ui.createWidget('NexusContextMenu')
  menu:addOption('Rename', function()
    NexusBot.UI.prompt('Rename profile', 'New name:', function(name)
      if not run(function() Profiles.rename(controller.definition.id, profile.id, name) end) then return end
      controller:refreshProfiles()
    end)
  end)
  menu:addOption('Duplicate', function() if run(function() Profiles.clone(controller.definition.id, profile.id) end) then controller:refreshAll() end end)
  menu:addOption('Delete', function()
    local ok, errorMessage = Profiles.delete(controller.definition.id, profile.id)
    if not ok then displayErrorBox('NexusBot', errorMessage) end
    controller:refreshAll()
  end)
  menu:display(g_window.getMousePosition())
end

function NexusBot.UI.openWorkspace(definition)
  local Profiles=definition.profileAPI or NexusBot.Profiles
  local window = NexusBot.loadUI('workspace', rootWidget)
  window:setText(definition.title)
  local available=g_ui.getRootWidget():getWidth()
  if available>=900 and available<1144 then
    window:setWidth(available-16)
    window.profiles:setWidth(132)
    window.inspector:setWidth(456)
    window.inspector.actionFields:setWidth(210)
  end
  local controller = { window=window, definition=definition, selectedRule=nil, rows={} }
  NexusBot.UI.Controllers[definition.id] = controller

  function controller:profile()
    return Profiles.getActive(self.definition.id)
  end
  function controller:rules()
    local profile = self:profile()
    return profile and self.definition.getRules(profile) or {}
  end
  function controller:refreshProfiles()
    clear(window.profiles.list)
    local query = window.profiles.search:getText():lower()
    local active = self:profile()
    window.profiles.current:setText(active and active.name or 'No profile')
    window.profiles.master:setOn(active and active.enabled == true)
    for _, profile in ipairs(Profiles.list(self.definition.id)) do
      if query == '' or profile.name:lower():find(query, 1, true) then
        local row = g_ui.createWidget('NexusProfileRow', window.profiles.list)
        row.name:setText(profile.name)
        row:setOn(active and active.id == profile.id)
        row.onClick = function() if self.editor then self.editor:destroy() end Profiles.select(self.definition.id, profile.id) self.selectedRule=nil self:refreshAll() end
        row.onMouseRelease = function(_, pos, button)
          if button == MouseRightButton then profileMenu(self, profile) return true end
        end
      end
    end
  end
  function controller:move(rule, delta)
    local rules = self:rules()
    for index, current in ipairs(rules) do
      if current == rule then
        local target = math.max(1, math.min(#rules, index + delta))
        if target ~= index then table.remove(rules, index) table.insert(rules, target, rule) end
        for order, entry in ipairs(rules) do entry.priority = order end
        NexusBot.Storage.touch() self:refreshRules() return
      end
    end
  end
  function controller:remove(rule)
    local rules = self:rules()
    for index, current in ipairs(rules) do if current == rule then table.remove(rules, index) break end end
    if self.selectedRule == rule then self.selectedRule = nil end
    NexusBot.Storage.touch() self:refreshRules() self:renderInspector()
  end
  function controller:select(rule)
    if self.selectedRule == rule then return end
    self.selectedRule = rule
    for _,entry in ipairs(self.rows) do entry.widget:setOn(entry.rule==rule) end
    self:renderInspector()
  end
  function controller:refreshRules()
    clear(window.actions.list)
    self.rows={}
    local query = window.actions.search:getText():lower()
    local found = 0
    local lastGroup = nil
    for _, rawRule in ipairs(self:rules()) do
      local rule = NexusBot.Validation.rule(rawRule)
      if rule then
      local description = self.definition.describe(rule)
      local haystack = (description.type .. ' ' .. description.action):lower()
      if query == '' or haystack:find(query, 1, true) then
        local group = self.definition.groupLabel and self.definition.groupLabel(rule) or nil
        if group and group ~= lastGroup then NexusBot.UI.section(window.actions.list, group) lastGroup=group end
        found = found + 1
        local row = g_ui.createWidget('NexusRuleRow', window.actions.list)
        row.actionLabel:setText(description.action)
        if definition.id=='magic_shooter' then
          local icon=g_ui.createWidget('UIWidget',row)
          icon:setSize({width=26,height=26}) icon:setPhantom(true)
          icon:addAnchor(AnchorLeft,'parent',AnchorLeft) icon:setMarginLeft(12)
          icon:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
          NexusBot.Spells.applyIcon(icon,NexusBot.Spells.get((rule.action or {}).spell))
          row.actionLabel:setMarginLeft(44)
        end
        row.conditionLabel:setText(NexusBot.Conditions.summary(rule.conditions))
        row:setTooltip(nil)
        local function paint()
          row.state:setBackgroundColor(rule.enabled~=false and '#4fd8a5' or '#536780')
          row.actionLabel:setColor(rule.enabled~=false and '#edf4ff' or '#7d8aa0')
        end
        local function toggle()
          rule.enabled=not (rule.enabled~=false) paint() NexusBot.Storage.touch()
          if self.selectedRule==rule then NexusBot.UI.refreshAfterInput(self,rule) end
        end
        paint() row:setOn(self.selectedRule==rule)
        self.rows[#self.rows+1]={widget=row,rule=rule}
        row.onClick=function() self:select(rule) end
        row.onDoubleClick=function() toggle() return true end
        row.onMouseRelease=function(_,pos,button)
          if button~=MouseRightButton then return false end
          local menu=g_ui.createWidget('NexusContextMenu')
          menu:addOption(rule.enabled~=false and 'Disable' or 'Enable',toggle)
          menu:addOption('Move up',function() self:move(rule,-1) end)
          menu:addOption('Move down',function() self:move(rule,1) end)
          menu:addOption('Delete',function() self:remove(rule) end)
          menu:display(pos) return true
        end
      end
      end
    end
  end
  function controller:renderInspector()
    clear(window.inspector.actionFields) clear(window.inspector.conditionFields)
    if not self.selectedRule then return end
    if self.definition.singlePageInspector then
      self.definition.renderInspector(self,'all',self.selectedRule,window.inspector.actionFields)
      return
    end
    NexusBot.UI.section(window.inspector.actionFields,'ACTION')
    self.definition.renderInspector(self,'action',self.selectedRule,window.inspector.actionFields)
    NexusBot.UI.section(window.inspector.conditionFields,'CONDITIONS')
    NexusBot.Inspector.conditions(self,window.inspector.conditionFields,self.selectedRule)
    NexusBot.UI.section(window.inspector.actionFields,'EXECUTION')
    NexusBot.UI.section(window.inspector.conditionFields,'LIMITS')
    NexusBot.Inspector.advanced(self,window.inspector.actionFields,self.selectedRule,window.inspector.conditionFields)
  end
  function controller:refreshAll() self:refreshProfiles() self:refreshRules() self:renderInspector() end

  window.closeButton.onClick=function()
    if not window:isDestroyed() then window:destroy() end
    return true
  end
  window.closeButton:setPhantom(false)
  window.closeButton:setEnabled(true)
  window.closeButton:raise()
  window.profiles.add.onClick=function()
    NexusBot.UI.prompt('New profile', 'Profile name:', function(name)
      local ok,err=pcall(Profiles.create,definition.id,name,definition.profileDefaults)
      if not ok then displayErrorBox('Profiles',tostring(err)) return end
      controller.selectedRule=nil controller:refreshAll()
    end)
  end
  window.profiles.master.onClick=function(toggle)
    local profile=controller:profile()
    if profile then
      local enabled=not (profile.enabled==true)
      local category=NexusBot.Categories.entries[definition.id]
      if category and category.setEnabled then NexusBot.Categories.setEnabled(category,enabled)
      elseif definition.setEnabled then definition.setEnabled(enabled)
      else profile.enabled=enabled if enabled then NexusBot.setEnabled(true) end end
      toggle:setOn(controller:profile().enabled==true) NexusBot.Storage.touch()
    end
  end
  window.profiles.search.onTextChange=function() controller:refreshProfiles() end
  window.actions.search.onTextChange=function() controller:refreshRules() end
  window.actions.add:setText(definition.addText or '+ New Rule')
  window.actions.add.onClick=function()
    if definition.onAdd then return definition.onAdd(controller) end
    local rule=definition.newRule(controller:profile())
    controller.selectedRule=rule NexusBot.Storage.touch() controller:refreshAll()
  end
  window.onEscape=window.closeButton.onClick
  NexusBot.EventBus.on('profilesChanged', controller, function(id) if id==definition.id then controller:refreshAll() end end)
  local previousDestroy=window.onDestroy
  window.onDestroy=function(widget) NexusBot.EventBus.offOwner(controller) NexusBot.UI.Controllers[definition.id]=nil if previousDestroy then previousDestroy(widget) end end
  if definition.referenceLayout then controller:refreshProfiles() else controller:refreshAll() end
  return window
end
