-- Fraction of generated trees that survive; the rest have their trunk
-- removed right after generation. Leaves left without a trunk nearby
-- decay on their own via default's built-in leafdecay mechanic.
local KEEP_CHANCE = 0.4

minetest.register_on_generated(function(minp, maxp)
	local trunks = minetest.find_nodes_in_area(minp, maxp, "group:tree")

	for _, pos in ipairs(trunks) do
		local below = { x = pos.x, y = pos.y - 1, z = pos.z }
		local below_name = minetest.get_node(below).name

		-- Only act once per tree, at its base (the node below isn't
		-- also a trunk node), then walk up removing the whole trunk.
		if minetest.get_item_group(below_name, "tree") == 0 then
			if math.random() > KEEP_CHANCE then
				local p = { x = pos.x, y = pos.y, z = pos.z }
				while minetest.get_item_group(minetest.get_node(p).name, "tree") > 0 do
					minetest.set_node(p, { name = "air" })
					p.y = p.y + 1
				end
			end
		end
	end
end)
