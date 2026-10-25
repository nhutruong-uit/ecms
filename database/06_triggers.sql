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
    -- UPDATE không đụng tới lớp / trạng thái (VD nhập điểm, đóng học phí) thì sĩ số không đổi: bỏ qua
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) AND NOT (UPDATE(MaLop) OR UPDATE(TrangThai)) RETURN;
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
      login SQL Server (SUSER_SNAME) và tài khoản ứng dụng (dbo.fn_NguoiDungHienTai: SESSION_CONTEXT
      'app_user' read-only của ứng dụng, hoặc tài khoản cùng tên với login minh hoạ – không tự khai được)
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
           (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
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
           (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
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
           (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
    FROM inserted i JOIN deleted d ON d.MaNV = i.MaNV
    WHERE i.LuongCoBan <> d.LuongCoBan;
END
GO

-- Chi tiết phiếu thu: tiền đã thu của từng đăng ký – ghi cả khi chuyển khoản sang đăng ký mới (sp_ChuyenLop)
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_CTPhieuThu
ON dbo.CT_PHIEUTHU
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op VARCHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                  WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                                  WHEN EXISTS (SELECT 1 FROM deleted) THEN 'DELETE' END;
    IF @op IS NULL RETURN;
    -- UPDATE đổi MaDK (một phần khoá chính) nên không ghép inserted – deleted theo khoá được: ghi hai vế riêng
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'CT_PHIEUTHU', @op, CONCAT(x.MaPT, N'/', x.MaDK), x.Cu, x.Moi, (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
    FROM (SELECT d.MaPT, d.MaDK, (SELECT d.MaPT, d.MaDK, d.SoTien FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS Cu, CAST(NULL AS NVARCHAR(MAX)) AS Moi
          FROM deleted d
          UNION ALL
          SELECT i.MaPT, i.MaDK, NULL, (SELECT i.MaPT, i.MaDK, i.SoTien FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) FROM inserted i) x;
END
GO

-- Tài khoản ứng dụng: ghi tạo / xoá, đổi vai trò, khoá – mở khoá, đổi mật khẩu (KHÔNG ghi hash, salt)
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_TaiKhoan
ON dbo.TAIKHOAN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op VARCHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                  WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                                  WHEN EXISTS (SELECT 1 FROM deleted) THEN 'DELETE' END;
    IF @op IS NULL RETURN;
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'TAIKHOAN', @op, COALESCE(i.TenDangNhap, d.TenDangNhap),
           (SELECT d.VaiTro, d.TrangThai, d.KhoaDen FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT i.VaiTro, i.TrangThai, i.KhoaDen,
                   CASE WHEN i.MatKhauHash <> d.MatKhauHash THEN CAST(1 AS BIT) END AS DoiMatKhau
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
    FROM inserted i FULL OUTER JOIN deleted d ON d.TenDangNhap = i.TenDangNhap
    -- đăng nhập thành công / sai chỉ đổi SoLanSai, LanDangNhapCuoi: không ghi để nhật ký không bị nhiễu
    WHERE @op <> 'UPDATE' OR i.VaiTro <> d.VaiTro OR i.TrangThai <> d.TrangThai OR i.MatKhauHash <> d.MatKhauHash
       OR ISNULL(i.KhoaDen, '19000101') <> ISNULL(d.KhoaDen, '19000101');
END
GO

-- Hồ sơ học viên là dữ liệu cá nhân: ghi mọi thay đổi để truy vết ai sửa, sửa gì
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_HocVien
ON dbo.HOCVIEN
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op VARCHAR(6) = CASE WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE'
                                  WHEN EXISTS (SELECT 1 FROM inserted) THEN 'INSERT'
                                  WHEN EXISTS (SELECT 1 FROM deleted) THEN 'DELETE' END;
    IF @op IS NULL RETURN;
    INSERT dbo.NHATKY (TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiDungUD)
    SELECT 'HOCVIEN', @op, COALESCE(i.MaHV, d.MaHV),
           (SELECT d.HoTen, d.NgaySinh, d.SoDienThoai, d.Email, d.SoNha, d.PhuongXa, d.QuanHuyen, d.TinhTP, d.HoTenPhuHuynh,
                   d.MaCN, d.TrangThai FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT i.HoTen, i.NgaySinh, i.SoDienThoai, i.Email, i.SoNha, i.PhuongXa, i.QuanHuyen, i.TinhTP, i.HoTenPhuHuynh,
                   i.MaCN, i.TrangThai FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT TOP 1 TenDangNhap FROM dbo.fn_NguoiDungHienTai())
    FROM inserted i FULL OUTER JOIN deleted d ON d.MaHV = i.MaHV
    WHERE @op <> 'UPDATE' OR EXISTS (
        SELECT i.HoHV, i.TenHV, i.NgaySinh, i.GioiTinh, i.SoDienThoai, i.Email, i.SoNha, i.PhuongXa, i.QuanHuyen, i.TinhTP,
               i.HoTenPhuHuynh, i.MaCN, i.TrangThai
        EXCEPT
        SELECT d.HoHV, d.TenHV, d.NgaySinh, d.GioiTinh, d.SoDienThoai, d.Email, d.SoNha, d.PhuongXa, d.QuanHuyen, d.TinhTP,
               d.HoTenPhuHuynh, d.MaCN, d.TrangThai);
END
GO

-- Nhật ký là bằng chứng kiểm toán: không cho UPDATE / DELETE. Giới hạn: TRUNCATE TABLE không kích hoạt trigger
-- (cần quyền ALTER – chỉ db_owner), DISABLE TRIGGER cũng vậy; muốn chống cả quản trị viên thì dùng
-- ledger table chỉ-ghi-thêm (SQL Server 2022: WITH (LEDGER = ON (APPEND_ONLY = ON))) hoặc SQL Server Audit.
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
    IF EXISTS (SELECT 1 FROM inserted WHERE ISNULL(GiamGia, 0) NOT BETWEEN 0 AND 50)
        THROW 50077, N'Giảm giá phải từ 0 đến 50%.', 1;
    -- Cùng luật khoá tiên quyết với sp_DangKyHoc (viết theo tập hợp): đã Đạt khoá tiên quyết HOẶC điểm đầu vào đủ
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.LOPHOC l ON l.MaLop = i.MaLop JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
               WHERE k.MaKHTienQuyet IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM dbo.DANGKY d JOIN dbo.LOPHOC l2 ON l2.MaLop = d.MaLop
                                 WHERE d.MaHV = i.MaHV AND l2.MaKH = k.MaKHTienQuyet AND d.KetQua = N'Đạt')
                 AND NOT EXISTS (SELECT 1 FROM dbo.KIEMTRA_DAUVAO t WHERE t.MaHV = i.MaHV AND t.DiemTong >= k.DiemDauVaoTu))
        THROW 50078, N'Có học viên chưa đủ điều kiện khoá tiên quyết.', 1;
    -- Ngày đăng ký luôn là hôm nay (không nhận giá trị từ client – tránh lùi hạn đóng học phí)
    INSERT dbo.DANGKY (MaHV, MaLop, NgayDK, HocPhi, GiamGia)
    SELECT i.MaHV, i.MaLop, CAST(GETDATE() AS DATE), k.HocPhi, ISNULL(i.GiamGia, 0)
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
    -- Cùng luật với sp_HuyDangKy: học viên đã đi học thì không huỷ, chỉ huỷ đăng ký đang học
    IF EXISTS (SELECT 1 FROM deleted d JOIN dbo.DIEMDANH dd ON dd.MaDK = d.MaDK)
        THROW 50079, N'Học viên đã đi học – không huỷ được đăng ký (dùng chuyển lớp).', 1;
    UPDATE dk SET TrangThai = N'Huỷ'
    FROM dbo.DANGKY dk JOIN deleted d ON d.MaDK = dk.MaDK
    WHERE dk.TrangThai = N'Đang học';
END
GO

PRINT N'✓ 06_triggers.sql: 14 trigger (11 AFTER, 3 INSTEAD OF trên bảng / view).';
GO
