/* =====================================================================
   ECMS – 04_views.sql : view bảo mật và view phục vụ báo cáo / form   (T16)
   Ứng dụng web (r_App) chỉ SELECT trên view, không truy cập bảng gốc (T15).
   Chạy lại được: CREATE OR ALTER VIEW.
   Lưu ý: indexed view yêu cầu QUOTED_IDENTIFIER, ANSI_NULLS ON khi tạo và khi
   ghi vào bảng gốc (SSMS, pyodbc mặc định ON; sqlcmd cần tham số -I).
   ===================================================================== */
USE ECMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   1. VIEW BẢO MẬT
   --------------------------------------------------------------------- */

-- Thông tin nhân viên công khai: ẩn lương, ngày sinh (giới hạn theo CỘT)
CREATE OR ALTER VIEW dbo.vw_NhanVien_CongKhai
AS
SELECT nv.MaNV, nv.HoNV, nv.TenNV, nv.HoTen, nv.GioiTinh, nv.SoDienThoai, nv.Email, nv.ChucVu,
       nv.MaCN, cn.TenCN, nv.MaNVQuanLy, ql.HoTen AS NguoiQuanLy, nv.NgayVaoLam, nv.TrangThai,
       gv.LoaiGV, gv.QuocTich, gv.TrinhDo
FROM dbo.NHANVIEN nv
JOIN dbo.CHINHANH cn ON cn.MaCN = nv.MaCN
LEFT JOIN dbo.NHANVIEN ql ON ql.MaNV = nv.MaNVQuanLy
LEFT JOIN dbo.GIAOVIEN gv ON gv.MaGV = nv.MaNV;
GO

-- Học viên của chi nhánh người dùng đang đăng nhập (giới hạn theo DÒNG – row-level).
-- Ứng dụng gọi sp_set_session_context N'ma_cn' sau khi đăng nhập (T19);
-- giá trị 'ALL' dành cho quản lý trung tâm. Không đặt context → không thấy dòng nào.
CREATE OR ALTER VIEW dbo.vw_HocVien_ChiNhanh
AS
SELECT h.MaHV, h.HoHV, h.TenHV, h.HoTen, h.NgaySinh, h.Tuoi, h.GioiTinh, h.SoDienThoai, h.Email,
       h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP,
       CONCAT_WS(N', ', h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP) AS DiaChi,
       h.HoTenPhuHuynh, h.NgayTao, h.MaCN, cn.TenCN, h.TrangThai
FROM dbo.HOCVIEN h
JOIN dbo.CHINHANH cn ON cn.MaCN = h.MaCN
WHERE CAST(SESSION_CONTEXT(N'ma_cn') AS VARCHAR(4)) IN (h.MaCN, 'ALL');
GO

-- Lịch dạy của giáo viên: chỉ thông tin lịch, không có học viên, học phí, lương
CREATE OR ALTER VIEW dbo.vw_LichDayGiaoVien
AS
SELECT l.MaGV, nv.HoTen AS GiaoVien, b.NgayHoc,
       CASE DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 WHEN 6 THEN N'Chủ nhật'
            ELSE N'Thứ ' + CAST(DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 + 2 AS NVARCHAR(1)) END AS Thu,
       c.MaCa, c.TenCa, c.GioBatDau, c.GioKetThuc, l.MaLop, k.TenKH, l.MaCN, b.MaPhong,
       b.STT AS BuoiThu, b.NoiDung, b.TrangThai
FROM dbo.BUOIHOC b
JOIN dbo.LOPHOC l   ON l.MaLop = b.MaLop
JOIN dbo.KHOAHOC k  ON k.MaKH = l.MaKH
JOIN dbo.CAHOC c    ON c.MaCa = b.MaCa
JOIN dbo.NHANVIEN nv ON nv.MaNV = l.MaGV;
GO

/* ---------------------------------------------------------------------
   2. VIEW NGHIỆP VỤ / BÁO CÁO
   --------------------------------------------------------------------- */

-- Đăng ký chi tiết (nguồn cho form ghi danh; INSTEAD OF trigger ở T13 cho phép INSERT qua view)
CREATE OR ALTER VIEW dbo.vw_DangKyChiTiet
AS
SELECT d.MaDK, d.MaHV, h.HoTen AS HoTenHV, h.SoDienThoai, d.MaLop, l.TenLop, l.MaKH, k.TenKH, l.MaCN,
       l.NgayKhaiGiang, l.TrangThai AS TrangThaiLop, d.NgayDK, d.HocPhi, d.GiamGia, d.ThanhTien,
       d.HanDongHP, d.TrangThaiHP, d.DiemGK, d.DiemCK, d.DiemTB, d.KetQua, d.TrangThai
FROM dbo.DANGKY d
JOIN dbo.HOCVIEN h  ON h.MaHV = d.MaHV
JOIN dbo.LOPHOC l   ON l.MaLop = d.MaLop
JOIN dbo.KHOAHOC k  ON k.MaKH = l.MaKH;
GO

-- Công nợ theo từng đăng ký chưa đóng đủ
CREATE OR ALTER VIEW dbo.vw_CongNoHocVien
AS
SELECT d.MaDK, d.MaHV, h.HoTen, h.SoDienThoai, d.MaLop, k.TenKH, l.MaCN,
       d.ThanhTien, ISNULL(t.DaThu, 0) AS DaThu, d.ThanhTien - ISNULL(t.DaThu, 0) AS ConNo,
       d.HanDongHP, d.TrangThaiHP,
       CASE WHEN d.HanDongHP < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS QuaHan,
       CASE WHEN d.HanDongHP < CAST(GETDATE() AS DATE) THEN DATEDIFF(DAY, d.HanDongHP, GETDATE()) ELSE 0 END AS SoNgayQuaHan
FROM dbo.DANGKY d
JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV
JOIN dbo.LOPHOC l  ON l.MaLop = d.MaLop
JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
OUTER APPLY (SELECT SUM(c.SoTien) AS DaThu FROM dbo.CT_PHIEUTHU c WHERE c.MaDK = d.MaDK) t
WHERE d.TrangThai <> N'Huỷ' AND d.ThanhTien > ISNULL(t.DaThu, 0);
GO

-- Bảng điểm: điểm, xếp loại, chuyên cần của mọi đăng ký
CREATE OR ALTER VIEW dbo.vw_BangDiem
AS
SELECT d.MaDK, d.MaLop, l.TenLop, k.TenKH, l.MaGV, d.MaHV, h.HoTen, d.DiemGK, d.DiemCK, d.DiemTB,
       dbo.fn_XepLoai(d.DiemTB) AS XepLoai, dbo.fn_TyLeChuyenCan(d.MaDK) AS ChuyenCan, d.KetQua, d.TrangThai
FROM dbo.DANGKY d
JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV
JOIN dbo.LOPHOC l  ON l.MaLop = d.MaLop
JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
WHERE d.TrangThai IN (N'Đang học', N'Hoàn thành');
GO

-- Doanh thu theo chi nhánh (của lớp) và tháng – INDEXED VIEW (kết quả gộp được lưu sẵn)
CREATE OR ALTER VIEW dbo.vw_DoanhThuThang
WITH SCHEMABINDING
AS
SELECT l.MaCN, YEAR(p.NgayThu) AS Nam, MONTH(p.NgayThu) AS Thang,
       SUM(c.SoTien) AS DoanhThu, COUNT_BIG(*) AS SoDongThu
FROM dbo.CT_PHIEUTHU c
JOIN dbo.PHIEUTHU p ON p.MaPT = c.MaPT
JOIN dbo.DANGKY d   ON d.MaDK = c.MaDK
JOIN dbo.LOPHOC l   ON l.MaLop = d.MaLop
GROUP BY l.MaCN, YEAR(p.NgayThu), MONTH(p.NgayThu);
GO
CREATE UNIQUE CLUSTERED INDEX IXV_DoanhThuThang ON dbo.vw_DoanhThuThang (MaCN, Nam, Thang);
GO

-- Sĩ số và tỷ lệ lấp đầy từng lớp
CREATE OR ALTER VIEW dbo.vw_SiSoLop
AS
SELECT l.MaLop, l.TenLop, l.MaKH, k.TenKH, k.MaCT, l.MaCN, cn.TenCN, l.MaGV, nv.HoTen AS GiaoVien,
       l.NgayKhaiGiang, l.NgayKetThuc, l.SiSoToiDa, l.SiSoHienTai,
       l.SiSoToiDa - l.SiSoHienTai AS ConCho,
       CAST(100.0 * l.SiSoHienTai / l.SiSoToiDa AS DECIMAL(5,1)) AS TyLeLapDay, l.TrangThai,
       STUFF((SELECT N', ' + CASE lh.Thu WHEN 8 THEN N'CN' ELSE N'T' + CAST(lh.Thu AS NVARCHAR(1)) END
                         + N' ' + c.TenCa + N' (' + lh.MaPhong + N')'
              FROM dbo.LICHHOC lh JOIN dbo.CAHOC c ON c.MaCa = lh.MaCa
              WHERE lh.MaLop = l.MaLop ORDER BY lh.Thu FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(200)'), 1, 2, N'') AS Lich
FROM dbo.LOPHOC l
JOIN dbo.KHOAHOC k   ON k.MaKH = l.MaKH
JOIN dbo.CHINHANH cn ON cn.MaCN = l.MaCN
JOIN dbo.NHANVIEN nv ON nv.MaNV = l.MaGV;
GO

-- Lớp đang mở tuyển / đang học – view CẬP NHẬT ĐƯỢC với WITH CHECK OPTION:
-- không cho sửa qua view làm dòng "rơi" khỏi view (VD chuyển lớp sang Đã kết thúc)
CREATE OR ALTER VIEW dbo.vw_LopHoc_DangMo
AS
SELECT MaLop, TenLop, MaKH, MaCN, MaGV, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai, TrangThai
FROM dbo.LOPHOC
WHERE TrangThai IN (N'Sắp mở', N'Đang học')
WITH CHECK OPTION;
GO

PRINT N'✓ 04_views.sql: 3 view bảo mật, 6 view nghiệp vụ (1 indexed view, 1 WITH CHECK OPTION).';
GO
