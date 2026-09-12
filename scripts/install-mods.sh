#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p mods

mods="
creatura https://github.com/ElCeejo/creatura
animalia https://github.com/ElCeejo/animalia
mobkit https://github.com/mt-mods/mobkit
biofuel https://github.com/Lokrates/Biofuel
motorboat https://github.com/APercy/motorboat
priviledges_manager https://github.com/JamesClarke7283/priviledges_manager
unified_inventory https://github.com/minetest-mods/unified_inventory
cg_plus https://github.com/random-geek/cg_plus
multidecor https://github.com/Andrey2470T/multidecor
edit_skin https://github.com/MrRar/edit_skin
xcompat https://github.com/mt-mods/xcompat
travelnet https://github.com/mt-mods/travelnet
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

mkdir -p textures

texturepacks="
sharpnet https://github.com/Sharpik/Minetest-SharpNet-Photo-Realism-Texturespack
"

echo "$texturepacks" | while read -r name url; do
  [ -z "$name" ] && continue
  if [ -d "textures/$name/.git" ]; then
    echo "== atualizando texture pack $name"
    git -C "textures/$name" pull --ff-only
  else
    echo "== clonando texture pack $name"
    git clone --depth 1 "$url" "textures/$name"
  fi
done

echo
echo "Mods e texturas prontos. Rode 'docker compose up -d --build' para aplicar."
