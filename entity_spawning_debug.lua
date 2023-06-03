
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

function randungeon.create_spawning_debug_html(dungeon_data)
    local entity_quantity = {}
    local entity_quantity_caves = {}
    local entity_quantity_rooms = {}
    local p = dungeon_data.pos
    local file = io.open(minetest.get_worldpath().."/entity_spawn_log_" .. tostring(p.x) .. "," .. tostring(p.y) .. "," .. tostring(p.z) .. ".html", "w")
    local level = 0
    local text = "<style>.container {display: flex; flex-direction: row; flex-wrap: wrap}\
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
                text = text .. cave_or_room_to_string(room, entity_quantity, entity_quantity_caves, entity_quantity_rooms, level)
            end
        end
        if dungeon_data.bubble_caves[y] then
            for _, cave in ipairs(dungeon_data.bubble_caves[y]) do
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


	if file then
		file:write(text)
		file:close()
	end
end
