#!/bin/sh
set -e

WORLD_DIR=/luanti/world
WORLD_MT="$WORLD_DIR/world.mt"
MODS="creatura animalia mobkit biofuel motorboat priviledges_manager unified_inventory mob_spawn_panel"

mkdir -p "$WORLD_DIR"
touch "$WORLD_MT"

# A brand-new world.mt has no gameid, and unlike most other fields
# minetestserver has no fallback for it -- it just refuses to start
# ("Game [] could not be found"). Only set it if missing so we never
# clobber an existing world's value.
if ! grep -q "^gameid = " "$WORLD_MT"; then
  printf 'gameid = minetest\n' >> "$WORLD_MT"
fi

for mod in $MODS; do
  sed -i "/^load_mod_$mod = /d" "$WORLD_MT"
  printf 'load_mod_%s = true\n' "$mod" >> "$WORLD_MT"
done

# minetestserver only scans /root/.minetest/mods for global mods; it has no
# flag to point it at another path, so link our bind-mounted /luanti/mods in.
mkdir -p /root/.minetest
ln -sfn /luanti/mods /root/.minetest/mods

exec /usr/games/minetestserver --config /luanti/minetest.conf
