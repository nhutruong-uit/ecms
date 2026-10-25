/* =====================================================================
   ECMS – 13_distributed.sql : CSDL phân tán theo chi nhánh (demo, không nằm trong run_all)   (T26)
   Mô phỏng 3 trạm (site) bằng 3 CSDL trên cùng instance + 1 CSDL lược đồ toàn cục:
     ECMS_CN01, ECMS_CN02, ECMS_CN03 : mảnh dữ liệu của từng chi nhánh
     ECMS_TOANCUC                     : partitioned view UNION ALL – người dùng truy vấn như một CSDL (trong suốt vị trí)
   Dữ liệu gốc lấy từ CSDL tập trung ECMS để đối chiếu kết quả.
   Phân mảnh:
     - NGANG chính     : HOCVIEN, LOPHOC theo MaCN
     - NGANG dẫn xuất  : DANGKY, DIEMDANH theo LOPHOC.MaCN (đăng ký nằm cùng trạm với lớp)
     - DỌC             : NHANVIEN → NHANVIEN_CHUNG (thông tin công khai, ở mọi trạm của chi nhánh)
                                   + NHANVIEN_LUONG (lương – chỉ lưu ở trạm trung tâm ECMS_TOANCUC)
     - HỖN HỢP         : NHANVIEN_CHUNG còn được phân mảnh ngang theo MaCN
     - NHÂN BẢN        : CHUONGTRINH, KHOAHOC, CAHOC (danh mục ít thay đổi, đọc nhiều)
   Kiến trúc 3 lược đồ: lược đồ TOÀN CỤC = view ở ECMS_TOANCUC; lược đồ PHÂN MẢNH = định nghĩa σ / π ở mục 1;
   lược đồ CẤP PHÁT (định vị) = mảnh nào nằm ở CSDL nào (bảng ở mục 1–2).
   Mục 6–9 (bổ sung): đồng bộ bản sao, ghi qua partitioned view, nửa kết (semi-join), giao tác liên trạm (2PC)
   và trạm gặp sự cố.
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;
GO
DECLARE @db SYSNAME, @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('ECMS_TOANCUC'), ('ECMS_CN01'), ('ECMS_CN02'), ('ECMS_CN03')) t(v);
OPEN c; FETCH NEXT FROM c INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@db) IS NOT NULL
    BEGIN
        SET @sql = N'ALTER DATABASE ' + QUOTENAME(@db) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@db) + N';';
        EXEC sp_executesql @sql;
    END
    SET @sql = N'CREATE DATABASE ' + QUOTENAME(@db) + N' COLLATE Vietnamese_CI_AS;';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM c INTO @db;
END
CLOSE c; DEALLOCATE c;
GO

/* ---------------------------------------------------------------------
   1. TẠO MẢNH Ở TỪNG TRẠM (cùng cấu trúc, khác CHECK MaCN)
   CHECK trên cột phân mảnh cho phép optimizer bỏ qua (prune) trạm không liên quan khi truy vấn view toàn cục.
   --------------------------------------------------------------------- */
DECLARE @cn CHAR(4), @db SYSNAME, @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('CN01'), ('CN02'), ('CN03')) t(v);
OPEN c; FETCH NEXT FROM c INTO @cn;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @db = N'ECMS_' + @cn;
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';
    -- Nhân bản danh mục
    SELECT * INTO dbo.CHUONGTRINH FROM ECMS.dbo.CHUONGTRINH;
    SELECT * INTO dbo.KHOAHOC     FROM ECMS.dbo.KHOAHOC;
    SELECT * INTO dbo.CAHOC       FROM ECMS.dbo.CAHOC;
    ALTER TABLE dbo.CHUONGTRINH ADD PRIMARY KEY (MaCT);
    ALTER TABLE dbo.KHOAHOC ADD PRIMARY KEY (MaKH);
    ALTER TABLE dbo.CAHOC ADD PRIMARY KEY (MaCa);

    -- Phân mảnh ngang chính: σ MaCN = ''' + @cn + N''' (HOCVIEN), σ MaCN = ''' + @cn + N''' (LOPHOC)
    CREATE TABLE dbo.HOCVIEN (
        MaHV CHAR(6) NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''' + @cn + N'''),
        HoHV NVARCHAR(50) NOT NULL, TenHV NVARCHAR(20) NOT NULL, NgaySinh DATE NOT NULL, GioiTinh NVARCHAR(3) NOT NULL,
        SoDienThoai VARCHAR(15) NOT NULL, Email VARCHAR(100) NULL, NgayTao DATE NOT NULL,
        PRIMARY KEY (MaHV, MaCN));
    INSERT dbo.HOCVIEN SELECT MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, NgayTao
                       FROM ECMS.dbo.HOCVIEN WHERE MaCN = ''' + @cn + N''';

    CREATE TABLE dbo.LOPHOC (
        MaLop VARCHAR(10) NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''' + @cn + N'''),
        TenLop NVARCHAR(100) NOT NULL, MaKH VARCHAR(6) NOT NULL REFERENCES dbo.KHOAHOC (MaKH), MaGV CHAR(6) NOT NULL,
        NgayKhaiGiang DATE NOT NULL, NgayKetThuc DATE NULL, SiSoToiDa TINYINT NOT NULL, SiSoHienTai TINYINT NOT NULL,
        TrangThai NVARCHAR(20) NOT NULL, PRIMARY KEY (MaLop, MaCN));
    INSERT dbo.LOPHOC SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai
                      FROM ECMS.dbo.LOPHOC WHERE MaCN = ''' + @cn + N''';

    -- Phân mảnh ngang dẫn xuất: DANGKY ⋉ LOPHOC_' + @cn + N' (theo chi nhánh của LỚP, không phải của học viên)
    CREATE TABLE dbo.DANGKY (
        MaDK INT NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''' + @cn + N'''),
        MaHV CHAR(6) NOT NULL, MaLop VARCHAR(10) NOT NULL, NgayDK DATE NOT NULL, HocPhi DECIMAL(12,0) NOT NULL,
        GiamGia DECIMAL(5,2) NOT NULL, ThanhTien DECIMAL(12,0) NOT NULL, TrangThaiHP NVARCHAR(20) NOT NULL,
        DiemGK DECIMAL(4,2) NULL, DiemCK DECIMAL(4,2) NULL, KetQua NVARCHAR(10) NULL, TrangThai NVARCHAR(20) NOT NULL,
        PRIMARY KEY (MaDK, MaCN), FOREIGN KEY (MaLop, MaCN) REFERENCES dbo.LOPHOC (MaLop, MaCN));
    INSERT dbo.DANGKY SELECT d.MaDK, l.MaCN, d.MaHV, d.MaLop, d.NgayDK, d.HocPhi, d.GiamGia, d.ThanhTien, d.TrangThaiHP,
                             d.DiemGK, d.DiemCK, d.KetQua, d.TrangThai
                      FROM ECMS.dbo.DANGKY d JOIN ECMS.dbo.LOPHOC l ON l.MaLop = d.MaLop WHERE l.MaCN = ''' + @cn + N''';

    CREATE TABLE dbo.DIEMDANH (
        MaDK INT NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''' + @cn + N'''), STT TINYINT NOT NULL,
        TrangThai NVARCHAR(10) NOT NULL, GhiChu NVARCHAR(200) NULL,
        PRIMARY KEY (MaDK, STT, MaCN), FOREIGN KEY (MaDK, MaCN) REFERENCES dbo.DANGKY (MaDK, MaCN));
    INSERT dbo.DIEMDANH SELECT dd.MaDK, ''' + @cn + N''', dd.STT, dd.TrangThai, dd.GhiChu
                        FROM ECMS.dbo.DIEMDANH dd JOIN ECMS.dbo.LOPHOC l ON l.MaLop = dd.MaLop WHERE l.MaCN = ''' + @cn + N''';

    -- Phân mảnh hỗn hợp: π(MaNV, HoTen, ChucVu, MaCN, …) rồi σ MaCN (NHANVIEN) – KHÔNG có lương
    CREATE TABLE dbo.NHANVIEN_CHUNG (
        MaNV CHAR(6) NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''' + @cn + N'''),
        HoNV NVARCHAR(50) NOT NULL, TenNV NVARCHAR(20) NOT NULL, ChucVu NVARCHAR(20) NOT NULL,
        SoDienThoai VARCHAR(15) NOT NULL, Email VARCHAR(100) NOT NULL, PRIMARY KEY (MaNV, MaCN));
    INSERT dbo.NHANVIEN_CHUNG SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, SoDienThoai, Email FROM ECMS.dbo.NHANVIEN WHERE MaCN = ''' + @cn + N''';';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM c INTO @cn;
END
CLOSE c; DEALLOCATE c;
GO

/* ---------------------------------------------------------------------
   2. TRẠM TRUNG TÂM: mảnh dọc nhạy cảm + LƯỢC ĐỒ TOÀN CỤC (partitioned view)
   --------------------------------------------------------------------- */
USE ECMS_TOANCUC;
GO
-- Mảnh dọc: π(MaNV, LuongCoBan) NHANVIEN – lương chỉ lưu tập trung, chi nhánh không giữ
SELECT MaNV, LuongCoBan INTO dbo.NHANVIEN_LUONG FROM ECMS.dbo.NHANVIEN;
ALTER TABLE dbo.NHANVIEN_LUONG ADD PRIMARY KEY (MaNV);
GO
CREATE VIEW dbo.HOCVIEN AS
    SELECT * FROM ECMS_CN01.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN02.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN03.dbo.HOCVIEN;
GO
CREATE VIEW dbo.LOPHOC AS
    SELECT * FROM ECMS_CN01.dbo.LOPHOC UNION ALL
    SELECT * FROM ECMS_CN02.dbo.LOPHOC UNION ALL
    SELECT * FROM ECMS_CN03.dbo.LOPHOC;
GO
CREATE VIEW dbo.DANGKY AS
    SELECT * FROM ECMS_CN01.dbo.DANGKY UNION ALL
    SELECT * FROM ECMS_CN02.dbo.DANGKY UNION ALL
    SELECT * FROM ECMS_CN03.dbo.DANGKY;
GO
CREATE VIEW dbo.DIEMDANH AS
    SELECT * FROM ECMS_CN01.dbo.DIEMDANH UNION ALL
    SELECT * FROM ECMS_CN02.dbo.DIEMDANH UNION ALL
    SELECT * FROM ECMS_CN03.dbo.DIEMDANH;
GO
-- Tái thiết NHANVIEN = (∪ NHANVIEN_CHUNG_CNi) ⋈ NHANVIEN_LUONG
CREATE VIEW dbo.NHANVIEN AS
    SELECT c.MaNV, c.MaCN, c.HoNV, c.TenNV, c.ChucVu, c.SoDienThoai, c.Email, l.LuongCoBan
    FROM (SELECT * FROM ECMS_CN01.dbo.NHANVIEN_CHUNG UNION ALL
          SELECT * FROM ECMS_CN02.dbo.NHANVIEN_CHUNG UNION ALL
          SELECT * FROM ECMS_CN03.dbo.NHANVIEN_CHUNG) c
    JOIN dbo.NHANVIEN_LUONG l ON l.MaNV = c.MaNV;
GO
-- Danh mục nhân bản: đọc bản tại trạm CN01 (bản nào cũng như nhau)
CREATE VIEW dbo.KHOAHOC AS SELECT * FROM ECMS_CN01.dbo.KHOAHOC;
GO

/* ---------------------------------------------------------------------
   3. KIỂM TRA TÍNH ĐÚNG ĐẮN CỦA PHÂN MẢNH
   --------------------------------------------------------------------- */
SELECT N'Đầy đủ (completeness): mọi dòng gốc có trong một mảnh' AS KiemTra, Bang, SoDongGoc, SoDongCacManh,
       IIF(SoDongGoc = SoDongCacManh AND SoThieu = 0, N'✓', N'✗') AS KetQua
FROM (
    SELECT 'HOCVIEN' AS Bang, (SELECT COUNT(*) FROM ECMS.dbo.HOCVIEN) AS SoDongGoc, (SELECT COUNT(*) FROM dbo.HOCVIEN) AS SoDongCacManh,
           (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS.dbo.HOCVIEN EXCEPT SELECT MaHV FROM dbo.HOCVIEN) x) AS SoThieu
    UNION ALL
    SELECT 'LOPHOC', (SELECT COUNT(*) FROM ECMS.dbo.LOPHOC), (SELECT COUNT(*) FROM dbo.LOPHOC),
           (SELECT COUNT(*) FROM (SELECT MaLop FROM ECMS.dbo.LOPHOC EXCEPT SELECT MaLop FROM dbo.LOPHOC) x)
    UNION ALL
    SELECT 'DANGKY', (SELECT COUNT(*) FROM ECMS.dbo.DANGKY), (SELECT COUNT(*) FROM dbo.DANGKY),
           (SELECT COUNT(*) FROM (SELECT MaDK FROM ECMS.dbo.DANGKY EXCEPT SELECT MaDK FROM dbo.DANGKY) x)
    UNION ALL
    SELECT 'DIEMDANH', (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH), (SELECT COUNT(*) FROM dbo.DIEMDANH),
           (SELECT COUNT(*) FROM (SELECT MaDK, STT FROM ECMS.dbo.DIEMDANH EXCEPT SELECT MaDK, STT FROM dbo.DIEMDANH) x)
    UNION ALL
    SELECT 'NHANVIEN', (SELECT COUNT(*) FROM ECMS.dbo.NHANVIEN), (SELECT COUNT(*) FROM dbo.NHANVIEN),
           (SELECT COUNT(*) FROM (SELECT MaNV FROM ECMS.dbo.NHANVIEN EXCEPT SELECT MaNV FROM dbo.NHANVIEN) x)
) t;

-- Rời nhau: mỗi khoá chỉ thuộc MỘT mảnh ngang – đếm khoá xuất hiện ở từ 2 trạm trở lên, cho mọi bảng phân mảnh ngang
SELECT N'Rời nhau (disjointness): khoá xuất hiện ở ≥ 2 trạm' AS KiemTra, Bang, SoKhoaTrung, IIF(SoKhoaTrung = 0, N'✓', N'✗') AS KetQua
FROM (
    SELECT 'HOCVIEN' AS Bang, COUNT(*) AS SoKhoaTrung FROM (SELECT MaHV FROM dbo.HOCVIEN GROUP BY MaHV HAVING COUNT(*) > 1) x
    UNION ALL SELECT 'LOPHOC', COUNT(*) FROM (SELECT MaLop FROM dbo.LOPHOC GROUP BY MaLop HAVING COUNT(*) > 1) x
    UNION ALL SELECT 'DANGKY', COUNT(*) FROM (SELECT MaDK FROM dbo.DANGKY GROUP BY MaDK HAVING COUNT(*) > 1) x
    UNION ALL SELECT 'DIEMDANH', COUNT(*) FROM (SELECT MaDK, STT FROM dbo.DIEMDANH GROUP BY MaDK, STT HAVING COUNT(*) > 1) x
    UNION ALL SELECT 'NHANVIEN_CHUNG', COUNT(*) FROM (SELECT MaNV FROM dbo.NHANVIEN GROUP BY MaNV HAVING COUNT(*) > 1) x
) t;

-- Tái thiết: ghép các mảnh (UNION ALL cho mảnh ngang, JOIN theo khoá cho mảnh dọc) phải ra ĐÚNG bảng gốc –
-- so sánh từng cột bằng EXCEPT hai chiều (thiếu dòng, thừa dòng hay sai giá trị đều bị phát hiện)
SELECT N'Tái thiết (reconstruction): ghép mảnh = bảng gốc' AS KiemTra, Bang, SoDongKhac, IIF(SoDongKhac = 0, N'✓', N'✗') AS KetQua
FROM (
    SELECT 'HOCVIEN' AS Bang,
           (SELECT COUNT(*) FROM (SELECT MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, CAST(NgayTao AS DATE) AS NgayTao FROM ECMS.dbo.HOCVIEN
                                  EXCEPT SELECT MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, NgayTao FROM dbo.HOCVIEN) a)
         + (SELECT COUNT(*) FROM (SELECT MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, NgayTao FROM dbo.HOCVIEN
                                  EXCEPT SELECT MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, CAST(NgayTao AS DATE) FROM ECMS.dbo.HOCVIEN) b) AS SoDongKhac
    UNION ALL SELECT 'LOPHOC',
           (SELECT COUNT(*) FROM (SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai FROM ECMS.dbo.LOPHOC
                                  EXCEPT SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai FROM dbo.LOPHOC) a)
         + (SELECT COUNT(*) FROM (SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai FROM dbo.LOPHOC
                                  EXCEPT SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai FROM ECMS.dbo.LOPHOC) b)
    UNION ALL SELECT 'DANGKY',
           (SELECT COUNT(*) FROM (SELECT MaDK, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai FROM ECMS.dbo.DANGKY
                                  EXCEPT SELECT MaDK, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai FROM dbo.DANGKY) a)
         + (SELECT COUNT(*) FROM (SELECT MaDK, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai FROM dbo.DANGKY
                                  EXCEPT SELECT MaDK, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai FROM ECMS.dbo.DANGKY) b)
    UNION ALL SELECT 'DIEMDANH',
           (SELECT COUNT(*) FROM (SELECT MaDK, STT, TrangThai, GhiChu FROM ECMS.dbo.DIEMDANH EXCEPT SELECT MaDK, STT, TrangThai, GhiChu FROM dbo.DIEMDANH) a)
         + (SELECT COUNT(*) FROM (SELECT MaDK, STT, TrangThai, GhiChu FROM dbo.DIEMDANH EXCEPT SELECT MaDK, STT, TrangThai, GhiChu FROM ECMS.dbo.DIEMDANH) b)
    UNION ALL SELECT N'NHANVIEN (dọc + ngang)',
           (SELECT COUNT(*) FROM (SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, SoDienThoai, Email, LuongCoBan FROM ECMS.dbo.NHANVIEN
                                  EXCEPT SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, SoDienThoai, Email, LuongCoBan FROM dbo.NHANVIEN) a)
         + (SELECT COUNT(*) FROM (SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, SoDienThoai, Email, LuongCoBan FROM dbo.NHANVIEN
                                  EXCEPT SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, SoDienThoai, Email, LuongCoBan FROM ECMS.dbo.NHANVIEN) b)
) t;

-- Số dòng mỗi trạm
SELECT 'CN01' AS Tram, (SELECT COUNT(*) FROM ECMS_CN01.dbo.HOCVIEN) AS HocVien, (SELECT COUNT(*) FROM ECMS_CN01.dbo.LOPHOC) AS LopHoc,
       (SELECT COUNT(*) FROM ECMS_CN01.dbo.DANGKY) AS DangKy, (SELECT COUNT(*) FROM ECMS_CN01.dbo.DIEMDANH) AS DiemDanh
UNION ALL SELECT 'CN02', (SELECT COUNT(*) FROM ECMS_CN02.dbo.HOCVIEN), (SELECT COUNT(*) FROM ECMS_CN02.dbo.LOPHOC),
       (SELECT COUNT(*) FROM ECMS_CN02.dbo.DANGKY), (SELECT COUNT(*) FROM ECMS_CN02.dbo.DIEMDANH)
UNION ALL SELECT 'CN03', (SELECT COUNT(*) FROM ECMS_CN03.dbo.HOCVIEN), (SELECT COUNT(*) FROM ECMS_CN03.dbo.LOPHOC),
       (SELECT COUNT(*) FROM ECMS_CN03.dbo.DANGKY), (SELECT COUNT(*) FROM ECMS_CN03.dbo.DIEMDANH);
GO

/* ---------------------------------------------------------------------
   4. TRUY VẤN TOÀN CỤC – viết như CSDL tập trung, kết quả phải giống ECMS
   --------------------------------------------------------------------- */
-- G1. Sĩ số và tỷ lệ đạt theo khoá học trên toàn hệ thống
DROP TABLE IF EXISTS #PhanTan, #TapTrung;
SELECT k.TenKH, COUNT(*) AS SoDK, SUM(CASE WHEN d.KetQua = N'Đạt' THEN 1 ELSE 0 END) AS SoDat, SUM(d.ThanhTien) AS PhaiThu
INTO #PhanTan
FROM dbo.DANGKY d JOIN dbo.LOPHOC l ON l.MaLop = d.MaLop AND l.MaCN = d.MaCN JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
GROUP BY k.TenKH;
SELECT k.TenKH, COUNT(*) AS SoDK, SUM(CASE WHEN d.KetQua = N'Đạt' THEN 1 ELSE 0 END) AS SoDat, SUM(d.ThanhTien) AS PhaiThu
INTO #TapTrung
FROM ECMS.dbo.DANGKY d JOIN ECMS.dbo.LOPHOC l ON l.MaLop = d.MaLop JOIN ECMS.dbo.KHOAHOC k ON k.MaKH = l.MaKH
GROUP BY k.TenKH;
SELECT N'G1 – sĩ số, tỷ lệ đạt theo khoá' AS TruyVan, (SELECT COUNT(*) FROM #PhanTan) AS SoDong,
       (SELECT COUNT(*) FROM (SELECT * FROM #PhanTan EXCEPT SELECT * FROM #TapTrung) a)
     + (SELECT COUNT(*) FROM (SELECT * FROM #TapTrung EXCEPT SELECT * FROM #PhanTan) b) AS SoDongKhacTapTrung;
SELECT TOP 5 * FROM #PhanTan ORDER BY PhaiThu DESC;

-- G2. Học viên học ở chi nhánh khác chi nhánh lập hồ sơ (cần dữ liệu từ 2 trạm: HOCVIEN ở trạm A, DANGKY ở trạm B)
SELECT N'G2 – học viên học khác chi nhánh' AS TruyVan,
       (SELECT COUNT(DISTINCT d.MaHV) FROM dbo.DANGKY d JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV WHERE h.MaCN <> d.MaCN) AS PhanTan,
       (SELECT COUNT(DISTINCT d.MaHV) FROM ECMS.dbo.DANGKY d JOIN ECMS.dbo.HOCVIEN h ON h.MaHV = d.MaHV
        JOIN ECMS.dbo.LOPHOC l ON l.MaLop = d.MaLop WHERE h.MaCN <> l.MaCN) AS TapTrung;

-- G3. Tổng quỹ lương theo chi nhánh – chỉ trạm trung tâm trả lời được (mảnh lương không có ở chi nhánh)
SELECT MaCN, COUNT(*) AS SoNV, SUM(LuongCoBan) AS QuyLuongCoBan FROM dbo.NHANVIEN GROUP BY MaCN ORDER BY MaCN;
GO

/* ---------------------------------------------------------------------
   5. TRONG SUỐT VỊ TRÍ + LOẠI BỎ MẢNH (partition elimination)
   Nhờ CHECK (MaCN = 'CNxx'), điều kiện MaCN = 'CN02' chỉ đọc ECMS_CN02: các bảng CN01, CN03 có Scan count 0.
   --------------------------------------------------------------------- */
SET STATISTICS IO ON;
SELECT COUNT(*) AS HocVienCN02 FROM dbo.HOCVIEN WHERE MaCN = 'CN02';
SET STATISTICS IO OFF;
GO

/* ---------------------------------------------------------------------
   6. NHÂN BẢN: ĐỒNG BỘ BẢN SAO DANH MỤC
   Bản sao danh mục ở các trạm được tạo bằng SELECT INTO (ảnh chụp – snapshot). Khi trung tâm đổi học phí,
   bản sao CŨ cho tới lần đồng bộ kế tiếp – đánh đổi của nhân bản: đọc nhanh, cục bộ nhưng có độ trễ nhất quán.
   sp_DongBoDanhMuc mô phỏng snapshot replication: MERGE bảng gốc vào bản sao ở mọi trạm.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_DongBoDanhMuc
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @db SYSNAME, @sql NVARCHAR(MAX);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT v FROM (VALUES ('ECMS_CN01'), ('ECMS_CN02'), ('ECMS_CN03')) t(v);
    OPEN c; FETCH NEXT FROM c INTO @db;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'MERGE ' + QUOTENAME(@db) + N'.dbo.KHOAHOC AS t USING ECMS.dbo.KHOAHOC AS s ON t.MaKH = s.MaKH
            WHEN MATCHED AND (t.HocPhi <> s.HocPhi OR t.SoBuoi <> s.SoBuoi OR t.TenKH <> s.TenKH) THEN
                 UPDATE SET TenKH = s.TenKH, SoBuoi = s.SoBuoi, HocPhi = s.HocPhi
            WHEN NOT MATCHED THEN INSERT (MaKH, TenKH, MaCT, CapDo, DiemDauVaoTu, DiemDauVaoDen, MucTieuDauRa, SoBuoi, HocPhi, MaKHTienQuyet)
                 VALUES (s.MaKH, s.TenKH, s.MaCT, s.CapDo, s.DiemDauVaoTu, s.DiemDauVaoDen, s.MucTieuDauRa, s.SoBuoi, s.HocPhi, s.MaKHTienQuyet);';
        EXEC sp_executesql @sql;
        FETCH NEXT FROM c INTO @db;
    END
    CLOSE c; DEALLOCATE c;
END
GO
BEGIN TRANSACTION;                                  -- thử trên dữ liệu thật rồi ROLLBACK
UPDATE ECMS.dbo.KHOAHOC SET HocPhi = HocPhi + 500000 WHERE MaKH = 'IE55';
SELECT N'Trước đồng bộ' AS Luc, (SELECT HocPhi FROM ECMS.dbo.KHOAHOC WHERE MaKH = 'IE55') AS Goc,
       (SELECT HocPhi FROM ECMS_CN01.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN01,
       (SELECT HocPhi FROM ECMS_CN02.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN02,
       (SELECT HocPhi FROM ECMS_CN03.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN03;
EXEC dbo.sp_DongBoDanhMuc;
SELECT N'Sau đồng bộ' AS Luc, (SELECT HocPhi FROM ECMS.dbo.KHOAHOC WHERE MaKH = 'IE55') AS Goc,
       (SELECT HocPhi FROM ECMS_CN01.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN01,
       (SELECT HocPhi FROM ECMS_CN02.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN02,
       (SELECT HocPhi FROM ECMS_CN03.dbo.KHOAHOC WHERE MaKH = 'IE55') AS BanSaoCN03;
ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   7. TRONG SUỐT PHÂN MẢNH KHI GHI: INSERT qua partitioned view
   View UNION ALL cập nhật được vì cột phân mảnh MaCN nằm trong khoá chính và có CHECK ở từng mảnh:
   người dùng ghi vào "bảng" HOCVIEN toàn cục, SQL Server tự đưa dòng vào đúng trạm.
   --------------------------------------------------------------------- */
BEGIN TRANSACTION;
INSERT dbo.HOCVIEN (MaHV, MaCN, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, NgayTao)
VALUES ('HV9001', 'CN02', N'Trần', N'Phân Tán', '2005-05-05', N'Nữ', '0909000901', NULL, '2026-10-15');
SELECT N'INSERT qua view toàn cục' AS ThaoTac,
       (SELECT COUNT(*) FROM ECMS_CN01.dbo.HOCVIEN WHERE MaHV = 'HV9001') AS TaiCN01,
       (SELECT COUNT(*) FROM ECMS_CN02.dbo.HOCVIEN WHERE MaHV = 'HV9001') AS TaiCN02,
       (SELECT COUNT(*) FROM ECMS_CN03.dbo.HOCVIEN WHERE MaHV = 'HV9001') AS TaiCN03;
ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   8. TỐI ƯU TRUY VẤN PHÂN TÁN: NỬA KẾT (SEMI-JOIN) cho G2 tại trạm CN01
   Câu hỏi tại CN01: học viên học lớp của CN01 nhưng hồ sơ thuộc chi nhánh khác là ai?
   Cách 1 – chuyển nguyên mảnh: CN02, CN03 gửi toàn bộ HOCVIEN về CN01 rồi kết nối tại CN01.
   Cách 2 – nửa kết: CN01 gửi π MaHV(DANGKY_CN01) sang CN02, CN03; mỗi trạm chỉ trả về học viên khớp
            (DANGKY_CN01 ⋉ HOCVIEN_CNj). Dữ liệu qua mạng = danh sách khoá + các dòng thật sự cần.
   Ước lượng dữ liệu truyền bằng tổng DATALENGTH của các dòng / cột phải gửi.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS #KhoaCN01;
SELECT DISTINCT MaHV INTO #KhoaCN01 FROM ECMS_CN01.dbo.DANGKY;            -- π MaHV(DANGKY_CN01)
SELECT N'Chuyển nguyên mảnh' AS PhuongAn,
       (SELECT COUNT(*) FROM ECMS_CN02.dbo.HOCVIEN) + (SELECT COUNT(*) FROM ECMS_CN03.dbo.HOCVIEN) AS SoDongGui,
       (SELECT SUM(DATALENGTH(MaHV) + DATALENGTH(MaCN) + DATALENGTH(HoHV) + DATALENGTH(TenHV) + 3 + DATALENGTH(GioiTinh)
                   + DATALENGTH(SoDienThoai) + ISNULL(DATALENGTH(Email), 0) + 3)
        FROM (SELECT * FROM ECMS_CN02.dbo.HOCVIEN UNION ALL SELECT * FROM ECMS_CN03.dbo.HOCVIEN) h) AS SoByteGui
UNION ALL
SELECT N'Nửa kết (semi-join)',
       2 * (SELECT COUNT(*) FROM #KhoaCN01)                                       -- gửi danh sách khoá tới 2 trạm
     + (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS_CN02.dbo.HOCVIEN WHERE MaHV IN (SELECT MaHV FROM #KhoaCN01)
                              UNION ALL SELECT MaHV FROM ECMS_CN03.dbo.HOCVIEN WHERE MaHV IN (SELECT MaHV FROM #KhoaCN01)) k),
       2 * (SELECT SUM(DATALENGTH(MaHV)) FROM #KhoaCN01)
     + (SELECT ISNULL(SUM(DATALENGTH(MaHV) + DATALENGTH(MaCN) + DATALENGTH(HoHV) + DATALENGTH(TenHV)), 0)
        FROM (SELECT * FROM ECMS_CN02.dbo.HOCVIEN UNION ALL SELECT * FROM ECMS_CN03.dbo.HOCVIEN) h
        WHERE h.MaHV IN (SELECT MaHV FROM #KhoaCN01));
-- Kết quả hai cách phải như nhau
SELECT N'Học viên ngoài chi nhánh học tại CN01' AS KetQua,
       (SELECT COUNT(DISTINCT d.MaHV) FROM ECMS_CN01.dbo.DANGKY d JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV WHERE h.MaCN <> 'CN01') AS ChuyenNguyenManh,
       (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS_CN02.dbo.HOCVIEN WHERE MaHV IN (SELECT MaHV FROM #KhoaCN01)
                              UNION SELECT MaHV FROM ECMS_CN03.dbo.HOCVIEN WHERE MaHV IN (SELECT MaHV FROM #KhoaCN01)) k) AS NuaKet;
DROP TABLE #KhoaCN01;
GO

/* ---------------------------------------------------------------------
   9. GIAO TÁC LIÊN TRẠM (2PC) – chuyển lớp từ lớp CN02 sang lớp CN01: đóng đăng ký cũ ở trạm CN02 và
      tạo đăng ký mới ở trạm CN01 phải xảy ra CÙNG NHAU hoặc không xảy ra.
   Trên một instance, giao tác ghi vào nhiều CSDL được SQL Server tự điều phối bằng cam kết hai pha nội bộ:
   pha chuẩn bị ghi bản ghi LOP_PREP_XACT vào log của TỪNG CSDL tham gia, rồi mới ghi LOP_COMMIT_XACT.
   Đếm bản ghi này bằng fn_dblog (hàm không được tài liệu hoá, chỉ dùng để quan sát trong môi trường học tập).
   Khi các trạm là máy chủ khác nhau: dùng linked server + BEGIN DISTRIBUTED TRANSACTION, MSDTC làm điều phối
   (xem mục 10); loopback linked server về chính máy KHÔNG dùng được trong giao tác phân tán.
   --------------------------------------------------------------------- */
DECLARE @p1 INT, @p2 INT, @q1 INT, @q2 INT, @DK INT, @DKMoi INT = 990001, @LopMoi VARCHAR(10), @s NVARCHAR(400);
-- fn_dblog đọc log của CSDL HIỆN HÀNH → gọi qua <CSDL>.sys.sp_executesql để chạy trong ngữ cảnh từng trạm
DECLARE @dem NVARCHAR(200) = N'SELECT @n = COUNT(*) FROM sys.fn_dblog(NULL, NULL) WHERE Operation = ''LOP_PREP_XACT''';
-- đăng ký đang học ở lớp CN02 và một lớp cùng khoá ở CN01 (ưu tiên lớp còn mở)
SELECT TOP 1 @DK = d.MaDK, @LopMoi = l1.MaLop
FROM ECMS_CN02.dbo.DANGKY d JOIN ECMS_CN02.dbo.LOPHOC l2 ON l2.MaLop = d.MaLop AND l2.MaCN = d.MaCN
JOIN ECMS_CN01.dbo.LOPHOC l1 ON l1.MaKH = l2.MaKH
WHERE d.TrangThai = N'Đang học'
ORDER BY CASE WHEN l1.TrangThai IN (N'Sắp mở', N'Đang học') THEN 0 ELSE 1 END, d.MaDK, l1.MaLop;
EXEC ECMS_CN01.sys.sp_executesql @dem, N'@n INT OUTPUT', @p1 OUTPUT;
EXEC ECMS_CN02.sys.sp_executesql @dem, N'@n INT OUTPUT', @p2 OUTPUT;

-- (a) thành công: cả hai trạm cùng ghi
BEGIN TRANSACTION;
UPDATE ECMS_CN02.dbo.DANGKY SET TrangThai = N'Đã chuyển lớp' WHERE MaDK = @DK AND MaCN = 'CN02';
INSERT ECMS_CN01.dbo.DANGKY (MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, TrangThai)
SELECT @DKMoi, 'CN01', MaHV, @LopMoi, '2026-10-15', HocPhi, GiamGia, ThanhTien, TrangThaiHP, N'Đang học'
FROM ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK;
COMMIT TRANSACTION;
EXEC ECMS_CN01.sys.sp_executesql @dem, N'@n INT OUTPUT', @q1 OUTPUT;
EXEC ECMS_CN02.sys.sp_executesql @dem, N'@n INT OUTPUT', @q2 OUTPUT;
SELECT N'(a) Chuyển lớp CN02 → CN01 thành công' AS KichBan,
       (SELECT TrangThai FROM ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK) AS TramCN02,
       (SELECT TrangThai FROM ECMS_CN01.dbo.DANGKY WHERE MaDK = @DKMoi) AS TramCN01,
       @q1 - @p1 AS BanGhiPrepare_CN01, @q2 - @p2 AS BanGhiPrepare_CN02;

-- (b) lỗi ở trạm thứ hai (vi phạm CHECK MaCN của mảnh CN01) → trạm thứ nhất cũng được huỷ
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE ECMS_CN02.dbo.DANGKY SET TrangThai = N'Bảo lưu' WHERE MaDK = @DK AND MaCN = 'CN02';
    INSERT ECMS_CN01.dbo.DANGKY (MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, TrangThai)
    VALUES (990002, 'CN02', 'HV0001', @LopMoi, '2026-10-15', 1, 0, 1, N'Chưa đóng', N'Đang học');
    COMMIT TRANSACTION;
    SET @s = N'không báo lỗi';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @s = CONCAT(ERROR_NUMBER(), N' ', LEFT(ERROR_MESSAGE(), 120));
END CATCH;
SELECT N'(b) Lỗi ở trạm CN01 → huỷ cả hai trạm' AS KichBan, @s AS Loi,
       (SELECT TrangThai FROM ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK) AS TramCN02_VanLa,
       (SELECT COUNT(*) FROM ECMS_CN01.dbo.DANGKY WHERE MaDK = 990002) AS TramCN01_SoDongMoi;

-- hoàn tác kịch bản (a) để các mảnh lại khớp CSDL tập trung
BEGIN TRANSACTION;
DELETE ECMS_CN01.dbo.DANGKY WHERE MaDK = @DKMoi;
UPDATE ECMS_CN02.dbo.DANGKY SET TrangThai = N'Đang học' WHERE MaDK = @DK AND MaCN = 'CN02';
COMMIT TRANSACTION;
GO

/* ---------------------------------------------------------------------
   10. TRẠM GẶP SỰ CỐ: đưa trạm CN03 OFFLINE
   Không có bản sao của mảnh CN03 nên view toàn cục không trả lời được nữa (không trong suốt sự cố);
   trạm CN01, CN02 vẫn phục vụ truy vấn cục bộ (tính tự trị địa phương). Muốn chịu lỗi cần nhân bản mảnh
   (Always On Availability Group / log shipping) để chuyển truy vấn sang bản sao.
   --------------------------------------------------------------------- */
ALTER DATABASE ECMS_CN03 SET OFFLINE WITH ROLLBACK IMMEDIATE;
GO
-- Lỗi "CSDL offline" (942) phát sinh lúc BIÊN DỊCH câu lệnh nên phải chạy bằng sp_executesql thì TRY/CATCH mới bắt được
DECLARE @s1 NVARCHAR(300), @s2 NVARCHAR(300), @s3 NVARCHAR(300), @n INT;
BEGIN TRY EXEC sp_executesql N'SELECT @n = COUNT(*) FROM ECMS_TOANCUC.dbo.HOCVIEN', N'@n INT OUTPUT', @n OUTPUT;
          SET @s1 = CONCAT(N'Được: ', @n, N' học viên'); END TRY
BEGIN CATCH SET @s1 = CONCAT(N'Lỗi ', ERROR_NUMBER(), N': ', LEFT(ERROR_MESSAGE(), 110)); END CATCH;
BEGIN TRY EXEC sp_executesql N'SELECT @n = COUNT(*) FROM ECMS_TOANCUC.dbo.HOCVIEN WHERE MaCN = ''CN02''', N'@n INT OUTPUT', @n OUTPUT;
          SET @s2 = CONCAT(N'Được: ', @n, N' học viên'); END TRY
BEGIN CATCH SET @s2 = CONCAT(N'Lỗi ', ERROR_NUMBER(), N': ', LEFT(ERROR_MESSAGE(), 110)); END CATCH;
BEGIN TRY EXEC sp_executesql N'SELECT @n = COUNT(*) FROM ECMS_CN02.dbo.HOCVIEN', N'@n INT OUTPUT', @n OUTPUT;
          SET @s3 = CONCAT(N'Được: ', @n, N' học viên'); END TRY
BEGIN CATCH SET @s3 = CONCAT(N'Lỗi ', ERROR_NUMBER(), N': ', LEFT(ERROR_MESSAGE(), 110)); END CATCH;
SELECT N'View toàn cục (mọi trạm)' AS TruyVan, @s1 AS KetQua
UNION ALL SELECT N'View toàn cục, lọc MaCN = CN02', @s2
UNION ALL SELECT N'Truy vấn trực tiếp trạm CN02', @s3;
GO
ALTER DATABASE ECMS_CN03 SET ONLINE;
GO

/* ---------------------------------------------------------------------
   11. Các trạm là máy chủ khác nhau: linked server + BEGIN DISTRIBUTED TRANSACTION, MSDTC của hai máy điều phối 2PC
       qua mạng → database/13b_2pc_msdtc.sql (trạm CN02 là SQL Server trên máy thứ hai, cấu hình ở database/tram_cn02/).
       Đã chạy giữa Windows 11 (trạm CN01) và Docker trên macOS (trạm CN02) cùng mạng Wi-Fi.
   --------------------------------------------------------------------- */
PRINT N'✓ 13_distributed.sql: 3 trạm chi nhánh + lược đồ toàn cục ECMS_TOANCUC; nhân bản, semi-join, 2PC, sự cố trạm.';
GO
