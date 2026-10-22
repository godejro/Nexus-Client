NexusBot.Profiles = {}

local function moduleData(moduleId)
  local data = NexusBot.Storage.get()
  data.modules[moduleId] = data.modules[moduleId] or { activeProfile = nil, profiles = {} }
  return data.modules[moduleId]
end

local function uniqueName(container, wanted, ignoredId)
  local base = (wanted and wanted ~= '') and wanted or 'profile'
  local name, suffix = base, 2
  local used = {}
  for _, profile in ipairs(container.profiles) do
    if profile.id ~= ignoredId and type(profile.name)=='string' then used[profile.name:lower()] = true end
  end
  while used[name:lower()] do name = base .. ' ' .. suffix suffix = suffix + 1 end
  return name
end

function NexusBot.Profiles.ensure(moduleId, defaults)
  local data = moduleData(moduleId)
  if type(data.profiles)~='table' then data.profiles={} end
  local sanitized={}
  for index,profile in ipairs(data.profiles) do
    if type(profile)=='table' then
      profile.id=NexusBot.Validation.text(profile.id,NexusBot.id('profile'))
      profile.name=NexusBot.Validation.text(profile.name,'profile '..index)
      profile.enabled=profile.enabled==true
      for key,value in pairs(defaults or {}) do if profile[key]==nil then profile[key]=NexusBot.copy(value) end end
      sanitized[#sanitized+1]=profile
    else
      NexusBot.Logger.warn('Profiles','Ignored malformed profile in '..moduleId)
    end
  end
  data.profiles=sanitized
  if #data.profiles == 0 then
    local profile = { id = NexusBot.id('profile'), name = 'default', enabled = false }
    for key, value in pairs(defaults or {}) do profile[key] = NexusBot.copy(value) end
    data.profiles[1] = profile
    data.activeProfile = profile.id
    NexusBot.Storage.touch()
  end
  if not NexusBot.Profiles.getActive(moduleId) then data.activeProfile = data.profiles[1].id end
  return data
end

function NexusBot.Profiles.list(moduleId) return moduleData(moduleId).profiles end

function NexusBot.Profiles.get(moduleId, profileId)
  for _, profile in ipairs(moduleData(moduleId).profiles) do
    if profile.id == profileId then return profile end
  end
end

function NexusBot.Profiles.getActive(moduleId)
  local data = moduleData(moduleId)
  return NexusBot.Profiles.get(moduleId, data.activeProfile)
end

function NexusBot.Profiles.select(moduleId, profileId)
  local data = moduleData(moduleId)
  if not NexusBot.Profiles.get(moduleId, profileId) then return false end
  data.activeProfile = profileId
  NexusBot.Storage.touch()
  NexusBot.EventBus.emit('profileChanged', moduleId, profileId)
  return true
end

function NexusBot.Profiles.create(moduleId, name, defaults)
  local data = moduleData(moduleId)
  local profile = { id = NexusBot.id('profile'), name = uniqueName(data, name), enabled = false }
  for key, value in pairs(defaults or {}) do profile[key] = NexusBot.copy(value) end
  data.profiles[#data.profiles + 1] = profile
  data.activeProfile = profile.id
  NexusBot.Storage.touch()
  NexusBot.EventBus.emit('profilesChanged', moduleId)
  return profile
end

function NexusBot.Profiles.rename(moduleId, profileId, name)
  local profile, data = NexusBot.Profiles.get(moduleId, profileId), moduleData(moduleId)
  if not profile then return false end
  profile.name = uniqueName(data, tostring(name or 'profile'), profileId)
  NexusBot.Storage.touch()
  NexusBot.EventBus.emit('profilesChanged', moduleId)
  return true
end

function NexusBot.Profiles.clone(moduleId, profileId)
  local source, data = NexusBot.Profiles.get(moduleId, profileId), moduleData(moduleId)
  if not source then return end
  local clone = NexusBot.copy(source)
  clone.id = NexusBot.id('profile')
  clone.name = uniqueName(data, source.name .. ' copy')
  clone.enabled = false
  data.profiles[#data.profiles + 1] = clone
  data.activeProfile = clone.id
  NexusBot.Storage.touch()
  NexusBot.EventBus.emit('profilesChanged', moduleId)
  return clone
end

function NexusBot.Profiles.delete(moduleId, profileId)
  local data = moduleData(moduleId)
  if #data.profiles <= 1 then return false, 'At least one profile is required' end
  for index, profile in ipairs(data.profiles) do
    if profile.id == profileId then
      table.remove(data.profiles, index)
      if data.activeProfile == profileId then data.activeProfile = data.profiles[math.min(index, #data.profiles)].id end
      NexusBot.Storage.touch()
      NexusBot.EventBus.emit('profilesChanged', moduleId)
      return true
    end
  end
  return false
end
