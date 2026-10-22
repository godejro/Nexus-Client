NexusBot.Scheduler = { events = {}, generation = 0 }

local function forget(handle)
  for index, event in ipairs(NexusBot.Scheduler.events) do
    if event == handle then table.remove(NexusBot.Scheduler.events, index) return end
  end
end

function NexusBot.Scheduler.after(delay, callback, scope)
  local generation = NexusBot.Scheduler.generation
  local handle
  handle = scheduleEvent(function()
    forget(handle)
    if generation ~= NexusBot.Scheduler.generation then return end
    NexusBot.safeCall(scope or 'Scheduler', callback)
  end, math.max(0, tonumber(delay) or 0))
  NexusBot.Scheduler.events[#NexusBot.Scheduler.events + 1] = handle
  return handle
end

function NexusBot.Scheduler.every(delay, callback, scope)
  local token = { cancelled = false }
  local function tick()
    if token.cancelled then return end
    NexusBot.safeCall(scope or 'Scheduler', callback)
    if not token.cancelled then token.handle = NexusBot.Scheduler.after(delay, tick, scope) end
  end
  token.handle = NexusBot.Scheduler.after(delay, tick, scope)
  return token
end

function NexusBot.Scheduler.cancel(token)
  if not token then return end
  if type(token)=='table' then token.cancelled = true end
  local handle = type(token)=='table' and (token.handle or token) or token
  if handle then pcall(removeEvent, handle) forget(handle) end
end

function NexusBot.Scheduler.clear()
  NexusBot.Scheduler.generation = NexusBot.Scheduler.generation + 1
  for _, event in ipairs(NexusBot.Scheduler.events) do pcall(removeEvent, event) end
  NexusBot.Scheduler.events = {}
end
