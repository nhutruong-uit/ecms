/* =====================================================================
   Kiểm thử phân quyền (T15) bằng EXECUTE AS USER: chứng minh quyền ĐƯỢC / KHÔNG ĐƯỢC
   của từng vai trò, và kiểm thử đăng nhập / băm mật khẩu.
   Chạy bằng tài khoản sysadmin (sa). Phần phân quyền chỉ đọc (quyền cấp thêm được REVOKE lại);
   phần đăng nhập chạy trong transaction rồi ROLLBACK.
   ===================================================================== */
USE ECMS;
SET NOCOUNT ON;
GO
DROP TABLE IF EXISTS #KQ;
CREATE TABLE #KQ (STT INT IDENTITY, NguoiDung SYSNAME, ThaoTac NVARCHAR(200), MongDoi NVARCHAR(80), ThucTe NVARCHAR(300),
                  KetQua AS (CASE WHEN ThucTe LIKE MongDoi + N'%' THEN 'PASS' ELSE 'FAIL' END));
GO
CREATE OR ALTER PROCEDURE #Thu @User SYSNAME, @Sql NVARCHAR(MAX), @MongDoi NVARCHAR(80), @MoTa NVARCHAR(200) = NULL
AS
BEGIN
    DECLARE @kq NVARCHAR(300);
    EXECUTE AS USER = @User;
    BEGIN TRY
        EXEC sp_set_session_context N'ma_cn', 'ALL';
        -- câu SELECT được bọc lại để không in kết quả ra màn hình (quyền vẫn được kiểm tra như thường)
        IF @Sql COLLATE DATABASE_DEFAULT LIKE N'SELECT %' SET @Sql = N'DECLARE @c INT; SELECT @c = COUNT(*) FROM (' + @Sql + N') x;';
        EXEC sp_executesql @Sql;
        SET @kq = N'ĐƯỢC';
    END TRY
    BEGIN CATCH
        SET @kq = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE());
    END CATCH
    REVERT;
    INSERT #KQ (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES (@User, ISNULL(@MoTa, @Sql), @MongDoi, @kq);
END
GO

-- Ứng dụng web: chỉ view / procedure, bảng gốc bị DENY
EXEC #Thu 'u_app', N'SELECT TOP 1 MaHV FROM dbo.HOCVIEN', N'BỊ CHẶN (229)';
EXEC #Thu 'u_app', N'SELECT TOP 1 MaLop FROM dbo.vw_SiSoLop', N'ĐƯỢC';
EXEC #Thu 'u_app', N'INSERT dbo.DANGKY (MaHV, MaLop, HocPhi) VALUES (''HV0001'', ''IE55-2601'', 1)', N'BỊ CHẶN (229)';
EXEC #Thu 'u_app', N'DECLARE @n INT; EXEC dbo.sp_TimKiemHocVien @TuKhoa = N''Lê'', @SoDongTrang = 1, @TongSo = @n OUTPUT', N'ĐƯỢC',
     N'EXEC sp_TimKiemHocVien (procedure đọc bảng HOCVIEN qua ownership chaining)';
EXEC #Thu 'u_app', N'SELECT TOP 1 * FROM dbo.fn_LopCuaGiaoVien(''NV0011'')', N'ĐƯỢC';
EXEC #Thu 'u_app', N'SELECT MatKhauHash FROM dbo.TAIKHOAN', N'BỊ CHẶN (229)';
-- Giáo vụ
EXEC #Thu 'u_giaovu', N'SELECT TOP 1 LuongCoBan FROM dbo.NHANVIEN', N'BỊ CHẶN (229)', N'Xem lương nhân viên';
EXEC #Thu 'u_giaovu', N'SELECT TOP 1 HoTen, ChucVu FROM dbo.vw_NhanVien_CongKhai', N'ĐƯỢC', N'Xem danh bạ qua view ẩn lương';
EXEC #Thu 'u_giaovu', N'INSERT dbo.PHIEUTHU (MaHV, MaNV) VALUES (''HV0001'', ''NV0004'')', N'BỊ CHẶN (229)', N'Tự lập phiếu thu';
EXEC #Thu 'u_giaovu', N'UPDATE dbo.HOCVIEN SET Email = Email WHERE MaHV = ''HV0001''', N'BỊ CHẶN (229)',
     N'Sửa thẳng bảng HOCVIEN (phải qua sp_LuuHocVien – không vượt lọc chi nhánh)';
-- Kế toán
EXEC #Thu 'u_ketoan', N'SELECT TOP 1 DiemCK FROM dbo.DANGKY', N'BỊ CHẶN (230)', N'Xem điểm (cột không được cấp)';
EXEC #Thu 'u_ketoan', N'SELECT TOP 1 ThanhTien, TrangThaiHP FROM dbo.DANGKY', N'ĐƯỢC', N'Xem học phí của đăng ký';
EXEC #Thu 'u_ketoan', N'UPDATE dbo.PHIEUTHU SET TongTien = 0 WHERE MaPT = 1', N'BỊ CHẶN (229)', N'Sửa phiếu thu đã lập';
EXEC #Thu 'u_ketoan', N'SELECT TOP 1 LuongCoBan FROM dbo.NHANVIEN', N'ĐƯỢC', N'Xem lương';
-- Quản lý
EXEC #Thu 'u_quanly', N'SELECT TOP 1 LuongCoBan FROM dbo.NHANVIEN', N'ĐƯỢC', N'Xem lương';
EXEC #Thu 'u_quanly', N'SELECT TOP 1 MatKhauHash FROM dbo.TAIKHOAN', N'BỊ CHẶN (230)', N'Xem hash mật khẩu (DENY cột thắng GRANT schema)';
EXEC #Thu 'u_quanly', N'SELECT TOP 1 TenDangNhap, VaiTro FROM dbo.TAIKHOAN', N'ĐƯỢC', N'Xem cột khác của TAIKHOAN';
EXEC #Thu 'u_quanly', N'DELETE dbo.CT_PHIEUTHU WHERE MaPT = 1', N'BỊ CHẶN (229)', N'Xoá chi tiết phiếu thu';
-- Giáo viên
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.PHIEUTHU', N'BỊ CHẶN (229)', N'Xem phiếu thu';
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.vw_CongNoHocVien', N'BỊ CHẶN (229)', N'Xem công nợ';
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.vw_BangDiem', N'ĐƯỢC', N'Xem bảng điểm';
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.vw_SiSoLop', N'BỊ CHẶN (229)', N'Xem sĩ số (chưa được cấp)';
-- WITH GRANT OPTION: quản lý cấp tiếp quyền cho giáo viên
EXEC #Thu 'u_quanly', N'GRANT SELECT ON dbo.vw_SiSoLop TO u_giaovien', N'ĐƯỢC', N'GRANT tiếp (nhờ WITH GRANT OPTION)';
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.vw_SiSoLop', N'ĐƯỢC', N'Xem sĩ số sau khi quản lý cấp';
EXEC #Thu 'u_giaovu', N'GRANT SELECT ON dbo.vw_SiSoLop TO u_hocvien', N'BỊ CHẶN', N'Giáo vụ cấp tiếp (không có GRANT OPTION)';
EXEC #Thu 'u_quanly', N'REVOKE SELECT ON dbo.vw_SiSoLop FROM u_giaovien', N'ĐƯỢC', N'Quản lý thu hồi quyền đã cấp (REVOKE)';
EXEC #Thu 'u_giaovien', N'SELECT TOP 1 * FROM dbo.vw_SiSoLop', N'BỊ CHẶN (229)', N'Xem sĩ số sau khi bị thu hồi';
-- Học viên
EXEC #Thu 'u_hocvien', N'SELECT TOP 1 * FROM dbo.HOCVIEN', N'BỊ CHẶN (229)', N'Xem danh sách học viên';
EXEC #Thu 'u_hocvien', N'SELECT * FROM dbo.fn_LichHocHocVien(''HV0004'', ''2026-10-15'')', N'ĐƯỢC', N'Xem lịch học';

GO
/* ---- Đăng nhập & băm mật khẩu: kết quả vào biến bảng @R (không bị ROLLBACK huỷ) ---- */
DECLARE @R TABLE (STT INT IDENTITY, NguoiDung SYSNAME, ThaoTac NVARCHAR(200), MongDoi NVARCHAR(80), ThucTe NVARCHAR(300));
BEGIN TRANSACTION;
DECLARE @tb NVARCHAR(200), @rc INT, @n INT;
DECLARE @U TABLE (TenDangNhap VARCHAR(30), VaiTro VARCHAR(10), MaNV CHAR(6), MaHV CHAR(6), HoTen NVARCHAR(71), MaCN CHAR(4), PhamViCN VARCHAR(4));
INSERT @U EXEC @rc = dbo.sp_DangNhap 'quanly', N'Ecms@2026', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) SELECT 'quanly', N'sp_DangNhap đúng mật khẩu', N'OK',
    CONCAT(IIF(@rc = 0, N'OK ', N'SAI '), (SELECT TOP 1 CONCAT(VaiTro, N' ', HoTen, N' phạm vi ', PhamViCN) FROM @U));
DELETE @U;
INSERT @U EXEC @rc = dbo.sp_DangNhap 'giaovu', N'Ecms@2026', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) SELECT 'giaovu', N'sp_DangNhap – giáo vụ chỉ thấy chi nhánh mình', N'OK',
    CONCAT(IIF(@rc = 0, N'OK ', N'SAI '), (SELECT TOP 1 CONCAT(VaiTro, N' phạm vi ', PhamViCN) FROM @U));
DECLARE @tb2 NVARCHAR(200);
EXEC @rc = dbo.sp_DangNhap 'quanly', N'sai-mat-khau', @tb OUTPUT;
EXEC dbo.sp_DangNhap 'khongtontai', N'abc', @tb2 OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('quanly / khongtontai',
    N'Sai mật khẩu và tài khoản không tồn tại: cùng một thông báo (không dò được tài khoản)', N'Giống nhau',
    IIF(@tb = @tb2 AND @tb = N'Sai tên đăng nhập hoặc mật khẩu.', N'Giống nhau: ' + @tb, CONCAT(N'Khác: ', @tb, N' / ', @tb2)));

DECLARE @hv1 CHAR(6), @hv2 CHAR(6), @hv3 CHAR(6);     -- học viên chưa có tài khoản
SELECT @hv1 = MIN(MaHV) FROM HOCVIEN h WHERE NOT EXISTS (SELECT 1 FROM TAIKHOAN t WHERE t.MaHV = h.MaHV);
SELECT @hv2 = MIN(MaHV) FROM HOCVIEN h WHERE MaHV > @hv1 AND NOT EXISTS (SELECT 1 FROM TAIKHOAN t WHERE t.MaHV = h.MaHV);
SELECT @hv3 = MIN(MaHV) FROM HOCVIEN h WHERE MaHV > @hv2 AND NOT EXISTS (SELECT 1 FROM TAIKHOAN t WHERE t.MaHV = h.MaHV);
EXEC dbo.sp_TaoTaiKhoan 'test.a', N'Test@12345', 'HocVien', NULL, @hv1;
EXEC dbo.sp_TaoTaiKhoan 'test.b', N'Test@12345', 'HocVien', NULL, @hv2;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe)
SELECT 'test.a / test.b', N'Cùng mật khẩu → salt và hash khác nhau', N'Khác nhau',
       IIF((SELECT MatKhauHash FROM TAIKHOAN WHERE TenDangNhap = 'test.a') <> (SELECT MatKhauHash FROM TAIKHOAN WHERE TenDangNhap = 'test.b'),
           N'Khác nhau: ' + CONVERT(NVARCHAR(20), (SELECT MatKhauHash FROM TAIKHOAN WHERE TenDangNhap = 'test.a'), 1) + N'… / '
                          + CONVERT(NVARCHAR(20), (SELECT MatKhauHash FROM TAIKHOAN WHERE TenDangNhap = 'test.b'), 1) + N'…', N'Giống nhau');
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe)
SELECT 'fn_BamMatKhau', N'Băm lặp 10.000 vòng ≠ một vòng SHA2_256', N'Khác nhau',
       IIF(dbo.fn_BamMatKhau(N'Test@12345', 0x01) <> HASHBYTES('SHA2_256', 0x01 + CAST(N'Test@12345' AS VARBINARY(200))), N'Khác nhau', N'Giống nhau');
SET @n = 0;
WHILE @n < 5 BEGIN EXEC dbo.sp_DangNhap 'test.a', N'sai', @tb OUTPUT; SET @n += 1; END
EXEC @rc = dbo.sp_DangNhap 'test.a', N'sai', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.a', N'Sai 5 lần rồi nhập SAI tiếp: không lộ trạng thái khoá', N'Sai tên đăng nhập hoặc mật khẩu.', @tb);
EXEC @rc = dbo.sp_DangNhap 'test.a', N'Test@12345', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.a', N'Sai 5 lần rồi nhập đúng → tạm khoá 15 phút', N'Tài khoản tạm khoá', @tb);
EXEC dbo.sp_CapNhatTaiKhoan 'test.a', @MatKhauMoi = N'Moi@12345';
EXEC @rc = dbo.sp_DangNhap 'test.a', N'Moi@12345', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.a', N'Quản lý đặt lại mật khẩu → gỡ tạm khoá, đăng nhập được', N'Đăng nhập thành công', @tb);
EXEC dbo.sp_DoiMatKhau 'test.b', N'sai-mat-khau', N'Moi@12345', @tb OUTPUT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.b', N'Đổi mật khẩu nhập sai mật khẩu cũ → tính vào số lần sai', N'Mật khẩu hiện tại không đúng. Số lần sai 1',
    CONCAT(@tb, N' Số lần sai ', (SELECT SoLanSai FROM TAIKHOAN WHERE TenDangNhap = 'test.b')));
BEGIN TRY EXEC dbo.sp_TaoTaiKhoan 'test.d', N'Test@12345', 'QuanLy', NULL, @hv3; SET @tb = N'không báo lỗi'; END TRY
BEGIN CATCH SET @tb = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.d', N'Tạo tài khoản học viên với vai trò QuanLy', N'50098', @tb);
BEGIN TRY EXEC dbo.sp_TaoTaiKhoan 'Test.E', N'Test@12345', 'HocVien', NULL, @hv3; SET @tb = N'không báo lỗi'; END TRY
BEGIN CATCH SET @tb = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('Test.E', N'Tên đăng nhập có chữ hoa', N'50093', @tb);
BEGIN TRY EXEC dbo.sp_TaoTaiKhoan 'test.c', N'12345678', 'HocVien', NULL, @hv3; SET @tb = N'không báo lỗi'; END TRY
BEGIN CATCH SET @tb = CONCAT(ERROR_NUMBER(), N' ', ERROR_MESSAGE()); END CATCH;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('test.c', N'Tạo tài khoản mật khẩu yếu', N'50091', @tb);

/* ---- Phân quyền mức dòng: login minh hoạ không mở rộng phạm vi bằng cách tự đặt SESSION_CONTEXT ---- */
DECLARE @hvCN02 CHAR(6) = (SELECT MIN(MaHV) FROM HOCVIEN WHERE MaCN = 'CN02');
DECLARE @h TABLE (HoHV NVARCHAR(50), TenHV NVARCHAR(20), NgaySinh DATE, GioiTinh NVARCHAR(3), SoDienThoai VARCHAR(15), Email VARCHAR(100),
                  SoNha NVARCHAR(100), PhuongXa NVARCHAR(50), QuanHuyen NVARCHAR(50), TinhTP NVARCHAR(50), HoTenPhuHuynh NVARCHAR(70));
INSERT @h SELECT HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, SoNha, PhuongXa, QuanHuyen, TinhTP, HoTenPhuHuynh FROM HOCVIEN WHERE MaHV = @hvCN02;
DECLARE @Ho NVARCHAR(50), @Ten NVARCHAR(20), @NS DATE, @GT NVARCHAR(3), @SDT VARCHAR(15), @Em VARCHAR(100), @PH NVARCHAR(70);
SELECT @Ho = HoHV, @Ten = TenHV, @NS = NgaySinh, @GT = GioiTinh, @SDT = SoDienThoai, @Em = Email, @PH = HoTenPhuHuynh FROM @h;
DECLARE @lopKhac VARCHAR(10) = (SELECT TOP 1 MaLop FROM LOPHOC WHERE MaGV <> 'NV0012' AND TrangThai = N'Đang học' ORDER BY MaLop);
DECLARE @ngayHV DATE = (SELECT TOP 1 b.NgayHoc FROM DANGKY d JOIN BUOIHOC b ON b.MaLop = d.MaLop
                        WHERE d.MaHV = 'HV0016' AND d.TrangThai = N'Đang học' ORDER BY b.NgayHoc);

EXECUTE AS USER = 'u_giaovu';
EXEC sp_set_session_context N'ma_cn', 'ALL';                      -- login minh hoạ tự khai "xem tất cả"
SELECT @n = COUNT(*) FROM dbo.vw_HocVien_ChiNhanh WHERE MaCN <> 'CN01';
SET @tb = CONCAT(@n, N' dòng');
SELECT @n = COUNT(*) FROM dbo.vw_HocVien_ChiNhanh WHERE MaCN = 'CN01';
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_giaovu', N'Tự đặt SESSION_CONTEXT ma_cn = ALL rồi xem học viên chi nhánh khác', N'0 dòng',
    CONCAT(@tb, N' (chi nhánh mình CN01: ', @n, N' dòng)'));
EXECUTE AS USER = 'u_giaovu';
BEGIN TRY
    EXEC dbo.sp_LuuHocVien @MaHV = @hvCN02, @HoHV = @Ho, @TenHV = @Ten, @NgaySinh = @NS, @GioiTinh = @GT, @SoDienThoai = @SDT,
                           @Email = @Em, @HoTenPhuHuynh = @PH, @MaCN = 'CN02';
    SET @tb = N'ĐƯỢC';
END TRY BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_giaovu', N'Sửa hồ sơ học viên chi nhánh khác qua sp_LuuHocVien', N'BỊ CHẶN (50097)', @tb);

EXECUTE AS USER = 'u_giaovien';                                  -- ↔ tài khoản 'giaovien' (NV0012)
SELECT @n = COUNT(*) FROM dbo.fn_LopCuaGiaoVien('NV0011');
SET @tb = CONCAT(@n, N' dòng');
SELECT @n = COUNT(*) FROM dbo.fn_LopCuaGiaoVien('NV0012');
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_giaovien', N'Xem lớp của giáo viên khác bằng cách đổi tham số', N'0 dòng',
    CONCAT(@tb, N' (lớp của mình: ', @n, N')'));
EXECUTE AS USER = 'u_hocvien';                                   -- ↔ tài khoản 'hocvien' (HV0016)
SELECT @n = COUNT(*) FROM dbo.fn_LichHocHocVien('HV0004', @ngayHV);
SET @tb = CONCAT(@n, N' dòng');
SELECT @n = COUNT(*) FROM dbo.fn_LichHocHocVien('HV0016', @ngayHV);
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_hocvien', N'Xem lịch học của học viên khác', N'0 dòng',
    CONCAT(@tb, N' (lịch của mình: ', @n, N')'));

-- Kết nối ứng dụng: kiểm tra quyền mặc định TỪ CHỐI
EXECUTE AS USER = 'u_app';
EXEC sp_set_session_context N'app_user', 'giaovien'; EXEC sp_set_session_context N'vai_tro', 'GiaoVien';
EXEC sp_set_session_context N'ma_nv', 'NV0012';      EXEC sp_set_session_context N'ma_cn', 'CN01';
BEGIN TRY EXEC dbo.sp_NhapDiem @lopKhac, N'[]'; SET @tb = N'ĐƯỢC'; END TRY
BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_app (giaovien)', N'Nhập điểm lớp của giáo viên khác', N'BỊ CHẶN (50043)', @tb);
EXECUTE AS USER = 'u_app';
EXEC sp_set_session_context N'app_user', NULL; EXEC sp_set_session_context N'vai_tro', NULL; EXEC sp_set_session_context N'ma_nv', NULL;
BEGIN TRY EXEC dbo.sp_NhapDiem @lopKhac, N'[]'; SET @tb = N'ĐƯỢC'; END TRY
BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES (N'u_app (không ngữ cảnh)', N'Nhập điểm khi không có ngữ cảnh người dùng (fail-closed)', N'BỊ CHẶN (50043)', @tb);
EXECUTE AS USER = 'u_app';
EXEC sp_set_session_context N'app_user', 'ketoan'; EXEC sp_set_session_context N'vai_tro', 'KeToan'; EXEC sp_set_session_context N'ma_nv', 'NV0008';
BEGIN TRY EXEC dbo.sp_TaoTaiKhoan 'test.f', N'Test@12345', 'HocVien', NULL, @hv3; SET @tb = N'ĐƯỢC'; END TRY
BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_app (ketoan)', N'Kế toán tạo tài khoản', N'BỊ CHẶN (50096)', @tb);
EXECUTE AS USER = 'u_app';
BEGIN TRY
    DECLARE @pt INT;
    EXEC dbo.sp_ThuHocPhi @MaHV = 'HV0001', @MaNV = 'NV0009', @ChiTiet = N'[]', @MaPT = @pt OUTPUT;
    SET @tb = N'ĐƯỢC';
END TRY BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT @R (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_app (ketoan)', N'Lập phiếu thu dưới tên kế toán khác', N'BỊ CHẶN (50015)', @tb);
EXEC sp_set_session_context N'app_user', NULL; EXEC sp_set_session_context N'vai_tro', NULL;
EXEC sp_set_session_context N'ma_nv', NULL;    EXEC sp_set_session_context N'ma_cn', NULL;

ROLLBACK TRANSACTION;
INSERT #KQ (NguoiDung, ThaoTac, MongDoi, ThucTe) SELECT NguoiDung, ThaoTac, MongDoi, ThucTe FROM @R ORDER BY STT;
GO
/* ---- Ngữ cảnh read-only (như ứng dụng đặt sau đăng nhập): không ghi đè được trong phiên. Đặt cuối vì giữ tới hết phiên ---- */
DECLARE @tb NVARCHAR(300);
EXECUTE AS USER = 'u_app';
EXEC sp_set_session_context N'ma_cn', 'CN01', @read_only = 1;
BEGIN TRY EXEC sp_set_session_context N'ma_cn', 'ALL'; SET @tb = N'ĐƯỢC'; END TRY
BEGIN CATCH SET @tb = CONCAT(N'BỊ CHẶN (', ERROR_NUMBER(), N') ', ERROR_MESSAGE()); END CATCH;
REVERT;
INSERT #KQ (NguoiDung, ThaoTac, MongDoi, ThucTe) VALUES ('u_app', N'Ghi đè ma_cn đã đặt read-only (giả lập câu lệnh bị chèn mã)', N'BỊ CHẶN (15664)', @tb);
GO
SELECT STT, NguoiDung, ThaoTac, MongDoi, ThucTe, KetQua FROM #KQ ORDER BY STT;
IF EXISTS (SELECT 1 FROM #KQ WHERE KetQua = 'FAIL') THROW 50099, N'Có ca kiểm thử phân quyền thất bại.', 1;
PRINT N'✓ Tất cả ca kiểm thử phân quyền PASS.';
GO
