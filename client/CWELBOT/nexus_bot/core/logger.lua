NexusBot.Logger = {
  levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
  level = 3
}

local function write(level, moduleName, message)
  if NexusBot.Logger.level < NexusBot.Logger.levels[level] then return end
  local line = string.format('[%s][%s][%s] %s', NexusBot.Metadata.name, level, moduleName or 'Core', tostring(message))
  if g_logger then
    if level == 'ERROR' then
      g_logger.error(line)
    elseif level == 'WARN' then
      g_logger.warning(line)
    elseif level == 'DEBUG' then
      g_logger.debug(line)
    else
      g_logger.info(line)
    end
  elseif NexusBot.botSandbox and level == 'ERROR' and error then
    error(line)
  elseif NexusBot.botSandbox and level == 'WARN' and warn then
    warn(line)
  elseif NexusBot.botSandbox and info then
    info(line)
  else
    print(line)
  end
end

function NexusBot.Logger.setDebug(enabled)
  NexusBot.Logger.level = enabled and 4 or 3
end
function NexusBot.Logger.error(moduleName, message) write('ERROR', moduleName, message) end
function NexusBot.Logger.warn(moduleName, message) write('WARN', moduleName, message) end
function NexusBot.Logger.info(moduleName, message) write('INFO', moduleName, message) end
function NexusBot.Logger.debug(moduleName, message) write('DEBUG', moduleName, message) end
