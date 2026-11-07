-- Remocao de agua numa area, em pedacos pequenos por passo do servidor para
-- nao travar o jogo. Tipos:
--
--   mar   - default:water_source/flowing e as variantes "mar" do agua_regional,
--           SOMENTE acima do nivel do mar. No mapa gerado agua do mar nunca
--           existe acima do nivel do mar (rios usam river_water), entao isso
--           desfaz as inundacoes da versao antiga do river_flow sem tocar no mar.
--   rio   - default:river_water_source/flowing e as variantes "rio", em
--           qualquer altura da faixa. Atencao: remove rios naturais da area.
--   todas - os dois, cada um com sua regra.
--
-- Nada fora da faixa de Y e tocado (planetas em outras altitudes).

local SEA_LEVEL = tonumber(minetest.settings:get("water_level")) or 1
local DEFAULT_YMIN = SEA_LEVEL + 1
local DEFAULT_YMAX = 256
local DEFAULT_RADIUS = 64
local MAX_RADIUS = 5000
local CHUNK = 64
local BUDGET_US = 40000 -- tempo maximo por passo do servidor (40 ms)

local FAMILY_LABEL = { mar = "agua do mar", rio = "agua de rio", todas = "agua do mar e de rio" }

local c_air
local sea_ids, river_ids = {}, {}
minetest.register_on_mods_loaded(function()
	c_air = minetest.get_content_id("air")
	for name in pairs(minetest.registered_nodes) do
		if name == "default:water_source" or name == "default:water_flowing"
			or name:match("^agua_regional:mar_%d+_") then
			sea_ids[minetest.get_content_id(name)] = true
		elseif name == "default:river_water_source" or name == "default:river_water_flowing"
			or name:match("^agua_regional:rio_%d+_") then
			river_ids[minetest.get_content_id(name)] = true
		end
	end
end)

local job -- um trabalho por vez

local function process_chunk(minp, maxp, remove, family)
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local found = 0
	local want_sea = family ~= "rio"
	local want_river = family ~= "mar"

	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local sea_ok = want_sea and y > SEA_LEVEL
			if sea_ok or want_river then
				local i = va:index(minp.x, y, z)
				for _ = minp.x, maxp.x do
					local c = data[i]
					if (sea_ok and sea_ids[c]) or (want_river and river_ids[c]) then
						found = found + 1
						if remove then data[i] = c_air end
					end
					i = i + 1
				end
			end
		end
	end

	if remove and found > 0 then
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
		job.found = job.found + process_chunk(minp, maxp, job.remove, job.family)
		job.index = k + 1

		local pct = math.floor(job.index * 100 / job.total)
		if pct >= job.next_report and job.index < job.total then
			job.next_report = pct + 10
			minetest.chat_send_player(job.owner, ("Agua: %d%% (%d blocos ate agora)"):format(pct, job.found))
		end
	end
end)

local USAGE = "/agua_limpar <contar|remover|parar> [raio|sel] [ymin] [ymax] [mar|rio|todas]"

minetest.register_chatcommand("agua_limpar", {
	params = "<contar|remover|parar> [raio|sel] [ymin] [ymax] [mar|rio|todas]",
	description = "Conta ou remove agua numa area. mar (padrao): so acima do nivel do mar, "
		.. "desfaz as inundacoes do river_flow antigo. rio: remove agua de rio, inclusive rios naturais. "
		.. "Padrao: raio " .. DEFAULT_RADIUS .. ", Y " .. DEFAULT_YMIN .. " a " .. DEFAULT_YMAX .. ".",
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

		-- O tipo de agua pode vir em qualquer posicao depois do modo.
		local family = "mar"
		local args = { mode }
		for i = 2, #raw do
			if FAMILY_LABEL[raw[i]] then
				family = raw[i]
			else
				args[#args + 1] = raw[i]
			end
		end

		local player = minetest.get_player_by_name(name)
		if not player then return false, "Jogador nao encontrado." end

		local ymin = tonumber(args[3]) or DEFAULT_YMIN
		local ymax = tonumber(args[4]) or DEFAULT_YMAX
		if ymax < ymin then return false, "Altura maxima menor que a minima." end
		if family == "mar" and ymax <= SEA_LEVEL then
			return false, ("Agua do mar so e removida acima do nivel do mar (%d)."):format(SEA_LEVEL)
		end

		local minp, maxp
		if args[2] == "sel" then
			local we = minetest.global_exists("worldedit") and worldedit
			local p1 = we and we.pos1 and we.pos1[name]
			local p2 = we and we.pos2 and we.pos2[name]
			if not (p1 and p2) then
				return false, "Nenhuma selecao do WorldEdit (//pos1 e //pos2)."
			end
			minp = vector.new(math.min(p1.x, p2.x), math.max(math.min(p1.y, p2.y), ymin), math.min(p1.z, p2.z))
			maxp = vector.new(math.max(p1.x, p2.x), math.min(math.max(p1.y, p2.y), ymax), math.max(p1.z, p2.z))
		else
			local radius = tonumber(args[2] or DEFAULT_RADIUS)
			if not radius or radius < 1 or radius > MAX_RADIUS then
				return false, "Raio invalido (1 a " .. MAX_RADIUS .. ")."
			end
			radius = math.floor(radius)
			local c = vector.round(player:get_pos())
			minp = vector.new(c.x - radius, ymin, c.z - radius)
			maxp = vector.new(c.x + radius, ymax, c.z + radius)
		end
		if maxp.y < minp.y then
			return false, "A selecao esta fora da faixa de altura " .. ymin .. " a " .. ymax .. "."
		end

		local nx = math.ceil((maxp.x - minp.x + 1) / CHUNK)
		local ny = math.ceil((maxp.y - minp.y + 1) / CHUNK)
		local nz = math.ceil((maxp.z - minp.z + 1) / CHUNK)
		job = {
			owner = name, remove = mode == "remover", family = family,
			minp = minp, maxp = maxp,
			nx = nx, ny = ny, total = nx * ny * nz,
			index = 0, found = 0, next_report = 10,
		}
		minetest.log("action", ("[agua_regional] %s iniciou /agua_limpar %s %s em %s-%s"):format(
			name, mode, family, minetest.pos_to_string(minp), minetest.pos_to_string(maxp)))
		local aviso = (family ~= "mar" and mode == "remover")
			and " Atencao: rios naturais da area tambem serao removidos." or ""
		return true, ("%s %s entre %s e %s (%d pedacos). Acompanhe o progresso no chat.%s")
			:format(mode == "remover" and "Removendo" or "Contando", FAMILY_LABEL[family],
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp), job.total, aviso)
	end,
})
