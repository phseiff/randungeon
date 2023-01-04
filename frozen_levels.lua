local function freeze_frozen_levels(pos, dungeon_maps, materials, room_styles, frozen_biome)
    for i = 1, #dungeon_maps do
        if (i>1 and dungeon_maps[i-1].frozen) or (i<#dungeon_maps and dungeon_maps[i+1].frozen) or (i==1 and frozen_biome) then
            dungeon_maps[i].frozen_caves = true
        end
        if ((i>1 and dungeon_maps[i-1].frozen) or (i==1 and frozen_biome)) and (i<#dungeon_maps and dungeon_maps[i+1].frozen) then
            dungeon_maps[i].frozen_corridors = true
        end
    end
    local width_in_blocks = #dungeon_maps[1] * 10
    local pos = table.copy(pos)
    -- for i = 1, #dungeon_maps do
    -- not implemented yet.
end

return {
    freeze_frozen_levels = freeze_frozen_levels
}