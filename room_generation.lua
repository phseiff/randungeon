-- Helper Functions For Block Comparisons
local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number
local get_solid_air_block_replacement = helper_functions.get_solid_air_block_replacement

-- Door Generation
local door_generation_code = dofile(mod_path.."/doors.lua")
local place_doubledoor_based_on_materials = door_generation_code.place_doubledoor_based_on_materials

-- Cave Nature Generator Functions
local cave_nature_generator_functions = dofile(mod_path.."/make_nature.lua")
local make_metadata_for_nature = cave_nature_generator_functions.make_metadata_for_nature
local make_nature = cave_nature_generator_functions.make_nature
local make_nature_in_area = cave_nature_generator_functions.make_nature_in_area
local get_random_pool_nature_type = cave_nature_generator_functions.get_random_cave_nature_type

-- Code to make frozen levels especially frozen
local frozen_levels_functions = dofile(mod_path.."/frozen_levels.lua")
local freeze_area = frozen_levels_functions.freeze_area

--
-- Helper Function
--

local function set_structure_block(pos, name, only_lace_solid_blocks)
	-- turn cobble around water into mossy cobble
	if name == "default:cobble" and minetest.find_node_near(pos, 1, {"group:water"}) then
		if math.random() < 0.5 then
			name = "default:mossycobble"
		else
			name = "randungeon:unmossy_cobble"
		end
	end
    -- reduced & modified version of set_structure_block from build_dungeon_from_blocks.lua
	local old_node_name = minetest.get_node(pos).name
	-- air nodes don't get placed, unless in water, in which case they get turned into glass, or lava, in which case they get turned into dungeon air
	-- (that later gets automatically obsidian-glass-mantlet)
	if name == "air" or name == "randungeon:dungeon_air" then
		if minetest.registered_nodes[old_node_name].buildable_to then
			minetest.set_node(pos, {name=get_solid_air_block_replacement(pos, true)})
		else
			return
		end
	end
	-- "[new_node]_with_" nodes don't get replaced, so stone with ores doesn't get replaced by stone
	if string.find(old_node_name, "^"..name.."_with_") then
		return
	end
	-- otherwise, set node
	minetest.set_node(pos, {name=name})
end

--
-- Functions To Build Dungeon Rooms
--

local function make_unconnected_room_style(materials)
    -- Generates a pattern to be applied to 2/3 of all rooms in a given dungeon level, based on its materials

    -- unpack relevant materials:
    local wall_type_1 = materials.wall_type_1
    local wall_type_2 = materials.wall_type_2
    -- ceiling height - will be higher in some rooms:
	local ceiling_height = 4
	local rand = math.random()
	if rand < 0.3 then
		ceiling_height = 5
	elseif rand < 0.15 then
		ceiling_height = 6
	end
	-- can have pillars and similar structures (if they'd be made from air they can't exist)
	local can_have_pillars = true
	if contains({wall_type_1, wall_type_2}, "air") then
		can_have_pillars = false
	end
	-- type of pillars/inner walls:
	local inner_walls = false -- <- means that there'll be bookshelf-like structures around the wall
	local edge_pillars = false -- <- means that there'll be pillars in all 4 corners
	local pillar_room = false -- <- means that every direction (x-x and z-z) will have a row of pillars if there is a door in that dir and it has an uneven block length
	local door_pillars = false -- <- means that there'll be two pillars in front of every door
	local rand = math.random()
	if contains({wall_type_1, wall_type_2}, "randungeon:bookshelf") and math.random() < 0.67 or rand < 0.15 then
		inner_walls = true -- 15% chance
	elseif rand < 0.40 then
		pillar_room = true -- 25% chance
	elseif rand < 0.52 then
		edge_pillars = true -- 12% chance
	elseif rand < 0.60 then
		door_pillars = true -- 8% chance
	else
		can_have_pillars = false -- 40% chance for no pillars at all
	end
	-- some rooms get max size or min size
	local max_size_room = false
	local min_size_room = false
	if math.random() < 0.2 then
		max_size_room = true
	elseif math.random() < 0.2 then
		min_size_room = true
	end
    -- pillar materials
    local rand = math.random()
    local pillar_material_type
    if rand < 0.2 and not (wall_type_1 == "randungeon:bookshelf" and wall_type_2 ~= "randungeon:bookshelf" and inner_walls) then
        pillar_material_type = 3 -- means that entire pillar is made from wall_type_2
    elseif rand < 0.4 and not (wall_type_2 == "randungeon:bookshelf" and wall_type_1 ~= "randungeon:bookshelf" and inner_walls) then
        pillar_material_type = 1 -- means entire pillar is made from wall_type_1
    else
        pillar_material_type = 2 -- means pillar is made from wall_type_1 for lowest block and wall_type_2 for all others
    end
    -- make frozen
    local frozen = false
    if math.random() < 1/5.5 then
        frozen = true
    end

	-- make room door style:
	local comfy_style = 0 -- <- gets bigger for wood/bookshelfes, gets lower for barebones stone
	for material_type, material_name in pairs(materials) do
		local to_add = 0
		if material_type == "bridge_type" then
			to_add = 0 -- ignore this bc it's not actually a material
		elseif material_name == "default:stone" or material_name == "default:desert_stone" or material_name == "air" then
			to_add = -1
		elseif minetest.registered_nodes[material_name].groups.wood then
			to_add = 1
		elseif material_name == "randungeon:bookshelf" then
			to_add = 2
		end
		if material_type == "pillar_type" then
			to_add = to_add / 2
		end
		comfy_style = comfy_style + to_add
	end
	local max_comfy_style = 6 
	local min_comfy_style = -4 
	local capped_comfy_style = comfy_style < -4 and -4 or -- min: walls, floor and roof from stone; everything else gets capped
	                           comfy_style > 6 and 6 or -- max: 2 bookshelfes and 2 wood; everything else gets capped
				               comfy_style
	local no_doors_chance = 1/5
	local all_doors_chance = 1/5
	if capped_comfy_style > 0 then
		no_doors_chance = 1/5 - 1/10 * (capped_comfy_style / 6)
		all_doors_chance = 1/5 + 1.5/5 *(capped_comfy_style / 6)
	elseif capped_comfy_style < 0 then
		all_doors_chance = 1/5 - 1/10 * (capped_comfy_style / -4)
		no_doors_chance = 1/5 + 1.5/5 * (capped_comfy_style / -4)
	end
	local rand = math.random()
	local room_has_doors = rand < no_doors_chance    and 0 or -- no doors
						   rand < 1-all_doors_chance and 1 or -- some doors
						   rand < 1                  and 2    -- all doors

	-- make corridor door style (it depends on comfyness factor and room door style):
	comfy_style = comfy_style - (room_has_doors-1) * 2
	capped_comfy_style = comfy_style < -4 and -4 or
	                     comfy_style > 6 and 6 or
				         comfy_style
	no_doors_chance = 0.3
	if capped_comfy_style > 0 then
		no_doors_chance = no_doors_chance - 0.2 * (capped_comfy_style / 6)
	elseif capped_comfy_style < 0 then
		no_doors_chance = no_doors_chance + 0.4 * (capped_comfy_style / -4)
	end
	local corridors_have_doors = not (math.random() < no_doors_chance)

	-- decide if bridges get doors or not:
	local no_doors_for_bridges = math.random() < 0.5

    return { -- roughly 45 combinations:
        ceiling_height = ceiling_height,
        can_have_pillars = can_have_pillars,
        inner_walls = inner_walls,
        pillar_room = pillar_room,
        edge_pillars = edge_pillars,
        door_pillars = door_pillars,
        max_size_room = max_size_room,
        min_size_room = min_size_room,
        pillar_material_type = pillar_material_type,
        frozen = frozen,
		room_has_doors = room_has_doors,
		corridors_have_doors = corridors_have_doors,
		no_doors_for_bridges = no_doors_for_bridges,

		-- properties that don't get generated in random room style generation, but that can be manually set to alter the appearence of themed rooms/levels:
		pool=nil,
		pool_liquid=nil, -- can be "default:Water_source" or "randungeon:lava_source"
		water_lilies=nil,
		is_treasure_level=false,
		room_center_treasure_block=nil,
		expand_x_plus=nil,
		expand_x_minus=nil,
		expand_z_plus=nil,
		expand_z_minus=nil,
		door_x_plus=nil,
		door_x_minus=nil,
		door_z_plus=nil,
		door_z_minus=nil,
		dont_deviate_from_room_style=false,
		build_even_if_in_cave=false,
		pinnacles_if_floating_in_cave=false,

		-- top_deph: height of the level/ the staircases of the level
		-- bottom_deph: deph of the level/ height of its pillars
    }
end

local function compare_room_styles(room_style_1, room_style_2)
    local score = 0

	-- -1.5 point per door type difference:
	score = score - math.abs(room_style_1.room_has_doors - room_style_2.room_has_doors) * 1.5
	score = score - bool_to_number(room_style_1.corridors_have_doors ~= room_style_2.corridors_have_doors) * 1.5
	-- -0.65 points if no_doors_for_bridges differs bc tbh it doesn't matter all that much:
	score = score - bool_to_number(room_style_1.no_doors_for_bridges ~= room_style_2.no_doors_for_bridges) * 0.65
    -- -1 point per pillar type difference:
    score = score - math.abs(room_style_1.pillar_material_type - room_style_2.pillar_material_type)
    -- -1 point per height difference:
    score = score - math.abs(room_style_1.ceiling_height - room_style_2.ceiling_height)
    -- -2 point if one level has min/max sized rooms and the other hasn't:
    if room_style_1.max_size_room ~= room_style_2.max_size_room or room_style_1.min_size_room ~= room_style_2.min_size_room then
        score = score - 1
    end
    -- -5 point if one level has min/max sized rooms and the other one has the opposite:
    if room_style_1.max_size_room == room_style_2.min_size_room and room_style_1.min_size_room == room_style_2.max_size_room then
        score = score - 5
    end
    -- -2 points if one level is frozen and the other isn't:
    if room_style_1.frozen ~= room_style_2.frozen then
        score = score - 2
    end
    -- -3 if one can have inner-room structures and the other can't:
    if room_style_1.can_have_pillars ~= room_style_2.can_have_pillars then
        score = score - 3
    else
        -- -2 points if one level has inner walls (aka bookshelves) and the other hasn't:
        if room_style_1.inner_walls ~= room_style_1.inner_walls then
            score = score - 2
        else
            -- -1 points if they have different room types among pillar_room/ edge_pillars/ door_pillars:
            for _, attr in ipairs({"pillar_room", "edge_pillars", "door_pillars"}) do
                if room_style_1[attr] ~= room_style_2[attr] then
                    score = score - 1
                    break
                end
            end
        end
    end
    return score
end

local function make_room_style(materials, former_room_style)
    -- Generates a pattern to be applied to 2/3 of all rooms in a given dungeon level, based on its materials AND the room pattern of the level above
    local best_score = -1000
    local best_room_style = make_unconnected_room_style(materials)
    for i = 1, 12 do
        local new_room_style = make_unconnected_room_style(materials)
        local new_score = compare_room_styles(former_room_style, new_room_style)
        if new_score > best_score then
            best_score = new_score
            best_room_style = new_room_style
        end
    end
    return best_room_style
end

local function make_room(pos, pos_a, pos_b, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, x_plus, x_minus, z_plus, z_minus, room_style, rooms_data)
	-- normalize pos values:
	if not pos_a or not pos_b then
		pos_a = {x=pos.x+1, y=pos.y, z=pos.z+1}
		pos_b = {x=pos.x+10, y=pos.y, z=pos.z+10}
	else
		pos = {x=pos_a.x-1, y=pos_a.y, z=pos_a.z-1}
	end
	-- check if we can even make a room here
	local is_in_cave = false
	if #minetest.find_nodes_in_area(pos_a, pos_b, {"air", "group:igniter", "group:liquid"}) > 0 then
		is_in_cave = true
		if not room_style.build_even_if_in_cave then
			return false
		end
	end
    -- generate individual room style only for this room in some cases
    local frozen = room_style.frozen
    if math.random() < 1/3 and not room_style.dont_deviate_from_room_style then
        room_style = make_unconnected_room_style(
			{floor_type=floor_type, wall_type_1=wall_type_1, wall_type_2=wall_type_2, roof_type=roof_type, pillar_type=pillar_type}
		)
    end
    -- unpack room style attributes
    local ceiling_height = room_style.ceiling_height
    local can_have_pillars = room_style.can_have_pillars
    local inner_walls = room_style.inner_walls
    local pillar_room = room_style.pillar_room
    local edge_pillars = room_style.edge_pillars
    local door_pillars = room_style.door_pillars
    local max_size_room = room_style.max_size_room
    local min_size_room = room_style.min_size_room
    local pillar_material_type = room_style.pillar_material_type
	local room_has_doors = room_style.room_has_doors
	if room_has_doors == 1 then -- if room style is "random amount of doors" then we will randomize it further by allowing additional room styles
		room_has_doors = make_unconnected_room_style({}).room_has_doors
	end

	-- actual building:

	local room_corner_1 = vector.add(pos_a, {x=1, y=0, z=1})
	local room_corner_2 = vector.add(pos_b, {x=-1, y=ceiling_height, z=-1})

	-- extend room in some directions:
	if (x_plus and not min_size_room and (max_size_room or math.random() < 0.5) and room_style.expand_x_plus ~= false) or room_style.expand_x_plus == true then
		room_corner_2.x = room_corner_2.x + 1
	end
	if (x_minus and not min_size_room and (max_size_room or math.random() < 0.5) and room_style.expand_x_minus ~= false) or room_style.expand_x_minus == true then
		room_corner_1.x = room_corner_1.x - 1
	end
	if (z_plus and not min_size_room and (max_size_room or math.random() < 0.5) and room_style.expand_z_plus ~= false) or room_style.expand_z_plus == true then
		room_corner_2.z = room_corner_2.z + 1
	end
	if (z_minus and not min_size_room and (max_size_room or math.random() < 0.5) and room_style.expand_z_minus ~= false) or room_style.expand_z_minus == true then
		room_corner_1.z = room_corner_1.z - 1
	end

	-- enter into randungeon.dungeons:
	if not rooms_data[room_corner_2.y] then
		rooms_data[room_corner_2.y] = {}
	end
	local room_data = {
		p1 = table.copy(room_corner_1),
		p2 = table.copy(room_corner_2),
		frozen = room_style.frozen
	}
	table.insert(rooms_data[room_corner_2.y], room_data)

	-- build room:
	for x = room_corner_1.x, room_corner_2.x do
		for z = room_corner_1.z, room_corner_2.z do
			for y = room_corner_1.y-1, room_corner_2.y do
				-- set floor (make it one block deeper so we can later place a pool in it)
				if y <= room_corner_1.y then
					set_structure_block({x=x, y=y, z=z}, floor_type)
				-- set lower wall part
				elseif y == room_corner_1.y + 1 then
					set_structure_block({x=x, y=y, z=z}, wall_type_1)
				-- set upper wall part
				elseif y < room_corner_2.y then
					set_structure_block({x=x, y=y, z=z}, wall_type_2)
				-- set upper wall part
				elseif y == room_corner_2.y then
					set_structure_block({x=x, y=y, z=z}, roof_type)
				end
			end
		end
	end
	-- fill room with air
	for x = room_corner_1.x+1, room_corner_2.x-1 do
		for z = room_corner_1.z+1, room_corner_2.z-1 do
			for y = room_corner_1.y+1, room_corner_2.y-1 do
				minetest.set_node({x=x, y=y, z=z}, {name="randungeon:dungeon_air"})
			end
		end
	end
	-- give pinnacles if needed
	if room_style.pinnacles_if_floating_in_cave and is_in_cave then
		-- print("PINNACLES ON PIZZA !")
		local top_side_area = (room_corner_2.x - room_corner_1.x + 1) * (room_corner_2.z - room_corner_1.z + 1) - 4 -- <-- 4 bc of the pillar on top
		local free_top_side_area = #minetest.find_nodes_in_area(
			{x=room_corner_1.x, y=room_corner_2.y+1, z=room_corner_1.z},
			{x=room_corner_2.x, y=room_corner_2.y+1, z=room_corner_2.z}, {"air", "group:water"}
		)
		if free_top_side_area / top_side_area > 0.4 then
			local pinnacle_table = {
				{room_corner_1, 1, 1},
				{room_corner_2,  -1, -1},
				{{x=room_corner_1.x, z=room_corner_2.z}, 1, -1},
				{{x=room_corner_2.x, z=room_corner_1.z}, -1, 1}
			}
			local pinnacle_height = room_corner_2.y+1
			for _, params in ipairs(pinnacle_table) do
				local p, x_dir, z_dir = unpack(params)
				local x_dir_2 = (room_corner_2.x - room_corner_1.x >= 9) and 2*x_dir or 0
				local z_dir_2 = (room_corner_2.z - room_corner_1.z >= 9) and 2*z_dir or 0
				minetest.set_node({x=p.x, y=pinnacle_height, z=p.z}, {name=wall_type_1})
				minetest.set_node({x=p.x+x_dir*2, y=pinnacle_height, z=p.z}, {name=wall_type_1})
				minetest.set_node({x=p.x, y=pinnacle_height, z=p.z+z_dir*2}, {name=wall_type_1})
				minetest.set_node({x=p.x+x_dir_2*2, y=pinnacle_height, z=p.z}, {name=wall_type_1})
				minetest.set_node({x=p.x, y=pinnacle_height, z=p.z+z_dir_2*2}, {name=wall_type_1})
			end
		end
	end

	-- place treasure block in room center, if needed
	if room_style.room_center_treasure_block then
		local treasure_x = math.random() < 0.5 and math.floor(room_corner_1.x + (room_corner_2.x - room_corner_1.x) / 2)
		                                        or math.ceil(room_corner_1.x + (room_corner_2.x - room_corner_1.x) / 2)
		local treasure_z = math.random() < 0.5 and math.floor(room_corner_1.z + (room_corner_2.z - room_corner_1.z) / 2)
		                                        or math.ceil(room_corner_1.z + (room_corner_2.z - room_corner_1.z) / 2)
		local treasure_pos = {x=treasure_x, y=room_corner_1.y+1, z=treasure_z}
		minetest.set_node(treasure_pos, {name=room_style.room_center_treasure_block})
		minetest.get_meta(treasure_pos):set_string("dont_replace_with_air", "true")
		treasure_pos.y = treasure_pos.y - 1
		minetest.get_meta(treasure_pos):set_string("dont_replace_with_air", "true")
	end
	-- make pillars or inner walls
	if can_have_pillars then
		-- make inner walls
		if inner_walls then
			for x = room_corner_1.x+2, room_corner_2.x-2 do
				for z = room_corner_1.z+2, room_corner_2.z-2 do
					for y = room_corner_1.y+1, room_corner_1.y+2 do
						-- set lower wall part
						if y == room_corner_1.y + 1 and pillar_material_type ~= 3 or pillar_material_type == 1  then
							set_structure_block({x=x, y=y, z=z}, wall_type_1)
						-- set upper wall part
						elseif y >= room_corner_1.y + 2 or pillar_material_type == 3 then
							set_structure_block({x=x, y=y, z=z}, wall_type_2)
						end
					end
				end
			end
		-- make pillars:
		elseif pillar_room then
			local dirs = {}
			if (z_plus or z_minus) and math.fmod(room_corner_1.z - room_corner_2.z, 2) == 0 then
				table.insert(dirs, {"z", "x"})
			end
			if (x_plus or x_minus) and math.fmod(room_corner_1.x - room_corner_2.x, 2) == 0 then
				table.insert(dirs, {"x", "z"})
			end
            local start_y = room_corner_1.y+1
            if math.random() <= 0.7 and not minetest.registered_nodes[wall_type_1].groups.flammable and not minetest.registered_nodes[wall_type_2].groups.flammable then
                start_y = room_corner_1.y -- <- pillars can go one block deeper than normal in many cases if they aren't woody to spice up pools
            end
			for _, dir in ipairs(dirs) do
				local v_a = dir[1]
				local v_b = dir[2]
				for a = room_corner_1[v_a]+2, room_corner_2[v_a]-2, 2 do
					for _2, b in ipairs({room_corner_1[v_b]+2, room_corner_2[v_b]-2}) do
						for y = start_y, room_corner_2.y-1 do
							local new_pos = {}
							new_pos[v_a] = a
							new_pos[v_b] = b
							new_pos.y = y
							if y <= room_corner_1.y+1 and pillar_material_type ~= 3 or pillar_material_type == 1 then
								set_structure_block(new_pos, wall_type_1)
							elseif y >= room_corner_1.y+2 or pillar_material_type == 3 then
								set_structure_block(new_pos, wall_type_2)
							end
							local meta = minetest.get_meta(new_pos)
							meta:set_string("dont_replace_with_air", "true")
						end
					end
				end
			end
		-- make corner pillars:
		elseif edge_pillars then
            local start_y = room_corner_1.y+1
            if math.random() <= 0.7 and not minetest.registered_nodes[wall_type_1].groups.flammable and not minetest.registered_nodes[wall_type_2].groups.flammable then
                start_y = room_corner_1.y -- <- pillars can go one block deeper than normal in many cases if they aren't woody to spice up pools
            end
			for _, x in ipairs({room_corner_1.x+2, room_corner_2.x-2}) do
				for _2, z in ipairs({room_corner_1.z+2, room_corner_2.z-2}) do
					for y = start_y, room_corner_2.y-1 do
						local new_pos = {x=x, y=y, z=z}
						if y <= room_corner_1.y+1 and pillar_material_type ~= 3 or pillar_material_type == 1 then
							set_structure_block(new_pos, wall_type_1)
						elseif y >= room_corner_1.y+2 or pillar_material_type == 3 then
							set_structure_block(new_pos, wall_type_2)
						end
						local meta = minetest.get_meta(new_pos)
						meta:set_string("dont_replace_with_air", "true")
					end
				end
			end
		-- make door pillars:
		elseif door_pillars then
			local dirs = {
				{x_plus, "x", "z", room_corner_2, -1},
				{x_minus, "x", "z", room_corner_1, 1},
				{z_plus, "z", "x", room_corner_2, -1},
				{z_minus, "z", "x", room_corner_1, 1},
			}
			for _, dir in ipairs(dirs) do
				if dir[1] then
					local v_a = dir[2]
					local v_b = dir[3]
					local door_corner = dir[4]
					local reverse_door_dir = dir[5]
					local a = door_corner[v_a] + reverse_door_dir * 2
					for _, b in ipairs({pos[v_b]+4, pos[v_b]+7}) do
						for y = room_corner_1.y+1, room_corner_2.y-1 do
							local new_pos = {}
							new_pos[v_a] = a
							new_pos[v_b] = b
							new_pos.y = y
							if y == room_corner_1.y+1 then
								set_structure_block(new_pos, wall_type_1)
							elseif y >= room_corner_1.y+2 then
								set_structure_block(new_pos, wall_type_2)
							end
							local meta = minetest.get_meta(new_pos)
							meta:set_string("dont_replace_with_air", "true")
						end
					end
				end
			end
		end
	end
	-- make doors:
	local dirs = {
		{x_plus, "x", "z", 2, "x_plus"},
		{x_minus, "x", "z", 1, "x_minus"},
		{z_plus, "z", "x", 2, "z_plus"},
		{z_minus, "z", "x", 1, "z_minus"},
	}
	for _, params in ipairs(dirs) do
		local has_door = room_style["door_" .. params[5]]
		if params[1] and ((room_has_doors == 2 or room_has_doors == 1 and math.random() < 0.5) and has_door ~= false) or has_door == true then
			local new_block_positions = {}
			local both_room_corners = {room_corner_1, room_corner_2}
			for value_a = 5, 6 do
				new_block_positions[value_a] = {
					[params[2]] = both_room_corners[params[4]][params[2]],
					[params[3]] = pos[params[3]] + value_a,
					y           = room_corner_1.y+1
				}
			end
			place_doubledoor_based_on_materials(new_block_positions[5], new_block_positions[6], params[5],
												{floor_type=floor_type, roof_type=roof_type, wall_type_1=wall_type_1, wall_type_2=wall_type_2, pillar_type=pillar_type},
												false)
		end
	end
    -- make pool:
	local pool_chance = room_style.is_treasure_level and 0.5 or 1/3
	-- print("room style: " .. minetest.serialize(room_style))
    if (math.random() < pool_chance and (edge_pillars or pillar_room or not can_have_pillars) and room_style.pool ~= false) or room_style.pool == true then
        -- decide on what to fill pool with:
        local pool_content
        local emergency_pool_bassin
		local pool_content_metadata
		if room_style.pool_liquid then
			pool_content = room_style.pool_liquid -- only allowed for "default:river_water_source" or "randungeon:lava_source"
		elseif room_style.is_treasure_level then
			pool_content = "default:goldblock"
            emergency_pool_bassin = "default:silver_sandstone_block"
		elseif math.random() <= 1/30 then
			pool_content = get_random_pool_nature_type()
            emergency_pool_bassin = randungeon.nature_types[pool_content].pool_bassin or "default:silver_sandstone_block"
			pool_content_metadata = make_metadata_for_nature(room_corner_1, pool_content)
        elseif math.random() < 2/3 then
            pool_content = "default:river_water_source"
            emergency_pool_bassin = "default:silver_sandstone_block"
        else
            pool_content = "randungeon:lava_source"
            emergency_pool_bassin = "default:obsidianbrick"
        end
		-- enter pool content in randungeon.dungeons:
		room_data.pool_content = pool_content
        -- freeze if needed:
        local frozen_version = {
            ["default:river_water_source"] = "default:ice",
            ["randungeon:lava_source"] = "default:obsidian"
        }
        local actual_pool_content = pool_content
        if frozen then
            actual_pool_content = frozen_version[pool_content] or pool_content
        end
        -- find a good water resistent node as replacement for floor if floor isn't water resistant:
        local pool_bassin
        if not minetest.registered_nodes[floor_type].groups.flammable then
            pool_bassin = floor_type
        elseif not minetest.registered_nodes[wall_type_1].groups.flammable then
            pool_bassin = wall_type_1
        elseif not minetest.registered_nodes[wall_type_2].groups.flammable then
            pool_bassin = wall_type_2
        elseif not minetest.registered_nodes[roof_type].groups.flammable then
            pool_bassin = roof_type
        else
            pool_bassin = emergency_pool_bassin
        end
        -- decide if we want to place waterlillies:
        local water_lilies = false
        if ((actual_pool_content == "default:river_water_source" and math.random() < 2/3 or actual_pool_content == "default:ice" and math.random() < 1/5)
		    and room_style.water_lilies ~= false) or room_style.water_lilies == true then
            water_lilies = true
        end
        -- decide if we want the ice to stand for itself, with no snow on it:
        local no_snow_on_frozen_pool = false
        if actual_pool_content == "default:ice" and ((room_corner_2.x+2)-(room_corner_1.x-2)+1) * ((room_corner_2.z+2)-(room_corner_2.z-2)+1) > 20 then
            if math.random() < 1/2 then
                no_snow_on_frozen_pool = true -- if bigger than a 4x5 bassin we want to keep the surface slippery sometimes
            end
        end
		-- set no snow on pool if it is filled with nature, since we freeze those manually:
		if minetest.get_item_group(pool_content, "make_nature_block") >= 1 then
			no_snow_on_frozen_pool = true
		end
        -- actually build the pool:
        for x = room_corner_1.x+1, room_corner_2.x-1 do
            for z = room_corner_1.z+1, room_corner_2.z-1 do
                local new_pos = {x=x, y=room_corner_1.y, z=z}
                local pos_above = {x=x, y=room_corner_1.y+1, z=z}
                if minetest.get_meta(pos_above):get_string("dont_replace_with_air") ~= "true" then
                    -- care for bassin itself:
                    if x >= room_corner_1.x+2 and x <= room_corner_2.x-2 and z >= room_corner_1.z+2 and z <= room_corner_2.z-2 then
                        minetest.set_node(new_pos, {name=actual_pool_content})
						-- if stairs mod is present and we want to make a gold pool, switch between different gold blocks:
						if actual_pool_content == "default:goldblock" and minetest.get_modpath("stairs") then
							local rand = math.random()
							local param2 = math.random(0, 3)
							if rand < 1/3 then
								minetest.set_node(new_pos, {name="stairs:stair_inner_goldblock", param2=param2})
							elseif rand < 2/3 then
								minetest.set_node(new_pos, {name="stairs:stair_goldblock", param2=param2})
							else
								minetest.set_node(new_pos, {name="stairs:stair_outer_goldblock", param2=param2})
							end
						end
						-- give nature blocks their metadata:
						if minetest.get_item_group(actual_pool_content, "make_nature_block") >= 1 then
							local p
							for y = 1, randungeon.nature_types[actual_pool_content].pool_deph do
								p = table.copy(new_pos)
								p.y = new_pos.y + 1 - y
								minetest.set_node(p, {name="air"})
							end
							minetest.set_node(p, {name=actual_pool_content})
							minetest.get_meta(p):from_table(pool_content_metadata)
						end
                        -- set water lillies:
                        if water_lilies and math.random() < 1/4 then -- around 3 water lillies for smallest room variant with corner pillars
                            minetest.set_node(pos_above, {name="flowers:waterlily_waving", param2=math.random(0, 3)})
                            minetest.get_meta(pos_above):set_string("dont_replace_with_air", "true")
                        end
                        -- set snow if frozen (we don't care about water lilies with this):
                        if frozen and not no_snow_on_frozen_pool and math.random() < 1/4 then
                            minetest.set_node(pos_above, {name="default:snow"})
                            minetest.get_meta(pos_above):set_string("dont_replace_with_air", "true")
                        end
                    -- set snow around bassin if frozen:
                    elseif frozen and math.random() < 1/4 then
                        minetest.set_node(pos_above, {name="default:snow"})
                        minetest.get_meta(pos_above):set_string("dont_replace_with_air", "true")
                    end
                end
            end
        end
        -- make sure the pool bassin is made from a waterproof material:
        local pool_bassin_nodes = minetest.find_nodes_in_area(
            {x=room_corner_1.x+1, y=room_corner_1.y-1, z=room_corner_1.z+1}, {x=room_corner_2.x-1, y=room_corner_1.y, z=room_corner_2.z-1}, {floor_type}
        )
        for _, pool_bassin_node_pos in ipairs(pool_bassin_nodes) do
            if minetest.find_node_near(pool_bassin_node_pos, 1, {actual_pool_content}) then
                minetest.set_node(pool_bassin_node_pos, {name=pool_bassin})
            end
        end
		-- mark relevant nodes to ensure no staircase is built through them with fireproof material:
		for x = room_corner_1.x+1, room_corner_2.x-1 do
			for z = room_corner_1.z+1, room_corner_2.z-1 do
				for y = room_corner_1.y-1, room_corner_1.y do
					minetest.get_meta({x=x, y=y, z=z}):set_string("must_be_fireproof", "true")
					minetest.get_meta({x=x, y=y, z=z}):set_string("fireproof_alternative", pool_bassin)
				end
			end
		end
		-- evolve nature if pool is filled with nature:
		if minetest.get_item_group(actual_pool_content, "make_nature_block") >= 1 then
			for x = room_corner_1.x, room_corner_2.x do
				for y = room_corner_1.y-1, room_corner_2.y do
					for z = room_corner_1.z, room_corner_2.z do
						if minetest.get_node({x=x, y=y, z=z}).name == "randungeon:dungeon_air" then
							minetest.set_node({x=x, y=y, z=z}, {name="air"})
						end
					end
				end
			end
			make_nature_in_area(room_corner_1, room_corner_2)
			if frozen then
				freeze_area(room_corner_1, room_corner_2, false)
			end
		end
    end
	return true
end


return {
    make_room = make_room,
    make_room_style = make_room_style,
    make_unconnected_room_style = make_unconnected_room_style,
	get_solid_air_block_replacement = get_solid_air_block_replacement
}