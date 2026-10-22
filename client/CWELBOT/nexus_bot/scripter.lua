-- SCRIPTER: GUI first; implementation and initialization below.
local category=NexusBot.Categories.define('scripter','SCRIPTER',11,false)
-- ==================== GUI / LAYOUT ====================
NexusBot.embeddedUI.scripter=[=[
NexusWindow
  size: 760 620
  text: SCRIPTER
  NexusCloseButton
    id: closeButton
    anchors.top: parent.top
    anchors.right: parent.right
    margin-top: -32
    text: X
  NexusSectionLabel
    id: sandboxLabel
    anchors.top: parent.top
    anchors.left: parent.left
    text: LUA SCRIPTS
  NexusToggle
    id: sandbox
    anchors.top: sandboxLabel.top
    anchors.right: parent.right
    size: 54 24
  NexusButton
    id: new
    text: New
    anchors.left: parent.left
    anchors.top: sandboxLabel.bottom
    margin-top: 8
    width: 72
  NexusButton
    id: save
    text: Save
    anchors.left: new.right
    anchors.top: new.top
    margin-left: 6
    width: 72
  NexusButton
    id: load
    text: Load
    anchors.left: save.right
    anchors.top: save.top
    margin-left: 6
    width: 72
  NexusButton
    id: unload
    text: Unload
    anchors.left: load.right
    anchors.top: load.top
    margin-left: 6
    width: 72
  NexusButton
    id: reload
    text: Refresh
    anchors.left: unload.right
    anchors.top: unload.top
    margin-left: 6
    width: 72
  NexusComboBox
    id: files
    visible: false
    size: 1 1
    anchors.top: parent.top
  NexusButton
    id: output
    text: Output
    anchors.left: reload.right
    anchors.top: reload.top
    margin-left: 6
    width: 72
  NexusPanel
    id: availablePanel
    anchors.top: new.bottom
    anchors.left: parent.left
    width: 356
    height: 212
    margin-top: 8
    NexusSectionLabel
      anchors.top: parent.top
      anchors.left: parent.left
      text: AVAILABLE SCRIPTS
    NexusScrollPanel
      id: available
      anchors.top: prev.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      layout:
        type: verticalBox
        spacing: 4
  NexusPanel
    id: runningPanel
    anchors.top: availablePanel.top
    anchors.left: availablePanel.right
    anchors.right: parent.right
    anchors.bottom: availablePanel.bottom
    margin-left: 8
    NexusSectionLabel
      anchors.top: parent.top
      anchors.left: parent.left
      text: RUNNING SCRIPTS
    NexusScrollPanel
      id: running
      anchors.top: prev.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      layout:
        type: verticalBox
        spacing: 4
  NexusSectionLabel
    id: editorTitle
    text: SCRIPT EDITOR
    anchors.top: availablePanel.bottom
    anchors.left: parent.left
    margin-top: 8
  NexusMutedLabel
    id: status
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 0
    visible: false
  MultilineTextEdit
    id: editor
    anchors.top: editorTitle.bottom
    anchors.bottom: status.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    margin-bottom: 6
    background-color: #0a1422
    color: #dbe9fa
    font: verdana-11px-antialised
]=]
category.open=function()
  local w=NexusBot.loadUI('scripter',rootWidget)
  local selected,dirty,loading
  local renderLists
  local function report(ok,err)
    if not ok then displayErrorBox('Scripter',tostring(err)) end
  end
  local function select(name)
    selected=name loading=true
    w.editor:setText(category.read(name))
    loading=false dirty=false
    if renderLists then renderLists() end
  end
  renderLists=function()
    NexusBot.UI.clear(w.availablePanel.available)
    NexusBot.UI.clear(w.runningPanel.running)
    local files=category.list()
    for _,name in ipairs(files) do
      local button=g_ui.createWidget('NexusButton',w.availablePanel.available)
      button:setText(name)
      button:setOn(name==selected)
      button.onClick=function() if dirty then displayErrorBox('Scripter','Save current edits first.') else select(name) end end
    end
    for _,name in ipairs(files) do
      if category.running[name] then
        local button=g_ui.createWidget('NexusButton',w.runningPanel.running)
        button:setText(name)
        button.onClick=function() if not dirty then select(name) end end
      end
    end
    w.sandbox:setOn(category.getEnabled())
  end
  local function refresh(name)
    w.files.onOptionChange=nil w.files:clearOptions()
    for _,file in ipairs(category.list()) do w.files:addOption(file,file) end
    if name then w.files:setCurrentOption(name,true) end
    local option=w.files:getCurrentOption()
    if option then select(option.data) end
    w.files.onOptionChange=function(_,text,data)
      if dirty then
        w.files:setCurrentOption(selected,true)
        displayErrorBox('Scripter','Save current edits before selecting another file.')
      else select(data or text) end
    end
    renderLists()
  end
  w.editor.onTextChange=function() if not loading then dirty=true end end
  w.closeButton.onClick=function() w:hide() return true end w.onEscape=w.closeButton.onClick
  w.save.onClick=function()
    if not selected then return end
    local ok,err=pcall(category.save,selected,w.editor:getText())
    if ok then dirty=false renderLists() end report(ok,err)
  end
  w.load.onClick=function()
    if dirty then displayErrorBox('Scripter','Save edits before loading.') return end
    if selected then report(pcall(category.load,selected)) renderLists() end
  end
  w.unload.onClick=function()
    if selected then category.unload(selected) renderLists() end
  end
  w.reload.onClick=function()
    if dirty then displayErrorBox('Scripter','Save current edits first.') return end
    refresh(selected)
  end
  w.output.onClick=function()
    if not selected then return end
    local name=selected
    NexusBot.WindowManager.close('script_output')
    local view,p=NexusBot.Features.Modern.shared.formWindow('SCRIPT OUTPUT',380) view:setWidth(540)
    local stats=NexusBot.UI.label(p,'') stats:setHeight(35) stats:setTextWrap(true)
    local output=g_ui.createWidget('MultilineTextEdit',p) output:setHeight(245) output:setEditable(false)
    local function update()
      local run=category.running[name] or category.lastRun(name)
      if not run then stats:setText(name..': no run') output:setText('') return end
      stats:setText(string.format('%s | %s | calls %d | CPU %.2f ms | max %.2f ms',name,run.active and 'running' or 'stopped',run.calls or 0,(run.cpu or 0)*1000,(run.maximum or 0)*1000))
      output:setText(table.concat(run.output or {},'\n'))
    end
    update() NexusBot.Features.Modern.shared.ownTimer(view,update,500)
    NexusBot.WindowManager.attach('script_output',view)
  end
  w.sandbox.onClick=function()
    category.setEnabled(not category.getEnabled())
    renderLists()
  end
  w.new.onClick=function()
    if dirty then displayErrorBox('Scripter','Save current edits first.') return end
    NexusBot.UI.prompt('New script','File name (.lua)',function(name)
      if not name:match('%.lua$') then name=name..'.lua' end
      local ok,err=pcall(function()
        assert(not g_resources.fileExists(category.path(name)),'File already exists.')
        category.save(name,'-- Trusted Lua script. Owned timers/events stop on Unload.\n-- Optionally return a cleanup function.\n')
      end)
      if ok then refresh(name) else report(false,err) end
    end)
  end
  refresh() return w
end
-- ==================== LOGIC / RUNTIME ====================
category.running={}
category.paused={}
category.history={}
function category.lastRun(name)
  for index=#category.history,1,-1 do if category.history[index].name==name then return category.history[index] end end
end
local function outputLine(state,text)
  state.output[#state.output+1]=tostring(text):sub(1,1000)
  if #state.output>100 then table.remove(state.output,1) end
end
local function measured(state,callback,...)
  local started=os.clock()
  local ok,result=pcall(callback,...)
  local elapsed=math.max(0,os.clock()-started)
  state.calls=state.calls+1 state.cpu=state.cpu+elapsed state.maximum=math.max(state.maximum,elapsed)
  if not ok then outputLine(state,'ERROR: '..tostring(result)) end
  return ok,result
end
function category.directory()
  if g_resources.writeFileContentsToWorkDir then return '/CWELBOT/lua scripts' end
  return (NexusBot.resourceRoot or '/nexus_bot')..'/scripts'
end
function category.path(name)
  assert(type(name)=='string' and #name<=100 and name:match('^[%w _%-]+%.lua$'),'Invalid .lua file name.')
  return category.directory()..'/'..name
end
function category.list()
  local result={}
  if g_resources.directoryExists(category.directory()) then
    for _,file in ipairs(g_resources.listDirectoryFiles(category.directory())) do
      local name=file:match('([^/\\]+%.lua)$')
      if name and name:match('^[%w _%-]+%.lua$') then result[#result+1]=name end
    end
  end
  table.sort(result) return result
end
function category.read(name) return g_resources.readFileContents(category.path(name)) end
function category.save(name,source)
  local file=category.path(name)
  assert(#source<=1024*1024,'Maximum script size: 1 MB.')
  local chunk,err=loadstring(source,'@'..name) assert(chunk,err)
  if g_resources.writeFileContentsToWorkDir then
    assert(g_resources.writeFileContentsToWorkDir(file:sub(2),source)~=false,'Could not save script in CWELBOT.')
  else
    g_resources.makeDir(category.directory())
    assert(g_resources.writeFileContents(file,source)~=false,'Could not save script.')
  end
end
function category.unload(name)
  category.paused[name]=nil
  local state=category.running[name] if not state then return end
  state.active=false category.running[name]=nil
  for event in pairs(state.events) do pcall(removeEvent,event) end
  for _,binding in ipairs(state.bindings) do pcall(disconnect,binding.object,binding.handlers) end
  if state.cleanup then NexusBot.safeCall('Scripter cleanup',state.cleanup) end
  state.events={} state.bindings={} state.cleanup=nil
  category.history[#category.history+1]=state
  if #category.history>20 then table.remove(category.history,1) end
end
function category.load(name)
  local source=category.read(name)
  assert(#source<=1024*1024,'Maximum script size: 1 MB.')
  local chunk,err=loadstring(source,'@'..name) assert(chunk,err)
  category.unload(name)
  local state={name=name,active=true,events={},bindings={},output={},calls=0,cpu=0,maximum=0} category.running[name]=state
  -- Lifecycle ownership, NOT a security sandbox. Only load trusted Lua.
  local env=setmetatable({}, {__index=_G})
  env.print=function(...)
    local values={} for i=1,select('#',...) do values[#values+1]=tostring(select(i,...)) end
    outputLine(state,table.concat(values,'\t'))
  end
  local function later(callback,delay,repeating)
    local event
    local schedule=repeating and cycleEvent or scheduleEvent
    event=schedule(function()
      if not repeating then state.events[event]=nil end
      if not state.active then return end
      local ok,message=measured(state,callback)
      if not ok then
        category.unload(name) NexusBot.Logger.error('Scripter '..name,message) return
      end
    end,math.max(20,tonumber(delay) or 100))
    state.events[event]=true return event
  end
  env.scheduleEvent=function(callback,delay) return later(callback,delay,false) end
  env.addEvent=function(callback) return later(callback,20,false) end
  env.cycleEvent=function(callback,delay) return later(callback,delay,true) end
  env.removeEvent=function(event)
    state.events[event]=nil
    return removeEvent(event)
  end
  env.connect=function(object,handlers)
    local wrapped,original={},{}
    for key,callback in pairs(handlers) do
      original[key]=callback
      wrapped[key]=function(...)
      if not state.active then return end
      local ok,result=measured(state,callback,...)
      if not ok then category.unload(name) NexusBot.Logger.error('Scripter '..name,result) return end
      return result
    end end
    state.bindings[#state.bindings+1]={object=object,handlers=wrapped,original=original}
    connect(object,wrapped)
  end
  env.disconnect=function(object,handlers)
    for index=#state.bindings,1,-1 do
      local binding=state.bindings[index]
      if binding.object==object then
        local selected={}
        for key,callback in pairs(handlers) do
          if binding.original[key]==callback then
            selected[key]=binding.handlers[key]
            binding.handlers[key]=nil binding.original[key]=nil
          end
        end
        disconnect(object,selected)
        if not next(binding.handlers) then table.remove(state.bindings,index) end
      end
    end
  end
  setfenv(chunk,env)
  local ok,result=measured(state,chunk)
  if not ok then category.unload(name) error(result) end
  if type(result)=='function' then state.cleanup=result end
  NexusBot.setEnabled(true)
end
function category.terminate()
  local names={} for name in pairs(category.running) do names[#names+1]=name end
  for _,name in ipairs(names) do category.unload(name) end
  for _,name in ipairs(names) do category.paused[name]=true end
end
category.getEnabled=function() return next(category.running)~=nil end
category.setEnabled=function(value)
  if not value then category.terminate() return end
  local names={} for name in pairs(category.paused) do names[#names+1]=name end
  for _,name in ipairs(names) do
    local ok,err=pcall(category.load,name)
    if not ok then NexusBot.Logger.error('Scripter '..name,err) end
  end
end
