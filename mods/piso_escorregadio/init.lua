-- Piso que escorrega ao extremo: usa o group "slippery" do engine no valor
-- maximo pratico. Esse group faz o jogador perder o controle de frenagem/giro
-- com uma chance de 1/(slippery+1) por passo -- valores altos tornam o
-- deslizamento quase constante.
local SLIPPERY_MAX = 200

local sound_defaults = default and default.node_sound_glass_defaults and default.node_sound_glass_defaults() or nil

core.register_node("piso_escorregadio:piso", {
	description = "Piso Escorregadio (extremo)",
	tiles = { "default_ice.png" },
	use_texture_alpha = "blend",
	paramtype = "light",
	is_ground_content = false,
	walkable = true,
	groups = { slippery = SLIPPERY_MAX, cracky = 3 },
	sounds = sound_defaults,
})
