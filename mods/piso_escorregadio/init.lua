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

-- Rampas de estrada do cottages: em vez de apenas reduzir atrito, elas
-- transferem velocidade real para baixo na inclinação. A direção facedir da
-- peça é a direção de descida e o vetor é normalizado para velocidade 100.
local ROAD_SLOPE_SPEED = 100
local road_slopes = {
	["cottages:feldweg_slope"] = true,
	["cottages:feldweg_slope_bamboo"] = true,
	["cottages:feldweg_slope_long"] = true,
	["cottages:feldweg_slope_long_bamboo"] = true,
}

local function slope_velocity(node)
	local down = core.facedir_to_dir(node.param2 or 0)
	local horizontal, vertical
	if node.name:find("_long", 1, true) then
		horizontal, vertical = ROAD_SLOPE_SPEED * 4 / math.sqrt(17), ROAD_SLOPE_SPEED / math.sqrt(17)
	else
		horizontal, vertical = ROAD_SLOPE_SPEED / math.sqrt(2), ROAD_SLOPE_SPEED / math.sqrt(2)
	end
	return {x = down.x * horizontal, y = -vertical, z = down.z * horizontal}
end

local function road_slope_under(pos)
	-- A colisão de uma malha inclinada pode deixar os pés entre dois níveis do
	-- nó. Verificar três alturas cobre a rampa curta e a rampa longa.
	for dy = 0, -2, -1 do
		local node = core.get_node(vector.add(pos, {x = 0, y = dy, z = 0}))
		if road_slopes[node.name] then return node end
	end
end

local slope_timer = 0
core.register_globalstep(function(dtime)
	slope_timer = slope_timer + dtime
	if slope_timer < 0.05 then return end
	local step = slope_timer
	slope_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = vector.subtract(player:get_pos(), {x = 0, y = 0.1, z = 0})
		local node = road_slope_under(pos)
		if node then
			local velocity = slope_velocity(node)
			-- Move pela superfície em vez de depender das colisões dos degraus do
			-- mesh: assim a descida fica contínua e mantém velocidade 100.
			player:set_pos(vector.add(player:get_pos(), vector.multiply(velocity, step)))
			player:set_velocity(velocity)
		end
	end
end)
