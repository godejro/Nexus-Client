NexusBot.Items = { list = nil, byId = {} }

function NexusBot.Items.init()
  NexusBot.Items.list, NexusBot.Items.byId = nil, {}
end

local function load()
  if NexusBot.Items.list then return end
  NexusBot.Items.list = {}
  local thingTypes = g_things.getThingTypes(ThingCategoryItem or 0) or {}
  for id, thingType in pairs(thingTypes) do
    local numericId = tonumber(id)
    if numericId and numericId >= 100 and thingType then
      local name = thingType:getName()
      if name and name ~= '' then
        local entry = { id = numericId, name = name, thingType = thingType }
        NexusBot.Items.list[#NexusBot.Items.list + 1] = entry
        NexusBot.Items.byId[numericId] = entry
      end
    end
  end
  table.sort(NexusBot.Items.list, function(a, b) return a.id < b.id end)
end

function NexusBot.Items.get(itemId)
  load()
  itemId = tonumber(itemId)
  if NexusBot.Items.byId[itemId] then return NexusBot.Items.byId[itemId] end
  if itemId and itemId > 0 then return { id = itemId, name = 'Item ' .. itemId } end
end

function NexusBot.Items.search(query, limit)
  load()
  query, limit = tostring(query or ''):lower(), limit or 100
  local numeric = tonumber(query)
  local result = {}
  for _, item in ipairs(NexusBot.Items.list) do
    if query == '' or item.name:lower():find(query, 1, true) or (numeric and tostring(item.id):find(query, 1, true)) then
      result[#result + 1] = item
      if #result >= limit then break end
    end
  end
  if numeric and not NexusBot.Items.byId[numeric] then result[1] = { id = numeric, name = 'Item ' .. numeric } end
  return result
end
