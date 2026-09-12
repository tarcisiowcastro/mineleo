local animal_defs = {
	{ "animalia:cow", "Vaca" },
	{ "animalia:sheep", "Ovelha" },
	{ "animalia:pig", "Porco" },
	{ "animalia:chicken", "Galinha" },
	{ "animalia:horse", "Cavalo" },
	{ "animalia:wolf", "Lobo" },
	{ "animalia:cat", "Gato" },
	{ "animalia:fox", "Raposa" },
	{ "animalia:bear", "Urso" },
	{ "animalia:reindeer", "Rena" },
	{ "animalia:turkey", "Peru" },
	{ "animalia:owl", "Coruja" },
	{ "animalia:song_bird", "Passaro" },
	{ "animalia:bat", "Morcego" },
	{ "animalia:frog", "Sapo" },
	{ "animalia:rat", "Rato" },
	{ "animalia:opossum", "Gamba" },
	{ "animalia:tropical_fish", "Peixe Tropical" },
}

local monster_defs = {
	{ "mobs_monster:dirt_monster", "Dirt Monster" },
	{ "mobs_monster:sand_monster", "Sand Monster" },
	{ "mobs_monster:stone_monster", "Stone Monster" },
	{ "mobs_monster:tree_monster", "Tree Monster" },
	{ "mobs_monster:oerkki", "Oerkki" },
	{ "mobs_monster:spider", "Spider" },
	{ "mobs_monster:mese_monster", "Mese Monster" },
	{ "mobs_monster:dungeon_master", "Dungeon Master" },
	{ "mobs_monster:land_guard", "Land Guard" },
	{ "mobs_monster:lava_flan", "Lava Flan" },
	{ "mobs_monster:obsidian_flan", "Obsidian Flan" },
	{ "mobs_monster:fire_spirit", "Fire Spirit" },
	{ "dmobs:orc", "Orc" },
	{ "dmobs:ogre", "Ogre" },
	{ "dmobs:skeleton", "Skeleton" },
	{ "dmobs:treeman", "Treeman" },
	{ "dmobs:gnorm", "Gnorm" },
	{ "dmobs:pig_evil", "Javali Malvado" },
	{ "dmobs:wasp", "Vespa" },
	{ "dmobs:wasp_leader", "Vespa Lider" },
	{ "dmobs:golem", "Golem" },
	{ "dmobs:dragon", "Dragao" },
	{ "dmobs:dragon_red", "Dragao Vermelho" },
	{ "dmobs:dragon_green", "Dragao Verde" },
	{ "dmobs:dragon_blue", "Dragao Azul" },
	{ "dmobs:dragon_black", "Dragao Preto" },
	{ "dmobs:dragon_great", "Dragao Grande" },
	{ "dmobs:waterdragon", "Dragao Aquatico" },
	{ "dmobs:wyvern", "Wyvern" },
}

local COLS = 3
local BTN_W, BTN_H, PAD = 2.6, 0.8, 0.2

local function build_formspec(label, defs)
	local rows = math.ceil(#defs / COLS)
	local width = COLS * (BTN_W + PAD) + PAD
	local grid_top = 0.8
	local grid_bottom = grid_top + rows * (BTN_H + PAD)
	local height = grid_bottom + BTN_H + PAD

	local fs = {
		"formspec_version[4]",
		string.format("size[%f,%f]", width, height),
		string.format("label[%f,0.4;%s]", PAD, label),
	}

	for i, def in ipairs(defs) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local x = PAD + col * (BTN_W + PAD)
		local y = grid_top + row * (BTN_H + PAD)
		fs[#fs + 1] = string.format(
			"button[%f,%f;%f,%f;spawn_%d;%s]",
			x, y, BTN_W, BTN_H, i, def[2]
		)
	end

	fs[#fs + 1] = string.format(
		"button_exit[%f,%f;%f,%f;quit;Fechar]",
		PAD, grid_bottom, BTN_W, BTN_H
	)

	return table.concat(fs)
end

local LEASH_RADIUS = 10
local LEASH_CHECK_INTERVAL = 0.5
local LEASH_PULL_FACTOR = 0.2 -- fraction of the remaining distance per correction
local leash_timer = 0

-- Mobs Redo has no built-in "stay near spawn" option, so this keeps
-- dungeon monsters from wandering off. A hard teleport straight back to
-- origin looked like a jarring snap, so instead this glides them a
-- fraction of the way back every tick while they're past LEASH_RADIUS,
-- which reads as being pulled back rather than popping in place.
minetest.register_globalstep(function(dtime)
	leash_timer = leash_timer + dtime
	if leash_timer < LEASH_CHECK_INTERVAL then
		return
	end
	leash_timer = 0

	for _, luaentity in pairs(minetest.luaentities) do
		local origin = luaentity._leash_origin
		local obj = luaentity.object
		if origin and obj then
			local pos = obj:get_pos()
			if pos and vector.distance(pos, origin) > LEASH_RADIUS then
				local pulled = vector.new(
					pos.x + (origin.x - pos.x) * LEASH_PULL_FACTOR,
					pos.y + (origin.y - pos.y) * LEASH_PULL_FACTOR,
					pos.z + (origin.z - pos.z) * LEASH_PULL_FACTOR
				)
				obj:set_pos(pulled)
			end
		end
	end
end)

local function spawn_in_front(player, entity_name, leashed)
	local pos = player:get_pos()
	local dir = minetest.yaw_to_dir(player:get_look_horizontal())
	pos = vector.add(pos, vector.multiply(dir, 2))
	pos.y = pos.y + 0.5

	local obj = minetest.add_entity(pos, entity_name)
	if leashed and obj then
		local luaentity = obj:get_luaentity()
		if luaentity then
			luaentity._leash_origin = vector.copy(pos)
		end
	end
end

local function register_spawn_panel(command, description, label, defs, leashed)
	local formname = "mob_spawn_panel:" .. command
	local formspec = build_formspec(label, defs)

	minetest.register_chatcommand(command, {
		description = description,
		privs = { give = true },
		func = function(caller_name)
			minetest.show_formspec(caller_name, formname, formspec)
		end,
	})

	minetest.register_on_player_receive_fields(function(player, formname_recv, fields)
		if formname_recv ~= formname then
			return
		end

		local player_name = player:get_player_name()
		if not minetest.check_player_privs(player_name, { give = true }) then
			return
		end

		for field in pairs(fields) do
			local index = field:match("^spawn_(%d+)$")
			if index then
				local def = defs[tonumber(index)]
				if def then
					spawn_in_front(player, def[1], leashed)
					minetest.chat_send_player(player_name, "Invocado: " .. def[2])
				end
				break
			end
		end
	end)
end

register_spawn_panel("bichos", "Abre o painel pra invocar animais da Animalia", "Invocar bicho (Animalia)", animal_defs, false)
register_spawn_panel("monstros", "Abre o painel pra invocar monstros e dragoes (dungeon)", "Invocar monstro/dragao", monster_defs, true)
