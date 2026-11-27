-- Boss difficulty selection (Tibia 15, Summer Update 2026 boss levers).
--
-- Server -> client 0x2F, client -> server 0xC2. Layout as implemented by the
-- Crystal server (zimbadev/crystalserver, ProtocolGame::sendBossDifficultySelection
-- and parseBossDifficultySelection):
--   0x2F u8 kind/selected, u32 f1, u8 f2, u16 raceId, u16 f4, u16 highestInGroup,
--        u16 personalHighest, u32 badLuck (x1000 %), 5 x string (party banners),
--        u16 update, u8 n + n x string (penalties), u8 n + n x string (bonuses)
--   0x2F 0x01 alone closes the window.
--   0xC2 u32 context (1), u8 action (0 start, 2 preview, 1 close), [u16 difficulty]
-- Every received packet is written to nexus_bossdifficulty.log (hex) so the
-- layout can be checked against a real server.

local OPCODE_SERVER = 0x2F
local OPCODE_CLIENT = 0xC2
local ACTION_START, ACTION_CLOSE, ACTION_PREVIEW = 0, 1, 2
local MIN_OPEN_PAYLOAD = 22
local LOG_FILE = '/nexus_bossdifficulty.log'

local window = nil
local state = nil
local registered = false
local logLines = {}

local function writeLog(line)
    logLines[#logLines + 1] = os.date('%Y-%m-%d %H:%M:%S ') .. line
    while #logLines > 200 do table.remove(logLines, 1) end
    pcall(g_resources.writeFileContents, LOG_FILE, table.concat(logLines, '\n') .. '\n')
end

-- Reader that records every consumed byte as hex for the log.
local function reader(msg)
    local r = { msg = msg, hex = {} }
    local function rec(fmt, value) r.hex[#r.hex + 1] = string.format(fmt, value) end
    function r.u8() local v = msg:getU8() rec('%02X', v) return v end
    function r.u16() local v = msg:getU16() rec('%04X', v) return v end
    function r.u32() local v = msg:getU32() rec('%08X', v) return v end
    function r.str()
        local s = msg:getString()
        rec('"%s"', s)
        return s
    end
    function r.unread() return msg:getUnreadSize() end
    return r
end

local function send(action, difficulty)
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local out = OutputMessage.create()
    out:addU8(OPCODE_CLIENT)
    out:addU32(state and state.context or 1)
    out:addU8(action)
    if action == ACTION_START or action == ACTION_PREVIEW then
        out:addU16(difficulty or 0)
    end
    protocol:send(out)
end

local function destroyWindow()
    if window then
        window:destroy()
        window = nil
    end
end

local function fillModifiers(panel, list, positive)
    panel:destroyChildren()
    for _, text in ipairs(list) do
        local label = g_ui.createWidget('BossDiffModifier', panel)
        label:setText((positive and '+  ' or '-  ') .. text)
        label:setColor(positive and '#7fdc7f' or '#e07070')
    end
end

-- Rules of the Boss Difficulty System (Summer Update 2026, CipSoft):
-- difficulty 0 is the practice mode (less damage taken, no loot, no Bosstiary
-- progress); a won fight unlocks everything up to the beaten difficulty + 3;
-- only the group leader can change the difficulty and start the fight.
local PRACTICE_PENALTIES = {}
local PRACTICE_INFO = {
    'Practice mode: you take reduced damage.',
    'No loot and no Bosstiary progress.',
    'You can still die in this mode.'
}

local function modeText(difficulty)
    if difficulty == 0 then
        return tr('Practice mode')
    end
    return tr('Difficulty %d', difficulty)
end

local function refreshInfo()
    if not window or not state then return end
    local penalties, bonuses = state.penalties, state.bonuses
    if state.selected == 0 then
        penalties = PRACTICE_PENALTIES
        bonuses = {}
        for _, line in ipairs(PRACTICE_INFO) do bonuses[#bonuses + 1] = tr(line) end
    elseif #penalties == 0 and #bonuses == 0 then
        bonuses = { tr('Waiting for the server to describe difficulty %d...', state.selected) }
    end
    fillModifiers(window.infoBox.penalties, penalties, false)
    fillModifiers(window.infoBox.bonuses, bonuses, true)
    if state.selected == 0 then
        local bonusPanel = window.infoBox.bonuses
        for _, child in ipairs(bonusPanel:getChildren()) do child:setColor('#9fb7d8') end
    end
    local unlockTo = state.personalHighest + 3
    window.bossBox.modeLabel:setText(modeText(state.selected))
    window.bossBox.personalValue:setTooltip(tr('A won fight unlocks every difficulty up to the beaten one + 3 (next: %d).', unlockTo))
    window.bossBox.groupValue:setTooltip(tr('The group can pick up to the lowest unlocked difficulty among its members.'))
    window.partyBox.startButton:setTooltip(tr('Only the group leader can change the difficulty and start the fight.'))
end

local function refreshSpinner()
    if not window or not state then return end
    local spinner = window.bossBox.spinner
    local maxValue = math.max(state.minDifficulty, state.highestInGroup)
    state.selected = math.max(state.minDifficulty, math.min(state.selected, maxValue))
    spinner.value:setText(tostring(state.selected))
    spinner.first:setEnabled(state.selected > state.minDifficulty)
    spinner.prev:setEnabled(state.selected > state.minDifficulty)
    spinner.next:setEnabled(state.selected < maxValue)
    spinner.last:setEnabled(state.selected < maxValue)
    refreshInfo()
end

local function showWindow()
    if not window then
        window = g_ui.displayUI('bossdifficulty')
        local spinner = window.bossBox.spinner
        spinner.first:setText('|<')
        spinner.prev:setText('<')
        spinner.next:setText('>')
        spinner.last:setText('>|')
    end
    local raceData = state.raceId > 0 and g_things.getRaceData(state.raceId) or nil
    window.bossBox.bossName:setText(raceData and raceData.name ~= '' and raceData.name or tr('Boss'))
    if raceData and raceData.outfit then
        window.bossBox.bossCreature:setOutfit(raceData.outfit)
    end
    window.bossBox.groupValue:setText(tostring(state.highestInGroup))
    window.bossBox.personalValue:setText(tostring(state.personalHighest))
    window.bossBox.badLuckValue:setText(string.format('%.2f%%', state.badLuck / 1000))
    for i = 1, 5 do
        local member = window.partyBox['member' .. i]
        local name = state.banners[i] or ''
        member:setText(#name > 18 and name:sub(1, 16) .. '...' or name)
        member:setVisible(name ~= '')
    end
    refreshSpinner()
    window:show()
    window:raise()
    window:focus()
end

local function onBossDifficulty(protocol, msg)
    local r = reader(msg)
    local ok, err = pcall(function()
        local kind = r.u8()
        if kind == 1 and r.unread() < MIN_OPEN_PAYLOAD then
            writeLog('0x2F close ' .. table.concat(r.hex, ' '))
            addEvent(destroyWindow)
            return
        end
        local s = { context = 1 }
        s.kind = kind
        s.f1 = r.u32()
        s.f2 = r.u8()
        s.raceId = r.u16()
        s.f4 = r.u16()
        s.highestInGroup = r.u16()
        s.personalHighest = r.u16()
        s.badLuck = r.u32()
        s.banners = {}
        for i = 1, 5 do s.banners[i] = r.str() end
        s.update = r.u16()
        s.penalties = {}
        for _ = 1, r.u8() do s.penalties[#s.penalties + 1] = r.str() end
        s.bonuses = {}
        for _ = 1, r.u8() do s.bonuses[#s.bonuses + 1] = r.str() end
        s.minDifficulty = 0
        -- Keep the player's own choice while the server only updates the window.
        if state and window then
            s.selected = state.selected
        else
            s.selected = s.f4 > 0 and s.f4 or (kind > 0 and kind or s.highestInGroup)
        end
        state = s
        writeLog(string.format('0x2F open race=%d sel=%d group=%d personal=%d unreadAfter=%d | %s',
            s.raceId, s.selected, s.highestInGroup, s.personalHighest, r.unread(), table.concat(r.hex, ' ')))
        addEvent(showWindow)
    end)
    if not ok then
        writeLog('0x2F PARSE ERROR ' .. tostring(err) .. ' | ' .. table.concat(r.hex, ' '))
        error(err)
    end
end

function step(direction)
    if not state then return end
    local maxValue = math.max(state.minDifficulty, state.highestInGroup)
    if direction == 'first' then
        state.selected = state.minDifficulty
    elseif direction == 'last' then
        state.selected = maxValue
    else
        state.selected = state.selected + direction
    end
    refreshSpinner()
    send(ACTION_PREVIEW, state.selected)
end

function startFight()
    if not state then return end
    send(ACTION_START, state.selected)
end

function close()
    if state then
        send(ACTION_CLOSE)
    end
    state = nil
    destroyWindow()
end

local function register()
    if registered then return end
    -- Boss challenge levels (Make Believe) arrived with the Summer Update 2026,
    -- protocol 15.30. On 15.25 and older the 0x2F opcode means something else
    -- or nothing, so the window is not registered there.
    local protocol = g_game.getProtocolVersion and g_game.getProtocolVersion() or g_game.getClientVersion()
    if g_game.getClientVersion() < 1530 or protocol < 1530 then return end
    ProtocolGame.registerOpcode(OPCODE_SERVER, onBossDifficulty)
    registered = true
end

local function unregister()
    if registered then
        ProtocolGame.unregisterOpcode(OPCODE_SERVER)
        registered = false
    end
    state = nil
    destroyWindow()
end

function init()
    connect(g_game, { onGameStart = register, onGameEnd = unregister })
    if g_game.isOnline() then register() end
end

function terminate()
    disconnect(g_game, { onGameStart = register, onGameEnd = unregister })
    unregister()
end
