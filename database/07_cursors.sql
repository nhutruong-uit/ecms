/* =====================================================================
   ECMS – 07_cursors.sql : procedure dùng cursor (xử lý tuần tự từng dòng)   (T14)
   Mỗi bài toán có thêm phiên bản set-based (_SetBased) để so sánh tốc độ
   (database/tests/bench_cursor.sql).
   Chạy lại được: CREATE OR ALTER.
   ===================================================================== */
USE ECMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   sp_SinhBuoiHoc – sinh các buổi học của lớp từ lịch cố định
   Duyệt từng ngày từ ngày khai giảng; với mỗi ngày, mở cursor trên các dòng LICHHOC
   trùng thứ của ngày đó (một ngày có thể có 2 ca). Bỏ qua ngày lễ (NGAYLE).
   Dừng khi đủ số buổi của khoá; cập nhật ngày kết thúc lớp.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_SinhBuoiHoc
    @MaLop     VARCHAR(10),
    @SinhLai   BIT = 0,              -- 1: xoá buổi cũ (chưa điểm danh) rồi sinh lại
    @SoBuoiTao INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ngay DATE, @SoBuoi INT, @Thu TINYINT, @MaCa TINYINT, @MaPhong VARCHAR(5), @STT INT = 0;

    SELECT @Ngay = l.NgayKhaiGiang, @SoBuoi = k.SoBuoi
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @MaLop;
    IF @Ngay IS NULL THROW 50080, N'Lớp học không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop) THROW 50081, N'Lớp chưa có lịch học cố định.', 1;
    IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
    BEGIN
        IF @SinhLai = 0 THROW 50082, N'Lớp đã có buổi học. Chọn "sinh lại" để tạo lại.', 1;
        IF EXISTS (SELECT 1 FROM dbo.DIEMDANH WHERE MaLop = @MaLop)
            THROW 50083, N'Lớp đã điểm danh, không thể sinh lại buổi học.', 1;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE dbo.BUOIHOC WHERE MaLop = @MaLop;
        DECLARE @Gioihan DATE = DATEADD(YEAR, 1, @Ngay);     -- chặn vòng lặp vô hạn nếu dữ liệu lịch sai

        WHILE @STT < @SoBuoi AND @Ngay <= @Gioihan
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.NGAYLE WHERE Ngay = @Ngay)
            BEGIN
                SET @Thu = DATEDIFF(DAY, '19000101', @Ngay) % 7 + 2;   -- 2 = thứ Hai … 8 = Chủ nhật

                DECLARE cur_Lich CURSOR LOCAL FAST_FORWARD FOR      -- 1. DECLARE
                    SELECT MaCa, MaPhong FROM dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu ORDER BY MaCa;
                OPEN cur_Lich;                                       -- 2. OPEN
                FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;       -- 3. FETCH
                WHILE @@FETCH_STATUS = 0 AND @STT < @SoBuoi          --    0 = lấy được dòng
                BEGIN
                    SET @STT += 1;
                    INSERT dbo.BUOIHOC (MaLop, STT, NgayHoc, MaCa, MaPhong, NoiDung)
                    VALUES (@MaLop, @STT, @Ngay, @MaCa, @MaPhong,
                            CASE @STT WHEN @SoBuoi / 2 THEN N'Kiểm tra giữa kỳ' WHEN @SoBuoi THEN N'Kiểm tra cuối kỳ'
                                      ELSE CONCAT(N'Unit ', @STT) END);
                    FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;
                END
                CLOSE cur_Lich;                                      -- 4. CLOSE
                DEALLOCATE cur_Lich;                                 -- 5. DEALLOCATE
            END
            SET @Ngay = DATEADD(DAY, 1, @Ngay);
        END

        UPDATE dbo.LOPHOC SET NgayKetThuc = (SELECT MAX(NgayHoc) FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        WHERE MaLop = @MaLop;
        SET @SoBuoiTao = @STT;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_Lich') >= -1 DEALLOCATE cur_Lich;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_TinhLuongGiaoVien – bảng lương tháng: lương cơ bản + số buổi đã dạy × đơn giá
   Cursor duyệt từng giáo viên đang làm việc; ghi (UPSERT) vào BANGLUONG.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TinhLuongGiaoVien
    @Thang CHAR(7)                    -- 'yyyy-MM'
AS
BEGIN
    SET NOCOUNT ON;
    IF @Thang NOT LIKE '[2][0-9][0-9][0-9]-[01][0-9]' THROW 50084, N'Tháng phải có dạng yyyy-MM.', 1;
    DECLARE @Tu DATE = CAST(@Thang + '-01' AS DATE);
    DECLARE @Den DATE = DATEADD(MONTH, 1, @Tu);
    DECLARE @MaGV CHAR(6), @DonGia DECIMAL(10,0), @Luong DECIMAL(12,0), @SoBuoi INT;

    DECLARE cur_GV CURSOR LOCAL STATIC READ_ONLY FOR
        SELECT g.MaGV, g.DonGiaBuoi, n.LuongCoBan
        FROM dbo.GIAOVIEN g JOIN dbo.NHANVIEN n ON n.MaNV = g.MaGV
        WHERE n.TrangThai = 1
        ORDER BY g.MaGV;
    OPEN cur_GV;
    FETCH NEXT FROM cur_GV INTO @MaGV, @DonGia, @Luong;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @SoBuoi = COUNT(*)
        FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
        WHERE l.MaGV = @MaGV AND b.TrangThai = N'Đã dạy' AND b.NgayHoc >= @Tu AND b.NgayHoc < @Den;

        IF EXISTS (SELECT 1 FROM dbo.BANGLUONG WHERE Thang = @Thang AND MaGV = @MaGV)
            UPDATE dbo.BANGLUONG SET SoBuoiDay = @SoBuoi, DonGiaBuoi = @DonGia, LuongCoBan = @Luong, NgayTinh = SYSDATETIME()
            WHERE Thang = @Thang AND MaGV = @MaGV;
        ELSE
            INSERT dbo.BANGLUONG (Thang, MaGV, SoBuoiDay, DonGiaBuoi, LuongCoBan) VALUES (@Thang, @MaGV, @SoBuoi, @DonGia, @Luong);

        FETCH NEXT FROM cur_GV INTO @MaGV, @DonGia, @Luong;
    END
    CLOSE cur_GV;
    DEALLOCATE cur_GV;

    SELECT b.Thang, b.MaGV, n.HoTen, b.SoBuoiDay, b.DonGiaBuoi, b.LuongCoBan, b.TongLuong
    FROM dbo.BANGLUONG b JOIN dbo.NHANVIEN n ON n.MaNV = b.MaGV
    WHERE b.Thang = @Thang ORDER BY b.TongLuong DESC;
END
GO

-- Cùng bài toán, cách set-based: một câu MERGE
CREATE OR ALTER PROCEDURE dbo.sp_TinhLuongGiaoVien_SetBased
    @Thang CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Tu DATE = CAST(@Thang + '-01' AS DATE);
    DECLARE @Den DATE = DATEADD(MONTH, 1, @Tu);
    MERGE dbo.BANGLUONG AS t
    USING (
        SELECT g.MaGV, g.DonGiaBuoi, n.LuongCoBan,
               (SELECT COUNT(*) FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
                WHERE l.MaGV = g.MaGV AND b.TrangThai = N'Đã dạy' AND b.NgayHoc >= @Tu AND b.NgayHoc < @Den) AS SoBuoi
        FROM dbo.GIAOVIEN g JOIN dbo.NHANVIEN n ON n.MaNV = g.MaGV WHERE n.TrangThai = 1
    ) AS s ON t.Thang = @Thang AND t.MaGV = s.MaGV
    WHEN MATCHED THEN UPDATE SET SoBuoiDay = s.SoBuoi, DonGiaBuoi = s.DonGiaBuoi, LuongCoBan = s.LuongCoBan, NgayTinh = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (Thang, MaGV, SoBuoiDay, DonGiaBuoi, LuongCoBan) VALUES (@Thang, s.MaGV, s.SoBuoi, s.DonGiaBuoi, s.LuongCoBan);
END
GO

/* ---------------------------------------------------------------------
   sp_CanhBaoChuyenCan – duyệt từng đăng ký đang học, tính tỷ lệ vắng trên các buổi đã
   điểm danh; vắng > @NguongVang% thì ghi CANHBAO_CHUYENCAN (mỗi đăng ký 1 lần / ngày).
   Mức độ: > 30% Nghiêm trọng, còn lại Nhắc nhở.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_CanhBaoChuyenCan
    @NguongVang     DECIMAL(5,2) = 20,
    @SoBuoiToiThieu INT = 4,           -- chưa đủ số buổi thì chưa đánh giá
    @MaLop          VARCHAR(10) = NULL,
    @SoCanhBao      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaDK INT, @Tong INT, @Vang INT, @TyLe DECIMAL(5,2), @Hom DATE = CAST(GETDATE() AS DATE);
    SET @SoCanhBao = 0;

    DECLARE cur_DK CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaDK FROM dbo.DANGKY
        WHERE TrangThai = N'Đang học' AND (@MaLop IS NULL OR MaLop = @MaLop);
    OPEN cur_DK;
    FETCH NEXT FROM cur_DK INTO @MaDK;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @Tong = COUNT(*), @Vang = SUM(CASE WHEN TrangThai = N'Vắng' THEN 1 ELSE 0 END)
        FROM dbo.DIEMDANH WHERE MaDK = @MaDK AND TrangThai <> N'Có phép';

        IF @Tong >= @SoBuoiToiThieu
        BEGIN
            SET @TyLe = 100.0 * @Vang / @Tong;
            IF @TyLe > @NguongVang AND NOT EXISTS (SELECT 1 FROM dbo.CANHBAO_CHUYENCAN WHERE MaDK = @MaDK AND NgayCanhBao = @Hom)
            BEGIN
                INSERT dbo.CANHBAO_CHUYENCAN (MaDK, NgayCanhBao, SoBuoiDaHoc, SoBuoiVang, TyLeVang, MucDo)
                VALUES (@MaDK, @Hom, @Tong, @Vang, @TyLe, CASE WHEN @TyLe > 30 THEN N'Nghiêm trọng' ELSE N'Nhắc nhở' END);
                SET @SoCanhBao += 1;
            END
        END
        FETCH NEXT FROM cur_DK INTO @MaDK;
    END
    CLOSE cur_DK;
    DEALLOCATE cur_DK;

    SELECT c.MaCB, c.MaDK, d.MaHV, h.HoTen, h.SoDienThoai, d.MaLop, c.SoBuoiDaHoc, c.SoBuoiVang, c.TyLeVang, c.MucDo
    FROM dbo.CANHBAO_CHUYENCAN c JOIN dbo.DANGKY d ON d.MaDK = c.MaDK JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV
    WHERE c.NgayCanhBao = @Hom AND (@MaLop IS NULL OR d.MaLop = @MaLop)
    ORDER BY c.TyLeVang DESC;
END
GO

-- Cùng bài toán, set-based: một câu INSERT … SELECT … GROUP BY
CREATE OR ALTER PROCEDURE dbo.sp_CanhBaoChuyenCan_SetBased
    @NguongVang     DECIMAL(5,2) = 20,
    @SoBuoiToiThieu INT = 4,
    @MaLop          VARCHAR(10) = NULL,
    @SoCanhBao      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hom DATE = CAST(GETDATE() AS DATE);
    INSERT dbo.CANHBAO_CHUYENCAN (MaDK, NgayCanhBao, SoBuoiDaHoc, SoBuoiVang, TyLeVang, MucDo)
    SELECT x.MaDK, @Hom, x.Tong, x.Vang, x.TyLe, CASE WHEN x.TyLe > 30 THEN N'Nghiêm trọng' ELSE N'Nhắc nhở' END
    FROM (
        SELECT dd.MaDK, COUNT(*) AS Tong, SUM(CASE WHEN dd.TrangThai = N'Vắng' THEN 1 ELSE 0 END) AS Vang,
               CAST(100.0 * SUM(CASE WHEN dd.TrangThai = N'Vắng' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS TyLe
        FROM dbo.DIEMDANH dd JOIN dbo.DANGKY d ON d.MaDK = dd.MaDK
        WHERE d.TrangThai = N'Đang học' AND dd.TrangThai <> N'Có phép' AND (@MaLop IS NULL OR d.MaLop = @MaLop)
        GROUP BY dd.MaDK
        HAVING COUNT(*) >= @SoBuoiToiThieu
    ) x
    WHERE x.TyLe > @NguongVang
      AND NOT EXISTS (SELECT 1 FROM dbo.CANHBAO_CHUYENCAN c WHERE c.MaDK = x.MaDK AND c.NgayCanhBao = @Hom);
    SET @SoCanhBao = @@ROWCOUNT;
END
GO

PRINT N'✓ 07_cursors.sql: 3 procedure dùng cursor + 2 phiên bản set-based để so sánh.';
GO
