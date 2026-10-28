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
docker compose up -d --wait          # lần đầu tải image ~1,5 GB; chờ trạng thái "healthy"
```

- Image mặc định là `mssql/server:2025-latest`. Không dùng image 2022 cho Linux: các bản CU24 → CU27 lỗi *Could not load the DLL (server internal)* (Msg 17750) khi gọi `sp_executesql`, `sp_set_session_context`, `sp_xml_preparedocument`.
- Apple Silicon (M1/M2/M3): bật **Settings → General → Use Rosetta for x86/amd64 emulation** trong Docker Desktop.
- Container chỉ báo **healthy** khi SQL Server đã đổi xong collation máy chủ sang `Vietnamese_CI_AS` (`database/healthcheck.sql`). Lần khởi động đầu mất khoảng 15–20 giây; `run_all.sh` cũng tự chờ. Tạo CSDL giữa lúc đang đổi collation làm máy chủ tự tắt (Msg 3434).
- Container chạy theo giờ Việt Nam (`TZ: Asia/Ho_Chi_Minh`) để ngày lập phiếu thu, nhật ký không lệch 7 giờ.
- SQL Server Agent **tắt** ở lần khởi động đầu: Agent khởi động song song với việc đổi collation sẽ tranh chấp khoá (Msg 1205) và làm máy chủ tự tắt (Msg 3434). Cần lịch sao lưu bằng Agent (`database/11_backup_restore.sql`) thì khi container đã healthy, đặt `MSSQL_AGENT_ENABLED=true` trong `.env` rồi chạy lại `docker compose up -d`.
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
6. Nên giữ `DB_USER=ecms_app` (SQL Authentication, cần *Mixed Mode*): ứng dụng khi đó chỉ có quyền gọi procedure và đọc view như thiết kế. `DB_TRUSTED=yes` (Windows Authentication) chỉ dùng khi không bật được Mixed Mode – tài khoản Windows thường là `sysadmin` nên bỏ qua phân quyền của `ecms_app`; các kiểm tra theo ngữ cảnh phiên trong procedure vẫn áp dụng. Login `sa` đang tắt (mặc định khi cài bằng Windows Authentication) thì đặt `SA_TRUSTED=yes` để các script quản trị (`scripts/import_export.py`, `oodb/`, `nosql/`) kết nối bằng tài khoản Windows đang chạy thay cho `sa`.
7. Chạy kiểm thử SQL bằng `sqlcmd` nhớ thêm `-I` (bật `QUOTED_IDENTIFIER`): `foreach ($t in "test_seed","test_procedures","test_triggers","test_security") { sqlcmd -S localhost -E -C -b -I -f 65001 -i "database\tests\$t.sql" }`.

Khác biệt theo bản SQL Server:

| Bản | Ảnh hưởng |
|---|---|
| Express | Không có SQL Server Agent: phần tạo job ở `11_backup_restore.sql` tự bỏ qua, sao lưu định kỳ chạy bằng Task Scheduler + `sqlcmd`. Không có TDE: mục 2–3 của `14_encryption_audit.sql` tự bỏ qua. |
| Developer / Standard / Enterprise | Chạy đủ mọi kịch bản demo, kể cả Agent job, TDE, SQL Server Audit. |
| Hai máy cùng mạng (Windows + máy có Docker) | Cam kết hai pha thật qua MSDTC: `database/13b_2pc_msdtc.sql`, dựng trạm CN02 và cấu hình MSDTC / tường lửa theo `database/tram_cn02/README.md`. |

## 3. Dựng CSDL

```bash
database/run_all.sh                  # macOS / Linux / Git Bash
```

```powershell
.\database\run_all.ps1                                   # Windows Authentication
.\database\run_all.ps1 -SqlLogin sa -Password "Ecms@12345"
```

Script chờ SQL Server sẵn sàng rồi chạy lần lượt `01_schema.sql → 09_xml.sql` (bỏ qua file chưa có). Băm mật khẩu lặp 10.000 vòng cho 80 tài khoản mẫu nên toàn bộ mất khoảng 20 giây. Mỗi file chạy lại được từ đầu, nên có thể chạy lại bất cứ lúc nào. Chỉ chạy một số file: `database/run_all.sh 04 05`.

Trên Windows cũng có thể mở từng file trong SSMS và nhấn **F5** theo đúng thứ tự.

## 4. Chạy ứng dụng web

```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
streamlit run app/main.py
```

Kiểm thử ứng dụng (cần CSDL vừa dựng): `pip install pytest` rồi `pytest tests/ -q` (125 ca).

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

## 6. Demo trên GitHub Codespaces (không cần máy của nhóm)

Codespace là máy ảo Linux của GitHub chạy trong trình duyệt. Repo có sẵn cấu hình `.devcontainer/`, nên mở Codespace là có SQL Server 2025 (Docker), CSDL `ECMS` và Streamlit, không phải cài gì. Codespace tự ngủ khi không ai dùng (mặc định 30 phút), hợp cho buổi demo chứ không chạy 24/7. Giờ dùng miễn phí hằng tháng xem ở **Settings → Billing** của tài khoản GitHub; máy 2 lõi là đủ.

1. Trên trang repo: **Code → Codespaces → Create codespace on main** (lần sau chọn lại Codespace cũ trong danh sách, khỏi tạo mới).
2. Lần đầu chờ khoảng 5 phút: dựng image (`Dockerfile`, có ODBC Driver 18), `setup.sh` cài thư viện Python, rồi `start.sh` khởi động SQL Server, dựng CSDL (01 → 09) và chạy Streamlit ngay trong terminal. Lần mở sau chỉ còn khoảng 1 phút vì CSDL đã có.
3. Tab **Ports** → cổng **8501** → chuột phải → **Port Visibility → Public**, rồi **Copy Local Address**. Link dạng `https://<tên-codespace>-8501.app.github.dev` mở được trên mọi máy, kể cả điện thoại, không cần đăng nhập GitHub.
4. Gửi link cho người xem. Giữ tab Codespace mở trong lúc demo; xong thì **Stop codespace** để không tốn giờ miễn phí.

| Tình huống | Cách xử lý |
|---|---|
| Lỡ đóng terminal, ứng dụng dừng | Chạy lại `bash .devcontainer/start.sh` |
| Mở Codespace bằng `gh` thay vì VS Code (`start.sh` không tự chạy) | `gh codespace ssh -c <tên> -- 'cd /workspaces/ecms && nohup setsid bash .devcontainer/start.sh > /tmp/ecms.log 2>&1 < /dev/null &'` rồi `gh codespace ports visibility 8501:public -c <tên>` |
| Muốn dữ liệu về như ban đầu | `RESET_DB=1 bash .devcontainer/start.sh` (dừng Streamlit đang chạy bằng `Ctrl+C` trước) |
| Người xem gặp trang đăng nhập GitHub | Cổng 8501 vẫn là Private – làm lại bước 3 |
| Codespace ngủ giữa buổi | Mở lại Codespace, `start.sh` tự chạy lại; link giữ nguyên nhưng cổng 8501 về Private – làm lại bước 3 |
