#!/usr/bin/env bash
# Cài môi trường cho Codespace (postCreateCommand – chạy một lần khi tạo): thư viện Python, .env.
# ODBC Driver 18 đã có trong image (.devcontainer/Dockerfile).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pip install -q -r requirements.txt pytest

# Ứng dụng kết nối SQL Server trong Docker qua 127.0.0.1 (giống CI); giữ .env đã sửa tay nếu có
if [[ ! -f .env ]]; then
  sed 's/^DB_SERVER=.*/DB_SERVER=127.0.0.1/' .env.example > .env
  echo "Đã tạo .env từ .env.example"
fi
