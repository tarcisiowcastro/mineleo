local storage = core.get_mod_storage()

-- Ligado por padrao; o estado escolhido pelo admin persiste entre reinicios
local enabled = storage:get_string("enabled") ~= "false"

local NOON = 0.5
local timer = 0

core.register_globalstep(function(dtime)
	if not enabled then
		return
	end
	timer = timer + dtime
	if timer < 5 then
		return
	end
	timer = 0
	core.set_timeofday(NOON)
end)

core.register_on_joinplayer(function()
	if enabled then
		core.set_timeofday(NOON)
	end
end)

core.register_chatcommand("dia_fixo", {
	params = "<on|off>",
	description = "Liga ou desliga o dia fixo (sem param, mostra o estado)",
	privs = { server = true },
	func = function(_, param)
		if param == "on" then
			enabled = true
			storage:set_string("enabled", "true")
			core.set_timeofday(NOON)
			return true, "Dia fixo ligado"
		elseif param == "off" then
			enabled = false
			storage:set_string("enabled", "false")
			return true, "Dia fixo desligado (o tempo volta a correr)"
		end
		return true, "Dia fixo esta " .. (enabled and "ligado" or "desligado") .. ". Use /dia_fixo on|off"
	end,
})
