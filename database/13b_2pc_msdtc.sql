/* =====================================================================
   ECMS – 13b_2pc_msdtc.sql : CAM KẾT HAI PHA THẬT giữa HAI MÁY, MSDTC làm bộ điều phối (demo, chạy sau 13)
   Mục 9 của 13_distributed.sql: các trạm là CSDL trên CÙNG một instance – SQL Server tự điều phối 2PC nội bộ.
   Ở đây trạm CN02 là SQL Server trên MỘT MÁY KHÁC trong mạng, nên giao tác liên trạm phải qua Microsoft Distributed
   Transaction Coordinator (MSDTC) của hai máy: BEGIN DISTRIBUTED TRANSACTION + linked server.
     - Trạm CN01 = instance chính trên Windows (chạy script này), có ECMS_CN01 và bản ECMS_CN02 do 13 tạo (nguồn chép mảnh)
     - Trạm CN02 = SQL Server trên máy thứ hai (VD Docker trên macOS – database/tram_cn02/docker-compose.yml);
       script tạo CSDL ECMS_CN02 ở đó và chép mảnh LOPHOC / DANGKY của chi nhánh CN02 sang
   Chuẩn bị (xem database/tram_cn02/README.md):
     - máy trạm CN02: container SQL Server mở cổng 1433 (→ 14335), 135 (RPC) và 51000 (MSDTC), tắt bảo mật RPC của MSDTC
     - máy Windows: MSDTC bật Network DTC Access (Inbound, Outbound, No Authentication Required), tường lửa cho msdtc.exe
       và cổng 135 từ máy trạm CN02, file hosts phân giải tên máy chủ của container
   Chạy (PowerShell; sqlcmd đọc biến script từ biến môi trường – "-v" không nhận giá trị có dấu phẩy như "IP,cổng"):
     $env:TRAM_CN02 = "192.168.1.168,14335"; $env:TRAM_CN02_MK = "Ecms@12345"
     sqlcmd -S localhost\MSSQLSERVER01 -E -C -b -I -f 65001 -i database\13b_2pc_msdtc.sql
   Bằng chứng MSDTC điều phối: trong giao tác, mã đơn vị công việc (transaction_uow – GUID do MSDTC cấp) của phiên ở CẢ HAI
   máy là MỘT giá trị (ngoài giao tác phân tán cột này là NULL); Get-DtcTransactionsStatistics trên Windows đếm thêm
   các giao tác đã cam kết / huỷ.
   ===================================================================== */
USE master;
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   1. Linked server tới trạm CN02, tạo ECMS_CN02 ở đó và chép mảnh của chi nhánh CN02
   --------------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'TRAM_CN02') EXEC sp_dropserver N'TRAM_CN02', 'droplogins';
-- MSOLEDBSQL19 mặc định bắt buộc mã hoá và kiểm tra chứng chỉ; container dùng chứng chỉ tự ký nên tin chứng chỉ máy chủ
EXEC sp_addlinkedserver @server = N'TRAM_CN02', @srvproduct = N'', @provider = N'MSOLEDBSQL19', @datasrc = N'$(TRAM_CN02)',
     @provstr = N'Encrypt=Mandatory;TrustServerCertificate=Yes';
EXEC sp_addlinkedsrvlogin @rmtsrvname = N'TRAM_CN02', @useself = N'FALSE', @locallogin = NULL,
     @rmtuser = N'sa', @rmtpassword = N'$(TRAM_CN02_MK)';                         -- mật khẩu chỉ dùng cho máy demo
EXEC sp_serveroption N'TRAM_CN02', N'rpc out', N'true';
EXEC sp_serveroption N'TRAM_CN02', N'remote proc transaction promotion', N'true';
GO
EXEC (N'IF DB_ID(N''ECMS_CN02'') IS NOT NULL
      BEGIN ALTER DATABASE ECMS_CN02 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ECMS_CN02; END
      CREATE DATABASE ECMS_CN02 COLLATE Vietnamese_CI_AS;') AT TRAM_CN02;
EXEC (N'USE ECMS_CN02;
CREATE TABLE dbo.LOPHOC (
    MaLop VARCHAR(10) NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''CN02''),
    TenLop NVARCHAR(100) NOT NULL, MaKH VARCHAR(6) NOT NULL, MaGV CHAR(6) NOT NULL,
    NgayKhaiGiang DATE NOT NULL, NgayKetThuc DATE NULL, SiSoToiDa TINYINT NOT NULL, SiSoHienTai TINYINT NOT NULL,
    TrangThai NVARCHAR(20) NOT NULL, PRIMARY KEY (MaLop, MaCN));
CREATE TABLE dbo.DANGKY (
    MaDK INT NOT NULL, MaCN CHAR(4) NOT NULL CHECK (MaCN = ''CN02''),
    MaHV CHAR(6) NOT NULL, MaLop VARCHAR(10) NOT NULL, NgayDK DATE NOT NULL, HocPhi DECIMAL(12,0) NOT NULL,
    GiamGia DECIMAL(5,2) NOT NULL, ThanhTien DECIMAL(12,0) NOT NULL, TrangThaiHP NVARCHAR(20) NOT NULL,
    DiemGK DECIMAL(4,2) NULL, DiemCK DECIMAL(4,2) NULL, KetQua NVARCHAR(10) NULL, TrangThai NVARCHAR(20) NOT NULL,
    PRIMARY KEY (MaDK, MaCN), FOREIGN KEY (MaLop, MaCN) REFERENCES dbo.LOPHOC (MaLop, MaCN));') AT TRAM_CN02;
GO
-- batch mới: bảng ở linked server được kiểm tra lúc BIÊN DỊCH batch (lỗi 7314 nếu cùng batch với lệnh tạo bảng)
INSERT TRAM_CN02.ECMS_CN02.dbo.LOPHOC (MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai)
SELECT MaLop, MaCN, TenLop, MaKH, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai FROM ECMS_CN02.dbo.LOPHOC;
INSERT TRAM_CN02.ECMS_CN02.dbo.DANGKY (MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai)
SELECT MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, DiemGK, DiemCK, KetQua, TrangThai FROM ECMS_CN02.dbo.DANGKY;
SELECT N'Trạm CN01' AS Tram, @@SERVERNAME AS Instance, (SELECT COUNT(*) FROM ECMS_CN01.dbo.DANGKY) AS DangKy
UNION ALL
SELECT N'Trạm CN02', (SELECT TOP 1 v FROM OPENQUERY(TRAM_CN02, 'SELECT CONCAT(@@SERVERNAME, N'' – '', host_platform) AS v FROM sys.dm_os_host_info')),
       (SELECT COUNT(*) FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY);
GO

/* ---------------------------------------------------------------------
   2. Chuyển lớp CN02 → CN01: đóng đăng ký ở trạm CN02 (máy kia), tạo đăng ký mới ở trạm CN01 (máy này).
      XACT_ABORT ON là bắt buộc khi ghi qua linked server trong giao tác (nếu không: lỗi 7395 nested transaction),
      đồng thời bảo đảm lỗi ở bất kỳ trạm nào cũng huỷ cả giao tác phân tán.
      Kết quả từng kịch bản ghi vào bảng tạm #KQ (giữ qua các batch của cùng phiên).
   --------------------------------------------------------------------- */
USE ECMS_CN01;
DROP TABLE IF EXISTS #Ctx, #KQ;
CREATE TABLE #Ctx (MaDK INT, LopMoi VARCHAR(10), MaDKMoi INT);
CREATE TABLE #KQ (STT INT IDENTITY, KichBan NVARCHAR(60), TramCN02 NVARCHAR(20), TramCN01 NVARCHAR(40),
                  UowCN01 UNIQUEIDENTIFIER, UowCN02 UNIQUEIDENTIFIER, Loi NVARCHAR(300));
-- dọn đăng ký demo còn sót nếu lần chạy trước bị ngắt giữa kịch bản (a) và bước hoàn tác (c)
DELETE dbo.DANGKY WHERE MaDK IN (990101, 990102);
-- đăng ký đang học ở lớp CN02 và một lớp cùng khoá ở CN01 (ưu tiên lớp còn mở) – như mục 9 của 13_distributed.sql
INSERT #Ctx
SELECT TOP 1 d.MaDK, l1.MaLop, 990101
FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY d JOIN TRAM_CN02.ECMS_CN02.dbo.LOPHOC l2 ON l2.MaLop = d.MaLop
JOIN dbo.LOPHOC l1 ON l1.MaKH = l2.MaKH
WHERE d.TrangThai = N'Đang học'
ORDER BY CASE WHEN l1.TrangThai IN (N'Sắp mở', N'Đang học') THEN 0 ELSE 1 END, d.MaDK, l1.MaLop;
GO

-- (a) thành công: MSDTC gửi PREPARE tới cả hai máy, cả hai sẵn sàng rồi mới COMMIT
SET XACT_ABORT ON;
DECLARE @DK INT, @LopMoi VARCHAR(10), @DKMoi INT, @uow1 UNIQUEIDENTIFIER, @uow2 UNIQUEIDENTIFIER;
SELECT @DK = MaDK, @LopMoi = LopMoi, @DKMoi = MaDKMoi FROM #Ctx;
BEGIN DISTRIBUTED TRANSACTION;
UPDATE TRAM_CN02.ECMS_CN02.dbo.DANGKY SET TrangThai = N'Đã chuyển lớp' WHERE MaDK = @DK AND MaCN = 'CN02';
INSERT dbo.DANGKY (MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, TrangThai)
SELECT @DKMoi, 'CN01', MaHV, @LopMoi, '2026-10-15', HocPhi, GiamGia, ThanhTien, TrangThaiHP, N'Đang học'
FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK;
-- mã đơn vị công việc (UOW) MSDTC cấp cho giao tác, đọc ở phiên của mỗi máy – NULL nếu giao tác không qua MSDTC
SELECT @uow1 = t.transaction_uow
FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_current_transaction c ON c.transaction_id = t.transaction_id;
SELECT @uow2 = uow FROM OPENQUERY(TRAM_CN02, 'SELECT t.transaction_uow AS uow FROM sys.dm_tran_active_transactions t
                                              JOIN sys.dm_tran_current_transaction c ON c.transaction_id = t.transaction_id');
COMMIT TRANSACTION;
INSERT #KQ (KichBan, TramCN02, TramCN01, UowCN01, UowCN02)
SELECT N'(a) Chuyển lớp CN02 → CN01 thành công',
       (SELECT TrangThai FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK),
       ISNULL((SELECT TrangThai FROM dbo.DANGKY WHERE MaDK = @DKMoi), N'(không có)'),
       @uow1, @uow2;
GO

-- (b) lỗi ở trạm CN01 (vi phạm CHECK MaCN của mảnh CN01) → MSDTC huỷ CẢ cập nhật đã làm ở trạm CN02.
-- Lỗi trong giao tác phân tán huỷ cả batch (TRY/CATCH không chạy tiếp được) nên kịch bản đứng riêng một batch,
-- sqlcmd bỏ qua lỗi của batch này; kết quả được kiểm tra ở batch sau.
:on error ignore
SET XACT_ABORT ON;
DECLARE @DK INT, @LopMoi VARCHAR(10);
SELECT @DK = MaDK, @LopMoi = LopMoi FROM #Ctx;
BEGIN DISTRIBUTED TRANSACTION;
UPDATE TRAM_CN02.ECMS_CN02.dbo.DANGKY SET TrangThai = N'Bảo lưu' WHERE MaDK = @DK AND MaCN = 'CN02';
INSERT dbo.DANGKY (MaDK, MaCN, MaHV, MaLop, NgayDK, HocPhi, GiamGia, ThanhTien, TrangThaiHP, TrangThai)
VALUES (990102, 'CN02', 'HV0001', @LopMoi, '2026-10-15', 1, 0, 1, N'Chưa đóng', N'Đang học');
COMMIT TRANSACTION;
GO
:on error exit
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
SET XACT_ABORT ON;
DECLARE @DK INT = (SELECT MaDK FROM #Ctx);
INSERT #KQ (KichBan, TramCN02, TramCN01, Loi)
SELECT N'(b) Lỗi ở trạm CN01 → huỷ cả hai trạm',
       (SELECT TrangThai FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK),
       CONCAT((SELECT COUNT(*) FROM dbo.DANGKY WHERE MaDK = 990102), N' dòng mới'),
       N'547 CHECK MaCN của mảnh CN01 → MSDTC huỷ giao tác (xem thông báo lỗi ở trên)';
GO

-- (c) hoàn tác kịch bản (a) – cũng là một giao tác phân tán: hai trạm lại khớp CSDL tập trung
SET XACT_ABORT ON;
DECLARE @DK INT, @DKMoi INT;
SELECT @DK = MaDK, @DKMoi = MaDKMoi FROM #Ctx;
BEGIN DISTRIBUTED TRANSACTION;
DELETE dbo.DANGKY WHERE MaDK = @DKMoi;
UPDATE TRAM_CN02.ECMS_CN02.dbo.DANGKY SET TrangThai = N'Đang học' WHERE MaDK = @DK AND MaCN = 'CN02';
COMMIT TRANSACTION;
INSERT #KQ (KichBan, TramCN02, TramCN01)
SELECT N'(c) Hoàn tác (a)', (SELECT TrangThai FROM TRAM_CN02.ECMS_CN02.dbo.DANGKY WHERE MaDK = @DK),
       CONCAT((SELECT COUNT(*) FROM dbo.DANGKY WHERE MaDK = @DKMoi), N' dòng ', @DKMoi);

SELECT k.KichBan, k.TramCN02, k.TramCN01, k.UowCN01, k.UowCN02,
       CASE WHEN k.UowCN01 IS NULL THEN NULL WHEN k.UowCN01 = k.UowCN02 THEN N'cùng một giao tác MSDTC' ELSE N'khác' END AS DoiChieuUow,
       k.Loi
FROM #KQ k ORDER BY k.STT;
SELECT MaDK AS MaDK_CN02, LopMoi AS LopMoi_CN01 FROM #Ctx;
GO

PRINT N'✓ 13b_2pc_msdtc.sql: cam kết hai pha qua MSDTC giữa hai máy – thành công, huỷ khi một trạm lỗi, hoàn tác.';
GO
