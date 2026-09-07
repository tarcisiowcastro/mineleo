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

echo
echo "Mods prontos em ./mods. Rode 'docker compose up -d --build' para aplicar."
