local function exclusions(controller)
    local ids = controller:getSellExclusions()
    if not ids then return nil end
    local blocked = {}
    for _, id in ipairs(ids) do blocked[id] = true end
    return blocked
end

local function offers(controller)
    local found, ordered = {}, {}
    local cyclopedia = modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
    for _, offer in ipairs(getSellItems()) do
        local ptr = offer.ptr
        local id = ptr:getId()
        local key = controller:isLegacyMode() and tostring(id) or (id .. '_' .. ptr:getSubType())
        if not found[key] and offer.price > 0 and not (cyclopedia and cyclopedia.Items and
                cyclopedia.Items.isInQuickSellWhitelist and cyclopedia.Items.isInQuickSellWhitelist(id)) then
            local count = getSellQuantity(ptr)
            if count > 0 then
                local entry = {key=key, id=id, ptr=ptr, count=count, price=offer.price, name=offer.name}
                found[key] = entry
                ordered[#ordered + 1] = entry
            end
        end
    end
    table.sort(ordered, function(a,b)
        if a.name == b.name then return a.key < b.key end
        return a.name < b.name
    end)
    return found, ordered
end

local function clearSaleTimer(sale)
    if sale.timer then
        removeEvent(sale.timer)
        sale.timer = nil
    end
end

local function showProgress(sale)
    local percent = math.floor(sale.done * 100 / sale.total)
    sale.window.progress:setPercent(percent)
    sale.window.progress:setText(string.format('%d%%  (%d / %d)', percent, sale.done, sale.total))
end

function controllerNpcTrader:finishQuickSale(message)
    local sale = self.quickSale
    if not sale then return end
    clearSaleTimer(sale)
    self.quickSale = nil
    sale.window.hint:setText(message)
    sale.window.cancel:setText('Close')
end

function controllerNpcTrader:sendNextQuickSale()
    local sale = self.quickSale
    if not sale or sale.waiting then return end
    if not isTrading() then self:closeQuickSell() return end
    local entry = sale.entries[sale.index]
    local stock = self:quickSellStock(entry.ptr)
    local ignoreEquipped = self.ignoreEquipped
    if self:isLegacyMode() then ignoreEquipped = self:legacyIgnoreEquipped() end
    if ignoreEquipped ~= sale.ignoreEquipped or getSellQuantity(entry.ptr) < entry.remaining then
        self:finishQuickSale('Inventory changed. Review the remaining items.')
        return
    end
    sale.waiting = true
    sale.stockBefore = stock
    sale.window.hint:setText('Selling: ' .. entry.name)
    sale.timer = scheduleEvent(function()
        if self.quickSale == sale then self:finishQuickSale('Stopped: the server did not confirm the sale.') end
    end, 6000)
    g_game.sellItem(entry.ptr, 1, sale.ignoreEquipped)
end

function controllerNpcTrader:quickSellGoodsUpdated()
    local sale = self.quickSale
    if not sale or not sale.waiting then return end
    local entry = sale.entries[sale.index]
    local stock = self:quickSellStock(entry.ptr)
    if stock == sale.stockBefore then return end
    if stock ~= sale.stockBefore - 1 then
        self:finishQuickSale('Inventory changed unexpectedly. Check the remaining items.')
        return
    end
    clearSaleTimer(sale)
    sale.waiting = false
    entry.remaining = entry.remaining - 1
    sale.done = sale.done + 1
    showProgress(sale)
    if sale.done == sale.total then
        self:finishQuickSale('Sale complete.')
        return
    end
    if entry.remaining == 0 then sale.index = sale.index + 1 end
    sale.timer = scheduleEvent(function()
        if self.quickSale == sale then
            sale.timer = nil
            self:sendNextQuickSale()
        end
    end, 150)
end

function controllerNpcTrader:closeQuickSell()
    if self.quickSale then
        clearSaleTimer(self.quickSale)
        self.quickSale = nil
    end
    if self.quickSell then
        self.quickSell:destroy()
        self.quickSell = nil
    end
end

function controllerNpcTrader:sellAllFromUi()
    if not isTrading() then return end
    if self.quickSale then self.quickSale.window:raise() return end
    self:closeQuickSell()
    local window = g_ui.displayUI('/game_npctrade/templates/quick_sell')
    self.quickSell = window
    local _, entries = offers(self)
    local blocked = exclusions(self)
    local function currency(amount)
        if self:isLegacyMode() then return formatCurrency(amount) end
        return tostring(amount) .. ' ' .. (self.currencyName or 'gold')
    end
    local function refresh()
        local total = 0
        for _, entry in ipairs(entries) do
            local visible = blocked and not blocked[entry.id] and not entry.removed
            entry.row:setVisible(visible == true)
            if visible and entry.row.sell:isChecked() then total = total + entry.count * entry.price end
        end
        window.total:setText('Total: ' .. currency(total))
        window.confirm:setEnabled(total > 0 and not window.editor:isVisible())
    end
    local function cancel() self:closeQuickSell() end
    window.cancel.onClick = cancel
    window.onEscape = cancel
    for _, entry in ipairs(entries) do
        local row = g_ui.createWidget('NpcQuickSellRow', window.items)
        entry.row = row
        row.icon:setItem(entry.ptr)
        row.caption:setText(entry.count .. ' x ' .. entry.name)
        row.price:setText(currency(entry.price * entry.count))
        row.sell:setChecked(true)
        row.sell.onCheckChange = refresh
        row.remove.onClick = function() entry.removed = true refresh() end
    end
    window.blacklist.onClick = function()
        if window.editor:isVisible() then
            local value = window.editor:getText()
            local ids = {}
            for token in (value .. ','):gmatch('(.-),') do
                local id = tonumber(token)
                if token:match('%S') and (not id or id ~= math.floor(id) or id < 1 or id > 65535) then
                    displayErrorBox('Black List', 'Enter item IDs separated by commas.')
                    return
                end
                if id then ids[#ids+1] = id end
            end
            self:setSellExclusionsText(table.concat(ids, ','))
            blocked = exclusions(self)
            window.editor:hide()
            window.blacklist:setText('Black List')
        else
            window.editor:setText(self:getSellExclusionsText())
            window.editor:show()
            window.editor:focus()
            window.blacklist:setText('Apply list')
        end
        refresh()
    end
    window.confirm.onClick = function()
        if self.quickSell ~= window or not window.confirm:isEnabled() or not isTrading() or window.editor:isVisible() then return end
        local live = offers(self)
        local excluded = exclusions(self)
        if not excluded then return end
        local selected, total = {}, 0
        for _, entry in ipairs(entries) do
            if not entry.removed and entry.row:isVisible() and entry.row.sell:isChecked() then
                local offer = live[entry.key]
                if excluded[entry.id] or not offer or offer.count < entry.count or offer.price ~= entry.price then
                    self:sellAllFromUi()
                    displayInfoBox('Quick Sell', 'The offer or inventory changed. Review the updated list.')
                    return
                end
                selected[#selected+1] = {ptr=offer.ptr, remaining=entry.count, name=entry.name}
                total = total + entry.count
            end
        end
        local ignoreEquipped = self.ignoreEquipped
        if self:isLegacyMode() then ignoreEquipped = self:legacyIgnoreEquipped() end
        if total == 0 then return end
        window.items:setEnabled(false)
        window.blacklist:setEnabled(false)
        window.confirm:setEnabled(false)
        window.progress:show()
        self.quickSale = {window=window, entries=selected, total=total, done=0, index=1, ignoreEquipped=ignoreEquipped}
        showProgress(self.quickSale)
        self:sendNextQuickSale()
    end
    refresh()
    window:raise()
    window:focus()
end
