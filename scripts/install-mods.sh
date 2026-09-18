#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p mods

mods="
creatura https://github.com/ElCeejo/creatura
animalia https://github.com/ElCeejo/animalia
biofuel https://github.com/Lokrates/Biofuel
priviledges_manager https://github.com/JamesClarke7283/priviledges_manager
unified_inventory https://github.com/minetest-mods/unified_inventory
cg_plus https://github.com/random-geek/cg_plus
multidecor https://github.com/Andrey2470T/multidecor
edit_skin https://github.com/MrRar/edit_skin
xcompat https://github.com/mt-mods/xcompat
travelnet https://github.com/mt-mods/travelnet
mobs https://codeberg.org/tenplus1/mobs_redo
mobs_monster https://codeberg.org/tenplus1/mobs_monster
dmobs https://codeberg.org/tenplus1/dmobs
visual_harm_1ndicators https://codeberg.org/Mantar/vis_harm_1nd
worldedit https://github.com/Uberi/Minetest-WorldEdit
airutils https://github.com/APercy/airutils
ww1_planes https://github.com/APercy/ww1_planes
discovery_maps https://codeberg.org/TomCon/discovery_maps
elevator https://github.com/tigris-mt/elevator
advtrains https://git.bananach.space/advtrains.git
advtrains_freight_train https://codeberg.org/advtrains_supplemental/advtrains_freight_train
"

echo "$mods" | while read -r name url; do
  [ -z "$name" ] && continue
  if [ -d "mods/$name/.git" ]; then
    echo "== atualizando $name"
    git -C "mods/$name" pull --ff-only
  else
    echo "== clonando $name"
    git clone --depth 1 "$url" "mods/$name"
  fi
done

# automobiles_pck's git HEAD moved on to requiring Luanti 5.12+; pinned to
# release 0.68e (ContentDB release id 31481), the newest one still declaring
# Luanti 5.6+ support, since that's what this server runs. No git tag exists
# for it, so this is a one-off zip download instead of a git clone.
if [ ! -d "mods/automobiles_pck" ]; then
  echo "== baixando automobiles_pck (release 0.68e, pinned p/ Luanti 5.6+)"
  curl -sL -o /tmp/automobiles_pck.zip \
    "https://content.luanti.org/packages/apercy/automobiles_pck/releases/31481/download/"
  unzip -q -o /tmp/automobiles_pck.zip -d mods/
  rm -f /tmp/automobiles_pck.zip
else
  echo "== automobiles_pck ja presente (pinado, nao atualiza sozinho)"
fi

# Same story as automobiles_pck: steampunk_blimp's git HEAD requires Luanti
# 5.9+ now. Pinned to release 0.47 (ContentDB release id 30012), the newest
# one still declaring Luanti 5.4+ support.
if [ ! -d "mods/steampunk_blimp" ]; then
  echo "== baixando steampunk_blimp (release 0.47, pinned p/ Luanti 5.4+)"
  curl -sL -o /tmp/steampunk_blimp.zip \
    "https://content.luanti.org/packages/apercy/steampunk_blimp/releases/30012/download/"
  unzip -q -o /tmp/steampunk_blimp.zip -d mods/
  rm -f /tmp/steampunk_blimp.zip
else
  echo "== steampunk_blimp ja presente (pinado, nao atualiza sozinho)"
fi

echo
echo "Mods prontos em ./mods. Rode 'docker compose up -d --build' para aplicar."
