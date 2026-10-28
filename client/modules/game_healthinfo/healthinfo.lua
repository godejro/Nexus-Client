local iconTopMenu = nil
local loadingBot = false
local floatingLauncher
local suppressClickUntil=0

function getBotButton()
    if g_settings.getString('nexusBotLauncherMode')=='floating' then return floatingLauncher end
    return healthManaController.ui and healthManaController.ui.cwelBotLauncher
end

function refreshBotChoice(value)
    local ui=healthManaController.ui
    if not ui then return end
    local visible=g_settings.getString('nexusBotLauncherMode')~='floating'
    if floatingLauncher then floatingLauncher:setVisible(not visible and g_game.isOnline()) end
    ui.cwelBotLauncher:setVisible(visible)
    ui.cwelBotLauncher:setHeight(visible and 24 or 0)
    ui.cwelBotLauncher:setMarginTop(visible and 4 or 0)
    ui.panelHeight=visible and 60 or 32
    ui:setHeight(ui.panelHeight)
end

function openBot()
    if loadingBot then return end
    loadingBot = true
    local ok, err = pcall(function()
        local bot = g_modules.getModule('nexus_bot')
        if not bot then error('CWEL BOT files are missing. Restore the CWELBOT/nexus_bot folder.') end
        local firstLoad=not bot:isLoaded()
        if firstLoad then
            if not bot:load() then error('CWEL BOT could not load. Check the client log.') end
        end
        -- Loading an automatic character setup can already open the launcher.
        -- The first click must show it, rather than immediately hiding it.
        if firstLoad then modules.nexus_bot.show() else modules.nexus_bot.toggle() end
    end)
    loadingBot = false
    if not ok then displayErrorBox('CWEL BOT', tostring(err)) end
end
local function healthManaEvent()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    healthManaController.ui.health.text:setText(player:getHealth())
    healthManaController.ui.health.current:setWidth(math.max(12, math.ceil(
        (healthManaController.ui.health.total:getWidth() * player:getHealth()) / player:getMaxHealth())))

    healthManaController.ui.mana.text:setText(player:getMana())
    healthManaController.ui.mana.current:setWidth(math.max(12, math.ceil(
        (healthManaController.ui.mana.total:getWidth() * player:getMana()) / player:getMaxMana())))
end

healthManaController = Controller:new()
healthManaController:setUI('healthinfo', modules.game_interface.getMainRightPanel())

function healthManaController:onInit()
    floatingLauncher=g_ui.createWidget('NexusFloatingLauncher',modules.game_interface.getRootPanel())
    local pos=g_settings.getNode('nexusBotLauncherPosition') or {x=30,y=100}
    floatingLauncher:setPosition({x=tonumber(pos.x) or 30,y=tonumber(pos.y) or 100})
    floatingLauncher:bindRectToParent()
    floatingLauncher.onClick=function()
        if g_clock.millis()>=suppressClickUntil then openBot() end
    end
    floatingLauncher.onDragLeave=function(widget)
        suppressClickUntil=g_clock.millis()+200
        g_settings.setNode('nexusBotLauncherPosition',widget:getPosition()) g_settings.save()
    end
    refreshBotChoice()
end

function healthManaController:onGameEnd()
    if floatingLauncher then floatingLauncher:hide() end
end

function healthManaController:onTerminate()
    if floatingLauncher then floatingLauncher:destroy() floatingLauncher=nil end
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
end

function healthManaController:onGameStart()
    refreshBotChoice()
    healthManaController:registerEvents(LocalPlayer, {
        onHealthChange = healthManaEvent,
        onManaChange = healthManaEvent
    }):execute()
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('healthMana', tr('Show health'),
                '/images/topbuttons/healthinfo', toggle)
            iconTopMenu:setOn(healthManaController.ui:isVisible())
            healthManaController.ui:setBorderColor('black')
            healthManaController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        healthManaController.ui:setBorderColor('alpha')
        healthManaController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if not mainRightPanel:hasChild(healthManaController.ui) then
            mainRightPanel:insertChild(2, healthManaController.ui)
        end
        healthManaController.ui:show()
    end
    healthManaController.ui.moveOnlyToMain = not extendedView
end

function toggle()
    if iconTopMenu:isOn() then
        healthManaController.ui:hide()
        iconTopMenu:setOn(false)
    else
        healthManaController.ui:show()
        iconTopMenu:setOn(true)
    end
end
