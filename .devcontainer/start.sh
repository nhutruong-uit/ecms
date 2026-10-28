#!/usr/bin/env bash
# Khởi động ECMS trong Codespace (postAttachCommand – mỗi lần mở Codespace):
# SQL Server (docker compose) → dựng CSDL nếu chưa có → Streamlit ở cổng 8501.
#   bash .devcontainer/start.sh            # chạy lại tay nếu đã tắt terminal
#   RESET_DB=1 bash .devcontainer/start.sh # dựng lại CSDL, dữ liệu về như ban đầu
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
SA_PASSWORD="${SA_PASSWORD:-Ecms@12345}"

# Mở Codespace ở hai cửa sổ thì cửa sổ sau không chạy Streamlit lần nữa (trùng cổng 8501)
if curl -fs http://localhost:8501/_stcore/health >/dev/null 2>&1; then
  echo "ECMS đang chạy ở cổng 8501 (tab Ports)."
  exit 0
fi

# Docker daemon (feature docker-in-docker) có thể chưa lên xong lúc Codespace vừa mở
for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done

echo "▶ Khởi động SQL Server 2025 (lần đầu tải image khoảng 1–2 phút)"
docker compose up -d --wait mssql

# CSDL dựng xong khi có fn_KyNangKiemTra – đối tượng cuối cùng 09_xml.sql giữ lại (chỉ mục XML tạo sau đó bị xoá
# khi đo X18). Thiếu (lần đầu, hoặc lần trước bị ngắt giữa chừng) thì chạy lại run_all.sh từ đầu
# (01_schema.sql xoá CSDL cũ rồi tạo lại)
DONE_SQL="SET NOCOUNT ON; IF OBJECT_ID(N'ECMS.dbo.fn_KyNangKiemTra') IS NULL THROW 50000, N'chưa dựng', 1;"
if [[ "${RESET_DB:-0}" == "1" ]] || ! docker exec ecms-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa \
     -P "$SA_PASSWORD" -C -b -Q "$DONE_SQL" >/dev/null 2>&1; then
  echo "▶ Dựng CSDL ECMS (01 → 09)"
  SQLCMD_MODE=docker database/run_all.sh
fi

echo "▶ Chạy Streamlit – mở tab Ports, cổng 8501. Muốn người khác xem: chuột phải → Port Visibility → Public"
# Codespaces đưa trang qua proxy *.app.github.dev: tắt kiểm tra CORS / XSRF để websocket và tải file lên hoạt động
# (cấu hình mẫu Codespaces của Streamlit cũng làm vậy)
exec python -m streamlit run app/main.py --server.headless true \
  --server.enableCORS false --server.enableXsrfProtection false
