# Chương 4. Trình bày thông tin

Chương 2–3 xây dựng CSDL và lớp xử lý (view, procedure, trigger, phân quyền). Chương này trình bày **tầng giao diện** – nơi người dùng thực sự tiếp xúc với thông tin – và đối chiếu từng nguyên tắc thiết kế **Menu, Form, Report** của Chương 4 với ứng dụng web ECMS.

Ứng dụng viết bằng **Python + Streamlit** ([`app/`](../app/)), kết nối SQL Server qua `pyodbc` bằng login riêng `ecms_app` (chỉ có quyền `EXECUTE` procedure và `SELECT` view – mục 3.2.2). Ba nguyên tắc kỹ thuật xuyên suốt:

1. **Giao diện chỉ gọi view / function / procedure**, không truy cập bảng gốc và không ghép chuỗi SQL (mọi tham số dùng `?`) – nghiệp vụ và ràng buộc nằm trong CSDL, giao diện không thể "đi vòng".
2. **Mỗi kết nối gắn ngữ cảnh người dùng** qua `sp_set_session_context` (tài khoản, chi nhánh, vai trò, mã NV/HV) → view tự lọc dữ liệu theo chi nhánh (row-level security), trigger ghi đúng người thao tác vào nhật ký.
3. **Lỗi nghiệp vụ hiển thị bằng tiếng Việt** đúng thông báo `THROW 500xx` của procedure/trigger (`core/db.py` rút gọn thông báo ODBC).

Ảnh chụp trong chương lấy từ dữ liệu mẫu (ngày tham chiếu 15/10/2026), đăng nhập bằng tài khoản demo `quanly` (Quản lý – toàn trung tâm) trừ khi ghi chú khác.

## 4.1 Thiết kế Menu

### 4.1.1 Cây chức năng

Toàn bộ menu khai báo **tại một chỗ** – danh sách `MENU` trong [`app/core/menu.py`](../app/core/menu.py), mỗi dòng gồm *(nhóm, file trang, tiêu đề, icon, vai trò được thấy)*. `main.py` dựng thanh điều hướng (`st.navigation`) từ danh sách này theo vai trò của người đăng nhập; sơ đồ dưới được sinh tự động từ cùng danh sách nên luôn khớp với ứng dụng.

![Hình 4.1 – Cây chức năng ECMS và vai trò được thấy từng mục](../docs/design/menu-tree.png)

*Hình 4.1 – Cây chức năng (nguồn: [`docs/design/menu-tree.dot`](../docs/design/menu-tree.dot), bản chỉnh sửa được: `menu-tree.drawio`). QL = Quản lý, GVụ = Giáo vụ, KT = Kế toán, GV = Giáo viên, HV = Học viên.*

### 4.1.2 Đối chiếu nguyên tắc thiết kế menu

| Nguyên tắc (Chương 4) | Cách ECMS áp dụng | Minh hoạ |
|---|---|---|
| **Rộng và nông** (breadth over depth) – ít cấp, mỗi cấp vừa đủ lựa chọn | Đúng **2 cấp**: nhóm → chức năng. 8 nhóm, mỗi nhóm 1–4 mục; không có menu con lồng nhau. Mọi chức năng đến được bằng **1 cú nhấp** từ thanh bên. | Hình 4.1, 4.3 |
| **Nhóm theo nghiệp vụ**, thứ tự theo luồng công việc | Nhóm bám quy trình ở mục 1.4: *Danh mục → Đào tạo → Học viên → Học tập → Tài chính → Báo cáo → Hệ thống*; trong nhóm cũng theo thứ tự thao tác (mở lớp → xếp lịch; kiểm tra đầu vào → ghi danh). | Hình 4.1 |
| **Tên rõ nghĩa, nhất quán** | Tiêu đề là danh từ nghiệp vụ quen thuộc ("Lập phiếu thu", "Công nợ"), trùng với tiêu đề trang; mỗi mục có icon Material cùng phong cách. | Hình 4.3 |
| **Chỉ hiện chức năng được phép** (menu theo vai trò) | `menu_for(role)` lọc theo cột vai trò; số mục mỗi vai trò thấy ở bảng 4.1. Mục không có quyền **bị ẩn hẳn**, không chỉ làm mờ. | Hình 4.3 vs 4.4 |
| **Chặn cả đường vòng** | Ẩn menu chưa đủ: đầu mỗi trang gọi `auth.require_role(...)` – gõ thẳng URL trang không được phép sẽ nhận "Bạn không có quyền truy cập chức năng này". Lớp cuối cùng là quyền SQL của role (`r_GiaoVien` … – mục 3.2.2). | – |
| **Cho biết đang ở đâu** (trạng thái active) | Mục đang mở được tô nền đậm trên thanh bên; tiêu đề trang lặp lại tên mục; cuối thanh bên luôn hiện *họ tên · vai trò · chi nhánh · phạm vi*. | Hình 4.6, 4.13 (mục đang mở được tô) |
| **Lối thoát rõ ràng** | Nút "Đăng xuất" cố định cuối thanh bên; trang chủ là điểm xuất phát cho mọi vai trò. | Hình 4.3 |
| **Dễ mở rộng** | Thêm chức năng = tạo file trong `app/pages/` + thêm 1 dòng vào `MENU`; trang chưa có file tự ẩn. | – |

*Bảng 4.1 – Độ rộng menu theo vai trò*

| Vai trò | Số nhóm | Số chức năng | Các nhóm thấy được |
|---|:-:|:-:|---|
| Quản lý | 8 | 20 | tất cả |
| Giáo vụ | 7 | 11 | Đào tạo, Học viên, Học tập (cảnh báo), Tài chính (công nợ), Báo cáo, Hệ thống |
| Kế toán | 5 | 7 | Danh mục (nhân viên), Tài chính, Báo cáo, Hệ thống |
| Giáo viên | 4 | 6 | Học tập, Báo cáo, Hệ thống |
| Học viên | 3 | 3 | Trang chủ, "Lịch học & kết quả của tôi", Đổi mật khẩu |

![Hình 4.2 – Màn hình đăng nhập](images/ch4/01_dang_nhap.jpg)

*Hình 4.2 – Đăng nhập: chỉ 2 ô và 1 nút; mật khẩu kiểm tra bằng `sp_DangNhap` (băm SHA2_256 + salt, khoá tài khoản sau 5 lần sai). Khung "Tài khoản demo" phục vụ buổi demo, cần gỡ khi triển khai thật.*

![Hình 4.3 – Trang chủ của Quản lý: menu đầy đủ 8 nhóm](images/ch4/02_trang_chu.jpg)

*Hình 4.3 – Trang chủ vai trò Quản lý: thanh bên đủ 8 nhóm; nội dung là các chỉ số tóm tắt theo phạm vi chi nhánh.*

![Hình 4.4 – Trang chủ của Giáo viên: menu rút gọn còn 4 nhóm](images/ch4/02b_trang_chu_giao_vien.jpg)

*Hình 4.4 – Cùng ứng dụng, đăng nhập `giaovien`: menu chỉ còn Học tập, Báo cáo, Hệ thống; trang chủ hiện các lớp của chi nhánh CN01.*

## 4.2 Thiết kế Form

### 4.2.1 Bố cục chung của một trang nghiệp vụ

Mọi trang danh mục/nghiệp vụ dùng chung một khuôn (hàm dùng chung trong [`app/core/ui.py`](../app/core/ui.py)), đi từ **tìm → xem → chọn → sửa**:

1. **Tiêu đề + một dòng mô tả** nói trang làm gì và ràng buộc nào CSDL sẽ kiểm tra (`ui.header`).
2. **Thanh lọc** ngang: các bộ lọc thường dùng nhất (chi nhánh, trạng thái, ô tìm kiếm).
3. **Bảng kết quả** có chọn một dòng (`ui.table`): cột tiền định dạng `6.750.000 đ`, ngày `dd/mm/yyyy`, ô rỗng thay cho `NULL`.
4. **Form bên dưới**: chưa chọn dòng → "Thêm mới"; chọn một dòng → form điền sẵn để sửa, kèm nút xoá ghi rõ đối tượng ("Xoá chi nhánh CN02").
5. **Thông báo kết quả** (`ui.flash`) xuất hiện sau khi lưu, kể cả khi trang tải lại.

Trang có nhiều đối tượng cùng loại chia **tab** (ví dụ Chi nhánh / Phòng học / Ca học), thay vì thêm mục menu – giữ menu nông.

![Hình 4.5 – Danh mục chi nhánh: bảng + form thêm/sửa, chia tab](images/ch4/03_danh_muc_chi_nhanh.jpg)

*Hình 4.5 – Khuôn trang danh mục: tab đối tượng, bảng chọn dòng, form "Thêm chi nhánh" phía dưới.*

### 4.2.2 Đối chiếu nguyên tắc thiết kế form

| Nguyên tắc (Chương 4) | Cách ECMS áp dụng | Minh hoạ |
|---|---|---|
| **Bố cục theo nhóm logic, trình tự tự nhiên** | Trường sắp theo thứ tự trên giấy tờ thật: mã → tên → địa chỉ → liên hệ; form dài chia cột (`st.columns`), nhóm bằng khung viền. Form phiếu thu đánh số bước *1. Thông tin phiếu (master) → 2. Chi tiết (detail)*. | 4.5, 4.16 |
| **Control phù hợp kiểu dữ liệu** | Ngày → `date_input` (lịch, định dạng dd/mm/yyyy); số/tiền/điểm → `number_input` có min/max/bước (điểm 0–10 bước 0,25); tập nhỏ cố định → `radio` (hình thức thi Tại trung tâm/Online); danh mục → `selectbox` lấy từ view (không gõ mã tay); bật/tắt → `toggle`; ngưỡng → `slider`; nhập hàng loạt → bảng sửa trực tiếp (`data_editor`). | 4.11, 4.13, 4.15 |
| **Giảm gõ phím, giá trị mặc định hợp lý** | Ô tìm học viên chấp nhận tên, SĐT hoặc mã; chọn lớp → tự điền khoá, học phí, chỗ trống; điểm danh mặc định "Có mặt" cho cả lớp, chỉ sửa người vắng; phiếu thu tự tích sẵn các khoản còn nợ và điền "Thu lần này" = số còn nợ. | 4.12, 4.13, 4.16 |
| **Kiểm tra dữ liệu 2 lớp** | *Lớp giao diện*: `ui.FieldErrors` kiểm tra định dạng/bắt buộc và hiện lỗi **ngay dưới ô sai** (hình 4.6). *Lớp CSDL*: CHECK/UNIQUE/FK, procedure và trigger – giao diện không thể bỏ qua; lỗi trả về bằng tiếng Việt (ví dụ "Lớp đã đủ sĩ số", "Học viên chưa hoàn thành khoá tiên quyết"). | 4.6, 4.12 |
| **Thông báo rõ ràng, đúng chỗ** | Lỗi theo trường nằm dưới trường; lỗi nghiệp vụ hiện khung đỏ trên nút lưu; thành công hiện khung xanh kèm mã vừa tạo ("Đã lập phiếu PT000527"); `help=` (biểu tượng ?) giải thích quy tắc ngay trên nhãn (16 chỗ). | 4.6, 4.16 |
| **Ngăn thao tác sai thay vì báo lỗi sau** | Nút "Lưu" bị khoá (`disabled`) khi chưa có thay đổi (21 chỗ); lớp đã đầy hiện "ĐẦY"; chỉ liệt kê lớp thuộc khoá đề xuất theo kết quả kiểm tra đầu vào (có thể tắt); học viên chỉ chọn được trong phạm vi chi nhánh mình. | 4.12, 4.14 |
| **Master–detail** | *Phiếu thu*: một phiếu (master `PHIEUTHU`) – nhiều dòng thu cho nhiều đăng ký (detail `CT_PHIEUTHU`), tổng phiếu cập nhật tức thời; lưu một lần bằng `sp_ThuHocPhi` nhận danh sách chi tiết dạng JSON, trong **một giao dịch**. *Hồ sơ học viên*: chọn học viên → các tab đăng ký, bảng điểm, kiểm tra đầu vào. *Lớp – lịch – buổi học*: chọn lớp → lịch cố định → danh sách buổi. | 4.9, 4.16 |
| **Nhập liệu hàng loạt dạng lưới** | Điểm danh, nhập điểm dùng lưới sửa trực tiếp: cột được sửa có biểu tượng bút, cột tính toán (TB, xếp loại, chuyên cần) chỉ đọc và cập nhật ngay; đếm "n học viên có thay đổi chưa lưu". | 4.13, 4.14 |
| **Nhất quán** | Cùng vị trí nút, cùng định dạng tiền/ngày, cùng màu (đỏ = cảnh báo/nợ quá hạn) trên mọi trang – do dùng chung `core/ui.py`. | toàn chương |

![Hình 4.6 – Kiểm tra dữ liệu ngay tại trường](images/ch4/04_kiem_tra_nhap_lieu.jpg)

*Hình 4.6 – Nhấn "Lưu" với form trống: lỗi hiện ngay dưới từng ô ("Mã phải có dạng CN + 2 chữ số", "Tên chi nhánh không được để trống"); dữ liệu chưa hề gửi xuống CSDL. Thanh bên tô mục đang mở.*

### 4.2.3 Ánh xạ Form ↔ đối tượng CSDL

Bảng 4.2 cho thấy mỗi form đọc từ đâu và ghi qua đâu. Không form nào `INSERT/UPDATE/DELETE` trực tiếp lên bảng – login ứng dụng bị `DENY` trên mọi bảng (mục 3.2.2).

*Bảng 4.2 – Form ↔ view / function / procedure / trigger*

| Nhóm | Form (file) | Đọc (view / function) | Ghi (procedure) | Bảng bị tác động · trigger liên quan |
|---|---|---|---|---|
| — | Trang chủ (`trang_chu.py`) | `vw_SiSoLop`, `vw_HocVien_ChiNhanh`, `vw_CongNoHocVien` | – | – |
| Danh mục | Chi nhánh, phòng, ca học (`danh_muc_chi_nhanh.py`) | `vw_DM_ChiNhanh`, `vw_DM_PhongHoc`, `vw_DM_CaHoc`, `vw_NhanVien` | `sp_LuuChiNhanh`, `sp_XoaChiNhanh`, `sp_LuuPhongHoc`, `sp_XoaPhongHoc`, `sp_LuuCaHoc`, `sp_XoaCaHoc` | CHINHANH, PHONGHOC, CAHOC |
| | Nhân viên & giáo viên (`danh_muc_nhan_vien.py`) | `vw_NhanVien`, `vw_ChungChiGV` | `sp_LuuNhanVien`, `sp_XoaNhanVien`, `sp_LuuChungChi`, `sp_XoaChungChi` | NHANVIEN, GIAOVIEN, CHUNGCHI_GV · `trg_NhatKy_Luong` (nhật ký đổi lương) |
| Đào tạo | Chương trình & khoá học (`dao_tao_khoa_hoc.py`) | `vw_DM_ChuongTrinh`, `vw_DM_KhoaHoc` | `sp_LuuChuongTrinh`, `sp_XoaChuongTrinh`, `sp_LuuKhoaHoc`, `sp_XoaKhoaHoc` | CHUONGTRINH, KHOAHOC |
| | Lớp học (`dao_tao_lop_hoc.py`) | `vw_SiSoLop`, `vw_DM_KhoaHoc`, `vw_NhanVien` | `sp_LuuLopHoc`, `sp_XoaLopHoc` | LOPHOC |
| | Xếp lịch & buổi học (`dao_tao_lich_hoc.py`) | `vw_LichHoc`, `vw_BuoiHoc`, `vw_DM_PhongHoc`, `vw_DM_CaHoc` | `sp_XepLichLop`, `sp_XoaLichLop`, `sp_SinhBuoiHoc` | LICHHOC, BUOIHOC · `trg_LichHoc_KiemTraTrung` (chặn trùng phòng / giáo viên) |
| Học viên | Hồ sơ học viên (`hoc_vien_ho_so.py`) | `vw_HocVien_ChiNhanh`, `vw_DangKyChiTiet`, `vw_BangDiem`, `vw_KiemTraChiTiet` | `sp_TimKiemHocVien`, `sp_LuuHocVien` | HOCVIEN |
| | Kiểm tra đầu vào (`hoc_vien_kiem_tra.py`) | `vw_KiemTraChiTiet`, `fn_KyNangKiemTra`, `fn_GoiYKhoaHoc` | `sp_GhiKetQuaKiemTra` | KIEMTRADAUVAO (cột XML có XML Schema) |
| | Ghi danh (`hoc_vien_ghi_danh.py`) | `vw_DangKyChiTiet`, `vw_SiSoLop`, `vw_KiemTraChiTiet` | `sp_DangKyHoc`, `sp_ChuyenLop`, `sp_HuyDangKy` | DANGKY · `trg_DangKy_KiemTraSiSo`, `trg_DangKy_SiSo`, `trg_NhatKy_DangKy` |
| | Lịch học & kết quả của tôi (`hoc_vien_cua_toi.py`) | `fn_LichHocHocVien`, `vw_DangKyChiTiet`, `vw_BangDiem`, `vw_CongNoHocVien` (lọc theo mã HV trong session) | – | – |
| Học tập | Điểm danh (`hoc_tap_diem_danh.py`) | `vw_BuoiHoc`, `vw_DiemDanh`, `vw_DangKyChiTiet` | `sp_DiemDanhBuoi` (JSON cả lớp) | DIEMDANH, BUOIHOC |
| | Nhập điểm (`hoc_tap_nhap_diem.py`) | `vw_BangDiem` | `sp_NhapDiem` | DANGKY · `trg_DangKy_KetQua` (tính Đạt/Không đạt) |
| | Cảnh báo chuyên cần (`hoc_tap_canh_bao.py`) | `vw_CanhBao` | `sp_CanhBaoChuyenCan` (cursor), `sp_XuLyCanhBao` | CANHBAO |
| Tài chính | Lập phiếu thu (`tai_chinh_phieu_thu.py`) | `vw_CongNoHocVien`, `vw_PhieuThu`, `vw_CTPhieuThu` | `sp_ThuHocPhi` (master + JSON detail) | PHIEUTHU, CT_PHIEUTHU, DANGKY · `trg_CTPhieuThu_TongTien`, `trg_NhatKy_PhieuThu` |
| | Công nợ (`tai_chinh_cong_no.py`) | `vw_CongNoHocVien` | – | – |
| Báo cáo | Dashboard (`bao_cao_dashboard.py`) | `vw_DoanhThuThang` (indexed view), `vw_BaoCaoDoanhThu`, `vw_SiSoLop`, `vw_BangDiem`, `vw_CongNoHocVien` | – | – |
| | Báo cáo & xuất file (`bao_cao_danh_sach.py`) | `vw_DangKyChiTiet`, `vw_BaoCaoDoanhThu`, `fn_BangDiemLop`, `vw_BangLuong`, `vw_CongNoHocVien`, `fn_LopCuaGiaoVien` | `sp_TinhLuongGiaoVien` | – |
| Hệ thống | Tài khoản (`he_thong_tai_khoan.py`) | `vw_TaiKhoan`, `vw_NhanVien` | `sp_TaoTaiKhoan`, `sp_CapNhatTaiKhoan` | TAIKHOAN |
| | Nhật ký hệ thống (`he_thong_nhat_ky.py`) | `vw_NhatKy` | – (chỉ trigger được ghi) | NHATKY |
| | Đổi mật khẩu (`he_thong_doi_mat_khau.py`) | – | `sp_DoiMatKhau` | TAIKHOAN |
| | Đăng nhập (`dang_nhap.py`) | – | `sp_DangNhap` | TAIKHOAN (đếm lần sai, khoá) |

### 4.2.4 Các form tiêu biểu theo phân hệ

**Danh mục và đào tạo.** Form nhân viên gom thông tin chung và phần riêng của giáo viên (chuyên môn, chứng chỉ) vào cùng trang theo quan hệ chuyên biệt hoá NHANVIEN – GIAOVIEN (mục 2.1). Trang Lớp học lọc theo chi nhánh/khoá/trạng thái (mặc định "Sắp mở, Đang học"); trang Xếp lịch hiển thị lịch cố định của lớp và danh sách buổi học sinh tự động, có tab "Lịch tuần toàn chi nhánh" dạng lưới thứ × ca.

![Hình 4.7 – Nhân viên & giáo viên](images/ch4/05_nhan_vien.jpg)

*Hình 4.7 – Danh mục nhân viên: lọc theo chi nhánh, chức vụ; chọn dòng để sửa.*

![Hình 4.8 – Lớp học](images/ch4/06_lop_hoc.jpg)

*Hình 4.8 – Lớp học: bộ lọc đa chọn trạng thái; form "Mở lớp mới" ngay dưới bảng.*

![Hình 4.9 – Xếp lịch & buổi học](images/ch4/07_xep_lich.jpg)

*Hình 4.9 – Master–detail Lớp → Lịch cố định → Buổi học (30 buổi, 18 buổi đã điểm danh); dòng tóm tắt in đậm khoá, giáo viên, ngày khai giảng, sĩ số.*

**Học viên.** Trang hồ sơ dùng `sp_TimKiemHocVien` (nhiều tiêu chí tuỳ chọn, phân trang `OFFSET/FETCH` 15 dòng). Trang Kiểm tra đầu vào là form nhập **dữ liệu XML**: 4 kỹ năng × (điểm + nhận xét); procedure dựng tài liệu XML, CSDL kiểm tra theo `XSC_KetQuaKiemTra` – điểm ngoài 0–10 hay thiếu kỹ năng bị từ chối. Trang Ghi danh hiện kết quả kiểm tra gần nhất và khoá đề xuất (`fn_GoiYKhoaHoc`) rồi chỉ liệt kê lớp phù hợp.

![Hình 4.10 – Hồ sơ học viên](images/ch4/08_ho_so_hoc_vien.jpg)

*Hình 4.10 – Hồ sơ học viên: 349 học viên trong phạm vi, phân trang 15 dòng; câu mô tả nhắc dữ liệu đã được lọc theo chi nhánh (row-level security).*

![Hình 4.11 – Kiểm tra đầu vào (form XML)](images/ch4/09_kiem_tra_dau_vao.jpg)

*Hình 4.11 – Form kết quả kiểm tra: control số có nút +/− (bước 0,5), radio cho hình thức thi; tab "Xem chi tiết" đọc lại từ XML bằng `nodes()/value()`.*

![Hình 4.12 – Ghi danh](images/ch4/10_ghi_danh.jpg)

*Hình 4.12 – Ghi danh: đăng ký hiện có của học viên (trạng thái học phí, kết quả) và gợi ý khoá IELTS Foundation từ kết quả kiểm tra; toggle "Chỉ hiện lớp của khoá đề xuất".*

**Học tập.** Hai lưới nhập hàng loạt: điểm danh cả lớp một lần (`sp_DiemDanhBuoi` nhận JSON) và nhập điểm giữa kỳ/cuối kỳ – điểm TB, xếp loại, kết quả do cột tính toán và trigger quyết định, giao diện chỉ hiển thị lại. Cảnh báo chuyên cần chạy procedure dùng **cursor** (mục 3.3.4) theo ngưỡng chọn bằng slider.

![Hình 4.13 – Điểm danh](images/ch4/11_diem_danh.jpg)

*Hình 4.13 – Điểm danh: chọn lớp → buổi (✓ = đã điểm danh); cột Trạng thái/Ghi chú sửa được (biểu tượng bút), các cột khác chỉ đọc.*

![Hình 4.14 – Nhập điểm](images/ch4/12_nhap_diem.jpg)

*Hình 4.14 – Nhập điểm: thanh tiến độ chuyên cần, TB = 0,4·GK + 0,6·CK, kết quả Đạt khi TB ≥ 5; nút "Lưu điểm" khoá khi chưa có thay đổi.*

![Hình 4.15 – Cảnh báo chuyên cần](images/ch4/13_canh_bao.jpg)

*Hình 4.15 – Sau khi nhấn "Quét cảnh báo hôm nay": 2 cảnh báo mới, phân mức Nghiêm trọng (> 30%) / Nhắc nhở; có SĐT phụ huynh để liên hệ.*

**Tài chính.** Phiếu thu là ví dụ **master–detail** đầy đủ nhất: phần master (học viên, hình thức, ghi chú) và lưới detail (các đăng ký còn nợ; cột "Thu lần này" sửa được, cho phép thu một phần). Tổng phiếu tính ngay trên màn hình, nhưng số chính thức do trigger `trg_CTPhieuThu_TongTien` cập nhật. Lưu xong có nút in phiếu PDF (hình 4.21).

![Hình 4.16 – Lập phiếu thu (master–detail)](images/ch4/14_phieu_thu.jpg)

*Hình 4.16 – Lập phiếu thu: master (1) – detail (2); khoản quá hạn đánh dấu ⚠; "Tổng phiếu" cập nhật theo số dòng được tích.*

![Hình 4.17 – Công nợ học phí](images/ch4/14b_cong_no.jpg)

*Hình 4.17 – Công nợ: 3 chỉ số tóm tắt trên cùng, dòng quá hạn tô đỏ (nguyên tắc "làm nổi bật ngoại lệ").*

**Hệ thống.** Tài khoản chỉ Quản lý thấy; mật khẩu không bao giờ hiển thị (chỉ lưu hash). Nhật ký là màn hình **chỉ đọc** – view `vw_NhatKy` không có procedure ghi tương ứng; dữ liệu chỉ do trigger thêm vào.

![Hình 4.18 – Tài khoản](images/ch4/17_tai_khoan.jpg)

*Hình 4.18 – Tài khoản: vai trò, chi nhánh, trạng thái, số lần đăng nhập sai, lần đăng nhập cuối.*

![Hình 4.19 – Nhật ký hệ thống](images/ch4/18_nhat_ky.jpg)

*Hình 4.19 – Nhật ký: mỗi thao tác ghi cả tài khoản ứng dụng (`ketoan`, lấy từ SESSION_CONTEXT) lẫn login SQL (`ecms_app`) – giải quyết bài toán "ai thật sự thao tác" khi mọi người dùng chung một login kết nối.*

## 4.3 Thiết kế Report và Dashboard

### 4.3.1 Cấu trúc một báo cáo

Hàm `bao_cao.pdf` ([`app/reports/bao_cao.py`](../app/reports/bao_cao.py), dùng ReportLab + font DejaVu hỗ trợ tiếng Việt) dựng mọi báo cáo theo đúng **5 vùng** của một report:

| Vùng | Nội dung trong ECMS |
|---|---|
| Report Header | Tên trung tâm, **tên báo cáo**, dòng tham số ("Từ 01/01/2026 đến 15/10/2026", "Lớp IE55-2601") |
| Page Header | Dòng tiêu đề cột lặp lại ở đầu mỗi trang (`repeatRows`) |
| Group Header / Footer | Khi có cột phân nhóm: dòng tên nhóm và dòng "Cộng …" (tổng phụ) |
| Detail | Mỗi dòng dữ liệu; cột tiền/số căn phải, định dạng `1.234.000 đ`, dòng xen kẽ màu |
| Report Footer / Page Footer | Dòng **TỔNG CỘNG**, số dòng; chân trang "ECMS · in lúc …" và **"Trang X / Y"** (canvas 2 lượt để biết tổng số trang) |

Khổ giấy dọc/ngang chọn theo số cột; nếu tổng độ rộng cột vượt khổ, các cột được co theo tỷ lệ. Mỗi báo cáo cũng xuất **Excel** (openpyxl): tiêu đề, dòng tham số, header in đậm, cột tiền định dạng số, dòng tổng bằng công thức.

![Hình 4.20 – Báo cáo PDF có nhóm, tổng phụ, tổng cộng](images/ch4/20_pdf_doanh_thu.jpg)

*Hình 4.20 – Báo cáo doanh thu theo chi nhánh → tháng (PDF): Report Header, Group Header (tên chi nhánh), Detail, Group Footer ("Cộng ECMS Thủ Đức 467.625.000 đ"), Report Footer (TỔNG CỘNG 1.172.802.000 đ), Page Footer "Trang 1 / 1".*

![Hình 4.21 – Phiếu thu in PDF (biểu mẫu)](images/ch4/19_pdf_phieu_thu.jpg)

*Hình 4.21 – Phiếu thu PT000527 (báo cáo dạng biểu mẫu – form report): thông tin chi nhánh, số phiếu, chi tiết từng lớp, tổng cộng, số tiền bằng chữ, chỗ ký.*

### 4.3.2 Phân loại báo cáo

Trang "Báo cáo & xuất file" gom các báo cáo theo đúng 3 loại trong Chương 4; mỗi vai trò chỉ thấy báo cáo của mình (Giáo viên chỉ thấy lớp mình dạy qua `fn_LopCuaGiaoVien`).

*Bảng 4.3 – Danh mục báo cáo*

| Báo cáo | Loại | Tham số | Nguồn dữ liệu | Vai trò |
|---|---|---|---|---|
| Danh sách học viên theo lớp | Định kỳ – đầu khoá | lớp | `vw_DangKyChiTiet` | QL, GVụ, GV |
| Doanh thu theo chi nhánh → tháng | Định kỳ – tháng/quý | khoảng ngày | `vw_BaoCaoDoanhThu` | QL, KT |
| Bảng lương giáo viên | Định kỳ – tháng | tháng, năm | `sp_TinhLuongGiaoVien`, `vw_BangLuong` | QL, KT |
| Bảng điểm lớp | Theo yêu cầu | lớp | `fn_BangDiemLop` (xếp hạng `RANK()`) | QL, GVụ, GV |
| Lịch sử học tập học viên | Theo yêu cầu | học viên | `vw_DangKyChiTiet`, `vw_BangDiem` | QL, GVụ |
| Công nợ học viên | Theo yêu cầu / ngoại lệ | ngưỡng nợ, chỉ quá hạn | `vw_CongNoHocVien` | QL, KT, GVụ |
| Tổng hợp theo chương trình | Tổng hợp | năm | `vw_SiSoLop`, `vw_BaoCaoDoanhThu`, `vw_BangDiem` | QL, KT |
| Phiếu thu | Biểu mẫu (form report) | số phiếu | `vw_PhieuThu`, `vw_CTPhieuThu` | QL, KT |
| Dashboard | Tổng hợp – tương tác | chi nhánh, năm | `vw_DoanhThuThang` (indexed view) … | QL, KT |

![Hình 4.22 – Trang Báo cáo & xuất file](images/ch4/15_bao_cao_danh_sach.jpg)

*Hình 4.22 – Chọn báo cáo (kèm loại), nhập tham số, xem trước trên màn hình rồi tải PDF hoặc Excel.*

### 4.3.3 Dashboard

Dashboard là tầng **Knowledge** trong mô hình DIKW (mục 1.4): từ dữ liệu giao dịch, tổng hợp thành chỉ số giúp quản lý ra quyết định.

- **Hàng chỉ số (KPI)**: học viên mới tháng này, doanh thu tháng, doanh thu năm, lấp đầy lớp đang mở, chuyên cần lớp đang học, công nợ hiện tại; mỗi chỉ số có **mũi tên so với tháng trước** (xanh tăng, đỏ giảm).
- **Biểu đồ** (Plotly): doanh thu theo tháng xếp chồng theo chi nhánh + đường luỹ kế (trục phụ); cơ cấu doanh thu theo chương trình (donut); tỷ lệ lấp đầy theo lớp (cột ngang); học viên mới theo tháng (đường); tương quan chuyên cần – điểm TB theo lớp (bong bóng, kích thước = sĩ số).
- **Bộ lọc** chi nhánh và năm ở đầu trang; dữ liệu đọc từ indexed view `vw_DoanhThuThang` nên trang tải nhanh dù số phiếu thu tăng.

![Hình 4.23 – Dashboard](images/ch4/16_dashboard.jpg)

*Hình 4.23 – Dashboard toàn trung tâm năm 2026: 6 KPI có so sánh kỳ trước; doanh thu tháng xếp chồng theo chi nhánh và đường luỹ kế; cơ cấu theo chương trình.*

### 4.3.4 Đối chiếu nguyên tắc thiết kế report

| Nguyên tắc (Chương 4) | Cách ECMS áp dụng |
|---|---|
| Đúng người – đúng lúc – đúng mức chi tiết | Báo cáo lọc theo vai trò và chi nhánh; nhân viên tác nghiệp xem chi tiết (danh sách, bảng điểm), quản lý xem tổng hợp (dashboard, tổng hợp chương trình). |
| Tiêu đề và tham số rõ ràng | Mọi báo cáo có tên in hoa và dòng tham số ngay dưới; tên file tải về mang tên báo cáo. |
| Làm nổi bật ngoại lệ | Công nợ quá hạn tô đỏ; bảng điểm tô đỏ học viên không đạt hoặc chuyên cần < 80%, tô xanh học viên Giỏi/Xuất sắc; cảnh báo chuyên cần chia mức nghiêm trọng. |
| Tổng phụ / tổng cộng | Group Footer và Report Footer trong PDF; dòng tổng bằng công thức trong Excel. |
| Định dạng số nhất quán | Tiền `1.234.000 đ`, số căn phải, ngày `dd/mm/yyyy` – dùng chung `pdf_common.money` và `ui.money`. |
| Phân trang, đánh số trang | Header cột lặp mỗi trang; "Trang X / Y" ở chân trang. |
| Trực quan hoá đúng loại biểu đồ | Xu hướng theo thời gian → cột + đường; cơ cấu → donut; so sánh giữa lớp → cột ngang; tương quan 2 chỉ số → bong bóng. |

## 4.4 Đánh giá

**Đạt được.** Menu 2 cấp theo vai trò, mọi chức năng 1 cú nhấp; 20 trang dùng chung một khuôn bố cục; kiểm tra dữ liệu 2 lớp (giao diện + CSDL); 2 form master–detail và 2 lưới nhập hàng loạt; 9 báo cáo thuộc đủ các loại định kỳ / theo yêu cầu / tổng hợp / biểu mẫu, xuất PDF và Excel; dashboard KPI. Bộ kiểm thử `tests/test_app_smoke.py` mở **mọi trang với từng vai trò** và sinh **mọi báo cáo** để bảo đảm không trang nào lỗi.

**Hạn chế.** Streamlit tải lại toàn trang sau mỗi tương tác nên thao tác nhanh liên tục có độ trễ nhỏ; nút xoá chưa có hộp xác nhận (dựa vào khoá ngoại để chặn xoá dữ liệu đang được tham chiếu); giao diện chưa tối ưu cho điện thoại; chưa có in hàng loạt nhiều phiếu thu một lần.
