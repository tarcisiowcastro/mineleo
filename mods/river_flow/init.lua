-- Luanti's built-in liquid solver only propagates a liquid up to eight nodes
-- from a source. That is fine for rivers, but it leaves two reservoirs at
-- different heights when a player opens a tunnel between them. The small
-- solver below detects that new connection and fills the connected, loaded
-- cavity from the sea up to the current surface level.

local WATER_NODES = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
	["default:river_water_source"] = true,
	["default:river_water_flowing"] = true,
}

local MAX_CAVITY_NODES = 65536
local SCAN_RADIUS = 32
local pending = {}
local timer = 0

-- Keep the native solver useful for ordinary streams too.
minetest.override_item("default:river_water_source", { liquid_range = 8 })
minetest.override_item("default:river_water_flowing", { liquid_range = 8 })
minetest.override_item("default:water_source", { liquid_range = 8 })
minetest.override_item("default:water_flowing", { liquid_range = 8 })

local function key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local function is_open_or_water(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node or node.name == "ignore" then return false end
	if WATER_NODES[node.name] then return true end
	local def = minetest.registered_nodes[node.name]
	return def and def.buildable_to and not def.walkable
end

local directions = {
	{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0},
	{x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0},
	{x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
}

local function balance_cavity(start)
	local queue = { start }
	local head = 1
	local seen = { [key(start)] = true }
	local cells = {}
	local water = 0
	local water_surface_y
	local reaches_scan_edge = false
	local has_sea_source = false

	while queue[head] and #cells < MAX_CAVITY_NODES do
		local pos = queue[head]
		head = head + 1
		if is_open_or_water(pos) then
			local node = minetest.get_node(pos)
			cells[#cells + 1] = { pos = pos, water = WATER_NODES[node.name] }
			if WATER_NODES[node.name] then
				water = water + 1
				water_surface_y = water_surface_y and math.max(water_surface_y, pos.y) or pos.y
				has_sea_source = has_sea_source or node.name == "default:water_source"
			end
			if math.abs(pos.x - start.x) == SCAN_RADIUS
				or math.abs(pos.y - start.y) == SCAN_RADIUS
				or math.abs(pos.z - start.z) == SCAN_RADIUS then
				reaches_scan_edge = true
			end
			for _, direction in ipairs(directions) do
				local next_pos = vector.add(pos, direction)
				local next_key = key(next_pos)
				if not seen[next_key]
					and math.abs(next_pos.x - start.x) <= SCAN_RADIUS
					and math.abs(next_pos.y - start.y) <= SCAN_RADIUS
					and math.abs(next_pos.z - start.z) <= SCAN_RADIUS then
					seen[next_key] = true
					queue[#queue + 1] = next_pos
				end
			end
		end
	end

	-- Default sea-water sources are inexhaustible in the base game. Treating
	-- one as a reservoir is what makes a tunnel actually fill instead of merely
	-- redistributing a fixed number of nodes from the sea side.
	if #cells == 0 or water == 0
		or (#cells >= MAX_CAVITY_NODES and not reaches_scan_edge and not has_sea_source) then return end
	if has_sea_source or reaches_scan_edge then
		for _, cell in ipairs(cells) do
			local should_hold_water = cell.pos.y <= water_surface_y
			if should_hold_water and not cell.water then
				minetest.set_node(cell.pos, { name = "default:water_source" })
			elseif not should_hold_water and cell.water then
				minetest.set_node(cell.pos, { name = "air" })
			end
		end
		return
	end

	table.sort(cells, function(a, b)
		if a.pos.y ~= b.pos.y then return a.pos.y < b.pos.y end
		if a.pos.z ~= b.pos.z then return a.pos.z < b.pos.z end
		return a.pos.x < b.pos.x
	end)

	for index, cell in ipairs(cells) do
		local should_hold_water = index <= water
		if should_hold_water and not cell.water then
			minetest.set_node(cell.pos, { name = "default:water_source" })
		elseif not should_hold_water and cell.water then
			minetest.set_node(cell.pos, { name = "air" })
		end
	end
end

local function schedule_balance(pos)
	-- Only queue a newly opened space beside water. This makes ordinary mining
	-- free and starts the calculation exactly when a tunnel can release water.
	for _, direction in ipairs(directions) do
		local neighbour = vector.add(pos, direction)
		local node = minetest.get_node_or_nil(neighbour)
		if node and WATER_NODES[node.name] then
			pending[key(pos)] = vector.new(pos)
			return
		end
	end
end

minetest.register_on_dignode(function(pos)
	schedule_balance(pos)
end)

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.25 then return end
	timer = 0
	for id, pos in pairs(pending) do
		pending[id] = nil
		balance_cavity(pos)
	end
end)
