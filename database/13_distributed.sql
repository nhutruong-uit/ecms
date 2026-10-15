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
        TrangThai NVARCHAR(10) NOT NULL, PRIMARY KEY (MaDK, STT, MaCN), FOREIGN KEY (MaDK, MaCN) REFERENCES dbo.DANGKY (MaDK, MaCN));
    INSERT dbo.DIEMDANH SELECT dd.MaDK, ''' + @cn + N''', dd.STT, dd.TrangThai
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

SELECT N'Rời nhau (disjointness): không dòng nào thuộc 2 mảnh' AS KiemTra,
       (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS_CN01.dbo.HOCVIEN INTERSECT SELECT MaHV FROM ECMS_CN02.dbo.HOCVIEN) x)
     + (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS_CN01.dbo.HOCVIEN INTERSECT SELECT MaHV FROM ECMS_CN03.dbo.HOCVIEN) x)
     + (SELECT COUNT(*) FROM (SELECT MaHV FROM ECMS_CN02.dbo.HOCVIEN INTERSECT SELECT MaHV FROM ECMS_CN03.dbo.HOCVIEN) x)
     + (SELECT COUNT(*) FROM (SELECT MaDK FROM ECMS_CN01.dbo.DANGKY INTERSECT SELECT MaDK FROM ECMS_CN02.dbo.DANGKY) x)
     + (SELECT COUNT(*) FROM (SELECT MaDK FROM ECMS_CN01.dbo.DANGKY INTERSECT SELECT MaDK FROM ECMS_CN03.dbo.DANGKY) x)
     + (SELECT COUNT(*) FROM (SELECT MaDK FROM ECMS_CN02.dbo.DANGKY INTERSECT SELECT MaDK FROM ECMS_CN03.dbo.DANGKY) x) AS SoDongTrung;

SELECT N'Tái thiết (reconstruction): NHANVIEN dọc ⋈ = bảng gốc' AS KiemTra,
       (SELECT COUNT(*) FROM (SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, LuongCoBan FROM ECMS.dbo.NHANVIEN
                              EXCEPT SELECT MaNV, MaCN, HoNV, TenNV, ChucVu, LuongCoBan FROM dbo.NHANVIEN) x) AS SoDongKhac;

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
   6. (Tuỳ chọn) Linked server: khi các trạm là máy chủ khác nhau, view toàn cục dùng tên 4 phần
      Server.Database.Schema.Table. Ví dụ tạo linked server trỏ về chính máy (loopback) để thử:
   --------------------------------------------------------------------- */
/*
EXEC sp_addlinkedserver @server = N'TRAM_CN02', @srvproduct = N'', @provider = N'MSOLEDBSQL', @datasrc = N'localhost';
EXEC sp_addlinkedsrvlogin @rmtsrvname = N'TRAM_CN02', @useself = N'FALSE', @rmtuser = N'sa', @rmtpassword = N'<mật khẩu>';
SELECT COUNT(*) FROM TRAM_CN02.ECMS_CN02.dbo.HOCVIEN;
-- Giao tác phân tán giữa các trạm (cần MSDTC, giao thức 2PC):
BEGIN DISTRIBUTED TRANSACTION;
    UPDATE TRAM_CN02.ECMS_CN02.dbo.DANGKY SET TrangThai = N'Đã chuyển lớp' WHERE MaDK = 100 AND MaCN = 'CN02';
    INSERT ECMS_CN01.dbo.DANGKY (...) VALUES (...);
COMMIT TRANSACTION;
*/
PRINT N'✓ 13_distributed.sql: 3 trạm chi nhánh + lược đồ toàn cục ECMS_TOANCUC.';
GO
