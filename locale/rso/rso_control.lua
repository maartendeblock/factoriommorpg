require("locale/rso/rso_config")
require("util")
require("locale/rso/rso_resource_config")
require("locale/oarc_utils")
require("config")

local MB=require("locale/rso/metaball")
local drand = require("locale/rso/drand")
local rng = drand.mwvc
if not deterministic then rng = drand.sys_rand end

-- math shortcuts
local floor = math.floor
local abs = math.abs
local cos = math.cos
local sin = math.sin
local pi = math.pi
local max = math.max

local function round(value)
	return math.floor(value + 0.5)
end

local function debug(str)
	if debug_enabled then
		game.players[1].print(str)
	end
end

-- constants
local CHUNK_SIZE = 32
local REGION_TILE_SIZE = CHUNK_SIZE*region_size
local MIN_BALL_DISTANCE = CHUNK_SIZE/6
local P_BALL_SIZE_FACTOR = 0.7
local N_BALL_SIZE_FACTOR = 0.95
local NEGATIVE_MODIFICATOR = 123456

local meta_shapes = nil

if use_donut_shapes then
	meta_shapes = {MB.MetaEllipse, MB.MetaSquare, MB.MetaDonut}
else
	meta_shapes = {MB.MetaEllipse, MB.MetaSquare}
end	

-- local globals
local index_is_built = false
local max_allotment = 0
local rgen = nil
local distance = util.distance
local spawner_probability_edge = 0  -- below this value a biter spawner, above/equal this value a spitter spawner
local invalidResources = {}
local config = nil
local configIndexed = nil

-- map gen settings mapping

local startingAreaMultiplier =
{
	none = 0,
	["very-low"] = 0.25,
	low = 0.5,
	normal = 1,
	high = 1.5,
	["very-high"] = 2,
}

local frequencyAllotmentMultiplier =
{
	["very-low"] = 0.5,
	low = 0.75,
	normal = 1,
	high = 1.5,
	["very-high"] = 2,
}

local sizeMultiplier =
{
	none = 0,
	["very-low"] = 0.5,
	low = 0.75,
	normal = 1,
	high = 1.25,
	["very-high"] = 1.5,
}

local richnessMultiplier =
{
	["very-low"] = 0.125,
	low = 0.25,
	normal = 1,
	high = 2,
	["very-high"] = 4,
}

local entityFrequencyMultiplier =
{
	["very-low"] = 0.25,
	low = 0.5,
	normal = 1,
	high = 2,
	["very-high"] = 4,
}

local entitySizeMultiplier =
{
	none = 0,
	["very-low"] = 0.5,
	low = 0.75,
	normal = 1,
	high = 2,
	["very-high"] = 4,
}

--[[ HELPER METHODS ]]--

local function normalize(n) --keep numbers at (positive) 32 bits
	return floor(n) % 0x80000000
end

local function bearing(origin, dest)
	-- finds relative angle
	local xd = dest.x - origin.x
	local yd = dest.y - origin.y
	return math.atan2(xd, yd);
end

local function str2num(s)
	local num = 0
	for i=1,s:len() do
		num=num + (s:byte(i) - 33)*i
	end
	return num
end

local function mult_for_pos(pos)
	local num = 0
	local x = pos.x
	local y = pos.y
	
	if x == 0 then x = 0.5 end
	if y == 0 then y = 0.5 end
	if x < 0 then
		x = abs(x) + NEGATIVE_MODIFICATOR
	end
	if y < 0 then
		y = abs(y) + NEGATIVE_MODIFICATOR
	end
	
	return drand.lcg(y, 'mvc'):random(0)*drand.lcg(x, 'nr'):random(0)
end

local function rng_for_reg_pos(pos)
	local rgen = rng(normalize(global.seed*mult_for_pos(pos)))
	rgen:random()
	rgen:random()
	rgen:random()
	return rgen
end

local function rng_restricted_angle(restrictions)
	local rng = rgen:random()
	local x_scale, y_scale
	local deformX = rgen:random() * 2 - 1
	local deformY = rgen:random() * 2 - 1
	
	if restrictions=='xy' then
		y_scale=1.0 + deformY*0.5
		x_scale=1.0 + deformX*0.5
		angle = rng*pi*2  
	elseif restrictions=='x' then
		y_scale=1.0 + deformY*0.6
		x_scale=1.0 + deformX*0.6
		angle = rng*pi/2 - pi/4
	elseif restrictions=='y' then
		y_scale=1.0 + deformY*0.6
		x_scale=1.0 + deformX*0.6
		angle = rng*pi/2 + pi/2
	else
		y_scale=1.0 + deformY*0.3
		x_scale=1.0 + deformX*0.3
		angle = rng*pi*2
	end
	
	return angle, x_scale, y_scale
end

local function vary_by_percentage(x, p)
	return x + (0.5 - rgen:random())*2*x*p
end


local function remove_trees(surface, x, y, x_size, y_size )
	local bb={{x - x_size, y - y_size}, {x + x_size, y + y_size}}
	for _, entity in pairs(surface.find_entities_filtered{area = bb, type="tree"}) do
		if entity.valid then
			entity.destroy()
		end
	end
end

local function removeDecorations(surface, x, y, width, height )
	local bb={{x, y}, {x + width, y + height}}
	for _, entity in pairs(surface.find_entities_filtered{area = bb, type="decorative"}) do
		if entity.valid then
			entity.destroy()
		end
	end
end

local function find_intersection(surface, x, y)
	-- try to get position in between of valid chunks by probing map
	-- this may breaks determinism of generation, but so far it returned on first if
	local gt = surface.get_tile
	local restriction = ''
	if gt(x + CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid then
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y).valid and gt(x, y + CHUNK_SIZE*2).valid then
		x=x + CHUNK_SIZE/2
		y=y + CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y).valid and gt(x, y - CHUNK_SIZE*2).valid then
		x=x + CHUNK_SIZE/2
		y=y - CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x - CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y).valid and gt(x, y + CHUNK_SIZE*2).valid then
		x=x - CHUNK_SIZE/2
		y=y + CHUNK_SIZE/2
		restriction = 'xy'    
	elseif gt(x - CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y).valid and gt(x, y - CHUNK_SIZE*2).valid then
		x=x - CHUNK_SIZE/2
		y=y - CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y).valid then
		x=x + CHUNK_SIZE/2
		restriction = 'x'
	elseif gt(x - CHUNK_SIZE*2, y).valid then
		x=x - CHUNK_SIZE/2
		restriction = 'x'
	elseif gt(x, y + CHUNK_SIZE*2).valid then
		y=y + CHUNK_SIZE/2
		restriction = 'y'
	elseif gt(x, y - CHUNK_SIZE*2).valid then
		y=y - CHUNK_SIZE/2
		restriction = 'y'
	end
	return x, y, restriction
end

local function find_random_chunk(r_x, r_y)
	local offset_x=rgen:random(region_size)-1
	local offset_y=rgen:random(region_size)-1
	local c_x=r_x*REGION_TILE_SIZE + offset_x*CHUNK_SIZE
	local c_y=r_y*REGION_TILE_SIZE + offset_y*CHUNK_SIZE
	return c_x, c_y
end

local function is_same_region(c_x1, c_y1, c_x2, c_y2)
	if not floor(c_x1/REGION_TILE_SIZE) == floor(c_x2/REGION_TILE_SIZE) then
		return false
	end
	if not floor(c_y1/REGION_TILE_SIZE) == floor(c_y2/REGION_TILE_SIZE) then
		return false
	end
	return true
end

local function find_random_neighbour_chunk(ocx, ocy)
	-- somewhat bruteforce and unoptimized
	local x_dir = rgen:random(-1,1)
	local y_dir = rgen:random(-1,1)
	local ncx = ocx + x_dir*CHUNK_SIZE
	local ncy = ocy + y_dir*CHUNK_SIZE
	if is_same_region(ncx, ncy, ocx, ocy) then
		return ncx, ncy
	end
	
	ncx = ocx - x_dir*CHUNK_SIZE
	ncy = ocy - y_dir*CHUNK_SIZE
	if is_same_region(ncx, ncy, ocx, ocy) then
		return ncx, ncy
	end
	
	ncx = ocx - x_dir*CHUNK_SIZE
	if is_same_region(ncx, ocy, ocx, ocy) then
		return ncx, ocy
	end
	
	ncy = ocy - y_dir*CHUNK_SIZE
	if is_same_region(ocx, ncy, ocx, ocy) then
		return ocx, ncy
	end
	
	return ocx, ocy
end

local function isInStartingArea( regionX, regionY )

	for idx, pos in pairs( global.startingAreas ) do
		
		local adjustedX = regionX - pos.x / REGION_TILE_SIZE
		local adjustedY = regionY - pos.y / REGION_TILE_SIZE
		if ((adjustedX * adjustedX + adjustedY * adjustedY) <= starting_area_size * starting_area_size) then
			return true
		end
	end

	return false
end

-- modifies the resource size - only used in endless_resource_mode
local function modify_resource_size(resourceName, resourceSize, startingArea)
	
	if not startingArea then
		resourceSize = math.ceil(resourceSize * global_size_mult)
	end
	
	resourceEntity = game.entity_prototypes[resourceName]
	if resourceEntity and resourceEntity.infinite_resource then
		
		newResourceSize = resourceSize * endless_resource_mode_sizeModifier
		
		-- make sure it's still an integer
		newResourceSize = math.ceil(newResourceSize)
		-- make sure it's not 0
		if newResourceSize == 0 then newResourceSize = 1 end
		return newResourceSize
	else
		return resourceSize
	end
end

--[[ SPAWN METHODS ]]--

local locationOrder =
{
	{ x = 0, y = 0 },
	{ x = -1, y = 0 },
	{ x = 1, y = 0 },
	{ x = 0, y = -1 },
	{ x = 0, y = 1 },
	{ x = -1, y = -1 },
	{ x = 1, y = -1 },
	{ x = -1, y = 1 },
	{ x = 1, y = 1 }
}

--[[ entity-field ]]--
local function spawn_resource_ore(surface, rname, pos, size, richness, startingArea, restrictions)
	-- blob generator, centered at pos, size controls blob diameter
	restrictions = restrictions or ''
	debug("Entering spawn_resource_ore "..rname.." at:"..pos.x..","..pos.y.." size:"..size.." richness:"..richness.." isStart:"..tostring(startingArea).." restrictions:"..restrictions)
	
	size = modify_resource_size(rname, size, startingArea)
	local radius = size / 2 -- to radius
	
	local p_balls={}
	local n_balls={}
	local MIN_BALL_DISTANCE = math.min(MIN_BALL_DISTANCE, radius/2)
	
	local maxPradius = 0	
	local outside = { xmin = 1e10, xmax = -1e10, ymin = 1e10, ymax = -1e10 }
	local inside = { xmin = 1e10, xmax = -1e10, ymin = 1e10, ymax = -1e10 }
	
	local function adjustRadius(radius, scaleX, scaleY, up)
		return radius
	end
	
	local function updateRect(rect, x, y, radius)
		rect.xmin = math.min(rect.xmin, x - radius)
		rect.xmax = math.max(rect.xmax, x + radius)
		rect.ymin = math.min(rect.ymin, y - radius)
		rect.ymax = math.max(rect.ymax, y + radius)
	end

	local function updateRects(x, y, radius, scaleX, scaleY)
		local adjustedRadius = adjustRadius(radius, scaleX, scaleY, true)
		local radiusMax = adjustedRadius * 3 -- arbitrary multiplier - needs to be big enough to not cut any metaballs
		updateRect(outside, x, y, radiusMax)
		updateRect(inside, x, y, adjustedRadius)
	end
	
	local function generate_p_ball()
		local angle, x_scale, y_scale, x, y, b_radius, shape
		angle, x_scale, y_scale=rng_restricted_angle(restrictions)
		local dev = radius / 2 + rgen:random() * radius / 4--math.min(CHUNK_SIZE/3, radius*1.5)
		local dev_x, dev_y = pos.x, pos.y
		x = rgen:random(-dev, dev)+dev_x
		y = rgen:random(-dev, dev)+dev_y
		if p_balls[#p_balls] and distance(p_balls[#p_balls], {x=x, y=y}) < MIN_BALL_DISTANCE then
			local new_angle = bearing(p_balls[#p_balls], {x=x, y=y})
			debug("Move ball old xy @ "..x..","..y)
			x=(cos(new_angle)*MIN_BALL_DISTANCE) + x
			y=(sin(new_angle)*MIN_BALL_DISTANCE) + y
			debug("Move ball new xy @ "..x..","..y)
		end
		
		if #p_balls == 0 then
			b_radius = ( 3 * radius / 4 + rgen:random() * radius / 4) -- * (P_BALL_SIZE_FACTOR^#p_balls)
		else
			b_radius = ( radius / 4 + rgen:random() * radius / 2) -- * (P_BALL_SIZE_FACTOR^#p_balls)
		end
		
		
		if #p_balls > 0 then
			local tempRect = table.deepcopy(inside)
			updateRect(tempRect, x, y, adjustRadius(b_radius, x_scale, y_scale))
			local rectSize = math.max(tempRect.xmax - tempRect.xmin, tempRect.ymax - tempRect.ymin)
			local targetSize = size * 1.25
			debug("Rect size "..rectSize.." targetSize "..targetSize)
			if rectSize > targetSize then
				local widthLeft = (targetSize - (inside.xmax - inside.xmin))
				local heightLeft = (targetSize - (inside.ymax - inside.ymin))
				local widthMod = math.min(x - inside.xmin, inside.xmax - x)
				local heightMod = math.min(y - inside.ymin, inside.ymax - y)
				local radiusBackup = b_radius
				b_radius = math.min(widthLeft + widthMod, heightLeft + heightMod)
				b_radius = adjustRadius(b_radius, x_scale, y_scale, false)
				debug("Reduced ball radius from "..radiusBackup.." to "..b_radius.." widthLeft:"..widthLeft.." heightLeft:"..heightLeft.." widthMod:"..widthMod.." heightMod:"..heightMod)
			end
		end

		if b_radius < 2 and #p_balls == 0 then
			b_radius = 2
		end
		
		if b_radius > 0 then
			
			maxPradius = math.max(maxPradius, b_radius)
			shape = meta_shapes[rgen:random(1,#meta_shapes)]
			local radiusText = ""
			if shape.type == "MetaDonut" then
				local inRadius = b_radius / 4 + b_radius / 2 * rgen:random()
				radiusText = " inRadius:"..inRadius
				p_balls[#p_balls+1] = shape:new(x, y, b_radius, inRadius, angle, x_scale, y_scale, 1.1)
			else
				p_balls[#p_balls+1] = shape:new(x, y, b_radius, angle, x_scale, y_scale, 1.1)
			end
			updateRects(x, y, b_radius, x_scale, y_scale)
		
			debug("P+Ball "..shape.type.." @ "..x..","..y.." radius: "..b_radius..radiusText.." angle: "..math.deg(angle).." scale: "..x_scale..", "..y_scale)
		end
	end
	
	local function generate_n_ball(i)
		local angle, x_scale, y_scale, x, y, b_radius, shape
		angle, x_scale, y_scale=rng_restricted_angle('xy')
		if p_balls[i] then
			local new_angle = p_balls[i].angle + pi*rgen:random(0,1) + (rgen:random()-0.5)*pi/2
			local dist = p_balls[i].radius
			x=(cos(new_angle)*dist) + p_balls[i].x
			y=(sin(new_angle)*dist) + p_balls[i].y
			angle = p_balls[i].angle + pi/2 + (rgen:random()-0.5)*pi*2/3
		else
			x = rgen:random(-radius, radius)+pos.x
			y = rgen:random(-radius, radius)+pos.y
		end
		
		if p_balls[i] then
			b_radius = (p_balls[i].radius / 4 + rgen:random() * p_balls[i].radius / 2) -- * (N_BALL_SIZE_FACTOR^#n_balls)
		else
			b_radius = (radius / 4 + rgen:random() * radius / 2) -- * (N_BALL_SIZE_FACTOR^#n_balls)
		end
		
		if b_radius < 1 then
			b_radius = 1
		end
		
		shape = meta_shapes[rgen:random(1,#meta_shapes)]
		local radiusText = ""
		if shape.type == "MetaDonut" then
			local inRadius = b_radius / 4 + b_radius / 2 * rgen:random()
			radiusText = " inRadius:"..inRadius
			n_balls[#n_balls+1] = shape:new(x, y, b_radius, inRadius, angle, x_scale, y_scale, 1.15)
		else
			n_balls[#n_balls+1] = shape:new(x, y, b_radius, angle, x_scale, y_scale, 1.15)
		end
		-- updateRects(x, y, b_radius, x_scale, y_scale) -- should not be needed here - only positive ball can generate ore
		debug("N-Ball "..shape.type.." @ "..x..","..y.." radius: "..b_radius..radiusText.." angle: "..math.deg(angle).." scale: "..x_scale..", "..y_scale)
	end
	
	local function calculate_force(x,y)
		local p_force = 0
		local n_force = 0
		for _,ball in ipairs(p_balls) do
			p_force = p_force + ball:force(x,y)
		end
		for _,ball in ipairs(n_balls) do
			n_force = n_force + ball:force(x,y)
		end
		local totalForce = 0
		if p_force > n_force then
			totalForce = 1 - 1/(p_force - n_force)
		end
		--debug("Force at "..x..","..y.." p:"..p_force.." n:"..n_force.." result:"..totalForce)
		--return (1 - 1/p_force) - n_force
		return totalForce
	end  
	
	local max_p_balls = 2
	local min_amount = config[rname].min_amount or min_amount
	if restrictions == 'xy' then
		max_p_balls = 3
	end

	radius = math.min(radius, 2*CHUNK_SIZE)

	local force
	-- generate blobs
	for i=1,max_p_balls do
		generate_p_ball()
	end
	
	for i=1,rgen:random(1, #p_balls) do
		generate_n_ball(i)
	end
	

	local _total = 0
	local oreLocations = {}
	local forceTotal = 0
	
	-- fill the map
	for y=outside.ymin, outside.ymax do

		for x=outside.xmin, outside.xmax do
				force = calculate_force(x, y)
				if force > 0 then
						oreLocations[#oreLocations + 1] = {x = x, y = y, force = force, valid = false}
						forceTotal = forceTotal + force
				end
		end
	end

	local validCount, resOffsetX, resOffsetY, ratio

	for _,locationOffset in ipairs(locationOrder) do
		validCount = 0
		resOffsetX = locationOffset.x * CHUNK_SIZE
		resOffsetY = locationOffset.y * CHUNK_SIZE
		
		for _, location in ipairs(oreLocations) do
			
			local newX = location.x + resOffsetX
			local newY = location.y + resOffsetY
			location.valid = false
			if surface.can_place_entity{name = rname, position = {x = newX,y = newY}} then
				location.valid = true
				validCount = validCount + 1
			end
		end
		
		ratio = 0
		
		if validCount > 0 then
			ratio = validCount / #oreLocations
		end
		
		debug("Valid ratio ".. ratio)
		
		if not useResourceCollisionDetection then
			break
		end
		
		if ratio > resourceCollisionDetectionRatio then
			break
		elseif resourceCollisionFieldSkip then -- in case no valid ratio was found we skip the field completely
			validCount = 0
		end
	end
	
	if validCount > 0 then
		local rectSize = ((inside.xmax - inside.xmin) + (inside.ymax - inside.ymin)) / 2

		local sizeMultiplier = rectSize ^ 0.6
		local minSize = richness * 5 * sizeMultiplier
		local maxSize = richness * 10 * sizeMultiplier
		local approxDepositSize = rgen:random(minSize, maxSize)

		approxDepositSize = approxDepositSize - validCount * min_amount
		
		if approxDepositSize < 0 then
			approxDepositSize = 100 * validCount
		end

		local forceFactor = approxDepositSize / forceTotal

		-- don't create very dense resources in starting area - another field will be generated
		if startingArea and forceFactor > 4000 then
			forceFactor = rgen:random(3000, 4000)
		end

		debug( "Force total:"..forceTotal.." sizeMin:"..minSize.." sizeMax:"..maxSize.." factor:"..forceFactor.." location#:"..validCount.." rectSize:"..rectSize.." sizeMultiplier:"..sizeMultiplier)
		local richnessMultiplier = global_richness_mult
		
		if startingArea then
			richnessMultiplier = starting_richness_mult
		end
		
		-- infinite ore handling for Angels Ores mod
		local infiniteOrePresent = false
		local infiniteOreName = "infinite-"..rname
		local minimumInfiniteOreAmount = nil
		local spawnName = rname

		if game.entity_prototypes[infiniteOreName] then
			infiniteOrePresent = true
			minimumInfiniteOreAmount = game.entity_prototypes[infiniteOreName].minimum_resource_amount
		end
		
		if startingArea and not infiniteResourceInStartArea then
			infiniteOrePresent = false
		end

		for _,location in ipairs(oreLocations) do
			if location.valid then
				
				local amount = floor(( forceFactor * location.force + min_amount ) * richnessMultiplier)
				
				if amount > 1e9 then
					amount = 1e9
				end
				
				_total = _total + amount
				
				spawnName = rname
				if infiniteOrePresent and location.force > infiniteResourceSpawnThreshold then
					spawnName = infiniteOreName
					if minimumInfiniteOreAmount and amount <  minimumInfiniteOreAmount then
						amount = minimumInfiniteOreAmount
					end
				end
				
				if amount > 0 then
					surface.create_entity{name = spawnName,
						position = {location.x + resOffsetX,location.y + resOffsetY},
						force = game.forces.neutral,
						amount = amount}
				end
			end
		end
		
	end
	
	if debug_enabled then
		debug("Total amount: ".._total)
		debug("Leaving spawn_resource_ore")
	end
	return _total
end

--[[ entity-liquid ]]--
local function spawn_resource_liquid(surface, rname, pos, size, richness, startingArea, restrictions)
	restrictions = restrictions or ''
	debug("Entering spawn_resource_liquid "..rname.." "..pos.x..","..pos.y.." "..size.." "..richness.." "..tostring(startingArea).." "..restrictions)
	local _total = 0
	local max_radius = rgen:random()*CHUNK_SIZE/2 + CHUNK_SIZE
	
	richness = ( 0.75 + rgen:random() / 2 ) * richness * size
	
	resourceEntity = game.entity_prototypes[rname]
	
	
	local total_share = 0
	local avg_share = 1/size
	local angle = rgen:random()*pi*2
	local saved = 0
	while total_share < 1 do
		local new_share = vary_by_percentage(avg_share, 0.25)
		if new_share + total_share > 1 then
			new_share = 1 - total_share
		end
		total_share = new_share + total_share
		if new_share < avg_share/10 then
			-- too small
			break 
		end
		local amount = floor(richness*new_share) + saved
		
		local richnessMultiplier = global_richness_mult
		
		if startingArea then
			richnessMultiplier = starting_richness_mult
		end
		
		--if amount >= game.entity_prototypes[rname].minimum then 
		if amount >= config[rname].minimum_amount then 
			saved = 0
			for try=1,5 do
				local dist = rgen:random()*(max_radius - max_radius*0.1)
				angle = angle + pi/4 + rgen:random()*pi/2
				local x, y = pos.x + cos(angle)*dist, pos.y + sin(angle)*dist
				if surface.can_place_entity{name = rname, position = {x,y}} then
					debug("@ "..x..","..y.." amount: "..amount.." new_share: "..new_share.." try: "..try)
					amount = floor(amount * richnessMultiplier)
					
					if amount > 1e9 then
						amount = 1e9
					end
					
					_total = _total + amount
					
					if amount > 0 then
						surface.create_entity{name = rname,
							position = {x,y},
							force = game.forces.neutral,
							amount = amount,
							direction = rgen:random(4)}
					end
					break
				elseif not startingArea then -- we don't want to make ultra rich nodes in starting area - failing to make them will add second spawn in different location
					entities = surface.find_entities_filtered{area = {{x-2.75, y-2.75}, {x+2.75, y+2.75}}, name=rname}
					if entities and #entities > 0 then
						_total = _total + amount
						for k, ent in pairs(entities) do
							ent.amount = ent.amount + floor(amount/#entities)
						end
						break
					end
				end
			end
		else
			saved = amount
		end
	end
	debug("Total amount: ".._total)
	debug("Leaving spawn_resource_liquid")
	return _total
end

local spawnerTable = nil

local function initSpawnerTable()
	if spawnerTable == nil then	
		spawnerTable = {}
		spawnerTable["biter-spawner"] = game.entity_prototypes["biter-spawner"] ~= nil
		spawnerTable["bob-biter-spawner"] = game.entity_prototypes["bob-biter-spawner"] ~= nil
		spawnerTable["spitter-spawner"] = game.entity_prototypes["spitter-spawner"] ~= nil
		spawnerTable["bob-spitter-spawner"] = game.entity_prototypes["bob-spitter-spawner"] ~= nil
	end
end

local function spawn_entity(surface, ent, r_config, x, y)
	if not use_RSO_biter_spawning then return end
	local size=rgen:random(r_config.size.min, r_config.size.max)
	
	local _total = 0
	local r_distance = distance({x=0,y=0},{x=x/REGION_TILE_SIZE,y=y/REGION_TILE_SIZE})  
	
	local distanceMultiplier = math.min(r_distance^r_config.size_per_region_factor, 5)
	if r_config.size_per_region_factor then
		size = size*distanceMultiplier
	end
	
	size = size * enemy_base_size_multiplier
	
	debug("Entering spawn_entity "..ent.." "..x..","..y.." "..size)
	
	local maxAttemptCount = 5
	local distancePerAttempt = 0.2
	
	initSpawnerTable()
	
	for i=1,size do
		for attempt = 1, maxAttemptCount do
			local richness=r_config.richness*(r_distance^richness_distance_factor)
			local max_d = floor(CHUNK_SIZE*(0.5 + distancePerAttempt*attempt))
			local s_x = x + rgen:random(0, floor(max_d - r_config.clear_range[1])) - max_d/2 + r_config.clear_range[1]
			local s_y = y + rgen:random(0, floor(max_d - r_config.clear_range[2])) - max_d/2 + r_config.clear_range[2]
			
			if surface.get_tile(s_x, s_y).valid then

				remove_trees(surface, s_x, s_y, r_config.clear_range[1], r_config.clear_range[2])

				local spawnerName = nil
				
				if spawner_probability_edge > 0 then
					
					bigSpawnerChance = rgen:random()
					
					if rgen:random() < spawner_probability_edge then
						if ( useBobEntity and bigSpawnerChance > 0.75 ) then
							spawnerName = "bob-biter-spawner"
						else
							spawnerName = "biter-spawner"
						end
					else
						if ( useBobEntity and bigSpawnerChance > 0.75 ) then
							spawnerName = "bob-spitter-spawner"
						else
							spawnerName = "spitter-spawner"
						end
					end
				end
				
				if spawnerName and spawnerTable[spawnerName] then
					if surface.can_place_entity{name=spawnerName, position={s_x, s_y}} then
						_total = _total + richness
						debug(spawnerName.." @ "..s_x..","..s_y.." placed on "..attempt.." attempt")
						
						surface.create_entity{name=spawnerName, position={s_x, s_y}, force=game.forces[r_config.force], amount=floor(richness)}--, direction=rgen:random(4)
						--			else
						--				debug("Entity "..spawnerName.." spawn failed")
						break;
					else
						if attempt == maxAttemptCount then
							debug(spawnerName.." @ "..s_x..","..s_y.." failed to spawn")
						end
					end
				else
					debug("Entity "..spawnerName.." doesn't exist")
				end
			end
		end
			
		if r_config.sub_spawn_probability then
			local sub_spawn_prob = r_config.sub_spawn_probability*math.min(r_config.sub_spawn_max_distance_factor, r_config.sub_spawn_distance_factor^r_distance)
			if rgen:random() < sub_spawn_prob then
				for i=1,(rgen:random(r_config.sub_spawn_size.min, r_config.sub_spawn_size.max)*distanceMultiplier) do
					local allotment_max = 0
					-- build table
					for k,v in pairs(r_config.sub_spawns) do
						if not v.min_distance or r_distance > v.min_distance then
							local allotment = v.allotment
							if v.allotment_distance_factor then
								allotment = allotment * (v.allotment_distance_factor^r_distance)
							end
							v.allotment_range ={min = allotment_max, max = allotment_max + allotment}
							allotment_max = allotment_max + allotment
						else
							v.allotment_range = nil
						end 
					end
					local sub_type = rgen:random(0, allotment_max)
					for sub_spawn,v in pairs(r_config.sub_spawns) do
						if v.allotment_range and sub_type >= v.allotment_range.min and sub_type <= v.allotment_range.max then
							for attempt = 1, maxAttemptCount do
								local max_d = floor(CHUNK_SIZE*distancePerAttempt*attempt)
								s_x = x + rgen:random(max_d) - max_d/2
								s_y = y + rgen:random(max_d) - max_d/2
								remove_trees(surface, s_x, s_y, v.clear_range[1], v.clear_range[2])
								if surface.can_place_entity{name=sub_spawn, position={s_x, s_y}} then
									surface.create_entity{name=sub_spawn, position={s_x, s_y}, force=game.forces[r_config.force]}--, direction=rgen:random(4)
									debug("Rolled subspawn "..sub_spawn.." @ "..s_x..","..s_x.." after "..attempt.." attempts")
									break;
								else
									if attempt == maxAttemptCount then
										debug("Rolling subspawn "..sub_spawn.." @ "..s_x..","..s_x.." failed")
									end
								end
							end
							break
						end
					end
				end
			end
		end
	end
	debug("Total amount: ".._total)
	debug("Leaving spawn_entity")
end

--[[ EVENT/INIT METHODS ]]--

local function spawn_starting_resources( surface, index )
	
	if global.startingAreas[index].spawned then return end
	if surface.map_gen_settings.starting_area == "none" and not ignoreMapGenSettings then return end -- starting area disabled by map gen
	if starting_area_size < 0.1 then return end -- skip spawning if starting area is to small
	
	local position = global.startingAreas[index]
	
	rgen = rng_for_reg_pos( position )
	local status = true
	for index,v in ipairs(configIndexed) do
		if v.starting then 
			local prob = rgen:random() -- probability that this resource is spawned
			debug("starting resource probability rolled "..prob)
			if v.starting.probability > 0 and prob <= v.starting.probability then
				local total = 0
				local radius = 25
				local min_threshold = 0
				
				if v.type == "resource-ore" then
					min_threshold = v.starting.richness * rgen:random(5, 10) -- lets make sure that there is at least 10-15 times starting richness ore at start
				elseif v.type == "resource-liquid" then
					min_threshold = v.starting.richness * 0.5 * v.starting.size
				end
				
				while (radius < 200) and (total < min_threshold) do
					local angle = rgen:random() * pi * 2
					local dist = rgen:random() * 30 + radius * 2
					local pos = { x = floor(cos(angle) * dist) + position.x, y = floor(sin(angle) * dist) + position.y }
					if v.type == "resource-ore" then
						total = total + spawn_resource_ore(surface, v.name, pos, v.starting.size, v.starting.richness, true)
					elseif v.type == "resource-liquid" then
						total = total + spawn_resource_liquid(surface, v.name, pos, v.starting.size, v.starting.richness, true)
					end
					radius = radius + 10
				end
				if total < min_threshold then
					status = false
				end
			end
		end
	end

	global.startingAreas[index].spawned = true
end

local function modifyMinMax(value, mod)
	value.min = round( value.min * mod )
	value.max = round( value.max * mod )
end

local function prebuild_config_data(surface)
	if index_is_built then return false end
	
	local mapGenSettings = nil
	
	if not ignoreMapGenSettings then
		mapGenSettings = surface.map_gen_settings
	end
	local autoPlaceSettings = nil
	if mapGenSettings then
		autoPlaceSettings = mapGenSettings.autoplace_controls
	end
	
	configIndexed = {}
	-- build additional indexed array to the associative array
	for res_name, res_conf in pairs(config) do
		if res_conf.valid then -- only add valid resources
			res_conf.name = res_name
			
			local settingsForResource = nil
			local isEntity = (res_conf.type == "entity")
			local addResource = true
			
			local autoplaceName = res_name
			
			if res_conf.autoplace_name then
				autoplaceName = res_conf.autoplace_name
			end
			
			if autoPlaceSettings then
				settingsForResource = autoPlaceSettings[autoplaceName]
			end
			
			if settingsForResource then
				local allotmentMod = nil
				local sizeMod = nil
				if isEntity then
					allotmentMod = entityFrequencyMultiplier[settingsForResource.frequency]
					sizeMod = entitySizeMultiplier[settingsForResource.size]
				else
					allotmentMod =frequencyAllotmentMultiplier[settingsForResource.frequency]
					sizeMod = sizeMultiplier[settingsForResource.size]
				end
				
				local richnessMod = richnessMultiplier[settingsForResource.richness]
				
			
				debug(res_name .. " allotment mod " .. allotmentMod .. " size mod " .. sizeMod .. " richness mod " .. richnessMod )

				
				if allotmentMod then
					if isEntity then
						res_conf.absolute_probability = res_conf.absolute_probability * allotmentMod
						debug("Entity chance modified to "..res_conf.absolute_probability)
					else
						res_conf.allotment = round( res_conf.allotment * allotmentMod )
					end
				end

				if sizeMod ~= nil and sizeMod == 0 then
					addResource = false
				end

				if sizeMod then
					modifyMinMax(res_conf.size, sizeMod)
					
					if res_conf.starting then
						res_conf.starting.size = round( res_conf.starting.size * sizeMod )
					end
					
					if isEntity then 
						if res_conf.sub_spawn_size then
							modifyMinMax(res_conf.sub_spawn_size, sizeMod)
						end
						modifyMinMax(res_conf.spawns_per_region, sizeMod)
					end
				end
				
				if richnessMod then
					if type == "resource-ore" then
						res_conf.richness = round( res_conf.richness * richnessMod )
					elseif type == "resource-liquid" then
						modifyMinMax(res_conf.richness, richnessMod)
					end
					
					if res_conf.starting then
						res_conf.starting.richness = round( res_conf.starting.richness * richnessMod )
					end
				end
			end
			
			if addResource then
				configIndexed[#configIndexed + 1] = res_conf
				if res_conf.multi_resource and multi_resource_active then
					local new_list = {}
					for sub_res_name, allotment in pairs(res_conf.multi_resource) do
						if config[sub_res_name] and config[sub_res_name].valid then
							new_list[#new_list+1] = {name = sub_res_name, allotment = allotment}
						end
					end
					table.sort(new_list, function(a, b) return a.name < b.name end)
					res_conf.multi_resource = new_list
				else
					res_conf.multi_resource_chance = nil
				end
			end
		end
	end
	
	table.sort(configIndexed, function(a, b) return a.name < b.name end)
	
	local pr=0
	for index,v in pairs(config) do
		if v.along_resource_probability then  
			v.along_resource_probability_range={min=pr, max=pr+v.along_resource_probability}
			pr=pr+v.along_resource_probability
		end
		if v.allotment and v.allotment > 0 then
			v.allotment_range={min=max_allotment, max=max_allotment+v.allotment}
			max_allotment=max_allotment+v.allotment
		end
	end
	
	if mapGenSettings and mapGenSettings.starting_area then
		local multiplier = startingAreaMultiplier[mapGenSettings.starting_area]
		if multiplier ~= nil then
			starting_area_size = starting_area_size * multiplier
			debug("Starting area "..starting_area_size)
		end
	end
	
	index_is_built = true
end

-- set up the probabilty segments from which to roll between for biter and spitter spawners
local function calculate_spawner_ratio()
	if (biter_ratio_segment ~= 0 and spitter_ratio_segment ~= 0) and biter_ratio_segment >= 0 and spitter_ratio_segment >= 0 then
		spawner_probability_edge=biter_ratio_segment/(biter_ratio_segment+spitter_ratio_segment)  -- normalize to between 0 and 1
	end
end

local function checkConfigForInvalidResources()
	--make sure that every resource in the config is actually available.
	--call this function, before the auxiliary config is prebuilt!
	if index_is_built then return end
	
	local prototypes = game.entity_prototypes
	
	for resourceName, resourceConfig in pairs(config) do
		if prototypes[resourceName] or resourceConfig.type == "entity" then
			resourceConfig.valid = true
		else
			-- resource was in config, but it doesn't exist in game files anymore - mark it invalid
			resourceConfig.valid = false
			
			table.insert(invalidResources, "Resource not available: " .. resourceName)
			debug("Resource not available: " .. resourceName)
		end
		
		if resourceConfig.valid and resourceConfig.type ~= "entity" then
 			if prototypes[resourceName].autoplace_specification == nil then
				resourceConfig.valid = false
				debug("Resource "..resourceName.." invalidated - autoplace not present")
			end
		end
	end
end

local function roll_region(c_x, c_y)
	--in what region is this chunk?
	local r_x=floor(c_x/REGION_TILE_SIZE)
	local r_y=floor(c_y/REGION_TILE_SIZE)
	local r_data = nil
	--don't spawn stuff in starting area
	if isInStartingArea( c_x/REGION_TILE_SIZE, c_y/REGION_TILE_SIZE ) then
		return false
	end

	if global.regions[r_x] and global.regions[r_x][r_y] then
		r_data = global.regions[r_x][r_y]
	else
		--if this chunk is the first in its region to be generated
		if not global.regions[r_x] then global.regions[r_x] = {} end
		global.regions[r_x][r_y]={}
		r_data = global.regions[r_x][r_y]
		rgen = rng_for_reg_pos{x=r_x,y=r_y}
		
		local rollCount = math.ceil(#configIndexed / 10) - 1 -- 0 based counter is more convenient here
		rollCount = math.min(rollCount, 3)
		
		for rollNumber = 0,rollCount do
		
			local resourceChance = absolute_resource_chance - rollNumber * 0.1
			--absolute chance to spawn resource
			local abct = rgen:random()
			debug("Rolling resource "..abct.." against "..resourceChance.." roll "..rollNumber)
			if abct <= resourceChance then
				local res_type=rgen:random(1, max_allotment)
				for index,v in ipairs(configIndexed) do
					if v.allotment_range and ((res_type >= v.allotment_range.min) and (res_type <= v.allotment_range.max)) then
						debug("Rolled primary resource "..v.name.." with res_type="..res_type.." @ "..r_x..","..r_y)
						local num_spawns=rgen:random(v.spawns_per_region.min, v.spawns_per_region.max)
						local last_spawn_coords = {}
						local along_
						for i=1,num_spawns do
							local c_x, c_y = find_random_chunk(r_x, r_y)
							if not r_data[c_x] then r_data[c_x] = {} end
							if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
							local c_data = r_data[c_x][c_y]
							c_data[#c_data+1]={v.name, rollNumber}
							last_spawn_coords[#last_spawn_coords+1] = {c_x, c_y}
							debug("Rolled primary chunk "..v.name.." @ "..c_x.."."..c_y.." reg: "..r_x..","..r_y)
							-- Along resource spawn, only once
							if i == 1 then
								local am_roll = rgen:random()
								for index,vv in ipairs(configIndexed) do
									if vv.along_resource_probability_range and am_roll >= vv.along_resource_probability_range.min and am_roll <= vv.along_resource_probability_range.max then
										c_data = r_data[c_x][c_y]
										c_data[#c_data+1]={vv.name, rollNumber}
										debug("Rolled along "..vv.name.." @ "..c_x.."."..c_y.." reg: "..r_x..","..r_y)
									end
								end
							end
						end
						-- roll multiple resources in same region
						local deep=0
						while v.multi_resource_chance and rgen:random() <= v.multi_resource_chance*(multi_resource_chance_diminish^deep) do
							deep = deep + 1
							local max_allotment = 0
							for index,sub_res in pairs(v.multi_resource) do max_allotment=max_allotment+sub_res.allotment end
							
							local res_type=rgen:random(1, max_allotment)
							local min=0
							for _, sub_res in pairs(v.multi_resource) do
								if (res_type >= min) and (res_type <= sub_res.allotment + min) then
									local last_coords = last_spawn_coords[rgen:random(1, #last_spawn_coords)]
									local c_x, c_y = find_random_neighbour_chunk(last_coords[1], last_coords[2]) -- in same as primary resource chunk
									if not r_data[c_x] then r_data[c_x] = {} end
									if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
									local c_data = r_data[c_x][c_y]
									c_data[#c_data+1]={sub_res.name, deep}
									debug("Rolled multiple "..sub_res.name..":"..deep.." with res_type="..res_type.." @ "..c_x.."."..c_y.." reg: "..r_x.."."..r_y)
									break
								else
									min = min + sub_res.allotment
								end
							end
						end
						break
					end
				end
				
			end
		end
		-- roll for absolute_probability - this rolls the enemies
		
		for index,v in ipairs(configIndexed) do
			if v.absolute_probability then
				local prob_factor = 1 
				if v.probability_distance_factor then 
					prob_factor = math.min(v.max_probability_distance_factor, v.probability_distance_factor^distance({x=0,y=0},{x=r_x,y=r_y}))
				end 
				local abs_roll = rgen:random()
				if abs_roll<v.absolute_probability*prob_factor then
					local num_spawns=rgen:random(v.spawns_per_region.min, v.spawns_per_region.max)
					for i=1,num_spawns do
						local c_x, c_y = find_random_chunk(r_x, r_y)
						if not r_data[c_x] then r_data[c_x] = {} end
						if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
						c_data = r_data[c_x][c_y]
						c_data[#c_data+1] = {v.name, 1}
						debug("Rolled absolute "..v.name.." with rt="..abs_roll.." @ "..c_x..","..c_y.." reg: "..r_x..","..r_y)
					end
				end
			end
		end
	end
end

local function roll_chunk(surface, c_x, c_y)
	--handle spawn in chunks
	local r_x=floor(c_x/REGION_TILE_SIZE)
	local r_y=floor(c_y/REGION_TILE_SIZE)
	local r_data = nil
	--don't spawn stuff in starting area
	if isInStartingArea( c_x/REGION_TILE_SIZE, c_y/REGION_TILE_SIZE ) then
		return false
	end
	
	local c_center_x=c_x + CHUNK_SIZE/2
	local c_center_y=c_y + CHUNK_SIZE/2
	if not (global.regions[r_x] and global.regions[r_x][r_y]) then
		return
	end
	r_data = global.regions[r_x][r_y]
	if not (r_data[c_x] and r_data[c_x][c_y]) then
		return
	end
	if r_data[c_x] and r_data[c_x][c_y] then
		rgen = rng_for_reg_pos{x=c_center_x,y=c_center_y}
		
		debug("Stumbled upon "..c_x..","..c_y.." reg: "..r_x.."."..r_y)
		local resource_list = r_data[c_x][c_y]
		--for resource, deep in pairs(r_data[c_x][c_y]) do
		--  resource_list[#resource_list+1] = {resource, deep}
		--end
		table.sort(resource_list, function(res1, res2) return res1[2] < res2[2] end)
		
		for _, res_con in ipairs(resource_list) do
			local resource = res_con[1]
			local deep = res_con[2]
			local r_config = config[resource]
			if r_config and r_config.valid then
				local dist = distance({x=0,y=0},{x=r_x,y=r_y})
				local sizeFactor = dist^size_distance_factor
				local richFactor = dist^richness_distance_factor
				debug("Resource "..resource.." distance "..dist.." factors (size, richness) "..sizeFactor..","..richFactor)
				if r_config.type=="resource-ore" then
					local size=rgen:random(r_config.size.min, r_config.size.max) * (multi_resource_size_factor^deep) * sizeFactor
					local richness = r_config.richness * richFactor * (multi_resource_richness_factor^deep)
					local restriction = ''
					debug("Center @ "..c_center_x..","..c_center_y)
					c_center_x, c_center_y, restriction = find_intersection(surface, c_center_x, c_center_y)
					debug("New Center @ "..c_center_x..","..c_center_y)
					spawn_resource_ore(surface, resource, {x=c_center_x,y=c_center_y}, size, richness, false, restriction)
				elseif r_config.type=="resource-liquid" then
					local size=rgen:random(r_config.size.min, r_config.size.max)  * (multi_resource_size_factor^deep) * sizeFactor
					local richness=rgen:random(r_config.richness.min, r_config.richness.max) * richFactor * (multi_resource_richness_factor^deep)
					local restriction = ''
					c_center_x, c_center_y, restriction = find_intersection(surface, c_center_x, c_center_y)
					spawn_resource_liquid(surface, resource, {x=c_center_x,y=c_center_y}, size, richness, false, restriction)
				elseif r_config.type=="entity" then

					-- OARC EDIT -- Remove spawns in any safe area!
					local isNearSpawn = false
					if (global.uniqueSpawns) and (SAFE_AREA_TILE_DIST) then
						for name,spawnPos in pairs(global.uniqueSpawns) do
					        local safeArea = {left_top=
					                            {x=spawnPos.x-SAFE_AREA_TILE_DIST,
					                             y=spawnPos.y-SAFE_AREA_TILE_DIST},
					                          right_bottom=
					                            {x=spawnPos.x+SAFE_AREA_TILE_DIST,
					                             y=spawnPos.y+SAFE_AREA_TILE_DIST}}

					        if (CheckIfInArea({x=c_center_x, y=c_center_y},safeArea)) then
					        	isNearSpawn = true
					        end
	                 	end
	                end
                 	if (not isNearSpawn) then
						spawn_entity(surface, resource, r_config, c_center_x, c_center_y)
					end
				end
			else
				debug("Resource access failed for " .. resource)
				debug("Resource access failed for " .. resource)
			end
		end
		r_data[c_x][c_y]=nil
	end
end

local function printResourceProbability(player)
	-- prints the probability of each resource - how likely it is to be spawned in percent
	-- this ignores the multi resource chance
	player.print("Max allotment"..string.format("%.1f",max_allotment))
	debug("Max allotment"..string.format("%.1f",max_allotment))
	local sanityCheckAllotment = 0
	for index,v in ipairs(configIndexed) do
		if v.type ~= "entity" then		-- ignore enemies - they don't have allotment set
			if v.allotment then
				local resProbability = (v.allotment/max_allotment) * 100
				sanityCheckAllotment = sanityCheckAllotment + v.allotment
				player.print("Resource: "..v.name.." Prob: "..string.format("%.1f",resProbability))
				debug("Resource: "..v.name.." Prob: "..string.format("%.1f",resProbability))
			else
				player.print("Resource: "..v.name.." Allotment not set")
				debug("Resource: "..v.name.." Allotment not set")
			end
		end
	end
	
	player.print("SanityCheck Allotment: "..string.format("%.1f", sanityCheckAllotment))
	debug("SanityCheck Allotment: "..string.format("%.1f", sanityCheckAllotment))
end

function RSO_init()
	if not initDone then
		
		local surface = game.surfaces['nauvis']
		
		if not global.regions then
			global.regions = {}
		end
		
		if not config then
			config = loadResourceConfig()
			checkConfigForInvalidResources()
			prebuild_config_data(surface)
		end
		
		global.seed = surface.map_gen_settings.seed

		if not global.startingAreas then
			global.startingAreas = {}
			table.insert( global.startingAreas, { x = 0, y = 0, spawned = false } )
			
			if global.start_resources_spawned or game.tick > 10 then
				global.startingAreas[1].spawned = true
			end
		end

		calculate_spawner_ratio()
		spawn_starting_resources(surface, 1 )
				
		initDone = true

	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["iron-ore"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA iron-ore GEN IS NOT DISABLED!")
	    end
	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["copper-ore"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA copper-ore GEN IS NOT DISABLED!")
	    end
	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["crude-oil"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA crude-oil GEN IS NOT DISABLED!")
	    end
	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["enemy-base"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA enemy-base GEN IS NOT DISABLED!")
	    end
	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["stone"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA stone GEN IS NOT DISABLED!")
	    end
	    if game.surfaces["nauvis"].map_gen_settings.autoplace_controls["coal"].size ~= "none" then
	        game.players[1].print("RSO WARNING - VANILLA coal GEN IS NOT DISABLED!")
	    end
	end
	
	script.on_event(defines.events.on_tick, nil)
end

-- Oarc removed this. No idea if this will break save game loads.
-- Tested it once and it seemed to work?
-- function RSO_delayedInit()
-- 	script.on_event(defines.events.on_tick, RSO_init)
-- end

function RSO_ChunkGenerated(event)
	local c_x = event.area.left_top.x
	local c_y = event.area.left_top.y

	RSO_init()
	
	roll_region(c_x, c_y)
	roll_chunk(event.surface, c_x, c_y)
end
