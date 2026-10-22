-- @docclass
UIMiniWindowContainer = extends(UIWidget, 'UIMiniWindowContainer')

function UIMiniWindowContainer.create()
    local container = UIMiniWindowContainer.internalCreate()
    container.scheduledWidgets = {}
    container:setFocusable(false)
    container:setPhantom(true)
    return container
end

-- TODO: connect to window onResize event
-- TODO: try to resize another widget?
-- TODO: try to find another panel?
function UIMiniWindowContainer:fitAll(noRemoveChild)
    if not self:isVisible() then
        return
    end

    if self.ignoreFillAll then
        return
    end

    if not noRemoveChild then
        local children = self:getChildren()
        if #children > 0 then
            noRemoveChild = children[#children]
        else
            return
        end
    end

    local sumHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() then
            sumHeight = sumHeight + children[i]:getHeight()
        end
    end

    local selfHeight = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom())
    if sumHeight <= selfHeight then
        return
    end

    local removeChildren = {}

    local overflow = sumHeight - selfHeight
    local childIndex = self:getChildIndex(noRemoveChild)

    -- While a miniwindow grows, first give it space by shrinking the first
    -- visible miniwindow below it. This keeps the vertical layout stable and
    -- lets containers stop naturally at their one-row minimum height.
    if childIndex then
        for i = childIndex + 1, #children do
            local child = children[i]
            if child:isVisible() then
                if child:isResizeable() and not child:isOn() then
                    local minimumHeight = child:getMinimumHeight()
                    local shrinkBy = math.min(overflow, math.max(child:getHeight() - minimumHeight, 0))
                    if shrinkBy > 0 then
                        self.ignoreFillAll = true
                        child:setHeight(child:getHeight() - shrinkBy)
                        self.ignoreFillAll = false
                        sumHeight = sumHeight - shrinkBy
                        overflow = overflow - shrinkBy
                    end
                end
                break
            end
        end
    end

    if overflow <= 0 then
        return
    end

    -- Once the window below reaches its minimum, clamp the window being
    -- resized instead of closing panels or scheduling a visible size jump.
    if noRemoveChild:isResizeable() and not noRemoveChild:isOn() then
        local minimumHeight = noRemoveChild:getMinimumHeight()
        local targetHeight = math.max(noRemoveChild:getHeight() - overflow, minimumHeight)
        local shrinkBy = noRemoveChild:getHeight() - targetHeight
        if shrinkBy > 0 then
            self.ignoreFillAll = true
            noRemoveChild:setHeight(targetHeight)
            self.ignoreFillAll = false
            sumHeight = sumHeight - shrinkBy
        end
    end

    if sumHeight <= selfHeight then
        return
    end

    -- try to remove no-save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and not child.save and not child.fixedPanel then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    -- try to remove save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and child:isVisible() and not child.fixedPanel then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    -- close widgets
    for i = 1, #removeChildren do
        removeChildren[i]:close()
    end
end

function UIMiniWindowContainer:fits(child, minContentHeight, maxContentHeight)
    if self.ignoreFillAll then
        return 0
    end

    local containerPanel = child:getChildById('contentsPanel')
    local indispensableHeight = containerPanel:getMarginTop() + containerPanel:getMarginBottom() +
        containerPanel:getPaddingTop() + containerPanel:getPaddingBottom()

    local totalHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() then
            totalHeight = totalHeight + children[i]:getHeight()
        end
    end

    local available = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom()) - totalHeight

    if maxContentHeight > 0 and available >= (maxContentHeight + indispensableHeight) then
        return maxContentHeight + indispensableHeight
    elseif available >= (minContentHeight + indispensableHeight) then
        return available
    else
        return -1
    end
end

function UIMiniWindowContainer:onDrop(widget, mousePos)
    if (self.onlyPhantomDrop and not (widget.moveOnlyToMain)) or (widget.moveOnlyToMain and not (self.onlyPhantomDrop)) then
        return true
    end

    if widget.UIMiniWindowContainer then
        local oldParent = widget:getParent()
        if oldParent == self then
            return true
        end

        if oldParent then
            oldParent:removeChild(widget)
        end

        if widget.movedWidget and self:getChildIndex(widget.movedWidget) then
            local index = self:getChildIndex(widget.movedWidget)
            if widget.movedWidget.fixedPanel then index=index+1
            else index=index+(widget.movedIndex or 0) end
            self:insertChild(index, widget)
        else
            self:addChild(widget)
        end

        -- Fixed top panels (including both halves of the expanded minimap)
        -- cannot be displaced by a saved position or a drag over their top half.
        local first=self:getChildByIndex(1)
        if first==widget and not widget.fixedPanel then
            for _,child in ipairs(self:getChildren()) do
                if child.fixedPanel then self:moveChildToIndex(child,1) end
            end
        end

        if widget:getId() == "botWindow" and
            (widget:getParent():getId() == "gameLeftPanel" or widget:getParent():getId() == "gameLeftExtraPanel" or
                widget:getParent():getId() == "gameRightExtraPanel") then
            widget:getParent():setWidth(190)
        end
        self:fitAll(widget)
        widget.dropContainer=self
        return true
    end
end

function UIMiniWindowContainer:swapInsert(widget, index)
    local oldParent = widget:getParent()
    local oldIndex = self:getChildIndex(widget)

    if oldParent == self and oldIndex ~= index then
        local oldWidget = self:getChildByIndex(index)
        if oldWidget then
            self:removeChild(oldWidget)
            self:insertChild(oldIndex, oldWidget)
        end
        self:removeChild(widget)
        self:insertChild(index, widget)
    end
end

function UIMiniWindowContainer:scheduleInsert(widget, index)
    if index - 1 > self:getChildCount() then
        if self.scheduledWidgets[index] then
            pdebug('replacing scheduled widget id ' .. widget:getId())
        end
        self.scheduledWidgets[index] = widget
    else
        local oldParent = widget:getParent()
        if oldParent ~= self then
            if oldParent then
                oldParent:removeChild(widget)
            end
            self:insertChild(index, widget)

            while true do
                local placed = false
                for nIndex, nWidget in pairs(self.scheduledWidgets) do
                    if nIndex - 1 <= self:getChildCount() then
                        self:insertChild(nIndex, nWidget)
                        self.scheduledWidgets[nIndex] = nil
                        placed = true
                        break
                    end
                end
                if not placed then
                    break
                end
            end
        end
    end
end

function UIMiniWindowContainer:order()
    local children = self:getChildren()
    for i = 1, #children do
        if not children[i].miniLoaded then
            return
        end
    end

    for i = 1, #children do
        if children[i].miniIndex then
            self:swapInsert(children[i], children[i].miniIndex)
        end
    end
end

function UIMiniWindowContainer:saveChildren()
    local children = self:getChildren()
    local ignoreIndex = 0
    for i = 1, #children do
        if children[i].save then
            children[i]:saveParentIndex(self:getId(), i - ignoreIndex)
        else
            ignoreIndex = ignoreIndex + 1
        end
    end
end
