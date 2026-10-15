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

start=$(date +%s)
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
