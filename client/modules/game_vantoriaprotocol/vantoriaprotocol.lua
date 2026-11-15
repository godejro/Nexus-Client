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
  -- Vocation data is decoded by the common, profile-configurable native parser.
  if opcode == 0xB4 and isActiveProfile() then sampleCombat(msg) end
  return false
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
