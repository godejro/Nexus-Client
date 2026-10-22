NexusBot.Fields={}

local function register(id, render)
  NexusBot.registerField({id=id,render=render})
end

register('boolean',function(parent,field,value,changed)
  return NexusBot.UI.toggle(parent,field.label or field.key,value==true,changed,field.tooltip)
end)
register('number',function(parent,field,value,changed)
  return NexusBot.UI.numberInput(parent,field.label or field.key,value,field.minimum,field.maximum,changed)
end)
register('percentage',function(parent,field,value,changed)
  return NexusBot.UI.numberInput(parent,field.label or field.key,value,0,100,changed)
end)
register('enum',function(parent,field,value,changed)
  return NexusBot.UI.combo(parent,field.label or field.key,field.options or {},value,changed)
end)
register('spell',function(parent,field,value,changed)
  return NexusBot.UI.spellPicker(parent,field.label or field.key,value,changed)
end)
register('item',function(parent,field,value,changed)
  return NexusBot.UI.itemPicker(parent,field.label or field.key,value,changed)
end)
register('hotkey',function(parent,field,value,changed)
  return NexusBot.UI.textInput(parent,field.label or field.key,value,changed)
end)
register('text',function(parent,field,value,changed)
  return NexusBot.UI.textInput(parent,field.label or field.key,value,changed)
end)
register('creature',function(parent,field,value,changed)
  return NexusBot.UI.textInput(parent,field.label or field.key,value,changed)
end)
register('range',function(parent,field,value,changed)
  value=type(value)=='table' and value or {minimum=0,maximum=100}
  NexusBot.UI.numberInput(parent,(field.label or field.key)..' minimum',value.minimum,field.minimum or 0,field.maximum or 999999,function(current) value.minimum=current changed(value) end)
  return NexusBot.UI.numberInput(parent,(field.label or field.key)..' maximum',value.maximum,field.minimum or 0,field.maximum or 999999,function(current) value.maximum=current changed(value) end)
end)
register('position',function(parent,field,value,changed)
  value=type(value)=='table' and value or {x=0,y=0,z=0}
  for _,axis in ipairs({'x','y','z'}) do
    NexusBot.UI.numberInput(parent,(field.label or 'Position')..' '..axis:upper(),value[axis],0,65535,function(current) value[axis]=current changed(value) end)
  end
end)
register('conditions',function(parent,field,value,changed,context)
  if context and context.controller and context.rule then return NexusBot.Inspector.conditions(context.controller,parent,context.rule) end
end)

function NexusBot.Fields.render(parent,fields,model,context)
  for _,field in ipairs(fields or {}) do
    local definition=NexusBot.FieldRegistry.get(field.type)
    if definition and definition.render then
      definition.render(parent,field,model[field.key],function(value)
        model[field.key]=value NexusBot.Storage.touch()
        if context and context.onChange then context.onChange(field,value) end
      end,context)
    else
      NexusBot.Logger.warn('Fields','Unknown field type: '..tostring(field.type))
    end
  end
end

