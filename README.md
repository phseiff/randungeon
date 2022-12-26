# Randungeon

a minetest mod that adds highly randomized (incl. materials used for individual parts of each separate level) dungeons into the world, as well as tools to generate these dungeons at chosen locations with chosen or randomized properties.

Please note: This manual/README only documents how you can modify dungeon generation and the parts you can modify & influence, but not how generation of individual dungeon part works or all the dungeon offers in regards to dungeon generation apart from that.

See the "Some Images" section at the end of this manual/README for some screenshots of the actual dungeon generation.

## Natural Generation

By default around every tenth 200x200 block area of the world has one dungeon in it, with its heighest level being at y=-50 and its top starcases reaching the ground.
These dungeons can range from 10 to 50 levels deep, weighted towards shallower dephs.

Note that dungeon generation can take many seconds and that during this time many normal operations of ones world (e.g. crops growing) will be blocked.
You may consider deactivating dungeon generation (or not playing with this mod) if this bothers you.

![530,62,c](randungeon_image_dungeon_generation_settings.png)


There are severals new settings added to the "All Settings" page of minetest (under "Mods -> randungeon") for this; these being:

`Allow randungeon to generate dungeons naturally in worlds`

Enabled/Disabled depending on whether dungeons should generate naturally within the world anywhere.
Defaults to `true`. When disabled, dungeons can only be spawned using the tools available in creative mode.

`Worlds for which dungeon generation should be specifically enabled`

Comma-separated list of worlds, e.g. "world1,world2,world3" for which dungeon generation should be specifically enabled.
Don't append whitespace that isn't actually there in the world name to the world names in this list.
  
`Worlds for which dungeon generation should be specifically disabled`

Comma-separated list of worlds, e.g. "world1,world2,world3" for which dungeon generation should be specifically disabled.
Don't append whitespace that isn't actually there in the world name to the world names in this list.
If a world name is both in both aforementioned lists we'll apply the default setting to it.
 
`Chance for a dungeon to be generated per 200x200 block area in percent`

For every 200x200 block wide chunk of the world there is a chance that a dungeon will be generated in it.
This chance can be modified with this option. Must be larger than 0 and not more than 100, since it's in percent.

## Manual Dungeon Generation

When you're in creative mode (or have creative privileges) you can alsoc reate dungeons manually, regardless of randungeon's settings in minetest's menu.

There are items for this ("Dungeon Spawn Sticks) that you can left-click with to generate a dungeon beneath you, as well as two special inventory tabs ("Make Dungeon" and "Make Dungeon (unrand)") where you can configure (on a per-player basis) what they can do, noth of which are only accessible in creative mode.

### Randomized Dungeon Spawn Stick

![530,132,c](randungeon_image_dungeon_stick_4.png)

This item creates a dungeon underneath and sideways from you, following the options given in the "Make Dungeon" Inventory tab.

The tab looks as follows, with its default options:

![530,348,c](randungeon_settings_rand.png)

Keep in mind that changing size of the dungeon can cause dungeon generation to take proportionally (and for some steps/options even quadratucally/cubically) longer.

The individual settings mean:

`dungeon_width / 10`:

The dungeon consists of individual segments, each of whom being either an L-, I-, T-, or X-section of corridor, and potentially having a room or an up-/downloading staircase in it. These sections are each 10 blocks wide in both horizontal directions, so `dungeon width / 10` (the number you enter into this field) is the number of dungeon segments in each horizontal line/row of the dungeon, or one tenth of the length/width of the dungeon. It defaults to 10 and must be an integer >=2.

`dist between dungeon levels`:

The dungeon consists of several levels, each of whom is a square-shaped horizontal plane beneath the former one made up of corridors. Individual levels are connected to each other via vertical spiral staircases. The value in the `dist between dungeon levels` field is the vertical distance between two adjacent levels. It defaults to 12, shouldn't be much smaller than that (at least 8), and should ideally be a multitude of 4. This is because each spiral staircase loop takes 4 blocks and if the distance between two levels is also a multitude of 4 the chance increases of not having to jump to reach the upper end of the staircase from the higher of both levels.

`amount of dungeon levels`:

How many levels the dungeon should have. This must be an int >= 1, and defaults to 10. If you want to have a wide variety of very different dungeon levels in your dungeon you can crank this up to smth around 30-60.

`height of bottom pillars`:

There are pillars between each level of the dungeon, one per segment (provided the segment is a bridge that crosses into a cave or smth like that). The pillars that go down from the lowest dungeon level should be a bit longer than the normal distance between dungeon levels, since there won't necessarily just be a normal level distance till ground but rather a potentially deeper chasm if they are in a cave. Defaults to 70 blocks and must be an int.

`max height of top staircase`:

The staircase of the upmost dungeon doesn't just need to reach the upper level (since there is none) but rather the ground above, so it needs to be significantly heighter that the other staircases. This option is the height of the upmost staircases. The staircases that go up from the upmost level will cut off as soon as they reach the surface, thought, so this is merely the max height of them. Must be an int and defaults to 100.

`max % of blocks taken up by bubble caves`:

Before the dungeon is generated, artificial bubble-shaped caves of varying size and interior (water, lava, nothing, lakes, nature etc.) are generated in the dungeon generation area. The value of `max % of blocks taken up by bubble caves` determines the maximum percentage of blocks in the generation area that may be made up by air blocks after bubble caves are generated (this includes space taken up by normal mapgen-generated caves). Must be an int between 0 and 100 and defaults to 30.

`light up corridors & caves`:

By default most structures of the dungeona are entirely dark; if you switch on this option (by default disabled); though, all air blokcks within the dungeon are replaced by lighting air blocks, which illuminates all structures of the dungeon to mayimum light level.

`gold pools on lowest level`:

This option is meant to aesthetically accompany the next option (`build treasure room with treasure block`) by turning the lowest level of the dungeon into smth with a fortified treasure trove vibe.
This basically means:

• pools filled with gold in some rooms, and more pools than usual

• bridges have a higher chance of being closed (walls all around, no windows)

• rooms can generate in caves (more rooms)

This option is enabled by default.

`build treasure room with treasure block`:

This option, if enabled (by putting a block into the inventory field), builds a treasure room on the lowest level of the dungeon in whose center the provided block lies. This can be used e.g. for roguelike or labyrinth-like games where the goal is to retrieve smth from a dungeon. Treasure rooms look like this:

• There is a room with pillars in the corners and the treasure block in the center

• There are several immediately adjacent rooms that form pillar-lined halls leading to the center room

• The center room and its adjacent rooms are lined with gold in their structure.

This option defaults to an examplary treasure block ("randungeon:example_treasure") that differs from the one used in naturally generated dungeons, and only accepts blocks.

`Open Manual`:

Can be clicked to read this manual.

### Unrandomized Dungeon Spawn Stick (mostly Debug Item)

![530,132,c](randungeon_image_dungeon_stick_3.png)

This item creates a semi-randomized dungeon underneath and sideways from you, following the options given in the "Make Dungeon" Inventory tab, as well as, in addition, the options n the "Make Dungeon (unrand)" tab. Its layout, rooms and bubble caves are randomized in the same way they are for normal randomized dungeons, but the materials it uses and the bridge type are set via the "Make Dungeon (unrand)" tab for the entire dungeon instead of randomized for every level.

The "Make Dungeon (unrand)" tab looks as follows, with its default options:

![530,348,c](randungeon_settings_unrand.png)

Its options work as follows:

`the five inv slots on the left`:

These are the materials that the dungeon are build from; you just drag the blocks into their respective fields. The inventory slots, from top to bottom, correspond to:

• dungeon ceiling (the ceiling of the corridors/rooms)

• upper wall block (corridor walls are two blocks height and this is the upper one of them)

• lower wall block (corridor walls are two blocks height and this is the lower one of them)

• floor blocks (the floor of corridors, rooms and bridges)

• pillar block (the block that the pillars that carry free-floating dungeon segments/ bridges are made from; not to confuse with the blocks that pillars in rooms are made from)

The icons next to the fields also illustrate this.

These fields are filled with some debugging-oriented light-emitting blocks by default, and only accept blocks. If the block provided for the upper wall element isn't a block usually used for this (in fully randomized dugneons, that is), the dungeon will generate without doorframes above doors. Leaving a field empty means that no block will be set for this part of the dungeon, leaving bare stone walls/floors/etc.

`bridge type`:

This inventory slot accepts one of five items/options that serve as indicators for how bridges (areas of the dungeon where corridors cut into caves) are supposed to look like.

The options are:

• `walls & roof present`: corridor is closed on all sides like normal, so its surroundings and bridge nature aren't even noticeable from the inside.

• `lower wall part & roof present`: only the upper half of the corridor's walls is missing in caves; you can look out of the corridor but can't jump out of it. Kinda like windows in a corridor.

• `lower wall part present`: upper wall part and roof are missing, so you still have a railing but can look & jump off the bridge. Kinda like a bridge with railing.

• `no walls or roof present`: only floor (and carrying pillars) of the corridor are present; no railing. Very open and risky-architecture-vibey look.

This option defaults to 

`Open Manual`:

Can be clicked to read this manual.

### Unrandomized Dungeon Level Spawn Stick (mostly Debug Item)

![530,132,c](randungeon_image_dungeon_stick_2.png)

This item creates a single semi-randomized dungeon level underneath and sideways from you, following the same options given in the "Make Dungeon" and "Dungeon Maker (unrand)" Inventory tab that the two tools above (Unrandomized Dungeon Spawn Stick and Randomized Dungeon Spawn Stick) follow. It comes without bubbly caves and is not considered to be a "final level" or "first level" for purposes like treasure room placement and staircase/pillar length.

### Unrandomized Dungeon Tile Spawn Stick (mostly Debug Item)

![530,132,c](randungeon_image_dungeon_stick_1.png)

This item creates a single non-randomized dungeon tile/segment around where you click, without any room in it and without any of the things that the Unrandomized Dungeon Level Spawn Stick's results are missing.

A dungeon tile is basically a small 10x10 area of dungeon that represents one I-/L-/T- or X-section of corridor in any rotation.

This item follows most of the same options (where applicable) as the Unrandomized Dungeon Level Spawn Stick, plus the following options from the "Make Dungeon (unrand)" tab:

`X+ / X- / Z+ / Z-`:

Inventory fields that can be marked with Direction Selector items (`randungeon:selected_frame`) to indicate that the dungeon tile's corridor should go into the respective direction. For example, if Z+ and X- are marked but the other two directions aren't then you're gonna get an L-shaped dungeon tile from the Z+ to the X- direction.

Accepts only Direction Selector items and is filled with four of them by default.

### Manual

There's also a manual item (the gray little book) that you can left-click with to open & read this manual/READMe in-game.

## Nodes

Randungeon strives to not add any survival-mode-obtainable (and ideally no non-technical creative-mode-obtainable) blocks to the game, since it is decidedly not a block mod.

However, some blocks still got added:

### Obtainable blocks:

`The five exemplary dungeon part blocks`:

There is one special block each for pillar, floor, both wall parts and roof of the dungeon. They are colorcoded, labeled, glow in the dark, and are the default blocks for non-randomized dungeon generation via dungeon sticks. They are only obtainable via creatve mode.

`Treasure Blocks`:

There are Treasure Blocks found in treasure faults when dungeons are naturally generated; these don't have any special proeprties except for remembering & displaying the location they were found at. If natural dungeon generation is disabled, these blocks cannot be naturally found and aren't present in the creative inventory either.

There are also exemplary Treasure Blocks used as the default value for treasure blocks in manually generated dungeons, which are always present in the creative inventory and don't have any gameplay-enhancing value.

### Unobtainable blocks:

`Technical blocks`:

There are some blocks that mimic blocks already present in minetest game, but display alternative behavior, that are used in some part of the dungeon (not necessarily in all parts that the block they mimic is used in, though) such as

• lava whose source block doesn't ignite anything (in rooms with lava pools)

• water that only flows one block wide (in bubble caves with swamps)

• air that emits light (for dungeons that are lit up)

• bookshelfs with book textures on all four sides and with no book inventory (for when dungeon walls are made from bookshelfs)

None of these blocks are obtainable without commands; trying to obtain one of them the usual way simply yields the block it is mimiking.

`Technical Blocks`:

There are also some blocks that are placed to mark certain positions during dungeon generation, all of whem get removed at the end of dungeon generation, so you will never get to see them during normal gameplay.

## Some Images

![530,298,c](randungeon_screenshot.1.png)

![530,298,c](randungeon_screenshot.2.png)

![530,298,c](randungeon_screenshot.3.png)

![530,298,c](randungeon_screenshot.4.png)

![530,298,c](randungeon_screenshot.5.png)

![530,298,c](randungeon_screenshot.6.png)
