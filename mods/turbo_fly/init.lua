-- Per-player opt-in speed boost. physics_override.speed is a multiplier
-- on top of whatever movement_speed_* + fast-mode already gives, so this
-- stacks with the existing default_privs fast/fly, it doesn't replace it.
local TURBO_SPEED = 2.5
local NORMAL_SPEED = 1

-- pova re-applies the summed physics every second, so a raw
-- set_physics_override would be undone; register the boost with it instead.
local has_pova = minetest.get_modpath("pova") ~= nil

local turbo_on = {}

local function set_speed(player, speed)
	if has_pova then
		local name = player:get_player_name()
		if speed == NORMAL_SPEED then
			pova.del_override(name, "turbo_fly")
		else
			pova.add_override(name, "turbo_fly", { speed = speed - 1 })
		end
		pova.do_override(player)
	else
		player:set_physics_override({ speed = speed })
	end
end

minetest.register_chatcommand("turbo", {
	description = "Liga/desliga velocidade extra de voo (so pra voce, opcional)",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end

		if turbo_on[name] then
			turbo_on[name] = nil
			set_speed(player, NORMAL_SPEED)
			return true, "Turbo desligado"
		end

		turbo_on[name] = true
		set_speed(player, TURBO_SPEED)
		return true, "Turbo ligado (velocidade x" .. TURBO_SPEED .. ")"
	end,
})

-- Reset on join so turbo never silently persists across sessions.
minetest.register_on_joinplayer(function(player)
	turbo_on[player:get_player_name()] = nil
end)
