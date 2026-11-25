-- Trade options shared by the right-click menu on a trade item and the
-- window's options button, laid out like the standard Tibia trade menu.
-- Choices are remembered between NPCs and sessions.

local SETTING_SORT = 'nexusNpcTradeSortBy'
local SETTING_BAGS = 'nexusNpcTradeBuyInBags'
local SETTING_CAPACITY = 'nexusNpcTradeIgnoreCapacity'
local SETTING_SEARCH = 'nexusNpcTradeShowSearch'
local SETTING_NO_WARNING = 'nexusNpcTradeNoLargeWarning'
local VALID_SORTS = { name = true, price = true, weight = true, amount = true }

-- Trades worth at least this much gold ask for confirmation, unless the
-- "Do not show a warning when trading large amounts" option is checked.
controllerNpcTrader.LARGE_TRADE_WARNING_GOLD = 100000

function controllerNpcTrader:loadTradeSettings()
    local sortBy = g_settings.get(SETTING_SORT)
    self.sortBy = VALID_SORTS[sortBy] and sortBy or controllerNpcTrader.DEFAULT_SORT_BY
    self.buyWithBackpack = g_settings.getBoolean(SETTING_BAGS, controllerNpcTrader.DEFAULT_BUY_WITH_BACKPACK)
    self.ignoreCapacity = g_settings.getBoolean(SETTING_CAPACITY, controllerNpcTrader.DEFAULT_IGNORE_CAPACITY)
    self.showSearchField = g_settings.getBoolean(SETTING_SEARCH, true)
    self.noLargeTradeWarning = g_settings.getBoolean(SETTING_NO_WARNING, false)
end

function controllerNpcTrader:addTradeOptions(menu)
    local function sortOption(text, sort)
        menu:addCheckBox(text, self.sortBy == sort, function()
            self:setSortBy(sort)
        end)
    end
    sortOption(tr('Sort by name'), 'name')
    sortOption(tr('Sort by price'), 'price')
    sortOption(tr('Sort by weight'), 'weight')
    sortOption(tr('Sort by amount'), 'amount')
    menu:addSeparator()
    menu:addCheckBox(tr('Buy in shopping bags'), self.buyWithBackpack, function()
        self:toggleBuyWithBackpack()
    end)
    menu:addCheckBox(tr('Ignore capacity'), self.ignoreCapacity, function()
        self:toggleIgnoreCapacity()
    end)
    if self.tradeMode == controllerNpcTrader.SELL then
        menu:addCheckBox(tr('Sell equipped items'), not self.ignoreEquipped, function()
            self:toggleIgnoreEquipped()
        end)
    end
    menu:addSeparator()
    menu:addCheckBox(tr('Show search field'), self.showSearchField ~= false, function()
        self:toggleShowSearchField()
    end)
    menu:addCheckBox(tr('Do not show a warning when trading large amounts'), self.noLargeTradeWarning, function()
        self:toggleLargeTradeWarning()
    end)
end

function controllerNpcTrader:onOptionsClick()
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    self:addTradeOptions(menu)
    menu:display()
end

-- Items the player owns of this offer (amount sort).
function controllerNpcTrader:getOwnedAmount(item, equipped)
    if not item or not item.ptr then
        return 0
    end
    return self:getSellQuantity(item.ptr, equipped)
end

function controllerNpcTrader:sortTradeItems(items)
    if not items then
        return
    end
    local owned
    if self.sortBy == 'amount' then
        owned = {}
        local equipped = self.ignoreEquipped and self:getEquippedCounts() or nil
        for _, item in ipairs(items) do
            owned[item] = self:getOwnedAmount(item, equipped)
        end
    end
    table.sort(items, function(a, b)
        if self.sortBy == 'price' then
            if a.price ~= b.price then return a.price < b.price end
        elseif self.sortBy == 'weight' then
            if a.weight ~= b.weight then return a.weight < b.weight end
        elseif self.sortBy == 'amount' then
            if owned[a] ~= owned[b] then return owned[a] > owned[b] end
        end
        return a.name:lower() < b.name:lower()
    end)
end

function controllerNpcTrader:setSortBy(sort)
    if not VALID_SORTS[sort] then
        return
    end
    self.sortBy = sort
    g_settings.set(SETTING_SORT, sort)
    self:filterTradeList(self.searchText or "")
end

function controllerNpcTrader:toggleIgnoreCapacity()
    self.ignoreCapacity = not self.ignoreCapacity
    g_settings.set(SETTING_CAPACITY, self.ignoreCapacity)
    self:updateAmount(self.amount)
end

function controllerNpcTrader:toggleBuyWithBackpack()
    self.buyWithBackpack = not self.buyWithBackpack
    g_settings.set(SETTING_BAGS, self.buyWithBackpack)
    self:updateAmount(self.amount)
end

function controllerNpcTrader:toggleIgnoreEquipped()
    self.ignoreEquipped = not self.ignoreEquipped
    self:refreshPlayerGoods()
    self:updateAmount(self.amount)
end

function controllerNpcTrader:toggleShowSearchField()
    self.showSearchField = not (self.showSearchField ~= false)
    g_settings.set(SETTING_SEARCH, self.showSearchField)
    if not self.showSearchField and (self.searchText or "") ~= "" then
        self:clearSearch()
    end
end

function controllerNpcTrader:toggleLargeTradeWarning()
    self.noLargeTradeWarning = not self.noLargeTradeWarning
    g_settings.set(SETTING_NO_WARNING, self.noLargeTradeWarning)
end
