-- Remove so a lava "de fora" (superficie); lava em cavernas fica.
local lava_nodes = { "group:lava" }

local function outside(pos)
	-- acima do nivel do mar, ou com ceu aberto (luz do dia no no acima)
	if pos.y >= 0 then
		return true
	end
	local above = { x = pos.x, y = pos.y + 1, z = pos.z }
	local light = core.get_node_light(above, 0.5)
	return light ~= nil and light >= core.LIGHT_MAX
end

local function clean(pos)
	if outside(pos) then
		core.set_node(pos, { name = "air" })
	end
end

core.register_lbm({
	label = "Remove surface lava",
	name = "no_lava:remove_surface",
	nodenames = lava_nodes,
	run_at_every_load = true,
	action = clean,
})

-- Lava colocada depois (balde, mods) ou que escorreu pra fora
core.register_abm({
	label = "Remove surface lava (ABM)",
	nodenames = lava_nodes,
	interval = 2,
	chance = 1,
	catch_up = false,
	action = clean,
})
