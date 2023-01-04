--
-- Helper Functions
--

local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number

--
-- Dungeon Material Generation Functions
--

local function make_random_dungeon_material_scheme()
	-- all available materials
	local available_materials = {
		--"default:brick",
		"randungeon:bookshelf",
		"default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick",
		"default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick",
		"default:cobble", "default:stone", "default:stone_block", "default:stonebrick",
		"default:sandstone", "default:sandstone_block",  "default:sandstonebrick", 
		"default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick",
		"air", "default:meselamp"
	}
	-- only 2/3 of all generated material schemes contain wood
	if math.random() < 0.66 then
		table.insert(available_materials, "default:aspen_wood")
		table.insert(available_materials, "default:acacia_wood")
		table.insert(available_materials, "default:pine_wood")
		table.insert(available_materials, "default:wood")
	end
	-- choose random materials
	local materials = {
		roof_type = available_materials[math.random(1, #available_materials)],
		wall_type_2 = available_materials[math.random(1, #available_materials)],
		wall_type_1 = available_materials[math.random(1, #available_materials)],
		floor_type = available_materials[math.random(1, #available_materials)],
		pillar_type = available_materials[math.random(1, #available_materials)],
		bridge_type = math.random(0, 3),
	}
	return materials
end

local function compare_dungeon_material_schemes(scheme1, scheme2)
	local similarity = 0
	for _, attr in ipairs({"roof_type", "wall_type_2", "wall_type_1", "floor_type", "pillar_type"}) do
		if scheme1[attr] == scheme2[attr] then
			similarity = similarity + 0.2
			-- if attr == "pillar_type" then
			-- 	similarity = similarity + 0.3
			-- end
		end
	end
	similarity = similarity - 0.2 * math.abs(scheme1.bridge_type - scheme2.bridge_type)
	return similarity
end

local function make_similar_dungeon_scheme(scheme1)
	local best_scheme = nil
	local best_similarity = -1
	for i = 1, 170 do
		local new_scheme = make_random_dungeon_material_scheme()
		local new_similarity = compare_dungeon_material_schemes(scheme1, new_scheme)
		if new_similarity > best_similarity then
			best_scheme = new_scheme
			best_similarity = new_similarity
		end
	end
	return best_scheme
end

local function rate_dungeon_materials(materials)
	local score = 10
	-- dungeon may not have air as a floor or as pillars, bc of caves
	if materials.floor_type == "air" or materials.pillar_type == "air" then
		return -100
	end
	--[[
	-- the more different materials, the worse the score
	-- Removed bc it caused useless repetition
	local present_materials = {}
	local num_materials = 0
	for _, m in pairs(materials) do
		if not present_materials[m] then
			present_materials[m] = true
			num_materials = num_materials + 1
		end
	end
	score = score - num_materials
	--]]
	-- material groups get bonuses
	local material_groups = {
		{"default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick"},
		{"default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick"},
		{"default:cobble", "default:stone", "default:stone_block", "default:stonebrick"},
		{"default:sandstone", "default:sandstone_block",  "default:sandstonebrick"}, 
		{"default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick"},
		{"default:aspen_wood", "default:acacia_wood", "default:pine_wood", "default:wood", "randungeon:bookshelf"},
		{"default:stone"},
		{"default:meselamp"},
		{"air"}
	}
	for _, material_group in ipairs(material_groups) do
		local occurances = 0
		for _, m in pairs(materials) do
			if contains(material_group, m) then
				occurances = occurances + 1
			end
		end
		if occurances > 1 then
			score = score + 1.7^occurances
		end
	end
	-- make a list of all materials we used
	local all_materials = {materials.floor_type, materials.pillar_type, materials.wall_type_1, materials.wall_type_2, materials.pillar_type}
	-- encourage using wood whose color fits the stone we used
	if intersects({"default:sandstone", "default:sandstone_block", "default:sandstonebrick"}, all_materials) and intersects(all_materials, {"default:aspen_wood", "default:acacia_wood"}) then
		score = score + 1
	elseif intersects({"default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick"}, all_materials) and intersects(all_materials, {"default:aspen_wood", "default:acacia_wood"}) then
		score = score + 1
	elseif intersects({"default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick"}, all_materials) and contains(all_materials, "default:pine_wood") then
		score = score + 1
	elseif intersects({"default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick"}, all_materials) and contains(all_materials, "default:acacia_wood") then
		score = score + 1
	elseif intersects({"default:cobble", "default:stone", "default:stone_block", "default:stonebrick"}, all_materials) and contains(all_materials, "default_wood") then
		score = score + 1
	end
	-- bonus for every woodtype we don't use, to make sure that this doesn't inflate wood usage and rather discourages using wrong woods
	local wood_types = {"default:aspen_wood", "default:acacia_wood", "default_pine_wood", "default:wood"}
	for _, wood in ipairs(wood_types) do
		if not contains(all_materials, wood) then
			score = score + 1.5
		end
	end
	-- having the lower wall block made from air without the one above also being air is bad
	if materials.wall_type_1 == "air" and materials.wall_type_2 ~= "air" then
		score = score - 4
	end
	-- having both roof and upper wall made from air gives a bonus
	if materials.wall_type_2 == "air" and materials.roof_type == "air" then
		score = score + 1
		if materials.wall_type_1 == "air" then
			score = score + 1
		end
	end
	-- combining normal stone with sand/desert adj stone gives sanction, and combining different desert-adj stone types gives some too
	local normal_stone_types_count = 0
	local desert_stone_types_count = 0
	for _, desert_stone_type in ipairs({
		{"default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick"},
		{"default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick"},
		{"default:sandstone", "default:sandstone_block",  "default:sandstonebrick"},
		{"default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick"}
	}) do
		if intersects(desert_stone_type, all_materials) then
			desert_stone_types_count = desert_stone_types_count + 1
		end
	end
	for _, material in ipairs(all_materials) do
		if contains({"default:cobble", "default:stone_block", "default:stonebrick"}, material) then
			normal_stone_types_count = normal_stone_types_count + 1
			break
		end
	end
	if normal_stone_types_count > 0 and desert_stone_types_count > 0 then
		score = score - 2.5
	elseif desert_stone_types_count > 1 then
		score = score - 1
	end
	-- sanction cobble and, to a lesser extend, desert cobble outside of pillars
	if materials.floor_type == "default:cobble" then
		score = score - 1.5
	elseif contains({materials.floor_type, materials.wall_type_1, materials.wall_type_2, materials.roof_type}, "default:cobble") then
		score = score - 1
	end
	if contains({materials.floor_type, materials.wall_type_1, materials.wall_type_2, materials.roof_type}, "default:desert_cobble") then
		score = score - 0.5
	end
	-- shelves should align with the roof
	if materials.wall_type_1 == "randungeon:bookshelf" and materials.wall_type_2 == "air" then
		score = score - 2
	elseif materials.wall_type_1 == "randungeon:bookshelf" and materials.wall_type_2 ~= "randungeon:bookshelf" then
		score = score - 3
	end
	-- no shelves as floor or roof
	if contains({materials.floor_type, materials.roof_type}, "randungeon:bookshelf") then
		score = score - 10
	end
	-- discourage wooden walls
	for _, wood in ipairs({"default:aspen_wood", "default:acacia_wood", "default:pine_wood", "default:wood"}) do
		if contains({materials.wall_type_1, materials.wall_type_2}, wood) then
			score = score - 0.5
		end
	end  
	-- discourage wooden pillars
	if contains({"default:aspen_wood", "default:acacia_wood", "default_pine_wood", "default:wood"}, materials.pillar_tpe) then
		score = score - 3
	elseif materials.pillar_type == "randungeon:bookshelf" then
		score = score - 5
	end
	-- reward identical upper and lower wall
	if materials.wall_type_1 == materials.wall_type_2 then
		score = score + 2
	end
	-- discourage using different types of wood
	local wood_types = {}
	for _, m in ipairs(all_materials) do
		if contains({"default:aspen_wood", "default:acacia_wood", "default:pine_wood", "default:wood"}, m) then
			wood_types[m] = true
		end
	end
	if #wood_types > 1 then
		score = score - 2
	end
	-- nonetheless, reward for bookshelves
	if contains(all_materials, "randungeon:bookshelf") then
		score = score + 2
	end
	-- reward for cobble-based pillars
	if contains({"default:cobble", "default:desert_cobble"}, materials.pillar_type) then
		score = score + 2
	end
	-- wood is good for floor
	if contains({"default:aspen_wood", "default:acacia_wood", "default:pine_wood", "default:wood"}, materials.floor_type) then
		score = score + 2
	end


	-- tiles are good for floor
	local tiles_blocks = {"default:stone_block", "default:desert_stone_block", "default:sandstone_block", "default:desert_sandstone_block", "default:silver_sandstone_block"}
	if contains(tiles_blocks, materials.floor_type) then
		score = score + 1.5
	end
	-- but bad if in walls or as a ceiling
	local tiles_as_wall_or_roof = false
	for _, m in ipairs({materials.roof, materials.wall_type_1, materials.wall_type_2}) do
		if contains(tiles_blocks, m) then
			tiles_as_wall_or_roof = true
		end
	end
	if tiles_as_wall_or_roof then
		score = score - 1
	end
	-- tiles should align with the floor if used in walls
	if contains(tiles_blocks, materials.wall_type_2) and materials.wall_type_1 == "air" then
		score = score - 0.5
	elseif contains(tiles_blocks, materials.wall_type_2) and not contains(tiles_blocks, materials.wall_type_1) then
		score = score - 1.5
	end


	-- level 3 bridge & wooden floor go well together:
	if materials.bridge_type == 3 and contains(wood_types, materials.floor_type) then
		score = score + 2
	end

	-- level 1&2 bridge & stone as lower wall part go bad together:
	if (materials.bridge_type == 1 or materials.bridge_type == 2) and materials.wall_type_1 == "default:stone" then
		score = score - 2
	end

    -- level 0 bridge element is frowned upon:
    if materials.bridge_type == 0 then
        score = score - 3
    end

	-- meselamp gets bonus if and only if it's used in upper wall element
	if materials.wall_type_2 == "default:mese_lamp" then
		score = score + 2
	end
	return score
end

local function get_good_material_set(old_material_set)
	local best_material_set = make_similar_dungeon_scheme(old_material_set)
	local best_score = rate_dungeon_materials(best_material_set)
	for i = 1, 120 * 4/3 do
		local new_material_set = make_similar_dungeon_scheme(old_material_set)
		local new_material_set_score = rate_dungeon_materials(new_material_set)
		if new_material_set_score > best_score then
			best_material_set = new_material_set
			best_score = new_material_set_score
		end
	end
	return best_material_set
end

return {
    make_random_dungeon_material_scheme = make_random_dungeon_material_scheme,
    compare_dungeon_material_schemes = compare_dungeon_material_schemes,
    make_similar_dungeon_scheme = make_similar_dungeon_scheme,
    rate_dungeon_materials = rate_dungeon_materials,
    get_good_material_set = get_good_material_set
}