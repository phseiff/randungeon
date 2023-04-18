
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

randungeon.entity_levels = {
    air = 1
}
randungeon.entity_spawnblocks = {}
randungeon.entity_required_surroundings = {}
randungeon.entity_groups = {}

local BUFFER_SIZE = 10
local SPAWN_CHECK_INTERVAL = 10

local function fill_room_or_cave_with_entity_group(room, entity_group, room_entities_in_groups, max_entities, max_level)

    -- stop filling this room if group ends filling
    if entity_group.end_room_filling then
        return false, nil
    end

    -- fill in left-out information on the entity group;
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

    -- check basic conditions required for this group to fit into this room
    if (entity_group.acceptable_pool_contents == nil or contains(entity_group.acceptable_pool_contents, (room.pool_content or room.nature or room.type or "nil"))) 
    and (entity_group.acceptable_frozen_states == nil or contains(entity_group.acceptable_frozen_states, room.frozen))
    and entity_group.lowest_level <= room.level
    and (entity_group.acceptor == nil or entity_group.acceptor(room) == true)
    and not (entity_group.highest_level and room.level > entity_group.highest_level) then

        -- set basic variables to describe room capacity that we can decrease as we fill the room
        local max_group_entities = entity_group.max_entities_per_room
        local max_level_in_room = entity_group.max_total_level_per_room or max_level

        -- randomize how many entities of this group we'll try to fit into the room
        if math.random() < 0.5 then
            if entity_group.max_entities_per_room_std1 then
                max_group_entities = max_group_entities - math.random(0, entity_group.max_entities_per_room_std1)
            end
        else
            if entity_group.max_entities_per_room_std2 then
                max_group_entities = max_group_entities + math.random(0, entity_group.max_entities_per_room_std2)
            end
        end
        -- go through entities that we can choose for this room until we don't have any fitting ones left
        while #entity_group.entities > 0 and max_entities > 0 and max_level > 0 and #entity_group_entities < max_group_entities do
            local potential_entity_index = math.random(1, #entity_group.entities)
            local potential_entity = entity_group.entities[potential_entity_index]
            -- check if required surroundings for this entity are fulfilled
            local required_surroundings = randungeon.entity_required_surroundings[potential_entity]
            local required_surroundings_fulfilled = true
            if required_surroundings then
                if room.p1 then
                    required_surroundings_fulfilled = #minetest.find_nodes_in_area(room.p1, room.p2, required_surroundings) > 0
                elseif room.center_pos then
                    required_surroundings_fulfilled = #minetest.find_node_near(room.center_pos, room.radius+2, nodenames, required_surroundings)
                end
            end
            -- if entity is too powerful or too much or its surroundings are unfitting, remove it from the copy of the group we operate on for this room
            if randungeon.entity_levels[potential_entity] > math.min(max_level, max_level_in_room) or not required_surroundings_fulfilled then
                table.remove(entity_group.entities, potential_entity_index)
            else
                -- otherwise, add it
                table.insert(entity_group_entities, potential_entity)
                max_level = max_level - randungeon.entity_levels[potential_entity]
                max_level_in_room = max_level_in_room - randungeon.entity_levels[potential_entity]
                max_entities = max_entities - 1
            end
        end
    end
    table.insert(room_entities_in_groups, entity_group_entities)
    return max_entities, max_level
end

local function group_is_underpowered(room, entity_group)
    local strongest_non_op_entity_level = 0
    if entity_group.always_fitting == true then
        strongest_non_op_entity_level = room.level
    else
        for _, entity_name in ipairs(entity_group.entities) do
            if randungeon.entity_levels[entity_name] <= room.level then
                strongest_non_op_entity_level = math.max(strongest_non_op_entity_level, randungeon.entity_levels[entity_name])
            end
        end
    end
    return room.level - strongest_non_op_entity_level + 1
end


local function physically_fill_room_or_cave_with_entities(room, room_entities_in_groups, spawned_entities, actually_spawn)

    -- likely remove last group we added if it is very small, to avoid super cut-off groups
    if #room_entities_in_groups > 1 then
        if math.random() < 1 / #room_entities_in_groups[#room_entities_in_groups] then
            table.remove(room_entities_in_groups, #room_entities_in_groups)
        end
    end
    -- put all room entities into a single list
    local room_entities = {}
    for _, group in ipairs(room_entities_in_groups) do
        for _, entity_name in ipairs(group) do
            table.insert(room_entities, entity_name)
        end
    end
    -- physically place entities in room
    local positions_where_mobs_already_spawned = {}
    for _, entity_name in ipairs(room_entities) do
        if entity_name ~= "air" then
            -- get list of blocks the entity can spawn in
            local valid_spawnblocks
            if randungeon.entity_spawnblocks[entity_name] then
                valid_spawnblocks = randungeon.entity_spawnblocks[entity_name]
            else
                valid_spawnblocks = {"air", "randungeon:air_glowing"}
            end
            local pool_deph = 1
            if randungeon.nature_types[room.pool_content] then
                pool_deph = randungeon.nature_types[room.pool_content].pool_deph or 1
            end
            -- get list of positions that hold these blocks
            local valid_spawnpositions
            if room.p1 then
                valid_spawnpositions = minetest.find_nodes_in_area({x=room.p1.x, y=room.p1.y-pool_deph+1, z=room.p1.z}, room.p2, valid_spawnblocks)
            elseif room.center_pos then
                local p1 = {x=room.center_pos.x-room.radius, y=room.center_pos.y-room.radius, z=room.center_pos.z-room.radius}
                local p2 = {x=room.center_pos.x+room.radius, y=room.center_pos.y+room.radius, z=room.center_pos.z+room.radius}
                valid_spawnpositions = minetest.find_nodes_in_area(p1, p2, valid_spawnblocks)
                for i = #valid_spawnpositions, 1, -1 do
                    if vector.distance(room.center_pos, valid_spawnpositions[i]) > room.radius + 1 then
                        table.remove(valid_spawnpositions, i)
                    end
                end
            end
            -- remove every spawn position if mob doesn't fit there, would float, or adjust spawn position based on mob collissionbox
            for i = #valid_spawnpositions, 1, -1 do
                local spawnp = valid_spawnpositions[i]
                local node_under_is_walkable = minetest.registered_nodes[minetest.get_node({x=spawnp.x, y=spawnp.y-1, z=spawnp.z}).name].walkable
                if not node_under_is_walkable then
                    table.remove(valid_spawnpositions, i) -- <- remove bc entity would float
                elseif minetest.get_modpath("mobs") and not minetest.registered_items[entity_name] then
                    local modified_spawn_pos = mobs:can_spawn(spawnp, entity_name)
                    if not modified_spawn_pos then
                        table.remove(valid_spawnpositions, i) -- <- remove bc mobs_redo says this position isn't valid
                    else
                        -- modify spawn position so it doesn't suffocate if it has a weird collision box
                        local entity_definition = minetest.registered_entities[entity_name]
                        valid_spawnpositions[i].y = modified_spawn_pos.y + (entity_definition.collisionbox[2] * -1) - 0.4
                    end
                end
            end
            -- remove spawn positions that are already used, if there are other options:
            local valid_spawnpositions_with_no_doubles = table.copy(valid_spawnpositions)
            for i = #valid_spawnpositions_with_no_doubles, 1, -1 do
                local spawnp = valid_spawnpositions_with_no_doubles[i]
                local spawnp_already_used = contains(positions_where_mobs_already_spawned, minetest.pos_to_string(spawnp))
                if spawnp_already_used then
                    table.remove(valid_spawnpositions_with_no_doubles, i)
                end
            end
            if #valid_spawnpositions_with_no_doubles > 0 then
                valid_spawnpositions = valid_spawnpositions_with_no_doubles
            end
            -- remove spawn positions that don't have environment nodes in close-ish proximity, if there are other options:
            if randungeon.entity_required_surroundings[entity_name] then
                for _ = 1, 10 do
                    local i = math.random(1, #valid_spawnpositions)
                    if minetest.find_node_near(valid_spawnpositions[i], 2, randungeon.entity_required_surroundings[entity_name]) then
                        valid_spawnpositions = {valid_spawnpositions[i]}
                        break
                    end
                end
            end
            -- spawn entity at remaining spawn position, if applicable
            if #valid_spawnpositions == 0 then
                print("failed to find a valid spawn position for " .. entity_name .. "!")
            else
                local chosen_spawn_pos = valid_spawnpositions[math.random(1, #valid_spawnpositions)]
                table.insert(spawned_entities, entity_name)
                if actually_spawn then
                    if minetest.registered_entities[entity_name] then
                        minetest.add_entity(chosen_spawn_pos, entity_name)
                    elseif minetest.registered_items[entity_name] then
                        local item_obj = minetest.add_item(chosen_spawn_pos, entity_name)
                        item_obj:get_luaentity().immortal_item = true
                        -- set this so other mods can use it as an indicator that the item was set to not expire
                        -- needs to be implemented by other mods, of course
                    end
                end
                -- remember that we already spawned a mob here
                table.insert(positions_where_mobs_already_spawned, minetest.pos_to_string(chosen_spawn_pos))
            end
        end
    end
end

local function spawn_entities(p1, p2, dungeon_data, actually_spawn)
    local spawned_entities = {}
    if actually_spawn == nil then -- <- if false the function will just return a list of what it would have spawned otherwise
        actually_spawn = true
    end
    for y = p1.y, p2.y do
        -- fill caves
        if dungeon_data.bubble_caves[y] then
            for _, cave in ipairs(dungeon_data.bubble_caves[y]) do
                local entity_groups = table.copy(randungeon.entity_groups)
                local cave_tiles = math.pi * cave.radius^2
                local max_entities = cave_tiles / (5^2)
                local max_level = math.floor(max_entities * cave.level)
                local cave_entities_in_groups = {}
                while #entity_groups > 0 do
                    local i = math.random(1, #entity_groups)

                    -- find out if group is unfit for caves in general
                    local caves_or_rooms = entity_groups[i].caves_or_rooms
                    local unfit_for_caves = false
                    if caves_or_rooms ~= "both" and caves_or_rooms ~= "caves" then
                        unfit_for_caves = true
                    end
                    if unfit_for_caves == false then
                        print("cave: " .. minetest.serialize(cave))
                    else
                        print("unfit to bear sheeps: " .. minetest.serialize(cave))
                    end

                    -- find out if group is underpowered
                    local group_is_underpowered = group_is_underpowered(cave, entity_groups[i])

                    -- decide which entities from which group will fill the cave
                    if math.random() <= 1 / group_is_underpowered and not unfit_for_caves then
                        local entity_group = table.remove(entity_groups, i)
                        local max_entities, max_level = fill_room_or_cave_with_entity_group(cave, entity_group, cave_entities_in_groups, max_entities, max_level)
                        if max_entities == false then
                            break
                        end
                    elseif unfit_for_caves then
                        table.remove(entity_groups, i)
                    end
                end
                -- physically fill cave with the entities
                print(minetest.serialize(cave_entities_in_groups))
                physically_fill_room_or_cave_with_entities(cave, cave_entities_in_groups, spawned_entities, actually_spawn)
            end
        end
        -- fill rooms
        if dungeon_data.rooms[y] then
            for _, room in ipairs(dungeon_data.rooms[y]) do
                local entity_groups = table.copy(randungeon.entity_groups)
                local room_tiles_min = 36
                local room_tiles_real = (room.p2.x-room.p1.x-1) * (room.p2.z-room.p1.z-1)
                local max_entities = math.floor(room_tiles_real / room_tiles_min * 5 * (1 + 0.5 * math.random()))
                local max_level = math.floor(room_tiles_real / room_tiles_min * 5 * room.level)
                local room_entities_in_groups = {}
                while #entity_groups > 0 do
                    local i = math.random(1, #entity_groups)

                    -- find out if group is unfit for rooms in general
                    local caves_or_rooms = entity_groups[i].caves_or_rooms
                    local unfit_for_rooms = false
                    if caves_or_rooms ~= nil and caves_or_rooms ~= "both" and caves_or_rooms ~= "rooms" then
                        unfit_for_rooms = true
                    end

                    -- find out if group is underpowered
                    local group_is_underpowered = group_is_underpowered(room, entity_groups[i])

                    -- decide which entities from which group will fill the room
                    if math.random() <= 1 / group_is_underpowered and not unfit_for_rooms then
                        local entity_group = table.remove(entity_groups, i)
                        local max_entities, max_level = fill_room_or_cave_with_entity_group(room, entity_group, room_entities_in_groups, max_entities, max_level)
                        if max_entities == false then
                            break
                        end
                    elseif unfit_for_rooms then
                        table.remove(entity_groups, i)
                    end
                end
                -- physically fill room with the entities
                physically_fill_room_or_cave_with_entities(room, room_entities_in_groups, spawned_entities, actually_spawn)
            end
        end
    end
    -- save dungeon data
	local randungeon_dungeons_string = minetest.serialize(randungeon.dungeons)
	randungeon.storage:set_string("dungeons", randungeon_dungeons_string)
    -- return list of spawned entities
    return spawned_entities
end

randungeon.spawn_entities = spawn_entities

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
    if #randungeon.entity_groups == 0 then
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
