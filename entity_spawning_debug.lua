
local pool_content_table = {
    [randungeon.EMPTY_ROOM] = "empty",
    [randungeon.EMPTY_CAVE] = "empty",
    [randungeon.POOL_WATER] = "water",
    [randungeon.CAVE_WATER] = "water",
    [randungeon.POOL_LAVA] = "lava",
    [randungeon.CAVE_LAVA] = "lava",
}

local function cave_or_room_to_string(cave_or_room, entity_quantity, entity_quantity_caves, entity_quantity_rooms, level)
    local text = "<div class='cave'>"
    if cave_or_room.center_pos then
        text = text .. "<u>cave</u>"
    else
        text = text .. "<u>room</u>"
    end
    local index = cave_or_room.type or cave_or_room.pool_content or ("|"..tostring(print(cave_or_room.pool_content) or cave_or_room.pool_content))
    text = text .. " ("
                .. (pool_content_table[index] or index)
                .. (cave_or_room.frozen and ", frozen" or "")
                .. (cave_or_room.nature and (", " .. randungeon.nature_types[cave_or_room.nature].name) or "")
                .. (cave_or_room.fill_height and (", filled " .. tostring(math.ceil(cave_or_room.fill_height * 100)) .. "%") or "")
                .. ")<br/>"
    -- text = text .. minetest.serialize(cave_or_room) .. "<br/>"
    for _, group in ipairs(cave_or_room.spawned_entities or {}) do
        for _, entity in ipairs(group) do
            text = text .. entity .. "<br/>"
            local entity_quantities = {entity_quantity, (cave_or_room.center_pos and entity_quantity_caves or entity_quantity_rooms)}
            for _, eq in ipairs(entity_quantities) do
                if not eq[entity] then
                    eq[entity] = {}
                end
                eq[entity][level] = (eq[entity][level] or 0) + 1
            end
        end
    end
    text = text .. "</div>"
    return text
end

randungeon.mods_whose_items_and_entities_need_to_occur_inside_the_dungeon = {
    "example_mod",
    "example_mod2"
}
randungeon.items_and_entities_that_dont_need_to_occur_inside_the_dungeon = {
    ["example:item"] = true
}

function randungeon.create_spawning_debug_html(dungeon_data)
    local entity_quantity = {}
    local entity_quantity_caves = {}
    local entity_quantity_rooms = {}
    local number_of_rooms_and_caves = 0
    local number_of_rooms = 0
    local p = dungeon_data.pos
    local file = io.open(minetest.get_worldpath().."/entity_spawn_log_" .. tostring(p.x) .. "," .. tostring(p.y) .. "," .. tostring(p.z) .. ".html", "w")
    local level = 0
    local text = ""
    text = text .. "<h1>All entities ranked by their level</h1>---<br/>"
    local levels = {}
    local max_entity_level = 0
    for entity_name, entity_level in pairs(randungeon.entity_levels) do
        if minetest.registered_entities[entity_name] then
            max_entity_level = math.max(max_entity_level, entity_level)
            local modified_entity_name = string.split(entity_name, ":")[2]
            if not levels[entity_level] then
                levels[entity_level] = {modified_entity_name}
            else
                table.insert(levels[entity_level], modified_entity_name)
            end
        end
    end
    for entity_level = 1, max_entity_level do
        text = text .. entity_level .. ": "
        if levels[entity_level] then
            text = text .. table.concat(levels[entity_level], ", ")
        end
        text = text .. "<br/>"
    end
    text = text .. "<h1>Things we'd need to spawn that aren't in the spawn tables</h1>---<br/>"
    local list_of_all_content_we_spawn = {}
    local already_added = {}
    for _, entity_group in ipairs(randungeon.entity_groups) do
        for _, entity_name in ipairs(entity_group.entities) do
            if not already_added[entity_name] then
                already_added[entity_name] = true
                table.insert(list_of_all_content_we_spawn, entity_name)
            end
        end
    end
    local list_of_all_content_we_need_to_spawn = {}
    for item_name, item_def in pairs(minetest.registered_craftitems) do
        for _, mod_name in ipairs(randungeon.mods_whose_items_and_entities_need_to_occur_inside_the_dungeon) do
            if item_def.mod_origin == mod_name and not already_added[item_name]
            and not randungeon.items_and_entities_that_dont_need_to_occur_inside_the_dungeon[item_name] then
                table.insert(list_of_all_content_we_need_to_spawn, item_name)
            end
        end
    end
    for item_name, item_def in pairs(minetest.registered_tools) do
        for _, mod_name in ipairs(randungeon.mods_whose_items_and_entities_need_to_occur_inside_the_dungeon) do
            if item_def.mod_origin == mod_name and not already_added[item_name]
            and not randungeon.items_and_entities_that_dont_need_to_occur_inside_the_dungeon[item_name] then
                table.insert(list_of_all_content_we_need_to_spawn, item_name)
            end
        end
    end
    for item_name, item_def in pairs(minetest.registered_entities) do
        for _, mod_name in ipairs(randungeon.mods_whose_items_and_entities_need_to_occur_inside_the_dungeon) do
            if item_def.mod_origin == mod_name and not already_added[item_name]
            and not randungeon.items_and_entities_that_dont_need_to_occur_inside_the_dungeon[item_name] then
                table.insert(list_of_all_content_we_need_to_spawn, item_name)
            end
        end
    end
    for _, item_name in ipairs(list_of_all_content_we_need_to_spawn) do
        text = text .. item_name .. "<br/>"
    end
    text = text .. "<h1>Room & Cave Report</h1>"
    text = text .. "<style>.container {display: flex; flex-direction: row; flex-wrap: wrap}\
    .cave {padding-top: 10px; padding-right: 10px; padding-bottom: 10px; padding-left: 10px;\
    margin-top: 10px; margin-right: 10px; margin-bottom: 10px; margin-left: 10px}</style>"
    text = text .. "<script src='https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.js'></script>"
    local lowest_room_floor_y = dungeon_data.p2.y+1000
    text = text .. "<div class='container'>"
    for y = dungeon_data.p2.y+1000, dungeon_data.p1.y-100, -1 do
        if dungeon_data.rooms[y] then
            for _, room in ipairs(dungeon_data.rooms[y]) do
                if room.p1.y < lowest_room_floor_y then
                    lowest_room_floor_y = room.p1.y
                    level = level + 1
                    text = text .. "\n</div><h2>Level " .. tostring(level) .. "</h2></div><div class='container'>"
                end
                if randungeon_player and level < randungeon_player.DUNGEON_LEVELS then
                    number_of_rooms_and_caves = number_of_rooms_and_caves + 1
                    number_of_rooms = number_of_rooms + 1
                end
                text = text .. cave_or_room_to_string(room, entity_quantity, entity_quantity_caves, entity_quantity_rooms, level)
            end
        end
        if dungeon_data.bubble_caves[y] then
            for _, cave in ipairs(dungeon_data.bubble_caves[y]) do
                if randungeon_player and level < randungeon_player.DUNGEON_LEVELS then
                    number_of_rooms_and_caves = number_of_rooms_and_caves + 1
                end
                text = text .. cave_or_room_to_string(cave, entity_quantity, entity_quantity_caves, entity_quantity_rooms, level)
            end
        end
    end
    text = text .. "</div>"
    -- plot entity spawning
    print(minetest.serialize(entity_quantity))
    local canvas_id = 0
    local entity_quantity_copy
    for _, normalize_spawnrates in ipairs({false, true}) do
        for _, mobs_and_entities in ipairs({"mobs", "items", "mobs & items"}) do
            for caves_and_rooms_string, caves_and_rooms in pairs({rooms=entity_quantity_rooms, caves=entity_quantity_caves, ["rooms & caves"]=entity_quantity}) do
                local datasets = ""
                entity_quantity_copy = table.copy(caves_and_rooms)
                for entity_name, _ in pairs(entity_quantity_copy) do
                    if mobs_and_entities == "mobs" and minetest.registered_items[entity_name] then
                        entity_quantity_copy[entity_name] = nil
                    elseif mobs_and_entities == "items" and not minetest.registered_items[entity_name] then
                        entity_quantity_copy[entity_name] = nil
                    end
                end
                local levels = {}
                for _, entity_data in pairs(entity_quantity_copy) do
                    for i = 1, level do
                        levels[i] = (levels[i] or 0) + (entity_data[i] or 0)
                    end
                end
                if normalize_spawnrates then
                    for _, entity_data in pairs(entity_quantity_copy) do
                        for i = 1, level do
                            entity_data[i] =  (levels[i]>0) and ((entity_data[i] or 0) / levels[i]) or 0
                        end
                    end
                end
                for entity_name, entity_data in pairs(entity_quantity_copy) do
                    datasets = datasets .. "{label: '" .. entity_name .. "', data: ["
                    for i = 1, level do
                        datasets = datasets .. tostring(entity_data[i] or 0) .. ","
                    end
                    datasets = datasets .. "], borderColor: stringToColour('" .. entity_name .. "'),\
                                        backgroundColor: stringToColour('" .. entity_name .. "'), fill: true},"
                end
                canvas_id = canvas_id + 1
                text = text .. "<h2>Entity Graph"
                            .. (normalize_spawnrates and " (normalized)" or "")
                            .. (mobs_and_entities and (" (" .. mobs_and_entities .. ")") or "")
                            .. " (" .. caves_and_rooms_string .. ")"
                            .. "</h2>\
                <canvas id='entity_plot_" .. tostring(canvas_id) .. "' style='width:100%'></canvas>"
                text = text .. [[<script>
                var stringToColour = function(str) { /* credit http://jsfiddle.net/sUK45/ */
                    var hash = 0;
                    for (var i = 0; i < str.length; i++) {
                        hash = str.charCodeAt(i) + ((hash << 5) - hash);
                    }
                    var colour = '#';
                    for (var i = 0; i < 3; i++) {
                        var value = (hash >> (i * 8)) & 0xFF;
                        colour += ('00' + value.toString(16)).substr(-2);
                    }
                    return colour;
                }
                var xValues = [];
                for (var i = 1; i <= ]] .. tostring(level) .. [[; i++) {
                    xValues.push(i);
                }

                new Chart("entity_plot_]] .. tostring(canvas_id) .. [[", {
                    type: "line",
                    data: {
                    labels: xValues,
                    datasets: []] .. datasets .. [[]
                    },
                    options: {
                    responsive: true,
                    plugins: {
                        title: {
                        display: true,
                        text: (ctx) => 'Chart.js Line Chart - stacked=' + ctx.chart.options.scales.y.stacked
                        },
                        tooltip: {
                        mode: 'index'
                        },
                    },
                    interaction: {
                        mode: 'nearest',
                        axis: 'x',
                        intersect: false
                    },
                    legend: {display: true},
                    scales: {
                        xAxes: {
                            stacked: true,
                            title: {
                                display: true,
                                text: 'Level'
                            }
                        },
                        yAxes: [{
                            stacked: true,
                            title: {
                                display: true,
                                text: '#'
                            }
                        }]
                    }
                    },
                });
                </script>]]
            end
        end
    end

    if randungeon_monsters and randungeon_monsters.total_hp_spawned_in_dungeon then
        text = text .. "\n<br/></br>total hp of monsters: " .. randungeon_monsters.total_hp_spawned_in_dungeon
        text = text .. "\n<br/>number of rooms and caves: " .. number_of_rooms_and_caves
        text = text .. "\n<br/>monster hp per room or cave: " .. (randungeon_monsters.total_hp_spawned_in_dungeon / number_of_rooms_and_caves)
        text = text .. "\n<br/>total hp of monsters in rooms: " .. (randungeon_monsters.total_hp_spawned_in_dungeon_rooms)
        text = text .. "\n<br/>number of rooms: " .. (number_of_rooms)
        text = text .. "\n<br/>monster hp per room: " .. (randungeon_monsters.total_hp_spawned_in_dungeon_rooms / number_of_rooms)
    end

	if file then
		file:write(text)
		file:close()
	end
end
