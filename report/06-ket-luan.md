# Chương 6. Kết luận

## 6.1 Kết quả đạt được

Nhóm đã xây dựng **ECMS** – hệ thống quản lý thông tin cho chuỗi 3 chi nhánh trung tâm tiếng Anh – đi qua đủ 4 giai đoạn của quy trình quản lý thông tin (thu thập → tổ chức → xử lý → trình bày) và tìm hiểu các mô hình CSDL tiên tiến.

*Bảng 6.1 – Sản phẩm theo chương*

| Chương | Sản phẩm chính | Minh chứng trong repo |
|---|---|---|
| 1. Tổng quan | Khảo sát nghiệp vụ 8 bước, 22 yêu cầu chức năng, 8 yêu cầu phi chức năng, ánh xạ DIKW | `report/01-tong-quan.md`, `docs/design/quy-trinh-nghiep-vu.*` |
| 2. Tổ chức thông tin | ERD (Chen) 17 thực thể, Class Diagram, lược đồ quan hệ chuẩn hoá (17/22 quan hệ đạt BCNF, phần còn lại có lý do giữ), 22 bảng với PK/FK/CHECK/UNIQUE, computed column, 22 chỉ mục; so sánh mô hình phẳng – quan hệ – XML; dữ liệu mẫu ~350 học viên, 25 lớp, ~500 phiếu thu | `database/01_schema.sql`, `02_seed.sql`, `docs/design/` |
| 3. Xử lý thông tin | 31 truy vấn SQL + truy vấn XML (XML Schema, `nodes/value/modify`); 27 view (có indexed view, `WITH CHECK OPTION`, view lọc theo chi nhánh); 38 procedure, 13 function, 11 trigger, cursor so sánh với set-based; phân quyền 5 role + login riêng ứng dụng, băm mật khẩu SHA2_256 + salt, nhật ký; sao lưu FULL/DIFF/LOG + phục hồi theo thời điểm; nhập/xuất CSV, XML, JSON | `database/03`–`12_*.sql`, `database/tests/` |
| 4. Trình bày thông tin | Ứng dụng web Streamlit: menu 2 cấp theo vai trò, 21 trang, 2 form master–detail, 9 báo cáo PDF/Excel, dashboard KPI | `app/`, `report/04-trinh-bay-thong-tin.md` |
| 5. CSDL tiên tiến | Lược đồ ODL + mapper Python (hướng đối tượng); phân mảnh ngang 3 trạm + partitioned view (phân tán); MongoDB 4 collection + 6 cặp truy vấn đối chiếu (NoSQL); bảng so sánh 4 mô hình | `oodb/`, `database/13_distributed.sql`, `nosql/` |

### 6.1.1 Đối chiếu yêu cầu

- **Yêu cầu chức năng FR01–FR22**: đã cài đặt đủ. Mỗi FR gắn với task và PR tương ứng (cột "Task" ở bảng 1.4.2); các luật nghiệp vụ (lớp còn chỗ, khoá tiên quyết, trùng phòng/giáo viên, thu không vượt thành tiền…) nằm trong CSDL nên không thể bị bỏ qua từ giao diện.
- **Yêu cầu phi chức năng**:

| Mã | Kết quả |
|---|---|
| NFR01 Toàn vẹn | Ghi danh, chuyển lớp, thu phí, điểm danh cả lớp chạy trong transaction lồng được (`SAVE TRANSACTION`); 25 ca kiểm thử procedure, 17 ca kiểm thử trigger đều PASS |
| NFR02 Bảo mật | Login `ecms_app` bị `DENY` trên mọi bảng, chỉ `EXECUTE`/`SELECT` qua view; 36 ca kiểm thử phân quyền PASS (truy cập bảng gốc, vượt phạm vi chi nhánh, sai vai trò…) |
| NFR03 Truy vết | Trigger ghi NHATKY (JSON trước/sau) kèm tài khoản ứng dụng lấy từ `SESSION_CONTEXT`; bảng nhật ký chỉ cho thêm |
| NFR04 Sẵn sàng | Lịch sao lưu đạt RPO 15 phút; diễn tập phục hồi theo thời điểm thành công (mục 3.2.4) |
| NFR05 Hiệu năng | Mọi trang tải < 1 giây trên dữ liệu mẫu; chỉ mục cho các cột tra cứu. *Chưa đo trên bảng chính với 10.000 học viên* (chỉ đo tốc độ nhập 10.000 dòng – mục 3.2.5) |
| NFR06 Tiếng Việt | Collation `Vietnamese_CI_AS`, `NVARCHAR`, PDF dùng font DejaVu hiển thị đúng dấu |
| NFR07 Dễ dùng | Menu 2 cấp, kiểm tra dữ liệu tại trường, thông báo lỗi tiếng Việt (Chương 4) |
| NFR08 Tái lập | `database/run_all.sh` / `run_all.ps1` dựng lại toàn bộ CSDL từ đầu |

### 6.1.2 Kiểm thử tích hợp

Kiểm thử tích hợp chạy lại toàn bộ hệ thống từ **CSDL trống**: xoá CSDL `ECMS` → chạy 01 → 09 → 4 bộ kiểm thử SQL → `10_queries.sql` → smoke test giao diện. Kết quả trên SQL Server 2025 (Docker, macOS):

| Bước | Kết quả |
|---|---|
| Dựng CSDL `01_schema` → `09_xml` | thành công, ~10 giây |
| `test_seed.sql` (11 kiểm tra nhất quán dữ liệu mẫu) | 0 lỗi |
| `test_procedures.sql` · `test_triggers.sql` · `test_security.sql` | 25 / 17 / 36 ca PASS |
| `10_queries.sql` (31 truy vấn) | chạy hết, không lỗi |
| `pytest tests/` – mọi trang × 5 vai trò + mọi báo cáo PDF/Excel | 52 passed |
| **Tổng thời gian** | ~35 giây |

Cùng quy trình được tự động hoá bằng GitHub Actions (`.github/workflows/ci.yml`) trên SQL Server 2025 (Docker, Linux) và là điều kiện bắt buộc để merge `develop → main` cho bản phát hành **v1.0.0**.

## 6.2 Hạn chế

1. **Quy mô dữ liệu nhỏ**: dữ liệu mẫu ~350 học viên; chưa kiểm thử tải với hàng chục nghìn học viên và nhiều người dùng đồng thời.
2. **Giao diện Streamlit** tải lại toàn trang sau mỗi tương tác, chưa tối ưu cho điện thoại; nút xoá chưa có hộp xác nhận (dựa vào khoá ngoại để chặn xoá dữ liệu đang được tham chiếu).
3. **Bảo mật triển khai**: chưa có HTTPS, chưa có xác thực 2 lớp; khung "Tài khoản demo" ở màn hình đăng nhập cần gỡ khi chạy thật.
4. **Phân tán** mới mô phỏng nhiều CSDL trên cùng một instance (không có độ trễ mạng thật, không có MSDTC giữa các máy).
5. **NoSQL** dừng ở bản sao một chiều từ SQL Server sang MongoDB, chưa đồng bộ liên tục (CDC).
6. **CI** chạy trên Linux; script `run_all.ps1` cho Windows chưa có CI riêng.

## 6.3 Hướng phát triển

- Cổng thông tin cho học viên / phụ huynh: đăng ký online, thanh toán trực tuyến, nhận thông báo vắng học qua email/Zalo (dữ liệu cảnh báo đã có sẵn ở bảng CANHBAO).
- Tách giao diện thành REST API + frontend (React) để hỗ trợ di động; giữ nguyên lớp procedure/view làm API nghiệp vụ.
- Kiến trúc *polyglot persistence* như kết luận ở 5.4: Redis cho phiên đăng nhập và cache dashboard, MongoDB đồng bộ bằng Change Data Capture cho cổng học viên.
- Khi mở rộng nhiều tỉnh: triển khai phân mảnh ngang theo chi nhánh ở 5.2 trên các máy chủ thật, kết hợp Always On Availability Groups.
- Kho dữ liệu (data warehouse) và mô hình dự báo học viên bỏ học dựa trên chuyên cần và điểm – nâng tầng **Wisdom** trong mô hình DIKW.

## 6.4 Phân công và mức độ đóng góp

### 6.4.1 Phân công theo task

Dự án chia **29 task** (T01–T29) theo 4 sprint, mỗi task là một issue trên GitHub và một Pull Request vào nhánh `develop` (chi tiết: [kế hoạch dự án](https://nhutruong-uit.github.io/ecms/), [GitHub Project](https://github.com/users/nhutruong-uit/projects/1)).

*Bảng 6.2 – Phân công*

| Thành viên | MSSV | Vai trò | Task phụ trách | Nội dung chính |
|---|:-:|---|---|---|
| Trương Quang Như | 25540022 | Nhóm trưởng | T01, T02, T03, T15, T19, T29 | Kế hoạch & quản lý dự án, Chương 1, môi trường Docker/khung ứng dụng, xác thực – phân quyền, menu & trang hệ thống/danh mục, CI, tổng hợp báo cáo |
| Đỗ Phạm Minh Trâm | 25540042 | Thành viên | T04, T05, T06, T07, T20, T25 | ERD, Class Diagram, lược đồ quan hệ – chuẩn hoá, DDL; trang Đào tạo; CSDL hướng đối tượng |
| Đỗ Bình Dương | 25540008 | Thành viên | T08, T09, T10, T18, T21, T27 | Dữ liệu mẫu, truy vấn SQL, XML, nhập/xuất dữ liệu; trang Học viên; NoSQL |
| Nguyễn Việt Phú | 25540025 | Thành viên | T11, T12, T13, T14, T22, T26 | Stored procedure, function, trigger, cursor; trang Học tập; CSDL phân tán |
| Nguyễn Bảo Giang | 25540009 | Thành viên | T16, T17, T23, T24, T28 | View, sao lưu – phục hồi; trang Tài chính, báo cáo & dashboard; Chương 4 |

### 6.4.2 Thống kê commit

Số liệu sinh bằng `python3 scripts/thong_ke_dong_gop.py` (không tính merge commit). "Dòng tự viết" bỏ qua file sinh tự động (dữ liệu mẫu `02_seed.sql`, CSV/XML/JSON trong `data/`, file `.drawio`, ảnh) – vì vậy cột "mọi file" của Dương lớn do script sinh dữ liệu mẫu được chạy lại nhiều lần.

*Bảng 6.3 – Thống kê đóng góp từ lịch sử git*

| Thành viên | Task phụ trách | Số commit | Tỷ lệ commit | Dòng thêm / xoá (mọi file) | Dòng tự viết | Tỷ lệ dòng tự viết |
|---|---|--:|--:|--:|--:|--:|
| Đỗ Phạm Minh Trâm | 6 (T04, T05, T06, T07, T20, T25) | 17 | 17% | +2.470 / −8 | 2.403 | 15% |
| Trương Quang Như | 6 (T01, T02, T03, T15, T19, T29) | 24 | 24% | +6.304 / −79 | 6.287 | 40% |
| Nguyễn Việt Phú | 6 (T11, T12, T13, T14, T22, T26) | 18 | 18% | +2.382 / −9 | 2.378 | 15% |
| Đỗ Bình Dương | 6 (T08, T09, T10, T18, T21, T27) | 26 | 25% | +73.293 / −44.443 | 2.883 | 18% |
| Nguyễn Bảo Giang | 5 (T16, T17, T23, T24, T28) | 17 | 17% | +1.679 / −6 | 1.657 | 11% |
| **Tổng** | 29 | 102 | 100% | | 15.608 | 100% |

*Số liệu tại thời điểm tổng hợp báo cáo (nhánh `t29-tong-hop-bao-cao`), chạy lại script để cập nhật.*

### 6.4.3 Đánh giá mức độ đóng góp

Mỗi thành viên phụ trách 5–6 task trải đủ các chương (thiết kế/CSDL, xử lý, giao diện, CSDL tiên tiến), nên phần đóng góp **tương đương nhau**; nhóm trưởng nhận thêm phần quản lý dự án, hạ tầng và tổng hợp.

| Thành viên | Mức độ đóng góp |
|---|:-:|
| Trương Quang Như | 20% |
| Đỗ Phạm Minh Trâm | 20% |
| Đỗ Bình Dương | 20% |
| Nguyễn Việt Phú | 20% |
| Nguyễn Bảo Giang | 20% |

## Tài liệu tham khảo

1. Slide bài giảng môn IE103 – Quản lý thông tin, Trường Đại học Công nghệ Thông tin – ĐHQG TP.HCM.
2. Microsoft, *SQL Server technical documentation* (T-SQL, XML Schema Collections, Row-Level Security, Backup and Restore). https://learn.microsoft.com/sql/
3. R. Elmasri, S. B. Navathe, *Fundamentals of Database Systems*, 7th ed., Pearson, 2016.
4. M. T. Özsu, P. Valduriez, *Principles of Distributed Database Systems*, 4th ed., Springer, 2020.
5. R. G. G. Cattell (ed.), *The Object Data Standard: ODMG 3.0*, Morgan Kaufmann, 2000.
6. MongoDB Inc., *MongoDB Manual* (Data Modeling, Aggregation Pipeline). https://www.mongodb.com/docs/manual/
7. Streamlit Inc., *Streamlit documentation*. https://docs.streamlit.io/
8. ReportLab, *ReportLab PDF Library User Guide*. https://docs.reportlab.com/
