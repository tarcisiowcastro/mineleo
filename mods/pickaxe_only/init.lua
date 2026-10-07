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

-- Grupos que normalmente exigem pa/machado/mao; a picareta passa a quebrar todos
local extra_groups = {
	"crumbly", "choppy", "snappy", "oddly_breakable_by_hand", "explody",
}

core.register_on_mods_loaded(function()
	-- A mao nao quebra nada
	core.override_item("", {
		tool_capabilities = {
			full_punch_interval = 0.9,
			max_drop_level = 0,
			groupcaps = {},
			damage_groups = { fleshy = 1 },
		},
	})

	for name, def in pairs(core.registered_tools) do
		local caps = def.tool_capabilities
		if caps then
			if is_pickaxe(name) then
				local groupcaps = table.copy(caps.groupcaps or {})
				local base = groupcaps.cracky
				if base then
					for _, g in ipairs(extra_groups) do
						if not groupcaps[g] then
							groupcaps[g] = table.copy(base)
						end
					end
					local new_caps = table.copy(caps)
					new_caps.groupcaps = groupcaps
					core.override_item(name, { tool_capabilities = new_caps })
				end
			elseif caps.groupcaps and next(caps.groupcaps) then
				-- Outras ferramentas (pa, machado, espada...) nao quebram blocos
				local new_caps = table.copy(caps)
				new_caps.groupcaps = {}
				core.override_item(name, { tool_capabilities = new_caps })
			end
		end
	end
end)
