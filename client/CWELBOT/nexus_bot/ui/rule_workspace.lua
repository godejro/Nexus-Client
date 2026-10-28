-- Shared presentation only. Category-specific fields and behaviour stay in their category files.
local U=NexusBot.UI

function U.ruleIcon(label,action)
  local icon=g_ui.createWidget(action.itemId and 'Item' or 'UIWidget',label)
  icon:setSize({width=24,height=24}) icon:setPhantom(true)
  icon:addAnchor(AnchorLeft,'parent',AnchorLeft) icon:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  if action.itemId then icon:setVirtual(true) icon:setItemId(action.itemId)
  else NexusBot.Spells.applyIcon(icon,NexusBot.Spells.get(action.spell)) end
  label:setTextOffset({x=28,y=0})
end

function U.rangeBar(parent,label,low,high,callback,color,maximum)
  maximum=maximum or 100
  low=math.max(0,math.min(maximum,tonumber(low) or 0))
  high=math.max(low,math.min(maximum,tonumber(high) or maximum))
  local box=g_ui.createWidget('Panel',parent) box:setHeight(64)
  local title=U.label(box,label) title:addAnchor(AnchorTop,'parent',AnchorTop) title:addAnchor(AnchorLeft,'parent',AnchorLeft)
  local a=g_ui.createWidget('NexusNumberInput',box) a:setId('minimum') a:setSize({width=48,height=24})
  a:addAnchor(AnchorTop,'parent',AnchorTop) a:addAnchor(AnchorRight,'parent',AnchorRight) a:setMarginRight(55)
  local b=g_ui.createWidget('NexusNumberInput',box) b:setId('maximum') b:setSize({width=48,height=24})
  b:addAnchor(AnchorTop,'parent',AnchorTop) b:addAnchor(AnchorRight,'parent',AnchorRight)
  for _,w in ipairs({a,b}) do w:setMinimum(0) w:setMaximum(maximum) end
  a:setValue(low) b:setValue(high)
  title:addAnchor(AnchorRight,'minimum',AnchorLeft) title:setMarginRight(4)
  local track=g_ui.createWidget('UIWidget',box) track:setHeight(20)
  track:addAnchor(AnchorTop,'parent',AnchorTop) track:setMarginTop(33)
  track:addAnchor(AnchorLeft,'parent',AnchorLeft) track:addAnchor(AnchorRight,'parent',AnchorRight)
  local rail=g_ui.createWidget('UIWidget',track) rail:setHeight(6) rail:setBackgroundColor('#29313e') rail:setPhantom(true)
  rail:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter) rail:addAnchor(AnchorLeft,'parent',AnchorLeft) rail:addAnchor(AnchorRight,'parent',AnchorRight)
  local fill=g_ui.createWidget('UIWidget',track) fill:setHeight(6) fill:setBackgroundColor(color or '#438fe3') fill:setPhantom(true)
  fill:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter) fill:addAnchor(AnchorLeft,'parent',AnchorLeft)
  local knobs={}
  for i=1,2 do
    local k=g_ui.createWidget('UIWidget',track) k:setSize({width=10,height=14}) k:setBackgroundColor('#edf4ff') k:setPhantom(true)
    k:addAnchor(AnchorLeft,'parent',AnchorLeft) k:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter) knobs[i]=k
  end
  local updating=false
  local function paint()
    local width=math.max(1,track:getWidth()-10)
    local x,y=math.floor(low/maximum*width),math.floor(high/maximum*width)
    knobs[1]:setMarginLeft(x) knobs[2]:setMarginLeft(y) fill:setMarginLeft(x+5) fill:setWidth(math.max(1,y-x))
  end
  local function set(which,value)
    if updating then return end
    updating=true
    value=math.max(0,math.min(maximum,math.floor(value+0.5)))
    if which==1 then low=math.min(value,high) else high=math.max(value,low) end
    a:setValue(low) b:setValue(high) paint() callback(low,high) NexusBot.Storage.touch() updating=false
  end
  a.onValueChange=function(_,v) set(1,v) end b.onValueChange=function(_,v) set(2,v) end
  local dragging
  local function valueAt(pos) return (pos.x-track:getX()-5)/math.max(1,track:getWidth()-10)*maximum end
  track.onMousePress=function(_,pos,button)
    if button~=MouseLeftButton then return false end
    local v=valueAt(pos) dragging=math.abs(v-low)<math.abs(v-high) and 1 or 2
    track:grabMouse() set(dragging,v) return true
  end
  track.onMouseMove=function(_,pos) if dragging then set(dragging,valueAt(pos)) return true end return false end
  track.onMouseRelease=function() if dragging then dragging=nil track:ungrabMouse() return true end return false end
  track.onDestroy=function() if dragging then track:ungrabMouse() dragging=nil end end
  track.onGeometryChange=paint paint()
  return box
end

function U.referenceEditor(controller,rule)
  if controller.editor and not controller.editor:isDestroyed() then controller.editor:destroy() end
  local def=controller.definition
  local w=g_ui.createWidget('NexusWindow',rootWidget)
  w:setText((def.title or def.id):upper())
  w:setSize({width=450,height=math.min(620,rootWidget:getHeight()-30)})
  local close=U.button(w,'X',function() w:destroy() end) close:setSize({width=26,height=26}) close:setColor('#fa6275')
  close:addAnchor(AnchorRight,'parent',AnchorRight) close:addAnchor(AnchorTop,'parent',AnchorTop) close:setMarginTop(-32)
  w.onEscape=function() w:destroy() end
  local tabs=g_ui.createWidget('Panel',w) tabs:setId('tabs') tabs:setHeight(30)
  tabs:addAnchor(AnchorLeft,'parent',AnchorLeft) tabs:addAnchor(AnchorRight,'parent',AnchorRight) tabs:addAnchor(AnchorTop,'parent',AnchorTop)
  tabs:setLayout(UIHorizontalLayout.create(tabs)) tabs:getLayout():setSpacing(4)
  local body=g_ui.createWidget('NexusScrollPanel',w) body:setId('fields')
  body:addAnchor(AnchorTop,'tabs',AnchorBottom) body:setMarginTop(8)
  body:addAnchor(AnchorLeft,'parent',AnchorLeft) body:addAnchor(AnchorRight,'parent',AnchorRight) body:addAnchor(AnchorBottom,'parent',AnchorBottom)
  body:setLayout(UIVerticalLayout.create(body)) body:getLayout():setSpacing(7) U.scrollbar(body)
  local buttons={} controller.editor=w controller.selectedRule=rule
  function controller:showTab(id)
    if w:isDestroyed() then return end
    self.editorTab=id U.clear(body) body:setVirtualOffset({x=0,y=0})
    for key,b in pairs(buttons) do b:setOn(id==key) end
    def.renderInspector(self,id,rule,body)
  end
  for _,tab in ipairs(def.tabs or {{'Action','action'},{'Conditions','conditions'},{'Advanced','advanced'}}) do
    local b=U.button(tabs,tab[1],function() controller:showTab(tab[2]) end)
    b:setWidth(tab[1]=='Conditions' and 100 or 86) buttons[tab[2]]=b
  end
  local p=controller.window:getPosition()
  w:setPosition({x=math.max(0,math.min(rootWidget:getWidth()-w:getWidth(),p.x+controller.window:getWidth()-25)),y=math.max(0,math.min(rootWidget:getHeight()-w:getHeight(),p.y+45))})
  w.onDestroy=function() if controller.editor==w then controller.editor=nil end end
  controller:showTab(controller.editorTab or (def.tabs and def.tabs[1][2]) or 'action')
  w:show() w:raise() w:focus()
  return w
end

function U.openReference(definition)
  definition.referenceLayout=true
  local w=U.openWorkspace(definition)
  local c=U.Controllers[definition.id]
  local refreshProfiles=c.refreshProfiles
  function c:refreshProfiles()
    local active=self:profile() local id=active and active.id
    if self.referenceProfileId~=id then
      if self.editor and not self.editor:isDestroyed() then self.editor:destroy() end
      if self.optionsEditor and not self.optionsEditor:isDestroyed() then self.optionsEditor:destroy() end
      self.selectedRule=nil self.referenceProfileId=id
    end
    return refreshProfiles(self)
  end
  w:setSize({width=math.min(960,rootWidget:getWidth()-24),height=490})
  w.inspector:hide() w.profiles:setWidth(185)
  w.profiles.current:hide()
  w.profiles.search:hide()
  w.profiles.list:addAnchor(AnchorTop,'heading',AnchorBottom)
  w.profiles.list:setMarginTop(8)
  w.actions:breakAnchors()
  w.actions:addAnchor(AnchorTop,'parent',AnchorTop) w.actions:addAnchor(AnchorBottom,'parent',AnchorBottom)
  w.actions:addAnchor(AnchorLeft,'profiles',AnchorRight) w.actions:addAnchor(AnchorRight,'parent',AnchorRight)
  w.actions:setMarginLeft(10) w.actions:setMarginRight(0)
  w.actions.hint:hide() w.actions.hint:setHeight(0)
  w.actions.list:breakAnchors()
  w.actions.search:hide() w.actions.search:setText('')
  w.actions.list:addAnchor(AnchorTop,'parent',AnchorTop) w.actions.list:setMarginTop(32)
  w.actions.list:addAnchor(AnchorBottom,'add',AnchorTop) w.actions.list:setMarginBottom(8)
  w.actions.list:addAnchor(AnchorLeft,'parent',AnchorLeft) w.actions.list:addAnchor(AnchorRight,'parent',AnchorRight)
  U.scrollbar(w.actions.list) U.scrollbar(w.profiles.list)
  local header=g_ui.createWidget('Panel',w.actions) header:setId('columnHeader') header:setHeight(27)
  header:setBackgroundColor('#18334e') header:addAnchor(AnchorTop,'parent',AnchorTop) header:setMarginTop(0)
  header:addAnchor(AnchorLeft,'parent',AnchorLeft) header:addAnchor(AnchorRight,'parent',AnchorRight)
  local columns=definition.columns or {'Type','Action','Target','Condition'}
  local function cells(parent,values)
    local result={}
    for i,text in ipairs(values) do local l=U.label(parent,tostring(text or ''),'NexusHeader') l:setPhantom(true) result[i]=l end
    local function layout()
      local total=math.max(1,parent:getWidth()-76)
      local width=total/#values
      local offset=44
      for i,l in ipairs(result) do
        local cellWidth=definition.id=='magic_shooter' and total*({0.16,0.46,0.14,0.24})[i] or width
        l:breakAnchors() l:addAnchor(AnchorLeft,'parent',AnchorLeft) l:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
        l:setMarginLeft(math.floor(offset)) l:setWidth(math.max(1,math.floor(cellWidth)-4))
        offset=offset+cellWidth
      end
    end
    parent.onGeometryChange=layout layout() return result
  end
  cells(header,columns)
  function c:renderInspector()
    if self.editor and not self.editor:isDestroyed() and self.selectedRule then self:showTab(self.editorTab or 'action') end
  end
  function c:select(rule)
    U.referenceEditor(self,rule) self:refreshRules()
  end
  function c:refreshRules()
    U.clear(w.actions.list) self.rows={}
    local query=w.actions.search:getText():lower()
    for _,rawRule in ipairs(self:rules()) do
      local rule=definition.profileAPI and rawRule or NexusBot.Validation.rule(rawRule)
      if rule then
      local d=definition.describe(rule)
      if query=='' or (tostring(d.action)..' '..tostring(d.target)..' '..tostring(d.type)):lower():find(query,1,true) then
        local row=g_ui.createWidget('NexusButton',w.actions.list) row:setHeight(50)
        row:setOn(self.selectedRule==rule)
        local data=definition.rowValues and definition.rowValues(rule) or {d.type,d.action,d.target,NexusBot.Conditions.summary(rule.conditions)}
        local labels=cells(row,data)
        local toggle=g_ui.createWidget('NexusToggle',row) toggle:setSize({width=38,height=24})
        toggle:addAnchor(AnchorLeft,'parent',AnchorLeft) toggle:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
        toggle:setOn(rule.enabled~=false)
        toggle.onClick=function() rule.enabled=not (rule.enabled~=false) NexusBot.Storage.touch() if definition.changed then definition.changed(rule) end self:refreshRules() end
        local edit=U.button(row,'>',function() self:select(rule) end) edit:setSize({width=24,height=26})
        edit:addAnchor(AnchorRight,'parent',AnchorRight) edit:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
        if definition.decorateRow then definition.decorateRow(row,labels,rule) end
        row.onClick=function() self:select(rule) end
        row.onMouseRelease=function(_,pos,button)
          if button~=MouseRightButton then return false end
          local menu=g_ui.createWidget('NexusContextMenu')
          menu:addOption(rule.enabled~=false and 'Disable' or 'Enable',toggle.onClick)
          menu:addOption('Move up',function() self:move(rule,-1) end)
          menu:addOption('Move down',function() self:move(rule,1) end)
          menu:addOption('Delete',function() if self.editor then self.editor:destroy() end self:remove(rule) end)
          menu:display(pos) return true
        end
        self.rows[#self.rows+1]={widget=row,rule=rule}
      end
      end
    end
  end
  w.actions.add.onClick=function()
    local rule=definition.newRule(c:profile()) NexusBot.Storage.touch() c:refreshRules() c:select(rule)
  end
  local destroy=w.onDestroy
  w.onDestroy=function(widget) if c.editor and not c.editor:isDestroyed() then c.editor:destroy() end if destroy then destroy(widget) end end
  local hide=w.onVisibilityChange
  w.onVisibilityChange=function(widget,visible) if not visible and c.editor and not c.editor:isDestroyed() then c.editor:destroy() end if hide then hide(widget,visible) end end
  c:refreshAll()
  return w,c
end
