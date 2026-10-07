local original_node_dig = core.node_dig

local function is_pickaxe(name)
	return name:find("pick", 1, true) ~= nil
end

-- Bloqueia o dig no servidor: so picaretas quebram blocos
core.node_dig = function(pos, node, digger)
	if digger and digger:is_player() then
		local wielded = digger:get_wielded_item():get_name()
		if not is_pickaxe(wielded) then
			return false
		end
	end
	return original_node_dig(pos, node, digger)
end

-- A mao nao tem capacidade de quebrar nada (evita a previsao no cliente)
core.register_on_mods_loaded(function()
	core.override_item("", {
		tool_capabilities = {
			full_punch_interval = 0.9,
			max_drop_level = 0,
			groupcaps = {},
			damage_groups = { fleshy = 1 },
		},
	})
end)
