#!/usr/bin/env bash
# Dựng lại toàn bộ CSDL ECMS: chạy lần lượt các script 01 → 09.
#
#   database/run_all.sh                 # dùng sqlcmd trên máy, nếu không có thì chạy trong container ecms-mssql
#   database/run_all.sh 01 02           # chỉ chạy các file bắt đầu bằng 01, 02
#   SQLCMD_MODE=docker database/run_all.sh
#
# Đọc SA_PASSWORD, DB_SERVER, DB_PORT từ .env (nếu có).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT/.env" ]] && set -a && source "$ROOT/.env" && set +a

SA_PASSWORD="${SA_PASSWORD:-Ecms@12345}"
SERVER="${DB_SERVER:-localhost},${DB_PORT:-1433}"
CONTAINER="${CONTAINER:-ecms-mssql}"
MODE="${SQLCMD_MODE:-auto}"

if [[ "$MODE" == "auto" ]]; then
  if command -v sqlcmd >/dev/null 2>&1; then MODE=local; else MODE=docker; fi
fi

DEFAULT_FILES=(01_schema 02_seed 03_functions 04_views 05_procedures 06_triggers 07_cursors 08_security 09_xml)
if [[ $# -gt 0 ]]; then PREFIXES=("$@"); else PREFIXES=("${DEFAULT_FILES[@]}"); fi

run_file() {
  local f="$1" name
  name="$(basename "$f")"
  echo "▶ $name"
  # -b: dừng khi lỗi · -f 65001: đọc file UTF-8 (tiếng Việt) · -C: tin chứng chỉ tự ký · -I: QUOTED_IDENTIFIER ON
  if [[ "$MODE" == "local" ]]; then
    sqlcmd -S "$SERVER" -U sa -P "$SA_PASSWORD" -C -b -I -f 65001 -i "$f"
  else
    docker exec -i "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" \
      -C -b -I -f 65001 -i "/database/$name"
  fi
}

# Chờ SQL Server sẵn sàng (tối đa 2 phút): lần đầu khởi động container còn đổi collation máy chủ,
# tạo CSDL lúc đó làm máy chủ tự tắt – xem database/healthcheck.sql
wait_ready() {
  local i
  for i in $(seq 1 60); do
    if [[ "$MODE" == "local" ]]; then
      sqlcmd -S "$SERVER" -U sa -P "$SA_PASSWORD" -C -b -f 65001 -i "$ROOT/database/healthcheck.sql" -o /dev/null 2>/dev/null && return 0
    else
      # healthcheck.sh không kết nối khi máy chủ đang đổi collation (kết nối lúc đó gây deadlock, Msg 3434)
      docker exec "$CONTAINER" bash /database/healthcheck.sh 2>/dev/null && return 0
    fi
    [[ $i -eq 1 ]] && echo "… chờ SQL Server sẵn sàng"
    sleep 2
  done
  echo "✗ SQL Server chưa sẵn sàng sau 2 phút" >&2
  exit 1
}

start=$(date +%s)
wait_ready
for p in "${PREFIXES[@]}"; do
  shopt -s nullglob
  matches=("$ROOT"/database/${p}*.sql)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "· bỏ qua $p (chưa có file)"
    continue
  fi
  for f in "${matches[@]}"; do run_file "$f"; done
done
echo "✓ Xong sau $(( $(date +%s) - start )) giây ($MODE)."
