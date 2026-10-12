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

`run_all.sh` / `run_all.ps1` (T03) chạy lần lượt các file 01 → 09 để dựng CSDL đầy đủ cho ứng dụng.
