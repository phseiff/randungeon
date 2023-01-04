-- Helper Functions For Block Comparisons
local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number

--
-- Function for generating a Map of the Dungeon
--

local function tiles_are_directly_connected(map, x, z, x2, z2)
	if x == x2 and z - 1 == z2 and map[x][z].z_minus and map[x2][z2].z_plus then
		return true
	elseif x == x2 and z + 1 == z2 and map[x][z].z_plus and map[x2][z2].z_minus then
		return true
	elseif z == z2 and x - 1 == x2 and map[x][z].x_minus and map[x2][z2].x_plus then
		return true
	elseif z == z2 and x + 1 == x2 and map[x][z].x_plus and map[x2][z2].x_minus then
		return true
	else
		return false
	end
end

local function generate_dungeon_map(width, rim_sealed, level_above)
	local x, z
	local map = {}
	for x = 1, width do
		local new_row = {}
		for z = 1, width do
			table.insert(new_row, {})
		end
		table.insert(map, new_row)
	end
	if rim_sealed == nil then
		rim_sealed = true
	end
	local undefined_fields = {}
	for x = 1, width do
		for z = 1, width do
			table.insert(undefined_fields, {x, z})
		end
	end
	while #undefined_fields > 0 do
		x, z = unpack(table.remove(undefined_fields, math.random(1, #undefined_fields)))
		-- note tile requirements based on nighbor tiles
		local requirements = {}
		if x > 1 and map[x-1][z] ~= {} then
			requirements.x_minus = map[x-1][z].x_plus
		end
		if x < width and map[x+1][z] ~= {} then
			requirements.x_plus = map[x+1][z].x_minus
		end
		if z > 1 and map[x][z-1] ~= {} then
			requirements.z_minus = map[x][z-1].z_plus
		end
		if z < width and map[x][z+1] ~= {} then
			requirements.z_plus = map[x][z+1].z_minus
		end
		-- if wanted, note tile requirements based on rim of the dungeon
		if rim_sealed then
			if x == 1 then
				requirements.x_minus = false
			end
			if x == width then
				requirements.x_plus = false
			end
			if z == 1 then
				requirements.z_minus = false
			end
			if z == width then
				requirements.z_plus = false
			end
		end
		local tile = {}
		
		-- modify nighbor tiles and choose directly if we'd have to make a dead end otherwise
		if (
			(requirements.x_plus == true and requirements.x_minus==false and requirements.z_plus==false and requirements.z_minus==false)
			or (requirements.x_minus == true and requirements.x_plus==false and requirements.z_plus==false and requirements.z_minus==false)
			or (requirements.z_plus == true and requirements.x_minus==false and requirements.x_plus==false and requirements.z_minus==false)
			or (requirements.z_minus == true and requirements.x_minus==false and requirements.z_plus==false and requirements.x_plus==false)
		) then
			local different_dirs = {
				-- opposite dir and then the two ortogonal ones and x- and z-offset of index dir function to determine if index dir out of bounds:
				x_plus = {"x_minus", "z_minus", "z_plus", 1,0, function(x, z) return x == width end},
				x_minus = {"x_plus", "z_minus", "z_plus", -1,0, function(x, z) return x == 1 end},
				z_plus = {"z_minus", "x_minus", "x_plus", 0,1, function(x, z) return z == width end},
				z_minus = {"z_plus", "x_minus", "x_plus", 0,-1, function(x, z) return z == 1 end}
			}
			local dir_options
			local dir_we_already_need_in
			for i, v in pairs(different_dirs) do
				if requirements[i] then
					dir_options = v
					dir_we_already_need_in = i
				end
			end
			if not different_dirs[dir_options[1]][6](x, z) then
				map[x+different_dirs[dir_options[1]][4]][z+different_dirs[dir_options[1]][5]][different_dirs[dir_options[1]]] = true
				requirements[dir_options[1]] = true
			elseif different_dirs[dir_options[3]][6](x, z) then
				map[x+different_dirs[dir_options[2]][4]][z+different_dirs[dir_options[2]][5]][different_dirs[dir_options[2]]] = true
				requirements[dir_options[2]] = true
			elseif different_dirs[dir_options[2]][6](x, z) then
				map[x+different_dirs[dir_options[3]][4]][z+different_dirs[dir_options[3]][5]][different_dirs[dir_options[3]]] = true
				requirements[dir_options[3]] = true
			else
				local r = math.random(2, 3)
				map[x+different_dirs[dir_options[r]][4]][z+different_dirs[dir_options[r]][5]][different_dirs[dir_options[r]]] = true
				requirements[dir_options[r]] = true
			end
		end
			
		-- randomly (weighted randomness) choose a fitting dungeon tile otherwise
		local tile_works = false
		while tile_works == false do
			local random_number = math.random()
			
			if random_number < 0.66 then
				-- I-kreuzung
				local random_number_2 = math.random()
				if random_number_2 < 0.5 then
					tile = {x_plus=true, x_minus=true, z_plus=false, z_minus=false}
				else
					tile = {x_plus=false, x_minus=false, z_plus=true, z_minus=true}
				end
				
			elseif random_number < 0.83 then
				-- L-kreuzung
				local random_number_2 = math.random()
				if random_number_2 < 0.25 then
					tile = {x_plus=false, x_minus=true, z_plus=true, z_minus=false}
				elseif random_number_2 < 0.50 then
					tile = {x_plus=true, x_minus=false, z_plus=true, z_minus=false}
				elseif random_number_2 < 0.75 then
					tile = {x_plus=false, x_minus=true, z_plus=false, z_minus=true}
				else
					tile = {x_plus=true, x_minus=false, z_plus=false, z_minus=true}
				end
				
			elseif random_number < 0.95 then
				-- T-kreuzung
				local random_number_2 = math.random()
				if random_number_2 < 0.25 then
					tile = {x_plus=false, x_minus=true, z_plus=true, z_minus=true}
				elseif random_number_2 < 0.50 then
					tile = {x_plus=true, x_minus=false, z_plus=true, z_minus=true}
				elseif random_number_2 < 0.75 then
					tile = {x_plus=true, x_minus=true, z_plus=false, z_minus=true}
				else
					tile = {x_plus=true, x_minus=true, z_plus=true, z_minus=false}
				end
				
			elseif random_number < 0.999 then
				-- +-kreuzung
				tile = {x_plus=true, x_minus=true, z_plus=true, z_minus=true}
			else
				-- ultra rare case to make sure we don't get hung up here
				tile = {x_plus=false, x_minus=false, z_plus=false, z_minus=false, empty_spot=true}
			end
			
			-- make sure we are only happy with the tile we made if it works
			tile_works = true
			for i, v in pairs(requirements) do
				if tile[i] ~= v then
					tile_works = false
				end
			end
		end
		map[x][z] = tile
	end
	-- divert tiles into groups, each of whom is one coherently accessible area
	local dungeon_groups = {}
	local free_tiles = {}
	for x = 1, width do
		for z = 1, width do
			if not (map[x][z].x_minus==false and map[x][z].x_plus==false and map[x][z].z_minus==false and map[x][z].z_plus==false) then
				table.insert(free_tiles, {x, z})
			end
		end
	end
	local function contains(table, value)
		for i=1,#table do
			if table[i][1] == value[1] and table[i][2] == value[2] then 
				return true
			end
		end
		return false
	end
	local function remove_from_array(array, value)
		for i, v in ipairs(array) do
			if v[1] == value[1] and v[2] == value[2] then
				table.remove(array, i)
				return
			end
		end
	end
	while #free_tiles > 0 do
		local new_group = {}
		local unchecked_tiles = {table.remove(free_tiles, 1)} -- tiles of the new group whose nighbors we haven't checked yet
		while #unchecked_tiles > 0 do
			local unchecked_tile = table.remove(unchecked_tiles, 1)
			table.insert(new_group, unchecked_tile)
			x, z = unpack(unchecked_tile)
			if x > 1 and map[x][z].x_minus then
				if map[x-1][z].x_plus then
					if not contains(new_group, {x-1, z}) and not contains(unchecked_tiles, {x-1, z}) then
						table.insert(unchecked_tiles, {x-1, z})
						remove_from_array(free_tiles, {x-1, z})
					end
				else
					map[x][z].stair_position = "x_minus"   -- we also check for the special case of dead ends and make them staircases here
					map[x][z].stair_orientation = table.remove({"z_minus", "z_plus"}, math.random(1, 2))
					map[x][z].is_dead_end = true
				end
			end
			if x < width and map[x][z].x_plus then
				if map[x+1][z].x_minus then
					if not contains(new_group, {x+1, z}) and not contains(unchecked_tiles, {x+1, z}) then
						table.insert(unchecked_tiles, {x+1, z})
						remove_from_array(free_tiles, {x+1, z})
					end
				else
					map[x][z].stair_position = "x_plus"
					map[x][z].stair_orientation = table.remove({"z_minus", "z_plus"}, math.random(1, 2))
					map[x][z].is_dead_end = true
				end
			end
			if z > 1 and map[x][z].z_minus then
				if map[x][z-1].z_plus then
					if not contains(new_group, {x, z-1}) and not contains(unchecked_tiles, {x, z-1}) then
						table.insert(unchecked_tiles, {x, z-1})
						remove_from_array(free_tiles, {x, z-1})
					end
				else
					map[x][z].stair_position = "z_minus"
					map[x][z].stair_orientation = table.remove({"x_minus", "x_plus"}, math.random(1, 2))
					map[x][z].is_dead_end = true
				end
			end
			if z < width and map[x][z].z_plus then
				if map[x][z+1].z_minus then
					if not contains(new_group, {x, z+1}) and not contains(unchecked_tiles, {x, z+1}) then
						table.insert(unchecked_tiles, {x, z+1})
						remove_from_array(free_tiles, {x, z+1})
					end
				else
					map[x][z].stair_position = "z_plus"
					map[x][z].stair_orientation = table.remove({"x_minus", "x_plus"}, math.random(1, 2))
					map[x][z].is_dead_end = true
				end
			end
		end
		table.insert(dungeon_groups, new_group)
	end
	-- remove tiles from groups if we can't give them stairs bc of empty tiles above them
	if level_above then
		for _, group in ipairs(dungeon_groups) do
			for i = #group, 1, -1 do
				local x, z = unpack(group[i])
				if level_above[x][z].empty_spot then
					table.remove(group, i)
				end
			end
		end
	end
	-- tag 1-2 tiles per group with having stairs
	for _, group in ipairs(dungeon_groups) do
		if #group > 1 then
			local i1 = math.random(1, #group)
			local i2 = math.random(1, #group)
			while i2 == i1 do
				i2 = math.random(1, #group)
			end
			local stair_tiles
			if math.random() < 0.5 then
				stair_tiles = {i1, i2}
			else
				stair_tiles = {i1, i2}
			end
			for _, i in ipairs(stair_tiles) do
				x, z = unpack(group[i])
				local stair_tile = map[x][z]
				local stair_tile_dirs = {}
				for _, dir_name in ipairs({"x_minus", "x_plus", "z_minus", "z_plus"}) do
					if stair_tile[dir_name] then
						table.insert(stair_tile_dirs, dir_name)
					end
				end
				local stair_position = stair_tile_dirs[math.random(1, #stair_tile_dirs)]
				local stair_orientation
				if stair_position:sub(1, 1) == "x" then
					local potentatial_stair_orientations = {"z_plus", "z_minus"}
					stair_orientation = potentatial_stair_orientations[math.random(1, 2)]
				else
					local potentatial_stair_orientations = {"x_plus", "x_minus"}
					stair_orientation = potentatial_stair_orientations[math.random(1, 2)]
				end
				if not stair_tile.stair_position then
					stair_tile.stair_position = stair_position
					stair_tile.stair_orientation = stair_orientation
				end
			end
		end
	end
    -- mark all tiles as having pillars
    for x = 1, width do
        for z = 1, width do
            if map[x][z].empty_spot then
                map[x][z].has_pillar = false
            else
                map[x][z].has_pillar = true
            end
        end
    end
    -- mark all tiles of level above as not needing pillars that don't need them
    if level_above then
        for x = 1, width do
            for z = 1, width do
                if map[x][z].empty_spot then
                    level_above[x][z].has_pillar = false
                end
            end
        end
    end
	-- set rooms
	for x = 1, width do
		for z = 1, width do
			if map[x][z].empty_spot or map[x][z].stair_position or level_above and level_above[x][z].has_room then
				map[x][z].has_room = false
			end
		end
	end
	local room_number = 0
	while room_number < width * width / 10 do
		local possible_rooms = {}
		for x = 1, width do
			for z = 1, width do
				if map[x][z].has_room == nil then
					table.insert(possible_rooms, {x, z})
				end
			end
		end
		if #possible_rooms == 0 then
			break
		end
		local x, z = unpack(table.remove(possible_rooms, math.random(1, #possible_rooms)))
		map[x][z].has_room = true
		room_number = room_number + 1
		local dirs = {
			{1, "x_plus", "x_minus", -1, 0},
			{1, "x_minus", "x_plus", 1, width},
			{2, "z_plus", "z_minus", -1, 0},
			{2, "z_minus", "z_plus", 1, width},
		}
		for _, dir in ipairs(dirs) do
			local dir_var, dir_name_2, dir_name, dir_step, max_dir_var = unpack(dir)
			local pos_test = {x, z}
			repeat
				if not map[pos_test[1]][pos_test[2]][dir_name] then
					break
				end
				pos_test[dir_var] = pos_test[dir_var] + dir_step
				if not map[pos_test[1]][pos_test[2]][dir_name_2] then
					break
				end
				map[pos_test[1]][pos_test[2]].has_room = false
			until pos_test[dir_var] == max_dir_var
		end
	end
    -- return generated map
	return map
end



return {
    generate_dungeon_map = generate_dungeon_map,
	tiles_are_directly_connected = tiles_are_directly_connected,
}