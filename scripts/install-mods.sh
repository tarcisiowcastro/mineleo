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
pova https://codeberg.org/tenplus1/pova
other_worlds https://codeberg.org/tenplus1/other_worlds
moreblocks https://github.com/minetest-mods/moreblocks
ambience https://codeberg.org/tenplus1/ambience
awards https://codeberg.org/rubenwardy/awards
hangglider https://github.com/mt-mods/hangglider
bike https://gitlab.com/h2mm/bike
supercub https://github.com/APercy/supercub
hidroplane https://github.com/APercy/hidroplane
mobs_npc https://codeberg.org/tenplus1/mobs_npc
castle_masonry https://github.com/minetest-mods/castle_masonry
castle_gates https://github.com/minetest-mods/castle_gates
castle_lighting https://github.com/minetest-mods/castle_lighting
castle_shields https://github.com/minetest-mods/castle_shields
castle_storage https://github.com/minetest-mods/castle_storage
anvil https://github.com/minetest-mods/anvil
castle_farming https://github.com/minetest-mods/castle_farming
castle_weapons https://github.com/minetest-mods/castle_weapons
crafting_bench https://github.com/minetest-mods/crafting_bench
orbs_of_time https://github.com/minetest-mods/orbs_of_time
ropes https://github.com/minetest-mods/ropes
mypaths https://github.com/minetest-mods/mypaths
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

# Fixados num commit (+ patch opcional em scripts/patches/<nome>.patch):
# - modlib/character_anim: o commit de 2025 corrige o corpo virado nos
#   clientes Luanti 5.11+, mas usa API do 5.9; o patch adapta para o 5.6.1.
# - size_editer: corrigido em runtime pelo mod proprio tamanho_jogador.
pinned="
modlib https://github.com/appgurueu/modlib 59ed71df15e4e01e0bb096e7b1d709ea9fdb25cb
character_anim https://github.com/appgurueu/character_anim 61b62ae2c71518bf6363736a63f54010f969c78a
size_editer https://github.com/HyvoxelCraft/size_editer 9e305c5
"
echo "$pinned" | while read -r name url rev; do
  [ -z "$name" ] && continue
  if [ ! -d "mods/$name/.git" ]; then
    echo "== clonando $name (fixo em $rev)"
    timeout 120 git clone -q "$url" "mods/$name" || { echo "!! $name: clone falhou"; continue; }
  fi
  if ! git -C "mods/$name" rev-parse HEAD | grep -q "^$rev"; then
    timeout 60 git -C "mods/$name" fetch -q origin || true
    git -C "mods/$name" checkout -q -f "$rev" || echo "!! $name: checkout $rev falhou"
  fi
  patch="scripts/patches/$name.patch"
  if [ -f "$patch" ] && ! git -C "mods/$name" apply --reverse --check "../../$patch" 2>/dev/null; then
    git -C "mods/$name" apply "../../$patch" && echo "== $name: patch aplicado" || echo "!! $name: patch falhou"
  fi
done

# christmastree: sem repositorio git, so zip no ContentDB (release 1.0.2).
if [ ! -d "mods/christmastree" ]; then
  echo "== baixando christmastree (release 1.0.2)"
  curl -sL -o /tmp/christmastree.zip \
    "https://content.luanti.org/packages/ExeterDad/christmastree/releases/8099/download/"
  unzip -q -o /tmp/christmastree.zip -d mods/
  rm -f /tmp/christmastree.zip
fi

echo
echo "Mods prontos em ./mods. Rode 'docker compose up -d --build' para aplicar."
