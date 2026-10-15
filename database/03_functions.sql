/* =====================================================================
   ECMS – 03_functions.sql : hàm do người dùng định nghĩa (UDF)        (T12)
   3 loại: vô hướng (scalar), inline trả về bảng, multi-statement trả về bảng.
   Chạy lại được: CREATE OR ALTER. Các CHECK dùng hàm được xoá trước rồi tạo lại.
   ===================================================================== */
USE ECMS;
GO
-- Bỏ ràng buộc đang tham chiếu hàm (nếu chạy lại) để có thể ALTER hàm
IF OBJECT_ID(N'CK_NHANVIEN_TuoiLaoDong', N'C') IS NOT NULL
    ALTER TABLE NHANVIEN DROP CONSTRAINT CK_NHANVIEN_TuoiLaoDong;
GO

/* ---------------------------------------------------------------------
   1. HÀM VÔ HƯỚNG
   --------------------------------------------------------------------- */

-- Tuổi tròn tại một ngày (mặc định hôm nay). Dùng trong SELECT, WHERE và CHECK.
CREATE OR ALTER FUNCTION dbo.fn_TinhTuoi (@NgaySinh DATE, @NgayTinh DATE = NULL)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @d DATE = ISNULL(@NgayTinh, CAST(GETDATE() AS DATE));
    RETURN DATEDIFF(YEAR, @NgaySinh, @d)
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @NgaySinh, @d), @NgaySinh) > @d THEN 1 ELSE 0 END;
END
GO

-- Tỷ lệ chuyên cần (%) của một đăng ký trên các buổi đã điểm danh.
-- Có mặt, Muộn: tính là có đi học; Có phép: không tính vào mẫu số; Vắng: không đi học.
CREATE OR ALTER FUNCTION dbo.fn_TyLeChuyenCan (@MaDK INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @CoMat INT, @Tong INT;
    SELECT @CoMat = SUM(CASE WHEN TrangThai IN (N'Có mặt', N'Muộn') THEN 1 ELSE 0 END),
           @Tong  = SUM(CASE WHEN TrangThai <> N'Có phép' THEN 1 ELSE 0 END)
    FROM dbo.DIEMDANH WHERE MaDK = @MaDK;
    RETURN CASE WHEN ISNULL(@Tong, 0) = 0 THEN NULL ELSE CAST(100.0 * @CoMat / @Tong AS DECIMAL(5,2)) END;
END
GO

-- Xếp loại theo điểm trung bình (thang 10)
CREATE OR ALTER FUNCTION dbo.fn_XepLoai (@DiemTB DECIMAL(4,2))
RETURNS NVARCHAR(20)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @DiemTB IS NULL THEN NULL
        WHEN @DiemTB >= 9   THEN N'Xuất sắc'
        WHEN @DiemTB >= 8   THEN N'Giỏi'
        WHEN @DiemTB >= 6.5 THEN N'Khá'
        WHEN @DiemTB >= 5   THEN N'Trung bình'
        ELSE N'Yếu' END;
END
GO

-- Số tiền đã đóng cho một đăng ký
CREATE OR ALTER FUNCTION dbo.fn_SoTienDaDong (@MaDK INT)
RETURNS DECIMAL(12,0)
AS
BEGIN
    RETURN ISNULL((SELECT SUM(SoTien) FROM dbo.CT_PHIEUTHU WHERE MaDK = @MaDK), 0);
END
GO

-- Tổng số tiền học viên còn nợ trên mọi đăng ký chưa huỷ
CREATE OR ALTER FUNCTION dbo.fn_SoTienConNo (@MaHV CHAR(6))
RETURNS DECIMAL(12,0)
AS
BEGIN
    DECLARE @No DECIMAL(12,0);
    SELECT @No = SUM(d.ThanhTien - ISNULL(t.DaThu, 0))
    FROM dbo.DANGKY d
    OUTER APPLY (SELECT SUM(c.SoTien) AS DaThu FROM dbo.CT_PHIEUTHU c WHERE c.MaDK = d.MaDK) t
    WHERE d.MaHV = @MaHV AND d.TrangThai NOT IN (N'Huỷ', N'Đã chuyển lớp');   -- khoản đã đóng đi theo đăng ký mới khi chuyển lớp
    RETURN ISNULL(@No, 0);
END
GO

-- Số chỗ còn trống của lớp
CREATE OR ALTER FUNCTION dbo.fn_SoChoConLai (@MaLop VARCHAR(10))
RETURNS INT
AS
BEGIN
    RETURN (SELECT SiSoToiDa - SiSoHienTai FROM dbo.LOPHOC WHERE MaLop = @MaLop);
END
GO

/* ---------------------------------------------------------------------
   2. HÀM INLINE TRẢ VỀ BẢNG (một câu SELECT – tối ưu như view có tham số)
   --------------------------------------------------------------------- */

-- Lịch học của học viên trong tuần chứa ngày @Tuan (thứ Hai → Chủ nhật)
CREATE OR ALTER FUNCTION dbo.fn_LichHocHocVien (@MaHV CHAR(6), @Tuan DATE)
RETURNS TABLE
AS
RETURN
    SELECT b.NgayHoc,
           -- thứ trong tuần theo cách gọi Việt Nam, không phụ thuộc SET LANGUAGE / DATEFIRST
           CASE DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 WHEN 6 THEN N'Chủ nhật'
                ELSE N'Thứ ' + CAST(DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 + 2 AS NVARCHAR(1)) END AS Thu,
           c.TenCa, c.GioBatDau, c.GioKetThuc,
           l.MaLop, k.TenKH, l.MaCN, b.MaPhong, b.STT AS BuoiThu, b.NoiDung, nv.HoTen AS GiaoVien, b.TrangThai
    FROM dbo.DANGKY d
    JOIN dbo.LOPHOC l   ON l.MaLop = d.MaLop
    JOIN dbo.KHOAHOC k  ON k.MaKH = l.MaKH
    JOIN dbo.BUOIHOC b  ON b.MaLop = l.MaLop
    JOIN dbo.CAHOC c    ON c.MaCa = b.MaCa
    JOIN dbo.NHANVIEN nv ON nv.MaNV = l.MaGV
    WHERE d.MaHV = @MaHV
      AND d.TrangThai = N'Đang học'
      -- (DATEDIFF(DAY, '19000101', x) % 7) = 0 là thứ Hai, không phụ thuộc SET DATEFIRST
      AND b.NgayHoc >= DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @Tuan) % 7), @Tuan)
      AND b.NgayHoc <  DATEADD(DAY, 7 - (DATEDIFF(DAY, '19000101', @Tuan) % 7), @Tuan);
GO

-- Các lớp của một giáo viên (dùng để giáo viên chỉ thấy lớp mình – T22)
CREATE OR ALTER FUNCTION dbo.fn_LopCuaGiaoVien (@MaGV CHAR(6))
RETURNS TABLE
AS
RETURN
    SELECT l.MaLop, l.TenLop, l.MaKH, k.TenKH, l.MaCN, l.NgayKhaiGiang, l.NgayKetThuc,
           l.SiSoHienTai, l.SiSoToiDa, l.TrangThai,
           (SELECT COUNT(*) FROM dbo.BUOIHOC b WHERE b.MaLop = l.MaLop AND b.NgayHoc <= CAST(GETDATE() AS DATE)) AS SoBuoiDaQua,
           k.SoBuoi
    FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
    WHERE l.MaGV = @MaGV;
GO

-- Gợi ý khoá học theo điểm test đầu vào (và chương trình nếu có)
CREATE OR ALTER FUNCTION dbo.fn_GoiYKhoaHoc (@Diem DECIMAL(3,1), @MaCT VARCHAR(5) = NULL)
RETURNS TABLE
AS
RETURN
    SELECT k.MaKH, k.TenKH, k.MaCT, k.CapDo, k.MucTieuDauRa, k.HocPhi,
           (SELECT COUNT(*) FROM dbo.LOPHOC l
            WHERE l.MaKH = k.MaKH AND l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoHienTai < l.SiSoToiDa) AS SoLopConCho
    FROM dbo.KHOAHOC k
    WHERE @Diem BETWEEN k.DiemDauVaoTu AND k.DiemDauVaoDen
      AND (@MaCT IS NULL OR k.MaCT = @MaCT);
GO

/* ---------------------------------------------------------------------
   3. HÀM MULTI-STATEMENT TRẢ VỀ BẢNG (nhiều câu lệnh, có biến bảng)
   --------------------------------------------------------------------- */

-- Bảng điểm của lớp: điểm, chuyên cần, xếp loại, thứ hạng, ghi chú cảnh báo
CREATE OR ALTER FUNCTION dbo.fn_BangDiemLop (@MaLop VARCHAR(10))
RETURNS @Bang TABLE (
    Hang        INT,
    MaDK        INT,
    MaHV        CHAR(6),
    HoTen       NVARCHAR(71),
    DiemGK      DECIMAL(4,2),
    DiemCK      DECIMAL(4,2),
    DiemTB      DECIMAL(4,2),
    XepLoai     NVARCHAR(20),
    ChuyenCan   DECIMAL(5,2),
    KetQua      NVARCHAR(10),
    GhiChu      NVARCHAR(100)
)
AS
BEGIN
    INSERT @Bang (MaDK, MaHV, HoTen, DiemGK, DiemCK, DiemTB, KetQua)
    SELECT d.MaDK, d.MaHV, h.HoTen, d.DiemGK, d.DiemCK, d.DiemTB, d.KetQua
    FROM dbo.DANGKY d JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV
    WHERE d.MaLop = @MaLop AND d.TrangThai IN (N'Đang học', N'Hoàn thành');

    UPDATE @Bang SET XepLoai = dbo.fn_XepLoai(DiemTB), ChuyenCan = dbo.fn_TyLeChuyenCan(MaDK);

    -- Thứ hạng theo điểm TB (đồng hạng nếu bằng điểm), chưa có điểm thì không xếp
    UPDATE b SET Hang = r.Hang
    FROM @Bang b JOIN (SELECT MaDK, RANK() OVER (ORDER BY DiemTB DESC) AS Hang FROM @Bang WHERE DiemTB IS NOT NULL) r
         ON r.MaDK = b.MaDK;

    UPDATE @Bang SET GhiChu = CONCAT_WS(N'; ',
        CASE WHEN ChuyenCan < 80 THEN N'Chuyên cần dưới 80% – không đủ điều kiện cấp chứng nhận' END,
        CASE WHEN DiemGK IS NOT NULL AND DiemGK < 5 AND DiemCK IS NULL THEN N'Điểm giữa kỳ dưới 5' END);
    UPDATE @Bang SET GhiChu = NULL WHERE GhiChu = N'';
    RETURN;
END
GO

/* ---------------------------------------------------------------------
   4. DÙNG HÀM TRONG CHECK CONSTRAINT
   Nhân viên phải trong độ tuổi lao động (18 – 65) tại ngày vào làm.
   --------------------------------------------------------------------- */
ALTER TABLE NHANVIEN WITH CHECK ADD CONSTRAINT CK_NHANVIEN_TuoiLaoDong
    CHECK (dbo.fn_TinhTuoi(NgaySinh, NgayVaoLam) BETWEEN 18 AND 65);
GO

PRINT N'✓ 03_functions.sql: 6 hàm vô hướng, 3 hàm inline, 1 hàm multi-statement.';
GO
