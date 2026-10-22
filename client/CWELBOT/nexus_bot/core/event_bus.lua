NexusBot.EventBus = { listeners = {} }

function NexusBot.EventBus.on(name, owner, callback)
  if type(callback) ~= 'function' then return end
  local list = NexusBot.EventBus.listeners[name] or {}
  list[#list + 1] = { owner = owner, callback = callback }
  NexusBot.EventBus.listeners[name] = list
end

function NexusBot.EventBus.offOwner(owner)
  for name, list in pairs(NexusBot.EventBus.listeners) do
    local kept = {}
    for _, entry in ipairs(list) do
      if entry.owner ~= owner then kept[#kept + 1] = entry end
    end
    NexusBot.EventBus.listeners[name] = kept
  end
end

function NexusBot.EventBus.emit(name, ...)
  local list = NexusBot.EventBus.listeners[name] or {}
  for _, entry in ipairs(list) do NexusBot.safeCall('EventBus:' .. name, entry.callback, ...) end
end

function NexusBot.EventBus.clear()
  NexusBot.EventBus.listeners = {}
end

