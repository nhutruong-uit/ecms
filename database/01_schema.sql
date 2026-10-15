/* =====================================================================
   ECMS – Hệ thống Quản lý Trung tâm Tiếng Anh
   01_schema.sql : tạo CSDL, bảng, khoá, ràng buộc, chỉ mục        (T07)
   Chạy lại được từ đầu: xoá CSDL ECMS cũ (nếu có) rồi tạo lại.
   ===================================================================== */
USE master;
GO
IF DB_ID(N'ECMS') IS NOT NULL
BEGIN
    ALTER DATABASE ECMS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  -- ngắt mọi kết nối đang mở
    DROP DATABASE ECMS;
END
GO
CREATE DATABASE ECMS COLLATE Vietnamese_CI_AS;   -- so sánh không phân biệt hoa thường, sắp xếp đúng tiếng Việt
GO
USE ECMS;
GO

/* ---------------------------------------------------------------------
   1. DANH MỤC: chi nhánh, nhân viên, giáo viên, phòng, ca
   --------------------------------------------------------------------- */

-- Chi nhánh. MaNVQuanLy (1–1 với NHANVIEN) được thêm khoá ngoại sau khi có bảng NHANVIEN
CREATE TABLE CHINHANH (
    MaCN          CHAR(4)        NOT NULL,
    TenCN         NVARCHAR(100)  NOT NULL,
    DiaChi        NVARCHAR(200)  NOT NULL,
    SoDienThoai   VARCHAR(15)    NOT NULL,
    NgayThanhLap  DATE           NOT NULL,
    MaNVQuanLy    CHAR(6)        NULL,
    CONSTRAINT PK_CHINHANH PRIMARY KEY (MaCN),
    CONSTRAINT UQ_CHINHANH_TenCN UNIQUE (TenCN),
    CONSTRAINT CK_CHINHANH_MaCN CHECK (MaCN LIKE 'CN[0-9][0-9]'),
    CONSTRAINT CK_CHINHANH_SDT CHECK (SoDienThoai NOT LIKE '%[^0-9]%')
);

-- Nhân viên (quản lý, giáo vụ, kế toán, giáo viên). Họ tên là thuộc tính phức hợp (HoNV + TenNV)
CREATE TABLE NHANVIEN (
    MaNV          CHAR(6)        NOT NULL,
    HoNV          NVARCHAR(50)   NOT NULL,
    TenNV         NVARCHAR(20)   NOT NULL,
    NgaySinh      DATE           NOT NULL,
    GioiTinh      NVARCHAR(3)    NOT NULL,
    SoDienThoai   VARCHAR(15)    NOT NULL,
    Email         VARCHAR(100)   NOT NULL,
    ChucVu        NVARCHAR(20)   NOT NULL,
    LuongCoBan    DECIMAL(12,0)  NOT NULL CONSTRAINT DF_NHANVIEN_Luong DEFAULT 0,
    NgayVaoLam    DATE           NOT NULL CONSTRAINT DF_NHANVIEN_NgayVaoLam DEFAULT CAST(GETDATE() AS DATE),
    MaCN          CHAR(4)        NOT NULL,
    MaNVQuanLy    CHAR(6)        NULL,                      -- quan hệ đệ quy: người quản lý trực tiếp
    TrangThai     BIT            NOT NULL CONSTRAINT DF_NHANVIEN_TrangThai DEFAULT 1,  -- 1: đang làm, 0: đã nghỉ
    HoTen AS (HoNV + N' ' + TenNV),                         -- thuộc tính suy diễn từ thuộc tính phức hợp
    CONSTRAINT PK_NHANVIEN PRIMARY KEY (MaNV),
    CONSTRAINT UQ_NHANVIEN_SDT UNIQUE (SoDienThoai),
    CONSTRAINT UQ_NHANVIEN_Email UNIQUE (Email),
    CONSTRAINT FK_NHANVIEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHINHANH (MaCN),
    CONSTRAINT FK_NHANVIEN_QuanLy FOREIGN KEY (MaNVQuanLy) REFERENCES NHANVIEN (MaNV),
    CONSTRAINT CK_NHANVIEN_MaNV CHECK (MaNV LIKE 'NV[0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_NHANVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ')),
    CONSTRAINT CK_NHANVIEN_ChucVu CHECK (ChucVu IN (N'Quản lý', N'Giáo vụ', N'Kế toán', N'Giáo viên')),
    CONSTRAINT CK_NHANVIEN_Luong CHECK (LuongCoBan >= 0),
    CONSTRAINT CK_NHANVIEN_Email CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_NHANVIEN_QuanLy CHECK (MaNVQuanLy IS NULL OR MaNVQuanLy <> MaNV),
    CONSTRAINT CK_NHANVIEN_Tuoi CHECK (DATEDIFF(YEAR, NgaySinh, NgayVaoLam) >= 18)   -- liên thuộc tính
);

ALTER TABLE CHINHANH ADD CONSTRAINT FK_CHINHANH_QuanLy
    FOREIGN KEY (MaNVQuanLy) REFERENCES NHANVIEN (MaNV);
-- Mỗi nhân viên quản lý tối đa 1 chi nhánh (1–1): UNIQUE chỉ áp dụng cho giá trị khác NULL
CREATE UNIQUE INDEX UX_CHINHANH_QuanLy ON CHINHANH (MaNVQuanLy) WHERE MaNVQuanLy IS NOT NULL;

-- Giáo viên: chuyên biệt hoá của NHANVIEN (khoá chính đồng thời là khoá ngoại)
CREATE TABLE GIAOVIEN (
    MaGV          CHAR(6)        NOT NULL,
    LoaiGV        NVARCHAR(20)   NOT NULL,
    QuocTich      NVARCHAR(50)   NOT NULL CONSTRAINT DF_GIAOVIEN_QuocTich DEFAULT N'Việt Nam',
    TrinhDo       NVARCHAR(30)   NOT NULL,
    DonGiaBuoi    DECIMAL(10,0)  NOT NULL,                  -- tiền dạy mỗi buổi, dùng tính lương (T14)
    CONSTRAINT PK_GIAOVIEN PRIMARY KEY (MaGV),
    CONSTRAINT FK_GIAOVIEN_NHANVIEN FOREIGN KEY (MaGV) REFERENCES NHANVIEN (MaNV) ON DELETE CASCADE,
    CONSTRAINT CK_GIAOVIEN_Loai CHECK (LoaiGV IN (N'Việt Nam', N'Bản ngữ')),
    CONSTRAINT CK_GIAOVIEN_TrinhDo CHECK (TrinhDo IN (N'Cử nhân', N'Thạc sĩ', N'Tiến sĩ')),
    CONSTRAINT CK_GIAOVIEN_DonGia CHECK (DonGiaBuoi BETWEEN 100000 AND 5000000)
);

-- Chứng chỉ giáo viên: thuộc tính đa trị của GIAOVIEN tách thành bảng riêng
CREATE TABLE CHUNGCHI_GV (
    MaGV          CHAR(6)        NOT NULL,
    TenChungChi   NVARCHAR(50)   NOT NULL,
    Diem          DECIMAL(5,1)   NULL,                      -- VD IELTS 8.0, TOEIC 950; TESOL/CELTA không có điểm
    NgayCap       DATE           NOT NULL,
    NoiCap        NVARCHAR(100)  NULL,
    CONSTRAINT PK_CHUNGCHI_GV PRIMARY KEY (MaGV, TenChungChi),
    CONSTRAINT FK_CHUNGCHI_GV_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES GIAOVIEN (MaGV) ON DELETE CASCADE,
    CONSTRAINT CK_CHUNGCHI_GV_Diem CHECK (Diem IS NULL OR Diem >= 0)
);

-- Phòng học: thực thể yếu, định danh bởi chi nhánh + số phòng
CREATE TABLE PHONGHOC (
    MaCN          CHAR(4)        NOT NULL,
    MaPhong       VARCHAR(5)     NOT NULL,
    SucChua       TINYINT        NOT NULL,
    LoaiPhong     NVARCHAR(20)   NOT NULL CONSTRAINT DF_PHONGHOC_Loai DEFAULT N'Thường',
    CONSTRAINT PK_PHONGHOC PRIMARY KEY (MaCN, MaPhong),
    CONSTRAINT FK_PHONGHOC_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHINHANH (MaCN) ON DELETE CASCADE,
    CONSTRAINT CK_PHONGHOC_SucChua CHECK (SucChua BETWEEN 5 AND 60),
    CONSTRAINT CK_PHONGHOC_Loai CHECK (LoaiPhong IN (N'Thường', N'Lab', N'Hội trường'))
);

-- Ca học trong ngày
CREATE TABLE CAHOC (
    MaCa          TINYINT        NOT NULL,
    TenCa         NVARCHAR(30)   NOT NULL,
    GioBatDau     TIME(0)        NOT NULL,
    GioKetThuc    TIME(0)        NOT NULL,
    CONSTRAINT PK_CAHOC PRIMARY KEY (MaCa),
    CONSTRAINT UQ_CAHOC_TenCa UNIQUE (TenCa),
    CONSTRAINT CK_CAHOC_Gio CHECK (GioKetThuc > GioBatDau)                 -- liên thuộc tính
);

/* ---------------------------------------------------------------------
   2. ĐÀO TẠO: chương trình, khoá học, lớp, lịch, buổi học
   --------------------------------------------------------------------- */

CREATE TABLE CHUONGTRINH (
    MaCT          VARCHAR(5)     NOT NULL,
    TenCT         NVARCHAR(100)  NOT NULL,
    DoiTuong      NVARCHAR(100)  NOT NULL,
    MoTa          NVARCHAR(500)  NULL,
    CONSTRAINT PK_CHUONGTRINH PRIMARY KEY (MaCT),
    CONSTRAINT UQ_CHUONGTRINH_TenCT UNIQUE (TenCT)
);

-- Khoá học; MaKHTienQuyet: quan hệ đệ quy (khoá phải học trước)
CREATE TABLE KHOAHOC (
    MaKH          VARCHAR(6)     NOT NULL,
    TenKH         NVARCHAR(100)  NOT NULL,
    MaCT          VARCHAR(5)     NOT NULL,
    CapDo         TINYINT        NOT NULL,                  -- thứ tự trong chương trình (1, 2, 3...)
    DiemDauVaoTu  DECIMAL(3,1)   NOT NULL,                  -- khoảng điểm test đầu vào phù hợp (thang 10)
    DiemDauVaoDen DECIMAL(3,1)   NOT NULL,
    MucTieuDauRa  NVARCHAR(50)   NOT NULL,                  -- VD: IELTS 5.5, TOEIC 650
    SoBuoi        TINYINT        NOT NULL,
    HocPhi        DECIMAL(12,0)  NOT NULL,
    MaKHTienQuyet VARCHAR(6)     NULL,
    CONSTRAINT PK_KHOAHOC PRIMARY KEY (MaKH),
    CONSTRAINT UQ_KHOAHOC_TenKH UNIQUE (TenKH),
    CONSTRAINT UQ_KHOAHOC_CapDo UNIQUE (MaCT, CapDo),
    CONSTRAINT FK_KHOAHOC_CHUONGTRINH FOREIGN KEY (MaCT) REFERENCES CHUONGTRINH (MaCT),
    CONSTRAINT FK_KHOAHOC_TienQuyet FOREIGN KEY (MaKHTienQuyet) REFERENCES KHOAHOC (MaKH),
    CONSTRAINT CK_KHOAHOC_TienQuyet CHECK (MaKHTienQuyet IS NULL OR MaKHTienQuyet <> MaKH),
    CONSTRAINT CK_KHOAHOC_Diem CHECK (DiemDauVaoTu >= 0 AND DiemDauVaoDen <= 10 AND DiemDauVaoTu <= DiemDauVaoDen),
    CONSTRAINT CK_KHOAHOC_SoBuoi CHECK (SoBuoi BETWEEN 8 AND 60),
    CONSTRAINT CK_KHOAHOC_HocPhi CHECK (HocPhi > 0)
);

-- Lớp học: một lần mở của khoá học tại một chi nhánh, do một giáo viên phụ trách
CREATE TABLE LOPHOC (
    MaLop         VARCHAR(10)    NOT NULL,
    TenLop        NVARCHAR(100)  NOT NULL,
    MaKH          VARCHAR(6)     NOT NULL,
    MaCN          CHAR(4)        NOT NULL,
    MaGV          CHAR(6)        NOT NULL,
    NgayKhaiGiang DATE           NOT NULL,
    NgayKetThuc   DATE           NULL,                      -- cập nhật khi sinh buổi học (T14)
    SiSoToiDa     TINYINT        NOT NULL CONSTRAINT DF_LOPHOC_SiSoToiDa DEFAULT 20,
    SiSoHienTai   TINYINT        NOT NULL CONSTRAINT DF_LOPHOC_SiSoHienTai DEFAULT 0,  -- suy diễn, duy trì bằng trigger (T13)
    TrangThai     NVARCHAR(20)   NOT NULL CONSTRAINT DF_LOPHOC_TrangThai DEFAULT N'Sắp mở',
    CONSTRAINT PK_LOPHOC PRIMARY KEY (MaLop),
    CONSTRAINT UQ_LOPHOC_Lop_CN UNIQUE (MaLop, MaCN),       -- để LICHHOC tham chiếu (MaLop, MaCN)
    CONSTRAINT FK_LOPHOC_KHOAHOC FOREIGN KEY (MaKH) REFERENCES KHOAHOC (MaKH),
    CONSTRAINT FK_LOPHOC_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHINHANH (MaCN),
    CONSTRAINT FK_LOPHOC_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES GIAOVIEN (MaGV),
    CONSTRAINT CK_LOPHOC_Ngay CHECK (NgayKetThuc IS NULL OR NgayKetThuc > NgayKhaiGiang),
    CONSTRAINT CK_LOPHOC_SiSoToiDa CHECK (SiSoToiDa BETWEEN 5 AND 40),
    CONSTRAINT CK_LOPHOC_SiSo CHECK (SiSoHienTai <= SiSoToiDa),
    CONSTRAINT CK_LOPHOC_TrangThai CHECK (TrangThai IN (N'Sắp mở', N'Đang học', N'Đã kết thúc', N'Huỷ'))
);

-- Lịch học cố định: liên kết 3 ngôi LOPHOC – PHONGHOC – CAHOC theo thứ trong tuần
-- Khoá ngoại (MaLop, MaCN) bảo đảm phòng thuộc đúng chi nhánh của lớp (RBTV liên quan hệ)
CREATE TABLE LICHHOC (
    MaLop         VARCHAR(10)    NOT NULL,
    Thu           TINYINT        NOT NULL,                  -- 2 = thứ Hai ... 7 = thứ Bảy, 8 = Chủ nhật
    MaCa          TINYINT        NOT NULL,
    MaCN          CHAR(4)        NOT NULL,
    MaPhong       VARCHAR(5)     NOT NULL,
    CONSTRAINT PK_LICHHOC PRIMARY KEY (MaLop, Thu, MaCa),
    CONSTRAINT FK_LICHHOC_LOPHOC FOREIGN KEY (MaLop, MaCN) REFERENCES LOPHOC (MaLop, MaCN) ON DELETE CASCADE,
    CONSTRAINT FK_LICHHOC_PHONGHOC FOREIGN KEY (MaCN, MaPhong) REFERENCES PHONGHOC (MaCN, MaPhong),
    CONSTRAINT FK_LICHHOC_CAHOC FOREIGN KEY (MaCa) REFERENCES CAHOC (MaCa),
    CONSTRAINT CK_LICHHOC_Thu CHECK (Thu BETWEEN 2 AND 8)
);

-- Buổi học cụ thể: thực thể yếu theo lớp (MaLop + số thứ tự buổi)
CREATE TABLE BUOIHOC (
    MaLop         VARCHAR(10)    NOT NULL,
    STT           TINYINT        NOT NULL,
    NgayHoc       DATE           NOT NULL,
    MaCa          TINYINT        NOT NULL,
    MaPhong       VARCHAR(5)     NULL,
    NoiDung       NVARCHAR(200)  NULL,
    TrangThai     NVARCHAR(20)   NOT NULL CONSTRAINT DF_BUOIHOC_TrangThai DEFAULT N'Đã lên lịch',
    CONSTRAINT PK_BUOIHOC PRIMARY KEY (MaLop, STT),
    CONSTRAINT FK_BUOIHOC_LOPHOC FOREIGN KEY (MaLop) REFERENCES LOPHOC (MaLop) ON DELETE CASCADE,
    CONSTRAINT FK_BUOIHOC_CAHOC FOREIGN KEY (MaCa) REFERENCES CAHOC (MaCa),
    CONSTRAINT UQ_BUOIHOC_Ngay UNIQUE (MaLop, NgayHoc, MaCa),
    CONSTRAINT CK_BUOIHOC_STT CHECK (STT >= 1),
    CONSTRAINT CK_BUOIHOC_TrangThai CHECK (TrangThai IN (N'Đã lên lịch', N'Đã dạy', N'Nghỉ'))
);

-- Ngày nghỉ lễ: bảng phụ trợ cho sp_SinhBuoiHoc (T14)
CREATE TABLE NGAYLE (
    Ngay          DATE           NOT NULL,
    TenNgayLe     NVARCHAR(100)  NOT NULL,
    CONSTRAINT PK_NGAYLE PRIMARY KEY (Ngay)
);

/* ---------------------------------------------------------------------
   3. HỌC VIÊN: hồ sơ, kiểm tra đầu vào, đăng ký, điểm danh
   --------------------------------------------------------------------- */

-- Học viên. Họ tên và Địa chỉ là thuộc tính phức hợp; Tuổi là thuộc tính suy diễn (computed column)
CREATE TABLE HOCVIEN (
    MaHV          CHAR(6)        NOT NULL,
    HoHV          NVARCHAR(50)   NOT NULL,
    TenHV         NVARCHAR(20)   NOT NULL,
    NgaySinh      DATE           NOT NULL,
    GioiTinh      NVARCHAR(3)    NOT NULL,
    SoDienThoai   VARCHAR(15)    NOT NULL,
    Email         VARCHAR(100)   NULL,
    SoNha         NVARCHAR(100)  NULL,                      -- Địa chỉ = Số nhà + Phường/Xã + Quận/Huyện + Tỉnh/TP
    PhuongXa      NVARCHAR(50)   NULL,
    QuanHuyen     NVARCHAR(50)   NULL,
    TinhTP        NVARCHAR(50)   NOT NULL CONSTRAINT DF_HOCVIEN_TinhTP DEFAULT N'TP. Hồ Chí Minh',
    HoTenPhuHuynh NVARCHAR(70)   NULL,                      -- bắt buộc với học viên dưới 16 tuổi (kiểm tra ở sp)
    NgayTao       DATE           NOT NULL CONSTRAINT DF_HOCVIEN_NgayTao DEFAULT CAST(GETDATE() AS DATE),
    MaCN          CHAR(4)        NOT NULL,                  -- chi nhánh tiếp nhận hồ sơ
    TrangThai     BIT            NOT NULL CONSTRAINT DF_HOCVIEN_TrangThai DEFAULT 1,
    HoTen AS (HoHV + N' ' + TenHV),
    Tuoi  AS (DATEDIFF(YEAR, NgaySinh, GETDATE())
              - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, NgaySinh, GETDATE()), NgaySinh) > GETDATE() THEN 1 ELSE 0 END),
    CONSTRAINT PK_HOCVIEN PRIMARY KEY (MaHV),
    CONSTRAINT FK_HOCVIEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHINHANH (MaCN),
    CONSTRAINT CK_HOCVIEN_MaHV CHECK (MaHV LIKE 'HV[0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_HOCVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ')),
    CONSTRAINT CK_HOCVIEN_SDT CHECK (LEN(SoDienThoai) BETWEEN 9 AND 11 AND SoDienThoai NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_HOCVIEN_Email CHECK (Email IS NULL OR Email LIKE '%_@_%._%'),
    CONSTRAINT CK_HOCVIEN_NgaySinh CHECK (NgaySinh BETWEEN '1950-01-01' AND DATEADD(YEAR, -4, NgayTao))
);
CREATE UNIQUE INDEX UX_HOCVIEN_Email ON HOCVIEN (Email) WHERE Email IS NOT NULL;

-- Kiểm tra đầu vào. KetQuaChiTiet là XML (4 kỹ năng, nhận xét); XML Schema gắn vào ở 09_xml.sql (T10)
CREATE TABLE KIEMTRA_DAUVAO (
    MaKT          INT IDENTITY(1,1) NOT NULL,
    MaHV          CHAR(6)        NOT NULL,
    NgayKT        DATE           NOT NULL CONSTRAINT DF_KIEMTRA_NgayKT DEFAULT CAST(GETDATE() AS DATE),
    DiemTong      DECIMAL(3,1)   NOT NULL,                  -- trung bình 4 kỹ năng, thang 10
    KetQuaChiTiet XML            NOT NULL,
    MaKHDeXuat    VARCHAR(6)     NULL,
    MaNVCham      CHAR(6)        NULL,
    CONSTRAINT PK_KIEMTRA_DAUVAO PRIMARY KEY (MaKT),
    CONSTRAINT FK_KIEMTRA_HOCVIEN FOREIGN KEY (MaHV) REFERENCES HOCVIEN (MaHV) ON DELETE CASCADE,
    CONSTRAINT FK_KIEMTRA_KHOAHOC FOREIGN KEY (MaKHDeXuat) REFERENCES KHOAHOC (MaKH),
    CONSTRAINT FK_KIEMTRA_NHANVIEN FOREIGN KEY (MaNVCham) REFERENCES NHANVIEN (MaNV),
    CONSTRAINT CK_KIEMTRA_Diem CHECK (DiemTong BETWEEN 0 AND 10)
);

-- Đăng ký (ghi danh): liên kết N–M HOCVIEN – LOPHOC có thuộc tính.
-- HocPhi được chép từ KHOAHOC lúc ghi danh để giữ đúng giá tại thời điểm đó.
CREATE TABLE DANGKY (
    MaDK          INT IDENTITY(1,1) NOT NULL,
    MaHV          CHAR(6)        NOT NULL,
    MaLop         VARCHAR(10)    NOT NULL,
    NgayDK        DATE           NOT NULL CONSTRAINT DF_DANGKY_NgayDK DEFAULT CAST(GETDATE() AS DATE),
    HocPhi        DECIMAL(12,0)  NOT NULL,
    GiamGia       DECIMAL(5,2)   NOT NULL CONSTRAINT DF_DANGKY_GiamGia DEFAULT 0,      -- phần trăm
    ThanhTien AS CAST(ROUND(HocPhi * (100 - GiamGia) / 100, -3) AS DECIMAL(12,0)) PERSISTED,
    HanDongHP AS DATEADD(DAY, 14, NgayDK) PERSISTED,        -- quá hạn mà chưa đóng đủ → nợ quá hạn
    TrangThaiHP   NVARCHAR(20)   NOT NULL CONSTRAINT DF_DANGKY_TrangThaiHP DEFAULT N'Chưa đóng',  -- trigger T13
    DiemGK        DECIMAL(4,2)   NULL,
    DiemCK        DECIMAL(4,2)   NULL,
    DiemTB AS CAST(ROUND(DiemGK * 0.4 + DiemCK * 0.6, 2) AS DECIMAL(4,2)) PERSISTED,
    KetQua        NVARCHAR(10)   NULL,                      -- Đạt / Không đạt, trigger T13
    TrangThai     NVARCHAR(20)   NOT NULL CONSTRAINT DF_DANGKY_TrangThai DEFAULT N'Đang học',
    CONSTRAINT PK_DANGKY PRIMARY KEY (MaDK),
    CONSTRAINT UQ_DANGKY_HV_Lop UNIQUE (MaHV, MaLop),
    CONSTRAINT UQ_DANGKY_DK_Lop UNIQUE (MaDK, MaLop),       -- để DIEMDANH tham chiếu (MaDK, MaLop)
    CONSTRAINT FK_DANGKY_HOCVIEN FOREIGN KEY (MaHV) REFERENCES HOCVIEN (MaHV),
    CONSTRAINT FK_DANGKY_LOPHOC FOREIGN KEY (MaLop) REFERENCES LOPHOC (MaLop),
    CONSTRAINT CK_DANGKY_HocPhi CHECK (HocPhi > 0),
    CONSTRAINT CK_DANGKY_GiamGia CHECK (GiamGia BETWEEN 0 AND 50),
    CONSTRAINT CK_DANGKY_DiemGK CHECK (DiemGK BETWEEN 0 AND 10),
    CONSTRAINT CK_DANGKY_DiemCK CHECK (DiemCK BETWEEN 0 AND 10),
    CONSTRAINT CK_DANGKY_TrangThaiHP CHECK (TrangThaiHP IN (N'Chưa đóng', N'Đóng một phần', N'Đã đóng')),
    CONSTRAINT CK_DANGKY_KetQua CHECK (KetQua IN (N'Đạt', N'Không đạt')),
    CONSTRAINT CK_DANGKY_TrangThai CHECK (TrangThai IN (N'Đang học', N'Hoàn thành', N'Bảo lưu', N'Đã chuyển lớp', N'Huỷ'))
);

-- Điểm danh: N–M giữa DANGKY và BUOIHOC. Khoá ngoại (MaDK, MaLop) bảo đảm học viên thuộc đúng lớp của buổi học
CREATE TABLE DIEMDANH (
    MaDK          INT            NOT NULL,
    MaLop         VARCHAR(10)    NOT NULL,
    STT           TINYINT        NOT NULL,
    TrangThai     NVARCHAR(10)   NOT NULL CONSTRAINT DF_DIEMDANH_TrangThai DEFAULT N'Có mặt',
    GhiChu        NVARCHAR(200)  NULL,
    CONSTRAINT PK_DIEMDANH PRIMARY KEY (MaDK, MaLop, STT),
    CONSTRAINT FK_DIEMDANH_DANGKY FOREIGN KEY (MaDK, MaLop) REFERENCES DANGKY (MaDK, MaLop) ON DELETE CASCADE,
    CONSTRAINT FK_DIEMDANH_BUOIHOC FOREIGN KEY (MaLop, STT) REFERENCES BUOIHOC (MaLop, STT),
    CONSTRAINT CK_DIEMDANH_TrangThai CHECK (TrangThai IN (N'Có mặt', N'Vắng', N'Muộn', N'Có phép'))
);

-- Cảnh báo chuyên cần: kết quả của sp_CanhBaoChuyenCan (T14)
CREATE TABLE CANHBAO_CHUYENCAN (
    MaCB          INT IDENTITY(1,1) NOT NULL,
    MaDK          INT            NOT NULL,
    NgayCanhBao   DATE           NOT NULL CONSTRAINT DF_CANHBAO_Ngay DEFAULT CAST(GETDATE() AS DATE),
    SoBuoiDaHoc   TINYINT        NOT NULL,
    SoBuoiVang    TINYINT        NOT NULL,
    TyLeVang      DECIMAL(5,2)   NOT NULL,
    MucDo         NVARCHAR(20)   NOT NULL,
    DaXuLy        BIT            NOT NULL CONSTRAINT DF_CANHBAO_DaXuLy DEFAULT 0,
    CONSTRAINT PK_CANHBAO_CHUYENCAN PRIMARY KEY (MaCB),
    CONSTRAINT UQ_CANHBAO_DK_Ngay UNIQUE (MaDK, NgayCanhBao),
    CONSTRAINT FK_CANHBAO_DANGKY FOREIGN KEY (MaDK) REFERENCES DANGKY (MaDK) ON DELETE CASCADE,
    CONSTRAINT CK_CANHBAO_MucDo CHECK (MucDo IN (N'Nhắc nhở', N'Nghiêm trọng'))
);

/* ---------------------------------------------------------------------
   4. TÀI CHÍNH: phiếu thu (master – detail), bảng lương
   --------------------------------------------------------------------- */

CREATE TABLE PHIEUTHU (
    MaPT          INT IDENTITY(1,1) NOT NULL,
    SoPhieu AS ('PT' + RIGHT('000000' + CAST(MaPT AS VARCHAR(10)), 6)) PERSISTED,
    MaHV          CHAR(6)        NOT NULL,
    MaNV          CHAR(6)        NOT NULL,                  -- kế toán lập phiếu
    NgayThu       DATETIME2(0)   NOT NULL CONSTRAINT DF_PHIEUTHU_NgayThu DEFAULT SYSDATETIME(),
    HinhThuc      NVARCHAR(20)   NOT NULL CONSTRAINT DF_PHIEUTHU_HinhThuc DEFAULT N'Tiền mặt',
    TongTien      DECIMAL(12,0)  NOT NULL CONSTRAINT DF_PHIEUTHU_TongTien DEFAULT 0,  -- suy diễn = SUM(CT_PHIEUTHU.SoTien), trigger T13
    GhiChu        NVARCHAR(200)  NULL,
    CONSTRAINT PK_PHIEUTHU PRIMARY KEY (MaPT),
    CONSTRAINT UQ_PHIEUTHU_SoPhieu UNIQUE (SoPhieu),
    CONSTRAINT FK_PHIEUTHU_HOCVIEN FOREIGN KEY (MaHV) REFERENCES HOCVIEN (MaHV),
    CONSTRAINT FK_PHIEUTHU_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHANVIEN (MaNV),
    CONSTRAINT CK_PHIEUTHU_HinhThuc CHECK (HinhThuc IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ')),
    CONSTRAINT CK_PHIEUTHU_TongTien CHECK (TongTien >= 0)
);

CREATE TABLE CT_PHIEUTHU (
    MaPT          INT            NOT NULL,
    MaDK          INT            NOT NULL,
    SoTien        DECIMAL(12,0)  NOT NULL,
    CONSTRAINT PK_CT_PHIEUTHU PRIMARY KEY (MaPT, MaDK),
    CONSTRAINT FK_CT_PHIEUTHU_PHIEUTHU FOREIGN KEY (MaPT) REFERENCES PHIEUTHU (MaPT) ON DELETE CASCADE,
    CONSTRAINT FK_CT_PHIEUTHU_DANGKY FOREIGN KEY (MaDK) REFERENCES DANGKY (MaDK),
    CONSTRAINT CK_CT_PHIEUTHU_SoTien CHECK (SoTien > 0)
);

-- Bảng lương giáo viên theo tháng: kết quả của sp_TinhLuongGiaoVien (T14)
CREATE TABLE BANGLUONG (
    Thang         CHAR(7)        NOT NULL,                  -- 'yyyy-MM'
    MaGV          CHAR(6)        NOT NULL,
    SoBuoiDay     SMALLINT       NOT NULL,
    DonGiaBuoi    DECIMAL(10,0)  NOT NULL,
    LuongCoBan    DECIMAL(12,0)  NOT NULL,
    TongLuong AS (LuongCoBan + SoBuoiDay * DonGiaBuoi) PERSISTED,
    NgayTinh      DATETIME2(0)   NOT NULL CONSTRAINT DF_BANGLUONG_NgayTinh DEFAULT SYSDATETIME(),
    CONSTRAINT PK_BANGLUONG PRIMARY KEY (Thang, MaGV),
    CONSTRAINT FK_BANGLUONG_GIAOVIEN FOREIGN KEY (MaGV) REFERENCES GIAOVIEN (MaGV) ON DELETE CASCADE,
    CONSTRAINT CK_BANGLUONG_Thang CHECK (Thang LIKE '[2][0-9][0-9][0-9]-[01][0-9]')
);

/* ---------------------------------------------------------------------
   5. HỆ THỐNG: tài khoản ứng dụng, nhật ký kiểm toán
   --------------------------------------------------------------------- */

-- Tài khoản đăng nhập ứng dụng web. Mật khẩu lưu dạng băm SHA2_256 + salt (T15)
CREATE TABLE TAIKHOAN (
    TenDangNhap   VARCHAR(30)    NOT NULL,
    MatKhauHash   VARBINARY(32)  NOT NULL,
    Salt          VARBINARY(16)  NOT NULL,
    VaiTro        VARCHAR(10)    NOT NULL,
    MaNV          CHAR(6)        NULL,
    MaHV          CHAR(6)        NULL,
    TrangThai     BIT            NOT NULL CONSTRAINT DF_TAIKHOAN_TrangThai DEFAULT 1,   -- 0: bị khoá
    SoLanSai      TINYINT        NOT NULL CONSTRAINT DF_TAIKHOAN_SoLanSai DEFAULT 0,
    LanDangNhapCuoi DATETIME2(0) NULL,
    NgayTao       DATETIME2(0)   NOT NULL CONSTRAINT DF_TAIKHOAN_NgayTao DEFAULT SYSDATETIME(),
    CONSTRAINT PK_TAIKHOAN PRIMARY KEY (TenDangNhap),
    CONSTRAINT FK_TAIKHOAN_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHANVIEN (MaNV) ON DELETE CASCADE,
    CONSTRAINT FK_TAIKHOAN_HOCVIEN FOREIGN KEY (MaHV) REFERENCES HOCVIEN (MaHV) ON DELETE CASCADE,
    CONSTRAINT CK_TAIKHOAN_VaiTro CHECK (VaiTro IN ('QuanLy', 'GiaoVu', 'KeToan', 'GiaoVien', 'HocVien')),
    -- tài khoản học viên gắn với HOCVIEN, các vai trò khác gắn với NHANVIEN (đúng một trong hai)
    CONSTRAINT CK_TAIKHOAN_ChuSoHuu CHECK (
        (VaiTro = 'HocVien' AND MaHV IS NOT NULL AND MaNV IS NULL) OR
        (VaiTro <> 'HocVien' AND MaNV IS NOT NULL AND MaHV IS NULL))
);
CREATE UNIQUE INDEX UX_TAIKHOAN_MaNV ON TAIKHOAN (MaNV) WHERE MaNV IS NOT NULL;   -- 1–1
CREATE UNIQUE INDEX UX_TAIKHOAN_MaHV ON TAIKHOAN (MaHV) WHERE MaHV IS NOT NULL;   -- 1–1

-- Nhật ký kiểm toán, ghi bởi trigger (T13). Dữ liệu cũ / mới lưu dạng JSON
CREATE TABLE NHATKY (
    MaNK          BIGINT IDENTITY(1,1) NOT NULL,
    TenBang       SYSNAME        NOT NULL,
    ThaoTac       VARCHAR(6)     NOT NULL,
    KhoaChinh     NVARCHAR(100)  NULL,
    DuLieuCu      NVARCHAR(MAX)  NULL,
    DuLieuMoi     NVARCHAR(MAX)  NULL,
    NguoiThucHien NVARCHAR(128)  NOT NULL CONSTRAINT DF_NHATKY_Nguoi DEFAULT SUSER_SNAME(),  -- login SQL Server
    NguoiDungUD   NVARCHAR(30)   NULL,                      -- tài khoản ứng dụng (SESSION_CONTEXT 'app_user')
    ThoiGian      DATETIME2(3)   NOT NULL CONSTRAINT DF_NHATKY_ThoiGian DEFAULT SYSDATETIME(),
    CONSTRAINT PK_NHATKY PRIMARY KEY (MaNK),
    CONSTRAINT CK_NHATKY_ThaoTac CHECK (ThaoTac IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT CK_NHATKY_DuLieuCu CHECK (DuLieuCu IS NULL OR ISJSON(DuLieuCu) = 1),
    CONSTRAINT CK_NHATKY_DuLieuMoi CHECK (DuLieuMoi IS NULL OR ISJSON(DuLieuMoi) = 1)
);
GO

/* ---------------------------------------------------------------------
   6. CHỈ MỤC NONCLUSTERED
   SQL Server tự tạo chỉ mục cho PRIMARY KEY (clustered) và UNIQUE, nhưng KHÔNG tự tạo cho khoá ngoại.
   Chọn chỉ mục cho: (a) khoá ngoại dùng trong JOIN thường xuyên, (b) cột tìm kiếm / lọc / sắp xếp.
   --------------------------------------------------------------------- */

-- (a) Khoá ngoại hay JOIN
CREATE INDEX IX_NHANVIEN_MaCN        ON NHANVIEN (MaCN) INCLUDE (ChucVu, TrangThai);
CREATE INDEX IX_NHANVIEN_QuanLy      ON NHANVIEN (MaNVQuanLy);
CREATE INDEX IX_KHOAHOC_MaCT         ON KHOAHOC (MaCT);
CREATE INDEX IX_LOPHOC_MaKH          ON LOPHOC (MaKH);
CREATE INDEX IX_LOPHOC_MaGV          ON LOPHOC (MaGV) INCLUDE (NgayKhaiGiang, NgayKetThuc, TrangThai);
CREATE INDEX IX_LICHHOC_Phong        ON LICHHOC (MaCN, MaPhong, Thu, MaCa);   -- kiểm tra trùng phòng (T11, T13)
CREATE INDEX IX_KIEMTRA_MaHV         ON KIEMTRA_DAUVAO (MaHV, NgayKT DESC);
CREATE INDEX IX_DANGKY_MaLop         ON DANGKY (MaLop) INCLUDE (MaHV, TrangThai, TrangThaiHP);
CREATE INDEX IX_DIEMDANH_Buoi        ON DIEMDANH (MaLop, STT) INCLUDE (TrangThai);
CREATE INDEX IX_PHIEUTHU_MaHV        ON PHIEUTHU (MaHV);
CREATE INDEX IX_CT_PHIEUTHU_MaDK     ON CT_PHIEUTHU (MaDK) INCLUDE (SoTien);   -- tính số tiền đã đóng của 1 đăng ký

-- (b) Cột tìm kiếm / lọc / báo cáo
CREATE INDEX IX_HOCVIEN_Ten          ON HOCVIEN (TenHV, HoHV);                 -- tìm theo tên (sp_TimKiemHocVien)
CREATE INDEX IX_HOCVIEN_SDT          ON HOCVIEN (SoDienThoai);                 -- tra cứu nhanh khi tư vấn
CREATE INDEX IX_HOCVIEN_MaCN         ON HOCVIEN (MaCN, NgayTao);
CREATE INDEX IX_LOPHOC_CN_TrangThai  ON LOPHOC (MaCN, TrangThai, NgayKhaiGiang);
CREATE INDEX IX_BUOIHOC_Ngay         ON BUOIHOC (NgayHoc, MaCa);              -- lịch theo ngày, tính lương theo tháng
CREATE INDEX IX_PHIEUTHU_NgayThu     ON PHIEUTHU (NgayThu) INCLUDE (TongTien, MaHV);  -- doanh thu theo kỳ
CREATE INDEX IX_NHATKY_Bang_ThoiGian ON NHATKY (TenBang, ThoiGian DESC);
GO

DECLARE @SoBang INT = (SELECT COUNT(*) FROM sys.tables);
PRINT N'✓ 01_schema.sql: đã tạo CSDL ECMS với ' + CAST(@SoBang AS NVARCHAR(10)) + N' bảng.';
GO
