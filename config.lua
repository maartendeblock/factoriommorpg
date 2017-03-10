-- config.lua
-- Configuration Options

--------------------------------------------------------------------------------
-- Messages
--------------------------------------------------------------------------------

WELCOME_MSG = "Hello!"
GAME_MODE_MSG = "Welcome to Factorio MMORPG!"
MODULES_ENABLED = "Mods Enabled: Separate Spawns, RSO, Gravestone Chests, Long-Reach, Autofill, Blueprint Strings"

WELCOME_MSG_TITLE = "A brand new world"

SPAWN_MSG1 = "Current Spawn Mode: HARDCORE WILDERNESS (Always in BETA)"
SPAWN_MSG2 = "In this mode, there is no default spawn. Everyone starts in the wild!"
SPAWN_MSG3 = "Resources are spread out far apart but are quite rich."

-- These are my specific welcome messages that get used only if I am the user
-- that creates the game.
WELCOME_MSG_OARC = "Welcome to Oarc's official server! Join the discord here: discord.gg/Wj56gkU"
WELCOME_MSG_TITLE_OARC = "Welcome to Oarc's Server"


--------------------------------------------------------------------------------
-- Module Enables
-- These enables are not fully tested!
--------------------------------------------------------------------------------

-- Separate spawns
ENABLE_SEPARATE_SPAWNS = true

-- Enable Scenario version of RSO
ENABLE_RSO = true

-- Enable Gravestone Chests
ENABLE_GRAVESTONE_CHESTS = true

-- Enable Undecorator
ENABLE_UNDECORATOR = true

-- Enable Tags
ENABLE_TAGS = true

-- Enable Long Reach
ENABLE_LONGREACH = true

-- Enable Autofill
ENABLE_AUTOFILL = true

-- Enable BPS
ENABLE_BLUEPRINT_STRING = true

-- Enable Economy
ENABLE_ECONOMY = true

-- Enable Plot
ENABLE_PLOT = true

--------------------------------------------------------------------------------
-- Spawn Options
--------------------------------------------------------------------------------

---------------------------------------
-- Distance Options
---------------------------------------
-- Moat distance (= lot size)
MOAT_DISTANCE = 80

-- Near Distance in chunks
NEAR_MIN_DIST = 25 --25
NEAR_MAX_DIST = 100 --100
                   --
-- Far Distance in chunks
FAR_MIN_DIST = 150 --100
FAR_MAX_DIST = 300 --200
                   --
---------------------------------------
-- Resource Options
---------------------------------------
WATER_SPAWN_OFFSET_X = -4
WATER_SPAWN_OFFSET_Y = -38
WATER_SPAWN_LENGTH = 8

-- Start resource amounts
START_IRON_AMOUNT = 1500
START_COPPER_AMOUNT = 1500
START_STONE_AMOUNT = 1500
START_COAL_AMOUNT = 1500
START_OIL_AMOUNT = 30000

-- Start resource shape
-- If this is true, it will be a circle
-- If false, it will be a square
ENABLE_RESOURCE_SHAPE_CIRCLE = true

-- Start resource position and size
-- Position is relative to player starting location
START_RESOURCE_STONE_POS_X = -27
START_RESOURCE_STONE_POS_Y = -34
START_RESOURCE_STONE_SIZE = 12

START_RESOURCE_COAL_POS_X = -27
START_RESOURCE_COAL_POS_Y = -20
START_RESOURCE_COAL_SIZE = 12

START_RESOURCE_COPPER_POS_X = -28
START_RESOURCE_COPPER_POS_Y = -3
START_RESOURCE_COPPER_SIZE = 14

START_RESOURCE_IRON_POS_X = -29
START_RESOURCE_IRON_POS_Y = 16
START_RESOURCE_IRON_SIZE = 16

START_RESOURCE_OIL_POS_X = -39
START_RESOURCE_OIL_POS_Y = 0

-- Force the land area circle at the spawn to be fully grass
ENABLE_SPAWN_FORCE_GRASS = true

-- Create a tree border around the spwan area
ENABLE_TREE_BORDER = false


---------------------------------------
-- Safe Spawn Area Options
---------------------------------------

-- Safe area has no aliens
-- +/- this in x and y direction
SAFE_AREA_TILE_DIST = CHUNK_SIZE*12

-- Warning area has reduced aliens
-- +/- this in x and y direction
WARNING_AREA_TILE_DIST = CHUNK_SIZE*20

-- 1 : X (spawners alive : spawners destroyed) in this area
WARN_AREA_REDUCTION_RATIO = 15

-- Create a circle of land area for the spawn
ENFORCE_LAND_AREA_TILE_DIST = 48


---------------------------------------
-- Other Forces/Teams Options
---------------------------------------

-- I am not currently implementing other teams. It gets too complicated.
-- Enable if people can join their own teams
-- ENABLE_OTHER_TEAMS = false

-- Main force is what default players join
MAIN_FORCE = "main_force"

-- Enable if people can spawn at the main base
ENABLE_DEFAULT_SPAWN = false

-- Enable if people can allow others to join their base
ENABLE_SHARED_SPAWNS = true
MAX_ONLINE_PLAYERS_AT_SHARED_SPAWN = 3


---------------------------------------
-- Special Action Cooldowns
---------------------------------------
RESPAWN_COOLDOWN_IN_MINUTES = 60
RESPAWN_COOLDOWN_TICKS = TICKS_PER_MINUTE * RESPAWN_COOLDOWN_IN_MINUTES

-- Require playes to be online for at least 5 minutes
-- Else their character is removed and their spawn point is freed up for use
MIN_ONLIME_TIME_IN_MINUTES = 5
MIN_ONLINE_TIME = TICKS_PER_MINUTE * MIN_ONLIME_TIME_IN_MINUTES


-- Allow players to choose another spawn in the first 10 minutes
-- This does not allow creating a new spawn point. Only joining other players.
-- SPAWN_CHANGE_GRACE_PERIOD_IN_MINUTES = 10
-- SPAWN_GRACE_TIME = TICKS_PER_MINUTE * SPAWN_CHANGE_GRACE_PERIOD_IN_MINUTES


--------------------------------------------------------------------------------
-- Alien Options
--------------------------------------------------------------------------------

-- Enable/Disable enemy expansion (Applies to RSO as well!)
ENEMY_EXPANSION = false

-- Divide the alien factors by this number to reduce it (or multiply if < 1)
ENEMY_POLLUTION_FACTOR_DIVISOR = 10
ENEMY_DESTROY_FACTOR_DIVISOR = 5

--------------------------------------------------------------------------------
-- Long Reach Options
--------------------------------------------------------------------------------

BUILD_DIST_BONUS = 20 --15
REACH_DIST_BONUS = BUILD_DIST_BONUS
RESOURCE_DIST_BONUS = 2

--------------------------------------------------------------------------------
-- Autofill Options
--------------------------------------------------------------------------------

AUTOFILL_TURRET_AMMO_QUANTITY = 20 --10

--------------------------------------------------------------------------------
-- Use rso_config and rso_resourece_config for RSO config settings
--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- DEBUG
--------------------------------------------------------------------------------

-- DEBUG prints for me
global.debugEnabled = true