-- ACCOUNT INFO: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('account_info', 'ACCOUNT INFO', 14, false)

-- ==================== GUI / LAYOUT ====================
NexusBot.embeddedUI = NexusBot.embeddedUI or {}
NexusBot.embeddedUI['account'] = [=[
NexusWindow
  id: nexusAccountInfo
  size: 390 430
  text: ACCOUNT INFO
  NexusIconButton
    id: closeButton
    anchors.top: parent.top
    anchors.right: parent.right
    margin-top: -32
    text: X
    color: #fa6275
  NexusPanel
    id: portrait
    anchors.top: level.bottom
    anchors.left: parent.left
    height: 160
    width: 138
    UICreature
      id: outfit
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      size: 110 110
      phantom: true
  NexusHeader
    id: character
    anchors.top: mana.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 0
    height: 44
    text-offset: 0 12
  NexusMutedLabel
    id: level
    anchors.top: character.bottom
    anchors.left: character.left
    anchors.right: parent.right
  UIProgressBar
    id: health
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 0
    height: 22
    background-color: #bb3c57
    color: #ffffff
    font: verdana-11px-antialised
    border-width: 1
    border-color: #f07188
  UIProgressBar
    id: mana
    anchors.top: health.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 22
    background-color: #285fb4
    color: #ffffff
    font: verdana-11px-antialised
    border-width: 1
    border-color: #68a8ff
  Panel
    id: equipment
    anchors.top: portrait.top
    anchors.left: portrait.right
    anchors.right: parent.right
    margin-top: 0
    margin-left: 22
    height: 152
  Panel
    id: changer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 112
    layout:
      type: verticalBox
      spacing: 4
]=]
local M=NexusBot.Features.Modern
local U=NexusBot.UI
local R=M.bindings
local H=M.shared
local safe=H.safe
local alarmSound=H.alarmSound
local config=H.config
local isAlive=H.isAlive
local ownTimer=H.ownTimer
local engineWindow=H.engineWindow
local formWindow=H.formWindow
local sortedKeys=H.sortedKeys
local title=H.title
local fields=H.fields
local managedToggle=H.managedToggle
local bindRuntime=H.bindRuntime

local function accountWindow()
  local w=NexusBot.loadUI('account',rootWidget)
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
  local slots={}
  local placement={{1,0},{0,1},{2,1},{1,1},{2,2},{0,2},{1,2},{1,3},{0,3},{2,3}}
  for slot=1,10 do
    local item=g_ui.createWidget('Item',w.equipment)
    item:setSize({width=34,height=34}) item:setVirtual(true)
    item:addAnchor(AnchorTop,'parent',AnchorTop) item:addAnchor(AnchorLeft,'parent',AnchorLeft)
    item:setMarginTop(placement[slot][2]*38-(placement[slot][1]~=1 and 19 or 0)) item:setMarginLeft(placement[slot][1]*38)
    slots[slot]=item
  end
  local cfg=category.config()
  U.toggle(w.changer,'Local outfit changer',cfg.enabled,function(value) cfg.enabled=value category.apply() end)
  local idField=U.numberInput(w.changer,'Outfit ID',cfg.id or 0,0,65535,function(id) cfg.id=id category.apply() end)
  U.button(w.changer,'Browse outfits',function()
    local options={}
    for _,thing in pairs(g_things.getThingTypes(ThingCategoryCreature)) do
      local id=thing:getId()
      if id>0 then options[#options+1]={data=id} end
    end
    table.sort(options,function(a,b) return a.data<b.data end)
    NexusBot.WindowManager.close('outfit_picker')
    local picker=NexusBot.loadUI('selectors',rootWidget)
    picker:setText('OUTFITS') picker:setSize({width=360,height=414})
    picker.closeButton:setMarginTop(-32) picker.closeButton:setMarginRight(0)
    picker.buttons.apply:destroy() picker.buttons.cancel:destroy() picker.buttons:hide()
    picker.filters:breakAnchors()
    picker.filters:addAnchor(AnchorBottom,'parent',AnchorBottom)
    picker.filters:addAnchor(AnchorHorizontalCenter,'parent',AnchorHorizontalCenter)
    picker.filters:setWidth(246) picker.filters:setHeight(26)
    picker.list:breakAnchors()
    picker.list:addAnchor(AnchorTop,'search',AnchorBottom)
    picker.list:addAnchor(AnchorLeft,'parent',AnchorLeft)
    picker.list:addAnchor(AnchorRight,'parent',AnchorRight)
    picker.list:addAnchor(AnchorBottom,'filters',AnchorTop)
    U.scrollbar(picker.list)
    local page,selected=1,cfg.id
    local render
    U.button(picker.filters,'Previous',function() page=math.max(1,page-1) render() end):setWidth(90)
    local count=U.label(picker.filters,'') count:setWidth(60) count:setTextAlign(AlignCenter)
    U.button(picker.filters,'Next',function() page=page+1 render() end):setWidth(90)
    render=function()
      U.clear(picker.list)
      local filtered={}
      for _,option in ipairs(options) do
        if tostring(option.data):find(picker.search:getText(),1,true) then filtered[#filtered+1]=option.data end
      end
      local pages=math.max(1,math.ceil(#filtered/100)) page=math.min(page,pages)
      count:setText(page..' / '..pages)
      for i=(page-1)*100+1,math.min(page*100,#filtered) do
        local id=filtered[i]
        local row=g_ui.createWidget('NexusSelectorRow',picker.list)
        row:setHeight(54) row.item:hide() row.spellIcon:hide()
        row.title:setText('Outfit '..id) row.title:setMarginLeft(28) row.detail:setText('')
        local preview=g_ui.createWidget('UICreature',row)
        preview:setSize({width=46,height=46}) preview:setPhantom(true)
        preview:addAnchor(AnchorLeft,'parent',AnchorLeft)
        preview:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
        preview:setOutfit({type=id,head=0,body=0,legs=0,feet=0,addons=0,mount=0})
        preview:setDirection(South)
        row.onClick=function() selected=id idField:setValue(id) cfg.id=id category.apply() NexusBot.Storage.touch() row:focus() end
        row.onDoubleClick=function() idField:setValue(id) picker:destroy() return true end
      end
      picker.list:updateScrollBars() picker.list.verticalScrollBar:setValue(0)
    end
    picker.search.onTextChange=function() page=1 render() end
    picker.closeButton.onClick=function() picker:hide() end picker.onEscape=picker.closeButton.onClick
    render() NexusBot.WindowManager.attach('outfit_picker',picker)
  end)
  local lastOutfit
  local function refresh()
    local player=g_game.getLocalPlayer()
    if not player then w.character:setText('Offline') return end
    w.character:setText(player:getName()) w.level:setText('LEVEL '..player:getLevel())
    local maxMana=player:getMaxMana()
    w.health:setPercent(player:getHealthPercent()) w.health:setText('HP  '..player:getHealth()..' / '..player:getMaxHealth())
    w.mana:setPercent(maxMana>0 and player:getMana()*100/maxMana or 0) w.mana:setText('MP  '..player:getMana()..' / '..maxMana)
    local outfit=player:getOutfit()
    local signature=json.encode(outfit)
    if signature~=lastOutfit then
      w.portrait.outfit:setOutfit(outfit)
      safe(function() w.portrait.outfit:getCreature():setStaticWalking(1000) end)
      safe(function() w.portrait.outfit:setDirection(South) end)
      lastOutfit=signature
    end
    for slot,item in ipairs(slots) do item:setItem(player:getInventoryItem(slot)) end
  end
  refresh() ownTimer(w,refresh,500) return w
end




M.windows.accountWindow=accountWindow
category.open = accountWindow

-- ==================== LOGIC / RUNTIME ====================
local observedPlayer,serverOutfit,changing,playerEvents,gameEvents
function category.config()
  local settings=NexusBot.Storage.get().settings
  settings.localOutfit=settings.localOutfit or {enabled=false,id=128}
  return settings.localOutfit
end
function category.apply()
  if changing or not observedPlayer or not serverOutfit then return end
  local cfg=category.config()
  local outfit=NexusBot.copy(serverOutfit)
  if cfg.enabled then
    local id=tonumber(cfg.id) or 0
    local thing=id>0 and g_things.getThingType(id,ThingCategoryCreature)
    if not thing or thing:getId()~=id then return end
    outfit.type=cfg.id outfit.auxType=0 outfit.addons=0 outfit.mount=0
  end
  changing=true
  local ok,err=pcall(function() observedPlayer:setOutfit(outfit) end)
  changing=false
  if not ok then NexusBot.Logger.warn('Local outfit',err) end
end
local function detach()
  if observedPlayer then
    if playerEvents then disconnect(observedPlayer,playerEvents) end
    if serverOutfit then pcall(function() observedPlayer:setOutfit(serverOutfit) end) end
  end
  observedPlayer=nil serverOutfit=nil playerEvents=nil
end
local function attach()
  detach()
  observedPlayer=g_game.getLocalPlayer()
  if not observedPlayer then return end
  serverOutfit=NexusBot.copy(observedPlayer:getOutfit())
  playerEvents={onOutfitChange=function(_,outfit)
    if changing then return end
    serverOutfit=NexusBot.copy(outfit) category.apply()
  end}
  connect(observedPlayer,playerEvents) category.apply()
end
category.init=function()
  gameEvents={onGameStart=attach,onGameEnd=detach}
  connect(g_game,gameEvents) attach()
end
category.terminate=function()
  detach()
  if gameEvents then disconnect(g_game,gameEvents) gameEvents=nil end
end
