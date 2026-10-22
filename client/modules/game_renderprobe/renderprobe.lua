local active, connected, previousPerformance = false, false, false
local captureEvent
local elapsed = 0
local function log(text) g_logger.info('[SmoothTest] ' .. text) end

local function botReport()
  local engine = modules.game_bot
  local context = engine and engine.getContext and engine.getContext()
  local rows = {}
  for index, macro in ipairs(context and context._macros or {}) do
    local timing = macro._performance
    if timing and timing.calls > 0 then
      rows[#rows+1] = {name=macro.name ~= '' and macro.name or ('macro#'..index), timing=timing}
    end
  end
  table.sort(rows,function(a,b) return a.timing.total > b.timing.total end)
  local summary = {'vBot='..(context and 'loaded' or 'OFF'),
    'CWELBOT='..((NexusBot and NexusBot.enabled) and 'ON' or 'OFF')}
  for i=1,math.min(3,#rows) do
    local row=rows[i]
    summary[#summary+1]=string.format('%s total=%dms max=%dms calls=%d',
      tostring(row.name):gsub('[\r\n]',' '),row.timing.total,row.timing.max,row.timing.calls)
  end
  log('Bot sample (cumulative): '..table.concat(summary,'; '))
end

function stopCapture()
  if captureEvent then removeEvent(captureEvent) captureEvent = nil end
  if not active then return end
  log('Final report\n' .. g_stats.getPerformanceReport())
  active = false
  g_stats.setPerformanceEnabled(previousPerformance)
end

local function sample()
  captureEvent = nil
  if not active then return end
  elapsed = elapsed + 10
  log(string.format('t=%ds displayFPS=%d processingFPS=%d', elapsed,
    g_app.getGraphicsFps(), g_app.getProcessingFps()))
  botReport()
  if elapsed >= 180 then stopCapture() return end
  captureEvent = scheduleEvent(sample, 10000)
end

function startCapture()
  if active then return end
  previousPerformance = g_stats.isPerformanceEnabled()
  g_stats.setPerformanceEnabled(true)
  active, elapsed = true, 0
  log('Capture started for 180 seconds. GPU=' .. g_graphics.getRenderer() ..
    '; VSync=' .. tostring(modules.client_options.getOption('vsync')))
  captureEvent = scheduleEvent(sample, 10000)
end

function init()
  local enabled = false
  for argument in g_app.getStartupOptions():gmatch('%S+') do
    if argument == '--smooth-diagnostics' then enabled = true end
  end
  if not enabled then return end
  log('Armed: waiting for game start; a parser error during login can prevent capture from starting.')
  connected = true
  connect(g_game, {onGameStart=startCapture, onGameEnd=stopCapture})
  if g_game.isOnline() then startCapture() end
end

function terminate()
  stopCapture()
  if connected then
    disconnect(g_game, {onGameStart=startCapture, onGameEnd=stopCapture})
    connected = false
  end
end
