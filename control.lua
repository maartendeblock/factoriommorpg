-- control.lua

-- Factorio MMORPG
-- code based on
-- Oarc's Separated Spawn Scenario
-- 
-- Credit:
--  RSO mod to RSO author - Orzelek - I contacted him via the forum
--  Tags - Taken from WOGs scenario 
--  Event - Taken from WOGs scenario (looks like original source was 3Ra)
--

-- Generic Utility Includes
require("locale/oarc_utils")
require("locale/debug/debug")
require("locale/economy/economy_control")
require("locale/plot/plot_control")
require("locale/rso/rso_control")
require("locale/tag")
require("locale/blueprintstring/bps")

-- Main Configuration File
require("config")

-- Scenario Specific Includes
require("separate_spawns")
require("separate_spawns_guis")

--------------------------------------------------------------------------------
-- ALL EVENT HANLDERS ARE HERE IN ONE PLACE!
--------------------------------------------------------------------------------


----------------------------------------
-- On Init - only runs once the first 
--   time the game starts
----------------------------------------
script.on_init(function(event)

    -- Configures the map settings for enemies
    -- This controls evolution growth factors and enemy expansion settings.
    ConfigureAlienStartingParams()

    if ENABLE_SEPARATE_SPAWNS then
        InitSpawnGlobalsAndForces()
    end

    if ENABLE_BLUEPRINT_STRING then
        bps_init()
    end
	
	if ENABLE_ECONOMY then
		economy_on_init(event)
	end	
	
	if ENABLE_ECONOMY then
		plot_on_init(event)
	end	

    global.welcome_msg = WELCOME_MSG
    global.welcome_msg_title = WELCOME_MSG_TITLE
end)

----------------------------------------
-- Chunk Generation
----------------------------------------
script.on_event(defines.events.on_chunk_generated, function(event)
    if ENABLE_UNDECORATOR then
        UndecorateOnChunkGenerate(event)
    end

    if ENABLE_RSO then
        RSO_ChunkGenerated(event)
    end

    -- This MUST come after RSO generation!
    if ENABLE_SEPARATE_SPAWNS then
        SeparateSpawnsGenerateChunk(event)
    end
end)


----------------------------------------
-- Gui Click
----------------------------------------
script.on_event(defines.events.on_gui_click, function(event)
    DebugGuiClick(event)
	
	if ENABLE_TAGS then
        TagGuiClick(event)
    end

    if ENABLE_SEPARATE_SPAWNS then
        WelcomeTextGuiClick(event)
        SpawnOptsGuiClick(event)
        SpawnCtrlGuiClick(event)
        SharedSpwnOptsGuiClick(event)
    end

    if ENABLE_BLUEPRINT_STRING then
        bps_on_gui_click(event)
    end
	
	if ENABLE_ECONOMY then
		economy_on_gui_click(event)
	end		
end)


----------------------------------------
-- Player Events
----------------------------------------

----------------------------------------
-- Player joined the game
----------------------------------------
script.on_event(defines.events.on_player_joined_game, function(event)
    PlayerJoinedMessages(event)

    if ENABLE_TAGS then
        CreateTagGui(event)
    end
	
	if ENABLE_ECONOMY then
        economy_on_player_joined_game(event)
    end
	
	CreateDebugGui(event)
end)

----------------------------------------
-- New player created
----------------------------------------
script.on_event(defines.events.on_player_created, function(event)
    SetOarcServerMessages(event)

    if ENABLE_LONGREACH then
        GivePlayerLongReach(game.players[event.player_index])
    end

    if not ENABLE_SEPARATE_SPAWNS then
        PlayerSpawnItems(event)
    else
        SeparateSpawnsPlayerCreated(event)
    end
	
	if ENABLE_ECONOMY then
		economy_on_player_created(event)
	end	
	
	local player = game.players[event.player_index]
	game.create_force(player.name)
	
	-- Disable landfill
	game.forces[player.name].technologies["landfill"].enabled = false
	
	-- Give a random score
	global.forcesScore[player.name] = 100

    -- Not sure if this should be here or in player joined....
    if ENABLE_BLUEPRINT_STRING then
        bps_player_joined(event)
    end
end)

----------------------------------------
-- Player died
----------------------------------------
script.on_event(defines.events.on_player_died, function(event)
    if ENABLE_GRAVESTONE_CHESTS then
        CreateGravestoneChestsOnDeath(event)
    end
end)

----------------------------------------
-- Player respawned
----------------------------------------
script.on_event(defines.events.on_player_respawned, function(event)
    if not ENABLE_SEPARATE_SPAWNS then
        PlayerRespawnItems(event)
    else 
        SeparateSpawnsPlayerRespawned(event)
    end

    if ENABLE_LONGREACH then
        GivePlayerLongReach(game.players[event.player_index])
    end
end)

----------------------------------------
-- Player leaves
----------------------------------------
script.on_event(defines.events.on_player_left_game, function(event)
    if ENABLE_SEPARATE_SPAWNS then
        FindUnusedSpawns(event)
    end
end)


----------------------------------------
-- Entity built
----------------------------------------
script.on_event(defines.events.on_built_entity, function(event)
    if ENABLE_AUTOFILL then
        Autofill(event)
    end
end)



----------------------------------------
-- On Research Finished
----------------------------------------
script.on_event(defines.events.on_research_finished, function(event)

    if ENABLE_BLUEPRINT_STRING then
        bps_on_research_finished(event)
    end

    -- Example of how to remove a particular recipe:
    -- RemoveRecipe(event, "beacon")
end)


----------------------------------------
-- BPS Specific Event
----------------------------------------
script.on_event(defines.events.on_robot_built_entity, function(event)
    if ENABLE_BLUEPRINT_STRING then
        bps_on_robot_built_entity(event)
    end
end

)