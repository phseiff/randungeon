
--
-- Dependencies
--
local mod_path = minetest.get_modpath("randungeon")

-- Room Generation
local room_generation_functions = dofile(mod_path.."/room_generation.lua")
local make_room = room_generation_functions.make_room
local make_room_style = room_generation_functions.make_room_style
local make_unconnected_room_style = room_generation_functions.make_unconnected_room_style

-- Dungeon Map Generator
local generate_dungeon_map_functions = dofile(mod_path.."/make_dungeon_map.lua")
local generate_dungeon_map = generate_dungeon_map_functions.generate_dungeon_map
local tiles_are_directly_connected = generate_dungeon_map_functions.tiles_are_directly_connected

--
-- Make Treasure Level
--

local function make_treasure_level(dungeon_maps, materials, room_styles)
    local i = #dungeon_maps
    local room_style = room_styles[i]
    local m = materials[i]
    local width = #dungeon_maps[1]

    -- treasure pools & others:
    room_style.is_treasure_level = true
    room_style.frozen = false
    room_style.build_even_if_in_cave = true
    room_style.pinnacles_if_floating_in_cave = true
    -- bridge type:
    m.bridge_type = math.max(0, m.bridge_type - 1)
    if math.random() < 0.5 then
        m.bridge_type = math.max(0, m.bridge_type - 1)
    end
    -- pillar type:
    if room_style.door_pillars or room_style.inner_walls then
        local replacement_pillar_type
        local rand = math.random()
        if rand < 1/3 then
            replacement_pillar_type = {"can_have_pillars", false}
        elseif rand < 2/3 then
            replacement_pillar_type = {"pillar_room", true}
        else
            replacement_pillar_type = {"edge_pillars", true}
        end
        for x = 1, width do
            for z = 1, width do
                local relevant_tile = dungeon_maps[i][x][z]
                if math.random() < 3/5 then
                    relevant_tile.tile_specific_room_style = table.copy(room_style)
                    relevant_tile.tile_specific_room_style[replacement_pillar_type[1]] = replacement_pillar_type[2]
                    relevant_tile.tile_specific_room_style.door_pillars = false
                    relevant_tile.tile_specific_room_style.inner_walls = false
                end
            end
        end
    end
end

local function make_treasure_rooms(dungeon_pos, dungeon_maps, materials, room_styles, treasure_block)
    local i = #dungeon_maps
    local level_pos = table.copy(dungeon_pos)
    for _, map_level in ipairs(dungeon_maps) do
        level_pos.y = level_pos.y - map_level.top_deph
    end
    local width = #dungeon_maps[1]
    -- find all possible treasure rooms and their attached tiles:
    local potential_rooms_and_their_neighbors = {}
    for x = 1, width do
        for z = 1, width do
            local relevant_tile_coords = {{x, z}}
            for x2 = math.max(x-1, 1), math.min(x+1, width) do
                for z2 = math.max(z-1, 1), math.min(z+1, width) do
                    if tiles_are_directly_connected(dungeon_maps[i], x, z, x2, z2) then
                        table.insert(relevant_tile_coords, {x2, z2})
                    end
                end
            end
            table.insert(potential_rooms_and_their_neighbors, relevant_tile_coords)
        end
    end
    -- print("options for treasure room & its neighbors: " .. minetest.serialize(potential_rooms_and_their_neighbors))
    -- remove all of them that have upgoing staircases in them, if possible:
    local staircase_free_options = {}
    for _, option in ipairs(potential_rooms_and_their_neighbors) do
        local has_staircase = false
        for _, coords in ipairs(option) do
            if dungeon_maps[i][coords[1]][coords[2]].stair_position then
                has_staircase = true
                break
            end
        end
        if not has_staircase then
            table.insert(staircase_free_options, option)
        end
    end
    -- print("options that don't have a staircase: " .. minetest.serialize(staircase_free_options))
    -- remove all of them that overlap with caves, if possible:
    if #staircase_free_options == 0 then
        staircase_free_options = potential_rooms_and_their_neighbors
    end
    local cave_free_options = {}
    for _, option in ipairs(staircase_free_options) do
        local overlaps_with_caves = false
        for _, coords in ipairs(option) do
            local x, z = unpack(coords)
            local pos1 = {x=level_pos.x+(x-1)*10, y=level_pos.y, z=level_pos.z+(z-1)*10}
            if #minetest.find_nodes_in_area(pos1, {x=pos1.x+10, y=pos1.y+7, z=pos1.z+10}, {"air", "group:liquid"}) > 0 then
                overlaps_with_caves = true
                break
            end
        end
        if not overlaps_with_caves then
            table.insert(cave_free_options, option)
        end
    end
    -- print("options that don't overlap with caves: " .. minetest.serialize(cave_free_options))
    if #cave_free_options == 0 then
        cave_free_options = staircase_free_options
    end
    -- only keep the ones with a max amount of adjacent corridors:
    local max_tiles_in_treasure_building_complex = 0
    for _, option in ipairs(cave_free_options) do
        if #option > max_tiles_in_treasure_building_complex then
            max_tiles_in_treasure_building_complex = #option
        end
    end
    local max_sized_options = {}
    for _, option in ipairs(cave_free_options) do
        if #option == max_tiles_in_treasure_building_complex then
            table.insert(max_sized_options, option)
        end
    end
    -- print("max tile size of a treasure room complex: " .. tostring(max_tiles_in_treasure_building_complex))
    -- print("max sized treasure building complexes: " .. minetest.serialize(max_sized_options))
    local treasure_rooms = max_sized_options[math.random(1, #max_sized_options)]
    -- print("treasure building complex: " .. minetest.serialize(treasure_rooms))
    local options_which_blocks_we_make_golden = {
        {"floor_type"},
        {"floor_type", "wall_type_1"},
        {"wall_type_1", "wall_type_2"},
        {"wall_type_2", "roof_type"},
        {"floor_type", "roof_type"}
    }
    local golden_blocks = options_which_blocks_we_make_golden[math.random(1, #options_which_blocks_we_make_golden)]
    local treasure_foreroom_height = math.random(5, 6)
    local treasure_room_has_doors = math.random() < 0.4
    local treasure_room_has_pool = false
    local treasure_room_has_double_doors = math.random() < 0.5 and treasure_room_has_doors
    local side_rooms_have_lava_if_treasure_room_is_poolless = math.random() < 0.5
    local main_treasure_room
    for treasure_room_number, treasure_room in ipairs(treasure_rooms) do
        local x, z = unpack(treasure_room)
        dungeon_maps[i][x][z].tile_specific_materials = {}
        for _, golden_material in ipairs(golden_blocks) do
            dungeon_maps[i][x][z].tile_specific_materials[golden_material] = "default:goldblock"
        end
        dungeon_maps[i][x][z].has_room = true
        dungeon_maps[i][x][z].tile_specific_room_style = {
            ceiling_height=treasure_foreroom_height,
            dont_deviate_from_room_style=true,
            build_even_if_in_cave=true,
            can_have_pillars=true,
            pool=false,
            frozen=false,
        }
        if treasure_room_number == 1 then
            main_treasure_room = dungeon_maps[i][x][z]
            local possible_x_expand_dirs = {"expand_x_plus", "expand_x_minus"}
            local possible_z_expand_dirs = {"expand_z_plus", "expand_z_minus"}
            table.shuffle(possible_x_expand_dirs)
            table.shuffle(possible_z_expand_dirs)
            dungeon_maps[i][x][z].tile_specific_room_style.ceiling_height = 6
            dungeon_maps[i][x][z].tile_specific_room_style.edge_pillars = true
            dungeon_maps[i][x][z].tile_specific_room_style.room_center_treasure_block = treasure_block
            dungeon_maps[i][x][z].tile_specific_room_style[possible_x_expand_dirs[1]] = true
            dungeon_maps[i][x][z].tile_specific_room_style[possible_x_expand_dirs[2]] = false
            dungeon_maps[i][x][z].tile_specific_room_style[possible_z_expand_dirs[1]] = true
            dungeon_maps[i][x][z].tile_specific_room_style[possible_z_expand_dirs[2]] = false
            if treasure_room_has_doors then
                for _, has_door in ipairs({"door_x_plus", "door_x_minus", "door_z_plus", "door_z_minus"}) do
                    dungeon_maps[i][x][z].tile_specific_room_style[has_door] = true
                end
            end
            if math.random() < 0.6 then
                local rand = math.random()
                if rand < 0.3 then
                    dungeon_maps[i][x][z].tile_specific_room_style.pool = true
                    dungeon_maps[i][x][z].tile_specific_room_style.is_treasure_level = true
                elseif rand < 0.7 then
                    dungeon_maps[i][x][z].tile_specific_room_style.pool = true
                    dungeon_maps[i][x][z].tile_specific_room_style.pool_liquid = "default:water_source"
                    dungeon_maps[i][x][z].tile_specific_room_style.water_lilies = true
                else
                    dungeon_maps[i][x][z].tile_specific_room_style.pool = true
                    dungeon_maps[i][x][z].tile_specific_room_style.pool_liquid = "randungeon:lava_source"
                end
            end
        else
            dungeon_maps[i][x][z].tile_specific_room_style.room_has_doors = 2
            if side_rooms_have_lava_if_treasure_room_is_poolless
                and (not main_treasure_room.tile_specific_room_style.pool
                or main_treasure_room.tile_specific_room_style.pool_liquid == "default:water_source") then
                dungeon_maps[i][x][z].tile_specific_room_style.pool = true
                dungeon_maps[i][x][z].tile_specific_room_style.pool_liquid = "randungeon:lava_source"
            end
            if x == treasure_rooms[1][1] then
                if z < treasure_rooms[1][2] then
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_z_plus = true
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_z_minus = false
                    dungeon_maps[i][x][z].tile_specific_room_style.door_z_plus = treasure_room_has_double_doors
                    -- dungeon_maps[i][x][z].tile_specific_room_style.door_z_minus = true
                else
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_z_plus = false
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_z_minus = true
                    -- dungeon_maps[i][x][z].tile_specific_room_style.door_z_plus = true
                    dungeon_maps[i][x][z].tile_specific_room_style.door_z_minus = treasure_room_has_double_doors
                end
                dungeon_maps[i][x][z].tile_specific_room_style.expand_x_plus = false
                dungeon_maps[i][x][z].tile_specific_room_style.expand_x_minus = false
            elseif z == treasure_rooms[1][2] then
                if x < treasure_rooms[1][1] then
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_x_plus = true
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_x_minus = false
                    dungeon_maps[i][x][z].tile_specific_room_style.door_x_plus = treasure_room_has_double_doors
                    -- dungeon_maps[i][x][z].tile_specific_room_style.door_x_minus = true
                else
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_x_plus = false
                    dungeon_maps[i][x][z].tile_specific_room_style.expand_x_minus = true
                    -- dungeon_maps[i][x][z].tile_specific_room_style.door_x_plus = true
                    dungeon_maps[i][x][z].tile_specific_room_style.door_x_minus = treasure_room_has_double_doors
                end
                dungeon_maps[i][x][z].tile_specific_room_style.expand_z_plus = false
                dungeon_maps[i][x][z].tile_specific_room_style.expand_z_minus = false
            end
            dungeon_maps[i][x][z].tile_specific_room_style.pillar_room = true
        end
    end
end


return {
    make_treasure_level = make_treasure_level,
    make_treasure_rooms = make_treasure_rooms,
}