/* =====================================================================
   Kiểm thử trigger (T13): chặn dữ liệu sai, duy trì dữ liệu suy diễn, ghi nhật ký.
   Thao tác TRỰC TIẾP lên bảng (bỏ qua procedure) để chứng minh CSDL tự bảo vệ.
   Lỗi phát sinh trong trigger luôn làm transaction bị "doomed" (XACT_ABORT mặc định ON
   trong trigger), nên mỗi ca chạy trong transaction riêng: ghi nhận kết quả vào biến,
   ROLLBACK, rồi mới ghi vào bảng kết quả. Dữ liệu mẫu không đổi sau khi chạy.
   ===================================================================== */
USE ECMS;
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO
DROP TABLE IF EXISTS #KQ;
CREATE TABLE #KQ (STT INT IDENTITY, TenTrigger SYSNAME, Ca NVARCHAR(200), MongDoi NVARCHAR(80), ThucTe NVARCHAR(400),
                  KetQua AS (CASE WHEN ThucTe LIKE MongDoi + N'%' THEN 'PASS' ELSE 'FAIL' END));
GO
DECLARE @LopDay VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE SiSoHienTai = SiSoToiDa);
DECLARE @LopTrong VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE TrangThai = N'Sắp mở' AND SiSoHienTai < SiSoToiDa ORDER BY MaLop);
DECLARE @HV CHAR(6) = (SELECT TOP 1 h.MaHV FROM HOCVIEN h WHERE NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV) ORDER BY h.MaHV);
DECLARE @HV2 CHAR(6) = (SELECT TOP 1 h.MaHV FROM HOCVIEN h WHERE h.MaHV <> @HV
                        AND NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV AND d.MaLop = @LopTrong) ORDER BY h.MaHV DESC);
DECLARE @KT CHAR(6) = (SELECT TOP 1 MaNV FROM NHANVIEN WHERE ChucVu = N'Kế toán');
DECLARE @Truoc INT, @MaDK INT, @MaPT INT, @NK INT, @s NVARCHAR(400), @t NVARCHAR(400);
DECLARE @R TABLE (STT INT IDENTITY, TenTrigger SYSNAME, Ca NVARCHAR(200), MongDoi NVARCHAR(80), ThucTe NVARCHAR(400));
EXEC sp_set_session_context N'app_user', N'kiemthu';

/* --- 1. trg_DangKy_KiemTraSiSo: INSERT thẳng vào lớp đầy --- */
BEGIN TRAN;
BEGIN TRY INSERT DANGKY (MaHV, MaLop, HocPhi) VALUES (@HV, @LopDay, 1000000); SET @s = N'không báo lỗi'; END TRY
BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_DangKy_KiemTraSiSo', N'INSERT thẳng vào lớp đầy ' + @LopDay, N'50070', @s);

/* --- 2–4. Chuỗi thao tác hợp lệ trong một transaction (rollback ở cuối) --- */
BEGIN TRAN;
SET @Truoc = (SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong);
INSERT DANGKY (MaHV, MaLop, HocPhi) VALUES (@HV, @LopTrong, 4000000);
SET @MaDK = SCOPE_IDENTITY();
SET @s = CONCAT(IIF((SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong) = @Truoc + 1, N'OK ', N'SAI '),
                @Truoc, N' → ', (SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong));
INSERT @R VALUES ('trg_DangKy_SiSo', N'INSERT 1 đăng ký → sĩ số +1', N'OK', @s);
UPDATE DANGKY SET TrangThai = N'Bảo lưu' WHERE MaDK = @MaDK;
SET @s = CONCAT(IIF((SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong) = @Truoc, N'OK ', N'SAI '),
                N'còn ', (SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong));
INSERT @R VALUES ('trg_DangKy_SiSo', N'Chuyển sang Bảo lưu → sĩ số −1', N'OK', @s);

UPDATE DANGKY SET TrangThai = N'Đang học', DiemGK = 4, DiemCK = 5 WHERE MaDK = @MaDK;
SET @s = (SELECT CONCAT(N'DiemTB=', DiemTB, N' → ', KetQua) FROM DANGKY WHERE MaDK = @MaDK);
INSERT @R VALUES ('trg_DangKy_KetQua', N'Nhập GK 4, CK 5', N'DiemTB=4.60 → Không đạt', @s);
UPDATE DANGKY SET DiemCK = 7 WHERE MaDK = @MaDK;
SET @s = (SELECT CONCAT(N'DiemTB=', DiemTB, N' → ', KetQua) FROM DANGKY WHERE MaDK = @MaDK);
INSERT @R VALUES ('trg_DangKy_KetQua', N'Sửa CK thành 7', N'DiemTB=5.80 → Đạt', @s);

INSERT PHIEUTHU (MaHV, MaNV) VALUES (@HV, @KT);
SET @MaPT = SCOPE_IDENTITY();
INSERT CT_PHIEUTHU (MaPT, MaDK, SoTien) VALUES (@MaPT, @MaDK, 1500000);
SET @s = (SELECT CONCAT(N'TongTien=', p.TongTien, N', ', d.TrangThaiHP) FROM PHIEUTHU p, DANGKY d WHERE p.MaPT = @MaPT AND d.MaDK = @MaDK);
INSERT @R VALUES ('trg_CTPhieuThu_TongTien', N'Thêm chi tiết 1.500.000', N'TongTien=1500000, Đóng một phần', @s);
UPDATE CT_PHIEUTHU SET SoTien = 4000000 WHERE MaPT = @MaPT AND MaDK = @MaDK;
SET @s = (SELECT CONCAT(N'TongTien=', p.TongTien, N', ', d.TrangThaiHP) FROM PHIEUTHU p, DANGKY d WHERE p.MaPT = @MaPT AND d.MaDK = @MaDK);
INSERT @R VALUES ('trg_CTPhieuThu_TongTien', N'Sửa thành đủ 4.000.000', N'TongTien=4000000, Đã đóng', @s);
DELETE CT_PHIEUTHU WHERE MaPT = @MaPT;
SET @s = (SELECT CONCAT(N'TongTien=', p.TongTien, N', ', d.TrangThaiHP) FROM PHIEUTHU p, DANGKY d WHERE p.MaPT = @MaPT AND d.MaDK = @MaDK);
INSERT @R VALUES ('trg_CTPhieuThu_TongTien', N'Xoá chi tiết', N'TongTien=0, Chưa đóng', @s);

SET @s = (SELECT CONCAT(COUNT(*), N' dòng: ', STRING_AGG(CONCAT(TenBang, ':', ThaoTac), ', ') WITHIN GROUP (ORDER BY MaNK))
          FROM NHATKY WHERE NguoiDungUD = N'kiemthu');
INSERT @R VALUES ('trg_NhatKy_DangKy / PhieuThu', N'Các thao tác trên được ghi nhật ký (app_user = kiemthu)', N'_%DANGKY:INSERT', @s);
SET @NK = (SELECT COUNT(*) FROM NHATKY);
UPDATE NHANVIEN SET LuongCoBan = LuongCoBan * 1.1 WHERE MaNV = @KT;
UPDATE NHANVIEN SET SoDienThoai = SoDienThoai WHERE MaNV = @KT;           -- không đổi lương → không ghi
SET @s = (SELECT TOP 1 CONCAT(N'+', (SELECT COUNT(*) FROM NHATKY) - @NK, N' dòng; ', TenBang, N' ', DuLieuCu, N' → ', DuLieuMoi,
                              N' bởi ', NguoiThucHien, N'/', NguoiDungUD) FROM NHATKY ORDER BY MaNK DESC);
INSERT @R VALUES ('trg_NhatKy_Luong', N'Tăng lương 10% rồi sửa cột khác', N'+1 dòng; NHANVIEN', @s);
ROLLBACK;

/* --- 5. trg_CTPhieuThu_TongTien chặn thu vượt / sai học viên --- */
SET @MaDK = (SELECT TOP 1 MaDK FROM DANGKY WHERE TrangThaiHP = N'Đã đóng' ORDER BY MaDK);
BEGIN TRAN;
BEGIN TRY
    INSERT PHIEUTHU (MaHV, MaNV) SELECT MaHV, @KT FROM DANGKY WHERE MaDK = @MaDK;
    INSERT CT_PHIEUTHU (MaPT, MaDK, SoTien) VALUES (SCOPE_IDENTITY(), @MaDK, 100000);
    SET @s = N'không báo lỗi';
END TRY BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_CTPhieuThu_TongTien', N'Thu thêm cho đăng ký đã đóng đủ', N'50072', @s);

BEGIN TRAN;
BEGIN TRY
    INSERT PHIEUTHU (MaHV, MaNV) VALUES (@HV, @KT);
    INSERT CT_PHIEUTHU (MaPT, MaDK, SoTien) VALUES (SCOPE_IDENTITY(), 1, 1000);
    SET @s = N'không báo lỗi';
END TRY BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_CTPhieuThu_TongTien', N'Chi tiết là đăng ký của học viên khác', N'50071', @s);

/* --- 6. trg_LichHoc_KiemTraTrung: INSERT thẳng lịch trùng phòng --- */
DECLARE @Thu TINYINT, @Ca TINYINT, @CN CHAR(4), @Ph VARCHAR(5), @LopA VARCHAR(10), @LopB VARCHAR(10);
SELECT TOP 1 @LopA = la.MaLop, @LopB = lb.MaLop, @Thu = lh.Thu, @Ca = lh.MaCa, @CN = lh.MaCN, @Ph = lh.MaPhong
FROM LICHHOC lh JOIN LOPHOC la ON la.MaLop = lh.MaLop
JOIN LOPHOC lb ON lb.MaCN = la.MaCN AND lb.MaLop <> la.MaLop AND lb.TrangThai = N'Sắp mở' AND la.TrangThai = N'Đang học'
WHERE la.NgayKetThuc >= lb.NgayKhaiGiang
  AND NOT EXISTS (SELECT 1 FROM LICHHOC x WHERE x.MaLop = lb.MaLop AND x.Thu = lh.Thu AND x.MaCa = lh.MaCa);
BEGIN TRAN;
BEGIN TRY INSERT LICHHOC (MaLop, Thu, MaCa, MaCN, MaPhong) VALUES (@LopB, @Thu, @Ca, @CN, @Ph); SET @s = N'không báo lỗi'; END TRY
BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_LichHoc_KiemTraTrung', CONCAT(N'Xếp ', @LopB, N' vào T', @Thu, N' ca ', @Ca, N' ', @Ph, N' (đang dùng bởi ', @LopA, N')'), N'50073', @s);

/* --- 7. trg_NhatKy_ChiDoc --- */
BEGIN TRAN;
BEGIN TRY UPDATE NHATKY SET NguoiThucHien = N'hacker'; SET @s = N'không báo lỗi'; END TRY
BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_NhatKy_ChiDoc', N'Sửa nhật ký', N'50074', @s);

/* --- 8. INSTEAD OF trên view vw_DangKyChiTiet --- */
BEGIN TRAN;
SET @Truoc = (SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = @LopTrong);
INSERT vw_DangKyChiTiet (MaHV, MaLop, GiamGia) VALUES (@HV2, @LopTrong, 10);
SET @s = (SELECT CONCAT(N'OK HocPhi=', d.HocPhi, N' ThanhTien=', d.ThanhTien, N' sĩ số ', @Truoc, N'→', l.SiSoHienTai)
          FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE d.MaHV = @HV2 AND d.MaLop = @LopTrong);
INSERT @R VALUES ('trg_vwDangKyChiTiet_Insert', N'INSERT qua view (chỉ MaHV, MaLop, GiamGia)', N'OK', @s);
DELETE vw_DangKyChiTiet WHERE MaHV = @HV2 AND MaLop = @LopTrong;
SET @s = (SELECT CONCAT(N'OK ', d.TrangThai, N', sĩ số ', l.SiSoHienTai) FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop
          WHERE d.MaHV = @HV2 AND d.MaLop = @LopTrong);
INSERT @R VALUES ('trg_vwDangKyChiTiet_Delete', N'DELETE qua view = huỷ đăng ký', N'OK Huỷ', @s);
ROLLBACK;

BEGIN TRAN;
BEGIN TRY
    INSERT vw_DangKyChiTiet (MaHV, MaLop) VALUES (@HV2, (SELECT TOP 1 MaLop FROM LOPHOC WHERE TrangThai = N'Đã kết thúc'));
    SET @s = N'không báo lỗi';
END TRY BEGIN CATCH SET @s = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @R VALUES ('trg_vwDangKyChiTiet_Insert', N'INSERT qua view vào lớp đã kết thúc', N'50075', @s);

EXEC sp_set_session_context N'app_user', NULL;
INSERT #KQ (TenTrigger, Ca, MongDoi, ThucTe) SELECT TenTrigger, Ca, MongDoi, ThucTe FROM @R ORDER BY STT;
GO
SELECT STT, TenTrigger AS [Trigger], Ca, MongDoi, ThucTe, KetQua FROM #KQ ORDER BY STT;
IF EXISTS (SELECT 1 FROM #KQ WHERE KetQua = 'FAIL') THROW 50099, N'Có ca kiểm thử trigger thất bại.', 1;
PRINT N'✓ Tất cả ca kiểm thử trigger PASS.';
GO
