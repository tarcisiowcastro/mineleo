-- meseportals hardcodes allowPrivatePortals = true in its own init.lua
-- (not a minetest.conf setting), so every portal is owner-exclusive by
-- default. This is a plain Lua flag read at use-time (not something the
-- engine snapshots at registration), so overriding it here after
-- meseportals loads is enough to make every portal public for everyone.
meseportals.allowPrivatePortals = false
