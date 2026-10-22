ThingsLoaderController = Controller:new()

local filename = nil
local loaded = false
local loadedAssetPath = nil

local function normalizePath(path)
    path = tostring(path or ''):gsub('\\', '/')
    if path:sub(-1) ~= '/' then
        path = path .. '/'
    end
    return path
end

local function getAssetPath(version)
    if modules.client_profiles and modules.client_profiles.getAssetPath then
        return normalizePath(modules.client_profiles.getAssetPath(version))
    end
    return string.format('/data/things/%d/', version)
end

local function getSoundPath(version)
    if modules.client_profiles and modules.client_profiles.getSoundPath then
        return normalizePath(modules.client_profiles.getSoundPath(version))
    end
    return string.format('/data/sounds/%d/', version)
end

local function validateAssetProfile(assetPath)
    local profilePath = assetPath .. 'asset-profile.json'
    if not g_resources.fileExists(profilePath) then
        return true
    end

    local ok, profile = pcall(function()
        return json.decode(g_resources.readFileContents(profilePath))
    end)
    if not ok or type(profile) ~= 'table' or type(profile.files) ~= 'table' then
        return false, string.format("Invalid asset validation profile: '%s'", profilePath)
    end

    for fileName, expectedHash in pairs(profile.files) do
        local filePath = assetPath .. fileName
        if not g_resources.fileExists(filePath) then
            return false, string.format("Required asset is missing: '%s'", filePath)
        end

        local contents = g_resources.readFileContents(filePath)
        local actualHash = g_crypt.sha256(contents):lower()
        if actualHash ~= tostring(expectedHash):lower() then
            return false, string.format(
                "Asset profile mismatch for '%s' (expected %s, got %s).",
                filePath,
                tostring(expectedHash):lower(),
                actualHash)
        end
    end

    return true
end

function setFileName(name)
    filename = name
end

function isLoaded()
    return loaded
end

local function tryLoadDatWithFallbacks(datPath)
    if g_things.loadDat(datPath) then
        return true
    end

    local featureFlags = {
        GameSpritesU32,
        GameEnhancedAnimations,
        GameIdleAnimations
    }

    local combinations = {
        { 1 }, { 2 }, { 3 },
        { 1, 2 }, { 1, 3 }, { 2, 3 },
        { 1, 2, 3 }
    }

    for _, combo in ipairs(combinations) do
        for _, idx in ipairs(combo) do
            g_game.enableFeature(featureFlags[idx])
        end

        if g_things.loadDat(datPath) then
            return true
        end
    end

    return false
end

local function load(version)
    local errorList = {}
    local assetPath = getAssetPath(version)
    local soundPath = getSoundPath(version)
    local profileValid, profileError = validateAssetProfile(assetPath)
    if not profileValid then
        errorList[#errorList + 1] = profileError
    end

    local versionStringPath = assetPath .. 'client-version.txt'
    local versionString = ''
    if g_resources.fileExists(versionStringPath) then
        versionString = g_resources.readFileContents(versionStringPath):gsub('^%s+', ''):gsub('%s+$', '')
    end
    g_game.setClientVersionString(versionString)

    if #errorList == 0 and version >= 1281 and not g_game.getFeature(GameLoadSprInsteadProtobuf) then
        local filePath = resolvepath(assetPath)
        if not g_things.loadAppearances(filePath) then
            errorList[#errorList + 1] = "Couldn't load assets"
        end
        if not g_things.loadStaticData(filePath) then
            errorList[#errorList + 1] = "Couldn't load staticdata"
        end
        if g_game.getFeature(GameProficiency) and not g_things.resolveProficienciesFile(filePath) then
            g_logger.warning(string.format(
                    "[game_things.load()] Couldn't load %sproficiencies-<hash>.json", assetPath))
        end
    elseif #errorList == 0 then
        local datPath, sprPath
        if filename then
            datPath = resolvepath('/data/things/' .. filename)
            sprPath = resolvepath('/data/things/' .. filename)
        else
            datPath = resolvepath(assetPath .. 'Tibia')
            sprPath = resolvepath(assetPath .. 'Tibia')
        end

        g_logger.setLevel(5)
        if not tryLoadDatWithFallbacks(datPath) then
            errorList[#errorList + 1] = tr('Unable to load dat file, please place a valid dat in \'%s.dat\'', datPath)
        end
        g_logger.setLevel(1)

        if not g_sprites.loadSpr(sprPath) then
            errorList[#errorList + 1] = tr('Unable to load spr file, please place a valid spr in \'%s.spr\'', sprPath)
        end
        if g_game.getFeature(GameLoadSprInsteadProtobuf) and version >= 1281 then
            local staticPath = resolvepath(assetPath .. 'appearances')
            if not g_things.loadAppearances(staticPath) then
                g_logger.warning(string.format(
                    "[game_things.load()] Couldn't load %sappearances.dat, possible packets error.", assetPath))
            end
        end
    end

    loaded = #errorList == 0
    if loaded then
        loadedAssetPath = assetPath
        g_settings.set('last-assets-version', version)
        g_settings.set('last-assets-path', assetPath)
        g_settings.save()

        -- loading client files was successful, try to load sounds now
        -- sound files are optional, this means that failing to load them
        -- will not block logging into game
        if g_resources.fileExists(soundPath .. 'catalog-sound.json') then
            g_sounds.loadClientFiles(resolvepath(soundPath))
        end
        g_logger.info(string.format('[game_things] Loaded client %d assets from %s', version, assetPath))
        return
    end

    loadedAssetPath = nil

    local messageBox = displayErrorBox(tr('Error'), table.concat(errorList, "\n"))
    addEvent(function()
        messageBox:raise()
        messageBox:focus()
    end)

    g_game.setClientVersion(0)
    g_game.setProtocolVersion(0)
end

function loadProfileAssets(version)
    load(tonumber(version) or g_game.getClientVersion())
    return loaded
end

function getLoadedAssetPath()
    return loadedAssetPath
end

function ThingsLoaderController:onInit()
    self:registerEvents(g_game, {
        onClientVersionChange = load
    })
end
