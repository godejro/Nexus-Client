local PROFILE_ROOT = '/profiles'
local VERSION_ROOT = '/versions'
local activeProfile
local profiles = {}
local versionProfiles = {}
local mountedModulePath
local loadedProfileModules = {}
local startupProfileId

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function clone(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = clone(child)
    end
    return copy
end

local function isArray(value)
    if type(value) ~= 'table' then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then
            return false
        end
        count = count + 1
    end
    return count > 0
end

local function merge(base, overlay)
    if type(overlay) ~= 'table' then
        return clone(overlay)
    end
    if isArray(overlay) then
        return clone(overlay)
    end

    local result = type(base) == 'table' and clone(base) or {}
    for key, value in pairs(overlay) do
        if type(value) == 'table' and not isArray(value) then
            result[key] = merge(result[key], value)
        else
            result[key] = clone(value)
        end
    end
    return result
end

local function readJson(path)
    if not g_resources.fileExists(path) then
        return nil, string.format("File does not exist: %s", path)
    end
    local ok, result = pcall(function()
        return json.decode(g_resources.readFileContents(path))
    end)
    if not ok or type(result) ~= 'table' then
        return nil, string.format("Invalid JSON: %s", path)
    end
    return result
end

local function normalizeResourcePath(path)
    path = trim(path):gsub('\\', '/')
    if path == '' then
        return path
    end
    if path:sub(1, 1) ~= '/' then
        path = '/' .. path
    end
    if path:sub(-1) ~= '/' then
        path = path .. '/'
    end
    return path
end

local function safeSlug(value)
    value = trim(value):lower()
    return value:match('^[a-z0-9][a-z0-9._%-]*$') ~= nil and not value:find('%.%.', 1, true)
end

local function globPattern(glob)
    local pattern = tostring(glob):gsub('([%^%$%(%)%%%.%[%]%+%-])', '%%%1')
    pattern = pattern:gsub('%*', '.*'):gsub('%?', '.')
    return '^' .. pattern .. '$'
end

local function directoryHasPattern(path, glob)
    if not g_resources.directoryExists(path) then
        return false
    end
    local pattern = globPattern(glob)
    for _, fileName in ipairs(g_resources.listDirectoryFiles(path)) do
        if tostring(fileName):match(pattern) then
            return true
        end
    end
    return false
end

local SECRET_KEYS = {
    password = true,
    passwd = true,
    token = true,
    email = true,
    account = true,
    session = true,
    secret = true,
    apikey = true,
    api_key = true
}

local function findSecretKey(value, prefix)
    if type(value) ~= 'table' then
        return nil
    end
    for key, child in pairs(value) do
        local name = tostring(key)
        local path = prefix and (prefix .. '.' .. name) or name
        if SECRET_KEYS[name:lower()] then
            return path
        end
        local nested = findSecretKey(child, path)
        if nested then
            return nested
        end
    end
    return nil
end

local function loadVersionProfile(id, stack)
    id = trim(id)
    if id == '' then
        return {}, nil
    end
    if versionProfiles[id] then
        return clone(versionProfiles[id]), nil
    end
    if not safeSlug(id) then
        return nil, 'Invalid version profile id: ' .. id
    end

    stack = stack or {}
    if stack[id] then
        return nil, 'Version profile inheritance cycle: ' .. id
    end
    stack[id] = true

    local raw, err = readJson(string.format('%s/%s.json', VERSION_ROOT, id))
    if not raw then
        return nil, err
    end
    local resolved = {}
    if raw.extends then
        local parent, parentError = loadVersionProfile(raw.extends, stack)
        if not parent then
            return nil, parentError
        end
        resolved = parent
    end
    resolved = merge(resolved, raw)
    stack[id] = nil
    versionProfiles[id] = clone(resolved)
    return resolved, nil
end

local function loadRawProfile(id)
    if not safeSlug(id) then
        return nil, 'Invalid profile id: ' .. tostring(id)
    end
    return readJson(string.format('%s/%s/profile.json', PROFILE_ROOT, id))
end

local function resolveProfile(id, stack)
    stack = stack or {}
    if stack[id] then
        return nil, 'Profile inheritance cycle: ' .. tostring(id)
    end
    stack[id] = true

    local raw, err = loadRawProfile(id)
    if not raw then
        return nil, err
    end

    local resolved = {}
    if raw.baseProfile then
        local parent, parentError = resolveProfile(raw.baseProfile, stack)
        if not parent then
            return nil, parentError
        end
        resolved = merge(resolved, parent)
    end

    local version, versionError = loadVersionProfile(raw.versionProfile or resolved.versionProfile)
    if not version then
        return nil, versionError
    end
    resolved = merge(resolved, version)

    resolved = merge(resolved, raw)
    resolved.id = id
    resolved.assetPath = normalizeResourcePath(resolved.assetPath)
    resolved.soundPath = normalizeResourcePath(resolved.soundPath)
    stack[id] = nil
    return resolved, nil
end

local function unloadProfileModules()
    for index = #loadedProfileModules, 1, -1 do
        local module = g_modules.getModule(loadedProfileModules[index])
        if module and module:isLoaded() then
            if not module:canUnload() then
                return false, 'Profile module cannot be unloaded: ' .. loadedProfileModules[index]
            end
            module:unload()
        end
    end
    loadedProfileModules = {}

    if mountedModulePath then
        g_resources.removeSearchPath(mountedModulePath)
        mountedModulePath = nil
    end
    return true
end

local function loadProfileModules(profile)
    local unloaded, unloadError = unloadProfileModules()
    if not unloaded then
        return false, unloadError
    end
    if type(profile.modules) ~= 'table' or #profile.modules == 0 then
        return true
    end

    mountedModulePath = g_resources.getWorkDir() .. 'profiles/' .. profile.id .. '/modules'
    if not g_resources.directoryExists('/profiles/' .. profile.id .. '/modules') then
        return false, 'Profile modules directory is missing.'
    end
    if not g_resources.addSearchPath(mountedModulePath, true) then
        mountedModulePath = nil
        return false, 'Unable to mount profile modules directory.'
    end

    g_modules.discoverModules()
    for _, moduleName in ipairs(profile.modules) do
        local module = g_modules.getModule(tostring(moduleName))
        if not module or not module:load() then
            unloadProfileModules()
            return false, 'Unable to load profile module: ' .. tostring(moduleName)
        end
        loadedProfileModules[#loadedProfileModules + 1] = tostring(moduleName)
    end
    return true
end

local function resolveFeature(name)
    local feature = _G[tostring(name)]
    return type(feature) == 'number' and feature or nil
end

local function applyFeatureList(list, enabled)
    if type(list) ~= 'table' then
        return
    end
    for _, name in ipairs(list) do
        local feature = resolveFeature(name)
        if feature then
            if enabled then
                g_game.enableFeature(feature)
            else
                g_game.disableFeature(feature)
            end
        else
            g_logger.warning('[ProfileManager] Unknown feature: ' .. tostring(name))
        end
    end
end

local function parseStartupProfile()
    local options = tostring(g_app.getStartupOptions() or '')
    return options:match('%-%-profile%s*=%s*["\']?([%w._%-]+)') or
        options:match('%-%-profile%s+["\']?([%w._%-]+)')
end

function reload()
    profiles = {}
    versionProfiles = {}
    if not g_resources.directoryExists(PROFILE_ROOT) then
        return profiles
    end

    for _, id in ipairs(g_resources.listDirectoryFiles(PROFILE_ROOT)) do
        if safeSlug(id) and g_resources.fileExists(string.format('%s/%s/profile.json', PROFILE_ROOT, id)) then
            local profile, err = resolveProfile(id)
            if profile and profile.enabled ~= false then
                profiles[id] = profile
            else
                g_logger.warning('[ProfileManager] Skipping ' .. tostring(id) .. ': ' .. tostring(err or 'disabled'))
            end
        end
    end
    return profiles
end

function getProfiles()
    local result = {}
    for id, profile in pairs(profiles) do
        result[id] = clone(profile)
    end
    return result
end

function getSortedProfiles()
    local result = {}
    for _, profile in pairs(profiles) do
        result[#result + 1] = clone(profile)
    end
    table.sort(result, function(left, right)
        return tostring(left.name or left.id):lower() < tostring(right.name or right.id):lower()
    end)
    return result
end

function getProfile(id)
    return profiles[id] and clone(profiles[id]) or nil
end

function getActiveProfile()
    return activeProfile and clone(activeProfile) or nil
end

function getSelectedProfileId()
    return startupProfileId or g_settings.get('active-profile') or ''
end

function setSelectedProfile(id)
    if id ~= '' and not profiles[id] then
        return false, 'Unknown profile: ' .. tostring(id)
    end
    startupProfileId = nil
    g_settings.set('active-profile', id)
    g_settings.save()
    return true
end

function validateProfile(profileOrId)
    local profile = type(profileOrId) == 'table' and profileOrId or profiles[profileOrId]
    local errors = {}
    local warnings = {}
    if not profile then
        return false, { 'Profile does not exist.' }, warnings
    end

    local secretKey = findSecretKey(profile)
    if secretKey then
        errors[#errors + 1] = 'Credentials are not allowed in profile JSON: ' .. secretKey
    end

    if not safeSlug(profile.id) then
        errors[#errors + 1] = 'Profile id must be a safe slug.'
    end
    if not tonumber(profile.clientVersion) then
        errors[#errors + 1] = 'clientVersion is required.'
    end
    if not tonumber(profile.protocolVersion) then
        errors[#errors + 1] = 'protocolVersion is required.'
    end
    if profile.loginType ~= 'http-json' and profile.loginType ~= 'http-native' and profile.loginType ~= 'classic' then
        errors[#errors + 1] = 'loginType must be http-json, http-native, or classic.'
    end
    if trim(profile.host) == '' then
        errors[#errors + 1] = 'host is required.'
    end
    local loginPort = tonumber(profile.loginPort)
    if not loginPort or loginPort < 1 or loginPort > 65535 then
        errors[#errors + 1] = 'loginPort must be between 1 and 65535.'
    end
    if profile.assetPath:find('%.%.', 1, true) then
        errors[#errors + 1] = 'assetPath cannot contain parent traversal.'
    elseif profile.assetPath == '' or not g_resources.directoryExists(profile.assetPath) then
        errors[#errors + 1] = 'Asset directory does not exist: ' .. tostring(profile.assetPath)
    else
        local sharedVersion = profile.assetPath:match('^/data/things/(%d+)/$')
        if (profile.assetMode == nil or profile.assetMode == 'shared-reference') and sharedVersion and
            tonumber(sharedVersion) ~= tonumber(profile.clientVersion) then
            errors[#errors + 1] = 'Shared asset directory does not match clientVersion.'
        end
        for _, pattern in ipairs(profile.requiredAssets or {}) do
            if not directoryHasPattern(profile.assetPath, pattern) then
                errors[#errors + 1] = 'Required asset is missing: ' .. tostring(pattern)
            end
        end
    end
    if profile.gameHostPolicy == 'profile-override' and trim(profile.gameHost) == '' then
        errors[#errors + 1] = 'gameHost is required for profile-override policy.'
    end
    if profile.capabilities and profile.capabilities.requiresLocalGameProxy then
        warnings[#warnings + 1] = 'This profile expects a local game proxy to be running.'
    end
    if type(profile.modules) ~= 'table' then
        errors[#errors + 1] = 'modules must be an array.'
    end
    return #errors == 0, errors, warnings
end

function getAssetPath(clientVersion)
    if activeProfile and tonumber(activeProfile.clientVersion) == tonumber(clientVersion) and activeProfile.assetPath ~= '' then
        return activeProfile.assetPath
    end
    return string.format('/data/things/%d/', tonumber(clientVersion) or 0)
end

function getSoundPath(clientVersion)
    if activeProfile and tonumber(activeProfile.clientVersion) == tonumber(clientVersion) and activeProfile.soundPath ~= '' then
        return activeProfile.soundPath
    end
    return string.format('/data/sounds/%d/', tonumber(clientVersion) or 0)
end

function getRsaPath(clientVersion)
    return getAssetPath(clientVersion) .. 'rsa.txt'
end

function hasCapability(name)
    return activeProfile and type(activeProfile.capabilities) == 'table' and activeProfile.capabilities[name] == true
end

function getDebugFlag(name)
    return activeProfile and type(activeProfile.debug) == 'table' and activeProfile.debug[name] == true
end

function applyProfile(id)
    if g_game.isOnline() then
        return false, { 'Disconnect before changing the active profile.' }, {}
    end
    local profile = profiles[id]
    local valid, errors, warnings = validateProfile(profile)
    if not valid then
        return false, errors, warnings
    end

    g_things.waitForPendingTextureLoads()
    local previousProfile = activeProfile
    local candidateProfile = clone(profile)
    local modulesOk, moduleError = loadProfileModules(candidateProfile)
    if not modulesOk then
        activeProfile = previousProfile
        return false, { moduleError }, warnings
    end
    activeProfile = candidateProfile

    local clientVersion = tonumber(activeProfile.clientVersion)
    local protocolVersion = tonumber(activeProfile.protocolVersion)
    if g_game.getClientVersion() == clientVersion then
        g_game.reloadClientFeatures()
    else
        g_game.setClientVersion(clientVersion)
    end
    g_game.setProtocolVersion(protocolVersion)
    g_game.setLoginPreviewState(tonumber(activeProfile.loginPreviewState) or 0)
    if trim(activeProfile.clientVersionString) ~= '' then
        g_game.setClientVersionString(activeProfile.clientVersionString)
    end

    local featureOverrides = activeProfile.features or {}
    applyFeatureList(featureOverrides.disable, false)
    applyFeatureList(featureOverrides.enable, true)

    local thingsModule = modules.game_things
    local assetsLoaded = thingsModule and thingsModule.getLoadedAssetPath and
        thingsModule.getLoadedAssetPath() == activeProfile.assetPath
    if not assetsLoaded and thingsModule and thingsModule.loadProfileAssets then
        assetsLoaded = thingsModule.loadProfileAssets(clientVersion)
    end

    local loadedAssetPath = thingsModule and thingsModule.getLoadedAssetPath and
        thingsModule.getLoadedAssetPath() or nil
    local runtimeMatches = g_game.getClientVersion() == clientVersion and
        g_game.getProtocolVersion() == protocolVersion
    if not assetsLoaded or loadedAssetPath ~= activeProfile.assetPath or not runtimeMatches then
        local errorMessage = string.format(
            '[ProfileMismatch] id=%s expectedClient=%d actualClient=%d expectedProtocol=%d actualProtocol=%d expectedAssets=%s actualAssets=%s',
            tostring(activeProfile.id),
            clientVersion,
            g_game.getClientVersion(),
            protocolVersion,
            g_game.getProtocolVersion(),
            tostring(activeProfile.assetPath),
            tostring(loadedAssetPath))
        g_logger.error(errorMessage)
        unloadProfileModules()
        activeProfile = nil
        g_game.setActiveProfileId('')
        return false, { errorMessage }, warnings
    end

    g_game.setActiveProfileId(activeProfile.id)
    g_settings.set('active-profile', id)
    g_settings.save()
    g_logger.info(string.format(
        '[ProfileManager] Active=%s client=%d protocol=%d login=%s assets=%s',
        activeProfile.id,
        clientVersion,
        tonumber(activeProfile.protocolVersion),
        activeProfile.loginType,
        activeProfile.assetPath))
    return true, {}, warnings
end

function clearActiveProfile()
    if g_game.isOnline() then
        return false
    end
    g_things.waitForPendingTextureLoads()
    local hadActiveProfile = activeProfile ~= nil
    local unloaded = unloadProfileModules()
    if not unloaded then
        return false
    end
    activeProfile = nil
    g_game.setActiveProfileId('')
    local clientVersion = g_game.getClientVersion()
    if hadActiveProfile and clientVersion > 0 and modules.game_things and
        modules.game_things.getLoadedAssetPath and modules.game_things.loadProfileAssets then
        local defaultPath = getAssetPath(clientVersion)
        if modules.game_things.getLoadedAssetPath() ~= defaultPath then
            modules.game_things.loadProfileAssets(clientVersion)
        end
    end
    g_settings.set('active-profile', '')
    g_settings.save()
    return true
end

function init()
    startupProfileId = parseStartupProfile()
    reload()
    local profileCount = 0
    for _ in pairs(profiles) do
        profileCount = profileCount + 1
    end
    if startupProfileId and not profiles[startupProfileId] then
        g_logger.warning('[ProfileManager] Unknown --profile value: ' .. tostring(startupProfileId))
        startupProfileId = nil
    end
    g_logger.info(string.format('[ProfileManager] Discovered=%d startup=%s',
        profileCount, startupProfileId or 'none'))
end

function terminate()
    g_things.waitForPendingTextureLoads()
    unloadProfileModules()
    activeProfile = nil
    g_game.setActiveProfileId('')
    profiles = {}
    versionProfiles = {}
end

init()
