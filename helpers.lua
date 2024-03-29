--
-- Helper Functions For Block Comparisons
--

local function contains(array, value)
	for i= 1, #array do
		if array[i] == value then
			return true
		end
	end
	return false
end

local function intersects(array1, array2)
	for _, v1 in ipairs(array1) do
		for _2, v2 in ipairs(array2) do
			if v1 == v2 then
				return true
			end
		end
	end
	return false
end

local function bool_to_number(value)
	if value == true then
		return 1
	else
		return 0
	end
end

local function number_to_bool(value)
	if value == 1 then
		return true
	else
		return false
	end
end

local function is_even(a)
	return a - (math.floor(a/2)*2) == 0
end

local function randomize_list(list)
	local list_new = {}
	while #list > 0 do
		table.insert(list_new, table.remove(list, math.random(1, #list)))
	end
	return list_new
end

local stone_ground_blocks = {
	"default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick",
	"default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick",
	"default:cobble", "default:stone", "default:stone_block", "default:stonebrick",
	"default:sandstone", "default:sandstone_block",  "default:sandstonebrick", 
	"default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick"
}
local function get_solid_air_block_replacement(pos, cobbelify)
	-- if we want to set an air block in a place with air, but actually need a structure block there for structure reasons
	local biome_data = minetest.get_biome_data(pos)
	if biome_data == nil then
		return "default:stone"
	end
	local biome_name = minetest.get_biome_name(biome_data.biome)
	local stone_type = minetest.registered_biomes[biome_name].node_stone or "default:stone"
	if stone_type == "default:stone" and cobbelify then
		return "default:cobble"
	elseif stone_type == "default:desert_stone" then
		return "default:desert_cobble"
	elseif contains(stone_ground_blocks, stone_type) then
		return stone_type
	else
		return "default:stone"
	end
end

local function is_in_frozen_biome(pos)
	-- code for v6
	if minetest.get_mapgen_setting("mg_name") == "v6" then
		return contains({"Taiga", "Tundra"}, biomeinfo.get_v6_biome(pos))
	end
	-- code for v7 and other mapgens that accept register_biome definitions
	local biome_data = minetest.get_biome_data(pos)
	if biome_data == nil then
		return nil
	end
	local biome_name = minetest.get_biome_name(biome_data.biome)
	local biome_definition = minetest.registered_biomes[biome_name]
	if biome_definition.heat_point <= 25 then
		return true
	end
	local biome_blocks = {
		biome_definition.node_dust,
		biome_definition.node_top,
		biome_definition.node_filler,
		biome_definition.node_stone,
		biome_definition.node_water_top,
		biome_definition.node_river_water,
		biome_definition.node_riverbed,
	}
	local cold_blocks = {
		"default:snowblock", "default:snow", "default:dirt_with_snow",
		"default:ice", "default:cave_ice", 
	}
	if intersects(biome_blocks, cold_blocks) then
		return true
	end
	for _, decoration_definition in ipairs(minetest.registered_decorations) do
		if contains(cold_blocks, decoration_definition.decoration) and contains(decoration_definition.biomes, biome_definition.name) then
			return true
		end
	end
	return false
end

local helper_functions = {
    contains = contains,
    intersects = intersects,
    bool_to_number = bool_to_number,
	number_to_bool = number_to_bool,
	is_even = is_even,
	randomize_list = randomize_list,
	get_solid_air_block_replacement = get_solid_air_block_replacement,
	is_in_frozen_biome = is_in_frozen_biome
}
randungeon.helper_functions = helper_functions
return helper_functions
