-- private variables
local background
local clientVersionLabel
local bgEffectEvent = nil
local toggleState = true  -- controls which effect  is active
local timeLoopBackgroundEffect = 5000 -- 5 seconds

-- After login the client background stays on screen with "Loading world map..."
-- until the game map has data and a ready view, instead of showing a black map.
local WORLD_LOADING_MIN_MS = 1200   -- keep the screen at least this long
local WORLD_LOADING_SETTLE_MS = 400 -- map must stay ready this long before revealing
local WORLD_LOADING_MAX_MS = 30000  -- never hold the player longer than this
local WORLD_LOADING_FADE_MS = 250
local worldLoadingEvent = nil
local worldLoadingStarted = 0
local worldReadySince = nil

-- public functions
function init()
    background = g_ui.displayUI('background')
    background:lower()

    clientVersionLabel = background:getChildById('clientVersionLabel')
    clientVersionLabel:setText('')
    clientVersionLabel:hide()

    if not g_game.isOnline() then
        addEvent(function()
            g_effects.fadeIn(clientVersionLabel, 1500)
        end)
    end

    connect(g_game, {
        onGameStart = hide
    })
    connect(g_game, {
        onGameEnd = show
    })
    startBackgroundEffectLoop() -- start the background effect loop
end

function terminate()
    disconnect(g_game, {
        onGameStart = hide
    })
    disconnect(g_game, {
        onGameEnd = show
    })

    g_effects.cancelFade(background:getChildById('clientVersionLabel'))
    stopWorldLoading()
    if bgEffectEvent then
        removeEvent(bgEffectEvent)
        bgEffectEvent = nil
    end
    background:destroy()

    background = nil
    clientVersionLabel = nil
end

local function stopWorldLoading()
    if worldLoadingEvent then
        removeEvent(worldLoadingEvent)
        worldLoadingEvent = nil
    end
    worldReadySince = nil
    if background then
        g_effects.cancelFade(background)
        background:setOpacity(1)
        background:getChildById('worldLoadingLabel'):hide()
        background:lower()
    end
end

local function hideNow()
    stopWorldLoading()
    background:hide()
    if bgEffectEvent then
        removeEvent(bgEffectEvent)
        bgEffectEvent = nil
    end
end

local function isWorldReady()
    local gameInterface = modules.game_interface
    local mapPanel = gameInterface and gameInterface.getMapPanel and gameInterface.getMapPanel()
    if not mapPanel or mapPanel:isDestroyed() then
        return false
    end
    return mapPanel:isMapDataReady() and mapPanel:isViewReady()
end

local function finishWorldLoading()
    if worldLoadingEvent then
        removeEvent(worldLoadingEvent)
        worldLoadingEvent = nil
    end
    background:getChildById('worldLoadingLabel'):hide()
    g_effects.fadeOut(background, WORLD_LOADING_FADE_MS)
    worldLoadingEvent = scheduleEvent(function()
        worldLoadingEvent = nil
        if g_game.isOnline() then
            hideNow()
        else
            stopWorldLoading()
        end
    end, WORLD_LOADING_FADE_MS + 20)
end

local function checkWorldLoading()
    if not g_game.isOnline() then
        -- Login failed or the game ended; onGameEnd shows the normal background.
        stopWorldLoading()
        return
    end
    local now = g_clock.millis()
    if isWorldReady() then
        worldReadySince = worldReadySince or now
    else
        worldReadySince = nil
    end
    local elapsed = now - worldLoadingStarted
    -- gentle pulse of the title while the map loads
    background:getChildById('worldLoadingLabel'):setOpacity(0.8 + 0.2 * math.cos(elapsed / 350))
    if (worldReadySince and now - worldReadySince >= WORLD_LOADING_SETTLE_MS and elapsed >= WORLD_LOADING_MIN_MS) or
        elapsed >= WORLD_LOADING_MAX_MS then
        finishWorldLoading()
    end
end

function startWorldLoading()
    if not background then
        return
    end
    stopWorldLoading()
    background:show()
    background:raise()
    local label = background:getChildById('worldLoadingLabel')
    label:setOpacity(1)
    label:show()
    worldLoadingStarted = g_clock.millis()
    worldLoadingEvent = cycleEvent(checkWorldLoading, 100)
end

-- Called on game start (and by game_interface.show). While logging in, keep the
-- background up as a loading screen; otherwise hide it right away.
function hide()
    if g_game.isOnline() then
        if not worldLoadingEvent then
            startWorldLoading()
        end
        return
    end
    hideNow()
end

function show()
    stopWorldLoading()
    background:show()
    startBackgroundEffectLoop()
end

function hideVersionLabel()
    background:getChildById('clientVersionLabel'):hide()
end

function setVersionText(text)
    clientVersionLabel:setText(text)
end

-- Bottom tip of the "N" logo in data/images/background.png, as a fraction of
-- the image size (852,404 in the 1672x941 art). The login window sits under it.
local LOGO_TIP_X = 852.5 / 1672
local LOGO_TIP_Y = 404 / 941

-- Screen position of the logo tip. The panel uses image-fixed-ratio: the
-- texture is cropped to the panel's aspect ratio (centered) and stretched.
function getLogoAnchor()
    if not background or background:isDestroyed() then
        return nil
    end
    local tw, th = background:getImageTextureWidth(), background:getImageTextureHeight()
    local rect = background:getRect()
    if not tw or not th or tw <= 0 or th <= 0 or rect.width <= 0 or rect.height <= 0 then
        return nil
    end
    local scale = math.min(tw / rect.width, th / rect.height)
    local offsetX = (tw - rect.width * scale) / 2
    local offsetY = (th - rect.height * scale) / 2
    return {
        x = math.floor(rect.x + (LOGO_TIP_X * tw - offsetX) / scale + 0.5),
        y = math.floor(rect.y + (LOGO_TIP_Y * th - offsetY) / scale + 0.5)
    }
end

function getBackground()
    return background
end

-- 🔄 example of how to use the particles widget
function startBackgroundEffectLoop()
    if bgEffectEvent then
        removeEvent(bgEffectEvent)
        bgEffectEvent = nil
    end

    if background then
        local particles=background:getChildById('particles')
        if particles then particles:setEffect('background2-effect') end
    end
end
