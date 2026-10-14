# Chương 2. Tổ chức thông tin

## 2.1 Mô hình thực thể – mối kết hợp (ERD)

### 2.1.1 Tập thực thể

Từ khảo sát ở Chương 1, nhóm xác định **17 tập thực thể** chính (cộng 2 bảng hệ thống TAIKHOAN, NHATKY và 3 bảng phụ trợ NGAYLE, CANHBAO_CHUYENCAN, BANGLUONG phát sinh khi cài đặt):

| Thực thể | Loại | Mô tả | Khoá |
|---|---|---|---|
| CHINHANH | Mạnh | Chi nhánh của trung tâm | MaCN |
| NHANVIEN | Mạnh (tổng quát) | Mọi nhân viên: quản lý, giáo vụ, kế toán, giáo viên | MaNV |
| GIAOVIEN | Chuyên biệt của NHANVIEN | Nhân viên giảng dạy, có thêm loại GV, trình độ, đơn giá | MaGV (= MaNV) |
| PHONGHOC | **Yếu** (phụ thuộc CHINHANH) | Phòng học, số phòng chỉ duy nhất trong một chi nhánh | (MaCN, MaPhong) |
| CAHOC | Mạnh | Ca học trong ngày | MaCa |
| CHUONGTRINH | Mạnh | IELTS, TOEIC, Giao tiếp, Thiếu nhi | MaCT |
| KHOAHOC | Mạnh | Khoá học thuộc một chương trình | MaKH |
| LOPHOC | Mạnh | Một lần mở khoá học tại một chi nhánh | MaLop |
| BUOIHOC | **Yếu** (phụ thuộc LOPHOC) | Buổi học thứ *n* của lớp | (MaLop, STT) |
| HOCVIEN | Mạnh | Người học | MaHV |
| KIEMTRA_DAUVAO | Mạnh | Một lần kiểm tra xếp lớp | MaKT |
| PHIEUTHU | Mạnh | Phiếu thu học phí | MaPT |
| TAIKHOAN | Mạnh | Tài khoản đăng nhập ứng dụng | TenDangNhap |
| NHATKY | Mạnh | Nhật ký thay đổi dữ liệu | MaNK |

Ba mối kết hợp có thuộc tính riêng được **thực thể hoá** khi cài đặt: ĐĂNG KÝ (HOCVIEN – LOPHOC), ĐIỂM DANH (ĐĂNG KÝ – BUOIHOC), CT PHIẾU THU (PHIEUTHU – ĐĂNG KÝ); thêm LỊCH HỌC là mối kết hợp 3 ngôi. Thuộc tính đa trị *Chứng chỉ* của giáo viên tách thành CHUNGCHI_GV.

### 2.1.2 Sơ đồ ERD (ký hiệu Chen)

![ERD tổng quan](../docs/design/erd.png)

*Hình 2.1 – ERD tổng quan: thực thể (chữ nhật), thực thể yếu (viền đôi), mối kết hợp (thoi, viền đôi là quan hệ xác định), bản số (min,max). File nguồn: `docs/design/erd.drawio`.*

![ERD chi tiết thuộc tính](../docs/design/erd-thuoc-tinh.png)

*Hình 2.2 – Minh hoạ các loại thuộc tính: khoá (gạch chân), phức hợp (Họ tên, Địa chỉ), đa trị (Chứng chỉ – elip đôi), suy diễn (Tuổi, Thành tiền, Điểm TB, Sĩ số hiện tại – nét đứt), thuộc tính của mối kết hợp (ĐĂNG KÝ).*

### 2.1.3 Phân loại thuộc tính

| Loại thuộc tính | Ví dụ trong ECMS | Cách cài đặt |
|---|---|---|
| Đơn trị, đơn | NgaySinh, SoDienThoai, HocPhi | Một cột |
| Khoá | MaHV, MaLop; khoá bộ phận của thực thể yếu: MaPhong, STT | PRIMARY KEY |
| **Phức hợp** | Họ tên = Họ + Tên; Địa chỉ HV = Số nhà + Phường/Xã + Quận/Huyện + Tỉnh/TP | Tách thành nhiều cột; `HoTen` là cột tính toán ghép lại |
| **Đa trị** | Một giáo viên có nhiều chứng chỉ (IELTS 8.0, TESOL, CELTA) | Bảng riêng CHUNGCHI_GV (MaGV, TenChungChi, …) |
| **Suy diễn** | Tuổi ← NgaySinh; Thành tiền ← Học phí, Giảm giá; Điểm TB ← GK, CK; Sĩ số hiện tại ← đếm ĐĂNG KÝ; Tổng tiền phiếu thu ← Σ chi tiết | Computed column (Tuổi, ThanhTien, DiemTB) hoặc cột lưu sẵn duy trì bằng trigger (SiSoHienTai, TongTien) |
| Thuộc tính của mối kết hợp | ĐĂNG KÝ: Ngày ĐK, Học phí, Giảm giá, Điểm GK/CK, Kết quả; ĐIỂM DANH: Trạng thái | Cột của bảng liên kết |
| Bán cấu trúc | Kết quả chi tiết kiểm tra đầu vào (4 kỹ năng, nhận xét) | Kiểu XML có XML Schema (T10) |

### 2.1.4 Mối kết hợp và bản số

| # | Mối kết hợp | Thực thể tham gia | Bản số | Loại | Giải thích |
|:-:|---|---|---|---|---|
| 1 | Làm việc | CHINHANH – NHANVIEN | (1,n) – (1,1) | 1–N | Mỗi nhân viên thuộc đúng một chi nhánh; chi nhánh có ít nhất một nhân viên |
| 2 | Quản lý CN | CHINHANH – NHANVIEN | (0,1) – (0,1) | **1–1** | Mỗi chi nhánh có tối đa một quản lý, một nhân viên quản lý tối đa một chi nhánh |
| 3 | Quản lý | NHANVIEN – NHANVIEN | (0,n) – (0,1) | **Đệ quy** 1–N | Nhân viên có thể có một người quản lý trực tiếp |
| 4 | ISA | NHANVIEN ⊃ GIAOVIEN | – | **Chuyên biệt hoá** (rời nhau, không toàn phần) | Giáo viên là nhân viên có thêm thuộc tính riêng; nhân viên khác không là giáo viên |
| 5 | Có phòng | CHINHANH – PHONGHOC | (1,n) – (1,1) | 1–N, **xác định** | Phòng chỉ định danh được khi biết chi nhánh (thực thể yếu) |
| 6 | Gồm | CHUONGTRINH – KHOAHOC | (1,n) – (1,1) | 1–N | Chương trình có nhiều khoá theo cấp độ |
| 7 | Tiên quyết | KHOAHOC – KHOAHOC | (0,n) – (0,1) | **Đệ quy** 1–N | Một khoá yêu cầu tối đa một khoá phải học trước |
| 8 | Mở | KHOAHOC – LOPHOC | (0,n) – (1,1) | 1–N | Một khoá được mở thành nhiều lớp |
| 9 | Tổ chức | CHINHANH – LOPHOC | (0,n) – (1,1) | 1–N | Lớp học tại một chi nhánh |
| 10 | Phụ trách | GIAOVIEN – LOPHOC | (0,n) – (1,1) | 1–N | Mỗi lớp có một giáo viên phụ trách |
| 11 | **Lịch học** | LOPHOC – PHONGHOC – CAHOC | (1,n) – (0,n) – (0,n) | **3 ngôi** | Lớp học vào một ca, ở một phòng, theo thứ trong tuần |
| 12 | Có buổi | LOPHOC – BUOIHOC | (0,n) – (1,1) | 1–N, **xác định** | Buổi học thứ *n* của lớp (thực thể yếu) |
| 13 | Tiếp nhận | CHINHANH – HOCVIEN | (0,n) – (1,1) | 1–N | Chi nhánh lập hồ sơ học viên |
| 14 | Dự | HOCVIEN – KIEMTRA_DAUVAO | (0,n) – (1,1) | 1–N | Học viên có thể test nhiều lần |
| 15 | Đề xuất | KHOAHOC – KIEMTRA_DAUVAO | (0,n) – (0,1) | 1–N | Kết quả test đề xuất một khoá học |
| 16 | **Đăng ký** | HOCVIEN – LOPHOC | (0,n) – (0,n) | **N–M** | Học viên học nhiều lớp, lớp có nhiều học viên; có thuộc tính học phí, điểm |
| 17 | **Điểm danh** | ĐĂNG KÝ – BUOIHOC | (0,n) – (0,n) | **N–M** (kết hợp hoá) | Mỗi đăng ký được điểm danh ở mỗi buổi của lớp |
| 18 | Đóng | HOCVIEN – PHIEUTHU | (0,n) – (1,1) | 1–N | Phiếu thu của một học viên |
| 19 | Lập | NHANVIEN – PHIEUTHU | (0,n) – (1,1) | 1–N | Kế toán lập phiếu thu |
| 20 | **CT phiếu thu** | PHIEUTHU – ĐĂNG KÝ | (1,n) – (0,n) | **N–M** | Một phiếu thu nhiều đăng ký; một đăng ký có thể đóng nhiều lần |
| 21 | Dùng | NHANVIEN – TAIKHOAN | (0,1) – (0,1) | **1–1** | Tài khoản ứng dụng của nhân viên |
| 22 | Dùng | HOCVIEN – TAIKHOAN | (0,1) – (0,1) | **1–1** | Tài khoản ứng dụng của học viên |

**Đối chiếu yêu cầu đề cương:** ERD có đủ 1–1 (#2, #21, #22), 1–N (#1, #6, #8…), N–M (#16, #17, #20), đệ quy (#3, #7), 3 ngôi (#11), thực thể yếu (#5, #12) và chuyên biệt hoá (#4).

## 2.2 Từ điển dữ liệu

Từ điển dưới đây được sinh trực tiếp từ CSDL sau khi cài đặt (`01_schema.sql`, mục 2.7) nên luôn khớp với script. Ký hiệu: **PK** khoá chính, FK khoá ngoại, ✓ cho phép NULL.

#### CHINHANH – Chi nhánh trung tâm

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaCN | Mã chi nhánh | CHAR(4) |  | **PK**; CHECK `([MaCN] like 'CN[0-9][0-9]')` |
| TenCN | Tên chi nhánh | NVARCHAR(100) |  |  |
| DiaChi | Địa chỉ | NVARCHAR(200) |  |  |
| SoDienThoai | Số điện thoại | VARCHAR(15) |  | CHECK `(NOT [SoDienThoai] like '%[^0-9]%')` |
| NgayThanhLap | Ngày thành lập | DATE |  |  |
| MaNVQuanLy | Mã nhân viên quản lý | CHAR(6) | ✓ | FK → NHANVIEN |

#### NHANVIEN – Nhân viên

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaNV | Mã nhân viên | CHAR(6) |  | **PK**; CHECK `([MaNV] like 'NV[0-9][0-9][0-9][0-9]')` |
| HoNV | Họ và tên lót | NVARCHAR(50) |  |  |
| TenNV | Tên | NVARCHAR(20) |  |  |
| NgaySinh | Ngày sinh | DATE |  |  |
| GioiTinh | Giới tính | NVARCHAR(3) |  | CHECK `([GioiTinh]=N'Nữ' OR [GioiTinh]=N'Nam')` |
| SoDienThoai | Số điện thoại | VARCHAR(15) |  |  |
| Email | Thư điện tử | VARCHAR(100) |  | CHECK `([Email] like '%_@_%._%')` |
| ChucVu | Chức vụ | NVARCHAR(20) |  | CHECK `([ChucVu]=N'Giáo viên' OR [ChucVu]=N'Kế toán' OR [ChucVu]=N'Giáo vụ' OR [ChucVu]=N'Quản lý')` |
| LuongCoBan | Lương cơ bản / tháng (VNĐ) | DECIMAL(12,0) |  | DEFAULT `((0))`; CHECK `([LuongCoBan]>=(0))` |
| NgayVaoLam | Ngày vào làm | DATE |  | DEFAULT `(CONVERT([date],getdate()))` |
| MaCN | Mã chi nhánh | CHAR(4) |  | FK → CHINHANH |
| MaNVQuanLy | Mã nhân viên quản lý | CHAR(6) | ✓ | FK → NHANVIEN |
| TrangThai | Trạng thái | BIT |  | DEFAULT `((1))` |
| HoTen | Họ tên đầy đủ (suy diễn) | (tính toán) |  | Tính toán: `(([HoNV]+N' ')+[TenNV])` |

#### GIAOVIEN – Giáo viên (chuyên biệt hoá NHANVIEN)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaGV | Mã giáo viên (= MaNV) | CHAR(6) |  | **PK**; FK → NHANVIEN |
| LoaiGV | Loại giáo viên | NVARCHAR(20) |  | CHECK `([LoaiGV]=N'Bản ngữ' OR [LoaiGV]=N'Việt Nam')` |
| QuocTich | Quốc tịch | NVARCHAR(50) |  | DEFAULT `(N'Việt Nam')` |
| TrinhDo | Trình độ học vấn | NVARCHAR(30) |  | CHECK `([TrinhDo]=N'Tiến sĩ' OR [TrinhDo]=N'Thạc sĩ' OR [TrinhDo]=N'Cử nhân')` |
| DonGiaBuoi | Đơn giá mỗi buổi dạy (VNĐ) | DECIMAL(10,0) |  | CHECK `([DonGiaBuoi]>=(100000) AND [DonGiaBuoi]<=(5000000))` |

#### CHUNGCHI_GV – Chứng chỉ giáo viên (thuộc tính đa trị)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaGV | Mã giáo viên (= MaNV) | CHAR(6) |  | **PK**; FK → GIAOVIEN |
| TenChungChi | Tên chứng chỉ | NVARCHAR(50) |  | **PK** |
| Diem | Điểm chứng chỉ | DECIMAL(5,1) | ✓ | CHECK `([Diem] IS NULL OR [Diem]>=(0))` |
| NgayCap | Ngày cấp | DATE |  |  |
| NoiCap | Nơi cấp | NVARCHAR(100) | ✓ |  |

#### PHONGHOC – Phòng học (thực thể yếu)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaCN | Mã chi nhánh | CHAR(4) |  | **PK**; FK → CHINHANH |
| MaPhong | Số phòng | VARCHAR(5) |  | **PK** |
| SucChua | Sức chứa (người) | TINYINT |  | CHECK `([SucChua]>=(5) AND [SucChua]<=(60))` |
| LoaiPhong | Loại phòng | NVARCHAR(20) |  | DEFAULT `(N'Thường')`; CHECK `([LoaiPhong]=N'Hội trường' OR [LoaiPhong]=N'Lab' OR [LoaiPhong]=N'Thường')` |

#### CAHOC – Ca học

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaCa | Mã ca | TINYINT |  | **PK** |
| TenCa | Tên ca | NVARCHAR(30) |  |  |
| GioBatDau | Giờ bắt đầu | TIME(0) |  |  |
| GioKetThuc | Giờ kết thúc | TIME(0) |  |  |

#### CHUONGTRINH – Chương trình đào tạo

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaCT | Mã chương trình | VARCHAR(5) |  | **PK** |
| TenCT | Tên chương trình | NVARCHAR(100) |  |  |
| DoiTuong | Đối tượng học viên | NVARCHAR(100) |  |  |
| MoTa | Mô tả | NVARCHAR(500) | ✓ |  |

#### KHOAHOC – Khoá học

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaKH | Mã khoá học | VARCHAR(6) |  | **PK** |
| TenKH | Tên khoá học | NVARCHAR(100) |  |  |
| MaCT | Mã chương trình | VARCHAR(5) |  | FK → CHUONGTRINH |
| CapDo | Cấp độ trong chương trình | TINYINT |  |  |
| DiemDauVaoTu | Điểm test đầu vào tối thiểu | DECIMAL(3,1) |  |  |
| DiemDauVaoDen | Điểm test đầu vào tối đa | DECIMAL(3,1) |  |  |
| MucTieuDauRa | Mục tiêu đầu ra | NVARCHAR(50) |  |  |
| SoBuoi | Số buổi | TINYINT |  | CHECK `([SoBuoi]>=(8) AND [SoBuoi]<=(60))` |
| HocPhi | Học phí (VNĐ) | DECIMAL(12,0) |  | CHECK `([HocPhi]>(0))` |
| MaKHTienQuyet | Mã khoá tiên quyết | VARCHAR(6) | ✓ | FK → KHOAHOC |

#### LOPHOC – Lớp học

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaLop | Mã lớp | VARCHAR(10) |  | **PK** |
| TenLop | Tên lớp | NVARCHAR(100) |  |  |
| MaKH | Mã khoá học | VARCHAR(6) |  | FK → KHOAHOC |
| MaCN | Mã chi nhánh | CHAR(4) |  | FK → CHINHANH |
| MaGV | Mã giáo viên (= MaNV) | CHAR(6) |  | FK → GIAOVIEN |
| NgayKhaiGiang | Ngày khai giảng | DATE |  |  |
| NgayKetThuc | Ngày kết thúc | DATE | ✓ |  |
| SiSoToiDa | Sĩ số tối đa | TINYINT |  | DEFAULT `((20))`; CHECK `([SiSoToiDa]>=(5) AND [SiSoToiDa]<=(40))` |
| SiSoHienTai | Sĩ số hiện tại (suy diễn, trigger) | TINYINT |  | DEFAULT `((0))` |
| TrangThai | Trạng thái | NVARCHAR(20) |  | DEFAULT `(N'Sắp mở')`; CHECK `([TrangThai]=N'Huỷ' OR [TrangThai]=N'Đã kết thúc' OR [TrangThai]=N'Đang học' OR [TrangThai]=N'Sắp mở')` |

#### LICHHOC – Lịch học (liên kết 3 ngôi)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaLop | Mã lớp | VARCHAR(10) |  | **PK**; FK → LOPHOC |
| Thu | Thứ trong tuần (2–8) | TINYINT |  | **PK**; CHECK `([Thu]>=(2) AND [Thu]<=(8))` |
| MaCa | Mã ca | TINYINT |  | **PK**; FK → CAHOC |
| MaCN | Mã chi nhánh | CHAR(4) |  | FK → LOPHOC |
| MaPhong | Số phòng | VARCHAR(5) |  | FK → PHONGHOC |

#### BUOIHOC – Buổi học (thực thể yếu)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaLop | Mã lớp | VARCHAR(10) |  | **PK**; FK → LOPHOC |
| STT | Số thứ tự buổi | TINYINT |  | **PK**; CHECK `([STT]>=(1))` |
| NgayHoc | Ngày học | DATE |  |  |
| MaCa | Mã ca | TINYINT |  | FK → CAHOC |
| MaPhong | Số phòng | VARCHAR(5) | ✓ |  |
| NoiDung | Nội dung buổi học | NVARCHAR(200) | ✓ |  |
| TrangThai | Trạng thái | NVARCHAR(20) |  | DEFAULT `(N'Đã lên lịch')`; CHECK `([TrangThai]=N'Nghỉ' OR [TrangThai]=N'Đã dạy' OR [TrangThai]=N'Đã lên lịch')` |

#### NGAYLE – Ngày nghỉ lễ (phụ trợ)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| Ngay | Ngày | DATE |  | **PK** |
| TenNgayLe | Tên ngày lễ | NVARCHAR(100) |  |  |

#### HOCVIEN – Học viên

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaHV | Mã học viên | CHAR(6) |  | **PK**; CHECK `([MaHV] like 'HV[0-9][0-9][0-9][0-9]')` |
| HoHV | Họ và tên lót | NVARCHAR(50) |  |  |
| TenHV | Tên | NVARCHAR(20) |  |  |
| NgaySinh | Ngày sinh | DATE |  |  |
| GioiTinh | Giới tính | NVARCHAR(3) |  | CHECK `([GioiTinh]=N'Nữ' OR [GioiTinh]=N'Nam')` |
| SoDienThoai | Số điện thoại | VARCHAR(15) |  | CHECK `(len([SoDienThoai])>=(9) AND len([SoDienThoai])<=(11) AND NOT [SoDienThoai] like '%[^0-9]%')` |
| Email | Thư điện tử | VARCHAR(100) | ✓ | CHECK `([Email] IS NULL OR [Email] like '%_@_%._%')` |
| SoNha | Số nhà, đường | NVARCHAR(100) | ✓ |  |
| PhuongXa | Phường / xã | NVARCHAR(50) | ✓ |  |
| QuanHuyen | Quận / huyện | NVARCHAR(50) | ✓ |  |
| TinhTP | Tỉnh / thành phố | NVARCHAR(50) |  | DEFAULT `(N'TP. Hồ Chí Minh')` |
| HoTenPhuHuynh | Họ tên phụ huynh | NVARCHAR(70) | ✓ |  |
| NgayTao | Ngày tạo | DATE |  | DEFAULT `(CONVERT([date],getdate()))` |
| MaCN | Mã chi nhánh | CHAR(4) |  | FK → CHINHANH |
| TrangThai | Trạng thái | BIT |  | DEFAULT `((1))` |
| HoTen | Họ tên đầy đủ (suy diễn) | (tính toán) |  | Tính toán: `(([HoHV]+N' ')+[TenHV])` |
| Tuoi | Tuổi (suy diễn) | (tính toán) | ✓ | Tính toán: `(datediff(year,[NgaySinh],getdate())-case when dateadd(year,datediff(year,[NgaySinh],getdate()),[NgaySinh])>getdate() then (1) else (0) end)` |

#### KIEMTRA_DAUVAO – Kiểm tra đầu vào

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaKT | Mã lần kiểm tra | INT |  | **PK**; IDENTITY |
| MaHV | Mã học viên | CHAR(6) |  | FK → HOCVIEN |
| NgayKT | Ngày kiểm tra | DATE |  | DEFAULT `(CONVERT([date],getdate()))` |
| DiemTong | Điểm tổng (TB 4 kỹ năng) | DECIMAL(3,1) |  | CHECK `([DiemTong]>=(0) AND [DiemTong]<=(10))` |
| KetQuaChiTiet | Kết quả chi tiết (XML) | XML |  |  |
| MaKHDeXuat | Khoá học đề xuất | VARCHAR(6) | ✓ | FK → KHOAHOC |
| MaNVCham | Nhân viên chấm | CHAR(6) | ✓ | FK → NHANVIEN |

#### DANGKY – Đăng ký học (N–M có thuộc tính)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaDK | Mã đăng ký | INT |  | **PK**; IDENTITY |
| MaHV | Mã học viên | CHAR(6) |  | FK → HOCVIEN |
| MaLop | Mã lớp | VARCHAR(10) |  | FK → LOPHOC |
| NgayDK | Ngày đăng ký | DATE |  | DEFAULT `(CONVERT([date],getdate()))` |
| HocPhi | Học phí (VNĐ) | DECIMAL(12,0) |  | CHECK `([HocPhi]>(0))` |
| GiamGia | Giảm giá (%) | DECIMAL(5,2) |  | DEFAULT `((0))`; CHECK `([GiamGia]>=(0) AND [GiamGia]<=(50))` |
| ThanhTien | Thành tiền = HocPhi × (100 − GiamGia)% | (tính toán) | ✓ | Tính toán PERSISTED: `(CONVERT([decimal](12,0),round(([HocPhi]*((100)-[GiamGia]))/(100),(-3))))` |
| HanDongHP | Hạn đóng học phí = NgayDK + 14 | (tính toán) | ✓ | Tính toán PERSISTED: `(dateadd(day,(14),[NgayDK]))` |
| TrangThaiHP | Trạng thái học phí (trigger) | NVARCHAR(20) |  | DEFAULT `(N'Chưa đóng')`; CHECK `([TrangThaiHP]=N'Đã đóng' OR [TrangThaiHP]=N'Đóng một phần' OR [TrangThaiHP]=N'Chưa đóng')` |
| DiemGK | Điểm giữa kỳ | DECIMAL(4,2) | ✓ | CHECK `([DiemGK]>=(0) AND [DiemGK]<=(10))` |
| DiemCK | Điểm cuối kỳ | DECIMAL(4,2) | ✓ | CHECK `([DiemCK]>=(0) AND [DiemCK]<=(10))` |
| DiemTB | Điểm TB = 0,4·GK + 0,6·CK | (tính toán) | ✓ | Tính toán PERSISTED: `(CONVERT([decimal](4,2),round([DiemGK]*(0.4)+[DiemCK]*(0.6),(2))))` |
| KetQua | Kết quả (trigger) | NVARCHAR(10) | ✓ | CHECK `([KetQua]=N'Không đạt' OR [KetQua]=N'Đạt')` |
| TrangThai | Trạng thái | NVARCHAR(20) |  | DEFAULT `(N'Đang học')`; CHECK `([TrangThai]=N'Huỷ' OR [TrangThai]=N'Đã chuyển lớp' OR [TrangThai]=N'Bảo lưu' OR [TrangThai]=N'Hoàn thành' OR [TrangThai]=N'Đang học')` |

#### DIEMDANH – Điểm danh

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaDK | Mã đăng ký | INT |  | **PK**; FK → DANGKY |
| MaLop | Mã lớp | VARCHAR(10) |  | **PK**; FK → DANGKY |
| STT | Số thứ tự buổi | TINYINT |  | **PK**; FK → BUOIHOC |
| TrangThai | Trạng thái | NVARCHAR(10) |  | DEFAULT `(N'Có mặt')`; CHECK `([TrangThai]=N'Có phép' OR [TrangThai]=N'Muộn' OR [TrangThai]=N'Vắng' OR [TrangThai]=N'Có mặt')` |
| GhiChu | Ghi chú | NVARCHAR(200) | ✓ |  |

#### CANHBAO_CHUYENCAN – Cảnh báo chuyên cần (phụ trợ)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaCB | Mã cảnh báo | INT |  | **PK**; IDENTITY |
| MaDK | Mã đăng ký | INT |  | FK → DANGKY |
| NgayCanhBao | Ngày cảnh báo | DATE |  | DEFAULT `(CONVERT([date],getdate()))` |
| SoBuoiDaHoc | Số buổi đã diễn ra | TINYINT |  |  |
| SoBuoiVang | Số buổi vắng | TINYINT |  |  |
| TyLeVang | Tỷ lệ vắng (%) | DECIMAL(5,2) |  |  |
| MucDo | Mức độ | NVARCHAR(20) |  | CHECK `([MucDo]=N'Nghiêm trọng' OR [MucDo]=N'Nhắc nhở')` |
| DaXuLy | Đã xử lý | BIT |  | DEFAULT `((0))` |

#### PHIEUTHU – Phiếu thu (master)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaPT | Mã phiếu thu | INT |  | **PK**; IDENTITY |
| SoPhieu | Số phiếu (suy diễn) | (tính toán) | ✓ | Tính toán PERSISTED: `('PT'+right('000000'+CONVERT([varchar](10),[MaPT]),(6)))` |
| MaHV | Mã học viên | CHAR(6) |  | FK → HOCVIEN |
| MaNV | Mã nhân viên | CHAR(6) |  | FK → NHANVIEN |
| NgayThu | Thời điểm thu | DATETIME2(0) |  | DEFAULT `(sysdatetime())` |
| HinhThuc | Hình thức thanh toán | NVARCHAR(20) |  | DEFAULT `(N'Tiền mặt')`; CHECK `([HinhThuc]=N'Thẻ' OR [HinhThuc]=N'Chuyển khoản' OR [HinhThuc]=N'Tiền mặt')` |
| TongTien | Tổng tiền = Σ chi tiết (trigger) | DECIMAL(12,0) |  | DEFAULT `((0))`; CHECK `([TongTien]>=(0))` |
| GhiChu | Ghi chú | NVARCHAR(200) | ✓ |  |

#### CT_PHIEUTHU – Chi tiết phiếu thu (detail)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaPT | Mã phiếu thu | INT |  | **PK**; FK → PHIEUTHU |
| MaDK | Mã đăng ký | INT |  | **PK**; FK → DANGKY |
| SoTien | Số tiền thu cho đăng ký | DECIMAL(12,0) |  | CHECK `([SoTien]>(0))` |

#### BANGLUONG – Bảng lương giáo viên (phụ trợ)

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| Thang | Tháng lương (yyyy-MM) | CHAR(7) |  | **PK**; CHECK `([Thang] like '[2][0-9][0-9][0-9]-[01][0-9]')` |
| MaGV | Mã giáo viên (= MaNV) | CHAR(6) |  | **PK**; FK → GIAOVIEN |
| SoBuoiDay | Số buổi đã dạy | SMALLINT |  |  |
| DonGiaBuoi | Đơn giá mỗi buổi dạy (VNĐ) | DECIMAL(10,0) |  |  |
| LuongCoBan | Lương cơ bản / tháng (VNĐ) | DECIMAL(12,0) |  |  |
| TongLuong | Tổng lương (suy diễn) | (tính toán) | ✓ | Tính toán PERSISTED: `([LuongCoBan]+[SoBuoiDay]*[DonGiaBuoi])` |
| NgayTinh | Ngày tính | DATETIME2(0) |  | DEFAULT `(sysdatetime())` |

#### TAIKHOAN – Tài khoản ứng dụng

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| TenDangNhap | Tên đăng nhập | VARCHAR(30) |  | **PK** |
| MatKhauHash | Mật khẩu đã băm SHA2_256 | VARBINARY(32) |  |  |
| Salt | Chuỗi ngẫu nhiên trộn khi băm | VARBINARY(16) |  |  |
| VaiTro | Vai trò | VARCHAR(10) |  | CHECK `([VaiTro]='HocVien' OR [VaiTro]='GiaoVien' OR [VaiTro]='KeToan' OR [VaiTro]='GiaoVu' OR [VaiTro]='QuanLy')` |
| MaNV | Mã nhân viên | CHAR(6) | ✓ | FK → NHANVIEN |
| MaHV | Mã học viên | CHAR(6) | ✓ | FK → HOCVIEN |
| TrangThai | Trạng thái | BIT |  | DEFAULT `((1))` |
| SoLanSai | Số lần nhập sai liên tiếp | TINYINT |  | DEFAULT `((0))` |
| LanDangNhapCuoi | Lần đăng nhập cuối | DATETIME2(0) | ✓ |  |
| NgayTao | Ngày tạo | DATETIME2(0) |  | DEFAULT `(sysdatetime())` |

#### NHATKY – Nhật ký kiểm toán

| Cột | Ý nghĩa | Kiểu | Null | Ràng buộc / miền giá trị |
|---|---|---|:---:|---|
| MaNK | Mã nhật ký | BIGINT |  | **PK**; IDENTITY |
| TenBang | Bảng bị thay đổi | SYSNAME |  |  |
| ThaoTac | Thao tác | VARCHAR(6) |  | CHECK `([ThaoTac]='DELETE' OR [ThaoTac]='UPDATE' OR [ThaoTac]='INSERT')` |
| KhoaChinh | Khoá chính dòng bị thay đổi | NVARCHAR(100) | ✓ |  |
| DuLieuCu | Dữ liệu cũ (JSON) | NVARCHAR(MAX) | ✓ | CHECK `([DuLieuCu] IS NULL OR isjson([DuLieuCu])=(1))` |
| DuLieuMoi | Dữ liệu mới (JSON) | NVARCHAR(MAX) | ✓ | CHECK `([DuLieuMoi] IS NULL OR isjson([DuLieuMoi])=(1))` |
| NguoiThucHien | Login SQL Server thực hiện | NVARCHAR(128) |  | DEFAULT `(suser_sname())` |
| NguoiDungUD | Tài khoản ứng dụng | NVARCHAR(30) | ✓ |  |
| ThoiGian | Thời điểm | DATETIME2(3) |  | DEFAULT `(sysdatetime())` |


## 2.3 Sơ đồ lớp (Class Diagram – UML)

![Class Diagram](../docs/design/class-diagram.png)

*Hình 2.3 – Class Diagram của ECMS (file nguồn `docs/design/class-diagram.drawio`). Phạm vi truy cập: `+` public, `-` private, `#` protected.*

### 2.3.1 Các lớp chính

| Lớp | Thuộc tính tiêu biểu | Phương thức | Ứng với bảng / đối tượng CSDL |
|---|---|---|---|
| «abstract» Nguoi | # ho, # ten, # ngaySinh, # gioiTinh | + hoTen(), + tuoi() | Cột chung của HOCVIEN, NHANVIEN; `Tuoi` computed |
| HocVien | - maHV, - diaChi : DiaChi | + dangKy(), + congNo(), + lichHoc() | HOCVIEN; `sp_DangKyHoc`, `fn_SoTienConNo`, `fn_LichHocHocVien` |
| NhanVien | - chucVu, - luongCoBan | + nguoiQuanLy(), + lapPhieuThu() | NHANVIEN; `sp_ThuHocPhi` |
| GiaoVien | - loaiGV, - donGiaBuoi | + lopDangDay(), + tinhLuong() | GIAOVIEN; `fn_LopCuaGiaoVien`, `sp_TinhLuongGiaoVien` |
| LopHoc | - maLop, - siSoToiDa | + siSoHienTai(), + siSoConLai(), + xepLich(), + sinhBuoiHoc() | LOPHOC; trigger sĩ số, `sp_XepLichLop`, `sp_SinhBuoiHoc` |
| DangKy «association class» | - hocPhi, - giamGia, - diemGK, - diemCK | + thanhTien(), + diemTB(), + ketQua(), + tyLeChuyenCan() | DANGKY; computed column, `fn_TyLeChuyenCan` |
| PhieuThu | - soPhieu, - ngayThu | + tinhTong(), + themDong(), + inPDF() | PHIEUTHU; trigger tổng tiền, báo cáo PDF |
| KiemTraDauVao | - listening, reading, writing, speaking | + diemTong(), + deXuatKhoa() | KIEMTRA_DAUVAO (XML) |

### 2.3.2 Các loại quan hệ giữa lớp

| Quan hệ | Ký hiệu | Ví dụ trong ECMS | Ý nghĩa |
|---|---|---|---|
| **Kế thừa** (generalization) | Tam giác rỗng | Nguoi ← HocVien; Nguoi ← NhanVien ← GiaoVien | GiaoVien *là một* NhanVien, kế thừa họ tên, ngày sinh, phương thức tuoi() |
| **Thành phần** (composition) | Kim cương đặc | LopHoc ◆— BuoiHoc; PhieuThu ◆— CTPhieuThu; ChiNhanh ◆— PhongHoc; GiaoVien ◆— ChungChi | Bộ phận không tồn tại độc lập: xoá lớp thì xoá buổi học (`ON DELETE CASCADE`) |
| **Kết tập** (aggregation) | Kim cương rỗng | ChuongTrinh ◇— KhoaHoc | Khoá học thuộc chương trình nhưng vẫn có ý nghĩa riêng; xoá chương trình không xoá khoá (FK không cascade) |
| **Kết hợp** (association) có bản số | Đường thẳng | GiaoVien 1 — 0..* LopHoc; KhoaHoc 0..1 — 0..* KhoaHoc (tiên quyết) | Liên kết thông thường, có thể đệ quy |
| **Lớp liên kết** (association class) | Nét đứt nối vào kết hợp | DangKy gắn với kết hợp HocVien 0..* — 0..* LopHoc | Kết hợp N–M có thuộc tính riêng |

### 2.3.3 So sánh ERD và Class Diagram trên bài toán ECMS

| Tiêu chí | ERD (Chen) | Class Diagram (UML) |
|---|---|---|
| Mục đích | Mô hình **dữ liệu** cần lưu trữ, làm cơ sở thiết kế CSDL quan hệ | Mô hình **đối tượng**: dữ liệu + hành vi, cơ sở thiết kế phần mềm hướng đối tượng |
| Thành phần | Thực thể, thuộc tính, mối kết hợp | Lớp, thuộc tính, **phương thức**, quan hệ |
| Hành vi | Không thể hiện; nghiệp vụ nằm ở procedure/trigger | `LopHoc.siSoConLai()`, `PhieuThu.tinhTong()` nằm ngay trong lớp |
| Đóng gói | Không có | Phạm vi truy cập `+ - #` |
| Thuộc tính phức hợp | Elip con (Địa chỉ → Số nhà, Phường…) | Kiểu dữ liệu riêng `diaChi : DiaChi` |
| Thuộc tính đa trị | Elip đôi, khi cài đặt phải tách bảng | Thuộc tính kiểu tập hợp hoặc lớp thành phần ChungChi |
| Thuộc tính suy diễn | Elip nét đứt (Tuổi, Thành tiền) | Phương thức `tuoi()`, `thanhTien()` |
| Chuyên biệt hoá | ISA, ràng buộc rời nhau / toàn phần | Kế thừa, đa hình (ghi đè phương thức) |
| Bản số | (min,max) đặt cạnh thực thể | Multiplicity `0..1, 1..*, *` đặt ở đầu kia |
| Quan hệ toàn thể – bộ phận | Chỉ biểu diễn gián tiếp qua thực thể yếu / quan hệ xác định | Phân biệt rõ composition và aggregation |
| N–M có thuộc tính | Mối kết hợp có thuộc tính (ĐĂNG KÝ) | Lớp liên kết DangKy |
| Chuyển sang cài đặt | Gần như 1–1 sang lược đồ quan hệ (mục 2.4) | Sang mã nguồn hoặc CSDL hướng đối tượng (Chương 5) |

**Nhận xét:** hai sơ đồ nhất quán về tập lớp/thực thể và bản số. ERD phù hợp để thiết kế CSDL quan hệ của đồ án; Class Diagram bổ sung góc nhìn hành vi – các phương thức trong sơ đồ được hiện thực trong CSDL dưới dạng function/procedure (Chương 3) và là nền cho lược đồ ODL ở Chương 5.

## 2.4 Mô hình quan hệ và chuẩn hoá

### 2.4.1 Quy tắc chuyển ERD sang lược đồ quan hệ

| Cấu trúc ERD | Quy tắc | Áp dụng trong ECMS |
|---|---|---|
| Thực thể mạnh | Mỗi thực thể → 1 quan hệ, khoá thực thể → khoá chính | CHINHANH, HOCVIEN, KHOAHOC, … |
| Thực thể yếu | Quan hệ mới, khoá chính = khoá thực thể chủ + khoá bộ phận | PHONGHOC (<u>MaCN, MaPhong</u>), BUOIHOC (<u>MaLop, STT</u>) |
| Thuộc tính phức hợp | Chỉ giữ thuộc tính thành phần | HoHV, TenHV; SoNha, PhuongXa, QuanHuyen, TinhTP |
| Thuộc tính đa trị | Quan hệ riêng gồm khoá thực thể + giá trị | CHUNGCHI_GV (<u>MaGV, TenChungChi</u>, …) |
| Thuộc tính suy diễn | Không lưu, hoặc lưu có kiểm soát | Computed column / trigger (xem `docs/design/relational-schema.md`) |
| 1–1 | Đặt khoá ngoại ở phía tham gia một phần + UNIQUE | CHINHANH.*MaNVQuanLy* (UNIQUE có lọc), TAIKHOAN.*MaNV*, *MaHV* |
| 1–N | Khoá ngoại đặt ở phía N | LOPHOC.*MaKH*, *MaCN*, *MaGV*; PHIEUTHU.*MaHV* |
| N–M | Quan hệ mới, khoá = tổ hợp khoá hai phía (+ thuộc tính kết hợp) | DANGKY (khoá thay thế MaDK, UNIQUE(MaHV, MaLop)), CT_PHIEUTHU, DIEMDANH |
| Đệ quy | Khoá ngoại trỏ về chính quan hệ | NHANVIEN.*MaNVQuanLy*, KHOAHOC.*MaKHTienQuyet* |
| 3 ngôi | Quan hệ mới chứa khoá của cả ba thực thể | LICHHOC (<u>*MaLop*, Thu, *MaCa*</u>, *MaCN*, *MaPhong*) |
| Chuyên biệt hoá | Quan hệ cho lớp cha + quan hệ cho lớp con, khoá lớp con = khoá lớp cha (phương án "mỗi lớp một bảng") | NHANVIEN, GIAOVIEN (<u>*MaGV*</u>) |

**Vì sao DANGKY dùng khoá thay thế MaDK?** Khoá tự nhiên (MaHV, MaLop) vẫn được giữ bằng UNIQUE, nhưng MaDK (INT IDENTITY) ngắn hơn khi làm khoá ngoại ở DIEMDANH, CT_PHIEUTHU, CANHBAO_CHUYENCAN – giảm kích thước chỉ mục và đơn giản tham số procedure.

### 2.4.2 Lược đồ quan hệ

Lược đồ đầy đủ 22 quan hệ (gạch chân khoá chính, in nghiêng khoá ngoại) và bảng phụ thuộc hàm từng quan hệ: [`docs/design/relational-schema.md`](../docs/design/relational-schema.md).

### 2.4.3 Kiểm tra dạng chuẩn

- **1NF:** mọi thuộc tính nguyên tố – thuộc tính phức hợp đã tách cột, đa trị đã tách bảng. Riêng `KetQuaChiTiet` (XML) được xem là một giá trị nguyên tố đối với mô hình quan hệ, chỉ được phân tích bằng phương thức XML (T10).
- **2NF:** quan hệ có khoá phức hợp (CHUNGCHI_GV, PHONGHOC, LICHHOC, BUOIHOC, DIEMDANH, CT_PHIEUTHU, BANGLUONG) không có thuộc tính không khoá phụ thuộc một phần vào khoá, **trừ LICHHOC.MaCN** (giữ có chủ đích, xem dưới).
- **3NF/BCNF:** 17/22 quan hệ đạt BCNF. Các phụ thuộc bắc cầu còn lại đều thuộc về thuộc tính suy diễn được SQL Server tự tính (computed column) hoặc duy trì bằng trigger, nên không gây dị thường cập nhật.

| Quan hệ | Chỗ chưa đạt BCNF | Lý do giữ | Cơ chế bảo đảm nhất quán |
|---|---|---|---|
| LICHHOC | MaLop → MaCN (phụ thuộc một phần) | FK (MaCN, MaPhong) bắt phòng thuộc đúng chi nhánh của lớp | FK (MaLop, MaCN) → LOPHOC(MaLop, MaCN) |
| DIEMDANH | MaDK → MaLop | FK (MaLop, STT) bắt buổi học thuộc đúng lớp của đăng ký | FK (MaDK, MaLop) → DANGKY(MaDK, MaLop) |
| DANGKY | HocPhi, GiamGia → ThanhTien; GK, CK → DiemTB | Truy vấn công nợ, bảng điểm nhanh | Computed column PERSISTED |
| LOPHOC | SiSoHienTai = đếm DANGKY | Kiểm tra lớp còn chỗ ở mỗi lần ghi danh | Trigger `trg_DangKy_SiSo` |
| PHIEUTHU | TongTien = Σ CT_PHIEUTHU | Báo cáo doanh thu | Trigger `trg_CTPhieuThu_TongTien` |

**So sánh phương án chuẩn hoá đầy đủ cho LICHHOC.** Nếu bỏ MaCN khỏi LICHHOC (đạt BCNF), FK tới PHONGHOC phải đổi thành (MaPhong) – không đủ vì MaPhong chỉ duy nhất trong một chi nhánh – hoặc dùng trigger tra ngược LOPHOC.MaCN mỗi lần thêm/sửa lịch. Phương án giữ MaCN tốn 4 byte/dòng nhưng để CSDL tự kiểm tra bằng ràng buộc khai báo, nhanh và không thể bị bỏ qua. Nhóm chọn phương án này.

## 2.5 Ràng buộc toàn vẹn

### 2.5.1 Đặc tả

| Mã | Loại | Nội dung | Bối cảnh | Cài đặt |
|---|---|---|---|---|
| RB01 | Miền giá trị | Giới tính ∈ {Nam, Nữ} | NHANVIEN, HOCVIEN | CHECK |
| RB02 | Miền giá trị | 0 ≤ DiemGK, DiemCK ≤ 10; 0 ≤ GiamGia ≤ 50 (%) | DANGKY | CHECK |
| RB03 | Miền giá trị | Trạng thái điểm danh ∈ {Có mặt, Vắng, Muộn, Có phép} | DIEMDANH | CHECK |
| RB04 | Liên thuộc tính | GioKetThuc > GioBatDau | CAHOC | CHECK |
| RB05 | Liên thuộc tính | NgayKetThuc > NgayKhaiGiang | LOPHOC | CHECK |
| RB06 | Liên thuộc tính | SiSoHienTai ≤ SiSoToiDa | LOPHOC | CHECK + trigger chặn khi lớp đầy |
| RB07 | Liên thuộc tính | Nhân viên đủ 18 tuổi khi vào làm | NHANVIEN | CHECK |
| RB08 | Liên bộ | Mỗi học viên đăng ký một lớp tối đa một lần | DANGKY | UNIQUE (MaHV, MaLop) |
| RB09 | Liên bộ | Một phòng, một ca, một thứ chỉ có một lớp trong cùng khoảng thời gian | LICHHOC × LOPHOC | Trigger `trg_LichHoc_KiemTraTrung`, `sp_XepLichLop` |
| RB10 | Liên bộ | Giáo viên không dạy hai lớp cùng thứ – ca trong cùng khoảng thời gian | LICHHOC × LOPHOC | Trigger `trg_LichHoc_KiemTraTrung` |
| RB11 | Khoá ngoại | Mỗi lớp thuộc một khoá học, chi nhánh, giáo viên đang tồn tại | LOPHOC | FOREIGN KEY |
| RB12 | Liên quan hệ | Phòng của lịch học phải thuộc chi nhánh của lớp | LICHHOC, LOPHOC, PHONGHOC | FK phức hợp (MaLop, MaCN), (MaCN, MaPhong) |
| RB13 | Liên quan hệ | Học viên chỉ được điểm danh ở buổi học của lớp mình đăng ký | DIEMDANH, DANGKY, BUOIHOC | FK phức hợp (MaDK, MaLop), (MaLop, STT) |
| RB14 | Liên quan hệ | SiSoHienTai = số đăng ký "Đang học"/"Hoàn thành" của lớp | LOPHOC, DANGKY | Trigger `trg_DangKy_SiSo` |
| RB15 | Liên quan hệ | TongTien phiếu thu = tổng SoTien chi tiết | PHIEUTHU, CT_PHIEUTHU | Trigger `trg_CTPhieuThu_TongTien` |
| RB16 | Liên quan hệ | Đăng ký trong chi tiết phiếu thu phải của chính học viên trên phiếu; tổng đã thu ≤ ThanhTien | CT_PHIEUTHU, PHIEUTHU, DANGKY | Trigger `trg_CTPhieuThu_TongTien` |
| RB17 | Liên quan hệ | Học viên chỉ đăng ký khoá có tiên quyết khi đã *Đạt* khoá tiên quyết | DANGKY, LOPHOC, KHOAHOC | `sp_DangKyHoc` |
| RB18 | Liên quan hệ | Tài khoản vai trò HocVien gắn MaHV, các vai trò khác gắn MaNV | TAIKHOAN | CHECK |

### 2.5.2 Bảng tầm ảnh hưởng

Ký hiệu: **+** thao tác có thể vi phạm ràng buộc (phải kiểm tra), **–** không vi phạm, **+(cột)** chỉ vi phạm khi sửa cột đó.

| RBTV | Quan hệ | Thêm | Xoá | Sửa |
|---|---|:-:|:-:|:-:|
| RB05 | LOPHOC | + | – | +(NgayKhaiGiang, NgayKetThuc) |
| RB06 / RB14 | LOPHOC | + | – | +(SiSoToiDa, SiSoHienTai) |
| | DANGKY | + | + | +(MaLop, TrangThai) |
| RB08 | DANGKY | + | – | +(MaHV, MaLop) |
| RB09 / RB10 | LICHHOC | + | – | +(Thu, MaCa, MaPhong) |
| | LOPHOC | – | – | +(MaGV, NgayKhaiGiang, NgayKetThuc) |
| RB12 | LICHHOC | + | – | +(MaCN, MaPhong) |
| | LOPHOC | – | – | +(MaCN) – bị FK chặn |
| | PHONGHOC | – | + | +(MaCN, MaPhong) |
| RB13 | DIEMDANH | + | – | +(MaDK, MaLop, STT) |
| | DANGKY | – | + (cascade) | +(MaLop) |
| | BUOIHOC | – | + | +(MaLop, STT) |
| RB15 / RB16 | CT_PHIEUTHU | + | + | +(SoTien, MaDK) |
| | PHIEUTHU | – | + (cascade) | +(MaHV) |
| | DANGKY | – | + | +(HocPhi, GiamGia) |
| RB17 | DANGKY | + | – | +(MaLop) |
| | DANGKY (của khoá tiên quyết) | – | + | +(KetQua) |

## 2.6 So sánh mô hình phẳng – quan hệ – XML

### 2.6.1 Mô hình phẳng (hiện trạng)

File `docs/design/flat-example.xlsx` mô phỏng file ghi danh Excel của chi nhánh Thủ Đức: mỗi dòng gộp học viên + lớp + khoá + giáo viên + lịch + tiền. Sheet *DiThuong* liệt kê dị thường:

| Dị thường | Ví dụ |
|---|---|
| Dư thừa | Thông tin giáo viên Trần Thị Mai lặp ở 4 dòng |
| Cập nhật | Học viên An có 2 số điện thoại khác nhau ở dòng 1 và 3 |
| Thêm | Không thể ghi nhận lớp TC650-03 khi chưa có học viên |
| Xoá | Xoá dòng của học viên Hà làm mất mức học phí 6.800.000 đã thoả thuận |
| Không nhất quán | "IELTS 5,5" và "IELTS 5.5", "P.101" và "P101" |

### 2.6.2 Mô hình XML cho cùng dữ liệu

```xml
<TrungTam>
  <ChiNhanh MaCN="CN01" Ten="Thủ Đức">
    <Lop MaLop="IE55-01" KhoaHoc="IELTS 5.5" HocPhi="6500000">
      <GiaoVien MaGV="NV0004" HoTen="Trần Thị Mai" SDT="0912000111"/>
      <Lich Thu="2" Ca="5" Phong="P101"/>
      <Lich Thu="4" Ca="5" Phong="P101"/>
      <HocVien MaHV="HV0001" HoTen="Nguyễn Văn An" SDT="0901234567" DaDong="6500000"/>
      <HocVien MaHV="HV0002" HoTen="Lê Thị Bình" SDT="0987654321" DaDong="3000000"/>
    </Lop>
    <Lop MaLop="TC650-02" KhoaHoc="TOEIC 650" HocPhi="5000000">
      <HocVien MaHV="HV0001" HoTen="Nguyễn Văn An" SDT="0901234567" DaDong="5000000"/>
    </Lop>
  </ChiNhanh>
</TrungTam>
```

Cây XML gom dữ liệu theo phân cấp tự nhiên Chi nhánh → Lớp → Học viên, nhưng học viên An học 2 lớp vẫn bị **lặp** ở hai nhánh. Muốn tránh lặp phải dùng tham chiếu `ID/IDREF`, khi đó XML mất ưu điểm đọc trực quan.

### 2.6.3 Bảng so sánh

| Tiêu chí | Phẳng (Excel) | Quan hệ (SQL Server) | XML |
|---|---|---|---|
| Cấu trúc | Một bảng hai chiều | Nhiều quan hệ liên kết qua khoá | Cây phân cấp |
| Lược đồ | Không có (tiêu đề cột) | Bắt buộc, chặt (DDL) | Tuỳ chọn (XSD), linh hoạt |
| Dư thừa | Rất cao | Thấp (chuẩn hoá 3NF/BCNF) | Trung bình (lặp khi quan hệ N–M) |
| Dị thường thêm/xoá/sửa | Có đủ ba loại | Hầu như không | Có với dữ liệu N–M |
| Toàn vẹn | Data validation đơn giản | PK, FK, CHECK, trigger, transaction | XSD kiểm kiểu và cấu trúc, không kiểm liên tài liệu |
| Truy vấn | Lọc, pivot thủ công | SQL mạnh: JOIN, GROUP BY, cửa sổ | XPath/XQuery, tốt cho một cây, kém khi kết nối nhiều tài liệu |
| Đồng thời, phân quyền | Khoá cả file | Theo dòng, theo cột, theo vai trò | Theo tài liệu |
| Trao đổi dữ liệu | CSV, dễ nhưng mất kiểu | Cần export | **Tốt nhất**: tự mô tả, chuẩn mở |
| Dữ liệu cấu trúc thay đổi | Thêm cột tuỳ ý | Phải ALTER TABLE | Thêm phần tử tuỳ ý |
| Phù hợp trong ECMS | Nhập liệu ban đầu, báo cáo gửi đi | **Lưu trữ chính** của toàn hệ thống | Kết quả kiểm tra đầu vào (cấu trúc linh hoạt), trao đổi danh sách lớp với hệ thống khác (T10) |

**Kết luận:** ECMS dùng mô hình quan hệ làm nền, kết hợp kiểu XML cho phần dữ liệu bán cấu trúc (kết quả test đầu vào) – tận dụng ưu điểm của cả hai, đúng hướng các hệ quản trị hiện đại hỗ trợ đa mô hình.

## 2.7 Cài đặt CSDL trên SQL Server

### 2.7.1 Script DDL

Toàn bộ lược đồ nằm trong [`database/01_schema.sql`](../database/01_schema.sql), chạy lại được từ đầu: nếu CSDL `ECMS` đã có thì chuyển sang `SINGLE_USER WITH ROLLBACK IMMEDIATE` để ngắt kết nối rồi `DROP DATABASE`, sau đó tạo mới với collation **`Vietnamese_CI_AS`** (so sánh không phân biệt hoa thường, sắp xếp đúng thứ tự tiếng Việt).

```bash
database/run_all.sh 01      # hoặc mở file trong SSMS, nhấn F5
```

| Thành phần | Số lượng | Ví dụ |
|---|:-:|---|
| Bảng | 22 | 19 bảng nghiệp vụ + NGAYLE, CANHBAO_CHUYENCAN, BANGLUONG |
| PRIMARY KEY | 22 | Khoá phức hợp cho thực thể yếu: `PK_BUOIHOC (MaLop, STT)` |
| FOREIGN KEY | 32 | Khoá ngoại phức hợp `FK_LICHHOC_LOPHOC (MaLop, MaCN)`, `FK_DIEMDANH_DANGKY (MaDK, MaLop)` |
| UNIQUE | 13 + 4 chỉ mục UNIQUE có lọc | `UQ_DANGKY_HV_Lop`; `UX_CHINHANH_QuanLy … WHERE MaNVQuanLy IS NOT NULL` cho quan hệ 1–1 cho phép NULL |
| CHECK | 51 | `CK_LOPHOC_SiSo (SiSoHienTai <= SiSoToiDa)`, `CK_TAIKHOAN_ChuSoHuu` |
| DEFAULT | 29 | `NgayDK DEFAULT GETDATE()`, `NguoiThucHien DEFAULT SUSER_SNAME()` |
| Cột tính toán | 8 | `ThanhTien`, `DiemTB`, `HanDongHP`, `SoPhieu`, `TongLuong` (PERSISTED); `Tuoi`, `HoTen` |
| Cột XML | 1 | `KIEMTRA_DAUVAO.KetQuaChiTiet` (gắn XML Schema ở `09_xml.sql`) |
| Chỉ mục nonclustered | 18 | Xem 2.7.3 |

**Hành vi ON DELETE**

| Khoá ngoại | Hành vi | Lý do |
|---|---|---|
| GIAOVIEN → NHANVIEN, CHUNGCHI_GV → GIAOVIEN | CASCADE | Lớp con / thuộc tính đa trị không tồn tại độc lập |
| PHONGHOC → CHINHANH, BUOIHOC → LOPHOC, LICHHOC → LOPHOC | CASCADE | Thực thể yếu và quan hệ thành phần |
| CT_PHIEUTHU → PHIEUTHU, DIEMDANH → DANGKY | CASCADE | Chi tiết của master–detail |
| DANGKY → HOCVIEN / LOPHOC, PHIEUTHU → HOCVIEN | NO ACTION (mặc định) | Không cho xoá học viên/lớp đã phát sinh học phí – giữ lịch sử tài chính |
| KHOAHOC → CHUONGTRINH | NO ACTION | Quan hệ kết tập: phải chuyển khoá sang chương trình khác trước khi xoá |

SQL Server không cho phép nhiều đường cascade tới cùng một bảng (VD: DIEMDANH vừa từ DANGKY vừa từ BUOIHOC), nên `FK_DIEMDANH_BUOIHOC` để NO ACTION; xoá buổi học phải xoá điểm danh trước (procedure T11 xử lý).

### 2.7.2 Thuộc tính suy diễn bằng computed column

```sql
ThanhTien AS CAST(ROUND(HocPhi * (100 - GiamGia) / 100, -3) AS DECIMAL(12,0)) PERSISTED,
DiemTB    AS CAST(ROUND(DiemGK * 0.4 + DiemCK * 0.6, 2) AS DECIMAL(4,2)) PERSISTED,
HanDongHP AS DATEADD(DAY, 14, NgayDK) PERSISTED,
Tuoi      AS (DATEDIFF(YEAR, NgaySinh, GETDATE()) - CASE WHEN ... THEN 1 ELSE 0 END)   -- không PERSISTED được
```

`PERSISTED` lưu giá trị vào trang dữ liệu và cập nhật khi cột nguồn đổi, nên có thể đánh chỉ mục; `Tuoi` dùng `GETDATE()` (không tất định) nên chỉ tính khi đọc.

### 2.7.3 Chỉ mục

SQL Server tự tạo chỉ mục clustered cho khoá chính và chỉ mục cho UNIQUE, nhưng **không** tự tạo cho khoá ngoại. Nhóm chọn chỉ mục theo hai nhóm:

| Nhóm | Chỉ mục | Phục vụ |
|---|---|---|
| Khoá ngoại hay JOIN | `IX_DANGKY_MaLop (MaLop) INCLUDE (MaHV, TrangThai, TrangThaiHP)` | Danh sách lớp, đếm sĩ số (trigger T13) – *covering index* tránh tra lại bảng |
| | `IX_CT_PHIEUTHU_MaDK (MaDK) INCLUDE (SoTien)` | Tính số tiền đã đóng của một đăng ký (công nợ) |
| | `IX_LOPHOC_MaGV`, `IX_LICHHOC_Phong` | Kiểm tra trùng lịch giáo viên / phòng |
| | `IX_DIEMDANH_Buoi (MaLop, STT)` | Điểm danh cả lớp theo buổi |
| Tìm kiếm, lọc, báo cáo | `IX_HOCVIEN_Ten (TenHV, HoHV)`, `IX_HOCVIEN_SDT` | Tra cứu học viên theo tên (người Việt hay tìm theo tên, không theo họ), theo SĐT khi tư vấn |
| | `IX_PHIEUTHU_NgayThu (NgayThu) INCLUDE (TongTien, MaHV)` | Doanh thu theo khoảng thời gian |
| | `IX_BUOIHOC_Ngay (NgayHoc, MaCa)` | Lịch theo ngày, đếm buổi dạy trong tháng để tính lương |
| | `IX_NHATKY_Bang_ThoiGian` | Xem nhật ký mới nhất theo bảng |

Hiệu quả của chỉ mục được đo ở mục 3.1 (T09).

### 2.7.4 Kiểm thử ràng buộc

```text
INSERT CAHOC VALUES (1, N'Sáng 1', '09:00', '08:00');
→ The INSERT statement conflicted with the CHECK constraint "CK_CAHOC_Gio".

INSERT CHINHANH (MaCN, ...) VALUES ('X1', ...);
→ The INSERT statement conflicted with the CHECK constraint "CK_CHINHANH_MaCN".

INSERT LICHHOC VALUES ('L1', 2, 1, 'CN01', 'P101');      -- lớp L1 không tồn tại ở chi nhánh CN01
→ The INSERT statement conflicted with the FOREIGN KEY constraint "FK_LICHHOC_LOPHOC".
```

Script đã chạy sạch hai lần liên tiếp trên CSDL trống (SQL Server 2022/2025): `✓ 01_schema.sql: đã tạo CSDL ECMS với 22 bảng.`

### 2.7.5 Sơ đồ CSDL

![Database Diagram](../docs/design/db-diagram.png)

*Hình 2.4 – Sơ đồ CSDL sinh từ metadata (`sys.tables`, `sys.columns`, `sys.foreign_keys`) sau khi chạy `01_schema.sql`, tương đương Database Diagram của SSMS: **PK** khoá chính, **FK** khoá ngoại, ✱ NOT NULL, chữ nghiêng là cột tính toán. Đối chiếu với lược đồ ở mục 2.4: đủ 22 bảng, 32 khoá ngoại khớp các mối kết hợp của ERD.*
