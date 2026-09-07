#!/bin/sh
set -e

WORLD_DIR=/luanti/world
WORLD_MT="$WORLD_DIR/world.mt"
MODS="creatura animalia mobkit biofuel motorboat"

mkdir -p "$WORLD_DIR"
touch "$WORLD_MT"

for mod in $MODS; do
  sed -i "/^load_mod_$mod = /d" "$WORLD_MT"
  printf 'load_mod_%s = true\n' "$mod" >> "$WORLD_MT"
done

exec /usr/games/minetestserver --config /luanti/minetest.conf
