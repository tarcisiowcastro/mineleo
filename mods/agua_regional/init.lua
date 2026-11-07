-- O alcance de escoamento (liquid_range) no Luanti pertence ao TIPO de bloco,
-- nao a posicao. Para ter alcances diferentes em lugares diferentes, este mod
-- registra variantes visuais identicas da agua do mar e do rio com alcances
-- de 1 a 8, e um comando que troca a agua de uma area pela variante desejada.
--
-- Padrao do jogo: agua de rio = 2, agua do mar = 8.

dofile(minetest.get_modpath("agua_regional") .. "/limpeza.lua")

local MIN_RANGE, MAX_RANGE = 1, 8
local MAX_VOLUME = 4000000
local DEFAULT_RADIUS = 16

local FAMILIES = {
	rio = {
		source = "default:river_water_source",
		flowing = "default:river_water_flowing",
		label = "Agua de rio",
	},
	mar = {
		source = "default:water_source",
		flowing = "default:water_flowing",
		label = "Agua",
	},
}

local function variant_names(family, range)
	local fam = FAMILIES[family]
	local base_range = minetest.registered_nodes[fam.source].liquid_range or 8
	if range == base_range then
		return fam.source, fam.flowing
	end
	return "agua_regional:" .. family .. "_" .. range .. "_source",
		"agua_regional:" .. family .. "_" .. range .. "_flowing"
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

for family, fam in pairs(FAMILIES) do
	for range = MIN_RANGE, MAX_RANGE do
		local src, flow = variant_names(family, range)
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

-- content id -> { family = "rio"/"mar", source = bool }
local lookup = {}
minetest.register_on_mods_loaded(function()
	for family in pairs(FAMILIES) do
		for range = MIN_RANGE, MAX_RANGE do
			local src, flow = variant_names(family, range)
			lookup[minetest.get_content_id(src)] = { family = family, source = true }
			lookup[minetest.get_content_id(flow)] = { family = family, source = false }
		end
	end
end)

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

local function apply(minp, maxp, family_filter, range)
	local volume = (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) * (maxp.z - minp.z + 1)
	if volume > MAX_VOLUME then
		return nil, "Area grande demais (" .. volume .. " blocos, maximo " .. MAX_VOLUME .. ")."
	end

	local targets = {}
	for family in pairs(FAMILIES) do
		local src, flow = variant_names(family, range == "padrao"
			and (minetest.registered_nodes[FAMILIES[family].source].liquid_range or 8)
			or range)
		targets[family] = {
			source = minetest.get_content_id(src),
			flowing = minetest.get_content_id(flow),
		}
	end

	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local changed = 0

	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = va:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				local info = lookup[data[i]]
				if info and (family_filter == "todas" or family_filter == info.family) then
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

local USAGE = "/agua_alcance <1-8|padrao> [raio|sel] [rio|mar|todas]"

minetest.register_chatcommand("agua_alcance", {
	params = "<1-8|padrao> [raio|sel] [rio|mar|todas]",
	description = "Define o alcance de escoamento da agua numa area. "
		.. "Sem area: usa a selecao do WorldEdit, ou raio " .. DEFAULT_RADIUS .. ". "
		.. "Padrao do jogo: rio=2, mar=8.",
	privs = { server = true },
	func = function(name, param)
		local args = param:split(" ")
		local range_arg, area_arg, family = args[1], args[2], args[3] or "todas"

		-- Permite "/agua_alcance 8 rio" sem informar a area.
		if area_arg and (FAMILIES[area_arg] or area_arg == "todas") then
			family, area_arg = area_arg, nil
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
		if family ~= "todas" and not FAMILIES[family] then
			return false, "Tipo de agua invalido. Use rio, mar ou todas."
		end

		local minp, maxp = get_area(name, area_arg)
		if not minp then return false, maxp end

		local changed, err = apply(minp, maxp, family, range)
		if not changed then return false, err end

		minetest.log("action", ("[agua_regional] %s definiu alcance %s (%s) em %s-%s: %d blocos")
			:format(name, tostring(range), family,
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp), changed))
		return true, ("Alcance %s aplicado a %d blocos de agua (%s) entre %s e %s.")
			:format(tostring(range), changed, family,
				minetest.pos_to_string(minp), minetest.pos_to_string(maxp))
	end,
})

minetest.register_chatcommand("agua_info", {
	description = "Mostra o alcance da agua onde voce esta (ou logo abaixo).",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Jogador nao encontrado." end
		local pos = vector.round(player:get_pos())
		for dy = 0, -3, -1 do
			local node = minetest.get_node(vector.offset(pos, 0, dy, 0))
			local def = minetest.registered_nodes[node.name]
			if def and def.liquidtype and def.liquidtype ~= "none" then
				return true, ("%s: alcance %d"):format(node.name, def.liquid_range or 8)
			end
		end
		return false, "Nenhuma agua aqui. Entre na agua ou fique logo acima dela."
	end,
})
