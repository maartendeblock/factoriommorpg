-- economy_control.lua
-- Main file for the economy mod. Comparable to control.lua if it was a standalone mod
-- Only put events in this file.

-- Include the other files of the mod
require("plot_config")
require("plot_gui")

-- script.on_init(function(event)
function economy_on_init(event)

end

-- script.on_event(defines.events.on_gui_click, function(event)
function economy_on_gui_click(event)
    if not (event and event.element and event.element.valid) then return end
    local name = event.element.name
	
	-- Check if it starts with economy_
	if string.sub(name,1,8) == "plot_" then
		-- Get current player
		local player = game.players[event.element.player_index]

	
	end
	
end 

-- script.on_event(defines.events.on_player_created, function(event)
function economy_on_player_created(event)
	local player = game.players[event.player_index]
	
end

-- script.on_event(defines.events.on_player_joined_game, function(event)
function economy_on_player_joined_game(event)

end