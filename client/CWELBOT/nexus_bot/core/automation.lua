NexusBot.Automation={independent=true}
local A=NexusBot.Automation
function A.call(object,method,fallback,...)
  if not object or type(object[method])~='function' then return fallback end
  local ok,value=pcall(object[method],object,...)
  if ok and value~=nil then return value end
  return fallback
end
function A.position()
  local player=g_game.getLocalPlayer()
  return A.call(player,'getServerPosition') or A.call(player,'getPosition')
end
function A.distance(a,b)
  if not a or not b or a.z~=b.z then return math.huge end
  return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))
end
function A.key(p) return p and (p.x..','..p.y..','..p.z) or '' end
function A.parsePosition(text)
  text=tostring(text)
  local base,radius=text:match('^(.-),%s*(%d+)%s*$')
  local x,y,z=text:match('^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
  if not x and base then
    x,y,z=base:match('^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$')
    radius=tonumber(radius)
    if not radius or radius>10 then return end
  else radius=nil end
  x,y,z=tonumber(x),tonumber(y),tonumber(z)
  if x and x<65535 and y<65535 and z<=15 then return {x=x,y=y,z=z,radius=radius} end
end
function A.status(engine,message)
  engine.status=message
end
function A.newList()
  local list={entries={}}
  function list:getChildren() local out={} for _,e in ipairs(self.entries) do out[#out+1]=e end return out end
  function list:getChildCount() return #self.entries end
  function list:getChildIndex(entry) for i,e in ipairs(self.entries) do if e==entry then return i end end end
  function list:getFirstChild() return self.entries[1] end
  function list:getFocusedChild() return self.focused end
  function list:focusChild(entry) self.focused=entry if self.onFocus then self.onFocus(entry) end end
  function list:moveChildToIndex(entry,index)
    local before=self:getChildIndex(entry) if not before then return end
    table.remove(self.entries,before) table.insert(self.entries,math.max(1,math.min(#self.entries+1,index)),entry)
  end
  function list:add(data)
    local entry=data or {} entry.parent=self
    function entry:isDestroyed() return self.destroyed==true end
    function entry:setText(value) self.text=value end
    function entry:destroy()
      local i=self.parent:getChildIndex(self)
      if i then table.remove(self.parent.entries,i) end
      if self.parent.focused==self then self.parent.focused=nil end
      self.destroyed=true
    end
    self.entries[#self.entries+1]=entry return entry
  end
  function list:clear() for _,entry in ipairs(self:getChildren()) do entry:destroy() end end
  return list
end
function A.countItem(id)
  local player=g_game.getLocalPlayer()
  local total=0
  for slot=1,10 do local item=A.call(player,'getInventoryItem',nil,slot)
    if item and item:getId()==id then total=total+A.call(item,'getCount',1) end
  end
  for _,bag in pairs(g_game.getContainers() or {}) do
    for _,item in ipairs(bag:getItems()) do if item:getId()==id then total=total+A.call(item,'getCount',1) end end
  end
  return total
end
function A.data()
  local storage=NexusBot.Storage.get()
  if not storage.automation then
    storage.automation={version=1,activeTarget='Default',activeCave='Default',targetProfiles={Default={targeting={},looting={}}},caveProfiles={Default={}},supplies={items={},minCapacity=0,minMana=0,minHealth=0,returnLabel='refill'}}
  end
  return storage.automation
end
function A.profileStore(kind)
  if kind=='targetbot_configs' then return A.data().targetProfiles end
  if kind=='cavebot_configs' then return A.data().caveProfiles end
  error('Unknown independent profile type')
end
function A.saveProfile(kind,name,data)
  if not NexusBot.Features.CaveTools.validName(name) then error('Invalid profile name') end
  local ok,err
  if kind=='targetbot_configs' then ok,err=NexusBot.Features.TargetTools.validateProfile(data)
  else ok,err=NexusBot.Features.CaveTools.validateRoute(data,A.CaveBot) end
  if not ok then error(err) end
  A.profileStore(kind)[name]=NexusBot.copy(data) NexusBot.Storage.touch() return true
end
function A.importLegacy(kind,runtime)
  local source=kind=='targetbot_configs' and runtime.TargetBot or runtime.CaveBot
  if not source or source.independent then return false,'No legacy engine is currently available. Import JSON instead.' end
  local data=kind=='targetbot_configs' and NexusBot.Features.TargetTools.snapshot(source) or NexusBot.Features.CaveTools.snapshot(source)
  local store=A.profileStore(kind) local i=1
  while store['Imported_'..i] do i=i+1 end
  local name='Imported_'..i
  local ok,err=pcall(A.saveProfile,kind,name,data)
  if not ok then return false,tostring(err) end
  if source.setOff then source.setOff() end
  if kind=='targetbot_configs' then A.TargetBot.setCurrentProfile(name) else A.CaveBot.setCurrentProfile(name) end
  return true,'Imported as '..name..'. Review settings before enabling.'
end
function A.legacyConflict(key)
  local modern=NexusBot.Features.Modern
  local runtime=modern and modern.getRuntime and modern.getRuntime()
  local engine=runtime and runtime[key]
  if engine and not engine.independent and engine.isOn and engine.isOn() then
    if engine.setOff then engine.setOff() end
    return true
  end
  return false
end
function A.stop()
  if A.TargetBot then A.TargetBot.setOff() end
  if A.CaveBot then A.CaveBot.setOff() A.CaveBot.Recorder.disable() end
  if A.Navigation then A.Navigation.reset() end
end
function A.init()
  if A.loop then A.terminate() end
  A.data()
  A.runtime={independent=true,Config={list=function(kind)
    local out={} for name in pairs(A.profileStore(kind)) do out[#out+1]=name end table.sort(out) return out
  end,save=A.saveProfile},saveConfig=NexusBot.Storage.touch}
  A.Targeting.init() A.Walker.init()
  A.debugLoop=NexusBot.Scheduler.every(200,A.Walker.drawDebug,'Cave debug')
  if LocalPlayer then
    A.walkConnections={onCancelWalk=A.Navigation.onCancelWalk,
      onServerPositionChange=function(player,pos,oldPos)
        if player==g_game.getLocalPlayer() then A.Walker.recordPosition(pos,oldPos) end
      end,
      onPositionChange=function(player,pos,oldPos)
        if player~=g_game.getLocalPlayer() then return end
        if A.Walker.recording and A.key(pos)~=A.key(A.position()) then
          -- Keyboard pre-walk fires immediately before g_game.onWalk. Keep its
          -- origin for recording intentions, never for route acknowledgement.
          A.Walker.recordPrediction={from=oldPos,to=pos,at=NexusBot.now()}
        elseif not player.getServerPosition then A.Walker.recordPosition(pos,oldPos) end
      end}
    connect(LocalPlayer,A.walkConnections)
  end
  A.runtime.TargetBot=A.TargetBot A.runtime.CaveBot=A.CaveBot
  local nextTargetTick=0
  A.loop=NexusBot.Scheduler.every(20,function()
    if not NexusBot.enabled or not g_game.isOnline() then
      if A.TargetBot.isOn() or A.CaveBot.isOn() or A.CaveBot.Recorder.isOn() then A.stop() end
      return
    end
    local ok,err=pcall(function()
      A.Navigation.beginTick()
      local now=NexusBot.now()
      if now>=nextTargetTick then nextTargetTick=now+100 A.Targeting.tick() end
      A.Walker.tick()
    end)
    if not ok then
      A.stop() A.TargetBot.status='Stopped: '..tostring(err) A.CaveBot.status=A.TargetBot.status
      NexusBot.Logger.error('Independent automation',err)
    end
  end,'Independent Targeting / CaveBot')
end
function A.terminate()
  NexusBot.Scheduler.cancel(A.debugLoop) A.debugLoop=nil
  if A.Walker.clearDebug then A.Walker.clearDebug() end
  A.stop() NexusBot.Scheduler.cancel(A.loop) A.loop=nil
  if A.Walker.removeRecorderHooks then A.Walker.removeRecorderHooks() end
  if A.connections then disconnect(g_game,A.connections) A.connections=nil end
  if A.walkConnections then disconnect(LocalPlayer,A.walkConnections) A.walkConnections=nil end
end
