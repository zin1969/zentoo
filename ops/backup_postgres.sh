#!/bin/bash
# 本番 DB をダンプして、rclone で VPS の外に保管する。VPS の cron から毎日実行する。
# 手順は docs/deployment.md の「日次バックアップ」。
#
#   BACKUP_REMOTE=zentoo-backup:zentoo ops/backup_postgres.sh

set -euo pipefail

: "${BACKUP_REMOTE:?BACKUP_REMOTE is required (rclone remote:path)}"

CONTAINER="${BACKUP_CONTAINER:-zentoo-api-db}"
DB_USER="${BACKUP_DB_USER:-zentoo}"
DB_NAME="${BACKUP_DB_NAME:-app_production}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
LOCAL_KEEP_DAYS="${LOCAL_KEEP_DAYS:-7}"
REMOTE_KEEP_DAYS="${REMOTE_KEEP_DAYS:-30}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

file="$BACKUP_DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).dump"
tmp="$file.tmp"
trap 'rm -f "$tmp"' EXIT

docker exec "$CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB_NAME" > "$tmp"
# 途中で切れたダンプを保管しないよう、読めることを確かめる
docker exec -i "$CONTAINER" pg_restore --list > /dev/null < "$tmp"
mv "$tmp" "$file"

rclone copy "$file" "$BACKUP_REMOTE"

find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -mtime +"$LOCAL_KEEP_DAYS" -delete
rclone delete "$BACKUP_REMOTE" --min-age "${REMOTE_KEEP_DAYS}d" --include "${DB_NAME}_*.dump"

echo "$(date '+%F %T') backup ok: $file"
