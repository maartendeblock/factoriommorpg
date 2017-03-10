-- economy_control.lua
-- Main file for the economy mod. Comparable to control.lua if it was a standalone mod
-- Only put events in this file.

-- Include the other files of the mod
require("economy_config")
require("economy_gui")

-- script.on_init(function(event)
function economy_on_init(event)
	-- Create global table keeping track of all credits
    if (global.economyCredits == nil) then
        global.economyCredits = {}
    end	
end

-- script.on_event(defines.events.on_gui_click, function(event)
function economy_on_gui_click(event)
    if not (event and event.element and event.element.valid) then return end
    local name = event.element.name
	
	-- Check if it starts with economy_
	if string.sub(name,1,8) == "economy_" then
		-- Get current player
		local player = game.players[event.element.player_index]
		
		if name == "economy_top_button" then
			economy_top_button_click(event)
		end
	
	end
	
end 

-- script.on_event(defines.events.on_player_created, function(event)
function economy_on_player_created(event)
	local player = game.players[event.player_index]
	
	-- Give the player starting credits
	global.economyCredits[player.name] = ECONOMY_PLAYER_STARTING_CREDITS
end

-- script.on_event(defines.events.on_player_joined_game, function(event)
function economy_on_player_joined_game(event)
	-- Create the main button on top of the screen
	economy_gui_top_button_create(event)

end