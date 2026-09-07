#!/bin/sh
set -e

WORLD_DIR=/luanti/world
WORLD_MT="$WORLD_DIR/world.mt"
MODS="creatura animalia mobkit biofuel motorboat priviledges_manager unified_inventory mob_spawn_panel"

mkdir -p "$WORLD_DIR"
touch "$WORLD_MT"

for mod in $MODS; do
  sed -i "/^load_mod_$mod = /d" "$WORLD_MT"
  printf 'load_mod_%s = true\n' "$mod" >> "$WORLD_MT"
done

# minetestserver only scans /root/.minetest/mods for global mods; it has no
# flag to point it at another path, so link our bind-mounted /luanti/mods in.
mkdir -p /root/.minetest
ln -sfn /luanti/mods /root/.minetest/mods

exec /usr/games/minetestserver --config /luanti/minetest.conf
