-- SETTINGS: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('settings', 'SETTINGS', 12, false)

-- ==================== GUI / LAYOUT ====================
category.open = function()
  local U=NexusBot.UI
  local w,p=NexusBot.Features.Modern.shared.formWindow('SETTINGS',350) w:setWidth(340)
  U.toggle(p,'Auto load: character name',NexusBot.Storage.get().settings.autoLoadCharacter==true,function(value)
    NexusBot.Storage.get().settings.autoLoadCharacter=value
    NexusBot.Storage.saveNow()
  end)
  U.toggle(p,'Auto save loaded configuration',NexusBot.Storage.get().settings.autoSaveSetup==true,function(value)
    NexusBot.Storage.get().settings.autoSaveSetup=value
    if not value then category.cancelAutoSave() end
  end)
  local selected
  local names={}
  for _,name in ipairs(category.list()) do names[#names+1]={name,name} end
  local picker=U.combo(p,'Configuration',names,nil,function(value) selected=value end)
  local last=NexusBot.Storage.get().settings.selectedSetup
  if last then picker:setCurrentOption(last,true) end
  local option=picker:getCurrentOption() selected=option and option.data
  local function run(callback)
    local ok,err=pcall(callback)
    if not ok then displayErrorBox('Settings',tostring(err)) end
    return ok
  end
  U.button(p,'Save as...',function()
    U.prompt('Save configuration','Name',function(name)
      if not run(function() category.save(name) end) then return end
      picker:clearOptions()
      for _,n in ipairs(category.list()) do picker:addOption(n,n) end
      picker:setCurrentOption(name) selected=name
    end,category.characterName())
  end)
  U.button(p,'Save selected',function() run(function() category.save(assert(selected,'Choose a configuration.')) end) end)
  U.button(p,'Load selected',function()
    local ok,err=pcall(category.load,selected)
    if not ok and not w:isDestroyed() then displayErrorBox('Settings',tostring(err)) end
  end)
  U.button(p,'Rename selected',function()
    if not selected then return end
    local old=selected
    U.prompt('Rename configuration','New name',function(name)
      if not run(function() category.rename(old,name) end) then return end
      picker:clearOptions()
      for _,n in ipairs(category.list()) do picker:addOption(n,n) end
      picker:setCurrentOption(name) selected=name
    end,old)
  end)
  U.button(p,'Restore previous version',function()
    run(function() category.restorePrevious(assert(selected,'Choose a configuration.')) end)
  end)
  return w
end

-- ==================== LOGIC / RUNTIME ====================
-- Only settings actually exposed by CWELBOT; never copy accounts or the whole vBot storage.
local legacyKeys={'atomicSmartPushV3','Fast Push','WallKeeper','atomicFlowerV2',
  'atomicAntiPushV1','atomicTrashMouseV2'}
local function directory()
  return NexusBot.Storage.directory..'/setups'
end
local function path(name)
  assert(type(name)=='string' and #name>0 and #name<=60 and name:match('^[%w _%-]+$'),
    'Use 1-60 letters, digits, spaces, - or _.')
  return directory()..'/'..name..'.json'
end
function category.characterName()
  local player=g_game.getLocalPlayer()
  return player and player:getName() or ''
end
function category.list()
  local names={}
  if g_resources.directoryExists(directory()) then
    for _,file in ipairs(g_resources.listDirectoryFiles(directory())) do
      local name=file:match('([^/\\]+)%.json$')
      if name then names[#names+1]=name end
    end
  end
  table.sort(names) return names
end
local function checkedWrite(file,contents)
  assert(g_resources.writeFileContents(file,contents)~=false,'Could not write '..file)
  assert(g_resources.readFileContents(file)==contents,'Write verification failed: '..file)
end
local function rotateHistory(name,previous)
  local history=directory()..'/history'
  g_resources.makeDir(history)
  for i=2,1,-1 do
    local from=history..'/'..name..'.'..i..'.json'
    if g_resources.fileExists(from) then checkedWrite(history..'/'..name..'.'..(i+1)..'.json',g_resources.readFileContents(from)) end
  end
  checkedWrite(history..'/'..name..'.1.json',previous)
end
local function saveSetup(name)
  local file=path(name)
  if NexusBot.Automation.CaveBot then NexusBot.Automation.CaveBot.save() end
  if NexusBot.Automation.TargetBot and NexusBot.Automation.TargetBot.save then NexusBot.Automation.TargetBot.save() end
  g_resources.makeDir(directory())
  local snapshot=NexusBot.copy(NexusBot.Storage.get())
  -- Native PvP settings are part of snapshot.pvp. Retain imported legacy data
  -- as an archive, never require a classic bot to load a CWEL configuration.
  snapshot.settings.masterEnabled=false
  local encoded=json.encode(snapshot,2)
  assert(#encoded<=10*1024*1024,'Configuration exceeds 10 MB.')
  if g_resources.fileExists(file) then
    local previous=g_resources.readFileContents(file)
    if previous~=encoded then rotateHistory(name,previous) end
  end
  checkedWrite(file,encoded)
  NexusBot.Storage.get().settings.selectedSetup=name
  category.activeSetup=name
  assert(NexusBot.Storage.saveNow()~=false,'Configuration saved, but UI preferences could not be written.')
end
function category.save(name)
  category.cancelAutoSave()
  category.saving=true
  local ok,err=pcall(saveSetup,name)
  category.saving=false
  if not ok then error(err) end
  return true
end
function category.cancelAutoSave()
  if category.autoSaveEvent then NexusBot.Scheduler.cancel(category.autoSaveEvent) category.autoSaveEvent=nil end
end
function category.queueAutoSave()
  if category.saving or not category.activeSetup or not NexusBot.Storage.get().settings.autoSaveSetup then return end
  category.cancelAutoSave()
  local name=category.activeSetup
  category.autoSaveEvent=NexusBot.Scheduler.after(8000,function()
    category.autoSaveEvent=nil
    if category.activeSetup~=name or not NexusBot.Storage.get().settings.autoSaveSetup then return end
    local ok,err=pcall(category.save,name)
    if not ok then NexusBot.Logger.error('Settings auto save',tostring(err)) end
  end,'Settings auto save')
end
function category.restorePrevious(name)
  local file=directory()..'/history/'..name..'.1.json'
  path(name) -- validate before constructing any write target
  assert(g_resources.fileExists(file),'No previous version for this configuration.')
  local contents=g_resources.readFileContents(file)
  local parsed=json.decode(contents)
  assert(type(parsed)=='table' and parsed.schemaVersion==NexusBot.Storage.schemaVersion,'Invalid backup.')
  local current=g_resources.readFileContents(path(name))
  checkedWrite(path(name),contents)
  checkedWrite(file,current) -- restoring can itself be undone
  return category.load(name)
end
function category.load(name)
  local contents=g_resources.readFileContents(path(name))
  assert(#contents<=10*1024*1024,'Configuration exceeds 10 MB.')
  local data=json.decode(contents)
  assert(type(data)=='table' and data.schemaVersion==NexusBot.Storage.schemaVersion
    and type(data.settings)=='table' and type(data.modules)=='table','Invalid bot configuration.')
  local runtime=NexusBot.Features.Modern.getRuntime() or {}
  local legacy=data.legacyBindings
  if legacy then
    assert(type(legacy)=='table' and type(legacy.storage)=='table','Invalid integrated settings.')
    for _,key in ipairs(legacyKeys) do
      assert(legacy.storage[key]==nil or type(legacy.storage[key])=='table','Invalid settings for '..key)
    end
    assert(legacy.conditions==nil or type(legacy.conditions)=='table','Invalid Condition Manager settings.')
    data.pvp=data.pvp or {}
    for _,key in ipairs({'atomicSmartPushV3','Fast Push','WallKeeper','atomicFlowerV2','atomicAntiPushV1','atomicTrashMouseV2'}) do
      if not data.pvp[key] and legacy.storage[key] then data.pvp[key]=NexusBot.copy(legacy.storage[key]) end
    end
  end
  -- A settings reload is a lifecycle boundary: clean all owned timers/events,
  -- then initialize the same registered categories against the new data.
  NexusBot.setEnabled(false)
  NexusBot.terminate()
  local preferences=NexusBot.Storage.get().settings
  data.settings.masterEnabled=false
  data.settings.autoLoadCharacter=preferences.autoLoadCharacter==true
  data.settings.autoSaveSetup=preferences.autoSaveSetup==true
  data.settings.manualConfigV1=true
  data.settings.selectedSetup=name
  NexusBot.Storage.data=data
  NexusBot.Storage.saveNow()
  NexusBot.init(true)
  category.activeSetup=name
  NexusBot.show()
end
function category.autoLoadForCharacter()
  if NexusBot.Storage.get().settings.autoLoadCharacter~=true then return end
  local name=category.characterName()
  if name=='' or not name:match('^[%w _%-]+$') or #name>60 then return end
  if g_resources.fileExists(path(name)) then
    local ok,err=pcall(category.load,name)
    if not ok then NexusBot.Logger.error('Settings',tostring(err)) end
  end
end
function category.rename(old,new)
  local from,to=path(old),path(new)
  if from==to then return end
  assert(not g_resources.fileExists(to),'That name already exists.')
  checkedWrite(to,g_resources.readFileContents(from))
  assert(g_resources.deleteFile(from)~=false,'New copy saved; original could not be removed.')
  if category.activeSetup==old then category.activeSetup=new end
  if NexusBot.Storage.get().settings.selectedSetup==old then NexusBot.Storage.get().settings.selectedSetup=new end
  category.cancelAutoSave()
  NexusBot.Storage.touch()
end
category.init=function()
  category.cancelAutoSave()
  NexusBot.EventBus.offOwner(category)
  NexusBot.EventBus.on('storageChanged',category,category.queueAutoSave)
end
category.terminate=function()
  category.cancelAutoSave()
  category.activeSetup=nil
  NexusBot.EventBus.offOwner(category)
end
