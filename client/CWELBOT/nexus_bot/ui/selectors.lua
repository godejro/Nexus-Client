local function selectorWindow(routeId, title, render)
  NexusBot.WindowManager.close(routeId)
  local window = NexusBot.loadUI('selectors', rootWidget)
  window:setText(title)
  window.closeButton.onClick=function() if not window:isDestroyed() then window:destroy() end return true end
  window.closeButton:setPhantom(false)
  window.closeButton:setEnabled(true)
  window.closeButton:raise()
  window.buttons.cancel.onClick=function() if not window:isDestroyed() then window:destroy() end return true end
  NexusBot.WindowManager.attach(routeId, window)
  render(window)
  return window
end

function NexusBot.UI.openSpellSelector(currentWords, callback)
  return selectorWindow('spell_selector', 'Select Spell', function(window)
    local selected, filter = NexusBot.Spells.get(currentWords), 'all'
    local refresh
    local filters={{'All','all'},{'Attack','attack'},{'Healing','healing'},{'Support','support'},{'Buff','buff'}}
    for _, item in ipairs(filters) do
      local button=NexusBot.UI.button(window.filters,item[1],function() filter=item[2] refresh() end)
      button:setWidth(72)
    end
    refresh=function()
      NexusBot.UI.clear(window.list)
      for _, spell in ipairs(NexusBot.Spells.search(window.search:getText(),filter,80)) do
        local row=g_ui.createWidget('NexusSelectorRow',window.list)
        row.item:hide() row.title:setText(spell.name) row.detail:setText(spell.words)
        NexusBot.Spells.applyIcon(row.spellIcon,spell)
        if selected and selected.words==spell.words then row:focus() end
        row.onClick=function() selected=spell row:focus() end
        row.onDoubleClick=function() selected=spell callback(spell) window:destroy() return true end
      end
      local custom=NexusBot.UI.button(window.list,'+ Custom Spell',function()
        NexusBot.UI.prompt('Custom spell','Spell words:',function(words)
          local entry=NexusBot.Spells.addCustom({name=words,words=words})
          if entry then callback(entry) window:destroy() end
        end)
      end,true)
      custom:setHeight(28)
    end
    window.search.onTextChange=refresh
    window.buttons.apply.onClick=function() if selected then callback(selected) window:destroy() end end
    refresh()
  end)
end

function NexusBot.UI.openItemSelector(currentId, callback)
  return selectorWindow('item_selector','Select Item',function(window)
    window.filters:setHeight(0) window.filters:hide()
    local selected=NexusBot.Items.get(currentId)
    local searchEvent
    local function refresh()
      NexusBot.UI.clear(window.list)
      for _, entry in ipairs(NexusBot.Items.search(window.search:getText(),100)) do
        local row=g_ui.createWidget('NexusSelectorRow',window.list)
        row.spellIcon:hide() row.item:setItemId(entry.id)
        row.title:setText(entry.name) row.detail:setText('Item ID: '..entry.id)
        if selected and selected.id==entry.id then row:focus() end
        row.onClick=function() selected=entry row:focus() end
        row.onDoubleClick=function() selected=entry callback(entry) window:destroy() return true end
      end
    end
    window.search.onTextChange=function()
      if searchEvent then NexusBot.Scheduler.cancel(searchEvent) end
      searchEvent=NexusBot.Scheduler.after(120,function()
        searchEvent=nil
        if not window:isDestroyed() then refresh() end
      end,'ItemSearch')
    end
    local previousDestroy=window.onDestroy
    window.onDestroy=function(widget)
      if searchEvent then NexusBot.Scheduler.cancel(searchEvent) searchEvent=nil end
      if previousDestroy then previousDestroy(widget) end
    end
    window.buttons.apply.onClick=function() if selected then callback(selected) window:destroy() end end
    refresh()
  end)
end

function NexusBot.UI.openCreatureSelector(currentName, callback)
  return selectorWindow('creature_selector','Select Creature',function(window)
    window.filters:setHeight(0) window.filters:hide()
    local selected
    local function refresh()
      NexusBot.UI.clear(window.list)
      if not g_game.isOnline() then
        NexusBot.UI.label(window.list,'Creature selection is available while online.')
        return
      end
      local player=g_game.getLocalPlayer()
      local query=window.search:getText():lower()
      for _,creature in ipairs(g_map.getSpectators(player:getPosition(),false) or {}) do
        local name=creature:getName()
        if creature~=player and (query=='' or name:lower():find(query,1,true)) then
          local row=g_ui.createWidget('NexusSelectorRow',window.list)
          row.item:hide() row.spellIcon:hide() row.title:setText(name)
          row.detail:setText(creature:isPlayer() and 'Player' or creature:isMonster() and 'Monster' or 'Creature')
          if currentName and name:lower()==tostring(currentName):lower() then row:focus() selected=name end
          row.onClick=function() selected=name row:focus() end
          row.onDoubleClick=function() callback(name) window:destroy() return true end
        end
      end
    end
    window.search.onTextChange=refresh
    window.buttons.apply.onClick=function() if selected then callback(selected) window:destroy() end end
    refresh()
  end)
end
