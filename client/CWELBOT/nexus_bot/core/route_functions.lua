-- Editable Function waypoint examples. Only the helpers installed below are
-- visible to route code; native objects stay inside the bot module.
local F={}
NexusBot.RouteFunctions=F
local A=NexusBot.Automation
F.examples={
  {'Wait for PZ lock', [[if pzLocked() then
  delay(500)
  return "retry"
end
return true]]},
  {'Check stamina and imbues', [[-- Minimum stamina in minutes and remaining imbue time in seconds.
local ready = readyToHunt(840, 900)
if ready == false then
  if gotoLabel("refill") then return true end
  delay(5000)
  return "retry"
end
return ready]]},
  {'Buy 200 mana potions from Eryn', [[return buyFrom("Eryn", "mana potion", 200)]]},
  {'Say hello five times', [[say("hello")
if retries < 4 then
  delay(1000)
  return "retry"
end
return true]]},
  {'Disable TargetBot','return TargetBot.setOff()'},
  {'Enable TargetBot','return TargetBot.setOn()'},
  {'Enable TargetBot luring','return TargetBot.setLuring(true)'},
  {'Disable TargetBot luring','return TargetBot.setLuring(false)'},
  {'Logout','return logout()'},
  {'Close loot containers','return closeLootContainers()'}
}

function F.releaseTracker()
  if not F.requested then return end
  F.requested=nil
  local module=modules.game_imbuementtracker
  local button=module and module.imbuementTrackerButton
  if g_game.isOnline() and not (button and button:isOn()) then g_game.imbuementDurations(false) end
end

function F.onImbues(items)
  local shortest
  for _,item in ipairs(items or {}) do
    for _,slot in ipairs(item.slots or {}) do
      local remaining=tonumber(slot.duration)
      if remaining then shortest=math.min(shortest or remaining,remaining) end
    end
  end
  F.imbues={shortest=shortest,time=NexusBot.now()}
  F.releaseTracker()
end

local function purchase(state,npc,name,quantity)
  quantity=tonumber(quantity)
  if not quantity or quantity<1 or quantity>10000 or quantity%1~=0 then error('Invalid purchase quantity') end
  local W=A.Walker
  local vendor=A.CaveExtensions.npc(npc)
  if not vendor then error('NPC not visible: '..npc) end
  if not W.tradeNpc or W.tradeNpc:lower()~=npc:lower() or not next(W.trade) then
    if state.purchase then error('Trade closed during purchase') end
    if W.tradeNpc and W.tradeNpc~='' and next(W.trade) then error('Close trade with the other NPC first') end
    local result,reason=A.CaveExtensions.dialog(state,npc,{'hi','trade'})
    if result==false then error(reason) end
    if result==true and next(W.trade) then error('Server did not identify the expected trader') end
    return 'retry'
  end
  if A.distance(A.position(),vendor:getPosition())>3 then error('Trader is out of reach') end
  local offer,id
  for itemId,entry in pairs(W.trade) do
    if entry.buy>0 and entry.name:lower()==name:lower() then
      if offer then error('Ambiguous offer: '..name) end
      offer,id=entry,itemId
    end
  end
  if not offer then error('Missing NPC offer: '..name) end
  local count=A.countItem(id)
  local progress=state.purchase or {goal=count+quantity}
  state.purchase=progress
  if progress.pending and count<progress.pending then
    if NexusBot.now()-progress.sentAt>5000 then error('Purchase not confirmed in inventory') end
    return 'retry'
  end
  if count>=progress.goal then return true end
  local batch=math.min(100,progress.goal-count)
  progress.pending=count+batch
  progress.sentAt=NexusBot.now()
  g_game.buyItem(offer.item,batch,false,false)
  return 'retry'
end

function F.bind(env,state)
  local W=A.Walker
  env.prev=W.previousResult
  W.scriptStorage=W.scriptStorage or {}
  env.storage=W.scriptStorage
  env.pzLocked=function() return g_game.getLocalPlayer():hasState(PlayerStates.PzBlock) end
  env.readyToHunt=function(minutes,seconds)
    if g_game.getLocalPlayer():getStamina()<minutes then return false end
    local now=NexusBot.now()
    if not F.imbues or now-F.imbues.time>2000 then
      if not state.requestedAt then
        state.requestedAt=now
        F.requested=true
        g_game.imbuementDurations(true)
      elseif now-state.requestedAt>4000 then
        F.releaseTracker()
        error('Server did not supply imbuement durations')
      end
      env.delay(200)
      return 'retry'
    end
    return (F.imbues.shortest or 0)>=seconds
  end
  env.buyFrom=function(npc,name,quantity) return purchase(state,npc,name,quantity) end
  env.TargetBot={
    isOn=A.TargetBot.isOn,
    setOn=function() A.TargetBot.setOn() return A.TargetBot.isOn() end,
    setOff=function() A.TargetBot.setOff() return true end,
    setLuring=function(enabled)
      A.Targeting.routeLuringDisabled=enabled==false
      A.Targeting.lureState=false
      A.Targeting.lureRule=nil
      A.Targeting.caveDelayUntil=0
      return true
    end
  }
  local depositer={run=function()
    state.depositor=state.depositor or {}
    local result,reason=A.CaveBot.Actions.depositor.callback('',state.depositor)
    if reason then error(reason) end
    return result
  end}
  env.Depositer=depositer
  env.CaveBot={gotoLabel=env.gotoLabel,delay=env.delay,isOn=A.CaveBot.isOn,Extensions={Depositer=depositer}}
  env.logout=function()
    if env.pzLocked() or g_game.getLocalPlayer():hasState(PlayerStates.Swords) then env.delay(500) return 'retry' end
    if not state.logoutSent then state.logoutSent=true g_game.safeLogout() end
    env.delay(1000)
    return 'retry'
  end
  env.closeLootContainers=function()
    local bags=g_game.getContainers()
    for id,bag in pairs(A.Targeting.routeLootBags or {}) do
      if bags[id]==bag then g_game.close(bag) end
      A.Targeting.routeLootBags[id]=nil
    end
    return true
  end
end
