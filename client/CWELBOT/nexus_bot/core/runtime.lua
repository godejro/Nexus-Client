NexusBot.Features.Modern={managed={},lastAlarm={},lastHealth=nil}
local M=NexusBot.Features.Modern
local U=NexusBot.UI
function M.getRuntime() return NexusBot.Automation.runtime end
local R={}
M.bindings=R
local function bindRuntime()
  local runtime=M.getRuntime() or {}
  R.CaveBot=runtime.CaveBot R.TargetBot=runtime.TargetBot
  return runtime
end
local function safe(fn,fallback)
  local ok,value=pcall(fn)
  if ok then return value end
  return fallback
end
local function config(id,defaults)
  local data=NexusBot.Storage.get()
  data.integrations=data.integrations or {}
  data.integrations[id]=NexusBot.merge(defaults,data.integrations[id])
  return data.integrations[id]
end
local function isAlive(widget) return widget and not widget:isDestroyed() end
local function ownTimer(window,callback,delay)
  local timer=NexusBot.Scheduler.every(delay or 400,function() if isAlive(window) and window:isVisible() then callback() end end,'Modern UI')
  local old=window.onDestroy
  window.onDestroy=function(w) NexusBot.Scheduler.cancel(timer) if old then old(w) end end
end
local function engineWindow(title)
  local w=NexusBot.loadUI('cave',rootWidget)
  w:setText(title)
  w.closeButton.onClick=function() w:destroy() return true end
  w.onEscape=w.closeButton.onClick
  return w,w.left.content,w.right.content
end
local function formWindow(title,height)
  local w=NexusBot.loadUI('integration',rootWidget)
  w:setText(title) w:setHeight(height or 460)
  w.content.heading:hide() w.content.status:hide()
  w.content.list:breakAnchors()
  w.content.list:addAnchor(AnchorTop,'parent',AnchorTop)
  w.content.list:addAnchor(AnchorBottom,'parent',AnchorBottom)
  w.content.list:addAnchor(AnchorLeft,'parent',AnchorLeft)
  w.content.list:addAnchor(AnchorRight,'parent',AnchorRight)
  w.closeButton.onClick=function() w:destroy() return true end
  w.closeButton:raise() w.onEscape=w.closeButton.onClick
  return w,w.content.list
end
local function sortedKeys(t)
  local keys={} for key in pairs(t or {}) do keys[#keys+1]=key end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end) return keys
end
local function title(key) return tostring(key):gsub('(%l)(%u)','%1 %2'):gsub('^%l',string.upper) end
local function fields(parent,t,save,excluded)
  for _,key in ipairs(sortedKeys(t)) do
    if not (excluded or {})[key] then
      local value=t[key]
      local function set(v) t[key]=v if save then save(key,v) end end
      if type(value)=='boolean' then U.toggle(parent,title(key),value,set)
      elseif type(value)=='number' then U.numberInput(parent,title(key),value,0,999999,set)
      elseif type(value)=='string' then U.textInput(parent,title(key),value,set) end
    end
  end
end
local function managedToggle(parent,label,object,key)
  if not object or not object.isOn or not object.setOn or not object.setOff then U.label(parent,label..' engine is not loaded.') return end
  local toggle=U.toggle(parent,label,object.isOn(),function(value)
    if value then NexusBot.setEnabled(true) object.setOn() M.managed[key]=object else object.setOff() end
  end)
  return toggle
end
function M.pauseManaged()
  if NexusBot.Automation then NexusBot.Automation.stop() end
  for _,object in pairs(M.managed) do if object.setOff then safe(object.setOff) end end
  M.managed={}
end

M.windows={}
M.shared={
  safe=safe,
  config=config,
  isAlive=isAlive,
  ownTimer=ownTimer,
  engineWindow=engineWindow,
  formWindow=formWindow,
  sortedKeys=sortedKeys,
  title=title,
  fields=fields,
  managedToggle=managedToggle,
  bindRuntime=bindRuntime,
}

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

function M.init()
  M.runtime=bindRuntime()
  NexusBot.Categories.initialize()
  M.wasOnline=g_game.isOnline()
  M.loop=NexusBot.Scheduler.every(200,function()
    local native=bindRuntime()
    if native~=M.runtime then
      for key,object in pairs(M.managed) do
        if not object.independent then if object.setOff then safe(object.setOff) end M.managed[key]=nil end
      end
      for _,id in ipairs({'support','scripter','extras'}) do NexusBot.WindowManager.close(id) end
      M.runtime=native
    end
    local online=g_game.isOnline()
    if M.wasOnline and not online then M.connectionLost=true M.lastHealth=nil end
    if online then M.connectionLost=false end
    if M.connectionLost then M.alert('disconnected','Connection lost.') end
    M.wasOnline=online
    if not NexusBot.enabled or not online then return end
    if not M.friends.enabled and not M.alarms.enabled then return end
    local context=NexusBot.Conditions.buildContext()
    if context then
      M.friendTick(context) M.alarmTick(context)
    end
  end,'Friends / Alarms')
end
