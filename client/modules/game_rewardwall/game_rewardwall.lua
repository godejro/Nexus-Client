rewardWallController = Controller:new()
-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - otui -> html/css (g_ui.displayUI)
-- - Improve Ids footerGold2 , footerGold1, "test", "displayGeneralBox3"

local ServerPackets = {
    ShowDialog = 0xED,
    DailyRewardCollectionState = 0xDE,
    OpenRewardWall = 0xE2,
    CloseRewardWall = 0xE3,
    DailyRewardBasic = 0xE4,
    DailyRewardHistory = 0xE5
    -- RestingAreaState = 0xA9
}

local ClientPackets = {
    OpenRewardWall = 0xD8,
    OpenRewardHistory = 0xD9,
    SelectReward = 0xDA,
    CollectionResource = 0x14,
    JokerResource = 0x15
}

-- @ widget
local ButtonRewardWall = nil
local windowsPickWindow = nil
local generalBox = nil
-- @ array
local bonuses = {}
local actualUsed = {}
local requiredRewardItems = 0
-- @ variable
local bonusShrine = 0
local rewardUnavailable = false
local awaitingWall = true
local serverErrorConnected = false
local claimPending = false
local claimTimeout
local getRewardRequestSource
local function resetClaim()
    claimPending=false
    if claimTimeout then removeEvent(claimTimeout) claimTimeout=nil end
end
local function submitClaim()
    if claimPending or awaitingWall or rewardUnavailable or not g_game.getLocalPlayer() then return false end
    claimPending=true
    rewardWallController.ui:show()
    rewardWallController.ui.restingAreaPanel.streakWarning:setText('Waiting for the server...')
    claimTimeout=scheduleEvent(function()
        claimTimeout=nil
        -- Never repeat a claim automatically: a delayed response may have already granted it.
        rewardWallController.ui.restingAreaPanel.streakWarning:setText('No confirmation received. Reopen the Reward Wall to refresh its state.')
    end,10000)
    g_game.requestGetRewardDaily(getRewardRequestSource(), actualUsed)
    return true
end
-- @ const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141"
}
local ZONE = {
    LAST_ZONE = -99,
    RESTING_AREA_ZONE = 1,
    ICON_ID = "condition_Rewards",
    NUMERIC_ICON_ID = 30
}

local bundleType = {
    ITEMS = 1,
    PREY = 2,
    XPBOOST = 3
}

local STATUS = {
    COLLECTED = 1,
    ACTIVE = 2,
    LOCKED = 3
}

local OPEN_WINDOWS = {
    BUTTON_WIDGET = 0,
    SHRINE = 1 -- itemClientId = 25802
}

getRewardRequestSource = function()
    -- The server request uses 0 for a shrine and 1 for the Reward Wall panel.
    return bonusShrine == OPEN_WINDOWS.SHRINE and 0 or 1
end

local DailyRewardStatus = { -- sendDailyRewardCollectionState 0xDE ?
    DAILY_REWARD_COLLECTED = 0,
    DAILY_REWARD_NOTCOLLECTED = 1,
    DAILY_REWARD_NOTAVAILABLE = 2
}

local CONST_WINDOWS_BOX = {
    ALREADY = 1,
    RELEASE = 2,
    CONFIRMATION_IRA = 3, -- IRA = Instant Reward Access
    NO_IRA = 4
}

local BOX_CONFIGS = {
    [CONST_WINDOWS_BOX.ALREADY] = {
        title = "Warning",
        content = "Sorry, you have already taken your daily reward or you are unable to collect it"
    },
    [CONST_WINDOWS_BOX.CONFIRMATION_IRA] = {
        title = "Confirmation of using Instant Reward Access",
        content = "Collecting away from a shrine uses one Instant Reward Access. Continue?",
        okCallback = function()
            if not submitClaim() then return end
            if windowsPickWindow then
                windowsPickWindow:destroy()
                windowsPickWindow = nil
            end
            if generalBox then
                generalBox:destroy()
                generalBox = nil
            end
        end
    },
    [CONST_WINDOWS_BOX.NO_IRA] = {
        title = "Warning: No Sufficient Instant Reward Access",
        content = "Remember! you can always collect your daily reward for free by visiting a reward shrine!\nyou do not have an Instant Reward Access.\nVisit the store to buy more!"
    }
}

-- /*=============================================
-- =            Local function                  =
-- =============================================*/
local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

local function premiumStatusWindwos(isPremium)
    rewardWallController.ui.premiumStatus.premiumMessage:setText(isPremium and
                                                                     "Great! You benefit from the best possible rewards and bonuses due to your premium status." or
                                                                     "With a Premium account, you would benefit from even better rewards and bonuses.")
    rewardWallController.ui.premiumStatus.premiumButton:setOn(not isPremium)
    rewardWallController.ui.infoPanel.free:setColor(isPremium and "#909090" or "#FFFFFF")
    rewardWallController.ui.infoPanel.premium:setColor(isPremium and "#FFFFFF" or "#909090")
    for i, widget in pairs(rewardWallController.ui.restingAreaPanel.bonusIcons:getChildren()) do
        if widget then
            widget:setOn(isPremium)
        end
    end
end

local function convert_timestamp(timestamp)
    return os.date("%Y-%m-%d, %H:%M:%S", timestamp)
end

local function getBonusStrings(bonuses)
    local result = {}
    for _, bonus in ipairs(bonuses) do
        table.insert(result, bonus["name"])
    end
    return table.concat(result, ", ")
end

local function visibleHistory(bool)
    local ui=rewardWallController.ui
    ui.historyPanel:setVisible(bool)
    for _,id in ipairs({'restingAreaPanel','dailyRewardsPanel','premiumStatus','infoPanel'}) do
        local widget=ui:getChildById(id)
        if widget then widget:setVisible(not bool) end
    end
end

local function updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    local dailyRewardsPanel = rewardWallController.ui.dailyRewardsPanel
    dayStreakDay = math.max(0, math.min(7, tonumber(dayStreakDay) or 0))

    -- The wall can be opened repeatedly during one session. Remove the dynamic
    -- status overlays from the previous response before rebuilding the seven days.
    for i = 1, 7 do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        local rewardArrow = dailyRewardsPanel:getChildById("arrow" .. i)
        if rewardArrow then rewardArrow:setImageClip("0 0 5 7") end
        if rewardWidget then
            local rewardGold = rewardWidget:getChildById("rewardGold" .. i)
            local rewardButton = rewardWidget:getChildById("rewardButton" .. i)
            if rewardGold then
                rewardGold:destroyChildren()
                rewardGold.status = nil
            end
            if rewardButton then
                rewardButton.status = STATUS.LOCKED
                rewardButton:setOn(true)
                rewardButton.ditherpattern:setVisible(true)
            end
        end
    end

    for i = 1, dayStreakDay do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        local rewardArrow = dailyRewardsPanel:getChildById("arrow" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(true)
            test:fill("parent")
            test:setPhantom(true)
            if rewardArrow then
                rewardArrow:setImageClip("5 0 5 7")
            end
            local rewardButton = rewardWidget:getChildById("rewardButton" .. i)
            rewardButton:setOn(true)
            rewardButton.ditherpattern:setVisible(true)
            rewardButton.status = STATUS.COLLECTED
            rewardWidget:getChildById("rewardGold" .. i).status = STATUS.COLLECTED
        end
    end

    local currentReward = dailyRewardsPanel:getChildById("reward" .. dayStreakDay + 1)
    if currentReward and not rewardUnavailable then
        local test = g_ui.createWidget("GoldLabel2", currentReward:getChildById("rewardGold" .. dayStreakDay + 1))
        test:setOn(true)
        test:fill("parent")
        test:setPhantom(true)
        test.text:setText('Ready')
        test.text:setColor('#88d477')
        test.gold:hide()
        currentReward:getChildById("rewardGold" .. dayStreakDay + 1).status = STATUS.ACTIVE
        currentReward:setOn(false)
        local currentButton = currentReward:getChildById("rewardButton" .. dayStreakDay + 1)
        currentButton.ditherpattern:setVisible(false)
        currentButton:setOn(false)
        currentButton.status = STATUS.ACTIVE
    end

    for i = dayStreakDay + 2, 7 do
        local rewardWidget = dailyRewardsPanel:getChildById("reward" .. i)
        if rewardWidget then
            local test = g_ui.createWidget("RewardButton", rewardWidget:getChildById("rewardGold" .. i))
            test:setOn(false)
            test:fill("parent")
            test:setPhantom(true)
            local rewardButton = rewardWidget:getChildById("rewardButton" .. i)
            rewardButton:setOn(true)
            rewardButton.ditherpattern:setVisible(true)
            rewardButton.status = STATUS.LOCKED
            rewardWidget:getChildById("rewardGold" .. i).status = STATUS.LOCKED
        end
    end
end

local function getDayStreakIcon(dayStreakLevel)
    local IconConsecutiveDays = {
        [24] = "icon-rewardstreak-default",
        [49] = "icon-rewardstreak-bronze",
        [99] = "icon-rewardstreak-silver",
        [100] = "icon-rewardstreak-gold"
    }
    if dayStreakLevel <= 24 then
        return IconConsecutiveDays[24]
    elseif dayStreakLevel <= 49 then
        return IconConsecutiveDays[49]
    elseif dayStreakLevel <= 99 then
        return IconConsecutiveDays[99]
    else
        return IconConsecutiveDays[100]
    end
end

local function getBonusDescription(bonusName, streakCount, activeBonuses)
    local isPremium = g_game.getLocalPlayer():isPremium()

    return string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonusName, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        streakCount, isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(activeBonuses) or "")
end

local function checkRewards(data)
    local premium = g_game.getLocalPlayer():isPremium()
    local rewardCount = math.min(7, math.max(#data.freeRewards, #data.premiumRewards))

    for index = 1, rewardCount do
        local freeReward = data.freeRewards[index]
        local premiumReward = data.premiumRewards[index]
        local reward = premium and premiumReward or freeReward

        if reward then
            local hasSelectableItems = reward.selectableItems and next(reward.selectableItems) ~= nil
            local rewardWidget = rewardWallController.ui.dailyRewardsPanel:getChildById("reward" .. index)
            local rewardButton = rewardWidget:getChildById("rewardButton" .. index)
            local iconWidget = rewardWidget:getChildByIndex(1)

            if hasSelectableItems then
                iconWidget:setIcon("/game_rewardwall/images/icon-reward-pickitems")
                rewardButton.bundleType = bundleType.ITEMS
                rewardButton.rewardItem = reward.selectableItems
                rewardButton.itemsToSelect = {
                    freeReward and freeReward.itemsToSelect or 0,
                    premiumReward and premiumReward.itemsToSelect or 0
                }
                rewardButton.selectionCount = reward.itemsToSelect or 0
            elseif reward.bundleItems[1] and reward.bundleItems[1].bundleType == bundleType.XPBOOST then
                iconWidget:setIcon("/game_rewardwall/images/icon-reward-xpboost")
                rewardButton.bundleType = bundleType.XPBOOST
                rewardButton.itemsToSelect = {
                    freeReward and freeReward.bundleItems[1] and freeReward.bundleItems[1].itemId or 0,
                    premiumReward and premiumReward.bundleItems[1] and premiumReward.bundleItems[1].itemId or 0
                }
                rewardButton.selectionCount = 0
            else
                iconWidget:setIcon("/game_rewardwall/images/icon-reward-fixeditems")
                rewardButton.bundleType = bundleType.PREY
                rewardButton.itemsToSelect = {
                    freeReward and freeReward.bundleItems[1] and freeReward.bundleItems[1].count or 0,
                    premiumReward and premiumReward.bundleItems[1] and premiumReward.bundleItems[1].count or 0
                }
                rewardButton.selectionCount = 0
            end
        end
    end
end

local function formatRewardTime(timeLeft, nextRewardTime)
    local seconds = tonumber(timeLeft) or 0
    local nextTimestamp = tonumber(nextRewardTime) or 0

    -- Some 15.x servers send an absolute Unix timestamp in this field.
    if seconds > 7 * 24 * 60 * 60 then
        seconds = seconds - os.time()
    elseif seconds <= 0 and nextTimestamp > os.time() then
        seconds = nextTimestamp - os.time()
    end

    seconds = math.max(0, math.floor(seconds))
    if seconds == 0 then
        return "Expired"
    elseif seconds == 90001 or seconds < 60 then
        return "< 1 min"
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%02d:%02d", hours, minutes)
end
-- /*=============================================
-- =            onParse                  =
-- =============================================*/
--[[
--  0xDE ??
local function onDailyRewardCollectionState(state)
    if not rewardWallController.ui:isVisible() then
        return
    end

    local text = {
        [DailyRewardStatus.DAILY_REWARD_COLLECTED] = "you did not claim your daily reward in time. too bad, you do not have enough Daily Reward Jokers.",
        [DailyRewardStatus.DAILY_REWARD_NOTCOLLECTED] = "You did not claim your daily reward in time. If you don't claim your reward now, your [color=#D33C3C]streak will be reset.[/color]",
        [DailyRewardStatus.DAILY_REWARD_NOTAVAILABLE] ="idk",
    }
    rewardWallController.ui.restingAreaPanel.streakWarning:parseColoredText(text[state],"#c0c0c0")
end 
]]

local function onRestingAreaState(zone, state, message)
    if ZONE.LAST_ZONE == zone then -- todo move cpp
        return
    end
    ZONE.LAST_ZONE = zone
    local gameInterface = modules.game_interface
    if zone == ZONE.RESTING_AREA_ZONE then
        gameInterface.processIcon(ZONE.NUMERIC_ICON_ID, function(icon)
            icon:setTooltip(message)
        end, true)
    else
        gameInterface.processIcon(ZONE.ICON_ID, function(icon)
            icon:destroy()
        end)
    end
end

local function onDailyReward(data)
    bonuses = data.bonuses
    checkRewards(data)
end

local function onServerError(code, error)
    if code ~= 0x14 then return end
    resetClaim()
    generalBox = destroyWindows(generalBox)
    local cancelCallback = function()
        generalBox = destroyWindows(generalBox)
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "ok",
        callback = cancelCallback
    }}

    generalBox = displayGeneralBox3(rewardWallController.ui:getText(), error, standardButtons)
end

local function connectOnServerError()
    if serverErrorConnected then return end
    serverErrorConnected=true
    connect(g_game, {
        onServerError = onServerError
    })
end

local function disconnectOnServerError()
    if not serverErrorConnected then return end
    serverErrorConnected=false
    disconnect(g_game, {
        onServerError = onServerError
    })
end

local function onOpenRewardWall(bonusShrines, nextRewardTime, dayStreakDay, wasDailyRewardTaken, errorMessage, tokens,
    timeLeft, dayStreakLevel)
    if not g_game.getLocalPlayer() then return end
    resetClaim()
    awaitingWall=false
    actualUsed={} requiredRewardItems=0
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
    visibleHistory(false)
    rewardWallController.ui.footerPanel.historyButton:setText('history')
    premiumStatusWindwos(g_game.getLocalPlayer():isPremium())
    rewardWallController.ui.restingAreaPanel.streakWarning:setText('')
    if bonusShrines == OPEN_WINDOWS.SHRINE then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
    bonusShrine = bonusShrines
    rewardUnavailable=wasDailyRewardTaken~=0
    connectOnServerError()
    updateDailyRewards(dayStreakDay, wasDailyRewardTaken)
    if rewardUnavailable and errorMessage and errorMessage~='' then
        rewardWallController.ui.restingAreaPanel.streakWarning:setText(errorMessage)
    end
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setText(dayStreakLevel)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.timeLeft:setText(
        formatRewardTime(timeLeft, nextRewardTime))
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold.text:setText(tokens)
    rewardWallController.ui.footerPanel.footerGold1.text:setText(tokens)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setImageSource(
        "/game_rewardwall/images/" .. getDayStreakIcon(dayStreakLevel))

    rewardWallController.ui.footerPanel.footerGold2.text:setText(
        g_game.getLocalPlayer():getResourceBalance(ResourceTypes.DAILYREWARD_STREAK))
end

local function onRewardHistory(rewardHistory)
    local transferHistory = rewardWallController.ui.historyPanel.historyList.List
    transferHistory:destroyChildren()

    local headerRow = g_ui.createWidget("historyData2", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Streak")
    headerRow.Description:setText("Event")

    for i, data in ipairs(rewardHistory) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row:setHeight(30)
        row.date:setText(convert_timestamp(data[1]))
        row.Balance:setText(data[4])
        row.Description:setText(data[3])
        row.Description:setTextWrap(true)
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
end

-- /*=============================================
-- =            Windows                  =
-- =============================================*/
function show()
    if not rewardWallController.ui or not g_game.getLocalPlayer() then
        return
    end
    awaitingWall=true
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
    actualUsed={} requiredRewardItems=0
    rewardWallController.ui.restingAreaPanel.streakWarning:setText('Loading rewards...')
    g_game.sendOpenRewardWall()
    rewardWallController.ui:show()
    rewardWallController.ui:raise()
    rewardWallController.ui:focus()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(true)
    end
    connectOnServerError()
    premiumStatusWindwos(g_game.getLocalPlayer():isPremium())
end

function hide(bool)
    if not rewardWallController.ui then
        return
    end
    rewardWallController.ui:hide()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(false)
    end
    if bool then
        disconnectOnServerError()
    end
end

function toggle()
    if not rewardWallController.ui then
        return
    end
    if rewardWallController.ui:isVisible() then
        return hide(true)
    end
    show()
end

local function configureLayout()
    local ui=rewardWallController.ui
    -- Native OTUI anchors avoid HTML reflow overwriting these fixed rows.
    ui:setSize({width=590,height=560})
    ui:setLayout(UIAnchorLayout.create(ui))
    local function box(widget,x,y,width,height)
        widget:breakAnchors() widget:setMargin(0)
        widget:addAnchor(AnchorLeft,'parent',AnchorLeft)
        widget:addAnchor(AnchorTop,'parent',AnchorTop)
        widget:setMarginLeft(x) widget:setMarginTop(y)
        widget:setSize({width=width,height=height})
    end
    box(ui.restingAreaPanel,0,0,558,135)
    box(ui.dailyRewardsPanel,0,140,558,125)
    box(ui.premiumStatus,0,270,558,55)
    box(ui.infoPanel,0,330,558,125)
    box(ui.footerSeparator,0,461,558,2)
    box(ui.footerPanel,0,469,558,26)
    box(ui.historyPanel,0,0,558,455)
    local rest=ui.restingAreaPanel
    box(rest.restingAreaInfo,0,0,100,104)
    box(rest.bonusIcons,110,0,408,68)
    for i=1,6 do rest.bonusIcons['bonusIcon'..i]:setSize({width=64,height=64}) end
    box(rest.streakWarning,110,73,408,34) rest.streakWarning:setTextWrap(true)
    local daily=ui.dailyRewardsPanel
    daily:setPaddingLeft(8)
    for i=1,7 do
        daily['reward'..i]:setWidth(68) daily['reward'..i]:setMarginTop(0)
    end
    daily.arrowLoop:setWidth(0)
    box(ui.premiumStatus.premiumMessage,0,0,372,42)
    ui.premiumStatus.premiumMessage:setTextWrap(true)
    box(ui.premiumStatus.premiumButton,396,0,128,37)
    ui.infoPanel:setTextAlign(AlignTopLeft) ui.infoPanel:setTextWrap(true)
    box(ui.infoPanel.free,8,6,259,110)
    box(ui.infoPanel.premium,279,6,259,110)
    for _,label in ipairs({ui.infoPanel.free,ui.infoPanel.premium}) do
        label:setTextAlign(AlignTopLeft) label:setTextWrap(true)
    end
    local footer=ui.footerPanel
    box(footer.footerGold1,0,0,66,22)
    box(footer.footerGold2,76,0,66,22)
    box(footer.instantRewardButton,148,0,24,22)
    box(footer.historyButton,380,0,78,22)
    box(footer.closeButton,468,0,78,22)
    rewardWallController.ui.historyPanel.historyList:fill('parent')

    -- note: I don't know how to edit children in css
    local restingAreaGold = rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold
    restingAreaGold.gold:setImageSource("/game_rewardwall/images/icon-daily-reward-joker")
    restingAreaGold.gold:setImageSize("12 12")
    restingAreaGold.gold:setImageOffset("-30 0")

    local footerGold1 = rewardWallController.ui.footerPanel.footerGold1
    footerGold1.gold:setImageSource("/game_rewardwall/images/icon-daily-reward-joker")
    footerGold1.gold:setImageSize("11 11")
    footerGold1.gold:setImageOffset("-3 0")
    footerGold1.text:setTextAlign(AlignRightCenter)

    local footerGold2 = rewardWallController.ui.footerPanel.footerGold2
    footerGold2.gold:setImageSource("/game_rewardwall/images/instant-reward-access-icon")
    footerGold2.gold:setImageSize("12 12")
    footerGold2.gold:setImageOffset("-5 0")
end
-- /*=============================================
-- =            Controller                  =
-- =============================================*/
function rewardWallController:onInit()
    g_ui.importStyle("styles/style.otui")
    rewardWallController:loadUI('game_rewardwall')
    rewardWallController.ui:hide()

    local ui=self.ui
    local function hover(widget,callback)
        widget.onHoverChange=function(target,value) callback(self,{target=target,value=value}) end
    end
    for i=1,7 do
        local row=ui.dailyRewardsPanel['reward'..i]
        local button=row['rewardButton'..i]
        button.onClick=function(target) self:onClickDisplayWindowsPickRewardWindow({target=target}) end
        hover(button,self.onhoverRewardType)
        hover(row['rewardGold'..i],self.onhoverStatusReward)
    end
    for i=1,6 do hover(ui.restingAreaPanel.bonusIcons['bonusIcon'..i],self.onhoverBonus) end
    for _,id in ipairs({'rewardStreakIcon','timeLeft','restingAreaGold'}) do
        hover(ui.restingAreaPanel.restingAreaInfo[id],self.onhoverStatusPlayer)
    end
    ui.footerPanel.closeButton.onClick=function() self:onClickToggle() end
    ui.onEscape=ui.footerPanel.closeButton.onClick
    ui.footerPanel.historyButton.onClick=function() self:onClickshowHistory() end
    ui.footerPanel.instantRewardButton.onClick=function() self:onClickbuyInstantRewardAccess() end
    ui.premiumStatus.premiumButton.onClick=function() self:onClickSendStoreRewardWall() end

    rewardWallController:registerEvents(g_game, {
        onOpenRewardWall = onOpenRewardWall,
        onDailyReward = onDailyReward,
        onRewardHistory = onRewardHistory,
        onRestingAreaState = onRestingAreaState
        -- onDailyRewardCollectionState
    })
    configureLayout()
end

function rewardWallController:onTerminate()
    resetClaim()
    disconnectOnServerError()
    generalBox, windowsPickWindow, ButtonRewardWall = destroyWindows({generalBox, windowsPickWindow, ButtonRewardWall})
end

function rewardWallController:onGameStart()
    if g_game.getClientVersion() > 1140 then -- Summer Update 2017
        if not ButtonRewardWall then
            ButtonRewardWall = modules.game_mainpanel.addToggleButton("rewardWall", tr("Open rewardWall"),
                "/images/options/rewardwall", toggle, false, 21)
        end
    else
        scheduleEvent(function()
            g_modules.getModule("game_rewardwall"):unload()
        end, 100)
    end
end

function rewardWallController:onGameEnd()
    resetClaim()
    disconnectOnServerError()
    awaitingWall=true rewardUnavailable=false actualUsed={} requiredRewardItems=0 ZONE.LAST_ZONE=-99
    if rewardWallController.ui:isVisible() then
        rewardWallController.ui:hide()
        if ButtonRewardWall then ButtonRewardWall:setOn(false) end
    end
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
end
-- /*=============================================
-- =            Call css onClick                =
-- =============================================*/
function rewardWallController:onClickshowHistory()
    visibleHistory(not rewardWallController.ui.historyPanel:isVisible())
    if rewardWallController.ui.historyPanel:isVisible() then
        g_game.requestOpenRewardHistory()
    end
    rewardWallController.ui.footerPanel.historyButton:setText(
    rewardWallController.ui.historyPanel:isVisible() and "back" or "history")
end

function rewardWallController:onClickToggle()
    toggle()
end

function rewardWallController:onClickSendStoreRewardWall()
    modules.game_store.toggle()
    g_game.sendRequestStorePremiumBoost()
end

function rewardWallController:onClickbuyInstantRewardAccess()
    modules.game_store.toggle()
    g_game.sendRequestUsefulThings(StoreConst.InstantRewardAccess)
end

function rewardWallController:onClickDisplayWindowsPickRewardWindow(event)
    if awaitingWall or rewardUnavailable or claimPending or not g_game.getLocalPlayer() then return end
    while event.target and event.target.status==nil do event.target=event.target:getParent() end
    if not event.target then return end
    if event.target.status ~= STATUS.ACTIVE then
        return
    end

    if event.target.bundleType == bundleType.ITEMS then
        local itemsToSelect = event.target.selectionCount or 0
        if not windowsPickWindow then
            actualUsed = {}
            itemsToSelect = math.max(1, itemsToSelect)
            requiredRewardItems = itemsToSelect
            windowsPickWindow = g_ui.displayUI('styles/pickreward')
            windowsPickWindow:show()
            windowsPickWindow:getChildById('capacity'):setText("Free capacity: " ..
                                                                   g_game:getLocalPlayer():getFreeCapacity() .. " oz")

            local text = string.format("You have selected [color=#D33C3C]0[/color] of %d reward items", itemsToSelect)
            windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text, "#c0c0c0")

            for i, item in pairs(event.target.rewardItem) do
                local getItem = g_ui.createWidget('ItemReward', windowsPickWindow:getChildById('rewardList'))
                getItem:getChildById('item'):setItemId(item.itemId)
                getItem:getChildById('title'):setText(item.name)
                getItem:setBackgroundColor((i % 2 == 0) and COLORS.BASE_1 or COLORS.BASE_2)
                getItem.totalWeight = (item.weight or 0) / 100
                getItem.itemsToSelect = itemsToSelect
                getItem:getChildById('number'):setMaximum(itemsToSelect)

            end
            hide()
        else
            windowsPickWindow:show()
            windowsPickWindow:raise()
            windowsPickWindow:focus()
        end

    elseif event.target.bundleType == bundleType.XPBOOST or event.target.bundleType == bundleType.PREY then
        hide()
        actualUsed = {}
        requiredRewardItems = 0
        if bonusShrine == OPEN_WINDOWS.SHRINE then
            submitClaim()
        else
            managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
        end
    end
end

-- /*=============================================
-- =            Call onHover css                  =
-- =============================================*/

function rewardWallController:onhoverBonus(event)
    rewardWallController.ui.infoPanel.free:setText('')
    rewardWallController.ui.infoPanel.premium:setText('')
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end

    local id = event.target:getId()
    local index = tonumber(id:match("%d+"))
    local bonus = bonuses[index]

    if not bonus then
        rewardWallController.ui.infoPanel:setText("Unknown bonus.")
        return
    end

    local isPremium = g_game.getLocalPlayer():isPremium()
    local bonusText = string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonus.name, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        bonus.id,
        isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(getBonusStrings(bonuses)) or "")

    rewardWallController.ui.infoPanel:parseColoredText(bonusText)
end

function rewardWallController:onhoverStatusPlayer(event)
    rewardWallController.ui.infoPanel.free:setText('')
    rewardWallController.ui.infoPanel.premium:setText('')
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end

    local playerStatus = {
        rewardStreakIcon = "This explains the reward streak system. You need to claim your daily reward between regular server saves to maintain your streak. At a streak of 2+, your character gets resting area bonuses. Free accounts can reach a maximum bonus at streak level 3, while premium players can reach higher levels. Characters on the same account share the streak.",
        timeLeft = "Time remaining to maintain your reward streak. The current time and any collection restrictions are supplied by the server.",
        restingAreaGold = "This explains how Daily Reward Jokers work. They help you maintain your streak on days when you can't claim your daily reward. Each character receives one Daily Reward Joker on the first day of each month. The message recommends collecting rewards daily to stay safe."
    }

    local DEFAULT_MESSAGE = "Unknown bonus."

    local id = event.target:getId()
    local info = playerStatus[id]
    rewardWallController.ui.infoPanel:parseColoredText(info or DEFAULT_MESSAGE)
end

function rewardWallController:onhoverRewardType(event)
    rewardWallController.ui.infoPanel:setText('')
    if not event.value then
        rewardWallController.ui.infoPanel.free:setText("")
        rewardWallController.ui.infoPanel.premium:setText("")
        return
    end

    local itemsToSelect = event.target.itemsToSelect or {1, 1}
    local freeAmount = 0
    local premiumAmount = 0

    if type(itemsToSelect) == "table" then
        freeAmount = itemsToSelect[1] or 0
        premiumAmount = itemsToSelect[2] or 0
    else
        freeAmount = itemsToSelect
        premiumAmount = itemsToSelect
    end

    local rewardType = event.target.bundleType
    local rewardTexts = {}

    if rewardType == bundleType.ITEMS then
        rewardTexts = {
            free = string.format(
                "Reward for Free Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                freeAmount),
            premium = string.format(
                "Reward for Premium Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                premiumAmount)
        }
    elseif rewardType == bundleType.PREY then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d x Prey Wildcard", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d x Prey Wildcard", premiumAmount)
        }
    elseif rewardType == bundleType.XPBOOST then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d minutes 50%% XP Boost", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d minutes 50%% XP Boost", premiumAmount)
        }
    else
        print("WARNING: Unknown rewardType:", rewardType)
        return
    end

    rewardWallController.ui.infoPanel.free:setText(rewardTexts.free)
    rewardWallController.ui.infoPanel.premium:setText(rewardTexts.premium)
end

function rewardWallController:onhoverStatusReward(event)
    rewardWallController.ui.infoPanel.free:setText('')
    rewardWallController.ui.infoPanel.premium:setText('')
    local statusReward = {
        [STATUS.COLLECTED] = "You have already collected this daily reward.\nThe daily rewards follow a specific cycle where each day you claim it, you get another reward. The cycle repeats after 7 claimed rewards. You will be able to claim this daily reward again as soon as you have reached this postion in the next cycle.",
        [STATUS.ACTIVE] = bonusShrine == OPEN_WINDOWS.SHRINE
            and "The daily reward can be claimed now at this shrine without Instant Reward Access."
            or "The daily reward can be claimed now. Collecting away from a shrine uses one Instant Reward Access. Visit a reward shrine to collect it for free.",
        [STATUS.LOCKED] = "This daily reward is still locked.\nFirst collect the previous daily rewards of this cycle."
    }
    if not event.value then
        rewardWallController.ui.infoPanel:setText("")
        return
    end
    rewardWallController.ui.infoPanel:setText(statusReward[event.target.status] or '')
end

-- /*=============================================
-- =            Auxiliar Windows pickReward      =
-- =============================================*/

function onClickBtnOk()
    if awaitingWall or rewardUnavailable or claimPending then return end
    local selectedCount = 0
    for _, count in pairs(actualUsed) do
        selectedCount = selectedCount + (tonumber(count) or 0)
    end
    if selectedCount ~= requiredRewardItems then
        return
    end
    if bonusShrine == OPEN_WINDOWS.SHRINE then
        if not submitClaim() then return end
        windowsPickWindow = destroyWindows(windowsPickWindow)
        return
    end
    managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
end

function destroyPickReward(bool)
    windowsPickWindow = destroyWindows(windowsPickWindow)
    requiredRewardItems = 0

    if bool then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
end

function onTextChangeChangeNumber(getPanel)
    if not windowsPickWindow or not getPanel.itemsToSelect then
        return
    end

    local alreadyUsed = 0
    local itemId = getPanel:getChildById('item'):getItemId()
    local thisPanelUsed = actualUsed[itemId] or 0

    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end

    local numberField = getPanel:getChildById('number')
    local currentValue = math.max(0, math.floor(tonumber(numberField:getText()) or 0))
    local maxAllowed = getPanel.itemsToSelect - (alreadyUsed - thisPanelUsed)

    currentValue = math.min(currentValue, math.max(0, maxAllowed))
    if tonumber(numberField:getText()) ~= currentValue then
        numberField:setText(currentValue)
    end
    if currentValue > 0 then
        actualUsed[itemId] = currentValue
    else
        actualUsed[itemId] = nil
    end
    alreadyUsed = 0
    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end
    local selectionComplete = alreadyUsed == getPanel.itemsToSelect
    local color = selectionComplete and "#00FF00" or "#D33C3C"
    windowsPickWindow:getChildById('btnOk'):setEnabled(selectionComplete)

    local text = string.format("You have selected [color=%s]%d[/color] of %d reward items", color, alreadyUsed,
        getPanel.itemsToSelect)
    windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text)
    getPanel:getChildById('weight'):setText(string.format("%.2f oz", (actualUsed[itemId] or 0) * getPanel.totalWeight))
    local totalWeight = 0
    for i, widget in pairs(getPanel:getParent():getChildren()) do
        local itemWidget = widget:getChildById('item')
        if itemWidget and widget.totalWeight then
            totalWeight = totalWeight + (actualUsed[itemWidget:getItemId()] or 0) * widget.totalWeight
        end
    end
    windowsPickWindow:getChildById("weight"):setText(string.format("Total weight: %.2f oz", totalWeight))
    windowsPickWindow:getChildById("weight"):resizeToText()
end

-- /*=============================================
-- =            Auxiliar GeneralBox             =
-- =============================================*/
function displayGeneralBox3(title, message, buttons, onEnterCallback, onEscapeCallback)
    generalBox=destroyWindows(generalBox)
    -- Use the client's tested message-box layout and button ownership.
    generalBox=displayGeneralBox(title,message,buttons,onEnterCallback,onEscapeCallback)
    return generalBox
end

function managerMessageBoxWindow(id)
    local config = BOX_CONFIGS[id]
    if not config then
        return
    end

    local cancelCallback = function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local okCallback = config.okCallback or function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "cancel",
        callback = cancelCallback
    }, {
        text = "ok",
        callback = okCallback
    }}

    generalBox = displayGeneralBox3(config.title, config.content, standardButtons)

    rewardWallController.ui:hide()

    if windowsPickWindow then
        windowsPickWindow = destroyWindows(windowsPickWindow)
    end
end
