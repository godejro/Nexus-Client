NexusBot.Integrations={}
local function safe(callback, fallback)
  local ok, value=pcall(callback)
  if ok then return value end
  return fallback
end

local function showWidget(widget)
  if not widget or safe(function() return widget:isDestroyed() end,true) then return false end
  safe(function() widget:show() end)
  safe(function() widget:raise() end)
  safe(function() widget:focus() end)
  return true
end

local function findWindow(title)
  local root=g_ui.getRootWidget()
  if not root then return nil end
  local wanted=string.lower(title or '')
  local function visit(widget)
    local text=safe(function() return widget:getText() end,'') or ''
    if string.lower(text)==wanted then return widget end
    local children=safe(function() return widget:getChildren() end,{}) or {}
    for _,child in ipairs(children) do
      local found=visit(child)
      if found then return found end
    end
  end
  return visit(root)
end

local function showTitle(title)
  local widget=findWindow(title)
  if showWidget(widget) then return true end
  NexusBot.Logger.warn('Integration','Window is not loaded: '..tostring(title))
  return false
end

local function botTable(getter)
  local value=safe(getter,nil)
  return type(value)=='table' and value or nil
end

local function botState(getter)
  local object=botTable(getter)
  if not object or type(object.isOn)~='function' then return nil end
  return safe(object.isOn,false)==true
end

local function setBot(getter,value)
  local object=botTable(getter)
  if not object then return false end
  local method=value and object.setOn or object.setOff
  if type(method)~='function' then return false end
  return safe(function() method() return true end,false)
end

local function simpleBot(name,getter,editor)
  return {
    name=name,
    get=function() return botState(getter) end,
    set=function(value) return setBot(getter,value) end,
    edit=editor
  }
end

local function makeRow(parent,definition)
  local row=g_ui.createWidget('NexusIntegrationRow',parent)
  row.name:setText(definition.name)
  if definition.get and definition.set then
    row.enabled:setOn(safe(definition.get,false)==true)
    row.enabled.onClick=function(widget)
      local value=not (safe(definition.get,false)==true)
      local ok=safe(function() return definition.set(value)~=false end,false)
      widget:setOn(ok and value or (safe(definition.get,false)==true))
    end
  else
    row.enabled:hide()
  end
  if definition.edit then
    row.edit.onClick=function() NexusBot.safeCall('Integration:'..definition.name,definition.edit) return true end
  else
    row.edit:hide()
  end
  row.refresh=function()
    if definition.get and not row:isDestroyed() then row.enabled:setOn(safe(definition.get,false)==true) end
  end
  return row
end

local function makeWindow(id,definition)
  local window=NexusBot.loadUI('integration',rootWidget)
  window:setId('nexusIntegration_'..id)
  window:setText(definition.title)
  window.content.heading:setText(definition.title)
  window.content.status:setText('')
  window.closeButton.onClick=function() if not window:isDestroyed() then window:destroy() end return true end
  window.closeButton:setPhantom(false)
  window.closeButton:raise()
  window.onEscape=window.closeButton.onClick
  local rows={}
  for _,entry in ipairs(definition.rows) do rows[#rows+1]=makeRow(window.content.list,entry) end
  window:setHeight(math.max(145,math.min(390,91+#rows*34)))
  local refresh=NexusBot.Scheduler.every(400,function()
    if window:isDestroyed() or not window:isVisible() then return end
    for _,row in ipairs(rows) do row.refresh() end
  end,'Integration:'..id)
  local previous=window.onDestroy
  window.onDestroy=function(widget)
    NexusBot.Scheduler.cancel(refresh)
    if previous then previous(widget) end
  end
  return window
end


NexusBot.LegacyWindows={make=makeWindow,showTitle=showTitle}
