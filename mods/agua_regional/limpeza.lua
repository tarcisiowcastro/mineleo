-- Remocao de agua numa area, em pedacos pequenos por passo do servidor para
-- nao travar o jogo. Reconhece todas as aguas descobertas no init.lua
-- (mar, rio, planetas e as variantes de alcance). Tipos:
--
--   mar   - aguas do tipo mar (inclui planetas), SOMENTE acima do nivel do
--           mar. Na Terra o nivel e o water_level do mundo; fora da Terra e
--           preciso informar o nivel do mar do planeta (nivel=Y), para nunca
--           apagar o oceano dele.
--   rio   - agua de rio em qualquer altura da faixa (remove rios naturais).
--   todas - os dois, cada um com sua regra.
--
-- Alturas omitidas ou "auto": na Terra, do nivel do mar + 1 ate 256; fora
-- dela, 64 blocos abaixo e acima de voce.

local SEA_LEVEL = agua_regional.SEA_LEVEL
local TERRA_YMAX = 256
local PLANET_SPAN = 64
local DEFAULT_RADIUS = 64
local MAX_RADIUS = 5000
local CHUNK = 64
local BUDGET_US = 40000 -- tempo maximo por passo do servidor (40 ms)

local FAMILY_LABEL = { mar = "agua do mar", rio = "agua de rio", todas = "agua do mar e de rio" }

local c_air
minetest.register_on_mods_loaded(function()
	c_air = minetest.get_content_id("air")
end)

local job -- um trabalho por vez

local function process_chunk(minp, maxp, j)
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local by_cid = agua_regional.by_cid
	local found = 0
	local want_sea = j.family ~= "rio"
	local want_river = j.family ~= "mar"

	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local sea_ok = want_sea and y > j.sea_level
			if sea_ok or want_river then
				local i = va:index(minp.x, y, z)
				for _ = minp.x, maxp.x do
					local info = by_cid[data[i]]
					if info and ((sea_ok and info.kind == "mar") or (want_river and info.kind == "rio")) then
						found = found + 1
						if j.remove then data[i] = c_air end
					end
					i = i + 1
				end
			end
		end
	end

	if j.remove and found > 0 then
		vm:set_data(data)
		vm:write_to_map(true)
		-- Faz a agua corrente vizinha (fora da area) secar sozinha.
		vm:update_liquids()
	end
	return found
end

local function chunk_bounds(j, ix, iy, iz)
	local minp = vector.new(
		j.minp.x + ix * CHUNK,
		j.minp.y + iy * CHUNK,
		j.minp.z + iz * CHUNK)
	local maxp = vector.new(
		math.min(minp.x + CHUNK - 1, j.maxp.x),
		math.min(minp.y + CHUNK - 1, j.maxp.y),
		math.min(minp.z + CHUNK - 1, j.maxp.z))
	return minp, maxp
end

local function finish(msg)
	local name = job.owner
	minetest.log("action", "[agua_regional] limpeza: " .. msg)
	minetest.chat_send_player(name, msg)
	job = nil
end

minetest.register_globalstep(function()
	if not job then return end
	local start = minetest.get_us_time()
	while minetest.get_us_time() - start < BUDGET_US do
		if job.index >= job.total then
			finish(("%s concluida: %d blocos de %s %s."):format(
				job.remove and "Remocao" or "Contagem", job.found,
				FAMILY_LABEL[job.family], job.remove and "removidos" or "encontrados"))
			return
		end
		local k = job.index
		local ix = k % job.nx
		local iy = math.floor(k / job.nx) % job.ny
		local iz = math.floor(k / (job.nx * job.ny))
		local minp, maxp = chunk_bounds(job, ix, iy, iz)
		job.found = job.found + process_chunk(minp, maxp, job)
		job.index = k + 1

		local pct = math.floor(job.index * 100 / job.total)
		if pct >= job.next_report and job.index < job.total then
			job.next_report = pct + 10
			minetest.chat_send_player(job.owner, ("Agua: %d%% (%d blocos ate agora)"):format(pct, job.found))
		end
	end
end)

local USAGE = "/agua_limpar <contar|remover|parar> [raio|sel] [ymin|auto] [ymax|auto] [mar|rio|todas] [nivel=Y]"

minetest.register_chatcommand("agua_limpar", {
	params = "<contar|remover|parar> [raio|sel] [ymin|auto] [ymax|auto] [mar|rio|todas] [nivel=Y]",
	description = "Conta ou remove agua numa area. mar (padrao): so acima do nivel do mar "
		.. "(fora da Terra, informe nivel=Y do planeta). rio: remove agua de rio, inclusive rios naturais.",
	privs = { server = true },
	func = function(name, param)
		local raw = param:split(" ")
		local mode = raw[1]

		if mode == "parar" then
			if not job then return false, "Nenhuma limpeza em andamento." end
			finish(("Interrompido em %d%%: %d blocos ate agora."):format(
				math.floor(job.index * 100 / job.total), job.found))
			return true
		end
		if mode ~= "contar" and mode ~= "remover" then
			return false, "Uso: " .. USAGE
		end
		if job then
			return false, "Ja existe uma limpeza em andamento (use /agua_limpar parar)."
		end

		-- Tipo e nivel=Y podem vir em qualquer posicao depois do modo.
		local family, nivel = "mar", nil
		local args = { mode }
		for i = 2, #raw do
			local n = raw[i]:match("^nivel=(%-?%d+)$")
			if n then
				nivel = tonumber(n)
			elseif FAMILY_LABEL[raw[i]] then
				family = raw[i]
			else
				args[#args + 1] = raw[i]
			end
		end

		local player = minetest.get_player_by_name(name)
		if not player then return false, "Jogador nao encontrado." end
		local ppos = vector.round(player:get_pos())
		local terra = agua_regional.on_terra(ppos)

		local sea_level = nivel or (terra and SEA_LEVEL or nil)
		if family ~= "rio" and not sea_level then
			return false, "Voce esta fora da Terra: informe o nivel do mar deste planeta "
				.. "(no painel, botao 'Detectar nivel' em cima da agua; no chat, nivel=Y)."
		end

		local ymin = tonumber(args[3])
		local ymax = tonumber(args[4])
		local auto_ymin = terra and (sea_level or SEA_LEVEL) + 1 or ppos.y - PLANET_SPAN
		local auto_ymax = terra and TERRA_YMAX or ppos.y + PLANET_SPAN

		local minp, maxp
		if args[2] == "sel" then
			local we = minetest.global_exists("worldedit") and worldedit
			local p1 = we and we.pos1 and we.pos1[name]
			local p2 = we and we.pos2 and we.pos2[name]
			if not (p1 and p2) then
				return false, "Nenhuma selecao do WorldEdit (//pos1 e //pos2)."
			end
			-- Na selecao, so limita a altura se ela foi informada.
			minp = vector.new(math.min(p1.x, p2.x), math.max(math.min(p1.y, p2.y), ymin or -31000), math.min(p1.z, p2.z))
			maxp = vector.new(math.max(p1.x, p2.x), math.min(math.max(p1.y, p2.y), ymax or 31000), math.max(p1.z, p2.z))
		else
			local radius = tonumber(args[2] or DEFAULT_RADIUS)
			if not radius or radius < 1 or radius > MAX_RADIUS then
				return false, "Raio invalido (1 a " .. MAX_RADIUS .. ")."
			end
			radius = math.floor(radius)
			minp = vector.new(ppos.x - radius, ymin or auto_ymin, ppos.z - radius)
			maxp = vector.new(ppos.x + radius, ymax or auto_ymax, ppos.z + radius)
		end
		if maxp.y < minp.y then
			return false, ("Faixa de altura vazia (%d a %d)."):format(minp.y, maxp.y)
		end
		if family == "mar" and maxp.y <= sea_level then
			return false, ("Agua do mar so e removida acima do nivel do mar (Y %d), e a area vai ate Y %d.")
				:format(sea_level, maxp.y)
		end

		local nx = math.ceil((maxp.x - minp.x + 1) / CHUNK)
		local ny = math.ceil((maxp.y - minp.y + 1) / CHUNK)
		local nz = math.ceil((maxp.z - minp.z + 1) / CHUNK)
		job = {
			owner = name, remove = mode == "remover", family = family,
			sea_level = sea_level or 31000,
			minp = minp, maxp = maxp,
			nx = nx, ny = ny, total = nx * ny * nz,
			index = 0, found = 0, next_report = 10,
		}
		minetest.log("action", ("[agua_regional] %s iniciou /agua_limpar %s %s (nivel %s) em %s-%s"):format(
			name, mode, family, tostring(sea_level), minetest.pos_to_string(minp), minetest.pos_to_string(maxp)))
		local aviso = (family ~= "mar" and mode == "remover")
			and " Atencao: rios naturais da area tambem serao removidos." or ""
		local nivel_txt = sea_level and family ~= "rio" and (", acima do nivel Y " .. sea_level) or ""
		return true, ("%s %s entre %s e %s%s (%d pedacos). Acompanhe o progresso no chat.%s")
			:format(mode == "remover" and "Removendo" or "Contando", FAMILY_LABEL[family],
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp), nivel_txt, job.total, aviso)
	end,
})
