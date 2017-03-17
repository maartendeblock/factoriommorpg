-- plot_gui.lua
-- GUI related funtctions

function plot_gui_top_button_create(event)
  local player = game.players[event.player_index]
  if player.gui.top.debug == nil then
  	  player.gui.top.add{name="plot_top_button", type="button", caption="Plots"}
  end  
end

function plot_top_button_click(event)
	plot_gui_available_plots(event)
end


function plot_gui_available_plots(event)
	local frame = gui_utils_frame_create_center(event, "plot_gui_available_plots", "PLOTS FOR SALE!!!", 500, 500, "vertical")
	
	for i=1,PLOT_STARTING_COUNT, 1
	do
	   frame.add{name = "plot_buy_" .. i, type = "button", caption=i}
	end
	
	gui_utils_frame_spacer_add(frame)
	gui_utils_frame_spacer_add(frame)
	gui_utils_frame_spacer_add(frame)
	gui_utils_frame_spacer_add(frame)


end