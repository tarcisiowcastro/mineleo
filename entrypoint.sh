#!/bin/sh
set -e

WORLD_DIR=/luanti/world
WORLD_MT="$WORLD_DIR/world.mt"
MODS="creatura animalia biofuel priviledges_manager unified_inventory mob_spawn_panel cg_plus tree_thinner decor_api craft_ingredients modern edit_skin automobiles_lib automobiles_beetle automobiles_buggy automobiles_catrelle automobiles_coupe automobiles_delorean automobiles_motorcycle automobiles_roadster automobiles_trans_am automobiles_vespa river_flow xcompat travelnet turbo_fly mobs mobs_monster dmobs visual_harm_1ndicators worldedit worldedit_commands worldedit_gui worldedit_shortcommands worldedit_brush airutils steampunk_blimp ww1_planes_lib albatros_d5 sopwith_f1_camel discovery_maps elevator serialize_lib advtrains advtrains_train_track advtrains_freight_train math_isfinite_polyfill"

mkdir -p "$WORLD_DIR"
touch "$WORLD_MT"

# A brand-new world.mt has no gameid, and unlike most other fields
# minetestserver has no fallback for it -- it just refuses to start
# ("Game [] could not be found"). Only set it if missing so we never
# clobber an existing world's value.
if ! grep -q "^gameid = " "$WORLD_MT"; then
  printf 'gameid = minetest\n' >> "$WORLD_MT"
fi

# Strip every load_mod_* line first (not just ones for mods still in
# $MODS) so a mod removed from this list doesn't linger as a stale
# "could not be found" entry, then set exactly the current list.
sed -i '/^load_mod_/d' "$WORLD_MT"
for mod in $MODS; do
  printf 'load_mod_%s = true\n' "$mod" >> "$WORLD_MT"
done

# minetestserver only scans /root/.minetest/mods for global mods; it has no
# flag to point it at another path, so link our bind-mounted /luanti/mods in.
mkdir -p /root/.minetest
ln -sfn /luanti/mods /root/.minetest/mods

exec /usr/games/minetestserver --config /luanti/minetest.conf
