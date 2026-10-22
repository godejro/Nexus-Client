local events, timer
local running = false
local ring, lastRead = {}, 0
local nextReport = 0
local sum, minimum, samples, lag, expected = 0, math.huge, 0, 0, 0
local pingSum, pingMin, pingMax, pingCount, pingDelta = 0, math.huge, 0, 0, 0
local previousPing, previousEventPing, nextPingReport
local opcodeCount, mapCount, moveCount, lastOpcodeTime = 0, 0, 0, nil

local function now() return g_clock.millis() end
local function active()
    local compatibility = modules.game_vantoriaprotocol
    return compatibility and compatibility.isActiveProfile and compatibility.isActiveProfile() or false
end

function observe(opcode, msg)
    if not running or not active() then return end
    local read = msg:getReadSize()
    if read <= lastRead then ring = {} end
    lastRead = read
    local time = now()
    opcodeCount = opcodeCount + 1
    lastOpcodeTime = time
    if (opcode >= 0x64 and opcode <= 0x6D) or opcode == 0xBE or opcode == 0xBF then
        mapCount = mapCount + 1
    end
    if opcode == 0x6D then moveCount = moveCount + 1 end
    if opcode == 0xA1 or opcode == 0xC1 or opcode == 0x84 then
        ring[#ring + 1] = {opcode=opcode, read=read, unread=msg:getUnreadSize()}
        if #ring > 3 then table.remove(ring, 1) end
    elseif opcode == 0 and time >= nextReport then
        nextReport = time + 30000
        local buffer = msg:getBuffer()
        for _,entry in ipairs(ring) do
            local preview = buffer:sub(entry.read + 1, entry.read + math.min(entry.unread, entry.opcode == 0xA1 and 320 or 24))
            local hex = preview:gsub('.', function(c) return string.format('%02X ', c:byte()) end)
            g_logger.warning(string.format('[VantoriaTrace] opcode=%02X read=%d unread=%d next=%s', entry.opcode, entry.read, entry.unread, hex))
        end
        local flags = {}
        for _,feature in ipairs({{'CharacterSkills',GameCharacterSkillStats},{'ForgeSkills',GameForgeSkillStats},
            {'AdditionalSkills',GameAdditionalSkills},{'Concotions',GameConcotions},{'Monk',GameVocationMonk}}) do
            if feature[2] then flags[#flags + 1] = feature[1] .. '=' .. tostring(g_game.getFeature(feature[2])) end
        end
        g_logger.warning('[VantoriaTrace] Unexpected opcode 00; ' .. table.concat(flags, ' '))
    end
end

local function applyTexturePreference()
    if g_settings.getBoolean('stableTextureLoadingV1') then return end
    if g_app.isEncrypted and g_app.isEncrypted() then return end
    local options = modules.client_options
    if options.getOption('asyncTxtLoading') == false then
        g_settings.set('stableTextureLoadingPrevious', false)
        options.setOption('asyncTxtLoading', true)
        g_logger.info('[ClientPerformance] Async texture loading enabled; rendering quality and walk timing unchanged.')
    end
    g_settings.set('stableTextureLoadingV1', true)
end

local function resetSamples()
    sum, minimum, samples, lag = 0, math.huge, 0, 0
    pingSum, pingMin, pingMax, pingCount, pingDelta = 0, math.huge, 0, 0, 0
    opcodeCount, mapCount, moveCount = 0, 0, 0
end

local function pingChanged(value)
    if not running or not g_game.isOnline() or not active() then return end
    if type(value) ~= 'number' or value < 0 then return end
    local difference = previousEventPing and math.abs(value - previousEventPing) or 0
    previousEventPing = value
    local time = now()
    if (value >= 250 or difference >= 100) and time >= (nextPingReport or 0) then
        nextPingReport = time + 10000
        g_logger.info(string.format('[ClientNetwork] gameRtt=%dms change=%dms; RTT includes server/client processing, not a packet-loss measurement', value, difference))
    end
end

local function sample()
    timer = nil
    if not running or not g_game.isOnline() then return end
    local time = now()
    if active() and g_window.isVisible() then
        local fps = g_app.getFps()
        if fps > 0 then
            sum = sum + fps minimum = math.min(minimum, fps) samples = samples + 1
            lag = math.max(lag, math.max(0, time - expected))
            local ping = g_game.getPing()
            if ping >= 0 then
                pingSum = pingSum + ping pingCount = pingCount + 1
                pingMin = math.min(pingMin, ping) pingMax = math.max(pingMax, ping)
                if previousPing then pingDelta = math.max(pingDelta, math.abs(ping - previousPing)) end
                previousPing = ping
            end
        end
        if samples >= 30 then
            g_logger.info(string.format('[ClientPerformance] sampledFps avg=%.1f min=%d luaDelayMax=%dms ping=%dms pingSampled[min/avg/max/maxDelta]=%d/%.1f/%d/%dms pingSamples=%d opcodes[all/map/move]=%d/%d/%d recvIdle=%dms',
                sum / samples, minimum, lag, g_game.getPing(),
                pingCount > 0 and pingMin or -1, pingCount > 0 and pingSum / pingCount or -1,
                pingCount > 0 and pingMax or -1, pingDelta, pingCount,
                opcodeCount, mapCount, moveCount, lastOpcodeTime and math.max(0, time - lastOpcodeTime) or -1))
            resetSamples()
        end
    else resetSamples() end
    expected = time + 1000
    timer = scheduleEvent(sample, 1000)
end

local function stopSession()
    if timer then removeEvent(timer) timer = nil end
    resetSamples() ring = {} lastRead = 0 nextReport = 0
    previousPing, previousEventPing, nextPingReport, lastOpcodeTime = nil, nil, nil, nil
end

local function startSession()
    stopSession()
    applyTexturePreference()
    expected = now() + 1000
    timer = scheduleEvent(sample, 1000)
end

function terminate()
    running = false
    if events then disconnect(g_game, events) events = nil end
    stopSession()
end

function init()
    terminate()
    running = true
    events = {onGameStart=startSession, onGameEnd=stopSession, onPingBack=pingChanged}
    connect(g_game, events)
    if g_game.isOnline() then startSession() end
end
