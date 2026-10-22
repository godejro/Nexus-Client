NexusBot.Registry = {}

local function createRegistry(name)
  local registry = { name = name, entries = {}, order = {} }
  function registry.register(definition)
    if type(definition) ~= 'table' or not definition.id then
      return NexusBot.Logger.warn(name, 'Ignored definition without id')
    end
    if not registry.entries[definition.id] then registry.order[#registry.order + 1] = definition.id end
    registry.entries[definition.id] = definition
    return definition
  end
  function registry.get(id) return registry.entries[id] end
  function registry.all()
    local result = {}
    for _, id in ipairs(registry.order) do result[#result + 1] = registry.entries[id] end
    return result
  end
  function registry.clear() registry.entries = {} registry.order = {} end
  return registry
end

NexusBot.ModuleRegistry = createRegistry('ModuleRegistry')
NexusBot.ActionRegistry = createRegistry('ActionRegistry')
NexusBot.ConditionRegistry = createRegistry('ConditionRegistry')
NexusBot.FieldRegistry = createRegistry('FieldRegistry')

function NexusBot.registerModule(value) return NexusBot.ModuleRegistry.register(value) end
function NexusBot.registerAction(value) return NexusBot.ActionRegistry.register(value) end
function NexusBot.registerCondition(value) return NexusBot.ConditionRegistry.register(value) end
function NexusBot.registerField(value) return NexusBot.FieldRegistry.register(value) end

