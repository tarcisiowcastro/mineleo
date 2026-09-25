local LAVA_NODES = { "default:lava_source", "default:lava_flowing" }
local AIR = { name = "air" }

-- Terrain generated from now on: strip lava right after the chunk is
-- generated, before any player ever sees it.
minetest.register_on_generated(function(minp, maxp)
	local lava = minetest.find_nodes_in_area(minp, maxp, LAVA_NODES)
	if #lava > 0 then
		minetest.bulk_set_node(lava, AIR)
	end
end)

-- Terrain that already exists in the world: run_at_every_load makes this
-- fire every time a mapblock is loaded, so lava generated before this mod
-- existed disappears as soon as anyone gets near it.
minetest.register_lbm({
	label = "Remove existing lava",
	name = "no_lava:remove_existing",
	nodenames = LAVA_NODES,
	run_at_every_load = true,
	action = function(pos)
		minetest.set_node(pos, AIR)
	end,
})

-- Lava placed at runtime (bucket, WorldEdit, /setnode...) removes itself
-- immediately, so it never gets the chance to flow.
for _, name in ipairs(LAVA_NODES) do
	minetest.override_item(name, {
		on_construct = function(pos)
			minetest.remove_node(pos)
		end,
	})
end

-- Hide the lava bucket from the creative inventory; there is no point in
-- handing players an item that does nothing.
if minetest.registered_items["bucket:bucket_lava"] then
	local groups = table.copy(minetest.registered_items["bucket:bucket_lava"].groups or {})
	groups.not_in_creative_inventory = 1
	minetest.override_item("bucket:bucket_lava", { groups = groups })
end
