# Chương 4. Trình bày thông tin

Chương 2 và Chương 3 đã xây dựng CSDL cùng lớp xử lý gồm view, procedure, trigger và phân quyền. Chương này trình bày tầng giao diện – nơi người dùng thực sự tiếp xúc với thông tin – và đối chiếu từng nguyên tắc thiết kế menu, form, báo cáo của môn học với ứng dụng web ECMS.

**Kiến trúc ứng dụng.** Ứng dụng được viết bằng Python với thư viện Streamlit, kết nối SQL Server qua pyodbc bằng login riêng `ecms_app` – login chỉ có quyền thực thi procedure và đọc view (mục 3.2.2). Ứng dụng gồm ba tầng: tầng trang (mỗi chức năng một tệp), tầng dùng chung (kết nối CSDL, xác thực, menu, các thành phần giao diện) và tầng báo cáo (sinh PDF, Excel, Word). Bốn nguyên tắc kỹ thuật được áp dụng xuyên suốt:

1. **Giao diện chỉ gọi view, function và procedure**, không truy cập bảng gốc và không ghép chuỗi SQL – mọi tham số đều được truyền qua dấu `?`. Nghiệp vụ và ràng buộc nằm trong CSDL nên giao diện không thể "đi vòng".
2. **Mỗi phiên làm việc có một kết nối riêng mang ngữ cảnh người dùng.** Ngay khi mở kết nối, ứng dụng gọi `sp_set_session_context` với tuỳ chọn `@read_only = 1` để ghi tên tài khoản, phạm vi chi nhánh, vai trò, mã nhân viên hoặc học viên; trong suốt kết nối đó không câu lệnh nào đổi được các giá trị này nữa. Ứng dụng không dùng connection pool, vì kết nối lấy lại từ pool vẫn giữ ngữ cảnh của người dùng trước. Nhờ ngữ cảnh này, view tự lọc dữ liệu theo chi nhánh, procedure kiểm tra quyền trên từng dòng và trigger ghi đúng người thao tác vào nhật ký.
3. **Phiên đăng nhập được kiểm tra lại liên tục.** Cứ sau 60 giây, đầu mỗi trang đọc lại trạng thái và vai trò của tài khoản: nếu Quản lý vừa khoá tài khoản hoặc đổi chức vụ của nhân viên, tab đang mở bị đăng xuất ngay ở thao tác kế tiếp, kèm lý do hiển thị ở trang đăng nhập. Không thao tác quá 30 phút thì phiên hết hạn.
4. **Lỗi nghiệp vụ được hiển thị bằng tiếng Việt**, đúng nội dung thông báo mà procedure hoặc trigger ném ra; phần thông tin kỹ thuật của trình điều khiển ODBC được lược bỏ trước khi hiển thị.

Các hình trong chương được chụp tự động bằng script `scripts/chup_anh.py` (Playwright) trên CSDL vừa dựng từ dữ liệu mẫu, khung nhìn 1280 điểm ảnh với độ phân giải gấp đôi. Mỗi hình đăng nhập bằng đúng vai trò mà phân hệ đó phục vụ – giáo vụ cho Đào tạo và Học viên, giáo viên cho Học tập, kế toán cho Tài chính, quản lý cho Danh mục, Báo cáo và Hệ thống – và vai trò được ghi trong chú thích. Hai hình báo cáo PDF được kết xuất từ chính tệp mà nút "Tải PDF" và "In phiếu" của ứng dụng tạo ra.

## 4.1 Thiết kế menu

### 4.1.1 Cây chức năng

Toàn bộ menu được khai báo **tại một chỗ** dưới dạng một danh sách, mỗi dòng gồm nhóm, tệp trang, tiêu đề, biểu tượng và các vai trò được thấy. Thanh điều hướng được dựng tự động từ danh sách này theo vai trò của người đăng nhập; sơ đồ cây chức năng ở Hình 4.1 cũng được sinh tự động từ cùng danh sách nên luôn khớp với ứng dụng. Ký hiệu vai trò trong hình: QL là Quản lý, GVụ là Giáo vụ, KT là Kế toán, GV là Giáo viên, HV là Học viên.

![Cây chức năng ECMS](../docs/design/menu-tree.png)

*Hình 4.1 – Cây chức năng và vai trò được thấy từng mục*

### 4.1.2 Đối chiếu nguyên tắc thiết kế menu

Bảng 4.1 đối chiếu từng nguyên tắc thiết kế menu của môn học với cách ECMS áp dụng:

*Bảng 4.1 – Đối chiếu nguyên tắc thiết kế menu*

| Nguyên tắc | Cách ECMS áp dụng | Minh hoạ |
|---|---|---|
| Rộng và nông: ít cấp, mỗi cấp vừa đủ lựa chọn | Đúng hai cấp: nhóm và chức năng. Tám nhóm, mỗi nhóm từ một đến bốn mục, không có menu con lồng nhau. Mọi chức năng đến được bằng một cú nhấp từ thanh bên | Hình 4.1, 4.3 |
| Nhóm theo nghiệp vụ, sắp theo luồng công việc | Thứ tự nhóm bám theo quy trình ở mục 1.2: Danh mục, Đào tạo, Học viên, Học tập, Tài chính, Báo cáo, Hệ thống; trong mỗi nhóm cũng theo thứ tự thao tác (mở lớp rồi xếp lịch; kiểm tra đầu vào rồi ghi danh) | Hình 4.1 |
| Tên rõ nghĩa, nhất quán | Tiêu đề là danh từ nghiệp vụ quen thuộc như "Lập phiếu thu", "Công nợ", trùng với tiêu đề trang; mỗi mục có biểu tượng cùng một phong cách | Hình 4.3 |
| Chỉ hiện chức năng được phép | Danh sách menu được lọc theo vai trò; mục không có quyền bị **ẩn hẳn** chứ không chỉ làm mờ | Hình 4.3, 4.4 |
| Chặn cả đường vòng | Ẩn menu là chưa đủ: đầu mỗi trang đều kiểm tra vai trò, nên gõ thẳng địa chỉ của trang không được phép sẽ nhận thông báo "Bạn không có quyền truy cập chức năng này". Lớp bảo vệ cuối cùng là quyền SQL của từng role và kiểm tra phạm vi trong procedure | – |
| Cho biết người dùng đang ở đâu | Mục đang mở được tô nền đậm trên thanh bên; tiêu đề trang lặp lại tên mục; cuối thanh bên luôn hiện họ tên, vai trò, chi nhánh và phạm vi dữ liệu | Hình 4.3, 4.4 |
| Lối thoát rõ ràng | Nút Đăng xuất cố định ở cuối thanh bên; Trang chủ là điểm xuất phát chung cho mọi vai trò | Hình 4.3 |
| Dễ mở rộng | Thêm một chức năng chỉ cần tạo tệp trang và thêm một dòng vào danh sách menu; trang chưa có tệp tự động bị ẩn | – |

Độ rộng của menu thay đổi theo vai trò (Bảng 4.2). Quản lý thấy nhiều chức năng nhất, học viên chỉ thấy ba mục:

*Bảng 4.2 – Số nhóm và số chức năng mỗi vai trò thấy trên menu*

| Vai trò | Số nhóm | Số chức năng | Các nhóm thấy được |
|---|:-:|:-:|---|
| Quản lý | 8 | 20 | Tất cả, trừ trang dành riêng cho học viên |
| Giáo vụ | 7 | 11 | Trang chủ, Đào tạo, Học viên, Học tập (cảnh báo), Tài chính (công nợ), Báo cáo, Hệ thống |
| Kế toán | 5 | 7 | Trang chủ, Danh mục (nhân viên), Tài chính, Báo cáo, Hệ thống |
| Giáo viên | 4 | 6 | Trang chủ, Học tập, Báo cáo, Hệ thống |
| Học viên | 3 | 3 | Trang chủ, Lịch học và kết quả của tôi, Đổi mật khẩu |

Màn hình đăng nhập (Hình 4.2) chỉ gồm hai ô nhập và một nút. Mật khẩu được kiểm tra bằng procedure `sp_DangNhap`: mật khẩu băm lặp 10.000 vòng có salt; sai tên đăng nhập và sai mật khẩu nhận **cùng một** thông báo để không dò được tài khoản nào có thật; sai năm lần liên tiếp thì tài khoản bị tạm khoá 15 phút (mục 3.2.1). Khi phiên bị đăng xuất tự động, lý do – phiên hết hạn, tài khoản bị khoá, vai trò vừa thay đổi – được hiện ngay trên màn hình này. Khung "Tài khoản demo" chỉ hiện ở môi trường phát triển và được tắt bằng biến `ECMS_SHOW_DEMO=no` khi triển khai thật.

![Màn hình đăng nhập](images/ch4/01_dang_nhap.jpg)

*Hình 4.2 – Màn hình đăng nhập*

Sau khi đăng nhập, thanh bên chỉ hiện các nhóm chức năng của vai trò tương ứng. Hình 4.3 và Hình 4.4 so sánh cùng một ứng dụng với hai vai trò: Quản lý cấp trung tâm thấy đủ tám nhóm cùng các chỉ số tóm tắt của toàn trung tâm; Giáo viên chỉ còn ba nhóm Học tập, Báo cáo, Hệ thống, và trang chủ chỉ hiện các lớp của chi nhánh CN01.

![Trang chủ của Quản lý](images/ch4/02_trang_chu.jpg)

*Hình 4.3 – Trang chủ và menu đầy đủ của vai trò Quản lý (tài khoản `quanly`)*

![Trang chủ của Giáo viên](images/ch4/02b_trang_chu_giao_vien.jpg)

*Hình 4.4 – Trang chủ và menu rút gọn của vai trò Giáo viên (tài khoản `giaovien`)*

## 4.2 Thiết kế form

### 4.2.1 Bố cục chung của một trang nghiệp vụ

Mọi trang danh mục và nghiệp vụ dùng chung một khuôn bố cục, đi theo trình tự tự nhiên **tìm – xem – chọn – sửa**:

1. **Tiêu đề và một dòng mô tả** cho biết trang dùng để làm gì và quy tắc chính cần nhớ.
2. **Thanh lọc** nằm ngang, gồm các bộ lọc thường dùng nhất như chi nhánh, trạng thái, ô tìm kiếm.
3. **Bảng kết quả** cho phép chọn một dòng; cột tiền được định dạng `6.750.000 đ`, ô trống thay cho giá trị NULL.
4. **Form bên dưới bảng**: khi chưa chọn dòng nào, form ở chế độ Thêm mới; khi chọn một dòng, form được điền sẵn để sửa, kèm nút xoá ghi rõ đối tượng, ví dụ "Xoá chi nhánh CN02".
5. **Thông báo kết quả** xuất hiện sau khi lưu và vẫn còn hiển thị khi trang tải lại.

Trang có nhiều đối tượng cùng loại được chia thành các **thẻ** (tab), chẳng hạn Chi nhánh, Phòng học, Ca học, thay vì thêm mục menu mới; nhờ đó menu vẫn giữ được độ nông. Hình 4.5 minh hoạ khuôn bố cục này trên trang danh mục chi nhánh khi đã chọn chi nhánh CN02.

![Danh mục chi nhánh](images/ch4/03_danh_muc_chi_nhanh.jpg)

*Hình 4.5 – Khuôn bố cục chung trên trang danh mục chi nhánh (tài khoản Quản lý)*

### 4.2.2 Đối chiếu nguyên tắc thiết kế form

*Bảng 4.3 – Đối chiếu nguyên tắc thiết kế form*

| Nguyên tắc | Cách ECMS áp dụng | Minh hoạ |
|---|---|---|
| Bố cục theo nhóm logic, trình tự tự nhiên | Trường được sắp theo thứ tự trên giấy tờ thật: mã, tên, địa chỉ, liên hệ; form dài được chia cột và nhóm trong khung viền. Form phiếu thu đánh số bước: thông tin phiếu (master) rồi đến chi tiết (detail) | Hình 4.5, 4.17 |
| Điều khiển phù hợp kiểu dữ liệu | Ngày dùng ô chọn lịch (dạng `dd/mm/yyyy`); số, tiền, điểm dùng ô số có giới hạn và bước nhảy (điểm từ 0 đến 10, bước 0,25); tập nhỏ cố định dùng nút chọn một; danh mục dùng hộp chọn lấy từ view thay vì gõ mã tay; bật tắt dùng công tắc; ngưỡng và tỷ lệ giảm giá dùng thanh trượt; nhập hàng loạt dùng lưới sửa trực tiếp | Hình 4.12, 4.14, 4.16 |
| Giảm gõ phím, giá trị mặc định hợp lý | Ô tìm học viên chấp nhận tên, số điện thoại hoặc mã; chọn lớp ghi danh thì thành tiền sau giảm giá được tính ngay; điểm danh mặc định Có mặt cho cả lớp, chỉ cần sửa người vắng; phiếu thu tích sẵn mọi khoản còn nợ và điền số tiền bằng số còn nợ | Hình 4.13, 4.14, 4.17 |
| Kiểm tra dữ liệu ở hai lớp | Lớp giao diện kiểm tra định dạng và trường bắt buộc, hiện lỗi ngay dưới ô sai (Hình 4.6). Lớp CSDL kiểm tra bằng CHECK, UNIQUE, khoá ngoại, procedure và trigger – giao diện không thể bỏ qua; lỗi trả về bằng tiếng Việt như "Lớp đã đủ sĩ số" | Hình 4.6, 4.13 |
| Thông báo rõ ràng, đúng chỗ | Lỗi theo trường nằm ngay dưới trường; lỗi nghiệp vụ hiện trong khung đỏ; thành công hiện khung xanh kèm mã vừa tạo, ví dụ "Đã lập phiếu thu PT000502"; biểu tượng dấu hỏi cạnh nhãn giải thích quy tắc nhập ở 10 ô nhập (mã chi nhánh, mã khoá học, tên đăng nhập, mật khẩu, giảm giá…) và 3 nút có tác dụng lớn (sinh buổi học, sinh lại buổi học, tính lại bảng lương) | Hình 4.6, 4.13 |
| Ngăn thao tác sai thay vì báo lỗi sau | Điều khiển không được dùng thì bị khoá thay vì để người dùng thao tác rồi mới báo lỗi: ô mã (khoá chính) không sửa được khi đang sửa bản ghi; khoá học và chi nhánh của lớp đã có học viên không đổi được; tài khoản cấp chi nhánh không chọn được chi nhánh khác; lớp đã điểm danh thì form xếp lịch cố định và nút "Sinh lại buổi học" bị ẩn; nút **Lưu điểm** khoá khi chưa có thay đổi, nút **Lập phiếu thu** khoá khi chưa chọn khoản nào hoặc có dòng nhập sai; lớp đã đầy được đánh dấu "ĐẦY"; mặc định chỉ liệt kê lớp thuộc khoá được đề xuất theo kết quả kiểm tra đầu vào | Hình 4.10, 4.13, 4.15 |
| Xác nhận trước thao tác không hoàn tác được | Mọi nút xoá, huỷ lớp, huỷ đăng ký, cho nhân viên nghỉ đều làm hai bước: bấm nút mở hộp cảnh báo nêu hậu quả, phải bấm **Xác nhận** mới thực hiện (Hình 4.7). Nút Lập phiếu thu gửi kèm một mã yêu cầu, nên bấm hai lần hay trình duyệt gửi lại cũng chỉ tạo **một** phiếu | Hình 4.7 |
| Master – detail | Phiếu thu: một phiếu (master) có nhiều dòng thu cho nhiều đăng ký (detail), tổng phiếu cập nhật tức thời, lưu một lần trong một giao dịch. Hồ sơ học viên: chọn học viên rồi xem các thẻ lớp đã học, kiểm tra đầu vào, học phí. Lớp học: chọn lớp rồi xem lịch cố định và danh sách buổi học | Hình 4.10, 4.11, 4.17 |
| Nhập liệu hàng loạt dạng lưới | Điểm danh và nhập điểm dùng lưới sửa trực tiếp: cột được sửa có biểu tượng bút; cột tính toán (điểm trung bình, xếp loại, chuyên cần) chỉ đọc. Trang điểm danh đếm ngay số học viên theo từng trạng thái; trang nhập điểm cho biết số học viên có thay đổi chưa lưu | Hình 4.14, 4.15 |
| Nhất quán | Cùng vị trí nút, cùng định dạng tiền, cùng quy ước màu (đỏ là cảnh báo, nợ quá hạn) trên mọi trang nhờ dùng chung một thư viện thành phần giao diện | Toàn chương |

Hình 4.6 minh hoạ nguyên tắc kiểm tra dữ liệu ngay tại trường: khi nhấn Lưu với form còn trống, lỗi hiện ngay dưới từng ô ("Mã phải có dạng CN + 2 chữ số", "Tên chi nhánh không được để trống") và dữ liệu chưa hề được gửi xuống CSDL. Hình 4.7 là hộp xác nhận hiện ra khi bấm nút xoá chi nhánh.

![Kiểm tra dữ liệu tại trường](images/ch4/04_kiem_tra_nhap_lieu.jpg)

*Hình 4.6 – Lỗi nhập liệu hiển thị ngay dưới ô tương ứng*

![Hộp xác nhận xoá](images/ch4/21_xac_nhan_xoa.jpg)

*Hình 4.7 – Nút xoá hai bước: phải bấm Xác nhận mới xoá*

### 4.2.3 Ánh xạ giữa form và đối tượng CSDL

Bảng 4.4 cho biết mỗi form đọc dữ liệu từ đâu và ghi dữ liệu qua đâu. Không có form nào thêm, sửa, xoá trực tiếp trên bảng, vì login của ứng dụng bị cấm trên mọi bảng (mục 3.2.2).

*Bảng 4.4 – Ánh xạ giữa form và đối tượng CSDL*

| Nhóm | Form | Đọc từ (view, function) | Ghi qua (procedure) | Bảng và trigger liên quan |
|---|---|---|---|---|
| – | Trang chủ | `vw_SiSoLop`, `vw_HocVien_ChiNhanh`, `vw_CongNoHocVien` | – | – |
| Danh mục | Chi nhánh, phòng, ca học | `vw_DM_ChiNhanh`, `vw_DM_PhongHoc`, `vw_DM_CaHoc`, `vw_NhanVien` | `sp_LuuChiNhanh`, `sp_XoaChiNhanh`, `sp_LuuPhongHoc`, `sp_XoaPhongHoc`, `sp_LuuCaHoc`, `sp_XoaCaHoc` | CHINHANH, PHONGHOC, CAHOC |
| | Nhân viên và giáo viên | `vw_NhanVien`, `vw_ChungChiGV` | `sp_LuuNhanVien`, `sp_XoaNhanVien`, `sp_LuuChungChi`, `sp_XoaChungChi` | NHANVIEN, GIAOVIEN, CHUNGCHI_GV, TAIKHOAN (vai trò theo chức vụ); trigger nhật ký đổi lương |
| Đào tạo | Chương trình và khoá học | `vw_DM_ChuongTrinh`, `vw_DM_KhoaHoc` | `sp_LuuChuongTrinh`, `sp_XoaChuongTrinh`, `sp_LuuKhoaHoc`, `sp_XoaKhoaHoc` | CHUONGTRINH, KHOAHOC |
| | Lớp học | `vw_SiSoLop`, `vw_DM_KhoaHoc`, `vw_NhanVien` | `sp_LuuLopHoc`, `sp_XoaLopHoc`; `sp_CapNhatTrangThaiLop` (sau mỗi lần đăng nhập) | LOPHOC |
| | Xếp lịch và buổi học | `vw_LichHoc`, `vw_BuoiHoc`, `vw_SiSoLop`, `vw_DM_PhongHoc`, `vw_DM_CaHoc` | `sp_XepLichLop`, `sp_XoaLichLop`, `sp_SinhBuoiHoc` | LICHHOC, BUOIHOC; trigger chặn trùng phòng và giáo viên |
| Học viên | Hồ sơ học viên | `vw_HocVien_ChiNhanh`, `vw_DangKyChiTiet`, `vw_BangDiem`, `vw_KiemTraChiTiet` | `sp_TimKiemHocVien`, `sp_LuuHocVien` | HOCVIEN; trigger nhật ký |
| | Kiểm tra đầu vào | `vw_KiemTraChiTiet`, `fn_KyNangKiemTra`, `fn_GoiYKhoaHoc` | `sp_GhiKetQuaKiemTra` | KIEMTRA_DAUVAO (cột XML có lược đồ) |
| | Ghi danh | `vw_HocVien_ChiNhanh`, `vw_DangKyChiTiet`, `vw_SiSoLop`, `vw_KiemTraChiTiet` | `sp_DangKyHoc`, `sp_ChuyenLop`, `sp_HuyDangKy` | DANGKY; trigger kiểm tra sĩ số, cập nhật sĩ số, nhật ký |
| | Lịch học và kết quả của tôi | `fn_LichHocHocVien`, `vw_DangKyChiTiet`, `vw_BangDiem`, `vw_CongNoHocVien` (lọc theo mã học viên của phiên) | – | – |
| Học tập | Điểm danh | `fn_LopCuaGiaoVien`, `vw_BuoiHoc`, `vw_DiemDanh`, `vw_DangKyChiTiet` | `sp_DiemDanhBuoi` (cả lớp dạng JSON) | DIEMDANH, BUOIHOC |
| | Nhập điểm | `fn_LopCuaGiaoVien`, `vw_BangDiem` | `sp_NhapDiem` | DANGKY; trigger xác định kết quả |
| | Cảnh báo chuyên cần | `vw_CanhBao` | `sp_CanhBaoChuyenCan` (cursor), `sp_XuLyCanhBao` | CANHBAO_CHUYENCAN |
| Tài chính | Lập phiếu thu | `vw_HocVien_ChiNhanh`, `vw_CongNoHocVien`, `vw_PhieuThu`, `vw_CTPhieuThu` | `sp_ThuHocPhi` (master kèm chi tiết JSON và mã yêu cầu chống trùng) | PHIEUTHU, CT_PHIEUTHU, DANGKY; trigger tổng tiền, nhật ký |
| | Công nợ | `vw_CongNoHocVien` | – | – |
| Báo cáo | Dashboard | `vw_DoanhThuThang` (indexed view, cho hai chỉ số doanh thu và mốc so sánh của chúng), `vw_BaoCaoDoanhThu`, `vw_HocVien_ChiNhanh`, `vw_SiSoLop`, `vw_BangDiem`, `vw_CongNoHocVien` | – | – |
| | Báo cáo và xuất tệp | `vw_DangKyChiTiet`, `vw_BaoCaoDoanhThu`, `fn_BangDiemLop`, `vw_BangDiem`, `vw_BangLuong`, `vw_CongNoHocVien`, `vw_SiSoLop`, `fn_LopCuaGiaoVien` | `sp_TinhLuongGiaoVien` (cursor) | BANGLUONG |
| Hệ thống | Tài khoản | `vw_TaiKhoan`, `vw_NhanVien` | `sp_TaoTaiKhoan`, `sp_CapNhatTaiKhoan` | TAIKHOAN; trigger nhật ký |
| | Nhật ký hệ thống | `vw_NhatKy` | – (chỉ trigger được ghi) | NHATKY |
| | Đổi mật khẩu | – | `sp_DoiMatKhau` | TAIKHOAN |
| | Đăng nhập | `vw_TaiKhoan` (kiểm tra lại phiên mỗi 60 giây) | `sp_DangNhap` | TAIKHOAN (đếm số lần sai, tạm khoá) |

### 4.2.4 Các form tiêu biểu theo phân hệ

**Danh mục và đào tạo.** Form nhân viên gom thông tin chung và phần riêng của giáo viên (trình độ, đơn giá, chứng chỉ) vào cùng một trang, phản ánh đúng quan hệ chuyên biệt hoá giữa NHANVIEN và GIAOVIEN ở mục 2.1. Kế toán mở được trang này để xem lương nhưng chỉ của chi nhánh mình, và không sửa được. Trang Lớp học có bộ lọc đa chọn theo trạng thái, mặc định chỉ hiện lớp Sắp mở và Đang học; dòng chú thích đầu trang nêu **vòng đời lớp**: Sắp mở → Đang học (hệ thống tự chuyển khi tới ngày khai giảng và lớp đã có học viên) → Đã kết thúc (giáo vụ chọn sau khi chốt điểm). Trang Xếp lịch là ví dụ master – detail ba cấp: chọn lớp, xem lịch cố định của lớp, rồi xem danh sách buổi học được sinh tự động; dòng tóm tắt in đậm khoá học, giáo viên, ngày khai giảng và sĩ số. Một thẻ riêng hiển thị lịch tuần của toàn chi nhánh dạng lưới thứ × ca để tìm phòng trống.

![Nhân viên và giáo viên](images/ch4/05_nhan_vien.jpg)

*Hình 4.8 – Danh mục nhân viên và giáo viên (tài khoản Quản lý)*

![Lớp học](images/ch4/06_lop_hoc.jpg)

*Hình 4.9 – Danh sách lớp học, vòng đời lớp và form mở lớp mới (tài khoản Giáo vụ)*

![Xếp lịch và buổi học](images/ch4/07_xep_lich.jpg)

*Hình 4.10 – Lịch cố định và danh sách buổi học của một lớp đã điểm danh (tài khoản Giáo vụ)*

**Học viên.** Trang hồ sơ học viên dùng procedure tìm kiếm nhiều tiêu chí, phân trang 15 dòng; câu mô tả đầu trang nhắc người dùng rằng dữ liệu đã được lọc theo chi nhánh. Chọn một học viên thì các thẻ lớp đã học và điểm, kiểm tra đầu vào, học phí và sửa hồ sơ hiện ngay bên dưới. Trang kiểm tra đầu vào là form nhập **dữ liệu XML**: bốn kỹ năng, mỗi kỹ năng gồm điểm và nhận xét; procedure dựng tài liệu XML và CSDL kiểm tra theo lược đồ, nên điểm ngoài khoảng 0 – 10 hay thiếu kỹ năng đều bị từ chối. Thẻ "Xem chi tiết" đọc ngược lại từ XML và vẽ biểu đồ điểm từng kỹ năng. Trang ghi danh hiển thị kết quả kiểm tra gần nhất cùng khoá được đề xuất và mặc định chỉ liệt kê các lớp phù hợp; công tắc "Chỉ hiện lớp của khoá đề xuất" cho phép bỏ lọc khi cần.

![Hồ sơ học viên](images/ch4/08_ho_so_hoc_vien.jpg)

*Hình 4.11 – Tìm kiếm, phân trang và xem chi tiết hồ sơ học viên (tài khoản Giáo vụ)*

![Kiểm tra đầu vào](images/ch4/09_kiem_tra_dau_vao.jpg)

*Hình 4.12 – Form nhập kết quả kiểm tra đầu vào (dữ liệu XML)*

![Ghi danh](images/ch4/10_ghi_danh.jpg)

*Hình 4.13 – Ghi danh với khoá học được đề xuất từ kết quả kiểm tra (tài khoản Giáo vụ)*

**Học tập.** Hai lưới nhập hàng loạt phục vụ giáo viên: điểm danh cả lớp trong một lần lưu và nhập điểm giữa kỳ, cuối kỳ. Danh sách lớp chỉ gồm các lớp giáo viên phụ trách, và trang điểm danh chỉ liệt kê lớp ở trạng thái Đang học. Ở trang điểm danh, buổi đã điểm danh được đánh dấu riêng; chỉ cột Trạng thái và Ghi chú được sửa. Ở trang nhập điểm, điểm trung bình được tính theo công thức 0,4 × GK + 0,6 × CK và kết quả Đạt khi điểm trung bình từ 5 trở lên – các giá trị này do cột tính toán và trigger quyết định, giao diện chỉ hiển thị lại; xoá trắng một ô rồi lưu để huỷ điểm nhập nhầm. Trang cảnh báo chuyên cần gọi procedure dùng cursor (mục 3.3.4) theo ngưỡng chọn bằng thanh trượt, phân mức Nghiêm trọng (vắng trên 30%) và Nhắc nhở, kèm số điện thoại học viên và họ tên phụ huynh để liên hệ.

![Điểm danh](images/ch4/11_diem_danh.jpg)

*Hình 4.14 – Điểm danh cả lớp trên lưới (tài khoản Giáo viên)*

![Nhập điểm](images/ch4/12_nhap_diem.jpg)

*Hình 4.15 – Nhập điểm giữa kỳ, cuối kỳ (tài khoản Giáo viên)*

![Cảnh báo chuyên cần](images/ch4/13_canh_bao.jpg)

*Hình 4.16 – Danh sách cảnh báo chuyên cần sau khi quét (tài khoản Giáo vụ, phạm vi chi nhánh CN01)*

**Tài chính.** Phiếu thu là ví dụ master – detail đầy đủ nhất: phần master gồm học viên, hình thức thanh toán, ghi chú; phần detail là lưới các đăng ký còn nợ, mọi khoản được **tích sẵn** với số tiền bằng số còn nợ – người dùng bỏ tích khoản chưa thu hoặc sửa cột "Thu lần này" để thu một phần; khoản quá hạn có dấu cảnh báo. Tổng phiếu được tính ngay trên màn hình để người dùng đối chiếu, nhưng số chính thức do trigger cập nhật trong CSDL. Lưu xong, hệ thống báo "Đã lập phiếu thu PTxxxxxx" và hiện nút in phiếu thu PDF (Hình 4.22). Trang công nợ đặt ba chỉ số tóm tắt ở trên cùng và tô màu theo mức độ – đỏ đậm khi quá hạn trên 30 ngày, đỏ nhạt khi đã quá hạn, vàng khi chưa đóng đồng nào – theo nguyên tắc làm nổi bật ngoại lệ.

![Lập phiếu thu](images/ch4/14_phieu_thu.jpg)

*Hình 4.17 – Lập phiếu thu master – detail (tài khoản Kế toán)*

![Công nợ học phí](images/ch4/14b_cong_no.jpg)

*Hình 4.18 – Theo dõi công nợ học phí (tài khoản Kế toán)*

**Hệ thống.** Trang tài khoản chỉ Quản lý thấy, hiển thị vai trò, chi nhánh, trạng thái, thời điểm hết tạm khoá, số lần đăng nhập sai và lần đăng nhập cuối; mật khẩu không bao giờ được hiển thị vì CSDL chỉ lưu giá trị băm. Vai trò của tài khoản nhân viên không sửa trực tiếp mà luôn đi theo chức vụ: đổi chức vụ ở trang Nhân viên thì vai trò đổi theo, và phiên đang mở của người đó bị đăng xuất. Đặt lại mật khẩu đồng thời gỡ tạm khoá. Trang nhật ký là màn hình **chỉ đọc**: dữ liệu chỉ do trigger ghi vào. Mỗi dòng nhật ký có cả tài khoản ứng dụng (lấy từ ngữ cảnh phiên) lẫn login SQL – nhờ đó trả lời được câu hỏi "ai thật sự đã thao tác" dù mọi người dùng web cùng kết nối bằng một login. Chọn một dòng để xem từng trường trước và sau khi thay đổi.

![Tài khoản](images/ch4/17_tai_khoan.jpg)

*Hình 4.19 – Quản lý tài khoản người dùng (tài khoản Quản lý)*

![Nhật ký hệ thống](images/ch4/18_nhat_ky.jpg)

*Hình 4.20 – Nhật ký thay đổi dữ liệu và chi tiết trước – sau của một dòng*

## 4.3 Thiết kế báo cáo và dashboard

### 4.3.1 Cấu trúc một báo cáo

Mọi báo cáo được sinh bởi một bộ dựng dùng chung: ReportLab với phông chữ DejaVu hỗ trợ tiếng Việt cho PDF, openpyxl cho Excel và python-docx cho Word. Bộ dựng tổ chức báo cáo theo đúng các vùng của một report theo lý thuyết môn học (Bảng 4.5):

*Bảng 4.5 – Các vùng của một báo cáo ECMS*

| Vùng | Nội dung trong ECMS |
|---|---|
| Report Header | Tên trung tâm, tên báo cáo và dòng tham số, ví dụ "Từ 01/01/2026 đến 25/10/2026" hoặc "Lớp TC650-2501 – TOEIC 650" |
| Page Header | Dòng tiêu đề cột, được lặp lại ở đầu mỗi trang |
| Group Header và Group Footer | Khi có cột phân nhóm: dòng tên nhóm ở đầu, dòng "Cộng …" (tổng phụ) và các dòng thống kê của nhóm (Trung bình, Cao nhất…) ở cuối mỗi nhóm |
| Detail | Mỗi dòng dữ liệu; cột tiền và số căn phải, định dạng `1.234.000 đ`, ngày dạng `dd/mm/yyyy`; ô chữ dài tự xuống dòng trong cột; các dòng xen kẽ màu nền, dòng thoả điều kiện được tô màu |
| Report Footer | Dòng TỔNG CỘNG, các dòng Trung bình, Thấp nhất, Cao nhất của toàn báo cáo và số dòng |
| Page Footer | Thời điểm in và "Trang X / Y" |

Để in được "Trang X / Y" cần biết tổng số trang trước khi vẽ chân trang. Bộ dựng giải quyết bằng một lớp canvas riêng: trong lúc dàn trang, mỗi trang được giữ lại chưa ghi ra tệp; khi dàn xong toàn bộ, tổng số trang đã biết, canvas mới vẽ chân trang cho từng trang rồi ghi tệp. Báo cáo vì vậy chỉ dàn trang một lần.

**Khổ giấy.** Báo cáo dạng bảng mặc định in **A4 ngang** để đủ chỗ cho nhiều cột; báo cáo ít cột như doanh thu theo chi nhánh in **A4 dọc** – hướng giấy do người viết báo cáo chọn cho từng loại, không tự động. Nếu tổng độ rộng cột vượt khổ giấy, các cột được co lại theo tỷ lệ. Phiếu thu là báo cáo dạng biểu mẫu nên in **A5 ngang**, bằng nửa tờ A4 như phiếu thu giấy.

**Ba định dạng xuất.** Mỗi báo cáo dạng bảng tải được ở ba định dạng, phục vụ ba nhu cầu khác nhau (Bảng 4.6). Quy tắc định dạng có điều kiện viết một lần dưới dạng một hàm nhận một dòng dữ liệu và trả về màu, rồi được áp dụng giống nhau trên màn hình và trong cả ba loại tệp.

*Bảng 4.6 – So sánh ba định dạng xuất báo cáo*

| Đặc điểm | PDF | Excel | Word |
|---|---|---|---|
| Mục đích | In, lưu trữ, gửi đi – không sửa được | Tiếp tục tính toán, lọc, sắp xếp | Chỉnh sửa câu chữ, ký duyệt |
| Report Header, dòng tham số | Có | Có (kèm thời điểm in) | Có |
| Tiêu đề cột lặp lại mỗi trang | Có | Có (vùng in lặp dòng tiêu đề) | Có (dòng tiêu đề bảng lặp lại) |
| Tổng phụ theo nhóm | Có | – | – |
| Tổng cộng | Số đã tính | Công thức `SUM` | Số đã tính |
| Trung bình, thấp nhất, cao nhất | 4 báo cáo | Công thức `AVERAGE`, `MIN`, `MAX` ở 2 báo cáo | – |
| Định dạng có điều kiện | Có | Có | Có |
| Khổ giấy và số trang | A4 ngang hoặc dọc, "Trang X / Y" | Trang in A4 ngang, vừa một trang bề ngang, chân trang "Trang X / Y" | A4 ngang, trường `PAGE` / `NUMPAGES` |
| Thêm cho người dùng | – | Cố định dòng tiêu đề, bộ lọc tự động, báo cáo công nợ có thêm trang tính chi tiết | – |

Hình 4.21 là báo cáo doanh thu theo chi nhánh và tháng, thể hiện đủ các vùng: Report Header, Group Header là tên chi nhánh, các dòng Detail, Group Footer "Cộng ECMS Thủ Đức 459.525.000 đ" cùng hai dòng Trung bình và Cao nhất của nhóm, Report Footer "TỔNG CỘNG 1.161.327.000 đ" và Page Footer "Trang 1 / 1". Hình 4.22 là phiếu thu – một báo cáo dạng biểu mẫu (form report) khổ A5 gồm thông tin chi nhánh, số phiếu, chi tiết từng lớp, tổng cộng, số tiền bằng chữ và chỗ ký.

![Báo cáo doanh thu PDF](images/ch4/20_pdf_doanh_thu.jpg)

*Hình 4.21 – Báo cáo doanh thu có nhóm, tổng phụ, thống kê và tổng cộng (A4 dọc)*

![Phiếu thu PDF](images/ch4/19_pdf_phieu_thu.jpg)

*Hình 4.22 – Phiếu thu in dạng biểu mẫu (A5 ngang)*

### 4.3.2 Phân loại báo cáo

Trang "Báo cáo & xuất file" gom các báo cáo theo đúng ba loại của môn học: định kỳ, theo yêu cầu và tổng hợp, cộng thêm báo cáo dạng biểu mẫu (Bảng 4.7). Mỗi vai trò chỉ thấy báo cáo của mình; giáo viên chỉ thấy các lớp mình dạy nhờ hàm `fn_LopCuaGiaoVien` và danh sách lớp in cho giáo viên được bỏ các cột tài chính; tài khoản cấp chi nhánh chỉ thấy số liệu của chi nhánh mình.

*Bảng 4.7 – Phân loại báo cáo của ECMS*

| Báo cáo | Loại | Tham số | Nguồn dữ liệu | Định dạng | Vai trò |
|---|---|---|---|---|---|
| Danh sách học viên theo lớp | Định kỳ – đầu khoá | Lớp | `vw_DangKyChiTiet` | PDF, Excel, Word | QL, GVụ, GV |
| Doanh thu theo chi nhánh và tháng | Định kỳ – tháng, quý | Khoảng ngày | `vw_BaoCaoDoanhThu` | PDF, Excel, Word | QL, KT |
| Bảng lương giáo viên | Định kỳ – tháng | Tháng | `sp_TinhLuongGiaoVien`, `vw_BangLuong` | PDF, Excel, Word | QL, KT |
| Bảng điểm lớp | Theo yêu cầu | Lớp | `fn_BangDiemLop` (xếp hạng bằng `RANK()`) | PDF, Excel, Word | QL, GVụ, GV |
| Lịch sử học tập của học viên | Theo yêu cầu | Học viên | `vw_DangKyChiTiet`, `vw_BangDiem` | PDF, Excel, Word | QL, GVụ |
| Công nợ học viên | Theo yêu cầu, ngoại lệ | Ngưỡng nợ | `vw_CongNoHocVien` | PDF, Excel (2 trang tính), Word | QL, KT, GVụ |
| Tổng hợp theo chương trình | Tổng hợp | Năm | `vw_SiSoLop`, `vw_BaoCaoDoanhThu`, `vw_BangDiem` | PDF, Excel, Word | QL, KT |
| Phiếu thu | Biểu mẫu | Số phiếu | `vw_PhieuThu`, `vw_CTPhieuThu` | PDF (A5) | QL, KT |
| Dashboard | Tổng hợp, tương tác | Chi nhánh, năm | `vw_DoanhThuThang` và các view báo cáo | Xem trên màn hình | QL, KT |

Người dùng chọn báo cáo (tên báo cáo có ghi kèm loại), nhập tham số, xem trước trên màn hình rồi tải về dạng PDF, Excel hoặc Word (Hình 4.23). Bảng điểm trên màn hình được tô màu giống hệt trong tệp xuất: xanh cho học viên Giỏi và Xuất sắc, đỏ cho học viên không đạt hoặc chuyên cần dưới 80%.

![Báo cáo và xuất file](images/ch4/15_bao_cao_danh_sach.jpg)

*Hình 4.23 – Trang chọn báo cáo, nhập tham số, xem trước có tô màu và tải tệp (tài khoản Quản lý)*

### 4.3.3 Dashboard

Dashboard là tầng **tri thức** trong mô hình DIKW (mục 1.6.2): từ dữ liệu giao dịch, hệ thống tổng hợp thành các chỉ số giúp quản lý ra quyết định. Dashboard gồm ba phần:

- **Hàng chỉ số (KPI)**: sáu chỉ số, mỗi chỉ số đi kèm một mốc so sánh phù hợp với bản chất của nó (Bảng 4.8) – mũi tên xanh là tốt, đỏ là cần chú ý.
- **Biểu đồ**: doanh thu theo tháng dạng cột xếp chồng theo chi nhánh kèm đường luỹ kế trên trục phụ; cơ cấu doanh thu theo chương trình dạng vành khuyên; tỷ lệ lấp đầy theo lớp dạng cột ngang có vạch mục tiêu 80%; số học viên mới theo tháng dạng đường; tương quan giữa chuyên cần và điểm trung bình của các lớp đã kết thúc trong năm dạng bong bóng, kích thước bong bóng là sĩ số và màu là tỷ lệ đạt.
- **Bộ lọc** chi nhánh và năm ở đầu trang; tài khoản cấp chi nhánh bị khoá ở chi nhánh của mình.

*Bảng 4.8 – Các chỉ số trên dashboard và mốc so sánh*

| Chỉ số | Mốc so sánh | Nguồn |
|---|---|---|
| Học viên mới tháng này | Tháng trước | `vw_HocVien_ChiNhanh` |
| Doanh thu tháng này | Tháng trước | `vw_DoanhThuThang` |
| Doanh thu năm đến tháng hiện tại | Cùng kỳ năm trước | `vw_DoanhThuThang` |
| Tỷ lệ lấp đầy các lớp đang mở | Mục tiêu 80% | `vw_SiSoLop` |
| Tỷ lệ chuyên cần các lớp đang học | Mục tiêu 80% | `vw_BangDiem` |
| Công nợ hiện tại | Phần đã quá hạn (màu đỏ; không hiện khi không có khoản quá hạn) | `vw_CongNoHocVien` |

Hai chỉ số doanh thu (tháng này, luỹ kế năm) cùng hai mốc so sánh (tháng trước, cùng kỳ năm trước) được đọc từ indexed view `vw_DoanhThuThang` – view đã được SQL Server tổng hợp sẵn theo tháng và chi nhánh, nên các ô KPI vẫn tải nhanh khi số phiếu thu tăng lên. Các biểu đồ doanh thu cần chi tiết theo chương trình nên đọc từ view thường `vw_BaoCaoDoanhThu`.

![Dashboard](images/ch4/16_dashboard.jpg)

*Hình 4.24 – Dashboard toàn trung tâm năm 2026 (tài khoản Quản lý)*

### 4.3.4 Đối chiếu nguyên tắc thiết kế báo cáo

*Bảng 4.9 – Đối chiếu nguyên tắc thiết kế báo cáo*

| Nguyên tắc | Cách ECMS áp dụng |
|---|---|
| Đúng người, đúng lúc, đúng mức chi tiết | Báo cáo được lọc theo vai trò và chi nhánh; nhân viên tác nghiệp xem chi tiết (danh sách lớp, bảng điểm), quản lý xem tổng hợp (dashboard, tổng hợp theo chương trình) |
| Tiêu đề và tham số rõ ràng | Mọi báo cáo có tên in hoa và dòng tham số ngay bên dưới; tên tệp tải về mang tên báo cáo và tham số, ví dụ `BangDiem_TC650-2501.pdf` |
| Làm nổi bật ngoại lệ | Công nợ quá hạn tô đỏ; bảng điểm và lịch sử học tập tô đỏ học viên không đạt hoặc chuyên cần dưới 80%, tô xanh học viên Giỏi và Xuất sắc; màu được giữ nguyên trong PDF, Excel và Word; cảnh báo chuyên cần chia mức độ |
| Tổng phụ, tổng cộng và thống kê | Group Footer và Report Footer trong PDF; dòng Trung bình, Thấp nhất, Cao nhất cho điểm, lương, doanh thu; dòng tổng và thống kê bằng công thức trong Excel |
| Định dạng số nhất quán | Tiền dạng `1.234.000 đ`, số căn phải, ngày dạng `dd/mm/yyyy` – dùng chung một hàm định dạng cho giao diện và các tệp xuất |
| Phân trang, đánh số trang | Tiêu đề cột lặp lại ở mỗi trang; "Trang X / Y" ở chân trang của cả ba định dạng |
| Chọn khổ giấy theo nội dung | A4 ngang cho bảng nhiều cột, A4 dọc cho bảng ít cột, A5 cho phiếu thu |
| Chọn đúng loại biểu đồ | Xu hướng theo thời gian dùng cột và đường; cơ cấu dùng vành khuyên; so sánh giữa các lớp dùng cột ngang; tương quan hai chỉ số dùng bong bóng |

### 4.3.5 So sánh với Crystal Report

Bài thực hành 4 của môn học thiết kế báo cáo bằng Crystal Report – công cụ thiết kế trực quan, kéo thả trường dữ liệu vào các vùng của báo cáo. ECMS chạy trên cả macOS và Docker nên không dùng được Crystal Report (chỉ chạy trên Windows), và chọn cách **viết báo cáo bằng mã** trên cùng các khái niệm. Bảng 4.10 đối chiếu hai cách làm.

*Bảng 4.10 – Đối chiếu Crystal Report với bộ dựng báo cáo của ECMS*

| Khái niệm | Crystal Report | ECMS |
|---|---|---|
| Các vùng báo cáo | Report Header, Page Header, Group Header, Details, Group Footer, Report Footer, Page Footer trong Section Expert | Cùng các vùng đó, sinh bởi một hàm dựng dùng chung (Bảng 4.5) |
| Nguồn dữ liệu | Kết nối bảng hoặc view, liên kết trong Database Expert | Chỉ đọc view, function, procedure; câu truy vấn tham số hoá |
| Tham số | Parameter Field, hộp thoại hỏi khi mở báo cáo | Ô nhập trên trang (lớp, khoảng ngày, ngưỡng nợ…) và dòng tham số in trên báo cáo |
| Nhóm, tổng phụ | Group Expert, Summary, Running Total | Tham số cột phân nhóm, danh sách cột cộng và danh sách thống kê (trung bình, thấp nhất, cao nhất) |
| Trường đặc biệt "Page N of M" | Special Field có sẵn | Canvas giữ trang và vẽ chân trang khi đã biết tổng số trang |
| Định dạng có điều kiện | Highlighting Expert, công thức trong Format Editor | Một hàm trả về màu cho từng dòng, áp dụng cho màn hình và cả ba loại tệp |
| Xuất tệp | PDF, Excel, Word, RTF… | PDF, Excel (giữ công thức), Word |
| Thiết kế giao diện báo cáo | Trình thiết kế trực quan, xem trước ngay | Viết mã; xem trước trên trang web trước khi tải |
| Quản lý phiên bản, kiểm thử | Tệp `.rpt` nhị phân, khó so sánh thay đổi | Mã nguồn trong Git; kiểm thử tự động sinh mọi báo cáo ở cả ba định dạng sau mỗi lần sửa |
| Môi trường chạy | Windows, cần bộ runtime của Crystal | Mọi hệ điều hành có Python |

Đổi lại, cách viết bằng mã thiếu trình thiết kế trực quan: muốn đổi vị trí một cột hay cỡ chữ phải sửa mã thay vì kéo thả, nên không phù hợp cho người dùng nghiệp vụ tự thiết kế báo cáo mới.

## 4.4 Đánh giá

**Kết quả đạt được.** Ứng dụng có menu hai cấp theo vai trò, mọi chức năng đến được bằng một cú nhấp; 21 trang chức năng cộng trang đăng nhập dùng chung một khuôn bố cục; dữ liệu được kiểm tra ở hai lớp giao diện và CSDL; thao tác xoá có hộp xác nhận, lập phiếu thu chống bấm trùng; phạm vi chi nhánh được áp dụng nhất quán từ giao diện xuống procedure; phiên đăng nhập được kiểm tra lại định kỳ. Có hai form master – detail và hai lưới nhập hàng loạt; chín báo cáo thuộc đủ các loại định kỳ, theo yêu cầu, tổng hợp và biểu mẫu, trong đó bảy báo cáo dạng bảng xuất được PDF, Excel và Word với định dạng có điều kiện và dòng thống kê; một dashboard KPI tương tác. Bộ kiểm thử tự động mở **mọi trang với từng vai trò** và sinh **mọi báo cáo** ở cả ba định dạng để bảo đảm không trang nào lỗi sau mỗi lần thay đổi (mục 6.1.3).

**Hạn chế.**

- Streamlit tải lại toàn trang sau mỗi tương tác nên khi thao tác nhanh liên tục có độ trễ nhỏ.
- Chưa có **phím tắt** riêng (như Ctrl+S để lưu, F2 để sửa): người dùng chỉ có các phím mặc định của trình duyệt – Enter để gửi form và ô tìm kiếm, Tab để chuyển ô, phím mũi tên để di chuyển trong lưới. Streamlit không cung cấp cơ chế gán phím tắt cho nút.
- Lưới dữ liệu trên màn hình hiển thị ngày theo dạng `yyyy-mm-dd`; dạng `dd/mm/yyyy` mới chỉ có ở ô nhập ngày và trong các tệp xuất.
- Báo cáo được thiết kế bằng mã, chưa có trình thiết kế trực quan như Crystal Report; dashboard chỉ xem trên màn hình, chưa xuất được PDF.
- Giao diện chưa được tối ưu cho điện thoại; chưa hỗ trợ in nhiều phiếu thu cùng lúc.

## 4.5 Tiểu kết chương

Chương 4 đã trình bày tầng giao diện của ECMS theo ba nhóm nguyên tắc menu, form và báo cáo của môn học, với mỗi nguyên tắc đều có minh chứng cụ thể trên ứng dụng và đối chiếu với Crystal Report của bài thực hành. Điểm nhất quán xuyên suốt là giao diện chỉ làm nhiệm vụ trình bày và thu thập thông tin, còn mọi quy tắc nghiệp vụ, phân quyền và tính toán đều nằm trong CSDL đã xây dựng ở Chương 2 và Chương 3. Nhờ vậy giao diện có thể thay thế bằng công nghệ khác trong tương lai mà không phải viết lại phần nghiệp vụ.
