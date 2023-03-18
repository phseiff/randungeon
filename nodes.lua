--
-- Special nodes
--

-- teporary stand in block for air in dungeons, used during dungeon generation
minetest.register_node("randungeon:dungeon_air", {
	description = "Dungeon Air (used by dungeon generator during genertion)",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	floodable = true,
	groups = {not_in_creative_inventory = 1},
	drop = {},
	buildable_to = true,
	pointable = false
})

-- glowing air
minetest.register_node("randungeon:air_glowing", {
	description = "Glowing Air",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	floodable = true,
	groups = {not_in_creative_inventory = 1},
	drop = {},
	light_source = default.LIGHT_MAX,
	buildable_to = true,
	pointable = false
})

-- booskshelfes in dungeons have books on all sides and no inventory
minetest.register_node("randungeon:bookshelf", {
	description = "Bookshelf (multisided one; drops normal bookshelf)",
	tiles = {"default_wood.png", "default_wood.png", "default_bookshelf.png"},
	is_ground_content = false,
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, not_in_creative_inventory = 1},
	drop = "default:bookshelf",
	sounds = default.node_sound_wood_defaults()
})

-- permafrost with snow
minetest.register_node("randungeon:permafrost_with_snow", {
	description = "Permafrost with Snow",
	tiles = {"default_snow.png", "default_permafrost.png",
		{name = "default_permafrost.png^default_snow_side.png",
			tileable_vertical = false}},
	groups = {cracky = 3, snowy = 1, not_in_creative_inventory = 1},
	drop = "default:permafrost",
	sounds = default.node_sound_dirt_defaults({
		footstep = {name = "default_snow_footstep", gain = 0.2},
	}),
})

-- cobble stone that doesn't get turned into mossy cobble
minetest.register_node("randungeon:unmossy_cobble", {
	description = "Moss-Resistant Cobblestone",
	tiles = {"default_cobble.png"},
	is_ground_content = false,
	groups = {cracky = 3, stone = 2, not_in_creative_inventory = 1},
	drop = "default:cobble",
	sounds = default.node_sound_stone_defaults(),
})

-- blocks that mark parts in dungeon rooms


minetest.register_node("randungeon:ceiling", {
	description = "Ceiling Block\n(exemplary/ for debugging)",
	tiles = {"default_stone.png^randungeon_block_ceiling.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("randungeon:wall_type_2", {
	description = "Upper Wall Block\n(exemplary/ for debugging)",
	tiles = {"default_stone_brick.png^randungeon_block_wall_type_2.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("randungeon:wall_type_1", {
	description = "Lower Wall Block\n(exemplary/ for debugging)",
	tiles = {"default_stone_block.png^randungeon_block_wall_type_1.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("randungeon:floor", {
	description = "Floor Block\n(exemplary/ for debugging)",
	tiles = {"default_pine_wood.png^randungeon_block_floor.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("randungeon:pillar", {
	description = "Pillar Block\n(exemplary/ for debugging)",
	tiles = {"default_cobble.png^randungeon_block_pillar.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = default.LIGHT_MAX,
})


minetest.register_node("randungeon:example_treasure", {
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


minetest.register_node("randungeon:dungeon_treasure", {
	description = "Treasure from the Deep\n(uninitialized; place somewhere to give it its position info)",
	tiles = {"default_diamond.png^[colorize:#000000:150"},
	drawtype = "plantlike",
	inventory_image = "default_diamond.png^[colorize:#000000:150",
	is_ground_content = false,
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	-- easy to dig to make it possible to journey into the dungeon by hand, and not in creative inv unless dungeon generation is enabled:
	groups = {cracky = 3, not_in_creative_inventory = 1},
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	light_source = math.floor(default.LIGHT_MAX / 2),
	selection_box = {
		type = "fixed",
		fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, 2 / 16, 6 / 16},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("pos_info", minetest.pos_to_string(pos))
	end,
	preserve_metadata = function(pos, oldnode, oldmeta, drops)
		local meta = drops[1]:get_meta()
		meta:set_string("pos_info", oldmeta.pos_info)
		meta:set_string("description", "Treasure from the Deep (found at " .. oldmeta.pos_info .. ")")
	end,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local pos_info = itemstack:get_meta():get_string("pos_info")
		if pos_info == "" then
			pos_info = minetest.pos_to_string(pos)
		end
		meta:set_string("pos_info", pos_info)
		meta:set_string("infotext", "Discoverership of Dungeon at pos " .. pos_info)
	end
})

-- DUNGEON WATER

-- special water source that only flows one block far
local dungeon_water_source = {}
for key, value in pairs(minetest.registered_nodes["default:water_source"]) do
	dungeon_water_source[key] = value
end
dungeon_water_source.liquid_alternative_flowing = "randungeon:water_flowing"
dungeon_water_source.liquid_alternative_source = "randungeon:water_source"
dungeon_water_source.liquid_range = 1
dungeon_water_source.description = "Water Source (with 1-block-range flow limit)\n(becomes normal water with bucket)"
dungeon_water_source.groups = {water = 3, liquid = 3, cools_lava = 1, not_in_creative_inventory = 1}
minetest.register_node("randungeon:water_source", dungeon_water_source)

-- flowing version of it
local dungeon_water_flowing = {}
for key, value in pairs(minetest.registered_nodes["default:water_flowing"]) do
	dungeon_water_flowing[key] = value
end
dungeon_water_flowing.liquid_alternative_flowing = "randungeon:water_flowing"
dungeon_water_flowing.liquid_alternative_source = "randungeon:water_source"
dungeon_water_flowing.liquid_range = 1
minetest.register_node("randungeon:water_flowing", dungeon_water_flowing)

-- make it so it gives a normal water bucket when collected via bucket
if minetest.get_modpath("bucket") then
	bucket.liquids["randungeon:water_source"] = {
		source = "randungeon:water_source",
		flowing = "randungeon:water_flowing",
		itemname = "bucket:bucket_water",
	}
end

-- DUNGEON LAVA

-- special lava source that doesn_t ignite things
local dungeon_lava_source = {}
for key, value in pairs(minetest.registered_nodes["default:lava_source"]) do
	dungeon_lava_source[key] = value
end
dungeon_lava_source.liquid_alternative_flowing = "randungeon:lava_flowing"
dungeon_lava_source.liquid_alternative_source = "randungeon:lava_source"
dungeon_lava_source.description = "Lava Source (but non-igniting)"
dungeon_lava_source.groups = {lava = 3, liquid = 2, not_in_creative_inventory = 1}
minetest.register_node("randungeon:lava_source", dungeon_lava_source)

-- flowing version of it
local dungeon_lava_flowing = {}
for key, value in pairs(minetest.registered_nodes["default:lava_flowing"]) do
	dungeon_lava_flowing[key] = value
end
dungeon_lava_flowing.liquid_alternative_flowing = "randungeon:lava_flowing"
dungeon_lava_flowing.liquid_alternative_source = "randungeon:lava_source"
-- dungeon_lava_flowing.groups = {lava = 3, liquid = 2, not_in_creative_inventory = 1, igniter = 1}
minetest.register_node("randungeon:lava_flowing", dungeon_lava_flowing)

-- make it so it gives a normal lava bucket when collected via bucket
if minetest.get_modpath("bucket") then
	bucket.liquids["randungeon:lava_source"] = {
		source = "randungeon:lava_source",
		flowing = "randungeon:lava_flowing",
		itemname = "bucket:bucket_lava",
	}
end