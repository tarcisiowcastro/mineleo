-- Garrafa do Tesouro: ao usar, marca um tesouro aleatório no mapa (abre o GPS/mapa do
-- Luanti via discovery_maps) e enterra um baú pirata ~6 blocos abaixo da superfície
-- naquele ponto.
local S = minetest.get_translator("garrafa_tesouro")

local MIN_DIST = 500 -- distância mínima do jogador, em blocos
local PROFUNDIDADE = 6
local TILE_SIZE = 128 -- precisa casar com persistent_map.tile_size (discovery_maps/init.lua)

local loot_bau = {
	"default:gold_ingot 6",
	"default:gold_ingot 6",
	"default:diamond 3",
	"default:mese_crystal 6",
	"default:mese 1",
	"default:obsidian_shard 5",
	"default:copper_ingot 6",
	"pescaria:peixe_lendario 1",
}

-- Só sorteia entre tiles que o PRÓPRIO jogador já descobriu no mapa (discovery_maps),
-- e que estejam a pelo menos MIN_DIST blocos de onde ele está agora.
local function tiles_descobertos_distantes(nome_jogador, pos)
	local candidatos = {}
	if not (persistent_map and persistent_map.get_player_data) then
		return candidatos
	end

	local pdata = persistent_map.get_player_data(nome_jogador)
	if not (pdata and pdata.discovered_tiles) then
		return candidatos
	end

	for _, tile in pairs(pdata.discovered_tiles) do
		local centro_x = tile.x * TILE_SIZE + TILE_SIZE / 2
		local centro_z = tile.z * TILE_SIZE + TILE_SIZE / 2
		local dist = math.sqrt((centro_x - pos.x) ^ 2 + (centro_z - pos.z) ^ 2)
		if dist >= MIN_DIST then
			table.insert(candidatos, tile)
		end
	end

	return candidatos
end

-- Retorna sempre um ponto para o tesouro. Quando ainda não há uma região
-- distante descoberta, cria o destino numa direção aleatória: o mapa da
-- garrafa continua funcionando para quem acabou de começar a explorar.
local function sortear_local_tesouro(nome_jogador, pos)
	local candidatos = tiles_descobertos_distantes(nome_jogador, pos)
	if #candidatos > 0 then
		local tile = candidatos[math.random(#candidatos)]
		return tile.x * TILE_SIZE + math.random(0, TILE_SIZE - 1),
			tile.z * TILE_SIZE + math.random(0, TILE_SIZE - 1)
	end

	local angulo = math.random() * math.pi * 2
	local distancia = MIN_DIST + math.random(0, 200)
	return math.floor(pos.x + math.cos(angulo) * distancia),
		math.floor(pos.z + math.sin(angulo) * distancia)
end

local function enterrar_bau(x, z, nome_jogador)
	local minp = {x = x - 1, y = -60, z = z - 1}
	local maxp = {x = x + 1, y = 150, z = z + 1}

	minetest.emerge_area(minp, maxp, function(_, _, calls_remaining)
		if calls_remaining > 0 then return end

		local superficie_y
		for y = 140, -50, -1 do
			local n = minetest.get_node({x = x, y = y, z = z})
			if n.name ~= "air" and n.name ~= "ignore" then
				superficie_y = y
				break
			end
		end
		if not superficie_y then
			minetest.log("warning", "[garrafa_tesouro] Não achou superfície em " .. x .. "," .. z)
			return
		end

		local pos_bau = {x = x, y = superficie_y - PROFUNDIDADE, z = z}
		minetest.set_node(pos_bau, {name = "default:chest"})

		local meta = minetest.get_meta(pos_bau)
		meta:set_string("infotext", S("Baú do Pirata"))
		local inv = meta:get_inventory()
		for _, itemname in ipairs(loot_bau) do
			inv:add_item("main", ItemStack(itemname))
		end

		minetest.log("action", string.format(
			"[garrafa_tesouro] Baú enterrado em %d,%d,%d para %s",
			pos_bau.x, pos_bau.y, pos_bau.z, nome_jogador))
	end)
end

minetest.register_craftitem("garrafa_tesouro:garrafa", {
	description = S("Garrafa do Tesouro\nClique com o botão direito para revelar um mapa"),
	inventory_image = "vessels_glass_bottle.png^[colorize:#2E8B57:110",
	stack_max = 10,
	on_use = function(itemstack, user, pointed_thing)
		if not (user and user:is_player()) then return end
		local nome = user:get_player_name()
		local pos = user:get_pos()
		local x, z = sortear_local_tesouro(nome, pos)

		enterrar_bau(x, z, nome)

		if persistent_map and persistent_map.add_marker_for_player then
			persistent_map.add_marker_for_player(nome, {x = x, y = 0, z = z}, S("Tesouro Pirata"), 6)
			persistent_map.show_map(nome)
		else
			minetest.chat_send_player(nome, S("Tesouro marcado em X=@1 Z=@2 (instale discovery_maps para ver no mapa)", x, z))
		end

		minetest.chat_send_player(nome,
			S("A garrafa revela um mapa antigo! Vá até o local marcado e cave cerca de @1 blocos abaixo da superfície.", PROFUNDIDADE))
		minetest.sound_play("default_glass_footstep",
			{pos = pos, gain = 0.5, max_hear_distance = 8}, true)

		itemstack:take_item()
		return itemstack
	end,
})

-- Achado raro ao cavar areia/terra: uma garrafa misteriosa enterrada.
local chance_por_node = {
	["default:sand"] = 220,
	["default:desert_sand"] = 220,
	["default:dirt"] = 400,
	["default:dirt_with_grass"] = 400,
}

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not (digger and digger:is_player()) then return end
	local chance = chance_por_node[oldnode.name]
	if not chance then return end

	if math.random(1, chance) == 1 then
		minetest.add_item(pos, "garrafa_tesouro:garrafa")
		minetest.chat_send_player(digger:get_player_name(),
			S("Você encontrou uma garrafa misteriosa enterrada!"))
	end
end)
