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
   Dừng khi đủ số buổi của khoá; cập nhật ngày kết thúc lớp. Không đủ số buổi trong giới hạn → báo lỗi.
   Transaction lồng được như 05_procedures.sql (SAVE TRANSACTION, không huỷ transaction của người gọi).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_SinhBuoiHoc
    @MaLop     VARCHAR(10),
    @SinhLai   BIT = 0,              -- 1: xoá buổi cũ (chưa điểm danh) rồi sinh lại
    @SoBuoiTao INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ngay DATE, @SoBuoi INT, @Thu TINYINT, @MaCa TINYINT, @MaPhong VARCHAR(5), @STT INT = 0, @MaCN CHAR(4);
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 SET XACT_ABORT ON;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_SinhBuoiHoc;
    BEGIN TRY
        -- khoá dòng lớp: hai người cùng bấm "sinh buổi học" chạy tuần tự, người sau thấy lớp đã có buổi
        SELECT @Ngay = l.NgayKhaiGiang, @SoBuoi = k.SoBuoi, @MaCN = l.MaCN
        FROM dbo.LOPHOC l WITH (UPDLOCK, HOLDLOCK) JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @MaLop;
        IF @Ngay IS NULL THROW 50080, N'Lớp học không tồn tại.', 1;
        IF dbo.fn_TrongPhamVi(@MaCN) = 0
            THROW 50097, N'Lớp thuộc chi nhánh nằm ngoài phạm vi của tài khoản đang đăng nhập.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop) THROW 50081, N'Lớp chưa có lịch học cố định.', 1;
        IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        BEGIN
            IF @SinhLai = 0 THROW 50082, N'Lớp đã có buổi học. Chọn "sinh lại" để tạo lại.', 1;
            IF EXISTS (SELECT 1 FROM dbo.DIEMDANH WHERE MaLop = @MaLop)
                THROW 50083, N'Lớp đã điểm danh, không thể sinh lại buổi học.', 1;
        END

        DELETE dbo.BUOIHOC WHERE MaLop = @MaLop;
        -- Chặn vòng lặp vô hạn nếu dữ liệu lịch sai. Lịch có ít nhất 1 buổi/tuần nên SoBuoi tuần là đủ,
        -- cộng thêm 8 tuần cho ngày lễ (Tết có thể nghỉ cả tuần). Trước đây giới hạn cứng 1 năm làm khoá
        -- 60 buổi học 1 buổi/tuần chỉ sinh được 52 buổi mà không báo lỗi.
        DECLARE @Gioihan DATE = DATEADD(WEEK, @SoBuoi + 8, @Ngay);

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
        IF @STT < @SoBuoi
        BEGIN
            DECLARE @msg NVARCHAR(200) = CONCAT(N'Chỉ sinh được ', @STT, N'/', @SoBuoi, N' buổi trước ', FORMAT(@Gioihan, 'dd/MM/yyyy'),
                                                N' – kiểm tra lịch cố định và ngày lễ.');
            THROW 50085, @msg, 1;
        END

        UPDATE dbo.LOPHOC SET NgayKetThuc = (SELECT MAX(NgayHoc) FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        WHERE MaLop = @MaLop;
        SET @SoBuoiTao = @STT;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_Lich') >= -1 DEALLOCATE cur_Lich;
        -- chỉ huỷ transaction do mình mở; được gọi trong transaction khác thì quay về savepoint
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_SinhBuoiHoc;
        THROW;
    END CATCH
END
GO

-- Cùng bài toán, cách set-based: sinh lịch ngày bằng bảng số (CTE), kết với LICHHOC theo thứ, loại ngày lễ,
-- đánh số buổi bằng ROW_NUMBER() rồi INSERT … SELECT một lần. Kết quả phải trùng khớp bản cursor
-- (database/tests/bench_cursor.sql đối chiếu bằng EXCEPT).
CREATE OR ALTER PROCEDURE dbo.sp_SinhBuoiHoc_SetBased
    @MaLop     VARCHAR(10),
    @SinhLai   BIT = 0,
    @SoBuoiTao INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Tu DATE, @SoBuoi INT, @MaCN CHAR(4);
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 SET XACT_ABORT ON;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_SinhBuoiHoc_SetBased;
    BEGIN TRY
        SELECT @Tu = l.NgayKhaiGiang, @SoBuoi = k.SoBuoi, @MaCN = l.MaCN
        FROM dbo.LOPHOC l WITH (UPDLOCK, HOLDLOCK) JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @MaLop;
        IF @Tu IS NULL THROW 50080, N'Lớp học không tồn tại.', 1;
        IF dbo.fn_TrongPhamVi(@MaCN) = 0
            THROW 50097, N'Lớp thuộc chi nhánh nằm ngoài phạm vi của tài khoản đang đăng nhập.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop) THROW 50081, N'Lớp chưa có lịch học cố định.', 1;
        IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        BEGIN
            IF @SinhLai = 0 THROW 50082, N'Lớp đã có buổi học. Chọn "sinh lại" để tạo lại.', 1;
            IF EXISTS (SELECT 1 FROM dbo.DIEMDANH WHERE MaLop = @MaLop)
                THROW 50083, N'Lớp đã điểm danh, không thể sinh lại buổi học.', 1;
        END
        DELETE dbo.BUOIHOC WHERE MaLop = @MaLop;

        DECLARE @SoNgay INT = DATEDIFF(DAY, @Tu, DATEADD(WEEK, @SoBuoi + 8, @Tu));
        WITH CS AS (SELECT n FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) v (n)),
        So AS (                                        -- bảng số 0 … 9.999 sinh tại chỗ, không cần bảng phụ
            SELECT a.n + 10 * b.n + 100 * c.n + 1000 * d.n AS n FROM CS a CROSS JOIN CS b CROSS JOIN CS c CROSS JOIN CS d
        ), Ngay AS (
            SELECT DATEADD(DAY, n, @Tu) AS NgayHoc FROM So WHERE n <= @SoNgay
        ), Buoi AS (
            SELECT ng.NgayHoc, lh.MaCa, lh.MaPhong, ROW_NUMBER() OVER (ORDER BY ng.NgayHoc, lh.MaCa) AS STT
            FROM Ngay ng
            JOIN dbo.LICHHOC lh ON lh.MaLop = @MaLop AND lh.Thu = DATEDIFF(DAY, '19000101', ng.NgayHoc) % 7 + 2
            WHERE NOT EXISTS (SELECT 1 FROM dbo.NGAYLE nl WHERE nl.Ngay = ng.NgayHoc)
        )
        INSERT dbo.BUOIHOC (MaLop, STT, NgayHoc, MaCa, MaPhong, NoiDung)
        SELECT @MaLop, STT, NgayHoc, MaCa, MaPhong,
               CASE STT WHEN @SoBuoi / 2 THEN N'Kiểm tra giữa kỳ' WHEN @SoBuoi THEN N'Kiểm tra cuối kỳ' ELSE CONCAT(N'Unit ', STT) END
        FROM Buoi WHERE STT <= @SoBuoi;
        SET @SoBuoiTao = @@ROWCOUNT;
        IF @SoBuoiTao < @SoBuoi
        BEGIN
            DECLARE @msg NVARCHAR(200) = CONCAT(N'Chỉ sinh được ', @SoBuoiTao, N'/', @SoBuoi, N' buổi – kiểm tra lịch cố định và ngày lễ.');
            THROW 50085, @msg, 1;
        END
        UPDATE dbo.LOPHOC SET NgayKetThuc = (SELECT MAX(NgayHoc) FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        WHERE MaLop = @MaLop;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_SinhBuoiHoc_SetBased;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_TinhLuongGiaoVien – bảng lương tháng: lương cơ bản + số buổi đã dạy × đơn giá
   Cursor duyệt từng giáo viên đang làm việc HOẶC có dạy trong tháng (nghỉ giữa tháng vẫn được trả công);
   ghi (UPSERT) vào BANGLUONG trong một transaction (lỗi giữa chừng không để bảng lương nửa vời).
   Buổi được tính cho người đã dạy: BUOIHOC.MaGVDay, chưa ghi thì là giáo viên phụ trách lớp.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TinhLuongGiaoVien
    @Thang CHAR(7)                    -- 'yyyy-MM'
AS
BEGIN
    SET NOCOUNT ON;
    -- 'yyyy-MM' với tháng 01–12 (mẫu LIKE cũ nhận cả '2026-00', '2026-19' rồi lỗi chuyển kiểu 241)
    IF @Thang IS NULL OR LEN(@Thang) <> 7 OR @Thang NOT LIKE '[2][0-9][0-9][0-9]-[01][0-9]' OR TRY_CAST(@Thang + '-01' AS DATE) IS NULL
        THROW 50084, N'Tháng phải có dạng yyyy-MM (tháng 01–12).', 1;
    DECLARE @Tu DATE = CAST(@Thang + '-01' AS DATE);
    DECLARE @Den DATE = DATEADD(MONTH, 1, @Tu);
    DECLARE @MaGV CHAR(6), @DonGia DECIMAL(10,0), @Luong DECIMAL(12,0), @SoBuoi INT;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 SET XACT_ABORT ON;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_TinhLuongGiaoVien;
    BEGIN TRY
        DECLARE cur_GV CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT g.MaGV, g.DonGiaBuoi, n.LuongCoBan
            FROM dbo.GIAOVIEN g JOIN dbo.NHANVIEN n ON n.MaNV = g.MaGV
            WHERE n.TrangThai = 1
               OR EXISTS (SELECT 1 FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
                          WHERE COALESCE(b.MaGVDay, l.MaGV) = g.MaGV AND b.TrangThai = N'Đã dạy' AND b.NgayHoc >= @Tu AND b.NgayHoc < @Den)
            ORDER BY g.MaGV;
        OPEN cur_GV;
        FETCH NEXT FROM cur_GV INTO @MaGV, @DonGia, @Luong;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @SoBuoi = COUNT(*)
            FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
            WHERE COALESCE(b.MaGVDay, l.MaGV) = @MaGV AND b.TrangThai = N'Đã dạy' AND b.NgayHoc >= @Tu AND b.NgayHoc < @Den;

            IF EXISTS (SELECT 1 FROM dbo.BANGLUONG WHERE Thang = @Thang AND MaGV = @MaGV)
                UPDATE dbo.BANGLUONG SET SoBuoiDay = @SoBuoi, DonGiaBuoi = @DonGia, LuongCoBan = @Luong, NgayTinh = SYSDATETIME()
                WHERE Thang = @Thang AND MaGV = @MaGV;
            ELSE
                INSERT dbo.BANGLUONG (Thang, MaGV, SoBuoiDay, DonGiaBuoi, LuongCoBan) VALUES (@Thang, @MaGV, @SoBuoi, @DonGia, @Luong);

            FETCH NEXT FROM cur_GV INTO @MaGV, @DonGia, @Luong;
        END
        CLOSE cur_GV;
        DEALLOCATE cur_GV;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_GV') >= -1 DEALLOCATE cur_GV;
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_TinhLuongGiaoVien;
        THROW;
    END CATCH

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
    IF @Thang IS NULL OR LEN(@Thang) <> 7 OR @Thang NOT LIKE '[2][0-9][0-9][0-9]-[01][0-9]' OR TRY_CAST(@Thang + '-01' AS DATE) IS NULL
        THROW 50084, N'Tháng phải có dạng yyyy-MM (tháng 01–12).', 1;
    DECLARE @Tu DATE = CAST(@Thang + '-01' AS DATE);
    DECLARE @Den DATE = DATEADD(MONTH, 1, @Tu);
    MERGE dbo.BANGLUONG AS t
    USING (
        SELECT g.MaGV, g.DonGiaBuoi, n.LuongCoBan, ISNULL(x.SoBuoi, 0) AS SoBuoi
        FROM dbo.GIAOVIEN g JOIN dbo.NHANVIEN n ON n.MaNV = g.MaGV
        LEFT JOIN (SELECT COALESCE(b.MaGVDay, l.MaGV) AS MaGV, COUNT(*) AS SoBuoi
                   FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop
                   WHERE b.TrangThai = N'Đã dạy' AND b.NgayHoc >= @Tu AND b.NgayHoc < @Den
                   GROUP BY COALESCE(b.MaGVDay, l.MaGV)) x ON x.MaGV = g.MaGV
        WHERE n.TrangThai = 1 OR x.SoBuoi > 0
    ) AS s ON t.Thang = @Thang AND t.MaGV = s.MaGV
    WHEN MATCHED THEN UPDATE SET SoBuoiDay = s.SoBuoi, DonGiaBuoi = s.DonGiaBuoi, LuongCoBan = s.LuongCoBan, NgayTinh = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (Thang, MaGV, SoBuoiDay, DonGiaBuoi, LuongCoBan) VALUES (@Thang, s.MaGV, s.SoBuoi, s.DonGiaBuoi, s.LuongCoBan);
END
GO

/* ---------------------------------------------------------------------
   sp_CanhBaoChuyenCan – duyệt từng đăng ký đang học, tính tỷ lệ vắng trên các buổi đã
   điểm danh; vắng > @NguongVang% thì ghi CANHBAO_CHUYENCAN (mỗi đăng ký 1 lần / ngày).
   Mức độ: > 30% Nghiêm trọng, còn lại Nhắc nhở.
   Chỉ quét các lớp người gọi được thao tác (dbo.fn_DuocThaoTacLop): giáo viên – lớp mình, giáo vụ / quản lý –
   lớp thuộc chi nhánh trong phạm vi.
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
        WHERE TrangThai = N'Đang học' AND (@MaLop IS NULL OR MaLop = @MaLop) AND dbo.fn_DuocThaoTacLop(MaLop) = 1;
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
    WHERE c.NgayCanhBao = @Hom AND (@MaLop IS NULL OR d.MaLop = @MaLop) AND dbo.fn_DuocThaoTacLop(d.MaLop) = 1
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
          AND dbo.fn_DuocThaoTacLop(d.MaLop) = 1
        GROUP BY dd.MaDK
        HAVING COUNT(*) >= @SoBuoiToiThieu
    ) x
    WHERE x.TyLe > @NguongVang
      AND NOT EXISTS (SELECT 1 FROM dbo.CANHBAO_CHUYENCAN c WHERE c.MaDK = x.MaDK AND c.NgayCanhBao = @Hom);
    SET @SoCanhBao = @@ROWCOUNT;
END
GO

PRINT N'✓ 07_cursors.sql: 3 procedure dùng cursor + 3 phiên bản set-based để so sánh.';
GO
