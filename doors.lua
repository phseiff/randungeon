-- Helper Functions For Block Comparisons

local mod_path = minetest.get_modpath("randungeon")
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number
local number_to_bool = helper_functions.number_to_bool
local is_even = helper_functions.is_even
local get_solid_air_block_replacement = helper_functions.get_solid_air_block_replacement

-- define available blocks:

local available_materials = {
    --"default:brick", "air",
    "randungeon:bookshelf",
    "default:desert_sandstone", "default:desert_sandstone_block", "default:desert_sandstone_brick",
    "default:desert_cobble", "default:desert_stone", "default:desert_stone_block", "default:desert_stonebrick",
    "default:cobble", "default:stone", "default:stone_block", "default:stonebrick",
    "default:sandstone", "default:sandstone_block",  "default:sandstonebrick", 
    "default:silver_sandstone", "default:silver_sandstone_block", "default:silver_sandstone_brick",
    "default:meselamp",

    "default:goldblock",

    "randungeon:ceiling", "randungeon:wall_type_2", "randungeon:wall_type_1", "randungeon:floor", "randungeon:pillar"
}

local woods = {
    "default:acacia_wood", "default:acacia_wood", "default:wood", "default:aspen_wood", "default:junglewood", "default:pine_wood"
}

for _, wood in ipairs(woods) do
    table.insert(available_materials, wood)
end

-- functions to get name of door or doorframe blocks:

local function get_doorframe_name(material)
    local split = string.split(material, ":")
    local name_appendix = split[1] .. "_" .. split[2]
    return "randungeon:doorframe_" .. name_appendix
end

local function get_door_name(material)
    local split = string.split(material, ":")
    local name_appendix = split[1] .. "_" .. split[2]
    return "randungeon:door_" .. name_appendix
end

-- function to get material set of door:

local function get_player_inv_materials(player)
    local materials = player:get_inventory():get_list("dungeon_materials")
    local roof_type = this_or_air(materials[1]:get_name())
    local wall_type_2 = this_or_air(materials[2]:get_name())
    local wall_type_1 = this_or_air(materials[3]:get_name())
    local floor_type = this_or_air(materials[4]:get_name())
    local pillar_type = this_or_air(materials[5]:get_name())
    return {roof_type=roof_type, wall_type_2=wall_type_2, wall_type_1=wall_type_1, floor_type=floor_type, pillar_type=pillar_type}
end

local function get_door_and_doorframe_materials(materials, pos)
    local doorframe
    if materials.wall_type_2 == "air" then
        doorframe = get_doorframe_name(get_solid_air_block_replacement(pos, false))
    elseif materials.wall_type_2 == "randungeon:bookshelf" then
        doorframe = get_doorframe_name("default:wood")
    elseif not contains(available_materials, materials.wall_type_2) then
        doorframe = nil -- for when there is no doorframe material available
    else
        doorframe = get_doorframe_name(materials.wall_type_2)
    end
    local door
    for _, node in ipairs({
        materials.floor_type, materials.wall_type_1, materials.wall_type_2, materials.roof_type, materials.pillar_type, "default:junglewood"
    }) do
        if contains(woods, node) then
            door = get_door_name(node)
            break
        end
    end
    -- if the only wooden thing in the level are bookshelfs then we use apple wood, since they are made of this
    if door == "randungeon:door_junglewood" and contains(
        {materials.floor_type, materials.wall_type_1, materials.wall_type_2, materials.roof_type, materials.pillar_type}, "randungeon:bookshelf") then
        door = "randungeon:door_wood"
    end
    return {door, doorframe}
end

-- item to spawn a door:

minetest.register_craftitem("randungeon:door_item", {
    description = "Make randomly rotated door based on dungeon material\nscheme set in 'Make Dungeon Tile' tab.",
    inventory_image = "randungeon_door_item.png",
	wield_image = "randungeon_door_item.png",
    groups = {not_in_creative_inventory = 1},
	on_use = function(itemstack, user, pointed_thing)
        -- figure out pos
        local pos
		if pointed_thing.type == "object" then
			pos = pointed_thing.ref:get_pos()
			pos = {x=math.floor(pos.x), y=math.floor(pos.y), z=math.floor(pos.z)}
		elseif pointed_thing.type == "node" then
			pos = pointed_thing.under
		elseif pointed_thing.type == "nothing" then
			pos = user:get_pos()
			pos = {x=math.floor(pos.x), y=math.floor(pos.y), z=math.floor(pos.z)}
		else
			minetest.chat_send_player(user:get_player_name(), "Can't make door at the thing you pointed at.")
		end
        local inv_materials = get_player_inv_materials(user)
        local door, doorframe = unpack(get_door_and_doorframe_materials(inv_materials, pos))
        if math.random() < 0.5 then
            door = door .. "_mirrored"
            if doorframe then
                doorframe = doorframe .. "_mirrored"
            end
        end
        minetest.chat_send_player(user:get_player_name(), "door: " .. door .. "; doorframe: " .. doorframe)
        local facedir = math.random(0, 3)
        minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z}, {name=door, param2=facedir})
        if doorframe then
            minetest.set_node({x=pos.x, y=pos.y+2, z=pos.z}, {name=doorframe, param2=facedir})
        end
    end
})

-- place doors function:
local function place_doubledoor_or_double_doorframe(pos1, pos2, dir_name, door_base_type)
    local door1, door2
    local rot1, rot2
    if dir_name == "x_minus" then
        door1 = door_base_type
        rot1 = 0
        door2 = door_base_type .. "_mirrored"
        rot2 = 2
    elseif dir_name == "x_plus" then
        door1 = door_base_type .. "_mirrored"
        rot1 = 0
        door2 = door_base_type
        rot2 = 2
    elseif dir_name == "z_minus" then
        door1 = door_base_type .. "_mirrored"
        rot1 = 1
        door2 = door_base_type
        rot2 = 3
    elseif dir_name == "z_plus" then
        door1 = door_base_type
        rot1 = 1
        door2 = door_base_type .. "_mirrored"
        rot2 = 3
    end
    minetest.set_node(pos1, {name=door1, param2=rot1})
    minetest.set_node(pos2, {name=door2, param2=rot2})
end

local function place_doubledoor_based_on_materials(pos1, pos2, dir_name, materials, no_doorframes)
    local door, doorframe = unpack(get_door_and_doorframe_materials(materials, pos1))
    place_doubledoor_or_double_doorframe(pos1, pos2, dir_name, door)
    if doorframe and not no_doorframes then
        place_doubledoor_or_double_doorframe({x=pos1.x, y=pos1.y+1, z=pos1.z}, {x=pos2.x, y=pos2.y+1, z=pos2.z}, dir_name, doorframe)
    end
end

-- doorframes:

for _, material in ipairs(available_materials) do
    local node = minetest.registered_nodes[material]
    for _, mirrored in ipairs({"", "_mirrored"}) do
        local new_node = {}
        for key, attr in pairs(node) do
            new_node[key] = attr
        end
        -- copy groups & add not_in_creative_inventory
        new_node["groups"] = {not_in_creative_inventory = 1}
        for group, value in pairs(node["groups"]) do
            new_node["groups"][group] = value
        end
        -- drawtype things
        new_node["paramtype"] = "light"
        new_node["paramtype2"] = "facedir"
        new_node["drawtype"] = "nodebox"
        if mirrored == "" then
            new_node["node_box"] = {
                type = "fixed",
                fixed = {
                    {2.5/8, 3/8,    -0.5, 4/8, 4/8, 0.5},
                    {2.5/8, 2.5/8,  -0.5, 4/8, 3/8, -1/16},
                    {2.5/8, 2/8,    -0.5, 4/8, 2.5/8, -3/16},
                    {2.5/8, 1.5/8,  -0.5, 4/8, 2/8, -4/16},
                    {2.5/8, 1/8,    -0.5, 4/8, 1.5/8, -5/16},
                    {3/8, 0,      -0.5, 4/8, 1/8, -6/16},
                    {2.5/8, 0,      -0.5, 4/8, 1/8, -7/16},
                    {2.5/8, -1.5/8, -0.5, 4/8, 0, -7/16},
                },
            }
            new_node["selection_box"] = {
                type = "fixed",
                fixed = {{2.5/8, 3/8, -0.5, 4/8, 4/8, 0.5}}
            }
        elseif mirrored == "_mirrored" then
            new_node["node_box"] = {
                type = "fixed",
                fixed = {
                    {-4/8, 3/8,    -0.5, -2.5/8, 4/8, 0.5},
                    {-4/8, 2.5/8,  -0.5, -2.5/8, 3/8, -1/16},
                    {-4/8, 2/8,    -0.5, -2.5/8, 2.5/8, -3/16},
                    {-4/8, 1.5/8,  -0.5, -2.5/8, 2/8, -4/16},
                    {-4/8, 1/8,    -0.5, -2.5/8, 1.5/8, -5/16},
                    {-4/8, 0,      -0.5, -2.5/8, 1/8, -7/16},
                    {-4/8, 0,      -0.5, -3/8, 1/8, -6/16},
                    {-4/8, -1.5/8, -0.5, -2.5/8, 0, -7/16},
                },
            }
            new_node["selection_box"] = {
                type = "fixed",
                fixed = {{-4/8, 3/8, -0.5, -2.5/8, 4/8, 0.5}}
            }
        end
        new_node["description"] = node["description"] .. " as a doorframe " .. mirrored
        new_node["drop"] = material
        new_node["on_construct"] = function(pos)
            minetest.get_meta(pos):set_string("dont_replace_with_air", "true")
        end
        
        minetest.register_node(get_doorframe_name(material) .. mirrored, new_node)
    end
end

-- doors:

for _, material in ipairs(woods) do
    -- get original node:
    local node = minetest.registered_nodes[material]

    -- generate new texture:
    local old_tex_name = node["tiles"][1]
    local old_tex_name_rot = old_tex_name .. "\\\\^[transformR90"
    local one_door = "\\[combine\\:16x32\\:0,0=" .. old_tex_name_rot .. "\\:0,16=" .. old_tex_name_rot .. "\\:0,0=randungeon_door_overlay.png"
    local new_tex_name = "[combine:32x32:0,0=" .. one_door .. ":16,0=" .. one_door
    local new_tex_name_mirrored = new_tex_name .. "^[transformFX"

    local one_door_uneven = "\\[combine\\:16x32\\:0,0=" .. old_tex_name_rot .. "\\:0,16=" .. old_tex_name_rot .. "\\:0,16=randungeon_door_overlay.png"
                            .. "\\:0,-16=randungeon_door_overlay.png"
    local new_tex_name_uneven = "[combine:32x32:0,0=" .. one_door_uneven .. ":16,0=" .. one_door_uneven
    local new_tex_name_uneven_mirrored = new_tex_name_uneven .. "^[transformFX"

    -- iterate over how height the block is placed (y*2 or y*2+1) and define texturing for both:
    local front_side
    local back_side
    for _, even in ipairs({"", "_uneven"}) do
        if even == "" then
            front_side = {
                name = new_tex_name,
                align_style = 'world',
                scale = 2
            }
            back_side = {
                name = new_tex_name_mirrored,
                align_style = 'world',
                scale = 2
            }
        elseif even == "_uneven" then
            front_side = {
                name = new_tex_name_uneven,
                align_style = 'world',
                scale = 2
            }
            back_side = {
                name = new_tex_name_uneven_mirrored,
                align_style = 'world',
                scale = 2
            }
        end

        -- iterate over mirrored vs not mirrored and define nodeboxes for both:
        for _, mirrored in ipairs({"", "_mirrored"}) do

            -- copy from basis node to our door version:
            local new_node = {}
            for key, value in pairs(node) do
                new_node[key] = value
            end
            -- copy groups & add not_in_creative_inventory
            new_node["groups"] = {not_in_creative_inventory = 1}
            for group, value in pairs(node["groups"]) do
                new_node["groups"][group] = value
            end

            -- drawtypes & stuff:
            new_node["paramtype"] = "light"
            new_node["paramtype2"] = "facedir"
            new_node["drawtype"] = "nodebox"
            new_node["drop"] = material

            -- different rotations:
            if mirrored == "" then
                new_node["node_box"] = {
                    type = "fixed",
                    fixed = {
                        {3/8, -0.5,    -0.5, 3.5/8, 1-1.5/8, 0.5},
                        {3/8, 1+2.5/8,  0.5, 3.5/8, 1+3/8, -1/16},
                        {3/8, 1+2/8,    0.5, 3.5/8, 1+2.5/8, -3/16},
                        {3/8, 1+1.5/8,  0.5, 3.5/8, 1+2/8, -4/16},
                        {3/8, 1+1/8,    0.5, 3.5/8, 1+1.5/8, -5/16},
                        {3/8, 1+0,      0.5, 3.5/8, 1+1/8, -6/16},
                        {3/8, 1-1.5/8,  0.5, 3.5/8, 1, -7/16},
                    },
                }
                new_node["selection_box"] = {
                    type = "fixed",
                    fixed = {{3/8, -0.5,   -0.5, 3.5/8, 1.5-1/8, 0.5}}
                }
            elseif mirrored == "_mirrored" then
                new_node["node_box"] = {
                    type = "fixed",
                    fixed = {
                        {-3.5/8, -0.5,    -0.5, -3/8, 1-1.5/8, 0.5},
                        {-3.5/8, 1+2.5/8,  0.5, -3/8, 1+3/8, -1/16},
                        {-3.5/8, 1+2/8,    0.5, -3/8, 1+2.5/8, -3/16},
                        {-3.5/8, 1+1.5/8,  0.5, -3/8, 1+2/8, -4/16},
                        {-3.5/8, 1+1/8,    0.5, -3/8, 1+1.5/8, -5/16},
                        {-3.5/8, 1+0,      0.5, -3/8, 1+1/8, -6/16},
                        {-3.5/8, 1-1.5/8,  0.5, -3/8, 1, -7/16},
                    },
                }
                new_node["selection_box"] = {
                    type = "fixed",
                    fixed = {{-3.5/8, -0.5,   -0.5, -3/8, 1.5-1/8, 0.5}}
                }
            end

            -- set desription and finally textures:
            new_node["description"] = node["description"] .. " as a door " .. even .. mirrored
            new_node["tiles"] = {
                {name = old_tex_name.. "^[transformR90"},
                {name = old_tex_name.. "^[transformR90"},
                front_side,
                back_side,
                {name = old_tex_name.. "^[transformR90"},
                {name = old_tex_name.. "^[transformR90"},
            }
            -- set on_construct function to make sure tiling works right:
            new_node["on_construct"] = function(pos)
                local n = minetest.get_node(pos)
                if not is_even(pos.y) and n.name == get_door_name(material) .. "_uneven" .. mirrored then
                    n.name = get_door_name(material) .. "" .. mirrored
                    minetest.set_node(pos, n)
                elseif is_even(pos.y) and n.name == get_door_name(material) .. "" .. mirrored then
                    n.name = get_door_name(material) .. "_uneven" .. mirrored
                    minetest.set_node(pos, n)
                end
                local meta = minetest.get_meta(pos)
                meta:set_string("door_state", "closed")
                meta:set_string("dont_replace_with_air", "true")
            end
            -- make door openeable:
            new_node["on_rightclick"] = function(pos, not_recursive, _1, _2, _3)
                local n = minetest.get_node(pos)
                -- get new node:
                if mirrored == "" then
                    n.name = get_door_name(material) .. even .. "_mirrored"
                elseif mirrored == "_mirrored" then
                    n.name = get_door_name(material) .. even .. ""
                end
                -- change change door states & play sounds:
                local door_state = minetest.get_meta(pos):get_string("door_state")
                if door_state == "closed" then
                    door_state = "open"
                    minetest.sound_play("doors_door_open", {pos=pos, gain=0.3, max_hear_distance=10}, true)
                elseif door_state == "open" then
                    door_state = "closed"
                    minetest.sound_play("doors_door_close", {pos=pos, gain=0.3, max_hear_distance=10}, true)
                end
                -- change param2:
                if n.name == get_door_name(material) .. even .. "_mirrored" then
                    n.param2 = n.param2 - 1
                elseif n.name == get_door_name(material) .. even then
                    n.param2 = n.param2 + 1
                end
                -- reduce param2 to intended range:
                if n.param2 < 0 then
                    n.param2 = n.param2 + 4
                elseif n.param2 > 3 then
                    n.param2 = n.param2 - 4
                end
                -- set everything:
                minetest.set_node(pos, n)
                minetest.get_meta(pos):set_string("door_state", door_state)
                -- check if there is a neighboring node (bc double door) that we also need to open:
                if not_recursive ~= true then
                    for _, p in ipairs({{x=pos.x+1, y=pos.y, z=pos.z}, {x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y, z=pos.z+1}, {x=pos.x, y=pos.y, z=pos.z-1}}) do
                        local n = minetest.get_node(p).name
                        if n == get_door_name(material) .. even .. "_mirrored" or n == get_door_name(material) .. even then
                            minetest.registered_nodes[n]["on_rightclick"](p, true)
                        end
                    end
                end
            end

            -- register node:
            -- print("registered dungeon door: " .. get_door_name(material) .. even .. mirrored)
            minetest.register_node(get_door_name(material) .. even .. mirrored, new_node)
        end
    end
end

return {
    place_doubledoor_based_on_materials = place_doubledoor_based_on_materials,
}