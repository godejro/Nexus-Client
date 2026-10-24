local version='v2026.10.23.2'
local window,button,timer,session,state,pending,startedAt,restartRequested
local function relative(file) return 'updater/sessions/'..session..'/'..file end
local function read(file)
  if not g_resources.fileExistsInWorkDir(file) then return end
  local ok,text=pcall(g_resources.readFileContentsFromWorkDir,file)
  if ok then return text end
end
local function installedVersion()
  local saved=read('updater/installed-version.txt')
  saved=saved and saved:match('^%s*(v?%d+%.%d+%.%d+%.%d+)%s*$')
  if not saved then return end
  local old,new={},{}
  for part in version:gmatch('%d+') do old[#old+1]=tonumber(part) end
  for part in saved:gmatch('%d+') do new[#new+1]=tonumber(part) end
  for i=1,4 do
    if new[i]>old[i] then version=saved return end
    if new[i]<old[i] then return end
  end
end
local function writeRequest(mode)
  if not g_platform.spawnProcess or not g_platform.getProcessId then return false end
  local root=g_resources.getWorkDir()
  local args={'-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',
    root..'updater/Start-Nexus.ps1','-Mode',mode,'-Session',session,'-CurrentVersion',version}
  if mode=='Apply' then
    args[#args+1]='-WaitPid' args[#args+1]=tostring(g_platform.getProcessId())
    local manager=modules.client_profiles
    local profile=manager and manager.getSelectedProfileId and manager.getSelectedProfileId()
    if type(profile)=='string' and profile:match('^[%w_.%-]+$') then args[#args+1]='-Profile' args[#args+1]=profile end
  end
  local ok,result=pcall(g_platform.spawnProcess,'powershell.exe',args)
  return ok and result~=false
end
function show()
  if not window then return end
  window:show() window:raise() window:focus()
end
function applyStatus(data)
  if type(data)~='table' or not window then return end
  state=data.phase
  local busy=state=='checking' or state=='downloading' or state=='verifying' or state=='waiting'
  window.heading:setText(data.version and data.version~='' and ('Nexus Client '..data.version) or ('Nexus Client '..version))
  window.message:setText(tostring(data.message or ''))
  local done,total=tonumber(data.done) or 0,tonumber(data.total) or 0
  window.progress:setPercent(total>0 and math.min(100,done*100/total) or 0)
  local count=''
  if state=='downloading' then count=string.format('%.1f / %.1f MB',done/1048576,total/1048576)
  elseif total>0 then count=string.format('%d / %d files',done,total) end
  window.file:setText(count..(data.file and data.file~='' and ('\n'..data.file) or ''))
  window.update:setText(state=='available' and 'Update' or state=='ready' and 'Restart and install' or busy and 'Please wait...' or 'Check for updates')
  window.update:setEnabled(not busy and (state~='ready' or not g_game.isOnline()))
  if state=='ready' and g_game.isOnline() then window.message:setText('Update downloaded. Log out before restarting.') end
end
local function poll()
  timer=nil
  if not window then return end
  local text=read(relative('status.json'))
  if text then
    local ok,data=pcall(json.decode,text)
    if ok and type(data)=='table' and (not pending or data.phase~=pending) then
      pending=nil
      local previous=state applyStatus(data)
      if state=='available' and previous~='available' then show() end
      if state=='error' and tostring(data.message):find('Previous update',1,true)==1 then show() end
      if state=='waiting' and restartRequested and not g_game.isOnline() then
        restartRequested=nil
        g_app.exit() return
      end
    end
  end
  if pending and g_clock.millis()-startedAt>30000 then
    pending=nil restartRequested=nil
    applyStatus({phase='error',message='Updater helper did not start. Check folder permissions and antivirus.'})
  end
  if pending or state=='checking' or state=='downloading' or state=='verifying' or state=='waiting' or state=='ready' then
    timer=scheduleEvent(poll,state=='ready' and 1000 or 250)
  end
end
local function start(mode)
  pending=state or 'none' startedAt=g_clock.millis()
  if not writeRequest(mode) then
    pending=nil
    applyStatus({phase='error',message='Could not start the updater helper.'}) return false
  end
  window.update:setEnabled(false)
  if not timer then timer=scheduleEvent(poll,250) end
  return true
end
function check()
  if not window then return end
  session=tostring(g_platform.getProcessId())..'-'..tostring(g_clock.millis())
  state=nil applyStatus({phase='checking',message='Checking for updates...'})
  start('Check')
end
function init()
  installedVersion()
  window=g_ui.displayUI('nexusupdate') window:hide()
  window.update.onClick=function()
    if state=='available' then start('Download')
    elseif state=='ready' then
      if g_game.isOnline() then return end
      restartRequested=start('Apply')
    else check() end
  end
  if modules.client_topmenu then
    button=modules.client_topmenu.addLeftButton('nexusUpdates','Nexus updates','/images/topbuttons/options',show,false)
  end
  -- Isolated offline QA must never download/install a release.
  if not g_app.getCompactName():find('audit',1,true) then
    check()
  end
end
function terminate()
  if timer then removeEvent(timer) timer=nil end
  if button then button:destroy() button=nil end
  if window then window:destroy() window=nil end
end
