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
    mapController.ui.minimapBorder:setWidth(math.max(115,width-58))
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
        mapController.ui.minimapBorder:setWidth(115)
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

function getMinimapProfileKey()
    local host = (G and G.host) or g_settings.getString('host') or 'unknown'
    local port = (G and G.port) or g_settings.get('port') or 0
    local version = g_game.getClientVersion()
    if not version or version == 0 then
        version = g_settings.getInteger('client-version') or 0
    end
    return string.format('%s_%s_%s', sanitizeProfilePart(host), sanitizeProfilePart(port),
        sanitizeProfilePart(version))
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
        g_satelliteMap.loadFloors(assetsDir, floor, floor)
        loadedStaticMinimapFloors[floor] = true
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

    -- Load Map
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
end

function mapController:onGameEnd()
    -- Save Map
    if otmm then
        g_minimap.saveOtmm(currentMinimapFile or getMinimapFile())
    else
        currentMinimapFile = currentMinimapFile or ('/minimaps/' .. getMinimapProfileKey() .. '.otcm')
        g_map.saveOtcm(currentMinimapFile)
    end

    self.ui.minimapBorder.minimap:save(getMinimapSettingsKey())
    self.ui.minimapBorder.minimap:setUseStaticMinimap(false)
    g_satelliteMap.clear()
    staticMinimapAssetsDir = nil
    loadedStaticMinimapFloors = {}
    g_settings.save()
end

function mapController:onTerminate()
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
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end

function downLayer()
    if virtualFloor == 15 then
        return
    end

    mapController.ui.minimapBorder.minimap:floorDown(1)
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
