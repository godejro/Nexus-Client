-- A missing item can change the length of a map record. Repair before login;
-- never guess item flags or skip ahead in the game stream.
local rules = json.decode(g_resources.readFileContents('/modules/client_profiles/publisher-catalogs.json'))
local pendingDetail
local activeDownload
local selectedRevisions = {}

local function ruleFor(profile)
    for _, rule in ipairs(rules) do
        if rule.host == profile.host and rule.client == tonumber(profile.clientVersion)
            and rule.protocol == tonumber(profile.protocolVersion) then return rule end
    end
end

local function missingKey(id, version)
    return 'catalog-missing-' .. id .. '-' .. version
end

function recordMissingItem(id, version, item)
    if id == '' then return end
    g_settings.set(missingKey(id, version), item)
    g_settings.save()
    pendingDetail = string.format('Profile %s is missing item %d. Reconnect to check for a verified catalog update.', id, item)
end

function takeCatalogError()
    local detail = pendingDetail
    pendingDetail = nil
    return detail
end

local function hasItem(id)
    local thing = g_things.getThingType(id, ThingCategoryItem)
    return thing and thing:getId() == id
end

local function revisionPath(profile, rule)
    return string.format('/data/things/%d/%s/revisions/%s/', rule.client, profile.id, rule.sha256)
end

function rememberedRevision(profile)
    return selectedRevisions[profile.id]
end

function checkLoadedCatalog(profile, thingsModule)
    local rule = ruleFor(profile)
    local key = missingKey(profile.id, profile.clientVersion)
    local observed = tonumber(g_settings.get(key))
    local missing
    if observed and not hasItem(observed) then missing = observed end
    local baselineMissing = false
    if rule then
        for _, id in ipairs(rule.items) do
            if not hasItem(id) then
                baselineMissing = true
                missing = missing or id
                break
            end
        end
    end
    if not missing then
        if observed then g_settings.remove(key) end
        return true
    end
    local advice = string.format('Profile %s lacks item %d. Update the original server client and import its folder in Nexus Studio.', profile.id, missing)
    -- A historical failure alone must not lock the account out on later logins.
    if not baselineMissing then
        g_logger.warning(advice)
        return true
    end
    local path = revisionPath(profile, rule)
    if profile.assetPath == path then return false, advice end
    local mark = path .. 'complete.txt'
    if not g_resources.fileExists(mark) or g_resources.readFileContents(mark) ~= rule.sha256 then
        return false, advice, true
    end
    profile.assetPath = path
    if not thingsModule.loadProfileAssets(tonumber(profile.clientVersion)) then
        return false, thingsModule.getLoadError() or advice
    end
    for _, id in ipairs(rule.items) do
        if not hasItem(id) then return false, advice end
    end
    selectedRevisions[profile.id] = path
    if observed and hasItem(observed) then g_settings.remove(key) end
    return true
end

function fetchProfileCatalog(id, retry)
    if activeDownload then activeDownload.box:raise() return end
    local root = os.getenv('SystemRoot')
    if not root or not id:match('^[a-z0-9][a-z0-9._%-]*$') then
        displayErrorBox(tr('Profile Error'), 'Update the original server client and import its folder in Nexus Studio.')
        return
    end
    local now = g_clock.millis()
    local session = string.format('%d-%d', g_platform.getProcessId(), now)
    local worker = root .. '/System32/WindowsPowerShell/v1.0/powershell.exe'
    local ok = g_platform.spawnProcess(worker, {'-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass', '-File', g_resources.getWorkDir() .. 'updater/Start-Nexus.ps1',
        '-Mode','ProfileAssets','-Profile',id,'-Session',session})
    if not ok then displayErrorBox(tr('Profile Error'), 'Could not start the asset updater. Open Nexus Studio.') return end
    local box = displayCancelBox(tr('Updating server assets'), 'Downloading and verifying the server catalog for ' .. id .. '.')
    local repair = {box=box}
    activeDownload = repair
    connect(box, {onCancel=function()
        if repair.event then removeEvent(repair.event) end
        activeDownload = nil
    end})
    local function poll()
        local status = 'updater/sessions/' .. session .. '/asset-result.json'
        if not g_resources.fileExistsInWorkDir(status) and g_clock.millis()-now < 900000 then
            repair.event = scheduleEvent(poll, 500)
            return
        end
        activeDownload = nil
        box:destroy()
        local good, result = pcall(function()
            return json.decode(g_resources.readFileContentsFromWorkDir(status))
        end)
        if good and type(result)=='table' and result.ok then
            if getSelectedProfileId()==id and not g_game.isOnline() then retry() end
        else
            displayErrorBox(tr('Profile Error'), good and type(result)=='table' and result.message or 'Catalog update did not finish. Retry or import the source folder in Nexus Studio.')
        end
    end
    repair.event = scheduleEvent(poll, 500)
end

function stopCatalogCheck()
    if activeDownload then
        if activeDownload.event then removeEvent(activeDownload.event) end
        activeDownload.box:destroy()
        activeDownload=nil
    end
end
