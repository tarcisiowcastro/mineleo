-- Per-player opt-in speed boost. physics_override.speed is a multiplier
-- on top of whatever movement_speed_* + fast-mode already gives, so this
-- stacks with the existing default_privs fast/fly, it doesn't replace it.
local TURBO_SPEED = 2.5
local NORMAL_SPEED = 1

local turbo_on = {}

minetest.register_chatcommand("turbo", {
	description = "Liga/desliga velocidade extra de voo (so pra voce, opcional)",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Jogador nao encontrado"
		end

		if turbo_on[name] then
			turbo_on[name] = nil
			player:set_physics_override({ speed = NORMAL_SPEED })
			return true, "Turbo desligado"
		end

		turbo_on[name] = true
		player:set_physics_override({ speed = TURBO_SPEED })
		return true, "Turbo ligado (velocidade x" .. TURBO_SPEED .. ")"
	end,
})

-- Reset on join so turbo never silently persists across sessions.
minetest.register_on_joinplayer(function(player)
	turbo_on[player:get_player_name()] = nil
end)
