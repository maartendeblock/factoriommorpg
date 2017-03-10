-- economy.lua
-- Main file for the economy mod

-- Include the config
require("economy_config")

-- script.on_init(function(event)
function economy_on_init(event)
	-- Create global table keeping track of all credits
    if (global.economyCredits == nil) then
        global.economyCredits = {}
    end	
end

-- script.on_event(defines.events.on_player_created, function(event)
function economy_on_player_created(event)
	local player = game.players[event.player_index]
	
	-- Give the player starting credits
	global.economyCredits[player.name] = ECONOMY_PLAYER_STARTING_CREDITS
end