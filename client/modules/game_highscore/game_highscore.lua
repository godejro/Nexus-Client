local highscoreButton = nil
local worldTypeRadioGroup = nil
local currentPage = 0
local countPages = 0
local updatingFilters = false
local requestPending = false
local requestTimeout
local function finishRequest()
    requestPending=false
    if requestTimeout then removeEvent(requestTimeout) requestTimeout=nil end
    if highscoreController and highscoreController.ui then highscoreController.ui.filters:setEnabled(true) end
end

local vocationArray = {}
local Category = {}

local tempFixworldType = {
    {0, "Open Pvp"},
    {1, "Optional Pvp"},
    {2, "Hardcore Pvp"},
    {3, "Retro Open Pvp"},
    {4, "Retro Hardcore Pvp"}
}

local serverSide = {
    action = 0,
    category = 0,
    vocation = 0xFFFFFFFF,
    world = "",
    worldType = 1,
    battlEye = 1,
    page = 1,
    totalInPages = 20
}

local function getMinutesDifference(t1, t2)
    local diffInSeconds = os.difftime(t2, t1)
    local diffInMinutes = diffInSeconds / 60
    local diffInHours = diffInMinutes / 60

    if diffInHours >= 1 then
        return string.format("Last Update: %.0f Hrs Ago", diffInHours)
    elseif diffInMinutes >= 1 then
        return string.format("Last Update: %.0f minutes Ago", diffInMinutes)
    else
        return string.format("Last Update: %.0f Second Ago", math.abs(diffInSeconds))
    end
end

local function getCategory(arg)
    if type(arg) == "string" then
        for i, cat in ipairs(Category) do
            if cat[2] == arg then
                return cat[1]
            end
        end
    end
    return 0
end

local function getVocation(arg)
    if type(arg) == "number" then
        return vocationNamesByClientId[arg] or "All Vocations"
    elseif type(arg) == "string" then
        -- First, search in vocationArray which comes from server
        for _, voc in ipairs(vocationArray) do
            if voc[2] == arg then
                return voc[1]
            end
        end
        -- If not found in vocationArray, search in vocationNamesByClientId
        for id, name in pairs(vocationNamesByClientId) do
            if name == arg then
                return id
            end
        end
    end
    return "All Vocations"
end

highscoreController = Controller:new()
highscoreController:setUI('game_highscore')

function highscoreController:onInit()
    highscoreController.ui:hide()
    highscoreController:registerEvents(g_game, {
        onProcessHighscores = onProcessHighscores,
        onHighscoresEmpty = onHighscoresEmpty
    })
end

local function refillComboBox(comboBox, values, leadingLabel)
    local current = comboBox:getCurrentOption()
    local selectedText = current and current.text or nil
    comboBox:clearOptions()
    if leadingLabel then
        comboBox:addOption(leadingLabel)
    end
    for _, value in ipairs(values) do
        comboBox:addOption(tostring(value[2]))
    end
    if selectedText and comboBox:isOption(selectedText) then
        comboBox:setCurrentOption(selectedText, true)
    end
end

function onHighscoresEmpty()
    finishRequest()
    local ui = highscoreController.ui
    currentPage = 0
    countPages = 0
    updatingFilters = false
    ui.data:destroyChildren()
    ui.page:setText('0 / 0')
    ui.last_update:setText(tr('No highscores available.'))
    disableButtons()
end

function highscoreController:onTerminate()
    finishRequest()
    if highscoreButton then
        highscoreButton:destroy()
        highscoreButton = nil
    end

    if worldTypeRadioGroup then
        worldTypeRadioGroup:destroy()
        worldTypeRadioGroup = nil
    end
end

function onProcessHighscores(serverName, world, worldType, battlEye, vocations, categories, page, totalInPages,
    highscores, entriesTs)
    if not g_game.getLocalPlayer() then return end
    finishRequest()
    updatingFilters = true
    vocationArray = table.copy(vocations)
    Category = table.copy(categories)
    currentPage = page
    serverSide.page = page
    countPages = math.max(1, totalInPages)
    serverSide.world = world
    serverSide.worldType = worldType
    serverSide.battlEye = battlEye
    local ui = highscoreController.ui
    local uiFilters = ui.filters

    if not uiFilters.PanelWorld.isFilled then
        worldTypeRadioGroup = UIRadioGroup.create()
        for _, temp in ipairs(tempFixworldType) do
            local label = g_ui.createWidget("WorldType", uiFilters.PanelWorld)
            label.text:setText(temp[2])
            label.enabled.worldType = temp[1]
            worldTypeRadioGroup:addWidget(label.enabled)
        end
        worldTypeRadioGroup.onSelectionChange = function(_, selected)
            if selected then
                serverSide.worldType = selected.worldType
            end
        end
        uiFilters.PanelWorld.isFilled = true
    end

    for _, widget in ipairs(worldTypeRadioGroup.widgets) do
        if widget.worldType == worldType then
            worldTypeRadioGroup:selectWidget(widget, true)
            break
        end
    end

    local filterData = {
        {box = uiFilters.vocationBox, data = vocations, label = "All Vocations"},
        {box = uiFilters.categoryBox, data = categories, label = nil},
    }

    for _, filter in ipairs(filterData) do
        refillComboBox(filter.box, filter.data, filter.label)
    end

    -- The server may enumerate categories in a different order than their IDs.
    -- The first option is not necessarily category 0 (Experience).
    -- Display the applied request, not whichever option clearOptions selected.
    for _,category in ipairs(categories) do
        if category[1]==serverSide.category then uiFilters.categoryBox:setCurrentOption(category[2],true) break end
    end
    if serverSide.vocation==0xFFFFFFFF then
        uiFilters.vocationBox:setCurrentOption('All Vocations',true)
    else
        for _,vocation in ipairs(vocations) do
            if vocation[1]==serverSide.vocation then uiFilters.vocationBox:setCurrentOption(vocation[2],true) break end
        end
    end

    uiFilters.gameWorldBox:clearOptions()
    uiFilters.gameWorldBox:addOption(world ~= "" and world or serverName)
    updatingFilters = false

    local isFirstPage = currentPage == 1
    local isLastPage = currentPage >= countPages

    ui.next:setEnabled(not isLastPage)
    ui.nextLast:setEnabled(not isLastPage)
    ui.prev:setEnabled(not isFirstPage)
    ui.prevLast:setEnabled(not isFirstPage)
    ui.ownRankButton:setEnabled(true)
    ui.page:setText(currentPage .. " / " .. countPages)

    local diferenciaEnMinutos = getMinutesDifference(entriesTs, os.time())
    ui.last_update:setText(diferenciaEnMinutos)

    createHighscores(highscores)
end

function highscoreController:onGameStart()
    if g_game.getClientVersion() < 1310 then
        return
    end

    highscoreButton = modules.client_topmenu.addRightGameToggleButton('highscore', tr('Highscores'),
        '/images/options/highscores', toggle, false)
    highscoreButton:setOn(false)
end

function highscoreController:onGameEnd()
    onHighscoresEmpty()
    if highscoreController.ui:isVisible() then
        highscoreController.ui:hide()
    end
end

function hide()
    if not highscoreController.ui then
        return
    end
    highscoreController.ui:hide()
    if highscoreButton then
        highscoreButton:setOn(false)
    end
end

function show()
    if not highscoreController.ui or not highscoreButton then
        return
    end

    highscoreController.ui:show()
    highscoreController.ui:raise()
    highscoreController.ui:focus()
    if highscoreButton then
        highscoreButton:setOn(true)
    end
    requestInfo()
end

function toggle()
    if not highscoreController.ui then
        return
    end

    if highscoreController.ui:isVisible() then
        return hide()
    end

    show()
end

function createHighscores(list)
    local data = highscoreController.ui.data
    data:getLayout():disableUpdates()
    data:destroyChildren()

    local player = g_game.getLocalPlayer()
    local playerName = player and player:getName():lower() or ''
    local sorted = {}
    local seen = {}

    for _, entry in ipairs(list) do
        local key = tostring(entry[1]) .. '\0' .. tostring(entry[2]):lower()
        if not seen[key] then
            seen[key] = true
            table.insert(sorted, entry)
        end
    end

    table.sort(sorted, function(a, b)
        local rankA, rankB = tonumber(a[1]) or math.huge, tonumber(b[1]) or math.huge
        if rankA ~= rankB then
            return rankA < rankB
        end
        local pointsA, pointsB = tonumber(a[8]) or 0, tonumber(b[8]) or 0
        if pointsA ~= pointsB then
            return pointsA > pointsB
        end
        return tostring(a[2]):lower() < tostring(b[2]):lower()
    end)

    for index, entry in ipairs(sorted) do
        local row = g_ui.createWidget("HighScoreData", data)
        row:setBackgroundColor(index % 2 == 0 and "#ffffff12" or "#00000012")
        row.rank:setText(entry[1] .. ".")
        row.name:setText(entry[2])
        row.voc:setText(entry[4] == 0 and "None" or getVocation(entry[4]))
        row.world:setText(entry[5])
        row.level:setText(entry[6])
        row.points:setText(comma_value(entry[8]))
        if playerName == entry[2]:lower() then
            for _, widget in pairs({"rank", "name", "voc", "world", "level", "points"}) do
                row[widget]:setColor("#60f860")
            end
        end
    end

    data:getLayout():enableUpdates()
    data:getLayout():update()
end

local function changePage(newPage)
    if requestPending or updatingFilters or countPages <= 0 then
        return
    end
    newPage = math.max(1, math.min(countPages, newPage))
    if newPage == currentPage then
        return
    end
    disableButtons()
    highscoreController.ui.data:destroyChildren()
    highscoreRequest(newPage, 0)
end

function nextPage() changePage(currentPage + 1) end
function nextEndPage() changePage(countPages) end
function prevPage() changePage(currentPage - 1) end
function prevEndPage() changePage(1) end

function disableButtons()
    for _, btn in ipairs({"next", "nextLast", "prev", "prevLast", "ownRankButton"}) do
        highscoreController.ui[btn]:setEnabled(false)
    end
end

function submit()
    if requestPending or updatingFilters then
        return
    end
    disableButtons()
    highscoreController.ui.data:destroyChildren()
    highscoreRequest(1, 0, true)
end

function showOwnRank()
    if requestPending or updatingFilters then
        return
    end
    disableButtons()
    highscoreController.ui.data:destroyChildren()
    highscoreRequest(1, 1, true)
end

function highscoreRequest(currentPage, typex, applyFilters)
    if requestPending or not g_game.getLocalPlayer() then return end
    local id,categoryId=serverSide.vocation,serverSide.category
    if applyFilters then
    local vocationOption = highscoreController.ui.filters.vocationBox:getCurrentOption()
    local categoryOption = highscoreController.ui.filters.categoryBox:getCurrentOption()
    id = getVocation(vocationOption and vocationOption.text or 'All Vocations')
    id = (id == "All Vocations" and 0xFFFFFFFF or id)

    categoryId = getCategory(categoryOption and categoryOption.text or '')
    end
    serverSide.category=categoryId serverSide.vocation=id serverSide.page=currentPage
    requestPending=true
    highscoreController.ui.filters:setEnabled(false)
    requestTimeout=scheduleEvent(function()
        finishRequest()
        highscoreController.ui.last_update:setText('No response. Use Submit to retry.')
    end,10000)
    g_game.requestHighscore(typex, categoryId, id, serverSide.world, serverSide.worldType, serverSide.battlEye,
        currentPage, serverSide.totalInPages)
end

function requestInfo()
    if requestPending then return end
    disableButtons()
    highscoreRequest(math.max(1,serverSide.page),0)
end
