local function execute(command, name, params)
	local chatcmd = minetest.registered_chatcommands["/" .. command]
	if not chatcmd then return end
	local _, message = chatcmd.func(name, params)
	if message then minetest.chat_send_player(name, message) end
end

-- Some installations load WorldEdit's GUI as a nested modpack member. Delay
-- registration until all mods have initialized so the GUI extension API exists.
minetest.register_on_mods_loaded(function()
	if not worldedit.register_gui_function or not worldedit.register_gui_handler then
		minetest.log("error", "[worldedit_purge] worldedit_gui is not available")
		return
	end

worldedit.register_gui_function("worldedit_purge_region", {
	name = "Apagar Tudo (P1/P2)",
	privs = {worldedit = true},
	get_formspec = function(name)
		local pos1, pos2 = worldedit.pos1[name], worldedit.pos2[name]
		local selected = pos1 and pos2
		return "size[8,4]" .. worldedit.get_formspec_header("worldedit_purge_region") ..
			"label[0.5,1;Remove todos os blocos, itens, mobs e entidades entre P1 e P2.]" ..
			"label[0.5,1.55;Jogadores não são removidos.]" ..
			(selected and "label[0.5,2.1;Seleção pronta.]" or "label[0.5,2.1;Defina P1 e P2 antes de continuar.]") ..
			"button_exit[2,3;4,0.8;worldedit_purge_region_confirm;APAGAR TUDO NA SELEÇÃO]"
	end,
})

worldedit.register_gui_handler("worldedit_purge_region", function(name, fields)
	if not fields.worldedit_purge_region_confirm then return false end
	local pos1, pos2 = worldedit.pos1[name], worldedit.pos2[name]
	if not (pos1 and pos2) then
		minetest.chat_send_player(name, "Defina os pontos 1 e 2 antes de apagar.")
		worldedit.show_page(name, "worldedit_purge_region")
		return true
	end

	-- Reuse WorldEdit's region-aware //set air implementation so metadata,
	-- inventories and undo behave like the built-in action.
	execute("set", name, "air")
	local removed = 0
	for _, object in ipairs(minetest.get_objects_in_area(pos1, pos2)) do
		if not object:is_player() then object:remove(); removed = removed + 1 end
	end
	minetest.chat_send_player(name, "Seleção apagada; " .. removed .. " entidade(s) removida(s).")
	return true
end)
end)
