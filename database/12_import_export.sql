/* =====================================================================
   ECMS – 12_import_export.sql : nhập / xuất dữ liệu (demo, không nằm trong run_all)   (T18)
   1. BULK INSERT CSV → bảng staging → kiểm tra chất lượng → đưa vào HOCVIEN (ETL nhỏ)
   2. OPENROWSET(BULK …) đọc file XML / CSV như một bảng
   3. Xuất FOR JSON / FOR XML (ghi ra file bằng sqlcmd -o hoặc bcp, xem cuối file)
   Đường dẫn file là đường dẫn TRÊN MÁY CHỦ SQL Server:
     Docker (docker-compose.yml gắn ./data vào /data): '/data/import/'
     Windows: 'C:\ecms\data\import\' (sửa biến @Dir bên dưới)
   Mặc định chạy thử: nhập trong transaction rồi ROLLBACK. Đặt @GhiThat = 1 để ghi thật.
   ===================================================================== */
USE ECMS;
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   0. Bảng staging: mọi cột kiểu chuỗi để nhận cả dữ liệu sai, kiểm tra sau
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.STG_HOCVIEN_ONLINE;
-- Cột VARCHAR với collation UTF-8 (SQL Server 2019+): BULK INSERT đọc đúng file CSV UTF-8 trên cả Windows lẫn Linux
-- (CODEPAGE = '65001' chỉ có trên Windows). Khi chuyển sang HOCVIEN mới đổi sang NVARCHAR.
CREATE TABLE dbo.STG_HOCVIEN_ONLINE (
    HoHV VARCHAR(200) COLLATE Latin1_General_100_CI_AS_SC_UTF8, TenHV VARCHAR(200) COLLATE Latin1_General_100_CI_AS_SC_UTF8,
    NgaySinh VARCHAR(30), GioiTinh VARCHAR(20) COLLATE Latin1_General_100_CI_AS_SC_UTF8, SoDienThoai VARCHAR(30),
    Email VARCHAR(150), QuanHuyen VARCHAR(200) COLLATE Latin1_General_100_CI_AS_SC_UTF8, MaCN VARCHAR(10),
    MaKHQuanTam VARCHAR(10), NgayDangKy VARCHAR(30)
);
GO

/* ---------------------------------------------------------------------
   1. BULK INSERT + kiểm tra + nạp (ETL)
   --------------------------------------------------------------------- */
DECLARE @Dir NVARCHAR(260) = N'/data/import/';
DECLARE @GhiThat BIT = 0;
DECLARE @t0 DATETIME2 = SYSDATETIME(), @sql NVARCHAR(MAX), @ms INT;

-- 1.1 Extract: BULK INSERT không nhận biến làm tên file → SQL động
SET @sql = N'BULK INSERT dbo.STG_HOCVIEN_ONLINE FROM ''' + REPLACE(@Dir + N'hocvien_online.csv', '''', '''''') + N'''
    WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', TABLOCK,
          MAXERRORS = 50);';      -- dòng hỏng cấu trúc CSV bị bỏ qua (tối đa 50) thay vì dừng cả lô
EXEC sp_executesql @sql;
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT N'BULK INSERT hocvien_online.csv' AS Buoc, COUNT(*) AS SoDong, @ms AS ThoiGianMs FROM dbo.STG_HOCVIEN_ONLINE;

-- 1.2 Transform: chuẩn hoá và kiểm tra từng dòng
DROP TABLE IF EXISTS #KT;
SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Dong, s.*,
       s.HoHV AS s_Ho, s.TenHV AS s_Ten,
       CAST(LTRIM(RTRIM(s.HoHV)) AS NVARCHAR(50)) COLLATE DATABASE_DEFAULT AS Ho,
       CAST(LTRIM(RTRIM(s.TenHV)) AS NVARCHAR(20)) COLLATE DATABASE_DEFAULT AS Ten,
       CAST(s.GioiTinh AS NVARCHAR(3)) COLLATE DATABASE_DEFAULT AS GT,
       CAST(s.QuanHuyen AS NVARCHAR(50)) COLLATE DATABASE_DEFAULT AS Quan,
       TRY_CONVERT(DATE, s.NgaySinh, 103) AS NS,             -- dd/MM/yyyy
       -- file CSV từ Windows / Excel xuống dòng bằng CRLF: cột cuối dính CHAR(13) làm TRY_CONVERT trả NULL
       -- (trước đây NULL bị thay bằng ngày hôm nay một cách lặng lẽ) → bỏ CR trước khi đổi kiểu
       TRY_CONVERT(DATE, REPLACE(s.NgayDangKy, CHAR(13), ''), 103) AS NDK,
       REPLACE(REPLACE(REPLACE(s.SoDienThoai, ' ', ''), '.', ''), '-', '') AS SDT,
       LOWER(LTRIM(RTRIM(s.Email))) AS Mail
INTO #KT
FROM dbo.STG_HOCVIEN_ONLINE s;

ALTER TABLE #KT ADD Loi NVARCHAR(400);
UPDATE #KT SET Loi = CONCAT_WS(N'; ',
    IIF(ISNULL(Ten, N'') = N'' OR ISNULL(Ho, N'') = N'', N'Thiếu họ tên', NULL),
    -- CAST ở trên cắt chuỗi theo độ dài cột HOCVIEN: báo lỗi thay vì lặng lẽ cắt họ tên
    IIF(LEN(LTRIM(RTRIM(s_Ho))) > 50 OR LEN(LTRIM(RTRIM(s_Ten))) > 20, N'Họ tên quá dài', NULL),
    IIF(NULLIF(LTRIM(REPLACE(NgayDangKy, CHAR(13), '')), '') IS NOT NULL AND NDK IS NULL, N'Ngày đăng ký sai định dạng', NULL),
    IIF(NS IS NULL, N'Ngày sinh sai định dạng', NULL),
    IIF(NS IS NOT NULL AND NS > DATEADD(YEAR, -4, CAST(GETDATE() AS DATE)), N'Ngày sinh không hợp lệ', NULL),
    IIF(ISNULL(GT, N'') NOT IN (N'Nam', N'Nữ'), N'Giới tính sai', NULL),
    IIF(SDT IS NULL OR LEN(SDT) NOT BETWEEN 9 AND 11 OR SDT LIKE '%[^0-9]%', N'Số điện thoại sai', NULL),
    IIF(Mail IS NOT NULL AND Mail <> '' AND Mail NOT LIKE '%_@_%._%', N'Email sai', NULL),
    IIF(NOT EXISTS (SELECT 1 FROM dbo.CHINHANH c WHERE c.MaCN = #KT.MaCN), N'Chi nhánh không tồn tại', NULL),
    IIF(MaKHQuanTam IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.KHOAHOC k WHERE k.MaKH = #KT.MaKHQuanTam), N'Khoá học không tồn tại', NULL),
    IIF(EXISTS (SELECT 1 FROM dbo.HOCVIEN h WHERE h.SoDienThoai = #KT.SDT), N'Trùng SĐT học viên đã có', NULL));
-- Trùng trong chính file: giữ dòng đầu tiên
WITH Trung AS (SELECT Dong, ROW_NUMBER() OVER (PARTITION BY SDT ORDER BY Dong) AS rn FROM #KT WHERE Loi = N'')
UPDATE k SET Loi = N'Trùng SĐT trong file' FROM #KT k JOIN Trung t ON t.Dong = k.Dong WHERE t.rn > 1;
UPDATE #KT SET Loi = NULL WHERE Loi = N'';

SELECT N'Hợp lệ' AS KetQua, COUNT(*) AS SoDong FROM #KT WHERE Loi IS NULL
UNION ALL SELECT N'Lỗi', COUNT(*) FROM #KT WHERE Loi IS NOT NULL;
SELECT Loi, COUNT(*) AS SoDong FROM #KT WHERE Loi IS NOT NULL GROUP BY Loi ORDER BY SoDong DESC;
SELECT TOP 8 Dong, HoHV, TenHV, NgaySinh, SoDienThoai, Email, MaCN, MaKHQuanTam, Loi FROM #KT WHERE Loi IS NOT NULL ORDER BY Dong;

-- 1.3 Load: đưa dòng hợp lệ vào HOCVIEN với mã mới, trong một transaction
BEGIN TRANSACTION;
DECLARE @Max INT = (SELECT ISNULL(MAX(CAST(SUBSTRING(MaHV, 3, 4) AS INT)), 0) FROM dbo.HOCVIEN);
INSERT dbo.HOCVIEN (MaHV, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, QuanHuyen, NgayTao, MaCN)
SELECT 'HV' + RIGHT('0000' + CAST(@Max + ROW_NUMBER() OVER (ORDER BY Dong) AS VARCHAR(4)), 4),
       Ho, Ten, NS, GT, SDT, NULLIF(Mail, ''), Quan, ISNULL(NDK, CAST(GETDATE() AS DATE)), MaCN
FROM #KT WHERE Loi IS NULL;
SELECT N'Đã nạp vào HOCVIEN' AS Buoc, @@ROWCOUNT AS SoDong, (SELECT COUNT(*) FROM dbo.HOCVIEN) AS TongHocVien;
IF @GhiThat = 1 COMMIT TRANSACTION; ELSE ROLLBACK TRANSACTION;

-- Dòng lỗi được giữ lại để gửi trả bộ phận tuyển sinh
DROP TABLE IF EXISTS dbo.STG_HOCVIEN_LOI;
SELECT Dong, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, QuanHuyen, MaCN, MaKHQuanTam, NgayDangKy, Loi
INTO dbo.STG_HOCVIEN_LOI FROM #KT WHERE Loi IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   1.4 Đo tốc độ BULK INSERT với 10 000 dòng
   --------------------------------------------------------------------- */
DECLARE @Dir NVARCHAR(260) = N'/data/import/', @sql NVARCHAR(MAX), @t0 DATETIME2;
TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE;
SET @t0 = SYSDATETIME();
SET @sql = N'BULK INSERT dbo.STG_HOCVIEN_ONLINE FROM ''' + @Dir + N'hocvien_10000.csv''
    WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', TABLOCK);';
EXEC sp_executesql @sql;
SELECT N'BULK INSERT 10 000 dòng' AS PhuongPhap, COUNT(*) AS SoDong, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()) AS ThoiGianMs
FROM dbo.STG_HOCVIEN_ONLINE;

-- So sánh: INSERT từng dòng bằng vòng lặp (giống ứng dụng gửi 10 000 câu lệnh)
DROP TABLE IF EXISTS #Copy;
SELECT * INTO #Copy FROM dbo.STG_HOCVIEN_ONLINE;
TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE;
DECLARE @a VARCHAR(200), @b VARCHAR(200), @c VARCHAR(30), @d VARCHAR(20), @e VARCHAR(30), @f VARCHAR(150), @g VARCHAR(200),
        @h VARCHAR(10), @i VARCHAR(10), @j VARCHAR(30);
SET @t0 = SYSDATETIME();
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #Copy;
OPEN cur; FETCH NEXT FROM cur INTO @a, @b, @c, @d, @e, @f, @g, @h, @i, @j;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT dbo.STG_HOCVIEN_ONLINE VALUES (@a, @b, @c, @d, @e, @f, @g, @h, @i, @j);
    FETCH NEXT FROM cur INTO @a, @b, @c, @d, @e, @f, @g, @h, @i, @j;
END
CLOSE cur; DEALLOCATE cur;
SELECT N'INSERT từng dòng (10 000 câu lệnh, cùng phiên)' AS PhuongPhap, COUNT(*) AS SoDong, DATEDIFF(MILLISECOND, @t0, SYSDATETIME()) AS ThoiGianMs
FROM dbo.STG_HOCVIEN_ONLINE;
TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE;
GO

/* ---------------------------------------------------------------------
   2. OPENROWSET(BULK …): đọc file trực tiếp trong câu SELECT
   --------------------------------------------------------------------- */
-- 2.1 File XML kết quả thi của đối tác (SINGLE_BLOB giữ nguyên mã hoá UTF-8 để kiểu XML tự giải mã)
DECLARE @x XML = (SELECT CAST(BulkColumn AS XML) FROM OPENROWSET(BULK '/data/xml/ketqua_doitac.xml', SINGLE_BLOB) AS f);
SELECT SDT, HoTen, CAST(AVG(Diem) AS DECIMAL(3,1)) AS DiemTong
FROM (SELECT ts.n.value('@SDT', 'VARCHAR(15)') AS SDT, ts.n.value('@HoTen', 'NVARCHAR(70)') AS HoTen,
             d.n.value('.', 'DECIMAL(3,1)') AS Diem
      FROM @x.nodes('/DanhSachThi/ThiSinh') ts(n) CROSS APPLY ts.n.nodes('Diem') d(n)) x
GROUP BY SDT, HoTen;

-- 2.2 File CSV đọc như bảng (SQL Server 2017+ hỗ trợ FORMAT = 'CSV' với OPENROWSET cần format file;
--     ở đây đọc cả file thành một chuỗi rồi tách dòng – đủ cho danh mục nhỏ)
SELECT TOP 5 value AS DongCSV
FROM OPENROWSET(BULK '/data/import/khoahoc.csv', SINGLE_CLOB) f
CROSS APPLY STRING_SPLIT(REPLACE(f.BulkColumn, CHAR(13), ''), CHAR(10))
WHERE value <> '';
GO

/* ---------------------------------------------------------------------
   3. XUẤT DỮ LIỆU
   --------------------------------------------------------------------- */
-- 3.1 JSON: danh sách lớp đang học kèm học viên (lồng mảng) – cho ứng dụng di động / API
SELECT l.MaLop, l.TenLop, l.MaCN, l.NgayKhaiGiang,
       (SELECT h.MaHV, h.HoTen, d.TrangThaiHP FROM dbo.DANGKY d JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV
        WHERE d.MaLop = l.MaLop AND d.TrangThai = N'Đang học' ORDER BY h.TenHV FOR JSON PATH) AS HocVien
FROM dbo.LOPHOC l WHERE l.TrangThai = N'Đang học'
ORDER BY l.MaLop
FOR JSON PATH, ROOT('LopDangHoc');

-- 3.2 JSON → bảng (nhập ngược): OPENJSON
DECLARE @j NVARCHAR(MAX) = (SELECT TOP 3 MaKH, TenKH, HocPhi FROM dbo.KHOAHOC ORDER BY MaKH FOR JSON PATH);
SELECT * FROM OPENJSON(@j) WITH (MaKH VARCHAR(6), TenKH NVARCHAR(100), HocPhi DECIMAL(12,0));

-- 3.3 XML: công nợ theo học viên
SELECT MaHV AS '@MaHV', HoTen AS 'HoTen', SUM(ConNo) AS 'TongNo', MAX(SoNgayQuaHan) AS 'QuaHanNgay'
FROM dbo.vw_CongNoHocVien GROUP BY MaHV, HoTen ORDER BY SUM(ConNo) DESC
FOR XML PATH('HocVien'), ROOT('CongNo');
GO

/* Ghi kết quả ra file (chạy trong terminal, không phải trong SSMS):

   -- bcp: xuất bảng / câu truy vấn ra CSV (UTF-8: -c -C 65001; -t, phân cách bằng dấu phẩy)
   bcp "SELECT MaHV, HoTen, SoDienThoai, MaCN FROM ECMS.dbo.vw_HocVien_ChiNhanh" queryout hocvien.csv -c -C 65001 -t, \
       -S localhost -U sa -P <mật khẩu> -u
   -- bcp: nhập CSV vào staging (nhanh như BULK INSERT nhưng chạy phía máy khách, đọc file trên máy người dùng)
   bcp ECMS.dbo.STG_HOCVIEN_ONLINE in data/import/hocvien_10000.csv -c -C 65001 -t, -F 2 -S localhost -U sa -P <mật khẩu> -u
   -- JSON ra file
   sqlcmd -S localhost -U sa -P <mật khẩu> -C -y 0 -Q "SET NOCOUNT ON; SELECT ... FOR JSON PATH" -o lop.json
   -- Excel: SSMS → Tasks → Export Data (SQL Server Import and Export Wizard) → Microsoft Excel,
             hoặc scripts/import_export.py export --format xlsx
*/
PRINT N'✓ 12_import_export.sql: BULK INSERT + ETL, OPENROWSET, FOR JSON / FOR XML, OPENJSON.';
GO
