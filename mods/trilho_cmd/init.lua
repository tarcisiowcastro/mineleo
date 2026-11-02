local MAX_LEN = 200
local MAX_HEIGHT = 5
local MAX_UNDO = 20
local MAX_WIDTH = 9
local MAX_FILL = 32
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

-- Itens que nao sao bloco mas colocam um bloco (ex.: trilho do advtrains)
local PLACER_TO_NODE = {
	["advtrains:dtrack_placer"] = RAIL,
}

-- /replicar <quantidade>: repete o bloco da mao numa reta pra frente,
-- substituindo o que estiver no caminho (o item da mao nao e consumido)
core.register_chatcommand("replicar", {
	params = "<quantidade>",
	description = "Coloca o bloco da sua mao numa linha reta na direcao em que voce olha, substituindo o que estiver no caminho",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end
		local count = parse_count(param)
		if not count then
			return false, "Uso: /replicar <quantidade> (1 a " .. MAX_LEN .. ")"
		end

		local item = player:get_wielded_item():get_name()
		if item == "" then
			return false, "Segure na mao o bloco que quer replicar"
		end
		local node_name = PLACER_TO_NODE[item] or item
		local def = core.registered_nodes[node_name]
		if not def then
			return false, ("'%s' nao e um bloco que da pra colocar"):format(item)
		end

		local dir = look_dir(player)
		local param2 = 0
		if node_name == RAIL then
			-- param2 0/2 = eixo Z (norte-sul), 1/3 = eixo X (leste-oeste)
			param2 = (dir.x ~= 0) and 1 or 0
		elseif def.paramtype2 == "facedir" or def.paramtype2 == "4dir" then
			-- vira a face do bloco pra quem esta colocando, como no clique normal
			param2 = core.dir_to_facedir(vector.multiply(dir, -1))
		end

		local pos = vector.add(vector.round(player:get_pos()), dir)
		local changes = {}
		for _ = 1, count do
			if core.get_node(pos).name ~= "ignore" then
				changes[#changes + 1] = snapshot(pos)
				core.set_node(pos, { name = node_name, param2 = param2 })
			end
			pos = vector.add(pos, dir)
		end
		push_history(name, changes)
		return true, ("Colocados %d x %s"):format(#changes, node_name)
	end,
})

-- Bloco inclinado do More Blocks equivalente ao da mao; nil se nao houver
local function slope_of(node_name)
	local mod, sub = node_name:match("^([^:]+):(.+)$")
	if not mod then
		return nil
	end
	for _, candidate in ipairs({ "moreblocks:slope_" .. sub, mod .. ":slope_" .. sub }) do
		if core.registered_nodes[candidate] then
			return candidate
		end
	end
	return nil
end

-- So ocupa espaco livre, pra nunca sobrescrever construcao existente
local function is_free(pos)
	local nname = core.get_node(pos).name
	local def = core.registered_nodes[nname]
	return nname ~= "ignore" and def and def.buildable_to
end

-- /ladeira <quantidade> [largura]: rampa subindo na direcao do olhar, com o
-- bloco da mao. Preenche por baixo ate o chao e pula o que ja estiver ocupado
core.register_chatcommand("ladeira", {
	params = "<quantidade> [largura]",
	description = "Constroi uma ladeira com o bloco da sua mao, subindo na direcao em que voce olha",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end
		local count_s, width_s = param:match("^(%S+)%s*(%S*)$")
		local count = parse_count(count_s)
		if not count then
			return false, "Uso: /ladeira <quantidade> [largura] (1 a " .. MAX_LEN .. ", largura 1 a " .. MAX_WIDTH .. ")"
		end
		local width = math.max(1, math.min(math.floor(tonumber(width_s or "") or 1), MAX_WIDTH))

		local item = player:get_wielded_item():get_name()
		if not core.registered_nodes[item] then
			return false, "Segure na mao o bloco da ladeira"
		end
		local slope = slope_of(item)

		local dir = look_dir(player)
		local side = { x = dir.z, y = 0, z = -dir.x }
		local param2 = core.dir_to_facedir(dir)
		local base = vector.add(vector.round(player:get_pos()), dir)
		local first = -math.floor((width - 1) / 2)
		local changes = {}
		local skipped = 0
		for step = 0, count - 1 do
			for offset = first, first + width - 1 do
				local pos = vector.add(base, vector.multiply(side, offset))
				if is_free(pos) then
					changes[#changes + 1] = snapshot(pos)
					core.set_node(pos, { name = slope or item, param2 = slope and param2 or 0 })
					local below = { x = pos.x, y = pos.y - 1, z = pos.z }
					for _ = 1, MAX_FILL do
						if not is_free(below) then
							break
						end
						changes[#changes + 1] = snapshot(below)
						core.set_node(below, { name = item })
						below.y = below.y - 1
					end
				else
					skipped = skipped + 1
				end
			end
			base = vector.add(base, { x = dir.x, y = 1, z = dir.z })
		end
		push_history(name, changes)
		return true, ("Ladeira pronta: %d blocos (pulados por bloco ocupado: %d)%s"):format(
			#changes, skipped, slope and "" or " - sem rampa pra esse bloco, ficou em degraus")
	end,
})

-- /desfazer: volta a ultima acao de /trilho, /cavar, /replicar ou /ladeira (ate MAX_UNDO por jogador)
core.register_chatcommand("desfazer", {
	description = "Desfaz o ultimo /trilho, /cavar, /replicar ou /ladeira",
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
