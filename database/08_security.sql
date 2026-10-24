/* =====================================================================
   ECMS – 08_security.sql : xác thực, phân quyền, băm mật khẩu ứng dụng     (T15)
   1. Chế độ xác thực           4. Băm mật khẩu tài khoản ứng dụng (TAIKHOAN)
   2. LOGIN (cấp server)         5. Procedure đăng nhập / quản lý tài khoản cho web
   3. USER, ROLE (cấp CSDL)      6. GRANT / REVOKE / DENY theo ma trận quyền
   Chạy lại được: login đã có thì đổi mật khẩu, user / role được xoá rồi tạo lại.
   Mật khẩu dưới đây là mật khẩu MÔI TRƯỜNG PHÁT TRIỂN (khớp .env.example), đổi khi triển khai thật.
   Chạy SAU 03–07 vì quyền của r_App được cấp tự động cho mọi view / procedure / function đang có.
   ===================================================================== */
USE master;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   1. CHẾ ĐỘ XÁC THỰC
   Windows Authentication: SQL Server tin danh tính đã xác thực bởi Windows / Active Directory.
   SQL Server Authentication: login + mật khẩu lưu (băm) trong master.
   Mixed mode = cho phép cả hai. Ứng dụng web chạy trên Linux/macOS và container nên cần Mixed mode.
   Bật Mixed mode trên Windows (cần khởi động lại dịch vụ):
     EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
   (Bản Docker mặc định đã là Mixed mode.)
   --------------------------------------------------------------------- */
SELECT CASE SERVERPROPERTY('IsIntegratedSecurityOnly') WHEN 1 THEN N'Chỉ Windows Authentication'
            ELSE N'Mixed mode (Windows + SQL Server Authentication)' END AS CheDoXacThuc;
GO

/* ---------------------------------------------------------------------
   2. LOGIN – mỗi vai trò một login minh hoạ + login cho ứng dụng web
   CHECK_POLICY = ON: áp chính sách độ phức tạp / khoá tài khoản của Windows (hoặc mặc định của SQL Server trên Linux)
   CHECK_EXPIRATION: login người dùng bật hết hạn mật khẩu; login ứng dụng tắt để dịch vụ không bị dừng đột ngột.
   --------------------------------------------------------------------- */
DECLARE @Logins TABLE (Ten SYSNAME, MatKhau NVARCHAR(128), HetHan BIT);
INSERT @Logins VALUES
    (N'ecms_app',      N'App@Ecms2026',      0),
    (N'ecms_quanly',   N'QuanLy@Ecms2026',   1),
    (N'ecms_giaovu',   N'GiaoVu@Ecms2026',   1),
    (N'ecms_ketoan',   N'KeToan@Ecms2026',   1),
    (N'ecms_giaovien', N'GiaoVien@Ecms2026', 1),
    (N'ecms_hocvien',  N'HocVien@Ecms2026',  1);
DECLARE @Ten SYSNAME, @MK NVARCHAR(128), @HH BIT, @sql NVARCHAR(MAX);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Ten, MatKhau, HetHan FROM @Logins;
OPEN cur; FETCH NEXT FROM cur INTO @Ten, @MK, @HH;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF SUSER_ID(@Ten) IS NULL
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@Ten) + N' WITH PASSWORD = ' + QUOTENAME(@MK, '''')
                 + N', DEFAULT_DATABASE = ECMS, CHECK_POLICY = ON, CHECK_EXPIRATION = ' + IIF(@HH = 1, N'ON', N'OFF') + N';';
    ELSE
        SET @sql = N'ALTER LOGIN ' + QUOTENAME(@Ten) + N' WITH PASSWORD = ' + QUOTENAME(@MK, '''')
                 + N', CHECK_POLICY = ON, CHECK_EXPIRATION = ' + IIF(@HH = 1, N'ON', N'OFF') + N'; ALTER LOGIN ' + QUOTENAME(@Ten) + N' ENABLE;';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur INTO @Ten, @MK, @HH;
END
CLOSE cur; DEALLOCATE cur;
GO

USE ECMS;
GO

/* ---------------------------------------------------------------------
   3. ROLE và USER trong CSDL ECMS
   --------------------------------------------------------------------- */
-- Xoá role cũ (phải gỡ thành viên trước) và user cũ khi chạy lại
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'ALTER ROLE ' + QUOTENAME(r.name) + N' DROP MEMBER ' + QUOTENAME(m.name) + N';'
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'r[_]%';
EXEC sp_executesql @sql;
SET @sql = N'';
SELECT @sql += N'DROP ROLE ' + QUOTENAME(name) + N';' FROM sys.database_principals WHERE type = 'R' AND name LIKE 'r[_]%';
EXEC sp_executesql @sql;
DROP USER IF EXISTS u_app;     DROP USER IF EXISTS u_quanly; DROP USER IF EXISTS u_giaovu;
DROP USER IF EXISTS u_ketoan;  DROP USER IF EXISTS u_giaovien; DROP USER IF EXISTS u_hocvien;
GO

CREATE ROLE r_QuanLy;    -- quản lý chi nhánh / trung tâm
CREATE ROLE r_GiaoVu;    -- tư vấn, tuyển sinh, xếp lớp
CREATE ROLE r_KeToan;    -- thu học phí, công nợ, lương
CREATE ROLE r_GiaoVien;  -- điểm danh, nhập điểm
CREATE ROLE r_HocVien;   -- tra cứu
CREATE ROLE r_App;       -- tài khoản kết nối của ứng dụng web
GO
CREATE USER u_app      FOR LOGIN ecms_app;      ALTER ROLE r_App      ADD MEMBER u_app;
CREATE USER u_quanly   FOR LOGIN ecms_quanly;   ALTER ROLE r_QuanLy   ADD MEMBER u_quanly;
CREATE USER u_giaovu   FOR LOGIN ecms_giaovu;   ALTER ROLE r_GiaoVu   ADD MEMBER u_giaovu;
CREATE USER u_ketoan   FOR LOGIN ecms_ketoan;   ALTER ROLE r_KeToan   ADD MEMBER u_ketoan;
CREATE USER u_giaovien FOR LOGIN ecms_giaovien; ALTER ROLE r_GiaoVien ADD MEMBER u_giaovien;
CREATE USER u_hocvien  FOR LOGIN ecms_hocvien;  ALTER ROLE r_HocVien  ADD MEMBER u_hocvien;
GO

/* ---------------------------------------------------------------------
   4. BĂM MẬT KHẨU TÀI KHOẢN ỨNG DỤNG
   dbo.fn_BamMatKhau (định nghĩa ở 01_schema.sql, cạnh bảng TAIKHOAN, vì dữ liệu mẫu cũng dùng):
   MatKhauHash = 10.000 vòng SHA2_256 trên (Salt ‖ mật khẩu UTF-16LE), Salt ngẫu nhiên 16 byte cho từng tài khoản
   → hai người cùng mật khẩu vẫn có hash khác nhau (chống bảng băm có sẵn – rainbow table) và mỗi lần đoán thử
   tốn 10.000 lần băm (kéo dãn khoá – key stretching, cùng ý tưởng với PBKDF2 / bcrypt).
   --------------------------------------------------------------------- */
-- Mật khẩu đủ mạnh: ≥ 8 ký tự, có chữ hoa, chữ thường, chữ số, ký tự đặc biệt
CREATE OR ALTER FUNCTION dbo.fn_MatKhauHopLe (@MatKhau NVARCHAR(100))
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN LEN(@MatKhau) >= 8
                 -- collation nhị phân: khoảng [A-Z] chỉ gồm chữ hoa (với collation thường, [A-Z] khớp cả chữ thường)
                 AND @MatKhau COLLATE Latin1_General_BIN LIKE '%[A-Z]%'
                 AND @MatKhau COLLATE Latin1_General_BIN LIKE '%[a-z]%'
                 AND @MatKhau LIKE '%[0-9]%'
                 AND @MatKhau COLLATE Latin1_General_BIN LIKE '%[^a-zA-Z0-9]%' THEN 1 ELSE 0 END;
END
GO

/* ---------------------------------------------------------------------
   5. PROCEDURE ĐĂNG NHẬP / QUẢN LÝ TÀI KHOẢN (ứng dụng web gọi – T19)
   --------------------------------------------------------------------- */

-- Đăng nhập: trả 1 dòng thông tin người dùng nếu đúng; sai thì không trả dòng nào và @ThongBao cho biết lý do.
-- Không THROW khi sai mật khẩu để việc tăng SoLanSai không bị rollback theo lỗi.
-- Chống dò tài khoản và dò mật khẩu:
--   • Sai mật khẩu và tài khoản không tồn tại trả CÙNG một thông báo, cùng thời gian xử lý (vẫn băm một lần),
--     không báo số lần thử còn lại → không đoán được tên đăng nhập nào có thật.
--   • Sai 5 lần liên tiếp → TẠM KHOÁ 15 phút (KhoaDen), không khoá vĩnh viễn: người khác gõ sai cố ý
--     cũng không khoá hẳn được tài khoản của quản lý (tấn công từ chối dịch vụ).
--   • Trạng thái khoá chỉ được báo khi mật khẩu ĐÚNG: người đang dò mật khẩu không biết tài khoản đã bị khoá.
CREATE OR ALTER PROCEDURE dbo.sp_DangNhap
    @TenDangNhap VARCHAR(30),
    @MatKhau     NVARCHAR(100),
    @ThongBao    NVARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hash VARBINARY(32), @Salt VARBINARY(16), @TrangThai BIT, @KhoaDen DATETIME2(0),
            @Luc DATETIME2(0) = SYSDATETIME(), @SaiChung NVARCHAR(200) = N'Sai tên đăng nhập hoặc mật khẩu.';
    SELECT @Hash = MatKhauHash, @Salt = Salt, @TrangThai = TrangThai, @KhoaDen = KhoaDen
    FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap;

    IF @Hash IS NULL
    BEGIN
        SET @Hash = dbo.fn_BamMatKhau(@MatKhau, 0x00);   -- băm "giả" để thời gian phản hồi như tài khoản có thật
        SET @ThongBao = @SaiChung;
        RETURN 1;
    END
    IF dbo.fn_BamMatKhau(@MatKhau, @Salt) <> @Hash
    BEGIN
        -- đang tạm khoá thì không cộng dồn; đủ 5 lần sai thì tạm khoá 15 phút và đếm lại từ đầu
        UPDATE dbo.TAIKHOAN
        SET KhoaDen  = IIF(SoLanSai + 1 >= 5, DATEADD(MINUTE, 15, @Luc), KhoaDen),
            SoLanSai = IIF(SoLanSai + 1 >= 5, 0, SoLanSai + 1)
        WHERE TenDangNhap = @TenDangNhap AND (KhoaDen IS NULL OR KhoaDen <= @Luc);
        SET @ThongBao = @SaiChung;
        RETURN 3;
    END
    IF @TrangThai = 0
    BEGIN
        SET @ThongBao = N'Tài khoản đã bị khoá. Liên hệ quản trị viên.';
        RETURN 2;
    END
    IF @KhoaDen > @Luc
    BEGIN
        SET @ThongBao = CONCAT(N'Tài khoản tạm khoá đến ', FORMAT(@KhoaDen, 'HH:mm'),
                               N' do nhập sai mật khẩu 5 lần liên tiếp. Thử lại sau hoặc liên hệ quản trị viên.');
        RETURN 4;
    END

    UPDATE dbo.TAIKHOAN SET SoLanSai = 0, KhoaDen = NULL, LanDangNhapCuoi = @Luc WHERE TenDangNhap = @TenDangNhap;
    SET @ThongBao = N'Đăng nhập thành công.';
    -- PhamViCN: chi nhánh dùng cho SESSION_CONTEXT 'ma_cn'; quản lý cấp cao nhất (không có người quản lý) xem tất cả
    SELECT t.TenDangNhap, t.VaiTro, t.MaNV, t.MaHV,
           COALESCE(nv.HoTen, hv.HoTen) AS HoTen,
           COALESCE(nv.MaCN, hv.MaCN) AS MaCN,
           CASE WHEN t.VaiTro = 'QuanLy' AND nv.MaNVQuanLy IS NULL THEN 'ALL' ELSE COALESCE(nv.MaCN, hv.MaCN) END AS PhamViCN
    FROM dbo.TAIKHOAN t
    LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = t.MaNV
    LEFT JOIN dbo.HOCVIEN hv ON hv.MaHV = t.MaHV
    WHERE t.TenDangNhap = @TenDangNhap;
    RETURN 0;
END
GO

-- Đổi mật khẩu của chính mình. Sai mật khẩu hiện tại cũng tính vào số lần sai (không dò mật khẩu qua trang này được).
-- Giống sp_DangNhap: sai mật khẩu không THROW (để số lần sai vừa tăng không bị rollback theo lỗi) mà trả
-- @ThongBao; @ThongBao = N'Đã đổi mật khẩu.' nghĩa là thành công.
CREATE OR ALTER PROCEDURE dbo.sp_DoiMatKhau
    @TenDangNhap VARCHAR(30),
    @MatKhauCu   NVARCHAR(100),
    @MatKhauMoi  NVARCHAR(100),
    @ThongBao    NVARCHAR(200) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- kết nối của ứng dụng chỉ đổi được mật khẩu của tài khoản đang đăng nhập
    IF IS_ROLEMEMBER('r_App') = 1 AND ISNULL(CAST(SESSION_CONTEXT(N'app_user') AS VARCHAR(30)), '') <> @TenDangNhap
        THROW 50090, N'Mật khẩu hiện tại không đúng.', 1;
    DECLARE @Luc DATETIME2(0) = SYSDATETIME();
    IF NOT EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap AND TrangThai = 1
                   AND (KhoaDen IS NULL OR KhoaDen <= @Luc) AND MatKhauHash = dbo.fn_BamMatKhau(@MatKhauCu, Salt))
    BEGIN
        UPDATE dbo.TAIKHOAN
        SET KhoaDen  = IIF(SoLanSai + 1 >= 5, DATEADD(MINUTE, 15, @Luc), KhoaDen),
            SoLanSai = IIF(SoLanSai + 1 >= 5, 0, SoLanSai + 1)
        WHERE TenDangNhap = @TenDangNhap AND (KhoaDen IS NULL OR KhoaDen <= @Luc);
        SET @ThongBao = N'Mật khẩu hiện tại không đúng.';
        RETURN 1;
    END
    IF dbo.fn_MatKhauHopLe(@MatKhauMoi) = 0
        THROW 50091, N'Mật khẩu mới phải từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt.', 1;
    IF @MatKhauMoi = @MatKhauCu THROW 50092, N'Mật khẩu mới phải khác mật khẩu cũ.', 1;
    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);     -- đổi mật khẩu thì sinh salt mới
    UPDATE dbo.TAIKHOAN SET Salt = @Salt, MatKhauHash = dbo.fn_BamMatKhau(@MatKhauMoi, @Salt), SoLanSai = 0
    WHERE TenDangNhap = @TenDangNhap;
    SET @ThongBao = N'Đã đổi mật khẩu.';
    RETURN 0;
END
GO

-- Vai trò tài khoản phải khớp chức vụ của nhân viên (học viên → HocVien): quyền luôn đi theo chức vụ thật
CREATE OR ALTER FUNCTION dbo.fn_VaiTroTheoChucVu (@MaNV CHAR(6), @MaHV CHAR(6))
RETURNS VARCHAR(10)
AS
BEGIN
    IF @MaHV IS NOT NULL RETURN 'HocVien';
    RETURN (SELECT CASE ChucVu WHEN N'Quản lý' THEN 'QuanLy' WHEN N'Giáo vụ' THEN 'GiaoVu'
                               WHEN N'Kế toán' THEN 'KeToan' WHEN N'Giáo viên' THEN 'GiaoVien' END
            FROM dbo.NHANVIEN WHERE MaNV = @MaNV);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TaoTaiKhoan
    @TenDangNhap VARCHAR(30),
    @MatKhau     NVARCHAR(100),
    @VaiTro      VARCHAR(10),
    @MaNV        CHAR(6) = NULL,
    @MaHV        CHAR(6) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- kết nối của ứng dụng: chỉ quản lý được tạo tài khoản
    IF IS_ROLEMEMBER('r_App') = 1 AND ISNULL(CAST(SESSION_CONTEXT(N'vai_tro') AS VARCHAR(10)), '') <> 'QuanLy'
        THROW 50096, N'Chỉ quản lý được tạo hoặc cập nhật tài khoản.', 1;
    -- so khớp theo collation nhị phân: với Vietnamese_CI_AS, [a-z] khớp cả chữ hoa
    IF LEN(@TenDangNhap) < 4 OR @TenDangNhap COLLATE Latin1_General_BIN NOT LIKE '[a-z0-9]%'
       OR @TenDangNhap COLLATE Latin1_General_BIN LIKE '%[^a-z0-9._]%'
        THROW 50093, N'Tên đăng nhập 4–30 ký tự, bắt đầu bằng chữ thường hoặc số, chỉ gồm chữ thường không dấu, số, dấu chấm, gạch dưới.', 1;
    IF EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 50094, N'Tên đăng nhập đã tồn tại.', 1;
    IF dbo.fn_MatKhauHopLe(@MatKhau) = 0
        THROW 50091, N'Mật khẩu phải từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt.', 1;
    IF ISNULL(dbo.fn_VaiTroTheoChucVu(@MaNV, @MaHV), '') <> @VaiTro
        THROW 50098, N'Vai trò tài khoản không khớp chức vụ của nhân viên (hoặc mã nhân viên / học viên không tồn tại).', 1;
    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
    INSERT dbo.TAIKHOAN (TenDangNhap, MatKhauHash, Salt, VaiTro, MaNV, MaHV)
    VALUES (@TenDangNhap, dbo.fn_BamMatKhau(@MatKhau, @Salt), @Salt, @VaiTro, @MaNV, @MaHV);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_CapNhatTaiKhoan
    @TenDangNhap  VARCHAR(30),
    @TrangThai    BIT = NULL,              -- 0 khoá, 1 mở khoá (mở khoá thì xoá số lần sai và tạm khoá)
    @VaiTro       VARCHAR(10) = NULL,
    @MatKhauMoi   NVARCHAR(100) = NULL     -- quản trị đặt lại mật khẩu (đồng thời gỡ tạm khoá do nhập sai)
AS
BEGIN
    SET NOCOUNT ON;
    IF IS_ROLEMEMBER('r_App') = 1 AND ISNULL(CAST(SESSION_CONTEXT(N'vai_tro') AS VARCHAR(10)), '') <> 'QuanLy'
        THROW 50096, N'Chỉ quản lý được tạo hoặc cập nhật tài khoản.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap)
        THROW 50095, N'Tài khoản không tồn tại.', 1;
    -- không tự khoá / tự hạ quyền tài khoản đang dùng (tránh mất quyền quản trị)
    IF @TenDangNhap = CAST(SESSION_CONTEXT(N'app_user') AS VARCHAR(30)) AND (@TrangThai = 0 OR @VaiTro <> 'QuanLy')
        THROW 50099, N'Không thể tự khoá hoặc đổi vai trò của tài khoản đang đăng nhập.', 1;
    IF @VaiTro IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.TAIKHOAN WHERE TenDangNhap = @TenDangNhap
                                      AND ISNULL(dbo.fn_VaiTroTheoChucVu(MaNV, MaHV), '') <> @VaiTro)
        THROW 50098, N'Vai trò tài khoản phải khớp chức vụ – đổi chức vụ ở trang Nhân viên, vai trò sẽ đổi theo.', 1;
    IF @MatKhauMoi IS NOT NULL AND dbo.fn_MatKhauHopLe(@MatKhauMoi) = 0
        THROW 50091, N'Mật khẩu phải từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt.', 1;
    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);
    UPDATE dbo.TAIKHOAN SET
        TrangThai   = ISNULL(@TrangThai, TrangThai),
        SoLanSai    = IIF(@TrangThai = 1 OR @MatKhauMoi IS NOT NULL, 0, SoLanSai),
        KhoaDen     = IIF(@TrangThai = 1 OR @MatKhauMoi IS NOT NULL, NULL, KhoaDen),
        VaiTro      = ISNULL(@VaiTro, VaiTro),
        Salt        = IIF(@MatKhauMoi IS NULL, Salt, @Salt),
        MatKhauHash = IIF(@MatKhauMoi IS NULL, MatKhauHash, dbo.fn_BamMatKhau(@MatKhauMoi, @Salt))
    WHERE TenDangNhap = @TenDangNhap;
END
GO

-- Danh sách tài khoản cho trang quản trị: KHÔNG có hash và salt
CREATE OR ALTER VIEW dbo.vw_TaiKhoan
AS
SELECT t.TenDangNhap, t.VaiTro, t.MaNV, t.MaHV, COALESCE(nv.HoTen, hv.HoTen) AS HoTen,
       COALESCE(nv.MaCN, hv.MaCN) AS MaCN, t.TrangThai, t.SoLanSai, t.KhoaDen, t.LanDangNhapCuoi, t.NgayTao
FROM dbo.TAIKHOAN t
LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = t.MaNV
LEFT JOIN dbo.HOCVIEN hv ON hv.MaHV = t.MaHV;
GO

-- Nhật ký cho trang quản trị
CREATE OR ALTER VIEW dbo.vw_NhatKy
AS
SELECT MaNK, TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiThucHien, NguoiDungUD, ThoiGian FROM dbo.NHATKY;
GO

/* ---------------------------------------------------------------------
   6. PHÂN QUYỀN – GRANT / REVOKE / DENY
   Nguyên tắc quyền tối thiểu. Mọi đối tượng thuộc schema dbo nên view / procedure truy cập bảng
   qua ownership chaining: người dùng chỉ cần quyền trên view / procedure, không cần (và bị DENY) quyền trên bảng.
   --------------------------------------------------------------------- */

-- 6.1 r_App: EXECUTE mọi procedure, SELECT mọi view và hàm trả về bảng, EXECUTE hàm vô hướng; DENY mọi bảng
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += CASE o.type
        WHEN 'P'  THEN N'GRANT EXECUTE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
        WHEN 'FN' THEN N'GRANT EXECUTE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
        WHEN 'V'  THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
        WHEN 'IF' THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
        WHEN 'TF' THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
        WHEN 'U'  THEN N'DENY SELECT, INSERT, UPDATE, DELETE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    END
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0 AND o.type IN ('P', 'FN', 'V', 'IF', 'TF', 'U') AND s.name = 'dbo';
EXEC sp_executesql @sql;
GO

-- 6.2 r_QuanLy: xem mọi thứ (kể cả lương), chạy báo cáo; không sửa trực tiếp dữ liệu tài chính
GRANT SELECT ON SCHEMA::dbo TO r_QuanLy;
GRANT EXECUTE ON dbo.sp_ThongKeDoanhThu TO r_QuanLy;
GRANT EXECUTE ON dbo.sp_TinhLuongGiaoVien TO r_QuanLy;
GRANT EXECUTE ON dbo.sp_CanhBaoChuyenCan TO r_QuanLy;
GRANT UPDATE ON dbo.NHANVIEN TO r_QuanLy;                              -- điều chỉnh lương (có nhật ký T13)
DENY  SELECT ON dbo.TAIKHOAN (MatKhauHash, Salt) TO r_QuanLy;          -- DENY mức CỘT thắng GRANT mức schema
DENY  INSERT, UPDATE, DELETE ON dbo.PHIEUTHU TO r_QuanLy;
DENY  INSERT, UPDATE, DELETE ON dbo.CT_PHIEUTHU TO r_QuanLy;
-- WITH GRANT OPTION: quản lý được tự cấp tiếp quyền xem báo cáo sĩ số cho người khác
GRANT SELECT ON dbo.vw_SiSoLop TO u_quanly WITH GRANT OPTION;
GO

-- 6.3 r_GiaoVu: tuyển sinh – xếp lớp
GRANT SELECT ON dbo.vw_HocVien_ChiNhanh TO r_GiaoVu;
GRANT SELECT ON dbo.vw_NhanVien_CongKhai TO r_GiaoVu;
GRANT SELECT ON dbo.vw_DangKyChiTiet TO r_GiaoVu;
GRANT SELECT ON dbo.vw_SiSoLop TO r_GiaoVu;
GRANT SELECT ON dbo.vw_LopHoc_DangMo TO r_GiaoVu;
GRANT SELECT ON dbo.vw_CongNoHocVien TO r_GiaoVu;
GRANT SELECT ON dbo.KHOAHOC TO r_GiaoVu;
GRANT SELECT ON dbo.CHUONGTRINH TO r_GiaoVu;
-- Hồ sơ học viên: KHÔNG cấp quyền trên bảng HOCVIEN (sẽ vượt qua lọc chi nhánh của view);
-- đọc qua vw_HocVien_ChiNhanh, ghi qua sp_LuuHocVien (procedure kiểm tra phạm vi chi nhánh)
GRANT EXECUTE ON dbo.sp_LuuHocVien TO r_GiaoVu;
GRANT SELECT ON dbo.KIEMTRA_DAUVAO TO r_GiaoVu;                     -- ghi kết quả qua sp_GhiKetQuaKiemTra (09_xml.sql)
GRANT SELECT ON dbo.fn_GoiYKhoaHoc TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_DangKyHoc TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_ChuyenLop TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_XepLichLop TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_SinhBuoiHoc TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_TimKiemHocVien TO r_GiaoVu;
DENY  SELECT ON dbo.NHANVIEN TO r_GiaoVu;                              -- chỉ xem nhân viên qua view (ẩn lương)
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.PHIEUTHU TO r_GiaoVu;
GO

-- 6.4 r_KeToan: học phí, công nợ, lương
GRANT SELECT ON dbo.PHIEUTHU TO r_KeToan;
GRANT SELECT ON dbo.CT_PHIEUTHU TO r_KeToan;
GRANT SELECT ON dbo.DANGKY (MaDK, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, HanDongHP, TrangThaiHP, TrangThai) TO r_KeToan;  -- mức cột: không xem điểm
GRANT SELECT ON dbo.vw_CongNoHocVien TO r_KeToan;
GRANT SELECT ON dbo.vw_DoanhThuThang TO r_KeToan;
GRANT SELECT ON dbo.vw_HocVien_ChiNhanh TO r_KeToan;
GRANT SELECT ON dbo.NHANVIEN TO r_KeToan;                              -- kế toán được xem lương
GRANT SELECT ON dbo.BANGLUONG TO r_KeToan;
GRANT EXECUTE ON dbo.sp_ThuHocPhi TO r_KeToan;
GRANT EXECUTE ON dbo.sp_ThongKeDoanhThu TO r_KeToan;
GRANT EXECUTE ON dbo.sp_TinhLuongGiaoVien TO r_KeToan;
DENY  UPDATE ON dbo.DANGKY TO r_KeToan;
DENY  UPDATE, DELETE ON dbo.PHIEUTHU TO r_KeToan;                      -- phiếu đã lập không sửa / xoá
GO

-- 6.5 r_GiaoVien: lớp của mình, điểm danh, nhập điểm
GRANT SELECT ON dbo.vw_LichDayGiaoVien TO r_GiaoVien;
GRANT SELECT ON dbo.vw_BangDiem TO r_GiaoVien;
GRANT SELECT ON dbo.fn_LopCuaGiaoVien TO r_GiaoVien;
GRANT SELECT ON dbo.fn_BangDiemLop TO r_GiaoVien;
GRANT EXECUTE ON dbo.sp_DiemDanhBuoi TO r_GiaoVien;
GRANT EXECUTE ON dbo.sp_NhapDiem TO r_GiaoVien;
GRANT EXECUTE ON dbo.sp_CanhBaoChuyenCan TO r_GiaoVien;
DENY  SELECT ON dbo.NHANVIEN TO r_GiaoVien;
DENY  SELECT ON dbo.PHIEUTHU TO r_GiaoVien;
DENY  SELECT ON dbo.vw_CongNoHocVien TO r_GiaoVien;
GO

-- 6.6 r_HocVien: chỉ lịch học và gợi ý khoá học
GRANT SELECT ON dbo.fn_LichHocHocVien TO r_HocVien;
GRANT SELECT ON dbo.fn_GoiYKhoaHoc TO r_HocVien;
GRANT SELECT ON dbo.KHOAHOC TO r_HocVien;
DENY  SELECT ON SCHEMA::dbo TO r_HocVien;                              -- chặn toàn schema…
REVOKE SELECT ON SCHEMA::dbo FROM r_HocVien;                           -- …rồi REVOKE để minh hoạ: REVOKE gỡ cả GRANT lẫn DENY
GO

PRINT N'✓ 08_security.sql: 6 login, 6 role, ma trận quyền, chính sách mật khẩu, procedure đăng nhập / tài khoản.';
GO
