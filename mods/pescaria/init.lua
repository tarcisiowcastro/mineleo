-- Pescaria: vara de pesca simples com peixes comuns, bonitos, raros e lendários.
local S = minetest.get_translator("pescaria")

pescaria = {}

-- Chances em pontos percentuais, somando 100.
-- A garrafa do tesouro também pode aparecer pescando (mensagem na garrafa).
local tabela_pesca = {
	{name = "pescaria:peixinho",       chance = 55},
	{name = "pescaria:peixe_colorido", chance = 25},
	{name = "pescaria:peixe_dourado",  chance = 12},
	{name = "pescaria:peixe_lendario", chance = 5},
	{name = "garrafa_tesouro:garrafa", chance = 3},
}

local function sortear_peixe()
	local roll = math.random(1, 100)
	local acumulado = 0
	for _, item in ipairs(tabela_pesca) do
		acumulado = acumulado + item.chance
		if roll <= acumulado then
			return item.name
		end
	end
	return tabela_pesca[1].name
end

minetest.register_craftitem("pescaria:peixinho", {
	description = S("Peixinho"),
	inventory_image = "default_clay_lump.png^[colorize:#6CA6CD:150",
	groups = {food = 1},
	on_use = minetest.item_eat(1),
})

minetest.register_craftitem("pescaria:peixe_colorido", {
	description = S("Peixe Colorido\nMuito bonito, ótimo para exibir!"),
	inventory_image = "default_clay_lump.png^[colorize:#FF6EC7:170",
	groups = {food = 1},
	on_use = minetest.item_eat(2),
})

minetest.register_craftitem("pescaria:peixe_dourado", {
	description = S("Peixe Dourado\nRaro e valioso!"),
	inventory_image = "default_gold_ingot.png^[colorize:#FFD700:60^[resize:16x16",
	groups = {food = 1},
	on_use = minetest.item_eat(3),
})

minetest.register_craftitem("pescaria:peixe_lendario", {
	description = S("Peixe Cristal Lendário\nUma lenda das águas, lindo e muito valioso!"),
	inventory_image = "default_diamond.png^[colorize:#7DF9FF:90",
	groups = {food = 1},
	on_use = minetest.item_eat(4),
})

local function agua_valida(nodename)
	return nodename == "default:water_source"
		or nodename == "default:river_water_source"
		or nodename == "default:water_flowing"
		or nodename == "default:river_water_flowing"
end

local ALCANCE_PESCA = 20

-- pointed_thing do clique não é confiável aqui: água não é sempre "pointable"
-- nessa versão do engine, então o clique chega com pointed_thing.type =
-- "nothing" mesmo apontando direto pra água. Por isso fazemos o próprio
-- raycast, forçando a detecção de líquidos (4º argumento = true).
local function agua_na_mira(user)
	local olho = user:get_pos()
	olho.y = olho.y + 1.5
	local dir = user:get_look_dir()
	local destino = vector.add(olho, vector.multiply(dir, ALCANCE_PESCA))

	local ray = minetest.raycast(olho, destino, false, true)
	for pointed in ray do
		if pointed.type == "node" then
			local node = minetest.get_node(pointed.under)
			if agua_valida(node.name) then
				return pointed.under
			elseif node.name ~= "air" and node.name ~= "ignore" then
				-- bateu em bloco sólido antes de achar água: sem linha de visão
				return nil
			end
		end
	end
	return nil
end

local function pescar(itemstack, user, pointed_thing)
	if not (user and user:is_player()) then return end

	local meta = itemstack:get_meta()
	local agora = minetest.get_us_time() / 1e6
	local ultimo = tonumber(meta:get_string("ultimo_lance")) or 0
	if agora - ultimo < 1.5 then
		return itemstack
	end
	meta:set_string("ultimo_lance", tostring(agora))

	local nome = user:get_player_name()

	if not agua_na_mira(user) then
		minetest.chat_send_player(nome, S("Aponte bem pra água e tente de novo!"))
		return itemstack
	end

	local pos = user:get_pos()
	local capturado = sortear_peixe()

	local inv = user:get_inventory()
	local sobra = inv:add_item("main", capturado)
	if not sobra:is_empty() then
		minetest.add_item(pos, sobra)
	end

	local def = minetest.registered_items[capturado]
	local descricao = def and def.description:match("^[^\n]*") or capturado
	minetest.chat_send_player(nome, S("Você pescou: @1!", descricao))
	minetest.sound_play("default_place_node_hard",
		{pos = pos, gain = 0.4, max_hear_distance = 8}, true)

	if capturado == "pescaria:peixe_lendario" then
		minetest.chat_send_all(S("@1 pescou algo incrível: um Peixe Cristal Lendário!", nome))
		minetest.add_particlespawner({
			amount = 40,
			time = 1,
			minpos = vector.offset(pos, -0.5, 0, -0.5),
			maxpos = vector.offset(pos, 0.5, 1, 0.5),
			minvel = {x = -1, y = 1, z = -1},
			maxvel = {x = 1, y = 3, z = 1},
			minacc = {x = 0, y = -2, z = 0},
			maxacc = {x = 0, y = -2, z = 0},
			minexptime = 0.5,
			maxexptime = 1.5,
			minsize = 2,
			maxsize = 4,
			texture = "default_diamond.png^[colorize:#7DF9FF:140",
		})
	elseif capturado == "garrafa_tesouro:garrafa" then
		minetest.chat_send_player(nome, S("Tem algo dentro da garrafa... clique nela para descobrir!"))
	end

	return itemstack
end

minetest.register_tool("pescaria:vara", {
	description = S("Vara de Pesca\nAponte para a água e clique com o botão direito"),
	inventory_image = "default_stick.png^[colorize:#8B5A2B:100",
	wield_image = "default_stick.png^[colorize:#8B5A2B:100",
	on_place = pescar,
	on_secondary_use = pescar,
	on_use = pescar,
})

minetest.register_craft({
	output = "pescaria:vara",
	recipe = {
		{"", "default:stick", ""},
		{"default:stick", "", "default:steel_ingot"},
		{"", "default:stick", ""},
	}
})

-- Povoar os mares: peixes e bichos marinhos nadando (visual, via engine Mobs Redo).
if minetest.get_modpath("mobs") then
	local NODES_AGUA = {
		"default:water_source", "default:river_water_source",
	}

	mobs:register_mob("pescaria:cardume", {
		type = "animal",
		passive = true,
		hp_min = 2,
		hp_max = 4,
		armor = 100,
		collisionbox = {-0.15, -0.1, -0.15, 0.15, 0.1, 0.15},
		visual = "sprite",
		visual_size = {x = 0.5, y = 0.5},
		textures = {"default_clay_lump.png^[colorize:#6CA6CD:150"},
		makes_footstep_sound = false,
		fly = true,
		fly_in = NODES_AGUA,
		floats = 0,
		walk_chance = 0,
		jump = false,
		view_range = 10,
		water_damage = 0,
		lava_damage = 5,
		light_damage = 0,
		fear_height = 0,
		drops = {
			{name = "pescaria:peixinho", chance = 1, min = 1, max = 1},
		},
		animation = {
			speed_normal = 15,
			stand_start = 0, stand_end = 0,
		},
	})

	mobs:register_egg("pescaria:cardume", S("Cardume de Peixes"),
		"default_clay_lump.png^[colorize:#6CA6CD:150", 1)

	mobs:spawn({
		name = "pescaria:cardume",
		nodes = NODES_AGUA,
		min_light = 0,
		max_light = 15,
		interval = 30,
		chance = 2000,
		active_object_count = 10,
		min_height = -50,
		max_height = 2,
	})

	mobs:register_mob("pescaria:predador_marinho", {
		type = "animal",
		passive = true,
		hp_min = 15,
		hp_max = 25,
		armor = 100,
		collisionbox = {-0.6, -0.3, -0.6, 0.6, 0.3, 0.6},
		visual = "sprite",
		visual_size = {x = 1.5, y = 1.5},
		textures = {"default_diamond.png^[colorize:#2E8B9A:120"},
		makes_footstep_sound = false,
		fly = true,
		fly_in = NODES_AGUA,
		floats = 0,
		walk_chance = 0,
		jump = false,
		view_range = 14,
		water_damage = 0,
		lava_damage = 10,
		light_damage = 0,
		fear_height = 0,
		drops = {
			{name = "pescaria:peixe_dourado", chance = 2, min = 1, max = 1},
		},
		animation = {
			speed_normal = 15,
			stand_start = 0, stand_end = 0,
		},
	})

	mobs:register_egg("pescaria:predador_marinho", S("Predador Marinho"),
		"default_diamond.png^[colorize:#2E8B9A:120", 1)

	mobs:spawn({
		name = "pescaria:predador_marinho",
		nodes = NODES_AGUA,
		min_light = 0,
		max_light = 15,
		interval = 45,
		chance = 9000,
		active_object_count = 3,
		min_height = -50,
		max_height = 2,
	})
end
