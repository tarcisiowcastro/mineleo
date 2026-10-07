local MAX_LEN = 200
local MAX_HEIGHT = 5
local MAX_UNDO = 20
local RAIL = "advtrains:dtrack_st"

-- Historico por jogador pro /desfazer: cada entrada e uma lista de
-- { pos, node, meta } com o estado ANTES da alteracao
local history = {}

local function push_history(name, changes)
	if #changes == 0 then
		return
	end
	local h = history[name] or {}
	h[#h + 1] = changes
	if #h > MAX_UNDO then
		table.remove(h, 1)
	end
	history[name] = h
end

local function snapshot(pos)
	return {
		pos = vector.new(pos),
		node = core.get_node(pos),
		meta = core.get_meta(pos):to_table(),
	}
end

-- Direcao cardinal pelo olhar horizontal
local function look_dir(player)
	local look = core.yaw_to_dir(player:get_look_horizontal())
	if math.abs(look.x) > math.abs(look.z) then
		return { x = look.x > 0 and 1 or -1, y = 0, z = 0 }
	end
	return { x = 0, y = 0, z = look.z > 0 and 1 or -1 }
end

local function parse_count(param)
	local count = param and tonumber(param)
	if not count or count < 1 then
		return nil
	end
	return math.min(math.floor(count), MAX_LEN)
end

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
		local count = parse_count(param)
		if not count then
			return false, "Uso: /trilho <quantidade> (1 a " .. MAX_LEN .. ")"
		end

		local dir = look_dir(player)
		-- param2 0/2 = eixo Z (norte-sul), 1/3 = eixo X (leste-oeste)
		local param2 = (dir.x ~= 0) and 1 or 0

		local pos = vector.add(vector.round(player:get_pos()), dir)
		local changes = {}
		local skipped = 0
		for _ = 1, count do
			local def = core.registered_nodes[core.get_node(pos).name]
			if def and def.buildable_to then
				changes[#changes + 1] = snapshot(pos)
				core.set_node(pos, { name = RAIL, param2 = param2 })
			else
				skipped = skipped + 1
			end
			pos = vector.add(pos, dir)
		end
		push_history(name, changes)
		return true, ("Trilhos colocados: %d (pulados por bloco ocupado: %d)"):format(#changes, skipped)
	end,
})

-- /cavar <quantidade> [altura]: tunel reto na direcao do olhar (altura padrao 2)
core.register_chatcommand("cavar", {
	params = "<quantidade> [altura]",
	description = "Quebra uma linha reta de blocos na direcao em que voce olha (tunel)",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end
		local count_s, height_s = param:match("^(%S+)%s*(%S*)$")
		local count = parse_count(count_s)
		if not count then
			return false, "Uso: /cavar <quantidade> [altura] (1 a " .. MAX_LEN .. ", altura 1 a " .. MAX_HEIGHT .. ")"
		end
		local height = math.max(1, math.min(tonumber(height_s or "") or 2, MAX_HEIGHT))

		local dir = look_dir(player)
		local base = vector.add(vector.round(player:get_pos()), dir)
		local changes = {}
		for _ = 1, count do
			for dy = 0, height - 1 do
				local pos = { x = base.x, y = base.y + dy, z = base.z }
				local nname = core.get_node(pos).name
				if nname ~= "air" and nname ~= "ignore" then
					changes[#changes + 1] = snapshot(pos)
					core.remove_node(pos)
				end
			end
			base = vector.add(base, dir)
		end
		push_history(name, changes)
		return true, ("Blocos quebrados: %d"):format(#changes)
	end,
})

-- /desfazer: volta a ultima acao de /trilho ou /cavar (ate MAX_UNDO por jogador)
core.register_chatcommand("desfazer", {
	description = "Desfaz o ultimo /trilho ou /cavar",
	privs = { server = true },
	func = function(name)
		local h = history[name]
		if not h or #h == 0 then
			return false, "Nada para desfazer"
		end
		local changes = table.remove(h)
		-- ordem inversa: restaura do ultimo alterado pro primeiro
		for i = #changes, 1, -1 do
			local c = changes[i]
			core.set_node(c.pos, c.node)
			core.get_meta(c.pos):from_table(c.meta)
		end
		return true, ("Desfeito: %d blocos restaurados (restam %d acoes)"):format(#changes, #h)
	end,
})
