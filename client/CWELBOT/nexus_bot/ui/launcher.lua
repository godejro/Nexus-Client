NexusBot.Launcher={window=nil,rows={}}

local function animateSwitch(switch,on) switch:setOn(on) end

function NexusBot.Launcher.refresh()
  for _,entry in ipairs(NexusBot.Launcher.rows) do
    if not entry.row:isDestroyed() and entry.category.getEnabled then
      animateSwitch(entry.row.power,NexusBot.enabled and entry.category.getEnabled())
    end
  end
end

function NexusBot.Launcher.create()
  local window=NexusBot.loadUI('launcher',rootWidget)
  NexusBot.Launcher.window=window
  NexusBot.Launcher.rows={}
  window.brand.primary:setText(NexusBot.Metadata.brandPrimary)
  window.brand.accent:setText(NexusBot.Metadata.brandAccent)
  window.onEscape=function() NexusBot.hide() return true end
  for _,entry in ipairs(NexusBot.Categories.list()) do
    local row=g_ui.createWidget('NexusNavigationRow',window.entries)
    row:setPhantom(false)
    row.title:setText(entry.title)
    row.icon:setImageSource(NexusBot.Assets.get(entry.id))
    row.power:setVisible(entry.setEnabled~=nil)
    row.power.onDestroy=function(widget) if widget.motion then removeEvent(widget.motion) widget.motion=nil end end
    local function togglePower()
      if entry.setEnabled then NexusBot.Categories.setEnabled(entry,not (NexusBot.enabled and entry.getEnabled())) end
      NexusBot.Launcher.refresh()
      return true
    end
    row.onClick=function()
      NexusBot.WindowManager.toggle(entry.id)
      return true
    end
    row.onDoubleClick=function() return true end
    row.power.onClick=togglePower
    NexusBot.Launcher.rows[#NexusBot.Launcher.rows+1]={row=row,category=entry}
  end
  NexusBot.Launcher.refresh()
  NexusBot.Features.Modern.shared.ownTimer(window,NexusBot.Launcher.refresh,350)
  local previous=window.onDestroy
  window.onDestroy=function(widget) NexusBot.Launcher.window=nil if previous then previous(widget) end end
  return window
end
