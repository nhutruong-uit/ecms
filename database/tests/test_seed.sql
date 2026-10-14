/* Kiểm tra tính nhất quán của dữ liệu mẫu (T08). Mọi dòng phải có SoLoi = 0.
   sqlcmd ... -i database/tests/test_seed.sql   (chạy sau 02_seed.sql)                      */
USE ECMS;
SET NOCOUNT ON;
DECLARE @KQ TABLE (KiemTra NVARCHAR(100), SoLoi INT);

INSERT @KQ SELECT N'Sĩ số hiện tại = số đăng ký đang học/hoàn thành', COUNT(*) FROM LOPHOC l
WHERE SiSoHienTai <> (SELECT COUNT(*) FROM DANGKY d WHERE d.MaLop = l.MaLop AND d.TrangThai IN (N'Đang học', N'Hoàn thành'));

INSERT @KQ SELECT N'Tổng tiền phiếu thu = tổng chi tiết', COUNT(*) FROM PHIEUTHU p
WHERE TongTien <> (SELECT ISNULL(SUM(SoTien), 0) FROM CT_PHIEUTHU c WHERE c.MaPT = p.MaPT);

INSERT @KQ SELECT N'Không thu vượt thành tiền', COUNT(*) FROM DANGKY d
WHERE ThanhTien < (SELECT ISNULL(SUM(SoTien), 0) FROM CT_PHIEUTHU c WHERE c.MaDK = d.MaDK);

INSERT @KQ SELECT N'Chi tiết phiếu thu đúng học viên', COUNT(*) FROM CT_PHIEUTHU c
JOIN PHIEUTHU p ON p.MaPT = c.MaPT JOIN DANGKY d ON d.MaDK = c.MaDK WHERE d.MaHV <> p.MaHV;

INSERT @KQ SELECT N'Trạng thái học phí khớp số tiền đã thu', COUNT(*) FROM DANGKY d
CROSS APPLY (SELECT ISNULL(SUM(SoTien), 0) AS DaThu FROM CT_PHIEUTHU c WHERE c.MaDK = d.MaDK) x
WHERE TrangThaiHP <> CASE WHEN x.DaThu >= d.ThanhTien THEN N'Đã đóng' WHEN x.DaThu > 0 THEN N'Đóng một phần' ELSE N'Chưa đóng' END;

INSERT @KQ SELECT N'Không trùng phòng (cùng thứ, ca, thời gian)', COUNT(*) FROM LICHHOC a
JOIN LICHHOC b ON a.MaCN = b.MaCN AND a.MaPhong = b.MaPhong AND a.Thu = b.Thu AND a.MaCa = b.MaCa AND a.MaLop < b.MaLop
JOIN LOPHOC la ON la.MaLop = a.MaLop JOIN LOPHOC lb ON lb.MaLop = b.MaLop
WHERE la.NgayKhaiGiang <= lb.NgayKetThuc AND lb.NgayKhaiGiang <= la.NgayKetThuc;

INSERT @KQ SELECT N'Không trùng lịch giáo viên', COUNT(*) FROM LICHHOC a
JOIN LICHHOC b ON a.Thu = b.Thu AND a.MaCa = b.MaCa AND a.MaLop < b.MaLop
JOIN LOPHOC la ON la.MaLop = a.MaLop JOIN LOPHOC lb ON lb.MaLop = b.MaLop
WHERE la.MaGV = lb.MaGV AND la.NgayKhaiGiang <= lb.NgayKetThuc AND lb.NgayKhaiGiang <= la.NgayKetThuc;

INSERT @KQ SELECT N'Đủ điều kiện khoá tiên quyết (đã Đạt hoặc test đầu vào đủ điểm)', COUNT(*) FROM DANGKY d
JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
WHERE k.MaKHTienQuyet IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM DANGKY d2 JOIN LOPHOC l2 ON l2.MaLop = d2.MaLop
                  WHERE d2.MaHV = d.MaHV AND l2.MaKH = k.MaKHTienQuyet AND d2.KetQua = N'Đạt')
  AND NOT EXISTS (SELECT 1 FROM KIEMTRA_DAUVAO t WHERE t.MaHV = d.MaHV AND t.DiemTong >= k.DiemDauVaoTu AND t.NgayKT <= d.NgayDK);

INSERT @KQ SELECT N'Kết quả khớp điểm TB', COUNT(*) FROM DANGKY
WHERE DiemTB IS NOT NULL AND KetQua <> CASE WHEN DiemTB >= 5 THEN N'Đạt' ELSE N'Không đạt' END;

INSERT @KQ SELECT N'Ngày đăng ký không trước ngày lập hồ sơ', COUNT(*) FROM DANGKY d
JOIN HOCVIEN h ON h.MaHV = d.MaHV WHERE d.NgayDK < h.NgayTao;

INSERT @KQ SELECT N'Buổi học không rơi vào ngày lễ', COUNT(*) FROM BUOIHOC b JOIN NGAYLE n ON n.Ngay = b.NgayHoc;

SELECT * FROM @KQ;
IF EXISTS (SELECT 1 FROM @KQ WHERE SoLoi > 0) THROW 50000, N'Dữ liệu mẫu không nhất quán.', 1;
PRINT N'✓ Dữ liệu mẫu nhất quán.';
