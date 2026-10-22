NexusBot.Storage = {
  path = NexusBot.storagePath or ((NexusBot.resourceRoot or '/nexus_bot') .. '/storage.json'),
  directory = NexusBot.storageDirectory or NexusBot.resourceRoot or '/nexus_bot',
  schemaVersion = 1,
  migrations = {},
  saveEvent = nil,
  data = nil
}

local defaultData = {
  schemaVersion = 1,
  settings = { debug = false, masterEnabled = false, windowPositions = {} },
  modules = {},
  customSpells = {}
}

function NexusBot.Storage.registerMigration(fromVersion, toVersion, callback)
  NexusBot.Storage.migrations[fromVersion] = { to = toVersion, run = callback }
end

function NexusBot.Storage.load()
  local loaded
  if g_resources.fileExists(NexusBot.Storage.path) then
    local ok, result = pcall(function()
      return json.decode(g_resources.readFileContents(NexusBot.Storage.path))
    end)
    if ok and type(result) == 'table' then
      loaded = result
    else
      NexusBot.Logger.warn('Storage', 'Invalid storage ignored: ' .. tostring(result))
    end
  end
  loaded = loaded or {}
  local version = tonumber(loaded.schemaVersion) or 0
  while version < NexusBot.Storage.schemaVersion do
    local migration = NexusBot.Storage.migrations[version]
    if not migration then break end
    local ok, result = pcall(migration.run, loaded)
    if not ok then
      NexusBot.Logger.error('Storage', 'Migration failed: ' .. tostring(result))
      break
    end
    loaded = result or loaded
    version = migration.to
    loaded.schemaVersion = version
  end
  NexusBot.Storage.data = NexusBot.merge(defaultData, loaded)
  NexusBot.Storage.data.schemaVersion = NexusBot.Storage.schemaVersion
  -- Keep UI preferences, but require an explicit setup load for automation.
  -- Preserve the old session as a recoverable setup once during migration.
  local previous=NexusBot.Storage.data
  if not previous.settings.manualConfigV1 and next(previous.modules or {}) then
    local directory=NexusBot.Storage.directory..'/setups'
    g_resources.makeDir(directory)
    local backup=directory..'/Previous session.json'
    if not g_resources.fileExists(backup) then
      assert(g_resources.writeFileContents(backup,json.encode(previous,2))~=false,'Could not preserve previous bot settings')
    end
  end
  NexusBot.Storage.data=NexusBot.copy(defaultData)
  NexusBot.Storage.data.settings=NexusBot.copy(previous.settings)
  NexusBot.Storage.data.settings.masterEnabled=false
  NexusBot.Storage.data.settings.manualConfigV1=true
  NexusBot.Logger.setDebug(NexusBot.Storage.data.settings.debug == true)
  return NexusBot.Storage.data
end

function NexusBot.Storage.get()
  return NexusBot.Storage.data or NexusBot.Storage.load()
end

function NexusBot.Storage.saveNow()
  if NexusBot.Storage.saveEvent then
    pcall(removeEvent, NexusBot.Storage.saveEvent)
    NexusBot.Storage.saveEvent = nil
  end
  -- A mounted source directory can exist while its writable overlay does not.
  -- makeDir is idempotent and must target the write layer even in that case.
  g_resources.makeDir(NexusBot.Storage.directory)
  local ok, encoded = pcall(function() return json.encode(NexusBot.Storage.get(), 2) end)
  if not ok then NexusBot.Logger.error('Storage', encoded) return false,encoded end
  if #encoded > 10 * 1024 * 1024 then return false,'Refusing a storage file above 10 MB' end
  local written, result = pcall(g_resources.writeFileContents,NexusBot.Storage.path,encoded)
  if not written or result==false then
    local message=written and 'Resource writer refused storage save.' or tostring(result)
    NexusBot.Logger.error('Storage',message)
    return false,message
  end
  return true
end

function NexusBot.Storage.touch()
  if NexusBot.EventBus then NexusBot.EventBus.emit('storageChanged') end
  if NexusBot.Storage.saveEvent then pcall(removeEvent, NexusBot.Storage.saveEvent) end
  NexusBot.Storage.saveEvent = scheduleEvent(function()
    NexusBot.Storage.saveEvent = nil
    NexusBot.Storage.saveNow()
  end, 250)
end

function NexusBot.Storage.terminate()
  NexusBot.Storage.saveNow()
end
