NexusBot.WindowManager = { instances = {}, tracked = {} }
local W = NexusBot.WindowManager

local function positions()
  local data = NexusBot.Storage.get()
  data.settings = data.settings or {}
  data.settings.windowPositions = data.settings.windowPositions or {}
  return data.settings.windowPositions
end

local function valid(position)
  return position and type(position.x)=='number' and type(position.y)=='number'
    and position.x==position.x and position.y==position.y
    and math.abs(position.x)<1000000 and math.abs(position.y)<1000000
end

local function remember(id, position)
  if not valid(position) then return end
  local saved = positions()[id]
  if saved and saved.x==position.x and saved.y==position.y then return end
  positions()[id] = {x=position.x,y=position.y}
  NexusBot.Storage.touch()
end

function W.clamp(widget)
  if not widget or widget:isDestroyed() then return end
  local parent = widget:getParent() or rootWidget
  if not parent or parent:isDestroyed() then return end
  local origin = parent:getPosition()
  local position = widget:getPosition()
  local x = math.max(origin.x,math.min(position.x,origin.x+math.max(0,parent:getWidth()-widget:getWidth())))
  local y = math.max(origin.y,math.min(position.y,origin.y+math.max(0,parent:getHeight()-widget:getHeight())))
  if x~=position.x or y~=position.y then widget:setPosition({x=x,y=y}) end
end

function W.track(id, widget)
  if not widget or widget:isDestroyed() then return widget end
  if id~='launcher' and widget.getText and widget.setText then
    widget:setText(string.upper(widget:getText() or ''))
  end
  if W.tracked[widget] then
    assert(W.tracked[widget].id==id,'A window cannot have two position keys')
    return widget
  end
  local saved=id=='launcher' and positions()[id] or nil
  if id=='heal_friends' and saved then
    local neighbour=W.instances.launcher
    if neighbour and not neighbour:isDestroyed() and neighbour:isVisible() then
      local p=neighbour:getPosition()
      if math.abs((tonumber(saved.x) or 0)-(p.x+neighbour:getWidth()+3))>32 then saved=nil end
    end
  end
  local previous
  widget:breakAnchors()
  if saved then
    local position={x=tonumber(saved.x),y=tonumber(saved.y)}
    if valid(position) then widget:setPosition(position) end
  elseif id ~= 'launcher' then
    previous = NexusBot.Categories.entries[id] and W.instances.launcher or (W.lastOpened or W.instances.launcher)
    while previous and W.tracked[previous] and W.tracked[previous].after and not NexusBot.Categories.entries[W.tracked[previous].id] do previous=W.tracked[previous].after end
    if previous and (previous:isDestroyed() or not previous:isVisible()) then previous=W.instances.launcher end
    if previous and previous ~= widget and not previous:isDestroyed() and previous:isVisible() then
      local p = previous:getPosition()
      widget:setPosition({x=p.x+previous:getWidth()+3,
        y=p.y+math.floor((previous:getHeight()-widget:getHeight())/2)})
    end
  end
  W.clamp(widget)
  -- Restore a dock relationship only for saved windows that are still adjacent.
  -- A deliberately moved window keeps its own saved position.
  if saved and id~='launcher' then
    local p=widget:getPosition()
    for candidate in pairs(W.tracked) do
      if candidate~=widget and not candidate:isDestroyed() and candidate:isVisible() then
        local q=candidate:getPosition()
        if math.abs(p.x-(q.x+candidate:getWidth()+3))<=4 then previous=candidate break end
      end
    end
  end
  local state={id=id,last=widget:getPosition(),after=previous}
  W.tracked[widget]=state
  local function capture(current)
    if not current:isDestroyed() then
      local pos=current:getPosition()
      if valid(pos) then
        local dx,dy=pos.x-state.last.x,pos.y-state.last.y
        state.last={x=pos.x,y=pos.y}
        if dx~=0 or dy~=0 then
          for child,childState in pairs(W.tracked) do
            if childState.after==current and not child:isDestroyed() then
              local p=child:getPosition()
              child:setPosition({x=p.x+dx,y=p.y+dy})
            end
          end
        end
      end
    end
    remember(id,state.last)
  end
  local handlers
  handlers={
    onGeometryChange=capture,
    onFocusChange=function(current,focused) if focused and NexusBot.Categories.entries[id] then W.lastOpened=current end end,
    onDragLeave=function(current) W.clamp(current) capture(current) end,
    onVisibilityChange=capture,
    onDestroy=function(current)
      -- Destruction may invalidate geometry before firing this callback.
      capture(current)
      if W.instances[id]==current then W.instances[id]=nil end
      W.tracked[current]=nil
      disconnect(current,handlers)
    end
  }
  state.handlers=handlers
  connect(widget,handlers)
  return widget
end

function W.attach(id, widget)
  if not widget then return nil end
  W.track(id,widget)
  W.instances[id]=widget
  -- Reuse the constructed UI instead of destroying/rebuilding on every X.
  if widget.closeButton and id~='launcher' then
    widget.closeButton.onClick=function() widget:hide() return true end
    widget.onEscape=widget.closeButton.onClick
  end
  widget:show() widget:raise() widget:focus()
  if id~='launcher' then W.dockBesideLauncher(widget) end
  W.lastOpened=widget
  return widget
end

function W.dockBesideLauncher(widget)
  local state=W.tracked[widget]
  local launcher=state and state.after or W.instances.launcher
  if not launcher or launcher==widget or launcher:isDestroyed() or not launcher:isVisible() then return end
  local parent=widget:getParent() or rootWidget
  local origin=parent:getPosition()
  local p=launcher:getPosition()
  local total=launcher:getWidth()+3+widget:getWidth()
  -- Keep the pair on screen together instead of clamping the child far away.
  if total<=parent:getWidth() and p.x+total>origin.x+parent:getWidth() then
    launcher:setPosition({x=origin.x+parent:getWidth()-total,y=p.y})
    p=launcher:getPosition()
  end
  local state=W.tracked[widget]
  if state then state.after=launcher end
  widget:setPosition({x=p.x+launcher:getWidth()+3,
    y=p.y+math.floor((launcher:getHeight()-widget:getHeight())/2)})
  W.clamp(widget)
end

function W.toggle(id)
  local widget=W.instances[id]
  if widget and not widget:isDestroyed() and widget:isVisible() then
    remember(id,widget:getPosition())
    widget:hide()
    return widget
  end
  return W.open(id)
end

function W.open(id, ...)
  local current=W.instances[id]
  if current and not current:isDestroyed() then
    W.clamp(current)
    current:show() current:raise() current:focus()
    if id~='launcher' then W.dockBesideLauncher(current) end
    W.lastOpened=current
    return current
  end
  local route=NexusBot.ModuleRegistry.get(id)
  if not route or type(route.open)~='function' then
    NexusBot.Logger.warn('WindowManager','Unknown route: '..tostring(id))
    return nil
  end
  local ok,widget=pcall(route.open,...)
  if not ok then NexusBot.Logger.error(id,widget) return nil end
  return W.attach(id,widget)
end

function W.close(id)
  local widget=W.instances[id]
  if widget and not widget:isDestroyed() then
    remember(id,widget:getPosition())
    widget:destroy()
  end
  W.instances[id]=nil
end

function W.closeAll()
  local ids={}
  for id in pairs(W.instances) do ids[#ids+1]=id end
  for _,id in ipairs(ids) do W.close(id) end
end

function W.hideAll()
  for _,widget in pairs(W.instances) do
    if not widget:isDestroyed() then widget:hide() end
  end
end

function W.detachAll()
  -- Some PvP windows belong to the external bot runtime and survive reloads.
  -- Release our listeners without destroying those externally owned widgets.
  local pending={}
  for widget,state in pairs(W.tracked) do pending[#pending+1]={widget,state} end
  for _,entry in ipairs(pending) do
    local widget,state=entry[1],entry[2]
    if not widget:isDestroyed() then remember(state.id,widget:getPosition())
    else remember(state.id,state.last) end
    disconnect(widget,state.handlers)
    W.tracked[widget]=nil
  end
  W.instances={}
  W.lastOpened=nil
end
