-- Correcoes do size_editer:
-- * meta:get_float() devolve 0 (nao nil) para quem nunca usou o mod, entao o
--   original deixava TODO jogador minusculo ao entrar. 0 aqui = "sem tamanho".
-- * o original sobrescrevia velocidade/pulo/gravidade, quebrando /turbo e a
--   gravidade dos planetas; aqui so muda o tamanho do corpo.
-- E adiciona /tamanho <jogador> <0.05-20|normal> para mudar outro jogador.
local DEF = {cb = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}, eye = 1.47, step = 0.6}

local function props(size)
	return {
		visual_size = {x = size, y = size},
		collisionbox = {DEF.cb[1] * size, 0, DEF.cb[3] * size, DEF.cb[4] * size, DEF.cb[5] * size, DEF.cb[6] * size},
		eye_height = DEF.eye * size,
		stepheight = DEF.step * size,
	}
end

function size_editer.set_player_size(name, size)
	local player = minetest.get_player_by_name(name)
	size = tonumber(size)
	if not player or not size or size <= 0 then return end
	size = math.max(0.05, math.min(size, 20))
	player:get_meta():set_float("player_size", size)
	player:set_properties(props(size))
	size_editer.size_change_effect(player)
end

minetest.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_float("player_size") <= 0 then meta:set_float("player_size", 1) end
end)

-- player_api/edit_skin resetam o corpo ao trocar modelo/animacao; reaplica.
local t = 0
minetest.register_globalstep(function(dtime)
	t = t + dtime
	if t < 2 then return end
	t = 0
	for _, player in ipairs(minetest.get_connected_players()) do
		local size = player:get_meta():get_float("player_size")
		if size > 0 and size ~= 1 and not player:get_attach() then
			local p = player:get_properties()
			if math.abs((p.eye_height or 0) - DEF.eye * size) > 0.01
				or math.abs((p.visual_size and p.visual_size.x or 1) - size) > 0.001 then
				player:set_properties(props(size))
			end
		end
	end
end)

minetest.register_chatcommand("tamanho", {
	params = "<jogador> <0.05 a 20 | normal>",
	description = "Muda o tamanho de um jogador (priv size_edit)",
	privs = {[size_editer.priv] = true},
	func = function(name, param)
		local alvo, valor = param:match("^(%S+)%s+(%S+)$")
		if not alvo then return false, "Uso: /tamanho <jogador> <0.05 a 20 | normal>" end
		if not minetest.get_player_by_name(alvo) then return false, "Jogador " .. alvo .. " não está online." end
		local size = valor == "normal" and 1 or tonumber(valor)
		if not size or size < 0.05 or size > 20 then return false, "Tamanho deve ser de 0.05 a 20 (ou normal)." end
		size_editer.set_player_size(alvo, size)
		if alvo ~= name then minetest.chat_send_player(alvo, name .. " mudou seu tamanho para " .. size .. ".") end
		return true, "Tamanho de " .. alvo .. " agora é " .. size .. "."
	end,
})
