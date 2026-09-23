-- village_populate: mg_villages already computes a full population per
-- village (name, bed position, occupation) for its own bookkeeping, but
-- never spawns anything for it unless a "mob_world_interaction" provider
-- mod is installed (there isn't one that fits our mob stack). This mod
-- reads that same data and spawns an actual working_villages villager on
-- each bed, so generated villages end up with visible residents instead
-- of empty houses.
--
-- Runs automatically: once ~30s after startup (covers villages that were
-- already generated before this mod existed) and then every 5 minutes
-- (covers villages mg_villages generates from then on, as players
-- explore new terrain). Also exposed as /povoar_vilas for an on-demand
-- pass. Idempotent via mod storage: a village already populated is never
-- re-spawned into on a later pass or after a server restart.

local storage = minetest.get_mod_storage()

local function village_key(v)
	return tostring(v.vx) .. ":" .. tostring(v.vz)
end

local function is_populated(key)
	return storage:get_int("done_" .. key) == 1
end

local function mark_populated(key)
	storage:set_int("done_" .. key, 1)
end

local genders = { "working_villages:villager_male", "working_villages:villager_female" }

local function spawn_resident(pos, label)
	local spawn_pos = { x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5 }
	local obj = minetest.add_entity(spawn_pos, genders[math.random(2)], "")
	if not obj then
		return false
	end
	local entity = obj:get_luaentity()
	if not entity then
		obj:remove()
		return false
	end
	entity.owner_name = "working_villages:self_employed"
	if label and label ~= "" then
		obj:set_nametag_attributes({ text = label })
	end
	if entity.update_infotext then
		entity:update_infotext()
	end
	return true
end

-- spawns residents for a single village table (as stored in
-- mg_villages.all_villages), staggered one per game step so a
-- village with many beds doesn't spawn everything in the same tick
local function populate_village(v, on_done)
	local key = village_key(v)
	if is_populated(key) then
		if on_done then on_done(0) end
		return
	end

	local beds = {}
	local bpos_list = v.to_add_data and v.to_add_data.bpos
	if bpos_list then
		for _, bpos in ipairs(bpos_list) do
			if bpos.beds then
				for _, bed in ipairs(bpos.beds) do
					if bed.x and bed.first_name then
						table.insert(beds, bed)
					end
				end
			end
		end
	end

	mark_populated(key)
	if #beds == 0 then
		if on_done then on_done(0) end
		return
	end

	local spawned = 0
	for i, bed in ipairs(beds) do
		minetest.after(i * 0.2, function()
			local label = (bed.title and (bed.title .. " ") or "") .. bed.first_name
			if spawn_resident({ x = bed.x, y = bed.y, z = bed.z }, label) then
				spawned = spawned + 1
			end
			if i == #beds and on_done then
				on_done(spawned)
			end
		end)
	end
end

local function populate_all(requester)
	if not mg_villages.all_villages then
		return
	end

	local villages = {}
	for _, v in pairs(mg_villages.all_villages) do
		table.insert(villages, v)
	end

	local villages_done, residents_done = 0, 0
	local pending = #villages
	if pending == 0 then
		if requester then
			minetest.chat_send_player(requester, "Nenhuma vila conhecida ainda.")
		end
		return
	end

	for _, v in ipairs(villages) do
		populate_village(v, function(spawned)
			if spawned > 0 then
				villages_done = villages_done + 1
				residents_done = residents_done + spawned
			end
			pending = pending - 1
			if pending == 0 then
				minetest.log("action", "[village_populate] populated " .. villages_done ..
					" village(s) with " .. residents_done .. " resident(s)")
				if requester then
					minetest.chat_send_player(requester, "Povoadas " .. villages_done ..
						" vila(s) com " .. residents_done .. " morador(es).")
				end
			end
		end)
	end
end

minetest.register_chatcommand("povoar_vilas", {
	description = "Spawna moradores em toda vila do mg_villages que ainda esteja vazia.",
	privs = { server = true },
	func = function(name)
		populate_all(name)
		return true, "Processando..."
	end,
})

local function periodic_pass()
	populate_all(nil)
	minetest.after(300, periodic_pass)
end

minetest.after(30, periodic_pass)
