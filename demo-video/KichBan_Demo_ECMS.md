# Kịch bản video demo ECMS

Video 1920×1080, không có tiếng, giải thích bằng phụ đề trên màn hình; thời lượng khoảng 6 phút 40 giây. Mốc thời gian dưới đây lấy từ chính video ECMS_demo.mp4 (tệp phụ đề rời phu-de/ECMS_demo.vi.srt khớp từng mốc).

Quay trên ứng dụng thật chạy ở GitHub Codespace, dữ liệu mẫu của dự án; các thao tác thêm học viên, ghi danh, lập phiếu thu là ghi dữ liệu thật (học viên demo: Nguyễn Minh Khang). Mạch chuyện theo “Quy trình nghiệp vụ mẫu” (Phần 6 hướng dẫn sử dụng): một học viên mới đi qua giáo vụ → kế toán → giáo viên → học viên → quản lý.

## Tổng quan các cảnh

| Cảnh | Từ – đến | Vai trò | Nội dung chính |
|---|---|---|---|
| 0. Mở đầu | 0:00 – 0:19 | — | Giới thiệu đề tài, nói tên nhóm và thành viên (phần này nhóm tự nói thêm). |
| 1. Trang đăng nhập và phân quyền | 0:19 – 0:52 | Chưa đăng nhập | 5 vai trò, mỗi vai trò thấy đúng menu của mình; dữ liệu nằm trong SQL Server. |
| 2. Giáo vụ – tổng quan và Đào tạo | 0:52 – 1:31 | giaovu (CN01) | Menu rộng và nông, chỉ hiện mục được phép; khoá học theo cấp độ, có khoá tiên quyết. |
| 3. Giáo vụ – tiếp nhận học viên mới | 1:31 – 2:04 | giaovu | Kiểm tra dữ liệu ngay trên giao diện; hồ sơ lưu qua thủ tục lưu trữ; mã học viên do hệ thống cấp. |
| 4. Giáo vụ – kiểm tra đầu vào | 2:04 – 2:31 | giaovu | Kết quả lưu dạng XML; hàm gợi ý khoá theo điểm tổng. |
| 5. Giáo vụ – ghi danh | 2:31 – 3:08 | giaovu | Tự kiểm tra lớp đầy, đăng ký trùng, điều kiện tiên quyết; sĩ số cập nhật; phát sinh công nợ. |
| 6. Kế toán – công nợ và lập phiếu thu | 3:08 – 4:07 | ketoan (CN01) | Hạn đóng = ngày đăng ký + 14 ngày; trigger cập nhật tổng tiền và trạng thái học phí; phiếu không sửa/xoá được. |
| 7. Giáo viên – điểm danh và nhập điểm | 4:07 – 4:56 | giaovien | Giáo viên chỉ thấy lớp mình dạy; điểm TB, xếp loại, kết quả do hệ thống tính (0,4·GK + 0,6·CK). |
| 8. Học viên | 4:56 – 5:23 | hocvien | Học viên chỉ xem dữ liệu của chính mình. |
| 9. Quản lý – dashboard, báo cáo, nhật ký | 5:23 – 6:24 | quanly (toàn trung tâm) | Quản lý thấy cả trung tâm; nhật ký do trigger ghi, chỉ thêm; thấy lại đúng thao tác của giáo vụ và kế toán ở trên. |
| 10. Kết | 6:24 – 6:41 | — | Chốt lại: trọn vòng đời học viên, 5 vai trò, SQL Server 2025, báo cáo – dashboard. |

## Chi tiết từng cảnh

### 0. Mở đầu  (0:00)

- **Vai trò / tài khoản:** —
- **Thao tác trên màn hình:** Thẻ tiêu đề xanh: ECMS – Hệ thống quản lý trung tâm tiếng Anh, đồ án IE103, Streamlit + SQL Server 2025.
- **Ý cần nhấn mạnh:** Giới thiệu đề tài, nói tên nhóm và thành viên (phần này nhóm tự nói thêm).
- **Phụ đề hiện trên video:**
  - `0:03` Xin chào quý thầy cô và các bạn. Nhóm chúng em xin giới thiệu ECMS – hệ thống quản lý trung tâm tiếng Anh, đồ án môn Quản lý thông tin.

### 1. Trang đăng nhập và phân quyền  (0:19)

- **Vai trò / tài khoản:** Chưa đăng nhập
- **Thao tác trên màn hình:** Mở khung “Tài khoản demo”, lướt chuột qua 5 tài khoản; gõ giaovu / mật khẩu mẫu rồi Đăng nhập.
- **Ý cần nhấn mạnh:** 5 vai trò, mỗi vai trò thấy đúng menu của mình; dữ liệu nằm trong SQL Server.
- **Phụ đề hiện trên video:**
  - `0:19` ECMS là ứng dụng web, dữ liệu lưu trong SQL Server 2025. Trang đăng nhập có sẵn các tài khoản dùng thử cho năm vai trò.
  - `0:30` Mỗi vai trò chỉ nhìn thấy đúng những chức năng thuộc quyền của mình: quản lý trung tâm, giáo vụ, kế toán, giáo viên và học viên.
  - `0:41` Ta bắt đầu từ hành trình của một học viên mới, với tài khoản giáo vụ của chi nhánh CN01.

### 2. Giáo vụ – tổng quan và Đào tạo  (0:52)

- **Vai trò / tài khoản:** giaovu (CN01)
- **Thao tác trên màn hình:** Rê chuột qua các nhóm menu; Trang chủ (4 chỉ số + bảng lớp); Chương trình & khoá học → Lớp học → Xếp lịch.
- **Ý cần nhấn mạnh:** Menu rộng và nông, chỉ hiện mục được phép; khoá học theo cấp độ, có khoá tiên quyết.
- **Phụ đề hiện trên video:**
  - `0:52` Menu bên trái được nhóm theo nghiệp vụ: Đào tạo, Học viên, Học tập, Tài chính, Báo cáo và Hệ thống – chỉ hiện những mục giáo vụ được phép dùng.
  - `1:04` Trang chủ tóm tắt nhanh số lớp đang học, lớp sắp khai giảng, số học viên và công nợ của chi nhánh.
  - `1:14` Phần Đào tạo quản lý khoá học, lớp học và lịch học. Mỗi chương trình gồm nhiều khoá theo cấp độ, khoá cấp sau có thể yêu cầu khoá tiên quyết.

### 3. Giáo vụ – tiếp nhận học viên mới  (1:31)

- **Vai trò / tài khoản:** giaovu
- **Thao tác trên màn hình:** Hồ sơ học viên: cuộn tới form “Thêm học viên mới”, bấm Lưu khi còn trống để thấy lỗi từng ô; gõ Nguyễn Minh Khang, số điện thoại, email, địa chỉ rồi Lưu → báo mã học viên mới.
- **Ý cần nhấn mạnh:** Kiểm tra dữ liệu ngay trên giao diện; hồ sơ lưu qua thủ tục lưu trữ; mã học viên do hệ thống cấp.
- **Phụ đề hiện trên video:**
  - `1:31` Bây giờ giáo vụ tiếp nhận một học viên mới. Nếu bỏ trống hoặc nhập sai, hệ thống báo lỗi ngay tại từng ô.
  - `1:44` Nhập đủ thông tin đúng định dạng, hồ sơ được lưu và hệ thống cấp mã học viên mới.

### 4. Giáo vụ – kiểm tra đầu vào  (2:04)

- **Vai trò / tài khoản:** giaovu
- **Thao tác trên màn hình:** Tìm học viên vừa tạo; nhập Listening 7, Reading 7.5, Writing 6.5, Speaking 7 + nhận xét; Lưu → bảng gợi ý khoá học.
- **Ý cần nhấn mạnh:** Kết quả lưu dạng XML; hàm gợi ý khoá theo điểm tổng.
- **Phụ đề hiện trên video:**
  - `2:04` Bước tiếp theo là kiểm tra đầu vào. Giáo vụ nhập điểm bốn kỹ năng, hệ thống lưu kết quả dạng XML và gợi ý khoá học phù hợp với điểm tổng.

### 5. Giáo vụ – ghi danh  (2:31)

- **Vai trò / tài khoản:** giaovu
- **Thao tác trên màn hình:** Trang Ghi danh: hiện kết quả kiểm tra gần nhất và khoá đề xuất; chọn lớp IE65-2601, kéo giảm giá 10%, bấm Ghi danh.
- **Ý cần nhấn mạnh:** Tự kiểm tra lớp đầy, đăng ký trùng, điều kiện tiên quyết; sĩ số cập nhật; phát sinh công nợ.
- **Phụ đề hiện trên video:**
  - `2:31` Cuối cùng là ghi danh. Hệ thống đề xuất khoá theo kết quả kiểm tra, chỉ liệt kê lớp còn chỗ và tự kiểm tra lớp đầy, đăng ký trùng, điều kiện tiên quyết.
  - `2:44` Chọn lớp, đặt mức giảm giá nếu có ưu đãi, rồi bấm ghi danh. Sĩ số lớp tự cập nhật và khoản học phí chuyển sang công nợ.

### 6. Kế toán – công nợ và lập phiếu thu  (3:08)

- **Vai trò / tài khoản:** ketoan (CN01)
- **Thao tác trên màn hình:** Đăng xuất, đăng nhập ketoan. Công nợ: bảng tô màu, tìm học viên mới. Lập phiếu thu: tìm học viên, bảng khoản còn nợ (master – detail), Lập phiếu thu, bấm In phiếu (PDF); thẻ Tra cứu phiếu thu → chọn một phiếu xem chi tiết.
- **Ý cần nhấn mạnh:** Hạn đóng = ngày đăng ký + 14 ngày; trigger cập nhật tổng tiền và trạng thái học phí; phiếu không sửa/xoá được.
- **Phụ đề hiện trên video:**
  - `3:08` Chuyển sang kế toán. Trang Công nợ liệt kê các đăng ký chưa đóng đủ; hạn đóng là mười bốn ngày sau ngày đăng ký, khoản quá hạn được tô màu.
  - `3:20` Học viên vừa ghi danh đã có mặt ở đây. Sang trang Lập phiếu thu: tìm học viên, hệ thống hiện các khoản còn nợ để chọn thu.
  - `3:32` Bấm lập phiếu thu. Hệ thống ghi phiếu, trigger tự cập nhật trạng thái học phí, và cho in phiếu thu dạng PDF.
  - `3:42` Thẻ Tra cứu phiếu thu giúp xem lại mọi phiếu đã lập, kèm chi tiết từng khoản.

### 7. Giáo viên – điểm danh và nhập điểm  (4:07)

- **Vai trò / tài khoản:** giaovien
- **Thao tác trên màn hình:** Điểm danh: chọn lớp, mở danh sách buổi học; Nhập điểm: lưới điểm giữa kỳ/cuối kỳ; Cảnh báo chuyên cần.
- **Ý cần nhấn mạnh:** Giáo viên chỉ thấy lớp mình dạy; điểm TB, xếp loại, kết quả do hệ thống tính (0,4·GK + 0,6·CK).
- **Phụ đề hiện trên video:**
  - `4:07` Giáo viên chỉ thấy các lớp mình phụ trách. Ở trang Điểm danh, giáo viên chọn lớp và buổi học, đánh dấu có mặt, muộn, có phép hoặc vắng cho cả lớp rồi lưu một lần.
  - `4:23` Trang Nhập điểm nhận điểm giữa kỳ và cuối kỳ. Điểm trung bình, xếp loại và kết quả đạt hay không đạt do hệ thống tự tính.
  - `4:35` Cảnh báo chuyên cần liệt kê những học viên vắng quá ngưỡng để kịp thời nhắc nhở.

### 8. Học viên  (4:56)

- **Vai trò / tài khoản:** hocvien
- **Thao tác trên màn hình:** Lịch học tuần → Bảng điểm → Học phí.
- **Ý cần nhấn mạnh:** Học viên chỉ xem dữ liệu của chính mình.
- **Phụ đề hiện trên video:**
  - `4:56` Học viên đăng nhập chỉ xem được dữ liệu của chính mình: lịch học theo tuần, bảng điểm và tình hình học phí.

### 9. Quản lý – dashboard, báo cáo, nhật ký  (5:23)

- **Vai trò / tài khoản:** quanly (toàn trung tâm)
- **Thao tác trên màn hình:** Dashboard: 6 chỉ số và các biểu đồ (cuộn từ từ); Báo cáo & xuất file: chọn báo cáo Doanh thu; Nhật ký hệ thống: chọn dòng UPDATE đăng ký để xem dữ liệu trước / sau.
- **Ý cần nhấn mạnh:** Quản lý thấy cả trung tâm; nhật ký do trigger ghi, chỉ thêm; thấy lại đúng thao tác của giáo vụ và kế toán ở trên.
- **Phụ đề hiện trên video:**
  - `5:23` Cuối cùng là quản lý trung tâm, với phạm vi toàn trung tâm. Dashboard tổng hợp học viên mới, doanh thu, tỷ lệ lấp đầy lớp, chuyên cần và công nợ, kèm biểu đồ theo tháng.
  - `5:45` Trang Báo cáo và xuất file cho phép chọn báo cáo, xem trước và tải về dạng PDF, Excel hoặc Word.
  - `6:00` Mọi thay đổi về đăng ký, phiếu thu, tài khoản, hồ sơ học viên đều được trigger ghi vào nhật ký; nhật ký chỉ thêm, không sửa hay xoá.
  - `6:12` Ở đây ta thấy lại các thao tác vừa rồi của giáo vụ và kế toán, kèm tên tài khoản thực hiện và dữ liệu trước, sau khi thay đổi.

### 10. Kết  (6:24)

- **Vai trò / tài khoản:** —
- **Thao tác trên màn hình:** Thẻ tổng kết 4 ý chính, giữ khoảng 3 giây.
- **Ý cần nhấn mạnh:** Chốt lại: trọn vòng đời học viên, 5 vai trò, SQL Server 2025, báo cáo – dashboard.
- **Phụ đề hiện trên video:**
  - `6:24` Tóm lại, ECMS đáp ứng trọn vòng đời của một học viên: tiếp nhận, ghi danh, thu học phí, học tập và báo cáo quản lý. Xin cảm ơn quý thầy cô và các bạn đã theo dõi.

## Gợi ý khi trình chiếu

- Phát video toàn màn hình, tự thuyết minh trực tiếp bằng lời theo các ý ở cột “Ý cần nhấn mạnh”; phụ đề đã có sẵn nên có thể nói ngắn hơn.
- Có thể dừng ở từng cảnh (mốc ở bảng trên) để trả lời câu hỏi rồi phát tiếp.
- Muốn quay lại hoặc sửa nội dung: sửa phụ đề / thao tác trong quay_demo.py rồi chạy lại (xem hướng dẫn ở đầu tệp).
