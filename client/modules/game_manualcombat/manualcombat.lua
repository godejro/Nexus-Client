local events, correctionEvent, followEvent
local originalSetChase, originalFollow, originalAttack
local guardedSetChase, guardedFollow, guardedAttack
local applying = false
local lastSnapshot = -1000
local nativeModes, modeWrappers = {}, {}
local tactics, active
local requestedMode = DontChase

local function modernTactics()
    return g_game.getClientVersion() == 1525 and g_game.getProtocolVersion() == 1525
end

local function getTactics()
    if not tactics then
        tactics = {chase=DontChase, safe=nativeModes.isSafeFight(), pvp=nativeModes.getPVPMode()}
    end
    return tactics
end

local function modeSignal(name, value)
    signalcall(g_game[name], value)
end

function isChaseLocked()
    return false
end

local function cancelPending()
    if correctionEvent then removeEvent(correctionEvent) correctionEvent = nil end
    if followEvent then removeEvent(followEvent) followEvent = nil end
    lastSnapshot = -1000
end

local function resendStand()
    if not modernTactics() then return end
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local msg = OutputMessage.create()
    msg:addU8(0xA0)
    -- 15.25 tactics removed fightMode: chase, secure, PvP (Canary #4051).
    msg:addU8(requestedMode)
    msg:addU8(g_game.isSafeFight() and 1 or 0)
    msg:addU8(g_game.getPVPMode())
    protocol:send(msg)
end

local function applyStand(resend)
    if applying or not g_game.isOnline() then return end
    applying = true
    local ok, err = pcall(function()
        local now = g_clock.millis()
        if modernTactics() then
            local state = getTactics()
            local changed = state.chase ~= requestedMode
            state.chase = requestedMode
            if changed then modeSignal('onChaseModeChange', requestedMode) end
            if changed or (resend and now - lastSnapshot >= 250) then
                resendStand()
                lastSnapshot = now
            end
        elseif g_game.getChaseMode() ~= requestedMode then
            originalSetChase(requestedMode)
            lastSnapshot = now
        elseif resend and now - lastSnapshot >= 250 then
            resendStand()
            lastSnapshot = now
        end
    end)
    applying = false
    if not ok then g_logger.warning('[ManualCombat] ' .. tostring(err)) end
end

local function cancelMonsterFollow()
    local creature = g_game.getFollowingCreature()
    if creature and creature:isMonster() then g_game.cancelFollow() end
end

function selectMode(mode)
    if mode ~= DontChase and mode ~= ChaseOpponent then return false end
    requestedMode = mode
    applyStand(true)
    if mode == DontChase and g_game.isOnline() then cancelMonsterFollow() end
    return true
end

local function modeChanged()
    if applying or not g_game.isOnline() or g_game.getChaseMode() == requestedMode or correctionEvent then return end
    -- Native callbacks run inside setChaseMode. Avoid re-entrant UI updates.
    correctionEvent = scheduleEvent(function()
        correctionEvent = nil
        applyStand(false)
    end, math.max(0, 250 - (g_clock.millis() - lastSnapshot)))
end

local function followingChanged(creature)
    if requestedMode ~= DontChase or not creature or not creature:isMonster() or followEvent then return end
    -- Game::follow emits this event before sending its packet.
    followEvent = scheduleEvent(function()
        followEvent = nil
        if requestedMode == DontChase and g_game.isOnline() then cancelMonsterFollow() end
    end, 0)
end

local function attackingChanged(creature)
    if creature then applyStand(true) end
end

local function gameStart()
    cancelPending()
    selectMode(DontChase)
end

-- The stable executable predates the 15.25 tactics layout. Handle its three
-- fields here without invoking native setters which would send the old layout.
function handleOpcode(opcode, msg)
    if not active or opcode ~= 0xA7 or not modernTactics() then return false end
    local chase, safe, pvp = msg:getU8(), msg:getU8(), msg:getU8()
    tactics = {chase=chase ~= 0 and ChaseOpponent or DontChase, safe=safe ~= 0, pvp=pvp}
    modeSignal('onFightModeChange', FightOffensive)
    modeSignal('onChaseModeChange', tactics.chase)
    modeSignal('onSafeFightChange', tactics.safe)
    modeSignal('onPVPModeChange', tactics.pvp)
    return true
end

local function installTactics()
    for _,name in ipairs({'getFightMode','getChaseMode','isSafeFight','getPVPMode','setFightMode','setSafeFight','setPVPMode'}) do
        nativeModes[name] = g_game[name]
    end
    local fields = {getFightMode='fight',getChaseMode='chase',isSafeFight='safe',getPVPMode='pvp'}
    for name,field in pairs(fields) do
        modeWrappers[name] = function(...)
            if not modernTactics() then return nativeModes[name](...) end
            if field == 'fight' then return FightOffensive end
            return getTactics()[field]
        end
    end
    modeWrappers.setFightMode = function(value)
        if not modernTactics() then return nativeModes.setFightMode(value) end
        -- Fight stance no longer exists on the 15.25 wire.
        if g_game.isOnline() then modeSignal('onFightModeChange', FightOffensive) end
    end
    for name,field in pairs({setSafeFight='safe',setPVPMode='pvp'}) do
        modeWrappers[name] = function(value)
            if not modernTactics() then return nativeModes[name](value) end
            if not g_game.isOnline() then return end
            if field == 'safe' then value = not not value
            elseif type(value) ~= 'number' or value < 0 or value > 3 or value % 1 ~= 0 then return end
            local state = getTactics()
            if state[field] == value then return end
            state[field] = value
            resendStand()
            lastSnapshot = g_clock.millis()
            modeSignal(field == 'safe' and 'onSafeFightChange' or 'onPVPModeChange', value)
        end
    end
    for name,fn in pairs(modeWrappers) do g_game[name] = fn end
end

function terminate()
    active = false
    if events then disconnect(g_game, events) events = nil end
    cancelPending()
    if guardedSetChase and g_game.setChaseMode == guardedSetChase then g_game.setChaseMode = originalSetChase end
    if guardedFollow and g_game.follow == guardedFollow then g_game.follow = originalFollow end
    if guardedAttack and g_game.attack == guardedAttack then g_game.attack = originalAttack end
    guardedSetChase, guardedFollow, guardedAttack = nil, nil, nil
    for name,fn in pairs(modeWrappers) do
        if g_game[name] == fn then g_game[name] = nativeModes[name] end
    end
    modeWrappers, nativeModes, tactics = {}, {}, nil
    applying = false
    requestedMode = DontChase
end

function init()
    terminate()
    installTactics()
    active = true
    originalSetChase, originalFollow, originalAttack = g_game.setChaseMode, g_game.follow, g_game.attack
    -- Only the explicit inventory/hotkey selector grants chase. Scripts may
    -- switch it off, but cannot silently opt a manual player into chasing.
    guardedSetChase = function(mode)
        if mode == DontChase then requestedMode = DontChase end
        applyStand(false)
    end
    guardedFollow = function(creature, ...)
        if requestedMode == DontChase and creature and creature:isMonster() then
            selectMode(DontChase)
            return
        end
        return originalFollow(creature, ...)
    end
    guardedAttack = function(creature, ...)
        if creature then applyStand(true) end
        return originalAttack(creature, ...)
    end
    g_game.setChaseMode, g_game.follow, g_game.attack = guardedSetChase, guardedFollow, guardedAttack
    events = {
        onGameStart = gameStart,
        onGameEnd = function() cancelPending() tactics = nil end,
        onChaseModeChange = modeChanged,
        onFollowingCreatureChange = followingChanged,
        onAttackingCreatureChange = attackingChanged
    }
    connect(g_game, events)
    if g_game.isOnline() then gameStart() end
    if modules and modules.game_inventory and modules.game_inventory.selectPosture then
        modules.game_inventory.selectPosture('stand', true)
    end
end
