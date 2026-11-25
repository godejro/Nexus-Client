ThingsLoaderController = Controller:new()

local filename = nil
local loaded = false
local loadedAssetPath = nil
local lastLoadError = nil

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
    -- Resetting the protocol after a failed load emits this event again.
    -- Version zero has no assets and must not create another error dialog.
    if not version or version <= 0 then
        loaded = false
        loadedAssetPath = nil
        return
    end
    lastLoadError = nil
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

    lastLoadError = table.concat(errorList, "\n")
    local manager = modules.client_profiles
    local profile = manager and manager.getActiveProfile and manager.getActiveProfile()
    -- Profile activation reports this failure to its caller. Only standalone
    -- asset loads own an error dialog here.
    if not profile then
        local messageBox = displayErrorBox(tr('Error'), lastLoadError)
        addEvent(function()
            messageBox:raise()
            messageBox:focus()
        end)
    end

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

function getLoadError()
    return lastLoadError
end

function ThingsLoaderController:onInit()
    self:registerEvents(g_game, {
        onClientVersionChange = load
    })
end

------------------------------------------------------------------------------
-- Item looks (client-bot contract): draw an item with another item's
-- appearance, only for this player. The item keeps its real id everywhere
-- (getId, packets, use, scripts, tile timers); nothing is sent to the server
-- and nothing is saved. Check `modules.game_things.setItemLook ~= nil`.
--   setItemLook(fromItemId, toItemId) -> true/false
--   clearItemLook(fromItemId)
--   clearItemLooks()
--   getItemLooks() -> { [fromId] = toId, ... }
--   hasLook(itemId) -> true when this client can draw that appearance
------------------------------------------------------------------------------
local itemLooks = {}

-- Cosmetics bundled with the client: they draw on every server, also where
-- the server's assets do not have these items. Twins share the same frames.
local BUNDLED_LOOKS = {
    -- id = { file, frame time in ms }; names as in the bot
    [56816] = {56816, 150}, -- Turquoise nebula
    [56817] = {56817, 150}, -- Yellow-green nebula
    [56819] = {56819, 150}, -- Purple nebula
    [56821] = {56821, 150}, -- Red-gold nebula
    [56823] = {56823, 150}, -- Navy nebula
    [56825] = {56825, 150}, -- Blue lightning
    [56843] = {56843, 150}, -- Bronze cube
    [56844] = {56844, 150}, -- Blue cube
    [56845] = {56845, 150}, -- Purple cube
    [56846] = {56846, 150}, -- Red cube
    [56815] = {56816, 150}, [56818] = {56817, 150}, [56820] = {56819, 150},
    [56822] = {56821, 150}, [56824] = {56823, 150}, [56826] = {56825, 150},
}
local COSMETIC_NAMES = {
    {56816, 'Turquoise nebula'}, {56817, 'Yellow-green nebula'}, {56819, 'Purple nebula'},
    {56821, 'Red-gold nebula'}, {56823, 'Navy nebula'}, {56825, 'Blue lightning'},
    {56843, 'Bronze cube'}, {56844, 'Blue cube'}, {56845, 'Purple cube'}, {56846, 'Red cube'},
}
-- Bundled cosmetics this client can draw: { {id=, name=}, ... }
function getCosmeticLooks()
    local list = {}
    for _, entry in ipairs(COSMETIC_NAMES) do
        if hasLook(entry[1]) then list[#list + 1] = {id = entry[1], name = entry[2]} end
    end
    return list
end
if g_things.loadItemLookImage then
    for id, look in pairs(BUNDLED_LOOKS) do
        g_things.loadItemLookImage(id, '/modules/game_things/itemlooks/' .. look[1] .. '.png', look[2])
    end
end

local function nativeLooks()
    return g_things.setItemLook ~= nil
end

local function itemId(value)
    value = tonumber(value)
    if not value or value % 1 ~= 0 or value < 1 or value > 65535 then return nil end
    return value
end

function hasLook(id)
    id = itemId(id)
    if not id or not nativeLooks() then return false end
    return g_things.hasItemLook(id) == true
end

function setItemLook(fromId, toId)
    fromId, toId = itemId(fromId), itemId(toId)
    if not fromId or not toId or not nativeLooks() then return false end
    if not g_things.setItemLook(fromId, toId) then return false end
    if fromId == toId then itemLooks[fromId] = nil else itemLooks[fromId] = toId end
    return true
end

function clearItemLook(fromId)
    fromId = itemId(fromId)
    if not fromId then return end
    itemLooks[fromId] = nil
    if nativeLooks() then g_things.clearItemLook(fromId) end
end

function clearItemLooks()
    itemLooks = {}
    if nativeLooks() then g_things.clearItemLooks() end
end

function getItemLooks()
    local result = {}
    if nativeLooks() then
        for fromId, toId in pairs(g_things.getItemLooks() or {}) do result[fromId] = toId end
    end
    return result
end

-- Reloading assets (another server) clears the looks in the engine; the ones
-- still valid for the new assets are applied again.
local function reapplyItemLooks()
    if not nativeLooks() then return end
    for fromId, toId in pairs(itemLooks) do
        if not g_things.setItemLook(fromId, toId) then itemLooks[fromId] = nil end
    end
end

connect(g_game, { onGameStart = reapplyItemLooks })
