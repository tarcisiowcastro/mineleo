#!/bin/sh
set -e

WORLD_DIR=/luanti/world
WORLD_MT="$WORLD_DIR/world.mt"
MODS="creatura animalia mobkit biofuel motorboat priviledges_manager unified_inventory mob_spawn_panel cg_plus tree_thinner decor_api craft_ingredients modern edit_skin automobiles_lib automobiles_beetle automobiles_buggy automobiles_catrelle automobiles_coupe automobiles_delorean automobiles_motorcycle automobiles_roadster automobiles_trans_am automobiles_vespa river_flow xcompat travelnet"

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

# A texture pack folder literally named "server" gets sent to every client
# automatically (unless they've picked their own pack locally).
if [ -d /luanti/textures/sharpnet ]; then
  mkdir -p /root/.minetest/textures
  ln -sfn /luanti/textures/sharpnet /root/.minetest/textures/server
fi

exec /usr/games/minetestserver --config /luanti/minetest.conf
