-- plot_control.lua
-- Main file for the economy mod. Comparable to control.lua if it was a standalone mod
-- Only put events in this file.

-- Include the other files of the mod
require("plot_config")
require("plot_gui")
require("plot_main")

-- script.on_init(function(event)
function plot_on_init(event)
	-- Create global table keeping track of all plots
    if (global.plot_table == nil) then
        global.plot_table = {}
		
		local rows = math.ceil(math.sqrt(PLOT_STARTING_COUNT))
		local x = 0
		local y = 0
		
		for i=1,rows, 1
		do
			for j=1,rows, 1
			do
				local plot_number = ((i-1) * rows) + j
				global.plot_table[plot_number] = {}
				global.plot_table[plot_number]["outer_corners"] = {}
				global.plot_table[plot_number]["inner_corners"] = {}

				global.plot_table[plot_number]["outer_corners"]["top_left"] = { (j - 1) * PLOT_SIZE, (i - 1) * PLOT_SIZE } 	   
				global.plot_table[plot_number]["inner_corners"]["top_left"] = { ((j - 1) * PLOT_SIZE) + PLOT_INNER_CORNER_OFFSET, ((i - 1) * PLOT_SIZE) + PLOT_INNER_CORNER_OFFSET }

				global.plot_table[plot_number]["outer_corners"]["top_right"] = { ((j - 1) * PLOT_SIZE) + PLOT_SIZE, (i - 1) * PLOT_SIZE } 
				global.plot_table[plot_number]["inner_corners"]["top_right"] = { ((j - 1) * PLOT_SIZE) + PLOT_SIZE - PLOT_INNER_CORNER_OFFSET, ((i - 1) * PLOT_SIZE) + PLOT_INNER_CORNER_OFFSET }

				global.plot_table[plot_number]["outer_corners"]["bottom_left"] = { (j - 1) * PLOT_SIZE, ((i - 1) * PLOT_SIZE) + PLOT_SIZE } 
				global.plot_table[plot_number]["inner_corners"]["bottom_left"] = { ((j - 1) * PLOT_SIZE) + PLOT_INNER_CORNER_OFFSET, (((i - 1) * PLOT_SIZE)) + PLOT_SIZE - PLOT_INNER_CORNER_OFFSET }

				global.plot_table[plot_number]["outer_corners"]["bottom_right"] = { ((j - 1) * PLOT_SIZE) + PLOT_SIZE, ((i - 1) * PLOT_SIZE) + PLOT_SIZE } 
				global.plot_table[plot_number]["inner_corners"]["bottom_right"] = { (((j - 1) * PLOT_SIZE) + PLOT_SIZE) - PLOT_INNER_CORNER_OFFSET, (((i - 1) * PLOT_SIZE)) + PLOT_SIZE - PLOT_INNER_CORNER_OFFSET }
				
				global.plot_table[plot_number]["center"] = {}
				global.plot_table[plot_number]["center"][1] = math.floor(global.plot_table[plot_number]["outer_corners"]["top_left"][1] + (global.plot_table[plot_number]["outer_corners"]["top_right"][1] - global.plot_table[plot_number]["outer_corners"]["top_left"][1]) / 2)
				global.plot_table[plot_number]["center"][2] = math.floor(global.plot_table[plot_number]["outer_corners"]["top_left"][2] + (global.plot_table[plot_number]["outer_corners"]["bottom_left"][2] - global.plot_table[plot_number]["outer_corners"]["top_left"][2]) / 2)
			end
		end
    end	
end

-- script.on_event(defines.events.on_gui_click, function(event)
function plot_on_gui_click(event)
    if not (event and event.element and event.element.valid) then return end
    local name = event.element.name
	
	-- Check if it starts with plot_
	if string.sub(name,1,5) == "plot_" then
		-- Get current player
		local player = game.players[event.element.player_index]
		
		if name == "plot_top_button" then
			plot_gui_available_plots(event)
		elseif string.sub(name, 1, 9) == "plot_buy_" then
		local plot_number = tonumber(string.sub(name, 10))
			plot_buy(event, plot_number)
			player.teleport(global.plot_table[plot_number]["center"])
		end

	
	end
	
end 

-- script.on_event(defines.events.on_player_created, function(event)
function plot_on_player_created(event)
	local player = game.players[event.player_index]
	
	
	
end

-- script.on_event(defines.events.on_player_joined_game, function(event)
function plot_on_player_joined_game(event)
	plot_gui_top_button_create(event)
	for i=1,PLOT_STARTING_COUNT, 1
		do
		-- DebugPrint(i .. ' TL ' .. ' ' .. global.plot_table[i]["outer_corners"]["top_left"][1] .. ',' .. global.plot_table[i]["outer_corners"]["top_left"][2])
		-- DebugPrint(i .. ' TR ' .. ' ' .. global.plot_table[i]["outer_corners"]["top_right"][1] .. ',' .. global.plot_table[i]["outer_corners"]["top_right"][2])
		-- DebugPrint(i .. ' BL ' .. ' ' .. global.plot_table[i]["outer_corners"]["bottom_left"][1] .. ',' .. global.plot_table[i]["outer_corners"]["bottom_left"][2])
		-- DebugPrint(i .. ' BR ' .. ' ' .. global.plot_table[i]["outer_corners"]["bottom_right"][1] .. ',' .. global.plot_table[i]["outer_corners"]["bottom_right"][2])

		-- DebugPrint(i .. ' TL ' .. ' ' .. global.plot_table[i]["inner_corners"]["top_left"][1] .. ',' .. global.plot_table[i]["inner_corners"]["top_left"][2])
		-- DebugPrint(i .. ' TR ' .. ' ' .. global.plot_table[i]["inner_corners"]["top_right"][1] .. ',' .. global.plot_table[i]["inner_corners"]["top_right"][2])
		-- DebugPrint(i .. ' BL ' .. ' ' .. global.plot_table[i]["inner_corners"]["bottom_left"][1] .. ',' .. global.plot_table[i]["inner_corners"]["bottom_left"][2])
		-- DebugPrint(i .. ' BR ' .. ' ' .. global.plot_table[i]["inner_corners"]["bottom_right"][1] .. ',' .. global.plot_table[i]["inner_corners"]["bottom_right"][2])
		
		DebugPrint(i .. ' center ' .. ' ' .. global.plot_table[i]["center"][1] .. ',' .. global.plot_table[i]["center"][2])


	end
end