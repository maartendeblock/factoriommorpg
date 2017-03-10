-- economy_gui.lua
-- GUI related funtctions

function economy_gui_top_button_create(event)
  local player = game.players[event.player_index]
  if player.gui.top.debug == nil then
  	  player.gui.top.add{name="economy_top_button", type="button", caption="Economy"}
  end  
end

function economy_top_button_click(event)
	DebugPrint("Economy Top button clicked")
end