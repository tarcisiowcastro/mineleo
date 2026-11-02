-- Piso que escorrega ao extremo: combina o group "slippery" (perda de
-- controle de frenagem/giro) com um physics_override de velocidade, porque
-- "slippery" por si so nao altera velocidade, so a chance de deslizar.
local SLIPPERY_MAX = 200
local SPEED_BOOST = 1000

local sound_defaults = default and default.node_sound_glass_defaults and default.node_sound_glass_defaults() or nil

-- O pova reaplica a fisica somada a cada segundo; um set_physics_override
-- direto seria desfeito, entao o boost entra como override nomeado dele.
local has_pova = core.get_modpath("pova") ~= nil

local function set_boost(player, on)
	if has_pova then
		local name = player:get_player_name()
		if on then
			pova.add_override(name, "piso_escorregadio", { speed = SPEED_BOOST - 1 })
		else
			pova.del_override(name, "piso_escorregadio")
		end
		pova.do_override(player)
	else
		player:set_physics_override({ speed = on and SPEED_BOOST or 1 })
	end
end

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
			set_boost(player, true)
			boosted[name] = true
		elseif not on_slippery and boosted[name] then
			set_boost(player, false)
			boosted[name] = false
		end
	end
end)

core.register_on_leaveplayer(function(player)
	boosted[player:get_player_name()] = nil
end)
