NexusBot.Categories={entries={},order={}}
local C=NexusBot.Categories
function C.define(id,title,order,hidden)
  assert(not C.entries[id],'Duplicate category: '..id)
  local category={id=id,title=title,order=order,hidden=hidden==true}
  C.entries[id]=category C.order[#C.order+1]=category
  return category
end
function C.list()
  local result={}
  for _,category in ipairs(C.order) do
    if not category.hidden then result[#result+1]=category end
  end
  table.sort(result,function(a,b) return a.order<b.order end)
  return result
end
function C.initialize()
  for _,category in ipairs(C.order) do
    if category.init then category.init() end
    if category.open then
      local current=category
      NexusBot.registerModule({id=current.id,title=current.title,open=function()
        NexusBot.Features.Modern.shared.bindRuntime()
        return current.open()
      end})
    end
  end
end

function C.terminate()
  for _,category in ipairs(C.order) do
    if category.terminate then NexusBot.safeCall(category.id..':terminate',category.terminate) end
  end
end

function C.setEnabled(category,value)
  if not category.setEnabled then return end
  if value and not NexusBot.enabled then
    -- Starting one category must not resume every saved category.
    for _,other in ipairs(C.order) do
      if other~=category and other.setEnabled then other.setEnabled(false) end
    end
    NexusBot.setEnabled(true)
  end
  category.setEnabled(value==true)
  NexusBot.Storage.touch()
  if NexusBot.Launcher.refresh then NexusBot.Launcher.refresh() end
end

function C.profilePower(category)
  category.getEnabled=function()
    local profile=NexusBot.Profiles.getActive(category.id)
    return profile and profile.enabled==true or false
  end
  category.setEnabled=function(value)
    local profile=NexusBot.Profiles.getActive(category.id)
    if profile then profile.enabled=value end
  end
end
