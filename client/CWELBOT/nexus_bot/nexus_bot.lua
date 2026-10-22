NexusBot.button=nil
NexusBot.connections=nil
NexusBot.enabled=false

local function removeStaleWidgets()
  local root=g_ui.getRootWidget()
  if not root then return end
  local ids={'nexusBotButton','nexusLauncher','nexusWorkspace','nexusSelector','godejroHealer'}
  for _,id in ipairs(ids) do
    for _=1,32 do
      local widget=root:recursiveGetChildById(id)
      if not widget or widget:isDestroyed() then break end
      widget:destroy()
    end
  end
end

function NexusBot.setEnabled(value)
  NexusBot.enabled=value==true
  NexusBot.Storage.get().settings.masterEnabled=NexusBot.enabled
  NexusBot.Storage.touch()
  if NexusBot.enabled then NexusBot.Actions.start()
  else
    NexusBot.Actions.stop() NexusBot.Features.Modern.pauseManaged()
    local scripter=NexusBot.Categories.entries.scripter
    if scripter then scripter.terminate() end
  end
  if NexusBot.button then NexusBot.button:setOn(NexusBot.enabled) end
  local window=NexusBot.Launcher.window
  if window and not window:isDestroyed() and window.power then window.power:setOn(NexusBot.enabled) end
end

function NexusBot.show()
  if g_tooltip and g_tooltip.hide then pcall(g_tooltip.hide) end
  local window=NexusBot.WindowManager.open('launcher')
  return window
end

function NexusBot.hide()
  if g_tooltip and g_tooltip.hide then pcall(g_tooltip.hide) end
  NexusBot.Features.Pvp.closeSettings()
  NexusBot.WindowManager.hideAll()
end

function NexusBot.toggle()
  local window=NexusBot.Launcher.window
  if window and not window:isDestroyed() and window:isVisible() then NexusBot.hide() else NexusBot.show() end
end

function NexusBot.init(fromSetup)
  NexusBot.terminating=false
  removeStaleWidgets()
  NexusBot.Assets.init()
  NexusBot.importStyle('theme')
  NexusBot.importStyle('widgets')
  if not fromSetup then NexusBot.Storage.load() end
  NexusBot.Spells.init()
  NexusBot.Actions.init()
  NexusBot.Items.init()
  NexusBot.registerModule({id='launcher',title=NexusBot.Metadata.name,open=NexusBot.Launcher.create})
  NexusBot.Automation.init()
  NexusBot.Features.Modern.init()
  NexusBot.connections={
    onGameStart=function()
      NexusBot.Categories.entries.settings.autoLoadForCharacter()
      if NexusBot.enabled then NexusBot.Actions.start() end
    end,
    onGameEnd=function()
      NexusBot.Features.Modern.alert('disconnected','Connection lost.')
      NexusBot.Automation.stop()
      NexusBot.Actions.stop() NexusBot.WindowManager.closeAll() NexusBot.Storage.saveNow()
    end
  }
  connect(g_game,NexusBot.connections)
  NexusBot.enabled=NexusBot.Storage.get().settings.masterEnabled==true
  if g_game.isOnline() and NexusBot.enabled then NexusBot.Actions.start() end
  NexusBot.createCrownButton()
  if NexusBot.button and NexusBot.button.setOn then NexusBot.button:setOn(NexusBot.enabled) end
  NexusBot.Logger.info('Core','Loaded '..NexusBot.Metadata.version)
  if not fromSetup and g_game.isOnline() then NexusBot.Categories.entries.settings.autoLoadForCharacter() end
end

function NexusBot.terminate()
  if NexusBot.terminating then return end
  NexusBot.terminating=true
  NexusBot.enabled=false
  NexusBot.Categories.terminate()
  if NexusBot.connections then disconnect(g_game,NexusBot.connections) NexusBot.connections=nil end
  NexusBot.Actions.terminate()
  if NexusBot.Automation then NexusBot.Automation.terminate() end
  NexusBot.Features.Modern.pauseManaged()
  NexusBot.Features.Pvp.closeSettings()
  NexusBot.WindowManager.closeAll()
  NexusBot.WindowManager.detachAll()
  NexusBot.Scheduler.clear()
  NexusBot.EventBus.clear()
  NexusBot.Storage.terminate()
  if NexusBot.button then
    if not NexusBot.button:isDestroyed() then
      if NexusBot.ownsButton then NexusBot.button:destroy() else NexusBot.button:setOn(false) end
    end
    NexusBot.button=nil
  end
  if NexusBot.lifecycle and not NexusBot.lifecycle:isDestroyed() then NexusBot.lifecycle:destroy() end
  NexusBot.lifecycle=nil
end

function NexusBot.createCrownButton()
  local health = modules.game_healthinfo
  if health and health.getBotButton then
    NexusBot.button = health.getBotButton()
    if NexusBot.button then NexusBot.button:setTooltip(nil) end
    NexusBot.ownsButton = false
    return
  end
  -- Compatibility for clients without the native launcher: dock to the
  -- client's button panel, never position an animated widget over the map.
  if modules.client_topmenu and modules.client_topmenu.addRightGameToggleButton then
    NexusBot.button = modules.client_topmenu.addRightGameToggleButton(
      'nexusBotButton', '', NexusBot.Assets.get('launcher'), NexusBot.toggle)
    NexusBot.ownsButton = true
  end
end
function init() NexusBot.init() end
function terminate() NexusBot.terminate() end
function show() return NexusBot.show() end
function hide() return NexusBot.hide() end
function toggle() return NexusBot.toggle() end
