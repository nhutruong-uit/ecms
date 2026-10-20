# Chương 6. Kết luận

Chương cuối tổng kết những gì nhóm đã làm được, đối chiếu với yêu cầu đặt ra ở Chương 1, trình bày kết quả kiểm thử tích hợp, những khó khăn gặp phải cùng cách khắc phục, các hạn chế còn tồn tại và hướng phát triển. Phần cuối chương trình bày phân công công việc và đánh giá mức độ đóng góp của từng thành viên.

## 6.1 Kết quả đạt được

Nhóm đã xây dựng hoàn chỉnh **ECMS** – hệ thống quản lý thông tin cho một chuỗi ba chi nhánh trung tâm tiếng Anh – đi qua đủ các giai đoạn của quy trình quản lý thông tin: thu thập, tổ chức, xử lý, trình bày và bảo vệ thông tin; đồng thời thử nghiệm ba mô hình CSDL tiên tiến trên chính dữ liệu của hệ thống. Sản phẩm của từng chương được tóm tắt dưới đây:

| Chương | Sản phẩm chính |
|---|---|
| 1. Tổng quan | Khảo sát quy trình nghiệp vụ bảy bước; đặc tả 6 tác nhân, 22 yêu cầu chức năng, 8 yêu cầu phi chức năng, 7 báo cáo; ánh xạ quy trình quản lý thông tin và mô hình DIKW; so sánh ba nhóm công cụ quản lý thông tin thực tế |
| 2. Tổ chức thông tin | ERD 14 thực thể và 22 mối kết hợp; sơ đồ lớp UML; 22 lược đồ quan hệ được kiểm tra dạng chuẩn, các điểm chưa chuẩn hoá đều có lý do và cơ chế bảo đảm nhất quán; 18 ràng buộc toàn vẹn kèm bảng tầm ảnh hưởng; script cài đặt 22 bảng với 32 khoá ngoại, 51 ràng buộc CHECK, 8 cột tính toán, 22 chỉ mục bổ sung; so sánh mô hình phẳng, quan hệ và XML; dữ liệu mẫu sinh theo nghiệp vụ gồm 349 học viên, 25 lớp, 539 đăng ký, hơn 10 nghìn lượt điểm danh |
| 3. Xử lý thông tin | 31 truy vấn SQL và 17 truy vấn XML có XML Schema; đo hiệu quả chỉ mục trên bảng một triệu dòng; 27 view gồm view bảo mật theo dòng, theo cột, indexed view và view có `WITH CHECK OPTION`; 38 procedure, 13 function, 11 trigger, cursor so sánh với xử lý theo tập hợp; xác thực với mật khẩu băm có salt, phân quyền 6 role theo nguyên tắc quyền tối thiểu, nhật ký kiểm toán; sao lưu Full, vi sai, nhật ký và diễn tập phục hồi theo thời điểm; nhập, xuất CSV, XML, JSON, Excel |
| 4. Trình bày thông tin | Ứng dụng web Streamlit có menu hai cấp theo vai trò, 20 trang chức năng, 2 form master – detail, 2 lưới nhập hàng loạt, 9 báo cáo PDF và Excel, dashboard KPI tương tác |
| 5. CSDL tiên tiến | Lược đồ ODL 18 lớp và mô hình đối tượng bằng Python; phân mảnh ngang, dọc, hỗn hợp cho ba trạm cùng lược đồ toàn cục; chuyển dữ liệu sang 4 collection MongoDB và 6 cặp truy vấn đối chiếu; bảng so sánh bốn mô hình |

### 6.1.1 Đối chiếu yêu cầu chức năng

Cả 22 yêu cầu chức năng từ FR01 đến FR22 đều đã được cài đặt; cột "Trình bày tại" của bảng ở mục 1.5.2 chỉ ra nơi mô tả cách đáp ứng từng yêu cầu. Điểm quan trọng là các quy tắc nghiệp vụ – lớp còn chỗ, khoá tiên quyết, không trùng phòng và giáo viên, không thu vượt học phí… – đều được đặt trong CSDL dưới dạng ràng buộc, procedure và trigger, nên không thể bị bỏ qua từ giao diện hay từ bất kỳ ứng dụng nào khác kết nối vào CSDL.

### 6.1.2 Đối chiếu yêu cầu phi chức năng

| Yêu cầu | Mức độ đáp ứng |
|---|---|
| NFR01 Toàn vẹn | Đạt. Ghi danh, chuyển lớp, thu phí, điểm danh cả lớp chạy trong giao dịch lồng được; 25 ca kiểm thử procedure và 17 ca kiểm thử trigger đều đạt |
| NFR02 Bảo mật | Đạt. Login của ứng dụng bị cấm trên mọi bảng, chỉ thực thi procedure và đọc view; 36 ca kiểm thử phân quyền đều đạt |
| NFR03 Truy vết | Đạt. Trigger ghi nhật ký dữ liệu trước và sau khi thay đổi, kèm tài khoản ứng dụng lấy từ ngữ cảnh phiên; bảng nhật ký chỉ cho phép thêm |
| NFR04 Sẵn sàng | Đạt. Lịch sao lưu bảo đảm RPO 15 phút, RTO dưới 30 phút; diễn tập phục hồi theo thời điểm thành công |
| NFR05 Hiệu năng | Đạt một phần. Mọi trang tải dưới 1 giây trên dữ liệu mẫu và các cột tra cứu đều có chỉ mục; nhưng chưa đo trên bảng học viên chính với 10.000 học viên – mới đo tốc độ nhập 10.000 dòng (mục 3.2.5) |
| NFR06 Tiếng Việt | Đạt. Bảng mã `Vietnamese_CI_AS`, chuỗi Unicode, báo cáo PDF dùng phông DejaVu hiển thị đúng dấu |
| NFR07 Dễ dùng | Đạt. Menu hai cấp, kiểm tra dữ liệu ngay tại trường, thông báo lỗi bằng tiếng Việt (Chương 4) |
| NFR08 Tái lập | Đạt. Một lệnh duy nhất dựng lại toàn bộ CSDL từ đầu trên cả macOS, Linux và Windows |

### 6.1.3 Kiểm thử tích hợp

Kiểm thử tích hợp chạy lại toàn bộ hệ thống từ **CSDL trống**: xoá CSDL ECMS, chạy lần lượt các script từ tạo bảng đến XML, chạy bốn bộ kiểm thử SQL, chạy bộ truy vấn và cuối cùng chạy kiểm thử giao diện. Kết quả trên SQL Server 2025 (Docker, macOS):

| Bước | Kết quả |
|---|---|
| Dựng CSDL: bảng, dữ liệu mẫu, function, view, procedure, trigger, cursor, phân quyền, XML | Thành công, khoảng 10 giây |
| Kiểm tra nhất quán dữ liệu mẫu (11 điều kiện) | Không có lỗi |
| Kiểm thử procedure, trigger, phân quyền | 25, 17 và 36 ca đều đạt |
| Bộ 31 truy vấn nghiệp vụ | Chạy hết, không có lỗi |
| Kiểm thử giao diện: mở mọi trang với từng vai trò và sinh mọi báo cáo PDF, Excel | 52 ca đạt |
| **Tổng thời gian** | Khoảng 35 giây |

Toàn bộ quy trình trên được tự động hoá bằng GitHub Actions trên SQL Server 2025 chạy trong Docker trên Linux, và là điều kiện bắt buộc trước khi hợp nhất mã nguồn vào nhánh phát hành cho phiên bản **v1.0.0**.

## 6.2 Khó khăn và cách khắc phục

Trong quá trình thực hiện, nhóm gặp một số khó khăn về môi trường và kỹ thuật. Các khó khăn tiêu biểu cùng cách khắc phục được ghi lại để làm kinh nghiệm:

| Khó khăn | Cách khắc phục |
|---|---|
| Thành viên dùng cả Windows và macOS, trong khi SQL Server không chạy trực tiếp trên macOS | Dùng SQL Server trong Docker cho macOS và Linux; viết script dựng CSDL cho cả shell và PowerShell; mã T-SQL chỉ dùng tính năng có trên cả hai bản 2022 và 2025 |
| Bản SQL Server 2022 cho Linux (các bản cập nhật CU24 đến CU27) báo lỗi Msg 17750 khi gọi `sp_executesql`, `sp_set_session_context`, `sp_xml_preparedocument` | Chuyển môi trường Docker và CI sang SQL Server 2025; vẫn cho phép đổi phiên bản bằng biến môi trường |
| Tuỳ chọn `CODEPAGE = '65001'` của `BULK INSERT` không có trên SQL Server for Linux, làm tệp CSV tiếng Việt bị lỗi phông | Khai báo các cột của bảng trung gian với bảng mã UTF-8 để đọc đúng trên mọi nền tảng |
| SQL Server không cho phép nhiều đường xoá lan truyền cùng tới bảng DIEMDANH | Để khoá ngoại tới BUOIHOC ở chế độ chặn xoá; procedure xoá điểm danh trước khi xoá buổi học |
| Không sửa được hàm `fn_TinhTuoi` khi chạy lại script vì hàm đang được ràng buộc CHECK tham chiếu | Script xoá ràng buộc trước, sửa hàm rồi tạo lại ràng buộc |
| Cơ chế khoá tài khoản sau 5 lần sai không có hiệu lực nếu `sp_DangNhap` ném lỗi, vì lệnh tăng số lần sai bị huỷ theo giao dịch | Trả kết quả qua tham số ra thay vì ném lỗi |
| Indexed view báo lỗi khi các phiên ghi vào bảng gốc không bật `QUOTED_IDENTIFIER` | Script dựng CSDL gọi `sqlcmd` với tuỳ chọn bật `QUOTED_IDENTIFIER` |
| Hàm tính lịch tuần cho kết quả khác nhau giữa SSMS và ứng dụng do cấu hình ngôn ngữ của phiên khác nhau | Tính ngày đầu tuần bằng số ngày kể từ một mốc thứ Hai cố định, không phụ thuộc `SET DATEFIRST` |
| Dữ liệu mẫu sinh ngẫu nhiên từng bảng dễ mâu thuẫn; thư viện Faker tiếng Việt đặt tên trước họ và kèm danh xưng | Viết chương trình mô phỏng nghiệp vụ theo trình tự thời gian với hạt giống cố định; tự ghép họ, tên lót, tên theo đúng thứ tự tiếng Việt |
| Trigger tính lại hoặc chặn các giá trị đã tính sẵn khi nạp dữ liệu mẫu | Tạm vô hiệu hoá trigger trong lúc nạp, nạp xong bật lại và chạy bộ kiểm tra nhất quán |

## 6.3 Hạn chế

1. **Quy mô dữ liệu nhỏ.** Dữ liệu mẫu có khoảng 350 học viên; hệ thống chưa được kiểm thử tải với hàng chục nghìn học viên và nhiều người dùng đồng thời.
2. **Giao diện.** Streamlit tải lại toàn trang sau mỗi tương tác, chưa tối ưu cho điện thoại; nút xoá chưa có hộp thoại xác nhận mà dựa vào khoá ngoại để chặn xoá dữ liệu đang được tham chiếu.
3. **Bảo mật khi triển khai.** Chưa có HTTPS và xác thực hai lớp; khung "Tài khoản demo" ở màn hình đăng nhập cần được gỡ bỏ khi chạy thật.
4. **CSDL phân tán** mới được mô phỏng bằng nhiều CSDL trên cùng một máy chủ, chưa có độ trễ mạng thật và chưa có giao tác phân tán giữa các máy.
5. **NoSQL** dừng ở bản sao một chiều từ SQL Server sang MongoDB, chưa đồng bộ liên tục.
6. **Kiểm thử tự động** mới chạy trên Linux; script dựng CSDL cho Windows chưa có quy trình kiểm thử tự động riêng.

## 6.4 Hướng phát triển

- Xây dựng cổng thông tin cho học viên và phụ huynh: đăng ký trực tuyến, thanh toán trực tuyến, nhận thông báo vắng học qua email hoặc Zalo – dữ liệu cảnh báo chuyên cần đã có sẵn trong CSDL.
- Tách giao diện thành REST API và ứng dụng web riêng để hỗ trợ thiết bị di động, giữ nguyên lớp procedure và view làm API nghiệp vụ.
- Triển khai kiến trúc nhiều loại CSDL như kết luận ở mục 5.4: Redis cho phiên đăng nhập và bộ nhớ đệm dashboard, MongoDB được đồng bộ bằng cơ chế ghi nhận thay đổi (Change Data Capture) cho cổng học viên.
- Khi mở rộng ra nhiều tỉnh, triển khai thiết kế phân mảnh ngang theo chi nhánh ở mục 5.2 trên các máy chủ thật, kết hợp nhóm sẵn sàng cao (Always On Availability Groups).
- Xây dựng kho dữ liệu và mô hình dự báo học viên có nguy cơ bỏ học dựa trên chuyên cần và điểm số – nâng hệ thống lên tầng **thông thái** của mô hình DIKW.

## 6.5 Bài học kinh nghiệm

Qua đồ án, nhóm rút ra một số bài học về quản lý thông tin và về cách làm việc nhóm:

- **Đặt quy tắc nghiệp vụ càng gần dữ liệu càng tốt.** Ràng buộc khai báo, procedure và trigger bảo vệ dữ liệu trước mọi nguồn thay đổi; giao diện chỉ nên kiểm tra để phản hồi nhanh cho người dùng chứ không phải là lớp bảo vệ duy nhất.
- **Chuẩn hoá là điểm xuất phát, không phải đích đến.** Mỗi chỗ phi chuẩn hoá đều cần một lý do cụ thể và một cơ chế bảo đảm nhất quán đi kèm.
- **Đo đạc thay vì phỏng đoán.** Các số liệu về chỉ mục, cursor, tốc độ nhập dữ liệu, OODB và NoSQL cho thấy nhiều khác biệt lớn hơn dự đoán ban đầu, từ hai lần tới hàng trăm lần.
- **Dữ liệu mẫu tốt là một nửa của kiểm thử.** Sinh dữ liệu theo nghiệp vụ, có sẵn trường hợp biên và kiểm tra nhất quán giúp phát hiện lỗi sớm và giúp cả nhóm cùng đối chiếu một kết quả.
- **Tự động hoá việc dựng lại và kiểm thử.** Nhờ chạy lại được toàn bộ hệ thống từ CSDL trống chỉ trong khoảng 35 giây, nhóm có thể thay đổi thiết kế đến tận giai đoạn cuối mà không sợ làm hỏng phần đã có.

## 6.6 Phân công và mức độ đóng góp

### 6.6.1 Phân công công việc

Dự án được chia thành 29 công việc trong bốn đợt. Mỗi công việc là một issue trên GitHub và được hoàn thành bằng một Pull Request vào nhánh tích hợp; kế hoạch chi tiết được công bố tại trang kế hoạch dự án (https://nhutruong-uit.github.io/ecms/) và bảng công việc GitHub Project. Mỗi thành viên phụ trách năm đến sáu công việc trải đều các chương:

| Thành viên | MSSV | Vai trò | Công việc phụ trách | Nội dung chính |
|---|:-:|---|---|---|
| Trương Quang Như | 25540022 | Nhóm trưởng | T01, T02, T03, T15, T19, T29 | Lập kế hoạch và quản lý dự án; Chương 1; môi trường Docker và khung ứng dụng; xác thực, phân quyền; menu và các trang hệ thống, danh mục; kiểm thử tự động; tổng hợp báo cáo |
| Đỗ Phạm Minh Trâm | 25540042 | Thành viên | T04, T05, T06, T07, T20, T25 | ERD, sơ đồ lớp, lược đồ quan hệ và chuẩn hoá, script tạo bảng; các trang Đào tạo; CSDL hướng đối tượng |
| Đỗ Bình Dương | 25540008 | Thành viên | T08, T09, T10, T18, T21, T27 | Dữ liệu mẫu, truy vấn SQL, XML, nhập và xuất dữ liệu; các trang Học viên; NoSQL |
| Nguyễn Việt Phú | 25540025 | Thành viên | T11, T12, T13, T14, T22, T26 | Stored procedure, function, trigger, cursor; các trang Học tập; CSDL phân tán |
| Nguyễn Bảo Giang | 25540009 | Thành viên | T16, T17, T23, T24, T28 | View, sao lưu và phục hồi; các trang Tài chính, báo cáo và dashboard; Chương 4 |

### 6.6.2 Thống kê từ lịch sử mã nguồn

Số liệu dưới đây được thống kê tự động từ lịch sử Git, không tính các commit hợp nhất nhánh. Cột "Dòng tự viết" bỏ qua các tệp sinh tự động như script dữ liệu mẫu, tệp CSV, XML, JSON trong thư mục dữ liệu, tệp draw.io và hình ảnh; vì vậy cột "Dòng thêm và xoá" của thành viên Dương lớn do chương trình sinh dữ liệu mẫu được chạy lại nhiều lần.

| Thành viên | Số công việc | Số commit | Tỷ lệ commit | Dòng thêm / xoá (mọi tệp) | Dòng tự viết | Tỷ lệ dòng tự viết |
|---|:-:|--:|--:|--:|--:|--:|
| Đỗ Phạm Minh Trâm | 6 | 17 | 17% | +2.470 / −8 | 2.403 | 15% |
| Trương Quang Như | 6 | 24 | 24% | +6.304 / −79 | 6.287 | 40% |
| Nguyễn Việt Phú | 6 | 18 | 18% | +2.382 / −9 | 2.378 | 15% |
| Đỗ Bình Dương | 6 | 26 | 25% | +73.293 / −44.443 | 2.883 | 18% |
| Nguyễn Bảo Giang | 5 | 17 | 17% | +1.679 / −6 | 1.657 | 11% |
| **Tổng** | **29** | **102** | **100%** | | **15.608** | **100%** |

Số liệu được ghi nhận tại thời điểm tổng hợp báo cáo. Tỷ lệ dòng mã của nhóm trưởng cao hơn vì phần này bao gồm cả hạ tầng dùng chung (khung ứng dụng, kiểm thử tự động, công cụ dựng báo cáo) phục vụ cả nhóm.

### 6.6.3 Đánh giá mức độ đóng góp

Mỗi thành viên phụ trách năm đến sáu công việc trải đủ các mảng thiết kế CSDL, xử lý thông tin, giao diện và CSDL tiên tiến, nên phần đóng góp của các thành viên là **tương đương nhau**; nhóm trưởng đảm nhận thêm phần quản lý dự án, hạ tầng và tổng hợp. Nhóm thống nhất đánh giá mức độ đóng góp như sau:

| Thành viên | Mức độ đóng góp |
|---|:-:|
| Trương Quang Như | 20% |
| Đỗ Phạm Minh Trâm | 20% |
| Đỗ Bình Dương | 20% |
| Nguyễn Việt Phú | 20% |
| Nguyễn Bảo Giang | 20% |

# Tài liệu tham khảo

1. Slide bài giảng môn IE103 – Quản lý thông tin, Trường Đại học Công nghệ Thông tin – ĐHQG TP.HCM.
2. Microsoft, *SQL Server technical documentation* (T-SQL, XML Schema Collections, Row-Level Security, Backup and Restore). https://learn.microsoft.com/sql/
3. R. Elmasri, S. B. Navathe, *Fundamentals of Database Systems*, 7th ed., Pearson, 2016.
4. M. T. Özsu, P. Valduriez, *Principles of Distributed Database Systems*, 4th ed., Springer, 2020.
5. R. G. G. Cattell (ed.), *The Object Data Standard: ODMG 3.0*, Morgan Kaufmann, 2000.
6. MongoDB Inc., *MongoDB Manual* (Data Modeling, Aggregation Pipeline). https://www.mongodb.com/docs/manual/
7. Streamlit Inc., *Streamlit documentation*. https://docs.streamlit.io/
8. ReportLab, *ReportLab PDF Library User Guide*. https://docs.reportlab.com/

# Phụ lục

## A. Cấu trúc mã nguồn

Toàn bộ mã nguồn của đồ án được công khai tại https://github.com/nhutruong-uit/ecms. Bảng dưới đây ánh xạ nội dung của báo cáo tới các tệp tương ứng trong kho mã để người đọc tiện đối chiếu.

| Nội dung | Mục trong báo cáo | Tệp, thư mục |
|---|---|---|
| Quy trình nghiệp vụ, ERD, sơ đồ lớp, cây chức năng | 1.2, 2.1, 2.3, 4.1 | `docs/design/` |
| Lược đồ quan hệ, phụ thuộc hàm, lược đồ ODL | 2.4, 5.1 | `docs/design/relational-schema.md`, `docs/design/odl-schema.md` |
| Tạo CSDL, bảng, ràng buộc, chỉ mục | 2.7 | `database/01_schema.sql` |
| Dữ liệu mẫu và chương trình sinh dữ liệu | 2.8 | `database/02_seed.sql`, `scripts/gen_seed.py` |
| Function | 3.3.2 | `database/03_functions.sql` |
| View | 3.2.3 | `database/04_views.sql` |
| Stored procedure | 3.3.1 | `database/05_procedures.sql` |
| Trigger | 3.3.3 | `database/06_triggers.sql` |
| Cursor | 3.3.4 | `database/07_cursors.sql` |
| Xác thực và phân quyền | 3.2.1, 3.2.2 | `database/08_security.sql` |
| XML Schema và truy vấn XML | 3.1.3 | `database/09_xml.sql` |
| Truy vấn nghiệp vụ và đo hiệu năng | 3.1.1, 3.1.2 | `database/10_queries.sql` |
| Sao lưu và phục hồi | 3.2.4 | `database/11_backup_restore.sql`, `scripts/backup.sh` |
| Nhập và xuất dữ liệu | 3.2.5 | `database/12_import_export.sql`, `scripts/import_export.py`, `data/` |
| CSDL phân tán | 5.2 | `database/13_distributed.sql` |
| Bộ kiểm thử SQL | 2.8.4, 3.2.2, 3.3 | `database/tests/` |
| Ứng dụng web | Chương 4 | `app/` |
| Bộ dựng báo cáo PDF, Excel | 4.3 | `app/reports/` |
| CSDL hướng đối tượng | 5.1.3 | `oodb/` |
| NoSQL MongoDB | 5.3 | `nosql/` |
| Kiểm thử giao diện và kiểm thử tự động | 6.1.3 | `tests/`, `.github/workflows/ci.yml` |

## B. Hướng dẫn chạy lại hệ thống

Cách cài đặt, khởi động và sử dụng hệ thống được trình bày chi tiết trong tài liệu *Hướng dẫn sử dụng ECMS* đi kèm báo cáo. Tóm tắt các lệnh chính trên macOS hoặc Linux:

```bash title="Dựng CSDL và chạy ứng dụng"
docker compose up -d                 # khởi động SQL Server
database/run_all.sh                  # dựng CSDL ECMS từ đầu
pip install -r requirements.txt
streamlit run app/main.py            # mở http://localhost:8501
```
