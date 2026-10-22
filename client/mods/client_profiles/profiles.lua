local settings = {}
local reloadEvent
local characterName
ChangedProfile = false

local function validSlot(value)
  local number = tonumber(value)
  if number and number >= 0 and number <= 10 and number % 1 == 0 then return number end
end

function queueProfileChange()
  if reloadEvent then removeEvent(reloadEvent) end
  reloadEvent = scheduleEvent(function()
    reloadEvent = nil
    onProfileChange(false)
  end, 0)
end

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

end

function terminate()
  if reloadEvent then removeEvent(reloadEvent) reloadEvent=nil end
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
end

-- loads settings on character login
function online()
  ChangedProfile = false
  characterName = g_game.getCharacterName()

  -- startup arguments has higher priority than settings
  local index = getProfileFromStartupArgument()
  if index then
    setProfileOption(index)
  end

  load()

  if not index then
    setProfileOption(getProfileFromSettings() or validSlot(g_settings.getNumber('profile')) or 1)
  end

  -- create main settings dir
  if not g_resources.directoryExists("/settings/") then
    g_resources.makeDir("/settings/")
  end

  -- create profiles dirs
  for i=1,10 do
    local path = "/settings/profile_"..i

    if not g_resources.directoryExists(path) then
      g_resources.makeDir(path)
    end
  end
  g_resources.makeDir('/settings/profile_' .. g_settings.getNumber('profile'))
end

function setProfileOption(index)
  index = validSlot(index)
  if index == nil then return false end
  local currentProfile = g_settings.getNumber('profile')
  currentProfile = tostring(currentProfile)
  index = tostring(index)

  if currentProfile ~= index then
    ChangedProfile = true
    return modules.client_options.setOption('profile', tonumber(index))
  end

end

-- load profile number from settings
function getProfileFromSettings()
  -- settings should save per character, return if not online
  if not g_game.isOnline() then return end

  local index = g_game.getCharacterName()
  local savedData = settings[index]

  return validSlot(savedData)
end

-- option to launch client with hardcoded profile
function getProfileFromStartupArgument()
    local startupOptions = string.split(g_app.getStartupOptions(), " ")
    if #startupOptions < 2 then
        return false
    end

    for index, option in ipairs(startupOptions) do
        if option == "--bot-profile" or option == "--profile" then
            local profileIndex = startupOptions[index + 1]
            if profileIndex == nil then
              return g_logger.info("Startup arguments incomplete: missing profile index.")
            end

            profileIndex = validSlot(profileIndex)
            -- --profile vantoria15_25-2 belongs to the server manager.
            if profileIndex ~= nil then
              g_logger.info("Startup options: Forced bot slot: "..profileIndex)
              return profileIndex
            end
        end
    end

    return false
end

-- returns string path ie. "/settings/1/actionbar.json"
function getSettingsFilePath(fileNameWithFormat)
  local currentProfile = g_settings.getNumber('profile')

  return "/settings/profile_"..currentProfile.."/"..fileNameWithFormat
end

function offline()
  if reloadEvent then removeEvent(reloadEvent) reloadEvent=nil end
  onProfileChange(true)
  characterName = nil
end

-- profile change callback (called in options), saves settings & reloads given module configs
function onProfileChange(offline)
  if not offline then
    if not g_game.isOnline() then return end
  -- had to apply some delay
    if reloadEvent then removeEvent(reloadEvent) end
    reloadEvent = scheduleEvent(function() reloadEvent=nil collectiveReload() end, 100)
  end

  local currentProfile = g_settings.getNumber('profile')
  local index = characterName or g_game.getCharacterName()

  if index and index ~= '' then
    settings[index] = currentProfile
    save()
  end
end

-- collection of refresh functions from different modules
function collectiveReload()
  for _,name in ipairs({'game_topbar', 'game_actionbar', 'game_bot'}) do
    local module = modules[name]
    if module and module.refresh then module.refresh(true) end
  end
end

-- json handlers
function load()
  local file = "/settings/profiles.json"
  if g_resources.fileExists(file) then
    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)
    if not status or type(result) ~= 'table' then
        return g_logger.warning(
                   "Error while reading profiles file. To fix this problem you can delete storage.json. Details: " ..
                       tostring(result))
    end
    settings = result
  end
end

function save()
  local file = "/settings/profiles.json"
  g_resources.makeDir('/settings')
  local status, result = pcall(function() return json.encode(settings, 2) end)
  if not status then
      return g_logger.warning(
                 "Error while saving profile settings. Data won't be saved. Details: " ..
                     result)
  end
  if result:len() > 100 * 1024 * 1024 then
      return g_logger.warning(
                 "Something went wrong, file is above 100MB, won't be saved")
  end
  local ok, written = pcall(g_resources.writeFileContents, file, result)
  if not ok or written == false then g_logger.warning('Cannot save bot profile selection: '..tostring(written)) end
end
