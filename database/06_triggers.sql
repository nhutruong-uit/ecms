/* =====================================================================
   ECMS – 06_triggers.sql : trigger duy trì dữ liệu suy diễn, chặn dữ liệu sai,
                            nhật ký kiểm toán, INSTEAD OF trên view          (T13)
   Mọi trigger viết theo TẬP HỢP (một câu lệnh có thể thêm/sửa nhiều dòng):
   luôn JOIN với bảng ảo inserted / deleted, không giả định chỉ có 1 dòng.
   Chạy lại được: CREATE OR ALTER TRIGGER.
   ===================================================================== */
USE ECMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   1. ĐĂNG KÝ: chặn lớp đầy, cập nhật sĩ số, tính kết quả
   --------------------------------------------------------------------- */

-- Chặn ghi danh / đổi trạng thái làm lớp vượt sĩ số tối đa (chạy TRƯỚC trigger sĩ số)
CREATE OR ALTER TRIGGER dbo.trg_DangKy_KiemTraSiSo
ON dbo.DANGKY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF UPDATE(MaLop) OR UPDATE(TrangThai) OR NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        DECLARE @Lop VARCHAR(10);
        SELECT TOP 1 @Lop = l.MaLop
        FROM dbo.LOPHOC l
        WHERE l.MaLop IN (SELECT MaLop FROM inserted)
          AND (SELECT COUNT(*) FROM dbo.DANGKY d
               WHERE d.MaLop = l.MaLop AND d.TrangThai IN (N'Đang học', N'Hoàn thành')) > l.SiSoToiDa;
        IF @Lop IS NOT NULL
        BEGIN
            DECLARE @msg NVARCHAR(200) = CONCAT(N'Lớp ', @Lop, N' đã đủ sĩ số, không thể ghi danh thêm.');
            THROW 50070, @msg, 1;      -- THROW trong trigger huỷ cả câu lệnh và transaction
        END
    END
END
GO

-- Cập nhật LOPHOC.SiSoHienTai = số đăng ký Đang học / Hoàn thành (chạy SAU CÙNG)
CREATE OR ALTER TRIGGER dbo.trg_DangKy_SiSo
ON dbo.DANGKY
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    UPDATE l
    SET SiSoHienTai = (SELECT COUNT(*) FROM dbo.DANGKY d
                       WHERE d.MaLop = l.MaLop AND d.TrangThai IN (N'Đang học', N'Hoàn thành'))
    FROM dbo.LOPHOC l
    WHERE l.MaLop IN (SELECT MaLop FROM inserted UNION SELECT MaLop FROM deleted);
END
GO

-- Tính Kết quả khi có điểm cuối kỳ: Đạt nếu điểm TB >= 5
CREATE OR ALTER TRIGGER dbo.trg_DangKy_KetQua
ON dbo.DANGKY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(DiemGK) OR UPDATE(DiemCK)) RETURN;
    UPDATE d
    SET KetQua = CASE WHEN d.DiemTB IS NULL THEN NULL WHEN d.DiemTB >= 5 THEN N'Đạt' ELSE N'Không đạt' END
    FROM dbo.DANGKY d JOIN inserted i ON i.MaDK = d.MaDK
    WHERE ISNULL(d.KetQua, N'') <> ISNULL(CASE WHEN d.DiemTB IS NULL THEN NULL WHEN d.DiemTB >= 5 THEN N'Đạt' ELSE N'Không đạt' END, N'');
END
GO

-- Thứ tự kích hoạt giữa các AFTER trigger cùng bảng, cùng thao tác
EXEC sp_settriggerorder @triggername = N'dbo.trg_DangKy_KiemTraSiSo', @order = N'First', @stmttype = N'INSERT';
EXEC sp_settriggerorder @triggername = N'dbo.trg_DangKy_KiemTraSiSo', @order = N'First', @stmttype = N'UPDATE';
EXEC sp_settriggerorder @triggername = N'dbo.trg_DangKy_SiSo',        @order = N'Last',  @stmttype = N'INSERT';
EXEC sp_settriggerorder @triggername = N'dbo.trg_DangKy_SiSo',        @order = N'Last',  @stmttype = N'UPDATE';
GO

/* ---------------------------------------------------------------------
   2. PHIẾU THU: kiểm tra chi tiết, cập nhật tổng tiền và trạng thái học phí
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_CTPhieuThu_TongTien
ON dbo.CT_PHIEUTHU
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    -- RB16: đăng ký phải của chính học viên trên phiếu thu
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.PHIEUTHU p ON p.MaPT = i.MaPT JOIN dbo.DANGKY d ON d.MaDK = i.MaDK
               WHERE d.MaHV <> p.MaHV)
        THROW 50071, N'Chi tiết phiếu thu chứa đăng ký của học viên khác.', 1;
    -- RB16: tổng đã thu của một đăng ký không vượt thành tiền
    IF EXISTS (SELECT 1 FROM dbo.DANGKY d
               WHERE d.MaDK IN (SELECT MaDK FROM inserted)
                 AND (SELECT SUM(c.SoTien) FROM dbo.CT_PHIEUTHU c WHERE c.MaDK = d.MaDK) > d.ThanhTien)
        THROW 50072, N'Tổng số tiền đã thu vượt quá học phí phải đóng.', 1;

    -- RB15: TongTien = Σ chi tiết
    UPDATE p SET TongTien = ISNULL((SELECT SUM(c.SoTien) FROM dbo.CT_PHIEUTHU c WHERE c.MaPT = p.MaPT), 0)
    FROM dbo.PHIEUTHU p
    WHERE p.MaPT IN (SELECT MaPT FROM inserted UNION SELECT MaPT FROM deleted);

    -- Trạng thái học phí của các đăng ký liên quan
    UPDATE d SET TrangThaiHP = CASE WHEN x.DaThu >= d.ThanhTien THEN N'Đã đóng'
                                    WHEN x.DaThu > 0 THEN N'Đóng một phần' ELSE N'Chưa đóng' END
    FROM dbo.DANGKY d
    CROSS APPLY (SELECT ISNULL(SUM(c.SoTien), 0) AS DaThu FROM dbo.CT_PHIEUTHU c WHERE c.MaDK = d.MaDK) x
    WHERE d.MaDK IN (SELECT MaDK FROM inserted UNION SELECT MaDK FROM deleted);
END
GO

/* ---------------------------------------------------------------------
   3. LỊCH HỌC: chặn trùng phòng / trùng giáo viên (RB09, RB10)
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_LichHoc_KiemTraTrung
ON dbo.LICHHOC
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(300);

    -- Khoảng thời gian của lớp: lớp chưa có ngày kết thúc thì ước lượng theo số buổi
    WITH Moi AS (
        SELECT i.MaLop, i.Thu, i.MaCa, i.MaCN, i.MaPhong, l.MaGV, l.NgayKhaiGiang AS Tu,
               ISNULL(l.NgayKetThuc, DATEADD(WEEK, k.SoBuoi, l.NgayKhaiGiang)) AS Den
        FROM inserted i JOIN dbo.LOPHOC l ON l.MaLop = i.MaLop JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
    ), Khac AS (
        SELECT lh.MaLop, lh.Thu, lh.MaCa, lh.MaCN, lh.MaPhong, l.MaGV, l.NgayKhaiGiang AS Tu,
               ISNULL(l.NgayKetThuc, DATEADD(WEEK, k.SoBuoi, l.NgayKhaiGiang)) AS Den
        FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
        WHERE l.TrangThai <> N'Huỷ'
    )
    SELECT TOP 1 @msg = CASE WHEN m.MaCN = k.MaCN AND m.MaPhong = k.MaPhong
                             THEN CONCAT(N'Trùng phòng ', m.MaPhong, N' (', m.MaCN, N') với lớp ', k.MaLop, N'.')
                             ELSE CONCAT(N'Giáo viên ', m.MaGV, N' trùng lịch với lớp ', k.MaLop, N'.') END
    FROM Moi m JOIN Khac k
      ON k.Thu = m.Thu AND k.MaCa = m.MaCa AND k.MaLop <> m.MaLop
     AND ((k.MaCN = m.MaCN AND k.MaPhong = m.MaPhong) OR k.MaGV = m.MaGV)
     AND k.Tu <= m.Den AND m.Tu <= k.Den;

    IF @msg IS NOT NULL THROW 50073, @msg, 1;
END
GO

/* ---------------------------------------------------------------------
   4. NHẬT KÝ KIỂM TOÁN (NHATKY): ghi dữ liệu cũ / mới dạng JSON,
      login SQL Server (SUSER_SNAME) và tài khoản ứng dụng (SESSION_CONTEXT 'app_user')
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_DangKy
ON dbo.DANGKY
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op VARCHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                  WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                                  WHEN EXISTS (SELECT 1 FROM deleted) THEN 'DELETE' END;
    IF @op IS NULL RETURN;
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'DANGKY', @op, CAST(COALESCE(i.MaDK, d.MaDK) AS NVARCHAR(100)),
           (SELECT d.MaHV, d.MaLop, d.HocPhi, d.GiamGia, d.TrangThaiHP, d.DiemGK, d.DiemCK, d.KetQua, d.TrangThai
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
           (SELECT i.MaHV, i.MaLop, i.HocPhi, i.GiamGia, i.TrangThaiHP, i.DiemGK, i.DiemCK, i.KetQua, i.TrangThai
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
           CAST(SESSION_CONTEXT(N'app_user') AS NVARCHAR(30))
    FROM inserted i FULL OUTER JOIN deleted d ON d.MaDK = i.MaDK
    -- UPDATE không đổi giá trị nào (VD trigger khác cập nhật lại cùng giá trị) thì bỏ qua
    WHERE @op <> 'UPDATE' OR EXISTS (
        SELECT i.MaHV, i.MaLop, i.HocPhi, i.GiamGia, i.TrangThaiHP, i.DiemGK, i.DiemCK, i.KetQua, i.TrangThai
        EXCEPT
        SELECT d.MaHV, d.MaLop, d.HocPhi, d.GiamGia, d.TrangThaiHP, d.DiemGK, d.DiemCK, d.KetQua, d.TrangThai);
END
GO

CREATE OR ALTER TRIGGER dbo.trg_NhatKy_PhieuThu
ON dbo.PHIEUTHU
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op VARCHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                  WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                                  WHEN EXISTS (SELECT 1 FROM deleted) THEN 'DELETE' END;
    IF @op IS NULL RETURN;
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'PHIEUTHU', @op, COALESCE(i.SoPhieu, d.SoPhieu),
           (SELECT d.MaHV, d.MaNV, d.NgayThu, d.HinhThuc, d.TongTien, d.GhiChu FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT i.MaHV, i.MaNV, i.NgayThu, i.HinhThuc, i.TongTien, i.GhiChu FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           CAST(SESSION_CONTEXT(N'app_user') AS NVARCHAR(30))
    FROM inserted i FULL OUTER JOIN deleted d ON d.MaPT = i.MaPT;
END
GO

-- Chỉ ghi khi lương cơ bản thay đổi thật sự
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_Luong
ON dbo.NHANVIEN
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(LuongCoBan) RETURN;
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'NHANVIEN', 'UPDATE', i.MaNV,
           (SELECT d.LuongCoBan FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT i.LuongCoBan, CAST(100.0 * (i.LuongCoBan - d.LuongCoBan) / NULLIF(d.LuongCoBan, 0) AS DECIMAL(6,2)) AS PhanTramThayDoi
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           CAST(SESSION_CONTEXT(N'app_user') AS NVARCHAR(30))
    FROM inserted i JOIN deleted d ON d.MaNV = i.MaNV
    WHERE i.LuongCoBan <> d.LuongCoBan;
END
GO

-- Nhật ký là bằng chứng kiểm toán: không cho sửa / xoá (kể cả db_owner phải tắt trigger mới xoá được)
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_ChiDoc
ON dbo.NHATKY
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    THROW 50074, N'Nhật ký kiểm toán chỉ được thêm, không được sửa hoặc xoá.', 1;
END
GO

/* ---------------------------------------------------------------------
   5. INSTEAD OF TRIGGER trên view vw_DangKyChiTiet
      View JOIN 4 bảng nên không INSERT trực tiếp được; trigger dịch thao tác trên view
      thành thao tác trên bảng DANGKY (học phí lấy từ KHOAHOC). Xoá qua view = huỷ đăng ký.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_vwDangKyChiTiet_Insert
ON dbo.vw_DangKyChiTiet
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i LEFT JOIN dbo.LOPHOC l ON l.MaLop = i.MaLop
               WHERE l.MaLop IS NULL OR l.TrangThai NOT IN (N'Sắp mở', N'Đang học'))
        THROW 50075, N'Lớp không tồn tại hoặc không còn nhận ghi danh.', 1;
    INSERT dbo.DANGKY (MaHV, MaLop, NgayDK, HocPhi, GiamGia)
    SELECT i.MaHV, i.MaLop, ISNULL(i.NgayDK, CAST(GETDATE() AS DATE)), k.HocPhi, ISNULL(i.GiamGia, 0)
    FROM inserted i JOIN dbo.LOPHOC l ON l.MaLop = i.MaLop JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_vwDangKyChiTiet_Delete
ON dbo.vw_DangKyChiTiet
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted d JOIN dbo.CT_PHIEUTHU c ON c.MaDK = d.MaDK)
        THROW 50076, N'Đăng ký đã có phiếu thu, không thể huỷ (cần hoàn tiền trước).', 1;
    UPDATE dk SET TrangThai = N'Huỷ'
    FROM dbo.DANGKY dk JOIN deleted d ON d.MaDK = dk.MaDK;
END
GO

PRINT N'✓ 06_triggers.sql: 11 trigger (8 AFTER, 3 INSTEAD OF trên bảng / view).';
GO
