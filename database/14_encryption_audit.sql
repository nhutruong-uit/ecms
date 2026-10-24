/* =====================================================================
   ECMS – 14_encryption_audit.sql : mã hoá và kiểm toán (demo, không nằm trong run_all)
   Bài giảng Chương 3 (an ninh dữ liệu) và Chương 1 (giai đoạn An toàn): mã hoá đường truyền (TLS), mã hoá dữ liệu
   lưu trữ (TDE), mã hoá cột, che dữ liệu, kiểm toán truy cập (SQL Server Audit) và nhật ký chống sửa (ledger).
     1. TLS – kết nối của ứng dụng có được mã hoá không
     2. TDE – mã hoá toàn bộ file dữ liệu / log / bản sao lưu   (CSDL demo ECMS_BaoMat, xoá ở cuối)
     3. Mã hoá cột lương bằng khoá đối xứng AES_256            (ECMS_BaoMat)
     4. Dynamic Data Masking – che số điện thoại, tên phụ huynh   (trên ECMS, trong transaction rồi ROLLBACK)
     5. SQL Server Audit – ghi cả thao tác ĐỌC dữ liệu nhạy cảm, so sánh với nhật ký bằng trigger (NHATKY)
     6. Ledger table – nhật ký chỉ-ghi-thêm, quản trị viên cũng không sửa được   (ECMS_BaoMat)
   Mật khẩu khoá trong file chỉ dùng cho môi trường demo. Chạy bằng sa trên SQL Server 2022 / 2025
   (TDE cần bản Developer / Standard / Enterprise; bản Express tự bỏ qua mục 2–3).
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1. MÃ HOÁ ĐƯỜNG TRUYỀN (TLS)
   ODBC Driver 18 mặc định Encrypt=yes: ứng dụng (app/core/config.py) luôn yêu cầu TLS. TrustServerCertificate=yes
   chỉ dùng cho máy phát triển có chứng chỉ tự ký; môi trường thật cài chứng chỉ do CA cấp và đặt =no để chống
   giả mạo máy chủ (man-in-the-middle). Bắt buộc mọi client mã hoá: Windows – SQL Server Configuration Manager →
   Protocols → Force Encryption = Yes; Linux – mssql-conf set network.forceencryption 1.
   --------------------------------------------------------------------- */
SELECT c.session_id, s.login_name, s.program_name, c.net_transport, c.encrypt_option AS MaHoaTLS, c.auth_scheme
FROM sys.dm_exec_connections c JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE s.is_user_process = 1
ORDER BY CASE WHEN s.login_name = N'ecms_app' THEN 0 ELSE 1 END, c.session_id;
GO

/* ---------------------------------------------------------------------
   CSDL demo cho mục 2, 3, 6 (bản sao dữ liệu nhân viên, không đụng tới ECMS)
   --------------------------------------------------------------------- */
IF DB_ID(N'ECMS_BaoMat') IS NOT NULL
BEGIN
    ALTER DATABASE ECMS_BaoMat SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ECMS_BaoMat;
END
CREATE DATABASE ECMS_BaoMat COLLATE Vietnamese_CI_AS;
GO
SELECT MaNV, HoTen, ChucVu, MaCN, LuongCoBan INTO ECMS_BaoMat.dbo.NHANVIEN FROM ECMS.dbo.NHANVIEN;
GO

/* ---------------------------------------------------------------------
   2. TDE – TRANSPARENT DATA ENCRYPTION
   Mã hoá ở mức trang khi ghi xuống đĩa và giải mã khi đọc lên bộ nhớ: ứng dụng không phải sửa gì, nhưng ai lấy
   được file .mdf / .ldf / .bak cũng không đọc được nếu không có certificate. Không bảo vệ trước người đã có
   quyền đọc trong CSDL (dữ liệu trên bộ nhớ và kết quả truy vấn vẫn là bản rõ) – việc đó là của mục 3–4.
   Thứ bậc khoá: Service Master Key → Database Master Key (master) → Certificate → Database Encryption Key.
   --------------------------------------------------------------------- */
IF CAST(SERVERPROPERTY('EngineEdition') AS INT) = 4
    PRINT N'Bản Express không hỗ trợ TDE – bỏ qua mục 2.';
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM master.sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Ecms@MasterKey2026';
    IF NOT EXISTS (SELECT 1 FROM master.sys.certificates WHERE name = N'ECMS_TDECert')
        CREATE CERTIFICATE ECMS_TDECert WITH SUBJECT = 'ECMS TDE certificate', EXPIRY_DATE = '2036-12-31';
END
GO
IF CAST(SERVERPROPERTY('EngineEdition') AS INT) <> 4
BEGIN
    -- Sao lưu certificate TDE ngay khi tạo: mất certificate = không gắn / phục hồi được CSDL đã mã hoá
    DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF RIGHT(@Dir, 1) NOT IN ('/', '\') SET @Dir += IIF(@Dir LIKE '%/%', '/', '\');
    DECLARE @Hau NVARCHAR(20) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'), @sql NVARCHAR(MAX);
    SET @sql = N'BACKUP CERTIFICATE ECMS_TDECert TO FILE = {CER} WITH PRIVATE KEY (FILE = {PVK}, ENCRYPTION BY PASSWORD = ''Ecms@CertKey2026'');';
    SET @sql = REPLACE(REPLACE(@sql, N'{CER}', QUOTENAME(@Dir + N'ECMS_TDECert_' + @Hau + N'.cer', '''')),
                       N'{PVK}', QUOTENAME(@Dir + N'ECMS_TDECert_' + @Hau + N'.pvk', ''''));
    EXEC (@sql);
    EXEC (N'USE ECMS_BaoMat; CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER CERTIFICATE ECMS_TDECert;');
    ALTER DATABASE ECMS_BaoMat SET ENCRYPTION ON;
    DECLARE @cho INT = 0;                                    -- quét mã hoá chạy nền: chờ tới trạng thái 3 = đã mã hoá
    WHILE @cho < 60 AND ISNULL((SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(N'ECMS_BaoMat')), 0) <> 3
    BEGIN WAITFOR DELAY '00:00:01'; SET @cho += 1; END
    SELECT DB_NAME(k.database_id) AS CSDL, k.encryption_state_desc AS TrangThai, k.key_algorithm, k.key_length,
           k.encryptor_type, d.is_encrypted, k.percent_complete
    FROM sys.dm_database_encryption_keys k JOIN sys.databases d ON d.database_id = k.database_id
    WHERE d.name IN (N'ECMS_BaoMat', N'tempdb');       -- bật TDE cho bất kỳ CSDL nào thì tempdb cũng được mã hoá
END
GO

/* ---------------------------------------------------------------------
   3. MÃ HOÁ CỘT (cell-level encryption) – lương chỉ người có quyền dùng khoá mới đọc được
   Khác TDE: dữ liệu được mã hoá ngay trong bảng, kể cả db_datareader đọc bảng cũng chỉ thấy chuỗi nhị phân.
   (Always Encrypted mã hoá ở phía client – máy chủ không bao giờ thấy bản rõ – nhưng cần cấu hình khoá trên
   máy ứng dụng nên không demo ở đây.)
   --------------------------------------------------------------------- */
USE ECMS_BaoMat;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Ecms@DbKey2026';
CREATE CERTIFICATE CertLuong WITH SUBJECT = 'Khoá bảo vệ cột lương', EXPIRY_DATE = '2036-12-31';
CREATE SYMMETRIC KEY KhoaLuong WITH ALGORITHM = AES_256 ENCRYPTION BY CERTIFICATE CertLuong;
ALTER TABLE dbo.NHANVIEN ADD LuongMaHoa VARBINARY(256) NULL;
GO
OPEN SYMMETRIC KEY KhoaLuong DECRYPTION BY CERTIFICATE CertLuong;
UPDATE dbo.NHANVIEN SET LuongMaHoa = ENCRYPTBYKEY(KEY_GUID('KhoaLuong'), CAST(LuongCoBan AS NVARCHAR(20)), 1, MaNV);  -- MaNV làm "authenticator": chép bản mã sang dòng khác sẽ không giải mã được
ALTER TABLE dbo.NHANVIEN DROP COLUMN LuongCoBan;                                                                     -- chỉ còn bản mã
SELECT TOP 3 MaNV, HoTen, CONVERT(VARCHAR(34), LuongMaHoa, 1) AS BanMa,
       CAST(CAST(DECRYPTBYKEY(LuongMaHoa, 1, MaNV) AS NVARCHAR(20)) AS DECIMAL(12,0)) AS GiaiMa_CoKhoa
FROM dbo.NHANVIEN ORDER BY MaNV;
CLOSE SYMMETRIC KEY KhoaLuong;
-- người dùng chỉ có quyền SELECT trên bảng (không có quyền trên khoá) đọc ra NULL
CREATE USER u_xem WITHOUT LOGIN;
GRANT SELECT ON dbo.NHANVIEN TO u_xem;
EXECUTE AS USER = 'u_xem';
SELECT TOP 3 MaNV, HoTen, CAST(DECRYPTBYKEY(LuongMaHoa, 1, MaNV) AS NVARCHAR(20)) AS GiaiMa_KhongQuyen FROM dbo.NHANVIEN ORDER BY MaNV;
REVERT;
GO

/* ---------------------------------------------------------------------
   4. DYNAMIC DATA MASKING – che một phần dữ liệu khi hiển thị cho người không có quyền UNMASK
   Áp trên ECMS trong transaction rồi ROLLBACK (không đổi lược đồ thật). Giáo vụ đọc qua vw_HocVien_ChiNhanh
   thấy số điện thoại / tên phụ huynh bị che; dbo thấy đầy đủ. (Cột Email có filtered unique index UX_HOCVIEN_Email
   nên SQL Server không cho thêm mask – lỗi 5074.) Lưu ý: masking chỉ che khi hiển thị, KHÔNG phải mã hoá –
   người dùng vẫn lọc WHERE theo giá trị thật được, nên chỉ dùng kèm phân quyền chặt.
   --------------------------------------------------------------------- */
USE ECMS;
GO
BEGIN TRANSACTION;
ALTER TABLE dbo.HOCVIEN ALTER COLUMN SoDienThoai ADD MASKED WITH (FUNCTION = 'partial(0, "xxxxxxx", 3)');
ALTER TABLE dbo.HOCVIEN ALTER COLUMN HoTenPhuHuynh ADD MASKED WITH (FUNCTION = 'default()');
DECLARE @Xem TABLE (NguoiXem SYSNAME, MaHV CHAR(6), SoDienThoai VARCHAR(15), HoTenPhuHuynh NVARCHAR(70));
DECLARE @hv TABLE (MaHV CHAR(6));
INSERT @hv SELECT TOP 2 MaHV FROM dbo.HOCVIEN WHERE MaCN = 'CN01' AND HoTenPhuHuynh IS NOT NULL ORDER BY MaHV;
INSERT @Xem SELECT N'dbo', MaHV, SoDienThoai, HoTenPhuHuynh FROM dbo.HOCVIEN WHERE MaHV IN (SELECT MaHV FROM @hv);
EXECUTE AS USER = 'u_giaovu';                             -- ↔ tài khoản 'giaovu' (CN01), không có quyền UNMASK
INSERT @Xem SELECT N'u_giaovu', MaHV, SoDienThoai, HoTenPhuHuynh FROM dbo.vw_HocVien_ChiNhanh WHERE MaHV IN (SELECT MaHV FROM @hv);
REVERT;
SELECT * FROM @Xem ORDER BY MaHV, NguoiXem;
ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   5. SQL SERVER AUDIT – kiểm toán do máy chủ ghi, ghi được cả thao tác ĐỌC
   Nhật ký bằng trigger (NHATKY, 06_triggers.sql) chỉ thấy INSERT / UPDATE / DELETE và nằm ngay trong CSDL;
   SQL Server Audit ghi cả SELECT, EXECUTE, đăng nhập… ra file ngoài CSDL, người có quyền trong CSDL không sửa được.
   --------------------------------------------------------------------- */
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = N'ECMS_Audit')
BEGIN
    IF EXISTS (SELECT 1 FROM ECMS.sys.database_audit_specifications WHERE name = N'ECMS_AuditDuLieuNhayCam')
        EXEC (N'USE ECMS; ALTER DATABASE AUDIT SPECIFICATION ECMS_AuditDuLieuNhayCam WITH (STATE = OFF);
                DROP DATABASE AUDIT SPECIFICATION ECMS_AuditDuLieuNhayCam;');
    ALTER SERVER AUDIT ECMS_Audit WITH (STATE = OFF);
    DROP SERVER AUDIT ECMS_Audit;
END
DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260)), @sql NVARCHAR(MAX);
SET @sql = N'CREATE SERVER AUDIT ECMS_Audit TO FILE (FILEPATH = {DIR}, MAXSIZE = 20 MB, MAX_ROLLOVER_FILES = 5)
             WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);';
SET @sql = REPLACE(@sql, N'{DIR}', QUOTENAME(@Dir, ''''));
EXEC (@sql);
ALTER SERVER AUDIT ECMS_Audit WITH (STATE = ON);
GO
USE ECMS;
GO
-- Ghi mọi lần đọc bảng lương / tài khoản và mọi lần gọi procedure quản trị tài khoản, của bất kỳ ai (public)
CREATE DATABASE AUDIT SPECIFICATION ECMS_AuditDuLieuNhayCam FOR SERVER AUDIT ECMS_Audit
    ADD (SELECT ON dbo.NHANVIEN BY public),
    ADD (SELECT ON dbo.TAIKHOAN BY public),
    ADD (EXECUTE ON dbo.sp_CapNhatTaiKhoan BY public)
    WITH (STATE = ON);
GO
-- Thao tác mẫu: quản lý xem lương (đọc – trigger không ghi được), ứng dụng đọc danh sách tài khoản qua view
DECLARE @BatDau DATETIME2 = SYSUTCDATETIME();
EXECUTE AS USER = 'u_quanly';
SELECT COUNT(*) AS SoNhanVien, SUM(LuongCoBan) AS QuyLuong FROM dbo.NHANVIEN;
REVERT;
EXECUTE AS USER = 'u_app';
SELECT COUNT(*) AS SoTaiKhoan FROM dbo.vw_TaiKhoan;
REVERT;
WAITFOR DELAY '00:00:02';                                    -- QUEUE_DELAY = 1 giây
DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
IF RIGHT(@Dir, 1) NOT IN ('/', '\') SET @Dir += IIF(@Dir LIKE '%/%', '/', '\');
SELECT a.event_time, a.action_id, a.server_principal_name AS Login, a.database_principal_name AS NguoiDungCSDL,
       a.object_name AS DoiTuong, LEFT(a.statement, 80) AS CauLenh
FROM sys.fn_get_audit_file(@Dir + N'ECMS_Audit*.sqlaudit', DEFAULT, DEFAULT) a
WHERE a.event_time >= @BatDau AND a.object_name IN (N'NHANVIEN', N'TAIKHOAN', N'sp_CapNhatTaiKhoan')
ORDER BY a.event_time;
GO
-- Dọn: tắt và xoá đặc tả kiểm toán (file .sqlaudit vẫn giữ trong thư mục sao lưu để xem lại)
ALTER DATABASE AUDIT SPECIFICATION ECMS_AuditDuLieuNhayCam WITH (STATE = OFF);
DROP DATABASE AUDIT SPECIFICATION ECMS_AuditDuLieuNhayCam;
GO
USE master;
ALTER SERVER AUDIT ECMS_Audit WITH (STATE = OFF);
DROP SERVER AUDIT ECMS_Audit;
GO

/* ---------------------------------------------------------------------
   6. LEDGER TABLE (SQL Server 2022 trở lên) – nhật ký chỉ-ghi-thêm
   Trigger trg_NhatKy_ChiDoc chặn UPDATE / DELETE trên NHATKY nhưng db_owner vẫn tắt được trigger hoặc TRUNCATE.
   Bảng ledger APPEND_ONLY bị chặn ở tầng máy chủ: không ai sửa / xoá được, mỗi giao dịch được băm nối chuỗi
   (blockchain) để kiểm chứng dữ liệu chưa bị can thiệp bằng sys.sp_verify_database_ledger.
   --------------------------------------------------------------------- */
USE ECMS_BaoMat;
GO
CREATE TABLE dbo.NHATKY_LEDGER (
    MaNK      BIGINT IDENTITY PRIMARY KEY,
    TenBang   SYSNAME        NOT NULL,
    ThaoTac   VARCHAR(6)     NOT NULL,
    DuLieuMoi NVARCHAR(MAX)  NULL,
    ThoiGian  DATETIME2(3)   NOT NULL DEFAULT SYSDATETIME()
) WITH (LEDGER = ON (APPEND_ONLY = ON));
GO
INSERT dbo.NHATKY_LEDGER (TenBang, ThaoTac, DuLieuMoi) VALUES (N'NHANVIEN', 'UPDATE', N'{"LuongCoBan":12000000}');
DECLARE @s1 NVARCHAR(300), @s2 NVARCHAR(300);
-- lỗi bị chặn phát sinh lúc biên dịch câu lệnh → chạy qua sp_executesql để TRY/CATCH bắt được
BEGIN TRY EXEC sp_executesql N'UPDATE dbo.NHATKY_LEDGER SET DuLieuMoi = N''{"LuongCoBan":99000000}'';'; SET @s1 = N'sửa được'; END TRY
BEGIN CATCH SET @s1 = CONCAT(N'Bị chặn – lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;
BEGIN TRY EXEC sp_executesql N'TRUNCATE TABLE dbo.NHATKY_LEDGER;'; SET @s2 = N'xoá được'; END TRY
BEGIN CATCH SET @s2 = CONCAT(N'Bị chặn – lỗi ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;
SELECT N'UPDATE bảng ledger (dbo / sa)' AS ThaoTac, @s1 AS KetQua
UNION ALL SELECT N'TRUNCATE bảng ledger (dbo / sa)', @s2
UNION ALL SELECT N'Số giao dịch ledger đã băm', CAST((SELECT COUNT(*) FROM sys.database_ledger_transactions) AS NVARCHAR(10));
GO

/* ---------------------------------------------------------------------
   Dọn CSDL demo (certificate trong master giữ lại; file .cer / .pvk ở thư mục sao lưu)
   --------------------------------------------------------------------- */
USE master;
GO
ALTER DATABASE ECMS_BaoMat SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE ECMS_BaoMat;
GO
PRINT N'✓ 14_encryption_audit.sql: TLS, TDE, mã hoá cột, dynamic data masking, SQL Server Audit, ledger table.';
GO
