NexusBot.Validation = {}

function NexusBot.Validation.number(value, fallback, minimum, maximum)
  value = tonumber(value)
  if not value or value~=value or value==math.huge or value==-math.huge then return fallback end
  if minimum then value = math.max(minimum, value) end
  if maximum then value = math.min(maximum, value) end
  return value
end

function NexusBot.Validation.text(value, fallback)
  if type(value) ~= 'string' then return fallback or '' end
  return value
end

function NexusBot.Validation.enum(value, allowed, fallback)
  for _, candidate in ipairs(allowed or {}) do
    if value == candidate then return value end
  end
  return fallback
end

function NexusBot.Validation.rule(rule)
  if type(rule) ~= 'table' then return nil, 'rule is not a table' end
  if type(rule.id) ~= 'string' then rule.id = NexusBot.id('rule') end
  rule.enabled = rule.enabled ~= false
  rule.type = NexusBot.Validation.text(rule.type, '')
  rule.priority = NexusBot.Validation.number(rule.priority, 100, 0, 100000)
  rule.action = type(rule.action) == 'table' and rule.action or {}
  rule.conditions = type(rule.conditions) == 'table' and rule.conditions or { mode = 'AND', children = {} }
  rule.advanced = type(rule.advanced) == 'table' and rule.advanced or {}
  if rule.type == '' or (NexusBot.ActionRegistry and not NexusBot.ActionRegistry.get(rule.type)) then
    rule.enabled = false
    rule.validationWarning = 'Unknown action type: ' .. tostring(rule.type)
  end
  return rule
end
