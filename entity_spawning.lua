
-- Helper Functions For Block Comparisons
local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number
local get_solid_air_block_replacement = helper_functions.get_solid_air_block_replacement

--
-- Functions to spawn entities in dungeons when the player enters new areas
--

randungeon.entity_levels = {}
randungeon.entity_spawnblocks = {}
randungeon.entity_groups = {
    {
        always_fitting = true,
        end_room_filling = true
    }
}

local BUFFER_SIZE = 10
local SPAWN_CHECK_INTERVAL = 10

local function spawn_entities(p1, p2, dungeon_data)
    for y = p1.y, p2.y do
        if dungeon_data.rooms[y] then
            for _, room in ipairs(dungeon_data.rooms[y]) do
                local entity_groups = table.copy(randungeon.entity_groups)
                local room_tiles_min = 36
                local room_tiles_real = (room.p2.x-room.p1.x-1) * (room.p2.z-room.p1.z-1)
                --print("room_tiles_real " .. tostring(room_tiles_real))
                local max_entities = math.floor(room_tiles_real / room_tiles_min * 5 * (1 + 0.5 * math.random()))
                local max_level = math.floor(room_tiles_real / room_tiles_min * 5 * room.level)
                local room_entities = {}
                local room_entities_in_groups = {}
                while #entity_groups > 0 do
                    local i = math.random(1, #entity_groups)
                    local strongest_non_op_entity_level = 0
                    if entity_groups[i].always_fitting == true then
                        strongest_non_op_entity_level = room.level
                    else
                        for _, entity_name in ipairs(entity_groups[i].entities) do
                            if randungeon.entity_levels[entity_name] <= room.level then
                                strongest_non_op_entity_level = math.max(strongest_non_op_entity_level, randungeon.entity_levels[entity_name])
                            end
                        end
                    end
                    local group_is_underpowered = room.level - strongest_non_op_entity_level + 1

                    if math.random() <= 1 / group_is_underpowered then
                        local entity_group = table.remove(entity_groups, i)
                        if entity_group.end_room_filling then
                            break
                        end

                        -- fill in left-out information on the entity group; end if we found the air group
                        if entity_group.lowest_level == nil then
                            entity_group.lowest_level = 1/0
                            if #entity_group.entities == 0 then
                                entity_group.lowest_level = 1
                            else
                                for _, entity_name in ipairs(entity_group.entities) do
                                    entity_group.lowest_level = math.min(entity_group.lowest_level, randungeon.entity_levels[entity_name])
                                end
                            end
                        end
                        local entity_group_entities = {}

                        if (entity_group.acceptable_pool_contents == nil or contains(entity_group.acceptable_pool_contents, (room.pool_content or "nil"))) 
                        and (entity_group.acceptable_frozen_states == nil or contains(entity_group.acceptable_frozen_states, room.frozen))
                        and entity_group.lowest_level <= room.level
                        and (entity_group.acceptor == nil or entity_group.acceptor(room) == true) then
                                local max_group_entities = entity_group.max_entities_per_room
                                if math.random() < 0.5 then
                                    if entity_group.max_entities_per_room_std1 then
                                        max_group_entities = max_group_entities - math.random(0, entity_group.max_entities_per_room_std1)
                                    end
                                else
                                    if entity_group.max_entities_per_room_std2 then
                                        max_group_entities = max_group_entities + math.random(0, entity_group.max_entities_per_room_std2)
                                    end
                                end
                                while #entity_group.entities > 0 and max_entities > 0 and max_level > 0 and #entity_group_entities < max_group_entities do
                                    local potential_entity_index = math.random(1, #entity_group.entities)
                                    local potential_entity = entity_group.entities[potential_entity_index]
                                    if randungeon.entity_levels[potential_entity] > max_level then
                                        table.remove(entity_group.entities, potential_entity_index)
                                    else
                                        table.insert(entity_group_entities, potential_entity)
                                        max_level = max_level - randungeon.entity_levels[potential_entity]
                                        max_entities = max_entities - 1
                                    end
                                end
                        end
                        table.insert(room_entities_in_groups, entity_group_entities)
                    end
                    if #room_entities_in_groups > 1 then
                        if math.random() < 1 / #room_entities_in_groups[#room_entities_in_groups] then
                            table.remove(room_entities_in_groups, #room_entities_in_groups)
                        end
                    end
                    for _, group in ipairs(room_entities_in_groups) do
                        for _, entity_name in ipairs(group) do
                            table.insert(room_entities, entity_name)
                        end
                    end
                    --print(dump(room))
                    --print(dump(room_entities))
                    for _, entity_name in ipairs(room_entities) do
                        local valid_spawnblocks
                        if minetest.registered_entities[entity_name] then
                            valid_spawnblocks = randungeon.entity_spawnblocks[entity_name]
                        elseif minetest.registered_items[entity_name] then
                            valid_spawnblocks = {"air", "randungeon:air_glowing"}
                        end
                        local pool_deph = 1
                        if randungeon.nature_types[room.pool_content] then
                            pool_deph = randungeon.nature_types[room.pool_content].pool_deph or 1
                        end
                        local valid_spawnpositions = minetest.find_nodes_in_area({x=room.p1.x, y=room.p1.y-pool_deph+1, z=room.p1.z}, room.p2, valid_spawnblocks)
                        for i = #valid_spawnpositions, 1, -1 do
                            local spawnp = valid_spawnpositions[i]
                            local node_under_is_walkable = minetest.registered_nodes[minetest.get_node({x=spawnp.x, y=spawnp.y-1, z=spawnp.z}).name].walkable
                            if node_under_is_walkable == true then
                                table.remove(valid_spawnpositions, i)
                            end
                        end
                        if #valid_spawnpositions == 0 then
                            print("failed to find a valid spawn position for " .. entity_name .. "!")
                        else
                            local chosen_spawn_pos = valid_spawnpositions[math.random(1, #valid_spawnpositions)]
                            if minetest.registered_entities[entity_name] then
                                minetest.add_entity(chosen_spawn_pos, entity_name)
                            elseif minetest.registered_items[entity_name] then
                                minetest.add_item(chosen_spawn_pos, entity_name)
                            end
                        end
                    end
                    print("---")
                end
            end
        end
    end
    -- save dungeon data
	local randungeon_dungeons_string = minetest.serialize(randungeon.dungeons)
	randungeon.storage:set_string("dungeons", randungeon_dungeons_string)
end

local function spawn_entities_if_necessary(player)
    local pos = player:get_pos()
    pos.y = math.floor(pos.y)
    for _, dungeon_data in pairs(randungeon.dungeons) do
        if dungeon_data.p1.x <= pos.x and dungeon_data.p2.x >= pos.x and dungeon_data.p1.z <= pos.z and dungeon_data.p2.z >= pos.z
        and pos.y < dungeon_data.lowest_explored_y and pos.y >= dungeon_data.p1.y then
            local p1 = {x=dungeon_data.p1.x, y=pos.y-BUFFER_SIZE, z=dungeon_data.p1.z}
            local p2 = {x=dungeon_data.p2.x, y=dungeon_data.lowest_explored_y-BUFFER_SIZE-1, z=dungeon_data.p2.z}
            dungeon_data.lowest_explored_y = pos.y
            spawn_entities(p1, p2, dungeon_data)
            return -- assumes that no two dungeons can overlap
        end
    end
end

local spawn_tick = 0
minetest.register_globalstep(function(dtime)
    if #randungeon.entity_groups <= 1 then
        return
    end
    spawn_tick = spawn_tick + dtime
    if spawn_tick >= SPAWN_CHECK_INTERVAL then
        spawn_tick = 0
        for _, player in ipairs(minetest.get_connected_players()) do
            spawn_entities_if_necessary(player)
        end
    end
end)
