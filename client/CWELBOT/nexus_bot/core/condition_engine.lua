NexusBot.Conditions = {}

local function distance(a, b)
  if not a or not b or a.z ~= b.z then return 99 end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

function NexusBot.Conditions.buildContext()
  local player = g_game.isOnline() and g_game.getLocalPlayer() or nil
  if not player then return nil end
  local target = g_game.getAttackingCreature()
  local position = player:getPosition()
  if not position then return nil end
  local context = {
    now = NexusBot.now(), player = player, target = target, position = position,
    health = player:getHealth(), mana = player:getMana(),
    healthPercent = player:getHealthPercent(), soul = player:getSoul(),
    capacity = player:getFreeCapacity(), floor = position.z
  }
  context.vocation = player:getVocation()
  local maxMana = player:getMaxMana()
  context.manaPercent = maxMana > 0 and math.floor(player:getMana() * 100 / maxMana) or 0
  context.targetExists = target ~= nil
  context.targetHealthPercent = target and target:getHealthPercent() or 0
  context.targetDistance = target and distance(position, target:getPosition()) or 99
  -- HP/mana/equipment rules need no map traversal. Resolve once, on demand,
  -- for count conditions, area spells, friends or alarms in this tick.
  setmetatable(context, {__index=function(t, key)
    if key == 'spectators' then
      local spectators = g_map.getSpectators(position, false) or {}
      rawset(t, key, spectators)
      return spectators
    end
  end})
  function context.count(kind, radius)
    local count = 0
    radius = tonumber(radius) or 99
    for _, creature in ipairs(context.spectators) do
      if creature ~= player and distance(position, creature:getPosition()) <= radius then
        if kind == 'monster' and creature:isMonster() then count = count + 1
        elseif kind == 'player' and creature:isPlayer() then count = count + 1
        elseif kind == 'creature' then count = count + 1 end
      end
    end
    return count
  end
  return context
end

local operators = {
  ['<'] = function(a, b) return a < b end,
  ['<='] = function(a, b) return a <= b end,
  ['='] = function(a, b) return a == b end,
  ['=='] = function(a, b) return a == b end,
  ['>='] = function(a, b) return a >= b end,
  ['>'] = function(a, b) return a > b end,
  between = function(a, b, c) return a >= math.min(b, c) and a <= math.max(b, c) end,
  outside = function(a, b, c) return a < math.min(b, c) or a > math.max(b, c) end
}

function NexusBot.Conditions.compare(actual, operator, value, value2)
  local callback = operators[operator or '<=']
  if not callback then return false end
  if type(actual) == 'boolean' then return callback(actual, value == true, value2 == true) end
  actual, value, value2 = tonumber(actual), tonumber(value), tonumber(value2)
  if actual == nil or value == nil then return false end
  if (operator == 'between' or operator == 'outside') and value2 == nil then return false end
  return callback(actual, value, value2)
end

function NexusBot.Conditions.evaluateCondition(condition, context)
  if type(condition) ~= 'table' or condition.enabled == false then return true end
  local definition = NexusBot.ConditionRegistry.get(condition.type)
  if not definition or type(definition.resolve) ~= 'function' then return false end
  local ok, actual = pcall(definition.resolve, context, condition)
  if not ok then
    NexusBot.Logger.warn('Conditions', actual)
    return false
  end
  if definition.boolean then return actual == (condition.value ~= false) end
  return NexusBot.Conditions.compare(actual, condition.operator, condition.value, condition.value2)
end

local function evaluateGroup(group, context)
  if not group or group.enabled == false then return nil end
  if group.type and group.type ~= 'group' then return NexusBot.Conditions.evaluateCondition(group, context) end
  local children = group.children or {}
  local mode = group.mode == 'OR' and 'OR' or 'AND'
  local active = false
  for _, child in ipairs(children) do
    local result = evaluateGroup(child, context)
    if result ~= nil then
      active = true
      if mode == 'AND' and not result then return false end
      if mode == 'OR' and result then return true end
    end
  end
  if not active then return nil end
  return mode == 'AND'
end

function NexusBot.Conditions.evaluate(group, context)
  local result = evaluateGroup(group, context)
  return result == nil or result
end

function NexusBot.Conditions.summary(group, depth)
  if not group or group.enabled == false then return 'Always' end
  depth = depth or 0
  if group.type and group.type ~= 'group' then
    local definition = NexusBot.ConditionRegistry.get(group.type)
    local text = (definition and definition.shortName or group.type) .. ' ' .. (group.operator or '') .. ' ' .. tostring(group.value)
    if group.operator == 'between' or group.operator == 'outside' then text = text .. '..' .. tostring(group.value2) end
    return text
  end
  local children = group.children or {}
  if #children == 0 then return 'Always' end
  if depth >= 2 then return (group.mode or 'AND') .. ' group (' .. #children .. ')' end
  local parts = {}
  for i = 1, math.min(2, #children) do
    local text = NexusBot.Conditions.summary(children[i], depth + 1)
    parts[#parts + 1] = children[i].type == 'group' and ('(' .. text .. ')') or text
  end
  return table.concat(parts, ' ' .. (group.mode or 'AND') .. ' ') .. (#children > 2 and (' +' .. (#children - 2)) or '')
end

local conditions = {
  { id='health_percent', name='Health Percentage', shortName='HP%', resolve=function(c) return c.healthPercent end },
  { id='mana_percent', name='Mana Percentage', shortName='MP%', resolve=function(c) return c.manaPercent end },
  { id='health_value', name='Health Value', shortName='HP', resolve=function(c) return c.health end },
  { id='mana_value', name='Mana Value', shortName='MP', resolve=function(c) return c.mana end },
  { id='target_exists', name='Target Exists', shortName='Target', boolean=true, resolve=function(c) return c.targetExists end },
  { id='no_target', name='No Target', shortName='No target', boolean=true, resolve=function(c) return not c.targetExists end },
  { id='target_hp', name='Target HP %', shortName='Target HP%', resolve=function(c) return c.targetHealthPercent end },
  { id='target_distance', name='Target Distance', shortName='Distance', resolve=function(c) return c.targetDistance end },
  { id='target_count', name='Target Count', shortName='Targets', resolve=function(c) return c.targetExists and 1 or 0 end },
  { id='monster_count', name='Monster Count', shortName='Monsters', resolve=function(c, x)
    if c.currentRule and (x.autoSpellPreset or (c.currentRule.action or {}).footprint) then return NexusBot.Spells.countAffected(c.currentRule,c,x.radius) end
    return c.count('monster', x.radius)
  end },
  { id='player_count', name='Player Count', shortName='Players', resolve=function(c, x) return c.count('player', x.radius) end },
  { id='creature_count', name='Creature Count', shortName='Creatures', resolve=function(c, x) return c.count('creature', x.radius) end },
  { id='range', name='Range', shortName='Range', resolve=function(c) return c.targetDistance end },
  { id='soul', name='Soul', shortName='Soul', resolve=function(c) return c.soul end },
  { id='capacity', name='Capacity', shortName='Cap', resolve=function(c) return c.capacity end },
  { id='floor', name='Position / Floor', shortName='Floor', resolve=function(c) return c.floor end },
  { id='cooldown_ready', name='Cooldown Ready', shortName='Ready', boolean=true, resolve=function(c, x) return NexusBot.Actions.isReady(x.actionId or c.currentRuleId, c.now) end }
}
for _, definition in ipairs(conditions) do NexusBot.registerCondition(definition) end

function NexusBot.Conditions.registerCustom(id, name, callback)
  return NexusBot.registerCondition({ id = id, name = name, shortName = name, resolve = callback })
end
