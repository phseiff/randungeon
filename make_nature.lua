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

local function make_waterlilie(pos)
    for y = 1, 60 do
        local block = minetest.get_node({x=pos.x, y=pos.y+y, z=pos.z}).name
        if block == "air" then
            minetest.set_node({x=pos.x, y=pos.y+y, z=pos.z}, {name="flowers:waterlily_waving", param2=math.random(0, 3)})
        end
        if block ~= "default:water_source" and block ~= "randungeon:water_source" then
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

local TESTING_CAVES = false

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

local function make_metadata_for_pretty_forest()
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

    return {fields = {
        water_lilies=tostring(water_lilies),
        mese_lamps=tostring(mese_lamps),
        mese_lamps_if_mese_lamps=tostring(mese_lamps_if_mese_lamps),
        can_have_apples=tostring(can_have_apples),
        grasses=tostring(grasses),
        ferns=tostring(ferns),
        mushrooms=tostring(mushrooms)
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

    local node_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name

    if TESTING_CAVES or mese_lamps_if_mese_lamps and minetest.find_node_near(pos, 20, {"default:meselamp"}) then
        mese_lamps = true
    end

    -- set dirt with grass (this'll be reverted if we are under water)
    minetest.set_node(pos, {name="default:dirt_with_grass"})

    -- set mese lamp posts
    if math.random() < 1/25 and node_above == "air" and mese_lamps then
        make_glowstick({x=pos.x, y=pos.y+1, z=pos.z})

    -- set tree
    elseif node_above == "air" then
        if math.random() < 1/25 and #minetest.find_nodes_in_area({x=pos.x, y=pos.y+1, z=pos.z}, {x=pos.x, y=pos.y+8, z=pos.z}, {"air"}) == 8 then
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
    groups = {not_in_creative_inventory = 1, make_nature_block = 1}
})

-- SWAMPY FOREST

local function make_metadata_for_swampy_forest()

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
    if math.random() < 0.3 then
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
    
    elseif node2 == "air" or node2 == "default:water_flowing" then
        -- is water:
        local deep_water_is_possible = minetest.get_node({x=pos2.x+1, y=pos2.y, z=pos2.z}).name ~= "air" and minetest.get_node({x=pos2.x-1, y=pos2.y, z=pos2.z}).name ~= "air"
                                       and minetest.get_node({x=pos2.x, y=pos2.y, z=pos2.z+1}).name ~= "air" and minetest.get_node({x=pos2.x, y=pos2.y, z=pos2.z-1}).name ~= "air"
                                       and minetest.get_node(pos2).name == "air"
        local shallow_water_is_possible = minetest.get_node({x=pos1.x+1, y=pos1.y, z=pos1.z}).name ~= "air" and minetest.get_node({x=pos1.x-1, y=pos1.y, z=pos1.z}).name ~= "air"
                                          and minetest.get_node({x=pos1.x, y=pos1.y, z=pos1.z+1}).name ~= "air" and minetest.get_node({x=pos1.x, y=pos1.y, z=pos1.z-1}).name ~= "air"

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
        elseif minetest.get_node(pos2).name == "air" then
            local vegetation_pos = pos3
            if dark_dirt then
                minetest.set_node(pos1, {name="default:permafrost"})
                minetest.set_node(pos2, {name="default:permafrost_with_moss"})
                if minetest.get_node(pos3).name == "air" and minetest.get_node(pos4).name == "air" then
                    minetest.set_node(pos2, {name="default:permafrost"})
                    minetest.set_node(pos3, {name="default:permafrost_with_moss"})
                    vegetation_pos = pos4
                end
            else
                minetest.set_node(pos1, {name="default:dirt"})
                minetest.set_node(pos2, {name="default:dirt_with_rainforest_litter"})
                if minetest.get_node(pos3).name == "air" and minetest.get_node(pos4).name == "air" then
                    minetest.set_node(pos2, {name="default:dirt"})
                    minetest.set_node(pos3, {name="default:dirt_with_rainforest_litter"})
                    vegetation_pos = pos4
                end
            end
            -- vegetation:
            if minetest.get_node(pos4).name == "air" then
                -- make ferns
                if ferns and ((dark_dirt and math.random() < 1/3) or (not dark_dirt and math.random() < 1/7)) then
                    make_fern(pos4)
                -- make mushrooms
                elseif mushrooms and (dark_dirt and math.random() < 1/15) or (not dark_dirt and math.random() < 1/5) then
                    make_mushroom(pos4)
                -- make trees
                elseif (math.random() < 1/20 or trees and math.random() < 1/3)
                       and #minetest.find_nodes_in_area(pos4, {x=pos4.x, y=pos4.y+14, z=pos4.z}, {"air"}) == 15 then
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
    groups = {not_in_creative_inventory = 1, make_nature_block = 1}
})


-- GENERAL FUNCTIONS

randungeon.nature_types = {
    ["randungeon:pretty_forest"] = {
        caves_weight = 0.5,
        pools_weight = 0.5,
        pool_deph = 1,
        pool_bassin = nil,
        make_metadata = make_metadata_for_pretty_forest,
        make_nature = make_pretty_forest,
    },
    ["randungeon:swampy_forest"] = {
        caves_weight = 0.5,
        pools_weight = 0.5,
        pool_deph = 3,
        pool_bassin = nil,
        make_metadata = make_metadata_for_swampy_forest,
        make_nature = make_swampy_forest
    }
}

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

local function make_metadata_for_nature(pos, nature_type)
    return randungeon.nature_types[nature_type].make_metadata(pos)
end

return {
    make_metadata_for_nature = make_metadata_for_nature,
    make_nature = make_nature,
    make_nature_in_area = make_nature_in_area,
    get_random_cave_nature_type = get_random_cave_nature_type,
    get_random_pool_nature_type = get_random_pool_nature_type,
}
