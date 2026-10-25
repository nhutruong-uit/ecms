# Lời mở đầu

Trong một trung tâm ngoại ngữ, thông tin phát sinh liên tục ở mọi khâu: tư vấn viên lập hồ sơ học viên, giáo vụ xếp lớp, giáo viên điểm danh và chấm điểm, kế toán thu học phí, quản lý theo dõi doanh thu và sĩ số. Khi các khâu này được ghi chép rời rạc trên nhiều tệp bảng tính, dữ liệu nhanh chóng trùng lặp, mâu thuẫn và khó tổng hợp; nhà quản lý có rất nhiều dữ liệu nhưng lại thiếu thông tin để ra quyết định. Đây chính là bài toán mà môn học Quản lý thông tin hướng tới: tổ chức, xử lý và trình bày dữ liệu sao cho đúng người nhận được đúng thông tin vào đúng lúc.

Xuất phát từ nhận định đó, Nhóm 1 chọn đề tài **"Hệ thống quản lý trung tâm tiếng Anh – ECMS (English Center Management System)"**. Đề tài đủ rộng để vận dụng toàn bộ nội dung của môn học – từ mô hình hoá dữ liệu, chuẩn hoá, ràng buộc toàn vẹn, truy vấn, an ninh dữ liệu, lập trình cơ sở dữ liệu (CSDL) đến thiết kế giao diện, báo cáo và các mô hình CSDL tiên tiến – đồng thời đủ gần gũi để nhóm tự khảo sát và kiểm chứng.

Báo cáo gồm sáu chương. **Chương 1** khảo sát bài toán, đặc tả yêu cầu và xác định phạm vi. **Chương 2** trình bày việc tổ chức thông tin: mô hình thực thể – mối kết hợp, sơ đồ lớp, lược đồ quan hệ, chuẩn hoá, ràng buộc toàn vẹn và cài đặt CSDL trên SQL Server. **Chương 3** trình bày việc xử lý thông tin: truy vấn SQL và XML, an ninh dữ liệu, sao lưu – phục hồi, nhập – xuất dữ liệu và lập trình CSDL. **Chương 4** trình bày tầng giao diện gồm menu, form, báo cáo và dashboard của ứng dụng web. **Chương 5** tìm hiểu và thử nghiệm ba mô hình CSDL tiên tiến trên chính dữ liệu của ECMS: hướng đối tượng, phân tán và NoSQL. **Chương 6** tổng kết kết quả, hạn chế, hướng phát triển và phân công công việc.

Nhóm xin gửi lời cảm ơn chân thành tới **TS. Võ Phương Bình** đã tận tình giảng dạy và định hướng trong suốt học kỳ. Do thời gian và kinh nghiệm còn hạn chế, báo cáo khó tránh khỏi thiếu sót; nhóm rất mong nhận được góp ý của thầy để hoàn thiện hơn.

# Chương 1. Tổng quan đề tài

Chương này giới thiệu bài toán quản lý trung tâm tiếng Anh, khảo sát quy trình nghiệp vụ và hiện trạng quản lý, từ đó xác định mục tiêu, phạm vi và đặc tả yêu cầu của hệ thống ECMS. Phần cuối chương đặt bài toán vào khung lý thuyết của môn học – quy trình quản lý thông tin và mô hình DIKW – và trình bày công cụ, phương pháp nhóm sử dụng.

## 1.1 Giới thiệu bài toán

### 1.1.1 Bối cảnh

ECMS được xây dựng cho một chuỗi trung tâm tiếng Anh (giả định) gồm ba chi nhánh tại TP. Hồ Chí Minh. Mỗi chi nhánh có bốn phòng học, đội ngũ nhân viên riêng và tự tuyển sinh, nhưng dùng chung danh mục chương trình, khoá học và chính sách học phí của trung tâm. Ba chi nhánh trong phạm vi khảo sát như sau:

*Bảng 1.1 – Ba chi nhánh trong phạm vi khảo sát*

| Mã | Chi nhánh | Địa chỉ | Số phòng học |
|---|---|---|:---:|
| CN01 | Thủ Đức | Khu phố 6, P. Linh Trung, TP. Thủ Đức | 4 |
| CN02 | Quận 1 | Đường Lê Lợi, P. Bến Nghé, Quận 1 | 4 |
| CN03 | Bình Thạnh | Đường Xô Viết Nghệ Tĩnh, P. 25, Quận Bình Thạnh | 4 |

### 1.1.2 Chương trình đào tạo

Trung tâm mở bốn chương trình: **IELTS**, **TOEIC**, **Giao tiếp** và **Thiếu nhi**. Mỗi chương trình gồm ba khoá học xếp theo cấp độ, chẳng hạn chương trình IELTS gồm IELTS Foundation, IELTS 5.5 và IELTS 6.5+. Khoá ở cấp sau yêu cầu học viên đã hoàn thành khoá ở cấp trước, gọi là **khoá tiên quyết**; học viên mới có thể vào thẳng cấp cao hơn nếu điểm kiểm tra đầu vào đủ cao. Mỗi khoá học được mở thành nhiều **lớp** tại các chi nhánh; mỗi lớp có giáo viên phụ trách, ngày khai giảng, sĩ số tối đa và một lịch học cố định trong tuần theo thứ – ca – phòng.

### 1.1.3 Cơ cấu tổ chức

Mỗi chi nhánh có năm nhóm người dùng với nhu cầu thông tin khác nhau. Bảng dưới đây tóm tắt quy mô và công việc chính của từng nhóm:

*Bảng 1.2 – Nhóm người dùng tại mỗi chi nhánh*

| Vai trò | Số lượng mỗi chi nhánh | Công việc chính |
|---|:---:|---|
| Quản lý chi nhánh | 1 | Điều hành chi nhánh, duyệt mở lớp, theo dõi doanh thu và sĩ số |
| Giáo vụ (tư vấn) | 1–2 | Tư vấn, kiểm tra đầu vào, ghi danh, xếp lịch lớp |
| Kế toán | 1 | Thu học phí, theo dõi công nợ, tính lương giáo viên |
| Giáo viên | 3–4 | Giảng dạy, điểm danh, nhập điểm, nhận xét học viên |
| Học viên | khoảng 100 | Xem lịch học, kết quả học tập và học phí của mình |

Nhân viên có thể có một **người quản lý trực tiếp**, ví dụ giáo viên chịu sự quản lý của quản lý chi nhánh. Giáo viên là một loại nhân viên đặc biệt: ngoài thông tin chung còn có loại giáo viên (Việt Nam hoặc bản ngữ), quốc tịch, trình độ, đơn giá mỗi buổi dạy và có thể sở hữu **nhiều chứng chỉ** như IELTS 8.0, TESOL, CELTA. Các đặc điểm này sẽ dẫn tới cấu trúc chuyên biệt hoá, mối kết hợp đệ quy và thuộc tính đa trị trong mô hình dữ liệu ở Chương 2.

## 1.2 Khảo sát quy trình nghiệp vụ

Qua khảo sát, hoạt động của trung tâm xoay quanh vòng đời của một học viên, đi từ lần tư vấn đầu tiên tới khi được cấp chứng nhận và tư vấn khoá tiếp theo. Hình 1.1 mô tả quy trình này cùng các tác nhân tham gia.

![Quy trình nghiệp vụ](../docs/design/quy-trinh-nghiep-vu.png)

*Hình 1.1 – Quy trình nghiệp vụ của trung tâm*

Quy trình gồm bảy bước. Mỗi bước do một tác nhân chịu trách nhiệm và tạo ra một loại dữ liệu riêng; cột cuối của bảng dưới đây cho biết dữ liệu đó được lưu ở bảng nào trong CSDL thiết kế ở Chương 2.

*Bảng 1.3 – Bảy bước nghiệp vụ và dữ liệu mỗi bước tạo ra*

| Bước | Nghiệp vụ | Người thực hiện | Dữ liệu tạo ra |
|:---:|---|---|---|
| 1 | **Tư vấn**: giới thiệu chương trình, học phí, lịch khai giảng; lập hồ sơ học viên | Giáo vụ | HOCVIEN |
| 2 | **Kiểm tra đầu vào**: đánh giá bốn kỹ năng Nghe, Đọc, Viết, Nói và ghi nhận xét | Giáo vụ, giáo viên | KIEMTRA_DAUVAO (kết quả chi tiết dạng XML) |
| 3 | **Xếp lớp và ghi danh**: đề xuất khoá phù hợp điểm kiểm tra, chọn lớp còn chỗ, kiểm tra khoá tiên quyết, áp dụng giảm giá | Giáo vụ | DANGKY |
| 4 | **Thu học phí**: lập phiếu thu cho một hoặc nhiều đăng ký, thu đủ hoặc thu một phần | Kế toán | PHIEUTHU, CT_PHIEUTHU |
| 5 | **Học và điểm danh**: mỗi buổi giáo viên ghi nhận có mặt, vắng, đi muộn hoặc vắng có phép | Giáo viên | BUOIHOC, DIEMDANH |
| 6 | **Thi và đánh giá**: điểm giữa kỳ, cuối kỳ, điểm trung bình và kết quả Đạt / Không đạt | Giáo viên | Các cột điểm của DANGKY |
| 7 | **Cấp chứng nhận**: học viên đạt và chuyên cần từ 80% trở lên được cấp chứng nhận, tư vấn khoá kế tiếp | Quản lý | Cột kết quả của DANGKY |

Song song với quy trình chính là các nghiệp vụ nền: quản lý chi nhánh, phòng học và ca học; quản lý nhân sự và chứng chỉ giáo viên; xếp lịch lớp sao cho không trùng phòng, không trùng giáo viên; cảnh báo học viên vắng nhiều; tính lương giáo viên theo số buổi dạy và lập báo cáo cho quản lý.

## 1.3 Hiện trạng và vấn đề cần giải quyết

Hiện nay mỗi bộ phận tự quản lý dữ liệu bằng tệp Excel riêng: mỗi chi nhánh có một tệp ghi danh, kế toán có một tệp thu tiền, mỗi giáo viên có một tệp điểm danh. Nhóm đã dựng lại một tệp ghi danh mẫu theo đúng cách trung tâm đang làm (phân tích chi tiết ở mục 2.6) và nhận thấy bảy nhóm vấn đề sau:

*Bảng 1.4 – Các vấn đề của cách quản lý bằng tệp Excel rời*

| Vấn đề | Biểu hiện thực tế |
|---|---|
| Trùng lặp dữ liệu | Họ tên, số điện thoại của học viên lặp lại ở mỗi dòng ghi danh; tên khoá học và học phí lặp lại ở mỗi học viên |
| Dị thường cập nhật | Học viên đổi số điện thoại nhưng chỉ được sửa ở một trong ba dòng, không còn biết số nào đúng |
| Dị thường thêm và xoá | Không thể nhập một lớp mới khi chưa có học viên; xoá học viên cuối cùng của lớp thì mất luôn thông tin lớp |
| Khó tổng hợp | Doanh thu theo chi nhánh và tháng phải chép thủ công từ ba tệp, mất một đến hai ngày mỗi cuối tháng |
| Không kiểm soát ràng buộc | Lớp vượt sĩ số, trùng phòng, ghi danh khi chưa học khoá tiên quyết vẫn nhập được |
| Không phân quyền, không truy vết | Ai có tệp cũng xem được lương giáo viên; không biết ai đã sửa số tiền trên phiếu thu |
| Rủi ro mất dữ liệu | Tệp nằm trên máy cá nhân, không được sao lưu định kỳ |

Các vấn đề này không thể khắc phục chỉ bằng cách cẩn thận hơn khi nhập liệu, vì nguyên nhân nằm ở chính mô hình lưu trữ phẳng. Giải pháp phù hợp là một **CSDL quan hệ tập trung** có ràng buộc toàn vẹn, phân quyền theo vai trò, nhật ký kiểm toán và cơ chế sao lưu, kèm một ứng dụng web có form nhập liệu tự kiểm tra dữ liệu và báo cáo tổng hợp tự động.

## 1.4 Mục tiêu và phạm vi

### 1.4.1 Mục tiêu

Đồ án đặt ra năm mục tiêu, tương ứng với nội dung của các chương tiếp theo:

1. Thiết kế một CSDL quan hệ chuẩn hoá cho toàn bộ nghiệp vụ của trung tâm, có đủ các loại ràng buộc toàn vẹn và dựng lại được từ đầu chỉ bằng một lệnh (Chương 2).
2. Xây dựng lớp xử lý thông tin ngay trong CSDL – truy vấn nghiệp vụ, view, stored procedure, function, trigger và cursor – sao cho mọi quy tắc nghiệp vụ được kiểm tra tại CSDL và không thể bị bỏ qua từ giao diện (Chương 3).
3. Bảo đảm an ninh dữ liệu: xác thực, phân quyền theo nguyên tắc quyền tối thiểu, băm mật khẩu, mã hoá dữ liệu, nhật ký kiểm toán, sao lưu và phục hồi theo thời điểm (Chương 3).
4. Xây dựng ứng dụng web có menu theo vai trò, form nhập liệu, báo cáo PDF/Excel/Word và dashboard theo các nguyên tắc trình bày thông tin của môn học (Chương 4).
5. Thử nghiệm chuyển dữ liệu ECMS sang các mô hình hướng đối tượng, phân tán và NoSQL để so sánh, đánh giá với mô hình quan hệ (Chương 5).

### 1.4.2 Phạm vi và giới hạn

Hệ thống bao quát toàn bộ quy trình ở mục 1.2 cho ba chi nhánh, năm vai trò nghiệp vụ và một vai trò quản trị. Một số nội dung nằm ngoài phạm vi đồ án:

- Không quản lý tuyển dụng nhân sự, kho giáo trình và thanh toán trực tuyến.
- Lương giáo viên chỉ tính bằng lương cơ bản cộng số buổi dạy nhân đơn giá, không tính thuế và bảo hiểm.
- Ứng dụng web phục vụ nhân viên nội bộ và học viên tra cứu; chưa có ứng dụng di động.
- Dữ liệu là dữ liệu mẫu do nhóm sinh theo nghiệp vụ (mục 2.8), không phải dữ liệu của một trung tâm thật.

## 1.5 Đặc tả yêu cầu

### 1.5.1 Tác nhân

Hệ thống có sáu tác nhân. Mỗi tác nhân được ánh xạ sang một vai trò (role) trong SQL Server để phân quyền ở mức CSDL, như trình bày ở mục 3.2.2.

*Bảng 1.5 – Tác nhân và vai trò tương ứng trong CSDL*

| Tác nhân | Mô tả | Vai trò trong CSDL |
|---|---|---|
| Quản lý | Quản lý chi nhánh hoặc ban giám đốc trung tâm | `r_QuanLy` |
| Giáo vụ | Tư vấn, tuyển sinh, xếp lớp | `r_GiaoVu` |
| Kế toán | Thu học phí, công nợ, lương | `r_KeToan` |
| Giáo viên | Giảng dạy, điểm danh, nhập điểm | `r_GiaoVien` |
| Học viên | Tra cứu thông tin cá nhân | `r_HocVien` |
| Quản trị hệ thống | Tài khoản, phân quyền, sao lưu | `db_owner` |

### 1.5.2 Yêu cầu chức năng

Từ quy trình nghiệp vụ, nhóm xác định 22 yêu cầu chức năng. Cột cuối cho biết mục của báo cáo trình bày cách đáp ứng yêu cầu đó.

*Bảng 1.6 – Yêu cầu chức năng*

| Mã | Yêu cầu | Tác nhân | Trình bày tại |
|---|---|---|:---:|
| FR01 | Đăng nhập, đăng xuất; mật khẩu được băm; tạm khoá 15 phút sau 5 lần nhập sai; menu hiển thị theo vai trò | Tất cả | 3.2.1, 4.1 |
| FR02 | Quản lý danh mục chi nhánh, phòng học, ca học | Quản lý | 4.2 |
| FR03 | Quản lý nhân viên, giáo viên và chứng chỉ giáo viên; lương chỉ quản lý và kế toán được xem | Quản lý | 3.2.2, 4.2 |
| FR04 | Quản lý chương trình, khoá học và khoá tiên quyết | Giáo vụ | 4.2 |
| FR05 | Mở lớp: chọn khoá, chi nhánh, giáo viên, ngày khai giảng, sĩ số tối đa | Giáo vụ | 4.2 |
| FR06 | Xếp lịch học theo thứ – ca – phòng, báo trùng phòng và trùng giáo viên | Giáo vụ | 3.3.1, 3.3.3 |
| FR07 | Sinh tự động các buổi học từ lịch và ngày khai giảng, bỏ qua ngày lễ | Giáo vụ | 3.3.4 |
| FR08 | Quản lý hồ sơ học viên, tìm kiếm theo nhiều tiêu chí có phân trang | Giáo vụ | 3.3.1, 4.2 |
| FR09 | Ghi nhận kiểm tra đầu vào bốn kỹ năng, lưu chi tiết dạng XML, gợi ý khoá học | Giáo vụ | 3.1.3, 4.2 |
| FR10 | Ghi danh: kiểm tra lớp còn chỗ, chưa đăng ký trùng, đã học khoá tiên quyết | Giáo vụ | 3.3.1 |
| FR11 | Chuyển lớp cho học viên trong cùng khoá học | Giáo vụ | 3.3.1 |
| FR12 | Lập phiếu thu cho nhiều đăng ký (master – detail), in phiếu thu PDF | Kế toán | 3.3.1, 4.3 |
| FR13 | Theo dõi công nợ học viên, làm nổi bật nợ quá hạn | Kế toán | 3.2.3, 4.2 |
| FR14 | Tính lương giáo viên theo số buổi dạy trong tháng | Kế toán | 3.3.4 |
| FR15 | Điểm danh cả lớp trong một lần lưu; giáo viên chỉ thấy lớp mình dạy | Giáo viên | 3.3.1, 4.2 |
| FR16 | Nhập điểm giữa kỳ, cuối kỳ; tự tính điểm trung bình, xếp loại, kết quả | Giáo viên | 3.3.1, 3.3.3 |
| FR17 | Cảnh báo học viên vắng quá 20% số buổi | Giáo viên, Giáo vụ | 3.3.4 |
| FR18 | Học viên xem lịch học, bảng điểm, công nợ của mình | Học viên | 3.3.2, 4.2 |
| FR19 | Báo cáo danh sách lớp, doanh thu, bảng điểm, dashboard KPI; xuất PDF, Excel và Word | Quản lý | 4.3 |
| FR20 | Ghi nhật ký mọi thay đổi trên đăng ký, phiếu thu và chi tiết phiếu thu, bảng lương, hồ sơ học viên, tài khoản; nhật ký chỉ được thêm, không được sửa, xoá; xem nhật ký | Quản trị | 3.3.3, 3.2.6 |
| FR21 | Quản lý tài khoản người dùng: vai trò theo chức vụ, khoá, mở khoá, đặt lại mật khẩu | Quản trị | 3.2.1 |
| FR22 | Sao lưu – phục hồi CSDL; nhập, xuất dữ liệu CSV, XML, JSON | Quản trị | 3.2.4, 3.2.5 |

### 1.5.3 Yêu cầu phi chức năng

Bên cạnh chức năng, hệ thống phải thoả tám yêu cầu về chất lượng. Mức độ đáp ứng từng yêu cầu được đánh giá lại ở mục 6.1.

*Bảng 1.7 – Yêu cầu phi chức năng*

| Mã | Nhóm | Yêu cầu |
|---|---|---|
| NFR01 | Toàn vẹn | Mọi nghiệp vụ nhiều bước (ghi danh, thu phí, chuyển lớp) chạy trong giao dịch; ràng buộc đặt tại CSDL bằng CHECK, khoá ngoại và trigger |
| NFR02 | Bảo mật | Quyền tối thiểu: ứng dụng chỉ được thực thi procedure và đọc view, không truy cập bảng gốc; lương bị ẩn với các vai trò không liên quan |
| NFR03 | Truy vết | Thay đổi trên dữ liệu nhạy cảm được ghi nhật ký kèm người thực hiện và thời điểm |
| NFR04 | Sẵn sàng | Lượng dữ liệu tối đa có thể mất (RPO) không quá 15 phút; thời gian khôi phục (RTO) không quá 1 giờ |
| NFR05 | Hiệu năng | Tra cứu học viên và lịch học dưới 1 giây với 10.000 học viên |
| NFR06 | Tiếng Việt | Sắp xếp, so sánh đúng tiếng Việt; báo cáo PDF hiển thị đúng dấu |
| NFR07 | Dễ dùng | Menu tối đa hai cấp; form kiểm tra dữ liệu và thông báo lỗi rõ ràng bằng tiếng Việt |
| NFR08 | Tái lập | Dựng lại toàn bộ CSDL từ đầu bằng một lệnh trên cả Windows và macOS |

### 1.5.4 Danh sách báo cáo

Ở góc độ quản lý thông tin, báo cáo là sản phẩm đầu ra quan trọng nhất của hệ thống. Nhóm xác định bảy báo cáo cần có, phân theo ba loại định kỳ, theo yêu cầu và tổng hợp:

*Bảng 1.8 – Danh sách báo cáo*

| Báo cáo | Loại | Người dùng |
|---|---|---|
| Danh sách học viên theo lớp | Định kỳ (đầu khoá) | Giáo viên, Giáo vụ |
| Doanh thu theo chi nhánh và tháng, có tổng phụ và tổng cộng | Định kỳ (tháng, quý) | Quản lý, Kế toán |
| Bảng điểm lớp, lịch sử học tập của học viên | Theo yêu cầu (có tham số) | Giáo viên, Học viên |
| Công nợ học viên | Theo yêu cầu | Kế toán |
| Cảnh báo chuyên cần | Định kỳ (hằng tuần) | Giáo vụ |
| Bảng lương giáo viên | Định kỳ (hằng tháng) | Kế toán |
| Dashboard KPI: học viên mới, doanh thu, tỷ lệ lấp đầy lớp, chuyên cần | Tổng hợp | Quản lý |

## 1.6 Thông tin, tri thức và quy trình quản lý thông tin trong ECMS

Phần này đặt bài toán ECMS vào khung lý thuyết của Chương 1 môn học: phân biệt dữ liệu – thông tin – tri thức, mô hình DIKW, lý do một tổ chức cần quản lý thông tin và quy trình năm giai đoạn. Các ví dụ đều lấy từ dữ liệu mẫu của chính hệ thống.

### 1.6.1 Dữ liệu, thông tin và tri thức

Theo bài giảng, **dữ liệu** là các sự kiện, số liệu thô chưa qua xử lý và chưa có ngữ cảnh; **thông tin** là kết quả của việc thu thập, tổ chức và chuyển đổi dữ liệu để nó có ý nghĩa với người dùng, giúp giảm sự không chắc chắn khi ra quyết định; **tri thức** là việc vận dụng thông tin cùng kinh nghiệm, ngữ cảnh và quy tắc để hiểu vấn đề và quyết định hành động. Bảng 1.9 so sánh ba khái niệm theo các tiêu chí của bài giảng, mỗi khái niệm kèm một ví dụ trong ECMS.

*Bảng 1.9 – So sánh dữ liệu, thông tin và tri thức trong ECMS*

| Tiêu chí | Dữ liệu | Thông tin | Tri thức |
|---|---|---|---|
| Mức độ | Nguyên bản, thô | Có cấu trúc, có ngữ cảnh | Thấu hiểu, ứng dụng |
| Bản chất | Quan sát, số liệu rời rạc | Dữ liệu đã được tổng hợp, chọn lọc | Phân tích, suy luận để hành động |
| Câu hỏi trả lời | Cái gì đã xảy ra? | Ai, ở đâu, khi nào, bao nhiêu? | Tại sao, làm thế nào? |
| Ví dụ trong ECMS | Bản ghi `DIEMDANH`: học viên HV0021, buổi 3 lớp TC650-2601 (24/08/2026), *Vắng* | HV0021 đã vắng 7 trên 16 buổi tính chuyên cần của lớp TC650-2601, tỷ lệ chuyên cần 56,25% | Học viên chuyên cần dưới 80% có tỷ lệ không đạt gấp ba lần nhóm còn lại, nên cần được chăm sóc sớm |
| Nơi lưu trong hệ thống | Bảng gốc (22 bảng) | View, function, báo cáo | Quy tắc trong procedure, ngưỡng cảnh báo, tài liệu hướng dẫn |

Bài giảng chia tri thức thành hai loại. **Tri thức hiện** (explicit) đã được văn bản hoá, lưu trong tài liệu hoặc CSDL nên chia sẻ được ngay; **tri thức ẩn** (tacit) nằm trong kinh nghiệm và kỹ năng của từng người nên dễ mất khi người đó nghỉ việc. Một mục tiêu của ECMS là chuyển dần tri thức ẩn của nhân viên thành tri thức hiện được hệ thống kiểm tra tự động:

*Bảng 1.10 – Tri thức hiện và tri thức ẩn tại trung tâm*

| Tri thức ẩn trước khi có ECMS | Chuyển thành tri thức hiện trong ECMS |
|---|---|
| Giáo vụ lâu năm "nhớ" khoá nào phải học trước khoá nào | Cột `MaKHTienQuyet` của `KHOAHOC`; `sp_DangKyHoc` từ chối ghi danh khi học viên chưa đạt khoá trước và điểm đầu vào chưa đủ |
| Tư vấn viên tự ước lượng trình độ học viên sau buổi kiểm tra | Điểm bốn kỹ năng lưu dạng XML có XML Schema; `fn_GoiYKhoaHoc` gợi ý khoá theo điểm |
| Giáo viên cảm nhận học viên "có vẻ sắp bỏ học" | Ngưỡng chuyên cần 80% và cảnh báo vắng quá 20% số buổi (`sp_CanhBaoChuyenCan`) |
| Kế toán nhớ mức giảm giá đã hứa với từng học viên | Cột `GiamGia` của `DANGKY` (CHECK 0–50%, form chọn theo bước 5%), thành tiền là cột tính toán và in trên phiếu thu |

Những gì vẫn là tri thức ẩn – cách giáo vụ thuyết phục một phụ huynh, cách giáo viên điều chỉnh bài giảng cho một lớp yếu – nằm ngoài phạm vi lưu trữ của CSDL; hệ thống chỉ hỗ trợ bằng cách cung cấp đúng thông tin để những người này ra quyết định.

### 1.6.2 Mô hình DIKW trên bài toán chuyên cần

Mô hình DIKW (Data – Information – Knowledge – Wisdom) mô tả tiến trình nâng dần giá trị từ dữ liệu thô tới **trí tuệ** – khả năng phán đoán và hành động. Hình 1.2 minh hoạ bốn tầng này bằng số liệu thật của bài toán chuyên cần trong dữ liệu mẫu; Bảng 1.11 chỉ ra đối tượng CSDL thực hiện mỗi bước chuyển tầng.

![Tháp DIKW trên bài toán chuyên cần](../docs/design/dikw.png)

*Hình 1.2 – Mô hình DIKW áp dụng cho bài toán chuyên cần, số liệu lấy từ CSDL mẫu*

*Bảng 1.11 – Các tầng DIKW và đối tượng CSDL tương ứng*

| Tầng | Ví dụ trong ECMS (số liệu thật) | Đối tượng CSDL |
|---|---|---|
| Dữ liệu (Data) | 10.063 bản ghi điểm danh, mỗi bản ghi chỉ cho biết một học viên có mặt, vắng, muộn hay có phép ở một buổi | Bảng `DIEMDANH` |
| Thông tin (Information) | Học viên HV0021 ở lớp TC650-2601 đã điểm danh 17 buổi: 8 có mặt, 1 muộn, 7 vắng, 1 có phép; tỷ lệ chuyên cần (buổi có phép không tính vào mẫu số) là 9 / 16 = **56,25%** | Hàm `fn_TyLeChuyenCan` |
| Tri thức (Knowledge) | Trong 344 đăng ký đã có kết quả, 12 đăng ký chuyên cần dưới 80% có tỷ lệ không đạt **33,3%**, trong khi 332 đăng ký còn lại chỉ **11,1%** – chuyên cần thấp là dấu hiệu sớm của nguy cơ không đạt | Truy vấn so sánh theo nhóm chuyên cần; procedure `sp_CanhBaoChuyenCan` |
| Trí tuệ (Wisdom) | Giáo vụ gọi điện chăm sóc, đề xuất học bù hoặc chuyển sang lớp có lịch phù hợp; quản lý điều chỉnh ca học nếu cả lớp vắng nhiều | Dashboard và báo cáo cảnh báo chuyên cần (Chương 4) |

Số liệu ở tầng tri thức có cỡ mẫu nhỏ (12 đăng ký) và dữ liệu là dữ liệu sinh, nên chỉ minh hoạ cách đi từ thông tin tới tri thức chứ không phải kết luận thống kê. Điều quan trọng là giá trị của hệ thống không nằm ở việc lưu được thật nhiều bản ghi điểm danh, mà ở chuỗi xử lý biến các bản ghi đó thành cảnh báo kịp thời và cuối cùng là hành động giữ chân học viên.

### 1.6.3 Vì sao trung tâm cần quản lý thông tin

Bài giảng nêu ba trụ cột của quản lý thông tin. Đối chiếu với hiện trạng ở mục 1.3, cả ba đều là nhu cầu thực của trung tâm:

- **Thông tin là tài sản.** Giống như vốn và nhân lực, dữ liệu học viên, học phí và kết quả học tập là tài sản của trung tâm. Quản lý kém dẫn tới quyết định sai: doanh thu tổng hợp chậm một đến hai ngày, không ai biết học viên nào sắp bỏ học.
- **Hỗ trợ người làm công nghệ.** Một mô hình dữ liệu chuẩn giúp tích hợp dữ liệu của ba chi nhánh, giúp ứng dụng web, báo cáo và các thử nghiệm ở Chương 5 dùng chung một nguồn dữ liệu nhất quán.
- **Bảo đảm an toàn.** Lương giáo viên và thông tin cá nhân học viên phải được phân quyền, mã hoá, ghi vết và sao lưu – những việc tệp Excel trên máy cá nhân không làm được.

### 1.6.4 Quy trình quản lý thông tin áp dụng vào ECMS

Bài giảng mô tả quản lý thông tin là quy trình năm giai đoạn: **Thu thập → Tổ chức → Chuyển đổi → Trình bày → An toàn**. Bảng 1.12 ánh xạ từng giai đoạn sang cách ECMS thực hiện và chương trình bày tương ứng; đây cũng chính là khung bố cục của báo cáo.

*Bảng 1.12 – Quy trình năm giai đoạn quản lý thông tin áp dụng vào ECMS*

| Giai đoạn | Áp dụng trong ECMS | Kỹ thuật chính | Chương |
|---|---|---|:---:|
| Thu thập | Form web nhập hồ sơ, kết quả kiểm tra, điểm danh, phiếu thu; nhập tệp CSV đăng ký trực tuyến; nhận tệp XML, JSON từ đối tác | Form có kiểm tra dữ liệu, BULK INSERT, OPENXML, OPENJSON | 3, 4 |
| Tổ chức | ERD được chuyển thành lược đồ quan hệ chuẩn hoá gồm 22 bảng có khoá, chỉ mục, ràng buộc; kết quả kiểm tra lưu dạng XML có XML Schema | ERD, chuẩn hoá, DDL, XSD | 2 |
| Chuyển đổi | Làm sạch và kiểm tra dữ liệu nhập (quy trình ETL: bảng tạm → 12 quy tắc kiểm tra → ghi vào bảng chính); truy vấn, view, procedure, function, trigger, cursor biến dữ liệu thô thành thông tin: sĩ số, công nợ, tỷ lệ chuyên cần, doanh thu | ETL, T-SQL, XQuery | 3 |
| Trình bày | Menu theo vai trò, form nhập liệu và master – detail, báo cáo PDF/Excel/Word, dashboard | Streamlit, ReportLab, openpyxl, python-docx, Plotly | 4 |
| An toàn | Xác thực, phân quyền, view bảo mật, băm mật khẩu, mã hoá đường truyền và dữ liệu lưu trữ, che dữ liệu, nhật ký kiểm toán, sao lưu – phục hồi | GRANT/DENY, HASHBYTES, TLS, TDE, Dynamic Data Masking, SQL Server Audit, BACKUP | 3 |

## 1.7 Khảo sát công cụ quản lý thông tin trong thực tế

Trước khi thiết kế, nhóm khảo sát ba nhóm công cụ mà các trung tâm ngoại ngữ đang sử dụng phổ biến (nội dung Bài thực hành số 1) để rút ra yêu cầu cho ECMS. Mỗi nhóm được đại diện bằng công cụ cụ thể: **Microsoft Excel và Google Sheets** cho bảng tính; **Fedena** và **OpenEduCat** (mã nguồn mở, có bản cộng đồng tự cài đặt) cho phần mềm quản lý trung tâm; **Moodle** và **Google Classroom** cho hệ thống quản lý học tập. Kết quả so sánh theo mười tiêu chí:

*Bảng 1.13 – So sánh ba nhóm công cụ quản lý trung tâm theo mười tiêu chí*

| Tiêu chí | Excel / Google Sheets | Phần mềm quản lý trung tâm (Fedena, OpenEduCat) | Hệ thống quản lý học tập (Moodle, Google Classroom) |
|---|---|---|---|
| Mục đích chính | Bảng tính đa năng | Tuyển sinh, lớp học, học phí, chăm sóc khách hàng | Giảng dạy, bài tập, chấm điểm trực tuyến |
| Mô hình dữ liệu | Phẳng (trang tính) | Quan hệ, ẩn sau giao diện (Fedena dùng MySQL, OpenEduCat chạy trên Odoo dùng PostgreSQL) | Quan hệ (Moodle dùng MySQL hoặc PostgreSQL) |
| Ràng buộc toàn vẹn | Gần như không có | Có, theo nghiệp vụ cài sẵn | Có, theo khoá học và người dùng |
| Phân quyền | Theo tệp (xem hoặc sửa) | Theo vai trò | Theo vai trò |
| Học phí, công nợ | Tự xây dựng công thức | Có sẵn | Không có |
| Điểm danh, điểm số | Thủ công | Có | Có, mạnh về bài tập |
| Báo cáo | Bảng tổng hợp thủ công | Mẫu có sẵn, khó tuỳ biến | Báo cáo học tập |
| Chi phí | Miễn phí hoặc thấp | Bản cộng đồng miễn phí nhưng phải tự vận hành; bản dịch vụ thuê bao theo tháng, theo số học viên | Miễn phí (Moodle tự vận hành, Classroom) |
| Khả năng tuỳ biến | Cao nhưng dễ sai | Thấp | Trung bình (qua plugin) |
| Truy vết, sao lưu | Lịch sử phiên bản (Google Sheets) | Có | Có |

Từ bảng so sánh, nhóm rút ra bốn định hướng cho ECMS:

1. Giữ sự linh hoạt khi nhập liệu như Excel nhưng chặn dữ liệu sai ngay tại CSDL bằng CHECK và trigger (FR10, NFR01).
2. Học theo phần mềm CRM: luồng tuyển sinh liền mạch từ kiểm tra đầu vào, ghi danh đến thu học phí (FR09–FR12).
3. Học theo hệ thống quản lý học tập: giáo viên tự điểm danh và nhập điểm trên các lớp của mình (FR15–FR16).
4. Bổ sung những điểm cả ba nhóm công cụ còn yếu với trung tâm nhỏ: báo cáo tuỳ biến theo chi nhánh, nhật ký kiểm toán và phân quyền tới mức cột (FR19–FR20, NFR02).

## 1.8 Công cụ và phương pháp thực hiện

### 1.8.1 Công cụ và môi trường

Nhóm lựa chọn công cụ theo hai tiêu chí: thống nhất với công cụ dùng trong các bài thực hành của môn học, và chạy được như nhau trên máy Windows lẫn macOS của các thành viên.

*Bảng 1.14 – Công cụ và môi trường thực hiện*

| Thành phần | Công cụ | Ghi chú |
|---|---|---|
| Hệ quản trị CSDL | Microsoft SQL Server 2022 (Windows), SQL Server 2025 (macOS, Linux qua Docker) | Mã T-SQL chạy được trên cả hai phiên bản |
| Công cụ quản trị, truy vấn | SQL Server Management Studio; Visual Studio Code với tiện ích MSSQL; sqlcmd | Phát triển và kiểm thử script |
| Ứng dụng web | Python 3.11, Streamlit, pyodbc (ODBC Driver 18), pandas, Plotly | Giao diện và kết nối CSDL |
| Báo cáo | ReportLab (PDF), openpyxl (Excel), python-docx (Word) | Font DejaVu để hiển thị tiếng Việt |
| Mô hình tiên tiến | MongoDB 7 (Docker), Python với pymongo | Thử nghiệm ở Chương 5 |
| Kiểm thử | Script T-SQL kiểm thử, pytest với Streamlit AppTest, Playwright | Kiểm thử CSDL, kiểm thử giao diện, chụp ảnh màn hình tự động |
| Thiết kế | draw.io, Graphviz | ERD, sơ đồ lớp, cây chức năng, tháp DIKW |
| Quản lý mã nguồn | Git, GitHub (Issues, Project, Pull Request, Actions) | Phân công, review và kiểm thử tự động |

### 1.8.2 Phương pháp làm việc

Đồ án được chia thành 30 công việc, thực hiện trong bốn đợt (sprint), mỗi đợt khoảng một tuần, từ ngày 12/10/2026 đến 04/11/2026. Mỗi công việc là một issue trên GitHub, được giao cho một thành viên và hoàn thành bằng một Pull Request vào nhánh tích hợp; nhóm trưởng review trước khi hợp nhất. Mọi script CSDL được đánh số theo thứ tự chạy và có thể chạy lại từ đầu, nhờ đó cả nhóm luôn làm việc trên cùng một bộ dữ liệu. Ở bản phát hành cuối, một quy trình kiểm thử tự động dựng lại CSDL trống, chạy toàn bộ bộ kiểm thử và mở thử mọi trang của ứng dụng trước khi chấp nhận thay đổi (mục 6.1.3). Bảng phân công chi tiết được trình bày ở mục 6.6.

## 1.9 Tiểu kết chương

Chương 1 đã xác định bài toán quản lý một chuỗi ba chi nhánh trung tâm tiếng Anh với quy trình bảy bước, chỉ ra những hạn chế của cách quản lý bằng tệp Excel rời và đặt ra mục tiêu xây dựng một CSDL quan hệ tập trung kèm ứng dụng web. Hệ thống được đặc tả bằng sáu tác nhân, 22 yêu cầu chức năng, tám yêu cầu phi chức năng và bảy báo cáo. Chương cũng đặt bài toán vào khung lý thuyết của môn học: phân biệt dữ liệu – thông tin – tri thức, chuyển tri thức ẩn thành tri thức hiện, minh hoạ tháp DIKW bằng số liệu chuyên cần thật và ánh xạ quy trình năm giai đoạn Thu thập – Tổ chức – Chuyển đổi – Trình bày – An toàn sang các chương của báo cáo. Những yêu cầu này là cơ sở để thiết kế mô hình dữ liệu ở Chương 2.
