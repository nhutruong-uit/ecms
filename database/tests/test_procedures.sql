/* =====================================================================
   Kiểm thử stored procedure (T11): mỗi procedure có ca thành công và ca thất bại.
   Toàn bộ chạy trong một transaction và ROLLBACK ở cuối → không làm thay đổi dữ liệu mẫu.
   Kết quả: bảng PASS/FAIL; script báo lỗi nếu có ca FAIL.
   ===================================================================== */
USE ECMS;
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO
DROP TABLE IF EXISTS #KQ;
CREATE TABLE #KQ (STT INT IDENTITY, Procedure_ SYSNAME, Ca NVARCHAR(200), MongDoi NVARCHAR(60), ThucTe NVARCHAR(300), KetQua AS
    (CASE WHEN ThucTe LIKE MongDoi + N'%' THEN 'PASS' ELSE 'FAIL' END));
GO
-- Kết quả ghi vào biến bảng: biến bảng KHÔNG bị ROLLBACK huỷ, bảng tạm thì có
DECLARE @KQ TABLE (STT INT IDENTITY, Procedure_ SYSNAME, Ca NVARCHAR(200), MongDoi NVARCHAR(60), ThucTe NVARCHAR(300));
BEGIN TRANSACTION;

DECLARE @MaDK INT, @MaPT INT, @Tong DECIMAL(14,0), @Tien DECIMAL(12,0), @n INT, @json NVARCHAR(MAX), @err NVARCHAR(300);
-- Dữ liệu dùng cho test
DECLARE @LopMo VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
                              WHERE l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoHienTai < l.SiSoToiDa
                              ORDER BY k.CapDo, l.SiSoHienTai);
DECLARE @DiemLopMo DECIMAL(3,1) = (SELECT k.DiemDauVaoTu FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @LopMo);
DECLARE @LopCap3 VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
                                WHERE l.TrangThai = N'Sắp mở' AND k.CapDo = 3 ORDER BY l.MaLop);
DECLARE @DiemCap3 DECIMAL(3,1) = (SELECT k.DiemDauVaoTu FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @LopCap3);
DECLARE @LopDay VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE SiSoHienTai = SiSoToiDa AND TrangThai IN (N'Sắp mở', N'Đang học'));
DECLARE @LopXong VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE TrangThai = N'Đã kết thúc');
-- khách tiềm năng (chưa ghi danh) có điểm test đủ vào @LopMo
DECLARE @HVMoi CHAR(6) = (SELECT TOP 1 h.MaHV FROM HOCVIEN h WHERE NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV)
                          AND EXISTS (SELECT 1 FROM KIEMTRA_DAUVAO t WHERE t.MaHV = h.MaHV AND t.DiemTong >= @DiemLopMo) ORDER BY h.MaHV);
-- học viên điểm test thấp, chưa Đạt khoá tiên quyết của @LopCap3
DECLARE @HVYeu CHAR(6) = (SELECT TOP 1 h.MaHV FROM HOCVIEN h
                          WHERE (SELECT MAX(DiemTong) FROM KIEMTRA_DAUVAO t WHERE t.MaHV = h.MaHV) < @DiemCap3
                            AND NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV AND d.MaLop = @LopCap3) ORDER BY h.MaHV);
DECLARE @KeToan CHAR(6) = (SELECT TOP 1 MaNV FROM NHANVIEN WHERE ChucVu = N'Kế toán');
DECLARE @GiaoVu CHAR(6) = (SELECT TOP 1 MaNV FROM NHANVIEN WHERE ChucVu = N'Giáo vụ');

/* ---------- sp_DangKyHoc ---------- */
BEGIN TRY
    EXEC sp_DangKyHoc @MaHV = @HVMoi, @MaLop = @LopMo, @GiamGia = 5, @MaDK = @MaDK OUTPUT;
    INSERT @KQ VALUES ('sp_DangKyHoc', N'Ghi danh hợp lệ vào ' + @LopMo, N'OK', CONCAT(N'OK MaDK=', @MaDK));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Ghi danh hợp lệ', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY EXEC sp_DangKyHoc @HVMoi, @LopMo, 0, @MaDK OUTPUT; INSERT @KQ VALUES ('sp_DangKyHoc', N'Đăng ký trùng', N'50003', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Đăng ký trùng', N'50003', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY EXEC sp_DangKyHoc @HVMoi, @LopDay, 0, @MaDK OUTPUT; INSERT @KQ VALUES ('sp_DangKyHoc', N'Lớp đã đủ sĩ số ' + @LopDay, N'50004', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Lớp đã đủ sĩ số ' + ISNULL(@LopDay, N'?'), N'50004', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY EXEC sp_DangKyHoc @HVYeu, @LopCap3, 0, @MaDK OUTPUT; INSERT @KQ VALUES ('sp_DangKyHoc', N'Thiếu khoá tiên quyết', N'50005', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Thiếu khoá tiên quyết (' + @LopCap3 + N')', N'50005', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY EXEC sp_DangKyHoc @HVMoi, @LopXong, 0, @MaDK OUTPUT; INSERT @KQ VALUES ('sp_DangKyHoc', N'Lớp đã kết thúc', N'50002', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Lớp đã kết thúc', N'50002', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY EXEC sp_DangKyHoc 'HV9999', @LopMo, 0, @MaDK OUTPUT; INSERT @KQ VALUES ('sp_DangKyHoc', N'Học viên không tồn tại', N'50001', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DangKyHoc', N'Học viên không tồn tại', N'50001', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_ThuHocPhi (master–detail) ---------- */
DECLARE @DK1 INT = (SELECT MaDK FROM DANGKY WHERE MaHV = @HVMoi AND MaLop = @LopMo);
BEGIN TRY
    SET @json = CONCAT(N'[{"MaDK":', @DK1, N',"SoTien":1000000}]');
    EXEC sp_ThuHocPhi @MaHV = @HVMoi, @MaNV = @KeToan, @HinhThuc = N'Chuyển khoản', @ChiTiet = @json,
                      @MaPT = @MaPT OUTPUT, @TongTien = @Tien OUTPUT;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Thu một phần 1.000.000', N'OK', CONCAT(N'OK MaPT=', @MaPT, N' Tong=', @Tien));
    SET @json = CONCAT(N'[{"MaDK":', @DK1, N'}]');                      -- không ghi số tiền = thu phần còn lại
    EXEC sp_ThuHocPhi @HVMoi, @KeToan, N'Tiền mặt', @json, NULL, @MaPT OUTPUT, @Tien OUTPUT;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Thu phần còn lại', N'OK', CONCAT(N'OK MaPT=', @MaPT, N' Tong=', @Tien));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThuHocPhi', N'Thu hợp lệ', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    SET @json = CONCAT(N'[{"MaDK":', @DK1, N',"SoTien":500000}]');
    EXEC sp_ThuHocPhi @HVMoi, @KeToan, N'Tiền mặt', @json, NULL, @MaPT OUTPUT, @Tien OUTPUT;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Thu vượt số còn nợ', N'50014', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThuHocPhi', N'Thu vượt số còn nợ', N'50014', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY
    SET @json = N'[{"MaDK":1,"SoTien":100000}]';                         -- đăng ký của học viên khác
    EXEC sp_ThuHocPhi @HVMoi, @KeToan, N'Tiền mặt', @json, NULL, @MaPT OUTPUT, @Tien OUTPUT;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Đăng ký của học viên khác', N'50012', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThuHocPhi', N'Đăng ký của học viên khác', N'50012', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY
    EXEC sp_ThuHocPhi @HVMoi, @GiaoVu, N'Tiền mặt', N'[]', NULL, @MaPT OUTPUT, @Tien OUTPUT;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Giáo vụ lập phiếu', N'50011', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThuHocPhi', N'Giáo vụ lập phiếu', N'50011', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_XepLichLop ---------- */
-- lớp chưa điểm danh (đã điểm danh thì không sửa được lịch cố định – ca riêng bên dưới)
DECLARE @L1 VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM LOPHOC l WHERE l.TrangThai = N'Sắp mở'
                           AND NOT EXISTS (SELECT 1 FROM DIEMDANH d WHERE d.MaLop = l.MaLop) ORDER BY l.NgayKhaiGiang, l.MaLop);
DECLARE @CN CHAR(4) = (SELECT MaCN FROM LOPHOC WHERE MaLop = @L1);
DECLARE @PhongTrong VARCHAR(5) = (SELECT TOP 1 MaPhong FROM PHONGHOC p WHERE p.MaCN = @CN AND p.SucChua >= 30
    AND NOT EXISTS (SELECT 1 FROM LICHHOC lh WHERE lh.MaCN = p.MaCN AND lh.MaPhong = p.MaPhong AND lh.Thu = 3 AND lh.MaCa = 2) ORDER BY MaPhong);
BEGIN TRY
    EXEC sp_XepLichLop @MaLop = @L1, @Thu = 3, @MaCa = 2, @MaPhong = @PhongTrong;
    INSERT @KQ VALUES ('sp_XepLichLop', N'Thêm lịch T3 ca 2 phòng trống', N'OK', N'OK');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_XepLichLop', N'Thêm lịch phòng trống', N'OK', ERROR_MESSAGE()); END CATCH;

DECLARE @Trung VARCHAR(10), @TThu TINYINT, @TCa TINYINT, @TPhong VARCHAR(5);
-- lớp khác cùng chi nhánh có thời gian học giao với @L1 (ước lượng như sp_XepLichLop: tối thiểu 1 buổi/tuần)
DECLARE @L1Tu DATE, @L1Den DATE;
SELECT @L1Tu = l.NgayKhaiGiang, @L1Den = ISNULL(l.NgayKetThuc, DATEADD(WEEK, k.SoBuoi, l.NgayKhaiGiang))
FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH WHERE l.MaLop = @L1;
SELECT TOP 1 @Trung = lh.MaLop, @TThu = lh.Thu, @TCa = lh.MaCa, @TPhong = lh.MaPhong
FROM LICHHOC lh JOIN LOPHOC l ON l.MaLop = lh.MaLop
WHERE l.TrangThai IN (N'Đang học', N'Sắp mở') AND lh.MaCN = @CN AND lh.MaLop <> @L1
  AND l.NgayKhaiGiang <= @L1Den AND ISNULL(l.NgayKetThuc, '9999-12-31') >= @L1Tu
  AND NOT EXISTS (SELECT 1 FROM LICHHOC x WHERE x.MaLop = @L1 AND x.Thu = lh.Thu AND x.MaCa = lh.MaCa)
ORDER BY l.NgayKhaiGiang DESC;
BEGIN TRY
    EXEC sp_XepLichLop @L1, @TThu, @TCa, @TPhong;
    INSERT @KQ VALUES ('sp_XepLichLop', N'Trùng phòng / giáo viên với ' + @Trung, N'5002', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_XepLichLop', N'Trùng lịch với ' + ISNULL(@Trung, N'?'), N'5002', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY
    DECLARE @LopDaDD VARCHAR(10) = (SELECT TOP 1 MaLop FROM DIEMDANH ORDER BY MaLop);
    EXEC sp_XepLichLop @LopDaDD, 8, 6, 'P101';
    INSERT @KQ VALUES ('sp_XepLichLop', N'Sửa lịch lớp đã điểm danh', N'50027', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_XepLichLop', N'Sửa lịch lớp đã điểm danh', N'50027', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY
    DECLARE @PhongCNKhac VARCHAR(5) = 'P999';
    EXEC sp_XepLichLop @L1, 6, 6, @PhongCNKhac;
    INSERT @KQ VALUES ('sp_XepLichLop', N'Phòng không thuộc chi nhánh', N'50022', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_XepLichLop', N'Phòng không thuộc chi nhánh', N'50022', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_DiemDanhBuoi ---------- */
DECLARE @LopHoc VARCHAR(10), @Buoi TINYINT;
SELECT TOP 1 @LopHoc = b.MaLop, @Buoi = b.STT FROM BUOIHOC b JOIN LOPHOC l ON l.MaLop = b.MaLop
WHERE l.TrangThai = N'Đang học' AND b.NgayHoc <= CAST(GETDATE() AS DATE) ORDER BY b.NgayHoc DESC;
BEGIN TRY
    SELECT @json = (SELECT MaDK, CASE WHEN ROW_NUMBER() OVER (ORDER BY MaDK) % 5 = 0 THEN N'Vắng' ELSE N'Có mặt' END AS TrangThai
                    FROM DANGKY WHERE MaLop = @LopHoc AND TrangThai = N'Đang học' FOR JSON PATH);
    EXEC sp_DiemDanhBuoi @MaLop = @LopHoc, @STT = @Buoi, @DanhSach = @json;
    INSERT @KQ VALUES ('sp_DiemDanhBuoi', CONCAT(N'Điểm danh cả lớp ', @LopHoc, N' buổi ', @Buoi, N' (1 lần lưu)'), N'OK',
        CONCAT(N'OK ', (SELECT COUNT(*) FROM DIEMDANH WHERE MaLop = @LopHoc AND STT = @Buoi), N' dòng'));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Điểm danh hợp lệ', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    DECLARE @BuoiSau TINYINT = (SELECT MIN(STT) FROM BUOIHOC WHERE MaLop = @LopHoc AND NgayHoc > CAST(GETDATE() AS DATE));
    EXEC sp_DiemDanhBuoi @LopHoc, @BuoiSau, N'[]';
    INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Điểm danh buổi chưa tới', N'50031', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Điểm danh buổi chưa tới', N'50031', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

BEGIN TRY
    SET @json = N'[{"MaDK":1,"TrangThai":"Có mặt"}]';
    EXEC sp_DiemDanhBuoi @LopHoc, @Buoi, @json;
    INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Học viên lớp khác', N'50033', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Học viên lớp khác', N'50033', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_NhapDiem ---------- */
BEGIN TRY
    SELECT @json = (SELECT MaDK, 7.5 AS DiemGK FROM DANGKY WHERE MaLop = @LopHoc AND TrangThai = N'Đang học' FOR JSON PATH);
    EXEC sp_NhapDiem @MaLop = @LopHoc, @DanhSach = @json, @SoDong = @n OUTPUT;
    INSERT @KQ VALUES ('sp_NhapDiem', N'Nhập điểm GK cả lớp', N'OK', CONCAT(N'OK ', @n, N' học viên'));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_NhapDiem', N'Nhập điểm hợp lệ', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    SELECT @json = (SELECT TOP 1 MaDK, 11 AS DiemCK FROM DANGKY WHERE MaLop = @LopHoc AND TrangThai = N'Đang học' FOR JSON PATH);
    EXEC sp_NhapDiem @LopHoc, @json, @n OUTPUT;
    INSERT @KQ VALUES ('sp_NhapDiem', N'Điểm 11', N'50042', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_NhapDiem', N'Điểm ngoài 0–10', N'50042', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_ChuyenLop ---------- */
DECLARE @DKChuyen INT, @LopDich VARCHAR(10), @DKMoi INT;
SELECT TOP 1 @DKChuyen = d.MaDK, @LopDich = l2.MaLop
FROM DANGKY d JOIN LOPHOC l1 ON l1.MaLop = d.MaLop
JOIN LOPHOC l2 ON l2.MaKH = l1.MaKH AND l2.MaLop <> l1.MaLop AND l2.TrangThai IN (N'Sắp mở', N'Đang học') AND l2.SiSoHienTai < l2.SiSoToiDa
WHERE d.TrangThai = N'Đang học' AND NOT EXISTS (SELECT 1 FROM DANGKY x WHERE x.MaHV = d.MaHV AND x.MaLop = l2.MaLop)
  AND EXISTS (SELECT 1 FROM CT_PHIEUTHU c WHERE c.MaDK = d.MaDK);
BEGIN TRY
    SET @Tien = dbo.fn_SoTienDaDong(@DKChuyen);
    EXEC sp_ChuyenLop @MaDK = @DKChuyen, @MaLopMoi = @LopDich, @MaDKMoi = @DKMoi OUTPUT;
    INSERT @KQ VALUES ('sp_ChuyenLop', CONCAT(N'Chuyển ĐK ', @DKChuyen, N' sang ', @LopDich), N'OK',
        CONCAT(N'OK MaDKMoi=', @DKMoi, N', tiền đã đóng chuyển theo: ', dbo.fn_SoTienDaDong(@DKMoi), N'/', @Tien));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ChuyenLop', N'Chuyển lớp hợp lệ', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    EXEC sp_ChuyenLop @DK1, @LopCap3, @DKMoi OUTPUT;
    INSERT @KQ VALUES ('sp_ChuyenLop', N'Chuyển sang khoá khác', N'50053', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ChuyenLop', N'Chuyển sang lớp khác khoá', N'50053', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_ThongKeDoanhThu ---------- */
BEGIN TRY
    DECLARE @R TABLE (MaCN CHAR(4), TenCN NVARCHAR(100), Nam INT, Thang INT, SoPhieu INT, DoanhThu DECIMAL(14,0));
    INSERT @R EXEC sp_ThongKeDoanhThu '2025-01-01', '2025-12-31', NULL, @Tong OUTPUT;
    INSERT @KQ VALUES ('sp_ThongKeDoanhThu', N'Doanh thu năm 2025', N'OK',
        CONCAT(N'OK ', (SELECT COUNT(*) FROM @R), N' dòng, tổng ', FORMAT(@Tong, 'N0'),
               IIF(@Tong = (SELECT SUM(DoanhThu) FROM @R), N' = tổng chi tiết', N' ≠ tổng chi tiết')));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThongKeDoanhThu', N'Doanh thu 2025', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    EXEC sp_ThongKeDoanhThu '2026-12-31', '2026-01-01', NULL, @Tong OUTPUT;
    INSERT @KQ VALUES ('sp_ThongKeDoanhThu', N'Khoảng ngày ngược', N'50060', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThongKeDoanhThu', N'Khoảng ngày ngược', N'50060', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- sp_TimKiemHocVien ---------- */
BEGIN TRY
    EXEC sp_set_session_context N'ma_cn', 'ALL';
    DECLARE @T TABLE (MaHV CHAR(6), HoTen NVARCHAR(71), NgaySinh DATE, Tuoi INT, GioiTinh NVARCHAR(3), SoDienThoai VARCHAR(15),
                      Email VARCHAR(100), DiaChi NVARCHAR(400), MaCN CHAR(4), TenCN NVARCHAR(100), SoLop INT, ConNo DECIMAL(12,0));
    INSERT @T EXEC sp_TimKiemHocVien @TuKhoa = N'Nguyễn', @ConNo = NULL, @Trang = 2, @SoDongTrang = 10, @TongSo = @n OUTPUT;
    INSERT @KQ VALUES ('sp_TimKiemHocVien', N'Tìm "Nguyễn", trang 2, 10 dòng/trang', N'OK',
        CONCAT(N'OK tổng ', @n, N', trang này ', (SELECT COUNT(*) FROM @T), N' dòng'));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_TimKiemHocVien', N'Tìm kiếm', N'OK', ERROR_MESSAGE()); END CATCH;

BEGIN TRY
    EXEC sp_TimKiemHocVien @Trang = 0;
    INSERT @KQ VALUES ('sp_TimKiemHocVien', N'Trang 0', N'50061', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_TimKiemHocVien', N'Tham số trang = 0', N'50061', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

/* ---------- Bổ sung sau rà soát: chống lập phiếu trùng, xoá điểm, mã lớp, lương, trạng thái lớp ---------- */
-- sp_ThuHocPhi gửi lại cùng @MaYeuCau (bấm nút hai lần) → chỉ một phiếu
DECLARE @HVNo CHAR(6), @DKNo INT, @YC UNIQUEIDENTIFIER = NEWID(), @PT1 INT, @PT2 INT;
SELECT TOP 1 @HVNo = MaHV, @DKNo = MaDK FROM vw_CongNoHocVien WHERE ConNo >= 300000 ORDER BY MaDK;
BEGIN TRY
    SET @json = CONCAT(N'[{"MaDK":', @DKNo, N',"SoTien":100000}]');
    EXEC sp_ThuHocPhi @MaHV = @HVNo, @MaNV = @KeToan, @ChiTiet = @json, @MaPT = @PT1 OUTPUT, @MaYeuCau = @YC;
    EXEC sp_ThuHocPhi @MaHV = @HVNo, @MaNV = @KeToan, @ChiTiet = @json, @MaPT = @PT2 OUTPUT, @MaYeuCau = @YC;
    INSERT @KQ VALUES ('sp_ThuHocPhi', N'Gửi lại cùng mã yêu cầu (bấm 2 lần)', N'OK 1 phiếu',
        CONCAT(IIF(@PT1 = @PT2, N'OK ', N'SAI '), (SELECT COUNT(*) FROM PHIEUTHU WHERE MaYeuCau = @YC), N' phiếu, MaPT ', @PT1, N'/', @PT2));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_ThuHocPhi', N'Gửi lại cùng mã yêu cầu', N'OK 1 phiếu', ERROR_MESSAGE()); END CATCH;

-- sp_NhapDiem: khoá có giá trị null → xoá điểm; không có khoá → giữ nguyên
DECLARE @DKDiem INT = (SELECT TOP 1 MaDK FROM DANGKY WHERE MaLop = @LopHoc AND TrangThai = N'Đang học' ORDER BY MaDK);
BEGIN TRY
    SET @json = CONCAT(N'[{"MaDK":', @DKDiem, N',"DiemCK":8}]');
    EXEC sp_NhapDiem @LopHoc, @json, @n OUTPUT;
    SET @json = CONCAT(N'[{"MaDK":', @DKDiem, N',"DiemCK":null}]');
    EXEC sp_NhapDiem @LopHoc, @json, @n OUTPUT;
    INSERT @KQ VALUES ('sp_NhapDiem', N'Xoá điểm CK nhập nhầm (null), giữ điểm GK', N'OK',
        (SELECT CONCAT(IIF(DiemCK IS NULL AND DiemGK = 7.5, N'OK ', N'SAI '), N'GK=', DiemGK, N' CK=', ISNULL(CAST(DiemCK AS NVARCHAR(10)), N'NULL'))
         FROM DANGKY WHERE MaDK = @DKDiem));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_NhapDiem', N'Xoá điểm nhập nhầm', N'OK', ERROR_MESSAGE()); END CATCH;

-- sp_DiemDanhBuoi ghi giáo viên đã dạy buổi (lương tính theo người dạy thật)
INSERT @KQ VALUES ('sp_DiemDanhBuoi', N'Ghi giáo viên dạy buổi (BUOIHOC.MaGVDay)', N'OK',
    (SELECT CONCAT(IIF(b.MaGVDay = l.MaGV, N'OK ', N'SAI '), b.MaGVDay) FROM BUOIHOC b JOIN LOPHOC l ON l.MaLop = b.MaLop
     WHERE b.MaLop = @LopHoc AND b.STT = @Buoi));

-- sp_LuuKhoaHoc: mã 6 ký tự làm mã lớp vượt VARCHAR(10) → chặn với thông báo rõ
BEGIN TRY
    EXEC sp_LuuKhoaHoc @MaKH = 'IELTS7', @TenKH = N'IELTS 7.0 thử', @MaCT = 'IELTS', @CapDo = 9, @DiemDauVaoTu = 7, @DiemDauVaoDen = 10,
                       @MucTieuDauRa = N'IELTS 7.0', @SoBuoi = 30, @HocPhi = 9900000;
    INSERT @KQ VALUES ('sp_LuuKhoaHoc', N'Mã khoá học 6 ký tự', N'50155', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_LuuKhoaHoc', N'Mã khoá học 6 ký tự', N'50155', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

-- sp_LuuLopHoc: mã lớp dài nhất (TC450-yy01 = 10 ký tự) và hết số thứ tự trong năm
DECLARE @GVLop CHAR(6) = (SELECT TOP 1 g.MaGV FROM GIAOVIEN g JOIN NHANVIEN n ON n.MaNV = g.MaGV WHERE n.TrangThai = 1 ORDER BY g.MaGV);
DECLARE @NamSau DATE = DATEFROMPARTS(YEAR(GETDATE()) + 1, 3, 2), @MaLopMoi VARCHAR(10);
BEGIN TRY
    EXEC sp_LuuLopHoc @TenLop = N'TOEIC 450 thử', @MaKH = 'TC450', @MaCN = 'CN01', @MaGV = @GVLop, @NgayKhaiGiang = @NamSau,
                      @SiSoToiDa = 20, @MaLopMoi = @MaLopMoi OUTPUT;
    INSERT @KQ VALUES ('sp_LuuLopHoc', N'Mở lớp khoá mã 5 ký tự', N'OK', CONCAT(N'OK ', @MaLopMoi, N' (', LEN(@MaLopMoi), N' ký tự)'));
    INSERT LOPHOC (MaLop, TenLop, MaKH, MaCN, MaGV, NgayKhaiGiang, SiSoToiDa)
    VALUES (CONCAT('TC450-', RIGHT(YEAR(@NamSau), 2), '99'), N'Lớp thứ 99', 'TC450', 'CN01', @GVLop, @NamSau, 20);
    EXEC sp_LuuLopHoc @TenLop = N'Lớp thứ 100', @MaKH = 'TC450', @MaCN = 'CN01', @MaGV = @GVLop, @NgayKhaiGiang = @NamSau,
                      @SiSoToiDa = 20, @MaLopMoi = @MaLopMoi OUTPUT;
    INSERT @KQ VALUES ('sp_LuuLopHoc', N'Lớp thứ 100 của khoá trong năm', N'50156', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_LuuLopHoc', N'Lớp thứ 100 của khoá trong năm', N'50156', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

-- sp_LuuNhanVien: giáo viên đã có bảng lương không đổi được chức vụ (không mất lịch sử lương)
DECLARE @GVMoi CHAR(6);
BEGIN TRY
    EXEC sp_LuuNhanVien @HoNV = N'Thử', @TenNV = N'Lương', @NgaySinh = '1995-05-05', @GioiTinh = N'Nữ', @SoDienThoai = '0900000999',
                        @Email = 'thu.luong@ecms.test', @ChucVu = N'Giáo viên', @LuongCoBan = 5000000, @NgayVaoLam = '2025-01-02',
                        @MaCN = 'CN01', @LoaiGV = N'Việt Nam', @TrinhDo = N'Cử nhân', @DonGiaBuoi = 300000, @MaNVMoi = @GVMoi OUTPUT;
    INSERT BANGLUONG (Thang, MaGV, SoBuoiDay, DonGiaBuoi, LuongCoBan) VALUES ('2026-09', @GVMoi, 4, 300000, 5000000);
    EXEC sp_LuuNhanVien @MaNV = @GVMoi, @HoNV = N'Thử', @TenNV = N'Lương', @NgaySinh = '1995-05-05', @GioiTinh = N'Nữ',
                        @SoDienThoai = '0900000999', @Email = 'thu.luong@ecms.test', @ChucVu = N'Giáo vụ', @LuongCoBan = 5000000,
                        @NgayVaoLam = '2025-01-02', @MaCN = 'CN01';
    INSERT @KQ VALUES ('sp_LuuNhanVien', N'Đổi chức vụ giáo viên đã có bảng lương', N'50132', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_LuuNhanVien', N'Đổi chức vụ giáo viên đã có bảng lương', N'50132', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

-- sp_TinhLuongGiaoVien: tháng không hợp lệ
BEGIN TRY
    EXEC sp_TinhLuongGiaoVien '2026-13';
    INSERT @KQ VALUES ('sp_TinhLuongGiaoVien', N'Tháng 2026-13', N'50084', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_TinhLuongGiaoVien', N'Tháng 2026-13', N'50084', CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE())); END CATCH;

-- sp_SinhBuoiHoc lỗi khi đang ở trong transaction của người gọi: chỉ quay về savepoint, transaction ngoài vẫn còn
BEGIN TRY
    EXEC sp_SinhBuoiHoc 'KHONGCO', 0, @n OUTPUT;
    INSERT @KQ VALUES ('sp_SinhBuoiHoc', N'Lỗi trong transaction của người gọi', N'OK', N'không báo lỗi');
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_SinhBuoiHoc', N'Lỗi trong transaction của người gọi → giữ transaction ngoài', N'OK',
    CONCAT(IIF(@@TRANCOUNT = 1 AND XACT_STATE() = 1, N'OK ', N'SAI '), N'@@TRANCOUNT=', @@TRANCOUNT, N' – ', ERROR_NUMBER())); END CATCH;

-- sp_SinhBuoiHoc (cursor) và sp_SinhBuoiHoc_SetBased cho cùng kết quả
DECLARE @LopSinh VARCHAR(10) = (SELECT TOP 1 l.MaLop FROM LOPHOC l WHERE EXISTS (SELECT 1 FROM LICHHOC x WHERE x.MaLop = l.MaLop)
                                AND NOT EXISTS (SELECT 1 FROM DIEMDANH d WHERE d.MaLop = l.MaLop) ORDER BY l.MaLop);
DECLARE @B1 TABLE (STT INT, NgayHoc DATE, MaCa TINYINT, MaPhong VARCHAR(5), NoiDung NVARCHAR(200));
BEGIN TRY
    EXEC sp_SinhBuoiHoc @LopSinh, 1, @n OUTPUT;
    INSERT @B1 SELECT STT, NgayHoc, MaCa, MaPhong, NoiDung FROM BUOIHOC WHERE MaLop = @LopSinh;
    EXEC sp_SinhBuoiHoc_SetBased @LopSinh, 1, @n OUTPUT;
    SET @err = CONCAT((SELECT COUNT(*) FROM (SELECT * FROM @B1 EXCEPT SELECT STT, NgayHoc, MaCa, MaPhong, NoiDung FROM BUOIHOC WHERE MaLop = @LopSinh) x)
                    + (SELECT COUNT(*) FROM (SELECT STT, NgayHoc, MaCa, MaPhong, NoiDung FROM BUOIHOC WHERE MaLop = @LopSinh EXCEPT SELECT * FROM @B1) y),
                      N' dòng khác nhau');
    INSERT @KQ VALUES ('sp_SinhBuoiHoc_SetBased', CONCAT(N'Cursor và set-based sinh ', (SELECT COUNT(*) FROM @B1), N' buổi cho ', @LopSinh), N'0 dòng khác nhau', @err);
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_SinhBuoiHoc_SetBased', N'So sánh cursor / set-based', N'0 dòng khác nhau', ERROR_MESSAGE()); END CATCH;

-- sp_CapNhatTrangThaiLop: lớp Sắp mở đã tới ngày khai giảng và có học viên → Đang học
DECLARE @LopToi VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE TrangThai = N'Sắp mở' AND SiSoHienTai > 0 ORDER BY NgayKhaiGiang);
BEGIN TRY
    UPDATE LOPHOC SET NgayKhaiGiang = CAST(GETDATE() AS DATE) WHERE MaLop = @LopToi AND (NgayKetThuc IS NULL OR NgayKetThuc > CAST(GETDATE() AS DATE));
    EXEC sp_CapNhatTrangThaiLop @n OUTPUT;
    INSERT @KQ VALUES ('sp_CapNhatTrangThaiLop', CONCAT(N'Lớp ', @LopToi, N' tới ngày khai giảng'), N'OK Đang học',
        CONCAT(N'OK ', (SELECT TrangThai FROM LOPHOC WHERE MaLop = @LopToi), N' (', @n, N' lớp)'));
END TRY BEGIN CATCH INSERT @KQ VALUES ('sp_CapNhatTrangThaiLop', N'Chuyển trạng thái lớp', N'OK Đang học', ERROR_MESSAGE()); END CATCH;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;      -- hoàn tác mọi thay đổi của kiểm thử
INSERT #KQ (Procedure_, Ca, MongDoi, ThucTe) SELECT Procedure_, Ca, MongDoi, ThucTe FROM @KQ ORDER BY STT;
GO
SELECT STT, Procedure_ AS [Procedure], Ca, MongDoi, ThucTe, KetQua FROM #KQ ORDER BY STT;
DECLARE @fail INT = (SELECT COUNT(*) FROM #KQ WHERE KetQua = 'FAIL');
IF @fail > 0 THROW 50099, N'Có ca kiểm thử procedure thất bại.', 1;
PRINT N'✓ Tất cả ca kiểm thử procedure PASS.';
GO
