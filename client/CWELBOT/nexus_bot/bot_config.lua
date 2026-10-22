-- BOT CONFIG: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('bot_config', 'BOT CONFIG', 13, false)
local hotkeyWindow

-- ==================== GUI / LAYOUT ====================
category.open = function()
  local w,p=NexusBot.Features.Modern.shared.formWindow('BOT CONFIG',210)
  w:setWidth(340)
  local key=NexusBot.Storage.get().settings.windowHotkey or ''
  local input=NexusBot.UI.textInput(p,'Show/Hide bot window',key,function() end)
  input:getParent().label:setWidth(160)
  NexusBot.UI.button(p,'Apply shortcut',function()
    local value=input:getText():gsub('^%s+',''):gsub('%s+$','')
    local ok,err=pcall(category.bind,value)
    if ok then
      NexusBot.Storage.get().settings.windowHotkey=value NexusBot.Storage.touch()
    else displayErrorBox('Shortcut',tostring(err)) end
  end)
  NexusBot.UI.button(p,'Action delays',function() NexusBot.WindowManager.open('delays') end)
  NexusBot.UI.button(p,'Category shortcuts',hotkeyWindow)
  return w
end

hotkeyWindow=function()
  NexusBot.WindowManager.close('category_shortcuts')
  local U=NexusBot.UI
  local w,p=NexusBot.Features.Modern.shared.formWindow('CATEGORY SHORTCUTS',250) w:setWidth(380)
  local options={{'Pause / resume bot','master'}}
  for _,c in ipairs(NexusBot.Categories.list()) do
    options[#options+1]={'Open '..c.title,'open:'..c.id}
    if c.setEnabled then options[#options+1]={'Toggle '..c.title,'toggle:'..c.id} end
  end
  for _,tool in ipairs(NexusBot.Features.Extras.tools) do
    options[#options+1]={'Extras: '..tool[2],'extras:'..tool[1]}
  end
  local selected='master' local input
  U.combo(p,'Action',options,selected,function(v)
    selected=v input:setText((NexusBot.Storage.get().settings.categoryHotkeys or {})[v] or '')
  end)
  input=U.textInput(p,'Shortcut',(NexusBot.Storage.get().settings.categoryHotkeys or {}).master or '',function() end)
  U.button(p,'Apply shortcut',function()
    local ok,err=pcall(category.bindAction,selected,input:getText():match('^%s*(.-)%s*$'))
    if not ok then displayErrorBox('Shortcut',tostring(err)) end
  end)
  U.button(p,'Remove shortcut',function() category.bindAction(selected,'') input:setText('') end)
  NexusBot.WindowManager.attach('category_shortcuts',w) return w
end

-- ==================== LOGIC / RUNTIME ====================
local boundKey
local actionBindings={}
local function toggle() NexusBot.toggle() end
function category.bind(key)
  if key~='' then
    assert(#key<=40 and key:match('^[%w+ %-]+$'),'Invalid shortcut.')
    for _,binding in pairs(actionBindings) do assert(binding.key:lower()~=key:lower(),'Shortcut already used by a category.') end
    -- Bind the new key first: invalid combinations do not destroy the old one.
    if key~=boundKey then g_keyboard.bindKeyDown(key,toggle,rootWidget) end
  end
  if boundKey and boundKey~=key then g_keyboard.unbindKeyDown(boundKey,toggle,rootWidget) end
  boundKey=key~='' and key or nil
end
function category.bindAction(id,key,loading)
  assert(id=='master' or id:match('^open:') or id:match('^toggle:') or id:match('^extras:'),'Invalid action.')
  local mode,categoryId=id:match('^(%w+):(.+)$')
  local target=categoryId and NexusBot.Categories.entries[categoryId]
  local extra
  if mode=='extras' then
    for _,tool in ipairs(NexusBot.Features.Extras.tools) do if tool[1]==categoryId then extra=true break end end
  end
  assert(id=='master' or extra or (target and (mode=='open' or target.setEnabled)),'Unknown category action.')
  if key~='' then
    assert(#key<=40 and key:match('^[%w+ %-]+$'),'Invalid shortcut.')
    assert(not boundKey or key:lower()~=boundKey:lower(),'Shortcut already opens the bot window.')
    for other,binding in pairs(actionBindings) do assert(other==id or key:lower()~=binding.key:lower(),'Shortcut already assigned.') end
  end
  local previous=actionBindings[id]
  if previous and previous.key==key then return end
  local lastPress
  local callback=function()
    -- Ignore rapid duplicate key notifications.
    local now=NexusBot.now()
    if lastPress and now-lastPress<350 then return true end
    lastPress=now
    if id=='master' then NexusBot.setEnabled(not NexusBot.enabled)
    elseif extra then
      local tools=NexusBot.Features.Extras
      tools.setTool(categoryId,not tools.active(categoryId))
    elseif mode=='open' then NexusBot.WindowManager.toggle(categoryId)
    else NexusBot.Categories.setEnabled(target,not (NexusBot.enabled and target.getEnabled())) end
    return true
  end
  if key~='' then g_keyboard.bindKeyDown(key,callback,rootWidget) end
  if previous then g_keyboard.unbindKeyDown(previous.key,previous.callback,rootWidget) end
  actionBindings[id]=key~='' and {key=key,callback=callback} or nil
  if not loading then
    local settings=NexusBot.Storage.get().settings settings.categoryHotkeys=settings.categoryHotkeys or {}
    settings.categoryHotkeys[id]=key~='' and key or nil NexusBot.Storage.touch()
  end
end
category.init=function()
  category.terminate()
  category.bind(NexusBot.Storage.get().settings.windowHotkey or '')
  for id,key in pairs(NexusBot.Storage.get().settings.categoryHotkeys or {}) do
    local ok,err=pcall(category.bindAction,id,key,true)
    if not ok then NexusBot.Logger.warn('Shortcut',tostring(err)) end
  end
end
category.terminate=function()
  if boundKey then g_keyboard.unbindKeyDown(boundKey,toggle,rootWidget) boundKey=nil end
  for _,binding in pairs(actionBindings) do g_keyboard.unbindKeyDown(binding.key,binding.callback,rootWidget) end
  actionBindings={}
end
