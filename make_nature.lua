--
-- helper functions
--

local function make_grass(pos)
    local grass = "default:grass_" .. tostring(math.random(1, 5))
    minetest.set_node(pos, {name=grass})
end

local function make_fern(pos)
    local fern = "default:fern_" .. tostring(math.random(1, 3))
    minetest.set_node(pos, {name=fern})
end

local function make_mushroom(pos)
    if math.random() < 0.5 then
        minetest.set_node(pos, {name="flowers:mushroom_brown"})
    else
        minetest.set_node(pos, {name="flowers:mushroom_red"})
    end
end

local function is_air(node_name)
    if node_name == "air" then
        return true
    end
    local node_definition = minetest.registered_nodes[node_name]
    if node_definition.buildable_to and node_definition.walkable == false and node_definition.drawtype == "airlike" then
        return true
    end
    return false
end

local function make_waterlilie(pos)
    for y = 1, 60 do
        local block = minetest.get_node({x=pos.x, y=pos.y+y, z=pos.z}).name
        if is_air(block) then
            minetest.set_node({x=pos.x, y=pos.y+y, z=pos.z}, {name="flowers:waterlily_waving", param2=math.random(0, 3)})
        end
        if block ~= "default:water_source" and block ~= "randungeon:water_source" and block ~= "default:river_water_source" then
            break
        end
    end
end

local function make_glowstick(pos)
    local apple_wood = #minetest.find_nodes_in_area({x=pos.x-20, y=pos.y-20, z=pos.z-20}, {x=pos.x+20, y=pos.y+20, z=pos.z+20}, {"default:wood"})
    local pine_wood = #minetest.find_nodes_in_area({x=pos.x-20, y=pos.y-20, z=pos.z-20}, {x=pos.x+20, y=pos.y+20, z=pos.z+20}, {"default:pine_wood"})
    local aspen_wood = #minetest.find_nodes_in_area({x=pos.x-20, y=pos.y-20, z=pos.z-20}, {x=pos.x+20, y=pos.y+20, z=pos.z+20}, {"default:aspen_wood"})
    local acacia_wood = #minetest.find_nodes_in_area({x=pos.x-20, y=pos.y-20, z=pos.z-20}, {x=pos.x+20, y=pos.y+20, z=pos.z+20}, {"default:acacia_wood"})
    local max_wood = math.max(apple_wood, pine_wood, aspen_wood, acacia_wood)

    local mese_lamp_type = apple_wood == max_wood and "default:mese_post_light" or 
                           pine_wood == max_wood and "default:mese_post_light_pine_wood" or
                           aspen_wood == max_wood and "default:mese_post_light_aspen_wood" or
                           acacia_wood == max_wood and "default:mese_post_light_acacia_wood"

    minetest.set_node(pos, {name=mese_lamp_type})
end

local function make_pond(pos, chance_for_water_lilies_on_seed_based_ponds)
    local neighbors = {
        {x=pos.x, y=pos.y, z=pos.z-1},
        {x=pos.x, y=pos.y, z=pos.z+1},
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x+1, y=pos.y, z=pos.z}
    }
    local all_solid = true
    for _, p in ipairs(neighbors) do
        local nname = minetest.get_node(p).name
        local ndef = minetest.registered_nodes[nname]
        if ndef and ndef.walkable == false and nname ~= "default:river_water_source" then
            all_solid = false
            break
        end
    end
    if all_solid then
        -- pond water
        minetest.set_node(pos, {name="default:river_water_source"})
        -- pond ground
        if math.random() < 0.9 then
            if math.random() < 0.5 then
                minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z}, {name="default:sand"})
            else
                minetest.set_node({x=pos.x, y=pos.y-1, z=pos.z}, {name="default:clay"})
            end
        end
        -- water lily
        if math.random() < chance_for_water_lilies_on_seed_based_ponds then
            local block = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name
            if is_air(block) then
                minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z}, {name="flowers:waterlily_waving", param2=math.random(0, 3)})
            end
        end
        return true
    end
end

local TESTING_CAVES = false


--
-- types of noise
--

local pond_noise_definition = {
    offset = -0.35,
    scale = 1,
    spread = {x = 11, y = 11, z = 11},
    seed = 1312,
    octaves = 2,
    persistence = 0.3,
    lacunarity = 3.0,
}

randungeon.initialize_perlin = function()
    randungeon.pond_noise = minetest.get_perlin(pond_noise_definition)
end

--
-- define types of nature
--

-- PRETTY FOREST

--[[
How it works:

node = random nature block
meta = make_metadata_for_nature(node)
for every pos we want to do this:
    set_node(pos, node)
    set_meta(pos, meta)
[do other stuff]
for every pos where a randungeon:pretty_forest is:
    make_nature(pos)
--]]

local function make_metadata_for_pretty_forest(pos, cave_or_room_data)
    local water_lilies = false
    if math.random() < 0.5 then
        water_lilies = true
    end
    local mese_lamps = false
    if math.random() < 0.5 then
        mese_lamps = true
    end
    local mese_lamps_if_mese_lamps = false
    if math.random() < 0.7 then
        mese_lamps_if_mese_lamps = true
    end
    local can_have_apples = false
    if math.random() < 0.6 then
        can_have_apples = true
    end
    local grasses = false
    local ferns = false
    if math.random() < 0.7 then
        grasses = true
    else
        ferns = true
    end
    local mushrooms = false
    local rand = math.random()
    if (grasses and rand < 0.35) or (ferns and rand < 0.75) then
        mushrooms = true
    end
    local block_to_turn_into_ponds = ""
    local block_to_turn_into_ponds2 = ""
    if math.random() < 1/2.6 then
        local ore_types = {
            "default:stone_with_coal", "default:stone_with_iron", "default:stone_with_copper", "default:stone_with_tin"}--,
            --"default:stone_with_gold", "default:stone_with_mese", "default:stone_with_diamond", "default:dirt"}
        block_to_turn_into_ponds = table.remove(ore_types, math.random(1, #ore_types))
        if math.random() > 2/3 then
            block_to_turn_into_ponds2 = ore_types[math.random(1, #ore_types)]
        end
    end
    local add_seed_based_ponds = math.random() < 1/2
    local water_lilies_on_seed_based_ponds = (water_lilies and math.random() < 0.56) or (not water_lilies and math.random() < 0.2)

    return {fields = {
        water_lilies=tostring(water_lilies),
        mese_lamps=tostring(mese_lamps),
        mese_lamps_if_mese_lamps=tostring(mese_lamps_if_mese_lamps),
        can_have_apples=tostring(can_have_apples),
        grasses=tostring(grasses),
        ferns=tostring(ferns),
        mushrooms=tostring(mushrooms),
        block_to_turn_into_ponds=block_to_turn_into_ponds,
        block_to_turn_into_ponds2=block_to_turn_into_ponds2,
        add_seed_based_ponds=tostring(add_seed_based_ponds),
        water_lilies_on_seed_based_ponds = tostring(water_lilies_on_seed_based_ponds)
    }}
end

local function make_pretty_forest(pos)

    if minetest.get_node(pos).name ~= "randungeon:pretty_forest" then
        print("oh noes! pos: " .. minetest.pos_to_string(pos))
    end
    
    local metadata = minetest.get_meta(pos):to_table().fields
    local water_lilies = minetest.is_yes(metadata.water_lilies)
    local mese_lamps = minetest.is_yes(metadata.mese_lamps)
    local mese_lamps_if_mese_lamps = minetest.is_yes(metadata.mese_lamps_if_mese_lamps)
    local can_have_apples = minetest.is_yes(metadata.can_have_apples)
    local grasses = minetest.is_yes(metadata.grasses)
    local ferns = minetest.is_yes(metadata.ferns)
    local mushrooms = minetest.is_yes(metadata.mushrooms)
    local block_to_turn_into_ponds = metadata.block_to_turn_into_ponds or ""
    local block_to_turn_into_ponds2 = metadata.block_to_turn_into_ponds2 or ""
    local add_seed_based_ponds = minetest.is_yes(metadata.add_seed_based_ponds)
    local chance_for_water_lilies_on_seed_based_ponds = minetest.is_yes(metadata.water_lilies_on_seed_based_ponds) and (math.random() * 1/9) or 0

    local node_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name
    local node_below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name

    if TESTING_CAVES or mese_lamps_if_mese_lamps and minetest.find_node_near(pos, 20, {"default:meselamp"}) then
        mese_lamps = true
    end

    -- set dirt with grass (this'll be reverted if we are under water)
    minetest.set_node(pos, {name="default:dirt_with_grass"})

    -- make ponds
    local made_pond
    if add_seed_based_ponds and randungeon.pond_noise:get_3d(pos) > 0 then
        made_pond = make_pond(pos, chance_for_water_lilies_on_seed_based_ponds)
    elseif node_below == block_to_turn_into_ponds or node_below == block_to_turn_into_ponds2 then
        made_pond = make_pond(pos, chance_for_water_lilies_on_seed_based_ponds)
    end
    if made_pond then
        do end

    -- set mese lamp posts
    elseif math.random() < 1/25 and is_air(node_above) and mese_lamps then
        make_glowstick({x=pos.x, y=pos.y+1, z=pos.z})

    -- set tree
    elseif is_air(node_above) then
        if math.random() < 1/25 and #minetest.find_nodes_in_area({x=pos.x, y=pos.y+1, z=pos.z}, {x=pos.x, y=pos.y+8, z=pos.z}, {"air", "group:air"}) == 8 then
            default.grow_tree({x=pos.x, y=pos.y+1, z=pos.z}, (math.random() < 1/3) and can_have_apples)
        -- make grass
        elseif grasses and math.random() < 1/5 then
            make_grass({x=pos.x, y=pos.y+1, z=pos.z})
        -- make ferns
        elseif ferns and math.random() < 1/6.5 then
            make_fern({x=pos.x, y=pos.y+1, z=pos.z})
        -- make mushrooms
        elseif mushrooms and (math.random() < 1/6 and minetest.find_node_near(pos, 2, {"group:tree"})
                           or math.random() < 1/15 and minetest.get_node_light({x=pos.x, y=pos.y+1, z=pos.z}, 9000) == 0) then
            make_mushroom({x=pos.x, y=pos.y+1, z=pos.z})
        end

    -- set sand or gravel if under water
    elseif node_above == "default:water_source" or node_above == "randungeon:water_source" then
        if math.random() < 0.5 then
            minetest.set_node(pos, {name="default:sand"})
        else
            minetest.set_node(pos, {name="default:gravel"})
        end
        -- set water lilies on top of water
        if water_lilies and math.random() < 1/10 then
            make_waterlilie(pos)
        end

    -- for when it's ledged under stone:
    else
        minetest.set_node(pos, {name="default:dirt"})
    end
end

minetest.register_node("randungeon:pretty_forest", {
    groups = {not_in_creative_inventory = 1, make_nature_block = 1},
    tiles = {"default_grass.png"}
})

-- SWAMPY FOREST

local function make_metadata_for_swampy_forest(pos, cave_or_room_data)

    local water_lilies = false
    if math.random() < 0.65 then
        water_lilies = true
    end
    local mese_lamps = false
    if math.random() < 0.5 then
        mese_lamps = true
    end
    local dark_dirt = false
    if math.random() < 0.5 then
        dark_dirt = true
    end
    local mese_lamps_if_mese_lamps = false
    if math.random() < 0.7 then
        mese_lamps_if_mese_lamps = true
    end
    local ferns = false
    if dark_dirt or math.random() < 0.35 then
        ferns = true
    end
    local mushrooms = false
    if not ferns or math.random() < 0.5 then
        mushrooms = true
    end
    local trees = false
    if math.random() < 0.7 then
        trees = true
    end
    local has_crater = false
    local has_flattened_floor = cave_or_room_data.cave_floor and (cave_or_room_data.cave_floor > cave_or_room_data.center_pos.y - cave_or_room_data.radius)
    if (math.random() < 0.35 and not has_flattened_floor) or (math.random() < 0.08 and has_flattened_floor) then
        has_crater = true
    end

    return {fields = {
        water_lilies=tostring(water_lilies),
        mese_lamps=tostring(mese_lamps),
        dark_dirt=tostring(dark_dirt),
        mese_lamps_if_mese_lamps=tostring(mese_lamps_if_mese_lamps),
        ferns=tostring(ferns),
        mushrooms=tostring(mushrooms),
        trees=tostring(trees),
        has_crater=tostring(has_crater),
    }}
end

local function make_swampy_forest(pos)

    if minetest.get_node(pos).name ~= "randungeon:swampy_forest" then
        return
    end
    
    local metadata = minetest.get_meta(pos):to_table().fields
    local water_lilies = minetest.is_yes(metadata.water_lilies)
    local mese_lamps = minetest.is_yes(metadata.mese_lamps)
    local dark_dirt = minetest.is_yes(metadata.dark_dirt)
    local mese_lamps_if_mese_lamps = minetest.is_yes(metadata.mese_lamps_if_mese_lamps)
    local ferns = minetest.is_yes(metadata.ferns)
    local mushrooms = minetest.is_yes(metadata.mushrooms)
    local trees = minetest.is_yes(metadata.trees)
    local has_crater = minetest.is_yes(metadata.has_crater)

    local pos1 = {x=pos.x, y=pos.y, z=pos.z}
    local pos2 = {x=pos.x, y=pos.y+1, z=pos.z}
    local pos3 = {x=pos.x, y=pos.y+2, z=pos.z}
    local pos4 = {x=pos.x, y=pos.y+3, z=pos.z}
    local node1 = minetest.get_node(pos1).name
    local node2 = minetest.get_node(pos2).name

    if TESTING_CAVES or mese_lamps_if_mese_lamps and minetest.find_node_near(pos4, 20, {"default:meselamp"}) then
        mese_lamps = true
    end

    if minetest.registered_nodes[node2].groups.water then
        if dark_dirt and math.random() < 1/5 then
            minetest.set_node(pos1, {name="default:permafrost"})
        elseif math.random() < 0.5 then
            minetest.set_node(pos1, {name="default:mossycobble"})
        else
            minetest.set_node(pos1, {name="default:gravel"})
        end
        if water_lilies and math.random() < 1/15 then
            make_waterlilie(pos1)
        end
    
    elseif is_air(node2) or node2 == "default:water_flowing" then
        -- is water:
        local deep_water_is_possible = not is_air(minetest.get_node({x=pos2.x+1, y=pos2.y, z=pos2.z}).name)
                                   and not is_air(minetest.get_node({x=pos2.x-1, y=pos2.y, z=pos2.z}).name)
                                   and not is_air(minetest.get_node({x=pos2.x, y=pos2.y, z=pos2.z+1}).name)
                                   and not is_air(minetest.get_node({x=pos2.x, y=pos2.y, z=pos2.z-1}).name)
                                   and is_air(minetest.get_node(pos2).name)
        local shallow_water_is_possible = not is_air(minetest.get_node({x=pos1.x+1, y=pos1.y, z=pos1.z}).name)
                                      and not is_air(minetest.get_node({x=pos1.x-1, y=pos1.y, z=pos1.z}).name)
                                      and not is_air(minetest.get_node({x=pos1.x, y=pos1.y, z=pos1.z+1}).name)
                                      and not is_air(minetest.get_node({x=pos1.x, y=pos1.y, z=pos1.z-1}).name)

        -- try deeper water if it can't flow away
        if deep_water_is_possible and math.random() < 3/4 then
            minetest.set_node(pos2, {name="randungeon:water_source"})
            if dark_dirt and math.random() < 1/5 then
                minetest.set_node(pos1, {name="default:permafrost"})
            elseif math.random() < 0.5 then
                minetest.set_node(pos1, {name="default:mossycobble"})
            else
                minetest.set_node(pos1, {name="default:gravel"})
            end
            if water_lilies and math.random() < 1/15 then
                make_waterlilie(pos2)
            end
        -- try shallower water otherwise, e.g. for steeper terrain or crater
        elseif shallow_water_is_possible and not deep_water_is_possible and (has_crater and math.random() < 9/10 or math.random() < 0.5) then
            minetest.set_node(pos1, {name="randungeon:water_source"})
            if water_lilies and math.random() < 1/15 then
                make_waterlilie(pos1)
            end
        -- is land:
        elseif is_air(minetest.get_node(pos2).name) then
            local vegetation_pos = pos3
            if dark_dirt then
                minetest.set_node(pos1, {name="default:permafrost"})
                minetest.set_node(pos2, {name="default:permafrost_with_moss"})
                if is_air(minetest.get_node(pos3).name) and is_air(minetest.get_node(pos4).name) then
                    minetest.set_node(pos2, {name="default:permafrost"})
                    minetest.set_node(pos3, {name="default:permafrost_with_moss"})
                    vegetation_pos = pos4
                end
            else
                minetest.set_node(pos1, {name="default:dirt"})
                minetest.set_node(pos2, {name="default:dirt_with_rainforest_litter"})
                if is_air(minetest.get_node(pos3).name) and is_air(minetest.get_node(pos4).name) then
                    minetest.set_node(pos2, {name="default:dirt"})
                    minetest.set_node(pos3, {name="default:dirt_with_rainforest_litter"})
                    vegetation_pos = pos4
                end
            end
            -- vegetation:
            if is_air(minetest.get_node(pos4).name) then
                -- make ferns
                if ferns and ((dark_dirt and math.random() < 1/3) or (not dark_dirt and math.random() < 1/7)) then
                    make_fern(pos4)
                -- make mushrooms
                elseif mushrooms and (dark_dirt and math.random() < 1/15) or (not dark_dirt and math.random() < 1/5) then
                    make_mushroom(pos4)
                -- make trees
                elseif (math.random() < 1/20 or trees and math.random() < 1/3)
                       and #minetest.find_nodes_in_area(pos4, {x=pos4.x, y=pos4.y+14, z=pos4.z}, {"air", "group:air"}) == 15 then
                    default.grow_jungle_tree(pos4, false)
                    if dark_dirt then
                        -- dark dirt version has pine wood
                        for _, pos in ipairs(minetest.find_nodes_in_area({x=pos4.x-1, y=pos4.y-3, z=pos4.z-1}, {x=pos4.x+1, y=pos4.y+14, z=pos4.z+1}, {"default:jungletree"})) do
                            minetest.set_node(pos, {name="default:pine_tree"})
                        end
                        for _, pos in ipairs(minetest.find_nodes_in_area({x=pos4.x-5, y=pos4.y+5, z=pos4.z-5}, {x=pos4.x+5, y=pos4.y+15, z=pos4.z+5}, {"default:jungleleaves"})) do
                            minetest.set_node(pos, {name="default:pine_needles"})
                        end
                    else
                        -- other version has apple wood
                        for _, pos in ipairs(minetest.find_nodes_in_area({x=pos4.x-1, y=pos4.y-3, z=pos4.z-1}, {x=pos4.x+1, y=pos4.y+14, z=pos4.z+1}, {"default:jungletree"})) do
                            minetest.set_node(pos, {name="default:tree"})
                        end
                        for _, pos in ipairs(minetest.find_nodes_in_area({x=pos4.x-5, y=pos4.y+5, z=pos4.z-5}, {x=pos4.x+5, y=pos4.y+15, z=pos4.z+5}, {"default:jungleleaves"})) do
                            minetest.set_node(pos, {name="default:leaves"})
                        end
                    end
                -- make glowing light
                elseif mese_lamps and math.random() < 1/25 then
                    make_glowstick(pos4)
                end
            end
        end
    
    -- for when it's ledged under stone:
    else
        if dark_dirt then
            minetest.set_node(pos1, {name="default:permafrost"})
        else
            minetest.set_node(pos1, {name="default:dirt"})
        end
    end
end

minetest.register_node("randungeon:swampy_forest", {
    groups = {not_in_creative_inventory = 1, make_nature_block = 1},
    tiles = {"default_grass.png"}
})


-- GENERAL FUNCTIONS

randungeon.nature_types = {
    ["randungeon:pretty_forest"] = {
        name = "pretty forest",
        caves_weight = 0.5,
        pools_weight = 0.5,
        pool_deph = 1,
        pool_bassin = nil,
        make_metadata = make_metadata_for_pretty_forest,
        make_nature = make_pretty_forest,
    },
    ["randungeon:swampy_forest"] = {
        name = "swampy forest",
        caves_weight = 0.5,
        pools_weight = 0.5,
        pool_deph = 3,
        pool_bassin = nil,
        make_metadata = make_metadata_for_swampy_forest,
        make_nature = make_swampy_forest
    }
}

randungeon.nature_functions = {}

local function get_random_cave_nature_type()
    local total_weight = 0
    for _, data in pairs(randungeon.nature_types) do
        total_weight = total_weight + data.caves_weight
    end
    local chosen_weight = math.random() * total_weight
    local weight_so_far = 0
    for name, data in pairs(randungeon.nature_types) do
        weight_so_far = weight_so_far + data.caves_weight
        if weight_so_far >= chosen_weight then
            return name
        end
    end
end

local function get_random_pool_nature_type()
    local total_weight = 0
    for _, data in pairs(randungeon.nature_types) do
        total_weight = total_weight + data.pools_weight
    end
    local chosen_weight = math.random() * total_weight
    local weight_so_far = 0
    for name, data in pairs(randungeon.nature_types) do
        weight_so_far = weight_so_far + data.pools_weight
        if weight_so_far >= chosen_weight then
            return name
        end
    end
end

local function make_nature(pos)
    local nature_type = minetest.get_node(pos).name
    randungeon.nature_types[nature_type].make_nature(pos)
end

local function make_nature_in_area(area_border1, area_border2)
    local nature_blocks_in_area = minetest.find_nodes_in_area(area_border1, area_border2, {"group:make_nature_block"})
    while #nature_blocks_in_area > 0 do
        local pos = table.remove(nature_blocks_in_area, math.random(1, #nature_blocks_in_area))
        make_nature(pos)
    end
end

local function make_metadata_for_nature(pos, nature_type, cave_or_room_data)
    return randungeon.nature_types[nature_type].make_metadata(pos, cave_or_room_data)
end

randungeon.nature_functions.get_random_cave_nature_type = get_random_cave_nature_type
randungeon.nature_functions.get_random_pool_nature_type = get_random_pool_nature_type
randungeon.nature_functions.make_nature = make_nature
randungeon.nature_functions.make_nature_in_area = make_nature_in_area
randungeon.nature_functions.make_metadata_for_nature = make_metadata_for_nature

return {
    make_metadata_for_nature = make_metadata_for_nature,
    make_nature = make_nature,
    make_nature_in_area = make_nature_in_area,
    get_random_cave_nature_type = get_random_cave_nature_type,
    get_random_pool_nature_type = get_random_pool_nature_type,
}
