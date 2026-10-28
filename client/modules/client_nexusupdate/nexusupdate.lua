local version='v2026.10.28.1'
local repository='godejro/Nexus-Client'
local window,button,operation,timer,session,state,automatic,manifest,release,stage,started
local active=false
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
function show() if window then window:show() window:raise() window:focus() end end
function applyStatus(data)
  if not window then return end
  state=data.phase
  local busy=state=='checking' or state=='downloading' or state=='verifying' or state=='waiting'
  local compact=automatic and state=='checking'
  window:setSize({width=compact and 300 or 460,height=compact and 125 or 235})
  window.heading:setVisible(not compact)
  window.progress:setVisible(not compact) window.file:setVisible(not compact)
  window.update:setVisible(not compact) window.close:setVisible(not compact)
  window.heading:setText('Nexus Client '..(data.version or version))
  window.message:setText(data.message or '')
  local done,total=tonumber(data.done) or 0,tonumber(data.total) or 0
  window.progress:setPercent(total>0 and math.min(100,done*100/total) or 0)
  local info=''
  if state=='downloading' then
    info=string.format('%.1f / %.1f MB   %.2f MB/s',done/1048576,total/1048576,tonumber(data.speed) or 0)
  elseif total>0 then info=string.format('%d / %d files',done,total) end
  window.file:setText(info..(data.file and data.file~='' and ('\n'..data.file) or ''))
  window.update:setText(state=='available' and 'Update' or state=='ready' and 'Restart and install' or busy and 'Please wait...' or 'Check for updates')
  window.update:setEnabled(not busy and (state~='ready' or not g_game.isOnline()))
  window.close:setText(automatic and 'Continue' or 'Close')
  window.close:setEnabled(not busy)
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
    if not g_resources.fileExistsInWorkDir(name) or g_resources.fileSha256InWorkDir(name)~=file.sha256 then fail('Downloaded file failed SHA256 verification: '..file.path) return end
  end
  applyStatus({phase='verifying',message='Verifying program files...',done=last,total=#manifest.files,file=manifest.files[last].path,version=release.version})
  if last<#manifest.files then timer=scheduleEvent(function() verifyFiles(last+1) end,1) return end
  applyStatus({phase='ready',message='Update verified.',done=last,total=last,version=release.version})
  if automatic then install() end
end
local function download()
  active=automatic
  applyStatus({phase='downloading',message='Downloading update manifest...',version=release.version})
  operation=request(HTTP.getJSON,release.manifest,function(data,err)
    if err then fail(err) return end
    if not validateManifest(data) then fail('Invalid update manifest. Nothing was installed.') return end
    manifest=data
    local base='updater/sessions/'..session stage=base..'/stage'
    if not g_resources.writeFileContentsToWorkDir(base..'/update.json',json.encode(manifest)) then fail('Cannot write updater staging directory.') return end
    started=g_clock.millis()
    operation=request(HTTP.download,release.url,'nexus-update-'..session,function(file,_,errorMessage)
      if errorMessage then fail(errorMessage) return end
      if not g_resources.writeDownloadedFileToWorkDir(file,base..'/package.zip',false) or g_resources.fileSha256InWorkDir(base..'/package.zip')~=manifest.sha256 then fail('Package SHA256 mismatch. Nothing was installed.') return end
      applyStatus({phase='verifying',message='Unpacking verified update...',version=release.version})
      if not g_resources.extractDownloadedArchiveToWorkDir(file,stage,'',false) then fail('Cannot unpack update.') return end
      verifyFiles(1)
    end,function(percent)
      local done=release.size*math.max(0,math.min(100,tonumber(percent) or 0))/100
      applyStatus({phase='downloading',message='Downloading update...',done=done,total=release.size,speed=done/1048576/math.max(0.1,(g_clock.millis()-started)/1000),file='nexus-update.zip',version=release.version})
    end)
  end)
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
    if automatic then download() else applyStatus({phase='available',message='A new update is available.',version=release.version}) end
  end)
end
function init()
  local saved=read('updater/installed-version.txt') if saved and newer(saved,version) then version=saved:match('v?%d+%.%d+%.%d+%.%d+') end
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
  if window then window:destroy() window=nil end
end
