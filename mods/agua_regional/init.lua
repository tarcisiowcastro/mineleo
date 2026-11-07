-- O alcance de escoamento (liquid_range) no Luanti pertence ao TIPO de bloco,
-- nao a posicao. Para ter alcances diferentes em lugares diferentes, este mod
-- registra variantes visuais identicas de cada agua do jogo (mar, rio e as
-- aguas de outros mods, como as dos planetas) com alcances de 1 a 8, e um
-- comando que troca a agua de uma area pela variante desejada.
--
-- Padrao do jogo: agua de rio = 2, agua do mar = 8.

local MIN_RANGE, MAX_RANGE = 1, 8
local MAX_VOLUME = 4000000
local DEFAULT_RADIUS = 16
local SEA_LEVEL = tonumber(minetest.settings:get("water_level")) or 1
-- Acima disto o jogador esta fora da Terra (camadas do other_worlds, planetas).
local TERRA_TOP = SEA_LEVEL + 1000

agua_regional = {
	SEA_LEVEL = SEA_LEVEL,
	families = {},   -- id -> { source, flowing, label, kind = "mar"|"rio", base_range }
	by_cid = {},     -- content id -> { family = id, kind = "mar"|"rio", source = bool }
}
local FAMILIES = agua_regional.families

function agua_regional.on_terra(pos)
	return pos.y < TERRA_TOP
end

-- Descobre as aguas registradas por qualquer mod. Roda no carregamento deste
-- mod; os mods que registram agua estao em optional_depends para carregar antes.
local function is_water_source(name, def)
	if def.liquidtype ~= "source" then return false end
	if name:find("^agua_regional:") then return false end
	if minetest.get_item_group(name, "lava") > 0 or name:find("lava") then return false end
	local flowing = def.liquid_alternative_flowing
	if not (flowing and minetest.registered_nodes[flowing]) then return false end
	return minetest.get_item_group(name, "water") > 0 or name:find("water") or name:find("agua")
end

local found = {}
for name, def in pairs(minetest.registered_nodes) do
	if is_water_source(name, def) then found[#found + 1] = name end
end
table.sort(found)

for _, name in ipairs(found) do
	local def = minetest.registered_nodes[name]
	local id
	if name == "default:water_source" then
		id = "mar"
	elseif name == "default:river_water_source" then
		id = "rio"
	else
		id = name:gsub("_source$", ""):gsub("[^%w]", "_")
	end
	if not FAMILIES[id] then
		FAMILIES[id] = {
			source = name,
			flowing = def.liquid_alternative_flowing,
			label = (def.description or name):match("^[^\n]*"),
			kind = name:find("river") and "rio" or "mar",
			base_range = def.liquid_range or 8,
		}
	end
end

local function variant_names(id, range)
	local fam = FAMILIES[id]
	if range == "padrao" or range == fam.base_range then
		return fam.source, fam.flowing
	end
	return "agua_regional:" .. id .. "_" .. range .. "_source",
		"agua_regional:" .. id .. "_" .. range .. "_flowing"
end

local function copy_node(base, name, range, src_name, flow_name, label)
	local def = table.copy(minetest.registered_nodes[base])
	def.name = nil
	def.mod_origin = nil
	def.type = nil
	def.liquid_range = range
	def.liquid_alternative_source = src_name
	def.liquid_alternative_flowing = flow_name
	def.description = label .. " (alcance " .. range .. ")"
	def.groups = table.copy(def.groups or {})
	def.groups.not_in_creative_inventory = 1
	minetest.register_node(":" .. name, def)
end

for id, fam in pairs(FAMILIES) do
	for range = MIN_RANGE, MAX_RANGE do
		local src, flow = variant_names(id, range)
		if src ~= fam.source then
			copy_node(fam.source, src, range, src, flow, fam.label)
			copy_node(fam.flowing, flow, range, src, flow, fam.label .. " corrente")
			-- Balde: recolher a variante devolve o balde normal.
			if minetest.global_exists("bucket") and bucket.liquids
				and bucket.liquids[fam.source] then
				local entry = table.copy(bucket.liquids[fam.source])
				entry.source = src
				entry.flowing = flow
				bucket.liquids[src] = entry
				bucket.liquids[flow] = entry
			end
		end
	end
end

minetest.register_on_mods_loaded(function()
	local names = {}
	for id, fam in pairs(FAMILIES) do
		names[#names + 1] = fam.source
		for range = MIN_RANGE, MAX_RANGE do
			local src, flow = variant_names(id, range)
			agua_regional.by_cid[minetest.get_content_id(src)] = { family = id, kind = fam.kind, source = true }
			agua_regional.by_cid[minetest.get_content_id(flow)] = { family = id, kind = fam.kind, source = false }
		end
	end
	table.sort(names)
	minetest.log("action", "[agua_regional] aguas reconhecidas: " .. table.concat(names, ", "))
end)

function agua_regional.water_info(nodename)
	local cid = minetest.registered_nodes[nodename] and minetest.get_content_id(nodename)
	return cid and agua_regional.by_cid[cid]
end

-- Superficie (Y da agua mais alta) da agua em que o jogador esta ou logo
-- abaixo dele, ate 32 blocos para baixo. nil se nao achar agua.
function agua_regional.water_surface(pos)
	local p = vector.round(pos)
	local function is_water(q) return agua_regional.water_info(minetest.get_node(q).name) ~= nil end
	if not is_water(p) then
		local found_y
		for dy = 1, 32 do
			local q = vector.offset(p, 0, -dy, 0)
			if is_water(q) then found_y = q.y break end
			if minetest.get_node(q).name ~= "air" then return nil end
		end
		if not found_y then return nil end
		return found_y
	end
	while is_water(vector.offset(p, 0, 1, 0)) do p.y = p.y + 1 end
	return p.y
end

local function sort_area(a, b)
	return vector.new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
		vector.new(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

local function get_area(name, area_arg)
	local player = minetest.get_player_by_name(name)
	if not player then return nil, "Jogador nao encontrado." end

	local we = minetest.global_exists("worldedit") and worldedit
	local p1 = we and we.pos1 and we.pos1[name]
	local p2 = we and we.pos2 and we.pos2[name]

	if area_arg == "sel" or (area_arg == nil and p1 and p2) then
		if not (p1 and p2) then
			return nil, "Nenhuma selecao do WorldEdit. Use //pos1 e //pos2 ou informe um raio."
		end
		local a, b = sort_area(p1, p2)
		return a, b
	end

	local radius = tonumber(area_arg or DEFAULT_RADIUS)
	if not radius or radius < 1 then
		return nil, "Raio invalido."
	end
	radius = math.floor(radius)
	local center = vector.round(player:get_pos())
	return vector.subtract(center, radius), vector.add(center, radius)
end

local function apply(minp, maxp, kind_filter, range)
	local volume = (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) * (maxp.z - minp.z + 1)
	if volume > MAX_VOLUME then
		return nil, "Area grande demais (" .. volume .. " blocos, maximo " .. MAX_VOLUME .. ")."
	end

	local targets = {}
	for id in pairs(FAMILIES) do
		local src, flow = variant_names(id, range)
		targets[id] = {
			source = minetest.get_content_id(src),
			flowing = minetest.get_content_id(flow),
		}
	end

	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local changed = 0
	local by_cid = agua_regional.by_cid

	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = va:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				local info = by_cid[data[i]]
				if info and (kind_filter == "todas" or kind_filter == info.kind) then
					local t = targets[info.family]
					local new = info.source and t.source or t.flowing
					if data[i] ~= new then
						data[i] = new
						changed = changed + 1
					end
				end
				i = i + 1
			end
		end
	end

	if changed > 0 then
		vm:set_data(data)
		vm:update_liquids()
		vm:write_to_map(true)
	end
	return changed
end

local KINDS = { todas = true, rio = true, mar = true }
local USAGE = "/agua_alcance <1-8|padrao> [raio|sel] [rio|mar|todas]"

minetest.register_chatcommand("agua_alcance", {
	params = "<1-8|padrao> [raio|sel] [rio|mar|todas]",
	description = "Define o alcance de escoamento da agua numa area. "
		.. "Sem area: usa a selecao do WorldEdit, ou raio " .. DEFAULT_RADIUS .. ". "
		.. "mar inclui as aguas dos planetas. Padrao do jogo: rio=2, mar=8.",
	privs = { server = true },
	func = function(name, param)
		local args = param:split(" ")
		local range_arg, area_arg, kind = args[1], args[2], args[3] or "todas"

		-- Permite "/agua_alcance 8 rio" sem informar a area.
		if area_arg and KINDS[area_arg] then
			kind, area_arg = area_arg, nil
		end

		local range
		if range_arg == "padrao" then
			range = "padrao"
		else
			range = tonumber(range_arg)
			if not range or range < MIN_RANGE or range > MAX_RANGE or range % 1 ~= 0 then
				return false, "Uso: " .. USAGE
			end
		end
		if not KINDS[kind] then
			return false, "Tipo de agua invalido. Use rio, mar ou todas."
		end

		local minp, maxp = get_area(name, area_arg)
		if not minp then return false, maxp end

		local changed, err = apply(minp, maxp, kind, range)
		if not changed then return false, err end

		minetest.log("action", ("[agua_regional] %s definiu alcance %s (%s) em %s-%s: %d blocos")
			:format(name, tostring(range), kind,
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp), changed))
		if changed == 0 then
			return true, ("Nenhuma agua (%s) encontrada entre %s e %s. Aumente o raio ou confira a selecao.")
				:format(kind, minetest.pos_to_string(minp), minetest.pos_to_string(maxp))
		end
		return true, ("Alcance %s aplicado a %d blocos de agua (%s) entre %s e %s.")
			:format(tostring(range), changed, kind,
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp))
	end,
})

-- Agua para onde o jogador olha (ate 20 blocos) ou onde ele esta.
local function water_near(player)
	local eye = vector.offset(player:get_pos(), 0, 1.5, 0)
	local target = vector.add(eye, vector.multiply(player:get_look_dir(), 20))
	for pointed in minetest.raycast(eye, target, false, true) do
		if pointed.type == "node" then
			local node = minetest.get_node(pointed.under)
			if agua_regional.water_info(node.name) then return pointed.under, node.name end
			if node.name ~= "air" and node.name ~= "ignore" then break end
		end
	end
	local pos = vector.round(player:get_pos())
	for dy = 0, -3, -1 do
		local p = vector.offset(pos, 0, dy, 0)
		local node = minetest.get_node(p)
		if agua_regional.water_info(node.name) then return p, node.name end
	end
end

minetest.register_chatcommand("agua_info", {
	description = "Mostra o tipo e o alcance da agua para onde voce olha (ou onde esta).",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Jogador nao encontrado." end
		local pos, nodename = water_near(player)
		if not pos then
			return false, "Nenhuma agua reconhecida. Olhe para a agua (ate 20 blocos) ou entre nela."
		end
		local info = agua_regional.water_info(nodename)
		local fam = FAMILIES[info.family]
		local def = minetest.registered_nodes[nodename]
		local surface = agua_regional.water_surface(pos)
		return true, ("%s (%s, tipo %s): alcance %d. Superficie em Y %s."):format(
			fam.label, nodename, info.kind, def.liquid_range or 8, tostring(surface or "?"))
	end,
})

dofile(minetest.get_modpath("agua_regional") .. "/limpeza.lua")
