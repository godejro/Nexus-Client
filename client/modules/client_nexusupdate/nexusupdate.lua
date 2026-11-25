local version='v2026.11.3.1'
local repository='godejro/Nexus-Client'
local window,button,operation,timer,session,state,automatic,manifest,release,stage,started
local active=false
local startAnimator,stopAnimator
local fallbackToFull
local function request(fn,...)
  local timeout=HTTP.timeout HTTP.timeout=120
  local id=fn(...) HTTP.timeout=timeout return id
end
local function read(path)
  if not g_resources.fileExistsInWorkDir(path) then return end
  return g_resources.readFileContentsFromWorkDir(path)
end
local function newer(a,b)
  local x,y={},{}
  for n in tostring(a):gmatch('%d+') do x[#x+1]=tonumber(n) end
  for n in tostring(b):gmatch('%d+') do y[#y+1]=tonumber(n) end
  if #x~=4 or #y~=4 then return false end
  for i=1,4 do if x[i]~=y[i] then return x[i]>y[i] end end
  return false
end
function isBusy() return active end
local function enterGame()
  active=false
  if not g_game.isOnline() and modules.client_entergame and modules.client_entergame.EnterGame then modules.client_entergame.EnterGame.show() end
end
function show() if window then window:show() window:raise() window:focus() startAnimator() end end
-- Smooth progress: the bar eases toward the real percent and a soft light
-- runs across the filled part while work is in progress.
local shownPercent,targetPercent,sheenX,animator=0,0,0,nil
local function drawProgress()
  if not window then return end
  local track=window.progress
  local width=math.max(0,track:getWidth()-4)
  local fillWidth=math.floor(width*shownPercent/100+0.5)
  track.fill:setWidth(fillWidth)
  track.fill:setVisible(fillWidth>0)
  track.percent:setText(string.format('%d%%',math.floor(shownPercent+0.5)))
  track.fill.sheen:setMarginLeft(sheenX-48)
end
stopAnimator=function() if animator then removeEvent(animator) animator=nil end end
startAnimator=function()
  if animator then return end
  animator=cycleEvent(function()
    if not window or not window:isVisible() then stopAnimator() return end
    local busy=state=='checking' or state=='downloading' or state=='verifying' or state=='waiting'
    local diff=targetPercent-shownPercent
    if math.abs(diff)<0.2 then shownPercent=targetPercent else shownPercent=shownPercent+diff*0.12 end
    if busy then
      sheenX=sheenX+6
      if sheenX>window.progress.fill:getWidth()+96 then sheenX=0 end
    else
      sheenX=0
    end
    drawProgress()
    if not busy and shownPercent==targetPercent then stopAnimator() end
  end,30)
end
local phaseText={checking='Checking for updates...',downloading='Downloading...',verifying='Verifying files...',
  waiting='Restarting...',ready='Ready to install',current='Nexus Client is up to date',available='A new update is available'}
function applyStatus(data)
  if not window then return end
  local previous=state
  state=data.phase
  local busy=state=='checking' or state=='downloading' or state=='verifying' or state=='waiting'
  local compact=automatic and state=='checking'
  local buttons=not busy and not compact
  window:setSize({width=440,height=compact and 110 or buttons and 190 or 150})
  window.progress:setVisible(not compact)
  window.update:setVisible(buttons) window.close:setVisible(buttons)
  local important=state=='error' or (state=='ready' and tostring(data.message or ''):find('Log out',1,true))
  window.message:setText(important and (data.message or '') or phaseText[state] or data.message or '')
  window.message:setColor(important and '#ff7a6b' or '#9fb4d6')
  local done,total=tonumber(data.done) or 0,tonumber(data.total) or 0
  local part=total>0 and math.min(1,done/total) or 0
  if state=='downloading' then targetPercent=part*90
  elseif state=='verifying' then targetPercent=90+part*10
  elseif state=='waiting' or state=='ready' or state=='current' then targetPercent=100
  elseif state=='checking' or state=='available' then targetPercent=0 end
  if state=='checking' and previous~='checking' then shownPercent=0 end
  window.update:setText(state=='available' and 'Update' or state=='ready' and 'Restart and install' or 'Check for updates')
  window.update:setEnabled(not busy and (state~='ready' or not g_game.isOnline()))
  window.close:setText(automatic and 'Continue' or 'Close')
  window.close:setEnabled(not busy)
  drawProgress()
  if window:isVisible() then startAnimator() end
end
local function fail(message)
  applyStatus({phase='error',message=tostring(message)}) enterGame() show()
end
local function releaseUrl(url)
  return type(url)=='string' and url:sub(1,#('https://github.com/'..repository..'/releases/download/'))=='https://github.com/'..repository..'/releases/download/'
end
local function programPath(path)
  if type(path)~='string' or path=='' or path:find('[\\:%z\1-\31<>|?*]') or path:sub(1,1)=='/' or path:find('//',1,true) then return false end
  for part in path:gmatch('[^/]+') do
    if part=='.' or part=='..' or part:find('[. ]$') then return false end
    local device=part:upper():match('^[^.]+')
    if device=='CON' or device=='PRN' or device=='AUX' or device=='NUL' or device:match('^COM%d$') or device:match('^LPT%d$') then return false end
  end
  local lower=path:lower()
  for part in lower:gmatch('[^/]+') do
    if part=='setups' or part=='lua scripts' or part=='scripts' or part=='settings' or part=='profiles' or part=='server_profiles' then return false end
    local stem,ext=part:match('^([^%.]+)%.([^%.]+)$')
    if ({storage=true,config=true,credentials=true,accounts=true})[stem] and ({json=true,ini=true,otml=true})[ext] then return false end
  end
  local roots={['Nexus Client.exe']=true,['init.lua']=true,['LICENSE']=true,['cacert.pem']=true,['Nexus.ico']=true,['Nexus-256.png']=true,['URUCHOM_NEXUS.cmd']=true,
    ['updater/Start-Nexus.ps1']=true,['updater/Update-Library.ps1']=true}
  if roots[path] then return true end
  local extension=path:match('%.([^./]+)$')
  local code={lua=true,otui=true,otmod=true,html=true,css=true,png=true,otfont=true,glsl=true,vert=true,frag=true,json=true}
  if path:match('^modules/.+') then return code[extension]==true end
  local mod=path:match('^mods/([^/]+)/')
  if mod and ({client_mods=true,client_profiles=true,client_textedit=true,game_buttons=true,game_itemselector=true,game_tasks=true})[mod] then return code[extension]==true end
  local data=path:match('^data/([^/]+)/')
  if data and ({cursors=true,fonts=true,images=true,styles=true,particles=true})[data] then return ({lua=true,otui=true,png=true,otfont=true,otps=true,cur=true,ani=true,css=true})[extension]==true end
  if path:match('^CWELBOT/nexus_bot/[^/]+%.lua$') or path:match('^CWELBOT/nexus_bot/[^/]+%.otmod$') then return true end
  local bot=path:match('^CWELBOT/nexus_bot/([^/]+)/')
  if bot=='core' or bot=='ui' or bot=='assets' then return ({lua=true,otui=true,png=true,ogg=true,wav=true,mp3=true,otfont=true,json=true})[extension]==true end
  return false
end
-- Exported for package compatibility tests; the native installer validates again.
testProgramPath=programPath
local function validateManifest(data)
  if type(data)~='table' or data.schema~=1 or data.version~=release.version or type(data.files)~='table' or #data.files<1 or #data.files>20000 or type(data.sha256)~='string' or #data.sha256~=64 or data.sha256:find('[^a-f0-9]') then return false end
  local seen,total={},0
  for _,file in ipairs(data.files) do
    if not programPath(file.path) or seen[file.path:lower()] or type(file.sha256)~='string' or #file.sha256~=64 or file.sha256:find('[^a-f0-9]') or type(file.size)~='number' or file.size<0 or file.size%1~=0 or file.size>134217728 then return false end
    total=total+file.size seen[file.path:lower()]=true
  end
  return total<=536870912 and seen['nexus client.exe'] and seen['init.lua']
end
local function install()
  if g_game.isOnline() then applyStatus({phase='ready',message='Log out before installing the update.'}) return end
  if not g_platform.hasNexusUpdater or not g_platform.hasNexusUpdater() then fail('This EXE does not support native updates. Install the current complete client once.') return end
  local profile=''
  if modules.client_profiles and modules.client_profiles.getSelectedProfileId then profile=modules.client_profiles.getSelectedProfileId() or '' end
  if not profile:match('^[%w_.%-]*$') then profile='' end
  applyStatus({phase='waiting',message='Restarting to install the verified update...'})
  local root=g_resources.getWorkDir()
  local ok=g_platform.spawnProcess(root..stage..'/Nexus Client.exe',{'--nexus-apply-update',root,session,tostring(g_platform.getProcessId()),profile})
  if not ok then fail('Could not start the verified client installer.') return end
  g_app.exit()
end
local function verifyFiles(index)
  if not window then return end
  local last=math.min(index+39,#manifest.files)
  for i=index,last do
    local file=manifest.files[i] local name=stage..'/'..file.path
    if not g_resources.fileExistsInWorkDir(name) or g_resources.fileSha256InWorkDir(name)~=file.sha256 then
      if manifest.delta then fallbackToFull('verify '..file.path) else fail('Downloaded file failed SHA256 verification: '..file.path) end
      return
    end
  end
  applyStatus({phase='verifying',message='Verifying program files...',done=last,total=#manifest.files,file=manifest.files[last].path,version=release.version})
  if last<#manifest.files then timer=scheduleEvent(function() verifyFiles(last+1) end,1) return end
  applyStatus({phase='ready',message='Update verified.',done=last,total=last,version=release.version})
  if automatic then install() end
end
-- Client and CWELBOT are updated separately. Each release names a content
-- hash of its client part and of its bot part (clientHash/botHash in the
-- manifest). A part is installed only when its hash differs from the one this
-- installation last received, so a client release never resets the bot and a
-- bot release never resets the client. A CWELBOT folder that is a git clone
-- (the bot developer's own copy) is never touched by the updater.
local PARTS_FILE='updater/installed-parts.json'
local PENDING_FILE='updater/parts-pending.json'
local function readJson(path)
  local text=read(path) if not text or text=='' then return nil end
  local ok,data=pcall(json.decode,text)
  return ok and type(data)=='table' and data or nil
end
local function isBotPath(path) return path:sub(1,8)=='CWELBOT/' end
local function isCoreFile(path) return path=='Nexus Client.exe' or path=='init.lua' end
local function botIsDeveloperCopy() return g_resources.fileExistsInWorkDir('CWELBOT/.git/HEAD') or g_resources.fileExistsInWorkDir('CWELBOT/.git') end
local function localEntry(path)
  local content=read(path)
  if not content then return nil end
  return {path=path,size=#content,sha256=g_resources.fileSha256InWorkDir(path),['local']=true}
end
-- Returns 'install', 'nothing' or nil plus a reason.
local function selectParts(data)
  local installed=readJson(PARTS_FILE) or {}
  local skipClient=type(data.clientHash)=='string' and installed.client==data.clientHash
  local skipBot=botIsDeveloperCopy() or (type(data.botHash)=='string' and installed.bot==data.botHash)
  local files,real={},0
  for _,entry in ipairs(data.files) do
    if isCoreFile(entry.path) and (skipClient or entry['local']==true) then
      local own=localEntry(entry.path)
      if not own then return nil,'missing '..entry.path end
      files[#files+1]=own
    elseif isBotPath(entry.path) then
      if not skipBot then files[#files+1]=entry real=real+1 end
    elseif not skipClient then
      files[#files+1]=entry real=real+1
    end
  end
  data.files=files
  local pending={version=data.version,client=data.clientHash or installed.client,bot=(botIsDeveloperCopy() and installed.bot) or data.botHash or installed.bot}
  if real==0 then
    g_resources.writeFileContentsToWorkDir('updater/installed-version.txt',data.version)
    g_resources.writeFileContentsToWorkDir(PARTS_FILE,json.encode(pending))
    version=data.version
    return 'nothing'
  end
  g_resources.writeFileContentsToWorkDir(PENDING_FILE,json.encode(pending))
  return 'install'
end
local function nothingToInstall()
  applyStatus({phase='current',message='Nexus Client is up to date.'})
  if automatic then window:hide() enterGame() else active=false end
end
local function copyLocalFiles()
  local root=g_resources.getWorkDir()
  for _,entry in ipairs(manifest.files) do
    if entry['local']==true and not g_platform.copyFile(root..entry.path,root..stage..'/'..entry.path) then return false,entry.path end
  end
  return true
end
local function fullDownload()
  active=automatic
  applyStatus({phase='downloading',message='Downloading update manifest...',version=release.version})
  operation=request(HTTP.getJSON,release.manifest,function(data,err)
    if err then fail(err) return end
    if not validateManifest(data) then fail('Invalid update manifest. Nothing was installed.') return end
    local choice,reason=selectParts(data)
    if not choice then fail('Cannot prepare update: '..tostring(reason)) return end
    if choice=='nothing' then nothingToInstall() return end
    manifest=data
    local base='updater/sessions/'..session stage=base..'/stage'
    if not g_resources.writeFileContentsToWorkDir(base..'/update.json',json.encode(manifest)) then fail('Cannot write updater staging directory.') return end
    started=g_clock.millis()
    operation=request(HTTP.download,release.url,'nexus-update-'..session,function(file,_,errorMessage)
      if errorMessage then fail(errorMessage) return end
      if not g_resources.writeDownloadedFileToWorkDir(file,base..'/package.zip',false) or g_resources.fileSha256InWorkDir(base..'/package.zip')~=manifest.sha256 then fail('Package SHA256 mismatch. Nothing was installed.') return end
      applyStatus({phase='verifying',message='Unpacking verified update...',version=release.version})
      if not g_resources.extractDownloadedArchiveToWorkDir(file,stage,'',false) then fail('Cannot unpack update.') return end
      local copied,failed=copyLocalFiles()
      if not copied then fail('Cannot prepare '..tostring(failed)) return end
      verifyFiles(1)
    end,function(percent)
      local done=release.size*math.max(0,math.min(100,tonumber(percent) or 0))/100
      applyStatus({phase='downloading',message='Downloading update...',done=done,total=release.size,speed=done/1048576/math.max(0.1,(g_clock.millis()-started)/1000),file='nexus-update.zip',version=release.version})
    end)
  end)
end
-- Small update: only the files changed since the previous release (delta.json
-- names that release in "from"). Unchanged Nexus Client.exe/init.lua are marked
-- "local" and copied from this installation into the stage, because the native
-- installer runs from the staged EXE. Any problem falls back to the full package.
fallbackToFull=function(reason)
  g_logger.info('[NexusUpdate] small update not used: '..tostring(reason))
  release.delta=nil manifest=nil
  session=session..'f'
  fullDownload()
end
local function deltaDownload()
  active=automatic
  local delta=release.delta
  applyStatus({phase='downloading',message='Downloading update manifest...',version=release.version})
  operation=request(HTTP.getJSON,delta.manifest,function(data,err)
    if err then fallbackToFull(err) return end
    local from=type(data)=='table' and tostring(data.from or ''):gsub('^v','') or ''
    if from~=tostring(version):gsub('^v','') or not validateManifest(data) then fallbackToFull('made for '..from) return end
    local choice,reason=selectParts(data)
    if not choice then fallbackToFull(reason) return end
    if choice=='nothing' then nothingToInstall() return end
    manifest=data manifest.delta=true
    local base='updater/sessions/'..session stage=base..'/stage'
    if not g_resources.writeFileContentsToWorkDir(base..'/update.json',json.encode(manifest)) then fallbackToFull('staging') return end
    started=g_clock.millis()
    operation=request(HTTP.download,delta.url,'nexus-delta-'..session,function(file,_,errorMessage)
      if errorMessage then fallbackToFull(errorMessage) return end
      if not g_resources.writeDownloadedFileToWorkDir(file,base..'/package.zip',false) or g_resources.fileSha256InWorkDir(base..'/package.zip')~=manifest.sha256 then fallbackToFull('package sha') return end
      applyStatus({phase='verifying',message='Unpacking verified update...',version=release.version})
      if not g_resources.extractDownloadedArchiveToWorkDir(file,stage,'',false) then fallbackToFull('unpack') return end
      local copied,failed=copyLocalFiles()
      if not copied then fallbackToFull('copy '..tostring(failed)) return end
      verifyFiles(1)
    end,function(percent)
      local done=delta.size*math.max(0,math.min(100,tonumber(percent) or 0))/100
      applyStatus({phase='downloading',message='Downloading update...',done=done,total=delta.size,speed=done/1048576/math.max(0.1,(g_clock.millis()-started)/1000),file='nexus-delta.zip',version=release.version})
    end)
  end)
end
local function download()
  if release.delta then deltaDownload() else fullDownload() end
end
function check(auto)
  if not window or active then return end
  automatic=auto==true active=automatic
  session=tostring(g_platform.getProcessId())..'-'..tostring(g_clock.millis())
  if automatic and modules.client_entergame and modules.client_entergame.EnterGame then modules.client_entergame.EnterGame.hide() end
  applyStatus({phase='checking',message='Checking for updates...'}) show()
  operation=request(HTTP.getJSON,'https://api.github.com/repos/'..repository..'/releases/latest',function(data,err)
    if err then fail('Cannot check updates: '..tostring(err)) return end
    if type(data)~='table' or type(data.tag_name)~='string' or not data.tag_name:match('^v?%d+%.%d+%.%d+%.%d+$') then fail('Invalid release response.') return end
    if not newer(data.tag_name,version) then applyStatus({phase='current',message='Nexus Client is up to date.'}) if automatic then window:hide() enterGame() end return end
    local assets={} for _,asset in ipairs(data.assets or {}) do assets[asset.name]=asset end
    local zip,meta=assets['nexus-update.zip'],assets['update.json']
    if not zip or not meta or not releaseUrl(zip.browser_download_url) or not releaseUrl(meta.browser_download_url) or type(zip.size)~='number' or zip.size<=0 or zip.size>536870912 then fail('Release package is incomplete.') return end
    release={version=data.tag_name,url=zip.browser_download_url,manifest=meta.browser_download_url,size=zip.size}
    local deltaZip,deltaMeta=assets['nexus-delta.zip'],assets['delta.json']
    if deltaZip and deltaMeta and releaseUrl(deltaZip.browser_download_url) and releaseUrl(deltaMeta.browser_download_url) and type(deltaZip.size)=='number' and deltaZip.size>0 and deltaZip.size<zip.size then
      release.delta={url=deltaZip.browser_download_url,manifest=deltaMeta.browser_download_url,size=deltaZip.size}
    end
    if automatic then download() else applyStatus({phase='available',message='A new update is available.',version=release.version}) end
  end)
end
function init()
  local saved=read('updater/installed-version.txt') if saved and newer(saved,version) then version=saved:match('v?%d+%.%d+%.%d+%.%d+') end
  -- The native installer finished the update prepared last time: remember its parts.
  local pending=readJson(PENDING_FILE)
  if pending and saved and tostring(pending.version)==saved:match('v?%d+%.%d+%.%d+%.%d+') then
    g_resources.writeFileContentsToWorkDir(PARTS_FILE,json.encode(pending))
    g_resources.writeFileContentsToWorkDir(PENDING_FILE,'')
  end
  window=g_ui.displayUI('nexusupdate') window:hide()
  window.close.onClick=function() if active then return end window:hide() enterGame() end
  window.onEscape=window.close.onClick
  window.update.onClick=function() if state=='available' then download() elseif state=='ready' then install() else check(false) end end
  if modules.client_topmenu then button=modules.client_topmenu.addLeftButton('nexusUpdates','Nexus updates','/images/topbuttons/options',show,false) end
  if not g_app.getCompactName():find('audit',1,true) then
    active=true
    timer=scheduleEvent(function()
      active=false
      local previous=read('updater/last-error.txt')
      if previous and previous~='' then g_resources.writeFileContentsToWorkDir('updater/last-error.txt','') fail('Previous update: '..previous) else check(true) end
    end,100)
  end
end
function terminate()
  active=false if timer then removeEvent(timer) timer=nil end
  if operation then HTTP.cancel(operation) operation=nil end
  if button then button:destroy() button=nil end
  stopAnimator()
  if window then window:destroy() window=nil end
end
