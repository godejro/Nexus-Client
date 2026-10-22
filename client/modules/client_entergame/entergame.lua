EnterGame = {}

function safeDecrypt(text)
    if not text or text == '' then
        return ''
    end
    local success, result = pcall(g_crypt.decrypt, text)
    return success and result or ''
end

-- private variables
local loadBox
local enterGame
local motdWindow
local enterGameButton
local clientBox
local profileBox
local protocolLogin
local motdEnabled = true
local tokenWindow
local authErrorBox
local hasAttemptedAuthenticator = false

-- private functions
local function onError(protocol, message, errorCode)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if errorCode == 6 then
        if hasAttemptedAuthenticator then
            if authErrorBox then
              authErrorBox:destroy()
            end
            authErrorBox = displayErrorBox(tr('Authentication Failed'), tr('The token you entered is incorrect.'))
            connect(authErrorBox, {
              onOk = function()
                authErrorBox = nil
                EnterGame.showAuthenticatorInput()
              end
            })
        else
            EnterGame.showAuthenticatorInput()
        end

        return
    end

    if not errorCode then
        EnterGame.clearAccountFields()
    end

    local errorBox = displayErrorBox(tr('Login Error'), message)
    connect(errorBox, {
        onOk = EnterGame.show
    })
end

local function onMotd(protocol, motd)
    G.motdNumber = tonumber(motd:sub(0, motd:find('\n')))
    G.motdMessage = motd:sub(motd:find('\n') + 1, #motd)
end

local function onSessionKey(protocol, sessionKey)
    G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()

    -- Try add server to the server list
    ServerList.add(G.host, G.port, g_game.getClientVersion(), httpLogin)

    -- Save 'Stay logged in' setting
    g_settings.set('staylogged', enterGame:getChildById('stayLoggedBox'):isChecked())
    g_settings.set('httpLogin', httpLogin)

    if enterGame:getChildById('rememberEmailBox'):isChecked() then
        local account = g_crypt.encrypt(G.account)
        local password = g_crypt.encrypt(G.password)

        g_settings.set('account', account)
        g_settings.set('password', password)

        ServerList.setServerAccount(G.host, G.account)
        ServerList.setServerPassword(G.host, G.password)
        ServerList.setServerAutologin(G.host, enterGame:getChildById('autoLoginBox'):isChecked())

        g_settings.set('autologin', enterGame:getChildById('autoLoginBox'):isChecked())
        ServerList.save()
    else
        -- reset server list account/password
        ServerList.setServerAccount(G.host, '')
        ServerList.setServerPassword(G.host, '')

        EnterGame.clearAccountFields()
    end

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    for _, characterInfo in pairs(characters) do
        if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
            characterInfo.worldName = characterInfo.worldName .. ', Preview'
        end
    end

    CharacterList.create(characters, account, otui)
    CharacterList.show()

    if motdEnabled then
        local lastMotdNumber = g_settings.getNumber('motd')
        if G.motdNumber and G.motdNumber ~= lastMotdNumber then
            g_settings.set('motd', G.motdNumber)
            motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
            connect(motdWindow, {
                onOk = function()
                    CharacterList.show()
                    motdWindow = nil
                end
            })
            CharacterList.hide()
        end
    end
end

local function onUpdateNeeded(protocol, signature)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if EnterGame.updateFunc then
        local continueFunc = EnterGame.show
        local cancelFunc = EnterGame.show
        EnterGame.updateFunc(signature, continueFunc, cancelFunc)
    else
        local errorBox = displayErrorBox(tr('Update needed'), tr('Your client needs updating, try redownloading it.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
    end
end

local function updateLabelText()
    if enterGame:getChildById('clientComboBox') and tonumber(enterGame:getChildById('clientComboBox'):getText()) > 1080 then
        enterGame:setText("Login")
        enterGame:getChildById('emailLabel'):setText("Email:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember Email:")
    else
        enterGame:setText("Enter Game")
        enterGame:getChildById('emailLabel'):setText("Name:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember password:")
    end
end

local function loadServerListModule()
    local module = g_modules.getModule('client_serverlist')

    if module and not module:isLoaded() then
        module:load()
    end
end

local function getProfileManager()
    return modules.client_profiles
end

local function getSelectedProfileId()
    if not profileBox then
        return ''
    end
    local option = profileBox:getCurrentOption()
    return option and tostring(option.data or '') or ''
end

local function restoreCredentialsForHost(host)
    local servers = g_settings.getNode('ServerList') or {}
    local serverData = servers[host] or {}
    if serverData.account then
        EnterGame.setAccountName(serverData.account)
        EnterGame.setPassword(serverData.password)
        enterGame:getChildById('rememberEmailBox'):setChecked(true)
    else
        EnterGame.setAccountName('')
        EnterGame.setPassword('')
        enterGame:getChildById('rememberEmailBox'):setChecked(false)
    end
    enterGame:getChildById('autoLoginBox'):setChecked(serverData.autologin == true)
end

function EnterGame.onProfileChange(comboBox, text, profileId)
    local manager = getProfileManager()
    profileId = tostring(profileId or '')
    if not manager then
        return
    end

    if profileId == '' then
        manager.setSelectedProfile('')
        manager.clearActiveProfile()
        return
    end

    local profile = manager.getProfile(profileId)
    if not profile then
        return
    end

    manager.setSelectedProfile(profileId)
    local loginHost = profile.loginUrl or profile.host
    enterGame:getChildById('serverHostTextEdit'):setText(loginHost)
    enterGame:getChildById('serverPortTextEdit'):setText(tonumber(profile.loginPort) or 7171)
    enterGame:getChildById('httpLoginBox'):setChecked(profile.loginType == 'http-json')
    clientBox:setCurrentOption(tonumber(profile.clientVersion))
    restoreCredentialsForHost(loginHost)
    updateLabelText()
end

local function populateProfileList()
    profileBox = enterGame:getChildById('profileComboBox')
    profileBox:clearOptions()

    local manager = getProfileManager()
    if not manager then
        return
    end
    local profiles = manager.getSortedProfiles()
    for _, profile in ipairs(profiles) do
        profileBox:addOption(profile.name or profile.id, profile.id)
    end

    connect(profileBox, {
        onOptionChange = EnterGame.onProfileChange
    })

    local selected = manager.getSelectedProfileId()
    if selected ~= '' and manager.getProfile(selected) then
        profileBox:setCurrentOptionByData(selected)
    elseif profiles[1] then
        profileBox:setCurrentOptionByData(profiles[1].id)
        EnterGame.onProfileChange(profileBox, profiles[1].name, profiles[1].id)
    else
        profileBox:addOption(tr('Add a server in Nexus Studio'), '')
        profileBox:setEnabled(false)
    end
end

-- public functions
function EnterGame.init()
    enterGame = g_ui.displayUI('entergame')
    local accountEdit = enterGame:getChildById('accountNameTextEdit')
    local visibilityToggle
    for _,child in ipairs(accountEdit:getChildren()) do
        if child:getClassName() == 'UICheckBox' then visibilityToggle=child break end
    end
    local revealed = g_settings.getBoolean('nexusRevealEmail')
    accountEdit:setTextHidden(not revealed)
    if visibilityToggle then
        visibilityToggle:setChecked(revealed)
        connect(visibilityToggle, {onCheckChange=function(widget)
            -- OTC checkboxes do not consistently pass the checked flag as arg 2.
            g_settings.set('nexusRevealEmail', widget:isChecked())
            g_settings.save()
        end})
    end
    Keybind.new("Misc.", "Change Character", "Ctrl+G", "")
    Keybind.bind("Misc.", "Change Character", {
      {
        type = KEY_DOWN,
        callback = EnterGame.openWindow,
      }
    })

    local host = g_settings.get('host')
    local port = g_settings.get('port')
    local stayLogged = g_settings.getBoolean('staylogged')
    local autologin = g_settings.getBoolean('autologin')
    local httpLogin = g_settings.getBoolean('httpLogin')
    local clientVersion = g_settings.getInteger('client-version')

    if not clientVersion or clientVersion == 0 then
        clientVersion = 860
    end

    if not port or port == 0 then
        port = 7171
    end

    local servers = g_settings.getNode("ServerList") or {}
    local serverData = servers[host] or {}
    if serverData and serverData.account then
        EnterGame.setAccountName(serverData.account)
        EnterGame.setPassword(serverData.password)
        enterGame:getChildById('rememberEmailBox'):setChecked(true)
    else
        EnterGame.setAccountName('')
        EnterGame.setPassword('')
        enterGame:getChildById('rememberEmailBox'):setChecked(false)
    end
    
    enterGame:getChildById('autoLoginBox'):setChecked(serverData.autologin == true)
    enterGame:getChildById('serverHostTextEdit'):setText(host)
    enterGame:getChildById('serverPortTextEdit'):setText(port)
    enterGame:getChildById('stayLoggedBox'):setChecked(stayLogged)
    enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)

    local installedClients = {}
    if modules.client_assets and modules.client_assets.getInstalledClientVersions then
        installedClients = modules.client_assets.getInstalledClientVersions()
    else
        for _, dirItem in ipairs(g_resources.listDirectoryFiles('/data/things/')) do
            if tonumber(dirItem) then
                installedClients[dirItem] = true
            end
        end
    end

    local amountInstalledClients = 0
    for _ in pairs(installedClients) do
        amountInstalledClients = amountInstalledClients + 1
    end
    local canDownloadAssets = modules.client_assets and modules.client_assets.isEnabled and modules.client_assets.isEnabled()

    clientBox = enterGame:getChildById('clientComboBox')

    for _, proto in pairs(g_game.getSupportedClients()) do
        local protoStr = tostring(proto)
        if installedClients[protoStr] or amountInstalledClients == 0 or (canDownloadAssets and proto >= 1281) then
            installedClients[protoStr] = nil
            clientBox:addOption(proto)
        end
    end

    for protoStr, status in pairs(installedClients) do
        if status then
            print(string.format('Warning: %s recognized as an installed client, but not supported.', protoStr))
        end
    end

    clientBox:setCurrentOption(clientVersion)

    connect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })

    populateProfileList()

    connect(enterGame:getChildById('rememberEmailBox'), {
        onCheckChange = function(self, checked)
            local host = enterGame:getChildById('serverHostTextEdit'):getText()
            local account = enterGame:getChildById('accountNameTextEdit'):getText()
            local password = enterGame:getChildById('accountPasswordTextEdit'):getText()

            if checked and #account > 0 then
                ServerList.setServerAccount(host, account)
                ServerList.setServerPassword(host, password)
                ServerList.setServerAutologin(host, enterGame:getChildById('autoLoginBox'):isChecked() or false)
                g_settings.set('host', host)
            else
                ServerList.setServerAccount(host, '')
                ServerList.setServerPassword(host, '')
                ServerList.setServerAutologin(host, false)
            end

            ServerList.save()
            g_configs.saveSettings()
        end
    })

    if Servers_init and next(Servers_init) ~= nil then
        local server = Servers_init[host]
        enterGame.disableToken = not (server and server.useAuthenticator)
        if table.size(Servers_init) == 1 then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setUniqueServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        elseif not host or host == "" then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setDefaultServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        end
    else
        EnterGame.toggleStayLoggedBox(clientVersion, true)
    end

    updateLabelText()

    enterGame:hide()

    connect(g_game, {
        onGameStart = EnterGame.hidePanels
    })

    connect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if g_app.isRunning() and not g_game.isOnline() then
        enterGame:show()
    end
end

function EnterGame.hidePanels()
    modules.client_topmenu.hide()
end

function EnterGame.showPanels()
end

function EnterGame.showServerList()
    loadServerListModule()

    if ServerList then
        ServerList.show()
    end
end

function EnterGame.firstShow()
    EnterGame.show()

    local host = g_settings.get('host')
    local servers = g_settings.getNode('ServerList') or {}
    local serverData = servers[host] or {}
    local account = safeDecrypt(serverData.account)
    local password = safeDecrypt(serverData.password)
    local autologin = serverData.autologin == true
    if #host > 0 and #password > 0 and #account > 0 and autologin then
        addEvent(function()
            if not g_settings.getBoolean('autologin') then
                return
            end
            EnterGame.doLogin()
        end)
    end

end

function EnterGame.terminate()
    Keybind.delete("Misc.", "Change Character")

    disconnect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })
    if profileBox then
        disconnect(profileBox, {
            onOptionChange = EnterGame.onProfileChange
        })
    end
    disconnect(g_game, {
        onGameStart = EnterGame.hidePanels
    })
    disconnect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if enterGame then
        enterGame:destroy()
        enterGame = nil
    end

    if clientBox then
        clientBox = nil
    end
    profileBox = nil

    if motdWindow then
        motdWindow:destroy()
        motdWindow = nil
    end

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if protocolLogin then
        protocolLogin:cancelLogin()
        protocolLogin = nil
    end

    EnterGame = nil
end

function EnterGame.show()
    if g_game.isOnline() or CharacterList.isVisible() then -- fix login quickly error (http post)
        return
    end

    if loadBox then
        return
    end

    enterGame:show()
    enterGame:raise()
    enterGame:focus()
    hasAttemptedAuthenticator = false
end

function EnterGame.hide()
    enterGame:hide()
end

function EnterGame.openWindow()
    if g_game.isOnline() then
        CharacterList.show()
    elseif not g_game.isLogging() and not CharacterList.isVisible() then
        EnterGame.show()
    end
end

function EnterGame.setAccountName(account)
    local decrypted = safeDecrypt(account or '')
    enterGame:getChildById('accountNameTextEdit'):setText(decrypted)
    enterGame:getChildById('accountNameTextEdit'):setCursorPos(-1)
    enterGame:getChildById('rememberEmailBox'):setChecked(#decrypted > 0)
end

function EnterGame.setPassword(password)
    enterGame:getChildById('accountPasswordTextEdit'):setText(safeDecrypt(password or ''))
end

function EnterGame.setHttpLogin(httpLogin)
    if type(httpLogin) == "boolean" then
        enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)
    else
        enterGame:getChildById('httpLoginBox'):setChecked(#httpLogin > 0)
    end
end

function EnterGame.clearAccountFields()
    enterGame:getChildById('accountNameTextEdit'):clearText()
    enterGame:getChildById('accountPasswordTextEdit'):clearText()
    enterGame:getChildById('accountNameTextEdit'):focus()
    g_settings.remove('account')
    g_settings.remove('password')
end

function EnterGame.toggleStayLoggedBox(clientVersion, init)
    local enabled = (clientVersion >= 1074)
    if enabled == enterGame.stayLoggedBoxEnabled then
        return
    end

    enterGame:getChildById('stayLoggedBox'):setOn(enabled)

    local newHeight = enterGame:getHeight()
    local newY = enterGame:getY()
    if enabled then
        newY = newY - enterGame.stayLoggedBoxHeight
        newHeight = newHeight + enterGame.stayLoggedBoxHeight
    else
        newY = newY + enterGame.stayLoggedBoxHeight
        newHeight = newHeight - enterGame.stayLoggedBoxHeight
    end

    if not init then
        enterGame:setY(newY)
        enterGame:bindRectToParent()
    end

    enterGame:setHeight(newHeight)
    enterGame.stayLoggedBoxEnabled = enabled
end

function EnterGame.onClientVersionChange(comboBox, text, data)
    local clientVersion = tonumber(text)
    EnterGame.toggleStayLoggedBox(clientVersion)
    updateLabelText()
end

local function configureModernHttpRsa(clientVersion)
    local defaultRsa = '126495449161879226050350002408283115509592174225408444125700211318409830989165415350154264672614218317455693398102112449398629738339173220923291850522536344311614352341122003744487051746122681362187472442062501840530395565823778354486784577798178348352208946270695758654206216289182676987700186634825528708389'
    local manager = getProfileManager()
    local profilePath = manager and manager.getRsaPath and manager.getRsaPath(clientVersion) or
                            string.format('/data/things/%d/rsa.txt', clientVersion)
    local activeProfile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    local configuredMode = activeProfile and tostring(activeProfile.rsaMode or ''):lower() or ''
    if not g_resources.fileExists(profilePath) then
        if configuredMode == 'otserv' then
            g_game.setRsa(OTSERV_RSA)
        elseif configuredMode == 'cipsoft' then
            g_game.setRsa(CIPSOFT_RSA)
        else
            g_game.setRsa(defaultRsa)
            configuredMode = configuredMode ~= '' and configuredMode or 'modern'
        end
        g_logger.info(string.format('[Game Login] RSA mode=%s (profile)', configuredMode))
        return
    end

    local profile = g_resources.readFileContents(profilePath):gsub('^%s+', ''):gsub('%s+$', ''):lower()
    if profile == 'otserv' then
        g_game.setRsa(OTSERV_RSA)
    elseif profile == 'cipsoft' then
        g_game.setRsa(CIPSOFT_RSA)
    elseif profile == 'modern' then
        g_game.setRsa(defaultRsa)
    elseif profile:match('^%d+$') then
        g_game.setRsa(profile)
        profile = 'custom'
    else
        g_logger.warning(string.format('Unknown RSA profile in %s; using the default modern key.', profilePath))
        g_game.setRsa(defaultRsa)
        profile = 'modern'
    end
    g_logger.info(string.format('[Game Login] RSA mode=%s path=%s', profile, profilePath))
end

function EnterGame.tryHttpLogin(clientVersion, httpLogin)
    g_game.setClientVersion(clientVersion)

    local manager = getProfileManager()
    local serverProfile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    if not serverProfile then
        local servers = ServerList and ServerList.getServers and ServerList.getServers() or
                            g_settings.getNode('ServerList') or {}
        serverProfile = servers[G.host]
    end
    local gameProtocol = type(serverProfile) == 'table' and tonumber(serverProfile.gameProtocol) or nil
    local gameVersionString = type(serverProfile) == 'table' and serverProfile.gameVersionString or nil
    local loginPreviewState = type(serverProfile) == 'table' and tonumber(serverProfile.loginPreviewState) or 0

    g_game.setProtocolVersion(gameProtocol or g_game.getClientProtocolVersion(clientVersion))
    g_game.setLoginPreviewState(loginPreviewState or 0)
    if type(gameVersionString) == 'string' and gameVersionString ~= '' then
        g_game.setClientVersionString(gameVersionString)
    end

    if gameProtocol or gameVersionString or loginPreviewState ~= 0 then
        g_logger.info(string.format(
            '[Server Profile] Game handshake protocol=%d version=%s preview=%d',
            g_game.getProtocolVersion(),
            g_game.getClientVersionString(),
            g_game.getLoginPreviewState()))
    end

    if clientVersion >= 1281 and httpLogin then
        configureModernHttpRsa(clientVersion)
        if clientVersion >= 1500 and g_app.getOs() == 'windows' then
            g_game.setCustomOs(OsTypes.NewWindows)
        elseif g_app.getOs() == 'windows' then
            g_game.setCustomOs(OsTypes.Windows)
        else
            g_game.setCustomOs(OsTypes.Linux)
        end
    else
        g_game.chooseRsa(G.host)
    end

    if not modules.game_things.isLoaded() then
        if loadBox then
            loadBox:destroy()
            loadBox = nil
        end

        local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put assets in things/%d/<assets>.", clientVersion))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    -- Show connecting message immediately
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))
    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            G.requestId = 0
            EnterGame.show()
        end
    })

    local originalHost = G.host
    local host, path = originalHost, "/"
    local scheme = originalHost:match("^(https?)://")
    if G.host:find("https?://") then
        local url = G.host:gsub("https?://", "")
        host, path = url:match("([^/]+)(/.*)")
        if not host then
            host = url
            path = "/"
        elseif not path or path == "" then
            path = "/"
        end
        local hostPort = host:match(":(%d+)$")
        if hostPort then
            host = host:gsub(":%d+$", "")
            G.port = tonumber(hostPort)
        end
    end

    if not G.port then
        if G.host:find("https") then
            G.port = 443
        else
            G.port = 80
        end
    end

    math.randomseed(os.time())
    G.requestId = math.random(1, 1000000000)

    if httpLogin then
        local url = string.format("%s://%s%s", scheme or (G.port == 443 and "https" or "http"), host, path)
        local oldTimeout = HTTP.timeout
        HTTP.timeout = 15

        HTTP.postJSON(url, {
            type = "login",
            email = G.account,
            password = G.password,
            token = G.authenticatorToken or "",
            rememberEmail = true
        }, function(data, err)
            HTTP.timeout = oldTimeout

            if err then
                EnterGame.loginFailed(G.requestId, err, nil)
                return
            end

            if type(data) ~= "table" then
                EnterGame.loginFailed(G.requestId, "Invalid login response.", nil)
                return
            end

            local errorMessage = data.error or data.errorMessage
            if type(errorMessage) == "table" then
                errorMessage = errorMessage.message or errorMessage.description
            end
            if not errorMessage and data.success == false then
                errorMessage = data.message or "Login failed."
            end
            if not errorMessage and not data.playdata and not data.playData and data.message then
                errorMessage = data.message
            end
            if errorMessage then
                EnterGame.loginFailed(G.requestId, tostring(errorMessage), data.errorCode)
                return
            end

            local playdata = data.playdata or data.playData or data
            EnterGame.loginSuccess(
                G.requestId,
                json.encode(data.session or playdata.session or {}),
                json.encode(playdata.worlds or data.worlds or {}),
                json.encode(playdata.characters or data.characters or {})
            )
        end)
        return
    end

    local http = LoginHttp.create()
    http:httpLogin(host, path, G.port, G.account, G.password, G.requestId, false, G.authenticatorToken)
end

function printTable(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(string.format("%q: {", k))
            printTable(v)
            print("}")
        else
            print(string.format("%q:", k) .. tostring(v) .. ",")
        end
    end
end

function EnterGame.loginSuccess(requestId, jsonSession, jsonWorlds, jsonCharacters)
    if G.requestId ~= requestId then
        return
    end

    -- Update the existing loadBox message or create new one if it doesn't exist
    if loadBox then
        loadBox:destroy()
    end
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))

    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            G.requestId = 0
            EnterGame.show()
        end
    })

    if tokenWindow then
        tokenWindow:destroy()
        tokenWindow = nil
    end

    local function decodeOrEmpty(value)
        if type(value) == "table" then
            return value
        end
        local ok, decoded = pcall(json.decode, value or "[]")
        if ok and type(decoded) == "table" then
            return decoded
        end
        return {}
    end

    local function numberOr(value, fallback)
        local number = tonumber(value)
        return number ~= nil and number or fallback
    end

    local function boolOrFalse(value)
        return value == true or value == 1 or value == "1"
    end

    local fallbackHost = tostring(G.host or ""):gsub("^https?://", ""):match("^([^/:]+)") or ""
    local fallbackWorld = {
        name = fallbackHost,
        ip = fallbackHost,
        port = 7172,
        previewState = false,
        pvptype = 0
    }

    local manager = getProfileManager()
    local serverProfile = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    if not serverProfile then
        local servers = ServerList and ServerList.getServers and ServerList.getServers() or
                            g_settings.getNode('ServerList') or {}
        serverProfile = servers[G.host]
    end
    local profileGameHost = type(serverProfile) == 'table' and serverProfile.gameHost or nil
    local profileGamePort = type(serverProfile) == 'table' and tonumber(serverProfile.gamePort) or nil
    if type(serverProfile) == 'table' and serverProfile.gameHostPolicy ~= 'profile-override' then
        profileGameHost = nil
        profileGamePort = nil
    end

    local worlds = {}
    local worldCount = 0
    for index, world in ipairs(decodeOrEmpty(jsonWorlds)) do
        local worldId = tostring(world.id or world.worldid or world.worldId or index)
        worlds[worldId] = {
            name = world.name or world.worldname or world.worldName or fallbackWorld.name,
            ip = profileGameHost or world.externaladdressprotected or world.externaladdressunprotected or
                world.address or world.ip or world.host or world.worldHost or fallbackWorld.ip,
            port = profileGamePort or numberOr(world.externalportprotected or world.externalportunprotected or
                world.port or world.worldPort, fallbackWorld.port),
            previewState = numberOr(world.previewstate or world.previewState, 0) == 1,
            pvptype = numberOr(world.pvptype or world.pvpType, 0)
        }
        worldCount = worldCount + 1
    end

    if profileGameHost then
        g_logger.info(string.format(
            "[Server Profile] Overriding game transport with %s:%d",
            tostring(profileGameHost),
            profileGamePort or fallbackWorld.port))
    end

    local characters = {}
    for index, character in ipairs(decodeOrEmpty(jsonCharacters)) do
        local worldId = tostring(character.worldid or character.worldId or character.world or "")
        local world = worlds[worldId] or fallbackWorld
        characters[index] = {
            name = character.name or character.charactername or character.characterName or "",
            level = numberOr(character.level, 1),
            main = boolOrFalse(character.ismaincharacter or character.isMainCharacter),
            dailyreward = numberOr(character.dailyrewardstate or character.dailyRewardState, 0),
            hidden = boolOrFalse(character.ishidden or character.isHidden),
            vocation = character.vocation or "",
            outfitid = numberOr(character.outfitid or character.looktype or character.outfitId, 0),
            headcolor = numberOr(character.headcolor or character.lookhead or character.headColor, 0),
            torsocolor = numberOr(character.torsocolor or character.lookbody or character.torsoColor, 0),
            legscolor = numberOr(character.legscolor or character.looklegs or character.legsColor, 0),
            detailcolor = numberOr(character.detailcolor or character.lookfeet or character.detailColor, 0),
            addonsflags = numberOr(character.addonsflags or character.lookaddons or character.addonsFlags, 0),
            worldName = world.name,
            worldIp = world.ip,
            worldPort = world.port,
            previewState = world.previewState,
            pvptype = world.pvptype
        }
    end

    if #characters == 0 then
        if loadBox then
            loadBox:destroy()
            loadBox = nil
        end
        EnterGame.show()
        displayErrorBox(tr("Login Error"), tr("No characters were returned by the login server."))
        return
    end

    local session = decodeOrEmpty(jsonSession)
    local premiumUntil = numberOr(session.premiumuntil or session.premiumUntil, os.time())

    local account = {
        status = '',
        premDays = math.floor((premiumUntil - os.time()) / 86400),
        subStatus = premiumUntil > os.time() and SubscriptionStatus.Premium or SubscriptionStatus.Free
    }

    -- set session key
    G.sessionKey = session.sessionkey or session.sessionKey or session.session or session.key or ""

    g_logger.info(string.format("[HTTP Login] Received %d character(s) across %d world(s)", #characters, worldCount))

    onCharacterList(nil, characters, account)
end

function EnterGame.loginFailed(requestId, msg, result)
    if G.requestId ~= requestId then
        return
    end
    onError(nil, msg, result)
end

function EnterGame.doLogin()
    G.stayLogged = enterGame:getChildById('stayLoggedBox'):isChecked()
    G.host = enterGame:getChildById('serverHostTextEdit'):getText()
    G.port = tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
    local clientVersion = tonumber(clientBox:getText())
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()
    local loginType
    local manager = getProfileManager()
    local selectedProfileId = getSelectedProfileId()
    local activeProfile

    if selectedProfileId ~= '' and manager then
        local applied, profileErrors, profileWarnings = manager.applyProfile(selectedProfileId)
        if not applied then
            local errorBox = displayErrorBox(tr('Profile Error'), table.concat(profileErrors or {}, '\n'))
            connect(errorBox, { onOk = EnterGame.show })
            return
        end
        for _, warning in ipairs(profileWarnings or {}) do
            g_logger.warning('[ProfileManager] ' .. tostring(warning))
        end
        activeProfile = manager.getActiveProfile()
        G.host = activeProfile.loginUrl or activeProfile.host
        G.port = tonumber(activeProfile.loginPort)
        clientVersion = tonumber(activeProfile.clientVersion)
        loginType = activeProfile.loginType
        httpLogin = loginType == 'http-json'
        enterGame:getChildById('serverHostTextEdit'):setText(G.host)
        enterGame:getChildById('serverPortTextEdit'):setText(G.port)
        enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)
        clientBox:setCurrentOption(clientVersion)
    end

    local servers = ServerList and ServerList.getServers and ServerList.getServers() or
                        g_settings.getNode('ServerList') or {}
    local serverProfile = activeProfile or servers[G.host]
    if not activeProfile and type(serverProfile) == 'table' then
        local profileVersion = tonumber(serverProfile.protocol)
        local profilePort = tonumber(serverProfile.port)

        if profileVersion then
            clientVersion = profileVersion
            clientBox:setCurrentOption(clientVersion)
        end
        if profilePort then
            G.port = profilePort
            enterGame:getChildById('serverPortTextEdit'):setText(profilePort)
        end
        if serverProfile.httpLogin ~= nil then
            httpLogin = serverProfile.httpLogin == true or serverProfile.httpLogin == 'true'
            enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)
        end
        if serverProfile.account then
            EnterGame.setAccountName(serverProfile.account)
        end
        if serverProfile.password then
            EnterGame.setPassword(serverProfile.password)
        end

        g_logger.info(string.format(
            '[Server Profile] Restored host=%s version=%d port=%d http=%s',
            G.host,
            clientVersion or 0,
            G.port or 0,
            tostring(httpLogin)))
    end

    G.account = enterGame:getChildById('accountNameTextEdit'):getText()
    G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
    G.clientVersion = clientVersion

    if g_game.isOnline() then
        local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    g_settings.set('host', G.host)
    g_settings.set('port', G.port)
    g_settings.set('client-version', clientVersion)
    g_settings.set('httpLogin', httpLogin)
    g_settings.save()

    if not activeProfile and clientVersion >= 1281 and modules.client_assets and modules.client_assets.ensureClientVersion and
        (not modules.client_assets.isEnabled or modules.client_assets.isEnabled()) and
        not modules.client_assets.isClientVersionInstalled(clientVersion) then
        modules.client_assets.ensureClientVersion(clientVersion, function(success, message)
            if success then
                EnterGame.doLogin()
                return
            end

            local errorBox = displayErrorBox(tr('Login Error'), message or tr('Unable to download client assets.'))
            connect(errorBox, {
                onOk = EnterGame.show
            })
        end)
        return
    end

    EnterGame.hide()

    if activeProfile and loginType ~= 'classic' then
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    elseif not activeProfile and clientVersion >= 1281 and G.port ~= 7171 then
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    else
        protocolLogin = ProtocolLogin.create()
        protocolLogin.onLoginError = onError
        protocolLogin.onMotd = onMotd
        protocolLogin.onSessionKey = onSessionKey
        protocolLogin.onCharacterList = onCharacterList
        protocolLogin.onUpdateNeeded = onUpdateNeeded

        loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))

        connect(loadBox, {
            onCancel = function(msgbox)
                loadBox = nil
                protocolLogin:cancelLogin()
                EnterGame.show()
            end
        })

        if not activeProfile then
            g_game.setClientVersion(clientVersion)
            g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
        end
        g_game.chooseRsa(G.host)

        if modules.game_things.isLoaded() then
            protocolLogin:login(G.host, G.port, G.account, G.password, G.authenticatorToken, G.stayLogged)
        else
            if loadBox then
                loadBox:destroy()
                loadBox = nil
            end

            local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put spr and dat in things/%d/<here>.", clientVersion))
            connect(errorBox, {
               onOk = EnterGame.show
            })
            return
        end
    end
end

function EnterGame.displayMotd()
    if not motdWindow then
        motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
        motdWindow.onOk = function()
            motdWindow = nil
        end
    end
end

function EnterGame.setDefaultServer(host, port, protocol)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    local clientLabel = enterGame:getChildById('clientLabel')
    local accountTextEdit = enterGame:getChildById('accountNameTextEdit')
    local passwordTextEdit = enterGame:getChildById('accountPasswordTextEdit')

    if hostTextEdit:getText() ~= host then
        hostTextEdit:setText(host)
        portTextEdit:setText(port)
        clientBox:setCurrentOption(protocol)
        accountTextEdit:setText('')
        passwordTextEdit:setText('')
    end
end

function EnterGame.setUniqueServer(host, port, protocol, windowWidth, windowHeight)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    hostTextEdit:setText(host)
    hostTextEdit:setVisible(false)
    hostTextEdit:setHeight(0)

    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    portTextEdit:setText(port)
    portTextEdit:setVisible(false)
    portTextEdit:setHeight(0)

    local stayLoggedBox = enterGame:getChildById('stayLoggedBox')
    stayLoggedBox:setChecked(false)
    stayLoggedBox:setOn(false)

    local clientVersion = tonumber(protocol)
    clientBox:setCurrentOption(clientVersion)
    clientBox:setVisible(false)
    clientBox:setHeight(0)

    local serverLabel = enterGame:getChildById('serverLabel')
    serverLabel:setVisible(false)
    serverLabel:setHeight(0)

    local portLabel = enterGame:getChildById('portLabel')
    portLabel:setVisible(false)
    portLabel:setHeight(0)

    local clientLabel = enterGame:getChildById('clientLabel')
    clientLabel:setVisible(false)
    clientLabel:setHeight(0)

    local httpLoginBox = enterGame:getChildById('httpLoginBox')
    httpLoginBox:setVisible(false)
    httpLoginBox:setHeight(0)

    local rememberEmailBox = enterGame:getChildById('rememberEmailBox')
    rememberEmailBox:setMarginTop(5)

    if not windowWidth then
        windowWidth = 380
    end
    enterGame:setWidth(windowWidth)
    if not windowHeight then
        windowHeight = 229
    end

    enterGame:setHeight(windowHeight)
    enterGame.disableToken = true
    local server = Servers_init[host]
    enterGame.disableToken = not (server and server.useAuthenticator)

    g_game.setClientVersion(clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
end

function EnterGame.setServerInfo(message)
    local label = enterGame:getChildById('serverInfoLabel')
    label:setText(message)
end

function EnterGame.disableMotd()
    motdEnabled = false
end

function EnterGame.showAuthenticatorInput()
    if tokenWindow then
        tokenWindow:destroy()
        tokenWindow = nil
    end
    
    -- Create a custom message box with embedded text edit
    tokenWindow = g_ui.createWidget('MessageBoxWindow', rootWidget)
    tokenWindow.title = tokenWindow:getChildById('title')
    tokenWindow.title:setText(tr('Two-Factor Authentication'))
    
    tokenWindow.content = tokenWindow:getChildById('content')
    tokenWindow.content:setText(tr('Please enter a new, valid token:'))
    tokenWindow.content:setColor('#c0c0c0')
    tokenWindow.content:resizeToText()
    -- Align content to the left instead of center
    tokenWindow.content:breakAnchors()
    tokenWindow.content:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    tokenWindow.content:addAnchor(AnchorTop, 'parent', AnchorTop)
    tokenWindow.content:setMarginLeft(15)
    tokenWindow.content:setMarginTop(32)
    
    -- Add text edit field for token input
    local tokenEdit = g_ui.createWidget('TextEdit', tokenWindow)
    tokenEdit:setId('tokenEdit')
    tokenEdit:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    tokenEdit:addAnchor(AnchorTop, 'content', AnchorBottom)
    tokenEdit:setMarginTop(10)
    tokenEdit:setMaxLength(8)
    tokenEdit:setWidth(320)
    tokenEdit:setHeight(16)
    tokenEdit:setMarginLeft(15)
    tokenEdit:setMarginRight(15)
    tokenEdit:focus()
    
    -- Add horizontal separator
    local separator = g_ui.createWidget('HorizontalSeparator', tokenWindow)
    separator:setId('customSeparator')
    separator:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    separator:addAnchor(AnchorRight, 'parent', AnchorRight)
    separator:addAnchor(AnchorTop, 'tokenEdit', AnchorBottom)
    separator:setMarginTop(10)
    separator:setMarginLeft(15)
    separator:setMarginRight(15)
    
    -- Reposition the holder to be below our custom separator
    tokenWindow.holder = tokenWindow:getChildById('holder')
    tokenWindow.holder:breakAnchors()
    tokenWindow.holder:addAnchor(AnchorRight, 'customSeparator', AnchorRight)
    tokenWindow.holder:addAnchor(AnchorLeft, 'customSeparator', AnchorLeft)
    tokenWindow.holder:addAnchor(AnchorTop, 'customSeparator', AnchorBottom)
    tokenWindow.holder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    tokenWindow.holder:setMarginTop(12)
    
    local okCallback = function()
        local token = tokenEdit:getText()
        if not token or token:len() == 0 then
            if authErrorBox then
              authErrorBox:destroy()
            end
            authErrorBox = displayErrorBox(tr('Error'), tr('Token is required.'))
            connect(authErrorBox, {
              onOk = function()
                authErrorBox = nil
                if tokenWindow then
                    tokenWindow:raise()
                    tokenWindow:focus()
                    tokenEdit:focus()
                end
              end
            })
            return
        end
        
        hasAttemptedAuthenticator = true
        
        G.account = enterGame:getChildById('accountNameTextEdit'):getText()
        G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
        G.host = enterGame:getChildById('serverHostTextEdit'):getText()
        G.port = tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
        G.authenticatorToken = token
        local clientVersion = tonumber(clientBox:getText())
        local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()
        
        if tokenWindow then
            tokenWindow:destroy()
            tokenWindow = nil
        end
        
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    end
    
    local cancelCallback = function()
        hasAttemptedAuthenticator = false
        G.authenticatorToken = nil
        if tokenWindow then
            tokenWindow:destroy()
            tokenWindow = nil
        end
        EnterGame.show()
    end
        
    -- Add Cancel button (to the left of OK button)
    local cancelButton = tokenWindow:addButton(tr('Cancel'), cancelCallback)
    cancelButton:breakAnchors()
    cancelButton:addAnchor(AnchorTop, 'parent', AnchorTop)
    cancelButton:addAnchor(AnchorRight, 'parent', AnchorRight)
    cancelButton:setWidth(45)

    -- Add OK button (right side, added first)
    local okButton = tokenWindow:addButton(tr('Ok'), okCallback)
    okButton:breakAnchors()
    okButton:addAnchor(AnchorTop, 'prev', AnchorTop)
    okButton:addAnchor(AnchorRight, 'prev', AnchorLeft)
    okButton:setMarginRight(10)
    okButton:setWidth(40)
    
    -- Calculate window size based on content
    local windowWidth = 350
    local windowHeight = 28 + tokenWindow.content:getHeight() + 10 + tokenEdit:getHeight() + 10 + 2 + 12 + okButton:getHeight() + 12
    
    tokenWindow:setWidth(windowWidth)
    tokenWindow:setHeight(windowHeight)
    
    -- Connect Enter and Escape keys
    connect(tokenWindow, {
        onEnter = okCallback,
        onEscape = cancelCallback
    })
    
    -- Connect text edit Enter key
    connect(tokenEdit, {
        onEnter = okCallback
    })
end

function EnterGame.doLoginWithToken()
    local manager = getProfileManager()
    local serverData = manager and manager.getActiveProfile and manager.getActiveProfile() or nil
    if not serverData then
        local servers = Servers_init or {}
        serverData = servers[G.host]
    end
    if not (serverData and serverData.useAuthenticator) then
        print('Authenticator token is disabled for this server.')
        return
    end
    
    EnterGame.showAuthenticatorInput()
end

function EnterGame.destroyToken()
    if tokenWindow then
      if tokenWindow.destroy then
        tokenWindow:destroy()
      end
      tokenWindow = nil
      hasAttemptedAuthenticator = false
      G.authenticatorToken = nil
    end
end

function ensableBtnCreateNewAccount()
    enterGame.btnCreateNewAccount:enable()
end
