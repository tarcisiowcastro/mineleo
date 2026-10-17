-- Piso que escorrega ao extremo: combina o group "slippery" (perda de
-- controle de frenagem/giro) com um physics_override de velocidade, porque
-- "slippery" por si so nao altera velocidade, so a chance de deslizar.
local SLIPPERY_MAX = 200
local SPEED_BOOST = 1000

local sound_defaults = default and default.node_sound_glass_defaults and default.node_sound_glass_defaults() or nil

core.register_node("piso_escorregadio:piso", {
	description = "Piso Escorregadio (extremo)",
	tiles = { "default_ice.png" },
	use_texture_alpha = "blend",
	paramtype = "light",
	is_ground_content = false,
	walkable = true,
	groups = { slippery = SLIPPERY_MAX, cracky = 3 },
	sounds = sound_defaults,
})

-- Quem esta com o boost aplicado agora, pra saber quando tirar
local boosted = {}

core.register_globalstep(function(_dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local feet = vector.subtract(player:get_pos(), { x = 0, y = 0.1, z = 0 })
		local on_slippery = core.get_node(feet).name == "piso_escorregadio:piso"

		if on_slippery and not boosted[name] then
			player:set_physics_override({ speed = SPEED_BOOST })
			boosted[name] = true
		elseif not on_slippery and boosted[name] then
			player:set_physics_override({ speed = 1 })
			boosted[name] = false
		end
	end
end)

core.register_on_leaveplayer(function(player)
	boosted[player:get_player_name()] = nil
end)
