local iconTopMenu = nil
local loadingBot = false

function getBotButton()
    return healthManaController.ui and healthManaController.ui.cwelBotLauncher
end

function refreshBotChoice(value)
    local ui=healthManaController.ui
    if not ui then return end
    local visible=true -- CWEL BOT is the client's only integrated bot.
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
    refreshBotChoice()
end

function healthManaController:onTerminate()
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
