-- Limpeza das inundacoes criadas pela versao antiga do river_flow.
--
-- O solver antigo enchia cavidades com default:water_source ate a altura da
-- agua mais alta por perto (inclusive rios e cachoeiras). No mapa gerado, agua
-- do MAR nunca existe acima do nivel do mar (rios usam river_water), entao toda
-- default:water_source / default:water_flowing acima de water_level e
-- artificial. Este comando remove exatamente isso, numa faixa de Y, em pedacos
-- pequenos por passo do servidor para nao travar o jogo.
--
-- Nao toca em: agua de rio, mar no nivel do mar ou abaixo, variantes do
-- agua_regional, e nada fora da faixa de Y (planetas em outras altitudes).

local SEA_LEVEL = tonumber(minetest.settings:get("water_level")) or 1
local DEFAULT_YMIN = SEA_LEVEL + 1
local DEFAULT_YMAX = 256
local DEFAULT_RADIUS = 64
local MAX_RADIUS = 5000
local CHUNK = 64
local BUDGET_US = 40000 -- tempo maximo por passo do servidor (40 ms)

local c_air, c_source, c_flowing
minetest.register_on_mods_loaded(function()
	c_air = minetest.get_content_id("air")
	c_source = minetest.get_content_id("default:water_source")
	c_flowing = minetest.get_content_id("default:water_flowing")
end)

local job -- um trabalho por vez

local function process_chunk(minp, maxp, remove)
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local found = 0

	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = va:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				local c = data[i]
				if c == c_source or c == c_flowing then
					found = found + 1
					if remove then data[i] = c_air end
				end
				i = i + 1
			end
		end
	end

	if remove and found > 0 then
		vm:set_data(data)
		vm:write_to_map(true)
		-- Faz a agua corrente vizinha (fora da faixa) secar sozinha.
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
			finish(("%s concluida: %d blocos de agua do mar acima do nivel do mar %s."):format(
				job.remove and "Limpeza" or "Contagem", job.found,
				job.remove and "removidos" or "encontrados"))
			return
		end
		local k = job.index
		local ix = k % job.nx
		local iy = math.floor(k / job.nx) % job.ny
		local iz = math.floor(k / (job.nx * job.ny))
		local minp, maxp = chunk_bounds(job, ix, iy, iz)
		job.found = job.found + process_chunk(minp, maxp, job.remove)
		job.index = k + 1

		local pct = math.floor(job.index * 100 / job.total)
		if pct >= job.next_report and job.index < job.total then
			job.next_report = pct + 10
			minetest.chat_send_player(job.owner, ("Agua: %d%% (%d blocos ate agora)"):format(pct, job.found))
		end
	end
end)

local USAGE = "/agua_limpar <contar|remover|parar> [raio|sel] [ymin] [ymax]"

minetest.register_chatcommand("agua_limpar", {
	params = "<contar|remover|parar> [raio|sel] [ymin] [ymax]",
	description = "Conta ou remove agua do MAR acima do nivel do mar (inundacoes do river_flow antigo). "
		.. "Padrao: raio " .. DEFAULT_RADIUS .. ", Y " .. DEFAULT_YMIN .. " a " .. DEFAULT_YMAX .. ". "
		.. "Nao mexe em rios nem no mar.",
	privs = { server = true },
	func = function(name, param)
		local args = param:split(" ")
		local mode = args[1]

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

		local player = minetest.get_player_by_name(name)
		if not player then return false, "Jogador nao encontrado." end

		local ymin = tonumber(args[3]) or DEFAULT_YMIN
		local ymax = tonumber(args[4]) or DEFAULT_YMAX
		if ymin <= SEA_LEVEL then
			return false, ("ymin precisa ser acima do nivel do mar (%d), senao apagaria o mar."):format(SEA_LEVEL)
		end
		if ymax < ymin then return false, "ymax menor que ymin." end

		local minp, maxp
		if args[2] == "sel" then
			local we = minetest.global_exists("worldedit") and worldedit
			local p1 = we and we.pos1 and we.pos1[name]
			local p2 = we and we.pos2 and we.pos2[name]
			if not (p1 and p2) then
				return false, "Nenhuma selecao do WorldEdit (//pos1 e //pos2)."
			end
			minp = vector.new(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))
			maxp = vector.new(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))
		else
			local radius = tonumber(args[2] or DEFAULT_RADIUS)
			if not radius or radius < 1 or radius > MAX_RADIUS then
				return false, "Raio invalido (1 a " .. MAX_RADIUS .. ")."
			end
			radius = math.floor(radius)
			local c = vector.round(player:get_pos())
			minp = vector.new(c.x - radius, 0, c.z - radius)
			maxp = vector.new(c.x + radius, 0, c.z + radius)
		end
		-- A faixa de Y sempre limita, inclusive dentro da selecao.
		if args[2] == "sel" then
			minp.y = math.max(minp.y, ymin)
			maxp.y = math.min(maxp.y, ymax)
		else
			minp.y, maxp.y = ymin, ymax
		end
		if maxp.y < minp.y then
			return false, "A selecao esta fora da faixa de Y " .. ymin .. " a " .. ymax .. "."
		end

		local nx = math.ceil((maxp.x - minp.x + 1) / CHUNK)
		local ny = math.ceil((maxp.y - minp.y + 1) / CHUNK)
		local nz = math.ceil((maxp.z - minp.z + 1) / CHUNK)
		job = {
			owner = name, remove = mode == "remover",
			minp = minp, maxp = maxp,
			nx = nx, ny = ny, total = nx * ny * nz,
			index = 0, found = 0, next_report = 10,
		}
		minetest.log("action", ("[agua_regional] %s iniciou /agua_limpar %s em %s-%s"):format(
			name, mode, minetest.pos_to_string(minp), minetest.pos_to_string(maxp)))
		return true, ("%s agua do mar entre %s e %s (%d pedacos). Acompanhe o progresso no chat.")
			:format(mode == "remover" and "Removendo" or "Contando",
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp), job.total)
	end,
})
