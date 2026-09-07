local animal_defs = {
	{ "cow", "Vaca" },
	{ "sheep", "Ovelha" },
	{ "pig", "Porco" },
	{ "chicken", "Galinha" },
	{ "horse", "Cavalo" },
	{ "wolf", "Lobo" },
	{ "cat", "Gato" },
	{ "fox", "Raposa" },
	{ "bear", "Urso" },
	{ "reindeer", "Rena" },
	{ "turkey", "Peru" },
	{ "owl", "Coruja" },
	{ "song_bird", "Passaro" },
	{ "bat", "Morcego" },
	{ "frog", "Sapo" },
	{ "rat", "Rato" },
	{ "opossum", "Gamba" },
	{ "tropical_fish", "Peixe Tropical" },
}

local FORMNAME = "mob_spawn_panel:main"
local COLS = 3
local BTN_W, BTN_H, PAD = 2.6, 0.8, 0.2
local ROWS = math.ceil(#animal_defs / COLS)

local WIDTH = COLS * (BTN_W + PAD) + PAD
local GRID_TOP = 0.8
local GRID_BOTTOM = GRID_TOP + ROWS * (BTN_H + PAD)
local HEIGHT = GRID_BOTTOM + BTN_H + PAD

local function build_formspec()
	local fs = {
		"formspec_version[4]",
		string.format("size[%f,%f]", WIDTH, HEIGHT),
		string.format("label[%f,0.4;Invocar bicho (Animalia)]", PAD),
	}

	for i, animal in ipairs(animal_defs) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local x = PAD + col * (BTN_W + PAD)
		local y = GRID_TOP + row * (BTN_H + PAD)
		fs[#fs + 1] = string.format(
			"button[%f,%f;%f,%f;spawn_%s;%s]",
			x, y, BTN_W, BTN_H, animal[1], animal[2]
		)
	end

	fs[#fs + 1] = string.format(
		"button_exit[%f,%f;%f,%f;quit;Fechar]",
		PAD, GRID_BOTTOM, BTN_W, BTN_H
	)

	return table.concat(fs)
end

local formspec = build_formspec()

minetest.register_chatcommand("bichos", {
	description = "Abre o painel pra invocar animais da Animalia",
	privs = { give = true },
	func = function(caller_name)
		minetest.show_formspec(caller_name, FORMNAME, formspec)
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end

	local player_name = player:get_player_name()
	if not minetest.check_player_privs(player_name, { give = true }) then
		return
	end

	for field in pairs(fields) do
		local animal = field:match("^spawn_(.+)$")
		if animal then
			local pos = player:get_pos()
			local dir = minetest.yaw_to_dir(player:get_look_horizontal())
			pos = vector.add(pos, vector.multiply(dir, 2))
			pos.y = pos.y + 0.5
			minetest.add_entity(pos, "animalia:" .. animal)
			minetest.chat_send_player(player_name, "Invocado: " .. animal)
			break
		end
	end
end)
