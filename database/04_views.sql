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
-- Phạm vi chi nhánh lấy từ dbo.fn_NguoiDungHienTai(): kết nối ứng dụng dùng SESSION_CONTEXT 'ma_cn' đặt
-- read-only sau khi đăng nhập; login minh hoạ (u_giaovu…) dùng chi nhánh của tài khoản cùng tên, tự gọi
-- sp_set_session_context cũng không mở rộng được. 'ALL' dành cho quản lý trung tâm.
-- Không xác định được người dùng → không thấy dòng nào.
CREATE OR ALTER VIEW dbo.vw_HocVien_ChiNhanh
AS
SELECT h.MaHV, h.HoHV, h.TenHV, h.HoTen, h.NgaySinh, h.Tuoi, h.GioiTinh, h.SoDienThoai, h.Email,
       h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP,
       CONCAT_WS(N', ', h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP) AS DiaChi,
       h.HoTenPhuHuynh, h.NgayTao, h.MaCN, cn.TenCN, h.TrangThai
FROM dbo.HOCVIEN h
JOIN dbo.CHINHANH cn ON cn.MaCN = h.MaCN
WHERE EXISTS (SELECT 1 FROM dbo.fn_NguoiDungHienTai() u WHERE u.PhamViCN IN (h.MaCN, 'ALL'));
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
WHERE d.TrangThai NOT IN (N'Huỷ', N'Đã chuyển lớp') AND d.ThanhTien > ISNULL(t.DaThu, 0);
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

/* ---------------------------------------------------------------------
   3. VIEW DANH MỤC cho form của ứng dụng web (T19)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DM_ChiNhanh
AS
SELECT cn.MaCN, cn.TenCN, cn.DiaChi, cn.SoDienThoai, cn.NgayThanhLap, cn.MaNVQuanLy, nv.HoTen AS QuanLy,
       (SELECT COUNT(*) FROM dbo.PHONGHOC p WHERE p.MaCN = cn.MaCN) AS SoPhong,
       (SELECT COUNT(*) FROM dbo.NHANVIEN n WHERE n.MaCN = cn.MaCN AND n.TrangThai = 1) AS SoNhanVien,
       (SELECT COUNT(*) FROM dbo.LOPHOC l WHERE l.MaCN = cn.MaCN AND l.TrangThai IN (N'Sắp mở', N'Đang học')) AS SoLopDangMo
FROM dbo.CHINHANH cn LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = cn.MaNVQuanLy;
GO

CREATE OR ALTER VIEW dbo.vw_DM_PhongHoc
AS
SELECT p.MaCN, cn.TenCN, p.MaPhong, p.SucChua, p.LoaiPhong,
       (SELECT COUNT(*) FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop
        WHERE lh.MaCN = p.MaCN AND lh.MaPhong = p.MaPhong AND l.TrangThai IN (N'Sắp mở', N'Đang học')) AS SoLichDangDung
FROM dbo.PHONGHOC p JOIN dbo.CHINHANH cn ON cn.MaCN = p.MaCN;
GO

CREATE OR ALTER VIEW dbo.vw_DM_CaHoc
AS
SELECT MaCa, TenCa, GioBatDau, GioKetThuc, DATEDIFF(MINUTE, GioBatDau, GioKetThuc) AS SoPhut FROM dbo.CAHOC;
GO

-- Đầy đủ thông tin nhân viên (gồm lương) – ứng dụng chỉ hiển thị cột lương cho Quản lý / Kế toán
CREATE OR ALTER VIEW dbo.vw_NhanVien
AS
SELECT nv.MaNV, nv.HoNV, nv.TenNV, nv.HoTen, nv.NgaySinh, nv.GioiTinh, nv.SoDienThoai, nv.Email, nv.ChucVu, nv.LuongCoBan,
       nv.NgayVaoLam, nv.MaCN, cn.TenCN, nv.MaNVQuanLy, ql.HoTen AS NguoiQuanLy, nv.TrangThai,
       gv.LoaiGV, gv.QuocTich, gv.TrinhDo, gv.DonGiaBuoi,
       (SELECT STRING_AGG(cc.TenChungChi + ISNULL(N' ' + FORMAT(cc.Diem, '0.#'), N''), N', ') FROM dbo.CHUNGCHI_GV cc WHERE cc.MaGV = nv.MaNV) AS ChungChi
FROM dbo.NHANVIEN nv
JOIN dbo.CHINHANH cn ON cn.MaCN = nv.MaCN
LEFT JOIN dbo.NHANVIEN ql ON ql.MaNV = nv.MaNVQuanLy
LEFT JOIN dbo.GIAOVIEN gv ON gv.MaGV = nv.MaNV;
GO

CREATE OR ALTER VIEW dbo.vw_ChungChiGV
AS
SELECT cc.MaGV, nv.HoTen, cc.TenChungChi, cc.Diem, cc.NgayCap, cc.NoiCap
FROM dbo.CHUNGCHI_GV cc JOIN dbo.NHANVIEN nv ON nv.MaNV = cc.MaGV;
GO

/* ---------------------------------------------------------------------
   4. VIEW PHÂN HỆ ĐÀO TẠO cho ứng dụng web (T20)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DM_ChuongTrinh
AS
SELECT ct.MaCT, ct.TenCT, ct.DoiTuong, ct.MoTa,
       (SELECT COUNT(*) FROM dbo.KHOAHOC k WHERE k.MaCT = ct.MaCT) AS SoKhoaHoc,
       (SELECT COUNT(*) FROM dbo.LOPHOC l JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
        WHERE k.MaCT = ct.MaCT AND l.TrangThai IN (N'Sắp mở', N'Đang học')) AS SoLopDangMo
FROM dbo.CHUONGTRINH ct;
GO

CREATE OR ALTER VIEW dbo.vw_DM_KhoaHoc
AS
SELECT k.MaKH, k.TenKH, k.MaCT, ct.TenCT, k.CapDo, k.DiemDauVaoTu, k.DiemDauVaoDen, k.MucTieuDauRa, k.SoBuoi, k.HocPhi,
       k.MaKHTienQuyet, tq.TenKH AS KhoaTienQuyet,
       (SELECT COUNT(*) FROM dbo.LOPHOC l WHERE l.MaKH = k.MaKH) AS SoLop
FROM dbo.KHOAHOC k
JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT
LEFT JOIN dbo.KHOAHOC tq ON tq.MaKH = k.MaKHTienQuyet;
GO

-- Lịch cố định của lớp (thứ – ca – phòng)
CREATE OR ALTER VIEW dbo.vw_LichHoc
AS
SELECT lh.MaLop, l.TenLop, l.MaCN, l.MaGV, lh.Thu,
       CASE lh.Thu WHEN 8 THEN N'Chủ nhật' ELSE N'Thứ ' + CAST(lh.Thu AS NVARCHAR(1)) END AS TenThu,
       lh.MaCa, c.TenCa, c.GioBatDau, c.GioKetThuc, lh.MaPhong, l.NgayKhaiGiang, l.NgayKetThuc, l.TrangThai
FROM dbo.LICHHOC lh JOIN dbo.LOPHOC l ON l.MaLop = lh.MaLop JOIN dbo.CAHOC c ON c.MaCa = lh.MaCa;
GO

-- Buổi học cụ thể kèm số học viên đã điểm danh
CREATE OR ALTER VIEW dbo.vw_BuoiHoc
AS
SELECT b.MaLop, l.TenLop, l.MaCN, l.MaGV, b.STT, b.NgayHoc,
       CASE DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 WHEN 6 THEN N'Chủ nhật'
            ELSE N'Thứ ' + CAST(DATEDIFF(DAY, '19000101', b.NgayHoc) % 7 + 2 AS NVARCHAR(1)) END AS Thu,
       b.MaCa, c.TenCa, c.GioBatDau, c.GioKetThuc, b.MaPhong, b.NoiDung, b.TrangThai,
       (SELECT COUNT(*) FROM dbo.DIEMDANH d WHERE d.MaLop = b.MaLop AND d.STT = b.STT) AS SoDaDiemDanh,
       (SELECT COUNT(*) FROM dbo.DIEMDANH d WHERE d.MaLop = b.MaLop AND d.STT = b.STT AND d.TrangThai = N'Vắng') AS SoVang
FROM dbo.BUOIHOC b JOIN dbo.LOPHOC l ON l.MaLop = b.MaLop JOIN dbo.CAHOC c ON c.MaCa = b.MaCa;
GO

/* ---------------------------------------------------------------------
   5. VIEW PHÂN HỆ HỌC TẬP cho ứng dụng web (T22)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_DiemDanh
AS
SELECT dd.MaDK, dd.MaLop, dd.STT, d.MaHV, h.HoTen, dd.TrangThai, dd.GhiChu
FROM dbo.DIEMDANH dd JOIN dbo.DANGKY d ON d.MaDK = dd.MaDK JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV;
GO

CREATE OR ALTER VIEW dbo.vw_CanhBao
AS
SELECT c.MaCB, c.MaDK, d.MaHV, h.HoTen, h.SoDienThoai, h.HoTenPhuHuynh, d.MaLop, l.MaGV, l.MaCN, c.NgayCanhBao,
       c.SoBuoiDaHoc, c.SoBuoiVang, c.TyLeVang, c.MucDo, c.DaXuLy
FROM dbo.CANHBAO_CHUYENCAN c JOIN dbo.DANGKY d ON d.MaDK = c.MaDK
JOIN dbo.HOCVIEN h ON h.MaHV = d.MaHV JOIN dbo.LOPHOC l ON l.MaLop = d.MaLop;
GO

/* ---------------------------------------------------------------------
   6. VIEW PHÂN HỆ TÀI CHÍNH cho ứng dụng web (T23)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_PhieuThu
AS
SELECT p.MaPT, p.SoPhieu, p.NgayThu, p.HinhThuc, p.TongTien, p.GhiChu, p.MaHV, h.HoTen AS HoTenHV, h.SoDienThoai,
       CONCAT_WS(N', ', h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP) AS DiaChiHV, h.MaCN,
       p.MaNV, nv.HoTen AS NguoiLap, cn.TenCN, cn.DiaChi AS DiaChiCN, cn.SoDienThoai AS DienThoaiCN,
       (SELECT COUNT(*) FROM dbo.CT_PHIEUTHU c WHERE c.MaPT = p.MaPT) AS SoDong
FROM dbo.PHIEUTHU p
JOIN dbo.HOCVIEN h   ON h.MaHV = p.MaHV
JOIN dbo.NHANVIEN nv ON nv.MaNV = p.MaNV
JOIN dbo.CHINHANH cn ON cn.MaCN = nv.MaCN;
GO

-- Chi tiết phiếu thu. DaThuTong / ConNo tính TẠI THỜI ĐIỂM LẬP PHIẾU (các khoản thu có MaPT ≤ phiếu này),
-- nên in lại một phiếu cũ vẫn ra đúng số liệu như lúc in lần đầu, không bị các lần đóng sau làm thay đổi.
CREATE OR ALTER VIEW dbo.vw_CTPhieuThu
AS
SELECT c.MaPT, c.MaDK, d.MaLop, k.TenKH, d.HocPhi, d.GiamGia, d.ThanhTien, c.SoTien,
       t.DaThuTong, d.ThanhTien - t.DaThuTong AS ConNo
FROM dbo.CT_PHIEUTHU c
JOIN dbo.DANGKY d  ON d.MaDK = c.MaDK
JOIN dbo.LOPHOC l  ON l.MaLop = d.MaLop
JOIN dbo.KHOAHOC k ON k.MaKH = l.MaKH
CROSS APPLY (SELECT SUM(c2.SoTien) AS DaThuTong FROM dbo.CT_PHIEUTHU c2 WHERE c2.MaDK = c.MaDK AND c2.MaPT <= c.MaPT) t;
GO

/* ---------------------------------------------------------------------
   7. VIEW BÁO CÁO & DASHBOARD (T24)
   --------------------------------------------------------------------- */
-- Từng khoản thu kèm chi nhánh của lớp, chương trình, khoá – nguồn cho báo cáo doanh thu nhiều chiều
CREATE OR ALTER VIEW dbo.vw_BaoCaoDoanhThu
AS
SELECT p.MaPT, p.SoPhieu, CAST(p.NgayThu AS DATE) AS NgayThu, YEAR(p.NgayThu) AS Nam, MONTH(p.NgayThu) AS Thang,
       DATEPART(QUARTER, p.NgayThu) AS Quy, p.HinhThuc, l.MaCN, cn.TenCN, k.MaCT, ct.TenCT, k.MaKH, k.TenKH, l.MaLop,
       d.MaHV, c.SoTien
FROM dbo.CT_PHIEUTHU c
JOIN dbo.PHIEUTHU p     ON p.MaPT = c.MaPT
JOIN dbo.DANGKY d       ON d.MaDK = c.MaDK
JOIN dbo.LOPHOC l       ON l.MaLop = d.MaLop
JOIN dbo.CHINHANH cn    ON cn.MaCN = l.MaCN
JOIN dbo.KHOAHOC k      ON k.MaKH = l.MaKH
JOIN dbo.CHUONGTRINH ct ON ct.MaCT = k.MaCT;
GO

CREATE OR ALTER VIEW dbo.vw_BangLuong
AS
SELECT b.Thang, b.MaGV, nv.HoTen, nv.MaCN, gv.LoaiGV, b.SoBuoiDay, b.DonGiaBuoi, b.LuongCoBan, b.TongLuong, b.NgayTinh
FROM dbo.BANGLUONG b JOIN dbo.NHANVIEN nv ON nv.MaNV = b.MaGV JOIN dbo.GIAOVIEN gv ON gv.MaGV = b.MaGV;
GO

PRINT N'✓ 04_views.sql: 3 view bảo mật, 6 view nghiệp vụ (1 indexed view, 1 WITH CHECK OPTION), 5 view danh mục, 4 view đào tạo, 2 view học tập, 2 view tài chính, 2 view báo cáo.';
GO
