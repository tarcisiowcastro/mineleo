local MAX_LEN = 200
local RAIL = "advtrains:dtrack_st"

-- /trilho <quantidade>: linha reta de trilhos a partir do bloco a frente de quem digitou
core.register_chatcommand("trilho", {
	params = "<quantidade>",
	description = "Assenta uma linha reta de trilhos na direcao em que voce olha",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end
		local count = tonumber(param)
		if not count or count < 1 then
			return false, "Uso: /trilho <quantidade> (1 a " .. MAX_LEN .. ")"
		end
		count = math.min(math.floor(count), MAX_LEN)

		-- direcao cardinal pelo olhar horizontal
		local look = core.yaw_to_dir(player:get_look_horizontal())
		local dir
		if math.abs(look.x) > math.abs(look.z) then
			dir = { x = look.x > 0 and 1 or -1, y = 0, z = 0 }
		else
			dir = { x = 0, y = 0, z = look.z > 0 and 1 or -1 }
		end
		-- param2 0/2 = eixo Z (norte-sul), 1/3 = eixo X (leste-oeste)
		local param2 = (dir.x ~= 0) and 1 or 0

		local pos = vector.add(vector.round(player:get_pos()), dir)
		local placed, skipped = 0, 0
		for _ = 1, count do
			local def = core.registered_nodes[core.get_node(pos).name]
			if def and def.buildable_to then
				core.set_node(pos, { name = RAIL, param2 = param2 })
				placed = placed + 1
			else
				skipped = skipped + 1
			end
			pos = vector.add(pos, dir)
		end
		return true, ("Trilhos colocados: %d (pulados por bloco ocupado: %d)"):format(placed, skipped)
	end,
})
