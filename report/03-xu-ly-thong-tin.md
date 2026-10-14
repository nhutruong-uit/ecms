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

## 3.2 An ninh dữ liệu

### 3.2.3 View bảo mật và view phục vụ báo cáo

File [`database/04_views.sql`](../database/04_views.sql) gồm **9 view**. Ứng dụng web và các vai trò nghiệp vụ được cấp quyền `SELECT` trên view thay vì bảng gốc (ma trận quyền ở mục 3.2.2).

| View | Loại | Mục đích | Kỹ thuật |
|---|---|---|---|
| `vw_NhanVien_CongKhai` | **Bảo mật – theo cột** | Danh bạ nhân viên, *ẩn lương và ngày sinh* | JOIN tự thân lấy tên người quản lý |
| `vw_HocVien_ChiNhanh` | **Bảo mật – theo dòng** | Mỗi chi nhánh chỉ thấy học viên của mình | `SESSION_CONTEXT(N'ma_cn')` |
| `vw_LichDayGiaoVien` | Bảo mật – theo cột | Lịch dạy, không lộ học viên, học phí, lương | Tính thứ trong tuần không phụ thuộc `DATEFIRST` |
| `vw_DangKyChiTiet` | Nghiệp vụ | Nguồn form ghi danh, cho phép INSERT qua view | INSTEAD OF trigger (T13) |
| `vw_CongNoHocVien` | Báo cáo | Đăng ký chưa đóng đủ, số ngày quá hạn | `OUTER APPLY` |
| `vw_BangDiem` | Báo cáo | Điểm, xếp loại, chuyên cần | Gọi `fn_XepLoai`, `fn_TyLeChuyenCan` (T12) |
| `vw_DoanhThuThang` | Báo cáo | Doanh thu chi nhánh × tháng | **Indexed view**: `WITH SCHEMABINDING` + `UNIQUE CLUSTERED INDEX` |
| `vw_SiSoLop` | Báo cáo | Sĩ số, tỷ lệ lấp đầy, lịch học dạng chuỗi | `FOR XML PATH` ghép chuỗi |
| `vw_LopHoc_DangMo` | Form | Lớp *Sắp mở / Đang học*, cập nhật được | **`WITH CHECK OPTION`** |

**Row-level security bằng SESSION_CONTEXT.** Sau khi đăng nhập, ứng dụng gọi `EXEC sp_set_session_context N'ma_cn', 'CN02'` trên kết nối; quản lý trung tâm nhận giá trị `'ALL'`. View lọc `WHERE CAST(SESSION_CONTEXT(N'ma_cn') AS VARCHAR(4)) IN (h.MaCN, 'ALL')`:

| Ngữ cảnh phiên | Kết quả `SELECT MaCN, COUNT(*) FROM vw_HocVien_ChiNhanh GROUP BY MaCN` |
|---|---|
| Chưa đặt | 0 dòng – mặc định **không thấy gì** (an toàn khi quên đặt) |
| `ma_cn = 'CN02'` | CN02: 119 |
| `ma_cn = 'ALL'` | CN01: 133 · CN02: 119 · CN03: 97 |

**WITH CHECK OPTION** chặn sửa dữ liệu qua view làm dòng không còn thoả điều kiện của view:

```sql
UPDATE vw_LopHoc_DangMo SET TrangThai = N'Đã kết thúc' WHERE MaLop = 'GT3-2601';
-- Msg 550: The attempted insert or update failed because the target view either specifies
-- WITH CHECK OPTION ... did not qualify under the CHECK OPTION constraint.
```

**Ví dụ kết quả**

`vw_CongNoHocVien` – 67 đăng ký còn nợ, tổng **283 218 000 đ**, trong đó 44 đăng ký quá hạn:

| MaDK | Học viên | Lớp | Thành tiền | Đã thu | Còn nợ | Hạn | Quá hạn (ngày) |
|--:|---|---|--:|--:|--:|---|--:|
| 182 | Hoàng Kim Xuân | IE65-2501 | 9 000 000 | 0 | 9 000 000 | 09/10/2025 | 370 |
| 376 | Mai Đức Bảo | IE55-2601 | 7 500 000 | 0 | 7 500 000 | 23/08/2026 | 52 |
| 487 | Nguyễn Mai Chi | IE65-2601 | 8 100 000 | 0 | 8 100 000 | 29/10/2026 | – |

`vw_SiSoLop` (lớp chưa kết thúc, trích):

| Lớp | Khoá | Chi nhánh | Sĩ số | Lấp đầy | Lịch |
|---|---|---|:-:|--:|---|
| IE55-2602 | IELTS 5.5 | Thủ Đức | 20/20 | 100,0% | T4 Tối 2 (P101), T6 Tối 2 (P101) |
| IE55-2601 | IELTS 5.5 | Bình Thạnh | 28/30 | 93,3% | T7 Sáng 1 (P101), CN Sáng 1 (P101) |
| GT3-2601 | Giao tiếp Nâng cao | Bình Thạnh | 10/25 | 40,0% | T3 Tối 1 (P101), T5 Tối 1 (P101) |

**Indexed view – so sánh tốc độ.** Tổng doanh thu theo chi nhánh × năm:

| Cách truy vấn | Logical reads | Ghi chú |
|---|--:|---|
| Gộp trực tiếp 4 bảng (`OPTION (EXPAND VIEWS)`) | 16 (DANGKY 5, CT_PHIEUTHU 4, PHIEUTHU 5, LOPHOC 2) + worktable | Phải JOIN và hash aggregate mỗi lần |
| Đọc `vw_DoanhThuThang WITH (NOEXPAND)` | **2** | Kết quả gộp sẵn theo tháng trong chỉ mục clustered của view |

Chênh lệch tăng theo kích thước dữ liệu vì indexed view chỉ lưu ~3 chi nhánh × 24 tháng = 72 dòng dù có hàng trăm nghìn dòng thu. Đổi lại, mỗi lần thêm/sửa CT_PHIEUTHU, SQL Server phải cập nhật thêm chỉ mục của view – phù hợp với dữ liệu *đọc nhiều, ghi ít* như doanh thu. Ràng buộc của indexed view: `SCHEMABINDING`, tên hai phần `dbo.X`, không `OUTER JOIN`, phải có `COUNT_BIG(*)` khi `GROUP BY`, và các phiên ghi vào bảng gốc phải bật `QUOTED_IDENTIFIER`, `ANSI_NULLS` (nên `run_all` gọi `sqlcmd -I`).

## 3.3 Lập trình trên CSDL

### 3.3.1 Stored procedure và transaction

File [`database/05_procedures.sql`](../database/05_procedures.sql) đóng gói các nghiệp vụ ghi dữ liệu. Ứng dụng web chỉ được `EXECUTE` procedure (T15) nên mọi kiểm tra nghiệp vụ nằm tại CSDL, không thể bị bỏ qua từ phía giao diện.

| Procedure | Tham số vào | OUTPUT | Transaction | Kiểm tra chính |
|---|---|---|:-:|---|
| `sp_DangKyHoc` | @MaHV, @MaLop, @GiamGia | @MaDK | ✔ | Học viên tồn tại, lớp đang mở, không trùng, **còn chỗ** (khoá dòng `UPDLOCK, HOLDLOCK`), **tiên quyết** (đã Đạt khoá trước hoặc test đầu vào đủ điểm) |
| `sp_ThuHocPhi` | @MaHV, @MaNV, @HinhThuc, **@ChiTiet (JSON)**, @GhiChu | @MaPT, @TongTien | ✔ | Master–detail: đăng ký thuộc học viên, không thu vượt nợ, người lập là kế toán/quản lý |
| `sp_XepLichLop` / `sp_XoaLichLop` | @MaLop, @Thu, @MaCa, @MaPhong | – | | Phòng thuộc chi nhánh, đủ sức chứa, **trùng phòng**, **trùng giáo viên** trong khoảng thời gian giao nhau |
| `sp_DiemDanhBuoi` | @MaLop, @STT, **@DanhSach (JSON)** | – | ✔ | Điểm danh cả lớp một lần lưu bằng `MERGE`; buổi đã tới ngày; học viên thuộc lớp |
| `sp_NhapDiem` | @MaLop, @DanhSach (JSON) | @SoDong | ✔ | Điểm 0–10, học viên đang học |
| `sp_ChuyenLop` | @MaDK, @MaLopMoi | @MaDKMoi | ✔ | Cùng khoá, lớp mới còn chỗ; 3 bước: đánh dấu ĐK cũ → tạo ĐK mới → chuyển khoản đã đóng |
| `sp_ThongKeDoanhThu` | @TuNgay, @DenNgay, @MaCN | @TongDoanhThu | | Trả bảng chi nhánh × tháng + tổng qua OUTPUT |
| `sp_TimKiemHocVien` | @TuKhoa, @MaCN, @MaKH, @ConNo, @Trang, @SoDongTrang | @TongSo | | Tiêu chí tuỳ chọn, phân trang `OFFSET … FETCH`, tự lọc chi nhánh qua `vw_HocVien_ChiNhanh` |

Tổng cộng **9 procedure**, 7 procedure có tham số OUTPUT, **5 procedure dùng transaction**.

**Mẫu transaction dùng chung** – procedure tự mở transaction khi được gọi độc lập, nhưng nếu người gọi đã có transaction thì chỉ đặt *savepoint*, lỗi xảy ra chỉ rollback phần của mình:

```sql
DECLARE @tc INT = @@TRANCOUNT;
IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_DangKyHoc;
BEGIN TRY
    ...  -- kiểm tra, THROW 5000x với thông báo tiếng Việt
    INSERT dbo.DANGKY (...) ...;
    SET @MaDK = SCOPE_IDENTITY();
    IF @tc = 0 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;   -- transaction hỏng / của mình
    ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_DangKyHoc;                   -- chỉ về savepoint
    THROW;                                                                          -- trả lỗi gốc cho ứng dụng
END CATCH
```

**Tại sao khoá `UPDLOCK, HOLDLOCK` khi đọc sĩ số?** Nếu hai giáo vụ cùng ghi danh vào chỗ cuối cùng, cả hai cùng đọc "còn 1 chỗ" rồi cùng INSERT → lớp vượt sĩ số. `UPDLOCK` giữ khoá cập nhật trên dòng LOPHOC tới hết transaction nên phiên thứ hai phải chờ, đọc lại thấy lớp đã đầy và nhận lỗi 50004. Trigger ở T13 là lớp bảo vệ thứ hai.

**Truyền danh sách bằng JSON.** `sp_ThuHocPhi`, `sp_DiemDanhBuoi`, `sp_NhapDiem` nhận cả danh sách trong một tham số `NVARCHAR(MAX)` dạng JSON và tách bằng `OPENJSON … WITH (...)`. So với table-valued parameter, JSON gọi được trực tiếp từ pyodbc / sqlcmd mà không cần tạo kiểu bảng, vẫn xử lý theo tập hợp trong một transaction (một lần lưu cho cả lớp).

**SQL tĩnh thay cho SQL động** trong `sp_TimKiemHocVien`: điều kiện dạng `(@x IS NULL OR cot = @x)` kèm `OPTION (RECOMPILE)` để mỗi lần chạy được tối ưu theo tham số thực. Không ghép chuỗi SQL nên không có nguy cơ SQL injection, và ownership chaining giữ nguyên – tài khoản ứng dụng không cần quyền trên bảng.

**Kiểm thử** – [`database/tests/test_procedures.sql`](../database/tests/test_procedures.sql) chạy 25 ca trong một transaction rồi `ROLLBACK` (kết quả ghi vào biến bảng vì biến bảng không bị rollback huỷ):

| Procedure | Ca kiểm thử | Mong đợi | Thực tế |
|---|---|---|---|
| sp_DangKyHoc | Ghi danh hợp lệ vào KD2-2601 | OK | OK MaDK=569 ✔ |
| | Đăng ký trùng | 50003 | 50003 Học viên đã đăng ký lớp này. ✔ |
| | Lớp IE55-2602 đã đủ sĩ số | 50004 | 50004 Lớp đã đủ sĩ số. ✔ |
| | Thiếu khoá tiên quyết (GT3-2601) | 50005 | 50005 Chưa đủ điều kiện: cần Đạt khoá GT2 hoặc điểm kiểm tra đầu vào từ 6.5 trở lên. ✔ |
| | Lớp đã kết thúc | 50002 | 50002 Lớp đã kết thúc hoặc đã huỷ, không nhận ghi danh. ✔ |
| | Học viên không tồn tại | 50001 | 50001 ✔ |
| sp_ThuHocPhi | Thu một phần 1 000 000 | OK | OK MaPT=524 ✔ |
| | Thu phần còn lại (không ghi số tiền) | OK | OK Tong=2 990 000 ✔ |
| | Thu vượt số còn nợ | 50014 | 50014 ✔ |
| | Đăng ký của học viên khác | 50012 | 50012 ✔ |
| | Giáo vụ lập phiếu | 50011 | 50011 Chỉ kế toán hoặc quản lý được lập phiếu thu. ✔ |
| sp_XepLichLop | Thêm lịch phòng trống | OK | OK ✔ |
| | Trùng lịch với GT3-2601 | 5002x | 50025 Trùng phòng P101 với lớp GT3-2601. ✔ |
| | Phòng không thuộc chi nhánh | 50022 | 50022 ✔ |
| sp_DiemDanhBuoi | Điểm danh cả lớp TC650-2601 buổi 17 | OK | OK 27 dòng ✔ |
| | Buổi chưa tới | 50031 | 50031 ✔ |
| | Học viên lớp khác | 50033 | 50033 ✔ |
| sp_NhapDiem | Nhập điểm GK cả lớp | OK | OK 27 học viên ✔ |
| | Điểm 11 | 50042 | 50042 Điểm phải nằm trong khoảng 0 – 10. ✔ |
| sp_ChuyenLop | Chuyển ĐK 387 sang IE55-2601 | OK | OK, tiền đã đóng chuyển theo 6 750 000/6 750 000 ✔ |
| | Sang lớp khác khoá | 50053 | 50053 ✔ |
| sp_ThongKeDoanhThu | Năm 2025 | OK | 15 dòng, tổng 1 082 090 000 = tổng chi tiết ✔ |
| | Khoảng ngày ngược | 50060 | 50060 ✔ |
| sp_TimKiemHocVien | "Nguyễn", trang 2, 10 dòng/trang | OK | tổng 35, trang này 10 dòng ✔ |
| | Trang 0 | 50061 | 50061 ✔ |

Kết quả: **25/25 PASS**; sau khi chạy, dữ liệu mẫu giữ nguyên (`test_seed.sql` vẫn 0 lỗi). Giá trị IDENTITY đã cấp trong transaction bị rollback không được trả lại nên MaDK/MaPT tiếp theo có khoảng trống – đây là hành vi bình thường của SQL Server.

### 3.3.2 Hàm do người dùng định nghĩa (function)

File [`database/03_functions.sql`](../database/03_functions.sql) gồm **10 hàm** thuộc đủ 3 loại:

| Hàm | Loại | Tham số → Kết quả | Dùng ở |
|---|---|---|---|
| `fn_TinhTuoi` | Vô hướng, `SCHEMABINDING` | (@NgaySinh, @NgayTinh = hôm nay) → INT | CHECK `CK_NHANVIEN_TuoiLaoDong`, báo cáo |
| `fn_TyLeChuyenCan` | Vô hướng | (@MaDK) → % có mặt (Muộn tính có mặt, Có phép không tính) | View bảng điểm, cursor cảnh báo (T14), web T22 |
| `fn_XepLoai` | Vô hướng, `SCHEMABINDING` | (@DiemTB) → Xuất sắc / Giỏi / Khá / Trung bình / Yếu | Bảng điểm, báo cáo |
| `fn_SoTienDaDong` | Vô hướng | (@MaDK) → tổng đã thu | Công nợ, phiếu thu |
| `fn_SoTienConNo` | Vô hướng | (@MaHV) → tổng còn nợ | Hồ sơ học viên (T21) |
| `fn_SoChoConLai` | Vô hướng | (@MaLop) → số chỗ trống | Ghi danh (T21) |
| `fn_LichHocHocVien` | **Inline TVF** | (@MaHV, @Tuan) → lịch tuần chứa ngày @Tuan | Trang học viên |
| `fn_LopCuaGiaoVien` | Inline TVF | (@MaGV) → các lớp của giáo viên | Giáo viên chỉ thấy lớp mình (T22) |
| `fn_GoiYKhoaHoc` | Inline TVF | (@Diem, @MaCT = NULL) → khoá phù hợp + số lớp còn chỗ | Kiểm tra đầu vào (T21) |
| `fn_BangDiemLop` | **Multi-statement TVF** | (@MaLop) → bảng điểm có xếp loại, chuyên cần, thứ hạng, ghi chú | Báo cáo bảng điểm (T24) |

**Ví dụ gọi và kết quả** (dữ liệu mẫu):

```sql
-- Hàm vô hướng trong SELECT, WHERE, ORDER BY và GROUP BY
SELECT TOP 3 MaHV, HoTen, dbo.fn_SoTienConNo(MaHV) AS ConNo
FROM HOCVIEN WHERE dbo.fn_SoTienConNo(MaHV) > 0 ORDER BY ConNo DESC;
```

| MaHV | HoTen | ConNo |
|---|---|--:|
| HV0019 | Nguyễn Thành Khoa | 15 275 000 |
| HV0162 | Đặng Quang Hưng | 13 500 000 |
| HV0022 | Bùi Kim Xuân | 9 000 000 |

```sql
SELECT dbo.fn_XepLoai(DiemTB) AS XepLoai, COUNT(*) AS SoHV
FROM DANGKY WHERE DiemTB IS NOT NULL GROUP BY dbo.fn_XepLoai(DiemTB);
```

| Xuất sắc | Giỏi | Khá | Trung bình | Yếu |
|:-:|:-:|:-:|:-:|:-:|
| 22 | 55 | 115 | 111 | 41 |

```sql
SELECT * FROM dbo.fn_GoiYKhoaHoc(5.0, NULL);          -- học viên test được 5.0 điểm
```

| MaKH | TenKH | Mục tiêu | Học phí | Lớp còn chỗ |
|---|---|---|--:|:-:|
| GT2 | Giao tiếp Trung cấp | B1 | 3 500 000 | 1 |
| IE55 | IELTS 5.5 | IELTS 5.5 | 7 500 000 | 1 |
| KD2 | Kids Movers | Cambridge Movers | 4 200 000 | 1 |
| TC650 | TOEIC 650 | TOEIC 650 | 4 500 000 | 1 |

```sql
SELECT * FROM dbo.fn_LichHocHocVien('HV0004', '2026-10-15');   -- tuần 12–18/10/2026
```

| NgayHoc | Thu | Ca | Lớp | Phòng | Buổi | Giáo viên |
|---|---|---|---|---|:-:|---|
| 2026-10-17 | Thứ 7 | Sáng 1 | IE55-2601 | P101 | 19 | Wilson David |
| 2026-10-18 | Chủ nhật | Sáng 1 | IE55-2601 | P101 | 20 | Wilson David |

`fn_LichHocHocVien` tính thứ Hai đầu tuần bằng `DATEDIFF(DAY, '19000101', @Tuan) % 7` (01/01/1900 là thứ Hai) nên không phụ thuộc `SET DATEFIRST` / `SET LANGUAGE` của phiên kết nối.

```sql
SELECT TOP 5 * FROM dbo.fn_BangDiemLop('GT1-2501') ORDER BY Hang;   -- multi-statement TVF
```

| Hạng | Họ tên | GK | CK | TB | Xếp loại | Chuyên cần | Kết quả |
|:-:|---|:-:|:-:|:-:|---|:-:|---|
| 1 | Trần Mai Vân | 10.00 | 10.00 | 10.00 | Xuất sắc | 100.00 | Đạt |
| 2 | Hoàng Kim Mai | 7.50 | 9.00 | 8.40 | Giỏi | 100.00 | Đạt |
| 3 | Bùi Minh Chi | 9.00 | 7.75 | 8.25 | Giỏi | 100.00 | Đạt |

Hàm multi-statement cần nhiều bước: nạp biến bảng → cập nhật xếp loại/chuyên cần bằng hàm vô hướng → tính `RANK()` → ghép ghi chú cảnh báo (`CONCAT_WS`). Một câu SELECT duy nhất (inline) khó viết và khó đọc hơn.

**Hàm trong CHECK constraint**

```sql
ALTER TABLE NHANVIEN ADD CONSTRAINT CK_NHANVIEN_TuoiLaoDong
    CHECK (dbo.fn_TinhTuoi(NgaySinh, NgayVaoLam) BETWEEN 18 AND 65);

INSERT NHANVIEN (..., NgaySinh, ..., NgayVaoLam) VALUES (..., '1950-01-01', ..., '2026-01-01');
-- Msg 547: The INSERT statement conflicted with the CHECK constraint "CK_NHANVIEN_TuoiLaoDong".
```

Khi chạy lại `03_functions.sql`, ràng buộc này được xoá trước rồi tạo lại vì SQL Server không cho `ALTER FUNCTION` khi hàm đang được CHECK tham chiếu.

**So sánh function và stored procedure**

| Tiêu chí | Function | Stored procedure |
|---|---|---|
| Giá trị trả về | Bắt buộc: một giá trị vô hướng hoặc một bảng | Tuỳ chọn: tập kết quả, tham số OUTPUT, mã trả về |
| Dùng trong câu lệnh | Được: `SELECT`, `WHERE`, `JOIN`, `CHECK`, cột tính toán | Không, chỉ `EXEC` |
| Thay đổi dữ liệu | **Không** (chỉ đọc; chỉ được sửa biến bảng cục bộ) | Được: INSERT / UPDATE / DELETE |
| Transaction, TRY…CATCH | Không | Có |
| Gọi hàm / thủ tục khác | Chỉ gọi function | Gọi được cả hai |
| Hiệu năng | Inline TVF được tối ưu như view; scalar UDF chạy từng dòng (SQL Server 2019+ có thể tự *inline*) | Kế hoạch thực thi được cache |
| Trong ECMS dùng cho | Tính toán dùng lại: chuyên cần, xếp loại, công nợ, lịch | Nghiệp vụ ghi dữ liệu: ghi danh, thu phí, điểm danh (T11) |

### 3.3.3 Trigger và nhật ký kiểm toán

File [`database/06_triggers.sql`](../database/06_triggers.sql) gồm **11 trigger**:

| Trigger | Bảng / view | Loại · sự kiện | Nhiệm vụ | RBTV |
|---|---|---|---|---|
| `trg_DangKy_KiemTraSiSo` | DANGKY | AFTER INSERT, UPDATE · **First** | Chặn ghi danh làm lớp vượt sĩ số (THROW 50070) | RB06 |
| `trg_DangKy_SiSo` | DANGKY | AFTER INSERT, UPDATE, DELETE · **Last** | Tính lại `LOPHOC.SiSoHienTai` | RB14 |
| `trg_DangKy_KetQua` | DANGKY | AFTER INSERT, UPDATE (DiemGK, DiemCK) | Kết quả Đạt / Không đạt theo điểm TB | – |
| `trg_CTPhieuThu_TongTien` | CT_PHIEUTHU | AFTER INSERT, UPDATE, DELETE | Chặn sai học viên / thu vượt; cập nhật `PHIEUTHU.TongTien`, `DANGKY.TrangThaiHP` | RB15, RB16 |
| `trg_LichHoc_KiemTraTrung` | LICHHOC | AFTER INSERT, UPDATE | Chặn trùng phòng, trùng giáo viên khi thời gian lớp giao nhau | RB09, RB10 |
| `trg_NhatKy_DangKy` | DANGKY | AFTER INSERT, UPDATE, DELETE | Ghi nhật ký (bỏ qua UPDATE không đổi giá trị) | NFR03 |
| `trg_NhatKy_PhieuThu` | PHIEUTHU | AFTER INSERT, UPDATE, DELETE | Ghi nhật ký phiếu thu | NFR03 |
| `trg_NhatKy_Luong` | NHANVIEN | AFTER UPDATE (LuongCoBan) | Ghi lương cũ / mới, % thay đổi | NFR03 |
| `trg_NhatKy_ChiDoc` | NHATKY | **INSTEAD OF** UPDATE, DELETE | Nhật ký chỉ được thêm | NFR03 |
| `trg_vwDangKyChiTiet_Insert` | **view** vw_DangKyChiTiet | **INSTEAD OF** INSERT | Ghi danh qua view JOIN 4 bảng, học phí lấy từ KHOAHOC | – |
| `trg_vwDangKyChiTiet_Delete` | **view** vw_DangKyChiTiet | **INSTEAD OF** DELETE | "Xoá" qua view = huỷ đăng ký (xoá mềm), chặn nếu đã có phiếu thu | – |

**Bảng inserted / deleted.** Trong trigger, SQL Server cung cấp hai bảng ảo cùng cấu trúc với bảng gốc:

| Thao tác | `inserted` | `deleted` |
|---|---|---|
| INSERT | Các dòng mới | rỗng |
| DELETE | rỗng | Các dòng bị xoá |
| UPDATE | Giá trị **sau** khi sửa | Giá trị **trước** khi sửa |

Mọi trigger trong ECMS được viết **theo tập hợp**: một câu `INSERT … SELECT` có thể thêm 30 đăng ký cùng lúc, nên trigger luôn JOIN với `inserted`/`deleted` (VD tính lại sĩ số cho mọi lớp trong `SELECT MaLop FROM inserted UNION SELECT MaLop FROM deleted`), không gán `@MaLop = (SELECT MaLop FROM inserted)` vốn chỉ đúng khi có một dòng.

**Thứ tự kích hoạt.** DANGKY có 4 AFTER trigger cho INSERT. Dùng `sp_settriggerorder` để `trg_DangKy_KiemTraSiSo` chạy **đầu tiên** (chặn sớm, trả lỗi tiếng Việt thay vì lỗi CHECK `CK_LOPHOC_SiSo`) và `trg_DangKy_SiSo` chạy **cuối cùng**; các trigger còn lại chạy theo thứ tự không xác định. Thứ tự đầy đủ của một câu `INSERT DANGKY`: kiểm tra ràng buộc (CHECK, FK, UNIQUE) → INSERT → AFTER trigger (First → … → Last) → COMMIT. INSTEAD OF trigger chạy *thay cho* thao tác, trước cả bước kiểm tra ràng buộc.

**Nhật ký kiểm toán.** Mỗi dòng NHATKY lưu dữ liệu cũ/mới dạng JSON (`FOR JSON PATH, WITHOUT_ARRAY_WRAPPER`), login SQL Server (`SUSER_SNAME()`, mặc định của cột) và tài khoản ứng dụng (`SESSION_CONTEXT(N'app_user')` do web đặt khi đăng nhập – vì mọi người dùng web đều kết nối bằng cùng một login `ecms_app`):

```text
NHANVIEN  {"LuongCoBan":11500000} → {"LuongCoBan":12650000,"PhanTramThayDoi":10.00}  bởi sa / kiemthu
```

**Kiểm thử** – [`database/tests/test_triggers.sql`](../database/tests/test_triggers.sql) thao tác **trực tiếp lên bảng** (bỏ qua procedure) để chứng minh CSDL tự bảo vệ. Vì lỗi trong trigger luôn làm transaction "doomed" (trigger chạy với `XACT_ABORT ON`), mỗi ca chạy trong transaction riêng rồi rollback:

| Trigger | Ca | Kết quả |
|---|---|---|
| trg_DangKy_KiemTraSiSo | INSERT thẳng vào lớp đầy IE55-2602 | 50070 Lớp IE55-2602 đã đủ sĩ số, không thể ghi danh thêm. ✔ |
| trg_DangKy_SiSo | INSERT 1 đăng ký / chuyển sang Bảo lưu | 10 → 11 → 10 ✔ |
| trg_DangKy_KetQua | GK 4, CK 5 → sửa CK 7 | 4.60 Không đạt → 5.80 Đạt ✔ |
| trg_CTPhieuThu_TongTien | Thêm 1,5 tr → sửa 4 tr → xoá | Đóng một phần → Đã đóng → Chưa đóng; TongTien khớp ✔ |
| | Thu thêm cho đăng ký đã đóng đủ | 50072 Tổng số tiền đã thu vượt quá học phí phải đóng. ✔ |
| | Chi tiết là đăng ký của học viên khác | 50071 ✔ |
| trg_LichHoc_KiemTraTrung | Xếp GT3-2601 vào T7 ca 1 P101 | 50073 Trùng phòng P101 (CN03) với lớp IE55-2601. ✔ |
| trg_NhatKy_* | Các thao tác trên | 13 dòng nhật ký có `app_user = kiemthu` ✔; tăng lương 10% ghi 1 dòng, sửa cột khác không ghi ✔ |
| trg_NhatKy_ChiDoc | Sửa nhật ký | 50074 Nhật ký kiểm toán chỉ được thêm, không được sửa hoặc xoá. ✔ |
| trg_vwDangKyChiTiet_* | INSERT qua view / DELETE qua view / lớp đã kết thúc | HocPhi 4 000 000, ThanhTien 3 600 000, sĩ số +1 / Huỷ, sĩ số −1 / 50075 ✔ |

Kết quả **17/17 PASS**. `02_seed.sql` chạy lại được khi đã có trigger (tạm `DISABLE TRIGGER ALL` lúc nạp), `test_procedures.sql` vẫn 25/25 PASS khi trigger hoạt động.

**So sánh trigger và CHECK constraint**

| Tiêu chí | CHECK constraint | Trigger |
|---|---|---|
| Phạm vi | Một dòng của một bảng (liên thuộc tính) | Nhiều dòng, nhiều bảng (liên bộ, liên quan hệ) |
| Ví dụ ECMS | `GioKetThuc > GioBatDau`, `SiSoHienTai <= SiSoToiDa` | Trùng phòng giữa các lớp, tổng tiền phiếu thu |
| Thời điểm | Trước khi ghi dòng | Sau khi ghi (AFTER) hoặc thay cho thao tác (INSTEAD OF) |
| Thay đổi dữ liệu khác | Không | Có (cập nhật sĩ số, ghi nhật ký) |
| Hiệu năng | Rất nhanh, optimizer tận dụng được | Chậm hơn, chạy thêm truy vấn mỗi lần ghi |
| Thông báo lỗi | Chuẩn của SQL Server (tên ràng buộc) | Tự viết, tiếng Việt |
| Bị vô hiệu khi | `NOCHECK` | `DISABLE TRIGGER` |
| Nguyên tắc nhóm áp dụng | Dùng CHECK/FK/UNIQUE trước; chỉ dùng trigger khi ràng buộc vượt quá một dòng | |
