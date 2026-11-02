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
	{id="bodiam", nome="Castelo de Bodiam", tamanho={x=57,y=22,z=57}, estilo="bodiam"},
	{id="conwy", nome="Castelo de Conwy", tamanho={x=69,y=28,z=39}, estilo="conwy"},
	{id="krak", nome="Krak des Chevaliers", tamanho={x=77,y=30,z=65}, estilo="krak"},
}

-- Além dos modelos selecionados acima, o painel descobre o restante dos
-- esquemas que a instalação de mg_villages oferece. Isso evita um catálogo
-- incompleto quando o pacote do servidor recebe novas casas.
local arquivo_catalogado = {}
for _, d in ipairs(catalogo) do arquivo_catalogado[d.arquivo] = true end
if schem_path and minetest.get_dir_list then
	for _, arquivo in ipairs(minetest.get_dir_list(schem_path, false)) do
		local base = arquivo:lower()
		-- Mantém todas as construções testáveis (inclusive oficinas, galpões,
		-- tendas e cabanas) e remove só peças isoladas/decorativas.
		local excluir = base:find("bench",1,true) or base:find("field",1,true) or base:find("well",1,true)
			or base:find("lamp",1,true) or base:find("tree",1,true) or base:find("wagon",1,true)
			or base:find("fountain",1,true) or base:find("empty",1,true) or base:find("park",1,true)
			or base:find("cotton",1,true) or base:find("clay_pit",1,true) or base:find("weide",1,true)
		if arquivo:sub(-4) == ".mts" and not excluir and not arquivo_catalogado[arquivo] then
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

-- As vilas antigas foram desenhadas com o mod cottages, que não está presente
-- neste servidor. Nunca entregamos um esquema com "no node": nomes ausentes
-- são convertidos previamente em blocos equivalentes já registrados.
local substituicoes_cache = {}
local equivalentes_cottages = {
	["cottages:roof_straw"]="default:wood", ["cottages:roof_connector_straw"]="default:wood", ["cottages:roof_flat_straw"]="default:wood",
	["cottages:roof_wood"]="default:wood", ["cottages:roof_connector_wood"]="default:wood", ["cottages:roof_flat_wood"]="default:wood",
	["cottages:window_shutter_open"]="default:glass", ["cottages:glass_pane"]="default:glass", ["cottages:glass_pane_side"]="default:glass",
	["cottages:shelf"]="default:wood", ["cottages:bench"]="default:wood", ["cottages:table"]="default:wood", ["cottages:wood_flat"]="default:wood",
	["cottages:wagon_wheel"]="default:wood", ["cottages:fence_small"]="default:wood", ["cottages:gate_open"]="default:wood", ["cottages:gate_closed"]="default:wood",
	["cottages:hatch_wood"]="default:wood", ["cottages:half_door"]="default:wood", ["cottages:half_door_inverted"]="default:wood",
	["cottages:bed_head"]="default:wood", ["cottages:bed_foot"]="default:wood", ["cottages:barrel"]="default:chest", ["cottages:barrel_lying"]="default:chest",
	["cottages:chest_work"]="default:chest", ["cottages:chest_private"]="default:chest", ["cottages:loam"]="default:dirt", ["cottages:straw_ground"]="default:dirt",
	["cottages:straw_bale"]="default:dirt", ["cottages:wool_tent"]="default:wood", ["cottages:washing"]="default:wood",
	["doors:door_wood_t_1"]="default:wood", ["poisonivy:seedling"]="default:grass_1",
}
local function substituicoes_para(def)
	if substituicoes_cache[def.id] then return substituicoes_cache[def.id] end
	local lista = {}
	if handle_schematics and handle_schematics.analyze_mts_file and schem_path then
		local dados = handle_schematics.analyze_mts_file(schem_path .. def.arquivo:gsub("%.mts$", ""))
		if dados and dados.nodenames then for _, nome in ipairs(dados.nodenames) do
			if nome ~= "air" and not minetest.registered_nodes[nome] then
				table.insert(lista, {nome, equivalentes_cottages[nome] or "default:stone"})
			end
		end end
	end
	substituicoes_cache[def.id] = lista
	return lista
end

-- Castelos originais: muralha com ameias, quatro torres, portão, pátio e torre
-- de menagem. Eles usam a ideia medieval geral, sem reproduzir plantas de outros jogos.
local function construir_castelo(inicio, tamanho, estilo)
	-- Este jogo não registra default:stonebrick; usar stone/cobble evita nós
	-- desconhecidos e mantém a leitura de muralha medieval.
	local pedra, tijolo, madeira = "default:cobble", "default:stone", "default:wood"
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
	if estilo == "bodiam" then
		-- Bodiam: portaria central e duas torres avançadas protegendo a entrada.
		table.insert(torres, {math.floor(tamanho.x/2)-4,2}); table.insert(torres, {math.floor(tamanho.x/2)+4,2})
	elseif estilo == "conwy" then
		-- Conwy: oito torres, quatro nos cantos e quatro no meio das cortinas.
		table.insert(torres, {math.floor(tamanho.x/2),2}); table.insert(torres, {math.floor(tamanho.x/2),tamanho.z-3})
		table.insert(torres, {2,math.floor(tamanho.z/2)}); table.insert(torres, {tamanho.x-3,math.floor(tamanho.z/2)})
	elseif estilo == "krak" then
		-- Krak: torres externas regulares em uma segunda linha defensiva.
		for x=9,tamanho.x-10,14 do table.insert(torres,{x,2}); table.insert(torres,{x,tamanho.z-3}) end
	end
	for _,t in ipairs(torres) do for x=t[1]-2,t[1]+2 do for z=t[2]-2,t[2]+2 do
		for y=0,tamanho.y-1 do if x==t[1]-2 or x==t[1]+2 or z==t[2]-2 or z==t[2]+2 then colocar(x,y,z,tijolo) end end
		if (x+t[1]+z+t[2])%2==0 then colocar(x,tamanho.y,z,tijolo) end
	end end end
	local kx, kz = math.floor(tamanho.x/2), math.floor(tamanho.z/2)+(estilo == "bodiam" and 10 or 5)
	for x=kx-6,kx+6 do for z=kz-5,kz+5 do
		for y=1,tamanho.y-7 do if x==kx-6 or x==kx+6 or z==kz-5 or z==kz+5 then colocar(x,y,z,pedra) end end
		if (x+z)%2==0 then colocar(x,tamanho.y-6,z,tijolo) end
	end end
	for x=kx-2,kx+2 do for y=1,3 do colocar(x,y,3,"air") end end
	for x=math.floor(tamanho.x/2)-2,math.floor(tamanho.x/2)+2 do for y=0,4 do colocar(x,y,0,"air") end end
	for x=5,tamanho.x-6,6 do for z=5,tamanho.z-6,6 do colocar(x,1,z,madeira) end end
	if estilo == "bodiam" then
		for x=7,tamanho.x-8 do for y=1,6 do if x%2==0 then colocar(x,y,8,pedra); colocar(x,y,tamanho.z-9,pedra) end end end
	elseif estilo == "conwy" then
		-- Torre de menagem octogonal, distinta do salão retangular da fortaleza.
		for x=kx-7,kx+7 do for z=kz-7,kz+7 do
			if math.abs(x-kx)+math.abs(z-kz) >= 9 and math.abs(x-kx)+math.abs(z-kz) <= 13 then
				for y=1,tamanho.y-3 do colocar(x,y,z,tijolo) end
			end
		end end
	elseif estilo == "krak" then
		-- Segunda muralha interna elevada e corredor exposto entre os dois anéis.
		for x=9,tamanho.x-10 do for z=9,tamanho.z-10 do
			if x==9 or z==9 or x==tamanho.x-10 or z==tamanho.z-10 then for y=1,tamanho.y-9 do colocar(x,y,z,tijolo) end end
		end end
	end
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
	if def.castelo and def.estilo ~= "esquema" then
		construir_castelo(inicio, tamanho, def.estilo)
	else
		minetest.place_schematic(inicio, schem_path .. def.arquivo, "0", substituicoes_para(def), true)
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
local miniaturas_esquema = {}
local function textura_no(nome)
	local def = minetest.registered_nodes[nome]
	local tile = def and def.tiles and def.tiles[1]
	if type(tile) == "table" then tile = tile.name end
	return tile or "unknown_node.png"
end
-- Projeção superior simplificada do arquivo MTS: cada quadrado é o bloco real
-- mais alto daquela coluna. Limitamos a 7x7 para o formspec continuar leve.
local function miniatura_real(def, px, py)
	if def.castelo or not (handle_schematics and handle_schematics.analyze_mts_file) then return "image["..px..","..py..";1.2,1.2;default_cobble.png]" end
	local dados = miniaturas_esquema[def.id]
	if not dados then
		dados = handle_schematics.analyze_mts_file(schem_path .. def.arquivo:gsub("%.mts$", ""))
		miniaturas_esquema[def.id] = dados or false
	end
	if not dados then return "image["..px..","..py..";1.2,1.2;default_paper.png]" end
	local partes, nx, nz = {}, math.min(7, dados.size.x), math.min(7, dados.size.z)
	for iz=1,nz do for ix=1,nx do
		local sx = math.min(dados.size.x, math.floor((ix-.5)*dados.size.x/nx)+1)
		local sz = math.min(dados.size.z, math.floor((iz-.5)*dados.size.z/nz)+1)
		local nome = "air"
		for y=dados.size.y,1,-1 do local no=dados.scm_data_cache[y] and dados.scm_data_cache[y][sx] and dados.scm_data_cache[y][sx][sz]; if no and dados.nodenames[no[1]] and dados.nodenames[no[1]] ~= "air" then nome=dados.nodenames[no[1]]; break end end
		if nome ~= "air" then partes[#partes+1] = string.format("image[%0.2f,%0.2f;%.2f,%.2f;%s]",px+(ix-1)*1.2/nx,py+(iz-1)*1.2/nz,1.2/nx+.01,1.2/nz+.01,textura_no(nome)) end
	end end
	return table.concat(partes)
end
local function mostrar_catalogo(nome, pagina)
	pagina = math.max(1, pagina or 1); pagina_catalogo[nome] = pagina
	local por_pagina, primeiro = 12, (pagina-1)*12+1
	local formspec = {"formspec_version[4]size[12,9]", "label[0.4,0.35;Catálogo de casas e castelos — escolha um deed para testar]"}
	for i=0,por_pagina-1 do
		local def = por_id[(catalogo[primeiro+i] or castelos[primeiro+i-#catalogo]) and (catalogo[primeiro+i] or castelos[primeiro+i-#catalogo]).id]
		if def then
			local x,y = (i%3)*4, 0.9+math.floor(i/3)*1.7
			formspec[#formspec+1] = miniatura_real(def, x+.1, y-.1)
			formspec[#formspec+1] = string.format("button[%0.1f,%0.1f;2.45,0.7;pegar_%s;Pegar deed]",x+1.45,y,def.id)
			formspec[#formspec+1] = string.format("label[%0.1f,%0.1f;%s]",x+1.45,y+.75,minetest.formspec_escape(def.nome))
		end
	end
	formspec[#formspec+1] = "button[0.4,8.2;2,0.6;anterior;< Anterior]button[2.6,8.2;2,0.6;proxima;Próxima >]button_exit[9.2,8.2;2,0.6;sair;Fechar]"
	minetest.show_formspec(nome, "garrafa_tesouro:catalogo", table.concat(formspec))
end

-- Renderiza a fachada real do arquivo .mts selecionado usando as texturas dos
-- próprios nós. Isto não é um ícone genérico: cada deed lê sua construção.
local previews_deed = {}
local function mostrar_previa(nome, def)
	if def.castelo then
		return minetest.show_formspec(nome, "garrafa_tesouro:preview_"..def.id,
			"formspec_version[4]size[12,9]label[0.4,0.4;"..minetest.formspec_escape(def.nome).."]"..
			"image[2.0,1.0;8,6;garrafa_tesouro_preview_casa.png]"..
			"label[0.7,7.3;Castelo estrutural: muralhas, quatro torres, portão, pátio e torre central.]"..
			"button[3.4,8;2.4,0.7;pegar_"..def.id..";Pegar deed]button[6.1,8;2.4,0.7;voltar;Voltar]")
	end
	if not (handle_schematics and handle_schematics.analyze_mts_file and build_chest and build_chest.preview_image_create_views) then
		return minetest.chat_send_player(nome, S("O renderizador de prévias não foi carregado; tente novamente após reiniciar o servidor."))
	end
	local chave = "garrafa_tesouro_" .. def.id
	if not previews_deed[chave] then
		local caminho = schem_path .. def.arquivo:gsub("%.mts$", "")
		local dados = handle_schematics.analyze_mts_file(caminho)
		if not dados then return minetest.chat_send_player(nome, S("Não foi possível ler a estrutura deste deed.")) end
		dados.yoff = 0
		dados.preview = build_chest.preview_image_create_views(dados)
		build_chest.building = build_chest.building or {}
		build_chest.building[chave] = dados
		previews_deed[chave] = true
	end
	local imagem = build_chest.preview_image_formspec(chave, {}, "front")
	minetest.show_formspec(nome, "garrafa_tesouro:preview_"..def.id,
		"formspec_version[4]size[12,11]label[0.4,0.3;"..minetest.formspec_escape(def.nome).." — prévia da estrutura real]"..
		imagem.."button[3.3,10.1;2.4,0.7;pegar_"..def.id..";Pegar deed]button[6.2,10.1;2.4,0.7;voltar;Voltar]")
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "garrafa_tesouro:catalogo" and not formname:find("^garrafa_tesouro:preview_") then return end
	local nome = player:get_player_name()
	if not minetest.check_player_privs(nome, {give=true}) then return true end
	if fields.voltar then return mostrar_catalogo(nome, pagina_catalogo[nome] or 1) end
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
