
--
-- Modding Interface
--

randungeon = {}

-- list of functions with call signatures like function(pos, dungeon_maps, materials, room_styles) that will be called before the dungeon is build
-- and that can modify the map, materials, room styles, staircase&pillar height etx of individual or multiple levels.
-- This dict exists to allow other mods to add functions that modify how dungeons are build.
randungeon.dungeon_prebuild_modifications = {}

-- list of functions with call signatures like function(pos, dungeon_maps, materials, room_styles) that will be called after the dungeon is build
-- and that can do block modifications in the already-generated area based on information from the world and the provided tables.
-- This dict exists to allow other mods to add functions that modify how dungeons are build.
randungeon.dungeon_postbuild_modifications = {}

--
-- Include parts of the mod defined elsewhere
--

local mod_path = minetest.get_modpath("randungeon")

-- Dungeon Map Generator
local generate_dungeon_map = dofile(mod_path.."/make_dungeon_map.lua").generate_dungeon_map

-- Register Helper Blocks
dofile(mod_path.."/nodes.lua")

-- Helper Functions For Block Comparisons
local helper_functions = dofile(mod_path.."/helpers.lua")
local contains = helper_functions.contains
local intersects = helper_functions.intersects
local bool_to_number = helper_functions.bool_to_number
local number_to_bool = helper_functions.number_to_bool

-- Dungeon Building Functions
local dungeon_building_functions = dofile(mod_path.."/build_dungeon_from_blocks.lua")
local make_dungeon_tile = dungeon_building_functions.make_dungeon_tile
local make_dungeon_level = dungeon_building_functions.make_dungeon_level
local make_dungeon = dungeon_building_functions.make_dungeon

-- Natural Dungeon Generation
dofile(mod_path.."/natural_generation.lua")

--
-- Helper Items
--

local selector_description = "\n\n(Used for 'Make Dungeon (unrand)' inventory tab;\nsee manual for further explanation.)"

minetest.register_craftitem("randungeon:selected_frame", {
	description = "Make Dungeon (unrand) Direction Selector" .. selector_description,
	inventory_image = "randungeon_selected_frame.png"
})

minetest.register_craftitem("randungeon:bridge_type_0", {
	description = "Bridge Type Selector (walls & roof present)" .. selector_description,
	groups = {bridge_type_selector = 1},
	inventory_image = "randungeon_inv_bg_color.png^randungeon_bridge_type_0.png"
})

minetest.register_craftitem("randungeon:bridge_type_1", {
	description = "Bridge Type Selector (lower wall part & roof present)" .. selector_description,
	groups = {bridge_type_selector = 1},
	inventory_image = "randungeon_inv_bg_color.png^randungeon_bridge_type_1.png"
})

minetest.register_craftitem("randungeon:bridge_type_2", {
	description = "Bridge Type Selector (lower wall part present)" .. selector_description,
	groups = {bridge_type_selector = 1},
	inventory_image = "randungeon_inv_bg_color.png^randungeon_bridge_type_2.png"
})

minetest.register_craftitem("randungeon:bridge_type_3", {
	description = "Bridge Type Selector (no walls or roof present)" .. selector_description,
	groups = {bridge_type_selector = 1},
	inventory_image = "randungeon_inv_bg_color.png^randungeon_bridge_type_3.png"
})

-- Manual

local readme_file = io.open(mod_path.."/README.md", "rb")
local readme_text = readme_file:read("*a")
readme_text = string.gsub(readme_text, "textures/", "")
readme_file:close()
local dungeon_manual_formspec = "size[8,10]" ..
				                --"scroll_container[0.3,0;9.5,10.8;manual_scrollbar;vertical]" .. 
				                -- md2f.md2ff(0,0,7.5,25, mod_path.."/README.md") ..
								md2f.md2f(0.3,0,8,10.8, readme_text) ..
				                --"scroll_container_end[]" ..
				                --"scrollbar[7.6,0;0.2,9;vertical;manual_scrollbar;0]" ..
								"button[0,6.3;8,8;exit_manual;Close]"

-- print(md2f.md2ff(0,0,8,18, mod_path.."/README.md"))

minetest.register_craftitem("randungeon:manual", {
	description = "Manual for Dungeon Generation Mod\n(left-click to read)",
	inventory_image = "randungeon_manual.png",
	groups = {book = 1},
	on_use = function(itemstack, user, pointed_thing)
		minetest.show_formspec(user:get_player_name(), "randungeon:manual", dungeon_manual_formspec)
	end
})

--
-- Inventory Stuff
--

sfinv.register_page("randungeon:make_dungeon_level", {
    title = "Make Dungeon",
    get = function(self, player, context)
		local meta = player:get_meta()
		if not meta:get("cave_percentage") then
			local text = "Click block with a Dungeon Maker Stick to initialize this form!"
			return sfinv.make_formspec(player, context, "label[0.375,0.5;" .. minetest.formspec_escape(text) .. "]", true)
		end
        return sfinv.make_formspec(player, context,

				"field[0.3,0.6;4,0.3;dungeon_width;" ..
				minetest.formspec_escape("dungeon width / 10:") ..";" .. tostring(meta:get("dungeon_width")) .. "]"..

				"field[0.3,1.6;4,0.3;dungeon_deph;" ..
				minetest.formspec_escape("dist between dungeon levels:") ..";" .. tostring(meta:get("dungeon_deph")) .. "]"..

				"field[0.3,2.6;4,0.3;dungeon_levels;" ..
				minetest.formspec_escape("amount of dungeon levels:") ..";" .. tostring(meta:get("dungeon_levels")) .. "]"..

				"field[0.3,3.6;4,0.3;dungeon_bottom_deph;" ..
				minetest.formspec_escape("height of bottom pillars:") ..";" .. tostring(meta:get("dungeon_bottom_deph")) .. "]"..

				"field[0.3,4.6;4,0.3;dungeon_top_deph;" ..
				minetest.formspec_escape("max height of top staircases:") ..";" .. tostring(meta:get("dungeon_top_deph")) .. "]"..


				"field[4.3,0.6;5,0.3;cave_percentage;" ..
				minetest.formspec_escape("max % of blocks taken up by bubble caves:") .. ";" .. tostring(meta:get("cave_percentage")) .. "]"..

				"checkbox[4.3,0.8;light_up_corridors;" ..
				minetest.formspec_escape("light up corridors & caves") .. ";"  .. tostring(number_to_bool(meta:get_int("light_up_corridors"))) .. "]" ..

				"checkbox[4.3,1.5;gold_pools;" ..
				minetest.formspec_escape("gold pools on lowest level") .. ";"  .. tostring(number_to_bool(meta:get_int("gold_pools"))) .. "]" ..

				"label[4.3,2.3;" .. minetest.formspec_escape("build treasure room with treasure block:\n"
			    .. "(leave empty to not create\ntreasure room on lowest\nlevel)") .. "]"..
				"list[current_player;dungeon_treasure_block;7,2.8;1,1;]" ..

				"button[4,3;3.7,3.4;open_manual;Open Manual]" ..
				"item_image[4.4,4.1;0.8,0.8;randungeon:manual]" ..

				"", true)
    end,
	is_in_nav = function(self, player, context)
		return minetest.is_creative_enabled(player:get_player_name())
	end
})

sfinv.register_page("randungeon:make_dungeon_tile", {
    title = "Make Dungeon (unrand)",
    get = function(self, player, context)
		local meta = player:get_meta()
		if not meta:get("dungeon_width") then
			local text = "Click block with a Dungeon Maker Stick to initialize this form!"
			return sfinv.make_formspec(player, context, "label[0.375,0.5;" .. minetest.formspec_escape(text) .. "]", true)
		end
        return sfinv.make_formspec(player, context,
				"image[0,0;1,1;randungeon_ceiling.png]"..
				"image[0,1;1,1;randungeon_wall_2.png]"..
				"image[0,2;1,1;randungeon_wall_1.png]"..
				"image[0,3;1,1;randungeon_floor.png]"..
				"image[0,4;1,1;randungeon_pillars.png]"..
				"list[current_player;dungeon_materials;1,0;1,5;]"..

				"image[2.6,3;1,1;randungeon_bridge_icon.png]"..
				"image[3.6,3;1,1;randungeon_bridge_type_0.png]"..
				"list[current_player;bridge_type;3.6,3;1,1]"..
				
				"image[4.08,1.2;0.8,0.8;randungeon_x_plus.png]  list[current_player;dungeon_x_plus;4,1;1,1;]"..
				"image[6.08,1.2;0.8,0.8;randungeon_x_minus.png]  list[current_player;dungeon_x_minus;6,1;1,1;]"..
				"image[5.08,0.2;0.8,0.8;randungeon_z_plus.png]  list[current_player;dungeon_z_plus;5,0;1,1;]"..
				"image[5.08,2.2;0.8,0.8;randungeon_z_minus.png]  list[current_player;dungeon_z_minus;5,2;1,1;]"..

				"button[5,3;3,3.4;open_manual;Open Manual]" ..
				"item_image[5.1,4.1;0.8,0.8;randungeon:manual]" ..
				"", true)
    end,
	is_in_nav = function(self, player, context)
		return minetest.is_creative_enabled(player:get_player_name())
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if fields.dungeon_width ~= nil then
		local meta = player:get_meta()
		-- dungeon_width
		local dungeon_width = tonumber(fields.dungeon_width)
		if dungeon_width == nil or dungeon_width < 2 then
			minetest.chat_send_player(player:get_player_name(), "dungeon_width has to be an int >=2. Please enter an int instead of \"" .. fields.dungeon_width .. "\"")
		else
			meta:set_int("dungeon_width", dungeon_width)
		end
		-- dungeon_deph
		local dungeon_deph = tonumber(fields.dungeon_deph)
		if dungeon_deph == nil then
			minetest.chat_send_player(player:get_player_name(), "dungeon_deph has to be an int. Please enter an int instead of \"" .. fields.dungeon_deph .. "\"")
		else
			meta:set_int("dungeon_deph", dungeon_deph)
		end
		-- dungeon_levels
		local dungeon_levels = tonumber(fields.dungeon_levels)
		if dungeon_levels == nil or dungeon_levels < 2 then
			minetest.chat_send_player(player:get_player_name(), "dungeon_levels has to be an int. Please enter an int >1 instead of \"" .. fields.dungeon_levels .. "\"")
		else
			meta:set_int("dungeon_levels", dungeon_levels)
		end
		-- dungeon_bottom_deph
		local dungeon_bottom_deph = tonumber(fields.dungeon_bottom_deph)
		if dungeon_bottom_deph == nil then
			minetest.chat_send_player(player:get_player_name(), "dungeon_bottom_deph has to be an int. Please enter an int instead of \"" .. fields.dungeon_bottom_deph .. "\"")
		else
			meta:set_int("dungeon_bottom_deph", dungeon_bottom_deph)
		end
		-- dungeon_top_deph
		local dungeon_top_deph = tonumber(fields.dungeon_top_deph)
		if dungeon_top_deph == nil then
			minetest.chat_send_player(player:get_player_name(), "dungeon_top_deph has to be an int. Please enter an int instead of \"" .. fields.dungeon_top_deph .. "\"")
		else
			meta:set_int("dungeon_top_deph", dungeon_top_deph)
		end
		-- cave_percentage
		local dungeon_top_deph = tonumber(fields.cave_percentage)
		if dungeon_top_deph == nil or dungeon_top_deph < 0 or dungeon_top_deph > 100 then
			minetest.chat_send_player(player:get_player_name(), "cave_percentage has to be an int from 0 to 100. Please enter that instead of \"" .. fields.cave_percentage .. "\"")
		else
			meta:set_int("cave_percentage", dungeon_top_deph)
		end
		-- light_up_corridors
		local light_up_corridors = fields.light_up_corridors
		if light_up_corridors ~= nil then
			meta:set_int("light_up_corridors", bool_to_number(light_up_corridors == "true"))
		end
		-- gold_pools
		local gold_pools = fields.gold_pools
		if gold_pools ~= nil then
			meta:set_int("gold_pools", bool_to_number(gold_pools == "true"))
		end
	end
	-- open manual
	if fields.open_manual then
		minetest.show_formspec(player:get_player_name(), "randungeon:manual", dungeon_manual_formspec)
	elseif fields.exit_manual then
		minetest.close_formspec(player:get_player_name(), "randungeon:manual")
	end
end)

minetest.register_allow_player_inventory_action(
	function(player, action, inventory, inventory_info)
		-- materials amy only be blocks
		if action == "move" and contains({"dungeon_treasure_block", "dungeon_materials"}, inventory_info.to_list) then
			local item_name = inventory:get_list(inventory_info.from_list)[inventory_info.from_index]:get_name()
			if not minetest.registered_nodes[item_name] then
				return 0
			end
		-- bridge type only accepts bridge type selectors
		elseif action == "move" and inventory_info.to_list == "bridge_type" then
			local item_name = inventory:get_list(inventory_info.from_list)[inventory_info.from_index]:get_name()
			if not (minetest.registered_craftitems[item_name] and minetest.registered_craftitems[item_name].groups.bridge_type_selector) then
				return 0
			end
		-- dungeon tile direction settings only accept selector item
		elseif action == "move" and contains({"dungeon_x_plus", "dungeon_x_minus", "dungeon_z_plus", "dungeon_z_minus"}, inventory_info.to_list) then
			local item_name = inventory:get_list(inventory_info.from_list)[inventory_info.from_index]:get_name()
			if item_name ~= "randungeon:selected_frame" then
				return 0
			end
		end
	end
)

function initialize_player_if_needed(user)
	local inv = user:get_inventory()
	local meta = user:get_meta()
	-- initialize dungeon material inventory if not initialized already
	if inv:get_size("dungeon_treasure_block") < 1 or meta:get("gold_pools") == nil then
		meta:set_int("dungeon_width", 10)
		meta:set_int("dungeon_deph", 12)
		meta:set_int("dungeon_levels", 10)
		meta:set_int("dungeon_bottom_deph", 70)
		meta:set_int("dungeon_top_deph", 100)
		meta:set_int("cave_percentage", 30)
		meta:set_int("light_up_corridors", 0)
		meta:set_int("gold_pools", 1)
		meta:set_int("rim_sealed", 1)
		inv:set_size("dungeon_treasure_block", 1)
		inv:set_list("dungeon_treasure_block", {"randungeon:example_treasure"})
		inv:set_size("dungeon_materials", 5)
		inv:set_list("dungeon_materials", {"randungeon:ceiling", "randungeon:wall_type_2", "randungeon:wall_type_1", "randungeon:floor", "randungeon:pillar"})
		inv:set_size("bridge_type", 1)
		inv:add_item("bridge_type", ItemStack("randungeon:bridge_type_2"))
		inv:set_size("dungeon_x_plus", 1)
		inv:set_list("dungeon_x_plus", {"randungeon:selected_frame"})
		inv:set_size("dungeon_x_minus", 1)
		inv:set_list("dungeon_x_minus", {"randungeon:selected_frame"})
		inv:set_size("dungeon_z_plus", 1)
		inv:set_list("dungeon_z_plus", {"randungeon:selected_frame"})
		inv:set_size("dungeon_z_minus", 1)
		inv:set_list("dungeon_z_minus", {"randungeon:selected_frame"})
		-- minetest.chat_send_player(user:get_player_name(), "Dungeon Maker Stick initialized for " .. user:get_player_name() .. ".")
	end
end

minetest.register_on_joinplayer(
	function(player_obj, last_login)
		initialize_player_if_needed(player_obj)
	end
)

function get_bridge_type(bridge_type_selector_item)
	if bridge_type_selector_item == "randungeon:bridge_type_0" then
		return 0
	elseif bridge_type_selector_item == "randungeon:bridge_type_1" then
		return 1
	elseif bridge_type_selector_item == "randungeon:bridge_type_2" then
		return 2
	elseif bridge_type_selector_item == "randungeon:bridge_type_3" then
		return 3
	else
		return 0
	end
end

function this_or_air(s)
	if s == "" then
		return "air"
	else
		return s
	end
end
	
minetest.register_craftitem("randungeon:dungeon_stick_1_tile", {
	description = "Unrandomized Dungeon Tile Spawn Stick (mostly Debug Item)",
	inventory_image = "([inventorycube{randungeon_dungeon_tile_top.png{randungeon_dungeon_level_side.png{randungeon_dungeon_level_side.png)",
	wield_image = "default_stick.png^[colorize:#4ddcfa:160",
	on_use = function(itemstack, user, pointed_thing)
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
			minetest.chat_send_player(user:get_player_name(), "Can't make dungeon at the thing you pointed at.")
		end
		
		local meta = user:get_meta()
		local inv = user:get_inventory()
		-- initialize dungeon material inventory if not initialized already
		initialize_player_if_needed(user)
		-- generate dungeon tile
		local materials = user:get_inventory():get_list("dungeon_materials")
		local roof_type = this_or_air(materials[1]:get_name())
		local wall_type_2 = this_or_air(materials[2]:get_name())
		local wall_type_1 = this_or_air(materials[3]:get_name())
		local floor_type = this_or_air(materials[4]:get_name())
		local pillar_type = this_or_air(materials[5]:get_name())
		local bridge_type = get_bridge_type(user:get_inventory():get_list("bridge_type")[1]:get_name())
		local x_plus = not user:get_inventory():is_empty("dungeon_x_plus")
		local x_minus = not user:get_inventory():is_empty("dungeon_x_minus")
		local z_plus = not user:get_inventory():is_empty("dungeon_z_plus")
		local z_minus = not user:get_inventory():is_empty("dungeon_z_minus")
		make_dungeon_tile(pos, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, x_plus, x_minus, z_plus, z_minus,
		                  meta:get_int("dungeon_deph"), meta:get_int("dungeon_deph"), meta:get_int("dungeon_deph"), nil, nil, bridge_type, false, nil, true, false,
						  false)
		for x = 1, 10 do
			for z = 1, 10 do
				for y = 0, 5 do
					if minetest.get_node({x=pos.x+x, y=pos.y+y, z=pos.z+z}).name == "randungeon:dungeon_air" then
						minetest.set_node({x=pos.x+x, y=pos.y+y, z=pos.z+z}, {name="air"})
					end
				end
			end
		end
	end
})
	
minetest.register_craftitem("randungeon:dungeon_stick_2_level", {
	description = "Unrandomized Dungeon Level Spawn Stick (mostly Debug Item)",
	inventory_image = "([inventorycube{randungeon_dungeon_top.png{randungeon_dungeon_level_side.png{randungeon_dungeon_level_side.png)",
	wield_image = "default_stick.png^[colorize:#4ddcfa:160",
	on_use = function(itemstack, user, pointed_thing)
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
			minetest.chat_send_player(user:get_player_name(), "Can't make dungeon at the thing you pointed at.")
		end
		
		local meta = user:get_meta()
		local inv = user:get_inventory()
		-- initialize dungeon material inventory if not initialized already
		initialize_player_if_needed(user)
		-- generate dungeon level
		local materials = user:get_inventory():get_list("dungeon_materials")
		local roof_type = this_or_air(materials[1]:get_name())
		local wall_type_2 = this_or_air(materials[2]:get_name())
		local wall_type_1 = this_or_air(materials[3]:get_name())
		local floor_type = this_or_air(materials[4]:get_name())
		local pillar_type = this_or_air(materials[5]:get_name())
		local bridge_type = get_bridge_type(user:get_inventory():get_list("bridge_type")[1]:get_name())

		-- make sure dungeon is generated horizontally centered under us
		local dungeon_width = meta:get_int("dungeon_width")
		pos.x = pos.x - (dungeon_width * 10 / 2)
		pos.z = pos.z - (dungeon_width * 10 / 2)
		-- fix dungeon into grid so different overlapping dungeons during testing cause less chaos
		pos.x = math.floor(pos.x / 10) * 10
		pos.y = math.floor(pos.y / 10) * 10
		pos.z = math.floor(pos.z / 10) * 10
		make_dungeon_level(pos, dungeon_width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, meta:get_int("dungeon_deph"),
		                   meta:get_int("dungeon_deph"), meta:get_int("dungeon_deph"), meta:get_int("rim_sealed"), false, bridge_type, nil, nil, true)
	end
})

minetest.register_craftitem("randungeon:dungeon_stick_3_dungeon", {
	description = "Unrandomized Dungeon Spawn Stick (mostly Debug Item)",
	inventory_image = "([inventorycube{randungeon_dungeon_top.png{randungeon_dungeon_side.png{randungeon_dungeon_side.png)",
	wield_image = "default_stick.png^[colorize:#4ddcfa:160",
	on_use = function(itemstack, user, pointed_thing)
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
			minetest.chat_send_player(user:get_player_name(), "Can't make dungeon at the thing you pointed at.")
		end
		
		local meta = user:get_meta()
		local inv = user:get_inventory()
		-- initialize dungeon material inventory if not initialized already
		initialize_player_if_needed(user)
		-- generate dungeon id
		local dungeon_id = math.random()
		minetest.chat_send_player(user:get_player_name(), "Starting the dungeon generation.. this may take some seconds with default settings, and proportionally longer for different settings.\n"
	    	.. "DungonID is " .. tostring(dungeon_id) .. "; server logs will state when the generation is finished.")
		dungeon_generation_started[dungeon_id] = minetest.get_us_time() / 10000000
		-- generate dungeon
		local materials = user:get_inventory():get_list("dungeon_materials")
		local roof_type = this_or_air(materials[1]:get_name())
		local wall_type_2 = this_or_air(materials[2]:get_name())
		local wall_type_1 = this_or_air(materials[3]:get_name())
		local floor_type = this_or_air(materials[4]:get_name())
		local pillar_type = this_or_air(materials[5]:get_name())
		local treasure_block = user:get_inventory():get_list("dungeon_treasure_block")[1]:get_name()
		if treasure_block ~= "" and not minetest.registered_nodes[treasure_block] then
			minetest.chat_send_player(user:get_player_name(), "Treasure block may only be a placable block, not an item; ignoring it therefore.")
			treasure_block = ""
		end

		-- make sure dungeon is generated horizontally centered under us
		local dungeon_width = meta:get_int("dungeon_width")
		pos.x = pos.x - (dungeon_width * 10 / 2)
		pos.z = pos.z - (dungeon_width * 10 / 2)
		-- fix dungeon into grid so different overlapping dungeons during testing cause less chaos
		pos.x = math.floor(pos.x / 10) * 10
		pos.y = math.floor(pos.y / 10) * 10
		pos.z = math.floor(pos.z / 10) * 10
		local bridge_type = get_bridge_type(user:get_inventory():get_list("bridge_type")[1]:get_name())
		make_dungeon(pos, dungeon_width, floor_type, wall_type_1, wall_type_2, roof_type, pillar_type, bridge_type,
		             meta:get_int("dungeon_deph"), meta:get_int("rim_sealed"), meta:get_int("dungeon_levels"),
		             meta:get_int("dungeon_bottom_deph"), meta:get_int("dungeon_top_deph"), false, meta:get("cave_percentage"),
					 number_to_bool(meta:get_int("light_up_corridors")), number_to_bool(meta:get_int("gold_pools")), treasure_block, dungeon_id)
	end
})
	
minetest.register_craftitem("randungeon:dungeon_stick_4_random", {
	description = "Randomized Dungeon Spawn Stick",
	inventory_image = "([inventorycube{randungeon_dungeon_top.png{randungeon_dungeon_randomized_side.png{randungeon_dungeon_randomized_side.png)",
	wield_image = "randungeon_dungeon_stick_4_coloring.png^[mask:default_stick.png\\^[colorize\\:#FFFFFF\\:170",
	on_use = function(itemstack, user, pointed_thing)
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
			minetest.chat_send_player(user:get_player_name(), "Can't make dungeon at the thing you pointed at.")
		end
		
		-- initialize dungeon material inventory if not initialized already
		initialize_player_if_needed(user)

		local dungeon_id = math.random()
		minetest.chat_send_player(user:get_player_name(), "Starting the dungeon generation.. this may take some seconds with default settings, and proportionally longer for different settings.\n"
	    	.. "DungonID is " .. tostring(dungeon_id) .. "; server logs will state when the generation is finished.")
			dungeon_generation_started[dungeon_id] = minetest.get_us_time() / 10000000

		local meta = user:get_meta()
		local inv = user:get_inventory()
		local treasure_block = inv:get_list("dungeon_treasure_block")[1]:get_name()
		if treasure_block ~= "" and not minetest.registered_nodes[treasure_block] then
			minetest.chat_send_player(user:get_player_name(), "Treasure block may only be a placable block, not an item; ignoring it therefore.")
			treasure_block = ""
		end

		-- make sure dungeon is generated horizontally centered under us
		local dungeon_width = meta:get_int("dungeon_width")
		pos.x = pos.x - (dungeon_width * 10 / 2)
		pos.z = pos.z - (dungeon_width * 10 / 2)
		-- fix dungeon into grid so different overlapping dungeons during testing cause less chaos
		pos.x = math.floor(pos.x / 10) * 10
		pos.y = math.floor(pos.y / 10) * 10
		pos.z = math.floor(pos.z / 10) * 10
		make_dungeon(pos, dungeon_width, nil, nil, nil, nil, nil, nil, meta:get_int("dungeon_deph"), meta:get_int("rim_sealed"),
		             meta:get_int("dungeon_levels"),meta:get_int("dungeon_bottom_deph"), meta:get_int("dungeon_top_deph"), true, meta:get("cave_percentage"),
					 number_to_bool(meta:get_int("light_up_corridors")), number_to_bool(meta:get_int("gold_pools")), treasure_block, dungeon_id)

		-- obsolete bc now we have async execution
		-- minetest.chat_send_player(user:get_player_name(), "Finished dungeon generation after " .. tostring((minetest.get_us_time() - time) / 10000000) .. " seconds.")
	end
})
