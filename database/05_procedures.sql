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
        -- Giáo viên đăng nhập web chỉ được thao tác trên lớp mình phụ trách (SESSION_CONTEXT do ứng dụng đặt – T19)
        IF CAST(SESSION_CONTEXT(N'vai_tro') AS VARCHAR(10)) = 'GiaoVien'
           AND NOT EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaLop = @MaLop AND MaGV = CAST(SESSION_CONTEXT(N'ma_nv') AS CHAR(6)))
            THROW 50035, N'Giáo viên chỉ được thao tác trên lớp mình phụ trách.', 1;
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
        -- Giáo viên đăng nhập web chỉ được thao tác trên lớp mình phụ trách (SESSION_CONTEXT do ứng dụng đặt – T19)
        IF CAST(SESSION_CONTEXT(N'vai_tro') AS VARCHAR(10)) = 'GiaoVien'
           AND NOT EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaLop = @MaLop AND MaGV = CAST(SESSION_CONTEXT(N'ma_nv') AS CHAR(6)))
            THROW 50043, N'Giáo viên chỉ được thao tác trên lớp mình phụ trách.', 1;
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

/* =====================================================================
   DANH MỤC – thêm / sửa / xoá cho form của ứng dụng web (T19)
   Mỗi "sp_Luu…" là upsert: có khoá thì sửa, chưa có thì thêm. Lỗi nghiệp vụ THROW 5012x.
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_LuuChiNhanh
    @MaCN CHAR(4), @TenCN NVARCHAR(100), @DiaChi NVARCHAR(200), @SoDienThoai VARCHAR(15),
    @NgayThanhLap DATE, @MaNVQuanLy CHAR(6) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MaNVQuanLy IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE MaNV = @MaNVQuanLy AND ChucVu = N'Quản lý')
        THROW 50120, N'Người quản lý chi nhánh phải là nhân viên có chức vụ Quản lý.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CHINHANH WHERE MaCN = @MaCN)
        UPDATE dbo.CHINHANH SET TenCN = @TenCN, DiaChi = @DiaChi, SoDienThoai = @SoDienThoai,
               NgayThanhLap = @NgayThanhLap, MaNVQuanLy = @MaNVQuanLy WHERE MaCN = @MaCN;
    ELSE
        INSERT dbo.CHINHANH (MaCN, TenCN, DiaChi, SoDienThoai, NgayThanhLap, MaNVQuanLy)
        VALUES (@MaCN, @TenCN, @DiaChi, @SoDienThoai, @NgayThanhLap, @MaNVQuanLy);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaChiNhanh @MaCN CHAR(4)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE MaCN = @MaCN) OR EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaCN = @MaCN)
       OR EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaCN = @MaCN)
        THROW 50121, N'Chi nhánh đã có nhân viên, lớp học hoặc học viên – không thể xoá.', 1;
    DELETE dbo.CHINHANH WHERE MaCN = @MaCN;     -- phòng học xoá theo (ON DELETE CASCADE)
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_LuuPhongHoc
    @MaCN CHAR(4), @MaPhong VARCHAR(5), @SucChua TINYINT, @LoaiPhong NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop
               WHERE lh.MaCN = @MaCN AND lh.MaPhong = @MaPhong AND l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoToiDa > @SucChua)
        THROW 50122, N'Sức chứa mới nhỏ hơn sĩ số tối đa của lớp đang dùng phòng.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PHONGHOC WHERE MaCN = @MaCN AND MaPhong = @MaPhong)
        UPDATE dbo.PHONGHOC SET SucChua = @SucChua, LoaiPhong = @LoaiPhong WHERE MaCN = @MaCN AND MaPhong = @MaPhong;
    ELSE
        INSERT dbo.PHONGHOC (MaCN, MaPhong, SucChua, LoaiPhong) VALUES (@MaCN, @MaPhong, @SucChua, @LoaiPhong);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaPhongHoc @MaCN CHAR(4), @MaPhong VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaCN = @MaCN AND MaPhong = @MaPhong)
        THROW 50123, N'Phòng đã được xếp lịch – không thể xoá.', 1;
    DELETE dbo.PHONGHOC WHERE MaCN = @MaCN AND MaPhong = @MaPhong;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_LuuCaHoc @MaCa TINYINT, @TenCa NVARCHAR(30), @GioBatDau TIME(0), @GioKetThuc TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CAHOC WHERE MaCa <> @MaCa AND @GioBatDau < GioKetThuc AND GioBatDau < @GioKetThuc)
        THROW 50124, N'Khung giờ trùng với một ca học khác.', 1;
    IF EXISTS (SELECT 1 FROM dbo.CAHOC WHERE MaCa = @MaCa)
        UPDATE dbo.CAHOC SET TenCa = @TenCa, GioBatDau = @GioBatDau, GioKetThuc = @GioKetThuc WHERE MaCa = @MaCa;
    ELSE
        INSERT dbo.CAHOC (MaCa, TenCa, GioBatDau, GioKetThuc) VALUES (@MaCa, @TenCa, @GioBatDau, @GioKetThuc);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaCaHoc @MaCa TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaCa = @MaCa) OR EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaCa = @MaCa)
        THROW 50125, N'Ca học đang được dùng trong lịch học – không thể xoá.', 1;
    DELETE dbo.CAHOC WHERE MaCa = @MaCa;
END
GO

-- Nhân viên + phần chuyên biệt Giáo viên trong một transaction. @MaNV NULL = thêm mới (tự sinh mã)
CREATE OR ALTER PROCEDURE dbo.sp_LuuNhanVien
    @MaNV CHAR(6) = NULL, @HoNV NVARCHAR(50), @TenNV NVARCHAR(20), @NgaySinh DATE, @GioiTinh NVARCHAR(3),
    @SoDienThoai VARCHAR(15), @Email VARCHAR(100), @ChucVu NVARCHAR(20), @LuongCoBan DECIMAL(12,0),
    @NgayVaoLam DATE, @MaCN CHAR(4), @MaNVQuanLy CHAR(6) = NULL, @TrangThai BIT = 1,
    @LoaiGV NVARCHAR(20) = NULL, @QuocTich NVARCHAR(50) = NULL, @TrinhDo NVARCHAR(30) = NULL, @DonGiaBuoi DECIMAL(10,0) = NULL,
    @MaNVMoi CHAR(6) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_LuuNhanVien;
    BEGIN TRY
        IF @ChucVu = N'Giáo viên' AND (@LoaiGV IS NULL OR @TrinhDo IS NULL OR @DonGiaBuoi IS NULL)
            THROW 50126, N'Giáo viên phải có loại giáo viên, trình độ và đơn giá mỗi buổi.', 1;
        IF EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE SoDienThoai = @SoDienThoai AND MaNV <> ISNULL(@MaNV, ''))
            THROW 50127, N'Số điện thoại đã được dùng cho nhân viên khác.', 1;
        IF EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE Email = @Email AND MaNV <> ISNULL(@MaNV, ''))
            THROW 50127, N'Email đã được dùng cho nhân viên khác.', 1;

        IF @MaNV IS NULL
        BEGIN
            SELECT @MaNV = 'NV' + RIGHT('0000' + CAST(ISNULL(MAX(CAST(SUBSTRING(MaNV, 3, 4) AS INT)), 0) + 1 AS VARCHAR(4)), 4)
            FROM dbo.NHANVIEN WITH (UPDLOCK, HOLDLOCK);
            INSERT dbo.NHANVIEN (MaNV, HoNV, TenNV, NgaySinh, GioiTinh, SoDienThoai, Email, ChucVu, LuongCoBan, NgayVaoLam, MaCN, MaNVQuanLy, TrangThai)
            VALUES (@MaNV, @HoNV, @TenNV, @NgaySinh, @GioiTinh, @SoDienThoai, @Email, @ChucVu, @LuongCoBan, @NgayVaoLam, @MaCN, @MaNVQuanLy, @TrangThai);
        END
        ELSE
        BEGIN
            IF @ChucVu <> N'Giáo viên' AND EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaGV = @MaNV)
                THROW 50128, N'Nhân viên đang phụ trách lớp, không thể đổi khỏi chức vụ Giáo viên.', 1;
            UPDATE dbo.NHANVIEN SET HoNV = @HoNV, TenNV = @TenNV, NgaySinh = @NgaySinh, GioiTinh = @GioiTinh,
                   SoDienThoai = @SoDienThoai, Email = @Email, ChucVu = @ChucVu, LuongCoBan = @LuongCoBan,
                   NgayVaoLam = @NgayVaoLam, MaCN = @MaCN, MaNVQuanLy = @MaNVQuanLy, TrangThai = @TrangThai
            WHERE MaNV = @MaNV;
            IF @@ROWCOUNT = 0 THROW 50129, N'Nhân viên không tồn tại.', 1;
        END

        IF @ChucVu = N'Giáo viên'
            MERGE dbo.GIAOVIEN AS t USING (SELECT @MaNV AS MaGV) AS s ON t.MaGV = s.MaGV
            WHEN MATCHED THEN UPDATE SET LoaiGV = @LoaiGV, QuocTich = ISNULL(@QuocTich, N'Việt Nam'), TrinhDo = @TrinhDo, DonGiaBuoi = @DonGiaBuoi
            WHEN NOT MATCHED THEN INSERT (MaGV, LoaiGV, QuocTich, TrinhDo, DonGiaBuoi)
                                  VALUES (@MaNV, @LoaiGV, ISNULL(@QuocTich, N'Việt Nam'), @TrinhDo, @DonGiaBuoi);
        ELSE
            DELETE dbo.GIAOVIEN WHERE MaGV = @MaNV;
        SET @MaNVMoi = @MaNV;
        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_LuuNhanVien;
        THROW;
    END CATCH
END
GO

-- Nhân viên đã phát sinh dữ liệu (lớp, phiếu thu, tài khoản) thì chỉ cho nghỉ việc (TrangThai = 0), không xoá
CREATE OR ALTER PROCEDURE dbo.sp_XoaNhanVien @MaNV CHAR(6)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaGV = @MaNV) OR EXISTS (SELECT 1 FROM dbo.PHIEUTHU WHERE MaNV = @MaNV)
       OR EXISTS (SELECT 1 FROM dbo.NHANVIEN WHERE MaNVQuanLy = @MaNV) OR EXISTS (SELECT 1 FROM dbo.CHINHANH WHERE MaNVQuanLy = @MaNV)
       OR EXISTS (SELECT 1 FROM dbo.KIEMTRA_DAUVAO WHERE MaNVCham = @MaNV)
    BEGIN
        UPDATE dbo.NHANVIEN SET TrangThai = 0 WHERE MaNV = @MaNV;
        UPDATE dbo.TAIKHOAN SET TrangThai = 0 WHERE MaNV = @MaNV;
        SELECT N'Nhân viên đã có dữ liệu liên quan nên được chuyển sang "Đã nghỉ" và khoá tài khoản.' AS ThongBao;
        RETURN;
    END
    DELETE dbo.NHANVIEN WHERE MaNV = @MaNV;           -- GIAOVIEN, CHUNGCHI_GV, TAIKHOAN xoá theo cascade
    SELECT N'Đã xoá nhân viên.' AS ThongBao;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_LuuChungChi
    @MaGV CHAR(6), @TenChungChi NVARCHAR(50), @Diem DECIMAL(5,1) = NULL, @NgayCap DATE, @NoiCap NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.GIAOVIEN WHERE MaGV = @MaGV) THROW 50130, N'Chỉ giáo viên mới có chứng chỉ.', 1;
    IF @NgayCap > CAST(GETDATE() AS DATE) THROW 50131, N'Ngày cấp không được ở tương lai.', 1;
    MERGE dbo.CHUNGCHI_GV AS t USING (SELECT @MaGV AS MaGV, @TenChungChi AS Ten) AS s
       ON t.MaGV = s.MaGV AND t.TenChungChi = s.Ten
    WHEN MATCHED THEN UPDATE SET Diem = @Diem, NgayCap = @NgayCap, NoiCap = @NoiCap
    WHEN NOT MATCHED THEN INSERT (MaGV, TenChungChi, Diem, NgayCap, NoiCap) VALUES (@MaGV, @TenChungChi, @Diem, @NgayCap, @NoiCap);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaChungChi @MaGV CHAR(6), @TenChungChi NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE dbo.CHUNGCHI_GV WHERE MaGV = @MaGV AND TenChungChi = @TenChungChi;
END
GO

/* =====================================================================
   ĐÀO TẠO – chương trình, khoá học, lớp học cho ứng dụng web (T20)   (lỗi 5014x)
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_LuuChuongTrinh @MaCT VARCHAR(5), @TenCT NVARCHAR(100), @DoiTuong NVARCHAR(100), @MoTa NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CHUONGTRINH WHERE MaCT = @MaCT)
        UPDATE dbo.CHUONGTRINH SET TenCT = @TenCT, DoiTuong = @DoiTuong, MoTa = @MoTa WHERE MaCT = @MaCT;
    ELSE
        INSERT dbo.CHUONGTRINH (MaCT, TenCT, DoiTuong, MoTa) VALUES (@MaCT, @TenCT, @DoiTuong, @MoTa);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaChuongTrinh @MaCT VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaCT = @MaCT)
        THROW 50140, N'Chương trình còn khoá học – chuyển hoặc xoá khoá học trước (quan hệ kết tập).', 1;
    DELETE dbo.CHUONGTRINH WHERE MaCT = @MaCT;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_LuuKhoaHoc
    @MaKH VARCHAR(6), @TenKH NVARCHAR(100), @MaCT VARCHAR(5), @CapDo TINYINT,
    @DiemDauVaoTu DECIMAL(3,1), @DiemDauVaoDen DECIMAL(3,1), @MucTieuDauRa NVARCHAR(50),
    @SoBuoi TINYINT, @HocPhi DECIMAL(12,0), @MaKHTienQuyet VARCHAR(6) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MaKHTienQuyet IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaKH = @MaKHTienQuyet AND MaCT = @MaCT)
            THROW 50141, N'Khoá tiên quyết phải thuộc cùng chương trình.', 1;
        -- Chặn vòng lặp tiên quyết: đi ngược chuỗi tiên quyết từ khoá được chọn, không được gặp lại chính khoá này
        DECLARE @Vong INT;
        WITH Chuoi AS (
            SELECT MaKH, MaKHTienQuyet, 1 AS Buoc FROM dbo.KHOAHOC WHERE MaKH = @MaKHTienQuyet
            UNION ALL
            SELECT k.MaKH, k.MaKHTienQuyet, c.Buoc + 1 FROM dbo.KHOAHOC k JOIN Chuoi c ON k.MaKH = c.MaKHTienQuyet WHERE c.Buoc < 50)
        SELECT @Vong = COUNT(*) FROM Chuoi WHERE MaKH = @MaKH;
        IF @Vong > 0 THROW 50142, N'Khoá tiên quyết tạo thành vòng lặp (A cần B, B lại cần A).', 1;
    END
    IF EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaKH = @MaKH)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaKH = @MaKH AND TrangThai IN (N'Đang học', N'Đã kết thúc'))
           AND EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaKH = @MaKH AND SoBuoi <> @SoBuoi)
            THROW 50143, N'Khoá đã có lớp học / kết thúc – không đổi được số buổi.', 1;
        UPDATE dbo.KHOAHOC SET TenKH = @TenKH, MaCT = @MaCT, CapDo = @CapDo, DiemDauVaoTu = @DiemDauVaoTu,
               DiemDauVaoDen = @DiemDauVaoDen, MucTieuDauRa = @MucTieuDauRa, SoBuoi = @SoBuoi, HocPhi = @HocPhi,
               MaKHTienQuyet = @MaKHTienQuyet
        WHERE MaKH = @MaKH;          -- học phí mới chỉ áp dụng cho đăng ký sau này (DANGKY lưu học phí lúc ghi danh)
    END
    ELSE
        INSERT dbo.KHOAHOC (MaKH, TenKH, MaCT, CapDo, DiemDauVaoTu, DiemDauVaoDen, MucTieuDauRa, SoBuoi, HocPhi, MaKHTienQuyet)
        VALUES (@MaKH, @TenKH, @MaCT, @CapDo, @DiemDauVaoTu, @DiemDauVaoDen, @MucTieuDauRa, @SoBuoi, @HocPhi, @MaKHTienQuyet);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_XoaKhoaHoc @MaKH VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaKH = @MaKH) THROW 50144, N'Khoá học đã mở lớp – không thể xoá.', 1;
    IF EXISTS (SELECT 1 FROM dbo.KHOAHOC WHERE MaKHTienQuyet = @MaKH) THROW 50145, N'Khoá học đang là tiên quyết của khoá khác.', 1;
    DELETE dbo.KHOAHOC WHERE MaKH = @MaKH;
END
GO

-- Mở lớp / sửa lớp. @MaLop NULL = mở lớp mới, mã tự sinh <MaKH>-<yy><stt>
CREATE OR ALTER PROCEDURE dbo.sp_LuuLopHoc
    @MaLop VARCHAR(10) = NULL, @TenLop NVARCHAR(100), @MaKH VARCHAR(6), @MaCN CHAR(4), @MaGV CHAR(6),
    @NgayKhaiGiang DATE, @SiSoToiDa TINYINT, @TrangThai NVARCHAR(20) = N'Sắp mở',
    @MaLopMoi VARCHAR(10) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.GIAOVIEN g JOIN dbo.NHANVIEN n ON n.MaNV = g.MaGV WHERE g.MaGV = @MaGV AND n.TrangThai = 1)
        THROW 50146, N'Giáo viên không tồn tại hoặc đã nghỉ việc.', 1;
    IF @MaLop IS NULL
    BEGIN
        IF @NgayKhaiGiang < CAST(GETDATE() AS DATE) THROW 50147, N'Ngày khai giảng của lớp mới không được ở quá khứ.', 1;
        DECLARE @yy CHAR(2) = RIGHT(CAST(YEAR(@NgayKhaiGiang) AS CHAR(4)), 2);
        SELECT @MaLop = @MaKH + '-' + @yy + RIGHT('0' + CAST(ISNULL(MAX(CAST(RIGHT(MaLop, 2) AS INT)), 0) + 1 AS VARCHAR(2)), 2)
        FROM dbo.LOPHOC WITH (UPDLOCK, HOLDLOCK) WHERE MaLop LIKE @MaKH + '-' + @yy + '__';
        INSERT dbo.LOPHOC (MaLop, TenLop, MaKH, MaCN, MaGV, NgayKhaiGiang, SiSoToiDa, TrangThai)
        VALUES (@MaLop, @TenLop, @MaKH, @MaCN, @MaGV, @NgayKhaiGiang, @SiSoToiDa, N'Sắp mở');
    END
    ELSE
    BEGIN
        DECLARE @Cu TABLE (MaKH VARCHAR(6), MaCN CHAR(4), MaGV CHAR(6), NgayKG DATE, SiSo TINYINT, TrangThai NVARCHAR(20));
        INSERT @Cu SELECT MaKH, MaCN, MaGV, NgayKhaiGiang, SiSoHienTai, TrangThai FROM dbo.LOPHOC WHERE MaLop = @MaLop;
        IF NOT EXISTS (SELECT 1 FROM @Cu) THROW 50148, N'Lớp học không tồn tại.', 1;
        IF EXISTS (SELECT 1 FROM @Cu WHERE SiSo > @SiSoToiDa) THROW 50149, N'Sĩ số tối đa nhỏ hơn số học viên đang có.', 1;
        IF EXISTS (SELECT 1 FROM dbo.DANGKY WHERE MaLop = @MaLop) AND EXISTS (SELECT 1 FROM @Cu WHERE MaKH <> @MaKH OR MaCN <> @MaCN)
            THROW 50150, N'Lớp đã có học viên – không đổi được khoá học hoặc chi nhánh.', 1;
        IF EXISTS (SELECT 1 FROM dbo.BUOIHOC WHERE MaLop = @MaLop) AND EXISTS (SELECT 1 FROM @Cu WHERE NgayKG <> @NgayKhaiGiang)
            THROW 50151, N'Lớp đã sinh buổi học – muốn đổi ngày khai giảng hãy sinh lại buổi học.', 1;
        IF EXISTS (SELECT 1 FROM @Cu WHERE TrangThai = N'Đã kết thúc') AND @TrangThai <> N'Đã kết thúc'
            THROW 50152, N'Lớp đã kết thúc không thể mở lại.', 1;
        IF EXISTS (SELECT 1 FROM dbo.LICHHOC WHERE MaLop = @MaLop) AND EXISTS (SELECT 1 FROM @Cu WHERE MaGV <> @MaGV)
        BEGIN
            -- đổi giáo viên: kiểm tra trùng lịch của giáo viên mới
            DECLARE @Trung VARCHAR(10) = (SELECT TOP 1 lh2.MaLop FROM dbo.LICHHOC lh JOIN dbo.LICHHOC lh2 ON lh2.Thu = lh.Thu AND lh2.MaCa = lh.MaCa
                                          JOIN dbo.LOPHOC l2 ON l2.MaLop = lh2.MaLop AND l2.MaGV = @MaGV AND l2.MaLop <> @MaLop
                                          JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop
                                          WHERE lh.MaLop = @MaLop AND l2.TrangThai <> N'Huỷ'
                                            AND l2.NgayKhaiGiang <= ISNULL(l.NgayKetThuc, '9999-12-31') AND l.NgayKhaiGiang <= ISNULL(l2.NgayKetThuc, '9999-12-31'));
            IF @Trung IS NOT NULL
            BEGIN
                DECLARE @msg NVARCHAR(200) = CONCAT(N'Giáo viên mới trùng lịch với lớp ', @Trung, N'.');
                THROW 50153, @msg, 1;
            END
        END
        UPDATE dbo.LOPHOC SET TenLop = @TenLop, MaKH = @MaKH, MaCN = @MaCN, MaGV = @MaGV, NgayKhaiGiang = @NgayKhaiGiang,
               SiSoToiDa = @SiSoToiDa, TrangThai = @TrangThai
        WHERE MaLop = @MaLop;
    END
    SET @MaLopMoi = @MaLop;
END
GO

-- Lớp chưa có học viên thì xoá hẳn; đã có học viên thì chỉ chuyển trạng thái Huỷ
CREATE OR ALTER PROCEDURE dbo.sp_XoaLopHoc @MaLop VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.DANGKY WHERE MaLop = @MaLop)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.LOPHOC WHERE MaLop = @MaLop AND TrangThai <> N'Sắp mở')
            THROW 50154, N'Chỉ huỷ được lớp chưa khai giảng.', 1;
        UPDATE dbo.LOPHOC SET TrangThai = N'Huỷ' WHERE MaLop = @MaLop;
        SELECT N'Lớp đã có học viên ghi danh nên được chuyển sang trạng thái Huỷ.' AS ThongBao;
        RETURN;
    END
    DELETE dbo.LOPHOC WHERE MaLop = @MaLop;      -- lịch học, buổi học xoá theo cascade
    SELECT N'Đã xoá lớp.' AS ThongBao;
END
GO

/* =====================================================================
   HỌC VIÊN – hồ sơ cho ứng dụng web (T21)   (lỗi 5016x)
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_LuuHocVien
    @MaHV CHAR(6) = NULL, @HoHV NVARCHAR(50), @TenHV NVARCHAR(20), @NgaySinh DATE, @GioiTinh NVARCHAR(3),
    @SoDienThoai VARCHAR(15), @Email VARCHAR(100) = NULL, @SoNha NVARCHAR(100) = NULL, @PhuongXa NVARCHAR(50) = NULL,
    @QuanHuyen NVARCHAR(50) = NULL, @TinhTP NVARCHAR(50) = N'TP. Hồ Chí Minh', @HoTenPhuHuynh NVARCHAR(70) = NULL,
    @MaCN CHAR(4), @TrangThai BIT = 1, @MaHVMoi CHAR(6) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_TinhTuoi(@NgaySinh, DEFAULT) < 16 AND NULLIF(LTRIM(@HoTenPhuHuynh), N'') IS NULL
        THROW 50160, N'Học viên dưới 16 tuổi phải có họ tên phụ huynh.', 1;
    IF EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE SoDienThoai = @SoDienThoai AND MaHV <> ISNULL(@MaHV, '')
               AND HoHV = @HoHV AND TenHV = @TenHV)
        THROW 50161, N'Đã có học viên trùng họ tên và số điện thoại – kiểm tra lại, tránh tạo hồ sơ trùng.', 1;
    IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE Email = @Email AND MaHV <> ISNULL(@MaHV, ''))
        THROW 50162, N'Email đã được dùng cho học viên khác.', 1;
    IF @MaHV IS NULL
    BEGIN
        SELECT @MaHV = 'HV' + RIGHT('0000' + CAST(ISNULL(MAX(CAST(SUBSTRING(MaHV, 3, 4) AS INT)), 0) + 1 AS VARCHAR(4)), 4)
        FROM dbo.HOCVIEN WITH (UPDLOCK, HOLDLOCK);
        INSERT dbo.HOCVIEN (MaHV, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, SoNha, PhuongXa, QuanHuyen, TinhTP,
                            HoTenPhuHuynh, MaCN, TrangThai)
        VALUES (@MaHV, @HoHV, @TenHV, @NgaySinh, @GioiTinh, @SoDienThoai, @Email, @SoNha, @PhuongXa, @QuanHuyen, @TinhTP,
                @HoTenPhuHuynh, @MaCN, @TrangThai);
    END
    ELSE
    BEGIN
        UPDATE dbo.HOCVIEN SET HoHV = @HoHV, TenHV = @TenHV, NgaySinh = @NgaySinh, GioiTinh = @GioiTinh, SoDienThoai = @SoDienThoai,
               Email = @Email, SoNha = @SoNha, PhuongXa = @PhuongXa, QuanHuyen = @QuanHuyen, TinhTP = @TinhTP,
               HoTenPhuHuynh = @HoTenPhuHuynh, MaCN = @MaCN, TrangThai = @TrangThai
        WHERE MaHV = @MaHV;
        IF @@ROWCOUNT = 0 THROW 50163, N'Học viên không tồn tại.', 1;
    END
    SET @MaHVMoi = @MaHV;
END
GO

-- Huỷ đăng ký chưa đóng tiền (giáo vụ ghi danh nhầm)
CREATE OR ALTER PROCEDURE dbo.sp_HuyDangKy @MaDK INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CT_PHIEUTHU WHERE MaDK = @MaDK)
        THROW 50164, N'Đăng ký đã có phiếu thu – không thể huỷ (cần hoàn tiền trước).', 1;
    IF EXISTS (SELECT 1 FROM dbo.DIEMDANH WHERE MaDK = @MaDK)
        THROW 50165, N'Học viên đã đi học – dùng chức năng bảo lưu / chuyển lớp thay vì huỷ.', 1;
    UPDATE dbo.DANGKY SET TrangThai = N'Huỷ' WHERE MaDK = @MaDK AND TrangThai = N'Đang học';
    IF @@ROWCOUNT = 0 THROW 50166, N'Chỉ huỷ được đăng ký đang học.', 1;
END
GO

/* =====================================================================
   HỌC TẬP – xử lý cảnh báo chuyên cần (T22)
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_XuLyCanhBao @MaCB INT, @DaXuLy BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CANHBAO_CHUYENCAN SET DaXuLy = @DaXuLy WHERE MaCB = @MaCB;
    IF @@ROWCOUNT = 0 THROW 50036, N'Cảnh báo không tồn tại.', 1;
END
GO

PRINT N'✓ 05_procedures.sql: 9 procedure nghiệp vụ + procedure danh mục cho web.';
GO
