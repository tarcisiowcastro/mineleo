-- Remove toda a lava do mundo (superficie e cavernas).
-- Inclui a lava "domada" do mg_villages (grupo lava_tamed, sem grupo lava).
local lava_nodes = { "group:lava", "group:lava_tamed" }

-- Qualquer liquido com "lava" no nome tambem entra (dos mods ja carregados,
-- ver optional_depends no mod.conf)
for name, def in pairs(core.registered_nodes) do
	if def.liquidtype and def.liquidtype ~= "none" and name:find("lava", 1, true) then
		lava_nodes[#lava_nodes + 1] = name
	end
end

local function clean(pos)
	core.set_node(pos, { name = "air" })
end

core.register_lbm({
	label = "Remove lava",
	name = "no_lava:remove_all",
	nodenames = lava_nodes,
	run_at_every_load = true,
	action = clean,
})

core.register_abm({
	label = "Remove lava (ABM)",
	nodenames = lava_nodes,
	interval = 1,
	chance = 1,
	catch_up = false,
	action = clean,
})

-- /limpar_lava [raio]: limpa a lava ao redor de quem digitou (padrao 40, max 60)
core.register_chatcommand("limpar_lava", {
	params = "[raio]",
	description = "Remove toda a lava ao redor de voce",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end
		-- find_nodes_in_area rejeita areas > 4096000 nos; 120^3 cabe com folga
		local r = math.max(1, math.min(tonumber(param) or 40, 60))
		local p = vector.round(player:get_pos())
		local minp = vector.subtract(p, r)
		local maxp = vector.add(p, r)
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining > 0 then
				return
			end
			local found = core.find_nodes_in_area(minp, maxp, lava_nodes)
			for _, pos in ipairs(found) do
				core.set_node(pos, { name = "air" })
			end
			core.chat_send_player(name, ("Lava removida: %d blocos"):format(#found))
		end)
		return true, "Limpando lava num raio de " .. r .. "..."
	end,
})
