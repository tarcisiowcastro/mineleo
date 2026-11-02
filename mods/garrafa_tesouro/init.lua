-- Garrafa do Tesouro: ao usar, marca um tesouro aleatório no mapa (abre o GPS/mapa do
-- Luanti via discovery_maps) e enterra um baú pirata ~6 blocos abaixo da superfície
-- naquele ponto.
local S = minetest.get_translator("garrafa_tesouro")

local MIN_DIST = 64 -- distância mínima no mesmo planeta, em blocos
local MAX_DIST = 180
local PROFUNDIDADE = 3

local loot_bau = {
	"garrafa_tesouro:deed_casa 1",
	"garrafa_tesouro:deed_casa 1",
	"garrafa_tesouro:deed_mansao 1",
	"garrafa_tesouro:deed_torre 1",
	"garrafa_tesouro:deed_castelo 1",
	"animalia:spawn_horse 1",
	"animalia:spawn_horse 1",
}

-- Deeds reutilizáveis: colocam uma construção pronta e o marco no topo pode
-- ser clicado pelo dono para empacotar a construção de volta no mesmo papel.
local deeds = {
	casa = {descricao = "Deed: Casa de Pescador", arquivo = "default_town_house_small.mts"},
	mansao = {descricao = "Deed: Mansão Medieval", arquivo = "default_town_house_large_1.mts"},
	torre = {descricao = "Deed: Torre de Pedra", arquivo = "default_town_tower.mts"},
	castelo = {descricao = "Deed: Castelo", arquivo = "chateau_without_garden.mts"},
}

minetest.register_node("garrafa_tesouro:marco_deed", {
	description = S("Marco de Deed (clique para recolher a construção)"),
	tiles = {"default_gold_block.png^[colorize:#5B2C6F:100"},
	groups = {cracky = 1, not_in_creative_inventory = 1},
	light_source = 8,
	drop = "",
})

local function recolher_deed(pos, clicker)
		local meta = minetest.get_meta(pos)
		if meta:get_string("owner") ~= clicker:get_player_name() then
			minetest.chat_send_player(clicker:get_player_name(), S("Somente quem colocou este deed pode recolhê-lo."))
			return false
		end
		local inicio = minetest.deserialize(meta:get_string("inicio"))
		local tamanho = minetest.deserialize(meta:get_string("tamanho"))
		local deed = meta:get_string("deed")
		if not (inicio and tamanho) then return false end
		local fim = vector.add(inicio, {x = tamanho.x - 1, y = tamanho.y - 1, z = tamanho.z - 1})
		for x = inicio.x, fim.x do for y = inicio.y, fim.y do for z = inicio.z, fim.z do
			local p = {x = x, y = y, z = z}
			if not minetest.is_protected(p, clicker:get_player_name()) then minetest.set_node(p, {name = "air"}) end
		end end end
		minetest.set_node(pos, {name = "air"})
		local sobra = clicker:get_inventory():add_item("main", deed)
		if not sobra:is_empty() then minetest.add_item(clicker:get_pos(), sobra) end
		minetest.chat_send_player(clicker:get_player_name(), S("Construção recolhida e transformada novamente em deed."))
		return true
end

minetest.override_item("garrafa_tesouro:marco_deed", {
	on_rightclick = function(pos, node, clicker)
		recolher_deed(pos, clicker)
	end,
})

minetest.register_chatcommand("recolher_deed", {
	description = S("Recolhe a construção do deed mais próxima"),
	func = function(nome)
		local jogador = minetest.get_player_by_name(nome)
		if not jogador then return false end
		local pos = jogador:get_pos()
		local raio = 96
		local marcos = minetest.find_nodes_in_area(
			vector.subtract(pos, raio), vector.add(pos, raio), {"garrafa_tesouro:marco_deed"})
		local mais_perto
		for _, marco in ipairs(marcos) do
			if not mais_perto or vector.distance(pos, marco) < vector.distance(pos, mais_perto) then mais_perto = marco end
		end
		if not mais_perto then return false, S("Nenhum deed foi encontrado por perto.") end
		return recolher_deed(mais_perto, jogador), S("Deed recolhido.")
	end,
})

for nome, def in pairs(deeds) do
	minetest.register_craftitem("garrafa_tesouro:deed_" .. nome, {
		description = S("@1\nColoque em terreno livre; use o marco no topo para recolher.", def.descricao),
		inventory_image = "default_paper.png^[colorize:#6A1B9A:120",
		stack_max = 1,
		on_place = function(itemstack, placer, pointed_thing)
			if not (placer and placer:is_player() and pointed_thing and pointed_thing.above) then return itemstack end
			local caminho = minetest.get_modpath("mg_villages")
			if not caminho then return itemstack end
			caminho = caminho .. "/schems/" .. def.arquivo
			local esquema = minetest.read_schematic(caminho, {})
			if not (esquema and esquema.size) then
				minetest.chat_send_player(placer:get_player_name(), S("Este deed ainda está sendo preparado."))
				return itemstack
			end
			local inicio = vector.new(pointed_thing.above)
			if minetest.is_protected(inicio, placer:get_player_name()) then return itemstack end
			minetest.place_schematic(inicio, caminho, "0", nil, false)
			local marco = vector.add(inicio, {x = math.floor(esquema.size.x / 2), y = esquema.size.y, z = math.floor(esquema.size.z / 2)})
			minetest.set_node(marco, {name = "garrafa_tesouro:marco_deed"})
			local meta = minetest.get_meta(marco)
			meta:set_string("owner", placer:get_player_name())
			meta:set_string("inicio", minetest.serialize(inicio))
			meta:set_string("tamanho", minetest.serialize(esquema.size))
			meta:set_string("deed", "garrafa_tesouro:deed_" .. nome)
			itemstack:take_item()
			return itemstack
		end,
	})
end

-- Os planetas ocupam faixas diferentes de Y, mas o discovery_maps é 2D. O
-- tesouro é sempre escolhido perto do jogador em X/Z e sua altura é resolvida
-- depois a partir do plano onde a garrafa foi aberta.
local function sortear_local_tesouro(pos)
	local angulo = math.random() * math.pi * 2
	local distancia = math.random(MIN_DIST, MAX_DIST)
	return math.floor(pos.x + math.cos(angulo) * distancia),
		math.floor(pos.z + math.sin(angulo) * distancia)
end

local function enterrar_bau(x, z, y_referencia, nome_jogador)
	local minp = {x = x - 1, y = y_referencia - 160, z = z - 1}
	local maxp = {x = x + 1, y = y_referencia + 96, z = z + 1}

	minetest.emerge_area(minp, maxp, function(_, _, calls_remaining)
		if calls_remaining > 0 then return end

		local superficie_y
		for y = y_referencia + 96, y_referencia - 160, -1 do
			local n = minetest.get_node({x = x, y = y, z = z})
			local def = minetest.registered_nodes[n.name]
			if n.name ~= "ignore" and def and def.walkable then
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
		local x, z = sortear_local_tesouro(pos)

		enterrar_bau(x, z, pos.y, nome)

		if persistent_map and persistent_map.add_marker_for_player then
			persistent_map.add_marker_for_player(nome, {x = x, y = pos.y, z = z}, S("Tesouro Pirata"), 6)
			persistent_map.show_map(nome)
		else
			minetest.chat_send_player(nome, S("Tesouro marcado em X=@1 Z=@2 (instale discovery_maps para ver no mapa)", x, z))
		end

		minetest.chat_send_player(nome,
			S("A garrafa revela um mapa antigo no mesmo planeta! Vá até o local marcado e cave cerca de @1 blocos abaixo da superfície.", PROFUNDIDADE))
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
