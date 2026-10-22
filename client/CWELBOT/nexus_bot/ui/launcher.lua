NexusBot.Launcher={window=nil,rows={}}

function NexusBot.Launcher.refresh()
  for _,entry in ipairs(NexusBot.Launcher.rows) do
    if not entry.row:isDestroyed() and entry.category.getEnabled then
      entry.row.power:setOn(NexusBot.enabled and entry.category.getEnabled())
    end
  end
end

function NexusBot.Launcher.create()
  local window=NexusBot.loadUI('launcher',rootWidget)
  NexusBot.Launcher.window=window
  NexusBot.Launcher.rows={}
  window.brand.primary:setText(NexusBot.Metadata.brandPrimary)
  window.brand.accent:setText(NexusBot.Metadata.brandAccent)
  window.closeButton.onClick=function() NexusBot.hide() return true end
  window.closeButton:setTooltip(nil)
  window.power:setOn(NexusBot.enabled)
  window.power:setTooltip(nil)
  window.power.onClick=function() NexusBot.setEnabled(not NexusBot.enabled) end
  window.closeButton:setPhantom(false)
  window.closeButton:setEnabled(true)
  window.closeButton:raise()
  window.onEscape=window.closeButton.onClick
  for _,entry in ipairs(NexusBot.Categories.list()) do
    local row=g_ui.createWidget('NexusNavigationRow',window.entries)
    row:setPhantom(false)
    row.title:setText(entry.title)
    row.icon:setImageSource(NexusBot.Assets.get(entry.id))
    row.power:setVisible(entry.setEnabled~=nil)
    local function togglePower()
      if entry.setEnabled then NexusBot.Categories.setEnabled(entry,not (NexusBot.enabled and entry.getEnabled())) end
      return true
    end
    local suppressRelease, beforeClick
    row.onClick=function()
      if suppressRelease then suppressRelease=false return true end
      local current=NexusBot.WindowManager.instances[entry.id]
      beforeClick=current and not current:isDestroyed() and current:isVisible() or false
      NexusBot.WindowManager.toggle(entry.id)
      return true
    end
    row.onDoubleClick=function()
      local current=NexusBot.WindowManager.instances[entry.id]
      if current and not current:isDestroyed() and beforeClick~=nil then current:setVisible(beforeClick) end
      suppressRelease=true
      return togglePower()
    end
    row.power.onClick=togglePower
    NexusBot.Launcher.rows[#NexusBot.Launcher.rows+1]={row=row,category=entry}
  end
  NexusBot.Launcher.refresh()
  NexusBot.Features.Modern.shared.ownTimer(window,NexusBot.Launcher.refresh,350)
  local previous=window.onDestroy
  window.onDestroy=function(widget) NexusBot.Launcher.window=nil if previous then previous(widget) end end
  return window
end
