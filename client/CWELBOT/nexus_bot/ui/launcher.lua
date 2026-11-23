NexusBot.Launcher={window=nil,rows={}}

local function animateSwitch(switch,on) switch:setOn(on) end

function NexusBot.Launcher.refresh()
  for _,entry in ipairs(NexusBot.Launcher.rows) do
    if not entry.row:isDestroyed() and entry.category.getEnabled then
      animateSwitch(entry.row.power,NexusBot.enabled and entry.category.getEnabled())
    end
  end
end

function NexusBot.Launcher.refreshMini()
  local L=NexusBot.Launcher
  local enabled=NexusBot.Storage.get().settings.miniBotEnabled==true and g_game.isOnline()
  if not enabled then
    NexusBot.WindowManager.close('mini_bot') L.mini=nil
    return
  end
  if L.mini and not L.mini:isDestroyed() then L.mini:show() return end
  local w=g_ui.createWidget('NexusWindow',rootWidget)
  L.mini=w w:setId('nexusMiniBot') w:setText('NEXUS BOT')
  w:setWidth(104) w:setPadding(8) w:setPaddingTop(30)
  local rows={}
  for _,entry in ipairs(NexusBot.Categories.list()) do
    if entry.setEnabled and entry.getEnabled then
      local row=g_ui.createWidget('UIWidget',w)
      row:setHeight(26) row:addAnchor(AnchorLeft,'parent',AnchorLeft) row:addAnchor(AnchorRight,'parent',AnchorRight)
      row:addAnchor(AnchorTop,'parent',AnchorTop) row:setMarginTop(#rows*26)
      local icon=g_ui.createWidget('UIWidget',row) icon:setSize({width=22,height=22})
      icon:addAnchor(AnchorLeft,'parent',AnchorLeft) icon:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
      icon:setImageSource(NexusBot.Assets.get(entry.id)) icon:setImageSmooth(true)
      icon:setTooltip(entry.title)
      local power=g_ui.createWidget('NexusPowerSwitch',row)
      power:addAnchor(AnchorRight,'parent',AnchorRight) power:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
      power:setTooltip(entry.title)
      power.onClick=function()
        NexusBot.Categories.setEnabled(entry,not (NexusBot.enabled and entry.getEnabled()))
        power:setOn(NexusBot.enabled and entry.getEnabled()) return true
      end
      rows[#rows+1]={power=power,category=entry}
    end
  end
  w:setHeight(38+#rows*26)
  local function refresh()
    for _,row in ipairs(rows) do
      local on=NexusBot.enabled and row.category.getEnabled() or false
      if row.power:isOn()~=on then row.power:setOn(on) end
    end
  end
  refresh() NexusBot.Features.Modern.shared.ownTimer(w,refresh,150)
  local oldDestroy=w.onDestroy
  w.onDestroy=function(widget)
    if g_tooltip then g_tooltip.hide() end L.mini=nil
    if oldDestroy then oldDestroy(widget) end
  end
  w.onEscape=function() return true end
  NexusBot.WindowManager.attach('mini_bot',w)
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
