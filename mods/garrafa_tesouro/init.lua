-- Garrafa do Tesouro: ao usar, marca um tesouro aleatório no mapa (abre o GPS/mapa do
-- Luanti via discovery_maps) e enterra um baú pirata ~6 blocos abaixo da superfície
-- naquele ponto.
local S = minetest.get_translator("garrafa_tesouro")

local MIN_DIST = 64 -- distância mínima no mesmo planeta, em blocos
local MAX_DIST = 180
local PROFUNDIDADE = 3

-- Catálogo de moradias reais do pacote mg_villages. Não são caixas geradas:
-- cada uma é o esquema completo usado pelas vilas do próprio mundo.
local modpath = minetest.get_modpath(minetest.get_current_modname())
local schem_path = minetest.get_modpath("mg_villages") and minetest.get_modpath("mg_villages") .. "/schems/" or nil
local catalogo = {
	{id="tiny_1", nome="Casa compacta I", arquivo="default_town_house_tiny_1.mts", grupo="Casas"},
	{id="tiny_2", nome="Casa compacta II", arquivo="default_town_house_tiny_2.mts", grupo="Casas"},
	{id="tiny_3", nome="Casa compacta III", arquivo="default_town_house_tiny_3.mts", grupo="Casas"},
	{id="small", nome="Casa pequena", arquivo="default_town_house_small.mts", grupo="Casas"},
	{id="medium", nome="Casa média", arquivo="default_town_house_medium.mts", grupo="Casas"},
	{id="large_1", nome="Casa grande I", arquivo="default_town_house_large_1.mts", grupo="Casas"},
	{id="large_2", nome="Casa grande II", arquivo="default_town_house_large_2.mts", grupo="Casas"},
	{id="medieval", nome="Casa medieval trabalhada", arquivo="house_medieval_fancy_1_90.mts", grupo="Medievais"},
	{id="village_house", nome="Casa de vila", arquivo="house_1_0.mts", grupo="Casas"},
	{id="garden_house", nome="Casa com jardim", arquivo="house_with_garden_1_0.mts", grupo="Casas"},
	{id="small_house", nome="Casa rústica", arquivo="small_house_1_0.mts", grupo="Casas"},
	{id="tower", nome="Torre habitável", arquivo="tower_1_0.mts", grupo="Torres"},
	{id="inn", nome="Hospedaria", arquivo="inn_1_0.mts", grupo="Grandes"},
	{id="library", nome="Biblioteca", arquivo="library_1_0.mts", grupo="Grandes"},
	{id="pub", nome="Taverna", arquivo="pub_1_0.mts", grupo="Grandes"},
	{id="hotel", nome="Hotel da vila", arquivo="default_town_hotel.mts", grupo="Grandes"},
	{id="mill", nome="Moinho", arquivo="mill_1.mts", grupo="Grandes"},
	{id="watermill", nome="Moinho d'água", arquivo="watermill_1.mts", grupo="Grandes"},
	{id="cabin_1", nome="Cabana de troncos I", arquivo="logcabin1.mts", grupo="Cabanas"},
	{id="cabin_2", nome="Cabana de troncos II", arquivo="logcabin2.mts", grupo="Cabanas"},
	{id="cabin_3", nome="Cabana de troncos III", arquivo="logcabin3.mts", grupo="Cabanas"},
	{id="cabin_4", nome="Cabana de troncos IV", arquivo="logcabin4.mts", grupo="Cabanas"},
	{id="cabin_5", nome="Cabana de troncos V", arquivo="logcabin5.mts", grupo="Cabanas"},
	{id="cabin_6", nome="Cabana de troncos VI", arquivo="logcabin6.mts", grupo="Cabanas"},
	{id="cabin_7", nome="Cabana de troncos VII", arquivo="logcabin7.mts", grupo="Cabanas"},
	{id="cabin_8", nome="Cabana de troncos VIII", arquivo="logcabin8.mts", grupo="Cabanas"},
	{id="cabin_9", nome="Cabana de troncos IX", arquivo="logcabin9.mts", grupo="Cabanas"},
	{id="cabin_10", nome="Cabana de troncos X", arquivo="logcabin10.mts", grupo="Cabanas"},
	{id="cabin_11", nome="Cabana de troncos XI", arquivo="logcabin11.mts", grupo="Cabanas"},
	{id="chateau", nome="Château", arquivo="chateau_without_garden.mts", grupo="Grandes"},
}

local castelos = {
	{id="fortaleza", nome="Fortaleza das Quatro Torres", tamanho={x=43,y=18,z=43}},
	{id="alcazar", nome="Alcáçar do Pátio Alto", tamanho={x=55,y=22,z=47}},
	{id="cidadela", nome="Cidadela do Rei", tamanho={x=63,y=25,z=55}},
}

-- Além dos modelos selecionados acima, o painel descobre o restante dos
-- esquemas que a instalação de mg_villages oferece. Isso evita um catálogo
-- incompleto quando o pacote do servidor recebe novas casas.
local arquivo_catalogado = {}
for _, d in ipairs(catalogo) do arquivo_catalogado[d.arquivo] = true end
if schem_path and minetest.get_dir_list then
	for _, arquivo in ipairs(minetest.get_dir_list(schem_path, false)) do
		if arquivo:sub(-4) == ".mts" and not arquivo_catalogado[arquivo] then
			local rotulo = arquivo:gsub("%.mts$", ""):gsub("[_%-]", " ")
			local id = "vila_" .. arquivo:gsub("[^%w]", "_")
			table.insert(catalogo, {id=id, nome="Estrutura da vila: " .. rotulo, arquivo=arquivo, grupo="Vilas"})
			arquivo_catalogado[arquivo] = true
		end
	end
end

local por_id = {}
for _, d in ipairs(catalogo) do por_id[d.id] = d end
for _, d in ipairs(castelos) do d.castelo = true; por_id[d.id] = d end

local function tamanho_esquema(def)
	if def.tamanho then return vector.new(def.tamanho) end
	if not schem_path then return nil end
	local esquema = minetest.read_schematic(schem_path .. def.arquivo, {})
	return esquema and esquema.size and vector.new(esquema.size) or nil
end

-- Castelos originais: muralha com ameias, quatro torres, portão, pátio e torre
-- de menagem. Eles usam a ideia medieval geral, sem reproduzir plantas de outros jogos.
local function construir_castelo(inicio, tamanho)
	local pedra, tijolo, madeira = "default:cobble", "default:stonebrick", "default:wood"
	local function colocar(x,y,z,n) minetest.set_node(vector.add(inicio,{x=x,y=y,z=z}), {name=n}) end
	local function parede(x,z)
		for y=0,tamanho.y-7 do colocar(x,y,z,pedra) end
		for y=tamanho.y-6,tamanho.y-4 do if (x+z+y)%2==0 then colocar(x,y,z,tijolo) end end
	end
	for x=0,tamanho.x-1 do for z=0,tamanho.z-1 do
		if x==0 or z==0 or x==tamanho.x-1 or z==tamanho.z-1 then
			local portao = z==0 and x>=math.floor(tamanho.x/2)-2 and x<=math.floor(tamanho.x/2)+2
			if not portao then parede(x,z) end
		end
	end end
	for x=3,tamanho.x-4 do for z=3,tamanho.z-4 do colocar(x,0,z,tijolo) end end
	local torres={{2,2},{tamanho.x-3,2},{2,tamanho.z-3},{tamanho.x-3,tamanho.z-3}}
	for _,t in ipairs(torres) do for x=t[1]-2,t[1]+2 do for z=t[2]-2,t[2]+2 do
		for y=0,tamanho.y-1 do if x==t[1]-2 or x==t[1]+2 or z==t[2]-2 or z==t[2]+2 then colocar(x,y,z,tijolo) end end
		if (x+t[1]+z+t[2])%2==0 then colocar(x,tamanho.y,z,tijolo) end
	end end end
	local kx, kz = math.floor(tamanho.x/2), math.floor(tamanho.z/2)+5
	for x=kx-6,kx+6 do for z=kz-5,kz+5 do
		for y=1,tamanho.y-7 do if x==kx-6 or x==kx+6 or z==kz-5 or z==kz+5 then colocar(x,y,z,pedra) end end
		if (x+z)%2==0 then colocar(x,tamanho.y-6,z,tijolo) end
	end end
	for x=kx-2,kx+2 do for y=1,3 do colocar(x,y,3,"air") end end
	for x=math.floor(tamanho.x/2)-2,math.floor(tamanho.x/2)+2 do for y=0,4 do colocar(x,y,0,"air") end end
	for x=5,tamanho.x-6,6 do for z=5,tamanho.z-6,6 do colocar(x,1,z,madeira) end end
end

minetest.register_node("garrafa_tesouro:marco_deed", {
	description = S("Placa de propriedade (clique para recolher a construção)"),
	tiles = {"default_wood.png^[colorize:#5B2C6F:90"},
	groups = {cracky = 1, not_in_creative_inventory = 1},
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
		-- A área vem do esquema efetivamente colocado; inclui telhado, torres,
		-- placa e ameias, para nunca deixar uma parte pendurada no mundo.
		local fim = vector.add(inicio, {x = tamanho.x - 1, y = tamanho.y + 1, z = tamanho.z - 1})
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

local function colocar_deed(itemstack, placer, pointed_thing, def)
	if not (placer and placer:is_player() and pointed_thing and pointed_thing.above) then return itemstack end
	local inicio, dono = vector.new(pointed_thing.above), placer:get_player_name()
	local tamanho = tamanho_esquema(def)
	if not tamanho then
		minetest.chat_send_player(dono, S("Este esquema não está disponível neste servidor."))
		return itemstack
	end
	local fim = vector.add(inicio, {x=tamanho.x-1,y=tamanho.y,z=tamanho.z-1})
	if minetest.is_protected(inicio, dono) or minetest.is_protected(fim, dono) then return itemstack end
	if def.castelo then
		construir_castelo(inicio, tamanho)
	else
		minetest.place_schematic(inicio, schem_path .. def.arquivo, "0", nil, true)
	end
	-- A placa fica junto à entrada, não escondida no teto: ela mostra o dono e
	-- também é o ponto físico para recolher a construção ao mesmo deed.
	local placa = vector.add(inicio, {x=math.floor(tamanho.x/2), y=1, z=0})
	minetest.set_node(placa, {name = "garrafa_tesouro:marco_deed"})
	local meta = minetest.get_meta(placa)
	meta:set_string("owner", dono)
	meta:set_string("inicio", minetest.serialize(inicio))
	meta:set_string("tamanho", minetest.serialize(tamanho))
	meta:set_string("deed", "garrafa_tesouro:deed_" .. def.id)
	meta:set_string("infotext", S("Propriedade de @1 — @2\nClique para recolher o deed", dono, def.nome))
	itemstack:take_item()
	return itemstack
end

for _, def in ipairs(catalogo) do
	minetest.register_craftitem("garrafa_tesouro:deed_" .. def.id, {
		description = S("Deed: @1\nEstrutura completa; a placa na entrada recolhe para este mesmo papel.", def.nome),
		inventory_image = "default_paper.png^[colorize:#8B5A2B:100",
		stack_max = 1,
		on_place = function(itemstack, placer, pointed_thing) return colocar_deed(itemstack, placer, pointed_thing, def) end,
	})
end
for _, def in ipairs(castelos) do
	minetest.register_craftitem("garrafa_tesouro:deed_" .. def.id, {
		description = S("Deed: @1\nCastelo com muralhas, torres, portão e pátio. Clique na placa da entrada para recolher.", def.nome),
		inventory_image = "default_paper.png^[colorize:#6E6E6E:130",
		stack_max = 1,
		on_place = function(itemstack, placer, pointed_thing) return colocar_deed(itemstack, placer, pointed_thing, def) end,
	})
end

local pagina_catalogo = {}
local function mostrar_catalogo(nome, pagina)
	pagina = math.max(1, pagina or 1); pagina_catalogo[nome] = pagina
	local por_pagina, primeiro = 12, (pagina-1)*12+1
	local formspec = {"formspec_version[4]size[12,9]", "label[0.4,0.35;Catálogo de casas e castelos — escolha um deed para testar]"}
	for i=0,por_pagina-1 do
		local def = por_id[(catalogo[primeiro+i] or castelos[primeiro+i-#catalogo]) and (catalogo[primeiro+i] or castelos[primeiro+i-#catalogo]).id]
		if def then
			local x,y = (i%3)*4, 0.9+math.floor(i/3)*1.7
			local cor = def.castelo and "6E6E6E" or "8B5A2B"
			formspec[#formspec+1] = string.format("image[%0.1f,%0.1f;0.8,1;default_paper.png^[colorize:#%s:100]", x+.2,y,cor)
			formspec[#formspec+1] = string.format("button[%0.1f,%0.1f;3.0,0.7;pegar_%s;%s]",x+1,y,def.id,minetest.formspec_escape(def.nome))
			formspec[#formspec+1] = string.format("label[%0.1f,%0.1f;%s]",x+1,y+.75,minetest.formspec_escape(def.grupo or "Castelos"))
		end
	end
	formspec[#formspec+1] = "button[0.4,8.2;2,0.6;anterior;< Anterior]button[2.6,8.2;2,0.6;proxima;Próxima >]button_exit[9.2,8.2;2,0.6;sair;Fechar]"
	minetest.show_formspec(nome, "garrafa_tesouro:catalogo", table.concat(formspec))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "garrafa_tesouro:catalogo" then return end
	local nome = player:get_player_name()
	if not minetest.check_player_privs(nome, {give=true}) then return true end
	if fields.anterior then return mostrar_catalogo(nome, (pagina_catalogo[nome] or 1)-1) end
	if fields.proxima then return mostrar_catalogo(nome, (pagina_catalogo[nome] or 1)+1) end
	for id in pairs(por_id) do if fields["pegar_"..id] then
		local sobra = player:get_inventory():add_item("main", "garrafa_tesouro:deed_"..id)
		if not sobra:is_empty() then minetest.add_item(player:get_pos(), sobra) end
		minetest.chat_send_player(nome, S("Deed recebido: @1", por_id[id].nome)); return true
	end end
	return true
end)

minetest.register_chatcommand("casas", {description=S("Abre o catálogo de casas e castelos para teste (admin)"), privs={give=true}, func=function(nome) mostrar_catalogo(nome,1); return true end})
minetest.register_chatcommand("deeds", {description=S("Abre o catálogo de deeds (admin)"), privs={give=true}, func=function(nome) mostrar_catalogo(nome,1); return true end})

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
		-- Um único deed bom por tesouro: não enche o baú com papéis repetidos.
		-- Todas as casas de vila e os três castelos entram no sorteio.
		local premio = math.random(1, 4) == 1 and castelos[math.random(#castelos)] or catalogo[math.random(#catalogo)]
		inv:add_item("main", ItemStack("garrafa_tesouro:deed_" .. premio.id))
		if minetest.registered_items["animalia:spawn_horse"] then inv:add_item("main", ItemStack("animalia:spawn_horse")) end
		inv:add_item("main", ItemStack("default:gold_ingot " .. math.random(2, 6)))

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
