# Chương 3. Xử lý thông tin

## 3.1 Truy vấn dữ liệu

### 3.1.1 Truy vấn SQL nghiệp vụ

Bộ truy vấn nằm trong [`database/10_queries.sql`](../database/10_queries.sql): **31 câu** (Q01–Q30 và Q24b) chia 6 nhóm kỹ thuật, mỗi câu trả lời một câu hỏi quản lý thực tế. Số dòng kết quả đo trên dữ liệu mẫu (ngày tham chiếu 15/10/2026).

| Nhóm | Câu | Câu hỏi nghiệp vụ | Kỹ thuật | Kết quả |
|---|:-:|---|---|--:|
| **1. Cơ bản** | Q01 | Học viên họ Nguyễn/Trần ở CN Thủ Đức | `LIKE`, `IN`, `ORDER BY` | 34 |
| | Q02 | Khoá học phí 4–6 triệu, học phí mỗi buổi | `BETWEEN`, biểu thức | 7 |
| | Q03 | Học viên chưa có email | `IS NULL` | 101 |
| | Q04 | 5 phiếu thu lớn nhất 2026 | `TOP … WITH TIES` | 5 |
| | Q05 | Lớp quý IV/2026 chưa đạt 60% sĩ số | điều kiện kết hợp | 2 |
| **2. Kết nối** | Q06 | Lớp đang học: khoá, chi nhánh, GV, lịch | `INNER JOIN` 6 bảng, `STRING_AGG` | 5 |
| | Q07 | Mọi giáo viên và số lớp (kể cả 0) | `LEFT JOIN` | 10 |
| | Q08 | Phòng chưa từng được xếp lịch | `RIGHT JOIN … IS NULL` | 6 |
| | Q09 | Đối chiếu khoá học – lớp | `FULL OUTER JOIN` | 25 |
| | Q10 | Nhân viên và người quản lý | **self-join** | 20 |
| **3. Gom nhóm** | Q11 | Doanh thu theo chi nhánh × tháng 2026 | `GROUP BY`, `SUM` | 18 |
| | Q12 | Sĩ số TB / min / max theo khoá | `AVG`, `MIN`, `MAX`, `HAVING` | 12 |
| | Q13 | Chương trình có tỷ lệ đạt < 95% | `HAVING` với biểu thức | 4 |
| | Q14 | Cơ cấu hình thức thanh toán theo năm | `GROUP BY` 2 cột | 6 |
| | Q15 | Doanh thu chi nhánh có tổng phụ, tổng cộng | `ROLLUP` | 10 |
| **4. Lồng** | Q16 | Học viên từng học IELTS | `IN (subquery)` | 93 |
| | Q17 | Khách đã test nhưng chưa ghi danh | `NOT EXISTS` | 15 |
| | Q18 | Học viên điểm TB cao hơn TB lớp | **tương quan** | 174 |
| | Q19 | Lớp 2026 lấp đầy hơn mọi lớp cùng khoá 2025 | `> ALL` | 7 |
| | Q20 | Học viên còn nợ | subquery trong `SELECT` và `FROM` | 58 |
| **5. Tập hợp** | Q21 | Danh bạ chung nhân viên ∪ học viên | `UNION` | 369 |
| | Q22 | Học viên học cả IELTS và TOEIC | `INTERSECT` | 2 |
| | Q23 | Đạt cấp 1 nhưng chưa học cấp 2 | `EXCEPT` | 69 |
| | Q24 | Học viên học **tất cả** khoá của một chương trình | **phép chia** (NOT EXISTS lồng) | 36 |
| | Q24b | Như Q24, cách đếm | `HAVING COUNT = (subquery)` | 36 |
| **6. Nâng cao** | Q25 | Doanh thu tháng, luỹ kế, chênh lệch tháng trước | CTE, `SUM() OVER`, `LAG` | 7 |
| | Q26 | Lộ trình tiên quyết tới IELTS 6.5+, TOEIC 850+ | **CTE đệ quy** | 2 |
| | Q27 | Cây quản lý nhân viên | CTE đệ quy | 20 |
| | Q28 | Top 3 mỗi lớp | `RANK`, `DENSE_RANK`, `NTILE`, `PARTITION BY` | 49 |
| | Q29 | Doanh thu chi nhánh × quý 2025 | `PIVOT` | 3 |
| | Q30 | Thống kê điểm danh lớp đang học | `PIVOT` + tỷ lệ | 5 |

Mỗi nhóm có ≥ 5 câu. Một số câu tiêu biểu:

**Q24 – Phép chia.** "Học viên *h* đã học mọi khoá của chương trình *ct*" ⇔ "không tồn tại khoá *k* thuộc *ct* mà *h* chưa đăng ký":

```sql
SELECT h.MaHV, h.HoTen, ct.TenCT
FROM HOCVIEN h CROSS JOIN CHUONGTRINH ct
WHERE NOT EXISTS (SELECT 1 FROM KHOAHOC k WHERE k.MaCT = ct.MaCT
        AND NOT EXISTS (SELECT 1 FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop
                        WHERE d.MaHV = h.MaHV AND l.MaKH = k.MaKH));
```

Hai cách viết (Q24, Q24b) cho cùng **36** cặp học viên – chương trình, xác nhận kết quả đúng.

**Q26 – CTE đệ quy** đi ngược khoá tiên quyết từ khoá đích:

| MaKH | Bước | Lộ trình |
|---|:-:|---|
| IEF | 2 | IELTS Foundation → IELTS 5.5 → IELTS 6.5+ |
| TC450 | 2 | TOEIC 450 → TOEIC 650 → TOEIC 850+ |

**Q15 – ROLLUP** (trích):

| Chi nhánh | Năm | Doanh thu (VNĐ) |
|---|---|--:|
| CN01 | 2025 | 352 950 000 |
| CN01 | 2026 | 459 525 000 |
| CN01 | Cả kỳ | 812 475 000 |
| CN02 | Cả kỳ | 711 627 000 |
| … | | |

**Q29 – PIVOT** doanh thu 2025 theo quý:

| Chi nhánh | Q1 | Q2 | Q3 | Q4 |
|---|--:|--:|--:|--:|
| CN01 | 168 650 000 | 62 475 000 | 0 | 121 825 000 |
| CN02 | 78 750 000 | 173 610 000 | 19 530 000 | 74 000 000 |
| CN03 | 52 500 000 | 71 100 000 | 0 | 259 650 000 |

Doanh thu dồn vào quý có đợt khai giảng (Q1, Q2, Q4) – thông tin giúp quản lý lên kế hoạch dòng tiền và chiến dịch tuyển sinh quý III.

### 3.1.2 Hiệu năng truy vấn và chỉ mục

Dữ liệu mẫu nhỏ (10 nghìn điểm danh) nên phần cuối `10_queries.sql` nhân bản DIEMDANH thành bảng tạm **1 000 000 dòng** rồi đo cùng câu truy vấn trước và sau khi tạo chỉ mục. Số liệu bằng `SET STATISTICS IO, TIME ON` trên SQL Server 2025 (Docker):

| Truy vấn | Không chỉ mục | Có chỉ mục | Giảm |
|---|---|---|--:|
| P1 – chuyên cần của 1 đăng ký (`WHERE MaDK = …`) | Clustered Index Scan, **6 023** logical reads, CPU 62 ms | Index Seek `IX_DD_MaDK`, **3** logical reads, CPU 0 ms | 99,9% |
| P2 – thống kê 1 lớp (`WHERE MaLop = … GROUP BY`) | Scan, **6 023** logical reads, CPU 194 ms | Seek `IX_DD_MaLop`, **150** logical reads, CPU 13 ms | 97,5% |
| P3 – phiếu thu tháng 3/2026 viết `YEAR(NgayThu) = 2026 AND MONTH(...) = 3` | Index **Scan**, 5 logical reads | – | |
| P3' – cùng điều kiện viết `NgayThu >= '2026-03-01' AND NgayThu < '2026-04-01'` | – | Index **Seek** `IX_PHIEUTHU_NgayThu`, 2 logical reads | 60% |

**Nhận xét**

- Chỉ mục có cột `INCLUDE (TrangThai)` là *covering index*: câu truy vấn đọc xong ngay trên chỉ mục, không phải tra lại bảng (Key Lookup) – vì vậy P1 chỉ còn 3 trang.
- P2 lọc ra ~1% bảng nên vẫn đọc 150 trang, nhưng ít hơn quét toàn bộ 40 lần.
- P3 cho thấy **điều kiện không SARGable** (bọc cột trong hàm `YEAR()`) làm mất khả năng seek dù đã có chỉ mục – quy tắc viết truy vấn nhóm áp dụng cho view báo cáo (T16) và procedure thống kê doanh thu (T11).
- Thời gian (ms) dao động giữa các lần chạy; logical reads ổn định nên được dùng làm thước đo chính.
