local deathTexts = {
    regular = {
        text = 'Alas! Brave adventurer, you have met a sad fate.\nBut do not despair, for the gods will bring you back\ninto this world in exchange for a small sacrifice\n\nSimply click on Ok to resume your journeys!',
        height = 140,
        width = 0
    },
    unfair = {
        text = 'Alas! Brave adventurer, you have met a sad fate.\nBut do not despair, for the gods will bring you back\ninto this world in exchange for a small sacrifice\n\nThis death penalty has been reduced by %i%%\nbecause it was an unfair fight.\n\nSimply click on Ok to resume your journeys!',
        height = 185,
        width = 0
    },
    blessed = {
        text = 'Alas! Brave adventurer, you have met a sad fate.\nBut do not despair, for the gods will bring you back into this world\n\nThis death penalty has been reduced by 100%\nbecause you are blessed with the Adventurer\'s Blessing\n\nSimply click on Ok to resume your journeys!',
        height = 170,
        width = 90
    }
}

deathController = Controller:new()
local reconnectEvent = nil
local reloginEvent = nil
local deathActionPending = false

local function cancelReconnect()
    if reconnectEvent then
        removeEvent(reconnectEvent)
        reconnectEvent = nil
    end
end

local function cancelRelogin()
    if reloginEvent then
        removeEvent(reloginEvent)
        reloginEvent = nil
    end
end

function deathController:onInit()
    deathController:registerEvents(g_game, {
        onDeath = display,
    })
end

function deathController:onTerminate()
    cancelReconnect()
    cancelRelogin()
    deathActionPending = false
    deathController.ui = destroyWindows()
end

function deathController:onGameEnd()
    cancelReconnect()
    deathController.ui = destroyWindows()
end

function destroyWindows()
    if deathController.ui and not deathController.ui:isDestroyed() then
        deathController.ui:destroy()
    end
    return nil
end

function display(deathType, penalty)
    cancelReconnect()
    cancelRelogin()
    deathActionPending = false
    displayDeadMessage()
    openWindow(deathType, penalty)
    scheduleReconnect()
end

local function finishDeath(relogin)
    if deathActionPending then
        return
    end

    deathActionPending = true
    cancelReconnect()
    deathController.ui = destroyWindows()

    if g_game.isOnline() then
        g_game.forceLogout()
    else
        g_game.cancelLogin()
    end

    if not relogin then
        deathActionPending = false
        return
    end

    cancelRelogin()
    reloginEvent = addEvent(function()
        reloginEvent = nil
        deathActionPending = false
        if CharacterList and CharacterList.doLogin then
            CharacterList.doLogin()
        else
            g_logger.error('Unable to relog after death: CharacterList is unavailable')
        end
    end)
end

function displayDeadMessage()
    local advanceLabel = modules.game_interface.getRootPanel():recursiveGetChildById('middleCenterLabel')
    if advanceLabel:isVisible() then
        return
    end

    modules.game_textmessage.displayGameMessage(tr('You are dead.'))
end

function openWindow(deathType, penalty)
    deathController.ui = destroyWindows()
    deathController.ui = g_ui.displayUI('deathwindow', rootWidget)

    local textLabel = deathController.ui:getChildById('labelText')
    if deathType == DeathType.Regular then
        if penalty == 100 then
            textLabel:setText(deathTexts.regular.text)
            deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.regular.height)
            deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.regular.width)
        else
            textLabel:setText(string.format(deathTexts.unfair.text, 100 - penalty))
            deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.unfair.height)
            deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.unfair.width)
        end
    elseif deathType == DeathType.Blessed then
        textLabel:setText(deathTexts.blessed.text)
        deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.blessed.height)
        deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.blessed.width)
    end

    local okButton = deathController.ui:getChildById('buttonOk')
    local cancelButton = deathController.ui:getChildById('buttonCancel')

    local okFunc = function()
        finishDeath(true)
    end
    local cancelFunc = function()
        finishDeath(false)
    end

    deathController.ui.onEnter = okFunc
    deathController.ui.onEscape = cancelFunc

    okButton.onClick = okFunc
    cancelButton.onClick = cancelFunc
end

function scheduleReconnect()
    cancelReconnect()
    if not g_settings.getBoolean('autoReconnect') then
        return
    end

    reconnectEvent = scheduleEvent(function()
        reconnectEvent = nil
        finishDeath(true)
    end, 2000)
end
