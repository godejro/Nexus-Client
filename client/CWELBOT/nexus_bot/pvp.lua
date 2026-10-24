-- PVP: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('pvp', 'PVP', 10, false)

-- ==================== GUI / LAYOUT ====================
category.layouts = {
  layout_1 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Smart Push
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_2 = [=[
MainWindow
  text: Smart Push
  size: 390 270
  @onEscape: self:hide()
  Label
    id: hotkeyLabel
    anchors.left: parent.left
    anchors.top: parent.top
    text: Push hotkey
  TextEdit
    id: hotkey
    anchors.left: parent.left
    anchors.top: hotkeyLabel.bottom
    margin-top: 3
    width: 70
  CheckBox
    id: normalMode
    anchors.left: parent.left
    anchors.top: hotkey.bottom
    margin-top: 8
    width: 155
    text: Normal MW
  CheckBox
    id: randomMode
    anchors.left: normalMode.right
    anchors.top: normalMode.top
    margin-left: 8
    width: 155
    text: Random MW
  CheckBox
    id: usePushRune
    anchors.left: parent.left
    anchors.top: normalMode.bottom
    margin-top: 4
    width: 155
    text: Use push rune
  CheckBox
    id: rewallPlayer
    anchors.left: usePushRune.right
    anchors.top: usePushRune.top
    margin-left: 8
    width: 155
    text: Rewall player
  Label
    id: pushRuneLabel
    anchors.left: parent.left
    anchors.top: usePushRune.bottom
    margin-top: 8
    text: Push rune ID
  TextEdit
    id: pushRuneId
    anchors.left: parent.left
    anchors.top: pushRuneLabel.bottom
    margin-top: 3
    width: 70
  Label
    id: durationLabel
    anchors.left: parent.horizontalCenter
    anchors.top: usePushRune.bottom
    margin-top: 8
    text: MW duration
  TextEdit
    id: duration
    anchors.left: parent.horizontalCenter
    anchors.top: durationLabel.bottom
    margin-top: 3
    width: 70
  Label
    id: mwRuneLabel
    anchors.left: parent.left
    anchors.top: pushRuneId.bottom
    margin-top: 7
    text: Magic Wall rune ID
  TextEdit
    id: mwRuneId
    anchors.left: parent.left
    anchors.top: mwRuneLabel.bottom
    margin-top: 3
    width: 70
  Label
    id: pushTimerLabel
    anchors.left: parent.horizontalCenter
    anchors.top: pushRuneId.bottom
    margin-top: 7
    text: Push timer
  TextEdit
    id: pushTimer
    anchors.left: parent.horizontalCenter
    anchors.top: pushTimerLabel.bottom
    margin-top: 3
    width: 70
  Label
    id: wallIdsLabel
    anchors.left: parent.left
    anchors.top: mwRuneId.bottom
    margin-top: 7
    text: Magic Wall object IDs
  TextEdit
    id: wallIds
    anchors.left: parent.left
    anchors.top: wallIdsLabel.bottom
    margin-top: 3
    width: 140
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 22
    text: Close
]=],
  layout_3 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Fast Push
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_4 = [=[
MainWindow
  text: Fast Push
  size: 350 125
  @onEscape: self:hide()
  CheckBox
    id: takeStepBack
    anchors.left: parent.left
    anchors.top: parent.top
    width: 150
    text: Take step back
  CheckBox
    id: diagonalPush
    anchors.left: takeStepBack.right
    anchors.top: takeStepBack.top
    margin-left: 8
    width: 150
    text: Diagonal push
  Label
    anchors.left: parent.left
    anchors.top: takeStepBack.bottom
    margin-top: 10
    text: Target/destination hotkey
  TextEdit
    id: hotkey
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 70
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 25
    text: Close
]=],
  layout_5 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Wall Keeper
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_6 = [=[
MainWindow
  text: Wall Keeper
  size: 350 220
  @onEscape: self:hide()
  Label
    anchors.left: parent.left
    anchors.top: parent.top
    text: Hotkey
  TextEdit
    id: hotkey
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 70
  CheckBox
    id: modeMw
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    width: 145
    text: Magic Wall
  CheckBox
    id: modeWg
    anchors.left: modeMw.right
    anchors.top: modeMw.top
    margin-left: 8
    width: 145
    text: Wild Growth
  Label
    id: mwRuneLabel
    anchors.left: parent.left
    anchors.top: modeMw.bottom
    margin-top: 8
    text: Magic Wall rune ID
  TextEdit
    id: mwRuneId
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 50
  Label
    id: mwWallIdsLabel
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 7
    text: Magic Wall object IDs
  TextEdit
    id: mwWallIds
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 100
  Label
    id: wgRuneLabel
    anchors.left: modeWg.left
    anchors.top: modeWg.bottom
    margin-top: 8
    text: Wild Growth rune ID
  TextEdit
    id: wgRuneId
    anchors.left: modeWg.left
    anchors.top: wgRuneLabel.bottom
    margin-top: 3
    width: 50
  Label
    id: wgWallIdsLabel
    anchors.left: modeWg.left
    anchors.top: wgRuneId.bottom
    margin-top: 7
    text: Wild Growth object IDs
  TextEdit
    id: wgWallIds
    anchors.left: modeWg.left
    anchors.top: wgWallIdsLabel.bottom
    margin-top: 3
    width: 100
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 25
    text: Close
]=],
  layout_7 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Atomic Flower
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_8 = [=[
MainWindow
  text: Atomic Flower
  size: 300 176
  @onEscape: self:hide()
  Label
    anchors.left: parent.left
    anchors.top: parent.top
    text: Hotkey
  TextEdit
    id: hotkey
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    text: Magic Wall object ID
  TextEdit
    id: wallId
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    text: Flower item ID
  TextEdit
    id: flowerId
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 22
    text: Close
]=],
  layout_9 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Atomic Anti Push
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_10 = [=[
MainWindow
  text: Atomic Anti Push
  size: 280 145
  @onEscape: self:hide()
  Label
    anchors.left: parent.left
    anchors.top: parent.top
    text: Item ID
  TextEdit
    id: itemId
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 100
  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    text: Amount
  TextEdit
    id: amount
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 100
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 22
    text: Close
]=],
  layout_11 = [=[
Panel
  height: 19
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Atomic Trash Mouse
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
]=],
  layout_12 = [=[
MainWindow
  text: Atomic Trash Mouse
  size: 300 176
  @onEscape: self:hide()
  Label
    anchors.left: parent.left
    anchors.top: parent.top
    text: Hotkey
  TextEdit
    id: hotkey
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    text: Item ID
  TextEdit
    id: itemId
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Label
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 8
    text: Amount per move
  TextEdit
    id: amount
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 3
    width: 150
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 22
    text: Close
]=],
  layout_13 = [=[
Panel
  height: 43
  BotSwitch
    id: enabled
    anchors.left: parent.left
    anchors.top: parent.top
    width: 130
    height: 18
    text: Atomic Protection
  Button
    id: edit
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
    margin-left: 3
    height: 18
    text: Edit
  Label
    id: status
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: enabled.bottom
    margin-top: 3
    height: 19
    text: Disabled
]=],
  layout_14 = [=[
MainWindow
  text: Atomic Protection
  size: 510 280
  @onEscape: self:hide()
  Panel
    id: stoneSkinCard
    anchors.left: parent.left
    anchors.top: parent.top
    width: 235
    height: 220
    border-width: 1
    border-color: #666666
    background-color: #202020
  Panel
    id: mightRingCard
    anchors.right: parent.right
    anchors.top: parent.top
    width: 235
    height: 220
    border-width: 1
    border-color: #666666
    background-color: #202020
  Label
    id: stoneSkinLabel
    anchors.left: stoneSkinCard.left
    anchors.right: stoneSkinCard.right
    anchors.top: stoneSkinCard.top
    margin-top: 7
    text-align: center
    text: AMULET | Charges: -
  BotItem
    id: stoneSkinItem
    anchors.left: stoneSkinCard.left
    anchors.top: stoneSkinLabel.bottom
    margin-left: 12
    margin-top: 8
    size: 34 34
  Label
    anchors.left: stoneSkinItem.right
    anchors.verticalCenter: stoneSkinItem.verticalCenter
    margin-left: 8
    text: Tank
  BotItem
    id: normalAmuletItem
    anchors.left: stoneSkinCard.left
    anchors.top: stoneSkinItem.bottom
    margin-left: 12
    margin-top: 7
    size: 34 34
  Label
    anchors.left: normalAmuletItem.right
    anchors.verticalCenter: normalAmuletItem.verticalCenter
    margin-left: 8
    text: Main
  Label
    id: stoneSkinLowLabel
    anchors.left: stoneSkinCard.left
    anchors.top: normalAmuletItem.bottom
    margin-left: 12
    margin-top: 11
    text: HP <=
  TextEdit
    id: stoneSkinHp
    anchors.left: stoneSkinLowLabel.right
    anchors.verticalCenter: stoneSkinLowLabel.verticalCenter
    margin-left: 6
    width: 42
  Label
    id: stoneSkinHighLabel
    anchors.left: stoneSkinHp.right
    anchors.verticalCenter: stoneSkinLowLabel.verticalCenter
    margin-left: 12
    text: Normal HP >=
  TextEdit
    id: stoneSkinRestoreHp
    anchors.left: stoneSkinHighLabel.right
    anchors.verticalCenter: stoneSkinLowLabel.verticalCenter
    margin-left: 6
    width: 42
  CheckBox
    id: stoneSkinUseMana
    anchors.left: stoneSkinCard.left
    anchors.top: stoneSkinLowLabel.bottom
    margin-left: 12
    margin-top: 10
    width: 205
    text: Use Mana instead of HP
  CheckBox
    id: alwaysStoneSkin
    anchors.left: stoneSkinUseMana.left
    anchors.top: stoneSkinUseMana.bottom
    margin-top: 5
    width: 205
    text: Always use tank
  CheckBox
    id: refillStoneSkin
    anchors.left: alwaysStoneSkin.left
    anchors.top: alwaysStoneSkin.bottom
    margin-top: 5
    width: 82
    text: Auto refill disabled
  Label
    anchors.left: refillStoneSkin.right
    anchors.verticalCenter: refillStoneSkin.verticalCenter
    margin-left: 4
    text: Buy below
  TextEdit
    id: stoneSkinBuyBelow
    anchors.left: prev.right
    anchors.verticalCenter: refillStoneSkin.verticalCenter
    margin-left: 5
    width: 42
  Label
    id: mightRingLabel
    anchors.left: mightRingCard.left
    anchors.right: mightRingCard.right
    anchors.top: mightRingCard.top
    margin-top: 7
    text-align: center
    text: RING | Charges: -
  BotItem
    id: mightRingItem
    anchors.left: mightRingCard.left
    anchors.top: mightRingLabel.bottom
    margin-left: 12
    margin-top: 8
    size: 34 34
  Label
    anchors.left: mightRingItem.right
    anchors.verticalCenter: mightRingItem.verticalCenter
    margin-left: 8
    text: Tank
  BotItem
    id: normalRingItem
    anchors.left: mightRingCard.left
    anchors.top: mightRingItem.bottom
    margin-left: 12
    margin-top: 7
    size: 34 34
  Label
    anchors.left: normalRingItem.right
    anchors.verticalCenter: normalRingItem.verticalCenter
    margin-left: 8
    text: Main
  Label
    id: mightRingLowLabel
    anchors.left: mightRingCard.left
    anchors.top: normalRingItem.bottom
    margin-left: 12
    margin-top: 11
    text: HP <=
  TextEdit
    id: mightRingHp
    anchors.left: mightRingLowLabel.right
    anchors.verticalCenter: mightRingLowLabel.verticalCenter
    margin-left: 6
    width: 42
  Label
    id: mightRingHighLabel
    anchors.left: mightRingHp.right
    anchors.verticalCenter: mightRingLowLabel.verticalCenter
    margin-left: 12
    text: Normal HP >=
  TextEdit
    id: mightRingRestoreHp
    anchors.left: mightRingHighLabel.right
    anchors.verticalCenter: mightRingLowLabel.verticalCenter
    margin-left: 6
    width: 42
  CheckBox
    id: mightRingUseMana
    anchors.left: mightRingCard.left
    anchors.top: mightRingLowLabel.bottom
    margin-left: 12
    margin-top: 10
    width: 205
    text: Use Mana instead of HP
  CheckBox
    id: alwaysMightRing
    anchors.left: mightRingUseMana.left
    anchors.top: mightRingUseMana.bottom
    margin-top: 5
    width: 205
    text: Always use tank
  CheckBox
    id: refillMightRing
    anchors.left: alwaysMightRing.left
    anchors.top: alwaysMightRing.bottom
    margin-top: 5
    width: 82
    text: Auto refill disabled
  Label
    anchors.left: refillMightRing.right
    anchors.verticalCenter: refillMightRing.verticalCenter
    margin-left: 4
    text: Buy below
  TextEdit
    id: mightRingBuyBelow
    anchors.left: prev.right
    anchors.verticalCenter: refillMightRing.verticalCenter
    margin-left: 5
    width: 42
  Button
    id: close
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 70 22
    text: Close
]=],
}
NexusBot.Features.Pvp={}
local P=NexusBot.Features.Pvp
P.openSettings={}
function P.closeSettings()
  for window in pairs(P.openSettings) do if not window:isDestroyed() then window:hide() end end
  P.openSettings={}
end
function P.modernLayout(text)
  text=text:gsub('\n([ ]+)BotSwitch\n','\n%1NexusToggle\n')
  if not text:match('^%s*MainWindow') then return text end
  text=text:gsub('^(%s*)MainWindow','%1NexusWindow',1)
  for old,new in pairs({Button='NexusButton',TextEdit='NexusTextInput',SpinBox='NexusNumberInput',ComboBox='NexusComboBox'}) do
    text=text:gsub('\n([ ]+)'..old..'\n','\n%1'..new..'\n')
  end
  return text
end
function P.styleLegacyConfig(widget)
  local class=widget:getClassName()
  local target=({UIButton='NexusButton',UITextEdit='NexusTextInput',UIComboBox='NexusComboBox'})[class]
  if target then
    local style=g_ui.getStyle(target)
    local visual={}
    for _,key in ipairs({'font','color','image-source','image-border','background-color','border-color','border-width','text-align','$hover !disabled','$focus','$disabled'}) do
      visual[key]=style[key]
    end
    widget:mergeStyle(visual)
  end
  for _,child in ipairs(widget:getChildren()) do P.styleLegacyConfig(child) end
end
local specs={
  {'smart_push','Smart Push','Smart Push'}, {'fast_push','Fast Push','Fast Push'},
  {'wall_keeper','Wall Keeper','Wall Keeper'}, {'flower','Flower Block','Atomic Flower'},
  {'anti_push','Anti Push','Atomic Anti Push'}, {'trash','Trash Mouse','Atomic Trash Mouse'}
}
function P.openConfig(entry,name)
  local config=entry.config
  if not config or config:isDestroyed() then return end
  if not entry.legacy then NexusBot.WindowManager.track('pvp:'..name,config) end
  if entry.edit and entry.edit.onClick then entry.edit:onClick() end
  if not entry.legacy then P.openSettings[config]=true config:show() config:raise() config:focus() return end
  local positionKey='pvp_config:'..name
  NexusBot.WindowManager.close(positionKey)
  local w=NexusBot.loadUI('integration',rootWidget) w:setText(name)
  w:setSize({width=math.max(390,config:getWidth()+32),height=math.max(220,config:getHeight()+64)})
  w.content:hide()
  local position=config:getPosition()
  local oldClose=config.close and config.close.onClick
  P.styleLegacyConfig(config)
  if config.close then config.close:hide() config.close:setHeight(0) end
  -- Child coordinates are relative to the wrapper, not the desktop. Using
  -- the wrapper's screen position pushed older vBot editors off-screen.
  config:setParent(w) config:breakAnchors() config:setPosition({x=16,y=42}) config:setVisible(true)
  config:addAnchor(AnchorTop,'parent',AnchorTop) config:addAnchor(AnchorLeft,'parent',AnchorLeft)
  w.onDestroy=function()
    if not config:isDestroyed() and not entry.owner:isDestroyed() then
      if config.close then config.close.onClick=oldClose end
      config:setParent(entry.owner) config:breakAnchors() config:setPosition(position)
    end
  end
  if config.close then config.close.onClick=function() w:destroy() return true end end
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
  NexusBot.WindowManager.attach(positionKey,w)
end
function P.open()
  local U=NexusBot.UI
  local w=NexusBot.loadUI('integration',rootWidget) w:setText('PVP') w:setSize({width=470,height=410})
  w.content.heading:hide() w.content.heading:setHeight(0)
  w.content.status:hide()
  w.closeButton.onClick=function() w:destroy() return true end w.onEscape=w.closeButton.onClick
  U.button(w.content.list,'Combo Bot',function() NexusBot.Features.Combo.open() end)
  local runtime=P.runtime()
  if not runtime then U.label(w.content.list,'Load a bot profile to access PvP scripts.') return w end
  local rows={}
  for _,spec in ipairs(specs) do
    local entry,err=P.acquire(runtime,spec)
    local row=g_ui.createWidget('NexusIntegrationRow',w.content.list) row.name:setText(spec[2])
    if entry then
      row.enabled:setOn(entry.switch:isOn())
      row.enabled.onClick=function()
        if entry.switch:isDestroyed() then return end
        entry.switch:onClick() row.enabled:setOn(entry.switch:isOn())
        if entry.switch:isOn() then
          category.setEnabled(true)
          NexusBot.setEnabled(true)
          NexusBot.Features.Modern.managed['pvp:'..spec[1]]={setOff=function() if not entry.switch:isDestroyed() and entry.switch:isOn() then entry.switch:onClick() end end}
        end
      end
      row.edit.onClick=function() P.openConfig(entry,spec[2]) end
      rows[#rows+1]={entry=entry,widget=row.enabled}
    else row.enabled:setEnabled(false) row.edit:setEnabled(false) row:setTooltip(nil) end
  end
  local timer=NexusBot.Scheduler.every(300,function()
    if w:isDestroyed() then return end
    if not NexusBot.botSandbox and P.runtime()~=runtime then w:destroy() return end
    for _,row in ipairs(rows) do if not row.entry.switch:isDestroyed() then row.widget:setOn(row.entry.switch:isOn()) end end
  end,'PvP status')
  w.onDestroy=function() NexusBot.Scheduler.cancel(timer) end
  return w
end

category.open = P.open
category.getEnabled=function() return NexusBot.Storage.get().settings.pvpEnabled==true end
category.setEnabled=function(value)
  NexusBot.Storage.get().settings.pvpEnabled=value==true
  if not value and NexusBot.Features.Combo then NexusBot.Features.Combo.stop() end
  if value and NexusBot.Features.Combo and NexusBot.Features.Combo.config().enabled then NexusBot.Features.Combo.running=true end
  local runtime=P.runtime()
  if runtime then
    for _,spec in ipairs(specs) do
      local entry=P.acquire(runtime,spec)
      if entry and entry.legacy and not value and entry.switch:isOn() then entry.switch:onClick() end
    end
  end
end

-- COMBO: local spell events only; no external room service or forced follow.
NexusBot.Features.Combo={running=false,queue={},seen={}}
do
local B=NexusBot.Features.Combo local U=NexusBot.UI
local function normalize(value) return tostring(value or ''):lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ') end
function B.config()
  local data=NexusBot.Storage.get() data.integrations=data.integrations or {}
  data.integrations.combo=data.integrations.combo or {rules={}}
  return data.integrations.combo
end
function B.clear() B.queue={} B.seen={} end
function B.stop() B.running=false B.clear() end
function B.start()
  B.clear() B.config().enabled=true NexusBot.Categories.setEnabled(category,true) B.running=true NexusBot.Storage.touch()
end
function B.open()
  NexusBot.WindowManager.close('pvp:combo')
  local w,list=NexusBot.Features.Modern.shared.formWindow('COMBO BOT',410) w:setWidth(390)
  local power=U.toggle(list,'Local combo',B.config().enabled==true,function(v)
    if v then B.start() else B.config().enabled=false B.stop() NexusBot.Storage.touch() end
  end)
  local rows=U.compactList(list,250)
  local function refresh()
    U.clear(rows)
    for _,rule in ipairs(B.config().rules) do
      local row=g_ui.createWidget('NexusIntegrationRow',rows)
      row.name:setText((rule.leader~='' and rule.leader or 'Leader')..': '..(rule.trigger or ''))
      row.enabled:setOn(rule.enabled==true)
      row.enabled.onClick=function() rule.enabled=not rule.enabled B.clear() NexusBot.Storage.touch() refresh() end
      row.edit.onClick=function() B.edit(rule) end
    end
  end
  U.button(list,'+ Add',function()
    local rule={id=NexusBot.id('combo'),leader='',trigger='',type='area_spell',enabled=false,ttl=600,delay=0,range=7,action={spell='',target='target',avoidPlayers=false}}
    table.insert(B.config().rules,rule) NexusBot.Storage.touch() refresh() B.edit(rule)
  end)
  NexusBot.Features.Modern.shared.ownTimer(w,function() power:setOn(B.config().enabled==true) end,300)
  refresh() NexusBot.WindowManager.attach('pvp:combo',w)
  NexusBot.Scheduler.after(25,function() NexusBot.WindowManager.clamp(w) end,'Combo window layout')
  return w
end
function B.edit(rule)
  B.clear()
  NexusBot.WindowManager.close('pvp:combo:edit')
  local w,list=NexusBot.Features.Modern.shared.formWindow('COMBO ACTION',440) w:setWidth(390) U.scrollbar(list)
  local function change(key,value) B.clear() rule[key]=value end
  U.textInput(list,'Leader (exact name)',rule.leader,function(v) change('leader',v) end)
  U.textInput(list,'Leader spell words',rule.trigger,function(v) change('trigger',v) end)
  U.combo(list,'My action',{{'Targeted spell','targeted_spell'},{'Area spell','area_spell'},{'Directional spell','directional_spell'},{'Rune on my target','rune'}},rule.type,function(v)
    change('type',v) rule.action={target='target'} B.edit(rule)
  end)
  if rule.type=='rune' then
    U.itemPicker(list,'Rune ID',rule.action.itemId,function(v)
      B.clear() rule.action.itemId=v rule.action.areaRune=NexusBot.Geometry.runes[v]~=nil
    end)
    U.toggle(list,'Area rune',rule.action.areaRune==true,function(v) B.clear() rule.action.areaRune=v end)
  else U.spellPicker(list,'My spell words',rule.action.spell,function(v)
    B.clear() rule.action.spell=v
    local preset=NexusBot.Spells.getPreset(v)
    if preset then rule.type=preset.actionType rule.range=preset.range or rule.range end
  end) end
  U.numberInput(list,'Range',rule.range,1,8,function(v) change('range',v) end)
  U.numberInput(list,'Event lifetime (ms)',rule.ttl,100,2000,function(v) change('ttl',v) end)
  U.numberInput(list,'Minimum delay (ms)',rule.delay,0,10000,function(v) change('delay',v) end)
  if rule.type=='area_spell' or rule.type=='directional_spell' or rule.type=='rune' then
    U.textInput(list,'Custom 0/1/3 rows',rule.action.customMask or '',function(v) B.clear() rule.action.customMask=v end)
  end
  U.button(list,'Delete',function()
    for i,r in ipairs(B.config().rules) do if r==rule then table.remove(B.config().rules,i) break end end
    B.clear() NexusBot.Storage.touch() w:destroy() B.open()
  end)
  NexusBot.WindowManager.attach('pvp:combo:edit',w)
  NexusBot.Scheduler.after(25,function() NexusBot.WindowManager.clamp(w) end,'Combo editor layout')
  return w
end
function B.onTalk(name,level,mode,text,channel,pos)
  if not B.running or not NexusBot.enabled or not category.getEnabled() or not g_game.isOnline() then return end
  if mode~=(MessageModes and MessageModes.Spell or 9) then return end
  local player=g_game.getLocalPlayer() if not player or normalize(name)==normalize(player:getName()) then return end
  local here=player:getPosition() if not here then return end
  local visible=false
  for _,c in ipairs(g_map.getSpectators(here,false) or {}) do
    local p=c:getPosition()
    if c:isPlayer() and normalize(c:getName())==normalize(name) and p and p.z==here.z and
      (not pos or (pos.x==p.x and pos.y==p.y and pos.z==p.z)) then visible=true break end
  end
  if not visible then return end
  local now=NexusBot.now()
  for key,untilTime in pairs(B.seen) do if untilTime<=now then B.seen[key]=nil end end
  for _,cfg in ipairs(B.config().rules) do
    if cfg.enabled and normalize(cfg.leader)==normalize(name) and normalize(cfg.trigger)==normalize(text) then
      local key=cfg.id..':'..normalize(name)..':'..normalize(text)
      if not B.seen[key] and #B.queue<16 then
        B.seen[key]=now+500
        local target=g_game.getAttackingCreature()
        local needsTarget=cfg.type=='targeted_spell' or cfg.type=='rune'
        if not needsTarget or target then
          local rule={id=cfg.id,type=cfg.type,enabled=true,priority=25,action=NexusBot.copy(cfg.action),conditions={mode='AND',children={}},pattern={autoFace=true},
            advanced={range=cfg.range or 7,minimumDelay=cfg.delay or 0,requiresTarget=needsTarget,onlyIfCooldownReady=true}}
          rule.action.avoidPlayers=false
          B.queue[#B.queue+1]={rule=rule,expires=now+math.max(100,math.min(2000,tonumber(cfg.ttl) or 600)),targetId=needsTarget and target:getId() or nil}
          -- Dispatch at the server spell event instead of waiting for the next
          -- 75-ms scheduler pass. Cooldown/PZ/turn ACK checks still apply.
          local ok,context=pcall(NexusBot.Conditions.buildContext)
          if ok and context then
            context.providerId='combo'
            NexusBot.Actions.execute(rule,context)
          end
        end
      end
    end
  end
end
function B.provide(context)
  if not B.running or not category.getEnabled() then B.clear() return {} end
  local keep,result={},{}
  for _,entry in ipairs(B.queue) do
    if entry.expires>context.now and (not entry.targetId or (context.target and context.target:getId()==entry.targetId)) then
      keep[#keep+1]=entry result[#result+1]=entry.rule
    end
  end
  B.queue=keep return result
end
function B.init()
  B.terminate()
  B.running=B.config().enabled==true
  B.connections={onTalk=B.onTalk,onGameEnd=B.stop}
  connect(g_game,B.connections)
  NexusBot.Actions.registerProvider('combo',25,B.provide)
  NexusBot.EventBus.on('actionExecuted','LocalCombo',function(rule)
    -- Consume only the exact queued instance, never a same-ID ordinary rule.
    for i,entry in ipairs(B.queue) do if entry.rule==rule then table.remove(B.queue,i) break end end
  end)
end
function B.terminate()
  B.stop()
  if B.connections then disconnect(g_game,B.connections) B.connections=nil end
  NexusBot.EventBus.offOwner('LocalCombo') NexusBot.Actions.unregisterProvider('combo')
end
category.init=B.init category.terminate=B.terminate
end

-- ==================== LOGIC / RUNTIME ====================
function P.layoutSource()
  local parts={'local __pvpLayouts={'}
  for key, value in pairs(category.layouts) do
    parts[#parts+1]=string.format('[%q]=%q,',key,P.modernLayout(value))
  end
  parts[#parts+1]='}\n'
  return table.concat(parts)
end
local function findSwitch(widget,name)
  if not widget or widget:isDestroyed() then return end
  local style=widget:getStyleName()
  if (style=='BotSwitch' or style=='SmallBotSwitch') and widget:getText()==name then return widget end
  for _,child in ipairs(widget:getChildren()) do local result=findSwitch(child,name) if result then return result end end
end
local function oldAdapter(runtime,spec)
  local root=runtime.atomicScriptCenterWindow
  if not root or root:isDestroyed() then return end
  local switch=findSwitch(root,spec[3])
  if not switch then return end
  local page=switch:getParent()
  while page and not page.masterInline do
    local config
    for _,child in ipairs(page:getChildren()) do if child.masterInline then config=child break end end
    if config then
      return {switch=switch,edit=switch:getParent().edit,config=config,owner=page,legacy=true}
    end
    page=page:getParent()
  end
end
function P.runtime()
  if not P.native then P.native=P.createRuntime() end
  return P.native
end

-- Private, lifecycle-owned CWEL runtime. No game_bot module, profile or globals.
function P.createRuntime()
  local A=NexusBot.Automation
  local env={bindings={},events={},active=true,GodejroPvp={entries={}}}
  setmetatable(env,{__index=function(_,key)
    if key=='now' then return NexusBot.now() end
    if key=='player' then return g_game.getLocalPlayer() end
    return _G[key]
  end})
  local data=NexusBot.Storage.get()
  data.pvp=data.pvp or {} env.storage=data.pvp
  env.panel=g_ui.createWidget('Panel',g_ui.getRootWidget()) env.panel:hide()
  env.setupUI=function(text,parent) return g_ui.loadUIFromString(text,parent or env.panel) end
  env.load=function(source)
    local fn,err=loadstring(source,'@CWELBOT/PVP') assert(fn,err) setfenv(fn,env) return fn
  end
  local function allowed() return env.active and NexusBot.enabled and category.getEnabled() and g_game.isOnline() end
  local function bind(object,event,callback)
    if not object then return end
    local handlers={[event]=function(...) if allowed() then return callback(...) end end}
    connect(object,handlers) env.bindings[#env.bindings+1]={object,handlers}
  end
  env.macro=function(delay,fn)
    local id=NexusBot.Scheduler.every(delay,function() if allowed() then fn() end end,'CWEL PvP')
    env.events[#env.events+1]=id return id
  end
  env.schedule=function(delay,fn)
    local id
    id=NexusBot.Scheduler.after(delay,function()
      for i,owned in ipairs(env.events) do if owned==id then table.remove(env.events,i) break end end
      if allowed() then fn() end
    end,'CWEL PvP')
    env.events[#env.events+1]=id return id
  end
  env.getSpectators=function() return g_map.getSpectators(A.position(),false) or {} end
  env.pos=A.position
  env.getTileUnderCursor=function()
    local map=modules.game_interface.getMapPanel()
    return map and map:getTile(g_window.getMousePosition())
  end
  env.useWith=function(id,target)
    if type(id)=='number' then return g_game.useInventoryItemWith(id,target) end
    return g_game.useWith(id,target)
  end
  env.autoWalk=function(position,_,options)
    A.Navigation.beginTick()
    return A.Navigation.walkRoute(position,options and options.precision or 0,false)
  end
  env.warn=function(message) NexusBot.Logger.warn('PVP',message) end
  for _,event in ipairs({'onKeyDown','onKeyUp','onKeyPress'}) do
    env[event]=function(fn)
      bind(modules.game_interface.getRootPanel(),event,function(_,code,modifiers,repeats)
        return fn(determineKeyComboDesc(code,modifiers),repeats)
      end)
    end
  end
  env.onTextMessage=function(fn) bind(g_game,'onTextMessage',fn) end
  if g_game.enableTileThingLuaCallback then g_game.enableTileThingLuaCallback(true) end
  env.onAddThing=function(fn) bind(Tile,'onAddThing',fn) end
  env.onRemoveThing=function(fn) bind(Tile,'onRemoveThing',fn) end
  env.onCreaturePositionChange=function(fn) bind(Creature,'onPositionChange',fn) end
  env.onPlayerPositionChange=function(fn) bind(LocalPlayer,'onServerPositionChange',function(_,new,old) fn(new,old) end) end
  return env
end
function P.disposeRuntime()
  local env=P.native if not env then return end
  env.active=false P.native=nil
  for _,id in ipairs(env.events) do NexusBot.Scheduler.cancel(id) end
  for _,binding in ipairs(env.bindings) do disconnect(binding[1],binding[2]) end
  if env.panel and not env.panel:isDestroyed() then env.panel:destroy() end
  P.openSettings={}
end
local initCombo,terminateCombo=category.init,category.terminate
category.init=function()
  if P.lifecycle then disconnect(g_game,P.lifecycle) end
  initCombo()
  P.lifecycle={onGameEnd=function() P.disposeRuntime() end}
  connect(g_game,P.lifecycle)
end
category.terminate=function()
  P.disposeRuntime()
  if P.lifecycle then disconnect(g_game,P.lifecycle) P.lifecycle=nil end
  terminateCombo()
end
local prefix=[==[
GodejroPvp=GodejroPvp or {entries={}}
local registry=GodejroPvp
registry.events=registry.events or {onKeyDown=onKeyDown,onKeyUp=onKeyUp,onKeyPress=onKeyPress,onTextMessage=onTextMessage,onAddThing=onAddThing,onRemoveThing=onRemoveThing,onCreaturePositionChange=onCreaturePositionChange,onPlayerPositionChange=onPlayerPositionChange or onPlayerServerPositionChange}
local originalSetup=setupUI
local currentId=__ID__
if registry.entries[currentId] then return end
local entry={}
registry.entries[currentId]=entry
local function guarded(callback)
  return function(...)
    if registry.isEnabled and registry.isEnabled() then return callback(...) end
  end
end
local originalMacro=macro
local macro=function(interval,callback) return originalMacro(interval,guarded(callback)) end
local onKeyDown=function(callback) return registry.events.onKeyDown(guarded(callback)) end
local onKeyUp=function(callback) return registry.events.onKeyUp(guarded(callback)) end
local onKeyPress=function(callback) return registry.events.onKeyPress(guarded(callback)) end
local onTextMessage=function(callback) return registry.events.onTextMessage(guarded(callback)) end
local onAddThing=function(callback) return registry.events.onAddThing(guarded(callback)) end
local onRemoveThing=function(callback) return registry.events.onRemoveThing(guarded(callback)) end
local onCreaturePositionChange=function(callback) return registry.events.onCreaturePositionChange(guarded(callback)) end
local onPlayerPositionChange=function(callback) return registry.events.onPlayerPositionChange(guarded(callback)) end
local owner=originalSetup('Panel\n  height: 0\n',panel)
owner:hide() entry.owner=owner
local setupUI=function(text,parent)
  if text:match('^%s*NexusWindow') then
    local window=originalSetup(text,g_ui.getRootWidget())
    window:setSize({width=window:getWidth()+12,height=window:getHeight()+22})
    if window.close then window.close:hide() window.close:setHeight(0) end
    local close=g_ui.createWidget('NexusCloseButton',window)
    close:setId('closeButton')
    close:setText('X')
    -- The embedded script sandbox does not export the UI anchor constants.
    -- Match corelib/const.lua (top=1, right=4), never pass nil to addAnchor.
    close:breakAnchors()
    close:addAnchor(1,'parent',1) close:addAnchor(4,'parent',4)
    close:setMarginTop(-38) close:setMarginRight(-12) close:raise()
    close.onClick=function() window:hide() return true end window.onEscape=close.onClick
    entry.config=window
    owner.onDestroy=function()
      local root=g_ui.getRootWidget()
      if root and not root:isDestroyed() and not window:isDestroyed() then window:destroy() end
    end
    return window
  end
  local widget=originalSetup(text,parent or owner)
  if widget.enabled then entry.switch=widget.enabled entry.edit=widget.edit end
  return widget
end
]==]
function P.acquire(runtime,spec)
  local existing=oldAdapter(runtime,spec)
  if existing then return existing end
  if runtime.atomicScriptCenterWindow and not runtime.atomicScriptCenterWindow:isDestroyed() then return nil,'Not loaded in the existing Script Center; reload that profile.' end
  local registry=runtime.GodejroPvp
  if registry then registry.isEnabled=function() return NexusBot.enabled==true and category.getEnabled() end end
  if registry and registry.entries[spec[1]] then local e=registry.entries[spec[1]] if e.error then return nil,e.error end return e end
  if not runtime.load or not runtime.setupUI then return nil,'CWEL PvP runtime unavailable.' end
  local source=NexusBot.PvpSources and NexusBot.PvpSources[spec[1]]
  if not source then return nil,'Bundled implementation missing.' end
  local ok,err=pcall(function()
    local code=P.layoutSource()..prefix:gsub('__ID__',string.format('%q',spec[1]))..'\n'..source:gsub('if not masterOk then','if not masterOk then entry.error=tostring(masterError) ')
    runtime.load(code)()
  end)
  registry=runtime.GodejroPvp
  if registry then registry.isEnabled=function() return NexusBot.enabled==true and category.getEnabled() end end
  local entry=registry and registry.entries[spec[1]]
  if not ok or not entry or not entry.switch or entry.error then return nil,tostring(err or (entry and entry.error) or 'Script did not create its controls; check bot log.') end
  local function persist(widget)
    for _,event in ipairs({'onTextChange','onValueChange','onClick'}) do
      local callback=widget[event]
      if type(callback)=='function' then widget[event]=function(...)
        local result=callback(...) NexusBot.Storage.touch() return result
      end end
    end
    for _,child in ipairs(widget:getChildren()) do persist(child) end
  end
  persist(entry.owner)
  if entry.config then persist(entry.config) end
  return entry
end

NexusBot.PvpSources={}

NexusBot.PvpSources['smart_push']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "atomicSmartPushV3"
    local defaults = {
      enabled = false, hotkey = "Delete", mode = "normal",
      usePushRune = false, rewallPlayer = true,
      pushRuneId = 3188, mwRuneId = 3180,
      wallIds = "2128,2129,2130",
      normalDurationSec = 20, pushBeforeSec = 0.99
    }
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    
    local bar = setupUI(__pvpLayouts.layout_1)
    
    local window = setupUI(__pvpLayouts.layout_2, g_ui.getRootWidget())
    window:hide()
    
    local wallIds = {}
    local selectedPos, armedTargetId = nil, nil
    local normalExpireAt, randomExpireAt = nil, nil
    local syncActive, syncDeadline, awaitingLookUntil = false, 0, 0
    local lastLookAt, previousLookSeconds = 0, nil
    local pushExecuted, pushOriginPos = false, nil
    local finishedPos, finishedTargetId, finishedUntil = nil, nil, 0
    local pendingRewallPos = nil
    
    local function copyPos(p)
      return p and {x = p.x, y = p.y, z = p.z} or nil
    end
    
    local function samePos(a, b)
      return a and b and a.x == b.x and a.y == b.y and a.z == b.z
    end
    
    local function distance(a, b)
      if not a or not b or a.z ~= b.z then return 999 end
      return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
    end
    
    local function decimal(value, fallback)
      return tonumber((tostring(value or ""):gsub(",", "."))) or fallback
    end
    
    local function normalizeKey(value)
      return tostring(value or ""):lower():gsub("%s+", "")
    end
    
    local function rebuildWallIds()
      wallIds = {}
      for id in tostring(cfg.wallIds or ""):gmatch("%d+") do
        wallIds[tonumber(id)] = true
      end
    end
    
    local function wallThing(tile)
      if not tile then return nil end
      local thing = tile:getTopThing()
      if thing and wallIds[thing:getId()] then return thing end
      thing = tile:getTopUseThing()
      if thing and wallIds[thing:getId()] then return thing end
      for _, item in ipairs(tile:getItems()) do
        if wallIds[item:getId()] then return item end
      end
      return nil
    end
    
    local function creatureById(id)
      if not id then return nil end
      for _, creature in ipairs(getSpectators(false)) do
        if creature:getId() == id then return creature end
      end
      return nil
    end
    
    local function playerByName(name)
      local wanted = tostring(name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if wanted == "" or wanted == "player name" then return nil end
      for _, creature in ipairs(getSpectators(false)) do
        if creature ~= player and creature:isPlayer() and creature:getName():lower() == wanted then
          return creature
        end
      end
      return nil
    end
    
    local function currentTarget()
      local target = g_game.getAttackingCreature()
      if target and target ~= player and target:isPlayer() then return target end
      target = g_game.getFollowingCreature()
      if target and target ~= player and target:isPlayer() then return target end
      if storage.afPerfect and storage.afPerfect.enabled then
        return playerByName(storage.afPerfect.name)
      end
      return nil
    end
    
    local function targetForPush()
      local target = creatureById(armedTargetId)
      if target and target ~= player and target:isPlayer() then return target end
      return currentTarget()
    end
    
    local function selectedTile()
      return selectedPos and g_map.getTile(selectedPos) or nil
    end
    
    local function clearTileText()
      local tile = selectedTile()
      if tile then tile:setText("") end
    end
    
    local function clearSelection()
      clearTileText()
      selectedPos, armedTargetId = nil, nil
      normalExpireAt, randomExpireAt = nil, nil
      syncActive, syncDeadline, awaitingLookUntil = false, 0, 0
      previousLookSeconds = nil
      pushExecuted, pushOriginPos = false, nil
    end
    
    local function tileTimer(tile)
      if not tile or not tile.getTimer then return nil end
      local ok, value = pcall(function() return tile:getTimer() end)
      return ok and value and value > 0 and value or nil
    end
    
    local function setCheck(widget, checked)
      widget:setChecked(checked)
    end
    
    local function refreshModeUi()
      local normal = cfg.mode == "normal"
      setCheck(window.normalMode, normal)
      setCheck(window.randomMode, not normal)
      if normal then
        window.durationLabel:show()
        window.duration:show()
      else
        window.durationLabel:hide()
        window.duration:hide()
      end
    end
    
    local function setMode(mode)
      cfg.mode = mode == "normal" and "normal" or "random"
      if selectedPos then clearSelection() end
      refreshModeUi()
    end
    
    local function requestLook(force)
      if not syncActive or not selectedPos then return false end
      if not force and now - lastLookAt < 50 then return false end
      local wall = wallThing(selectedTile())
      if not wall then return false end
      lastLookAt = now
      awaitingLookUntil = syncDeadline + 500
      return pcall(function() g_game.look(wall) end)
    end
    
    local function beginRandomSync()
      randomExpireAt, previousLookSeconds = nil, nil
      syncActive, syncDeadline = true, now + 2000
      awaitingLookUntil, lastLookAt = syncDeadline + 500, 0
      requestLook(true)
    end
    
    local function finishRandomSync()
      if not syncActive then return end
      syncActive, awaitingLookUntil = false, 0
      if previousLookSeconds ~= nil then
        randomExpireAt = now + math.max(50, ((previousLookSeconds + 1) * 1000) - 60)
      else
        local timer = tileTimer(selectedTile())
        if timer then randomExpireAt = now + timer end
      end
    end
    
    local function selectWall(tile)
      if not wallThing(tile) then return false end
      clearSelection()
      selectedPos = copyPos(tile:getPosition())
      local target = currentTarget()
      armedTargetId = target and target:getId() or nil
      tile:setText("PUSH ?")
      if cfg.mode == "normal" then
        local timer = tileTimer(tile)
        normalExpireAt = now + (timer or math.floor(math.max(0.1, decimal(cfg.normalDurationSec, 20)) * 1000))
      else
        beginRandomSync()
      end
      return true
    end
    
    local function remainingMs()
      local tile = selectedTile()
      if not tile or not wallThing(tile) then return nil end
      if cfg.mode == "normal" then
        return tileTimer(tile) or (normalExpireAt and normalExpireAt - now or nil)
      end
      return randomExpireAt and randomExpireAt - now or nil
    end
    
    local function runeTargetUnderCreature(creature)
      if not creature then return nil end
      local tile = g_map.getTile(creature:getPosition())
      if not tile then return nil end
      local ground = tile:getGround()
      local items = tile:getItems()
      for index = #items, 1, -1 do
        local item = items[index]
        if item ~= ground then return item end
      end
      return ground or tile:getTopThing()
    end
    
    local function executePushOnce()
      if pushExecuted or not cfg.enabled or not selectedPos then return false end
      local destination = copyPos(selectedPos)
      local target = targetForPush()
      if not target or distance(target:getPosition(), destination) ~= 1 then return false end
      armedTargetId = target:getId()
      local targetId = armedTargetId
      pushOriginPos = copyPos(target:getPosition())
      pushExecuted = true
      if cfg.usePushRune then
        local runeId = tonumber(cfg.pushRuneId) or 0
        local runeTarget = runeTargetUnderCreature(target)
        if runeId <= 0 or not runeTarget or
           not pcall(function() useWith(runeId, runeTarget) end) then
          pushExecuted = false
          return false
        end
        schedule(10, function()
          local current = creatureById(targetId)
          if current then
            pcall(function() g_game.move(current, destination) end)
          end
        end)
      else
        pcall(function() g_game.move(target, destination) end)
      end
      return true
    end
    
    local function executeDirectPush(destination)
      if not cfg.enabled or not destination then return false end
      local target = currentTarget()
      if not target or distance(target:getPosition(), destination) ~= 1 then return false end
      local targetId = target:getId()
      pushOriginPos = copyPos(target:getPosition())
      finishedPos = copyPos(destination)
      finishedTargetId = targetId
      finishedUntil = now + 500
      if cfg.usePushRune then
        local runeId = tonumber(cfg.pushRuneId) or 0
        local runeTarget = runeTargetUnderCreature(target)
        if runeId <= 0 or not runeTarget or
           not pcall(function() useWith(runeId, runeTarget) end) then
          finishedPos, finishedTargetId, finishedUntil = nil, nil, 0
          pushOriginPos = nil
          return false
        end
        schedule(10, function()
          local current = creatureById(targetId)
          if current then
            pcall(function() g_game.move(current, destination) end)
          end
        end)
      else
        pcall(function() g_game.move(target, destination) end)
      end
      return true
    end
    
    local function castPendingRewall()
      if not pendingRewallPos then return end
      local tile = g_map.getTile(pendingRewallPos)
      if not tile or tile:hasCreature() or wallThing(tile) then return end
      local target = tile:getTopUseThing() or tile:getGround() or tile:getTopThing()
      local runeId = tonumber(cfg.mwRuneId) or 0
      pendingRewallPos = nil
      if target and runeId > 0 then useWith(runeId, target) end
    end
    
    local function finishWallCycle()
      if not selectedPos then return end
      finishedPos, finishedTargetId = copyPos(selectedPos), armedTargetId
      finishedUntil = now + 500
      clearSelection()
    end
    
    rebuildWallIds()
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
      if not cfg.enabled then clearSelection() end
    end
    
    bar.edit.onClick = function()
      window.hotkey:setText(tostring(cfg.hotkey))
      window.pushRuneId:setText(tostring(cfg.pushRuneId))
      window.mwRuneId:setText(tostring(cfg.mwRuneId))
      window.wallIds:setText(tostring(cfg.wallIds))
      window.duration:setText(tostring(cfg.normalDurationSec))
      window.pushTimer:setText(tostring(cfg.pushBeforeSec))
      setCheck(window.usePushRune, cfg.usePushRune)
      setCheck(window.rewallPlayer, cfg.rewallPlayer)
      refreshModeUi()
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.normalMode.onClick = function() setMode("normal") end
    window.randomMode.onClick = function() setMode("random") end
    window.usePushRune.onClick = function(widget)
      cfg.usePushRune = not cfg.usePushRune
      setCheck(widget, cfg.usePushRune)
    end
    window.rewallPlayer.onClick = function(widget)
      cfg.rewallPlayer = not cfg.rewallPlayer
      setCheck(widget, cfg.rewallPlayer)
    end
    window.hotkey.onTextChange = function(_, text) cfg.hotkey = text end
    window.pushRuneId.onTextChange = function(_, text) cfg.pushRuneId = tonumber(text) or 0 end
    window.mwRuneId.onTextChange = function(_, text) cfg.mwRuneId = tonumber(text) or 0 end
    window.wallIds.onTextChange = function(_, text)
      cfg.wallIds = text
      rebuildWallIds()
    end
    window.duration.onTextChange = function(_, text) cfg.normalDurationSec = decimal(text, 20) end
    window.pushTimer.onTextChange = function(_, text) cfg.pushBeforeSec = decimal(text, 0.99) end
    
    onKeyUp(function(keys)
      if not cfg.enabled or normalizeKey(keys) ~= normalizeKey(cfg.hotkey) then return end
      local tile = getTileUnderCursor()
      if not tile then return end
      local tilePos = copyPos(tile:getPosition())
      if wallThing(tile) then
        if selectedPos and samePos(selectedPos, tilePos) then
          clearSelection()
          return
        end
        selectWall(tile)
        return
      end
      clearSelection()
      finishedPos, finishedTargetId, finishedUntil = nil, nil, 0
      executeDirectPush(tilePos)
    end)
    
    onTextMessage(function(_, text)
      if not cfg.enabled or cfg.mode ~= "random" or not selectedPos then return end
      if not syncActive or now > awaitingLookUntil then return end
      local lower = tostring(text or ""):lower()
      if not lower:find("magic wall", 1, true) then return end
      if lower:find("brand%-new") or lower:find("brand new", 1, true) then
        randomExpireAt, syncActive, awaitingLookUntil = now + 940, false, 0
        return
      end
      local raw = lower:match("will expire in%s+([%d%.,]+)%s+seconds?") or
        lower:match("will disappear in%s+([%d%.,]+)%s+seconds?")
      if not raw then return end
      local seconds = tonumber((raw:gsub(",", ".")))
      if not seconds then return end
      local whole = math.floor(seconds)
      if math.abs(seconds - whole) > 0.001 then
        randomExpireAt = now + math.max(50, math.floor(seconds * 1000) - 50)
        syncActive, awaitingLookUntil = false, 0
      elseif previousLookSeconds ~= nil and whole < previousLookSeconds then
        randomExpireAt = now + math.max((whole * 1000) + 10, ((whole + 1) * 1000) - 60)
        syncActive, awaitingLookUntil = false, 0
      else
        previousLookSeconds = whole
      end
    end)
    
    onRemoveThing(function(tile, thing)
      if cfg.enabled and selectedPos and samePos(tile:getPosition(), selectedPos) and wallIds[thing:getId()] then
        finishWallCycle()
      end
    end)
    
    onCreaturePositionChange(function(creature, newPos, oldPos)
      local destination = selectedPos or finishedPos
      local targetId = armedTargetId or finishedTargetId
      if not destination or not targetId or creature:getId() ~= targetId then return end
      if not samePos(newPos, destination) then return end
      if cfg.rewallPlayer then pendingRewallPos = copyPos(oldPos or pushOriginPos) end
      finishedPos, finishedTargetId, finishedUntil = nil, nil, 0
      clearSelection()
      castPendingRewall()
    end)
    
    macro(1, function()
      castPendingRewall()
      if finishedUntil > 0 and now >= finishedUntil then
        finishedPos, finishedTargetId, finishedUntil = nil, nil, 0
      end
      if not cfg.enabled or not selectedPos then return end
      local tile = selectedTile()
      if not tile or not wallThing(tile) then
        finishWallCycle()
        return
      end
      if cfg.mode == "random" and syncActive then
        if now < syncDeadline then requestLook(false) else finishRandomSync() end
      end
      local remaining = remainingMs()
      if not remaining then
        tile:setText("PUSH ?")
        return
      end
      tile:setText(string.format("PUSH %.2f", remaining / 1000))
      if remaining <= math.max(0, decimal(cfg.pushBeforeSec, 0.99)) * 1000 then
        executePushOnce()
      end
    end)
  end)
  if not masterOk then warn("[My Script Center] Smart Push: " .. tostring(masterError)) end
end
]====]

NexusBot.PvpSources['fast_push']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "Fast Push"
    local defaults = {enabled = false, hotkey = "PageDown", takeStepBack = true, diagonalPush = false}
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    
    local bar = setupUI(__pvpLayouts.layout_3)
    
    local window = setupUI(__pvpLayouts.layout_4, g_ui.getRootWidget())
    window:hide()
    
    local targetId = nil
    local targetMarkPos = nil
    local destination = nil
    local fastPushKey = nil
    local fastPushStarted = false
    local fastApproachPos = nil
    local fastBackPos = nil
    
    local cardinal = {
      {x = 0, y = -1}, {x = 1, y = 0},
      {x = 0, y = 1}, {x = -1, y = 0}
    }
    
    local diagonal = {
      {x = 0, y = -1}, {x = 1, y = 0},
      {x = 0, y = 1}, {x = -1, y = 0},
      {x = 1, y = -1}, {x = 1, y = 1},
      {x = -1, y = 1}, {x = -1, y = -1}
    }
    
    local function copyPos(p)
      return {x = p.x, y = p.y, z = p.z}
    end
    
    local function samePos(a, b)
      return a and b and a.x == b.x and a.y == b.y and a.z == b.z
    end
    
    local function distance(a, b)
      if not a or not b or a.z ~= b.z then return 999 end
      return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
    end
    
    local function posKey(p)
      return p.x .. ":" .. p.y .. ":" .. p.z
    end
    
    local function getTarget()
      if not targetId then return nil end
      for _, creature in ipairs(getSpectators()) do
        if creature:getId() == targetId then return creature end
      end
      return nil
    end
    
    local function clearTextAt(p, expected)
      local tile = p and g_map.getTile(p) or nil
      if tile and tile:getText() == expected then tile:setText("") end
    end
    
    local function clearSelection()
      clearTextAt(targetMarkPos, "PUSH TARGET")
      clearTextAt(destination, "PUSH DEST")
      targetId = nil
      targetMarkPos = nil
      destination = nil
      fastPushKey = nil
      fastPushStarted = false
      fastApproachPos = nil
      fastBackPos = nil
    end
    
    local function magicFieldOn(tile)
      if not tile then return true end
      for _, item in ipairs(tile:getItems()) do
        local ok, result = pcall(function() return item:isMagicField() end)
        if ok and result then return true end
      end
      return false
    end
    
    local function tileFree(p, allowPlayer)
      local tile = g_map.getTile(p)
      if not tile or not tile:isWalkable(false) or magicFieldOn(tile) then return false end
      for _, item in ipairs(tile:getItems()) do
        local walkOk, notWalkable = pcall(function() return item:isNotWalkable() end)
        local pathOk, notPathable = pcall(function() return item:isNotPathable() end)
        if (walkOk and notWalkable) or (pathOk and notPathable) then return false end
      end
      if tile:hasCreature() then
        if not allowPlayer then return false end
        for _, creature in ipairs(tile:getCreatures()) do
          if creature ~= player then return false end
        end
      end
      return true
    end
    
    local function targetHasItemUnder(target)
      local tile = g_map.getTile(target:getPosition())
      if not tile then return true end
      if magicFieldOn(tile) then return true end
      local ground = tile:getGround()
      for _, item in ipairs(tile:getItems()) do
        if item ~= ground then
          local ok, immovable = pcall(function() return item:isNotMoveable() end)
          if not ok or not immovable then return true end
        end
      end
      return false
    end
    
    local function orderedDirections(p, goal)
      local source = cardinal
      local result = {}
      for index, dir in ipairs(source) do
        table.insert(result, {x = dir.x, y = dir.y, order = index})
      end
      table.sort(result, function(a, b)
        local da = math.max(math.abs(goal.x - p.x - a.x), math.abs(goal.y - p.y - a.y))
        local db = math.max(math.abs(goal.x - p.x - b.x), math.abs(goal.y - p.y - b.y))
        if da == db then return a.order < b.order end
        return da < db
      end)
      return result
    end
    
    local function findPushPath(startPos, goalPos)
      if not startPos or not goalPos or startPos.z ~= goalPos.z then return nil end
      if not tileFree(goalPos, true) then return nil end
      local startKey = posKey(startPos)
      local queue = {copyPos(startPos)}
      local head = 1
      local visited = {[startKey] = true}
      local parents = {}
      local positions = {[startKey] = copyPos(startPos)}
      local found = nil
    
      while head <= #queue and head <= 1200 do
        local current = queue[head]
        head = head + 1
        for _, dir in ipairs(orderedDirections(current, goalPos)) do
          local nextPos = {x = current.x + dir.x, y = current.y + dir.y, z = current.z}
          local nextKey = posKey(nextPos)
          local inRange = math.abs(nextPos.x - startPos.x) <= 20 and math.abs(nextPos.y - startPos.y) <= 20
          if inRange and not visited[nextKey] and tileFree(nextPos, true) then
            visited[nextKey] = true
            parents[nextKey] = posKey(current)
            positions[nextKey] = nextPos
            table.insert(queue, nextPos)
            if samePos(nextPos, goalPos) then
              found = nextKey
              break
            end
          end
        end
        if found then break end
      end
    
      if not found then return nil end
      local path = {}
      local keyValue = found
      while keyValue and keyValue ~= startKey do
        table.insert(path, 1, positions[keyValue])
        keyValue = parents[keyValue]
      end
      return path
    end
    
    local function setCheck(widget, value)
      widget:setChecked(value)
    end
    
    local function setMode(mode)
      cfg.takeStepBack = mode == "step"
      cfg.diagonalPush = mode == "diagonal"
      setCheck(window.takeStepBack, cfg.takeStepBack)
      setCheck(window.diagonalPush, cfg.diagonalPush)
    end
    
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
      if not cfg.enabled then clearSelection() end
    end
    
    bar.edit.onClick = function()
      window.hotkey:setText(tostring(cfg.hotkey))
      setMode(cfg.diagonalPush and "diagonal" or "step")
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.takeStepBack.onClick = function() setMode("step") end
    window.diagonalPush.onClick = function() setMode("diagonal") end
    window.hotkey.onTextChange = function(_, text) cfg.hotkey = text end
    
    onKeyUp(function(keys)
      if not cfg.enabled or tostring(keys):lower() ~= tostring(cfg.hotkey):lower() then return end
      local tile = getTileUnderCursor()
      if not tile then return end
      if targetId and destination then
        clearSelection()
        return
      end
      if not targetId then
        local creatures = tile:getCreatures()
        local creature = creatures and creatures[1] or nil
        if not creature or creature == player then return end
        targetId = creature:getId()
        targetMarkPos = copyPos(creature:getPosition())
        tile:setText("PUSH TARGET")
        return
      end
      destination = copyPos(tile:getPosition())
      tile:setText("PUSH DEST")
    end)
    
    onCreaturePositionChange(function(creature, newPos, oldPos)
      if not targetId or creature:getId() ~= targetId then return end
      clearTextAt(targetMarkPos, "PUSH TARGET")
      targetMarkPos = copyPos(newPos)
      fastPushKey = nil
      fastPushStarted = false
      fastApproachPos = nil
      fastBackPos = nil
      if samePos(newPos, destination) then
        clearSelection()
      else
        local tile = g_map.getTile(newPos)
        if tile then tile:setText("PUSH TARGET") end
      end
    end)
    
    macro(20, function()
      if not cfg.enabled or not targetId or not destination then return end
      local target = getTarget()
      if not target then
        clearSelection()
        return
      end
      local targetPos = target:getPosition()
      if samePos(targetPos, destination) then
        clearSelection()
        return
      end
      if targetHasItemUnder(target) then return end
      local path = findPushPath(targetPos, destination)
      if not path or not path[1] then return end
      local nextPos = path[1]
      local dx = nextPos.x - targetPos.x
      local dy = nextPos.y - targetPos.y
      if cfg.takeStepBack then
        local stepKey = posKey(targetPos) .. ">" .. posKey(nextPos)
        if fastPushKey ~= stepKey then
          fastPushKey = stepKey
          fastPushStarted = false
          fastApproachPos = nil
          fastBackPos = nil
          local playerPos = player:getPosition()
          if distance(playerPos, targetPos) == 1 and not samePos(playerPos, nextPos) then
            local awayX = playerPos.x - targetPos.x
            local awayY = playerPos.y - targetPos.y
            local backPos = {x = playerPos.x + awayX, y = playerPos.y + awayY, z = playerPos.z}
            if tileFree(backPos, true) then
              fastApproachPos = copyPos(playerPos)
              fastBackPos = backPos
            end
          end
        end
        if not fastApproachPos or not fastBackPos then return end
        if not fastPushStarted then
          local playerPos = player:getPosition()
          if samePos(playerPos, fastBackPos) then
            fastPushStarted = true
            local movingTargetId = targetId
            local movingFrom = copyPos(targetPos)
            local movingTo = copyPos(nextPos)
            autoWalk(fastApproachPos, 1, {ignoreNonPathable = false, precision = 0})
            schedule(10, function()
              local current = getTarget()
              if current and current:getId() == movingTargetId and
                 samePos(current:getPosition(), movingFrom) then
                g_game.move(current, movingTo)
              end
            end)
            return
          end
          if samePos(playerPos, fastApproachPos) then
            autoWalk(fastBackPos, 1, {ignoreNonPathable = false, precision = 0})
          else
            fastPushKey = nil
            fastApproachPos = nil
            fastBackPos = nil
          end
          return
        end
        if not samePos(player:getPosition(), fastApproachPos) then
          if samePos(player:getPosition(), fastBackPos) then
            autoWalk(fastApproachPos, 1, {ignoreNonPathable = false, precision = 0})
          else
            fastPushKey = nil
            fastPushStarted = false
            fastApproachPos = nil
            fastBackPos = nil
          end
          return
        end
        g_game.move(target, nextPos)
        return
      end
      fastPushKey = nil
      fastPushStarted = false
      fastApproachPos = nil
      fastBackPos = nil
      g_game.move(target, nextPos)
    end)
  end)
  if not masterOk then warn("[My Script Center] Fast Push: " .. tostring(masterError)) end
end
]====]

NexusBot.PvpSources['wall_keeper']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "WallKeeper"
    local defaults = {
      enabled = false,
      hotkey = "Insert",
      mode = "mw",
      mwRuneId = 3180,
      mwWallIds = "2128,2129,2130",
      wgRuneId = 3156,
      wgWallIds = "2131,2132"
    }
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    
    local bar = setupUI(__pvpLayouts.layout_5)
    
    local window = setupUI(__pvpLayouts.layout_6, g_ui.getRootWidget())
    window:hide()
    
    local marked = {}
    local mwIds = {}
    local wgIds = {}
    
    local function copyPos(p)
      return {x = p.x, y = p.y, z = p.z}
    end
    
    local function posKey(p)
      return p.x .. ":" .. p.y .. ":" .. p.z
    end
    
    local function parseIds(text)
      local result = {}
      for id in tostring(text or ""):gmatch("%d+") do result[tonumber(id)] = true end
      return result
    end
    
    local function rebuildIds()
      mwIds = parseIds(cfg.mwWallIds)
      wgIds = parseIds(cfg.wgWallIds)
    end
    
    local function entryLabel(entry)
      return entry.mode == "wg" and "HOLD WG" or "HOLD MW"
    end
    
    local function entryRune(entry)
      return tonumber(entry.mode == "wg" and cfg.wgRuneId or cfg.mwRuneId) or 0
    end
    
    local function entryIds(entry)
      return entry.mode == "wg" and wgIds or mwIds
    end
    
    local function tileHasWall(tile, entry)
      if not tile then return false end
      local ids = entryIds(entry)
      for _, item in ipairs(tile:getItems()) do
        if ids[item:getId()] then return true end
      end
      return false
    end
    
    local function clearEntry(entry)
      local tile = entry and g_map.getTile(entry.pos) or nil
      if tile and tile:getText() == entryLabel(entry) then tile:setText("") end
    end
    
    local function clearAll()
      for _, entry in pairs(marked) do clearEntry(entry) end
      marked = {}
    end
    
    local function castOnce(entry, forceMissing)
      if not cfg.enabled or not entry then return false end
      if now < (entry.nextAttempt or 0) then return false end
      local tile = g_map.getTile(entry.pos)
      if not tile or tile:hasCreature() then return false end
      if not forceMissing and tileHasWall(tile, entry) then return false end
      local target = tile:getTopUseThing() or tile:getGround() or tile:getTopThing()
      local runeId = entryRune(entry)
      if not target or runeId <= 0 then return false end
      -- A use request is not an acknowledgement: cooldown, range or missing
      -- rune can reject it. Retry until a wall actually appears on this tile.
      entry.nextAttempt = now + 250
      local result = useWith(runeId, target)
      return result ~= false
    end
    
    local function setCheck(widget, value)
      widget:setChecked(value)
    end
    
    local function setMode(mode)
      cfg.mode = mode
      setCheck(window.modeMw, mode == "mw")
      setCheck(window.modeWg, mode == "wg")
    end
    
    rebuildIds()
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
      if not cfg.enabled then clearAll() end
    end
    
    bar.edit.onClick = function()
      window.hotkey:setText(tostring(cfg.hotkey))
      window.mwRuneId:setText(tostring(cfg.mwRuneId))
      window.mwWallIds:setText(tostring(cfg.mwWallIds))
      window.wgRuneId:setText(tostring(cfg.wgRuneId))
      window.wgWallIds:setText(tostring(cfg.wgWallIds))
      setMode(cfg.mode == "wg" and "wg" or "mw")
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.modeMw.onClick = function() setMode("mw") end
    window.modeWg.onClick = function() setMode("wg") end
    window.hotkey.onTextChange = function(_, text) cfg.hotkey = text end
    window.mwRuneId.onTextChange = function(_, text) cfg.mwRuneId = tonumber(text) or 0 end
    window.wgRuneId.onTextChange = function(_, text) cfg.wgRuneId = tonumber(text) or 0 end
    window.mwWallIds.onTextChange = function(_, text)
      cfg.mwWallIds = text
      rebuildIds()
    end
    window.wgWallIds.onTextChange = function(_, text)
      cfg.wgWallIds = text
      rebuildIds()
    end

    macro(100, function()
      if not cfg.enabled then return end
      for _, entry in pairs(marked) do castOnce(entry) end
    end)
    
    onKeyDown(function(keys)
      if not cfg.enabled or tostring(keys):lower() ~= tostring(cfg.hotkey):lower() then return end
      local tile = getTileUnderCursor()
      if not tile then return end
      local tilePos = tile:getPosition()
      local keyValue = posKey(tilePos)
      if marked[keyValue] then
        clearEntry(marked[keyValue])
        marked[keyValue] = nil
        return
      end
      local entry = {pos = copyPos(tilePos), mode = cfg.mode, sent = false}
      marked[keyValue] = entry
      tile:setText(entryLabel(entry))
      castOnce(entry)
    end)
    
    onAddThing(function(tile, thing)
      local entry = marked[posKey(tile:getPosition())]
      if not entry then return end
      if entryIds(entry)[thing:getId()] then entry.sent = false end
    end)
    
    onRemoveThing(function(tile, thing)
      local entry = marked[posKey(tile:getPosition())]
      if not entry then return end
      if entryIds(entry)[thing:getId()] then
        entry.sent = false
        castOnce(entry, true)
      end
    end)
    
    onCreaturePositionChange(function(creature, newPos, oldPos)
      if not oldPos then return end
      local entry = marked[posKey(oldPos)]
      if entry then
        entry.sent = false
        castOnce(entry)
      end
    end)
  end)
  if not masterOk then warn("[My Script Center] Wall Keeper: " .. tostring(masterError)) end
end
]====]

NexusBot.PvpSources['flower']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "atomicFlowerV2"
    local defaults = {enabled = false, hotkey = "F", wallId = 2129, flowerId = 2983}
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    
    local bar = setupUI(__pvpLayouts.layout_7)
    
    local window = setupUI(__pvpLayouts.layout_8, g_ui.getRootWidget())
    window:hide()
    
    local markedPos = nil
    
    local function samePos(a, b)
      return a and b and a.x == b.x and a.y == b.y and a.z == b.z
    end
    
    local function copyPos(p)
      return {x = p.x, y = p.y, z = p.z}
    end
    
    local function clearMark()
      if markedPos then
        local tile = g_map.getTile(markedPos)
        if tile and tile:getText() == "FLOWER" then tile:setText("") end
      end
      markedPos = nil
    end
    
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
      if not cfg.enabled then clearMark() end
    end
    
    bar.edit.onClick = function()
      window.hotkey:setText(tostring(cfg.hotkey))
      window.wallId:setText(tostring(cfg.wallId))
      window.flowerId:setText(tostring(cfg.flowerId))
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.hotkey.onTextChange = function(_, text) cfg.hotkey = text end
    window.wallId.onTextChange = function(_, text) cfg.wallId = tonumber(text) or 0 end
    window.flowerId.onTextChange = function(_, text) cfg.flowerId = tonumber(text) or 0 end
    
    onKeyDown(function(keys)
      if not cfg.enabled or tostring(keys):lower() ~= tostring(cfg.hotkey):lower() then return end
      local tile = getTileUnderCursor()
      if not tile then return end
      local tilePos = tile:getPosition()
      if samePos(markedPos, tilePos) then
        clearMark()
        return
      end
      clearMark()
      markedPos = copyPos(tilePos)
      tile:setText("FLOWER")
    end)
    
    onRemoveThing(function(tile, thing)
      if not cfg.enabled or not markedPos then return end
      if thing:getId() ~= tonumber(cfg.wallId) then return end
      if not samePos(tile:getPosition(), markedPos) then return end
      local destination = copyPos(markedPos)
      clearMark()
      local flower = findItem(tonumber(cfg.flowerId) or 0)
      if flower then g_game.move(flower, destination, 1) end
    end)
  end)
  if not masterOk then warn("[My Script Center] Flower: " .. tostring(masterError)) end
end
]====]

NexusBot.PvpSources['anti_push']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "atomicAntiPushV1"
    local defaults = {enabled = false, itemId = 3031, amount = 1}
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    cfg.amount = math.max(1, math.min(1000, math.floor(tonumber(cfg.amount) or 1)))
    
    local bar = setupUI(__pvpLayouts.layout_9)
    
    local window = setupUI(__pvpLayouts.layout_10, g_ui.getRootWidget())
    window:hide()
    
    local pendingPos = nil
    
    local function copyPos(p)
      return {x = p.x, y = p.y, z = p.z}
    end
    
    local function samePos(a, b)
      return a and b and a.x == b.x and a.y == b.y and a.z == b.z
    end
    
    local function itemCount(item)
      local ok, count = pcall(function() return item:getCount() end)
      if not ok or not count or count < 1 then return 1 end
      return count
    end
    
    local function itemUnderPlayer(tile, itemId)
      if not tile then return false end
      for _, item in ipairs(tile:getItems()) do
        if item:getId() == itemId then return true end
      end
      return false
    end
    
    local function findStack(itemId, amount)
      for _, container in pairs(g_game.getContainers()) do
        for _, item in ipairs(container:getItems()) do
          if item:getId() == itemId and itemCount(item) >= amount then return item end
        end
      end
      return nil
    end
    
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
      pendingPos = nil
    end
    
    bar.edit.onClick = function()
      window.itemId:setText(tostring(cfg.itemId))
      window.amount:setText(tostring(cfg.amount))
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.itemId.onTextChange = function(_, text)
      cfg.itemId = math.max(0, math.floor(tonumber(text) or 0))
      pendingPos = nil
    end
    window.amount.onTextChange = function(_, text)
      cfg.amount = math.max(1, math.min(1000, math.floor(tonumber(text) or 1)))
      pendingPos = nil
    end
    
    onPlayerPositionChange(function()
      pendingPos = nil
    end)
    
    onAddThing(function(tile, thing)
      if thing:getId() == tonumber(cfg.itemId) and samePos(tile:getPosition(), pos()) then
        pendingPos = nil
      end
    end)
    
    onRemoveThing(function(tile, thing)
      if thing:getId() == tonumber(cfg.itemId) and samePos(tile:getPosition(), pos()) then
        pendingPos = nil
      end
    end)
    
    macro(20, function()
      if not cfg.enabled then return end
      local playerPos = pos()
      local tile = g_map.getTile(playerPos)
      local itemId = tonumber(cfg.itemId) or 0
      local amount = math.max(1, math.min(1000, math.floor(tonumber(cfg.amount) or 1)))
      if itemId <= 0 or not tile then return end
      if itemUnderPlayer(tile, itemId) then
        pendingPos = nil
        return
      end
      if pendingPos and samePos(pendingPos, playerPos) then return end
      local item = findStack(itemId, amount)
      if not item then return end
      pendingPos = copyPos(playerPos)
      local ok = pcall(function() g_game.move(item, playerPos, amount) end)
      if not ok then
        pendingPos = nil
        return
      end
      local attemptedPos = copyPos(playerPos)
      schedule(250, function()
        if pendingPos and samePos(pendingPos, attemptedPos) then
          local currentTile = g_map.getTile(attemptedPos)
          if not itemUnderPlayer(currentTile, tonumber(cfg.itemId) or 0) then
            pendingPos = nil
          end
        end
      end)
    end)
  end)
  if not masterOk then warn("[My Script Center] Anti Push: " .. tostring(masterError)) end
end
]====]

NexusBot.PvpSources['trash']=[====[
do
  local masterOk, masterError = pcall(function()
    local key = "atomicTrashMouseV2"
    local defaults = {enabled = false, hotkey = "T", itemId = 3031, amount = 1}
    storage[key] = storage[key] or {}
    local cfg = storage[key]
    for name, value in pairs(defaults) do
      if cfg[name] == nil then cfg[name] = value end
    end
    cfg.amount = math.max(1, math.min(1000, math.floor(tonumber(cfg.amount) or 1)))
    
    local bar = setupUI(__pvpLayouts.layout_11)
    
    local window = setupUI(__pvpLayouts.layout_12, g_ui.getRootWidget())
    window:hide()
    
    local busy = false
    
    local function itemCount(item)
      local ok, count = pcall(function() return item:getCount() end)
      if not ok or not count or count < 1 then return 1 end
      return count
    end
    
    local function findStack(itemId, amount)
      for _, container in pairs(g_game.getContainers()) do
        for _, item in ipairs(container:getItems()) do
          if item:getId() == itemId and itemCount(item) >= amount then return item end
        end
      end
      return nil
    end
    
    bar.enabled:setOn(cfg.enabled)
    bar.enabled.onClick = function(widget)
      cfg.enabled = not cfg.enabled
      widget:setOn(cfg.enabled)
    end
    
    bar.edit.onClick = function()
      window.hotkey:setText(tostring(cfg.hotkey))
      window.itemId:setText(tostring(cfg.itemId))
      window.amount:setText(tostring(cfg.amount))
      window:show()
      window:raise()
      window:focus()
    end
    
    window.close.onClick = function() window:hide() end
    window.hotkey.onTextChange = function(_, text) cfg.hotkey = text end
    window.itemId.onTextChange = function(_, text) cfg.itemId = tonumber(text) or 0 end
    window.amount.onTextChange = function(_, text)
      cfg.amount = math.max(1, math.min(1000, math.floor(tonumber(text) or 1)))
    end
    
    onKeyPress(function(keys)
      if not cfg.enabled or busy then return end
      if tostring(keys):lower() ~= tostring(cfg.hotkey):lower() then return end
      local tile = getTileUnderCursor()
      if not tile then return end
      local itemId = tonumber(cfg.itemId) or 0
      local amount = math.max(1, math.min(1000, math.floor(tonumber(cfg.amount) or 1)))
      if itemId <= 0 then return end
      busy = true
      local ok = pcall(function()
        local item = findStack(itemId, amount)
        if item then g_game.move(item, tile:getPosition(), amount) end
      end)
      busy = false
      if not ok then busy = false end
    end)
  end)
  if not masterOk then warn("[My Script Center] Trash: " .. tostring(masterError)) end
end
]====]


