--
-- Helper Functions
--

local mod_path = minetest.get_modpath("randungeon")

local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number

local dungeon_building_functions = dofile(mod_path.."/build_dungeon_from_blocks.lua")
local make_dungeon = dungeon_building_functions.make_dungeon

--
-- Code to naturally generate dungeons into the world
--

local settings = minetest.settings

local generation_enabled = settings:get_bool("randungeon_enable_natural_dungeon_generation") ~= false
local enabled_worlds = string.split(settings:get("randungeon_worlds_with_nat_dungeon_generation_enabled") or "", ",")
local disabled_worlds = string.split(settings:get("randungeon_worlds_with_nat_dungeon_generation_disabled") or "", ",")
local dungeon_chance = (settings:get("randungeon_dungeon_chance") or 10) / 100

local world_name = minetest.get_worldpath():match("([^/]+)$")

if contains(enabled_worlds, world_name) and contains(disabled_worlds, world_name) then
    generation_enabled = generation_enabled
elseif contains(enabled_worlds, world_name) then
    generation_enabled = true
elseif contains(disabled_worlds, world_name) then
    generation_enabled = false
else
    generation_enabled = generation_enabled
end

if generation_enabled then
    -- show dungeon treasure to creative inv if naturaldungeon generation is enabled
    minetest.registered_nodes["randungeon:dungeon_treasure"].groups.not_in_creative_inventory = nil

    -- make dungeons spawn naturally
    minetest.register_on_generated(function(minpos, maxpos, blockseed)
        if randungeon.TURN_OFF_NATURAL_DUNGEO_GENERATION then
            return -- <- option for other mods to deactivate natural dungeon generation
        end
        local n = 200 -- every 200 blocks we can (!!) build a dungeon
        minpos.x = math.ceil(minpos.x / n) * n
        minpos.z = math.ceil(minpos.z / n) * n
        if maxpos.y < 0 or minpos.y > 0 then
            return
        end
        for x = minpos.x, maxpos.x, n do
            for z = minpos.z, maxpos.z, n do
                local pos = {x=x, y=0, z=z}
                if math.random() < dungeon_chance then
                    local pos = {x=x, y=200, z=z}
                    local levels
                    local rand = math.random()
                    if rand < 0.1 then
                        levels = 50 -- 10% chance
                    elseif rand < 0.3 then
                        levels = 30 -- 20% chance
                    elseif rand < 0.6 then
                        levels = 20 -- 30% chance
                    else
                        levels = 10 -- 40% chance
                    end
                    make_dungeon(
                        pos, 10, -- pos and width
                        nil, nil, nil, nil, nil, nil, -- materials
                        12, -- dungeon_deph
                        true, --- rim_sealed
                        levels, -- dungeon levels
                        100, 250, -- bottom deph and top deph
                        true, -- random materials
                        30, -- cave_percentage
                        false, -- light_up_corridors , treasure_block, dungeon_id
                        true, -- gold_pools
                        "randungeon:dungeon_treasure", -- treasure block
                        nil -- dungeon id
                    )
                end
            end
        end
    end)
end
