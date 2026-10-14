#!/usr/bin/env bash
# Sao lưu ECMS theo lịch bằng cron (dùng khi không có SQL Server Agent, VD bản Express hoặc Docker).
#
#   scripts/backup.sh FULL|DIFF|LOG
#
# crontab -e (giờ máy chủ):
#   0 1 * * 0      /đường/dẫn/ecms/scripts/backup.sh FULL     # Chủ nhật 01:00
#   0 1 * * 1-6    /đường/dẫn/ecms/scripts/backup.sh DIFF     # Thứ Hai – thứ Bảy 01:00
#   */15 * * * *   /đường/dẫn/ecms/scripts/backup.sh LOG      # mỗi 15 phút
#   30 2 * * *     find /đường/dẫn/ecms/backups -name 'ECMS_*' -mtime +14 -delete   # giữ 14 ngày
#
# Cần procedure master.dbo.sp_SaoLuuECMS (database/11_backup_restore.sql).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT/.env" ]] && set -a && source "$ROOT/.env" && set +a
LOAI="${1:?Dùng: backup.sh FULL|DIFF|LOG}"
CONTAINER="${CONTAINER:-ecms-mssql}"
SQL="EXEC master.dbo.sp_SaoLuuECMS @Loai = '$LOAI';"
if command -v sqlcmd >/dev/null 2>&1; then
  sqlcmd -S "${DB_SERVER:-localhost},${DB_PORT:-1433}" -U sa -P "${SA_PASSWORD:-Ecms@12345}" -C -b -Q "$SQL"
else
  docker exec "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${SA_PASSWORD:-Ecms@12345}" -C -b -Q "$SQL"
fi
echo "$(date '+%F %T') ✓ sao lưu $LOAI"
