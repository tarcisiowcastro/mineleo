-- Luanti's built-in liquid solver only propagates a liquid up to eight nodes
-- from a source. When a player opens a tunnel from the sea into a cavity
-- below sea level, the native solver leaves it half dry. The small solver
-- below detects that new connection and fills the connected cavity with sea
-- water, but never above sea level and never from river water (rivers sit
-- above sea level and would otherwise flood whole valleys).

local SEA_NODES = {
	["default:water_source"] = true,
	["default:water_flowing"] = true,
}

local SEA_LEVEL = tonumber(minetest.settings:get("water_level")) or 1
local MAX_CAVITY_NODES = 4096
local SCAN_RADIUS = 16
local pending = {}
local timer = 0

local function key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local directions = {
	{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0},
	{x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0},
	{x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
}

local function fill_cavity(start)
	if start.y > SEA_LEVEL then return end

	local queue = { start }
	local head = 1
	local seen = { [key(start)] = true }
	local air_cells = {}
	local has_sea_source = false
	local visited = 0

	while queue[head] do
		local pos = queue[head]
		head = head + 1
		local node = minetest.get_node_or_nil(pos)
		if node and node.name == "default:water_source" then
			has_sea_source = true
		elseif node and node.name == "air" then
			visited = visited + 1
			-- Too big to be a tunnel/cave: it's open terrain. Do nothing.
			if visited > MAX_CAVITY_NODES then return end
			air_cells[#air_cells + 1] = pos
			for _, direction in ipairs(directions) do
				local next_pos = vector.add(pos, direction)
				local next_key = key(next_pos)
				if not seen[next_key]
					and next_pos.y <= SEA_LEVEL
					and math.abs(next_pos.x - start.x) <= SCAN_RADIUS
					and math.abs(next_pos.y - start.y) <= SCAN_RADIUS
					and math.abs(next_pos.z - start.z) <= SCAN_RADIUS then
					seen[next_key] = true
					queue[#queue + 1] = next_pos
				end
			end
		end
	end

	if not has_sea_source then return end
	for _, pos in ipairs(air_cells) do
		minetest.set_node(pos, { name = "default:water_source" })
	end
end

local function schedule_fill(pos)
	if pos.y > SEA_LEVEL then return end
	for _, direction in ipairs(directions) do
		local node = minetest.get_node_or_nil(vector.add(pos, direction))
		if node and SEA_NODES[node.name] then
			pending[key(pos)] = vector.new(pos)
			return
		end
	end
end

minetest.register_on_dignode(function(pos)
	schedule_fill(pos)
end)

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.25 then return end
	timer = 0
	for id, pos in pairs(pending) do
		pending[id] = nil
		fill_cavity(pos)
	end
end)
