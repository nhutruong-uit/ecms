/* =====================================================================
   So sánh cursor và set-based (T14) + minh hoạ các loại cursor.
   Mỗi lần đo chạy trong transaction rồi ROLLBACK nên không làm thay đổi dữ liệu.
   Kết quả: thời gian trung bình (ms) của @N lần chạy.
   ===================================================================== */
USE ECMS;
SET NOCOUNT ON;
GO
DECLARE @N INT = 20, @i INT, @t0 DATETIME2(7), @ms1 FLOAT, @ms2 FLOAT, @x INT;
DECLARE @KQ TABLE (BaiToan NVARCHAR(100), CursorMs DECIMAL(10,2), SetBasedMs DECIMAL(10,2), NhanhHon DECIMAL(10,1), KetQuaGiongNhau NVARCHAR(10));
DECLARE @C1 INT, @C2 INT;

/* 1. Cảnh báo chuyên cần trên toàn bộ đăng ký đang học */
SELECT @i = 0, @ms1 = 0, @ms2 = 0;
WHILE @i < @N
BEGIN
    BEGIN TRAN; SET @t0 = SYSDATETIME();
    DECLARE @T1 TABLE (a INT, b INT, c CHAR(6), d NVARCHAR(71), e VARCHAR(15), f VARCHAR(10), g INT, h INT, k DECIMAL(5,2), m NVARCHAR(20));
    DELETE @T1;
    INSERT @T1 EXEC dbo.sp_CanhBaoChuyenCan @SoCanhBao = @C1 OUTPUT;
    SET @ms1 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0; ROLLBACK;

    BEGIN TRAN; SET @t0 = SYSDATETIME();
    EXEC dbo.sp_CanhBaoChuyenCan_SetBased @SoCanhBao = @C2 OUTPUT;
    SET @ms2 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0; ROLLBACK;
    SET @i += 1;
END
INSERT @KQ VALUES (N'Cảnh báo chuyên cần (' + CAST(@C1 AS NVARCHAR) + N' cảnh báo)', @ms1 / @N, @ms2 / @N, @ms1 / NULLIF(@ms2, 0), IIF(@C1 = @C2, N'Có', N'Không'));

/* 2. Tính lương giáo viên 12 tháng năm 2025 */
SELECT @i = 0, @ms1 = 0, @ms2 = 0;
DECLARE @Thang CHAR(7), @m INT, @L1 DECIMAL(18,0), @L2 DECIMAL(18,0);
WHILE @i < @N
BEGIN
    BEGIN TRAN; SET @t0 = SYSDATETIME(); SET @m = 1;
    DECLARE @T2 TABLE (a CHAR(7), b CHAR(6), c NVARCHAR(71), d SMALLINT, e DECIMAL(10,0), f DECIMAL(12,0), g DECIMAL(14,0));
    WHILE @m <= 12 BEGIN SET @Thang = CONCAT('2025-', RIGHT('0' + CAST(@m AS VARCHAR), 2)); DELETE @T2; INSERT @T2 EXEC dbo.sp_TinhLuongGiaoVien @Thang; SET @m += 1; END
    SET @ms1 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0;
    SET @L1 = (SELECT SUM(TongLuong) FROM BANGLUONG WHERE Thang LIKE '2025-%'); ROLLBACK;

    BEGIN TRAN; SET @t0 = SYSDATETIME(); SET @m = 1;
    WHILE @m <= 12 BEGIN SET @Thang = CONCAT('2025-', RIGHT('0' + CAST(@m AS VARCHAR), 2)); EXEC dbo.sp_TinhLuongGiaoVien_SetBased @Thang; SET @m += 1; END
    SET @ms2 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0;
    SET @L2 = (SELECT SUM(TongLuong) FROM BANGLUONG WHERE Thang LIKE '2025-%'); ROLLBACK;
    SET @i += 1;
END
INSERT @KQ VALUES (N'Bảng lương 12 tháng 2025 (tổng ' + FORMAT(@L1, 'N0') + N')', @ms1 / @N, @ms2 / @N, @ms1 / NULLIF(@ms2, 0), IIF(@L1 = @L2, N'Có', N'Không'));

/* 3. Sinh buổi học cho một lớp 30 buổi: cursor (sp_SinhBuoiHoc) vs một câu SELECT dùng bảng số */
DECLARE @Lop VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
                            WHERE k.SoBuoi = 30 AND NOT EXISTS (SELECT 1 FROM DIEMDANH d WHERE d.MaLop = l.MaLop) ORDER BY l.MaLop);
DECLARE @Ngay1 DATE, @Ngay2 DATE;
SELECT @i = 0, @ms1 = 0, @ms2 = 0;
WHILE @i < @N
BEGIN
    BEGIN TRAN; SET @t0 = SYSDATETIME();
    EXEC dbo.sp_SinhBuoiHoc @MaLop = @Lop, @SinhLai = 1, @SoBuoiTao = @x OUTPUT;
    SET @ms1 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0;
    SET @Ngay1 = (SELECT MAX(NgayHoc) FROM BUOIHOC WHERE MaLop = @Lop); ROLLBACK;

    SET @t0 = SYSDATETIME();
    WITH So AS (SELECT TOP (400) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects),
    Ngay AS (SELECT DATEADD(DAY, s.n, l.NgayKhaiGiang) AS NgayHoc FROM LOPHOC l CROSS JOIN So s WHERE l.MaLop = @Lop),
    Buoi AS (SELECT n.NgayHoc, lh.MaCa, lh.MaPhong, ROW_NUMBER() OVER (ORDER BY n.NgayHoc, lh.MaCa) AS STT
             FROM Ngay n JOIN LICHHOC lh ON lh.MaLop = @Lop AND lh.Thu = DATEDIFF(DAY, '19000101', n.NgayHoc) % 7 + 2
             WHERE NOT EXISTS (SELECT 1 FROM NGAYLE h WHERE h.Ngay = n.NgayHoc))
    SELECT @Ngay2 = MAX(NgayHoc) FROM Buoi WHERE STT <= 30;
    SET @ms2 += DATEDIFF(MICROSECOND, @t0, SYSDATETIME()) / 1000.0;
    SET @i += 1;
END
INSERT @KQ VALUES (N'Sinh 30 buổi học lớp ' + @Lop, @ms1 / @N, @ms2 / @N, @ms1 / NULLIF(@ms2, 0), IIF(@Ngay1 = @Ngay2, N'Có', N'Không'));

SELECT * FROM @KQ;
GO

/* =====================================================================
   Minh hoạ các loại cursor: sửa / thêm dữ liệu trong khi cursor đang mở
   ===================================================================== */
DROP TABLE IF EXISTS #Demo;
CREATE TABLE #Demo (Id INT PRIMARY KEY, GiaTri INT);
INSERT #Demo VALUES (1, 10), (2, 20), (3, 30);
DECLARE @KQ2 TABLE (LoaiCursor VARCHAR(20), ThayDongSua NVARCHAR(20), ThayDongMoi NVARCHAR(20), Duyet NVARCHAR(100));
DECLARE @Loai VARCHAR(20), @Id INT, @G INT, @Duyet NVARCHAR(100);
DECLARE @Loais TABLE (Loai VARCHAR(20)); INSERT @Loais VALUES ('STATIC'), ('KEYSET'), ('DYNAMIC'), ('FAST_FORWARD');
DECLARE cur_Loai CURSOR LOCAL FAST_FORWARD FOR SELECT Loai FROM @Loais;
OPEN cur_Loai; FETCH NEXT FROM cur_Loai INTO @Loai;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE #Demo SET GiaTri = Id * 10; DELETE #Demo WHERE Id > 3; SET @Duyet = N'';
    IF @Loai = 'STATIC'  DECLARE c CURSOR LOCAL STATIC  FOR SELECT Id, GiaTri FROM #Demo ORDER BY Id;
    IF @Loai = 'KEYSET'  DECLARE c CURSOR LOCAL KEYSET  FOR SELECT Id, GiaTri FROM #Demo ORDER BY Id;
    IF @Loai = 'DYNAMIC' DECLARE c CURSOR LOCAL DYNAMIC FOR SELECT Id, GiaTri FROM #Demo ORDER BY Id;
    IF @Loai = 'FAST_FORWARD' DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Id, GiaTri FROM #Demo ORDER BY Id;
    OPEN c;
    FETCH NEXT FROM c INTO @Id, @G;                       -- đọc dòng 1, sau đó sửa dòng 2 và thêm dòng 4
    SET @Duyet += CONCAT(@Id, ':', @G, ' ');
    UPDATE #Demo SET GiaTri = 999 WHERE Id = 2;
    INSERT #Demo VALUES (4, 40);
    FETCH NEXT FROM c INTO @Id, @G;
    WHILE @@FETCH_STATUS = 0 BEGIN SET @Duyet += CONCAT(@Id, ':', @G, ' '); FETCH NEXT FROM c INTO @Id, @G; END
    CLOSE c; DEALLOCATE c;
    INSERT @KQ2 VALUES (@Loai, IIF(@Duyet LIKE N'%2:999%', N'Có', N'Không'), IIF(@Duyet LIKE N'%4:40%', N'Có', N'Không'), @Duyet);
    FETCH NEXT FROM cur_Loai INTO @Loai;
END
CLOSE cur_Loai; DEALLOCATE cur_Loai;
SELECT * FROM @KQ2;
GO
