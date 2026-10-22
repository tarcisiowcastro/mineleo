-- multidecor.shelves.drawer_on_step faz vector.subtract(self.end_v, self.start_v)
-- sem checar nil. Uma gaveta salva no mundo sem esses campos derruba o
-- servidor inteiro ("attempt to index local 'a' (a nil value)") toda vez
-- que alguem chega perto dela. Aqui a gaveta quebrada so fica parada.
local original = multidecor.shelves.drawer_on_step

local function safe_drawer_on_step(self, dtime)
	if self.dir ~= 0 and (not self.start_v or not self.end_v or not self.object:get_pos()) then
		self.dir = 0
		self.object:set_velocity(vector.zero())
		return
	end
	return original(self, dtime)
end

core.register_on_mods_loaded(function()
	for _, def in pairs(core.registered_entities) do
		if def.on_step == original then
			def.on_step = safe_drawer_on_step
		end
	end
end)
