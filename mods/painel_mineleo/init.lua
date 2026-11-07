-- Painel unico para todos os mods proprios do servidor. Abre por um botao na
-- barra fixa do inventario (unified_inventory) ou por /painel. Cada botao
-- chama o comando de chat correspondente por baixo, entao privilegios e
-- comportamento sao exatamente os mesmos de digitar o comando.

local FORMNAME = "painel_mineleo:main"
local esc = minetest.formspec_escape

local TABS = { "Construção", "Água", "Mundo", "Casas e bichos", "Itens" }

local ALCANCES = { "1", "2", "3", "4", "5", "6", "7", "8", "padrao" }
local ALCANCE_LABELS = { "1", "2", "3", "4", "5", "6", "7", "8", "Padrão (rio 2, mar 8)" }
local TIPOS = { "todas", "rio", "mar" }
local TIPO_LABELS = { "Rio e mar", "Só rio", "Só mar" }
local AREA_LABELS = { "Seleção do WorldEdit", "Raio em volta de mim" }
local L_TIPOS = { "mar", "rio", "todas" }
local L_TIPO_LABELS = { "Só mar", "Só rio", "Rio e mar" }

local ITENS = {
	{ "pescaria:vara", "Vara de pesca" },
	{ "garrafa_tesouro:manipulador", "Manipulador" },
	{ "garrafa_tesouro:garrafa", "Garrafa do tesouro" },
	{ "piso_escorregadio:piso", "Piso escorregadio" },
}

-- Estado por jogador: aba, valores dos campos e ultima mensagem.
local state = {}

local function get_state(name)
	local s = state[name]
	if not s then
		s = {
			tab = 1, status = "",
			qtd = "10", altura = "2", largura = "1",
			alcance = 8, tipo = 1, area = 2, raio = "16",
			l_tipo = 1, l_area = 2, l_raio = "64", ymin = "2", ymax = "256",
			item_qtd = "1",
		}
		state[name] = s
	end
	return s
end

minetest.register_on_leaveplayer(function(player)
	state[player:get_player_name()] = nil
end)

local function run(name, cmd, param)
	local def = minetest.registered_chatcommands[cmd]
	if not def then
		return false, "Recurso indisponível (/" .. cmd .. " não está carregado)."
	end
	local ok, missing = minetest.check_player_privs(name, def.privs or {})
	if not ok then
		return false, "Falta o privilégio: " .. table.concat(missing, ", ")
	end
	local success, msg = def.func(name, param or "")
	if msg == nil or msg == "" then
		msg = success == false and "Não foi possível executar." or "Feito."
	end
	return success ~= false, msg
end

local function button(x, y, w, id, label)
	return ("button[%s,%s;%s,0.8;%s;%s]"):format(x, y, w, id, esc(label))
end

local function field(x, y, w, id, label, value)
	return ("field[%s,%s;%s,0.8;%s;%s;%s]field_close_on_enter[%s;false]")
		:format(x, y, w, id, esc(label), esc(value), id)
end

local function dropdown(x, y, w, id, labels, index)
	local items = {}
	for i, l in ipairs(labels) do items[i] = esc(l) end
	return ("dropdown[%s,%s;%s,0.8;%s;%s;%d;true]"):format(x, y, w, id, table.concat(items, ","), index)
end

local function label(x, y, text)
	return ("label[%s,%s;%s]"):format(x, y, esc(text))
end

local function section(x, y, text)
	return ("style_type[label;font=bold]label[%s,%s;%s]style_type[label;font=normal]"):format(x, y, esc(text))
end

local pages = {}

pages[1] = function(s)
	return table.concat({
		label(0.5, 0.9, "Tudo é feito na direção em que você está olhando, a partir do bloco à sua frente."),
		field(0.5, 1.8, 3.6, "qtd", "Quantidade (1 a 200)", s.qtd),
		field(4.5, 1.8, 3.6, "altura", "Altura do túnel (1 a 5)", s.altura),
		field(8.5, 1.8, 3.6, "largura", "Largura da ladeira (1 a 9)", s.largura),
		button(0.5, 3.0, 3.6, "b_trilho", "Trilhos"),
		button(4.5, 3.0, 3.6, "b_cavar", "Cavar túnel"),
		button(8.5, 3.0, 3.6, "b_ladeira", "Ladeira (bloco da mão)"),
		button(0.5, 4.0, 3.6, "b_replicar", "Replicar bloco da mão"),
		button(4.5, 4.0, 3.6, "b_desfazer", "Desfazer última ação"),
		label(0.5, 5.4, "Trilhos: usa a Quantidade."),
		label(0.5, 5.9, "Cavar túnel: usa Quantidade e Altura."),
		label(0.5, 6.4, "Ladeira: usa Quantidade e Largura, com o bloco que está na sua mão."),
		label(0.5, 6.9, "Replicar: repete o bloco da sua mão em linha reta, substituindo o caminho."),
		label(0.5, 7.4, "Desfazer: volta a última dessas ações (até 20)."),
	})
end

pages[2] = function(s)
	return table.concat({
		section(0.5, 0.8, "Alcance do escoamento da água"),
		label(7.0, 0.8, "(fora das áreas alteradas: rio 2, mar 8)"),
		label(0.5, 1.4, "Alcance"),
		dropdown(0.5, 1.6, 3.2, "alcance", ALCANCE_LABELS, s.alcance),
		label(4.0, 1.4, "Tipo de água"),
		dropdown(4.0, 1.6, 2.6, "tipo", TIPO_LABELS, s.tipo),
		label(6.9, 1.4, "Área"),
		dropdown(6.9, 1.6, 3.6, "area", AREA_LABELS, s.area),
		field(10.8, 1.6, 2.4, "raio", "Raio", s.raio),
		button(0.5, 2.7, 4.2, "b_alcance", "Aplicar alcance"),
		button(5.0, 2.7, 4.2, "b_agua_info", "Ver alcance onde estou"),

		section(0.5, 4.2, "Remover água"),
		label(0.5, 4.8, "Tipo de água"),
		dropdown(0.5, 5.0, 2.6, "l_tipo", L_TIPO_LABELS, s.l_tipo),
		label(3.4, 4.8, "Área"),
		dropdown(3.4, 5.0, 3.6, "l_area", AREA_LABELS, s.l_area),
		field(7.3, 5.0, 1.8, "l_raio", "Raio", s.l_raio),
		field(9.4, 5.0, 1.8, "ymin", "Altura mín.", s.ymin),
		field(11.5, 5.0, 1.8, "ymax", "Altura máx.", s.ymax),
		button(0.5, 6.1, 3.6, "b_limpar_contar", "Só contar"),
		button(4.4, 6.1, 3.6, "b_limpar_remover", "Remover água"),
		button(8.3, 6.1, 3.6, "b_limpar_parar", "Parar"),
		label(0.5, 7.3, "Mar: só acima do nível do mar (desfaz inundações, o mar fica). Rio: remove"),
		label(0.5, 7.8, "rios inteiros na área, inclusive naturais. Faça backup antes de remover."),
	})
end

pages[3] = function()
	return table.concat({
		section(0.5, 0.8, "Dia fixo"),
		button(0.5, 1.2, 3.6, "b_dia_on", "Ligar dia fixo"),
		button(4.5, 1.2, 3.6, "b_dia_off", "Desligar dia fixo"),
		button(8.5, 1.2, 3.6, "b_dia_estado", "Ver estado"),

		section(0.5, 2.7, "Velocidade"),
		button(0.5, 3.1, 3.6, "b_turbo", "Ligar/desligar turbo"),

		section(0.5, 4.6, "Vilas"),
		button(0.5, 5.0, 3.6, "b_povoar", "Povoar vilas vazias"),

		section(0.5, 6.5, "WorldEdit"),
		button(0.5, 6.9, 5.0, "b_purge", "Apagar tudo na seleção (P1/P2)"),
	})
end

pages[4] = function()
	return table.concat({
		section(0.5, 0.8, "Casas e castelos"),
		button(0.5, 1.2, 3.6, "b_casas", "Catálogo de casas"),
		button(4.5, 1.2, 4.6, "b_recolher", "Recolher deed mais próximo"),

		section(0.5, 2.7, "Invocar"),
		button(0.5, 3.1, 3.6, "b_bichos", "Animais"),
		button(4.5, 3.1, 3.6, "b_monstros", "Monstros e dragões"),

		section(0.5, 4.6, "Pesca"),
		button(0.5, 5.0, 3.6, "b_pescar", "Pescar agora"),
		label(4.5, 5.4, "Olhe para a água e tenha a vara no inventário."),
	})
end

pages[5] = function(s)
	local out = {
		field(0.5, 1.2, 2.4, "item_qtd", "Quantidade", s.item_qtd),
		label(3.2, 1.6, "Clique no item para recebê-lo (precisa do privilégio give)."),
	}
	for i, it in ipairs(ITENS) do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local x, y = 0.5 + col * 6.4, 2.6 + row * 1.6
		if minetest.registered_items[it[1]] then
			out[#out + 1] = ("item_image_button[%s,%s;1.2,1.2;%s;item_%d;]"):format(x, y, it[1], i)
			out[#out + 1] = label(x + 1.4, y + 0.6, it[2])
		end
	end
	return table.concat(out)
end

local function show(name)
	local s = get_state(name)
	local fs = {
		"formspec_version[4]",
		"size[14,10]",
		("tabheader[0,0;tab;%s;%d;false;false]"):format(
			table.concat((function()
				local t = {}
				for i, v in ipairs(TABS) do t[i] = esc(v) end
				return t
			end)(), ","), s.tab),
		pages[s.tab](s),
		"box[0.3,8.55;13.4,0.9;#00000055]",
		label(0.5, 9.0, s.status ~= "" and s.status or "Pronto."),
		"button_exit[11.2,8.6;2.4,0.8;fechar;Fechar]",
	}
	minetest.show_formspec(name, FORMNAME, table.concat(fs))
end

local function int_or(value, fallback)
	local n = tonumber(value)
	return n and math.floor(n) or fallback
end

-- Acoes: retornam ok, msg. "abre_outro" = o comando abre sua propria janela.
local actions = {}

actions.b_trilho = function(n, s) return run(n, "trilho", s.qtd) end
actions.b_cavar = function(n, s) return run(n, "cavar", s.qtd .. " " .. s.altura) end
actions.b_ladeira = function(n, s) return run(n, "ladeira", s.qtd .. " " .. s.largura) end
actions.b_replicar = function(n, s) return run(n, "replicar", s.qtd) end
actions.b_desfazer = function(n) return run(n, "desfazer", "") end

actions.b_alcance = function(n, s)
	local area = s.area == 1 and "sel" or tostring(int_or(s.raio, 16))
	return run(n, "agua_alcance", ALCANCES[s.alcance] .. " " .. area .. " " .. TIPOS[s.tipo])
end
actions.b_agua_info = function(n) return run(n, "agua_info", "") end

local function limpar(mode)
	return function(n, s)
		local area = s.l_area == 1 and "sel" or tostring(int_or(s.l_raio, 64))
		return run(n, "agua_limpar", ("%s %s %d %d %s"):format(
			mode, area, int_or(s.ymin, 2), int_or(s.ymax, 256), L_TIPOS[s.l_tipo]))
	end
end
actions.b_limpar_contar = limpar("contar")
actions.b_limpar_remover = limpar("remover")
actions.b_limpar_parar = function(n) return run(n, "agua_limpar", "parar") end

actions.b_dia_on = function(n) return run(n, "dia_fixo", "on") end
actions.b_dia_off = function(n) return run(n, "dia_fixo", "off") end
actions.b_dia_estado = function(n) return run(n, "dia_fixo", "") end
actions.b_turbo = function(n) return run(n, "turbo", "") end
actions.b_povoar = function(n) return run(n, "povoar_vilas", "") end
actions.b_recolher = function(n) return run(n, "recolher_deed", "") end
actions.b_pescar = function(n) return run(n, "pescar", "") end

local function own_window(cmd)
	return function(n)
		local ok, msg = run(n, cmd, "")
		if ok then return ok, msg, true end
		return ok, msg
	end
end
actions.b_casas = own_window("casas")
actions.b_bichos = own_window("bichos")
actions.b_monstros = own_window("monstros")

actions.b_purge = function(n)
	if not (minetest.global_exists("worldedit") and worldedit.show_page and worldedit.pages
		and worldedit.pages["worldedit_purge_region"]) then
		return false, "WorldEdit GUI indisponível."
	end
	if not minetest.check_player_privs(n, { worldedit = true }) then
		return false, "Falta o privilégio: worldedit"
	end
	worldedit.show_page(n, "worldedit_purge_region")
	return true, "", true
end

local function give_item(name, s, index)
	local it = ITENS[index]
	if not (it and minetest.registered_items[it[1]]) then
		return false, "Item indisponível."
	end
	if not minetest.check_player_privs(name, { give = true }) then
		return false, "Falta o privilégio: give"
	end
	local player = minetest.get_player_by_name(name)
	local qtd = math.max(1, math.min(int_or(s.item_qtd, 1), 99))
	local stack = ItemStack(it[1] .. " " .. qtd)
	local sobra = player:get_inventory():add_item("main", stack)
	if not sobra:is_empty() then
		minetest.add_item(player:get_pos(), sobra)
	end
	return true, ("Você recebeu %d x %s."):format(qtd, it[2])
end

local TEXT_FIELDS = { "qtd", "altura", "largura", "raio", "l_raio", "ymin", "ymax", "item_qtd" }
local DROPDOWNS = {
	alcance = #ALCANCE_LABELS, tipo = #TIPO_LABELS, area = #AREA_LABELS, l_area = #AREA_LABELS,
	l_tipo = #L_TIPO_LABELS,
}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return end
	local name = player:get_player_name()
	local s = get_state(name)

	for _, f in ipairs(TEXT_FIELDS) do
		if fields[f] then s[f] = fields[f] end
	end
	for f, max in pairs(DROPDOWNS) do
		local idx = tonumber(fields[f])
		if idx and idx >= 1 and idx <= max then s[f] = idx end
	end

	if fields.quit then return true end

	if fields.tab then
		local t = tonumber(fields.tab)
		if t and pages[t] then
			s.tab = t
			s.status = ""
		end
		show(name)
		return true
	end

	for id, fn in pairs(actions) do
		if fields[id] then
			local ok, msg, other_window = fn(name, s)
			msg = tostring(msg or "")
			if msg ~= "" then minetest.chat_send_player(name, msg) end
			s.status = (ok and "" or "Erro: ") .. msg:gsub("\n", " ")
			if not other_window then show(name) end
			return true
		end
	end

	for f in pairs(fields) do
		local index = f:match("^item_(%d+)$")
		if index then
			local ok, msg = give_item(name, s, tonumber(index))
			s.status = (ok and "" or "Erro: ") .. msg
			show(name)
			return true
		end
	end

	-- Dropdown alterado ou Enter num campo: so redesenha.
	show(name)
	return true
end)

minetest.register_chatcommand("painel", {
	description = "Abre o painel do servidor (o mesmo do botão no inventário)",
	func = function(name)
		show(name)
		return true
	end,
})

if minetest.global_exists("unified_inventory") and unified_inventory.register_button then
	unified_inventory.register_button("painel_mineleo", {
		type = "image",
		image = "default_book_written.png",
		tooltip = "Painel do servidor",
		action = function(player)
			show(player:get_player_name())
		end,
	})
end
