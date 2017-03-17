function CreateDebugGui(event)
  local player = game.players[event.player_index]
  if player.gui.top.debug == nil then
  	  player.gui.top.add{name="debug", type="button", caption="Debug"}
  end   
end

local function ExpandDebugGui(player)
    local frame = player.gui.left["debug-panel"]

    if (frame) then
        frame.destroy()
    else
        local frame = player.gui.left.add{type="frame", name="debug-panel", caption="Don't push any buttons"}
		
		frame.add{type="button", caption="Spawn", name="debug-spawn"}
		
		--frame.add{name = "debug_forcesScore", type = "label", caption="score: " .. global.forcesScore[player.name]}
		--ApplyStyle(frame.debug_forcesScore, my_label_style) 
		
		--frame.add{name = "debug_playerCredits", type = "label", caption="credits: " .. global.economyCredits[player.name]}
		--ApplyStyle(frame.debug_playerCredits, my_label_style) 
    end
end

function DebugGuiClick(event) 
    if not (event and event.element and event.element.valid) then return end
    local player = game.players[event.element.player_index]
    local name = event.element.name

	if (name == "debug") then
		ExpandDebugGui(player)		
	end
	
	if (name == "debug-spawn") then
		DisplaySpawnOptions(player)		
	end
	
	if (name == "Clear") then 
		player.tag = ""
		return
	end
    
end

-- Print debug only to me while testing.
function DebugPrint(msg)
    if ((game.players["Maniah"] ~= nil) and (global.debugEnabled)) then
        game.players["Maniah"].print("DEBUG: " .. msg)
    end
end