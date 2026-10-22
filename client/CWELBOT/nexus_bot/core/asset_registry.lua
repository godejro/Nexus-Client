NexusBot.Assets={}
function NexusBot.Assets.init()
  NexusBot.assetRoot=(configDir or NexusBot.resourceRoot or '/nexus_bot')..'/nexus_visuals_v1'
  if NexusBot.embeddedAssets then
    if not g_resources.directoryExists(NexusBot.assetRoot) then g_resources.makeDir(NexusBot.assetRoot) end
    for name,encoded in pairs(NexusBot.embeddedAssets) do
      local path=NexusBot.assetRoot..'/'..name..'.png'
      if not g_resources.fileExists(path) then g_resources.writeFileContents(path,base64.decode(encoded)) end
    end
  else NexusBot.assetRoot=(NexusBot.resourceRoot or '/nexus_bot')..'/assets' end
end
function NexusBot.Assets.get(id)
  return NexusBot.assetRoot..'/'..id..'.png'
end
NexusBot.Assets.resolve=NexusBot.Assets.get
NexusBot.AssetResolver=NexusBot.Assets
