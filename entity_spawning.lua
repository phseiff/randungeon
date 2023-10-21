
-- Helper Functions For Block Comparisons
local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number
local get_solid_air_block_replacement = helper_functions.get_solid_air_block_replacement

--
-- Introduce a privilege that gives special dev rights/attrs
--

minetest.register_privilege("randungeon_dev", {
	description = "Allows breathing in solid blocks & using dev commands",
	give_to_singleplayer = false,
	give_to_admin = false,
})


--
-- Functions to spawn entities in dungeons when the player enters new areas
--

-- function to override the code that selects mobs for a room
-- if defined, it should take the room/cave data and return a list of monster groups
randungeon.get_entities_for_room = nil

randungeon.entity_levels = {
    air = 1
}
randungeon.entity_spawnblocks = {}
randungeon.cave_entity_spawnblocks = {}
randungeon.entity_required_surroundings = {}
randungeon.entity_can_spawn_in_air = {}
randungeon.entity_groups = {}

randungeon.max_level_of_group_underpowerdness = 4
randungeon.max_entities_per_cave = 13

local BUFFER_SIZE = 10
local SPAWN_CHECK_INTERVAL = 10

randungeon.match_cave_type_and_nature = function(type, nature)
    return tostring(type) .. " " .. tostring(nature)
end

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
    local room_content_descriptors_to_match
    if room.center_pos then
        room_content_descriptors_to_match = {room.nature, room.type, randungeon.match_cave_type_and_nature(room.type, room.nature)}
    else
        room_content_descriptors_to_match = {room.pool_content}
    end
    if (entity_group.acceptable_pool_contents == nil or intersects(entity_group.acceptable_pool_contents, room_content_descriptors_to_match))
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
                    required_surroundings_fulfilled = minetest.find_node_near(room.center_pos, room.radius+2, required_surroundings) ~= nil
                end
            end
            -- if entity is too powerful or too much or its surroundings are unfitting, remove it from the copy of the group we operate on for this room
            if (randungeon.entity_levels[potential_entity] > math.min(max_level, max_level_in_room)) or not required_surroundings_fulfilled then
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
            if randungeon.entity_levels[entity_name] == nil then
                print(entity_name .. " misses level specification.")
            end
            if randungeon.entity_levels[entity_name] <= room.level then
                strongest_non_op_entity_level = math.max(strongest_non_op_entity_level, randungeon.entity_levels[entity_name])
            end
        end
    end
    return math.max(randungeon.max_level_of_group_underpowerdness, room.level - strongest_non_op_entity_level + 1)
end


local function physically_fill_room_or_cave_with_entities(room, room_entities_in_groups, spawned_entities, actually_spawn)

    -- likely remove last group we added if it is very small, to avoid super cut-off groups
    if #room_entities_in_groups > 1 and not randungeon.get_entities_for_room then
        if math.random() < 1 / #room_entities_in_groups[#room_entities_in_groups] then
            table.remove(room_entities_in_groups, #room_entities_in_groups)
        end
    end
    -- save that we spawned these entities in this group
    if actually_spawn then
        room.spawned_entities = room_entities_in_groups
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
            if room.center_pos and randungeon.cave_entity_spawnblocks[entity_name] then 
                valid_spawnblocks = randungeon.cave_entity_spawnblocks[entity_name] -- if in a cave, use randungeon.cave_entity_spawnblocks
            elseif randungeon.entity_spawnblocks[entity_name] then
                valid_spawnblocks = randungeon.entity_spawnblocks[entity_name] -- else, use randungeon.entity_spawnblocks
            elseif minetest.registered_items[entity_name] then
                valid_spawnblocks = {"air", "randungeon:air_glowing", "group:water"}
                if minetest.get_item_group(entity_name, "flammable") == 0 then
                    table.insert(valid_spawnblocks, "group:lava")
                end
            else
                valid_spawnblocks = {"air", "randungeon:air_glowing"} -- else, use defaults
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
                local p1 = {x=room.center_pos.x-room.radius, y=room.cave_floor-1 or (room.center_pos.y-room.radius), z=room.center_pos.z-room.radius}
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
                local ndef_under = minetest.registered_nodes[minetest.get_node({x=spawnp.x, y=spawnp.y-1, z=spawnp.z}).name]
                local node_under_is_walkable = ndef_under and ndef_under.walkable
                local removed_due_to_missing_los = false
                if room.center_pos then
                    -- don't let the entity spawn in a bubble cave if there is natural stone or corridors separating it from the cave's center
                    -- trees, leaves, dirt and other vegetation notably does not count as separation! and glass doesn't either, for funsies
                    local p = table.copy(room.center_pos)
                    p.y = p.y + 1
                    local ray = Raycast(p, spawnp, false, false)
                    for pointed_thing in ray do
                        local nname = minetest.get_node(pointed_thing.under)
                        if contains(randungeon.available_materials, nname) then
                            table.remove(valid_spawnpositions, i)
                            removed_due_to_missing_los = true
                        end
                    end
                end
                if removed_due_to_missing_los then
                    do end
                elseif not node_under_is_walkable and not randungeon.entity_can_spawn_in_air[entity_name] then
                    table.remove(valid_spawnpositions, i) -- <- remove bc entity would float
                elseif minetest.get_modpath("randungeon_monsters") and not minetest.registered_items[entity_name] then
                    local modified_spawn_pos = randungeon_monsters.fix_spawn_position(spawnp, entity_name)
                    if not modified_spawn_pos then
                        table.remove(valid_spawnpositions, i) -- <- remove bc randungeon_monsters says this position isn't valid
                    else
                        valid_spawnpositions[i] = modified_spawn_pos
                    end
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
            if randungeon.entity_required_surroundings[entity_name] and #valid_spawnpositions > 0 then
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
                        minetest.add_entity(chosen_spawn_pos, entity_name, minetest.serialize({naturally_spawned=true}))
                        -- remember that we already spawned a mob here
                        table.insert(positions_where_mobs_already_spawned, minetest.pos_to_string(chosen_spawn_pos))
                    elseif minetest.registered_items[entity_name] then
                        local item_obj = minetest.add_item(chosen_spawn_pos, entity_name)
                        item_obj:get_luaentity().immortal_item = true
                        -- set this so other mods can use it as an indicator that the item was set to not expire
                        -- needs to be implemented by other mods, of course
                    end
                end
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
                local cave_entities_in_groups = {}
                if randungeon.get_entities_for_room then
                    cave_entities_in_groups = randungeon.get_entities_for_room(cave)
                else
                    local entity_groups = table.copy(randungeon.entity_groups)
                    local cave_tiles = math.pi * cave.radius^2
                    local max_entities = math.min(randungeon.max_entities_per_cave, cave_tiles / (7^2))
                    local max_level = math.floor(max_entities * cave.level)
                    while #entity_groups > 0 do
                        local i = math.random(1, #entity_groups)

                        -- find out if group is unfit for caves in general
                        local caves_or_rooms = entity_groups[i].caves_or_rooms
                        local unfit_for_caves = false
                        if caves_or_rooms ~= "both" and caves_or_rooms ~= "caves" then
                            unfit_for_caves = true
                        end

                        -- find out if group is underpowered
                        local group_is_underpowered = group_is_underpowered(cave, entity_groups[i])

                        -- decide which entities from which group will fill the cave
                        if math.random() <= 1 / group_is_underpowered and not unfit_for_caves then
                            local entity_group = table.remove(entity_groups, i)
                            max_entities, max_level = fill_room_or_cave_with_entity_group(cave, entity_group, cave_entities_in_groups, max_entities, max_level)
                            if max_entities == false or max_entities <= 0 then
                                break
                            end
                        elseif unfit_for_caves then
                            table.remove(entity_groups, i)
                        end
                    end
                end
                -- physically fill cave with the entities
                physically_fill_room_or_cave_with_entities(cave, cave_entities_in_groups, spawned_entities, actually_spawn)
            end
        end
        -- fill rooms
        if dungeon_data.rooms[y] then
            for _, room in ipairs(dungeon_data.rooms[y]) do
                local room_entities_in_groups = {}
                if randungeon.get_entities_for_room then
                    room_entities_in_groups = randungeon.get_entities_for_room(room)
                else
                    local entity_groups = table.copy(randungeon.entity_groups)
                    local room_tiles_min = 6 * 6
                    local room_tiles_real = (room.p2.x-room.p1.x-1) * (room.p2.z-room.p1.z-1)
                    local max_entities = math.floor(room_tiles_real / room_tiles_min * 5 * (1 + 0.5 * math.random()))
                    local max_level = math.floor(max_entities * room.level)
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
                            max_entities, max_level = fill_room_or_cave_with_entity_group(room, entity_group, room_entities_in_groups, max_entities, max_level)
                            if max_entities == false or max_entities <= 0 then
                                break
                            end
                        elseif unfit_for_rooms then
                            table.remove(entity_groups, i)
                        end
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

-- chat commands to clear out dungeon & repopulate them

local function do_thing_with_player_dungeon_corner_points(player, f)
    if player then
        local pos = player:get_pos()
        pos.y = math.floor(pos.y)
        for _, dungeon_data in pairs(randungeon.dungeons) do
            if dungeon_data.p1.x <= pos.x and dungeon_data.p2.x >= pos.x
            and dungeon_data.p1.z <= pos.z and dungeon_data.p2.z >= pos.z
            and pos.y < dungeon_data.p2.y and pos.y >= dungeon_data.p1.y then
                local p1 = {x=dungeon_data.p1.x-35, y=dungeon_data.p1.y, z=dungeon_data.p1.z-35}
                local p2 = {x=dungeon_data.p2.x+35, y=dungeon_data.p2.y, z=dungeon_data.p2.z+35}
	            minetest.load_area(p1, p2)
                f(p1, p2, dungeon_data)
                dungeon_data.lowest_explored_y = p1.y-60 -- set the dungeon to fully explored so the resulting dungeon doesn't get changed by new entities spawning
                return true
            end
        end
    end
end

local function delete_entities_between_points(p1, p2)
    local objs = minetest.get_objects_in_area(p1, p2)
    for _, obj in ipairs(objs) do
        local ent = obj:get_luaentity()
        if ent and ((randungeon.entity_levels[ent.name] or randungeon.get_entities_for_room) or ent.name == "__builtin:item") then
            obj:remove()
        end
    end
end

local function respawn_entities_between_points(p1, p2, dungeon_data)
    delete_entities_between_points(p1, p2)
    spawn_entities(p1, p2, dungeon_data)
    randungeon.create_spawning_debug_html(dungeon_data)
end

local function rewrite_entity_logs_between_points(p1, p2, dungeon_data)
    randungeon.create_spawning_debug_html(dungeon_data)
end

local function light_air_between_points(p1, p2)
    for x = p1.x, p2.x do
        for y = p1.y, p2.y do
            for z = p1.z, p2.z do
                local p = {x=x, y=y, z=z}
                if minetest.get_node(p).name == "air" then
                    minetest.set_node(p, {name="randungeon:air_glowing"})
                end
            end
        end
    end
end

local function unlight_air_between_points(p1, p2)
    for x = p1.x, p2.x do
        for y = p1.y, p2.y do
            for z = p1.z, p2.z do
                local p = {x=x, y=y, z=z}
                if minetest.get_node(p).name == "randungeon:air_glowing" then
                    minetest.set_node(p, {name="air"})
                end
            end
        end
    end
end

minetest.register_chatcommand("randungeon:clear_dungeon", {
    params = "",
    description = "removes all entities from the dungeon that one is currently in.",
    privs = {randungeon_dev=true},
    func = function(name, param)
        minetest.chat_send_player(name, "Starting the clearing process...")
        local player = minetest.get_player_by_name(name)
        local finished_execution = do_thing_with_player_dungeon_corner_points(player, delete_entities_between_points)
        if finished_execution then
            minetest.chat_send_player(name, "Removed all spawnable entities from dungeon.")
        else
            minetest.chat_send_player(name, "Couldn't remove entities bc you aren't in a dungeon right now.")
        end
    end
})

minetest.register_chatcommand("randungeon:populate_dungeon", {
    params = "",
    description = "re-spawns entities for the entire dungeon.",
    privs = {randungeon_dev=true},
    func = function(name, param)
        minetest.chat_send_player(name, "Starting the re-spawning process...")
        local player = minetest.get_player_by_name(name)
        local finished_execution = do_thing_with_player_dungeon_corner_points(player, respawn_entities_between_points)
        minetest.chat_send_player(name, "(Removed if needed) and re-spawned all entities.")
    end
})

minetest.register_chatcommand("randungeon:rewrite_spawn_log", {
    params = "",
    description = "(re-)writes the html spawn log for all the entities spawned in this dungeon.",
    privs = {randungeon_dev=true},
    func = function(name, param)
        minetest.chat_send_player(name, "Starting the re-writing process...")
        local player = minetest.get_player_by_name(name)
        local finished_execution = do_thing_with_player_dungeon_corner_points(player, rewrite_entity_logs_between_points)
        minetest.chat_send_player(name, "Rewrote entity spawn logs.")
    end
})

minetest.register_chatcommand("randungeon:light_dungeon", {
    params = "",
    description = "lights dungeon up by turning air blocks into luminescent air blocks.",
    privs = {randungeon_dev=true},
    func = function(name, param)
        minetest.chat_send_player(name, "Starting the lighting process...")
        local player = minetest.get_player_by_name(name)
        local finished_execution = do_thing_with_player_dungeon_corner_points(player, light_air_between_points)
        minetest.chat_send_player(name, "Turned on the light.")
    end
})

minetest.register_chatcommand("randungeon:unlight_dungeon", {
    params = "",
    description = "unlights dungeon up by turning randungeon's flowing air blocks into regular air blocks.",
    privs = {randungeon_dev=true},
    func = function(name, param)
        minetest.chat_send_player(name, "Starting the unlighting process...")
        local player = minetest.get_player_by_name(name)
        local finished_execution = do_thing_with_player_dungeon_corner_points(player, unlight_air_between_points)
        minetest.chat_send_player(name, "Turned off the light.")
    end
})
