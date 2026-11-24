-- Nexus Sell All: sells every owned item the NPC buys, one item type at a time,
-- waiting for the server's goods update before sending the next request.

local GOLD_COIN_ID = 3031
local DEFAULT_DELAY = 100
local MIN_DELAY = 50
local MAX_DELAY = 2000
local CONFIRM_TIMEOUT = 4000
local MAX_RETRIES = 1
local DELAY_SETTING = 'nexusNpcSellAllDelay'

local function blockedSet(controller)
    local ids = controller:getSellExclusions()
    if not ids then return nil end
    local blocked = {}
    for _, id in ipairs(ids) do blocked[id] = true end
    return blocked
end

local function saveBlockedSet(controller, blocked)
    local ids = {}
    for id in pairs(blocked) do ids[#ids + 1] = id end
    table.sort(ids)
    controller:setSellExclusionsText(table.concat(ids, ','))
end

local function inCyclopediaWhitelist(id)
    local cyclopedia = modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
    local items = cyclopedia and cyclopedia.Items
    return items and items.isInQuickSellWhitelist and items.isInQuickSellWhitelist(id) == true
end

local function offerKey(controller, ptr)
    if controller:isLegacyMode() then return tostring(ptr:getId()) end
    return ptr:getId() .. '_' .. ptr:getSubType()
end

-- Every distinct item the NPC buys, with what the player can sell of it right now.
local function npcOffers(controller)
    local byKey, ordered = {}, {}
    for _, offer in ipairs(getSellItems()) do
        local ptr = offer.ptr
        if ptr and (offer.price or 0) > 0 then
            local key = offerKey(controller, ptr)
            if not byKey[key] then
                local entry = {
                    key = key, id = ptr:getId(), ptr = ptr, price = offer.price,
                    name = offer.name or ('item ' .. ptr:getId()), count = getSellQuantity(ptr)
                }
                byKey[key] = entry
                ordered[#ordered + 1] = entry
            end
        end
    end
    table.sort(ordered, function(a, b)
        if a.name == b.name then return a.key < b.key end
        return a.name < b.name
    end)
    return byKey, ordered
end

local function shortCount(n)
    if n >= 100000 then return math.floor(n / 1000) .. 'k' end
    return tostring(n)
end

local function maxPerRequest()
    return g_game.getFeature(GameDoubleShopSellAmount) and 10000 or 100
end

local function currentIgnoreEquipped(controller)
    if controller:isLegacyMode() then return controller:legacyIgnoreEquipped() end
    return controller.ignoreEquipped
end

function controllerNpcTrader:getSellAllDelay()
    local value = tonumber(g_settings.get(DELAY_SETTING))
    if not value then return DEFAULT_DELAY end
    return math.max(MIN_DELAY, math.min(MAX_DELAY, math.floor(value)))
end

local function setCellItem(cell, ptr)
    cell.item:setItem(ptr)
    if cell.item.setShowCount then cell.item:setShowCount(false) end
end

------------------------------------------------------------------------------
-- Selling loop
------------------------------------------------------------------------------

local function clearSaleTimer(sale)
    if sale.timer then
        removeEvent(sale.timer)
        sale.timer = nil
    end
end

function controllerNpcTrader:sellAllRefresh()
    local ui = self.quickSell
    if not ui then return end
    local sale = self.quickSale
    local total, value = 0, 0
    for _, entry in ipairs(ui.entries) do
        if entry.cell then
            local visible = not ui.blocked[entry.id] and entry.count > 0
            entry.cell:setVisible(visible)
            if visible then
                entry.cell.count:setText(shortCount(entry.count))
                entry.cell.check:setVisible(entry.selected)
                entry.cell:setOpacity(entry.selected and 1.0 or 0.45)
                if entry.selected then
                    total = total + entry.count
                    value = value + entry.count * entry.price
                end
            end
        end
    end
    ui.window.valueBox.value:setText(tostring(value))
    ui.window.sellPage.empty:setVisible(total == 0 and not sale)
    if sale then
        local percent = sale.total > 0 and math.floor(sale.done * 100 / sale.total) or 100
        ui.window.progress:setPercent(percent)
        ui.window.progress:setText(tr('Sale Progress') .. ': ' .. percent .. '%')
        ui.window.sellButton:setText(tr('Stop'))
        ui.window.sellButton:setEnabled(true)
    else
        if not ui.finished then
            ui.window.progress:setPercent(0)
            ui.window.progress:setText(tr('Sale Progress'))
        end
        ui.window.sellButton:setText(tr('Sell All'))
        ui.window.sellButton:setEnabled(total > 0)
    end
end

function controllerNpcTrader:finishSellAll(message)
    local sale = self.quickSale
    if sale then clearSaleTimer(sale) end
    self.quickSale = nil
    local ui = self.quickSell
    if not ui then return end
    ui.finished = true
    if message then ui.window.progress:setText(message) end
    for _, entry in ipairs(ui.entries) do
        entry.count = getSellQuantity(entry.ptr)
    end
    self:sellAllRefresh()
end

-- Picks the next selected entry that still has something to sell and sends one request for it.
function controllerNpcTrader:sendNextQuickSale()
    local sale = self.quickSale
    if not sale or sale.waiting then return end
    if not isTrading() then self:closeQuickSell() return end
    if currentIgnoreEquipped(self) ~= sale.ignoreEquipped then
        self:finishSellAll(tr('Stopped: settings changed.'))
        return
    end
    local ui = self.quickSell
    while sale.index <= #sale.queue do
        local entry = sale.queue[sale.index]
        local live = getSellQuantity(entry.ptr)
        if entry.selected and not ui.blocked[entry.id] and live > 0 then
            local amount = math.min(live, maxPerRequest())
            sale.waiting = true
            sale.stockBefore = self:quickSellStock(entry.ptr)
            sale.current = entry
            sale.timer = scheduleEvent(function()
                if self.quickSale ~= sale then return end
                sale.timer = nil
                sale.waiting = false
                sale.retries = (sale.retries or 0) + 1
                if sale.retries > MAX_RETRIES then
                    self:finishSellAll(tr('Stopped: the server did not confirm the sale.'))
                else
                    self:sendNextQuickSale()
                end
            end, CONFIRM_TIMEOUT)
            g_game.sellItem(entry.ptr, amount, sale.ignoreEquipped)
            return
        end
        if entry.count > 0 then
            sale.done = sale.done + entry.count
            entry.count = 0
        end
        sale.index = sale.index + 1
    end
    sale.done = sale.total
    self:sellAllRefresh()
    self:finishSellAll(tr('Sale Progress') .. ': 100% - ' .. tr('done'))
end

-- Called from both trade UIs after every onPlayerGoods.
function controllerNpcTrader:quickSellGoodsUpdated()
    local ui = self.quickSell
    local sale = self.quickSale
    if not ui then return end
    if not sale then
        -- Keep counts live while the window is open but idle.
        for _, entry in ipairs(ui.entries) do entry.count = getSellQuantity(entry.ptr) end
        self:sellAllRefresh()
        return
    end
    if not sale.waiting then return end
    local entry = sale.current
    local stock = self:quickSellStock(entry.ptr)
    if stock >= sale.stockBefore then return end -- unrelated update (money, loot)
    clearSaleTimer(sale)
    sale.waiting = false
    sale.retries = 0
    local live = getSellQuantity(entry.ptr)
    local sold = math.max(0, math.min(entry.count, entry.count - live))
    sale.done = math.min(sale.total, sale.done + sold)
    entry.count = live
    self:sellAllRefresh()
    sale.timer = scheduleEvent(function()
        if self.quickSale == sale then
            sale.timer = nil
            self:sendNextQuickSale()
        end
    end, sale.delay)
end

function controllerNpcTrader:startSellAll()
    local ui = self.quickSell
    if not ui or self.quickSale or not isTrading() then return end
    local blocked = blockedSet(self)
    if not blocked then
        displayErrorBox(tr('BlackList'), tr('The saved blacklist is invalid. Fix it in the BlackList tab.'))
        return
    end
    ui.blocked = blocked
    local live = npcOffers(self)
    local queue, total = {}, 0
    for _, entry in ipairs(ui.entries) do
        local offer = live[entry.key]
        entry.count = offer and offer.count or 0
        if offer and offer.price ~= entry.price then
            entry.price = offer.price
        end
        if entry.selected and not blocked[entry.id] and entry.count > 0 then
            queue[#queue + 1] = entry
            total = total + entry.count
        end
    end
    if total == 0 then self:sellAllRefresh() return end
    ui.finished = false
    self.quickSale = {
        queue = queue, index = 1, total = total, done = 0, retries = 0,
        ignoreEquipped = currentIgnoreEquipped(self), delay = self:getSellAllDelay()
    }
    self:sellAllRefresh()
    self:sendNextQuickSale()
end

function controllerNpcTrader:stopSellAll()
    if self.quickSale then self:finishSellAll(tr('Stopped.')) end
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------

function controllerNpcTrader:closeQuickSell()
    if self.quickSale then
        clearSaleTimer(self.quickSale)
        self.quickSale = nil
    end
    if self.quickSell then
        self.quickSell.window:destroy()
        self.quickSell = nil
    end
end

local function showPage(ui, page)
    local onSell = page == 'sell'
    ui.window.sellPage:setVisible(onSell)
    ui.window.blacklistPage:setVisible(not onSell)
    ui.window.sellTab:setOn(onSell)
    ui.window.blacklistTab:setOn(not onSell)
end

function controllerNpcTrader:buildBlacklistGrid()
    local ui = self.quickSell
    if not ui then return end
    local page = ui.window.blacklistPage
    page.grid:destroyChildren()
    local shown = {}
    local function addCell(id, ptr, name)
        if shown[id] then return end
        shown[id] = true
        local cell = g_ui.createWidget('NexusSellAllCell', page.grid)
        if ptr then setCellItem(cell, ptr) else cell.item:setItemId(id) end
        cell.count:setText('')
        cell.check:setVisible(false)
        local function paint()
            local isBlocked = ui.blocked[id] == true
            cell.lock:setVisible(isBlocked)
            cell:setOpacity(isBlocked and 1.0 or 0.45)
            cell:setTooltip(string.format('%s (ID %d)\n%s', name or '?', id,
                isBlocked and tr('Blocked - never sold. Click to unblock.') or tr('Click to block.')))
        end
        cell.onMouseRelease = function(_, _, button)
            if button ~= MouseLeftButton or self.quickSale then return false end
            if ui.blocked[id] then ui.blocked[id] = nil else ui.blocked[id] = true end
            saveBlockedSet(self, ui.blocked)
            paint()
            self:sellAllRefresh()
            return true
        end
        paint()
    end
    -- Blocked ids first, then everything this NPC buys.
    local blockedIds = {}
    for id in pairs(ui.blocked) do blockedIds[#blockedIds + 1] = id end
    table.sort(blockedIds)
    local names = {}
    for _, entry in ipairs(ui.entries) do names[entry.id] = names[entry.id] or entry.name end
    for _, id in ipairs(blockedIds) do addCell(id, nil, names[id]) end
    for _, entry in ipairs(ui.entries) do addCell(entry.id, entry.ptr, entry.name) end
end

-- Header "Sell All" button of the modern window: works from both Buy and Sell tabs.
function controllerNpcTrader:openSellAll()
    if not self:isLegacyMode() and self.tradeMode ~= self.SELL then
        self:setTradeMode(self.SELL)
    end
    self:sellAllFromUi()
end

function controllerNpcTrader:sellAllFromUi()
    if not isTrading() then return end
    if self.quickSell then
        self.quickSell.window:show()
        self.quickSell.window:raise()
        self.quickSell.window:focus()
        return
    end

    local blocked = blockedSet(self)
    if not blocked then
        -- Corrupt setting: start clean rather than refusing to open.
        self:setSellExclusionsText('')
        blocked = {}
    end

    local window = g_ui.displayUI('/game_npctrade/templates/quick_sell')
    local _, entries = npcOffers(self)
    local ui = {window = window, entries = {}, blocked = blocked}
    self.quickSell = ui

    local currencyId = self:isLegacyMode() and GOLD_COIN_ID or (self.currencyId or GOLD_COIN_ID)
    window.valueBox.coin:setItemId(currencyId)
    window.sellTab.icon:setItemId(currencyId)
    window.progress:setOn(true)

    local grid = window.sellPage.grid
    for _, entry in ipairs(entries) do
        if not inCyclopediaWhitelist(entry.id) then
            entry.selected = true
            local cell = g_ui.createWidget('NexusSellAllCell', grid)
            entry.cell = cell
            setCellItem(cell, entry.ptr)
            cell:setTooltip(string.format('%s (ID %d)\n%d gp each\n%s', entry.name, entry.id, entry.price,
                tr('Left click: skip this sale. Right click: add to BlackList.')))
            cell.onMouseRelease = function(_, _, button)
                if self.quickSale then return false end
                if button == MouseLeftButton then
                    entry.selected = not entry.selected
                elseif button == MouseRightButton then
                    ui.blocked[entry.id] = true
                    saveBlockedSet(self, ui.blocked)
                    if window.blacklistPage:isVisible() then self:buildBlacklistGrid() end
                else
                    return false
                end
                self:sellAllRefresh()
                return true
            end
            ui.entries[#ui.entries + 1] = entry
        end
    end

    local delayInput = window.blacklistPage.delayInput
    delayInput:setText(tostring(self:getSellAllDelay()))
    delayInput.onTextChange = function(widget, text)
        local clean = text:gsub('[^%d]', '')
        if clean ~= text then widget:setText(clean) return end
        local value = tonumber(clean)
        if value then
            g_settings.set(DELAY_SETTING, math.max(MIN_DELAY, math.min(MAX_DELAY, value)))
        end
    end

    local idInput = window.blacklistPage.idInput
    local function addTypedId()
        local id = tonumber(idInput:getText())
        if not id or id % 1 ~= 0 or id < 1 or id > 65535 then
            displayErrorBox(tr('BlackList'), tr('Enter a valid item ID (1-65535).'))
            return
        end
        ui.blocked[id] = true
        saveBlockedSet(self, ui.blocked)
        idInput:setText('')
        self:buildBlacklistGrid()
        self:sellAllRefresh()
    end
    idInput.onKeyPress = function(_, keyCode)
        if keyCode == KeyEnter then addTypedId() return true end
        return false
    end
    window.blacklistPage.addId.onClick = addTypedId
    window.blacklistPage.clearIds.onClick = function()
        if self.quickSale then return end
        ui.blocked = {}
        saveBlockedSet(self, ui.blocked)
        self:buildBlacklistGrid()
        self:sellAllRefresh()
    end

    window.sellTab.onClick = function() showPage(ui, 'sell') end
    window.blacklistTab.onClick = function()
        self:buildBlacklistGrid()
        showPage(ui, 'blacklist')
    end
    window.sellButton.onClick = function()
        if self.quickSale then self:stopSellAll() else self:startSellAll() end
    end
    local function close() self:closeQuickSell() end
    window.closeButton.onClick = close
    window.onEscape = close

    showPage(ui, 'sell')
    self:sellAllRefresh()
    window:raise()
    window:focus()
end
