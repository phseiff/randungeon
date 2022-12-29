--
-- Include parts of the mod defined elsewhere
--

local mod_path = minetest.get_modpath("randungeon")

-- Dungeon Map Generator
local generate_dungeon_map_functions = dofile(mod_path.."/make_dungeon_map.lua")
local generate_dungeon_map = generate_dungeon_map_functions.generate_dungeon_map
local tiles_are_directly_connected = generate_dungeon_map_functions.tiles_are_directly_connected

-- Helper Functions For Block Comparisons
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number

-- Dungeon Material Generator Functions
local dungeon_materials_generator_functions = dofile(mod_path.."/dungeon_materials_generator.lua")
local make_random_dungeon_material_scheme = dungeon_materials_generator_functions.make_random_dungeon_material_scheme
local compare_dungeon_material_schemes = dungeon_materials_generator_functions.compare_dungeon_material_schemes
local make_similar_dungeon_scheme = dungeon_materials_generator_functions.make_similar_dungeon_scheme
local rate_dungeon_materials = dungeon_materials_generator_functions.rate_dungeon_materials
local get_good_material_set = dungeon_materials_generator_functions.get_good_material_set

-- Room Generation
local room_generation_functions = dofile(mod_path.."/room_generation.lua")
local make_room = room_generation_functions.make_room
local make_room_style = room_generation_functions.make_room_style
local make_unconnected_room_style = room_generation_functions.make_unconnected_room_style

-- Door Generation
local door_generation_code = dofile(mod_path.."/doors.lua")
local place_doubledoor_based_on_materials = door_generation_code.place_doubledoor_based_on_materials

-- Cave Nature Generator Functions
local cave_nature_generator_functions = dofile(mod_path.."/make_nature.lua")
local make_metadata_for_nature = cave_nature_generator_functions.make_metadata_for_nature
local make_nature = cave_nature_generator_functions.make_nature
local make_nature_in_area = cave_nature_generator_functions.make_nature_in_area

-- Special Rooms Generators
local special_rooms_funcions = dofile(mod_path.."/special_rooms.lua")
local make_treasure_level = special_rooms_funcions.make_treasure_level
local make_treasure_rooms = special_rooms_funcions.make_treasure_rooms

--
-- Local Helper Functions
--

local function set_structure_block(pos, name, only_replace_solid_blocks, dont_replace_pool_blocks)
	local old_node_name = minetest.get_node(pos).name
	-- don't replace nodes that were marked as irreplacable by air (like snow, water lillys, etc) (important bc of staircase walls)
	if minetest.get_meta(pos):get_string("dont_replace_with_air") == "true"  then
		return
	end
	-- don't replace pool and pool bassin blocks in some cases (important for staircase extensions since these don't need to go into pools)
	if dont_replace_pool_blocks and minetest.get_meta(pos):get_string("must_be_fireproof") == "true" then
		return
	end
	-- sometimes nodes should be treated like air if the block they want to replace isn't solid
	if only_replace_solid_blocks and minetest.registered_nodes[old_node_name].buildable_to then
		name = "air"
	end
	-- handle the rim of pool bassins specially
	if minetest.get_meta(pos):get_string("must_be_fireproof") == "true" then
		if name == "air" or name == "randungeon:dungeon_air" then
			name = "default:stone"
		end
		local alternative = minetest.get_meta(pos):get_string("fireproof_alternative")
		if not minetest.registered_nodes[name]["groups"]["flammable"] then
			minetest.set_node(pos, {name=name})
		else
			minetest.set_node(pos, {name=alternative})
		end
		minetest.get_meta(pos):set_string("fireproof_alternative", alternative)
		minetest.get_meta(pos):set_string("must_be_fireproof", "true")
		return
	end
	-- air nodes don't get placed, unless in water, in which case they get turned into glass, or lava, in which case they get turned into dungeon air
	-- (that later gets automatically obsidian-glass-mantlet)
	if name == "air" or name == "randungeon:dungeon_air" then
		if old_node_name == "default:water_source" then
			minetest.set_node(pos, {name="default:glass"})
		elseif minetest.registered_nodes[old_node_name].groups["igniter"] then
			minetest.set_node(pos, {name="randungeon:dungeon_air"})
		end
		return
	end
	-- "[new_node]_with_" nodes don't get replaced, so stone with ores doesn't get replaced by stone
	if string.find(old_node_name, "^"..name.."_with_") then
		return
	end
	-- otherwise, set node
	minetest.set_node(pos, {name=name})
end

local function insulate_position(pos, only_against_fire)
	if minetest.get_meta(pos):get_string("must_be_fireproof") == "true" then
		return -- <-- if there's a fireproof alternative then all is well since this is just the controlled case of cutting into a pool
	end
	local igniters = minetest.find_nodes_in_area({x=pos.x+1, y=pos.y+1, z=pos.z+1}, {x=pos.x-1, y=pos.y-1, z=pos.z-1}, {"group:igniter"})
	for _, igniter_pos in pairs(igniters) do
		minetest.set_node(igniter_pos, {name="default:obsidian_glass"})
	end
	if only_against_fire then
		return-- <-- option to only insulate against lava, but not against water
	end
	local igniters = minetest.find_nodes_in_area({x=pos.x+1, y=pos.y+1, z=pos.z+1}, {x=pos.x-1, y=pos.y-1, z=pos.z-1}, {"group:water"})
	for _, igniter_pos in pairs(igniters) do
		if minetest.get_meta(igniter_pos):get_string("must_be_fireproof") ~= "true" then
			minetest.set_node(igniter_pos, {name="default:glass"})
		end
	end
end

local function set_insulated_structure_block(pos, block_type, only_against_fire)
	insulate_position(pos, only_against_fire)
	set_structure_block(pos, block_type)
end

local function make_insulated_cavity(pos)
	insulate_position(pos)
	minetest.set_node(pos, {name="air"})
end

local function fill_with_dungeon_air_if_okay(pos)
	local meta = minetest.get_meta(pos)
	if not (meta:get_string("dont_replace_with_air") == "true") then
		minetest.set_node(pos, {name="randungeon:dungeon_air"})
	end
end

--
-- Dungeon Building Functions
--

local function build_dungeon_tile_floor_and_roof_and_walls(pos, floor_type, roof_type, wall_type_1, wall_type_2, pillar_type, x_plus, x_minus, z_plus, z_minus,
	                                                       bridge_type, is_dead_end, pillar_height, needs_staircase, room_style, has_room)
	local dirs = {
		{x_plus, "x", "z", function(n) return 11 - n end, "x_plus"},
		{x_minus, "x", "z", function(n) return n end, "x_minus"},
		{z_plus, "z", "x", function(n) return 11 - n end, "z_plus"},
		{z_minus, "z", "x", function(n) return n end, "z_minus"},
	}

	-- figure out what to omit:
	local omit_roof_in_caves = false
	local omit_wall_1_in_caves = false
	local omit_wall_2_in_caves = false
	if bridge_type >= 1 then
		omit_wall_2_in_caves = true
	end
	if bridge_type >= 2 then
		omit_roof_in_caves = true
	end
	if bridge_type == 3 then
		omit_wall_1_in_caves = true
	end
	-- CHECK IF WE ARE LIKELY UNDERNEATH A PILLAR THAT WE NEED TO HOLD WITH MINI PILLARS:
	local area_border1 = {x=pos.x+4; y=pos.y+3, z=pos.z+4}
	local area_border2 = {x=pos.x+7, y=pos.y+3, z=pos.z+7}
	local has_pillar_or_rock_above_it = (#minetest.find_nodes_in_area(area_border1, area_border2, {"air"}) == 0)
	-- WALLS, FLOOR & ROOF:
	for _, params in ipairs(dirs) do
		if params[1] then
			for value_b = 1, 6 do
				local new_block_pos = {}
				local omit_if_air = false
				for value_a = 4, 7 do
					new_block_pos[params[2]] = pos[params[2]] + params[4](value_b)
					new_block_pos[params[3]] = pos[params[3]] + value_a
					-- check if we need to add mini pillars to hold larger pillar
					local no_mini_pillars_needed = true
					if has_pillar_or_rock_above_it and (value_a==4 or value_a==7) and (value_b==4 or value_b==7) then
						no_mini_pillars_needed = false
					end
					-- wall 1
					new_block_pos["y"] = pos.y+1
					set_structure_block(new_block_pos, wall_type_1, omit_wall_1_in_caves and no_mini_pillars_needed)
					-- wall 2
					new_block_pos["y"] = pos.y+2
					set_structure_block(new_block_pos, wall_type_2, omit_wall_2_in_caves and no_mini_pillars_needed)
				end
				for value_a = 5, 6 do
					-- floor
					new_block_pos[params[3]] = pos[params[3]] + value_a
					new_block_pos["y"] = pos.y
					set_structure_block(new_block_pos, floor_type)
					-- roof
					new_block_pos["y"] = pos.y+3
					set_structure_block(new_block_pos, roof_type, omit_roof_in_caves)
				end
				-- make sure both roof sides are simmetrical
				local new_roof_pos_1 = new_block_pos
				local new_roof_pos_2 = {x=new_block_pos.x, y=new_block_pos.y, z=new_block_pos.z}
				new_roof_pos_2[params[3]] = pos[params[3]] + 5
				if minetest.get_node(new_roof_pos_1).name == "air" and minetest.get_node(new_roof_pos_2).name == roof_type then
					set_structure_block(new_roof_pos_1, roof_type)
				elseif minetest.get_node(new_roof_pos_2).name == "air" and minetest.get_node(new_roof_pos_1).name == roof_type then 
					set_structure_block(new_roof_pos_2, roof_type)
				end
			end
		end
	end
	-- MAKE ROOM:
	local made_room = false
	if has_room then
		made_room = make_room(pos, false, false, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, x_plus, x_minus, z_plus, z_minus, room_style)
	end
	-- CREATE NATURE AROUND TILE before yeeting leaves that grew into corridors with air:
	make_nature_in_area({x=pos.x, y=pos.y-pillar_height+4, z=pos.z}, {x=pos.x+10, y=pos.y+4, z=pos.z+10})

	-- CHECK WHICH TYPE OF TILE WE ARE, for door reasons:
	local dirs_total = bool_to_number(x_plus) + bool_to_number(x_minus) + bool_to_number(z_plus) + bool_to_number(z_minus)
	local type_of_tile, chance_of_doors, max_doors = unpack((dirs_total == 4)                       and {"X", 0.5,  3} or
	                                                        (dirs_total == 3)                       and {"T", 0.25, 2} or
					                                        (dirs_total == 2 and x_plus ~= x_minus) and {"L", 0.1,  1} or
						                                    (dirs_total == 2 and x_plus == x_minus) and {"I", 0.3,  1} or -- chance is 0.3 which translates to 0.15
						                                    (dirs_total <=1)                        and {" ", 0,    0})

	local might_be_bridge = #minetest.find_nodes_in_area(pos, {x=pos.x+10, y=pos.y+5, z=pos.z+10}, {"air", "group:igniter", "group:liquid"}) > 0
	local tile_has_doors = room_style.corridors_have_doors
	                       and math.random() < chance_of_doors
						   and not made_room
						   and not (might_be_bridge and (bridge_type == 3 or math.random() < 0.6 or room_style.no_doors_for_bridges))
	local doors_made_on_this_tile = 0

	-- FILL WITH AIR:
	local indexes = {1, 2, 3, 4}
	for _ = 1, 4 do
		local params = dirs[table.remove(indexes, math.random(1, #indexes))]
		if params[1] then
			for value_b = 1, 6 do
				local new_block_pos = {}
				for value_a = 5, 6 do
					new_block_pos[params[2]] = pos[params[2]] + params[4](value_b)
					new_block_pos[params[3]] = pos[params[3]] + value_a
					-- fill the path with air
					new_block_pos["y"] = pos.y+1
					fill_with_dungeon_air_if_okay(new_block_pos)
					new_block_pos["y"] = pos.y+2
					fill_with_dungeon_air_if_okay(new_block_pos)
				end
			end
			-- make doors:
			if tile_has_doors and math.random() < 0.5 and doors_made_on_this_tile < max_doors then
				local new_block_positions = {}
				local value_b = 4
				for value_a = 5, 6 do
					new_block_positions[value_a] = {
						[params[2]] = pos[params[2]] + params[4](value_b),
						[params[3]] = pos[params[3]] + value_a,
						["y"] = pos.y+1
					}
				end
				place_doubledoor_based_on_materials(new_block_positions[5], new_block_positions[6], params[5],
													{floor_type=floor_type, roof_type=roof_type, wall_type_1=wall_type_1, wall_type_2=wall_type_2, pillar_type=pillar_type},
												    omit_wall_2_in_caves and might_be_bridge)
				doors_made_on_this_tile = doors_made_on_this_tile + 1
			end
		end
		-- add a wall at the end if we are a dead end
		if is_dead_end == params[5] then
			local value_b = 0
			local new_block_pos = {}
			for value_a = 5, 6 do
				new_block_pos[params[2]] = pos[params[2]] + params[4](value_b)
				new_block_pos[params[3]] = pos[params[3]] + value_a
				new_block_pos["y"] = pos.y+1
				set_structure_block(new_block_pos, wall_type_1, omit_wall_1_in_caves)
				new_block_pos["y"] = pos.y+2
				set_structure_block(new_block_pos, wall_type_2, omit_wall_2_in_caves)
			end
		end
	end
	-- COATS IN WATER OR OBSIDIAN GLASS:
	local needs_water_source = {}
	local needs_glass = {}
	for _, params in ipairs(dirs) do
		if params[1] then
			for value_b = 1, 7 do
				local new_block_pos = {}
				for value_a = 3, 8 do
					new_block_pos[params[2]] = pos[params[2]] + params[4](value_b)
					new_block_pos[params[3]] = pos[params[3]] + value_a
					-- replace lava with water or glass
					for i = -1, 4 do
						if not ((i == -1 or i == 4) and (value_a == 3 or value_a == 8)) then
							local check_block_pos = {x=new_block_pos["x"], y=pos.y + i, z=new_block_pos["z"]}
							if minetest.registered_nodes[minetest.get_node(check_block_pos).name].groups["igniter"] then
								if minetest.find_node_near(check_block_pos, 1, {"randungeon:dungeon_air"}) then
									table.insert(needs_glass, check_block_pos)
								else
									table.insert(needs_water_source, check_block_pos)
								end
							end
						end
					end
				end
			end
		end
	end
	for _, pos in ipairs(needs_glass) do
		minetest.set_node(pos, {name="default:obsidian_glass"})
	end
	for _, pos in ipairs(needs_water_source) do
		-- test if placing a water source would flood surroundings
		local floodable_positions = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y, z=pos.z-1}, {x=pos.x, y=pos.y, z=pos.z+1},
		                             {x=pos.x, y=pos.y-1, z=pos.z}}
		local is_flooding = false
		for _, pos2 in ipairs(floodable_positions) do
			local node_name = minetest.get_node(pos2).name
			if contains({"air", "randungeon:dungeon_air", "default:water_flowing", "default:lava_flowing"}, node_name)
			   or minetest.registered_nodes[node_name]["floodable"] then
				is_flooding = true
			end
		end
		if is_flooding then
			-- if placing water source is dangerous, place stone or obsidian
			local area_border1 = {x=pos.x-1,y=pos.y-1,z=pos.z-1}
			local area_border2 = {x=pos.x+1,y=pos.y+1,z=pos.z+1}
			local surrounding_obsidian = #minetest.find_nodes_in_area(area_border1, area_border2, {"default:obsidian", "default:lava_source"})
			local surrounding_stone = #minetest.find_nodes_in_area(area_border1, area_border2, {"default:stone", "default:lava_flowing"})
			if surrounding_obsidian > surrounding_stone then
				minetest.set_node(pos, {name="default:obsidian"})
			else
				minetest.set_node(pos, {name="default:stone"})
			end
		else
			minetest.set_node(pos, {name="default:water_source"})
		end
	end
end

local function build_dungeon_tile_pillar(pos, pillar_type, dungeon_deph)
	if pillar_type == "air" or pillar_type == "randungeon:dungeon_air" then
		return -- shouldn't happen usually anyways but whatever
	end
	-- dungeon_deph is the distance between dungeon levels
	for x = pos.x+4, pos.x+7 do
		for z = pos.z+4, pos.z+7 do
			for y = pos.y-dungeon_deph + 3, pos.y-1 do
				if not (y > pos.y-dungeon_deph+3 and (x>pos.x+6 or x<pos.x+5 or z>pos.z+6 or z<pos.z+5)) then
					local new_pos = {x=x, y=y, z=z}
					local node = minetest.get_node(new_pos)
					if minetest.registered_nodes[node.name].buildable_to then
						-- change into obsidian (if igniter is near)
						if minetest.find_node_near(new_pos, 1, {"group:igniter"}) then
							node.name = "default:obsidian"
							minetest.set_node(new_pos, node)
						-- otherwise, set intended block
						else
							node.name = pillar_type
							minetest.set_node(new_pos, node)
						end
					end
				end
			end
		end
	end
end

local function build_dungeon_stairs(pos, stair_position, stair_orientation, dungeon_deph, floor_type, roof_type, wall_type_1, is_top_staircase)
	-- get positions for the staircase
	local x_min, x_max, z_min, z_max
	if stair_position == "x_plus" then
		x_min=9; x_max=10;
	elseif stair_position == "x_minus" then
		x_min=1; x_max=2;
	elseif stair_position == "z_plus" then
		z_min=9; z_max=10;
	elseif stair_position == "z_minus" then
		z_min=1; z_max=2;
	end
	if stair_orientation == "x_plus" then
		x_min=7; x_max=8;
	elseif stair_orientation == "x_minus" then
		x_min=3; x_max=4;
	elseif stair_orientation == "z_plus" then
		z_min=7; z_max=8;
	elseif stair_orientation == "z_minus" then
		z_min=3; z_max=4;
	end
	-- check if we can reduce the staircase height
	if is_top_staircase then
		local required_height = -3
		for y = pos.y+1, pos.y+dungeon_deph+2 do
			required_height = required_height + 1
			local found_bad_node = false
			for x = pos.x+x_min-1, pos.x+x_max+1 do
				for z = pos.z+z_min-1, pos.z+z_max+1 do
					local p = {x=x, y=y, z=z}
					local nname = minetest.get_node(p).name
					local ndef = minetest.registered_nodes[nname]
					if y < 0
					or (ndef["is_ground_content"] == true and nname ~= "air" or ndef["groups"]["liquid"])
					or (minetest.get_natural_light(p, 0.5) < 6 and not (ndef["groups"]["tree"])) then
						found_bad_node = true
					end
				end
			end
			if not found_bad_node then
				dungeon_deph = required_height
				local y_top = y
				-- remove vegetation above the point we found:
				for x = pos.x+x_min-1, pos.x+x_max+1 do
					for z = pos.z+z_min-1, pos.z+z_max+1 do
						minetest.set_node({x=x, y=y_top, z=z}, {name="air"}) -- <- make sure we don't build roof bc of leaves or smth
						-- remove non-leaf vegetation above us:
						for y = y_top, y+16 do
							local p = {x=x, y=y, z=z}
							local nname = minetest.get_node(p).name
							local ndef = minetest.registered_nodes[nname]
							if nname == "default:tree" or ndef["groups"]["tree"] or (ndef["groups"]["flammable"] and not ndef["groups"]["leaves"]) then
								minetest.set_node(p, {name="air"})
							end
						end
					end
				end
				break
			end
		end
	end
	-- make bottom platform
	for x = pos.x+x_min, pos.x+x_max do
		for z = pos.z+z_min, pos.z+z_max do
			set_insulated_structure_block({x=x, y=pos.y, z=z}, floor_type)
		end
	end
	-- make roof platform
	for x = pos.x+x_min, pos.x+x_max do
		for z = pos.z+z_min, pos.z+z_max do
			local roof_pos = {x=x, y=pos.y+dungeon_deph+3, z=z}
			if minetest.get_node(roof_pos).name == "air" then
				minetest.set_node(roof_pos, {name="doors:trapdoor_steel"})
			else
				set_insulated_structure_block(roof_pos, roof_type)
			end
		end
	end
	-- make vertical tunnel
	for x = pos.x+x_min, pos.x+x_max do
		for z = pos.z+z_min, pos.z+z_max do
			for y = pos.y+1, pos.y+dungeon_deph+2 do
				make_insulated_cavity({x=x, y=y, z=z})
			end
		end
	end
	-- make walls around vertical tunnel
	for x = pos.x+x_min-1, pos.x+x_max+1 do
		for z = pos.z+z_min-1, pos.z+z_max+1 do
			for y = pos.y+1, pos.y+dungeon_deph+2 do
				if x == pos.x+x_min-1 or x==pos.x+x_max+1 or z == pos.z+z_min-1 or z == pos.z+z_max+1 then
					local block_to_build_wall_to = minetest.get_node({x=x, y=y, z=z}).name
					-- don't replace dungeon air with our wall so we can still step out into the dungeon:
					if not contains({"randungeon:dungeon_air", "default:glass", "default:obsidian_glass"}, block_to_build_wall_to) then
						local p = {x=x, y=y, z=z}
						-- don't replace waterlilys or snow if underground, but rather remove them since these are pool decorations:
						if contains({"flowers:waterlily_waving", "default:snow"}, block_to_build_wall_to) and minetest.get_natural_light(p) < 4 then
							minetest.set_node(p, {name="randungeon:dungeon_air"})
						else
							set_insulated_structure_block(p, wall_type_1)
						end
					end
				end
			end
		end
	end
	-- check if we see an entrancy
	local entry_found = false
	for _, x in ipairs({pos.x+x_min-1, pos.x+x_max+1}) do
		for _, z in ipairs({pos.z+z_min-1, pos.z+z_max+1}) do
			for y = pos.y+dungeon_deph, pos.y+dungeon_deph+2 do
				if minetest.get_node({x=x, y=y, z=z}).name == "randungeon:dungeon_air" then
					entry_found = true
				end
			end
		end
	end
	-- make stairs
	local stair_positions = {
		{pos.x+x_min, pos.z+z_max},
		{pos.x+x_max, pos.z+z_max},
		{pos.x+x_max, pos.z+z_min},
		{pos.x+x_min, pos.z+z_min}
	}
	local stair_index
	if stair_orientation == "z_plus" then
		stair_index = 1
	elseif stair_orientation == "x_plus" then
		stair_index = 2
	elseif stair_orientation == "z_minus" then
		stair_index = 3
	else
		stair_index = 4
	end
	for y = pos.y, pos.y+dungeon_deph do
		set_insulated_structure_block({x=stair_positions[stair_index][1], y=y, z=stair_positions[stair_index][2]}, floor_type)
		stair_index = stair_index + 1
		if stair_index > 4 then
			stair_index = stair_index - 4
		end
	end
	
	-- make tunnel wider at the top with tunnels so it actually reaches the nearest corridor, if needed
	if not entry_found and not is_top_staircase then
		local dirs = { -- a, b, a_min, a_max, tunnel_from, tunnel_dir
			{"x", "z", x_min, x_max, z_max, 1},
			{"x", "z", x_max, x_min, z_min, -1},
			{"z", "x", z_min, z_max, x_max, 1},
			{"z", "x", z_max, z_min, x_min, -1},
		--                           ^- the side of the staircase from which the tunnel gets build
		--             ^------^- marking from where to where the girth of the tunnel goes
		--         ^- dir that we build into/against
		--                                   ^ whether we build into or against this direction
		-- 	  ^- the dir that's ortogonal to the dir we build into
		}

		for _, dir in ipairs(dirs) do
			local a, b, a_min, a_max, b_tunnelstart, tunneldir = unpack(dir)
			local p
			if minetest.find_node_near({[a]=pos[a]+a_min, y=pos.y+dungeon_deph+1, [b]=pos[b]+b_tunnelstart+2*tunneldir}, 1, {name="randungeon:dungeon_air"})
			or minetest.find_node_near({[a]=pos[a]+a_max, y=pos.y+dungeon_deph+1, [b]=pos[b]+b_tunnelstart+2*tunneldir}, 1, {name="randungeon:dungeon_air"})
			or minetest.find_node_near({[a]=pos[a]+a_min, y=pos.y+dungeon_deph+1, [b]=pos[b]+b_tunnelstart+3*tunneldir}, 1, {name="randungeon:dungeon_air"})
			or minetest.find_node_near({[a]=pos[a]+a_max, y=pos.y+dungeon_deph+1, [b]=pos[b]+b_tunnelstart+3*tunneldir}, 1, {name="randungeon:dungeon_air"}) then
				for a_value = pos[a]+a_min, pos[a]+a_max do
					for b_value = pos[b]+b_tunnelstart+tunneldir*1, pos[b]+b_tunnelstart+tunneldir*4, tunneldir do
						-- make passage
						for y = pos.y+dungeon_deph+1, pos.y+dungeon_deph+2 do
							p = {[a]=a_value, y=y, [b]=b_value}
							if not contains({"flowers:waterlily_waving", "default:snow"}, minetest.get_node(p).name) then
								make_insulated_cavity(p)
							end
						end
						-- make passage floor
						p = {[a]=a_value, y=pos.y+dungeon_deph, [b]=b_value}
						if minetest.get_meta(p):get_string("must_be_fireproof") ~= "true" then -- don't cut into pool or pool bassin
							set_insulated_structure_block(p, floor_type)
						end
						-- make passage roof
						set_insulated_structure_block({[a]=a_value, y=pos.y+dungeon_deph+3, [b]=b_value}, roof_type)
					end
					-- make wall at the end of the tunnel
					local b_value = pos[b]+b_tunnelstart+tunneldir*5
					for y = pos.y+dungeon_deph+1, pos.y+dungeon_deph+2 do
						p = {[a]=a_value, y=y, [b]=b_value}
						if not contains({"flowers:waterlily_waving", "default:snow", "randungeon:dungeon_air"}, minetest.get_node(p).name) then
							set_insulated_structure_block(p, wall_type_1)
						end
					end
				end
				-- make wall at the side of extended structure
				for _, a_value in ipairs({pos[a]+a_min-1, pos[a]+a_max+1}) do
					for b_value = pos[b]+b_tunnelstart+tunneldir*1, pos[b]+b_tunnelstart+tunneldir*4, tunneldir do
						for y = pos.y+dungeon_deph+1, pos.y+dungeon_deph+2 do
							local p = {[a]=a_value, y=y, [b]=b_value}
							if not contains({"flowers:waterlily_waving", "default:snow", "randungeon:dungeon_air"}, minetest.get_node(p).name) then
								set_insulated_structure_block(p, wall_type_1)
							end
						end
					end
				end
				return
			end
		end
		print("no corridor entrance found: ".. tostring(pos.x) .. ", " .. tostring(pos.y+dungeon_deph+1) .. ", " .. tostring(pos.z))
	end
end

local function is_loaded_and_generated(pos, width_in_blocks, height_in_blocks)
	for x = 0, math.ceil(width_in_blocks / 16) do
		for z = 0, math.ceil(width_in_blocks / 16) do
			for y = 0, math.ceil(height_in_blocks / 16) do
				local position_to_load = {x=pos.x+16*x, y=pos.y-16*y, z=pos.z+16*z}
				if minetest.get_node(position_to_load).name == "ignore" then
					return false
				end
			end
		end
	end
	return true
end

local function make_forceload(pos, width_in_blocks, height_in_blocks)
	local positions_to_load = {}
	for x = 0, math.ceil(width_in_blocks / 16) do
		for z = 0, math.ceil(width_in_blocks / 16) do
			for y = 0, math.ceil(height_in_blocks / 16) do
				local position_to_load = {x=pos.x+16*x, y=pos.y-16*y, z=pos.z+16*z}
				table.insert(positions_to_load, position_to_load)
				minetest.forceload_block(position_to_load, true, -1)
			end
		end
	end
	return positions_to_load
end

local function remove_forceload(positions_to_load)
	for _, pos in ipairs(positions_to_load) do
		minetest.forceload_free_block(pos, true)
	end
end

local function add_artificial_caves(pos, width, height_in_blocks, wanted_cave_percentage, top_staircase_height)
	local surface_per_slice = (width * 10) * (width * 10) -- surface of every horizontal slice of dungeon
	--[[
    volume dungeon area per horizontal slice = (width * 10) * (width * 10)
	volume ball = 4/3 * pi * r^2
	durchmessr ball = 2*r
	volume ball per horizontal slice = 4/3 * pi * r^2 / (2r) = 4/3 * pi * r/2 = 4/6 * pi * r = 2/3 * pi * r

	[actual cave percentage] = ([pre-existing cave amount] + [volume ball per horizontal slice]) / [volume dungeon area per horizontal slice]
	=> [acp] = ([pca] + 2/3 * pi * r) / (100*width^2)
	=> [acp] = [pca] / (100*width^2) + 2/3 * pi * r / (100*width^2)
	=> [acp] = [pca] / (100*width^2) + 2/300 * pi * r / width^2   | - [pca] / (100*width^2)
	=> [acp] - [pca] / (100*width^2) = 2/300 * pi * r / width^2   | / (2/300)
	=> 150 * ([acp] - [pca] / (100*width^2)) = pi * r / width^2   | * width^2
	=> 150 * width^2 * ([acp] - [pca] / (100*width^2)) = pi * r   | / pi
	=> 150 * width^2 / pi * ([acp] - [pca] / (100*width^2)) = r   | umdrehen
	=> r = 150 * width^2 / pi * ([acp] - [pca] / (100*width^2))

	--]]

	-- determine how much is already filled by caves
	local total_air_blocks = 0
	for i = 0, math.ceil(height_in_blocks / 10) do
		local area_border1 = {x=pos.x, y=pos.y-i*10, z=pos.z}
		local area_border2 = {x=pos.x+10*width, y=pos.y-i*10, z=pos.z+10*width}
		local air_blocks_in_this_slice = #minetest.find_nodes_in_area(area_border1, area_border2, {"air", "group:liquid"})
		total_air_blocks = total_air_blocks + air_blocks_in_this_slice
	end
	local number_of_tested_slices = (1 + math.ceil(height_in_blocks / 10))
	local total_air_blocks_per_slice = total_air_blocks / number_of_tested_slices
	local total_air_blocks = total_air_blocks_per_slice * height_in_blocks
	local total_blocks = (10*width) * (10*width) * height_in_blocks
	local wanted_total_air_blocks = total_blocks * wanted_cave_percentage
	local needed_new_air_blocks = wanted_total_air_blocks - total_air_blocks

	-- print("total blocks: " .. tostring(total_blocks))
	-- print("air blocks: " .. tostring(total_air_blocks))
	-- print("wanted_total_air_blocks: " .. tostring(wanted_total_air_blocks))
	-- print("needed_new_air_blocks: " .. tostring(needed_new_air_blocks))

	-- fill the rest with air until we have enough:

	local round = 1  -- it uses two rounds, one with larger and one with smaller bubbles
	local radius_min = 15 -- 10 in round 2
	local radius_max = 30 -- 20 in round 2
	local fruitless_attempts = 0

	while true do
		-- make it easier if we are stuck and exit if we are still stuck after that
		if round == 1 and (needed_new_air_blocks <= 0 or fruitless_attempts > 30000) then
			round = 2
			radius_min = 10
			radius_max = 20
			fruitless_attempts = 0
		elseif round == 2 and (needed_new_air_blocks <= 0 or fruitless_attempts > 10000) then
			break
		end
		-- choose what to fill bubbles with
		local material
		local rand_num = math.random()
		if rand_num < 0.25 then
			material = "default:lava_source"
		elseif rand_num < 0.6 then
			material = "default:water_source"
		else
			material = "air"
		end
		-- decide how high the liquid should go, if it is one
		local pegel = false
		if material ~= "air" then
			if math.random() < 0.7 then
				pegel = math.random()
			end
		end
		-- decide on radius and position
		local max_bubble_radius = math.min(radius_max, math.ceil(needed_new_air_blocks * 3/2 / math.pi))
		local bubble_radius = math.random(radius_min, max_bubble_radius)
		local bubble_pos = {
			x = math.random(pos.x, pos.x+10*width),
			y = math.random(pos.y, pos.y-height_in_blocks),
			z = math.random(pos.z, pos.z+10*width)
		}
		-- decide if we'll add nature to the bubble
		local nature = false
		local nature_metadata = {}
		if material == "air" or (material == "default:water_source" and pegel and pegel < 0.45) and math.random() < 0.5 then
			if math.random() < 0.5 then
				nature = "randungeon:pretty_forest"
			else
				nature = "randungeon:swampy_forest"
			end
			nature_metadata = make_metadata_for_nature({x=bubble_pos.x, y=bubble_pos.y - bubble_radius * 1/3, z=bubble_pos.z}, nature)
		end
		-- build it if it doesn't intersect with pre-existing caves
		if not minetest.find_node_near(bubble_pos, bubble_radius+1, {"air", "group:liquid"}) then
			fruitless_attempts = 0
			local nature_blocks_to_grow_directly = {}
			for x = -bubble_radius, bubble_radius do
				for y = -bubble_radius, bubble_radius do
					for z = -bubble_radius, bubble_radius do
						if (x^2 + y^2 + z^2) ^ 0.5 <= bubble_radius then
							local new_block_pos = {x=bubble_pos.x+x, y=bubble_pos.y+y, z=bubble_pos.z+z}
							if (not pegel) or y < -bubble_radius + 2 * bubble_radius * pegel then
								minetest.set_node(new_block_pos, {name=material})
							else
								minetest.set_node(new_block_pos, {name="air"})
							end
							needed_new_air_blocks = needed_new_air_blocks - 1
							-- make nature if needed and we're at the ground of a bubble
							if nature and (x^2 + (y-1)^2 + z^2) ^ 0.5 > bubble_radius then
								minetest.set_node(new_block_pos, {name=nature})
								minetest.get_meta(new_block_pos):from_table(nature_metadata)
								-- find out if any nature blocks are outside the area we will green later (after the corridors are set):
								if (bubble_pos.x+x < pos.x) or (bubble_pos.x+x > pos.x + width * 10)
								or (bubble_pos.z+z < pos.z) or (bubble_pos.z+z > pos.z + width * 10)
								or (bubble_pos.y+y > pos.y - top_staircase_height) or (bubble_pos.y+y < pos.y-height_in_blocks+6) then
									table.insert(nature_blocks_to_grow_directly, new_block_pos)
								end
							end
						end
					end
				end
			end
			-- green all nature blocks that are outside the area we will green later:
			for _, pos2 in ipairs(nature_blocks_to_grow_directly) do
				make_nature(pos2)
			end
		else
			fruitless_attempts = fruitless_attempts + 1
		end
	end
end

local function make_dungeon_tile(pos, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, x_plus, x_minus, z_plus, z_minus,
	                             dungeon_deph, staircase_height, pillar_height, stair_position, stair_orientation, bridge_type, is_dead_end, room_style, has_pillar,
						         has_room, is_top_level)

	if is_top_level == nil then
		is_top_level = false
	end
	if is_dead_end then
		is_dead_end = stair_position
	end
	if not room_style then
		room_style = make_unconnected_room_style({wall_type_1=wall_type_1, wall_type_2=wall_type_2})
	end
	if has_pillar then
		build_dungeon_tile_pillar(pos, pillar_type, pillar_height)
	end
	build_dungeon_tile_floor_and_roof_and_walls(pos, floor_type, roof_type, wall_type_1, wall_type_2, pillar_type, x_plus, x_minus, z_plus, z_minus, bridge_type,
	                                            is_dead_end, pillar_height, stair_position, room_style, has_room)
	if stair_position then
		build_dungeon_stairs(pos, stair_position, stair_orientation, staircase_height, floor_type, roof_type, wall_type_1, is_top_level)
	end
end

local function make_dungeon_level(pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, dungeon_deph, staircase_height, pillar_height, rim_sealed,
	                        called_by_dungeon_maker_function, bridge_type, room_style, map, is_top_level)

	if is_top_level == nil then
		is_top_level = false
	end
	if not width then
		width = 10
	end
	if not staircase_height then
		staircase_height = 12
	end
	if not pillar_height then
		pillar_height = staircase_height
	end
	if rim_sealed == nil then
		rim_sealed = true
	end
	if not room_style then
		room_style = make_unconnected_room_style({wall_type_1=wall_type_1, wall_type_2=wall_type_2})
	end
	if not map then
		map = generate_dungeon_map(width, rim_sealed)
	end
	for x = 1, width do
		for z = 1, width do
			local tile_pos = {x=pos.x+(x-1)*10, y=pos.y, z=pos.z+(z-1)*10}
			local tile = map[x][z]
			local tile_specific_materials = tile.tile_specific_materials or {}
			local tile_specific_room_style = tile.tile_specific_room_style

			make_dungeon_tile(tile_pos,
			                  tile_specific_materials.floor_type or floor_type,
							  tile_specific_materials.wall_type_1 or wall_type_1,
							  tile_specific_materials.wall_type_2 or wall_type_2,
							  tile_specific_materials.roof_type or roof_type, 
							  tile_specific_materials.pillar_type or pillar_type,
							  tile.x_plus, tile.x_minus, tile.z_plus, tile.z_minus,
			                  dungeon_deph, staircase_height, pillar_height, tile["stair_position"], tile["stair_orientation"],
							  tile_specific_materials.bridge_type or bridge_type,
							  tile["is_dead_end"],
							  tile_specific_room_style or room_style,
							  tile["has_pillar"], tile["has_room"], is_top_level)
		end
	end
	-- replace dungeon air with normal air
	if not called_by_dungeon_maker_function then
		for x = 1, width * 10 do
			for z = 1, width * 10 do
				for y = 0, dungeon_deph do
					if minetest.get_node({x=pos.x+x, y=pos.y+y, z=pos.z+z}).name == "randungeon:dungeon_air" then
						minetest.set_node({x=pos.x+x, y=pos.y+y, z=pos.z+z}, {name="air"})
					end
				end
			end
		end
	end
end

randungeon_finished_dungeons = {}
randungeon_make_dungeon_function_container = {}
dungeon_generation_started = {}

local function make_dungeon_once_generated(blockpos, action, calls_remaining, param)
	local pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, bridge_type, dungeon_deph, rim_sealed, dungeon_levels,
	dungeon_bottom_deph, dungeon_top_deph, random_materials, cave_percentage, light_up_corridors, gold_pools, treasure_block, dungeon_id = unpack(param)
	if calls_remaining > 0 then
		return
	end
	local pos1 = {x=pos.x-30, y=pos.y, z=pos.z-30}
	local pos2 = {x=pos.x+width*10+30, y=pos.y-(dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph)-17, z=pos.z+width*10+30}
	minetest.load_area(pos1, pos2)
	-- print("dungeon build area generated.")
	randungeon_make_dungeon_function_container[1](pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, bridge_type, dungeon_deph, rim_sealed,
	                                                 dungeon_levels, dungeon_bottom_deph, dungeon_top_deph, random_materials, cave_percentage, light_up_corridors,
													 gold_pools, treasure_block, dungeon_id)
end

local function make_dungeon(pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, bridge_type, dungeon_deph, rim_sealed, dungeon_levels,
	                  dungeon_bottom_deph, dungeon_top_deph, random_materials, cave_percentage, light_up_corridors, gold_pools, treasure_block, dungeon_id)
	-- proload & forceload area
	if dungeon_id == false or dungeon_id == nil then -- a dungeon id so we can be sure we don't generate the same dungeon twice
		dungeon_id = math.random()
		dungeon_generation_started[dungeon_id] = minetest.get_us_time() / 10000000
	elseif contains(randungeon_finished_dungeons, dungeon_id) then
		print("dungeon with id " .. tostring(dungeon_id) .. " already build; aborting.")
		return
	end
	local pos1 = {x=pos.x-30, y=pos.y, z=pos.z-30}
	local pos2 = {x=pos.x+width*10+30, y=pos.y-(dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph)-17, z=pos.z+width*10+30}
	local forceloaded_area = make_forceload(pos, width * 10, dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph)
	minetest.load_area(pos1, pos2)
	if not is_loaded_and_generated(pos, width * 10, dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph) then
		minetest.emerge_area(
			pos1, pos2, make_dungeon_once_generated, {pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, bridge_type, dungeon_deph, rim_sealed,
			dungeon_levels, dungeon_bottom_deph, dungeon_top_deph, random_materials, cave_percentage, light_up_corridors, gold_pools, treasure_block, dungeon_id}
		)
		return
	end
	table.insert(randungeon_finished_dungeons, dungeon_id)
	print("Build area for dungeon with dungeon_id " .. tostring(dungeon_id) .. " generated.")

	-- make air bubbles
	if not cave_percentage then
		cave_percentage = 30
	end
	add_artificial_caves(pos, width, dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph, cave_percentage/100, dungeon_top_deph)

	pos.y = pos.y - dungeon_top_deph

	-- make dungeon maps & materials & room styles:
	local dungeon_maps = {generate_dungeon_map(width, rim_sealed)}
	local materials = {}
	local room_styles = {}
	for i = 2, dungeon_levels do
		table.insert(dungeon_maps, generate_dungeon_map(width, rim_sealed, dungeon_maps[i-1]))
	end
	local given_materials = {floor_type=floor_type, wall_type_2=wall_type_2, wall_type_1=wall_type_1, roof_type=roof_type, pillar_type=pillar_type, bridge_type=bridge_type}
	local start_materials = make_random_dungeon_material_scheme()
	for i = 1, dungeon_levels do
		if random_materials then
			local level_above_materials = materials[i-1] or start_materials
			table.insert(materials, get_good_material_set(level_above_materials))
		else
			table.insert(materials, table.copy(given_materials))
		end
	end
	local start_room_style = make_unconnected_room_style(start_materials)
	for i = 1, dungeon_levels do
		local level_above_room_style = room_styles[i-1] or start_room_style
		table.insert(room_styles, make_room_style(materials[i], level_above_room_style))
		if i == 1 then
			-- make highest levels frozen/ not frozen state depend on biome
			local biome_data = minetest.get_biome_data({x=pos.x+10*width/2, y=0, z=pos.z+10*width/2})
			local heat
			if biome_data == nil then
				heat = 50
			else
				heat = biome_data.heat
			end
			room_styles[i].frozen = (heat < 50)
		end
	end

	-- make special levels:
	if gold_pools then
		make_treasure_level(dungeon_maps, materials, room_styles)
	end
	if treasure_block and treasure_block ~= "" then
		make_treasure_rooms(dungeon_maps, materials, room_styles, pos, dungeon_deph, treasure_block)
	end

	-- actually build dungeon:
	for i = 1, dungeon_levels do
		local level_pos = {x=pos.x, y=pos.y-((i-1)*dungeon_deph), z=pos.z}
		-- unpack materials & room style
		floor_type = materials[i].floor_type
		wall_type_1 = materials[i].wall_type_1
		wall_type_2 = materials[i].wall_type_2
		roof_type = materials[i].roof_type
		pillar_type = materials[i].pillar_type
		bridge_type = materials[i].bridge_type
		local room_style = room_styles[i]
		-- determine pillar and staircase height
		local pillar_height = dungeon_deph
		local staircase_height = dungeon_deph
		if i == 1 then
			staircase_height = dungeon_top_deph
		elseif i == dungeon_levels then
			pillar_height = dungeon_bottom_deph
		end
		-- make dungeon level
		make_dungeon_level(level_pos, width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, dungeon_deph, staircase_height, pillar_height,
		                   rim_sealed, true, bridge_type, room_style, dungeon_maps[i], i==1)
	end
	-- replace dungeon air with normal air
	for x = 1, width * 10 do
		for z = 1, width * 10 do
			-- for y = -dungeon_levels*dungeon_deph-1, dungeon_deph do
			for y = -(dungeon_top_deph + dungeon_bottom_deph + (dungeon_levels - 1) * dungeon_deph)-17, dungeon_top_deph+10 do
				local p = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
				local current_node = minetest.get_node(p).name
				if contains({"randungeon:dungeon_air", "air"}, current_node) and light_up_corridors then
					minetest.set_node(p, {name="randungeon:air_glowing"})
				elseif current_node == "randungeon:dungeon_air" then
					minetest.set_node(p, {name="air"})
				end
			end
		end
	end
	-- unforceload area
	remove_forceload(forceloaded_area)
	-- inform about generated dungeon
	print("dungeon with id " .. tostring(dungeon_id) .. " generated in " ..
	      tostring(minetest.get_us_time() / 10000000 - dungeon_generation_started[dungeon_id]) .. " seconds.")
end

randungeon_make_dungeon_function_container[1] = make_dungeon

randungeon.make_dungeon = make_dungeon

return {
    make_dungeon_tile = make_dungeon_tile,
    make_dungeon_level = make_dungeon_level,
    make_dungeon = make_dungeon
}