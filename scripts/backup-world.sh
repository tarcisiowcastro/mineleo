#!/usr/bin/env bash
set -euo pipefail

# Para o servidor durante a copia pra o map.sqlite nao sair inconsistente.
# Inclui mods/ porque parte dos mods proprios so existe na VPS.
# Rode pelo cron da VPS, ex.: 0 5 * * * /root/mineleo/scripts/backup-world.sh
cd "$(dirname "$0")/.."

BACKUP_DIR="${BACKUP_DIR:-/root/mineleo-backups}"
KEEP_DAYS="${KEEP_DAYS:-2}"
FILE="$BACKUP_DIR/mineleo-$(date +%Y%m%d-%H%M%S).tar.gz"

mkdir -p "$BACKUP_DIR"

# Religa o servidor mesmo se o tar falhar no meio.
trap 'docker compose start' EXIT
docker compose stop -t 180
tar -czf "$FILE" world mods minetest.conf
trap - EXIT
docker compose start

find "$BACKUP_DIR" -name 'mineleo-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
echo "Backup salvo em $FILE"
