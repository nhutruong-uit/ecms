# database/

Script SQL Server, đánh số theo **thứ tự chạy**. Mỗi file chạy lại được từ đầu (`DROP ... IF EXISTS`).

| File | Nội dung | Task | Phụ trách |
|---|---|:---:|---|
| `01_schema.sql` | Tạo CSDL `ECMS`, bảng, khoá, ràng buộc, chỉ mục | T07 | Trâm |
| `02_seed.sql` | Dữ liệu mẫu (sinh bằng `scripts/gen_seed.py`) | T08 | Dương |
| `03_functions.sql` | User-defined function | T12 | Phú |
| `04_views.sql` | View bảo mật và view báo cáo | T16 | Giang |
| `05_procedures.sql` | Stored procedure + transaction | T11 | Phú |
| `06_triggers.sql` | Trigger + nhật ký kiểm toán | T13 | Phú |
| `07_cursors.sql` | Procedure dùng cursor | T14 | Phú |
| `08_security.sql` | Login, user, role, GRANT/REVOKE/DENY | T15 | Như |
| `09_xml.sql` | XML Schema, XPath/XQuery, FOR XML | T10 | Dương |
| `10_queries.sql` | ≥ 25 truy vấn nghiệp vụ (chỉ để demo, không cần cho ứng dụng) | T09 | Dương |
| `11_backup_restore.sql` | Kịch bản sao lưu / phục hồi (demo) | T17 | Giang |
| `12_import_export.sql` | BULK INSERT, OPENROWSET, FOR JSON (demo) | T18 | Dương |
| `13_distributed.sql` | CSDL phân tán theo chi nhánh (demo) | T26 | Phú |
| `13b_2pc_msdtc.sql` | Cam kết hai pha qua MSDTC giữa hai máy: trạm CN01 trên Windows, trạm CN02 trên máy thứ hai (`tram_cn02/`) (demo) | T30 | Như |
| `14_encryption_audit.sql` | TLS, TDE, mã hoá cột, Dynamic Data Masking, SQL Server Audit, ledger (demo) | T30 | Như |
| `healthcheck.sql` | SQL Server đã sẵn sàng chưa (chờ đổi collation xong) – dùng bởi `healthcheck.sh` và `run_all` | T30 | Như |
| `healthcheck.sh` | Healthcheck Docker: đọc errorlog từ file, chỉ kết nối (chạy `healthcheck.sql`) khi không còn đổi collation – kết nối lúc đang đổi gây deadlock (Msg 1205 → 3434) | T30 | Như |

`run_all.sh` / `run_all.ps1` (T03) chờ SQL Server sẵn sàng (`healthcheck.sql`) rồi chạy lần lượt các file 01 → 09 để dựng CSDL
đầy đủ cho ứng dụng. Các file 10 → 14 là kịch bản demo, chạy riêng trong SSMS hoặc sqlcmd (11, 13, 14 cần quyền `sa`).

## Kiểm thử (`tests/`)

| File | Nội dung |
|---|---|
| `test_seed.sql` | Dữ liệu mẫu nhất quán: sĩ số, tổng tiền phiếu thu, công nợ, kết quả theo điểm |
| `test_procedures.sql` | 39 ca: procedure nghiệp vụ, mã lỗi, giao dịch, khoá chống tranh chấp, mã yêu cầu chống lập phiếu trùng |
| `test_triggers.sql` | 22 ca: trigger sĩ số, trùng lịch, tổng tiền, nhật ký kiểm toán, view INSTEAD OF |
| `test_security.sql` | 53 ca: phân quyền theo vai trò bằng `EXECUTE AS`, ngữ cảnh phiên chỉ đọc, phạm vi chi nhánh, đăng nhập và tạm khoá |
| `bench_cursor.sql` | So sánh cursor với set-based trên cùng thao tác ghi, N = 20 lần |

```bash
sqlcmd -S localhost,14334 -U sa -P "$SA_PASSWORD" -C -b -I -f 65001 -i database/tests/test_security.sql   # Docker
sqlcmd -S localhost -E -C -b -I -f 65001 -i database\tests\test_security.sql                             # Windows
```

`-I` bật `QUOTED_IDENTIFIER` (sqlcmd mặc định tắt, SSMS mặc định bật): thiếu nó thì mọi lệnh ghi vào bảng có chỉ mục lọc
(filtered index) hoặc gọi phương thức XML báo lỗi 1934.
