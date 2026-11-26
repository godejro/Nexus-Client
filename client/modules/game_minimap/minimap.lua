local iconTopMenu = nil
-- @ Minimap
local minimapWidget = nil -- bot fix
local otmm = true
local oldPos = nil
local fullscreenWidget
local virtualFloor = 7
local bundledMinimapFile = '/minimap-full.otmm'
local currentDayTime = {
    h = 12,
    m = 0
}
local currentMinimapFile = nil
local staticMinimapAssetsDir = nil
local loadedStaticMinimapFloors = {}
local wideMap = false
local mainMapSpace, extraMapSpace
local mapGeometryHandlers
local openedExtraForMap = false

-- The expanded map overlays two containers. A drop anywhere over its header
-- or contents must go below its reserved space, never behind the map.
local function dropBelowMap(_, widget, mousePos)
    if not widget or not widget.UIMiniWindowContainer or widget.fixedPanel then return false end
    local main=modules.game_interface.getMainRightPanel()
    local extra=modules.game_interface.getRightExtraPanel()
    local container=wideMap and mousePos.x<main:getX() and extra or main
    if widget.moveOnlyToMain then container=main
    elseif container==main then container=modules.game_interface.getRightPanel() end
    if not container then return false end
    if widget.setMovedChildMargin then widget.setMovedChildMargin(widget.movedOldMargin or 0) end
    widget.setMovedChildMargin=nil widget.movedOldMargin=nil
    widget.movedWidget=container==extra and extraMapSpace or (container==main and (wideMap and mainMapSpace or mapController.ui) or nil)
    widget.movedIndex=1
    return container:onDrop(widget,mousePos)
end

local function arrangeWideMap()
    if not wideMap or not mapController or not mapController.ui or mapController.ui:isDestroyed() then return end
    local root=modules.game_interface.getRootPanel()
    local main=modules.game_interface.getMainRightPanel()
    local extra=modules.game_interface.getRightExtraPanel()
    if not root or not main or not extra then return end
    local width=main:getWidth()+extra:getWidth()+extra:getMarginRight()
    local height=mapController.ui:getHeight()
    mapController.ui:setWidth(width)
    mapController.ui:setPosition({x=main:getX()-extra:getWidth()-extra:getMarginRight()-root:getX(),
                                  y=main:getY()-root:getY()})
    if mainMapSpace then mainMapSpace:setHeight(height) end
    if extraMapSpace then extraMapSpace:setHeight(height) end
    mapController.ui:raise()
end

local function releaseWideMap()
    if not wideMap then return end
    wideMap=false
    local root=modules.game_interface and modules.game_interface.getRootPanel()
    local main=modules.game_interface and modules.game_interface.getMainRightPanel()
    local extra=modules.game_interface and modules.game_interface.getRightExtraPanel()
    if mapGeometryHandlers then
        for _,widget in ipairs({root,main,extra}) do
            if widget and not widget:isDestroyed() then disconnect(widget,mapGeometryHandlers) end
        end
        mapGeometryHandlers=nil
    end
    if mapController and mapController.ui and not mapController.ui:isDestroyed() and main and not main:isDestroyed() then
        mapController.ui:setParent(main)
        main:moveChildToIndex(mapController.ui,1)
        mapController.ui:setWidth(main:getWidth())
        mapController.ui.widenMap:setText('<')
    end
    for _,widget in ipairs({mainMapSpace,extraMapSpace}) do
        if widget and not widget:isDestroyed() then widget:destroy() end
    end
    mainMapSpace,extraMapSpace=nil,nil
    if openedExtraForMap then
        openedExtraForMap=false
        modules.client_options.setOption('showRightExtraPanel',false)
    end
    if modules.game_mainpanel and modules.game_mainpanel.reloadMainPanelSizes then
        modules.game_mainpanel.reloadMainPanelSizes()
    end
end

function toggleWideMinimap()
    if wideMap then releaseWideMap() return end
    if not mapController or not mapController.ui or mapController.ui:isDestroyed() then return end
    local main=modules.game_interface.getMainRightPanel()
    local extra=modules.game_interface.getRightExtraPanel()
    local root=modules.game_interface.getRootPanel()
    if not main or not extra or not root then return end
    openedExtraForMap=not modules.client_options.getOption('showRightExtraPanel')
    if openedExtraForMap then modules.client_options.setOption('showRightExtraPanel',true) end
    local height=mapController.ui:getHeight()
    mainMapSpace=g_ui.createWidget('UIWidget',main)
    mainMapSpace:setId('wideMinimapMainSpace') mainMapSpace:setHeight(height)
    mainMapSpace.panelHeight=height
    mainMapSpace.fixedPanel=true
    main:moveChildToIndex(mainMapSpace,1)
    extraMapSpace=g_ui.createWidget('UIWidget',extra)
    extraMapSpace:setId('wideMinimapExtraSpace') extraMapSpace:setHeight(height)
    extraMapSpace.fixedPanel=true
    extra:moveChildToIndex(extraMapSpace,1)
    mapController.ui:setParent(root)
    mapController.ui:breakAnchors()
    mapController.ui.widenMap:setText('>')
    wideMap=true
    mapGeometryHandlers={onGeometryChange=arrangeWideMap,onVisibilityChange=arrangeWideMap}
    for _,widget in ipairs({root,main,extra}) do connect(widget,mapGeometryHandlers) end
    arrangeWideMap()
    if modules.game_mainpanel and modules.game_mainpanel.reloadMainPanelSizes then
        modules.game_mainpanel.reloadMainPanelSizes()
    end
end

local function sanitizeProfilePart(value)
    value = tostring(value or ''):lower()
    value = value:gsub('^https?://', '')
    value = value:gsub('[^%w%._%-]', '_')
    value = value:gsub('_+', '_')
    value = value:gsub('^_+', ''):gsub('_+$', '')
    return value ~= '' and value or 'unknown'
end

-- The explored map belongs to the server (Nexus Studio profile), shared by
-- every character on it. Without a profile the login host and port decide.
local function legacyMinimapProfileKey()
    local host = (G and G.host) or g_settings.getString('host') or 'unknown'
    local port = (G and G.port) or g_settings.get('port') or 0
    local version = g_game.getClientVersion()
    if not version or version == 0 then
        version = g_settings.getInteger('client-version') or 0
    end
    return string.format('%s_%s_%s', sanitizeProfilePart(host), sanitizeProfilePart(port),
        sanitizeProfilePart(version))
end

function getMinimapProfileKey()
    local manager = modules.client_profiles
    local profile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    if profile and profile.id and tostring(profile.id) ~= '' then
        return 'server_' .. sanitizeProfilePart(profile.id)
    end
    return legacyMinimapProfileKey()
end

-- Maps saved under the old host/port key are carried over once.
local function migrateMinimapFile(extension)
    local key = getMinimapProfileKey()
    local legacy = legacyMinimapProfileKey()
    if key == legacy then return end
    local target = '/minimaps/' .. key .. extension
    local source = '/minimaps/' .. legacy .. extension
    if not g_resources.fileExists(target) and g_resources.fileExists(source) then
        local data = g_resources.readFileContents(source)
        if data and #data > 0 then
            g_resources.makeDir('/minimaps')
            g_resources.writeFileContents(target, data)
        end
    end
end

function getMinimapFile()
    g_resources.makeDir('/minimaps')
    return '/minimaps/' .. getMinimapProfileKey() .. '.otmm'
end

function getMinimapSettingsKey()
    return 'Minimap_' .. getMinimapProfileKey()
end

function getMinimapAssetsDir()
    local manager = modules.client_profiles
    local profile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    local assetsDir = profile and profile.assetPath or nil
    if not assetsDir or assetsDir == '' then
        assetsDir = string.format('/data/things/%d/', g_game.getClientVersion())
    end
    return assetsDir:gsub('/+$', '')
end

local function getProfileOtmmFile()
    local manager = modules.client_profiles
    local profile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    local assetsDir = getMinimapAssetsDir()
    local candidates = {}

    if profile and profile.minimapFile and tostring(profile.minimapFile) ~= '' then
        local configured = tostring(profile.minimapFile):gsub('\\', '/')
        if configured:sub(1, 1) ~= '/' then
            configured = assetsDir .. '/' .. configured
        end
        candidates[#candidates + 1] = configured
    end

    candidates[#candidates + 1] = assetsDir .. '/minimap.otmm'
    candidates[#candidates + 1] = assetsDir .. '/minimap-full.otmm'
    candidates[#candidates + 1] = assetsDir .. '/automap.otmm'

    for _, candidate in ipairs(candidates) do
        if g_resources.fileExists(candidate) then
            return candidate
        end
    end

    if g_resources.directoryExists(assetsDir) then
        local files = g_resources.listDirectoryFiles(assetsDir)
        table.sort(files)
        for _, fileName in ipairs(files) do
            local lowerName = tostring(fileName):lower()
            if lowerName:match('minimap.*%.otmm$') or lowerName:match('automap.*%.otmm$') then
                return assetsDir .. '/' .. fileName
            end
        end
    end
    return nil
end

local function showMinimapError(message)
    g_logger.error('[Minimap] ' .. message)
    displayErrorBox(tr('Minimap Error'), message)
end

local function loadBundledMinimap()
    if not g_resources.fileExists(bundledMinimapFile) then
        return true
    end

    if g_minimap.loadOtmm(bundledMinimapFile) then
        return true
    end

    g_logger.error('[Minimap] Bundled minimap is damaged or uses an unsupported format: ' .. bundledMinimapFile)
    return false
end

local function loadProfileMinimap()
    local profileMinimapFile = getProfileOtmmFile()
    if not profileMinimapFile then
        return true
    end

    if g_minimap.loadOtmm(profileMinimapFile) then
        g_logger.info('[Minimap] Loaded profile map: ' .. profileMinimapFile)
        return true
    end

    g_logger.error('[Minimap] Profile minimap is damaged or unsupported: ' .. profileMinimapFile)
    return false
end

local function ensureStaticMinimapFloor(floor)
    local widget = mapController and mapController.ui and mapController.ui.minimapBorder.minimap or nil
    if not widget or floor == nil then
        return false
    end

    local assetsDir = getMinimapAssetsDir()
    if staticMinimapAssetsDir ~= assetsDir then
        g_satelliteMap.clear()
        loadedStaticMinimapFloors = {}
        staticMinimapAssetsDir = assetsDir
    end

    if not loadedStaticMinimapFloors[floor] then
        local count = g_satelliteMap.loadFloors(assetsDir, floor, floor) or 0
        loadedStaticMinimapFloors[floor] = true
        g_logger.info(string.format('[Minimap] Full map floor %d: %d chunk files from %s', floor, count, assetsDir))
    end

    local available = g_satelliteMap.hasMinimapChunksForFloor(floor)
    widget:setUseStaticMinimap(available)
    return available
end

local function loadCurrentMinimap(showError)
    currentMinimapFile = getMinimapFile()
    if not g_resources.fileExists(currentMinimapFile) then
        return true
    end

    if g_minimap.loadOtmm(currentMinimapFile) then
        return true
    end

    g_minimap.clean()
    loadBundledMinimap()
    loadProfileMinimap()
    if showError then
        showMinimapError(tr('The minimap file for this server is damaged or uses an unsupported format:\n%s',
            currentMinimapFile))
    end
    return false
end

------------------------------------------------------------------------------
-- Full minimap from the server's own client files (Tibia 13+ asset format).
-- The map-*.dat index (copied by Nexus Studio) lists minimap/satellite/subarea
-- chunk files. Nexus Studio copies them on import; for servers imported
-- earlier this copies the missing chunks from the server's original client
-- folder into the profile's asset folder and reloads the minimap live.
------------------------------------------------------------------------------
local MAP_SOURCE_SETTING = 'nexusFullMapSource_'
local mapDownload = nil
local fullMapNotice = {}

local function mapChunkNames(assetsDir)
    local names, seen = {}, {}
    for _, file in ipairs(g_resources.listDirectoryFiles(assetsDir) or {}) do
        if file:lower():match('^map%-%x+%.dat$') then
            local data = g_resources.readFileContents(assetsDir .. '/' .. file) or ''
            for _, pattern in ipairs({'minimap%-%d+%-%d+%-%d+%-%d+%-%x+%.bmp%.lzma',
                'satellite%-%d+%-%d+%-%d+%-%d+%-%x+%.bmp%.lzma', 'subarea%-%d+%-%x+%.bmp%.lzma'}) do
                for name in data:gmatch(pattern) do
                    if not seen[name] then
                        seen[name] = true
                        names[#names + 1] = name
                    end
                end
            end
        end
    end
    return names
end

local function reloadFullMinimap()
    g_satelliteMap.clear()
    loadedStaticMinimapFloors = {}
    staticMinimapAssetsDir = nil
    local player = g_game.getLocalPlayer()
    local pos = player and player:getPosition()
    if pos then
        ensureStaticMinimapFloor(pos.z)
    end
end

local function finishMapDownload(copied, failed, missing, total)
    mapDownload = nil
    reloadFullMinimap()
    local player = g_game.getLocalPlayer()
    local pos = player and player:getPosition()
    local shown = pos and g_satelliteMap.hasMinimapChunksForFloor(pos.z)
    g_logger.info(string.format('[Minimap] Download result: copied=%d failed=%d missing=%d total=%d shown=%s',
        copied, failed, missing, total, tostring(shown)))
    if failed == 0 and copied > 0 and pos and pos.z <= 7 and not shown then
        showMinimapError(tr('The map files were copied (%d), but the client cannot read them. Send nexus_client.log to the developer.', copied))
        return
    end
    if failed > 0 then
        showMinimapError(tr('%d map files could not be copied into the client folder. Close programs that may lock it and try again.', failed))
    elseif missing == total then
        showMinimapError(tr('The found client has no map files of this server.'))
    elseif missing > 0 then
        displayInfoBox(tr('Full minimap'), tr('Copied %d of %d map files. %d are missing in the server\'s client, so parts of the map stay empty.', copied, total, missing))
    else
        displayInfoBox(tr('Full minimap'), tr('The full minimap of this server is ready.'))
    end
end

-- Copies run in a hidden PowerShell/robocopy process, so the game keeps its
-- frame rate; the client only polls for the result file.
local function psQuote(text)
    return "'" .. tostring(text):gsub("'", "''") .. "'"
end

local function psList(items)
    local quoted = {}
    for _, item in ipairs(items) do
        quoted[#quoted + 1] = psQuote(item)
    end
    return '@(' .. table.concat(quoted, ',') .. ')'
end

-- Where the server's original client was when Nexus Studio imported it.
local function importedSourceFolders()
    local folders = {}
    local manager = modules.client_profiles
    local profile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    local integrity = profile and profile.sourceIntegrity
    if type(integrity) ~= 'table' and profile and profile.id and tostring(profile.id):match('^[%w_.%-]+$') then
        local path = '/profiles/' .. profile.id .. '/profile.json'
        if g_resources.fileExists(path) then
            local ok, data = pcall(function() return json.decode(g_resources.readFileContents(path)) end)
            integrity = ok and type(data) == 'table' and data.sourceIntegrity or nil
        end
    end
    -- Every source Nexus Studio recorded: the client folder, or the local
    -- snapshot of a publisher archive (e.g. Vantoria's downloaded assets).
    local function add(value)
        if type(value) == 'string' and value ~= '' then folders[#folders + 1] = value end
    end
    if type(integrity) == 'table' then
        add(integrity.source)
        if type(integrity.snapshot) == 'table' then add(integrity.snapshot.source) end
    end
    return folders
end

-- Finds the server's own client by itself: first the folder Nexus Studio
-- imported from and the last folder that worked, then a background search of
-- the usual places (Desktop, Downloads, Documents, AppData, Program Files and
-- the drives) for a map file this server's client must have.
local function copyMapChunks(candidates, probe, names, targetDir)
    local resultName = '/nexus-map-copy-' .. getMinimapProfileKey() .. '.txt'
    local resultPath = g_resources.getWriteDir():gsub('[/\\]+$', '') .. resultName
    if g_resources.fileExists(resultName) then
        g_resources.deleteFile(resultName)
    end
    local script = table.concat({
        "$ErrorActionPreference='SilentlyContinue'",
        '$probe=' .. psQuote(probe),
        '$dst=' .. psQuote(targetDir:gsub('/', '\\')),
        '$out=' .. psQuote(resultPath:gsub('/', '\\')),
        '$dstFull=[IO.Path]::GetFullPath($dst).TrimEnd([char]92)',
        'trap { Set-Content -LiteralPath $out -Value @(\'98\', [string]$_) -Encoding utf8; exit }',
        'function Test-Src($d) { if (-not $d) { return $null }; foreach ($c in @($d, (Join-Path $d \'assets\'))) { if ((Test-Path -LiteralPath (Join-Path $c $probe)) -and ([IO.Path]::GetFullPath($c).TrimEnd([char]92) -ne $dstFull)) { return $c } }; return $null }',
        '$src=$null',
        'foreach ($c in ' .. psList(candidates) .. ') { $src = Test-Src $c; if ($src) { break } }',
        'if (-not $src) {',
        '  $roots=@()',
        "  foreach ($n in @('Desktop','Downloads','Documents','OneDrive')) { $roots += (Join-Path $env:USERPROFILE $n) }",
        '  $roots += @($env:LOCALAPPDATA, $env:APPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})',
        "  $roots += @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:' } | ForEach-Object { $_.Root })",
        '  foreach ($r in $roots) {',
        '    if (-not $r -or -not (Test-Path -LiteralPath $r)) { continue }',
        "    $hit = Get-ChildItem -LiteralPath $r -Filter $probe -File -Recurse -Depth 10 -Force | Where-Object { $_.DirectoryName -notmatch '\\\\Windows\\\\|\\$Recycle' -and ([IO.Path]::GetFullPath($_.DirectoryName).TrimEnd([char]92) -ne $dstFull) } | Select-Object -First 1",
        '    if ($hit) { $src = $hit.DirectoryName; break }',
        '  }',
        '}',
        "if (-not $src) { Set-Content -LiteralPath $out -Value '99' -Encoding utf8; exit }",
        'robocopy $src $dst minimap-*.bmp.lzma satellite-*.bmp.lzma subarea-*.bmp.lzma /XC /XN /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null',
        'Set-Content -LiteralPath $out -Value @([string]$LASTEXITCODE, $src) -Encoding utf8'
    }, '\r\n')
    -- No visible window: the script goes to a .ps1 file and Windows Script
    -- Host (which has no console) starts PowerShell with window style 0.
    local writeDir = g_resources.getWriteDir():gsub('[/\\]+$', '')
    local scriptName = '/nexus-map-copy.ps1'
    local launcherName = '/nexus-map-copy.vbs'
    local scriptPath = (writeDir .. scriptName):gsub('/', '\\')
    local launcherPath = (writeDir .. launcherName):gsub('/', '\\')
    local command = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' .. scriptPath .. '""'
    local written = g_resources.writeFileContents(scriptName, '\239\187\191' .. script)
        and g_resources.writeFileContents(launcherName, 'CreateObject("WScript.Shell").Run "' .. command .. '", 0, False\r\n')
    local ok, started = false, false
    if written then
        ok, started = pcall(g_platform.spawnProcess, 'wscript', {'//B', '//Nologo', launcherPath})
    end
    if not ok or not started then
        mapDownload = nil
        showMinimapError(tr('Windows did not start the copy (PowerShell is not available).'))
        return
    end
    if modules.game_textmessage then
        modules.game_textmessage.displayStatusMessage(tr('Looking for this server\'s client and copying the full minimap in the background...'))
    end
    local started_at = g_clock.millis()
    local notifiedSlow = false
    local function poll()
        if not mapDownload then
            return
        end
        if not g_resources.fileExists(resultName) then
            if not notifiedSlow and g_clock.millis() - started_at > 60000 and modules.game_textmessage then
                notifiedSlow = true
                modules.game_textmessage.displayStatusMessage(tr('Still searching this computer for the server\'s client...'))
            end
            if g_clock.millis() - started_at > 600000 then
                mapDownload = nil
                showMinimapError(tr('Finding and copying the full minimap takes too long. Try again.'))
                return
            end
            mapDownload = scheduleEvent(poll, 500)
            return
        end
        local text = (g_resources.readFileContents(resultName) or ''):gsub('^\239\187\191', '')
        g_resources.deleteFile(resultName)
        local code = tonumber(text:match('%d+')) or 16
        g_logger.info('[Minimap] Copy script result: ' .. text:gsub('[\r\n]+', ' | '))
        if code == 98 then
            mapDownload = nil
            showMinimapError(tr('Copying the full minimap failed: %s', (text:match('[\r\n]+(.+)') or ''):gsub('[\r\n]+', ' ')))
            return
        end
        if code == 99 then
            mapDownload = nil
            showMinimapError(tr('The client of this server was not found on this computer. Download the server\'s own client, start it once, and click Download full minimap again.'))
            return
        end
        local found = text:match('[\r\n]+([^\r\n]+)')
        if found and code < 8 then
            g_settings.set(MAP_SOURCE_SETTING .. getMinimapProfileKey(), found)
        end
        local copied, missing = 0, 0
        for _, name in ipairs(names) do
            if g_platform.fileExists(targetDir .. '/' .. name) then
                copied = copied + 1
            else
                missing = missing + 1
            end
        end
        -- robocopy: 0-7 success, 8 and above means some files failed.
        finishMapDownload(copied, code >= 8 and missing or 0, code >= 8 and 0 or missing, #names)
    end
    mapDownload = scheduleEvent(poll, 500)
end

function downloadFullMinimap()
    if mapDownload then
        return
    end
    local assetsDir = getMinimapAssetsDir()
    local names = mapChunkNames(assetsDir)
    if #names == 0 then
        showMinimapError(tr('This server\'s client files contain no full map. The minimap is filled while you explore.'))
        return
    end
    local probe
    for _, name in ipairs(names) do
        if not g_resources.fileExists(assetsDir .. '/' .. name) then
            probe = name
            break
        end
    end
    if not probe then
        reloadFullMinimap()
        displayInfoBox(tr('Full minimap'), tr('The full minimap of this server is already installed.'))
        return
    end
    local realDir = g_resources.getRealDir(assetsDir)
    if not realDir or realDir == '' then
        showMinimapError(tr('The asset folder of this server could not be found.'))
        return
    end
    local targetDir = (realDir:gsub('[/\\]+$', '')) .. assetsDir
    local candidates = importedSourceFolders()
    local saved = g_settings.getString(MAP_SOURCE_SETTING .. getMinimapProfileKey(), '')
    if saved ~= '' then
        candidates[#candidates + 1] = saved
    end
    mapDownload = true
    copyMapChunks(candidates, probe, names, targetDir)
end

function importMinimap()
    displayTextInputBox(tr('Import Minimap'), tr('Full path to an .otmm file:'), function(sourcePath)
        sourcePath = sourcePath:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^"(.*)"$', '%1')
        if sourcePath == '' or not sourcePath:lower():match('%.otmm$') then
            showMinimapError(tr('Select a valid .otmm file.'))
            return
        end
        if not g_platform.fileExists(sourcePath) then
            showMinimapError(tr('The selected minimap file does not exist:\n%s', sourcePath))
            return
        end

        currentMinimapFile = getMinimapFile()
        local temporaryFile = '/minimaps/__import_validation.otmm'
        local temporaryRealPath = g_resources.getWriteDir() .. '/minimaps/__import_validation.otmm'
        if not g_platform.copyFile(sourcePath, temporaryRealPath) then
            showMinimapError(tr('The selected minimap could not be copied.'))
            return
        end

        if g_resources.fileExists(currentMinimapFile) then
            g_minimap.saveOtmm(currentMinimapFile)
        end
        g_minimap.clean()

        if not g_minimap.loadOtmm(temporaryFile) then
            g_resources.deleteFile(temporaryFile)
            g_minimap.clean()
            loadCurrentMinimap(false)
            showMinimapError(tr('The selected minimap is damaged or uses an unsupported format.'))
            return
        end

        g_minimap.saveOtmm(currentMinimapFile)
        g_resources.deleteFile(temporaryFile)
        mapController.ui.minimapBorder.minimap:load(getMinimapSettingsKey())
        resetMap()
        displayInfoBox(tr('Minimap'), tr('The minimap was imported for this server and client version.'))
    end)
end

local function refreshVirtualFloors()
    mapController.ui.layersPanel.layersMark:setMarginTop(((virtualFloor + 1) * 4) - 3)
    mapController.ui.layersPanel.automapLayers:setImageClip((virtualFloor * 14) .. ' 0 14 67')
end

------------------------------------------------------------------------------
-- Map click walking like the official client. The client's own walk only
-- trusts tiles it has seen, so far clicks stopped after a few steps with
-- "There is no way". Here the whole route is planned over the known map
-- (unseen tiles allowed), then walked in short visible segments; each segment
-- is re-planned with what has become visible, until the destination.
------------------------------------------------------------------------------
local longWalk = nil
local DIRS = {[0] = {0, -1}, {1, 0}, {0, 1}, {-1, 0}, {1, -1}, {1, 1}, {-1, 1}, {-1, -1}}

function isLongWalking()
    return longWalk ~= nil
end

function stopLongWalk()
    if longWalk and longWalk.event then
        removeEvent(longWalk.event)
    end
    longWalk = nil
end

local function samePos(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function posKey(p)
    return p.x .. ',' .. p.y .. ',' .. p.z
end

local function failLongWalk()
    stopLongWalk()
    modules.game_textmessage.displayFailureMessage(tr('There is no way.'))
end

-- Sends the next part of the route (up to 127 steps, the protocol limit) in
-- one go, like a right click: the server walks it without pauses.
local function sendRoute(walk, player)
    local start = player:getPosition()
    local path = g_map.findPath(start, walk.dest, 60000, PathFindFlags.AllowNullTiles + PathFindFlags.AllowCreatures)
    if type(path) ~= 'table' or #path == 0 then
        return false
    end
    local dirs, route = {}, {[posKey(start)] = true}
    local p = {x = start.x, y = start.y, z = start.z}
    for i = 1, math.min(#path, 127) do
        local d = DIRS[path[i]]
        if not d then break end
        p = {x = p.x + d[1], y = p.y + d[2], z = p.z}
        dirs[#dirs + 1] = path[i]
        route[posKey(p)] = true
    end
    if #dirs == 0 then return false end
    walk.route, walk.endpoint = route, p
    walk.lastPos, walk.lastMove = start, g_clock.millis()
    g_game.autoWalk(dirs, start)
    return true
end

local function longWalkTick()
    local walk = longWalk
    if not walk then return end
    walk.event = scheduleEvent(longWalkTick, 100)
    local player = g_game.getLocalPlayer()
    if not g_game.isOnline() or not player then stopLongWalk() return end
    local pos = player:getPosition()
    if not pos or samePos(pos, walk.dest) or pos.z ~= walk.dest.z then stopLongWalk() return end
    local now = g_clock.millis()
    if not walk.route[posKey(pos)] then
        stopLongWalk() -- off the route: the player took over (keyboard, other click)
        return
    end
    if not samePos(pos, walk.lastPos) then
        walk.lastPos, walk.lastMove, walk.failures = pos, now, 0
    end
    if samePos(pos, walk.endpoint) then
        if not sendRoute(walk, player) then failLongWalk() end
        return
    end
    -- Standing still on the route: the server stopped at an unknown obstacle.
    -- Plan again with what is visible now.
    if not player:isWalking() and now - walk.lastMove > 700 then
        walk.failures = walk.failures + 1
        if walk.failures > 3 or not sendRoute(walk, player) then failLongWalk() end
    end
end

function walkTo(dest)
    stopLongWalk()
    local player = g_game.getLocalPlayer()
    if not player or not dest then return false end
    local pos = player:getPosition()
    if not pos or pos.z ~= dest.z or Position.distance(pos, dest) <= 7 then
        return player:autoWalk(dest)
    end
    local walk = {dest = {x = dest.x, y = dest.y, z = dest.z}, failures = 0}
    if not sendRoute(walk, player) then
        -- Nothing known about the way: let the client try its own walk.
        return player:autoWalk(dest)
    end
    longWalk = walk
    walk.event = scheduleEvent(longWalkTick, 100)
    return true
end

local function onPositionChange()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local pos = player:getPosition()
    if not pos then
        return
    end

    ensureStaticMinimapFloor(pos.z)

    local minimapWidget = mapController.ui.minimapBorder.minimap
    if not (minimapWidget) or minimapWidget:isDragging() then
        return
    end

    if not minimapWidget.fullMapView then
        minimapWidget:setCameraPosition(pos)
    end

    minimapWidget:setCrossPosition(pos)
    virtualFloor = pos.z
    refreshVirtualFloors()
end

mapController = Controller:new()
mapController:setUI('minimap', modules.game_interface.getMainRightPanel())

function onChangeWorldTime(hour, minute)
--[[ 

check 
tfs c++ (old) : void ProtocolGame::sendWorldTime()
tfs lua (new) : function Player.sendWorldTime(self, time)
Canary: void ProtocolGame::sendTibiaTime(int32_t time)
 ]]

    currentDayTime = {
        h = hour % 24,
        m = minute
    }

    mapController:scheduleEvent(function()
        local nextH = currentDayTime.h
        local nextM = currentDayTime.m + 12
        if nextM >= 60 then
            nextH = nextH + 1
            nextM = nextM - 60
        end

        onChangeWorldTime(nextH, nextM)
    end, 30000, 'dayTime')

    local position = math.floor((124 / (24 * 60)) * ((hour * 60) + minute))
    local mainWidth = 31
    local secondaryWidth = 0

    if (position + 31) >= 124 then
        secondaryWidth = ((position + 31) - 124) + 1
        mainWidth = 31 - secondaryWidth
    end

    mapController.ui.rosePanel.ambients.main:setWidth(mainWidth)
    mapController.ui.rosePanel.ambients.secondary:setWidth(secondaryWidth)

    if secondaryWidth == 0 then
        mapController.ui.rosePanel.ambients.secondary:hide()
    else
        mapController.ui.rosePanel.ambients.secondary:setImageClip('0 0 ' .. secondaryWidth .. ' 31')
        mapController.ui.rosePanel.ambients.secondary:show()
    end

    if mainWidth == 0 then
        mapController.ui.rosePanel.ambients.main:hide()
    else
        mapController.ui.rosePanel.ambients.main:setImageClip(position .. ' 0 ' .. mainWidth .. ' 31')
        mapController.ui.rosePanel.ambients.main:show()
    end
end

function mapController:onInit()
    self.ui:setDraggable(false)
    local savedHeight=math.max(134,math.min(500,tonumber(g_settings.get('nexusMinimapHeight')) or 134))
    self.ui.panelHeight=savedHeight
    self.ui:setHeight(savedHeight)
    self.ui.minimapBorder:setHeight(savedHeight-23)
    local resizing=false
    self.ui.onGeometryChange=function(widget)
        if resizing then return end
        resizing=true
        local height=widget:getHeight()
        -- Parent layout temporarily collapses hidden panels during login/logout.
        if height < 134 then resizing=false return end
        widget.panelHeight=height
        widget.minimapBorder:setHeight(math.max(111,height-23))
        if mainMapSpace then mainMapSpace.panelHeight=height mainMapSpace:setHeight(height) end
        if extraMapSpace then extraMapSpace.panelHeight=height extraMapSpace:setHeight(height) end
        arrangeWideMap()
        if modules.game_mainpanel then modules.game_mainpanel.reloadMainPanelSizes() end
        resizing=false
    end
    local border=g_ui.createWidget('ResizeBorder',self.ui)
    border:setId('mapResizeBorder')
    border:addAnchor(AnchorLeft,'parent',AnchorLeft)
    border:addAnchor(AnchorRight,'parent',AnchorRight)
    border:addAnchor(AnchorBottom,'parent',AnchorBottom)
    border:setHeight(5) border:setMinimum(134) border:setMaximum(500) border.vertical=true
    local release=border.onMouseRelease
    border.onMouseRelease=function(widget,...)
        if release then release(widget,...) end
        g_settings.set('nexusMinimapHeight',self.ui:getHeight()) g_settings.save()
    end
    self.ui.onDragEnter=function() return false end
    local function protectDrops(widget)
        widget.onDrop=dropBelowMap
        for _,child in ipairs(widget:getChildren()) do protectDrops(child) end
    end
    protectDrops(self.ui)
    self.ui.widenMap:raise()
    self.ui.minimapBorder.minimap:getChildById('floorUpButton'):hide()
    self.ui.minimapBorder.minimap:getChildById('floorDownButton'):hide()
    self.ui.minimapBorder.minimap:getChildById('zoomInButton'):hide()
    self.ui.minimapBorder.minimap:getChildById('zoomOutButton'):hide()
    self.ui.minimapBorder.minimap:getChildById('resetButton'):hide()
end

function mapController:onGameStart()
    self.ui.panelHeight=math.max(134,tonumber(self.ui.panelHeight) or 134)
    self.ui:setHeight(self.ui.panelHeight)
    self.ui:show()
    modules.game_mainpanel.reloadMainPanelSizes()
    g_satelliteMap.clear()
    staticMinimapAssetsDir = nil
    loadedStaticMinimapFloors = {}

    mapController:registerEvents(g_game, {
        onChangeWorldTime = onChangeWorldTime
    })

    mapController:registerEvents(LocalPlayer, {
        onPositionChange = onPositionChange
    }):execute()

    if mapAutosave then removeEvent(mapAutosave) end
    mapAutosave = cycleEvent(function() if g_game.isOnline() then saveExploredMap() end end, 600000)
    -- Load Map
    migrateMinimapFile(otmm and '.otmm' or '.otcm')
    g_minimap.clean()

    if otmm then
        loadBundledMinimap()
        loadProfileMinimap()
        loadCurrentMinimap(true)
    else
        currentMinimapFile = '/minimaps/' .. getMinimapProfileKey() .. '.otcm'
        if g_resources.fileExists(currentMinimapFile) then
            g_map.loadOtcm(currentMinimapFile)
        end
    end

    self.ui.minimapBorder.minimap:load(getMinimapSettingsKey())

    local player = g_game.getLocalPlayer()
    local position = player and player:getPosition() or nil
    if position then
        ensureStaticMinimapFloor(position.z)
    else
        self.ui.minimapBorder.minimap:setUseStaticMinimap(false)
    end
    -- Tell once per server and session whether its full map is installed.
    local serverKey = getMinimapProfileKey()
    scheduleEvent(function()
        if not g_game.isOnline() or fullMapNotice[serverKey] then return end
        local assetsDir = getMinimapAssetsDir()
        local names = mapChunkNames(assetsDir)
        if #names == 0 then return end
        local installed = 0
        for _, name in ipairs(names) do
            if g_resources.fileExists(assetsDir .. '/' .. name) then installed = installed + 1 end
        end
        fullMapNotice[serverKey] = true
        g_logger.info(string.format('[Minimap] Full map of %s: %d of %d files installed', serverKey, installed, #names))
        if installed == 0 and modules.game_textmessage then
            modules.game_textmessage.displayStatusMessage(tr('The full minimap of this server is not downloaded yet: right-click the minimap and choose Download full minimap.'))
        end
    end, 3000)
end

-- The explored map is also saved every 10 minutes and when the client
-- closes, so a crash or a closed window never loses the exploring.
mapAutosave = nil
function saveExploredMap()
    if otmm then
        g_minimap.saveOtmm(currentMinimapFile or getMinimapFile())
    else
        currentMinimapFile = currentMinimapFile or ('/minimaps/' .. getMinimapProfileKey() .. '.otcm')
        g_map.saveOtcm(currentMinimapFile)
    end
end

function mapController:onGameEnd()
    stopLongWalk()
    if mapDownload then
        if type(mapDownload) ~= 'boolean' then
            removeEvent(mapDownload)
        end
        mapDownload = nil
    end
    -- Save Map
    saveExploredMap()
    if mapAutosave then removeEvent(mapAutosave) mapAutosave = nil end

    self.ui.minimapBorder.minimap:save(getMinimapSettingsKey())
    self.ui.minimapBorder.minimap:setUseStaticMinimap(false)
    g_satelliteMap.clear()
    staticMinimapAssetsDir = nil
    loadedStaticMinimapFloors = {}
    g_settings.save()
end

function mapController:onTerminate()
    if mapAutosave then removeEvent(mapAutosave) mapAutosave = nil end
    if g_game.isOnline() then pcall(saveExploredMap) end
    releaseWideMap()
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
end

function zoomIn()
    mapController.ui.minimapBorder.minimap:zoomIn()
end

function zoomOut()
    mapController.ui.minimapBorder.minimap:zoomOut()
end

function openCyclopediaMap()
    if g_game.getClientVersion() >= 1310 then
        modules.game_cyclopedia.toggle('map')
    else
        return fullscreen()
    end
end

function fullscreen()
    local minimapWidget = mapController.ui.minimapBorder.minimap
    if not minimapWidget then
        minimapWidget = fullscreenWidget
    end
    local zoom;

    if not minimapWidget then
        return
    end

    if minimapWidget.fullMapView then
        fullscreenWidget = nil
        minimapWidget:setParent(mapController.ui.minimapBorder)
        minimapWidget:fill('parent')
        mapController.ui:show()
        zoom = minimapWidget.zoomMinimap
        g_keyboard.unbindKeyDown('Escape')
        minimapWidget.fullMapView = false
    else
        fullscreenWidget = minimapWidget
        mapController.ui:hide(true)
        minimapWidget:setParent(modules.game_interface.getRootPanel())
        minimapWidget:fill('parent')
        zoom = minimapWidget.zoomFullmap
        g_keyboard.bindKeyDown('Escape', fullscreen)
        minimapWidget.fullMapView = true
    end

    local pos = oldPos or minimapWidget:getCameraPosition()
    oldPos = minimapWidget:getCameraPosition()
    minimapWidget:setZoom(zoom)
    minimapWidget:setCameraPosition(pos)
end

function upLayer()
    if virtualFloor == 0 then
        return
    end

    mapController.ui.minimapBorder.minimap:floorUp(1)
    local camera = mapController.ui.minimapBorder.minimap:getCameraPosition()
    if camera then ensureStaticMinimapFloor(camera.z) end
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end

function downLayer()
    if virtualFloor == 15 then
        return
    end

    mapController.ui.minimapBorder.minimap:floorDown(1)
    local camera = mapController.ui.minimapBorder.minimap:getCameraPosition()
    if camera then ensureStaticMinimapFloor(camera.z) end
    virtualFloor = virtualFloor + 1
    refreshVirtualFloors()
end

function onClickRoseButton(dir)
    if dir == 'north' then
        mapController.ui.minimapBorder.minimap:move(0, 1)
    elseif dir == 'north-east' then
        mapController.ui.minimapBorder.minimap:move(-1, 1)
    elseif dir == 'east' then
        mapController.ui.minimapBorder.minimap:move(-1, 0)
    elseif dir == 'south-east' then
        mapController.ui.minimapBorder.minimap:move(-1, -1)
    elseif dir == 'south' then
        mapController.ui.minimapBorder.minimap:move(0, -1)
    elseif dir == 'south-west' then
        mapController.ui.minimapBorder.minimap:move(1, -1)
    elseif dir == 'west' then
        mapController.ui.minimapBorder.minimap:move(1, 0)
    elseif dir == 'north-west' then
        mapController.ui.minimapBorder.minimap:move(1, 1)
    end
end

function resetMap()
    mapController.ui.minimapBorder.minimap:reset()
    local player = g_game.getLocalPlayer()
    if player then
        virtualFloor = player:getPosition().z
        refreshVirtualFloors()
    end
end

function getMiniMapUi()
    return mapController.ui.minimapBorder.minimap
end

function extendedView(extendedView)
    if wideMap then releaseWideMap() end
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('miniMap', tr('Show miniMap'),
                '/images/topbuttons/minimap', toggle)
            iconTopMenu:setOn(mapController.ui:isVisible())
            mapController.ui:setBorderColor('black')
            mapController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        mapController.ui:setBorderColor('alpha')
        mapController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if not mainRightPanel:hasChild(mapController.ui) then
            mainRightPanel:insertChild(1, mapController.ui)
        end
        mapController.ui:show()

    end
    mapController.ui.moveOnlyToMain = not extendedView
end

function toggle()
    if iconTopMenu:isOn() then
        mapController.ui:hide()
        iconTopMenu:setOn(false)
    else
        mapController.ui:show()
        iconTopMenu:setOn(true)
    end
end
