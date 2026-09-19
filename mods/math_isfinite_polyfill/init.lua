-- airutils' lib_planes/custom_physics.lua calls math.isfinite(), which
-- doesn't exist in Lua 5.1 (what Minetest embeds) -- crashes the server
-- every physics tick a plane entity exists ("attempt to call field
-- 'isfinite' (a nil value)"), which persists in the world and re-crashes
-- on every restart. Polyfilling it here is enough; nothing needs to load
-- before this, since the crash only happens at runtime (entity step),
-- well after all mods finish loading.
if not math.isfinite then
	function math.isfinite(x)
		return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
	end
end
