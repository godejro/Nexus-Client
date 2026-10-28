local UI
local vocations={'All vocations','Sorcerer','Druid','Paladin','Knight','Monk'}
local vocIds={{},{1,5},{2,6},{3,7},{4,8},{9,10}}
local groups={'All groups','Attack','Healing','Support','Special','Conjure'}
-- Reference visuals only; the active server remains authoritative for combat.
local previewInfo=dofile('/game_cyclopedia/tab/magicalArchives/reference.lua')
local selected,additional=false,false
local function contains(list,value)
    for _,v in ipairs(list or {}) do if v==value then return true end end
    return false
end
local function drawPreview(info)
    local panel=UI.details.preview
    for _,child in ipairs(panel:getChildren()) do if child:getId()~='caption' then child:destroy() end end
    local metadata=previewInfo[info.words] or {}
    local effectId=tonumber(info.effectId) or metadata.effect
    local validEffect=false
    if effectId then
        for _,appearance in pairs(g_things.getThingTypes(ThingCategoryEffect)) do
            if appearance:getId()==effectId then
                validEffect=appearance:getWidth()>0 and appearance:getHeight()>0
                    and appearance:getNumPatternX()>0 and appearance:getNumPatternY()>0
                    and appearance:getAnimationPhases()>0
                break
            end
        end
    end
    panel.caption:setText(validEffect and '' or 'No animation provided by the server assets')
    local grid=g_ui.createWidget('UIWidget',panel)
    grid:setSize({width=96,height=96})
    grid:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter)
    grid:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
    for y=0,2 do for x=0,2 do
        local cell=g_ui.createWidget('UIWidget',grid)
        cell:setSize({width=32,height=32})
        cell:addAnchor(AnchorLeft,'parent',AnchorLeft)
        cell:addAnchor(AnchorTop,'parent',AnchorTop)
        cell:setMarginLeft(x*32) cell:setMarginTop(y*32)
        cell:setBackgroundColor('#9bafb555') cell:setBorderWidth(1) cell:setBorderColor('#b9c6c9')
        if x==1 and y==1 then
            if g_game.getLocalPlayer() then
                local creature=g_ui.createWidget('Creature',cell)
                creature:fill('parent') creature:setOutfit(g_game.getLocalPlayer():getOutfit())
                creature:setDirection(South)
            end
            if validEffect then
                local effect=g_ui.createWidget('Effect',cell)
                effect:fill('parent') effect:setEffectId(effectId) effect:setVirtual(true) effect:setDraggable(false)
            end
        end
    end end
end
local function updateDetails()
    if not UI or UI:isDestroyed() then return end
    if not selected then
        UI.details.name:setText('No matching spells')
        UI.details.words:setText('') UI.details.icon:setImageSource('')
        UI.details.statistics.left:setText('') UI.details.statistics.right:setText('')
        for _,child in ipairs(UI.details.preview:getChildren()) do if child:getId()~='caption' then child:destroy() end end
        UI.details.preview.caption:setText('')
        return
    end
    local info=SpellInfo.Default[selected]
    local stats=previewInfo[info.words] or {}
    UI.details.name:setText(selected..'    Level '..tostring(info.level or 0))
    UI.details.words:setText(info.words or '')
    Spells.applyIcon(UI.details.icon,info)
    UI.details.combat:setOn(not additional) UI.details.additional:setOn(additional)
    if additional then
        local names={}
        for i=2,#vocations do
            if contains(info.vocations,vocIds[i][1]) or contains(info.vocations,vocIds[i][2]) then names[#names+1]=vocations[i] end
        end
        UI.details.statistics.left:setText('Vocation: '..table.concat(names,', ')..'\nPremium: '..(info.premium and 'Yes' or 'No')..'\nSoul: '..tostring(info.soul or 0))
        UI.details.statistics.right:setText('Type: '..tostring(info.type or 'Instant')..'\nTarget: '..(info.needTarget and 'Required' or 'Not required')..'\nSpell ID: '..tostring(info.id))
    else
        local groupNames={} local groupCooldown=0
        for id,duration in pairs(info.group or {}) do groupNames[#groupNames+1]=groups[id+1] or tostring(id) groupCooldown=math.max(groupCooldown,tonumber(duration) or 0) end
        table.sort(groupNames)
        UI.details.statistics.left:setText('Mana: '..tostring(info.mana or 0)..'\nSpell group: '..table.concat(groupNames,', ')..'\nBase power: '..tostring(info.basePower or stats.power or '-')..'\nScales with: '..tostring(info.scalesWith or stats.scale or '-'))
        UI.details.statistics.right:setText('Cooldown: '..tostring((info.exhaustion or 0)/1000)..' s\nGroup cooldown: '..tostring(groupCooldown/1000)..' s\nMagic type: '..tostring(info.magicType or stats.element or '-')..'\nRange: '..((info.range or 0)>0 and (info.range..' sqm') or 'Self'))
    end
    drawPreview(info)
end
local function refresh()
    if not UI or UI:isDestroyed() then return end
    local filter=UI.selection
    local vocation=filter.vocation:getCurrentOption().data or 1
    local group=filter.group:getCurrentOption().data or 1
    local query=filter.search:getText():lower()
    local player=g_game.getLocalPlayer()
    filter.list:destroyChildren()
    local names={}
    for name,info in pairs(SpellInfo.Default) do
        local voc=vocation==1 or contains(info.vocations,0)
        for _,id in ipairs(vocIds[vocation] or {}) do voc=voc or contains(info.vocations,id) end
        if voc and (group==1 or (info.group or {})[group-1])
          and (not filter.level:isChecked() or not player or (info.level or 0)<=player:getLevel())
          and (name:lower():find(query,1,true) or tostring(info.words):lower():find(query,1,true)) then names[#names+1]=name end
    end
    table.sort(names)
    if not contains(names,selected) then selected=names[1] end
    for _,name in ipairs(names) do
        local row=g_ui.createWidget('ArchiveSpellRow',filter.list)
        row:setText(name) row:setTooltip(name..'\n'..SpellInfo.Default[name].words)
        row.spellName=name Spells.applyIcon(row.icon,SpellInfo.Default[name])
        row:setOn(name==selected)
        row.onClick=function()
            selected=name
            for _,other in ipairs(filter.list:getChildren()) do other:setOn(other==row) end
            updateDetails()
        end
        if name==selected then row:focus() end
    end
    updateDetails()
end
function showMagicalArchives(parent)
    UI=g_ui.loadUI('magicalArchives',parent or contentContainer)
    for i,name in ipairs(vocations) do UI.selection.vocation:addOption(name,i) end
    for i,name in ipairs(groups) do UI.selection.group:addOption(name,i) end
    UI.selection.vocation.onOptionChange=refresh UI.selection.group.onOptionChange=refresh
    UI.selection.search.onTextChange=refresh UI.selection.level.onCheckChange=refresh
    UI.details.combat.onClick=function() additional=false updateDetails() end
    UI.details.additional.onClick=function() additional=true updateDetails() end
    if controllerCyclopedia.ui then
        for _,id in ipairs({'CharmsBase','GoldBase','BestiaryTrackerButton','CharmsBase1410'}) do
            local child=controllerCyclopedia.ui:getChildById(id) if child then child:hide() end
        end
    end
    refresh() updateDetails() UI:show()
    return UI
end
