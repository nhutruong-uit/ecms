# Hướng dẫn cài đặt môi trường

Mục tiêu: mọi thành viên chạy **cùng một CSDL `ECMS`** và ứng dụng web Streamlit, trên Windows lẫn macOS.

| Thành phần | Windows | macOS |
|---|---|---|
| SQL Server | SQL Server 2022 Developer/Express + SSMS | Docker Desktop + `docker compose` (SQL Server 2025) |
| Công cụ SQL | SSMS (có `sqlcmd`) | VS Code + extension **SQL Server (mssql)**, hoặc Azure Data Studio |
| ODBC | ODBC Driver 18 for SQL Server | `brew install msodbcsql18` |
| Python | 3.11+ | 3.11+ |

## 1. Lấy mã nguồn

```bash
git clone https://github.com/nhutruong-uit/ecms.git
cd ecms
git switch develop
cp .env.example .env        # Windows: copy .env.example .env
```

## 2. Cài SQL Server

### macOS (Docker)

```bash
docker compose up -d                 # lần đầu tải image ~1,5 GB
docker compose ps                    # chờ trạng thái "healthy"
```

- Image mặc định là `mssql/server:2025-latest`. Không dùng image 2022 cho Linux: các bản CU24 → CU27 lỗi *Could not load the DLL (server internal)* (Msg 17750) khi gọi `sp_executesql`, `sp_set_session_context`, `sp_xml_preparedocument`.
- Apple Silicon (M1/M2/M3): bật **Settings → General → Use Rosetta for x86/amd64 emulation** trong Docker Desktop.
- Dữ liệu nằm trong volume `mssql-data`, xoá container không mất dữ liệu. Muốn làm lại từ đầu: `docker compose down -v`.
- Thư mục `backups/` của repo được gắn vào `/var/opt/mssql/backup` (dùng ở T17), `data/` gắn vào `/data` (T10, T18).

Cài ODBC Driver 18:

```bash
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18
```

### Windows

1. Cài **SQL Server 2022 Developer** (hoặc Express), chọn *Mixed Mode* (SQL Server and Windows Authentication), đặt mật khẩu `sa`.
2. Khi cài, chọn collation **Vietnamese_CI_AS** (hoặc để mặc định – script tạo CSDL đã chỉ định collation riêng).
3. Cài **SSMS** và **ODBC Driver 18 for SQL Server**.
4. Mở *SQL Server Configuration Manager* → bật **TCP/IP** cho instance, khởi động lại dịch vụ.
5. Sửa `.env`: `DB_SERVER=localhost` (Express: `localhost\SQLEXPRESS`, khi đó để trống `DB_PORT` hoặc dùng cổng động đã cấu hình).

## 3. Dựng CSDL

```bash
database/run_all.sh                  # macOS / Linux / Git Bash
```

```powershell
.\database\run_all.ps1                                   # Windows Authentication
.\database\run_all.ps1 -SqlLogin sa -Password "Ecms@12345"
```

Script chạy lần lượt `01_schema.sql → 09_xml.sql` (bỏ qua file chưa có). Mỗi file chạy lại được từ đầu, nên có thể chạy lại bất cứ lúc nào. Chỉ chạy một số file: `database/run_all.sh 04 05`.

Trên Windows cũng có thể mở từng file trong SSMS và nhấn **F5** theo đúng thứ tự.

## 4. Chạy ứng dụng web

```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
streamlit run app/main.py
```

Mở http://localhost:8501 → **Kiểm tra kết nối**. Trang báo *Kết nối thành công* kèm số bảng là môi trường đã sẵn sàng.

Ứng dụng kết nối CSDL bằng login ít quyền `ecms_app` (tạo ở `08_security.sql`, mật khẩu trong `.env.example`): chỉ được gọi procedure và đọc view, không truy cập bảng.

**Tài khoản demo** (dữ liệu mẫu, chỉ dùng cho môi trường phát triển):

| Tài khoản | Mật khẩu | Vai trò |
|---|---|---|
| `quanly` | `Ecms@2026` | Quản lý trung tâm (xem mọi chi nhánh) |
| `giaovu` | `Ecms@2026` | Giáo vụ CN01 |
| `ketoan` | `Ecms@2026` | Kế toán CN01 |
| `giaovien` | `Ecms@2026` | Giáo viên |
| `hocvien` | `Hocvien@2026` | Học viên |

Login SQL Server minh hoạ từng vai trò (`ecms_quanly`, `ecms_giaovu`, …) có mật khẩu ghi trong đầu file `database/08_security.sql`.

## 5. Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `Can't open lib 'ODBC Driver 18 for SQL Server'` | Chưa cài driver, xem bước 2 |
| `SSL Provider: certificate verify failed` | Đặt `DB_TRUST_CERT=yes` trong `.env` |
| `Login timeout expired` | Container chưa chạy xong (`docker compose ps`), hoặc Windows chưa bật TCP/IP |
| `Login failed for user 'sa'` | `SA_PASSWORD` trong `.env` khác mật khẩu lúc tạo container – `docker compose down -v` rồi `up -d` lại |
| Tiếng Việt bị lỗi font trong kết quả `sqlcmd` | Chạy kèm `-f 65001` (run_all đã có sẵn) |
