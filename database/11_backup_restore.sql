/* =====================================================================
   ECMS – 11_backup_restore.sql : sao lưu & phục hồi (demo, không nằm trong run_all)   (T17)
   Kịch bản: Full → (thay đổi) → Differential → (thay đổi) → [mốc T0] → SỰ CỐ xoá nhầm → Log backup
             → phục hồi point-in-time (STOPAT = T0) ra CSDL ECMS_KhoiPhuc → đối chiếu → chép dữ liệu bị xoá về ECMS.
   Phục hồi song song (không ghi đè ECMS) để demo chạy lại được nhiều lần và không gián đoạn ứng dụng.
   Thư mục sao lưu: thư mục mặc định của instance (docker-compose đặt MSSQL_BACKUP_DIR=/var/opt/mssql/backup
   = thư mục backups/ của repo). Script có bước XOÁ THẬT dữ liệu rồi khôi phục – chỉ chạy trên môi trường demo.
   ===================================================================== */
USE master;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   0. Chuẩn bị: recovery model FULL (bắt buộc để có log backup và phục hồi theo thời điểm)
   --------------------------------------------------------------------- */
ALTER DATABASE ECMS SET RECOVERY FULL;
SELECT name AS CSDL, recovery_model_desc AS RecoveryModel FROM sys.databases WHERE name = 'ECMS';
GO

/* ---------------------------------------------------------------------
   1. Thủ tục sao lưu dùng chung (Full / Diff / Log), có nén, checksum; dùng cho lịch tự động
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_SaoLuuECMS
    @Loai    VARCHAR(4),             -- FULL | DIFF | LOG
    @TenFile NVARCHAR(200) = NULL,   -- bỏ trống: ECMS_<loai>_<yyyyMMdd_HHmmss>.bak/.trn
    @GhiDe   BIT = 0,
    @File    NVARCHAR(400) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Loai NOT IN ('FULL', 'DIFF', 'LOG') THROW 50110, N'Loại sao lưu phải là FULL, DIFF hoặc LOG.', 1;
    DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
    IF RIGHT(@Dir, 1) NOT IN ('/', '\') SET @Dir += IIF(@Dir LIKE '%/%', '/', '\');
    SET @File = @Dir + ISNULL(@TenFile, CONCAT('ECMS_', LOWER(@Loai), '_', FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss'),
                                               IIF(@Loai = 'LOG', '.trn', '.bak')));
    -- Bản Express không hỗ trợ nén sao lưu
    DECLARE @Nen NVARCHAR(20) = IIF(CAST(SERVERPROPERTY('EngineEdition') AS INT) = 4, N'NO_COMPRESSION', N'COMPRESSION');
    DECLARE @sql NVARCHAR(MAX) =
        CASE @Loai WHEN 'LOG' THEN N'BACKUP LOG ECMS TO DISK = @f' ELSE N'BACKUP DATABASE ECMS TO DISK = @f' END
        + N' WITH ' + IIF(@Loai = 'DIFF', N'DIFFERENTIAL, ', N'') + @Nen + N', CHECKSUM, STATS = 50'
        + IIF(@GhiDe = 1, N', INIT, FORMAT', N', NOINIT')
        + N', NAME = @n, DESCRIPTION = N''ECMS – sao lưu tự động'';';
    DECLARE @Ten NVARCHAR(128) = CONCAT('ECMS ', @Loai, ' ', FORMAT(SYSDATETIME(), 'yyyy-MM-dd HH:mm:ss'));
    EXEC sp_executesql @sql, N'@f NVARCHAR(400), @n NVARCHAR(128)', @f = @File, @n = @Ten;
END
GO

/* ---------------------------------------------------------------------
   2. Kịch bản sự cố và phục hồi point-in-time
   --------------------------------------------------------------------- */
DECLARE @FFull NVARCHAR(400), @FDiff NVARCHAR(400), @FLog NVARCHAR(400), @T0 DATETIME, @sql NVARCHAR(MAX);   -- STOPAT nhận DATETIME
DECLARE @Lop VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM ECMS.dbo.LOPHOC l WHERE l.TrangThai = N'Đang học'
                            AND EXISTS (SELECT 1 FROM ECMS.dbo.DIEMDANH d WHERE d.MaLop = l.MaLop) ORDER BY l.MaLop);
DECLARE @Moc TABLE (Buoc NVARCHAR(100), ThoiDiem DATETIME2(3), SoDiemDanhLop INT, SoPhieuThu INT);

-- 2.1 FULL
EXEC dbo.sp_SaoLuuECMS 'FULL', 'ECMS_demo_full.bak', 1, @FFull OUTPUT;
INSERT @Moc SELECT N'1. Full backup', SYSDATETIME(), (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH WHERE MaLop = @Lop), (SELECT COUNT(*) FROM ECMS.dbo.PHIEUTHU);

-- 2.2 Phát sinh nghiệp vụ sau full: 1 phiếu thu mới
INSERT ECMS.dbo.PHIEUTHU (MaHV, MaNV, HinhThuc, GhiChu)
SELECT TOP 1 MaHV, (SELECT TOP 1 MaNV FROM ECMS.dbo.NHANVIEN WHERE ChucVu = N'Kế toán'), N'Tiền mặt', N'Demo T17 – sau full backup'
FROM ECMS.dbo.HOCVIEN ORDER BY MaHV;
EXEC dbo.sp_SaoLuuECMS 'DIFF', 'ECMS_demo_diff.bak', 1, @FDiff OUTPUT;
INSERT @Moc SELECT N'2. Thêm 1 phiếu thu → Differential backup', SYSDATETIME(), (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH WHERE MaLop = @Lop), (SELECT COUNT(*) FROM ECMS.dbo.PHIEUTHU);

-- 2.3 Thêm 1 phiếu thu nữa, rồi chốt mốc T0 (thời điểm "còn đúng" cuối cùng)
INSERT ECMS.dbo.PHIEUTHU (MaHV, MaNV, HinhThuc, GhiChu)
SELECT TOP 1 MaHV, (SELECT TOP 1 MaNV FROM ECMS.dbo.NHANVIEN WHERE ChucVu = N'Kế toán'), N'Chuyển khoản', N'Demo T17 – sau diff'
FROM ECMS.dbo.HOCVIEN ORDER BY MaHV DESC;
WAITFOR DELAY '00:00:01';
SET @T0 = GETDATE();
INSERT @Moc SELECT N'3. Thêm 1 phiếu thu – MỐC T0 trước sự cố', @T0, (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH WHERE MaLop = @Lop), (SELECT COUNT(*) FROM ECMS.dbo.PHIEUTHU);
WAITFOR DELAY '00:00:01';

-- 2.4 SỰ CỐ: giáo vụ xoá nhầm toàn bộ điểm danh của một lớp
DELETE ECMS.dbo.DIEMDANH WHERE MaLop = @Lop;
INSERT @Moc SELECT N'4. SỰ CỐ: xoá nhầm điểm danh lớp ' + @Lop, SYSDATETIME(), (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH WHERE MaLop = @Lop), (SELECT COUNT(*) FROM ECMS.dbo.PHIEUTHU);

-- 2.5 Sao lưu log ngay sau sự cố (chứa giao dịch từ diff tới hiện tại, gồm cả T0)
EXEC dbo.sp_SaoLuuECMS 'LOG', 'ECMS_demo_log.trn', 1, @FLog OUTPUT;

-- 2.6 Kiểm tra bản sao lưu trước khi phục hồi
RESTORE VERIFYONLY FROM DISK = @FFull WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = @FDiff WITH CHECKSUM;
RESTORE VERIFYONLY FROM DISK = @FLog WITH CHECKSUM;

-- 2.7 Phục hồi chuỗi Full → Diff → Log (STOPAT T0) ra CSDL mới ECMS_KhoiPhuc
IF DB_ID('ECMS_KhoiPhuc') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX('ECMS_KhoiPhuc', 'Status') = 'ONLINE'      -- lần chạy trước có thể dừng ở trạng thái RESTORING
        ALTER DATABASE ECMS_KhoiPhuc SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ECMS_KhoiPhuc;
END
DECLARE @DataDir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @LogDir  NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260));
DECLARE @DataName SYSNAME = (SELECT name FROM ECMS.sys.database_files WHERE type = 0);
DECLARE @LogName  SYSNAME = (SELECT name FROM ECMS.sys.database_files WHERE type = 1);
DECLARE @Move NVARCHAR(MAX) = N'MOVE @dn TO @dd, MOVE @ln TO @ld';
DECLARE @dd NVARCHAR(400) = @DataDir + 'ECMS_KhoiPhuc.mdf', @ld NVARCHAR(400) = @LogDir + 'ECMS_KhoiPhuc_log.ldf';
DECLARE @BatDauKhoiPhuc DATETIME2(3) = SYSDATETIME();              -- đo RTO: thời gian từ lúc bắt đầu phục hồi tới khi dùng được
SET @sql = N'RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = @f WITH ' + @Move + N', NORECOVERY, REPLACE;';
EXEC sp_executesql @sql, N'@f NVARCHAR(400), @dn SYSNAME, @dd NVARCHAR(400), @ln SYSNAME, @ld NVARCHAR(400)',
     @f = @FFull, @dn = @DataName, @dd = @dd, @ln = @LogName, @ld = @ld;
RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = @FDiff WITH NORECOVERY;
RESTORE LOG ECMS_KhoiPhuc FROM DISK = @FLog WITH STOPAT = @T0, RECOVERY;
DECLARE @RTO INT = DATEDIFF(MILLISECOND, @BatDauKhoiPhuc, SYSDATETIME());
-- Bản phục hồi phải toàn vẹn về vật lý và logic trước khi lấy dữ liệu ra dùng: DBCC CHECKDB
DBCC CHECKDB (ECMS_KhoiPhuc) WITH NO_INFOMSGS, ALL_ERRORMSGS;
SELECT N'RTO đo được (Full + Diff + Log STOPAT)' AS ChiSo, @RTO AS Mili_giay,
       N'DBCC CHECKDB không báo lỗi' AS KiemTraToanVen;

-- 2.8 Đối chiếu: CSDL phục hồi có đủ điểm danh và có cả 2 phiếu thu tạo sau full backup
SET @sql = N'SELECT @n1 = (SELECT COUNT(*) FROM ECMS_KhoiPhuc.dbo.DIEMDANH WHERE MaLop = @l),
                    @n2 = (SELECT COUNT(*) FROM ECMS_KhoiPhuc.dbo.PHIEUTHU);';
DECLARE @n1 INT, @n2 INT;
EXEC sp_executesql @sql, N'@l VARCHAR(10), @n1 INT OUTPUT, @n2 INT OUTPUT', @l = @Lop, @n1 = @n1 OUTPUT, @n2 = @n2 OUTPUT;
INSERT @Moc VALUES (N'5. ECMS_KhoiPhuc sau RESTORE … STOPAT = T0', @T0, @n1, @n2);

-- 2.9 Khắc phục: chép lại các dòng bị xoá từ bản phục hồi về CSDL đang chạy
SET @sql = N'INSERT ECMS.dbo.DIEMDANH (MaDK, MaLop, STT, TrangThai, GhiChu)
             SELECT k.MaDK, k.MaLop, k.STT, k.TrangThai, k.GhiChu FROM ECMS_KhoiPhuc.dbo.DIEMDANH k
             WHERE k.MaLop = @l AND NOT EXISTS (SELECT 1 FROM ECMS.dbo.DIEMDANH d
                                                WHERE d.MaDK = k.MaDK AND d.MaLop = k.MaLop AND d.STT = k.STT);';
EXEC sp_executesql @sql, N'@l VARCHAR(10)', @l = @Lop;
INSERT @Moc SELECT N'6. ECMS sau khi chép lại dữ liệu bị xoá', SYSDATETIME(), (SELECT COUNT(*) FROM ECMS.dbo.DIEMDANH WHERE MaLop = @Lop), (SELECT COUNT(*) FROM ECMS.dbo.PHIEUTHU);

SELECT Buoc, ThoiDiem, SoDiemDanhLop, SoPhieuThu FROM @Moc ORDER BY Buoc;
-- Dọn dữ liệu demo: xoá 2 phiếu thu thử nghiệm (không có chi tiết) để dữ liệu mẫu như cũ
DELETE ECMS.dbo.PHIEUTHU WHERE GhiChu LIKE N'Demo T17%';
GO

/* ---------------------------------------------------------------------
   3. Xem thông tin bản sao lưu
   --------------------------------------------------------------------- */
DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
IF RIGHT(@Dir, 1) NOT IN ('/', '\') SET @Dir += IIF(@Dir LIKE '%/%', '/', '\');
DECLARE @f NVARCHAR(400) = @Dir + 'ECMS_demo_full.bak';
RESTORE HEADERONLY FROM DISK = @f;        -- loại bản sao lưu, LSN, thời điểm, kích thước, có nén không
RESTORE FILELISTONLY FROM DISK = @f;      -- các file dữ liệu / log bên trong (dùng cho WITH MOVE)

-- Lịch sử sao lưu lưu trong msdb: so sánh kích thước trước / sau nén
SELECT TOP 6 bs.database_name, CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' END AS Loai,
       bs.backup_start_date, bs.backup_finish_date,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS KichThuocMB,
       CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS SauNenMB,
       CAST(100 - 100.0 * bs.compressed_backup_size / NULLIF(bs.backup_size, 0) AS DECIMAL(5,1)) AS TietKiemPhanTram,
       bmf.physical_device_name
FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'ECMS' ORDER BY bs.backup_finish_date DESC;
GO

/* ---------------------------------------------------------------------
   4. Lịch sao lưu tự động bằng SQL Server Agent (bản Developer/Standard; Docker: MSSQL_AGENT_ENABLED=true)
      Full: Chủ nhật 01:00 · Diff: 01:00 thứ Hai – thứ Bảy · Log: mỗi 15 phút.
      Job được tạo ở trạng thái TẮT (@enabled = 0) để máy demo không sinh file sao lưu liên tục; chạy thử job Log
      MỘT lần bằng sp_start_job rồi xem kết quả trong lịch sử job. Bật lịch thật: sp_update_job @enabled = 1.
      Bản Express không có Agent: dùng Task Scheduler / cron gọi scripts/backup.sh.
   --------------------------------------------------------------------- */
IF (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = N'Agent XPs') = 1
BEGIN
    DECLARE @Jobs TABLE (Ten SYSNAME, Loai VARCHAR(4), FreqType INT, FreqInterval INT, SubdayType INT, SubdayInterval INT);
    INSERT @Jobs VALUES (N'ECMS – Full hằng tuần', 'FULL', 8, 1, 1, 0),        -- hằng tuần, Chủ nhật, 1 lần/ngày
                        (N'ECMS – Diff hằng ngày', 'DIFF', 8, 126, 1, 0),      -- 126 = T2 … T7 (2+4+8+16+32+64)
                        (N'ECMS – Log 15 phút',    'LOG',  4, 1, 4, 15);       -- hằng ngày, mỗi 15 phút
    DECLARE @Ten SYSNAME, @L VARCHAR(4), @ft INT, @fi INT, @st INT, @si INT, @cmd NVARCHAR(200);
    DECLARE cj CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @Jobs;
    OPEN cj; FETCH NEXT FROM cj INTO @Ten, @L, @ft, @fi, @st, @si;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @Ten) EXEC msdb.dbo.sp_delete_job @job_name = @Ten;
        SET @cmd = CONCAT(N'EXEC master.dbo.sp_SaoLuuECMS ''', @L, N''';');
        EXEC msdb.dbo.sp_add_job @job_name = @Ten, @enabled = 0, @description = N'ECMS – lịch sao lưu (T17)';
        EXEC msdb.dbo.sp_add_jobstep @job_name = @Ten, @step_name = @L, @subsystem = N'TSQL', @database_name = N'master', @command = @cmd;
        EXEC msdb.dbo.sp_add_jobschedule @job_name = @Ten, @name = @Ten, @freq_type = @ft, @freq_interval = @fi,
             @freq_recurrence_factor = 1, @freq_subday_type = @st, @freq_subday_interval = @si, @active_start_time = 10000;
        EXEC msdb.dbo.sp_add_jobserver @job_name = @Ten;
        FETCH NEXT FROM cj INTO @Ten, @L, @ft, @fi, @st, @si;
    END
    CLOSE cj; DEALLOCATE cj;

    EXEC msdb.dbo.sp_start_job @job_name = N'ECMS – Log 15 phút';               -- chạy thử 1 lần
    DECLARE @cho INT = 0;
    WHILE @cho < 30 AND NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobhistory h JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
                                    WHERE j.name = N'ECMS – Log 15 phút' AND h.step_id = 0)
    BEGIN WAITFOR DELAY '00:00:01'; SET @cho += 1; END
    SELECT j.name AS Job, j.enabled AS DangBat, s.name AS Lich,
           (SELECT TOP 1 CASE h.run_status WHEN 1 THEN N'Thành công' WHEN 0 THEN N'Thất bại' ELSE N'Khác' END
            FROM msdb.dbo.sysjobhistory h WHERE h.job_id = j.job_id AND h.step_id = 0 ORDER BY h.instance_id DESC) AS LanChayThu
    FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
    WHERE j.name LIKE N'ECMS – %' ORDER BY j.name;
END
ELSE
    PRINT N'SQL Server Agent chưa bật (bản Express hoặc Docker thiếu MSSQL_AGENT_ENABLED) – bỏ qua phần lập lịch.';
GO

/* ---------------------------------------------------------------------
   5. Sao lưu có mã hoá (AES-256): bản .bak bị lấy cắp cũng không phục hồi được nếu không có certificate.
      Master key + certificate nằm trong master; PHẢI sao lưu certificate kèm khoá riêng ra file riêng –
      mất certificate = không phục hồi được bản sao lưu. Mật khẩu dưới đây chỉ dùng cho môi trường demo.
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM master.sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Ecms@MasterKey2026';
IF NOT EXISTS (SELECT 1 FROM master.sys.certificates WHERE name = N'ECMS_BackupCert')
    CREATE CERTIFICATE ECMS_BackupCert WITH SUBJECT = 'ECMS backup encryption', EXPIRY_DATE = '2036-12-31';
GO
DECLARE @Dir NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(260));
IF RIGHT(@Dir, 1) NOT IN ('/', '\') SET @Dir += IIF(@Dir LIKE '%/%', '/', '\');
DECLARE @Hau NVARCHAR(20) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss');   -- BACKUP CERTIFICATE không ghi đè file có sẵn
DECLARE @cer NVARCHAR(400) = @Dir + 'ECMS_BackupCert_' + @Hau + '.cer', @pvk NVARCHAR(400) = @Dir + 'ECMS_BackupCert_' + @Hau + '.pvk';
DECLARE @bak NVARCHAR(400) = @Dir + 'ECMS_encrypted.bak', @sql NVARCHAR(MAX);
SET @sql = N'BACKUP CERTIFICATE ECMS_BackupCert TO FILE = {CER} WITH PRIVATE KEY (FILE = {PVK}, ENCRYPTION BY PASSWORD = ''Ecms@CertKey2026'');';
SET @sql = REPLACE(REPLACE(@sql, N'{CER}', QUOTENAME(@cer, '''')), N'{PVK}', QUOTENAME(@pvk, ''''));   -- tên file phải là hằng
EXEC (@sql);
BACKUP DATABASE ECMS TO DISK = @bak
    WITH COMPRESSION, ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = ECMS_BackupCert), INIT, FORMAT, CHECKSUM,
         NAME = N'ECMS FULL – mã hoá AES_256';
RESTORE VERIFYONLY FROM DISK = @bak WITH CHECKSUM;
SELECT TOP 1 bs.name, bs.key_algorithm AS ThuatToan, bs.encryptor_type AS LoaiKhoa,
       CONVERT(VARCHAR(20), bs.encryptor_thumbprint, 1) AS VanTayCertificate,
       CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS KichThuocMB
FROM msdb.dbo.backupset bs WHERE bs.database_name = 'ECMS' ORDER BY bs.backup_finish_date DESC;
GO

PRINT N'✓ 11_backup_restore.sql: Full → Diff → Log, phục hồi point-in-time + DBCC CHECKDB, lịch Agent, sao lưu mã hoá.';
GO
