/* =====================================================================
   ECMS – 10_queries.sql : truy vấn nghiệp vụ (demo, không cần cho ứng dụng)   (T09)
   30 câu, 6 nhóm kỹ thuật. Ngày tham chiếu của dữ liệu mẫu: 15/10/2026.
   Chạy từng câu (bôi đen + F5 trong SSMS) hoặc cả file.
   ===================================================================== */
USE ECMS;
GO
SET NOCOUNT ON;

/* =========================== NHÓM 1 – CƠ BẢN ============================ */

-- Q01. Học viên họ "Nguyễn" hoặc "Trần" ở chi nhánh Thủ Đức, sắp xếp theo tên.   [LIKE, IN, ORDER BY]
SELECT MaHV, HoHV, TenHV, SoDienThoai, MaCN
FROM HOCVIEN
WHERE (HoHV LIKE N'Nguyễn%' OR HoHV LIKE N'Trần%') AND MaCN IN ('CN01')
ORDER BY TenHV, HoHV;

-- Q02. Khoá học có học phí từ 4 đến 6 triệu, rẻ nhất trước.                      [BETWEEN]
SELECT MaKH, TenKH, MaCT, SoBuoi, HocPhi, HocPhi / SoBuoi AS HocPhiMoiBuoi
FROM KHOAHOC
WHERE HocPhi BETWEEN 4000000 AND 6000000
ORDER BY HocPhi;

-- Q03. Học viên chưa có email (cần bổ sung hồ sơ).                                 [IS NULL]
SELECT MaHV, HoTen, Tuoi, SoDienThoai, HoTenPhuHuynh
FROM HOCVIEN
WHERE Email IS NULL
ORDER BY Tuoi;

-- Q04. 5 phiếu thu có giá trị lớn nhất năm 2026.                                   [TOP, ORDER BY DESC]
SELECT TOP (5) WITH TIES SoPhieu, MaHV, NgayThu, HinhThuc, TongTien
FROM PHIEUTHU
WHERE NgayThu >= '2026-01-01' AND NgayThu < '2027-01-01'
ORDER BY TongTien DESC;

-- Q05. Lớp khai giảng trong quý IV/2026 chưa đạt 60% sĩ số (cần đẩy tuyển sinh).
SELECT MaLop, TenLop, NgayKhaiGiang, SiSoHienTai, SiSoToiDa
FROM LOPHOC
WHERE NgayKhaiGiang BETWEEN '2026-10-01' AND '2026-12-31' AND SiSoHienTai < 0.6 * SiSoToiDa;

/* =========================== NHÓM 2 – KẾT NỐI =========================== */

-- Q06. Danh sách lớp đang học: khoá, chi nhánh, giáo viên, lịch.                 [INNER JOIN ≥ 4 bảng]
SELECT l.MaLop, k.TenKH, cn.TenCN, nv.HoTen AS GiaoVien,
       STRING_AGG(CONCAT(N'T', lh.Thu, N' ', c.TenCa, N' (', lh.MaPhong, N')'), N', ') AS Lich
FROM LOPHOC l
JOIN KHOAHOC k   ON k.MaKH = l.MaKH
JOIN CHINHANH cn ON cn.MaCN = l.MaCN
JOIN NHANVIEN nv ON nv.MaNV = l.MaGV
JOIN LICHHOC lh  ON lh.MaLop = l.MaLop
JOIN CAHOC c     ON c.MaCa = lh.MaCa
WHERE l.TrangThai = N'Đang học'
GROUP BY l.MaLop, k.TenKH, cn.TenCN, nv.HoTen;

-- Q07. Mọi giáo viên và số lớp đã/đang dạy, kể cả giáo viên chưa có lớp.          [LEFT JOIN]
SELECT gv.MaGV, nv.HoTen, gv.LoaiGV, COUNT(l.MaLop) AS SoLop
FROM GIAOVIEN gv
JOIN NHANVIEN nv ON nv.MaNV = gv.MaGV
LEFT JOIN LOPHOC l ON l.MaGV = gv.MaGV
GROUP BY gv.MaGV, nv.HoTen, gv.LoaiGV
ORDER BY SoLop DESC;

-- Q08. Phòng học chưa từng được xếp lịch.                                        [RIGHT JOIN + IS NULL]
SELECT p.MaCN, p.MaPhong, p.LoaiPhong, p.SucChua
FROM LICHHOC lh
RIGHT JOIN PHONGHOC p ON p.MaCN = lh.MaCN AND p.MaPhong = lh.MaPhong
WHERE lh.MaLop IS NULL;

-- Q09. Cung – cầu theo khoá học: "cầu" = khách tiềm năng (được kiểm tra đầu vào đề xuất khoá nhưng chưa ghi danh
--      khoá đó), "cung" = số chỗ trống của các lớp còn nhận ghi danh. Hai tập độc lập nên CẢ HAI phía đều có thể
--      không khớp: có khách mà không còn lớp nhận (cần mở lớp) và còn chỗ mà chưa có khách (cần tư vấn).  [FULL OUTER JOIN]
SELECT COALESCE(cau.MaKH, cung.MaKH) AS MaKH, ISNULL(cau.SoTiemNang, 0) AS KhachTiemNang, ISNULL(cung.SoChoTrong, 0) AS ChoTrong,
       CASE WHEN cung.MaKH IS NULL THEN N'Có khách, không còn lớp nhận'
            WHEN cau.MaKH IS NULL THEN N'Còn chỗ, chưa có khách' ELSE N'Khớp' END AS NhanXet
FROM (SELECT t.MaKHDeXuat AS MaKH, COUNT(DISTINCT t.MaHV) AS SoTiemNang
      FROM KIEMTRA_DAUVAO t
      WHERE t.MaKHDeXuat IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE d.MaHV = t.MaHV AND l.MaKH = t.MaKHDeXuat)
      GROUP BY t.MaKHDeXuat) cau
FULL OUTER JOIN
     (SELECT MaKH, SUM(SiSoToiDa - SiSoHienTai) AS SoChoTrong
      FROM LOPHOC WHERE TrangThai IN (N'Sắp mở', N'Đang học') AND SiSoHienTai < SiSoToiDa GROUP BY MaKH) cung
  ON cung.MaKH = cau.MaKH
ORDER BY NhanXet, MaKH;

-- Q10. Nhân viên và người quản lý trực tiếp.                                     [SELF JOIN]
SELECT nv.MaNV, nv.HoTen, nv.ChucVu, nv.MaCN, ql.HoTen AS NguoiQuanLy, ql.ChucVu AS ChucVuQL
FROM NHANVIEN nv
LEFT JOIN NHANVIEN ql ON ql.MaNV = nv.MaNVQuanLy
ORDER BY nv.MaCN, ql.HoTen;

/* =========================== NHÓM 3 – GOM NHÓM ========================== */

-- Q11. Doanh thu theo chi nhánh (của lớp) và tháng năm 2026.                     [GROUP BY, SUM]
SELECT l.MaCN, FORMAT(p.NgayThu, 'yyyy-MM') AS Thang, COUNT(DISTINCT p.MaPT) AS SoPhieu, SUM(c.SoTien) AS DoanhThu
FROM CT_PHIEUTHU c
JOIN PHIEUTHU p ON p.MaPT = c.MaPT
JOIN DANGKY d   ON d.MaDK = c.MaDK
JOIN LOPHOC l   ON l.MaLop = d.MaLop
WHERE p.NgayThu >= '2026-01-01'
GROUP BY l.MaCN, FORMAT(p.NgayThu, 'yyyy-MM')
ORDER BY l.MaCN, Thang;

-- Q12. Sĩ số trung bình, nhỏ nhất, lớn nhất theo khoá học; chỉ khoá mở ≥ 2 lớp.  [AVG, MIN, MAX, HAVING]
SELECT k.TenKH, COUNT(*) AS SoLop, AVG(CAST(l.SiSoHienTai AS DECIMAL(5,1))) AS SiSoTB,
       MIN(l.SiSoHienTai) AS ItNhat, MAX(l.SiSoHienTai) AS NhieuNhat
FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
GROUP BY k.TenKH
HAVING COUNT(*) >= 2
ORDER BY SiSoTB DESC;

-- Q13. Chương trình có tỷ lệ đạt dưới 95% (chỉ tính đăng ký đã có kết quả).      [HAVING với biểu thức]
SELECT k.MaCT, COUNT(*) AS SoKetQua,
       SUM(CASE WHEN d.KetQua = N'Đạt' THEN 1 ELSE 0 END) AS SoDat,
       CAST(100.0 * SUM(CASE WHEN d.KetQua = N'Đạt' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS TyLeDat
FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
WHERE d.KetQua IS NOT NULL
GROUP BY k.MaCT
HAVING 1.0 * SUM(CASE WHEN d.KetQua = N'Đạt' THEN 1 ELSE 0 END) / COUNT(*) < 0.95;

-- Q14. Cơ cấu hình thức thanh toán theo năm.                                    [COUNT, GROUP BY 2 cột]
SELECT YEAR(NgayThu) AS Nam, HinhThuc, COUNT(*) AS SoPhieu, SUM(TongTien) AS TongTien
FROM PHIEUTHU
GROUP BY YEAR(NgayThu), HinhThuc
ORDER BY Nam, TongTien DESC;

-- Q15. Tổng hợp doanh thu theo chi nhánh có dòng tổng cộng.                      [GROUP BY ROLLUP]
SELECT COALESCE(l.MaCN, N'TỔNG') AS ChiNhanh, COALESCE(CAST(YEAR(p.NgayThu) AS NVARCHAR(10)), N'Cả kỳ') AS Nam,
       SUM(c.SoTien) AS DoanhThu
FROM CT_PHIEUTHU c JOIN PHIEUTHU p ON p.MaPT = c.MaPT JOIN DANGKY d ON d.MaDK = c.MaDK JOIN LOPHOC l ON l.MaLop = d.MaLop
GROUP BY ROLLUP (l.MaCN, YEAR(p.NgayThu));

/* =========================== NHÓM 4 – TRUY VẤN LỒNG ===================== */

-- Q16. Học viên đã đăng ký khoá thuộc chương trình IELTS.                         [IN]
SELECT MaHV, HoTen FROM HOCVIEN
WHERE MaHV IN (SELECT d.MaHV FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
               WHERE k.MaCT = 'IELTS');

-- Q17. Học viên đã kiểm tra đầu vào nhưng chưa ghi danh lớp nào (khách tiềm năng). [NOT EXISTS]
SELECT h.MaHV, h.HoTen, h.SoDienThoai, t.NgayKT, t.DiemTong, t.MaKHDeXuat
FROM HOCVIEN h JOIN KIEMTRA_DAUVAO t ON t.MaHV = h.MaHV
WHERE NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV);

-- Q18. Học viên có điểm TB cao hơn điểm TB của chính lớp mình.                    [truy vấn con tương quan]
SELECT d.MaLop, h.HoTen, d.DiemTB
FROM DANGKY d JOIN HOCVIEN h ON h.MaHV = d.MaHV
WHERE d.DiemTB > (SELECT AVG(d2.DiemTB) FROM DANGKY d2 WHERE d2.MaLop = d.MaLop)
ORDER BY d.MaLop, d.DiemTB DESC;

-- Q19. Lớp có tỷ lệ lấp đầy cao hơn mọi lớp cùng khoá ở năm trước.               [ALL]
SELECT l.MaLop, l.MaKH, l.SiSoHienTai, l.SiSoToiDa
FROM LOPHOC l
WHERE YEAR(l.NgayKhaiGiang) = 2026
  AND 1.0 * l.SiSoHienTai / l.SiSoToiDa > ALL (SELECT 1.0 * x.SiSoHienTai / x.SiSoToiDa FROM LOPHOC x
                                               WHERE x.MaKH = l.MaKH AND YEAR(x.NgayKhaiGiang) = 2025);

-- Q20. Học viên còn nợ: số nợ tính bằng truy vấn con trong SELECT, lọc bằng truy vấn con trong FROM.
SELECT * FROM (
    SELECT h.MaHV, h.HoTen, h.SoDienThoai,
           -- loại cả đăng ký "Đã chuyển lớp": khoản đã đóng đã đi theo đăng ký mới (giống dbo.fn_SoTienConNo)
           (SELECT SUM(d.ThanhTien) FROM DANGKY d WHERE d.MaHV = h.MaHV AND d.TrangThai NOT IN (N'Huỷ', N'Đã chuyển lớp'))
         - (SELECT ISNULL(SUM(c.SoTien), 0) FROM CT_PHIEUTHU c JOIN DANGKY d ON d.MaDK = c.MaDK
            WHERE d.MaHV = h.MaHV AND d.TrangThai NOT IN (N'Huỷ', N'Đã chuyển lớp')) AS ConNo
    FROM HOCVIEN h
) x
WHERE x.ConNo > 0
ORDER BY x.ConNo DESC;

/* =========================== NHÓM 5 – TẬP HỢP =========================== */

-- Q21. Danh bạ chung (nhân viên ∪ học viên) để gửi thông báo nghỉ lễ.             [UNION]
SELECT N'Nhân viên' AS Loai, HoTen, SoDienThoai FROM NHANVIEN WHERE TrangThai = 1
UNION
SELECT N'Học viên', HoTen, SoDienThoai FROM HOCVIEN WHERE TrangThai = 1
ORDER BY Loai, HoTen;

-- Q22. Học viên học cả IELTS và TOEIC.                                            [INTERSECT]
SELECT d.MaHV FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE l.MaKH LIKE 'IE%'
INTERSECT
SELECT d.MaHV FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE l.MaKH LIKE 'TC%';

-- Q23. Học viên Đạt khoá cấp 1 nhưng chưa học tiếp cấp 2 (tư vấn học tiếp).       [EXCEPT]
SELECT d.MaHV FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
WHERE k.CapDo = 1 AND d.KetQua = N'Đạt'
EXCEPT
SELECT d.MaHV FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
WHERE k.CapDo = 2;

-- Q24. PHÉP CHIA: học viên đã học TẤT CẢ các khoá của một chương trình.
--      "Không tồn tại khoá nào của chương trình mà học viên chưa học" (NOT EXISTS lồng NOT EXISTS)
SELECT h.MaHV, h.HoTen, ct.TenCT
FROM HOCVIEN h CROSS JOIN CHUONGTRINH ct
WHERE NOT EXISTS (
    SELECT 1 FROM KHOAHOC k
    WHERE k.MaCT = ct.MaCT
      AND NOT EXISTS (SELECT 1 FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop
                      WHERE d.MaHV = h.MaHV AND l.MaKH = k.MaKH));

-- Q24b. Phép chia cách 2: đếm (GROUP BY + HAVING COUNT = tổng số khoá)
SELECT d.MaHV, k.MaCT
FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop JOIN KHOAHOC k ON k.MaKH = l.MaKH
GROUP BY d.MaHV, k.MaCT
HAVING COUNT(DISTINCT k.MaKH) = (SELECT COUNT(*) FROM KHOAHOC k2 WHERE k2.MaCT = k.MaCT);

/* =========================== NHÓM 6 – NÂNG CAO ========================== */

-- Q25. Doanh thu từng tháng 2026 và luỹ kế.                                        [CTE + SUM OVER]
WITH DT AS (
    SELECT FORMAT(NgayThu, 'yyyy-MM') AS Thang, SUM(TongTien) AS DoanhThu
    FROM PHIEUTHU WHERE NgayThu >= '2026-01-01' GROUP BY FORMAT(NgayThu, 'yyyy-MM')
)
SELECT Thang, DoanhThu, SUM(DoanhThu) OVER (ORDER BY Thang ROWS UNBOUNDED PRECEDING) AS LuyKe,
       DoanhThu - LAG(DoanhThu) OVER (ORDER BY Thang) AS ChenhLechThangTruoc
FROM DT ORDER BY Thang;

-- Q26. Chuỗi khoá tiên quyết để học tới IELTS 6.5+ và TOEIC 850+.                 [CTE đệ quy]
WITH LoTrinh AS (
    SELECT MaKH, TenKH, MaKHTienQuyet, 0 AS Buoc, CAST(TenKH AS NVARCHAR(400)) AS DuongDi
    FROM KHOAHOC WHERE MaKH IN ('IE65', 'TC850')
    UNION ALL
    SELECT k.MaKH, k.TenKH, k.MaKHTienQuyet, lt.Buoc + 1, CAST(k.TenKH + N' → ' + lt.DuongDi AS NVARCHAR(400))
    FROM KHOAHOC k JOIN LoTrinh lt ON k.MaKH = lt.MaKHTienQuyet
)
SELECT MaKH, TenKH, Buoc, DuongDi FROM LoTrinh WHERE MaKHTienQuyet IS NULL;

-- Q27. Cây quản lý nhân viên (cấp bậc).                                            [CTE đệ quy]
WITH Cay AS (
    SELECT MaNV, HoTen, ChucVu, MaNVQuanLy, 0 AS Cap, CAST(HoTen AS NVARCHAR(400)) AS ChuoiQL
    FROM NHANVIEN WHERE MaNVQuanLy IS NULL
    UNION ALL
    SELECT n.MaNV, n.HoTen, n.ChucVu, n.MaNVQuanLy, c.Cap + 1, CAST(c.ChuoiQL + N' > ' + n.HoTen AS NVARCHAR(400))
    FROM NHANVIEN n JOIN Cay c ON n.MaNVQuanLy = c.MaNV
)
SELECT REPLICATE(N'    ', Cap) + HoTen AS NhanVien, ChucVu, Cap, ChuoiQL FROM Cay ORDER BY ChuoiQL;

-- Q28. Xếp hạng học viên trong lớp và top 3 mỗi lớp đã kết thúc.                  [RANK, DENSE_RANK, PARTITION BY]
SELECT * FROM (
    SELECT d.MaLop, h.HoTen, d.DiemTB,
           RANK()       OVER (PARTITION BY d.MaLop ORDER BY d.DiemTB DESC) AS Hang,
           DENSE_RANK() OVER (PARTITION BY d.MaLop ORDER BY d.DiemTB DESC) AS HangLienTuc,
           NTILE(4)     OVER (PARTITION BY d.MaLop ORDER BY d.DiemTB DESC) AS NhomTuPhanVi
    FROM DANGKY d JOIN HOCVIEN h ON h.MaHV = d.MaHV
    WHERE d.DiemTB IS NOT NULL
) x WHERE Hang <= 3
ORDER BY MaLop, Hang;

-- Q29. Bảng chéo doanh thu: chi nhánh × quý năm 2025.                             [PIVOT]
SELECT MaCN, ISNULL([1], 0) AS Q1, ISNULL([2], 0) AS Q2, ISNULL([3], 0) AS Q3, ISNULL([4], 0) AS Q4
FROM (
    SELECT l.MaCN, DATEPART(QUARTER, p.NgayThu) AS Quy, c.SoTien
    FROM CT_PHIEUTHU c JOIN PHIEUTHU p ON p.MaPT = c.MaPT JOIN DANGKY d ON d.MaDK = c.MaDK JOIN LOPHOC l ON l.MaLop = d.MaLop
    WHERE YEAR(p.NgayThu) = 2025
) src
PIVOT (SUM(SoTien) FOR Quy IN ([1], [2], [3], [4])) pv;

-- Q30. Số buổi mỗi trạng thái điểm danh của từng lớp đang học (PIVOT) và tỷ lệ chuyên cần.
SELECT MaLop, [Có mặt], [Muộn], [Có phép], [Vắng],
       CAST(100.0 * ([Có mặt] + [Muộn]) / NULLIF([Có mặt] + [Muộn] + [Vắng], 0) AS DECIMAL(5,2)) AS ChuyenCan
FROM (SELECT dd.MaLop, dd.TrangThai FROM DIEMDANH dd JOIN LOPHOC l ON l.MaLop = dd.MaLop WHERE l.TrangThai = N'Đang học') s
PIVOT (COUNT(TrangThai) FOR TrangThai IN ([Có mặt], [Muộn], [Có phép], [Vắng])) pv;
GO

/* =====================================================================
   ĐO HIỆU NĂNG: trước / sau khi có chỉ mục
   Dữ liệu mẫu nhỏ nên nhân bản DIEMDANH thành bảng tạm ~1 triệu dòng để thấy khác biệt.
   Đo bằng SET STATISTICS IO (logical reads – ổn định giữa các lần chạy) và TIME.
   ===================================================================== */
DROP TABLE IF EXISTS #DD;
SELECT TOP (1000000) ISNULL(CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT), 0) AS Id,   -- ISNULL: cột NOT NULL để làm PK
       d.MaDK + 1000 * (n.k % 100) AS MaDK, d.MaLop, d.STT, d.TrangThai
INTO #DD
FROM DIEMDANH d CROSS JOIN (SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k FROM sys.all_objects) n;
ALTER TABLE #DD ADD CONSTRAINT PK_DD PRIMARY KEY (Id);
GO
SET STATISTICS IO, TIME ON;
-- (P1) Chuyên cần của 1 đăng ký – KHÔNG có chỉ mục trên MaDK: quét toàn bảng
SELECT COUNT(*) AS SoBuoi, SUM(CASE WHEN TrangThai = N'Vắng' THEN 1 ELSE 0 END) AS Vang FROM #DD WHERE MaDK = 50120;
-- (P2) Thống kê theo lớp – KHÔNG có chỉ mục trên MaLop
SELECT TrangThai, COUNT(*) FROM #DD WHERE MaLop = 'IE55-2602' GROUP BY TrangThai;
SET STATISTICS IO, TIME OFF;
GO
CREATE INDEX IX_DD_MaDK ON #DD (MaDK) INCLUDE (TrangThai);
CREATE INDEX IX_DD_MaLop ON #DD (MaLop) INCLUDE (TrangThai);
GO
SET STATISTICS IO, TIME ON;
-- (P1') cùng câu, CÓ chỉ mục: Index Seek
SELECT COUNT(*) AS SoBuoi, SUM(CASE WHEN TrangThai = N'Vắng' THEN 1 ELSE 0 END) AS Vang FROM #DD WHERE MaDK = 50120;
-- (P2') cùng câu, CÓ chỉ mục
SELECT TrangThai, COUNT(*) FROM #DD WHERE MaLop = 'IE55-2602' GROUP BY TrangThai;
SET STATISTICS IO, TIME OFF;
GO
-- (P3) Truy vấn không tận dụng được chỉ mục (SARGability): hàm bọc cột làm mất Index Seek
SET STATISTICS IO ON;
SELECT COUNT(*) FROM PHIEUTHU WHERE YEAR(NgayThu) = 2026 AND MONTH(NgayThu) = 3;              -- Index Scan
SELECT COUNT(*) FROM PHIEUTHU WHERE NgayThu >= '2026-03-01' AND NgayThu < '2026-04-01';      -- Index Seek
SET STATISTICS IO OFF;
DROP TABLE IF EXISTS #DD;
GO
