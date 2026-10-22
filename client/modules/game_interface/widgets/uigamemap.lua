UIGameMap = extends(UIMap, 'UIGameMap')

function UIGameMap.create()
    local gameMap = UIGameMap.internalCreate()
    gameMap:setKeepAspectRatio(true)
    gameMap:setMaxZoomIn(1)
    gameMap:setMaxZoomOut(13)
    gameMap:setVisibleDimension({
        width = 15,
        height = 11
    })
    gameMap:setDrawLights(true)
    return gameMap
end

function UIGameMap:onZoomChange()
    local label=self:getChildById('visibleTilesLabel')
    if label then
        local size=self:getVisibleDimension()
        label:setText(string.format('%dx%d',size.width,size.height))
    end
end

function UIGameMap:changeTiles(dx,dy)
    local size=self:getVisibleDimension()
    local width=math.max(1,math.min(17,size.width+dx))
    local height=math.max(1,math.min(13,size.height+dy))
    self:setKeepAspectRatio(true)
    self:setVisibleDimension({width=width,height=height})
    self:onZoomChange()
end

function UIGameMap:zoomIn() self:changeTiles(-2,-2) return true end
function UIGameMap:zoomOut() self:changeTiles(2,2) return true end

function UIGameMap:onGeometryChange()
    if self.zoomLabelUpdate then removeEvent(self.zoomLabelUpdate) end
    self.zoomLabelUpdate=scheduleEvent(function()
        self.zoomLabelUpdate=nil
        if not self:isDestroyed() then self:onZoomChange() end
    end,1)
end

function UIGameMap:onDragEnter(mousePos)
    local tile = self:getTile(mousePos)
    if not tile then
        return false
    end

    local thing = tile:getTopMoveThing()
    if not thing then
        return false
    end

    if thing:isItem() and not thing:isNotMoveable() then
        UIDragIcon:display(thing)
    end

    self.currentDragThing = thing

    g_mouse.pushCursor('target')
    self.allowNextRelease = false
    return true
end

function UIGameMap:onDragLeave(droppedWidget, mousePos)
    self.currentDragThing = nil
    self.hoveredWho = nil
    g_mouse.popCursor('target')
    UIDragIcon:hide()
    return true
end

function UIGameMap:onDrop(widget, mousePos)
    if not self:canAcceptDrop(widget, mousePos) then
        return false
    end

    local tile = self:getTile(mousePos)
    if not tile then
        return false
    end

    local thing = widget.currentDragThing
    local thingPos = thing:getPosition()
    if not thingPos then
        return false
    end

    local thingTile = thing:getTile()
    if thingPos.x ~= 65535 then
        if not thingTile then
            return false
        end
        if thingTile:getThingStackPos(thing) == -1 then
            return false
        end
    end

    local toPos = tile:getPosition()
    if thingPos.x == toPos.x and thingPos.y == toPos.y and thingPos.z == toPos.z then
        return false
    end

    if thing:isItem() and thing:getCount() > 1 then
        modules.game_interface.moveStackableItem(thing, toPos)
    else
        g_game.move(thing, toPos, 1)
    end

    UIDragIcon:hide()
    return true
end

local LOOK_CHORD_DELAY = 90

local function isLookChordButton(button)
    return button == MouseLeftButton or button == MouseRightButton
end

function UIGameMap:lookAtMousePosition(mousePosition)
    local tile = self:getTile(mousePosition)
    local thing = tile and tile:getTopLookThing() or nil
    if thing then
        g_game.look(thing)
        return true
    end
    return false
end

function UIGameMap:onMousePress(mousePosition, mouseButton)
    if not self:isDragging() then
        self.allowNextRelease = true
    end

    if not modules.client_options.getOption('classicControl') or
        g_keyboard.getModifiers() ~= KeyboardNoModifier or not isLookChordButton(mouseButton) then
        return
    end

    local oppositeButton = mouseButton == MouseLeftButton and MouseRightButton or MouseLeftButton
    local pending = self.pendingMouseAction
    local pendingIsChord = pending and pending.button == oppositeButton and
        g_clock.millis() - pending.time <= LOOK_CHORD_DELAY

    if g_mouse.isPressed(oppositeButton) or pendingIsChord then
        if pending then
            removeEvent(pending.event)
            self.pendingMouseAction = nil
        end
        self.lookChordActive = true
        self:lookAtMousePosition(mousePosition)
        return true
    end
end

function UIGameMap:onMouseMove()
    return false
end

function UIGameMap:performMouseAction(mousePosition, mouseButton)
    if not g_game.isOnline() then
        return false
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end

    local autoWalkPos = self:getPosition(mousePosition)
    if not autoWalkPos then
        return false
    end

    local localPlayerPos = player:getPosition()
    if autoWalkPos.z ~= localPlayerPos.z then
        local dz = autoWalkPos.z - localPlayerPos.z
        autoWalkPos.x = autoWalkPos.x + dz
        autoWalkPos.y = autoWalkPos.y + dz
        autoWalkPos.z = localPlayerPos.z
    end

    local lookThing
    local useThing
    local creatureThing
    local attackCreature

    local tile = self:getTile(mousePosition)
    if tile then
        lookThing = tile:getTopLookThing()
        useThing = tile:getTopUseThing()
        creatureThing = tile:getTopCreature(true)
        attackCreature = creatureThing
    end

    if not attackCreature then
        local autoWalkTile = g_map.getTile(autoWalkPos)
        if autoWalkTile then
            attackCreature = autoWalkTile:getTopCreature(true)
        end
    end

    return modules.game_interface.processMouseAction(mousePosition, mouseButton, autoWalkPos, lookThing, useThing,
        creatureThing, attackCreature)
end

function UIGameMap:onMouseRelease(mousePosition, mouseButton)
    if not self.allowNextRelease then
        if self.lookChordActive and not g_mouse.isPressed(MouseLeftButton) and
            not g_mouse.isPressed(MouseRightButton) then
            self.lookChordActive = false
        end
        return true
    end

    if self.lookChordActive then
        self.allowNextRelease = false
        if not g_mouse.isPressed(MouseLeftButton) and not g_mouse.isPressed(MouseRightButton) then
            self.lookChordActive = false
        end
        return true
    end

    if modules.client_options.getOption('classicControl') and
        g_keyboard.getModifiers() == KeyboardNoModifier and isLookChordButton(mouseButton) then
        local pending = self.pendingMouseAction
        if pending and pending.button ~= mouseButton and g_clock.millis() - pending.time <= LOOK_CHORD_DELAY then
            removeEvent(pending.event)
            self.pendingMouseAction = nil
            self.allowNextRelease = false
            self:lookAtMousePosition(mousePosition)
            return true
        end

        local action = {
            button = mouseButton,
            mousePosition = mousePosition,
            time = g_clock.millis()
        }
        action.event = scheduleEvent(function()
            if self.pendingMouseAction ~= action then
                return
            end
            self.pendingMouseAction = nil
            self:performMouseAction(action.mousePosition, action.button)
        end, LOOK_CHORD_DELAY)
        self.pendingMouseAction = action
        self.allowNextRelease = false
        return true
    end

    local ret = self:performMouseAction(mousePosition, mouseButton)
    if ret then
        self.allowNextRelease = false
    end

    return ret
end

function UIGameMap:canAcceptDrop(widget, mousePos)
    if not widget or not widget.currentDragThing then
        return false
    end

    local children = rootWidget:recursiveGetChildrenByPos(mousePos)
    for i = 1, #children do
        local child = children[i]
        if child == self then
            return true
        elseif not child:isPhantom() then
            return false
        end
    end

    error('Widget ' .. self:getId() .. ' not in drop list.')
    return false
end
