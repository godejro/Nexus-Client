-- Long-session memory log. One row per minute, last 12 hours kept, written to
-- nexus_memlog.csv in the client's write directory every 5 minutes and on exit.
-- Cost: a few counter reads per minute; no allocation-heavy scans.

local SAMPLE_MS = 60 * 1000
local WRITE_EVERY = 5
local MAX_ROWS = 12 * 60
local FILE = '/nexus_memlog.csv'
local HEADER = 'time,uptime_min,working_set_mb,lua_mb,map_layers_nearest,map_layers_linear,map_cached,'
    .. 'map_inactive_sizes,fg_layers_nearest,fg_layers_linear,fg_cached,known_creatures,pending_textures,online'

local rows = {}
local sampleEvent
local started = 0
local sinceWrite = 0

local function atlasPart(text, prefix)
    -- getStats(): "map=size=WxH cached=N | linear:layers=a textures=b free=c inactive=d | nearest:layers=..."
    local section = text:match(prefix .. '=(.-)$') or ''
    section = section:match('^(.-) | fg=') or section
    local cached = tonumber(section:match('cached=(%d+)')) or 0
    local linear = tonumber(section:match('linear:layers=(%d+)')) or 0
    local nearest = tonumber(section:match('nearest:layers=(%d+)')) or 0
    local inactive = 0
    for count in section:gmatch('inactive=(%d+)') do inactive = inactive + tonumber(count) end
    return nearest, linear, cached, inactive
end

local function call(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function writeFile()
    sinceWrite = 0
    local lines = {HEADER}
    for i = 1, #rows do lines[#lines + 1] = rows[i] end
    call(g_resources.writeFileContents, FILE, table.concat(lines, '\n') .. '\n')
end

local function sample()
    local stats = (g_atlas and call(g_atlas.getStats)) or ''
    local mapNearest, mapLinear, mapCached, mapInactive = atlasPart(stats, 'map')
    local fgNearest, fgLinear, fgCached = atlasPart(stats, 'fg')
    local workingSet = (call(g_platform.getMemoryUsage) or 0) / 1048576
    local online = g_game.isOnline()
    rows[#rows + 1] = string.format('%s,%d,%.0f,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
        os.date('%Y-%m-%d %H:%M:%S'),
        math.floor((g_clock.millis() - started) / 60000),
        workingSet,
        collectgarbage('count') / 1024,
        mapNearest, mapLinear, mapCached, mapInactive,
        fgNearest, fgLinear, fgCached,
        online and (call(g_map.getKnownCreatureCount) or 0) or 0,
        call(g_things.getPendingTextureLoadCount) or 0,
        online and 1 or 0)
    while #rows > MAX_ROWS do table.remove(rows, 1) end
    sinceWrite = sinceWrite + 1
    if sinceWrite >= WRITE_EVERY then writeFile() end
end

function init()
    started = g_clock.millis()
    sample()
    sampleEvent = cycleEvent(sample, SAMPLE_MS)
end

function terminate()
    if sampleEvent then
        removeEvent(sampleEvent)
        sampleEvent = nil
    end
    if #rows > 0 then writeFile() end
end
