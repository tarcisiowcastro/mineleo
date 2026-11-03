-- Garrafa do Tesouro: ao usar, marca um tesouro aleatório no mapa (abre o GPS/mapa do
-- Luanti via discovery_maps) e enterra um baú pirata ~6 blocos abaixo da superfície
-- naquele ponto.
local S = minetest.get_translator("garrafa_tesouro")

local MIN_DIST = 64 -- distância mínima no mesmo planeta, em blocos
local MAX_DIST = 180
local PROFUNDIDADE = 3
local HOUSE_GAP = 2
local storage = minetest.get_mod_storage()
local houses = minetest.deserialize(storage:get_string("houses")) or {}
local forms_open = {}

minetest.register_privilege("house_admin", {
	description = S("Pode administrar qualquer casa colocada por escritura"),
	give_to_singleplayer = false,
})

local function can_manage_house(player, house)
	return player and house and (player:get_player_name() == house.owner
		or minetest.check_player_privs(player, {house_admin = true}))
end

local function save_houses()
	storage:set_string("houses", minetest.serialize(houses))
end

local function house_id(pos)
	return minetest.pos_to_string(pos)
end

local function rotated_size(size, rotation)
	if rotation == "90" or rotation == "270" then
		return {x = size.z, y = size.y, z = size.x}
	end
	return vector.new(size)
end

local function house_bounds(start, size, rotation)
	local actual = rotated_size(size, rotation or "0")
	return vector.new(start), vector.add(start, {x = actual.x - 1, y = actual.y + 1, z = actual.z - 1})
end

local function overlaps(a1, a2, b1, b2)
	return a1.x <= b2.x and a2.x >= b1.x
		and a1.y <= b2.y and a2.y >= b1.y
		and a1.z <= b2.z and a2.z >= b1.z
end

local function house_collision(start, size, rotation, ignored_id)
	local p1, p2 = house_bounds(start, size, rotation)
	p1 = vector.subtract(p1, HOUSE_GAP)
	p2 = vector.add(p2, HOUSE_GAP)
	for id, house in pairs(houses) do
		if id ~= ignored_id and house.start and house.size then
			local h1, h2 = house_bounds(house.start, house.size, house.rotation)
			if overlaps(p1, p2, h1, h2) then return house end
		end
	end
	return nil
end

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
local function construir_castelo(inicio, tamanho, estilo, rotation)
	-- Este jogo não registra default:stonebrick; usar stone/cobble evita nós
	-- desconhecidos e mantém a leitura de muralha medieval.
	local pedra, tijolo, madeira = "default:cobble", "default:stone", "default:wood"
	local function colocar(x,y,z,n)
		local rx, rz = x, z
		if rotation == "90" then rx, rz = tamanho.z - 1 - z, x
		elseif rotation == "180" then rx, rz = tamanho.x - 1 - x, tamanho.z - 1 - z
		elseif rotation == "270" then rx, rz = z, tamanho.x - 1 - x end
		minetest.set_node(vector.add(inicio,{x=rx,y=y,z=rz}), {name=n})
	end
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
	can_dig = function() return false end,
	on_blast = function() return {} end,
})

local MARKER_NODE = minetest.registered_nodes["building_sign:building_marker"]
	and "building_sign:building_marker" or "garrafa_tesouro:marco_deed"
local place_beacon

local function update_area_access(house)
	if not areas or not house.area_id or not areas.areas[house.area_id] then return end
	for _, id in ipairs(house.guest_area_ids or {}) do
		if areas.areas[id] then areas:remove(id) end
	end
	house.guest_area_ids = {}
	for _, guest in ipairs(house.guests or {}) do
		local id = areas:add(guest, "Acesso à casa de " .. house.owner,
			house.start, house.finish, house.area_id)
		table.insert(house.guest_area_ids, id)
	end
	areas:save()
end

local function add_house_area(house)
	if not areas then return end
	house.area_id = areas:add(house.owner, "Casa de " .. house.owner,
		house.start, house.finish, nil)
	update_area_access(house)
	areas:save()
end

local function remove_house_area(house)
	if areas and house.area_id and areas.areas[house.area_id] then
		areas:remove(house.area_id, true)
		areas:save()
	end
end

local function marker_position(start, size, rotation)
	local actual = rotated_size(size, rotation or "0")
	return vector.add(start, {x = math.floor(actual.x / 2), y = 1, z = 0})
end

local function beacon_position(house)
	local actual = rotated_size(house.size, house.rotation or "0")
	return {x = house.start.x + math.floor(actual.x / 2), y = house.finish.y + 5,
		z = house.start.z + math.floor(actual.z / 2)}
end

local function place_marker(house)
	local pos = marker_position(house.start, house.size, house.rotation)
	minetest.set_node(pos, {name = MARKER_NODE, param2 = 4})
	local meta = minetest.get_meta(pos)
	meta:set_string("house_id", house.id)
	meta:set_string("owner", house.owner)
	meta:set_string("inicio", minetest.serialize(house.start))
	meta:set_string("tamanho", minetest.serialize(house.size))
	meta:set_string("deed", house.deed)
	meta:set_string("infotext", "Casa de " .. house.owner .. " — clique para informações")
	if place_beacon then place_beacon(house) end
	return pos
end

local function users_from_text(text)
	local users, known = {}, {}
	for name in (text or ""):gmatch("[^,%s;]+") do
		if not known[name] then known[name] = true; table.insert(users, name) end
	end
	return users
end

local function house_form(player, pos, house)
	local owner = can_manage_house(player, house)
	local guests = table.concat(house.guests or {}, ", ")
	local built = os.date("%d/%m/%Y %H:%M", house.built_at or os.time())
	local formspec = "formspec_version[4]size[10,8]" ..
		"label[0.5,0.5;Casa: " .. minetest.formspec_escape(house.name or "") .. "]" ..
		"label[0.5,1.1;Dono: " .. minetest.formspec_escape(house.owner) .. "]" ..
		"label[0.5,1.6;Construída em: " .. built .. "]" ..
		"label[0.5,2.1;Moradores autorizados: " .. minetest.formspec_escape(guests ~= "" and guests or "ninguém além do dono") .. "]"
	if owner then
		formspec = formspec .. "field[0.5,3.2;9,0.8;guests;Usuários que podem entrar (separe por vírgulas);" .. minetest.formspec_escape(guests) .. "]" ..
			"button[0.5,4;2.2,0.8;save_guests;Salvar acessos]" ..
			"button[2.9,4;2.2,0.8;collect;Voltar a escritura]" ..
			"button[5.3,4;1.8,0.8;rotate_left;Girar ←]button[7.2,4;1.8,0.8;rotate_right;Girar →]" ..
			"label[0.5,5.15;Mover a casa inteira:]" ..
			"button[0.5,5.6;1.3,0.8;move_n;Norte]button[1.9,5.6;1.3,0.8;move_s;Sul]button[3.3,5.6;1.3,0.8;move_w;Oeste]button[4.7,5.6;1.3,0.8;move_e;Leste]" ..
			"button[6.2,5.6;1.3,0.8;move_up;Subir]button[7.6,5.6;1.3,0.8;move_down;Descer]"
	end
	forms_open[player:get_player_name()] = pos
	minetest.show_formspec(player:get_player_name(), "garrafa_tesouro:house", formspec)
end

local function recolher_deed(pos, clicker)
		local meta = minetest.get_meta(pos)
		local house_id = meta:get_string("house_id")
		local recorded_house = houses[house_id]
		if recorded_house and not can_manage_house(clicker, recorded_house) then
			minetest.chat_send_player(clicker:get_player_name(), S("Somente o dono ou um administrador de casas pode recolhê-lo."))
			return false
		end
		local id = house_id
		local house = recorded_house
		if not house and meta:get_string("owner") ~= clicker:get_player_name()
			and not minetest.check_player_privs(clicker, {house_admin = true}) then
			minetest.chat_send_player(clicker:get_player_name(), S("Somente o dono ou um administrador de casas pode recolhê-lo."))
			return false
		end
		local inicio = house and house.start or minetest.deserialize(meta:get_string("inicio"))
		local tamanho = house and house.size or minetest.deserialize(meta:get_string("tamanho"))
		local deed = meta:get_string("deed")
		if not (inicio and tamanho) then return false end
		-- A área vem do esquema efetivamente colocado; inclui telhado, torres,
		-- placa e ameias, para nunca deixar uma parte pendurada no mundo.
		local fim = house and house.finish or vector.add(inicio, {x = tamanho.x - 1, y = tamanho.y + 1, z = tamanho.z - 1})
		for x = inicio.x, fim.x do for y = inicio.y, fim.y do for z = inicio.z, fim.z do
			local p = {x = x, y = y, z = z}
			minetest.set_node(p, {name = "air"})
		end end end
		if house then
			minetest.set_node(beacon_position(house), {name = "air"})
			remove_house_area(house)
			houses[id] = nil
			save_houses()
		end
		local sobra = clicker:get_inventory():add_item("main", deed)
		if not sobra:is_empty() then minetest.add_item(clicker:get_pos(), sobra) end
		minetest.chat_send_player(clicker:get_player_name(), S("Construção recolhida e transformada novamente em deed."))
		return true
end

local function marker_rightclick(pos, node, clicker)
	local meta = minetest.get_meta(pos)
	local house = houses[meta:get_string("house_id")]
	if house then house_form(clicker, pos, house); return end
	recolher_deed(pos, clicker)
end

local function is_deed_marker(pos)
	local meta = minetest.get_meta(pos)
	return meta:get_string("house_id") ~= ""
		or (meta:get_string("deed") ~= "" and meta:get_string("inicio") ~= "")
end

minetest.register_node("garrafa_tesouro:house_beacon", {
	description = S("Marcador amarelo da casa"),
	drawtype = "plantlike",
	tiles = {"garrafa_tesouro_house_marker_yellow.png"},
	inventory_image = "garrafa_tesouro_house_marker_yellow.png",
	wield_image = "garrafa_tesouro_house_marker_yellow.png",
	visual_scale = 0.75,
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	groups = {not_in_creative_inventory = 1},
	drop = "",
	can_dig = function() return false end,
	on_blast = function() return {} end,
	on_rightclick = function(pos, node, clicker)
		local house = houses[minetest.get_meta(pos):get_string("house_id")]
		if house then house_form(clicker, pos, house) end
	end,
})

place_beacon = function(house)
	local pos = beacon_position(house)
	minetest.set_node(pos, {name = "garrafa_tesouro:house_beacon"})
	minetest.get_meta(pos):set_string("house_id", house.id)
end

minetest.override_item("garrafa_tesouro:marco_deed", {on_rightclick = marker_rightclick})
if MARKER_NODE == "building_sign:building_marker" then
	local original = minetest.registered_nodes[MARKER_NODE].on_rightclick
	local original_can_dig = minetest.registered_nodes[MARKER_NODE].can_dig
	local original_on_blast = minetest.registered_nodes[MARKER_NODE].on_blast
	minetest.override_item(MARKER_NODE, {on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if minetest.get_meta(pos):get_string("house_id") ~= "" then
			return marker_rightclick(pos, node, clicker)
		end
		if original then return original(pos, node, clicker, itemstack, pointed_thing) end
	end, can_dig = function(pos, player)
		if is_deed_marker(pos) then return false end
		if original_can_dig then return original_can_dig(pos, player) end
		return true
	end, on_blast = function(pos)
		if is_deed_marker(pos) then return {} end
		if original_on_blast then return original_on_blast(pos) end
	end})
end

minetest.register_chatcommand("recolher_deed", {
	description = S("Recolhe a construção do deed mais próxima"),
	func = function(nome)
		local jogador = minetest.get_player_by_name(nome)
		if not jogador then return false end
		local pos = jogador:get_pos()
		local raio = 96
		local marcos = minetest.find_nodes_in_area(
			vector.subtract(pos, raio), vector.add(pos, raio), {MARKER_NODE, "garrafa_tesouro:marco_deed"})
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
	local rotation = "0"
	local _, fim = house_bounds(inicio, tamanho, rotation)
	if minetest.is_protected(inicio, dono) or minetest.is_protected(fim, dono) then return itemstack end
	if house_collision(inicio, tamanho, rotation) then
		minetest.chat_send_player(dono, S("Não há espaço: deixe pelo menos @1 blocos livres entre as casas.", HOUSE_GAP))
		return itemstack
	end
	if def.castelo and def.estilo ~= "esquema" then
		construir_castelo(inicio, tamanho, def.estilo, rotation)
	else
		minetest.place_schematic(inicio, schem_path .. def.arquivo, rotation, substituicoes_para(def), true)
	end
	local id = house_id(inicio)
	local house = {id=id, owner=dono, start=inicio, size=tamanho, rotation=rotation,
		finish=fim, deed="garrafa_tesouro:deed_" .. def.id, def_id=def.id, name=def.nome,
		built_at=os.time(), guests={}}
	houses[id] = house
	add_house_area(house)
	place_marker(house)
	save_houses()
	itemstack:take_item()
	return itemstack
end

local rotations = { ["0"] = 1, ["90"] = 2, ["180"] = 3, ["270"] = 4 }
local rotation_values = {"0", "90", "180", "270"}

local function rebuild_house(house, new_start, new_rotation, player)
	if house_collision(new_start, house.size, new_rotation, house.id) then
		minetest.chat_send_player(player:get_player_name(), S("Não há espaço suficiente entre esta e outra casa."))
		return false
	end
	local def = por_id[house.def_id]
	if not def then return false end
	local _, new_finish = house_bounds(new_start, house.size, new_rotation)
	if not minetest.check_player_privs(player, {house_admin = true})
		and (minetest.is_protected(new_start, player:get_player_name())
		or minetest.is_protected(new_finish, player:get_player_name())) then
		minetest.chat_send_player(player:get_player_name(), S("A nova posição está protegida."))
		return false
	end
	minetest.set_node(beacon_position(house), {name="air"})
	for x = house.start.x, house.finish.x do for y = house.start.y, house.finish.y do for z = house.start.z, house.finish.z do
		minetest.set_node({x=x, y=y, z=z}, {name="air"})
	end end end
	if def.castelo and def.estilo ~= "esquema" then
		construir_castelo(new_start, house.size, def.estilo, new_rotation)
	else
		minetest.place_schematic(new_start, schem_path .. def.arquivo, new_rotation, substituicoes_para(def), true)
	end
	remove_house_area(house)
	house.start, house.finish, house.rotation = vector.new(new_start), new_finish, new_rotation
	add_house_area(house)
	place_marker(house)
	save_houses()
	return true
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "garrafa_tesouro:house" then return end
	local pos = forms_open[player:get_player_name()]
	forms_open[player:get_player_name()] = nil
	if not pos then return true end
	if fields.quit then return true end
	local house = houses[minetest.get_meta(pos):get_string("house_id")]
	if not can_manage_house(player, house) then return true end
	if fields.save_guests then
		house.guests = users_from_text(fields.guests)
		update_area_access(house)
		save_houses()
		minetest.chat_send_player(player:get_player_name(), S("Acessos da casa atualizados."))
	elseif fields.collect then
		recolher_deed(pos, player)
		return true
	elseif fields.rotate_left or fields.rotate_right then
		local current = rotations[house.rotation or "0"] or 1
		local delta = fields.rotate_left and -1 or 1
		local next_index = ((current - 1 + delta) % #rotation_values) + 1
		rebuild_house(house, house.start, rotation_values[next_index], player)
	else
		local moves = {
			move_n={x=0,y=0,z=-1}, move_s={x=0,y=0,z=1}, move_w={x=-1,y=0,z=0},
			move_e={x=1,y=0,z=0}, move_up={x=0,y=1,z=0}, move_down={x=0,y=-1,z=0},
		}
		for field, offset in pairs(moves) do
			if fields[field] then rebuild_house(house, vector.add(house.start, offset), house.rotation, player); break end
		end
	end
	-- Re-open the same panel after every non-destructive action. The marker may
	-- have moved with the house, so use its new position rather than the old one.
	house_form(player, marker_position(house.start, house.size, house.rotation), house)
	return true
end)

-- Existing large deed stones are transparently upgraded when their mapblock
-- loads. New houses always use the small marker_desc sign above the doorway.
minetest.register_lbm({
	name = "garrafa_tesouro:upgrade_deed_marker",
	nodenames = {"garrafa_tesouro:marco_deed", "building_sign:building_marker"}, run_at_every_load = false,
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local known = houses[meta:get_string("house_id")]
		if known then place_beacon(known); return end
		local start, size = minetest.deserialize(meta:get_string("inicio")), minetest.deserialize(meta:get_string("tamanho"))
		if not (start and size) then return end
		local id = house_id(start)
		local _, finish = house_bounds(start, size, "0")
		local deed = meta:get_string("deed")
		local def_id = deed:match("garrafa_tesouro:deed_(.+)$")
		local house = {id=id, owner=meta:get_string("owner"), start=start, size=size, rotation="0", finish=finish,
			deed=deed, def_id=def_id, name=(por_id[def_id] and por_id[def_id].nome) or "Casa", built_at=os.time(), guests={}}
		houses[id] = house
		add_house_area(house)
		minetest.set_node(pos, {name=MARKER_NODE, param2=4})
		place_marker(house)
		save_houses()
	end,
})

-- A marker may have been removed before its protection was introduced. House
-- records are persistent, so restore both controls from that record at server
-- start instead of leaving the house impossible to collect or administer.
minetest.register_on_mods_loaded(function()
	minetest.after(0, function()
		for _, house in pairs(houses) do
			if house.start and house.size then
				local house_to_restore = house
				house.rotation = house.rotation or "0"
				if not house.finish then
					local _, finish = house_bounds(house.start, house.size, house.rotation)
					house.finish = finish
				end
				local marker = marker_position(house_to_restore.start, house_to_restore.size, house_to_restore.rotation)
				local beacon = beacon_position(house_to_restore)
				minetest.emerge_area(marker, beacon, function(_, action, remaining)
					if remaining ~= 0 or action == "cancelled" then return end
					place_marker(house_to_restore)
				end)
			end
		end
		save_houses()
	end)
end)

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
-- Fachada frontal do arquivo MTS: a primeira face visível ao entrar pela porta.
-- Cada quadrado vem do bloco real do esquema; limitamos a 7x7 para o formspec.
local function miniatura_real(def, px, py)
	if def.castelo or not (handle_schematics and handle_schematics.analyze_mts_file) then return "image["..px..","..py..";1.2,1.2;default_cobble.png]" end
	local dados = miniaturas_esquema[def.id]
	if not dados then
		dados = handle_schematics.analyze_mts_file(schem_path .. def.arquivo:gsub("%.mts$", ""))
		miniaturas_esquema[def.id] = dados or false
	end
	if not dados then return "image["..px..","..py..";1.2,1.2;default_paper.png]" end
	local partes, nx, ny = {}, math.min(7, dados.size.x), math.min(7, dados.size.y)
	for iy=1,ny do for ix=1,nx do
		local sx = math.min(dados.size.x, math.floor((ix-.5)*dados.size.x/nx)+1)
		local sy = math.max(1, dados.size.y-math.floor((iy-.5)*dados.size.y/ny))
		local nome = "air"
		for z=1,dados.size.z do local no=dados.scm_data_cache[sy] and dados.scm_data_cache[sy][sx] and dados.scm_data_cache[sy][sx][z]; if no and dados.nodenames[no[1]] and dados.nodenames[no[1]] ~= "air" then nome=dados.nodenames[no[1]]; break end end
		if nome ~= "air" then partes[#partes+1] = string.format("image[%0.2f,%0.2f;%.2f,%.2f;%s]",px+(ix-1)*1.2/nx,py+(iy-1)*1.2/ny,1.2/nx+.01,1.2/ny+.01,textura_no(nome)) end
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
			formspec[#formspec+1] = string.format("button[%0.1f,%0.1f;2.45,0.7;ver_%s;Ver em detalhes]",x+1.45,y,def.id)
			formspec[#formspec+1] = string.format("label[%0.1f,%0.1f;%s]",x+1.45,y+.75,minetest.formspec_escape(def.nome))
		end
	end
	formspec[#formspec+1] = "button[0.4,8.2;2,0.6;anterior;< Anterior]button[2.6,8.2;2,0.6;proxima;Próxima >]button_exit[9.2,8.2;2,0.6;sair;Fechar]"
	minetest.show_formspec(nome, "garrafa_tesouro:catalogo", table.concat(formspec))
end

-- Renderiza a fachada real do arquivo .mts selecionado usando as texturas dos
-- próprios nós. Isto não é um ícone genérico: cada deed lê sua construção.
local previews_deed = {}
local function mostrar_previa(nome, def, lado)
	if def.castelo then
		local imagem = def.estilo == "bodiam" and "garrafa_tesouro_preview_casa.png"
			or def.estilo == "conwy" and "garrafa_tesouro_preview_alcazar.png"
			or "garrafa_tesouro_preview_fortaleza.png"
		local size = def.tamanho
		return minetest.show_formspec(nome, "garrafa_tesouro:preview_"..def.id,
			"formspec_version[4]size[12,10]label[0.4,0.4;"..minetest.formspec_escape(def.nome).." — prévia detalhada]"..
			"image[2.0,1.0;8,6;"..imagem.."]"..
			"label[0.7,7.3;Castelo: muralhas, torres, portão, pátio e torre central.]"..
			"label[0.7,7.8;Tamanho: "..size.x.." × "..size.y.." × "..size.z.." blocos]"..
			"button[3.4,8.8;2.4,0.7;pegar_"..def.id..";Pegar deed]button[6.1,8.8;2.4,0.7;voltar;Voltar]")
	end
	if not (handle_schematics and handle_schematics.analyze_mts_file and build_chest and build_chest.preview_image_create_views) then
		return minetest.chat_send_player(nome, S("O renderizador de prévias não foi carregado; tente novamente após reiniciar o servidor."))
	end
	local chave = "garrafa_tesouro_" .. def.id
	build_chest.building = build_chest.building or {}
	local dados = build_chest.building[chave]
	if not previews_deed[chave] then
		local caminho = schem_path .. def.arquivo:gsub("%.mts$", "")
		local ok, carregado = pcall(handle_schematics.analyze_mts_file, caminho)
		if not ok then
			minetest.log("error", "[garrafa_tesouro] Falha ao ler prévia de " .. def.id .. ": " .. tostring(carregado))
			return minetest.chat_send_player(nome, S("Não foi possível montar a prévia desta estrutura."))
		end
		dados = carregado
		if not dados then return minetest.chat_send_player(nome, S("Não foi possível ler a estrutura deste deed.")) end
		dados.yoff = 0
		local preview_ok, preview = pcall(build_chest.preview_image_create_views, dados)
		if not preview_ok then
			minetest.log("error", "[garrafa_tesouro] Falha ao renderizar prévia de " .. def.id .. ": " .. tostring(preview))
			return minetest.chat_send_player(nome, S("Não foi possível renderizar a prévia desta estrutura."))
		end
		dados.preview = preview
		build_chest.building[chave] = dados
		previews_deed[chave] = true
	end
	if not dados or not dados.size then
		return minetest.chat_send_player(nome, S("Os dados da prévia desta estrutura estão incompletos."))
	end
	local preview_ok, imagem = pcall(build_chest.preview_image_formspec, chave, {}, lado or "front")
	if not preview_ok then
		minetest.log("error", "[garrafa_tesouro] Falha ao exibir prévia de " .. def.id .. ": " .. tostring(imagem))
		return minetest.chat_send_player(nome, S("Não foi possível exibir a prévia desta estrutura."))
	end
	minetest.show_formspec(nome, "garrafa_tesouro:preview_"..def.id,
		"formspec_version[4]size[12,11]label[0.4,0.3;"..minetest.formspec_escape(def.nome).." — prévia da estrutura real]"..
		"label[0.4,0.75;Use os botões Frente, Direita, Trás, Esquerda, Topo e Piso para inspecionar todos os lados.]"..
		"label[0.4,9.45;Tamanho: "..dados.size.x.." × "..dados.size.y.." × "..dados.size.z.." blocos]"..
		imagem.."button[3.3,10.1;2.4,0.7;pegar_"..def.id..";Pegar deed]button[6.2,10.1;2.4,0.7;voltar;Voltar]")
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "garrafa_tesouro:catalogo" and not formname:find("^garrafa_tesouro:preview_") then return end
	local nome = player:get_player_name()
	if not minetest.check_player_privs(nome, {give=true}) then return true end
	if fields.voltar then return mostrar_catalogo(nome, pagina_catalogo[nome] or 1) end
	if fields.anterior then return mostrar_catalogo(nome, (pagina_catalogo[nome] or 1)-1) end
	if fields.proxima then return mostrar_catalogo(nome, (pagina_catalogo[nome] or 1)+1) end
	for id, def in pairs(por_id) do
		if fields["ver_"..id] then return mostrar_previa(nome, def) end
		local preview_id = formname:match("^garrafa_tesouro:preview_(.+)$")
		if preview_id == id and fields.preview then return mostrar_previa(nome, def, fields.preview) end
	end
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
