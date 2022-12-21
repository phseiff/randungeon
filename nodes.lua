--
-- Special nodes
--

-- teporary stand in block for air in dungeons, used during dungeon generation
minetest.register_node("dungeon_watch:dungeon_air", {
	groups={not_in_creative_inventory = 1}
})

-- glowing air
minetest.register_node("dungeon_watch:air_glowing", {
	description = "Glowing Air",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {snappy = 3, flammable = 2, not_in_creative_inventory = 1},
	light_source = default.LIGHT_MAX,
	buildable_to = true,
	pointable = false
})

-- booskshelfes in dungeons have books on all sides and no inventory
minetest.register_node("dungeon_watch:bookshelf", {
	description = "Bookshelf (multisided one; drops normal bookshelf)",
	tiles = {"default_wood.png", "default_wood.png", "default_bookshelf.png"},
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, not_in_creative_inventory = 1},
	drop = "default:bookshelf",
	sounds = default.node_sound_wood_defaults()
})

-- blocks that mark parts in dungeon rooms


minetest.register_node("dungeon_watch:ceiling", {
	description = "Ceiling Block\n(exemplary/ for debugging)",
	tiles = {"default_stone.png^dungeon_watch_block_ceiling.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("dungeon_watch:wall_type_2", {
	description = "Upper Wall Block\n(exemplary/ for debugging)",
	tiles = {"default_stone_brick.png^dungeon_watch_block_wall_type_2.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("dungeon_watch:wall_type_1", {
	description = "Lower Wall Block\n(exemplary/ for debugging)",
	tiles = {"default_stone_block.png^dungeon_watch_block_wall_type_1.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("dungeon_watch:floor", {
	description = "Floor Block\n(exemplary/ for debugging)",
	tiles = {"default_pine_wood.png^dungeon_watch_block_floor.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("dungeon_watch:pillar", {
	description = "Pillar Block\n(exemplary/ for debugging)",
	tiles = {"default_cobble.png^dungeon_watch_block_pillar.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("dungeon_watch:example_treasure", {
	description = "Treasure Block\n\n(examplary; replace this with whatever you\nwant to be retrievable from the bottom of the\ndungeon)",
	tiles = {"default_diamond.png"},
	drawtype = "plantlike",
	is_ground_content = false,
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = math.floor(default.LIGHT_MAX / 2),
	selection_box = {
		type = "fixed",
		fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, 2 / 16, 6 / 16},
	},
})

-- DUNGEON WATER

-- special water source that only flows one block far
local dungeon_water_source = {}
for key, value in pairs(minetest.registered_nodes["default:water_source"]) do
	dungeon_water_source[key] = value
end
dungeon_water_source["liquid_alternative_flowing"] = "dungeon_watch:water_flowing"
dungeon_water_source["liquid_alternative_source"] = "dungeon_watch:water_source"
dungeon_water_source["liquid_range"] = 1
dungeon_water_source["description"] = "Water Source (with 1-block-range flow limit)\n(becomes normal water with bucket)"
dungeon_water_source["groups"] = {water = 3, liquid = 3, cools_lava = 1, not_in_creative_inventory = 1}
minetest.register_node("dungeon_watch:water_source", dungeon_water_source)

-- flowing version of it
local dungeon_water_flowing = {}
for key, value in pairs(minetest.registered_nodes["default:water_flowing"]) do
	dungeon_water_flowing[key] = value
end
dungeon_water_flowing["liquid_alternative_flowing"] = "dungeon_watch:water_flowing"
dungeon_water_flowing["liquid_alternative_source"] = "dungeon_watch:water_source"
dungeon_water_flowing["liquid_range"] = 1
minetest.register_node("dungeon_watch:water_flowing", dungeon_water_flowing)

-- make it so it gives a normal water bucket when collected via bucket
if minetest.get_modpath("bucket") then
	bucket.liquids["dungeon_watch:water_source"] = {
		source = "dungeon_watch:water_source",
		flowing = "dungeon_watch:water_flowing",
		itemname = "bucket:bucket_water",
	}
end

-- DUNGEON LAVA

-- special lava source that doesn_t ignite things
local dungeon_lava_source = {}
for key, value in pairs(minetest.registered_nodes["default:lava_source"]) do
	dungeon_lava_source[key] = value
end
dungeon_lava_source["liquid_alternative_flowing"] = "dungeon_watch:lava_flowing"
dungeon_lava_source["liquid_alternative_source"] = "dungeon_watch:lava_source"
dungeon_lava_source["description"] = "Lava Source (but non-igniting)"
dungeon_lava_source["groups"] = {lava = 3, liquid = 2, not_in_creative_inventory = 1}
minetest.register_node("dungeon_watch:lava_source", dungeon_lava_source)

-- flowing version of it
local dungeon_lava_flowing = {}
for key, value in pairs(minetest.registered_nodes["default:lava_flowing"]) do
	dungeon_lava_flowing[key] = value
end
dungeon_lava_flowing["liquid_alternative_flowing"] = "dungeon_watch:lava_flowing"
dungeon_lava_flowing["liquid_alternative_source"] = "dungeon_watch:lava_source"
-- dungeon_lava_flowing["groups"] = {lava = 3, liquid = 2, not_in_creative_inventory = 1, igniter = 1}
minetest.register_node("dungeon_watch:lava_flowing", dungeon_lava_flowing)

-- make it so it gives a normal lava bucket when collected via bucket
if minetest.get_modpath("bucket") then
	bucket.liquids["dungeon_watch:lava_source"] = {
		source = "dungeon_watch:lava_source",
		flowing = "dungeon_watch:lava_flowing",
		itemname = "bucket:bucket_lava",
	}
end