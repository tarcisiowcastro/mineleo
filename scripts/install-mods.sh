#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p mods

# working_villages: manutenção listada como "desconhecida" na ContentDB e há
# reviews de crash (lenhador cortando árvore, placa de construção) e de bugs
# que pioram combinados com outros mods de mob — aqui já rodamos
# creatura/animalia/dmobs/mobs_monster. Teste num mundo local antes de subir
# pra VPS; se travar o servidor, `rm -rf mods/working_villages` e remover a
# linha do world.mt resolve sem afetar os demais mods.
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
working_villages https://github.com/theFox6/working_villages
areas https://github.com/minetest-mods/areas
handle_schematics https://github.com/Sokomine/handle_schematics
mg_villages https://github.com/Sokomine/mg_villages
mobs_animal https://codeberg.org/tenplus1/mobs_animal
"

echo "$mods" | while read -r name url; do
  [ -z "$name" ] && continue
  # timeout evita que um host lento/instável (ex: git.bananach.space do
  # advtrains) trave o script inteiro pra sempre; "|| true" deixa seguir
  # pros próximos mods em vez de abortar tudo por causa de um só.
  if [ -d "mods/$name/.git" ]; then
    echo "== atualizando $name"
    timeout 60 git -C "mods/$name" pull --ff-only \
      || echo "!! $name: pull falhou ou expirou, mantendo versão local"
    [ "$name" = "working_villages" ] && timeout 60 git -C "mods/$name" submodule update --init --recursive
  elif [ "$name" = "working_villages" ]; then
    # traz o modutil embutido como submodule (working_villagers/modutil);
    # sem --recursive o mod cai no fallback portable.lua, mas o submodule
    # é a versão que o autor mantém de fato.
    echo "== clonando $name (com submodules)"
    timeout 120 git clone --depth 1 --recursive "$url" "mods/$name" \
      || echo "!! $name: clone falhou ou expirou"
  else
    echo "== clonando $name"
    timeout 60 git clone --depth 1 "$url" "mods/$name" \
      || echo "!! $name: clone falhou ou expirou"
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
