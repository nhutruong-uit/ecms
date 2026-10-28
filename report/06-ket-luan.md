# Chương 6. Kết luận

Chương cuối tổng kết những gì nhóm đã làm được, đối chiếu với yêu cầu đặt ra ở Chương 1, trình bày kết quả kiểm thử tích hợp, những khó khăn gặp phải cùng cách khắc phục, các hạn chế còn tồn tại và hướng phát triển. Phần cuối chương trình bày phân công công việc và đánh giá mức độ đóng góp của từng thành viên.

## 6.1 Kết quả đạt được

Nhóm đã xây dựng hoàn chỉnh **ECMS** – hệ thống quản lý thông tin cho một chuỗi ba chi nhánh trung tâm tiếng Anh – đi qua đủ năm giai đoạn của quy trình quản lý thông tin: thu thập, tổ chức, chuyển đổi, trình bày và an toàn thông tin; đồng thời thử nghiệm ba mô hình CSDL tiên tiến trên chính dữ liệu của hệ thống. Sản phẩm của từng chương được tóm tắt dưới đây:

*Bảng 6.1 – Sản phẩm chính của từng chương*

| Chương | Sản phẩm chính |
|---|---|
| 1. Tổng quan | Khảo sát quy trình nghiệp vụ bảy bước; đặc tả 6 tác nhân, 22 yêu cầu chức năng, 8 yêu cầu phi chức năng, 7 báo cáo; phân biệt dữ liệu – thông tin – tri thức, tri thức hiện và tri thức ẩn; tháp DIKW minh hoạ bằng số liệu chuyên cần thật; ánh xạ quy trình năm giai đoạn quản lý thông tin; so sánh ba nhóm công cụ quản lý thông tin thực tế |
| 2. Tổ chức thông tin | ERD 14 thực thể; sơ đồ lớp UML; 22 lược đồ quan hệ được phân tích phụ thuộc hàm và dạng chuẩn, các chỗ chưa đạt BCNF được chỉ rõ cùng lý do và cơ chế giữ nhất quán; đặc tả ràng buộc toàn vẹn kèm bảng tầm ảnh hưởng; script cài đặt 22 bảng với 33 khoá ngoại, 53 ràng buộc CHECK, 8 cột tính toán, 23 chỉ mục bổ sung; so sánh mô hình phẳng, mô hình có cấu trúc, quan hệ và XML; dữ liệu mẫu sinh theo nghiệp vụ gồm 349 học viên, 25 lớp, 539 đăng ký, hơn 10 nghìn lượt điểm danh |
| 3. Xử lý thông tin | 31 truy vấn SQL và 18 truy vấn XML có XML Schema, đo hiệu quả của chỉ mục thường và chỉ mục XML; 27 view gồm view bảo mật theo dòng, theo cột, indexed view và view có `WITH CHECK OPTION`; 41 procedure, 17 function, 14 trigger, cursor so sánh công bằng với xử lý theo tập hợp; xác thực với mật khẩu băm lặp có salt, danh tính người dùng không giả mạo được, phân quyền 6 role theo nguyên tắc quyền tối thiểu; mã hoá đường truyền, TDE, mã hoá cột, che dữ liệu, nhật ký kiểm toán bằng trigger, SQL Server Audit và ledger; sao lưu Full, vi sai, nhật ký, sao lưu mã hoá, lịch SQL Server Agent và diễn tập phục hồi theo thời điểm; nhập, xuất CSV, XML, JSON, Excel qua quy trình làm sạch 12 quy tắc |
| 4. Trình bày thông tin | Ứng dụng web Streamlit có menu hai cấp theo vai trò, 20 trang chức năng, 2 form master – detail, 2 lưới nhập hàng loạt, hộp thoại xác nhận khi xoá; 7 báo cáo xuất được PDF, Excel và Word có dòng thống kê và tô màu có điều kiện; phiếu thu in PDF khổ A5; dashboard KPI tương tác |
| 5. CSDL tiên tiến | Lược đồ ODL 16 lớp, 1 interface và mô hình đối tượng bằng Python có OID, identity map, đối tượng bền; so sánh ba chiến lược ánh xạ kế thừa; phân mảnh ngang, dọc, hỗn hợp cho ba trạm theo kiến trúc ba lược đồ, nhân bản, nửa kết, cam kết hai pha và tình huống trạm gặp sự cố; chuyển 14 bảng sang 4 collection MongoDB, đối chiếu 6 truy vấn đọc và 3 thao tác ghi; bảng so sánh bốn mô hình |

### 6.1.1 Đối chiếu yêu cầu chức năng

Cả 22 yêu cầu chức năng từ FR01 đến FR22 đều đã được cài đặt; cột "Trình bày tại" của bảng ở mục 1.5.2 chỉ ra nơi mô tả cách đáp ứng từng yêu cầu. Điểm quan trọng là các quy tắc nghiệp vụ – lớp còn chỗ, khoá tiên quyết, không trùng phòng và giáo viên, không thu vượt học phí… – đều được đặt trong CSDL dưới dạng ràng buộc, procedure và trigger, nên không thể bị bỏ qua từ giao diện hay từ bất kỳ ứng dụng nào khác kết nối vào CSDL.

Ở giai đoạn cuối, nhóm rà soát lại toàn bộ đồ án theo nội dung bài giảng và kiểm thử theo hướng "người dùng cố tình làm sai". Các yêu cầu chức năng được củng cố như sau:

*Bảng 6.2 – Yêu cầu chức năng được củng cố trong đợt rà soát cuối*

| Yêu cầu | Điểm được củng cố | Cơ chế |
|---|---|---|
| FR01 | Mật khẩu băm lặp 10.000 vòng; sai 5 lần thì **tạm khoá 15 phút** thay vì khoá vĩnh viễn, nên người khác không thể cố ý khoá tài khoản; thông báo lỗi không tiết lộ tài khoản có tồn tại hay không; tài khoản bị khoá hoặc đổi vai trò bị đăng xuất ở lần tải trang kế tiếp | `fn_BamMatKhau`, `sp_DangNhap`, cột `TAIKHOAN.KhoaDen`; ứng dụng kiểm tra lại phiên |
| FR02, FR05, FR14 | Giáo vụ, kế toán của một chi nhánh chỉ thao tác và xem được dữ liệu của chi nhánh mình | `fn_TrongPhamVi`, lỗi 50097 |
| FR03 | Không đổi được chức vụ của giáo viên đã có bảng lương hoặc buổi dạy; bảng lương không còn bị xoá dây chuyền | `sp_LuuNhanVien` (lỗi 50132), khoá ngoại BANGLUONG không `CASCADE` |
| FR05 | Lớp tự chuyển từ "Sắp mở" sang "Đang học" khi tới ngày khai giảng | `sp_CapNhatTrangThaiLop` |
| FR06 | Hai lần xếp lịch đồng thời không lấy trùng phòng; không sửa lịch của lớp đã điểm danh | `sp_getapplock`, lỗi 50027 |
| FR12 | Bấm "Lập phiếu thu" hai lần không tạo hai phiếu; ký tự đặc biệt trong họ tên, ghi chú không làm hỏng bản in | Cột `PHIEUTHU.MaYeuCau` có chỉ mục duy nhất; escape dữ liệu trước khi dựng PDF |
| FR16 | Xoá ô điểm trên lưới thì điểm cũ được xoá thật thay vì giữ nguyên | `sp_NhapDiem` phân biệt "không gửi" với "gửi rỗng" bằng `JSON_PATH_EXISTS` |
| FR19 | Mọi báo cáo xuất được cả PDF, Excel và **Word**; tệp có dòng thống kê và tô màu có điều kiện như trên màn hình | `app/reports/bao_cao.py` |
| FR20 | Ngoài trigger, bổ sung SQL Server Audit ghi cả thao tác đọc và bảng ledger chống sửa – chạy thử trên CSDL demo | `database/14_encryption_audit.sql` |
| FR21 | Vai trò tài khoản suy ra từ chức vụ; đặt lại mật khẩu đồng thời gỡ tạm khoá | `fn_VaiTroTheoChucVu`, `sp_CapNhatTaiKhoan` |
| Mọi trang danh mục | Hỏi xác nhận trước khi xoá | Hộp thoại xác nhận của ứng dụng |

### 6.1.2 Đối chiếu yêu cầu phi chức năng

*Bảng 6.3 – Mức độ đáp ứng các yêu cầu phi chức năng*

| Yêu cầu | Mức độ đáp ứng |
|---|---|
| NFR01 Toàn vẹn | Đạt. Ghi danh, chuyển lớp, thu phí, điểm danh cả lớp chạy trong giao dịch lồng được: procedure tự mở giao dịch thì bật `XACT_ABORT`, được gọi trong giao dịch của người gọi thì dùng điểm lưu (savepoint); tranh chấp được tuần tự hoá bằng `UPDLOCK, HOLDLOCK` và `sp_getapplock`; 39 ca kiểm thử procedure và 22 ca kiểm thử trigger đều đạt |
| NFR02 Bảo mật | Đạt. Login của ứng dụng bị cấm trên mọi bảng, chỉ thực thi procedure và đọc view; danh tính người dùng được ghi vào ngữ cảnh phiên ở chế độ chỉ đọc nên mã bị chèn cũng không đổi được, và quyền được kiểm tra theo kiểu "thiếu thông tin thì từ chối"; kết nối được mã hoá TLS; 53 ca kiểm thử phân quyền đều đạt. TDE, mã hoá cột và che dữ liệu đã chạy thử trên CSDL demo |
| NFR03 Truy vết | Đạt. Sáu trigger ghi nhật ký dữ liệu trước và sau khi thay đổi kèm tài khoản ứng dụng lấy từ ngữ cảnh phiên; bảng nhật ký chỉ cho phép thêm; SQL Server Audit và ledger (lỗi 37359, 13545 khi cố sửa) đã chạy thử trên CSDL demo |
| NFR04 Sẵn sàng | Đạt. Lịch sao lưu Full hằng tuần, vi sai hằng ngày, nhật ký 15 phút bảo đảm RPO 15 phút; diễn tập phục hồi Full + vi sai + nhật ký tới một thời điểm mất 607 – 810 ms trên CSDL mẫu (Docker trên macOS và SQL Server cài trên Windows) (bản sao lưu nén khoảng 2 MB), xa dưới mức RTO 1 giờ; `DBCC CHECKDB` sau phục hồi không có lỗi |
| NFR05 Hiệu năng | Đạt với các thao tác tra cứu. Đo trên bản sao 10.121 học viên, mọi thao tác tra cứu chính đều dưới 150 ms (Bảng 6.4); 125 ca kiểm thử giao diện mở mọi trang với mọi vai trò trên dữ liệu mẫu chạy hết trong khoảng 30 giây. Chưa kiểm thử tải với nhiều người dùng đồng thời |
| NFR06 Tiếng Việt | Đạt. Bảng mã `Vietnamese_CI_AS`, chuỗi Unicode; báo cáo PDF dùng phông DejaVu, tệp Excel và Word hiển thị đúng dấu |
| NFR07 Dễ dùng | Đạt. Menu hai cấp, kiểm tra dữ liệu ngay tại trường, hỏi xác nhận trước khi xoá, thông báo lỗi bằng tiếng Việt (Chương 4) |
| NFR08 Tái lập | Đạt. Một lệnh duy nhất dựng lại toàn bộ CSDL từ đầu (`run_all.sh` trên macOS, Linux; `run_all.ps1` trên Windows); container chỉ báo sẵn sàng khi SQL Server đổi xong bảng mã, nên lệnh dựng không còn chạy quá sớm |

Để kiểm chứng NFR05 mà không làm thay đổi CSDL, nhóm nhân bản dữ liệu mẫu 29 lần vào bảng tạm (10.121 học viên, 15.631 đăng ký, 14.732 dòng chi tiết phiếu thu) với cùng các chỉ mục như bảng thật, rồi chạy mỗi thao tác 11 lần trên SQL Server 2025 trong Docker, bỏ lần đầu:

*Bảng 6.4 – Thời gian tra cứu với 10.121 học viên (SQL Server 2025)*

| Thao tác | Số dòng kết quả | Trung vị | Chậm nhất |
|---|--:|--:|--:|
| Tìm theo từ khoá "Nguyễn" trên họ tên, mã, số điện thoại, email; trang đầu 20 dòng kèm công nợ – như `sp_TimKiemHocVien` | 1.015 | 66 ms | 75 ms |
| Lọc học viên còn nợ, tính công nợ của cả 10.121 học viên | 1.682 | 77 ms | 131 ms |
| Lịch học trong tuần của một học viên – như `fn_LichHocHocVien` | 4 | 2 ms | 5 ms |

### 6.1.3 Kiểm thử tích hợp

Kiểm thử tích hợp chạy lại toàn bộ hệ thống từ **CSDL trống**: khởi động SQL Server, chạy lần lượt các script từ tạo bảng đến XML, chạy bốn bộ kiểm thử SQL, chạy bộ truy vấn và cuối cùng chạy kiểm thử giao diện. Kết quả trên SQL Server 2025 (Docker, macOS):

*Bảng 6.5 – Kết quả kiểm thử tích hợp từ CSDL trống*

| Bước | Kết quả |
|---|---|
| Khởi động SQL Server; healthcheck chờ đổi bảng mã máy chủ xong | Sẵn sàng sau khoảng 16 giây |
| Dựng CSDL: bảng, dữ liệu mẫu, function, view, procedure, trigger, cursor, phân quyền, XML | Thành công, khoảng 18 – 20 giây; phần lớn thời gian dành cho băm mật khẩu 10.000 vòng của 80 tài khoản mẫu |
| Kiểm tra nhất quán dữ liệu mẫu (11 điều kiện) | Không có lỗi |
| Kiểm thử procedure, trigger, phân quyền | 39, 22 và 53 ca đều đạt |
| Bộ 31 truy vấn nghiệp vụ | Chạy hết trong khoảng 4 giây, không có lỗi |
| Kiểm thử giao diện và báo cáo: mở mọi trang với từng vai trò, vai trò bị chặn, phạm vi chi nhánh, kiểm tra lại phiên, CSDL từ chối khi thiếu ngữ cảnh, sinh tệp PDF, Excel, Word | 125 ca đạt, khoảng 30 giây |
| **Tổng thời gian** | Khoảng 1 – 2 phút |

Toàn bộ quy trình trên được tự động hoá bằng GitHub Actions (`.github/workflows/ci.yml`) trên SQL Server 2025 chạy trong Docker trên Linux. CI chạy khi có Pull Request hoặc push vào nhánh `main` và khi gắn tag phát hành; nhánh tích hợp `develop` không chạy CI để tiết kiệm thời gian. Ở các lần chạy trước, CI thỉnh thoảng thất bại vì healthcheck `SELECT 1` báo sẵn sàng trong lúc SQL Server còn đổi bảng mã sang `Vietnamese_CI_AS`; healthcheck mới (`database/healthcheck.sql`) chỉ báo sẵn sàng khi nhật ký lỗi của SQL Server ghi nhận việc đổi bảng mã đã xong, nên bước dựng CSDL không còn chạy quá sớm. Lần chạy CI của bản phát hành còn lộ thêm một nguyên nhân thứ hai: SQL Server Agent khởi động song song và bật tuỳ chọn *Agent XPs* đúng lúc đang dựng lại chỉ mục của `master`, hai tiến trình tranh chấp khoá (Msg 1205) làm việc đổi bảng mã thất bại (Msg 3434). Từ đó Agent được tắt ở lần khởi động đầu và chỉ bật khi cần lịch sao lưu. Sau bản phát hành, CI còn lộ nguyên nhân thứ ba: chính kết nối của healthcheck tới SQL Server trong lúc đổi bảng mã cũng tranh chấp khoá với việc dựng lại chỉ mục của `master` (Msg 1205 rồi Msg 3434). Healthcheck vì vậy được tách thành `database/healthcheck.sh`: đọc trực tiếp tệp nhật ký lỗi của SQL Server và chỉ kết nối để chạy `healthcheck.sql` khi việc đổi bảng mã đã xong, hoặc đã qua 10 giây kể từ lúc máy chủ sẵn sàng mà không có lần đổi nào. Theo quy ước của nhóm (`CONTRIBUTING.md`), Pull Request từ `develop` vào `main` chỉ được hợp nhất khi CI xanh; tuy nhiên nhánh `main` chưa bật branch protection nên quy ước này chưa được GitHub cưỡng chế.

## 6.2 Khó khăn và cách khắc phục

Trong quá trình thực hiện, nhóm gặp một số khó khăn về môi trường và kỹ thuật. Các khó khăn tiêu biểu cùng cách khắc phục được ghi lại để làm kinh nghiệm:

*Bảng 6.6 – Khó khăn kỹ thuật và cách khắc phục*

| Khó khăn | Cách khắc phục |
|---|---|
| Thành viên dùng cả Windows và macOS, trong khi SQL Server không chạy trực tiếp trên macOS | Dùng SQL Server trong Docker cho macOS và Linux; viết script dựng CSDL cho cả shell và PowerShell; mã T-SQL chỉ dùng tính năng có trên cả hai bản 2022 và 2025 |
| Bản SQL Server 2022 cho Linux (các bản cập nhật CU24 đến CU27) báo lỗi Msg 17750 khi gọi `sp_executesql`, `sp_set_session_context`, `sp_xml_preparedocument` | Chuyển môi trường Docker và CI sang SQL Server 2025; vẫn cho phép đổi phiên bản bằng biến môi trường |
| Container báo sẵn sàng khi SQL Server còn đang đổi bảng mã máy chủ; dựng CSDL đúng lúc đó (indexed view, filtered index) làm máy chủ tự tắt và CI thất bại ngẫu nhiên | Healthcheck đọc nhật ký lỗi, chỉ báo sẵn sàng khi việc đổi bảng mã hoàn tất; `run_all` tự chờ máy chủ sẵn sàng; SQL Server Agent tắt ở lần khởi động đầu vì Agent bật *Agent XPs* giữa lúc đổi bảng mã gây tranh chấp khoá (Msg 1205) |
| Kết nối dùng chung (connection pooling) của ODBC giữ lại ngữ cảnh phiên chỉ đọc của người dùng trước, khiến phiên sau không đặt được danh tính của mình | Mỗi phiên làm việc của ứng dụng giữ một kết nối riêng, tắt pooling; chi phí mở kết nối khoảng 135 ms chỉ phát sinh một lần cho mỗi phiên |
| Tuỳ chọn `CODEPAGE = '65001'` của `BULK INSERT` không có trên SQL Server for Linux, làm tệp CSV tiếng Việt bị lỗi phông | Khai báo các cột của bảng trung gian với bảng mã UTF-8 để đọc đúng trên mọi nền tảng |
| Ký tự xuống dòng kiểu Windows (CR) ở cuối dòng CSV làm cột ngày không chuyển kiểu được và bị thay ngầm bằng ngày hiện tại | Loại bỏ `CHAR(13)` trước khi chuyển kiểu; thêm quy tắc báo lỗi khi ngày sai định dạng, chỉ ô để trống mới nhận ngày hiện tại |
| Một số lỗi như CSDL đang offline (942) hay ghi vào bảng ledger (37359) phát sinh lúc biên dịch nên `TRY…CATCH` cùng cấp không bắt được | Chạy câu lệnh qua `sp_executesql` để lỗi xảy ra ở cấp con và được bắt |
| SQL Server không cho phép nhiều đường xoá lan truyền cùng tới bảng DIEMDANH | Để khoá ngoại tới BUOIHOC ở chế độ chặn xoá; procedure xoá điểm danh trước khi xoá buổi học |
| Không sửa được hàm `fn_TinhTuoi` khi chạy lại script vì hàm đang được ràng buộc CHECK tham chiếu | Script xoá ràng buộc trước, sửa hàm rồi tạo lại ràng buộc |
| Cơ chế đếm số lần sai mật khẩu không có hiệu lực nếu `sp_DangNhap`, `sp_DoiMatKhau` ném lỗi, vì lệnh tăng số lần sai bị huỷ theo giao dịch | Trả kết quả qua tham số ra thay vì ném lỗi |
| Indexed view báo lỗi khi các phiên ghi vào bảng gốc không bật `QUOTED_IDENTIFIER` | Script dựng CSDL gọi `sqlcmd` với tuỳ chọn bật `QUOTED_IDENTIFIER` |
| Hàm tính lịch tuần cho kết quả khác nhau giữa SSMS và ứng dụng do cấu hình ngôn ngữ của phiên khác nhau | Tính ngày đầu tuần bằng số ngày kể từ một mốc thứ Hai cố định, không phụ thuộc `SET DATEFIRST` |
| Dữ liệu mẫu sinh ngẫu nhiên từng bảng dễ mâu thuẫn; thư viện Faker tiếng Việt đặt tên trước họ và kèm danh xưng | Viết chương trình mô phỏng nghiệp vụ theo trình tự thời gian với hạt giống cố định; tự ghép họ, tên lót, tên theo đúng thứ tự tiếng Việt |
| Trigger tính lại hoặc chặn các giá trị đã tính sẵn khi nạp dữ liệu mẫu | Tạm vô hiệu hoá trigger trong lúc nạp, nạp xong bật lại và chạy bộ kiểm tra nhất quán |

## 6.3 Hạn chế

1. **Quy mô và tải.** Dữ liệu mẫu có khoảng 350 học viên; thao tác tra cứu đã được đo trên bản sao 10.121 học viên, nhưng hệ thống chưa được kiểm thử tải với nhiều người dùng đồng thời.
2. **Giao diện.** Streamlit tải lại toàn trang sau mỗi tương tác, chưa tối ưu cho điện thoại và không hỗ trợ phím tắt tuỳ biến cho các thao tác nhập liệu lặp lại.
3. **Bảo mật khi triển khai.** Ứng dụng web chưa chạy HTTPS và chưa có xác thực hai lớp. Kết nối tới CSDL đã mã hoá TLS nhưng máy phát triển tin chứng chỉ tự ký. TDE, mã hoá cột, che dữ liệu, SQL Server Audit và ledger mới được chạy thử trên CSDL demo, chưa bật trên CSDL ECMS chính.
4. **CSDL phân tán** phần lớn mới được mô phỏng bằng nhiều CSDL trên cùng một máy chủ. Giao tác phân tán qua MSDTC đã chạy thật giữa hai máy (Windows và macOS cùng mạng Wi-Fi), nhưng chỉ cho kịch bản chuyển lớp; phân mảnh, nửa kết và truy vấn toàn cục chưa đo trên mạng thật. Lược đồ toàn cục chưa chịu được sự cố của một trạm.
5. **NoSQL** dừng ở bản sao một chiều từ SQL Server sang MongoDB, chưa đồng bộ liên tục.
6. **Kiểm thử tự động và quy trình.** CI chạy trên Linux và chỉ cho nhánh `main`; nhánh `main` chưa bật branch protection. Script dựng CSDL cho Windows, các tính năng chỉ có trên Windows (MSDTC, SQL Server Agent trên bản không phải Express, TDE trên bản Developer trở lên) và việc chụp ảnh màn hình minh hoạ được kiểm tra thủ công trên máy Windows có SQL Server và SSMS.

## 6.4 Hướng phát triển

- Xây dựng cổng thông tin cho học viên và phụ huynh: đăng ký trực tuyến, thanh toán trực tuyến, nhận thông báo vắng học qua email hoặc Zalo – dữ liệu cảnh báo chuyên cần đã có sẵn trong CSDL.
- Tách giao diện thành REST API và ứng dụng web riêng để hỗ trợ thiết bị di động và phím tắt, giữ nguyên lớp procedure và view làm API nghiệp vụ.
- Bật TDE, SQL Server Audit và chứng chỉ TLS do CA cấp trên máy chủ thật; chuyển bảng nhật ký sang ledger để chống sửa nhật ký.
- Triển khai kiến trúc nhiều loại CSDL như kết luận ở mục 5.4: Redis cho phiên đăng nhập và bộ nhớ đệm dashboard, MongoDB được đồng bộ bằng cơ chế ghi nhận thay đổi (Change Data Capture) cho cổng học viên.
- Khi mở rộng ra nhiều tỉnh, triển khai thiết kế phân mảnh ngang theo chi nhánh ở mục 5.2 trên các máy chủ thật, nhân bản mỗi mảnh bằng Always On Availability Groups để lược đồ toàn cục chịu được sự cố trạm.
- Bật branch protection cho `main`, chạy CI cả trên Windows và trên nhánh `develop`, bổ sung kiểm thử tải.
- Xây dựng kho dữ liệu và mô hình dự báo học viên có nguy cơ bỏ học dựa trên chuyên cần và điểm số – nâng hệ thống lên tầng **trí tuệ** của mô hình DIKW.

## 6.5 Bài học kinh nghiệm

Qua đồ án, nhóm rút ra một số bài học về quản lý thông tin và về cách làm việc nhóm:

- **Đặt quy tắc nghiệp vụ càng gần dữ liệu càng tốt.** Ràng buộc khai báo, procedure và trigger bảo vệ dữ liệu trước mọi nguồn thay đổi; giao diện chỉ nên kiểm tra để phản hồi nhanh cho người dùng chứ không phải là lớp bảo vệ duy nhất.
- **Không tin bất cứ điều gì đến từ phía ứng dụng.** Danh tính người dùng, vai trò và chi nhánh phải được CSDL tự xác lập và khoá lại; mọi kiểm tra quyền phải từ chối khi thiếu thông tin thay vì cho qua.
- **Chuẩn hoá là điểm xuất phát, không phải đích đến.** Mỗi chỗ phi chuẩn hoá đều cần một lý do cụ thể và một cơ chế bảo đảm nhất quán đi kèm.
- **Đo đạc thay vì phỏng đoán.** Các số liệu về chỉ mục, cursor, tốc độ nhập dữ liệu, OODB, CSDL phân tán và NoSQL cho thấy nhiều khác biệt lớn hơn dự đoán ban đầu, từ hai lần tới hàng chục lần; phép đo phải so sánh công bằng và ghi kèm độ dao động.
- **Dữ liệu mẫu tốt là một nửa của kiểm thử.** Sinh dữ liệu theo nghiệp vụ, có sẵn trường hợp biên và kiểm tra nhất quán giúp phát hiện lỗi sớm và giúp cả nhóm cùng đối chiếu một kết quả.
- **Tự động hoá việc dựng lại và kiểm thử.** Nhờ chạy lại được toàn bộ hệ thống từ CSDL trống chỉ trong một đến hai phút, nhóm có thể sửa thiết kế đến tận giai đoạn rà soát cuối mà không sợ làm hỏng phần đã có.

## 6.6 Phân công và mức độ đóng góp

### 6.6.1 Phân công công việc

Dự án được chia thành 30 công việc trong bốn đợt. Mỗi công việc là một issue trên GitHub và được hoàn thành bằng một Pull Request vào nhánh tích hợp; kế hoạch chi tiết được công bố tại trang kế hoạch dự án (https://nhutruong-uit.github.io/ecms/) và bảng công việc GitHub Project. Mỗi thành viên phụ trách năm đến bảy công việc trải đều các chương:

*Bảng 6.7 – Phân công công việc*

| Thành viên | MSSV | Vai trò | Công việc phụ trách | Nội dung chính |
|---|:-:|---|---|---|
| Trương Quang Như | 25540022 | Nhóm trưởng | T01, T02, T03, T15, T19, T29, T30 | Lập kế hoạch và quản lý dự án; Chương 1; môi trường Docker và khung ứng dụng; xác thực, phân quyền; menu và các trang hệ thống, danh mục; kiểm thử tự động; tổng hợp báo cáo; khắc phục sau rà soát |
| Đỗ Phạm Minh Trâm | 25540042 | Thành viên | T04, T05, T06, T07, T20, T25 | ERD, sơ đồ lớp, lược đồ quan hệ và chuẩn hoá, script tạo bảng; các trang Đào tạo; CSDL hướng đối tượng |
| Đỗ Bình Dương | 25540008 | Thành viên | T08, T09, T10, T18, T21, T27 | Dữ liệu mẫu, truy vấn SQL, XML, nhập và xuất dữ liệu; các trang Học viên; NoSQL |
| Nguyễn Việt Phú | 25540025 | Thành viên | T11, T12, T13, T14, T22, T26 | Stored procedure, function, trigger, cursor; các trang Học tập; CSDL phân tán |
| Nguyễn Bảo Giang | 25540009 | Thành viên | T16, T17, T23, T24, T28 | View, sao lưu và phục hồi; các trang Tài chính, báo cáo và dashboard; Chương 4 |

### 6.6.2 Thống kê từ lịch sử mã nguồn

Số liệu dưới đây được thống kê tự động bằng `scripts/thong_ke_dong_gop.py` từ lịch sử Git, không tính các commit hợp nhất nhánh. Cột "Dòng tự viết" bỏ qua các tệp sinh tự động như script dữ liệu mẫu, tệp CSV, XML, JSON trong thư mục dữ liệu, tệp draw.io và hình ảnh; vì vậy cột "Dòng thêm và xoá" của thành viên Dương lớn do chương trình sinh dữ liệu mẫu được chạy lại nhiều lần.

*Bảng 6.8 – Thống kê đóng góp từ lịch sử Git*

| Thành viên | Số công việc | Số commit | Tỷ lệ commit | Dòng thêm / xoá (mọi tệp) | Dòng tự viết | Tỷ lệ dòng tự viết |
|---|:-:|--:|--:|--:|--:|--:|
| Đỗ Phạm Minh Trâm | 6 | 17 | 12% | +2.470 / −8 | 2.403 | 9% |
| Trương Quang Như | 7 | 63 | 45% | +16.439 / −3.751 | 16.416 | 64% |
| Nguyễn Việt Phú | 6 | 18 | 13% | +2.382 / −9 | 2.378 | 9% |
| Đỗ Bình Dương | 6 | 26 | 18% | +73.293 / −44.443 | 2.883 | 11% |
| Nguyễn Bảo Giang | 5 | 17 | 12% | +1.679 / −6 | 1.657 | 6% |
| **Tổng** | **30** | **141** | **100%** | | **25.737** | **100%** |

Số liệu được tạo lại khi phát hành bản v1.0.0, tính trên nhánh `develop` tại commit `5564f37` – mã nguồn của bản phát hành, sau khi gộp toàn bộ 30 công việc – gồm 141 commit; không tính các commit hợp nhất nhánh và commit cập nhật chính bảng này.

### 6.6.3 Đánh giá mức độ đóng góp

Về **phân công**, mỗi thành viên phụ trách năm đến bảy công việc trải đủ các mảng thiết kế CSDL, xử lý thông tin, giao diện và CSDL tiên tiến, và đều hoàn thành phần việc được giao. Về **khối lượng mã nguồn**, đóng góp không đồng đều: nhóm trưởng chiếm 45% số commit và 64% số dòng tự viết, vì ngoài phần việc như các thành viên khác còn đảm nhận hạ tầng dùng chung (Docker, khung ứng dụng, kiểm thử tự động, công cụ dựng báo cáo) và toàn bộ đợt khắc phục sau rà soát (T30) ở giai đoạn cuối. Số dòng mã cũng không phản ánh hết phần thiết kế, phân tích và viết báo cáo của từng thành viên. Trên cơ sở mức độ hoàn thành phần việc được giao, nhóm thống nhất đánh giá mức độ đóng góp như sau:

*Bảng 6.9 – Đánh giá mức độ đóng góp do nhóm thống nhất*

| Thành viên | Mức độ đóng góp |
|---|:-:|
| Trương Quang Như | 20% |
| Đỗ Phạm Minh Trâm | 20% |
| Đỗ Bình Dương | 20% |
| Nguyễn Việt Phú | 20% |
| Nguyễn Bảo Giang | 20% |

# Tài liệu tham khảo

1. Khoa Khoa học và Kỹ thuật Thông tin, Trường Đại học Công nghệ Thông tin – ĐHQG TP.HCM, *Slide bài giảng môn IE103 – Quản lý thông tin*: Chương 1 – Tổng quan quản lý thông tin; Chương 2 – Tổ chức thông tin; Chương 3 – Xử lý thông tin; Chương 4 – Trình bày thông tin; Chương 5 – Mô hình CSDL tiên tiến, Phần 1: CSDL hướng đối tượng, Phần 2: CSDL phân tán; bài giảng tham khảo *Mô hình CSDL tiên tiến (P2) – NoSQL*, 2026.
2. Microsoft, *SQL Server technical documentation* (T-SQL, XML Schema Collections, Row-Level Security, Backup and Restore, SQL Server Agent). https://learn.microsoft.com/sql/
3. Microsoft, *Transparent data encryption*, *Encrypt a column of data*, *Dynamic data masking*, *SQL Server Audit*, *Ledger overview*. https://learn.microsoft.com/sql/relational-databases/security/
4. Microsoft, *Partitioned views* và *Distributed transactions (MSDTC)*. https://learn.microsoft.com/sql/
5. R. Elmasri, S. B. Navathe, *Fundamentals of Database Systems*, 7th ed., Pearson, 2016.
6. M. T. Özsu, P. Valduriez, *Principles of Distributed Database Systems*, 4th ed., Springer, 2020.
7. R. G. G. Cattell (ed.), *The Object Data Standard: ODMG 3.0*, Morgan Kaufmann, 2000.
8. M. Fowler, *Patterns of Enterprise Application Architecture*, Addison-Wesley, 2002 (Identity Map, Single Table / Class Table / Concrete Table Inheritance).
9. E. Brewer, "CAP Twelve Years Later: How the 'Rules' Have Changed", *Computer*, vol. 45, no. 2, pp. 23–29, 2012.
10. D. Pritchett, "BASE: An Acid Alternative", *ACM Queue*, vol. 6, no. 3, pp. 48–55, 2008.
11. MongoDB Inc., *MongoDB Manual* (Data Modeling, Aggregation Pipeline, Schema Validation, BSON Types – Decimal128, Transactions). https://www.mongodb.com/docs/manual/
12. Streamlit Inc., *Streamlit documentation*. https://docs.streamlit.io/
13. ReportLab, *ReportLab PDF Library User Guide*. https://docs.reportlab.com/
14. *openpyxl documentation* và *python-docx documentation*. https://openpyxl.readthedocs.io/, https://python-docx.readthedocs.io/

# Phụ lục

## A. Cấu trúc mã nguồn

Toàn bộ mã nguồn của đồ án được công khai tại https://github.com/nhutruong-uit/ecms. Bảng dưới đây ánh xạ nội dung của báo cáo tới các tệp tương ứng trong kho mã để người đọc tiện đối chiếu.

*Bảng A.1 – Ánh xạ nội dung báo cáo tới tệp mã nguồn*

| Nội dung | Mục trong báo cáo | Tệp, thư mục |
|---|---|---|
| Quy trình nghiệp vụ, tháp DIKW, ERD, sơ đồ lớp, cây chức năng | 1.2, 1.6, 2.1, 2.3, 4.1 | `docs/design/` |
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
| Mã hoá, che dữ liệu, kiểm toán, ledger | 3.2 | `database/14_encryption_audit.sql` |
| CSDL phân tán | 5.2 | `database/13_distributed.sql` |
| Bộ kiểm thử SQL | 2.8.4, 3.2.2, 3.3 | `database/tests/` |
| Ứng dụng web | Chương 4 | `app/` |
| Bộ dựng báo cáo PDF, Excel, Word | 4.3 | `app/reports/` |
| CSDL hướng đối tượng | 5.1.3, 5.1.4 | `oodb/` |
| NoSQL MongoDB | 5.3 | `nosql/` |
| Môi trường Docker và healthcheck | 6.1.3 | `docker-compose.yml`, `database/healthcheck.sh`, `database/healthcheck.sql`, `database/run_all.sh`, `database/run_all.ps1` |
| Kiểm thử giao diện và kiểm thử tự động | 6.1.3 | `tests/`, `.github/workflows/ci.yml` |
| Văn bản báo cáo (Markdown) và công cụ dựng Word, PDF | Toàn bộ báo cáo, Phụ lục C | `report/01-tong-quan.md` … `report/07-phu-luc.md`, `scripts/build_report.py` |

## B. Hướng dẫn chạy lại hệ thống

Cách cài đặt, khởi động và sử dụng hệ thống được trình bày chi tiết trong tài liệu *Hướng dẫn sử dụng ECMS* đi kèm báo cáo. Tóm tắt các lệnh chính trên macOS hoặc Linux (trên Windows dùng `database\run_all.ps1` thay cho `run_all.sh`):

```bash title="Dựng CSDL, chạy ứng dụng và kiểm thử"
docker compose up -d --wait          # khởi động SQL Server, chờ healthcheck
database/run_all.sh                  # dựng CSDL ECMS từ đầu
pip install -r requirements.txt
streamlit run app/main.py            # mở http://localhost:8501
cd app && pytest ../tests -q         # 125 ca kiểm thử giao diện
```
