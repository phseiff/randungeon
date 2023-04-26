-- Helper Functions For Block Comparisons
local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number

--
-- Functions for freezing part of the dungeon
--

local function freeze_area(p1, p2, frozen_corridors)
    for x = p1.x, p2.x do
        for y = p1.y, p2.y do
            for z = p1.z, p2.z do
                local p = {x=x, y=y, z=z}
                local p_above = {x=x, y=y+1, z=z}
                local nname = minetest.get_node(p).name
                local nname_above = minetest.get_node(p_above).name
                local new_node = nil
                local new_node_above = nil
                if contains({"default:dirt_with_grass", "default:dirt_with_rainforest_litter", "default:permafrost_with_moss"}, nname)
                and not minetest.get_item_group(nname_above, "water") ~= 0 then
                    if nname ==  "default:permafrost_with_moss" then
                        new_node = "randungeon:permafrost_with_snow"
                    else
                        new_node = "default:dirt_with_snow"
                    end
                end
                if minetest.get_item_group(new_node, "snowy") >= 1 or minetest.get_item_group(nname, "leaves") >= 1
                   or minetest.get_item_group(nname, "tree") >= 1 or contains(randungeon.snow_carrying_blocks, nname) then
                    if nname_above == "air" or nname_above == "randungeon:air_glowing" then
                        new_node_above = "default:snow"
                    end
                end
                if minetest.get_item_group(nname, "lava") >= 1 and minetest.registered_nodes[nname].liquidtype == "source" then
                    if (nname_above == "air" or nname_above == "randungeon:air_glowing") or math.random() < 1/3 then
                        new_node = "default:obsidian"
                    end
                end
                if minetest.get_item_group(nname, "water") >= 1 and minetest.registered_nodes[nname].liquidtype == "source" then
                    if (nname_above == "air" or nname_above == "randungeon:air_glowing" or nname_above == "flowers:waterlily_waving")
                    or (math.random() < 1/3 and minetest.get_natural_light(p, 0.5) == 0) then
                        new_node = "default:ice"
                    end
                end
                if randungeon.frozen_variants[nname] then
                    new_node = randungeon.frozen_variants[nname]
                end
                if frozen_corridors then
                    local node_data = minetest.registered_nodes[nname]
                    if node_data.walkable ~= false and (node_data.drawtype == nil or node_data.drawtype == "normal")
                       and minetest.get_item_group(nname, "wood") == 0
                       and (nname_above == "air" or nname_above == "randungeon:air_glowing")
                       and math.random() < 1/3 then
                        new_node_above = "default:snow"
                    end
                end
                if new_node then
                    minetest.set_node(p, {name=new_node})
                end
                if new_node_above then
                    minetest.set_node(p_above, {name=new_node_above})
                end
            end
        end
    end
end

local function freeze_frozen_levels(pos, dungeon_maps, materials, room_styles, frozen_biome, dungeon_data)
    -- mark levels as freeze types
    for i = 1, #dungeon_maps do
        if (i>1 and room_styles[i-1].frozen) or (i<#dungeon_maps and room_styles[i+1].frozen) or (i==1 and frozen_biome) then
            room_styles[i].frozen_caves = true
        end
        if ((i>1 and room_styles[i-1].frozen) or (i==1 and frozen_biome)) and (i<#dungeon_maps and room_styles[i+1].frozen) then
            room_styles[i].frozen_corridors = true
        end
    end
    local width_in_blocks = #dungeon_maps[1] * 10
    local pos = table.copy(pos)
    -- freeze levels appropriately
    local y_max = pos.y
    for i = 1, #dungeon_maps do
        local y_min
        if i == 1 then
            y_min = y_max - dungeon_maps[i].top_deph - math.ceil(dungeon_maps[i].bottom_deph / 2)
        elseif i == #dungeon_maps then
            y_min = y_max - math.floor(dungeon_maps[i].top_deph / 2) - dungeon_maps[i].bottom_deph
        else
            y_min = y_max - math.floor(dungeon_maps[i].top_deph / 2) - math.ceil(dungeon_maps[i].bottom_deph / 2)
        end
        y_max = math.min(0, y_max) - 1
        if y_max >= y_min and room_styles[i].frozen_caves then
            local p1 = {x=pos.x-30, y=y_min, z=pos.z-30}
            local p2 = {x=pos.x+width_in_blocks+30, y=y_max, z=pos.z+width_in_blocks+30}
            freeze_area(p1, p2, room_styles[i].frozen_corridors)
        end
        y_max = y_min
    end
end

return {
    freeze_frozen_levels = freeze_frozen_levels,
    freeze_area = freeze_area
}