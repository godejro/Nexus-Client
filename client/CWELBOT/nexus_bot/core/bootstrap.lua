NexusBot = NexusBot or {}
NexusBot.Core = NexusBot.Core or {}
NexusBot.UI = NexusBot.UI or {}
NexusBot.Features = NexusBot.Features or {}
AnchorTop=AnchorTop or 1
AnchorBottom=AnchorBottom or 2
AnchorLeft=AnchorLeft or 3
AnchorRight=AnchorRight or 4
AnchorVerticalCenter=AnchorVerticalCenter or 5
AnchorHorizontalCenter=AnchorHorizontalCenter or 6

function NexusBot.prepareStyle(text)
  return text:gsub('@NEXUS_ASSETS@',NexusBot.assetRoot or ((NexusBot.resourceRoot or '/nexus_bot')..'/assets'))
end

function NexusBot.loadUI(name, parent)
  local embedded=NexusBot.embeddedUI and NexusBot.embeddedUI[name]
  if embedded and g_ui.loadUIFromString then return g_ui.loadUIFromString(NexusBot.prepareStyle(embedded),parent) end
  local path=(NexusBot.resourceRoot or '/nexus_bot')..'/ui/'..name..'.otui'
  return g_ui.loadUIFromString(NexusBot.prepareStyle(g_resources.readFileContents(path)),parent)
end

function NexusBot.importStyle(name)
  local embedded=NexusBot.embeddedUI and NexusBot.embeddedUI[name]
  local path=(NexusBot.resourceRoot or '/nexus_bot')..'/ui/'..name..'.otui'
  local contents=NexusBot.prepareStyle(embedded or g_resources.readFileContents(path))
  if g_ui.importStyleFromString then return g_ui.importStyleFromString(contents) end
  return g_ui.loadUIFromString(contents)
end

local function unpackValues(values, index, last)
  index = index or 1
  last = last or #values
  if index > last then return end
  return values[index], unpackValues(values, index + 1, last)
end

function NexusBot.now()
  if g_clock and g_clock.millis then return g_clock.millis() end
  if type(now) == 'number' then return now end
  return math.floor(os.clock() * 1000)
end

function NexusBot.copy(value, seen)
  if type(value) ~= 'table' then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, item in pairs(value) do
    result[NexusBot.copy(key, seen)] = NexusBot.copy(item, seen)
  end
  return result
end

function NexusBot.merge(defaults, loaded)
  if type(defaults) ~= 'table' then
    if loaded ~= nil then return loaded end
    return defaults
  end
  if type(loaded) ~= 'table' then return NexusBot.copy(defaults) end
  local result = NexusBot.copy(loaded)
  for key, value in pairs(defaults) do
    if result[key] == nil then
      result[key] = NexusBot.copy(value)
    elseif type(value) == 'table' and type(result[key]) == 'table' and #value == 0 then
      result[key] = NexusBot.merge(value, result[key])
    end
  end
  return result
end

function NexusBot.id(prefix)
  NexusBot._idCounter = (NexusBot._idCounter or 0) + 1
  return string.format('%s_%d_%d', prefix or 'id', NexusBot.now(), NexusBot._idCounter)
end

function NexusBot.safeCall(scope, callback, ...)
  local args = {...}
  local ok, result = pcall(function() return callback(unpackValues(args)) end)
  if not ok and NexusBot.Logger then NexusBot.Logger.error(scope, result) end
  return ok, result
end
