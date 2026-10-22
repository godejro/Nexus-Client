-- HUD: GUI first; implementation and initialization below.
local category = NexusBot.Categories.define('hud', 'HUD', 15, true)

-- ==================== GUI / LAYOUT ====================
local showTitle=NexusBot.LegacyWindows.showTitle
local definition={title='HUD',rows={
    {name='Analytics HUD',edit=function() return showTitle('Analytics Selector') end},
    {name='Party Analyzer',edit=function() return showTitle('Party Hunt') end},
    {name='Player List',edit=function() return showTitle('Player List') end}
  }}
category.open=function() return NexusBot.LegacyWindows.make('hud',definition) end

-- ==================== LOGIC / RUNTIME ====================
-- Hidden compatibility route; not added to the launcher.
