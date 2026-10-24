## C. Từ điển dữ liệu

Từ điển dữ liệu mô tả từng cột của 22 bảng sau khi cài đặt (mục 2.2). Để bảo đảm từ điển luôn khớp với script, nhóm sinh khung từ điển trực tiếp từ siêu dữ liệu của CSDL (`sys.columns`, `sys.check_constraints`, `sys.foreign_keys`) rồi bổ sung ý nghĩa và diễn giải ràng buộc. Quy ước: **PK** là khoá chính, **FK** là khoá ngoại, cột NULL ghi "Có" nếu được phép để trống; cột tính toán được ghi kiểu "tính toán" kèm công thức. Khoá ngoại không ghi hành vi xoá là khoá ngoại chặn xoá (NO ACTION).

### C.1 Nhóm danh mục

*Bảng C.1 – Bảng CHINHANH (chi nhánh)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaCN | Mã chi nhánh | CHAR(4) | | PK; dạng `CN` + 2 chữ số |
| TenCN | Tên chi nhánh | NVARCHAR(100) | | Duy nhất |
| DiaChi | Địa chỉ | NVARCHAR(200) | | |
| SoDienThoai | Số điện thoại | VARCHAR(15) | | Chỉ gồm chữ số |
| NgayThanhLap | Ngày thành lập | DATE | | |
| MaNVQuanLy | Nhân viên quản lý chi nhánh | CHAR(6) | Có | FK → NHANVIEN; duy nhất khi khác NULL (quan hệ 1 – 1) |

*Bảng C.2 – Bảng NHANVIEN (nhân viên)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaNV | Mã nhân viên | CHAR(6) | | PK; dạng `NV` + 4 chữ số |
| HoNV | Họ và tên lót | NVARCHAR(50) | | |
| TenNV | Tên | NVARCHAR(20) | | |
| NgaySinh | Ngày sinh | DATE | | Từ 18 đến 65 tuổi tại ngày vào làm (RB07) |
| GioiTinh | Giới tính | NVARCHAR(3) | | Nam hoặc Nữ |
| SoDienThoai | Số điện thoại | VARCHAR(15) | | Duy nhất |
| Email | Thư điện tử | VARCHAR(100) | | Duy nhất; đúng dạng địa chỉ email |
| ChucVu | Chức vụ | NVARCHAR(20) | | Quản lý, Giáo vụ, Kế toán hoặc Giáo viên; đổi chức vụ thì vai trò tài khoản đổi theo |
| LuongCoBan | Lương cơ bản mỗi tháng (đồng) | DECIMAL(12,0) | | Mặc định 0; không âm |
| NgayVaoLam | Ngày vào làm | DATE | | Mặc định ngày hiện tại |
| MaCN | Chi nhánh làm việc | CHAR(4) | | FK → CHINHANH |
| MaNVQuanLy | Người quản lý trực tiếp | CHAR(6) | Có | FK → NHANVIEN; khác chính MaNV |
| TrangThai | Đang làm việc | BIT | | Mặc định 1 |
| HoTen | Họ tên đầy đủ (suy diễn) | tính toán | | HoNV + ' ' + TenNV; không lưu |

*Bảng C.3 – Bảng GIAOVIEN (chuyên biệt hoá của NHANVIEN)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaGV | Mã giáo viên, trùng mã nhân viên | CHAR(6) | | PK; FK → NHANVIEN, xoá theo nhân viên |
| LoaiGV | Loại giáo viên | NVARCHAR(20) | | Việt Nam hoặc Bản ngữ |
| QuocTich | Quốc tịch | NVARCHAR(50) | | Mặc định Việt Nam |
| TrinhDo | Trình độ học vấn | NVARCHAR(30) | | Cử nhân, Thạc sĩ hoặc Tiến sĩ |
| DonGiaBuoi | Đơn giá mỗi buổi dạy (đồng) | DECIMAL(10,0) | | Từ 100.000 đến 5.000.000 |

*Bảng C.4 – Bảng CHUNGCHI_GV (chứng chỉ của giáo viên – thuộc tính đa trị)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaGV | Mã giáo viên | CHAR(6) | | PK; FK → GIAOVIEN, xoá theo giáo viên |
| TenChungChi | Tên chứng chỉ | NVARCHAR(50) | | PK |
| Diem | Điểm chứng chỉ | DECIMAL(5,1) | Có | Không âm; để trống với chứng chỉ không có điểm (TESOL, CELTA) |
| NgayCap | Ngày cấp | DATE | | |
| NoiCap | Nơi cấp | NVARCHAR(100) | Có | |

*Bảng C.5 – Bảng PHONGHOC (phòng học – thực thể yếu)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaCN | Chi nhánh | CHAR(4) | | PK; FK → CHINHANH, xoá theo chi nhánh |
| MaPhong | Số phòng | VARCHAR(5) | | PK |
| SucChua | Sức chứa (người) | TINYINT | | Từ 5 đến 60 |
| LoaiPhong | Loại phòng | NVARCHAR(20) | | Thường, Lab hoặc Hội trường; mặc định Thường |

*Bảng C.6 – Bảng CAHOC (ca học)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaCa | Mã ca | TINYINT | | PK |
| TenCa | Tên ca | NVARCHAR(30) | | Duy nhất |
| GioBatDau | Giờ bắt đầu | TIME(0) | | |
| GioKetThuc | Giờ kết thúc | TIME(0) | | Lớn hơn giờ bắt đầu |

*Bảng C.7 – Bảng NGAYLE (ngày nghỉ lễ – bảng phụ trợ)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| Ngay | Ngày nghỉ | DATE | | PK |
| TenNgayLe | Tên ngày lễ | NVARCHAR(100) | | |

### C.2 Nhóm đào tạo

*Bảng C.8 – Bảng CHUONGTRINH (chương trình đào tạo)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaCT | Mã chương trình | VARCHAR(5) | | PK |
| TenCT | Tên chương trình | NVARCHAR(100) | | Duy nhất |
| DoiTuong | Đối tượng học viên | NVARCHAR(100) | | |
| MoTa | Mô tả | NVARCHAR(500) | Có | |

*Bảng C.9 – Bảng KHOAHOC (khoá học)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaKH | Mã khoá học | VARCHAR(6) | | PK; 2 đến 5 ký tự, chỉ gồm chữ in hoa và chữ số, để mã lớp tự sinh vừa 10 ký tự |
| TenKH | Tên khoá học | NVARCHAR(100) | | Duy nhất |
| MaCT | Chương trình | VARCHAR(5) | | FK → CHUONGTRINH |
| CapDo | Cấp độ trong chương trình | TINYINT | | Cặp (MaCT, CapDo) duy nhất |
| DiemDauVaoTu | Điểm kiểm tra đầu vào tối thiểu | DECIMAL(3,1) | | Từ 0, không lớn hơn điểm tối đa |
| DiemDauVaoDen | Điểm kiểm tra đầu vào tối đa | DECIMAL(3,1) | | Không quá 10 |
| MucTieuDauRa | Mục tiêu đầu ra | NVARCHAR(50) | | |
| SoBuoi | Số buổi học | TINYINT | | Từ 8 đến 60 |
| HocPhi | Học phí (đồng) | DECIMAL(12,0) | | Lớn hơn 0 |
| MaKHTienQuyet | Khoá tiên quyết | VARCHAR(6) | Có | FK → KHOAHOC; khác chính MaKH |

*Bảng C.10 – Bảng LOPHOC (lớp học)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaLop | Mã lớp | VARCHAR(10) | | PK; dạng MaKH-yynn (ví dụ `IE55-2601`); cặp (MaLop, MaCN) duy nhất để LICHHOC tham chiếu |
| TenLop | Tên lớp | NVARCHAR(100) | | |
| MaKH | Khoá học | VARCHAR(6) | | FK → KHOAHOC |
| MaCN | Chi nhánh | CHAR(4) | | FK → CHINHANH |
| MaGV | Giáo viên phụ trách | CHAR(6) | | FK → GIAOVIEN |
| NgayKhaiGiang | Ngày khai giảng | DATE | | |
| NgayKetThuc | Ngày kết thúc | DATE | Có | Sau ngày khai giảng; cập nhật khi sinh buổi học |
| SiSoToiDa | Sĩ số tối đa | TINYINT | | Từ 5 đến 40; mặc định 20 |
| SiSoHienTai | Sĩ số hiện tại (suy diễn, trigger duy trì) | TINYINT | | Mặc định 0; không vượt sĩ số tối đa |
| TrangThai | Trạng thái lớp | NVARCHAR(20) | | Sắp mở, Đang học, Đã kết thúc hoặc Huỷ; mặc định Sắp mở; tự chuyển sang Đang học khi tới ngày khai giảng và đã có học viên (`sp_CapNhatTrangThaiLop`) |

*Bảng C.11 – Bảng LICHHOC (lịch học cố định – mối kết hợp ba ngôi)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaLop | Lớp học | VARCHAR(10) | | PK; FK (MaLop, MaCN) → LOPHOC, xoá theo lớp |
| Thu | Thứ trong tuần (2 là thứ Hai, 8 là Chủ nhật) | TINYINT | | PK; từ 2 đến 8 |
| MaCa | Ca học | TINYINT | | PK; FK → CAHOC |
| MaCN | Chi nhánh của lớp | CHAR(4) | | Thuộc FK (MaLop, MaCN) và FK (MaCN, MaPhong) |
| MaPhong | Phòng học | VARCHAR(5) | | FK (MaCN, MaPhong) → PHONGHOC |

*Bảng C.12 – Bảng BUOIHOC (buổi học – thực thể yếu)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaLop | Lớp học | VARCHAR(10) | | PK; FK → LOPHOC, xoá theo lớp |
| STT | Số thứ tự buổi | TINYINT | | PK; từ 1; bộ (MaLop, NgayHoc, MaCa) duy nhất |
| NgayHoc | Ngày học | DATE | | |
| MaCa | Ca học | TINYINT | | FK → CAHOC |
| MaPhong | Phòng học | VARCHAR(5) | Có | |
| NoiDung | Nội dung buổi học | NVARCHAR(200) | Có | |
| TrangThai | Trạng thái buổi | NVARCHAR(20) | | Đã lên lịch, Đã dạy hoặc Nghỉ; mặc định Đã lên lịch |
| MaGVDay | Giáo viên dạy buổi này | CHAR(6) | Có | FK → GIAOVIEN; ghi khi điểm danh, để trống nghĩa là giáo viên phụ trách lớp; dùng để tính lương khi đổi giáo viên giữa khoá |

### C.3 Nhóm học viên và học tập

*Bảng C.13 – Bảng HOCVIEN (học viên)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaHV | Mã học viên | CHAR(6) | | PK; dạng `HV` + 4 chữ số |
| HoHV | Họ và tên lót | NVARCHAR(50) | | |
| TenHV | Tên | NVARCHAR(20) | | |
| NgaySinh | Ngày sinh | DATE | | Từ năm 1950; học viên ít nhất 4 tuổi khi lập hồ sơ |
| GioiTinh | Giới tính | NVARCHAR(3) | | Nam hoặc Nữ |
| SoDienThoai | Số điện thoại | VARCHAR(15) | | 9 đến 11 chữ số |
| Email | Thư điện tử | VARCHAR(100) | Có | Đúng dạng email; duy nhất khi khác NULL |
| SoNha | Số nhà, đường | NVARCHAR(100) | Có | |
| PhuongXa | Phường, xã | NVARCHAR(50) | Có | |
| QuanHuyen | Quận, huyện | NVARCHAR(50) | Có | |
| TinhTP | Tỉnh, thành phố | NVARCHAR(50) | | Mặc định TP. Hồ Chí Minh |
| HoTenPhuHuynh | Họ tên phụ huynh | NVARCHAR(70) | Có | Bắt buộc với học viên dưới 16 tuổi (kiểm tra trong `sp_LuuHocVien`) |
| NgayTao | Ngày lập hồ sơ | DATE | | Mặc định ngày hiện tại |
| MaCN | Chi nhánh tiếp nhận | CHAR(4) | | FK → CHINHANH |
| TrangThai | Còn hoạt động | BIT | | Mặc định 1 |
| HoTen | Họ tên đầy đủ (suy diễn) | tính toán | | HoHV + ' ' + TenHV; không lưu |
| Tuoi | Tuổi (suy diễn) | tính toán | Có | Tính từ NgaySinh tới ngày hiện tại; không lưu được vì dùng `GETDATE()` |

*Bảng C.14 – Bảng KIEMTRA_DAUVAO (kiểm tra đầu vào)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaKT | Mã lần kiểm tra | INT | | PK; tự tăng |
| MaHV | Học viên | CHAR(6) | | FK → HOCVIEN, xoá theo học viên |
| NgayKT | Ngày kiểm tra | DATE | | Mặc định ngày hiện tại |
| DiemTong | Điểm tổng (trung bình bốn kỹ năng, làm tròn một chữ số) | DECIMAL(3,1) | | Từ 0 đến 10; do `sp_GhiKetQuaKiemTra` tính từ bốn điểm kỹ năng |
| KetQuaChiTiet | Kết quả chi tiết | XML | | Kiểm tra theo XML Schema `XSC_KetQuaKiemTra` |
| MaKHDeXuat | Khoá học đề xuất | VARCHAR(6) | Có | FK → KHOAHOC |
| MaNVCham | Nhân viên chấm | CHAR(6) | Có | FK → NHANVIEN |

*Bảng C.15 – Bảng DANGKY (đăng ký học – mối kết hợp N – M có thuộc tính)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaDK | Mã đăng ký | INT | | PK; tự tăng |
| MaHV | Học viên | CHAR(6) | | FK → HOCVIEN; cặp (MaHV, MaLop) duy nhất |
| MaLop | Lớp học | VARCHAR(10) | | FK → LOPHOC; cặp (MaDK, MaLop) duy nhất để DIEMDANH tham chiếu |
| NgayDK | Ngày đăng ký | DATE | | Mặc định ngày hiện tại |
| HocPhi | Học phí tại thời điểm ghi danh | DECIMAL(12,0) | | Lớn hơn 0; chép từ KHOAHOC lúc ghi danh |
| GiamGia | Giảm giá (%) | DECIMAL(5,2) | | Từ 0 đến 50; mặc định 0 |
| ThanhTien | Thành tiền | tính toán | | HocPhi × (100 − GiamGia) / 100, làm tròn nghìn đồng; lưu sẵn |
| HanDongHP | Hạn đóng học phí | tính toán | | NgayDK + 14 ngày; lưu sẵn |
| TrangThaiHP | Trạng thái học phí (trigger duy trì) | NVARCHAR(20) | | Chưa đóng, Đóng một phần hoặc Đã đóng |
| DiemGK | Điểm giữa kỳ | DECIMAL(4,2) | Có | Từ 0 đến 10 |
| DiemCK | Điểm cuối kỳ | DECIMAL(4,2) | Có | Từ 0 đến 10 |
| DiemTB | Điểm trung bình | tính toán | Có | 0,4 × DiemGK + 0,6 × DiemCK; lưu sẵn |
| KetQua | Kết quả (trigger duy trì) | NVARCHAR(10) | Có | Đạt khi DiemTB ≥ 5, ngược lại Không đạt |
| TrangThai | Trạng thái đăng ký | NVARCHAR(20) | | Đang học, Hoàn thành, Bảo lưu, Đã chuyển lớp hoặc Huỷ |

*Bảng C.16 – Bảng DIEMDANH (điểm danh)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaDK | Đăng ký | INT | | PK; FK (MaDK, MaLop) → DANGKY, xoá theo đăng ký |
| MaLop | Lớp học | VARCHAR(10) | | PK; cột dư thừa có chủ đích (mục 2.4.3), thuộc hai khoá ngoại phức hợp |
| STT | Buổi học | TINYINT | | PK; FK (MaLop, STT) → BUOIHOC |
| TrangThai | Trạng thái | NVARCHAR(10) | | Có mặt, Vắng, Muộn hoặc Có phép; mặc định Có mặt |
| GhiChu | Ghi chú | NVARCHAR(200) | Có | |

*Bảng C.17 – Bảng CANHBAO_CHUYENCAN (cảnh báo chuyên cần – bảng phụ trợ)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaCB | Mã cảnh báo | INT | | PK; tự tăng |
| MaDK | Đăng ký bị cảnh báo | INT | | FK → DANGKY, xoá theo đăng ký; mỗi đăng ký tối đa một cảnh báo mỗi ngày |
| NgayCanhBao | Ngày cảnh báo | DATE | | Mặc định ngày hiện tại |
| SoBuoiDaHoc | Số buổi đã diễn ra | TINYINT | | |
| SoBuoiVang | Số buổi vắng | TINYINT | | |
| TyLeVang | Tỷ lệ vắng (%) | DECIMAL(5,2) | | |
| MucDo | Mức độ | NVARCHAR(20) | | Nhắc nhở hoặc Nghiêm trọng (tỷ lệ vắng trên 30%) |
| DaXuLy | Đã liên hệ xử lý | BIT | | Mặc định 0 |

### C.4 Nhóm tài chính

*Bảng C.18 – Bảng PHIEUTHU (phiếu thu – master)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaPT | Mã phiếu thu | INT | | PK; tự tăng |
| SoPhieu | Số phiếu in trên chứng từ | tính toán | | `PT` + 6 chữ số của MaPT; lưu sẵn, duy nhất |
| MaHV | Học viên nộp tiền | CHAR(6) | | FK → HOCVIEN |
| MaNV | Nhân viên lập phiếu | CHAR(6) | | FK → NHANVIEN |
| NgayThu | Thời điểm thu | DATETIME2(0) | | Mặc định thời điểm hiện tại |
| HinhThuc | Hình thức thanh toán | NVARCHAR(20) | | Tiền mặt, Chuyển khoản hoặc Thẻ; mặc định Tiền mặt |
| TongTien | Tổng tiền (trigger duy trì) | DECIMAL(12,0) | | Bằng tổng các dòng chi tiết; không âm |
| GhiChu | Ghi chú | NVARCHAR(200) | Có | |
| MaYeuCau | Mã yêu cầu lập phiếu | UNIQUEIDENTIFIER | Có | Duy nhất khi khác NULL (`UX_PHIEUTHU_MaYeuCau`); ứng dụng sinh một mã cho mỗi lần mở form, gửi lại cùng mã thì không lập phiếu mới |

*Bảng C.19 – Bảng CT_PHIEUTHU (chi tiết phiếu thu – detail)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaPT | Phiếu thu | INT | | PK; FK → PHIEUTHU, xoá theo phiếu |
| MaDK | Đăng ký được thu tiền | INT | | PK; FK → DANGKY |
| SoTien | Số tiền thu cho đăng ký | DECIMAL(12,0) | | Lớn hơn 0 |

*Bảng C.20 – Bảng BANGLUONG (bảng lương giáo viên – bảng phụ trợ)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| Thang | Tháng lương | CHAR(7) | | PK; dạng yyyy-MM với tháng từ 01 đến 12 |
| MaGV | Giáo viên | CHAR(6) | | PK; FK → GIAOVIEN, chặn xoá để giữ lịch sử lương |
| SoBuoiDay | Số buổi đã dạy | SMALLINT | | |
| DonGiaBuoi | Đơn giá mỗi buổi tại thời điểm tính | DECIMAL(10,0) | | |
| LuongCoBan | Lương cơ bản tại thời điểm tính | DECIMAL(12,0) | | |
| TongLuong | Tổng lương | tính toán | | LuongCoBan + SoBuoiDay × DonGiaBuoi; lưu sẵn |
| NgayTinh | Thời điểm tính | DATETIME2(0) | | Mặc định thời điểm hiện tại |

### C.5 Nhóm hệ thống

*Bảng C.21 – Bảng TAIKHOAN (tài khoản ứng dụng)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| TenDangNhap | Tên đăng nhập | VARCHAR(30) | | PK |
| MatKhauHash | Mật khẩu đã băm: 10.000 vòng SHA2_256 có trộn salt (`fn_BamMatKhau`) | VARBINARY(32) | | |
| Salt | Chuỗi ngẫu nhiên 16 byte trộn vào khi băm | VARBINARY(16) | | |
| VaiTro | Vai trò | VARCHAR(10) | | QuanLy, GiaoVu, KeToan, GiaoVien hoặc HocVien; với nhân viên luôn đi theo chức vụ |
| MaNV | Nhân viên sở hữu | CHAR(6) | Có | FK → NHANVIEN, xoá theo nhân viên; duy nhất khi khác NULL |
| MaHV | Học viên sở hữu | CHAR(6) | Có | FK → HOCVIEN, xoá theo học viên; duy nhất khi khác NULL |
| TrangThai | Đang hoạt động | BIT | | Mặc định 1; 0 là bị quản lý khoá |
| SoLanSai | Số lần nhập sai liên tiếp | TINYINT | | Mặc định 0 |
| KhoaDen | Tạm khoá đến thời điểm | DATETIME2(0) | Có | Sai 5 lần liên tiếp thì tạm khoá 15 phút |
| LanDangNhapCuoi | Lần đăng nhập cuối | DATETIME2(0) | Có | |
| NgayTao | Ngày tạo | DATETIME2(0) | | Mặc định thời điểm hiện tại |

Ràng buộc mức bảng `CK_TAIKHOAN_ChuSoHuu`: tài khoản vai trò HocVien phải gắn MaHV, các vai trò còn lại phải gắn MaNV.

*Bảng C.22 – Bảng NHATKY (nhật ký kiểm toán)*

| Cột | Ý nghĩa | Kiểu | NULL | Ràng buộc |
|---|---|---|:---:|---|
| MaNK | Mã nhật ký | BIGINT | | PK; tự tăng |
| TenBang | Bảng bị thay đổi | SYSNAME | | |
| ThaoTac | Thao tác | VARCHAR(6) | | INSERT, UPDATE hoặc DELETE |
| KhoaChinh | Khoá chính của dòng bị thay đổi | NVARCHAR(100) | Có | |
| DuLieuCu | Dữ liệu trước khi thay đổi | NVARCHAR(MAX) | Có | Phải là JSON hợp lệ |
| DuLieuMoi | Dữ liệu sau khi thay đổi | NVARCHAR(MAX) | Có | Phải là JSON hợp lệ |
| NguoiThucHien | Login SQL Server thực hiện | NVARCHAR(128) | | Mặc định `SUSER_SNAME()` |
| NguoiDungUD | Tài khoản ứng dụng thực hiện | NVARCHAR(30) | Có | Trigger lấy qua `fn_NguoiDungHienTai()` (khoá `app_user` chỉ đọc trong SESSION_CONTEXT) |
| ThoiGian | Thời điểm | DATETIME2(3) | | Mặc định thời điểm hiện tại |
