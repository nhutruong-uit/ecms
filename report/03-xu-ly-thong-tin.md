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

### 3.1.3 Truy vấn dữ liệu XML (Bài thực hành 2)

Kết quả kiểm tra đầu vào có cấu trúc linh hoạt (4 kỹ năng, nhận xét từng kỹ năng, nhận xét chung, khoá đề xuất) nên được lưu trong cột `KIEMTRA_DAUVAO.KetQuaChiTiet` kiểu **XML**. File [`database/09_xml.sql`](../database/09_xml.sql).

**XML Schema và typed XML.** `XSC_KetQuaKiemTra` quy định: phần tử gốc `KetQua` có thuộc tính bắt buộc `HinhThuc` ∈ {Online, Tại trung tâm}; **đúng 4** phần tử `KyNang`, mỗi phần tử có `Ten` ∈ {Listening, Reading, Writing, Speaking} và `Diem` kiểu `Diem` (decimal 0–10, 1 chữ số thập phân); `NhanXetChung`, `DeXuat` tuỳ chọn. Gắn vào cột bằng `ALTER COLUMN KetQuaChiTiet XML(DOCUMENT dbo.XSC_KetQuaKiemTra)` – toàn bộ 357 tài liệu trong dữ liệu mẫu được kiểm tra lại và hợp lệ.

XML sai cấu trúc bị từ chối:

| Trường hợp | Kết quả |
|---|---|
| Điểm 11 | ✗ 6926 XML Validation: Invalid simple type value: '11'. Location: /KetQua[1]/KyNang[1]/@Diem |
| Thiếu một kỹ năng (3/4) | ✗ 6908 XML Validation: Invalid content. Expected element(s): 'KyNang'. |
| Tên kỹ năng "Grammar" | ✗ 6926 Invalid simple type value: 'Grammar' |
| Thiếu `HinhThuc` | ✗ 6906 Required attribute 'HinhThuc' is missing. |
| Hợp lệ | ✓ |

Typed XML còn giúp truy vấn: SQL Server biết `@Diem` là số nên so sánh `@Diem >= 7` không cần ép kiểu, nhưng cũng chặt hơn – `.modify()` phải đưa vào đúng kiểu (`"5.5" cast as Diem?`), phần tử kiểu đơn không dùng được `text()`.

**Các truy vấn** (X01–X17):

| # | Câu hỏi | Phương thức / kỹ thuật |
|:-:|---|---|
| X01 | Điểm từng kỹ năng của các bài gần nhất | `.value()` với vị từ `[@Ten="Listening"]` |
| X02 | Bài có Speaking thấp hơn điểm tổng ≥ 0,7 (26 bài) | `.exist()` + `sql:column()` |
| X03 | Tách 4 kỹ năng thành 4 dòng | `.nodes()` + `CROSS APPLY` |
| X04 | Điểm TB từng kỹ năng theo hình thức thi | `.nodes()` + `GROUP BY` (qua bảng dẫn xuất) |
| X05 | Mảnh XML các kỹ năng ≥ 7 điểm | `.query()` |
| X06 | Kỹ năng yếu nhất của mỗi bài | **FLWOR** `let / for / where / order by / return` |
| X07 | Chênh lệch kỹ năng mạnh – yếu | `max()`, `min()` trong XQuery |
| X08 | Khoá đề xuất trong XML khớp cột quan hệ | `sql:column()`, `sql:variable()` |
| X09 | Phúc khảo: sửa điểm Writing | `.modify(replace value of …)` |
| X10 | Thêm / sửa nhận xét chung | `.modify(insert … after …)`, `replace value of` |
| X11 | Xoá nhận xét Listening | `.modify(delete …)` |
| X12 | XML sai cấu trúc bị từ chối | XML Schema |
| X13 | Xuất danh mục khoá học | `FOR XML RAW, ROOT` |
| X14 | Chương trình → khoá học | `FOR XML AUTO` |
| X15 | Chi nhánh → lớp đang học → học viên | `FOR XML PATH` lồng 3 cấp, `TYPE` |
| X16 | Nhập kết quả thi từ đối tác | `OPENXML` (`sp_xml_preparedocument` / `sp_xml_removedocument`) |
| X17 | Chuyển XML đối tác sang cấu trúc ECMS, kiểm tra bằng schema | `.nodes()` + `FOR XML PATH` + `CAST AS XML(DOCUMENT …)` |

**Ví dụ – FLWOR (X06):**

```sql
SELECT MaKT, KetQuaChiTiet.query('
    let $min := min(/KetQua/KyNang/@Diem)
    for $k in /KetQua/KyNang
    where $k/@Diem = $min
    order by $k/@Ten
    return <YeuNhat KyNang="{data($k/@Ten)}" Diem="{data($k/@Diem)}"/>') AS KyNangYeu
FROM KIEMTRA_DAUVAO;
```

| MaKT | KyNangYeu |
|--:|---|
| 1 | `<YeuNhat KyNang="Writing" Diem="1.3"/>` |
| 2 | `<YeuNhat KyNang="Speaking" Diem="2.3"/>` |
| 4 | `<YeuNhat KyNang="Speaking" Diem="0.2"/>` |

**X04 – điểm TB theo hình thức thi:** thi tại trung tâm cao hơn online ở cả 4 kỹ năng (Listening 4,22 so với 3,49; Reading 4,33 / 3,47; Writing 4,22 / 3,54; Speaking 4,14 / 3,52) – thông tin giúp trung tâm xem lại độ khó đề online.

**X15 – FOR XML PATH lồng nhiều cấp** xuất danh sách lớp đang học gửi đối tác ([`data/xml/danhsach_lop_dang_hoc.xml`](../data/xml/danhsach_lop_dang_hoc.xml)):

```xml
<ECMS>
  <ChiNhanh Ma="CN01" Ten="ECMS Thủ Đức">
    <Lop Ma="IE55-2602">
      <KhoaHoc>IELTS 5.5</KhoaHoc> <KhaiGiang>2026-08-19</KhaiGiang> <GiaoVien>…</GiaoVien>
      <DanhSach>
        <HocVien Ma="HV…"><HoTen>…</HoTen><NgaySinh>…</NgaySinh><HocPhi>Đã đóng</HocPhi></HocVien>
        …
```

**Đối tượng phục vụ ứng dụng web (T21):** `vw_KiemTraChiTiet` tách XML thành cột (`.value()`), `sp_GhiKetQuaKiemTra` dựng XML bằng `FOR XML PATH` vào biến kiểu `XML(DOCUMENT XSC_KetQuaKiemTra)`, tính điểm tổng và gợi ý khoá qua `fn_GoiYKhoaHoc`. Thử: L 5.5, R 6, W 5, S 4.5, chương trình IELTS → điểm tổng 5.3, đề xuất **IE55**; nhập Listening = 11 → bị XML Schema từ chối.

**So sánh lưu XML và tách thành bảng quan hệ**

| Tiêu chí | Cột XML (cách ECMS dùng) | Bảng quan hệ KETQUA_KYNANG (MaKT, KyNang, Diem, NhanXet) |
|---|---|---|
| Thay đổi cấu trúc (thêm kỹ năng Grammar, thêm điểm thành phần) | Sửa XSD, dữ liệu cũ vẫn giữ | ALTER TABLE / thêm bảng, di chuyển dữ liệu |
| Đọc nguyên một kết quả | 1 dòng, 1 cột | JOIN 4 dòng |
| Truy vấn thống kê theo kỹ năng | `.nodes()` + `.value()`, chậm hơn, cú pháp phức tạp | `GROUP BY` đơn giản, dùng chỉ mục thường |
| Ràng buộc | XSD: kiểu, miền, số lần xuất hiện | CHECK, FK, UNIQUE (MaKT, KyNang) |
| Trao đổi với hệ thống khác | Xuất / nhập nguyên văn | Phải dựng lại XML (`FOR XML`) |
| Chỉ mục | XML index (primary / secondary), tốn dung lượng | B-tree thông thường |
| Kết luận cho ECMS | Phù hợp vì kết quả test chủ yếu được ghi một lần, đọc nguyên khối và gửi đi; điểm tổng cần lọc thường xuyên được tách sẵn thành cột `DiemTong` | Phù hợp nếu cần phân tích sâu từng kỹ năng thường xuyên |

## 3.2 An ninh dữ liệu

### 3.2.1 Xác thực

**Hai cơ chế xác thực của SQL Server**

| | Windows Authentication | SQL Server Authentication |
|---|---|---|
| Ai xác thực | Windows / Active Directory (Kerberos, NTLM) | SQL Server, mật khẩu băm lưu trong `master` |
| Ưu điểm | Không truyền mật khẩu, dùng chính sách mật khẩu và khoá tài khoản của domain, đăng nhập một lần | Dùng được từ Linux/macOS, container, ứng dụng web ngoài domain |
| Nhược điểm | Cần máy trong domain hoặc tài khoản Windows | Phải tự quản lý mật khẩu, dễ lộ trong chuỗi kết nối |
| Trong ECMS | Thành viên dùng Windows + SSMS kết nối quản trị (`-E`) | Ứng dụng web (`ecms_app`) và 5 login minh hoạ vai trò |

ECMS dùng **Mixed mode** (cả hai). Script kiểm tra bằng `SERVERPROPERTY('IsIntegratedSecurityOnly')` → *Mixed mode*; trên Windows bật bằng *Server Properties → Security → SQL Server and Windows Authentication mode* (hoặc `xp_instance_regwrite … LoginMode = 2`) rồi khởi động lại dịch vụ.

**Login** ([`database/08_security.sql`](../database/08_security.sql)) – tạo mới nếu chưa có, chạy lại thì đổi mật khẩu:

| Login | User trong ECMS | Role | CHECK_POLICY | CHECK_EXPIRATION |
|---|---|---|:-:|:-:|
| `ecms_app` | u_app | r_App | ON | OFF (tài khoản dịch vụ, không được hết hạn đột ngột) |
| `ecms_quanly` | u_quanly | r_QuanLy | ON | ON |
| `ecms_giaovu` | u_giaovu | r_GiaoVu | ON | ON |
| `ecms_ketoan` | u_ketoan | r_KeToan | ON | ON |
| `ecms_giaovien` | u_giaovien | r_GiaoVien | ON | ON |
| `ecms_hocvien` | u_hocvien | r_HocVien | ON | ON |

`CHECK_POLICY = ON` áp chính sách độ phức tạp và khoá tài khoản (trên Windows lấy từ Group Policy); `CHECK_EXPIRATION = ON` buộc đổi mật khẩu định kỳ.

**Tài khoản ứng dụng (TAIKHOAN) – băm mật khẩu có salt**

Người dùng web không có login SQL Server riêng: họ đăng nhập bằng bảng TAIKHOAN, còn kết nối tới CSDL luôn là `ecms_app`. Mật khẩu không bao giờ được lưu dạng rõ:

```sql
MatKhauHash = HASHBYTES('SHA2_256', Salt + CAST(@MatKhau AS VARBINARY(200)))   -- dbo.fn_BamMatKhau
Salt        = CRYPT_GEN_RANDOM(16)                                              -- ngẫu nhiên cho từng tài khoản, đổi khi đổi mật khẩu
```

| Procedure | Chức năng |
|---|---|
| `sp_DangNhap` (@TenDangNhap, @MatKhau, @ThongBao OUTPUT) | So hash; đúng → trả thông tin người dùng + phạm vi chi nhánh (`PhamViCN`), sai → tăng `SoLanSai`, **sai 5 lần khoá tài khoản**. Thông báo chung "Sai tên đăng nhập hoặc mật khẩu" để không tiết lộ tài khoản nào tồn tại |
| `sp_DoiMatKhau` | Kiểm tra mật khẩu cũ, độ mạnh mật khẩu mới (`fn_MatKhauHopLe`: ≥ 8 ký tự, hoa, thường, số, ký tự đặc biệt), sinh salt mới |
| `sp_TaoTaiKhoan`, `sp_CapNhatTaiKhoan` | Quản trị tạo tài khoản, khoá / mở khoá, đặt lại mật khẩu |
| `vw_TaiKhoan` | Danh sách tài khoản cho trang quản trị – **không** có cột hash, salt |

`sp_DangNhap` không `THROW` khi sai mật khẩu mà trả về `@ThongBao`: nếu THROW, transaction của ứng dụng bị rollback và lần tăng `SoLanSai` cũng mất, khiến cơ chế khoá tài khoản vô hiệu.

### 3.2.2 Phân quyền

**Role và nguyên tắc.** 6 role theo tác nhân ở mục 1.4.1, áp dụng **quyền tối thiểu**. Mọi view, function, procedure và bảng cùng thuộc `dbo`, nên khi người dùng gọi view/procedure, SQL Server **không kiểm tra quyền trên bảng bên dưới** (ownership chaining). Nhờ đó có thể `DENY` bảng gốc mà view/procedure vẫn chạy – procedure không dùng SQL động để không làm đứt chuỗi sở hữu.

**r_App** được cấp tự động bằng vòng lặp trên `sys.objects`: `GRANT EXECUTE` mọi procedure và hàm vô hướng, `GRANT SELECT` mọi view và hàm trả về bảng, **`DENY SELECT, INSERT, UPDATE, DELETE` trên mọi bảng**. Kể cả khi ứng dụng bị chèn SQL, kẻ tấn công cũng không đọc được bảng TAIKHOAN hay sửa phiếu thu trực tiếp.

**Ma trận phân quyền** (G = GRANT, D = DENY, G* = GRANT … WITH GRANT OPTION, – = không cấp; *qua view/proc* = chỉ truy cập gián tiếp)

| Đối tượng | r_QuanLy | r_GiaoVu | r_KeToan | r_GiaoVien | r_HocVien | r_App |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| NHANVIEN (gồm lương) | G SELECT, UPDATE | **D SELECT** | G SELECT | **D SELECT** | – | D |
| HOCVIEN | G SELECT | G SELECT, INSERT, UPDATE | – | – | – | D |
| DANGKY | G SELECT | – | G SELECT **mức cột** (không có điểm), **D UPDATE** | – | – | D |
| PHIEUTHU, CT_PHIEUTHU | G SELECT, **D INSERT/UPDATE/DELETE** | **D** mọi thao tác (PHIEUTHU) | G SELECT, **D UPDATE/DELETE** | **D SELECT** | – | D |
| TAIKHOAN | G SELECT, **D SELECT (MatKhauHash, Salt)** | – | – | – | – | D |
| Bảng khác | G SELECT (schema) | G SELECT KHOAHOC, CHUONGTRINH; G SELECT, INSERT KIEMTRA_DAUVAO | G SELECT BANGLUONG | – | G SELECT KHOAHOC | D |
| vw_NhanVien_CongKhai | G | G | – | – | – | G |
| vw_HocVien_ChiNhanh | G | G | G | – | – | G |
| vw_CongNoHocVien | G | G | G | **D** | – | G |
| vw_SiSoLop | **G*** | G | – | – | – | G |
| vw_BangDiem, vw_LichDayGiaoVien | G | – | – | G | – | G |
| fn_LichHocHocVien | G | – | – | – | G | G |
| sp_DangKyHoc, sp_ChuyenLop, sp_XepLichLop, sp_SinhBuoiHoc, sp_TimKiemHocVien | – | G EXEC | – | – | – | G |
| sp_ThuHocPhi | – | – | G EXEC | – | – | G |
| sp_ThongKeDoanhThu, sp_TinhLuongGiaoVien | G EXEC | – | G EXEC | – | – | G |
| sp_DiemDanhBuoi, sp_NhapDiem, sp_CanhBaoChuyenCan | G EXEC (cảnh báo) | – | – | G EXEC | – | G |
| sp_DangNhap, sp_DoiMatKhau, sp_TaoTaiKhoan… | – | – | – | – | – | G |

**GRANT / REVOKE / DENY**

- `GRANT` cấp quyền; `DENY` cấm tường minh và **thắng mọi GRANT** (kể cả GRANT qua role khác hay mức schema) – VD `DENY SELECT ON TAIKHOAN (MatKhauHash, Salt)` vẫn chặn dù r_QuanLy có `GRANT SELECT ON SCHEMA::dbo`.
- `REVOKE` gỡ một GRANT *hoặc* DENY đã có, đưa về trạng thái "không được cấp". Script minh hoạ: `DENY SELECT ON SCHEMA::dbo TO r_HocVien` rồi `REVOKE` – học viên chỉ còn các quyền GRANT riêng.
- `WITH GRANT OPTION`: u_quanly được cấp `SELECT ON vw_SiSoLop WITH GRANT OPTION` nên tự cấp tiếp cho giáo viên, và tự thu hồi được; giáo vụ (không có grant option) thì không.
- Quyền **mức cột**: kế toán chỉ được SELECT các cột học phí của DANGKY, không xem điểm.

**Kiểm thử bằng `EXECUTE AS USER`** – [`database/tests/test_security.sql`](../database/tests/test_security.sql), 36 ca, trích:

| Người dùng | Thao tác | Kết quả |
|---|---|---|
| u_app | `SELECT … FROM HOCVIEN` | BỊ CHẶN (229) The SELECT permission was denied on the object 'HOCVIEN' ✔ |
| u_app | `EXEC sp_TimKiemHocVien` (đọc HOCVIEN bên trong) | ĐƯỢC – ownership chaining ✔ |
| u_app | `SELECT MatKhauHash FROM TAIKHOAN` | BỊ CHẶN (229) ✔ |
| u_giaovu | Xem lương trong NHANVIEN / xem `vw_NhanVien_CongKhai` | BỊ CHẶN (229) / ĐƯỢC ✔ |
| u_giaovu | Tự lập phiếu thu | BỊ CHẶN (229) ✔ |
| u_ketoan | `SELECT DiemCK FROM DANGKY` / `SELECT ThanhTien …` | BỊ CHẶN (230) mức cột / ĐƯỢC ✔ |
| u_ketoan | Sửa phiếu thu đã lập | BỊ CHẶN (229) ✔ |
| u_quanly | Xem `MatKhauHash` (DENY cột thắng GRANT schema) | BỊ CHẶN (230) ✔ |
| u_giaovien | Xem phiếu thu / công nợ / bảng điểm | BỊ CHẶN / BỊ CHẶN / ĐƯỢC ✔ |
| u_quanly → u_giaovien | GRANT tiếp `vw_SiSoLop` → giáo viên xem được → REVOKE → bị chặn lại | ✔ |
| u_giaovu | GRANT tiếp (không có grant option) | BỊ CHẶN (15151) ✔ |
| quanly / giaovu | `sp_DangNhap` đúng mật khẩu | QuanLy phạm vi **ALL** / GiaoVu phạm vi **CN01** ✔ |
| test.a, test.b | Cùng mật khẩu `Test@12345` | Hash khác nhau: `0xAF91BBB9…` / `0xF4C73B81…` ✔ |
| test.a | Sai 5 lần rồi nhập đúng | Tài khoản đã bị khoá ✔ |

Kết quả **36/36 PASS**. Kết nối thật bằng login `ecms_app` từ Python: `sp_DangNhap` trả thông tin người dùng, `SELECT * FROM NHANVIEN` bị từ chối – ứng dụng chỉ có đúng quyền tối thiểu.

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

### 3.2.4 Sao lưu và phục hồi

**Các loại sao lưu** (recovery model **FULL** – bắt buộc để có log backup và phục hồi theo thời điểm):

| Loại | Nội dung | Kích thước (ECMS) | Phục hồi cần |
|---|---|--:|---|
| Full | Toàn bộ CSDL + phần log đủ để nhất quán | 14,09 MB → **1,38 MB** khi nén (−90,2%) | Chỉ bản full |
| Differential | Các extent thay đổi kể từ full gần nhất | 2,09 MB → 0,12 MB (−94,2%) | Full + diff mới nhất |
| Transaction log | Mọi giao dịch kể từ log backup trước | 0,21 MB → 0,06 MB (−72,8%) | Full + diff + **mọi** log sau diff theo thứ tự; cho phép `STOPAT` |

Script [`database/11_backup_restore.sql`](../database/11_backup_restore.sql) tạo procedure dùng chung `master.dbo.sp_SaoLuuECMS @Loai = 'FULL' | 'DIFF' | 'LOG'` (tên file theo thời điểm, `COMPRESSION` – tự tắt trên bản Express, `CHECKSUM`) rồi chạy kịch bản sự cố.

**Kịch bản: xoá nhầm dữ liệu → phục hồi về đúng thời điểm trước sự cố**

| Bước | Thời điểm | Điểm danh lớp GT2-2601 | Số phiếu thu |
|---|---|--:|--:|
| 1. Full backup | 18:56:27.446 | 364 | 501 |
| 2. Thêm 1 phiếu thu → Differential backup | 18:56:27.528 | 364 | 502 |
| 3. Thêm 1 phiếu thu – **mốc T0** | 18:56:28.543 | 364 | 503 |
| 4. **SỰ CỐ**: giáo vụ `DELETE` toàn bộ điểm danh của lớp | 18:56:29.584 | **0** | 503 |
| 5. Log backup → `RESTORE` Full + Diff + Log `WITH STOPAT = T0` ra **ECMS_KhoiPhuc** | (T0) | **364** | 503 |
| 6. Chép các dòng bị xoá từ ECMS_KhoiPhuc về ECMS | 18:56:30.439 | **364** | 503 |

```sql
RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_full.bak' WITH MOVE ..., NORECOVERY, REPLACE;
RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_diff.bak' WITH NORECOVERY;
RESTORE LOG      ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_log.trn'  WITH STOPAT = @T0, RECOVERY;
```

Bản phục hồi có **503 phiếu thu** – tức là giữ được cả 2 phiếu lập sau full backup (một phiếu nằm trong diff, một phiếu chỉ có trong log) – và đủ **364 dòng điểm danh** đã bị xoá sau T0. Nhóm phục hồi *song song* ra CSDL mới thay vì ghi đè ECMS: ứng dụng không phải dừng, các giao dịch hợp lệ xảy ra sau sự cố không bị mất, chỉ những dòng bị xoá được chép lại. Phục hồi đè (`RESTORE DATABASE ECMS … WITH REPLACE` sau khi sao lưu *tail-log* `WITH NORECOVERY`) chỉ dùng khi toàn bộ CSDL hỏng.

**Kiểm tra bản sao lưu**

| Lệnh | Mục đích | Kết quả trên bản full |
|---|---|---|
| `RESTORE VERIFYONLY … WITH CHECKSUM` | Bản sao lưu đọc được, checksum từng trang đúng | Thành công cho cả 3 file |
| `RESTORE HEADERONLY` | Loại sao lưu, LSN đầu / cuối, thời điểm, có nén, collation | BackupType 1 (Full), Compressed 1, `Vietnamese_CI_AS`, MS_XPRESS |
| `RESTORE FILELISTONLY` | Tên logic / vật lý các file bên trong (cần cho `WITH MOVE`) | `ECMS` → ECMS.mdf, `ECMS_log` → ECMS_log.ldf |
| `msdb.dbo.backupset` | Lịch sử sao lưu, kích thước trước / sau nén | Bảng kích thước ở trên |

**Chiến lược sao lưu đề xuất cho trung tâm**

| Thành phần | Lịch | Giữ lại | Lý do |
|---|---|---|---|
| Full | Chủ nhật 01:00 | 4 tuần | Ngoài giờ học; nền cho chuỗi phục hồi |
| Differential | Thứ Hai – thứ Bảy 01:00 | 1 tuần | Rút ngắn chuỗi phục hồi: tối đa 1 diff thay vì 6 ngày log |
| Transaction log | Mỗi 15 phút, 07:00 – 22:00 | 2 tuần | Giới hạn mất dữ liệu ≤ 15 phút |
| Bản sao ngoài máy chủ | Hằng ngày đồng bộ thư mục `backups/` lên lưu trữ đám mây | 3 tháng | Phòng hỏng ổ đĩa / ransomware (quy tắc 3-2-1) |
| Kiểm tra phục hồi | Hằng tháng chạy lại kịch bản trên ra CSDL thử | – | Bản sao lưu chưa từng phục hồi thử thì chưa chắc dùng được |

- **RPO** (lượng dữ liệu tối đa có thể mất) = **15 phút** (chu kỳ log backup).
- **RTO** (thời gian khôi phục) ≈ **< 30 phút**: CSDL ~15 MB, phục hồi full + 1 diff + ≤ 96 log trong vài phút; phần lớn thời gian là xác định thời điểm sự cố.

**Tự động hoá:** SQL Server Agent (bản Developer/Standard; `docker-compose.yml` bật `MSSQL_AGENT_ENABLED`) – mục 4 của script có mẫu `sp_add_job`/`sp_add_schedule`. Bản Express không có Agent: dùng [`scripts/backup.sh`](../scripts/backup.sh) với cron (hoặc Task Scheduler gọi `sqlcmd`). Mục 5 của script có mẫu sao lưu **mã hoá AES-256** bằng certificate (phải sao lưu riêng certificate, mất certificate là không phục hồi được).

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

### 3.3.4 Cursor

File [`database/07_cursors.sql`](../database/07_cursors.sql) gồm 3 procedure dùng cursor cho các nghiệp vụ cần xử lý tuần tự, kèm 2 phiên bản set-based để đối chiếu:

| Procedure | Cursor | Loại cursor | Nghiệp vụ |
|---|---|---|---|
| `sp_SinhBuoiHoc` (@MaLop, @SinhLai, @SoBuoiTao OUTPUT) | `cur_Lich` – các dòng LICHHOC trùng thứ của ngày đang xét | `LOCAL FAST_FORWARD` | Duyệt từng ngày từ ngày khai giảng, bỏ ngày lễ, sinh BUOIHOC tới đủ số buổi của khoá; cập nhật ngày kết thúc lớp. Chặn sinh lại khi lớp đã điểm danh |
| `sp_TinhLuongGiaoVien` (@Thang) | `cur_GV` – giáo viên đang làm | `LOCAL STATIC READ_ONLY` | Đếm buổi *Đã dạy* trong tháng × đơn giá + lương cơ bản → UPSERT BANGLUONG |
| `sp_CanhBaoChuyenCan` (@NguongVang = 20, @SoBuoiToiThieu = 4, @MaLop, @SoCanhBao OUTPUT) | `cur_DK` – đăng ký đang học | `LOCAL FAST_FORWARD` | Tính tỷ lệ vắng; > ngưỡng thì ghi CANHBAO_CHUYENCAN (> 30% *Nghiêm trọng*) |
| `sp_TinhLuongGiaoVien_SetBased`, `sp_CanhBaoChuyenCan_SetBased` | – | – | Cùng kết quả bằng một câu `MERGE` / `INSERT … SELECT … GROUP BY` |

**Vòng đời cursor** (trích `sp_SinhBuoiHoc`):

```sql
DECLARE cur_Lich CURSOR LOCAL FAST_FORWARD FOR            -- 1. DECLARE: định nghĩa câu SELECT
    SELECT MaCa, MaPhong FROM dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu ORDER BY MaCa;
OPEN cur_Lich;                                             -- 2. OPEN: thực thi, tạo tập kết quả
FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;             -- 3. FETCH: lấy từng dòng vào biến
WHILE @@FETCH_STATUS = 0 AND @STT < @SoBuoi                --    0 = lấy được; -1 = hết dòng; -2 = dòng đã bị xoá
BEGIN
    SET @STT += 1;
    INSERT dbo.BUOIHOC (...) VALUES (@MaLop, @STT, @Ngay, @MaCa, @MaPhong, ...);
    FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;
END
CLOSE cur_Lich;                                            -- 4. CLOSE: giải phóng tập kết quả, khoá
DEALLOCATE cur_Lich;                                       -- 5. DEALLOCATE: huỷ định nghĩa cursor
```

`LOCAL` giới hạn cursor trong procedure (không đụng tên với phiên khác); khối `CATCH` kiểm tra `CURSOR_STATUS` để `DEALLOCATE` khi lỗi xảy ra giữa chừng.

**Kết quả chạy**

`sp_SinhBuoiHoc 'IE65-2601', 1` sinh **30 buổi**, ngày kết thúc 07/02/2027 – trùng khớp 100% với lịch trong dữ liệu mẫu (0 buổi khác). Gọi cho lớp IE55-2602 đã điểm danh: `50083 Lớp đã điểm danh, không thể sinh lại buổi học.`

`sp_TinhLuongGiaoVien '2026-09'` (trích):

| Giáo viên | Buổi dạy | Đơn giá | Lương cơ bản | Tổng lương |
|---|:-:|--:|--:|--:|
| Wilson David | 8 | 700 000 | 7 000 000 | 12 600 000 |
| Smith John | 8 | 800 000 | 6 000 000 | 12 400 000 |
| Lê Thanh Yến | 8 | 450 000 | 7 500 000 | 11 100 000 |
| Bùi Đức Nhiên | 0 | 400 000 | 8 000 000 | 8 000 000 |

`sp_CanhBaoChuyenCan @NguongVang = 15` → 11 cảnh báo, đầu danh sách:

| Học viên | Lớp | Đã học | Vắng | Tỷ lệ vắng | Mức độ |
|---|---|:-:|:-:|--:|---|
| Phạm Khánh Duyên | TC650-2601 | 16 | 7 | 43,75% | Nghiêm trọng |
| Trần Phương Dương | KD2-2601 | 13 | 3 | 23,08% | Nhắc nhở |
| Vũ Minh Châu | KD2-2601 | 10 | 2 | 20,00% | Nhắc nhở |

**Các loại cursor** – [`database/tests/bench_cursor.sql`](../database/tests/bench_cursor.sql) mở cursor trên bảng 3 dòng, đọc dòng 1, rồi **sửa dòng 2** và **thêm dòng 4** trong khi cursor đang mở:

| Loại | Thấy dòng bị sửa | Thấy dòng mới | Duyệt được | Đặc điểm |
|---|:-:|:-:|---|---|
| `STATIC` | Không | Không | 1:10 2:20 3:30 | Chụp toàn bộ kết quả vào tempdb lúc OPEN; cuộn tới/lui được; không cập nhật được |
| `KEYSET` | Có | Không | 1:10 **2:999** 3:30 | Lưu tập *khoá* lúc OPEN, đọc giá trị mới nhất theo khoá |
| `DYNAMIC` | Có | Có | 1:10 **2:999** 3:30 **4:40** | Đánh giá lại mỗi lần FETCH, tốn nhất |
| `FAST_FORWARD` | Có | Có | 1:10 2:999 3:30 4:40 | Chỉ tiến, chỉ đọc, tối ưu nhất – mặc định nên dùng |

**So sánh thời gian cursor và set-based** (trung bình 20 lần, mỗi lần trong transaction rồi rollback, SQL Server 2025 Docker):

| Bài toán | Cursor (ms) | Set-based (ms) | Cursor chậm hơn | Kết quả giống nhau |
|---|--:|--:|--:|:-:|
| Cảnh báo chuyên cần (toàn bộ đăng ký đang học) | 13,25 | 5,94 | 2,2 lần | ✔ |
| Bảng lương 12 tháng năm 2025 (tổng 1 000 400 000 đ) | 47,98 | 11,51 | 4,2 lần | ✔ |
| Sinh 30 buổi học (lớp IE65-2601) | 10,50 | 4,77 | 2,2 lần | ✔ (cùng ngày kết thúc) |

**Nhận xét.** Set-based nhanh hơn 2–4 lần ngay trên dữ liệu nhỏ, và khoảng cách tăng theo số dòng vì cursor thực hiện một truy vấn con cho *mỗi* dòng (10 giáo viên × 12 tháng = 120 lần đếm buổi) trong khi set-based để optimizer gộp thành một kế hoạch. Cursor vẫn hợp lý khi logic phụ thuộc kết quả bước trước (sinh buổi học: số thứ tự và điều kiện dừng phụ thuộc số buổi đã sinh, dễ đọc hơn hẳn câu CTE dùng bảng số), khi cần gọi procedure cho từng dòng, hoặc xử lý theo lô nhỏ để tránh khoá lâu. Nguyên tắc nhóm áp dụng: **mặc định set-based, chỉ dùng cursor `LOCAL FAST_FORWARD` khi bài toán thật sự tuần tự**.
