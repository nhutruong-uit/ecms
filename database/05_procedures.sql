/* =====================================================================
   ECMS – 05_procedures.sql : stored procedure + transaction           (T11)
   Ứng dụng web chỉ gọi procedure để ghi dữ liệu (T15: r_App chỉ có EXECUTE).

   Quy ước lỗi: THROW 500xx với thông báo tiếng Việt, ứng dụng hiển thị nguyên văn.
     5000x ghi danh · 5001x thu học phí · 5002x xếp lịch · 5003x điểm danh
     5004x nhập điểm · 5005x chuyển lớp · 5006x thống kê / tìm kiếm
   Mẫu transaction lồng được: nếu đã có transaction bên ngoài thì dùng SAVE TRANSACTION,
   khi lỗi chỉ rollback về savepoint (không huỷ transaction của người gọi).
   Chạy lại được: CREATE OR ALTER.
   ===================================================================== */
USE ECMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   sp_DangKyHoc – ghi danh học viên vào lớp
   Kiểm tra: học viên tồn tại, lớp đang mở, chưa đăng ký trùng, lớp còn chỗ,
   đủ điều kiện khoá tiên quyết (đã Đạt khoá tiên quyết HOẶC test đầu vào đủ điểm).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_DangKyHoc
    @MaHV    CHAR(6),
    @MaLop   VARCHAR(10),
    @GiamGia DECIMAL(5,2) = 0,
    @MaDK    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_DangKyHoc;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaHV = @MaHV AND TrangThai = 1)
            THROW 50001, N'Học viên không tồn tại hoặc đã ngừng học.', 1;

        DECLARE @MaKH VARCHAR(6), @TrangThaiLop NVARCHAR(20), @ToiDa TINYINT, @HienTai TINYINT;
        -- UPDLOCK + HOLDLOCK: khoá dòng lớp tới hết transaction, hai giáo vụ ghi danh cùng lúc
        -- vào chỗ cuối cùng sẽ phải chờ nhau thay vì cùng thấy "còn chỗ"
        SELECT @MaKH = MaKH, @TrangThaiLop = TrangThai, @ToiDa = SiSoToiDa, @HienTai = SiSoHienTai
        FROM dbo.LOPHOC WITH (UPDLOCK, HOLDLOCK) WHERE MaLop = @MaLop;

        IF @MaKH IS NULL
            THROW 50002, N'Lớp học không tồn tại.', 1;
        IF @TrangThaiLop NOT IN (N'Sắp mở', N'Đang học')
            THROW 50002, N'Lớp đã kết thúc hoặc đã huỷ, không nhận ghi danh.', 1;
        IF EXISTS (SELECT 1 FROM dbo.DANGKY WHERE MaHV = @MaHV AND MaLop = @MaLop)
            THROW 50003, N'Học viên đã đăng ký lớp này.', 1;
        IF @HienTai >= @ToiDa
            THROW 50004, N'Lớp đã đủ sĩ số.', 1;
        IF @GiamGia NOT BETWEEN 0 AND 50
            THROW 50006, N'Giảm giá phải từ 0 đến 50%.', 1;

        DECLARE @TienQuyet VARCHAR(6), @DiemCan DECIMAL(3,1);
        SELECT @TienQuyet = MaKHTienQuyet, @DiemCan = DiemDauVaoTu FROM dbo.KHOAHOC WHERE MaKH = @MaKH;
        IF @TienQuyet IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.DANGKY d JOIN dbo.LOPHOC l ON l.MaLop = d.MaLop
                           WHERE d.MaHV = @MaHV AND l.MaKH = @TienQuyet AND d.KetQua = N'Đạt')
           AND NOT EXISTS (SELECT 1 FROM dbo.KIEMTRA_DAUVAO WHERE MaHV = @MaHV AND DiemTong >= @DiemCan)
        BEGIN
            DECLARE @msg NVARCHAR(300) = CONCAT(N'Chưa đủ điều kiện: cần Đạt khoá ', @TienQuyet,
                N' hoặc điểm kiểm tra đầu vào từ ', @DiemCan, N' trở lên.');
            THROW 50005, @msg, 1;
        END

        INSERT dbo.DANGKY (MaHV, MaLop, HocPhi, GiamGia)
        SELECT @MaHV, @MaLop, HocPhi, @GiamGia FROM dbo.KHOAHOC WHERE MaKH = @MaKH;
        SET @MaDK = SCOPE_IDENTITY();      -- sĩ số do trigger trg_DangKy_SiSo cập nhật (T13)

        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_DangKyHoc;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_ThuHocPhi – lập phiếu thu (master) kèm nhiều dòng chi tiết (detail)
   @ChiTiet: JSON [{"MaDK": 12, "SoTien": 3500000}, {"MaDK": 15}]  (thiếu SoTien = thu hết phần còn nợ)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ThuHocPhi
    @MaHV     CHAR(6),
    @MaNV     CHAR(6),
    @HinhThuc NVARCHAR(20) = N'Tiền mặt',
    @ChiTiet  NVARCHAR(MAX),
    @GhiChu   NVARCHAR(200) = NULL,
    @MaPT     INT OUTPUT,
    @TongTien DECIMAL(12,0) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_ThuHocPhi;
    BEGIN TRY
        IF ISJSON(@ChiTiet) <> 1
            THROW 50010, N'Danh sách chi tiết phiếu thu không hợp lệ.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE MaNV = @MaNV AND ChucVu IN (N'Kế toán', N'Quản lý'))
            THROW 50011, N'Chỉ kế toán hoặc quản lý được lập phiếu thu.', 1;

        DECLARE @CT TABLE (MaDK INT PRIMARY KEY, SoTien DECIMAL(12,0) NULL);
        INSERT @CT (MaDK, SoTien)
        SELECT MaDK, MAX(SoTien) FROM OPENJSON(@ChiTiet) WITH (MaDK INT '$.MaDK', SoTien DECIMAL(12,0) '$.SoTien')
        GROUP BY MaDK;

        IF NOT EXISTS (SELECT 1 FROM @CT)
            THROW 50010, N'Phiếu thu phải có ít nhất một dòng.', 1;
        IF EXISTS (SELECT 1 FROM @CT c LEFT JOIN dbo.DANGKY d ON d.MaDK = c.MaDK
                   WHERE d.MaDK IS NULL OR d.MaHV <> @MaHV OR d.TrangThai IN (N'Huỷ', N'Đã chuyển lớp'))
            THROW 50012, N'Có đăng ký không thuộc học viên này hoặc đã huỷ / chuyển lớp.', 1;

        -- Thu hết phần còn nợ khi không ghi số tiền
        UPDATE c SET SoTien = d.ThanhTien - dbo.fn_SoTienDaDong(d.MaDK)
        FROM @CT c JOIN dbo.DANGKY d ON d.MaDK = c.MaDK WHERE c.SoTien IS NULL;

        IF EXISTS (SELECT 1 FROM @CT WHERE SoTien <= 0)
            THROW 50013, N'Số tiền thu phải lớn hơn 0 (đăng ký đã đóng đủ?).', 1;
        IF EXISTS (SELECT 1 FROM @CT c JOIN dbo.DANGKY d ON d.MaDK = c.MaDK
                   WHERE c.SoTien > d.ThanhTien - dbo.fn_SoTienDaDong(d.MaDK))
            THROW 50014, N'Số tiền thu vượt quá số tiền còn nợ của đăng ký.', 1;

        INSERT dbo.PHIEUTHU (MaHV, MaNV, HinhThuc, GhiChu) VALUES (@MaHV, @MaNV, @HinhThuc, @GhiChu);
        SET @MaPT = SCOPE_IDENTITY();
        INSERT dbo.CT_PHIEUTHU (MaPT, MaDK, SoTien) SELECT @MaPT, MaDK, SoTien FROM @CT;
        -- TongTien của phiếu và TrangThaiHP của đăng ký do trigger trg_CTPhieuThu_TongTien cập nhật (T13)
        SELECT @TongTien = SUM(SoTien) FROM @CT;

        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_ThuHocPhi;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_XepLichLop – thêm một buổi cố định trong tuần (thứ, ca, phòng) cho lớp
   Kiểm tra trùng phòng và trùng giáo viên với các lớp có thời gian học giao nhau.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_XepLichLop
    @MaLop   VARCHAR(10),
    @Thu     TINYINT,
    @MaCa    TINYINT,
    @MaPhong VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaCN CHAR(4), @MaGV CHAR(6), @Tu DATE, @Den DATE, @SoBuoi INT, @msg NVARCHAR(300);
    SELECT @MaCN = l.MaCN, @MaGV = l.MaGV, @Tu = l.NgayKhaiGiang, @SoBuoi = k.SoBuoi,
           -- lớp chưa sinh buổi học: ước lượng ngày kết thúc theo số buổi (tối thiểu 1 buổi/tuần)
           @Den = ISNULL(l.NgayKetThuc, DATEADD(WEEK, k.SoBuoi, l.NgayKhaiGiang))
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @MaLop;

    IF @MaCN IS NULL THROW 50020, N'Lớp học không tồn tại.', 1;
    IF @Thu NOT BETWEEN 2 AND 8 THROW 50021, N'Thứ phải từ 2 (thứ Hai) đến 8 (Chủ nhật).', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.CAHOC WHERE MaCa = @MaCa) THROW 50021, N'Ca học không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.PHONGHOC WHERE MaCN = @MaCN AND MaPhong = @MaPhong)
        THROW 50022, N'Phòng không thuộc chi nhánh của lớp.', 1;
    IF EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu AND MaCa = @MaCa)
        THROW 50023, N'Lớp đã có lịch vào thứ và ca này.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PHONGHOC p JOIN dbo.LOPHOC l ON l.MaLop = @MaLop
               WHERE p.MaCN = @MaCN AND p.MaPhong = @MaPhong AND p.SucChua < l.SiSoToiDa)
        THROW 50024, N'Sức chứa phòng nhỏ hơn sĩ số tối đa của lớp.', 1;

    DECLARE @LopTrung VARCHAR(10);
    SELECT TOP 1 @LopTrung = lh.MaLop
    FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop
    WHERE lh.MaCN = @MaCN AND lh.MaPhong = @MaPhong AND lh.Thu = @Thu AND lh.MaCa = @MaCa
      AND l.TrangThai <> N'Huỷ' AND l.MaLop <> @MaLop
      AND l.NgayKhaiGiang <= @Den AND ISNULL(l.NgayKetThuc, '9999-12-31') >= @Tu;
    IF @LopTrung IS NOT NULL
    BEGIN
        SET @msg = CONCAT(N'Trùng phòng ', @MaPhong, N' với lớp ', @LopTrung, N'.');
        THROW 50025, @msg, 1;
    END

    SELECT TOP 1 @LopTrung = lh.MaLop
    FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop
    WHERE l.MaGV = @MaGV AND lh.Thu = @Thu AND lh.MaCa = @MaCa
      AND l.TrangThai <> N'Huỷ' AND l.MaLop <> @MaLop
      AND l.NgayKhaiGiang <= @Den AND ISNULL(l.NgayKetThuc, '9999-12-31') >= @Tu;
    IF @LopTrung IS NOT NULL
    BEGIN
        SET @msg = CONCAT(N'Giáo viên đã dạy lớp ', @LopTrung, N' vào thứ và ca này.');
        THROW 50026, @msg, 1;
    END

    INSERT dbo.LICHHOC (MaLop, Thu, MaCa, MaCN, MaPhong) VALUES (@MaLop, @Thu, @MaCa, @MaCN, @MaPhong);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaLichLop
    @MaLop VARCHAR(10), @Thu TINYINT, @MaCa TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop)
        THROW 50027, N'Lớp đã sinh buổi học, không thể sửa lịch cố định.', 1;
    DELETE dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu AND MaCa = @MaCa;
END
GO

/* ---------------------------------------------------------------------
   sp_DiemDanhBuoi – điểm danh cả lớp cho một buổi trong MỘT lần lưu
   @DanhSach: JSON [{"MaDK": 1, "TrangThai": "Vắng", "GhiChu": "..."}, ...]
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_DiemDanhBuoi
    @MaLop    VARCHAR(10),
    @STT      TINYINT,
    @DanhSach NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_DiemDanhBuoi;
    BEGIN TRY
        DECLARE @Ngay DATE = (SELECT NgayHoc FROM dbo.BUOIHOC WHERE MaLop = @MaLop AND STT = @STT);
        IF @Ngay IS NULL THROW 50030, N'Buổi học không tồn tại.', 1;
        IF @Ngay > CAST(GETDATE() AS DATE) THROW 50031, N'Chưa tới ngày học, không thể điểm danh.', 1;
        IF ISJSON(@DanhSach) <> 1 THROW 50032, N'Danh sách điểm danh không hợp lệ.', 1;

        DECLARE @DS TABLE (MaDK INT PRIMARY KEY, TrangThai NVARCHAR(10), GhiChu NVARCHAR(200));
        INSERT @DS SELECT MaDK, TrangThai, GhiChu
        FROM OPENJSON(@DanhSach) WITH (MaDK INT, TrangThai NVARCHAR(10), GhiChu NVARCHAR(200));

        IF EXISTS (SELECT 1 FROM @DS s LEFT JOIN dbo.DANGKY d ON d.MaDK = s.MaDK AND d.MaLop = @MaLop WHERE d.MaDK IS NULL)
            THROW 50033, N'Có học viên không thuộc lớp này.', 1;
        IF EXISTS (SELECT 1 FROM @DS WHERE TrangThai NOT IN (N'Có mặt', N'Vắng', N'Muộn', N'Có phép') OR TrangThai IS NULL)
            THROW 50034, N'Trạng thái điểm danh chỉ được là Có mặt, Vắng, Muộn, Có phép.', 1;

        MERGE dbo.DIEMDANH AS t
        USING (SELECT MaDK, @MaLop AS MaLop, @STT AS STT, TrangThai, GhiChu FROM @DS) AS s
           ON t.MaDK = s.MaDK AND t.MaLop = s.MaLop AND t.STT = s.STT
        WHEN MATCHED THEN UPDATE SET TrangThai = s.TrangThai, GhiChu = s.GhiChu
        WHEN NOT MATCHED THEN INSERT (MaDK, MaLop, STT, TrangThai, GhiChu)
                              VALUES (s.MaDK, s.MaLop, s.STT, s.TrangThai, s.GhiChu);

        UPDATE dbo.BUOIHOC SET TrangThai = N'Đã dạy' WHERE MaLop = @MaLop AND STT = @STT;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_DiemDanhBuoi;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_NhapDiem – nhập điểm giữa kỳ / cuối kỳ cho nhiều học viên của lớp
   @DanhSach: JSON [{"MaDK": 1, "DiemGK": 7.5, "DiemCK": 8}, ...]  (bỏ trống = giữ nguyên)
   Kết quả Đạt / Không đạt do trigger trg_DangKy_KetQua tính (T13).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_NhapDiem
    @MaLop    VARCHAR(10),
    @DanhSach NVARCHAR(MAX),
    @SoDong   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_NhapDiem;
    BEGIN TRY
        IF ISJSON(@DanhSach) <> 1 THROW 50040, N'Danh sách điểm không hợp lệ.', 1;
        DECLARE @DS TABLE (MaDK INT PRIMARY KEY, DiemGK DECIMAL(4,2), DiemCK DECIMAL(4,2));
        INSERT @DS SELECT MaDK, DiemGK, DiemCK
        FROM OPENJSON(@DanhSach) WITH (MaDK INT, DiemGK DECIMAL(4,2), DiemCK DECIMAL(4,2));

        IF EXISTS (SELECT 1 FROM @DS s LEFT JOIN dbo.DANGKY d ON d.MaDK = s.MaDK AND d.MaLop = @MaLop
                   WHERE d.MaDK IS NULL OR d.TrangThai NOT IN (N'Đang học', N'Hoàn thành'))
            THROW 50041, N'Có học viên không thuộc lớp hoặc không còn học.', 1;
        IF EXISTS (SELECT 1 FROM @DS WHERE DiemGK NOT BETWEEN 0 AND 10 OR DiemCK NOT BETWEEN 0 AND 10)
            THROW 50042, N'Điểm phải nằm trong khoảng 0 – 10.', 1;

        UPDATE d SET DiemGK = ISNULL(s.DiemGK, d.DiemGK), DiemCK = ISNULL(s.DiemCK, d.DiemCK)
        FROM dbo.DANGKY d JOIN @DS s ON s.MaDK = d.MaDK;
        SET @SoDong = @@ROWCOUNT;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_NhapDiem;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_ChuyenLop – chuyển học viên sang lớp khác CÙNG khoá học (transaction nhiều bước):
   1) đánh dấu đăng ký cũ "Đã chuyển lớp"  2) tạo đăng ký mới giữ nguyên học phí, giảm giá
   3) chuyển các khoản đã đóng sang đăng ký mới. Sĩ số hai lớp do trigger cập nhật.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ChuyenLop
    @MaDK     INT,
    @MaLopMoi VARCHAR(10),
    @MaDKMoi  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_ChuyenLop;
    BEGIN TRY
        DECLARE @MaHV CHAR(6), @LopCu VARCHAR(10), @HocPhi DECIMAL(12,0), @GiamGia DECIMAL(5,2), @TT NVARCHAR(20);
        SELECT @MaHV = MaHV, @LopCu = MaLop, @HocPhi = HocPhi, @GiamGia = GiamGia, @TT = TrangThai
        FROM dbo.DANGKY WHERE MaDK = @MaDK;
        IF @MaHV IS NULL THROW 50050, N'Đăng ký không tồn tại.', 1;
        IF @TT NOT IN (N'Đang học', N'Bảo lưu') THROW 50051, N'Chỉ chuyển lớp cho đăng ký đang học hoặc bảo lưu.', 1;

        DECLARE @KhCu VARCHAR(6) = (SELECT MaKH FROM dbo.LOPHOC WHERE MaLop = @LopCu);
        DECLARE @KhMoi VARCHAR(6), @TTMoi NVARCHAR(20), @ToiDa TINYINT, @HienTai TINYINT;
        SELECT @KhMoi = MaKH, @TTMoi = TrangThai, @ToiDa = SiSoToiDa, @HienTai = SiSoHienTai
        FROM dbo.LOPHOC WITH (UPDLOCK, HOLDLOCK) WHERE MaLop = @MaLopMoi;
        IF @KhMoi IS NULL OR @TTMoi NOT IN (N'Sắp mở', N'Đang học') THROW 50052, N'Lớp mới không tồn tại hoặc không còn mở.', 1;
        IF @KhMoi <> @KhCu THROW 50053, N'Chỉ được chuyển sang lớp cùng khoá học.', 1;
        IF @HienTai >= @ToiDa THROW 50004, N'Lớp mới đã đủ sĩ số.', 1;
        IF EXISTS (SELECT 1 FROM dbo.DANGKY WHERE MaHV = @MaHV AND MaLop = @MaLopMoi)
            THROW 50003, N'Học viên đã đăng ký lớp mới.', 1;

        UPDATE dbo.DANGKY SET TrangThai = N'Đã chuyển lớp' WHERE MaDK = @MaDK;
        INSERT dbo.DANGKY (MaHV, MaLop, HocPhi, GiamGia) VALUES (@MaHV, @MaLopMoi, @HocPhi, @GiamGia);
        SET @MaDKMoi = SCOPE_IDENTITY();
        UPDATE dbo.CT_PHIEUTHU SET MaDK = @MaDKMoi WHERE MaDK = @MaDK;   -- trigger tính lại trạng thái học phí
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_ChuyenLop;
        THROW;
    END CATCH
END
GO

/* ---------------------------------------------------------------------
   sp_ThongKeDoanhThu – doanh thu theo chi nhánh × tháng trong khoảng ngày
   Trả về bảng chi tiết + tổng qua tham số OUTPUT.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeDoanhThu
    @TuNgay       DATE,
    @DenNgay      DATE,
    @MaCN         CHAR(4) = NULL,
    @TongDoanhThu DECIMAL(14,0) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @TuNgay > @DenNgay THROW 50060, N'Từ ngày phải trước hoặc bằng đến ngày.', 1;

    -- Điều kiện khoảng ngày viết dạng SARGable để dùng được IX_PHIEUTHU_NgayThu
    SELECT l.MaCN, cn.TenCN, YEAR(p.NgayThu) AS Nam, MONTH(p.NgayThu) AS Thang,
           COUNT(DISTINCT p.MaPT) AS SoPhieu, SUM(c.SoTien) AS DoanhThu
    FROM dbo.CT_PHIEUTHU c
    JOIN dbo.PHIEUTHU p  ON p.MaPT = c.MaPT
    JOIN dbo.DANGKY d    ON d.MaDK = c.MaDK
    JOIN dbo.LOPHOC l    ON l.MaLop = d.MaLop
    JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
    WHERE p.NgayThu >= @TuNgay AND p.NgayThu < DATEADD(DAY, 1, @DenNgay)
      AND (@MaCN IS NULL OR l.MaCN = @MaCN)
    GROUP BY l.MaCN, cn.TenCN, YEAR(p.NgayThu), MONTH(p.NgayThu)
    ORDER BY l.MaCN, Nam, Thang;

    SELECT @TongDoanhThu = ISNULL(SUM(c.SoTien), 0)
    FROM dbo.CT_PHIEUTHU c
    JOIN dbo.PHIEUTHU p ON p.MaPT = c.MaPT
    JOIN dbo.DANGKY d   ON d.MaDK = c.MaDK
    JOIN dbo.LOPHOC l   ON l.MaLop = d.MaLop
    WHERE p.NgayThu >= @TuNgay AND p.NgayThu < DATEADD(DAY, 1, @DenNgay)
      AND (@MaCN IS NULL OR l.MaCN = @MaCN);
END
GO

/* ---------------------------------------------------------------------
   sp_TimKiemHocVien – tìm theo nhiều tiêu chí tuỳ chọn, phân trang OFFSET/FETCH
   Đọc từ vw_HocVien_ChiNhanh nên tự giới hạn theo chi nhánh của người dùng (T16).
   SQL tĩnh + OPTION (RECOMPILE): mỗi lần chạy tối ưu theo tham số thực, không dùng SQL động
   (giữ ownership chaining, tránh SQL injection).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TimKiemHocVien
    @TuKhoa      NVARCHAR(100) = NULL,   -- họ tên, mã HV, SĐT, email
    @MaCN        CHAR(4)       = NULL,
    @MaKH        VARCHAR(6)    = NULL,   -- đã / đang học khoá này
    @ConNo       BIT           = NULL,   -- 1: chỉ học viên còn nợ
    @Trang       INT           = 1,
    @SoDongTrang INT           = 20,
    @TongSo      INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Trang < 1 OR @SoDongTrang NOT BETWEEN 1 AND 200
        THROW 50061, N'Tham số phân trang không hợp lệ.', 1;
    DECLARE @k NVARCHAR(102) = N'%' + NULLIF(LTRIM(RTRIM(@TuKhoa)), N'') + N'%';

    DECLARE @KQ TABLE (MaHV CHAR(6) PRIMARY KEY);
    INSERT @KQ
    SELECT h.MaHV FROM dbo.vw_HocVien_ChiNhanh h
    WHERE (@k IS NULL OR h.HoTen LIKE @k OR h.MaHV LIKE @k OR h.SoDienThoai LIKE @k OR h.Email LIKE @k)
      AND (@MaCN IS NULL OR h.MaCN = @MaCN)
      AND (@MaKH IS NULL OR EXISTS (SELECT 1 FROM dbo.DANGKY d JOIN dbo.LOPHOC l ON l.MaLop = d.MaLop
                                    WHERE d.MaHV = h.MaHV AND l.MaKH = @MaKH))
      AND (@ConNo IS NULL OR (@ConNo = 1 AND dbo.fn_SoTienConNo(h.MaHV) > 0) OR (@ConNo = 0 AND dbo.fn_SoTienConNo(h.MaHV) = 0))
    OPTION (RECOMPILE);
    SET @TongSo = @@ROWCOUNT;

    SELECT h.MaHV, h.HoTen, h.NgaySinh, h.Tuoi, h.GioiTinh, h.SoDienThoai, h.Email, h.DiaChi, h.MaCN, h.TenCN,
           (SELECT COUNT(*) FROM dbo.DANGKY d WHERE d.MaHV = h.MaHV) AS SoLopDaDangKy,
           dbo.fn_SoTienConNo(h.MaHV) AS ConNo
    FROM dbo.vw_HocVien_ChiNhanh h JOIN @KQ k ON k.MaHV = h.MaHV
    ORDER BY h.TenHV, h.HoHV, h.MaHV
    OFFSET (@Trang - 1) * @SoDongTrang ROWS FETCH NEXT @SoDongTrang ROWS ONLY;
END
GO

PRINT N'✓ 05_procedures.sql: 9 procedure nghiệp vụ.';
GO
