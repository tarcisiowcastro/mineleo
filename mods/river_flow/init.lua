-- Minetest Game sets river water's liquid_range to 2 (vs. 8 for regular
-- water) so rivers stay shallow/slow. 8 is the engine's hard max for this
-- property -- there is no way to make propagation truly unlimited.
minetest.override_item("default:river_water_source", { liquid_range = 8 })
minetest.override_item("default:river_water_flowing", { liquid_range = 8 })
