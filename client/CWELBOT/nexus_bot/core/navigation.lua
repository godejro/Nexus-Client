local A=NexusBot.Automation
A.Navigation={nextWalk=0}
local N=A.Navigation
N.directions={{0,-1,0},{1,0,1},{0,1,2},{-1,0,3},{1,-1,4},{1,1,5},{-1,1,6},{-1,-1,7}}
function N.reset()
  if N.pending and N.pending.route and g_game.isOnline() then
    if g_game.stop then g_game.stop() end
    local player=g_game.getLocalPlayer()
    if player and player.stopAutoWalk then player:stopAutoWalk() end
  end
  N.nextWalk=0 N.pending=nil N.blocked={} N.budget=nil
end
function N.beginTick()
  N.budget=2200 N.lastExpanded=0 N.lastBudgetHit=false
  N.nativeBudget=3
  N.tileCache={}
  local now=NexusBot.now()
  for key,expires in pairs(N.blocked or {}) do if expires<=now then N.blocked[key]=nil end end
end
-- Use the client's explored minimap for remote route recovery. Send only the
-- currently visible, checked prefix; discover/revalidate the next part on ACK.
function N.mappedPath(start,goal,transition,visibleOnly)
  if not g_map.findPath or not start or not goal or start.z~=goal.z or A.distance(start,goal)>64 then return nil end
  if (N.nativeBudget or 0)<=0 then return nil end
  N.nativeBudget=N.nativeBudget-1
  local path=g_map.findPath(start,goal,2000,0)
  if type(path)~='table' or #path==0 then return nil end
  if not visibleOnly then return path end
  local result={} local p={x=start.x,y=start.y,z=start.z}
  for _,direction in ipairs(path) do
    local d=N.directions[direction+1] if not d then return nil end
    p={x=p.x+d[1],y=p.y+d[2],z=p.z}
    if not N.safeTile(p,transition and A.distance(p,goal)==0) then break end
    result[#result+1]=direction
    if #result>=12 then break end
  end
  if #result>0 then return result end
end
function N.transition(tile)
  if not tile then return false end
  if A.call(tile,'hasFloorChange',false) then return true end
  for _,item in ipairs(A.call(tile,'getItems',{})) do
    if A.call(item,'isGround',false) and A.call(item,'hasFloorChange',false) then return true end
    local kind=A.call(item,'getThingType')
    if not kind and g_things and g_things.getThingType then kind=g_things.getThingType(item:getId(),ThingCategoryItem or 0) end
    if A.call(kind,'hasFloorChange',false) then return true end
    local id=item:getId()
    if id==1946 or id==1947 or id==1387 or (id>=2118 and id<=2132) then return true end
  end
  return false
end
function N.hazard(tile)
  if not tile or N.transition(tile) then return true end
  for _,item in ipairs(A.call(tile,'getItems',{})) do
    if A.call(item,'isMagicField',false) then return true end
  end
  return false
end
function N.safeTile(p,allowTransition)
  if N.blocked and (N.blocked[A.key(p)] or 0)>NexusBot.now() then return false end
  local key=A.key(p)..(allowTransition and ':transition' or ':normal')
  if N.tileCache and N.tileCache[key]~=nil then return N.tileCache[key] end
  local tile=g_map.getTile(p)
  local safe=tile~=nil and A.call(tile,'isWalkable',false,false)
  if safe and not allowTransition then safe=not N.hazard(tile) and A.call(tile,'isPathable',true) end
  if N.tileCache then N.tileCache[key]=safe end
  return safe
end
function N.path(start,goal,range,transition,constraint)
  if not start or not goal or start.z~=goal.z then return nil end
  range=range or 0
  if A.distance(start,goal)<=range then return {} end
  local heap={} local costs={[A.key(start)]=0} local expanded=0
  local function push(node)
    local i=#heap+1 heap[i]=node
    while i>1 do local parent=math.floor(i/2) if heap[parent].f<=node.f then break end heap[i]=heap[parent] i=parent end heap[i]=node
  end
  local function pop()
    local result=heap[1] local last=table.remove(heap)
    if #heap>0 then
      local i=1
      while i*2<=#heap do
        local child=i*2 if child+1<=#heap and heap[child+1].f<heap[child].f then child=child+1 end
        if last.f<=heap[child].f then break end heap[i]=heap[child] i=child
      end heap[i]=last
    end return result
  end
  push({p=start,g=0,f=A.distance(start,goal)*10})
  while #heap>0 and expanded<450 do
    if N.budget and N.budget<=0 then N.lastBudgetHit=true return nil end
    local node=pop() expanded=expanded+1 N.lastExpanded=(N.lastExpanded or 0)+1
    if N.budget then N.budget=N.budget-1 end
    if A.distance(node.p,goal)<=range then
      local path={} while node.parent do table.insert(path,1,node.direction) node=node.parent end return path
    end
    if node.g==costs[A.key(node.p)] then
    for _,d in ipairs(N.directions) do
      local p={x=node.p.x+d[1],y=node.p.y+d[2],z=start.z}
      local key=A.key(p)
      -- Tibia charges three orthogonal step durations for a diagonal step.
      local cost=node.g+(d[1]~=0 and d[2]~=0 and 30 or 10)
      if (not costs[key] or cost<costs[key]) and A.distance(start,p)<=18 then
        local final=A.distance(p,goal)==0
        local safe=(not constraint or constraint(p)) and N.safeTile(p,transition and final)
        -- Like the native OTC pathfinder, validate the destination itself.
        -- Adjacent decorations do not make a free diagonal tile unwalkable.
        if safe then
          costs[key]=cost
          push({p=p,parent=node,direction=d[3],g=cost,f=cost+math.max(0,A.distance(p,goal)-range)*10})
        end
      end
    end
    end
  end
end
function N.walk(goal,range,transition,routeWalk,constraint)
  local player=g_game.getLocalPlayer() local pos=A.position() local now=NexusBot.now()
  if not pos or not goal or pos.z~=goal.z then return false,'Different floor; add a transition waypoint.' end
  if A.distance(pos,goal)<=(range or 0) then N.pending=nil return true,'arrived' end
  if N.pending then
    if N.pending.route then
      local pending=N.pending
      if pending.goal~=A.key(goal) then N.reset()
      else
        if A.key(pos)~=pending.from then
          local found
          for index=pending.index,#pending.route do
            if pending.route[index]==A.key(pos) then found=index break end
          end
          if not found then N.reset()
          else
            pending.index=found+1 pending.from=A.key(pos)
            pending.untilTime=now+pending.timeout
            if pending.index>#pending.route then N.pending=nil end
          end
        end
        if N.pending then
          if now<pending.untilTime then return false,'waiting' end
          local blocked=pending.route[pending.index]
          N.reset()
          if blocked then N.blocked[blocked]=now+1500 end
        end
      end
    elseif A.key(pos)~=N.pending.from then N.pending=nil
    elseif now>=N.pending.untilTime then
      N.blocked=N.blocked or {} N.blocked[N.pending.destination]=now+1500 N.pending=nil
    else return false,'waiting' end
  end
  if now<N.nextWalk or (not routeWalk and A.call(player,'isWalking',false)) then return false,'waiting' end
  local path=N.path(pos,goal,range,transition,constraint)
  local config=A.CaveBot and A.CaveBot.Config and A.CaveBot.Config.values
  if not path and routeWalk and not constraint and config and config.autoNavigate then
    path=N.mappedPath(pos,goal,transition,true)
  end
  N.nextWalk=now+math.max(0,tonumber(config and config.stepDelay) or 180)
  if not path or not path[1] then return false,'No safe visible path. Move closer or add intermediate waypoints.' end
  if A.call(player,'isAutoWalking',false) and player.stopAutoWalk then player:stopAutoWalk() end
  if routeWalk and g_game.autoWalk then
    -- Send the reviewed path to this exact waypoint, like Classic OTC.
    -- Only authoritative position changes advance the route cursor.
    local route={} local current={x=pos.x,y=pos.y,z=pos.z}
    while #path>127 do table.remove(path) end
    for _,direction in ipairs(path) do
      local d=N.directions[direction+1]
      current={x=current.x+d[1],y=current.y+d[2],z=current.z}
      route[#route+1]=A.key(current)
    end
    local timeout=math.max(1200,math.max(0,tonumber(g_game.getPing and g_game.getPing()) or 0)*3+A.call(player,'getStepDuration',350)*2)
    N.pending={from=A.key(pos),goal=A.key(goal),route=route,index=1,timeout=timeout,untilTime=now+timeout}
    g_game.autoWalk(path,pos)
    return false,'walking'
  end
  if g_game.walk(path[1])==false then return false,'Walk rejected by client.' end
  local step=N.directions[path[1]+1]
  local duration=A.call(player,'getStepDuration',350)
  local ping=math.max(0,tonumber(g_game.getPing and g_game.getPing()) or 0)
  N.pending={from=A.key(pos),destination=A.key({x=pos.x+step[1],y=pos.y+step[2],z=pos.z}),untilTime=now+math.max(350,duration*2+ping*3)}
  return false,'walking'
end
function N.walkRoute(goal,range,transition,constraint) return N.walk(goal,range,transition,true,constraint) end
function N.onCancelWalk()
  local pending=N.pending
  if not pending then return end
  local blocked=pending.route and pending.route[pending.index] or pending.destination
  N.pending=nil N.nextWalk=0
  if blocked then N.blocked=N.blocked or {} N.blocked[blocked]=NexusBot.now()+1500 end
end
function N.step(direction)
  local pos=A.position() if not pos then return false end
  local d=N.directions[direction+1] if not d then return false end
  local p={x=pos.x+d[1],y=pos.y+d[2],z=pos.z}
  return N.walk(p,0,false)
end
