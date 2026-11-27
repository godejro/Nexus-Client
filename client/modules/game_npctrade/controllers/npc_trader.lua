function controllerNpcTrader:onOpenNpcTrade(items, currencyId, currencyName, npcName)
    if currencyName=='' then currencyName=nil end
    if currencyId==0 then currencyId=nil end
    local ui = controllerNpcTrader.ui
    if not ui or not ui:isVisible() then
        controllerNpcTrader:initNpcWindow()
    end
    if npcName and npcName ~= "" then self.creatureName=npcName end
    local isNewSession = not controllerNpcTrader.isTradeOpen
    if isNewSession then
        controllerNpcTrader.isTradeOpen = true
        controllerNpcTrader.widthConsole = controllerNpcTrader.TRADE_CONSOLE_WIDTH
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.currencyId = currencyId or controllerNpcTrader.DEFAULT_CURRENCY_ID
        controllerNpcTrader.currencyName = currencyName or controllerNpcTrader.DEFAULT_CURRENCY_NAME
    else
        if currencyId then
            controllerNpcTrader.currencyId = currencyId
        end
        if currencyName then
            controllerNpcTrader.currencyName = currencyName
        end
    end

    if items and type(items) == "table" then
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.selectedItem = nil
        for _, itemData in ipairs(items) do
            local ptr = itemData[1]
            local name = itemData[2]
            local weight = itemData[3] / 100
            local buyPrice = itemData[4]
            local sellPrice = itemData[5]
            if buyPrice > 0 then
                table.insert(controllerNpcTrader.buyItems, {
                    ptr = ptr,
                    name = name,
                    weight = weight,
                    price = buyPrice,
                    count = 1
                })
            end
            if sellPrice > 0 then
                table.insert(controllerNpcTrader.sellItems, {
                    ptr = ptr,
                    name = name,
                    weight = weight,
                    price = sellPrice,
                    count = 1
                })
            end
        end
    end

    local currencyLabel = controllerNpcTrader:findWidget(".tradeCurrencyName")
    if currencyLabel then
        currencyLabel:setText(controllerNpcTrader.currencyName)
    end
    local currencyIcon = controllerNpcTrader:findWidget(".tradeCurrencyIcon")
    if currencyIcon then
        local item = Item.create(controllerNpcTrader.currencyId)
        if item then
            currencyIcon:setItem(item)
        else
            currencyIcon:setItemId(controllerNpcTrader.currencyId)
        end
    end

    if isNewSession then
        -- Initial State
        local initialMode = controllerNpcTrader.BUY
        if #controllerNpcTrader.buyItems > 0 then
            initialMode = controllerNpcTrader.BUY
        elseif #controllerNpcTrader.sellItems > 0 then
            initialMode = controllerNpcTrader.SELL
        end

        controllerNpcTrader.tradeMode = initialMode
        controllerNpcTrader.searchText = ""
        controllerNpcTrader.itemBatchSize = controllerNpcTrader.ITEM_BATCH_SIZE
        controllerNpcTrader.loadedItems = 0
        controllerNpcTrader.currentList = {}

        -- Settings & Sorting (remembered between NPCs, see npc_options.lua)
        controllerNpcTrader:loadTradeSettings()
        controllerNpcTrader.ignoreEquipped = controllerNpcTrader.DEFAULT_IGNORE_EQUIPPED

        controllerNpcTrader:setTradeMode(initialMode)
    else
        controllerNpcTrader.allTradeItems = (controllerNpcTrader.tradeMode == controllerNpcTrader.BUY) and
                                                controllerNpcTrader.buyItems or controllerNpcTrader.sellItems
        controllerNpcTrader:filterTradeList(controllerNpcTrader.searchText or "")
        controllerNpcTrader:refreshPlayerGoods(true)
    end
end

function controllerNpcTrader:setTradeMode(mode)
    self.tradeMode = mode
    self.selectedItem = nil

    local buyTab = self:findWidget("#tabBuy")
    local sellTab = self:findWidget("#tabSell")

    if buyTab then
        buyTab:setEnabled(mode ~= controllerNpcTrader.BUY)
    end
    if sellTab then
        sellTab:setEnabled(mode ~= controllerNpcTrader.SELL)
    end
    local toggleButton = self:findWidget("#toggleButton")
    if toggleButton then
        toggleButton:setText(mode == controllerNpcTrader.BUY and "Buy" or "Sell")
    end

    self.shouldFocusFirst = true
    self:updateListSource()
    self:refreshPlayerGoods(true)
end

function controllerNpcTrader:updateListSource()
    if self.tradeMode == controllerNpcTrader.BUY then
        self.allTradeItems = self.buyItems
    else
        self.allTradeItems = self.sellItems
    end
    self:filterTradeList(self.searchText or "")
end

function controllerNpcTrader:loadNextBatch()
    if not self.currentList then
        return
    end

    local total = #self.currentList
    local current = self.loadedItems
    if current >= total then
        return
    end

    local limit = math.min(total, current + self.itemBatchSize)
    for i = current + 1, limit do
        table.insert(self.tradeItems, self.currentList[i])
    end
    self.loadedItems = limit
end

function controllerNpcTrader:onTradeScroll(widget, offset)
    if self.loadedItems >= #self.currentList then
        return
    end
    local rowHeight = controllerNpcTrader.ITEM_ROW_HEIGHT
    local contentHeight = self.loadedItems * rowHeight
    local viewportHeight = widget:getHeight()
    local maxScroll = math.max(0, contentHeight - viewportHeight)
    local value = offset.y
    if value >= maxScroll - controllerNpcTrader.SCROLL_THRESHOLD then
        self:loadNextBatch()
    end
end

function controllerNpcTrader:onTradeListRendered()
    local list = self:findWidget("#tradeListScroll")
    if list then
        if not list.onScrollEventConnected then
            list.onScrollChange = function(widget, offset)
                self:onTradeScroll(widget, offset)
            end
            list.onScrollEventConnected = true
        end
        local equipped = self.tradeMode == controllerNpcTrader.SELL and self.ignoreEquipped and self:getEquippedCounts() or nil
        local blocked = {}
        for _, id in ipairs(self:getSellExclusions() or {}) do blocked[id] = true end
        for i = 1, list:getChildCount() do
            local child = list:getChildByIndex(i)
            local item = child.tradeItem
            if item then
                local canTrade = self:canTradeItem(item, equipped)
                local color = canTrade and '#c0c0c0' or '#707070'
                local isBlocked = self.tradeMode == controllerNpcTrader.SELL and item.ptr and blocked[item.ptr:getId()]
                local infoBlock = child:getChildByIndex(2)
                if infoBlock then
                    local nameLabel = infoBlock:getChildById("nameLabel")
                    local infoLabel = infoBlock:getChildById("infoLabel")
                    if nameLabel then
                        -- Locked Items show their name in red.
                        nameLabel:setColor(isBlocked and (canTrade and '#e06060' or '#904848') or color)
                    end
                    if infoLabel then
                        infoLabel:setColor(color)
                    end
                end

                child.onMouseRelease = function(widget, mousePos, mouseButton)
                    self:onTradeItemMouseRelease(item, widget, mousePos, mouseButton)
                end
            end
        end
        if self.shouldFocusFirst then
            local firstChild = list:getChildByIndex(1)
            if firstChild then
                self:selectTradeItem(self.tradeItems[1], firstChild)
            end
            self.shouldFocusFirst = false
        elseif self.selectedItem then
            for i = 1, list:getChildCount() do
                local child = list:getChildByIndex(i)
                if child.tradeItem == self.selectedItem then
                    child:focus()
                    break
                end
            end
        end
    end
end

function controllerNpcTrader:onTradeItemMouseRelease(item, widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        menu:addOption("Look", function()
            g_game.inspectNpcTrade(item.ptr)
        end)
        menu:addOption("Inspect", function()
            g_game.inspectionObject(InspectObjectTypes.INSPECT_CYCLOPEDIA, item.ptr:getId())
        end)
        local itemId = item.ptr:getId()
        menu:addCheckBox(tr('Lock Item'), self:isSellBlocked(itemId), function(_, checked)
            self:setSellBlocked(itemId, checked)
        end)
        menu:addSeparator()
        self:addTradeOptions(menu)
        menu:display(mousePos)
        return true
    elseif mouseButton == MouseLeftButton then
        self:selectTradeItem(item, widget)
        return true
    end
    return false
end

function controllerNpcTrader:selectTradeItem(item, widget)
    self.selectedItem = item
    if widget then
        widget:focus()
    end
    self:updateAmount(1)

    local scroll = self:findWidget("#amountScrollBar")
    if scroll then
        scroll:enable()
        scroll:setValue(1)
    end
end

function controllerNpcTrader:updateAmount(amount)
    amount = tonumber(amount) or 1
    if self.selectedItem then
        local maxAmount = controllerNpcTrader.MAX_AMOUNT_NORMAL
        local minAmount = controllerNpcTrader.MIN_AMOUNT
        if self.tradeMode == controllerNpcTrader.BUY then
            local playerMoney = self:getPlayerMoney()
            local maxByMoney = math.floor(playerMoney / self.selectedItem.price)
            local maxByCapacity = controllerNpcTrader.MAX_AMOUNT_NORMAL
            if not self.ignoreCapacity then
                local player = g_game.getLocalPlayer()
                local freeCapacity = player and player:getFreeCapacity() or 0
                local itemWeight = tonumber(self.selectedItem.weight) or 0
                maxByCapacity = itemWeight > 0 and math.floor(freeCapacity / itemWeight) or maxByCapacity
            end
            maxAmount = math.max(minAmount, math.min(controllerNpcTrader.MAX_AMOUNT_NORMAL, maxByMoney, maxByCapacity))
            if self.selectedItem.ptr and self.selectedItem.ptr:isStackable() then
                maxAmount = math.max(minAmount,
                    math.min(controllerNpcTrader.MAX_AMOUNT_STACKABLE, maxByMoney, maxByCapacity))
            end
        else
            local sellable = self:getSellQuantity(self.selectedItem.ptr)
            minAmount = sellable > 0 and controllerNpcTrader.MIN_AMOUNT or 0
            maxAmount = math.max(minAmount, sellable)
        end
        if amount > maxAmount then
            amount = maxAmount
        end
        if amount < minAmount then
            amount = minAmount
        end
        local scroll = self:findWidget("#amountScrollBar")
        if scroll then
            scroll:setMaximum(maxAmount)
            scroll:setMinimum(minAmount)
            if scroll:getValue() ~= amount then
                scroll:setValue(amount)
            end
        end
    end
    self.amount = amount
    if self.selectedItem then
        self.totalPrice = self.selectedItem.price * amount
        self.totalWeight = string.format("%.2f", self.selectedItem.weight * amount)
    else
        self.totalPrice = 0
        self.totalWeight = "0.00"
    end
end

function controllerNpcTrader:onAmountScrollBarChange(value)
    self:updateAmount(value)
end

function controllerNpcTrader:onAmountInputChange(event)
    local input = event.target
    local text = input:getText()
    local cleanText = text:gsub("[^%d]", "")
    if cleanText ~= text then
        input:setText(cleanText)
        text = cleanText
    end
    if text == "" then
        text = "1"
    end
    local amount = tonumber(text) or 1
    self:updateAmount(amount)
    local scroll = self:findWidget("#amountScrollBar")
    if scroll then
        if amount ~= self.amount then
            input:setText(tostring(self.amount))
        end
        scroll:setValue(self.amount)
    end
end

function controllerNpcTrader:getPlayerMoney()
    if self.playerMoney ~= nil then
        return self.playerMoney
    end
    local player = g_game.getLocalPlayer()
    if not player then
        return 0
    end
    return player:getTotalMoney()
end

-- Counts of equipped items by "id_subtype". Read once per list refresh instead of
-- ten inventory lookups for every quantity check (the sell list sort used to do
-- this thousands of times per refresh).
function controllerNpcTrader:getEquippedCounts()
    local counts = {}
    local player = g_game.getLocalPlayer()
    if not player then
        return counts
    end
    for i = 1, 10 do
        local item = player:getInventoryItem(i)
        if item then
            local key = item:getId() .. "_" .. item:getSubType()
            counts[key] = (counts[key] or 0) + item:getCount()
        end
    end
    return counts
end

function controllerNpcTrader:getSellQuantity(itemPtr, equipped)
    if not itemPtr then
        return 0
    end
    local key = itemPtr:getId() .. "_" .. itemPtr:getSubType()
    local inventoryTotal = self.playerItems and self.playerItems[key] or 0

    if self.ignoreEquipped and inventoryTotal > 0 then
        equipped = equipped or self:getEquippedCounts()
        return math.max(0, inventoryTotal - (equipped[key] or 0))
    end

    return inventoryTotal
end

function controllerNpcTrader:canTradeItem(item, equipped)
    if self.tradeMode == controllerNpcTrader.BUY then
        local playerMoney = self:getPlayerMoney()
        -- Add capacity check if needed, but for now we'll just check price
        return playerMoney >= item.price
    else
        return self:getSellQuantity(item.ptr, equipped) > 0
    end
end

function controllerNpcTrader:onPlayerGoods(money, items)
    if not items or type(items) ~= "table" then
        return
    end
    self.playerMoney = money
    local newPlayerItems = {}
    for _, itemData in ipairs(items) do
        local ptr = itemData[1]
        local key = ptr:getId() .. "_" .. ptr:getSubType()
        local count = itemData[2]
        newPlayerItems[key] = (newPlayerItems[key] or 0) + count
    end
    local changed = not self.playerItems
    if not changed then
        for key, count in pairs(newPlayerItems) do
            if self.playerItems[key] ~= count then changed = true break end
        end
        if not changed then
            for key in pairs(self.playerItems) do
                if newPlayerItems[key] == nil then changed = true break end
            end
        end
    end
    self.playerItems = newPlayerItems
    -- Money-only updates (and repeats of the same goods) keep the rendered list.
    self:refreshPlayerGoods(not changed)
    self:quickSellGoodsUpdated()
end

function controllerNpcTrader:refreshPlayerGoods(skipFilter)
    local money = self:getPlayerMoney()
    local display = self:findWidget("#playerMoneyDisplay")
    if display then
        display:setText(tostring(money))
    end
    if not skipFilter and self.tradeMode == controllerNpcTrader.SELL then
        -- Sell All and the bot sell many items in a row, and every sale sends
        -- new goods. Rebuild the list once the updates settle, not per sale.
        if self.goodsFilterEvent then
            removeEvent(self.goodsFilterEvent)
        end
        self.goodsFilterEvent = scheduleEvent(function()
            self.goodsFilterEvent = nil
            if self.tradeMode == controllerNpcTrader.SELL and isTrading() then
                self:filterTradeList(self.searchText or "")
            end
        end, 150)
    end
    if self.selectedItem then
        self:updateAmount(self.amount)
    end
end

function controllerNpcTrader:sendTrade(item, amount, mode)
    if not item or not isTrading() then
        return
    end
    if mode == controllerNpcTrader.BUY then
        g_game.buyItem(item.ptr, amount, self.ignoreCapacity, self.buyWithBackpack)
    else
        g_game.sellItem(item.ptr, amount, self.ignoreEquipped)
    end
end

function controllerNpcTrader:executeTrade()
    if not self.selectedItem then
        return
    end
    local item, amount, mode = self.selectedItem, self.amount, self.tradeMode
    local total = (item.price or 0) * (amount or 0)
    local blocked = mode == controllerNpcTrader.SELL and item.ptr and self:isSellBlocked(item.ptr:getId())
    local large = not self.noLargeTradeWarning and total >= controllerNpcTrader.LARGE_TRADE_WARNING_GOLD
    if not blocked and not large then
        self:sendTrade(item, amount, mode)
        return
    end

    if self.largeTradeConfirm then
        self.largeTradeConfirm:destroy()
        self.largeTradeConfirm = nil
    end
    local function close()
        if self.largeTradeConfirm then
            self.largeTradeConfirm:destroy()
            self.largeTradeConfirm = nil
        end
    end
    local function confirm()
        close()
        self:sendTrade(item, amount, mode)
    end
    local verb = mode == controllerNpcTrader.BUY and tr('buy') or tr('sell')
    local message = tr('Do you really want to %s %d x %s for %d gold?', verb, amount, item.name or '?', total)
    if blocked then
        message = tr('%s is a Locked Item.', item.name or '?') .. '\n' .. message
    end
    self.largeTradeConfirm = displayGeneralBox(tr('Confirm Trade'), message, {
            { text = tr('Yes'), callback = confirm },
            { text = tr('No'), callback = close },
            anchor = AnchorHorizontalCenter
        }, confirm, close)
end

function controllerNpcTrader:clearSearch()
    local input = self:findWidget(".tradeSearchInput")
    if input then
        input:setText("")
        self:filterTradeList("")
    end
end

function controllerNpcTrader:filterTradeList(searchText)
    if not self.allTradeItems then
        return
    end

    self.searchText = searchText
    local lowerSearch = searchText:lower()
    local filteredItems = {}

    for _, item in ipairs(self.allTradeItems) do
        local includeItem = true
        if searchText ~= "" and not item.name:lower():find(lowerSearch, 1, true) then
            includeItem = false
        end

        if includeItem then
            table.insert(filteredItems, item)
        end
    end

    if self.tradeMode == controllerNpcTrader.SELL then
        local equipped = self.ignoreEquipped and self:getEquippedCounts() or nil
        local quantity = {}
        for _, item in ipairs(filteredItems) do
            quantity[item] = self:getSellQuantity(item.ptr, equipped)
        end
        table.sort(filteredItems, function(a, b)
            local qtyA = quantity[a]
            local qtyB = quantity[b]
            if qtyA ~= qtyB then
                return qtyA > qtyB
            end
            if self.sortBy == 'price' and a.price ~= b.price then
                return a.price > b.price
            elseif self.sortBy == 'weight' and a.weight ~= b.weight then
                return a.weight > b.weight
            end
            return a.name:lower() < b.name:lower()
        end)
    else
        self:sortTradeItems(filteredItems)
    end

    -- Same items in the same order: keep the existing rows and only recolour
    -- them, instead of destroying and rebuilding every row widget.
    local previous = self.currentList
    local same = previous and #previous == #filteredItems and self.tradeItems and #self.tradeItems > 0
    if same then
        for i = 1, #filteredItems do
            if previous[i] ~= filteredItems[i] then same = false break end
        end
    end
    if same then
        self:onTradeListRendered()
        return
    end

    self.currentList = filteredItems
    self.tradeItems = {}
    self.loadedItems = 0
    self:loadNextBatch()

    if #self.currentList > 0 then
        local found = false
        if self.selectedItem then
            for _, item in ipairs(self.currentList) do
                if item == self.selectedItem then
                    found = true;
                    break
                end
            end
        end
        if not found then
            self:selectTradeItem(self.tradeItems[1])
        end
    else
        self.selectedItem = nil
        self:updateAmount(0)
    end
end

function controllerNpcTrader:sellAll(delayed, exceptions)
    if type(delayed) == "table" then
        exceptions = delayed
        delayed = false
    end
    exceptions = exceptions or {}

    if self.sellAllWithDelayEvent then
        removeEvent(self.sellAllWithDelayEvent)
        self.sellAllWithDelayEvent = nil
    end

    local queue = {}
    if not self.sellItems or #self.sellItems == 0 then
        return
    end

    for _, entry in ipairs(self.sellItems or {}) do
        local id = entry.ptr:getId()
        if not table.find(exceptions, id) then
            local sellQuantity = self:getSellQuantity(entry.ptr)
            while sellQuantity > 0 do
                local maxPossible = g_game.getFeature(GameDoubleShopSellAmount) and 10000 or 100
                local maxAmount = math.min(sellQuantity, maxPossible)

                if delayed then
                    g_game.sellItem(entry.ptr, maxAmount, self.ignoreEquipped)
                    self.sellAllWithDelayEvent = scheduleEvent(function()
                        self:sellAll(true, exceptions)
                    end, 1100)
                    return
                end

                table.insert(queue, {entry.ptr, maxAmount, self.ignoreEquipped})
                sellQuantity = sellQuantity - maxAmount
            end
        end
    end

    for _, entry in ipairs(queue) do
        g_game.sellItem(entry[1], entry[2], entry[3])
    end
end
