-- Explicit tile masks, north-facing. Baseline: Canary register_spells.lua.
-- A server/wheel variant must select its own mask; unknown areas fail closed.
NexusBot.Geometry = {}
local G=NexusBot.Geometry
G.masks={
  adjacent={'111','131','111'}, wave4={'11111','01110','01110','00300'},
  squarewave5={'111','111','111','010','030'}, wave7={'11111','11111','01110','01110','00300'},
  shortwave3={'111','111','030'}, sweep={'131'},
  beam5={'1','1','1','1','3'}, beam6={'1','1','1','1','1','3'}, beam7={'1','1','1','1','1','1','3'}, beam8={'1','1','1','1','1','1','1','3'},
  flurry={'00100','01110','01310','01010'}, greater_flurry={'00100','01110','01110','11311','01010'},
  sweeping={'01110','11111','11111','11311','11011'},
  burst={'000111000','001111100','011111110','111000111','111020111','111000111','011111110','001111100','000111000'},
  diamond2={'00100','01110','11311','01110','00100'},
  square2={'11111','11111','11311','11111','11111'},
  circle2={'01110','11111','11311','11111','01110'},
  circle3={'0011100','0111110','1111111','1113111','1111111','0111110','0011100'}
}
for _,radius in ipairs({5,6}) do
  local rows={}
  for y=-radius,radius do local row=''
    for x=-radius,radius do row=row..(x==0 and y==0 and '3' or (math.abs(x)+math.abs(y)<=radius and '1' or '0')) end
    rows[#rows+1]=row
  end
  G.masks['diamond'..radius]=rows
end
G.spells={['exori']='adjacent',['exori gran']='adjacent',['exori min']='sweep',
  ['exevo flam hur']='wave4',['exevo frigo hur']='wave4',
  ['exevo vis hur']='squarewave5',['exevo tera hur']='squarewave5',
  ['exevo gran flam hur']='wave7',['exevo gran frigo hur']='shortwave3',
  ['exevo vis lux']='beam5',['exevo gran vis lux']='beam8',
  ['exori mas']='circle3',['exevo mas san']='circle3',
  ['exevo gran mas flam']='diamond5',['exevo gran mas vis']='diamond6',
  ['exevo gran mas frigo']='diamond5',['exevo gran mas tera']='diamond6',
  ['exori mas pug']='flurry',['exori gran mas pug']='greater_flurry',['exori mas nia']='sweeping',
  ['exevo ulus frigo']='burst',['exevo ulus tera']='burst'}
G.spells['exori scu']='adjacent'
G.spells['exevo fur frigo']='chain'
G.spells['exevo fur tera']='chain'
G.spells['exori dir moe']='diamond2'
G.spells['exori dir san']='diamond2'
-- Reference server footprints; variants can override them in Pattern.
G.spells['exori mas amp pug']='circle3'
G.spells['exevo mort ora']='square2'
G.centered={['exori dir moe']=true,['exori dir san']=true,['exori mas amp pug']=true,['exevo mort ora']=true}
G.chain={['exevo fur frigo']={targets=7,jump=5},['exevo fur tera']={targets=6,jump=5}}
G.directional={['exori mas pug']=true,['exori gran mas pug']=true,['exori mas nia']=true}
G.runes={[3161]='circle3',[3191]='circle3'}
local function words(value) return tostring(value or ''):lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ') end
G.cache={}
function G.parse(text)
  if type(text)~='string' or #text>220 then return nil,'Mask must be at most 13 x 13.' end
  if G.cache[text] then return G.cache[text] end
  local rows={} for row in text:gmatch('[^/\r\n]+') do rows[#rows+1]=row end
  if #rows==0 or #rows>13 then return nil,'Mask must be at most 13 x 13.' end
  local ax,ay,width=nil,nil,#rows[1]
  if width<1 or width>13 then return nil,'Invalid width.' end
  for y,row in ipairs(rows) do
    if #row~=width or row:find('[^0123]') then return nil,'Use equal rows of 0/1 and one 2/3 (origin).' end
    for x=1,width do if row:sub(x,x)=='3' or row:sub(x,x)=='2' then
      if ax then return nil,'Only one origin is allowed.' end ax,ay=x,y
    end end
  end
  if not ax then return nil,'Missing origin (3).' end
  local offsets={}
  for y,row in ipairs(rows) do for x=1,width do
    if row:sub(x,x)=='1' or row:sub(x,x)=='3' then offsets[#offsets+1]={x=x-ax,y=y-ay} end
  end end
  -- Bounded cache, including user edits; no per-frame mask parsing.
  G.cacheCount=(G.cacheCount or 0)+1
  if G.cacheCount>128 then G.cache={} G.cacheCount=1 end
  G.cache[text]=offsets return offsets
end
function G.shape(rule)
  local action=rule.action or {}
  if rule.type=='targeted_spell' or (rule.type=='rune' and not action.areaRune) then return 'target' end
  if action.customMask and action.customMask~='' then return 'custom' end
  if action.geometryPreset and G.masks[action.geometryPreset] then return action.geometryPreset end
  if rule.type=='rune' then return G.runes[tonumber(action.itemId)] or 'unknown' end
  return G.spells[words(action.spell)] or 'unknown'
end
function G.offsets(rule)
  local shape=G.shape(rule)
  if shape=='custom' then return G.parse(rule.action.customMask) end
  if G.masks[shape] then return G.parse(table.concat(G.masks[shape],'/')) end
end
local function distance(a,b)
  if not a or not b or a.z~=b.z then return math.huge end
  return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))
end
function G.visible(a,b)
  if not a or not b or a.z~=b.z then return false end
  return not g_map or not g_map.isSightClear or g_map.isSightClear(a,b)
end
local function rotated(p,d)
  if d==1 then return -p.y,p.x elseif d==2 then return -p.x,-p.y elseif d==3 then return p.y,-p.x end
  return p.x,p.y
end
function G.matchesMonster(rule,creature)
  if not creature or not creature:isMonster() then return false end
  local a=rule.action or {}
  local hp=creature.getHealthPercent and creature:getHealthPercent() or 100
  if hp<(tonumber(a.targetHpMin) or 0) or hp>(tonumber(a.targetHpMax) or 100) then return false end
  local name=creature.getName and creature:getName():lower() or ''
  local function matches(patterns,wildcards)
    for entry in tostring(patterns or ''):lower():gmatch('[^,;\r\n]+') do
      entry=entry:match('^%s*(.-)%s*$')
      if wildcards then
        local pattern=entry:gsub('.',function(ch)
          if ch=='*' then return '.*' elseif ch=='?' then return '.' end
          if ch:find('[%^%$%(%)%%%.%[%]%+%-%?]') then return '%'..ch end return ch
        end)
        if name:match('^'..pattern..'$') then return true end
      elseif name==entry then return true end
    end
    return false
  end
  if matches(a.ignoreNames,false) then return false end
  return matches(a.monsterNames or '*',true)
end
function G.plan(rule,context,direction,center)
  local action=rule.action or {} local shape=G.shape(rule)
  local range=tonumber((rule.advanced or {}).range) or 5
  if shape=='chain' then return G.chainPlan(rule,context) end
  if shape=='target' then
    local t=context.target local p=t and t:getPosition()
    local valid=p and distance(context.position,p)<=range and t:canShoot()
    if valid and t:isMonster() and not G.matchesMonster(rule,t) then valid=false end
    return {count=valid and t:isMonster() and 1 or 0,valid=not not valid,players=valid and t:isPlayer() and 1 or 0,center=p}
  end
  local offsets=G.offsets(rule)
  if not offsets then return {valid=false,count=0,players=0,reason='Configure an exact area mask.'} end
  if not center and G.centered[words(action.spell)] then
    center=context.target and context.target:getPosition() or context.position
    if distance(context.position,center)>range or not G.visible(context.position,center) then return {valid=false,count=0,players=0} end
  end
  center=center or context.position direction=direction or 0
  if rule.type=='rune' and (distance(context.position,center)>range or not G.visible(context.position,center)) then return {valid=false,count=0,players=0} end
  local hits={}
  for _,p in ipairs(offsets) do
    local dx,dy=rotated(p,direction)
    hits[(center.x+dx)..','..(center.y+dy)]=true
  end
  local result={valid=true,count=0,players=0,center=center,direction=direction}
  for _,c in ipairs(context.spectators or {}) do
    local p=c:getPosition()
    if c~=context.player and p and p.z==center.z and hits[p.x..','..p.y] and G.visible(center,p) then
      if G.matchesMonster(rule,c) then result.count=result.count+1 elseif c:isPlayer() then result.players=result.players+1 end
    end
  end
  return result
end
-- A fork is not a cone. Predict nearest successive creatures, not tiles in a
-- bounding square. Server-side PvP eligibility and unseen creatures are unknown;
-- Avoid players therefore conservatively rejects any reachable player branch.
function G.chainPlan(rule,context)
  local spec=G.chain[words((rule.action or {}).spell)]
  if not spec then return {valid=false,count=0,players=0} end
  local range=tonumber((rule.advanced or {}).range) or 7
  local candidates={} local seen={}
  for _,c in ipairs(context.spectators or {}) do
    if c~=context.player and (c:isMonster() or c:isPlayer()) and not seen[c:getId()] then
      candidates[#candidates+1]=c seen[c:getId()]=true
    end
  end
  if context.target and not seen[context.target:getId()] then candidates[#candidates+1]=context.target end
  local visited={} local current=context.position
  local result={valid=false,count=0,players=0,center=context.position}
  for index=1,spec.targets do
    local chosen,bestDistance
    for _,c in ipairs(candidates) do
      local p=c:getPosition()
      if not visited[c:getId()] and distance(current,p)<=(index==1 and range or spec.jump) and G.visible(current,p) then
        local d=(current.x-p.x)^2+(current.y-p.y)^2
        if index==1 and c==context.target then d=-1 end
        if not chosen or d<bestDistance or (d==bestDistance and c:getId()<chosen:getId()) then chosen,bestDistance=c,d end
        if c:isPlayer() then result.players=result.players+1 end
      end
    end
    if not chosen then break end
    visited[chosen:getId()]=true current=chosen:getPosition() result.valid=true
    if index==1 then result.center=current end
    if G.matchesMonster(rule,chosen) then result.count=result.count+1 end
  end
  return result
end
function G.best(rule,context)
  local action=rule.action or {} local best
  local function consider(plan)
    if not plan.valid or (action.avoidPlayers~=false and plan.players>0 and G.shape(rule)~='target') then return end
    if context.providerId=='magic_shooter' and action.countOperator and not NexusBot.Conditions.compare(plan.count,action.countOperator,tonumber(action.minimumHits) or 1) then return end
    if not best or plan.count>best.count then best=plan end
  end
  if rule.type=='rune' and action.areaRune then
    if action.aim=='best_tile' then
      -- Reverse the mask once per creature instead of rescanning all creatures
      -- and rebuilding the hit set for every candidate tile.
      local candidates={} local offsets=G.offsets(rule) or {}
      local range=math.min(8,tonumber((rule.advanced or {}).range) or 5)
      for _,c in ipairs(context.spectators or {}) do if G.matchesMonster(rule,c) then
        local p=c:getPosition()
        if p and p.z==context.position.z then for _,o in ipairs(offsets) do
          local center={x=p.x-o.x,y=p.y-o.y,z=p.z} local key=center.x..','..center.y
          if distance(context.position,center)<=range and G.visible(center,p) then
            local plan=candidates[key]
            if not plan then plan={valid=true,count=0,players=0,center=center,direction=0} candidates[key]=plan end
            plan.count=plan.count+1
          end
        end end
      end end
      for _,c in ipairs(context.spectators or {}) do if c~=context.player and c:isPlayer() then
        local p=c:getPosition()
        if p and p.z==context.position.z then for _,o in ipairs(offsets) do
          local plan=candidates[(p.x-o.x)..','..(p.y-o.y)]
          if plan and G.visible(plan.center,p) then plan.players=plan.players+1 end
        end end
      end end
      local ordered={} for _,plan in pairs(candidates) do ordered[#ordered+1]=plan end
      table.sort(ordered,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        local da,db=distance(context.position,a.center),distance(context.position,b.center)
        if da~=db then return da<db end
        if a.center.x~=b.center.x then return a.center.x<b.center.x end
        return a.center.y<b.center.y
      end)
      for _,plan in ipairs(ordered) do
        if (action.avoidPlayers==false or plan.players==0) and G.visible(context.position,plan.center) then
          local tile=g_map.getTile(plan.center)
          if tile and tile:getTopUseThing() then consider(plan) if best then break end end
        end
      end
    else consider(G.plan(rule,context,0,context.target and context.target:getPosition() or context.position)) end
  elseif rule.type=='directional_spell' then
    local preferred=NexusBot.Spells.direction(rule,context)
    consider(G.plan(rule,context,preferred))
    if (rule.pattern or {}).autoFace~=false then for d=0,3 do if d~=preferred then consider(G.plan(rule,context,d)) end end end
  else consider(G.plan(rule,context,0)) end
  return best or {valid=false,count=0,players=0,reason='No safe area / unknown mask.'}
end
