-- private variables
local topMenu
local rightButtonsPanel
local leftButtonsPanel
local rightGameButtonsPanel
local topLeftTogglesPanel
local topLeftButtonsPanel
local fpsLabel
local pingLabel
local lastSyncValue = -1
local fpsEvent = nil
local fpsMin = -1;
local fpsMax = -1;
local pingPanel
local MainPingPanel
local mainFpsPanel
local fpsPanel2
local PingWidget
local pingImg
local serverLabel
local onlineEvent
local originalSetTitle
local nexusSetTitle
local statusGeometrySources = {}

function positionStatusOverlay()
    if not PingWidget or PingWidget:isDestroyed() then return end
    local root = modules.game_interface.getRootPanel()
    local map = modules.game_interface.getMapPanel()
    if not root or not map or map:isDestroyed() then return end
    local r = map:getRect()
    local left, right = r.x, r.x+r.width
    -- In extended view sidebars overlay the map rather than shrinking it.
    for _,id in ipairs({'gameLeftPanel','gameLeftExtraPanel','gameLeftActionPanel','leftIncreaseSidePanels','leftDecreaseSidePanels'}) do
        local panel=root:getChildById(id)
        if panel and panel:isVisible() and panel:getWidth()>0 then
            left=math.max(left,panel:getX()+panel:getWidth())
        end
    end
    for _,id in ipairs({'gameMainRightPanel','gameRightPanel','gameRightExtraPanel','gameRightActionPanel','rightIncreaseSidePanels','rightDecreaseSidePanels'}) do
        local panel=root:getChildById(id)
        if panel and panel:isVisible() and panel:getWidth()>0 then right=math.min(right,panel:getX()) end
    end
    local width=math.max(1,math.min(180,right-left-10))
    PingWidget:setWidth(width)
    local textWidth=math.max(1,width-21)
    for _,label in ipairs({pingPanel,serverLabel,fpsPanel2}) do
        if label and not label:isDestroyed() then label:setWidth(textWidth) end
    end
    -- getRect()/getX() use screen coordinates; setPosition() is relative to root.
    PingWidget:setPosition({x=left+5-root:getX(),y=r.y+5-root:getY()})
    PingWidget:raise()
end

local function watchStatusGeometry()
    if #statusGeometrySources>0 then return end
    local root=modules.game_interface.getRootPanel()
    local sources={root,modules.game_interface.getMapPanel()}
    for _,id in ipairs({'gameLeftPanel','gameLeftExtraPanel','gameLeftActionPanel','gameMainRightPanel','gameRightPanel','gameRightExtraPanel','gameRightActionPanel','leftIncreaseSidePanels','leftDecreaseSidePanels','rightIncreaseSidePanels','rightDecreaseSidePanels'}) do
        local panel=root:getChildById(id)
        if panel then sources[#sources+1]=panel end
    end
    for _,source in ipairs(sources) do
        connect(source,{onGeometryChange=positionStatusOverlay,onVisibilityChange=positionStatusOverlay})
        statusGeometrySources[#statusGeometrySources+1]=source
    end
end

local zoomInButton = nil
local zoomOutButton = nil
local zoomLevel = 2

local managerAccountsButton = nil
-- private functions
local function addButton(id, description, icon, callback, panel, toggle, front)
    local class
    if toggle then
        class = 'MainToggleButton'
    else
        class = 'Button'
    end

    local button = panel:getChildById(id)
    if not button then
        button = g_ui.createWidget(class)
        if front then
            panel:insertChild(1, button)
        else
            panel:addChild(button)
        end
    end
    button:setId(id)
    button:setTooltip(description)
    if toggle then
        button:setIcon(resolvepath(icon, 3))
    else
        button:setText(description)
    end
    button.onMouseRelease = function(widget, mousePos, mouseButton)
        if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
            callback()
            return true
        end
    end
    return button
end

local function updateZoomButtons()
    if zoomInButton then
        zoomInButton:setEnabled(zoomLevel < 6)
    end
    if zoomOutButton then
        zoomOutButton:setEnabled(zoomLevel > 1.5)
    end
end

local function setZoom(value)
    local oldValue = zoomLevel
    zoomLevel = math.max(1.5, math.min(6, value))
    modules.client_options.setOption('hudScale', zoomLevel)
    updateZoomButtons()
    return oldValue ~= zoomLevel
end

-- public functions
function init()
    originalSetTitle = g_window.setTitle
    nexusSetTitle = function()
        local player = g_game.isOnline() and g_game.getLocalPlayer()
        originalSetTitle(player and ('Nexus - ' .. player:getName()) or 'Nexus Client')
    end
    -- Existing user copies of vBot also write titles. Keep branding consistent
    -- without editing their saved scripts, settings or gameplay behavior.
    g_window.setTitle = nexusSetTitle
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onPingBack = updatePing
    })
    connect(g_app, {
        onFps = updateFps
    })

    topMenu = g_ui.displayUI('topmenu')

    topLeftButtonsPanel = topMenu:getChildById('topLeftButtonsPanel')
    topLeftTogglesPanel = topMenu:getChildById('topLeftTogglesPanel')
    rightButtonsPanel = topMenu:getChildById('rightButtonsPanel')
    leftButtonsPanel = topMenu:getChildById('leftButtonsPanel')
    rightGameButtonsPanel = topMenu:getChildById('rightGameButtonsPanel')
    pingLabel = topMenu:getChildById('pingLabel')
    fpsLabel = topMenu:getChildById('fpsLabel')

    Keybind.new("UI", "Toggle Top Menu", "Ctrl+Shift+T", "")
    Keybind.bind("UI", "Toggle Top Menu", {
      {
        type = KEY_DOWN,
        callback = toggle,
      }
    })
    if Services.websites and not managerAccountsButton then
        managerAccountsButton = modules.client_topmenu.addTopRightRegularButton('hotkeysButton', tr('Manage Account'),
            nil, openManagerAccounts)
    end
    if g_platform.isMobile() then
        zoomInButton = modules.client_topmenu.addLeftToggleButton('zoomInButton', 'Zoom In',
            '/images/topbuttons/zoomin', function()
                setZoom(zoomLevel + 0.5)
            end)

        zoomOutButton = modules.client_topmenu.addLeftToggleButton('zoomOutButton', 'Zoom Out',
            '/images/topbuttons/zoomout', function()
                setZoom(zoomLevel - 0.5)
            end)
        updateZoomButtons()
    end
    if g_game.isOnline() then
        online()
    else
        topMenu:hide()
    end
end

function terminate()
    if g_window.setTitle == nexusSetTitle then g_window.setTitle = originalSetTitle end
    if onlineEvent then removeEvent(onlineEvent) onlineEvent = nil end
    if fpsEvent then removeEvent(fpsEvent) fpsEvent = nil end
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onPingBack = updatePing
    })
    disconnect(g_app, {
        onFps = updateFps
    })

    topMenu:destroy()
    topMenu = nil
    pingLabel = nil
    fpsLabel = nil
    for _,source in ipairs(statusGeometrySources) do
        disconnect(source,{onGeometryChange=positionStatusOverlay,onVisibilityChange=positionStatusOverlay})
    end
    statusGeometrySources={}
    if PingWidget and not PingWidget:isDestroyed() then
        PingWidget:destroy()
        PingWidget = nil
    end
    pingPanel, pingImg, fpsPanel2, serverLabel = nil, nil, nil, nil
    if managerAccountsButton and not managerAccountsButton:isDestroyed() then
        managerAccountsButton:destroy()
        managerAccountsButton = nil
    end
    if g_platform.isMobile() then
        if zoomInButton and not zoomOutButton:isDestroyed() then
            zoomInButton:destroy()
            zoomInButton= nil
        end
        if zoomOutButton and not zoomOutButton:isDestroyed() then
            zoomOutButton:destroy()
            zoomOutButton= nil
        end
    end

    Keybind.delete("UI", "Toggle Top Menu")
end

function hide()
    topMenu:hide()
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'parent', AnchorTop)
end

function show()
    topMenu:show()
    topMenu:raise()
    topMenu:focus()
    if modules.game_interface.currentViewMode == 2 then
        modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
    end
end

function online()
    showGameButtons()
    local player = g_game.getLocalPlayer()
    if player then g_window.setTitle('Nexus - ' .. player:getName()) end
    if onlineEvent then removeEvent(onlineEvent) end
    onlineEvent = addEvent(function()
        onlineEvent = nil
        if not topMenu or topMenu:isDestroyed() or not g_game.isOnline() then return end
        if modules.game_interface.currentViewMode ~= 2 and g_game.isOnline() then
            hide()
        end
        if not PingWidget then
            PingWidget = g_ui.loadUI("pingFps", modules.game_interface.getRootPanel())
            PingWidget:breakAnchors()
            PingWidget:setMarginTop(0)
            PingWidget:setMarginLeft(0)
            pingImg = PingWidget:getChildById('pingImg')
            pingPanel = PingWidget:getChildById('ping')
            serverLabel = PingWidget:getChildById('server')
            fpsPanel2 = PingWidget:getChildById('fps')
        end
        PingWidget:show()
        watchStatusGeometry()
        positionStatusOverlay()
        serverLabel:setText(g_game.getWorldName() or '')
        pingPanel:setText('Connecting...')
        setPingVisible(modules.client_options.getOption('showPing'))
        setFpsVisible(modules.client_options.getOption('showFps'))
        setServerNameVisible(modules.client_options.getOption('showServerName'))
    end)
end

function offline()
    if onlineEvent then removeEvent(onlineEvent) onlineEvent = nil end
    if fpsEvent then removeEvent(fpsEvent) fpsEvent = nil end
    g_window.setTitle('Nexus Client')
    if PingWidget then PingWidget:hide() end
    hideGameButtons()
    pingLabel:hide()
    if pingPanel then
        pingPanel:hide()
        pingImg:hide()
    end
    fpsMin = -1
end

function updateFps(fps)
    if not fpsLabel or fpsLabel:isDestroyed() then return end
    if fpsLabel:isVisible() then -- for the time being retained for the extended view
        local text = 'FPS ' .. fps
        if g_game.isOnline() then
            local vsync = modules.client_options.getOption('vsync')
            if fpsEvent == nil and lastSyncValue ~= vsync then
                fpsEvent = scheduleEvent(function()
                    fpsMin = -1
                    lastSyncValue = vsync
                    fpsEvent = nil
                end, 2000)
            end

            if fpsMin == -1 then
                fpsMin = fps
                fpsMax = fps
            end

            if fps > fpsMax then
                fpsMax = fps
            end

            if fps < fpsMin then
                fpsMin = fps
            end

            local midFps = math.floor((fpsMin + fpsMax) / 2)
            fpsLabel:setTooltip('Min: ' .. fpsMin .. '\nMid: ' .. midFps .. '\nMax: ' .. fpsMax)
        else
            fpsLabel:removeTooltip()
        end
        fpsLabel:setText(text)
    end

    local text = fps .. ' fps'
    if fpsPanel2 and fpsPanel2:isVisible() then
        if g_game.isOnline() then
            fpsPanel2:setText(text)
        end
    end

end

function updatePing(ping)
    if not pingLabel or pingLabel:isDestroyed() then return end
    if pingLabel:isVisible() then -- for the time being retained for the extended view

        local text = 'Ping: '
        local color
        if ping < 0 then
            text = text .. '??'
            color = 'yellow'
        else
            text = text .. ping .. ' ms'
            if ping >= 500 then
                color = 'red'
            elseif ping >= 250 then
                color = 'yellow'
            else
                color = 'green'
            end
        end
        pingLabel:setColor(color)
        pingLabel:setText(text)
    end
    if pingPanel and pingPanel:isVisible() then

        local text
        local imagen
        if ping < 0 then
            text = 'High lag (??)'
            imagen = nil
        elseif ping >= 500 then
            text = 'High lag (' .. ping .. ' ms)'
            imagen = '/images/ui/high_ping'
        elseif ping >= 250 then
            text = 'Medium lag (' .. ping .. ' ms)'
            imagen = '/images/ui/medium_ping'
        else
            text = 'Low lag (' .. ping .. ' ms)'
            imagen = '/images/ui/low_ping'
        end

        pingImg:setImageSource(imagen)
        pingPanel:setText(text)
    end
end

function setPingVisible(enable)
    if pingLabel then pingLabel:setVisible(enable) end
    if pingPanel then
        pingPanel:setVisible(enable)
        pingImg:setVisible(enable)
    end
    layoutStatus()
end

function setFpsVisible(enable)
    if fpsLabel then fpsLabel:setVisible(enable) end
    if fpsPanel2 then
        fpsPanel2:setVisible(enable)
    end
    layoutStatus()
end

function setServerNameVisible(enable)
    if serverLabel then serverLabel:setVisible(enable) end
    layoutStatus()
end

function layoutStatus()
    if not PingWidget then return end
    local y = 0
    for _,widget in ipairs({pingPanel, serverLabel, fpsPanel2}) do
        if widget:isExplicitlyVisible() then
            widget:setMarginTop(y)
            y = y + 14
        end
    end
    PingWidget:setHeight(math.max(17, y))
end

function addLeftButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, leftButtonsPanel, false, front)
end

function addLeftToggleButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, leftButtonsPanel, true, front)
end

function addRightButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, topLeftTogglesPanel, false, front)
end

function addRightToggleButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, rightButtonsPanel, true, front)
end

function addLeftGameButton(id, description, icon, callback, front, index)
    if not g_modules.getModule("game_mainpanel"):isLoaded() then
        -- Temp fix. game_mainpanel is not loaded if called from a client_XXX.
        scheduleEvent(function()
            return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
        end, 100)
    else
        return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)

    end
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
    if not g_modules.getModule("game_mainpanel"):isLoaded() then
        -- Temp fix. game_mainpanel is not loaded if called from a client_XXX.
        scheduleEvent(function()
            return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
        end, 100)
    else
        return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)

    end
end

function addRightGameButton(id, description, icon, callback, front, index)
    if not g_modules.getModule("game_mainpanel"):isLoaded() then
        -- Temp fix. game_mainpanel is not loaded if called from a client_XXX.
        scheduleEvent(function()
            return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
        end, 100)
    else
        return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)

    end
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
    if not g_modules.getModule("game_mainpanel"):isLoaded() then
        -- Temp fix. game_mainpanel is not loaded if called from a client_XXX.
        scheduleEvent(function()
            return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
        end, 100)
    else
        return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)

    end

end

function addTopRightRegularButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, topLeftButtonsPanel, false, front)
end

function addTopRightToggleButton(id, description, icon, callback, front)
    return addButton(id, description, icon, callback, topLeftTogglesPanel, true, front)
end

function showGameButtons()

    rightGameButtonsPanel:show()
end

function hideGameButtons()

    rightGameButtonsPanel:hide()
end

function getButton(id)
    return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
    return topMenu
end

function getRightGameButtonsPanel()
    return topLeftTogglesPanel
end

function toggle()
    if not topMenu then
        return
    end

    if topMenu:isVisible() then
        hide()
    else
        show()
    end
end

function openManagerAccounts()
    if Services.websites then
        g_platform.openUrl(Services.websites)
    end

end

function extendedView(extendedView)
    if not topMenu then
        return
    end
    topMenu:breakAnchors()
    if extendedView then
        topMenu:show()
        topMenu:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        topMenu:addAnchor(AnchorRight, 'parent', AnchorRight)
        modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
        pingLabel:setVisible(false)
        fpsLabel:setVisible(false)
    else
        if g_game.isOnline() then
            topMenu:hide()
        end
        topMenu:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'parent', AnchorTop)
        topMenu:setWidth(1020)
    end
end
