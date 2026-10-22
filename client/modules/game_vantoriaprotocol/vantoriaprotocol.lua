local running = false
local events
local cachedProfile, cachedActive
local combatSamples = {}
virtueSpellIds = {}

local function reset()
  virtueSpellIds = {}
  cachedProfile, cachedActive = nil, nil
  combatSamples = {}
end

function isActiveProfile()
  if not running or g_game.getClientVersion() ~= 1525 or g_game.getProtocolVersion() ~= 1525 or
      not g_game.getActiveProfileId then return false end
  local id = g_game.getActiveProfileId()
  if id ~= cachedProfile then
    local manager = modules and modules.client_profiles
    if manager and manager.getActiveProfile then
      local profile = manager.getActiveProfile()
      local host = profile and tostring(profile.host or ''):lower():match('^%s*(.-)%s*$')
      cachedActive = profile ~= nil and profile.id == id and host:gsub('%.$', '') == 'vantoria.net'
    else
      cachedActive = id == 'vantoria15_25-2'
    end
    cachedProfile = id
  end
  return cachedActive == true
end

local function sampleCombat(msg)
  if not g_logger or not msg.getBuffer or msg:getUnreadSize() < 1 then return end
  local code = msg:peekU8()
  if not ((code >= 23 and code <= 29) or code == 43) or (combatSamples[code] or 0) >= 2 then return end
  combatSamples[code] = (combatSamples[code] or 0) + 1
  local offset = msg:getReadSize()
  local header = msg:getBuffer():sub(offset + 1, offset + math.min(64, msg:getUnreadSize()))
  local hex = header:gsub('.', function(c) return string.format('%02X ', c:byte()) end)
  g_logger.info(string.format('[VantoriaCombat] mode=%d header=%s', code, hex))
end

function handleOpcode(opcode, msg)
  if (opcode ~= 0xC1 and opcode ~= 0xB4) or not isActiveProfile() then return false end
  if opcode == 0xB4 then sampleCombat(msg) return false end
  if msg:getUnreadSize() < 1 or msg:peekU8() ~= 2 then return false end
  -- Official VocationSpecificPlayerData subtype 2 is a list of U16 spell IDs,
  -- not the legacy one-byte Monk virtue. Read exactly this payload, not the
  -- following opcode. The other subtypes remain in the native parser.
  if msg:getUnreadSize() < 2 then error('Truncated Vantoria virtue count') end
  local count = math.floor(msg:peekU16() / 256)
  if msg:getUnreadSize() < 2 + count * 2 then error('Truncated Vantoria virtue list') end
  msg:getU8()
  msg:getU8()
  local ids = {}
  for i = 1, count do ids[i] = msg:getU16() end
  virtueSpellIds = ids
  return true
end

function terminate()
  running = false
  if events then disconnect(g_game, events) events = nil end
  reset()
end

function init()
  terminate()
  running = true
  events = {onGameEnd=reset, onClientFeaturesReload=reset, onClientVersionChange=reset}
  connect(g_game, events)
end
