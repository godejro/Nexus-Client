-- DELAYS: GUI first; shared action gates below. Reachable from BOT CONFIG.
local category=NexusBot.Categories.define('delays','DELAYS',16,true)
local D={}
NexusBot.Features.Delays=D

category.open=function()
  local U=NexusBot.UI local c=D.config()
  local w,p=NexusBot.Features.Modern.shared.formWindow('DELAYS',295) w:setWidth(350)
  U.toggle(p,'Shared item cooldown',c.items,function(v) c.items=v end)
  U.numberInput(p,'Item delay ms',c.itemMs,100,5000,function(v) c.itemMs=v end)
  U.toggle(p,'Include server ping',c.includePing,function(v) c.includePing=v end)
  U.toggle(p,'Pause non-healing on lag',c.networkGuard,function(v) c.networkGuard=v end)
  U.numberInput(p,'Maximum ping ms',c.maxPing,100,5000,function(v) c.maxPing=v end)
  return w
end

function D.config()
  local data=NexusBot.Storage.get() data.integrations=data.integrations or {}
  if not data.integrations.delays then data.integrations.delays={items=false,itemMs=1000,includePing=false,networkGuard=false,maxPing=700} end
  return data.integrations.delays
end
function D.isItem(rule) return rule.type=='item' or rule.type=='rune' or rule.type=='use_item' end
function D.ping()
  local value=g_game.getPing and tonumber(g_game.getPing()) or 0
  return math.max(0,math.min(value or 0,10000))
end
function D.allows(rule,context)
  local c=D.config()
  if c.networkGuard and context.providerId~='healer' and D.ping()>(tonumber(c.maxPing) or 700) then return false end
  return not (c.items and D.isItem(rule) and context.now<(D.itemReady or 0))
end
function D.executed(rule,context)
  local c=D.config()
  if c.items and D.isItem(rule) then
    D.itemReady=context.now+NexusBot.Validation.number(c.itemMs,1000,100,5000)+(c.includePing and D.ping() or 0)
  end
end
category.init=function()
  D.itemReady=0
  if D.handlers then disconnect(g_game,D.handlers) end
  D.handlers={onGameEnd=function() D.itemReady=0 end}
  connect(g_game,D.handlers)
end
category.terminate=function()
  D.itemReady=0
  if D.handlers then disconnect(g_game,D.handlers) D.handlers=nil end
end
