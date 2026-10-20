# Chương 3. Xử lý thông tin

Nếu Chương 2 trả lời câu hỏi "dữ liệu được tổ chức thế nào", thì Chương 3 trả lời câu hỏi "dữ liệu được biến thành thông tin và được bảo vệ ra sao". Chương gồm ba phần. Phần thứ nhất trình bày bộ truy vấn SQL và XML trả lời các câu hỏi quản lý thực tế, kèm đo đạc hiệu quả của chỉ mục. Phần thứ hai trình bày an ninh dữ liệu: xác thực, phân quyền, view bảo mật, sao lưu – phục hồi và nhập – xuất dữ liệu. Phần thứ ba trình bày lập trình trên CSDL bằng stored procedure, function, trigger và cursor. Mọi kết quả trong chương được đo trên dữ liệu mẫu với ngày tham chiếu 15/10/2026, chạy trên SQL Server 2025 trong Docker.

## 3.1 Truy vấn dữ liệu

### 3.1.1 Bộ truy vấn nghiệp vụ

**Phân tích.** Thay vì viết truy vấn để minh hoạ cú pháp, nhóm xuất phát từ các câu hỏi mà quản lý, giáo vụ, kế toán thực sự đặt ra hằng ngày, rồi chọn kỹ thuật SQL phù hợp để trả lời. Kết quả là bộ 31 truy vấn chia thành sáu nhóm kỹ thuật, mỗi nhóm có ít nhất năm câu. Cột cuối là số dòng kết quả trên dữ liệu mẫu, dùng để đối chiếu khi chạy lại.

| Nhóm | Câu | Câu hỏi nghiệp vụ | Kỹ thuật | Số dòng |
|---|:-:|---|---|--:|
| Cơ bản | Q01 | Học viên họ Nguyễn hoặc Trần ở chi nhánh Thủ Đức | `LIKE`, `IN`, `ORDER BY` | 34 |
| | Q02 | Khoá học có học phí 4 – 6 triệu và học phí mỗi buổi | `BETWEEN`, biểu thức | 7 |
| | Q03 | Học viên chưa có email | `IS NULL` | 101 |
| | Q04 | 5 phiếu thu lớn nhất năm 2026 | `TOP … WITH TIES` | 5 |
| | Q05 | Lớp quý IV/2026 chưa đạt 60% sĩ số | Điều kiện kết hợp | 2 |
| Kết nối | Q06 | Lớp đang học kèm khoá, chi nhánh, giáo viên, lịch | `INNER JOIN` 6 bảng, `STRING_AGG` | 5 |
| | Q07 | Mọi giáo viên và số lớp phụ trách, kể cả 0 lớp | `LEFT JOIN` | 10 |
| | Q08 | Phòng chưa từng được xếp lịch | `RIGHT JOIN … IS NULL` | 6 |
| | Q09 | Đối chiếu khoá học và lớp học | `FULL OUTER JOIN` | 25 |
| | Q10 | Nhân viên và người quản lý trực tiếp | Kết nối với chính nó | 20 |
| Gom nhóm | Q11 | Doanh thu theo chi nhánh và tháng năm 2026 | `GROUP BY`, `SUM` | 18 |
| | Q12 | Sĩ số trung bình, nhỏ nhất, lớn nhất theo khoá | `AVG`, `MIN`, `MAX`, `HAVING` | 12 |
| | Q13 | Chương trình có tỷ lệ đạt dưới 95% | `HAVING` với biểu thức | 4 |
| | Q14 | Cơ cấu hình thức thanh toán theo năm | `GROUP BY` hai cột | 6 |
| | Q15 | Doanh thu chi nhánh có tổng phụ và tổng cộng | `ROLLUP` | 10 |
| Lồng | Q16 | Học viên từng học chương trình IELTS | `IN (truy vấn con)` | 93 |
| | Q17 | Khách đã kiểm tra đầu vào nhưng chưa ghi danh | `NOT EXISTS` | 15 |
| | Q18 | Học viên có điểm trung bình cao hơn trung bình lớp | Truy vấn con tương quan | 174 |
| | Q19 | Lớp năm 2026 lấp đầy hơn mọi lớp cùng khoá năm 2025 | `> ALL` | 7 |
| | Q20 | Học viên còn nợ học phí | Truy vấn con trong `SELECT` và `FROM` | 58 |
| Tập hợp | Q21 | Danh bạ chung của nhân viên và học viên | `UNION` | 369 |
| | Q22 | Học viên học cả IELTS và TOEIC | `INTERSECT` | 2 |
| | Q23 | Đạt cấp 1 nhưng chưa học cấp 2 | `EXCEPT` | 69 |
| | Q24 | Học viên học tất cả khoá của một chương trình | Phép chia bằng `NOT EXISTS` lồng | 36 |
| | Q24b | Như Q24, viết bằng cách đếm | `HAVING COUNT = (truy vấn con)` | 36 |
| Nâng cao | Q25 | Doanh thu tháng, luỹ kế và chênh lệch với tháng trước | CTE, `SUM() OVER`, `LAG` | 7 |
| | Q26 | Lộ trình tiên quyết tới IELTS 6.5+ và TOEIC 850+ | CTE đệ quy | 2 |
| | Q27 | Cây quản lý nhân viên | CTE đệ quy | 20 |
| | Q28 | Ba học viên điểm cao nhất mỗi lớp | `RANK`, `DENSE_RANK`, `NTILE`, `PARTITION BY` | 49 |
| | Q29 | Doanh thu chi nhánh theo quý năm 2025 | `PIVOT` | 3 |
| | Q30 | Thống kê điểm danh các lớp đang học | `PIVOT` kết hợp tỷ lệ | 5 |

Dưới đây phân tích bốn truy vấn tiêu biểu cho các kỹ thuật khó.

**Phép chia (Q24).** Câu hỏi "học viên *h* đã học mọi khoá của chương trình *ct*" là bài toán chia trong đại số quan hệ. SQL không có phép chia trực tiếp nên nhóm chuyển câu hỏi về dạng phủ định kép tương đương: "không tồn tại khoá *k* thuộc *ct* mà *h* chưa đăng ký".

```sql title="Mã lệnh – Q24: Học viên đã học mọi khoá của một chương trình"
SELECT h.MaHV, h.HoTen, ct.TenCT
FROM HOCVIEN h CROSS JOIN CHUONGTRINH ct
WHERE NOT EXISTS (SELECT 1 FROM KHOAHOC k WHERE k.MaCT = ct.MaCT
        AND NOT EXISTS (SELECT 1 FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop
                        WHERE d.MaHV = h.MaHV AND l.MaKH = k.MaKH));
```

Để kiểm chứng, nhóm viết thêm cách thứ hai (Q24b) bằng cách đếm số khoá đã học của mỗi học viên trong chương trình rồi so với tổng số khoá của chương trình. Hai cách viết độc lập cho cùng **36** cặp học viên – chương trình, xác nhận kết quả đúng.

**CTE đệ quy (Q26).** Lộ trình học là một chuỗi khoá tiên quyết có độ dài không biết trước. CTE đệ quy bắt đầu từ khoá đích và lần ngược theo cột `MaKHTienQuyet` cho tới khi gặp khoá không có tiên quyết. Kết quả:

| Khoá xuất phát | Số bước | Lộ trình |
|---|:-:|---|
| IEF | 2 | IELTS Foundation → IELTS 5.5 → IELTS 6.5+ |
| TC450 | 2 | TOEIC 450 → TOEIC 650 → TOEIC 850+ |

**Tổng phụ bằng ROLLUP (Q15).** `GROUP BY ROLLUP (MaCN, Nam)` sinh thêm dòng tổng của từng chi nhánh và dòng tổng toàn trung tâm trong cùng một câu truy vấn, thay cho việc cộng tay như khi dùng Excel. Trích kết quả:

| Chi nhánh | Năm | Doanh thu (đồng) |
|---|---|--:|
| CN01 | 2025 | 352.950.000 |
| CN01 | 2026 | 459.525.000 |
| CN01 | Cả kỳ | 812.475.000 |
| CN02 | Cả kỳ | 711.627.000 |
| … | | |

**Xoay bảng bằng PIVOT (Q29).** Doanh thu năm 2025 của từng chi nhánh được xoay từ dạng dòng sang dạng cột theo quý, đúng hình thức báo cáo mà quản lý quen đọc:

| Chi nhánh | Quý I | Quý II | Quý III | Quý IV |
|---|--:|--:|--:|--:|
| CN01 | 168.650.000 | 62.475.000 | 0 | 121.825.000 |
| CN02 | 78.750.000 | 173.610.000 | 19.530.000 | 74.000.000 |
| CN03 | 52.500.000 | 71.100.000 | 0 | 259.650.000 |

**Nhận xét.** Bảng PIVOT cho thấy doanh thu dồn vào các quý có đợt khai giảng (quý I, II, IV), trong khi quý III gần như không có doanh thu ở hai chi nhánh. Đây là ví dụ điển hình của việc biến dữ liệu thành thông tin: từ hàng trăm phiếu thu rời rạc, quản lý nhận được một bảng mười hai con số đủ để lên kế hoạch dòng tiền và mở chiến dịch tuyển sinh cho quý III.

### 3.1.2 Hiệu năng truy vấn và vai trò của chỉ mục

**Phân tích.** Dữ liệu mẫu chỉ có khoảng 10 nghìn dòng điểm danh – quá nhỏ để thấy khác biệt khi có và không có chỉ mục. Vì vậy nhóm nhân bản bảng DIEMDANH thành một bảng tạm **1.000.000 dòng**, rồi chạy cùng một truy vấn trước và sau khi tạo chỉ mục. Số liệu được thu bằng `SET STATISTICS IO, TIME ON`; số trang đọc logic (logical reads) được dùng làm thước đo chính vì ổn định giữa các lần chạy, còn thời gian CPU chỉ để tham khảo.

| Truy vấn | Không có chỉ mục | Có chỉ mục | Mức giảm |
|---|---|---|--:|
| P1 – chuyên cần của một đăng ký (`WHERE MaDK = …`) | Quét toàn bộ, 6.023 trang, CPU 62 ms | Tìm trực tiếp trên `IX_DD_MaDK`, 3 trang, CPU 0 ms | 99,9% |
| P2 – thống kê một lớp (`WHERE MaLop = … GROUP BY`) | Quét toàn bộ, 6.023 trang, CPU 194 ms | Tìm trực tiếp trên `IX_DD_MaLop`, 150 trang, CPU 13 ms | 97,5% |
| P3 – phiếu thu tháng 3/2026 viết `YEAR(NgayThu) = 2026 AND MONTH(NgayThu) = 3` | Quét chỉ mục, 5 trang | – | |
| P3' – cùng điều kiện viết `NgayThu >= '2026-03-01' AND NgayThu < '2026-04-01'` | – | Tìm trực tiếp trên `IX_PHIEUTHU_NgayThu`, 2 trang | 60% |

**Nhận xét.**

- Chỉ mục của P1 có cột `INCLUDE (TrangThai)` nên là **chỉ mục bao phủ**: truy vấn đọc được mọi cột cần thiết ngay trên chỉ mục mà không phải tra lại bảng, vì thế chỉ còn 3 trang.
- P2 lọc ra khoảng 1% bảng nên vẫn phải đọc 150 trang, nhưng ít hơn quét toàn bộ khoảng 40 lần.
- Cặp P3 và P3' cho thấy một lỗi thường gặp: bọc cột trong hàm `YEAR()`, `MONTH()` làm điều kiện **không khai thác được chỉ mục** (non-SARGable), dù chỉ mục đã có. Nhóm áp dụng quy tắc viết điều kiện theo khoảng cho mọi view báo cáo và procedure thống kê doanh thu.

### 3.1.3 Truy vấn dữ liệu XML

**Phân tích.** Kết quả kiểm tra đầu vào có cấu trúc linh hoạt: bốn kỹ năng, mỗi kỹ năng có điểm và nhận xét, thêm nhận xét chung và khoá đề xuất; trong tương lai có thể bổ sung kỹ năng hoặc điểm thành phần. Nhóm lưu phần này trong cột `KIEMTRA_DAUVAO.KetQuaChiTiet` kiểu XML và dùng nó để thực hiện nội dung Bài thực hành số 2 trên chính dữ liệu của đồ án.

**XML Schema.** Để cột XML không trở thành nơi chứa dữ liệu tuỳ tiện, nhóm định nghĩa tập lược đồ `XSC_KetQuaKiemTra` với các quy định: phần tử gốc `KetQua` có thuộc tính bắt buộc `HinhThuc` nhận một trong hai giá trị *Online* hoặc *Tại trung tâm*; có **đúng bốn** phần tử `KyNang`, mỗi phần tử có thuộc tính `Ten` thuộc {Listening, Reading, Writing, Speaking} và `Diem` là số thập phân từ 0 đến 10 với một chữ số lẻ; các phần tử `NhanXetChung`, `DeXuat` là tuỳ chọn. Lược đồ được gắn vào cột bằng lệnh:

```sql title="Mã lệnh – Gắn XML Schema vào cột kết quả kiểm tra"
ALTER TABLE dbo.KIEMTRA_DAUVAO
    ALTER COLUMN KetQuaChiTiet XML(DOCUMENT dbo.XSC_KetQuaKiemTra);
```

Khi gắn lược đồ, SQL Server kiểm tra lại toàn bộ 357 tài liệu đã có và tất cả đều hợp lệ. Sau đó nhóm thử ghi các tài liệu sai cấu trúc:

| Trường hợp thử | Kết quả |
|---|---|
| Điểm một kỹ năng bằng 11 | Bị từ chối – lỗi 6926: Invalid simple type value '11' tại `/KetQua[1]/KyNang[1]/@Diem` |
| Chỉ có ba kỹ năng | Bị từ chối – lỗi 6908: Invalid content, thiếu phần tử `KyNang` |
| Tên kỹ năng "Grammar" | Bị từ chối – lỗi 6926: Invalid simple type value 'Grammar' |
| Thiếu thuộc tính `HinhThuc` | Bị từ chối – lỗi 6906: Required attribute 'HinhThuc' is missing |
| Tài liệu đúng lược đồ | Được chấp nhận |

Lược đồ còn giúp truy vấn: vì SQL Server biết `@Diem` là kiểu số nên phép so sánh `@Diem >= 7` không cần ép kiểu. Đổi lại, các thao tác sửa bằng `.modify()` phải đưa vào đúng kiểu dữ liệu đã khai báo.

**Bộ truy vấn XML.** Nhóm viết 17 truy vấn bao quát đủ các phương thức của kiểu XML, XQuery và các cách chuyển đổi giữa dữ liệu quan hệ với XML:

| Câu | Câu hỏi | Phương thức, kỹ thuật |
|:-:|---|---|
| X01 | Điểm từng kỹ năng của các bài kiểm tra gần nhất | `.value()` với vị từ `[@Ten="Listening"]` |
| X02 | Bài có điểm Speaking thấp hơn điểm tổng từ 0,7 trở lên (26 bài) | `.exist()` kết hợp `sql:column()` |
| X03 | Tách bốn kỹ năng thành bốn dòng | `.nodes()` với `CROSS APPLY` |
| X04 | Điểm trung bình từng kỹ năng theo hình thức thi | `.nodes()` kết hợp `GROUP BY` |
| X05 | Trích các kỹ năng đạt từ 7 điểm trở lên | `.query()` |
| X06 | Kỹ năng yếu nhất của mỗi bài | Biểu thức FLWOR `let / for / where / order by / return` |
| X07 | Chênh lệch giữa kỹ năng mạnh nhất và yếu nhất | Hàm `max()`, `min()` trong XQuery |
| X08 | Khoá đề xuất trong XML có khớp cột quan hệ không | `sql:column()`, `sql:variable()` |
| X09 | Phúc khảo: sửa điểm Writing | `.modify(replace value of …)` |
| X10 | Thêm hoặc sửa nhận xét chung | `.modify(insert … after …)` |
| X11 | Xoá nhận xét kỹ năng Listening | `.modify(delete …)` |
| X12 | Tài liệu sai cấu trúc bị từ chối | XML Schema |
| X13 | Xuất danh mục khoá học | `FOR XML RAW, ROOT` |
| X14 | Xuất chương trình kèm khoá học | `FOR XML AUTO` |
| X15 | Xuất chi nhánh, lớp đang học và học viên | `FOR XML PATH` lồng ba cấp, `TYPE` |
| X16 | Nhập kết quả thi từ đối tác | `OPENXML` với `sp_xml_preparedocument` |
| X17 | Chuyển XML của đối tác sang cấu trúc ECMS và kiểm tra bằng lược đồ | `.nodes()`, `FOR XML PATH`, ép kiểu về XML có lược đồ |

Truy vấn X06 minh hoạ sức mạnh của XQuery: biểu thức FLWOR tìm điểm thấp nhất trong bốn kỹ năng, duyệt lại các kỹ năng để chọn kỹ năng có điểm bằng giá trị đó và dựng một phần tử XML mới làm kết quả.

```sql title="Mã lệnh – X06: Kỹ năng yếu nhất của mỗi bài kiểm tra"
SELECT MaKT, KetQuaChiTiet.query('
    let $min := min(/KetQua/KyNang/@Diem)
    for $k in /KetQua/KyNang
    where $k/@Diem = $min
    order by $k/@Ten
    return <YeuNhat KyNang="{data($k/@Ten)}" Diem="{data($k/@Diem)}"/>') AS KyNangYeu
FROM KIEMTRA_DAUVAO;
```

Kết quả (trích ba dòng đầu):

| MaKT | KyNangYeu |
|--:|---|
| 1 | `<YeuNhat KyNang="Writing" Diem="1.3"/>` |
| 2 | `<YeuNhat KyNang="Speaking" Diem="2.3"/>` |
| 4 | `<YeuNhat KyNang="Speaking" Diem="0.2"/>` |

Truy vấn X04 cho một kết quả có giá trị quản lý: học viên thi tại trung tâm có điểm cao hơn thi trực tuyến ở cả bốn kỹ năng (Listening 4,22 so với 3,49; Reading 4,33 so với 3,47; Writing 4,22 so với 3,54; Speaking 4,14 so với 3,52). Đây là dấu hiệu để trung tâm xem lại độ khó hoặc điều kiện làm bài của đề trực tuyến. Truy vấn X15 xuất danh sách lớp đang học kèm học viên thành một tệp XML phân cấp ba mức để gửi cho đối tác.

**Phục vụ ứng dụng web.** Phần XML không chỉ dừng ở truy vấn minh hoạ mà được dùng trực tiếp trong form kiểm tra đầu vào (mục 4.2). View `vw_KiemTraChiTiet` tách XML thành các cột bằng `.value()`; procedure `sp_GhiKetQuaKiemTra` dựng tài liệu XML bằng `FOR XML PATH` vào một biến kiểu XML có lược đồ, tính điểm tổng và gợi ý khoá học bằng hàm `fn_GoiYKhoaHoc`. Khi thử nhập Listening 5,5, Reading 6, Writing 5, Speaking 4,5 cho chương trình IELTS, procedure trả về điểm tổng 5,3 và đề xuất khoá **IE55**; nhập Listening bằng 11 thì bị lược đồ XML từ chối.

**So sánh lưu XML với tách thành bảng quan hệ.** Một phương án khác là tách kết quả kiểm tra thành bảng KETQUA_KYNANG (MaKT, KyNang, Diem, NhanXet). Hai phương án được so sánh như sau:

| Tiêu chí | Cột XML (phương án ECMS dùng) | Bảng quan hệ KETQUA_KYNANG |
|---|---|---|
| Thay đổi cấu trúc (thêm kỹ năng, thêm điểm thành phần) | Sửa XML Schema, dữ liệu cũ vẫn giữ nguyên | Phải ALTER TABLE hoặc thêm bảng, di chuyển dữ liệu |
| Đọc nguyên một kết quả | Một dòng, một cột | Kết nối và đọc bốn dòng |
| Thống kê theo kỹ năng | `.nodes()` và `.value()`, chậm hơn, cú pháp phức tạp | `GROUP BY` đơn giản, dùng chỉ mục thường |
| Ràng buộc | XSD: kiểu, miền giá trị, số lần xuất hiện | CHECK, khoá ngoại, UNIQUE (MaKT, KyNang) |
| Trao đổi với hệ thống khác | Xuất, nhập nguyên văn | Phải dựng lại XML bằng `FOR XML` |
| Chỉ mục | Chỉ mục XML, tốn nhiều dung lượng | Chỉ mục B-tree thông thường |

**Nhận xét.** Lưu XML phù hợp với ECMS vì kết quả kiểm tra chủ yếu được ghi một lần, đọc nguyên khối và gửi đi; riêng điểm tổng cần lọc và sắp xếp thường xuyên đã được tách sẵn thành cột `DiemTong`. Nếu trung tâm cần phân tích sâu từng kỹ năng thường xuyên, phương án bảng quan hệ sẽ phù hợp hơn.

## 3.2 An ninh dữ liệu

### 3.2.1 Xác thực

**Hai cơ chế xác thực của SQL Server.** SQL Server hỗ trợ hai cách xác thực người kết nối, mỗi cách có ưu, nhược điểm riêng:

| Tiêu chí | Windows Authentication | SQL Server Authentication |
|---|---|---|
| Bên xác thực | Windows, Active Directory (Kerberos, NTLM) | SQL Server; mật khẩu được băm và lưu trong CSDL `master` |
| Ưu điểm | Không truyền mật khẩu; dùng chính sách mật khẩu và khoá tài khoản của domain; đăng nhập một lần | Dùng được từ Linux, macOS, container và ứng dụng web ngoài domain |
| Nhược điểm | Cần máy trong domain hoặc tài khoản Windows | Phải tự quản lý mật khẩu; dễ lộ nếu để trong chuỗi kết nối |
| Sử dụng trong ECMS | Thành viên dùng Windows kết nối quản trị bằng SSMS | Ứng dụng web (`ecms_app`) và năm login minh hoạ vai trò |

Vì cần cả hai, ECMS chạy ở **chế độ hỗn hợp** (Mixed mode). Script kiểm tra chế độ hiện tại bằng `SERVERPROPERTY('IsIntegratedSecurityOnly')`; trên Windows, chế độ này được bật trong *Server Properties → Security → SQL Server and Windows Authentication mode* rồi khởi động lại dịch vụ.

**Login và user.** Nhóm tạo sáu login, mỗi login gắn với một user trong CSDL ECMS và một role. Script tạo login nếu chưa có, chạy lại thì chỉ đổi mật khẩu.

| Login | User | Role | Kiểm tra độ mạnh mật khẩu | Buộc đổi mật khẩu định kỳ |
|---|---|---|:-:|:-:|
| `ecms_app` | u_app | r_App | Có | Không (tài khoản dịch vụ, không được hết hạn đột ngột) |
| `ecms_quanly` | u_quanly | r_QuanLy | Có | Có |
| `ecms_giaovu` | u_giaovu | r_GiaoVu | Có | Có |
| `ecms_ketoan` | u_ketoan | r_KeToan | Có | Có |
| `ecms_giaovien` | u_giaovien | r_GiaoVien | Có | Có |
| `ecms_hocvien` | u_hocvien | r_HocVien | Có | Có |

**Tài khoản ứng dụng và băm mật khẩu.** Người dùng web không có login SQL Server riêng: họ đăng nhập bằng bảng TAIKHOAN, còn kết nối tới CSDL luôn dùng login `ecms_app`. Mật khẩu không bao giờ được lưu ở dạng rõ mà được băm bằng SHA2-256 sau khi trộn với một chuỗi ngẫu nhiên (salt) 16 byte riêng cho từng tài khoản. Nhờ salt, hai người đặt cùng mật khẩu vẫn có giá trị băm khác nhau, và kẻ tấn công không thể dùng bảng băm tính sẵn.

```sql title="Mã lệnh – Hàm băm mật khẩu có salt"
CREATE OR ALTER FUNCTION dbo.fn_BamMatKhau (@MatKhau NVARCHAR(100), @Salt VARBINARY(16))
RETURNS VARBINARY(32)
WITH SCHEMABINDING
AS
BEGIN
    RETURN HASHBYTES('SHA2_256', @Salt + CAST(@MatKhau AS VARBINARY(200)));
END
GO
-- Khi tạo tài khoản hoặc đổi mật khẩu: Salt = CRYPT_GEN_RANDOM(16)
```

Các procedure quản lý tài khoản được thiết kế như sau:

| Procedure | Chức năng |
|---|---|
| `sp_DangNhap` | So sánh giá trị băm. Đúng thì trả thông tin người dùng và phạm vi chi nhánh; sai thì tăng số lần sai, sai 5 lần liên tiếp thì khoá tài khoản. Thông báo lỗi chung "Sai tên đăng nhập hoặc mật khẩu" để không tiết lộ tài khoản nào tồn tại |
| `sp_DoiMatKhau` | Kiểm tra mật khẩu cũ và độ mạnh của mật khẩu mới (từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt), sinh salt mới |
| `sp_TaoTaiKhoan`, `sp_CapNhatTaiKhoan` | Quản trị tạo tài khoản, khoá, mở khoá, đặt lại mật khẩu |
| `vw_TaiKhoan` | Danh sách tài khoản cho trang quản trị, **không** có cột giá trị băm và salt |

**Phân tích một quyết định thiết kế.** `sp_DangNhap` không ném lỗi (`THROW`) khi sai mật khẩu mà trả kết quả qua tham số `@ThongBao`. Nếu ném lỗi, giao dịch của ứng dụng sẽ bị huỷ và lệnh tăng số lần sai cũng bị huỷ theo, khiến cơ chế khoá tài khoản sau 5 lần sai không bao giờ có hiệu lực.

### 3.2.2 Phân quyền

**Nguyên tắc.** Sáu role tương ứng sáu tác nhân ở mục 1.5.1 được cấp quyền theo nguyên tắc **quyền tối thiểu**: mỗi role chỉ có đúng những quyền cần cho công việc. Mọi bảng, view, function và procedure đều thuộc schema `dbo` của cùng một chủ sở hữu, nên khi người dùng gọi một view hoặc procedure, SQL Server **không kiểm tra lại quyền trên các bảng bên dưới** – cơ chế này gọi là chuỗi sở hữu (ownership chaining). Nhờ đó có thể cấm truy cập bảng gốc mà view và procedure vẫn hoạt động. Để không làm đứt chuỗi sở hữu, các procedure không dùng SQL động.

**Quyền của ứng dụng web.** Role `r_App` của login `ecms_app` được cấp tự động bằng một vòng lặp trên khung nhìn hệ thống `sys.objects`: cấp quyền thực thi cho mọi procedure và hàm vô hướng, quyền đọc cho mọi view và hàm trả về bảng, đồng thời **cấm mọi thao tác trên mọi bảng**.

```sql title="Mã lệnh – Sinh lệnh cấp quyền cho r_App theo loại đối tượng"
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += CASE o.type
    WHEN 'P'  THEN N'GRANT EXECUTE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    WHEN 'FN' THEN N'GRANT EXECUTE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    WHEN 'V'  THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    WHEN 'IF' THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    WHEN 'TF' THEN N'GRANT SELECT ON '  + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
    WHEN 'U'  THEN N'DENY SELECT, INSERT, UPDATE, DELETE ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N' TO r_App;'
END
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0 AND o.type IN ('P', 'FN', 'V', 'IF', 'TF', 'U') AND s.name = 'dbo';
EXEC sp_executesql @sql;
```

Thiết kế này có ý nghĩa bảo mật quan trọng: kể cả khi ứng dụng bị tấn công chèn mã SQL, kẻ tấn công cũng không thể đọc bảng TAIKHOAN hay sửa trực tiếp một phiếu thu, vì login của ứng dụng không có bất kỳ quyền nào trên bảng.

**Ma trận phân quyền.** Bảng dưới đây tóm tắt quyền của từng role trên các đối tượng chính. Ký hiệu: G là cấp quyền (GRANT), D là cấm (DENY), G* là cấp quyền kèm quyền cấp tiếp (WITH GRANT OPTION), dấu gạch là không cấp.

| Đối tượng | r_QuanLy | r_GiaoVu | r_KeToan | r_GiaoVien | r_HocVien | r_App |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| NHANVIEN (có cột lương) | G SELECT, UPDATE | D SELECT | G SELECT | D SELECT | – | D |
| HOCVIEN | G SELECT | G SELECT, INSERT, UPDATE | – | – | – | D |
| DANGKY | G SELECT | – | G SELECT mức cột (không gồm điểm), D UPDATE | – | – | D |
| PHIEUTHU, CT_PHIEUTHU | G SELECT, D INSERT/UPDATE/DELETE | D mọi thao tác | G SELECT, D UPDATE/DELETE | D SELECT | – | D |
| TAIKHOAN | G SELECT, D SELECT trên cột băm và salt | – | – | – | – | D |
| Các bảng khác | G SELECT toàn schema | G SELECT KHOAHOC, CHUONGTRINH; G SELECT, INSERT KIEMTRA_DAUVAO | G SELECT BANGLUONG | – | G SELECT KHOAHOC | D |
| vw_NhanVien_CongKhai | G | G | – | – | – | G |
| vw_HocVien_ChiNhanh | G | G | G | – | – | G |
| vw_CongNoHocVien | G | G | G | D | – | G |
| vw_SiSoLop | G* | G | – | – | – | G |
| vw_BangDiem, vw_LichDayGiaoVien | G | – | – | G | – | G |
| fn_LichHocHocVien | G | – | – | – | G | G |
| Procedure ghi danh, chuyển lớp, xếp lịch, sinh buổi học, tìm kiếm | – | G EXECUTE | – | – | – | G |
| sp_ThuHocPhi | – | – | G EXECUTE | – | – | G |
| sp_ThongKeDoanhThu, sp_TinhLuongGiaoVien | G EXECUTE | – | G EXECUTE | – | – | G |
| Procedure điểm danh, nhập điểm, cảnh báo chuyên cần | G EXECUTE (cảnh báo) | – | – | G EXECUTE | – | G |
| Procedure đăng nhập, đổi mật khẩu, quản lý tài khoản | – | – | – | – | – | G |

**GRANT, REVOKE, DENY và WITH GRANT OPTION.** Script minh hoạ đủ bốn câu lệnh phân quyền:

- `GRANT` cấp quyền; `DENY` cấm tường minh và **luôn thắng** mọi GRANT, kể cả GRANT nhận qua role khác hay ở mức schema. Ví dụ `DENY SELECT ON TAIKHOAN (MatKhauHash, Salt)` vẫn chặn quản lý xem giá trị băm dù r_QuanLy đã được cấp quyền đọc toàn schema.
- `REVOKE` gỡ một GRANT hoặc một DENY đã có, đưa về trạng thái "không được cấp". Script minh hoạ bằng cách cấm r_HocVien đọc toàn schema rồi thu hồi lệnh cấm đó; học viên chỉ còn các quyền được cấp riêng.
- `WITH GRANT OPTION`: u_quanly được cấp quyền đọc `vw_SiSoLop` kèm quyền cấp tiếp, nên có thể tự cấp cho giáo viên và tự thu hồi; giáo vụ không có quyền cấp tiếp nên không làm được.
- Quyền **mức cột**: kế toán chỉ được đọc các cột học phí của DANGKY, không xem được điểm.

**Kiểm thử.** Bộ kiểm thử `test_security.sql` dùng lệnh `EXECUTE AS USER` để lần lượt đóng vai từng user và thử các thao tác được phép lẫn không được phép. Trích kết quả tiêu biểu:

| Người dùng | Thao tác | Mong đợi | Kết quả |
|---|---|---|:-:|
| u_app | Đọc trực tiếp bảng HOCVIEN | Bị chặn (lỗi 229) | Đạt |
| u_app | Gọi `sp_TimKiemHocVien` (bên trong đọc HOCVIEN) | Được phép nhờ chuỗi sở hữu | Đạt |
| u_app | Đọc cột `MatKhauHash` của TAIKHOAN | Bị chặn (lỗi 229) | Đạt |
| u_giaovu | Xem lương trong NHANVIEN; xem `vw_NhanVien_CongKhai` | Bị chặn; được phép | Đạt |
| u_giaovu | Tự lập phiếu thu | Bị chặn (lỗi 229) | Đạt |
| u_ketoan | Đọc cột điểm cuối kỳ; đọc cột thành tiền của DANGKY | Bị chặn mức cột (lỗi 230); được phép | Đạt |
| u_ketoan | Sửa phiếu thu đã lập | Bị chặn (lỗi 229) | Đạt |
| u_quanly | Xem `MatKhauHash` dù có quyền đọc toàn schema | Bị chặn (lỗi 230) – DENY thắng GRANT | Đạt |
| u_giaovien | Xem phiếu thu; xem công nợ; xem bảng điểm | Bị chặn; bị chặn; được phép | Đạt |
| u_quanly cấp cho u_giaovien | Cấp tiếp quyền xem `vw_SiSoLop`, rồi thu hồi | Giáo viên xem được, sau khi thu hồi bị chặn lại | Đạt |
| u_giaovu | Cấp tiếp quyền khi không có grant option | Bị chặn (lỗi 15151) | Đạt |
| quanly, giaovu | Đăng nhập đúng mật khẩu | Quản lý phạm vi toàn trung tâm; giáo vụ phạm vi CN01 | Đạt |
| test.a, test.b | Hai tài khoản cùng mật khẩu `Test@12345` | Hai giá trị băm khác nhau | Đạt |
| test.a | Sai mật khẩu 5 lần rồi nhập đúng | Tài khoản đã bị khoá | Đạt |

Kết quả **36/36 ca đạt**. Nhóm cũng kết nối thật bằng login `ecms_app` từ Python: `sp_DangNhap` trả về thông tin người dùng, còn `SELECT * FROM NHANVIEN` bị từ chối – ứng dụng chỉ có đúng quyền tối thiểu.

### 3.2.3 View bảo mật và view phục vụ báo cáo

**Phân tích.** CSDL có tổng cộng 27 view. Ứng dụng web và các role nghiệp vụ được cấp quyền đọc trên view thay vì bảng gốc, nhờ đó view vừa là lớp bảo mật vừa là lớp trừu tượng cho giao diện. Chín view chính về bảo mật và báo cáo được trình bày dưới đây; các view còn lại cung cấp dữ liệu cho form danh mục và nhập liệu ở Chương 4.

| View | Loại | Mục đích | Kỹ thuật |
|---|---|---|---|
| `vw_NhanVien_CongKhai` | Bảo mật theo cột | Danh bạ nhân viên, ẩn lương và ngày sinh | Kết nối với chính bảng để lấy tên người quản lý |
| `vw_HocVien_ChiNhanh` | Bảo mật theo dòng | Mỗi chi nhánh chỉ thấy học viên của mình | `SESSION_CONTEXT(N'ma_cn')` |
| `vw_LichDayGiaoVien` | Bảo mật theo cột | Lịch dạy, không lộ học viên, học phí, lương | Tính thứ trong tuần không phụ thuộc cấu hình ngôn ngữ của phiên |
| `vw_DangKyChiTiet` | Nghiệp vụ | Nguồn dữ liệu cho form ghi danh; cho phép thêm qua view | INSTEAD OF trigger (mục 3.3.3) |
| `vw_CongNoHocVien` | Báo cáo | Đăng ký chưa đóng đủ, số ngày quá hạn | `OUTER APPLY` |
| `vw_BangDiem` | Báo cáo | Điểm, xếp loại, chuyên cần | Gọi `fn_XepLoai`, `fn_TyLeChuyenCan` |
| `vw_DoanhThuThang` | Báo cáo | Doanh thu theo chi nhánh và tháng | Indexed view: `WITH SCHEMABINDING` và chỉ mục phân cụm duy nhất |
| `vw_SiSoLop` | Báo cáo | Sĩ số, tỷ lệ lấp đầy, lịch học dạng chuỗi | `FOR XML PATH` để ghép chuỗi |
| `vw_LopHoc_DangMo` | Form | Lớp đang mở hoặc sắp mở, cập nhật được | `WITH CHECK OPTION` |

**Bảo mật theo dòng bằng SESSION_CONTEXT.** Sau khi người dùng đăng nhập, ứng dụng gọi `sp_set_session_context N'ma_cn', 'CN02'` trên kết nối của họ; quản lý cấp trung tâm nhận giá trị `'ALL'`. View chỉ trả về các dòng thuộc chi nhánh trong ngữ cảnh phiên:

```sql title="Mã lệnh – View lọc học viên theo chi nhánh của phiên"
CREATE OR ALTER VIEW dbo.vw_HocVien_ChiNhanh
AS
SELECT h.MaHV, h.HoHV, h.TenHV, h.HoTen, h.NgaySinh, h.Tuoi, h.GioiTinh, h.SoDienThoai, h.Email,
       h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP,
       CONCAT_WS(N', ', h.SoNha, h.PhuongXa, h.QuanHuyen, h.TinhTP) AS DiaChi,
       h.HoTenPhuHuynh, h.NgayTao, h.MaCN, cn.TenCN, h.TrangThai
FROM dbo.HOCVIEN h
JOIN dbo.CHINHANH cn ON cn.MaCN = h.MaCN
WHERE CAST(SESSION_CONTEXT(N'ma_cn') AS VARCHAR(4)) IN (h.MaCN, 'ALL');
```

Kiểm thử với ba ngữ cảnh phiên khác nhau, cùng chạy câu `SELECT MaCN, COUNT(*) FROM vw_HocVien_ChiNhanh GROUP BY MaCN`:

| Ngữ cảnh phiên | Kết quả |
|---|---|
| Chưa đặt | 0 dòng – mặc định không thấy gì, an toàn khi ứng dụng quên đặt ngữ cảnh |
| `ma_cn = 'CN02'` | CN02: 119 học viên |
| `ma_cn = 'ALL'` | CN01: 133, CN02: 119, CN03: 97 học viên |

**WITH CHECK OPTION.** Tuỳ chọn này chặn việc sửa dữ liệu qua view làm cho dòng không còn thoả điều kiện của view. Ví dụ, cập nhật trạng thái một lớp thành "Đã kết thúc" qua view `vw_LopHoc_DangMo` (chỉ chứa lớp đang mở) bị từ chối:

```sql title="Kiểm thử – Sửa dữ liệu qua view có WITH CHECK OPTION"
UPDATE vw_LopHoc_DangMo SET TrangThai = N'Đã kết thúc' WHERE MaLop = 'GT3-2601';
-- Msg 550: The attempted insert or update failed because the target view either specifies
-- WITH CHECK OPTION ... did not qualify under the CHECK OPTION constraint.
```

**Kết quả của các view báo cáo.** View `vw_CongNoHocVien` liệt kê 67 đăng ký còn nợ với tổng số tiền **283.218.000 đồng**, trong đó 44 đăng ký đã quá hạn. Trích ba dòng:

| Mã ĐK | Học viên | Lớp | Thành tiền | Đã thu | Còn nợ | Hạn đóng | Số ngày quá hạn |
|--:|---|---|--:|--:|--:|---|--:|
| 182 | Hoàng Kim Xuân | IE65-2501 | 9.000.000 | 0 | 9.000.000 | 09/10/2025 | 370 |
| 376 | Mai Đức Bảo | IE55-2601 | 7.500.000 | 0 | 7.500.000 | 23/08/2026 | 52 |
| 487 | Nguyễn Mai Chi | IE65-2601 | 8.100.000 | 0 | 8.100.000 | 29/10/2026 | – |

View `vw_SiSoLop` trên các lớp chưa kết thúc (trích):

| Lớp | Khoá | Chi nhánh | Sĩ số | Lấp đầy | Lịch học |
|---|---|---|:-:|--:|---|
| IE55-2602 | IELTS 5.5 | Thủ Đức | 20/20 | 100,0% | T4 Tối 2 (P101), T6 Tối 2 (P101) |
| IE55-2601 | IELTS 5.5 | Bình Thạnh | 28/30 | 93,3% | T7 Sáng 1 (P101), CN Sáng 1 (P101) |
| GT3-2601 | Giao tiếp Nâng cao | Bình Thạnh | 10/25 | 40,0% | T3 Tối 1 (P101), T5 Tối 1 (P101) |

**Indexed view.** View `vw_DoanhThuThang` được tạo với `WITH SCHEMABINDING` và một chỉ mục phân cụm duy nhất, nên kết quả gộp được lưu sẵn như một bảng. Nhóm so sánh số trang đọc khi tính tổng doanh thu theo chi nhánh và năm bằng hai cách:

| Cách truy vấn | Số trang đọc | Ghi chú |
|---|--:|---|
| Gộp trực tiếp từ 4 bảng gốc | 16 (DANGKY 5, CT_PHIEUTHU 4, PHIEUTHU 5, LOPHOC 2) và bảng tạm | Phải kết nối và gộp nhóm mỗi lần chạy |
| Đọc từ `vw_DoanhThuThang WITH (NOEXPAND)` | 2 | Kết quả đã gộp sẵn theo tháng trong chỉ mục của view |

**Nhận xét.** Khoảng cách giữa hai cách sẽ tăng theo kích thước dữ liệu, vì indexed view chỉ lưu khoảng 3 chi nhánh × 24 tháng = 72 dòng dù có hàng trăm nghìn phiếu thu. Cái giá phải trả là mỗi lần thêm hoặc sửa chi tiết phiếu thu, SQL Server phải cập nhật thêm chỉ mục của view; vì vậy indexed view chỉ phù hợp với dữ liệu *đọc nhiều, ghi ít* như doanh thu. Indexed view cũng có nhiều điều kiện khắt khe: phải có `SCHEMABINDING`, tên đối tượng hai phần `dbo.X`, không dùng kết nối ngoài, phải có `COUNT_BIG(*)` khi gộp nhóm, và mọi phiên ghi vào bảng gốc phải bật `QUOTED_IDENTIFIER`, `ANSI_NULLS`.

### 3.2.4 Sao lưu và phục hồi

**Phân tích.** Để có thể phục hồi về một thời điểm bất kỳ, CSDL được đặt ở mô hình phục hồi **FULL** – điều kiện bắt buộc để sao lưu nhật ký giao dịch. Nhóm sử dụng cả ba loại sao lưu và đo kích thước thực tế trên CSDL ECMS:

| Loại sao lưu | Nội dung | Kích thước (gốc → nén) | Khi phục hồi cần |
|---|---|--:|---|
| Toàn bộ (Full) | Toàn bộ CSDL và phần nhật ký đủ để nhất quán | 14,09 MB → 1,38 MB (giảm 90,2%) | Chỉ bản Full |
| Vi sai (Differential) | Các vùng dữ liệu thay đổi kể từ bản Full gần nhất | 2,09 MB → 0,12 MB (giảm 94,2%) | Bản Full và bản vi sai mới nhất |
| Nhật ký (Transaction log) | Mọi giao dịch kể từ lần sao lưu nhật ký trước | 0,21 MB → 0,06 MB (giảm 72,8%) | Bản Full, bản vi sai và **mọi** bản nhật ký sau đó theo đúng thứ tự; cho phép dừng tại một thời điểm |

Script `11_backup_restore.sql` tạo procedure dùng chung `sp_SaoLuuECMS` nhận tham số loại sao lưu, tự đặt tên tệp theo thời điểm, bật nén (tự tắt trên bản Express) và kiểm tra checksum.

**Kịch bản diễn tập sự cố.** Nhóm mô phỏng tình huống giáo vụ lỡ tay xoá toàn bộ điểm danh của một lớp, rồi phục hồi về đúng thời điểm trước sự cố:

| Bước | Thời điểm | Số dòng điểm danh lớp GT2-2601 | Số phiếu thu |
|---|---|--:|--:|
| 1. Sao lưu Full | 18:56:27.446 | 364 | 501 |
| 2. Thêm một phiếu thu, sao lưu vi sai | 18:56:27.528 | 364 | 502 |
| 3. Thêm một phiếu thu – **mốc T0** | 18:56:28.543 | 364 | 503 |
| 4. **Sự cố**: xoá toàn bộ điểm danh của lớp | 18:56:29.584 | **0** | 503 |
| 5. Sao lưu nhật ký, phục hồi Full + vi sai + nhật ký dừng tại T0 ra CSDL `ECMS_KhoiPhuc` | (T0) | **364** | 503 |
| 6. Chép các dòng bị xoá từ `ECMS_KhoiPhuc` về ECMS | 18:56:30.439 | **364** | 503 |

```sql title="Mã lệnh – Phục hồi về thời điểm T0 ra một CSDL mới"
RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_full.bak' WITH MOVE ..., NORECOVERY, REPLACE;
RESTORE DATABASE ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_diff.bak' WITH NORECOVERY;
RESTORE LOG      ECMS_KhoiPhuc FROM DISK = '.../ECMS_demo_log.trn'  WITH STOPAT = @T0, RECOVERY;
```

**Kết quả.** Bản phục hồi có đủ 503 phiếu thu – tức là giữ được cả hai phiếu lập sau lần sao lưu Full, một phiếu nằm trong bản vi sai và một phiếu chỉ có trong nhật ký – và đủ 364 dòng điểm danh đã bị xoá. Nhóm chọn phục hồi *song song* ra một CSDL mới thay vì ghi đè lên ECMS: ứng dụng không phải dừng, các giao dịch hợp lệ xảy ra sau sự cố không bị mất, chỉ những dòng bị xoá được chép lại. Phục hồi ghi đè chỉ nên dùng khi toàn bộ CSDL bị hỏng, và khi đó phải sao lưu phần nhật ký cuối (tail-log) trước.

**Kiểm tra bản sao lưu.** Một bản sao lưu chưa từng được kiểm tra thì chưa chắc dùng được. Nhóm dùng bốn công cụ kiểm tra:

| Lệnh | Mục đích | Kết quả trên bản Full |
|---|---|---|
| `RESTORE VERIFYONLY … WITH CHECKSUM` | Bản sao lưu đọc được, checksum từng trang đúng | Thành công cho cả ba tệp |
| `RESTORE HEADERONLY` | Loại sao lưu, LSN đầu và cuối, thời điểm, có nén không, bảng mã | Loại Full, có nén, `Vietnamese_CI_AS` |
| `RESTORE FILELISTONLY` | Tên logic và vật lý của các tệp bên trong, cần cho `WITH MOVE` | `ECMS` → ECMS.mdf, `ECMS_log` → ECMS_log.ldf |
| `msdb.dbo.backupset` | Lịch sử sao lưu, kích thước trước và sau khi nén | Số liệu ở bảng kích thước bên trên |

**Chiến lược sao lưu đề xuất.** Dựa trên quy mô và giờ hoạt động của trung tâm (07:00 – 22:00), nhóm đề xuất lịch sao lưu sau:

| Thành phần | Lịch | Thời gian lưu giữ | Lý do |
|---|---|---|---|
| Sao lưu Full | Chủ nhật 01:00 | 4 tuần | Ngoài giờ học; làm nền cho chuỗi phục hồi |
| Sao lưu vi sai | Thứ Hai – thứ Bảy 01:00 | 1 tuần | Rút ngắn chuỗi phục hồi: tối đa một bản vi sai thay vì nhật ký của sáu ngày |
| Sao lưu nhật ký | Mỗi 15 phút từ 07:00 đến 22:00 | 2 tuần | Giới hạn lượng dữ liệu có thể mất trong 15 phút |
| Bản sao ngoài máy chủ | Đồng bộ thư mục sao lưu lên lưu trữ đám mây hằng ngày | 3 tháng | Phòng hỏng ổ đĩa, mã độc tống tiền (quy tắc 3-2-1) |
| Diễn tập phục hồi | Hằng tháng chạy lại kịch bản trên ra CSDL thử | – | Bảo đảm bản sao lưu thực sự dùng được |

Với lịch này, lượng dữ liệu tối đa có thể mất (RPO) là **15 phút** – đúng chu kỳ sao lưu nhật ký – và thời gian khôi phục (RTO) **dưới 30 phút**: CSDL khoảng 15 MB, việc phục hồi một bản Full, một bản vi sai và tối đa 96 bản nhật ký chỉ mất vài phút, phần lớn thời gian còn lại dành cho việc xác định thời điểm sự cố. Cả hai chỉ số đều đạt yêu cầu NFR04.

**Tự động hoá.** Trên bản SQL Server có SQL Server Agent, lịch sao lưu được tạo thành job bằng `sp_add_job` và `sp_add_schedule`. Bản Express không có Agent nên nhóm viết script shell gọi procedure sao lưu, chạy định kỳ bằng cron (hoặc Task Scheduler trên Windows). Script cũng có mẫu sao lưu **mã hoá AES-256** bằng certificate; khi dùng cách này phải sao lưu riêng certificate, vì mất certificate thì không thể phục hồi.

### 3.2.5 Nhập và xuất dữ liệu

**Bài toán nhập dữ liệu.** Bộ phận marketing định kỳ gửi tệp CSV gồm 1.200 đăng ký trực tuyến, trong đó có những dòng sai. Dữ liệu không thể nạp thẳng vào HOCVIEN; nhóm xử lý theo quy trình ETL ba bước:

1. **Trích xuất (Extract)** – nạp tệp bằng `BULK INSERT` vào bảng trung gian `STG_HOCVIEN_ONLINE` có mọi cột kiểu chuỗi để nhận cả dữ liệu sai. Các cột dùng bảng mã UTF-8 nên đọc đúng tiếng Việt trên cả Windows lẫn Linux.
2. **Biến đổi (Transform)** – chuẩn hoá dữ liệu (cắt khoảng trắng, bỏ dấu chấm và gạch trong số điện thoại, chuyển ngày bằng `TRY_CONVERT`), kiểm tra 9 quy tắc chất lượng và ghi lý do lỗi vào cột `Loi`.
3. **Nạp (Load)** – chuyển các dòng hợp lệ vào HOCVIEN với mã mới trong một giao dịch; các dòng lỗi được lưu vào bảng riêng để gửi trả bộ phận marketing.

| Kết quả | Số dòng |
|---|--:|
| Đọc từ tệp CSV | 1.200 (34 ms) |
| Hợp lệ, nạp vào HOCVIEN | **1.160** |
| Lỗi | **40**, gồm: khoá học không tồn tại 8, ngày sinh sai định dạng 8, chi nhánh không tồn tại 6, email sai 6, trùng số điện thoại trong tệp 5, thiếu họ tên 4, số điện thoại sai 3 |

Script mặc định chạy ở chế độ thử (huỷ giao dịch ở cuối) để có thể chạy lại nhiều lần. Một chương trình Python dùng pandas thực hiện cùng quy trình cho **cùng kết quả 1.160 dòng hợp lệ và 40 dòng lỗi**, đồng thời ghi tệp các dòng lỗi. Ngoài ra, `OPENROWSET(BULK …)` được dùng để đọc trực tiếp tệp XML kết quả thi của đối tác và tệp CSV danh mục khoá học ngay trong câu SELECT mà không cần bảng trung gian.

**Xuất dữ liệu.** Hệ thống xuất được năm định dạng phục vụ các mục đích khác nhau:

| Định dạng | Cách thực hiện | Ứng dụng |
|---|---|---|
| JSON | `FOR JSON PATH, ROOT`: lớp đang học kèm mảng học viên lồng bên trong; `OPENJSON … WITH` đọc ngược JSON thành bảng | Cung cấp cho API, ứng dụng di động |
| XML | `FOR XML PATH, ROOT`: công nợ theo học viên | Trao đổi với hệ thống kế toán |
| CSV | Công cụ `bcp` với bảng mã UTF-8; Python ghi CSV có BOM | Mở bằng Excel không lỗi tiếng Việt |
| Excel | SQL Server Import and Export Wizard; Python với openpyxl (hai trang tính, tự giãn cột) | Gửi báo cáo cho quản lý |
| JSON, XML từ Python | `DataFrame.to_json`, `DataFrame.to_xml` | Tích hợp với hệ thống khác |

**So sánh tốc độ nhập 10.000 dòng.** Nhóm nhập cùng một tệp 10.000 dòng vào bảng trung gian bằng sáu cách để so sánh:

| Phương pháp | Thời gian | Số dòng mỗi giây | Ghi chú |
|---|--:|--:|---|
| `BULK INSERT` (tệp trên máy chủ, khoá bảng) | **38 ms** | khoảng 262.000 | Nhanh nhất: máy chủ đọc tệp trực tiếp, ghi nhật ký tối thiểu; nhưng tệp phải nằm trên máy chủ |
| `bcp in` | 513 ms | khoảng 19.500 | Đọc tệp phía máy khách, gửi theo lô; thời gian gồm cả khởi động tiến trình |
| Python `executemany` với `fast_executemany` | 352 ms | khoảng 28.400 | Gửi cả mảng tham số trong ít lượt mạng; cách ứng dụng web nên dùng |
| Python `executemany` mặc định | 10.133 ms | khoảng 990 | Mỗi dòng một lượt gọi ODBC |
| Python `execute` từng dòng | 16.865 ms | khoảng 590 | Mỗi dòng một lượt mạng |
| T-SQL `INSERT` từng dòng trong cursor | 7.842 ms | khoảng 1.280 | Không có độ trễ mạng nhưng vẫn là 10.000 câu lệnh |

**Nhận xét.** Chênh lệch giữa cách nhanh nhất và chậm nhất lên tới hơn 400 lần, chủ yếu do số lượt trao đổi giữa máy khách và máy chủ. Từ kết quả đo, nhóm đánh giá các công cụ như sau:

| Công cụ | Tốc độ | Tiện dụng | Kiểm soát chất lượng dữ liệu | Phù hợp cho |
|---|:-:|---|---|---|
| BULK INSERT | Rất cao | Cần quyền thao tác hàng loạt, tệp phải ở trên máy chủ | Qua bảng trung gian và T-SQL | Nạp định kỳ số lượng lớn |
| bcp | Cao | Chạy dòng lệnh từ máy khách, dễ đưa vào script | Gần như không có | Sao chép dữ liệu giữa các máy chủ |
| Import and Export Wizard | Trung bình | Giao diện trực quan, lưu được thành gói SSIS | Chỉ ánh xạ kiểu cơ bản | Thao tác một lần của người không lập trình |
| Python pandas và pyodbc | Cao (với `fast_executemany`) | Linh hoạt, xuất được Excel, JSON, XML | Mạnh nhất | Ứng dụng web ECMS, báo cáo |
| OPENROWSET, OPENJSON, FOR JSON, FOR XML | Cao | Thực hiện ngay trong câu SQL | Bằng T-SQL | Trao đổi dữ liệu bán cấu trúc |

## 3.3 Lập trình trên CSDL

Phần này trình bày bốn loại đối tượng lập trình của SQL Server. Toàn bộ CSDL có 38 stored procedure (trong đó 3 procedure dùng cursor), 13 function và 11 trigger; mỗi mục dưới đây giới thiệu các đối tượng chính, phân tích một đối tượng tiêu biểu, kiểm thử và nhận xét.

### 3.3.1 Stored procedure và giao dịch

**Vai trò.** Ứng dụng web chỉ được thực thi procedure (mục 3.2.2), vì vậy mọi nghiệp vụ ghi dữ liệu đều được đóng gói thành procedure và mọi quy tắc nghiệp vụ được kiểm tra tại CSDL. Chín procedure nghiệp vụ chính được tóm tắt dưới đây; 19 procedure còn lại thực hiện thêm, sửa, xoá cho các form danh mục.

| Procedure | Tham số vào | Tham số ra | Giao dịch | Kiểm tra chính |
|---|---|---|:-:|---|
| `sp_DangKyHoc` | Mã học viên, mã lớp, giảm giá | Mã đăng ký | Có | Học viên tồn tại, lớp đang mở, không trùng, còn chỗ, đủ điều kiện tiên quyết |
| `sp_ThuHocPhi` | Mã học viên, mã nhân viên, hình thức, danh sách chi tiết (JSON), ghi chú | Mã phiếu thu, tổng tiền | Có | Đăng ký thuộc học viên, không thu vượt số nợ, người lập là kế toán hoặc quản lý |
| `sp_XepLichLop`, `sp_XoaLichLop` | Mã lớp, thứ, ca, phòng | – | | Phòng thuộc chi nhánh, đủ sức chứa, không trùng phòng, không trùng giáo viên |
| `sp_DiemDanhBuoi` | Mã lớp, số buổi, danh sách (JSON) | – | Có | Lưu cả lớp một lần bằng `MERGE`; buổi đã tới ngày; học viên thuộc lớp |
| `sp_NhapDiem` | Mã lớp, danh sách (JSON) | Số dòng | Có | Điểm từ 0 đến 10, học viên đang học |
| `sp_ChuyenLop` | Mã đăng ký, mã lớp mới | Mã đăng ký mới | Có | Cùng khoá, lớp mới còn chỗ; chuyển cả số tiền đã đóng |
| `sp_ThongKeDoanhThu` | Từ ngày, đến ngày, mã chi nhánh | Tổng doanh thu | | Trả bảng chi nhánh × tháng và tổng qua tham số ra |
| `sp_TimKiemHocVien` | Từ khoá, chi nhánh, khoá học, còn nợ, trang, số dòng mỗi trang | Tổng số kết quả | | Tiêu chí tuỳ chọn, phân trang `OFFSET … FETCH` |

**Phân tích procedure tiêu biểu – sp_DangKyHoc.** Ghi danh là nghiệp vụ quan trọng nhất và có nhiều điều kiện nhất. Procedure kiểm tra lần lượt các điều kiện dưới đây; điều kiện đầu tiên không thoả sẽ dừng procedure với một mã lỗi và thông báo tiếng Việt riêng, giúp giao diện hiển thị đúng lý do cho giáo vụ.

| Thứ tự | Điều kiện kiểm tra | Mã lỗi | Thông báo |
|:-:|---|:-:|---|
| 1 | Học viên tồn tại và đang hoạt động | 50001 | Học viên không tồn tại hoặc đã ngừng học |
| 2 | Lớp tồn tại, đang ở trạng thái Sắp mở hoặc Đang học | 50002 | Lớp đã kết thúc hoặc đã huỷ, không nhận ghi danh |
| 3 | Học viên chưa đăng ký lớp này | 50003 | Học viên đã đăng ký lớp này |
| 4 | Lớp còn chỗ | 50004 | Lớp đã đủ sĩ số |
| 5 | Giảm giá từ 0 đến 50% | 50006 | Giảm giá phải từ 0 đến 50% |
| 6 | Đã đạt khoá tiên quyết hoặc có điểm đầu vào đủ cao | 50005 | Chưa đủ điều kiện: cần đạt khoá tiên quyết hoặc điểm kiểm tra đầu vào đủ cao |
| – | Tất cả hợp lệ | – | Thêm đăng ký với học phí lấy từ khoá học, trả về mã đăng ký |

```sql title="Mã lệnh – Procedure sp_DangKyHoc"
CREATE OR ALTER PROCEDURE dbo.sp_DangKyHoc
    @MaHV    CHAR(6),
    @MaLop   VARCHAR(10),
    @GiamGia DECIMAL(5,2) = 0,
    @MaDK    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    IF @tc = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION sp_DangKyHoc;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaHV = @MaHV AND TrangThai = 1)
            THROW 50001, N'Học viên không tồn tại hoặc đã ngừng học.', 1;

        DECLARE @MaKH VARCHAR(6), @TrangThaiLop NVARCHAR(20), @ToiDa TINYINT, @HienTai TINYINT;
        -- Khoá dòng lớp tới hết giao dịch: hai giáo vụ ghi danh cùng lúc phải chờ nhau
        SELECT @MaKH = MaKH, @TrangThaiLop = TrangThai, @ToiDa = SiSoToiDa, @HienTai = SiSoHienTai
        FROM dbo.LOPHOC WITH (UPDLOCK, HOLDLOCK) WHERE MaLop = @MaLop;

        IF @MaKH IS NULL
            THROW 50002, N'Lớp học không tồn tại.', 1;
        IF @TrangThaiLop NOT IN (N'Sắp mở', N'Đang học')
            THROW 50002, N'Lớp đã kết thúc hoặc đã huỷ, không nhận ghi danh.', 1;
        IF EXISTS (SELECT 1 FROM dbo.DANGKY WHERE MaHV = @MaHV AND MaLop = @MaLop)
            THROW 50003, N'Học viên đã đăng ký lớp này.', 1;
        IF @HienTai >= @ToiDa
            THROW 50004, N'Lớp đã đủ sĩ số.', 1;
        IF @GiamGia NOT BETWEEN 0 AND 50
            THROW 50006, N'Giảm giá phải từ 0 đến 50%.', 1;

        DECLARE @TienQuyet VARCHAR(6), @DiemCan DECIMAL(3,1);
        SELECT @TienQuyet = MaKHTienQuyet, @DiemCan = DiemDauVaoTu FROM dbo.KHOAHOC WHERE MaKH = @MaKH;
        IF @TienQuyet IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.DANGKY d JOIN dbo.LOPHOC l ON l.MaLop = d.MaLop
                           WHERE d.MaHV = @MaHV AND l.MaKH = @TienQuyet AND d.KetQua = N'Đạt')
           AND NOT EXISTS (SELECT 1 FROM dbo.KIEMTRA_DAUVAO WHERE MaHV = @MaHV AND DiemTong >= @DiemCan)
        BEGIN
            DECLARE @msg NVARCHAR(300) = CONCAT(N'Chưa đủ điều kiện: cần Đạt khoá ', @TienQuyet,
                N' hoặc điểm kiểm tra đầu vào từ ', @DiemCan, N' trở lên.');
            THROW 50005, @msg, 1;
        END

        INSERT dbo.DANGKY (MaHV, MaLop, HocPhi, GiamGia)
        SELECT @MaHV, @MaLop, HocPhi, @GiamGia FROM dbo.KHOAHOC WHERE MaKH = @MaKH;
        SET @MaDK = SCOPE_IDENTITY();      -- sĩ số do trigger trg_DangKy_SiSo cập nhật

        IF @tc = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 OR (XACT_STATE() = 1 AND @tc = 0) ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION sp_DangKyHoc;
        THROW;
    END CATCH
END
```

Procedure này thể hiện bốn quyết định thiết kế mà nhóm áp dụng cho mọi procedure ghi dữ liệu:

- **Giao dịch lồng được.** Procedure tự mở giao dịch khi được gọi độc lập; nếu người gọi đã có giao dịch thì chỉ đặt điểm lưu (`SAVE TRANSACTION`). Khi có lỗi, khối CATCH dựa vào `XACT_STATE()` để quyết định huỷ toàn bộ (giao dịch hỏng hoặc do chính procedure mở) hay chỉ quay về điểm lưu, rồi ném lại lỗi gốc cho ứng dụng.
- **Chống ghi danh vượt sĩ số khi có truy cập đồng thời.** Nếu hai giáo vụ cùng ghi danh vào chỗ cuối cùng của một lớp, cả hai có thể cùng đọc thấy "còn 1 chỗ" rồi cùng thêm đăng ký. Gợi ý khoá `UPDLOCK, HOLDLOCK` giữ khoá cập nhật trên dòng LOPHOC tới hết giao dịch, nên phiên thứ hai phải chờ, đọc lại thấy lớp đã đầy và nhận lỗi 50004. Trigger ở mục 3.3.3 là lớp bảo vệ thứ hai.
- **Truyền danh sách bằng JSON.** Các procedure thu học phí, điểm danh, nhập điểm nhận cả danh sách trong một tham số chuỗi JSON và tách bằng `OPENJSON … WITH`. So với tham số kiểu bảng, JSON gọi được trực tiếp từ pyodbc mà không cần tạo kiểu dữ liệu riêng, trong khi vẫn xử lý theo tập hợp trong một giao dịch – cả lớp được lưu trong một lần.
- **SQL tĩnh thay cho SQL động.** `sp_TimKiemHocVien` có nhiều tiêu chí tuỳ chọn nhưng không ghép chuỗi SQL; điều kiện được viết dạng `(@x IS NULL OR cot = @x)` kèm `OPTION (RECOMPILE)` để mỗi lần chạy được tối ưu theo giá trị thực. Cách này loại bỏ nguy cơ chèn mã SQL và giữ nguyên chuỗi sở hữu.

**Kiểm thử.** Bộ kiểm thử `test_procedures.sql` chạy 25 ca trong một giao dịch rồi huỷ ở cuối; kết quả từng ca được ghi vào biến bảng vì biến bảng không bị ảnh hưởng khi huỷ giao dịch. Kết quả:

| Procedure | Ca kiểm thử | Mong đợi | Thực tế | Đánh giá |
|---|---|---|---|:-:|
| sp_DangKyHoc | Ghi danh hợp lệ vào lớp KD2-2601 | Thành công | Thành công, mã đăng ký 569 | Đạt |
| | Đăng ký trùng | 50003 | 50003 Học viên đã đăng ký lớp này | Đạt |
| | Lớp IE55-2602 đã đủ sĩ số | 50004 | 50004 Lớp đã đủ sĩ số | Đạt |
| | Thiếu khoá tiên quyết (lớp GT3-2601) | 50005 | 50005 Chưa đủ điều kiện: cần Đạt khoá GT2 hoặc điểm kiểm tra đầu vào từ 6.5 trở lên | Đạt |
| | Lớp đã kết thúc | 50002 | 50002 Lớp đã kết thúc hoặc đã huỷ | Đạt |
| | Học viên không tồn tại | 50001 | 50001 | Đạt |
| sp_ThuHocPhi | Thu một phần 1.000.000 đồng | Thành công | Thành công, mã phiếu 524 | Đạt |
| | Thu phần còn lại, không ghi số tiền | Thành công | Thành công, tổng 2.990.000 đồng | Đạt |
| | Thu vượt số còn nợ | 50014 | 50014 | Đạt |
| | Đăng ký của học viên khác | 50012 | 50012 | Đạt |
| | Giáo vụ lập phiếu | 50011 | 50011 Chỉ kế toán hoặc quản lý được lập phiếu thu | Đạt |
| sp_XepLichLop | Thêm lịch vào phòng trống | Thành công | Thành công | Đạt |
| | Trùng lịch với lớp GT3-2601 | 5002x | 50025 Trùng phòng P101 với lớp GT3-2601 | Đạt |
| | Phòng không thuộc chi nhánh của lớp | 50022 | 50022 | Đạt |
| sp_DiemDanhBuoi | Điểm danh cả lớp TC650-2601 buổi 17 | Thành công | Thành công, 27 dòng | Đạt |
| | Buổi học chưa tới ngày | 50031 | 50031 | Đạt |
| | Học viên của lớp khác | 50033 | 50033 | Đạt |
| sp_NhapDiem | Nhập điểm giữa kỳ cả lớp | Thành công | Thành công, 27 học viên | Đạt |
| | Điểm bằng 11 | 50042 | 50042 Điểm phải nằm trong khoảng 0 – 10 | Đạt |
| sp_ChuyenLop | Chuyển đăng ký 387 sang lớp IE55-2601 | Thành công | Thành công, chuyển đủ 6.750.000 đồng đã đóng | Đạt |
| | Chuyển sang lớp khác khoá | 50053 | 50053 | Đạt |
| sp_ThongKeDoanhThu | Năm 2025 | Thành công | 15 dòng, tổng 1.082.090.000 đồng bằng tổng chi tiết | Đạt |
| | Khoảng ngày ngược | 50060 | 50060 | Đạt |
| sp_TimKiemHocVien | Từ khoá "Nguyễn", trang 2, 10 dòng mỗi trang | Thành công | Tổng 35 kết quả, trang 2 có 10 dòng | Đạt |
| | Trang số 0 | 50061 | 50061 | Đạt |

Kết quả **25/25 ca đạt**; sau khi chạy, dữ liệu mẫu giữ nguyên (bộ kiểm tra nhất quán vẫn không có lỗi). Giá trị tự tăng đã cấp trong giao dịch bị huỷ không được trả lại, nên mã đăng ký và mã phiếu tiếp theo có khoảng trống – đây là hành vi bình thường của SQL Server.

### 3.3.2 Hàm do người dùng định nghĩa

**Phân loại.** SQL Server có ba loại hàm người dùng. ECMS có 13 hàm thuộc đủ ba loại; mười hàm nghiệp vụ được liệt kê dưới đây, ba hàm còn lại phục vụ băm mật khẩu, kiểm tra độ mạnh mật khẩu và tách kỹ năng từ XML.

| Hàm | Loại | Tham số và kết quả | Được dùng ở |
|---|---|---|---|
| `fn_TinhTuoi` | Vô hướng, có `SCHEMABINDING` | Ngày sinh, ngày tính → tuổi | Ràng buộc CHECK tuổi nhân viên, báo cáo |
| `fn_TyLeChuyenCan` | Vô hướng | Mã đăng ký → tỷ lệ có mặt (%) | View bảng điểm, procedure cảnh báo, trang điểm danh |
| `fn_XepLoai` | Vô hướng, có `SCHEMABINDING` | Điểm trung bình → Xuất sắc, Giỏi, Khá, Trung bình, Yếu | Bảng điểm, báo cáo |
| `fn_SoTienDaDong` | Vô hướng | Mã đăng ký → tổng số tiền đã thu | Công nợ, phiếu thu |
| `fn_SoTienConNo` | Vô hướng | Mã học viên → tổng số tiền còn nợ | Hồ sơ học viên |
| `fn_SoChoConLai` | Vô hướng | Mã lớp → số chỗ trống | Form ghi danh |
| `fn_LichHocHocVien` | Bảng nội tuyến | Mã học viên, một ngày → lịch của tuần chứa ngày đó | Trang của học viên |
| `fn_LopCuaGiaoVien` | Bảng nội tuyến | Mã giáo viên → các lớp phụ trách | Giáo viên chỉ thấy lớp mình |
| `fn_GoiYKhoaHoc` | Bảng nội tuyến | Điểm, chương trình → khoá phù hợp và số lớp còn chỗ | Form kiểm tra đầu vào |
| `fn_BangDiemLop` | Bảng nhiều câu lệnh | Mã lớp → bảng điểm có xếp loại, chuyên cần, thứ hạng, ghi chú | Báo cáo bảng điểm |

**Phân tích hàm tiêu biểu – fn_TyLeChuyenCan.** Hàm này là "tầng thông tin" trong ví dụ DIKW ở mục 1.6.2. Theo quy định của trung tâm, đi muộn vẫn tính là có mặt, còn vắng có phép không tính vào tổng số buổi. Hàm trả về NULL khi chưa có buổi nào được điểm danh để phân biệt "chưa có dữ liệu" với "chuyên cần 0%".

```sql title="Mã lệnh – Hàm fn_TyLeChuyenCan"
CREATE OR ALTER FUNCTION dbo.fn_TyLeChuyenCan (@MaDK INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @CoMat INT, @Tong INT;
    SELECT @CoMat = SUM(CASE WHEN TrangThai IN (N'Có mặt', N'Muộn') THEN 1 ELSE 0 END),
           @Tong  = SUM(CASE WHEN TrangThai <> N'Có phép' THEN 1 ELSE 0 END)
    FROM dbo.DIEMDANH WHERE MaDK = @MaDK;
    RETURN CASE WHEN ISNULL(@Tong, 0) = 0 THEN NULL ELSE CAST(100.0 * @CoMat / @Tong AS DECIMAL(5,2)) END;
END
```

**Kiểm thử các loại hàm.** Hàm vô hướng được gọi ở mọi vị trí của câu truy vấn – SELECT, WHERE, ORDER BY và GROUP BY:

```sql title="Kiểm thử – Hàm vô hướng trong SELECT, WHERE, ORDER BY và GROUP BY"
SELECT TOP 3 MaHV, HoTen, dbo.fn_SoTienConNo(MaHV) AS ConNo
FROM HOCVIEN WHERE dbo.fn_SoTienConNo(MaHV) > 0 ORDER BY ConNo DESC;

SELECT dbo.fn_XepLoai(DiemTB) AS XepLoai, COUNT(*) AS SoHV
FROM DANGKY WHERE DiemTB IS NOT NULL GROUP BY dbo.fn_XepLoai(DiemTB);
```

Kết quả – ba học viên nợ nhiều nhất và phân bố xếp loại trên toàn bộ đăng ký đã có điểm:

| Mã HV | Họ tên | Còn nợ (đồng) |
|---|---|--:|
| HV0019 | Nguyễn Thành Khoa | 15.275.000 |
| HV0162 | Đặng Quang Hưng | 13.500.000 |
| HV0022 | Bùi Kim Xuân | 9.000.000 |

| Xuất sắc | Giỏi | Khá | Trung bình | Yếu |
|:-:|:-:|:-:|:-:|:-:|
| 22 | 55 | 115 | 111 | 41 |

Hàm bảng nội tuyến được dùng trong mệnh đề FROM như một view có tham số. Với học viên có điểm kiểm tra 5,0, `fn_GoiYKhoaHoc(5.0, NULL)` gợi ý bốn khoá thuộc bốn chương trình:

| Mã KH | Tên khoá | Mục tiêu | Học phí (đồng) | Số lớp còn chỗ |
|---|---|---|--:|:-:|
| GT2 | Giao tiếp Trung cấp | B1 | 3.500.000 | 1 |
| IE55 | IELTS 5.5 | IELTS 5.5 | 7.500.000 | 1 |
| KD2 | Kids Movers | Cambridge Movers | 4.200.000 | 1 |
| TC650 | TOEIC 650 | TOEIC 650 | 4.500.000 | 1 |

`fn_LichHocHocVien('HV0004', '2026-10-15')` trả về lịch của tuần 12 – 18/10/2026:

| Ngày học | Thứ | Ca | Lớp | Phòng | Buổi | Giáo viên |
|---|---|---|---|---|:-:|---|
| 17/10/2026 | Thứ Bảy | Sáng 1 | IE55-2601 | P101 | 19 | Wilson David |
| 18/10/2026 | Chủ nhật | Sáng 1 | IE55-2601 | P101 | 20 | Wilson David |

Hàm xác định ngày thứ Hai đầu tuần bằng biểu thức `DATEDIFF(DAY, '19000101', @Tuan) % 7` (ngày 01/01/1900 là thứ Hai), nên kết quả không phụ thuộc vào cấu hình `SET DATEFIRST` hay `SET LANGUAGE` của phiên kết nối – một lỗi thường gặp khi ứng dụng và SSMS dùng ngôn ngữ khác nhau.

Hàm bảng nhiều câu lệnh `fn_BangDiemLop` cần nhiều bước xử lý: nạp biến bảng, cập nhật xếp loại và chuyên cần bằng hàm vô hướng, tính thứ hạng bằng `RANK()`, ghép ghi chú cảnh báo. Viết cùng logic trong một câu SELECT duy nhất (hàm nội tuyến) sẽ khó viết và khó đọc hơn nhiều. Kết quả cho lớp GT1-2501 (trích ba dòng đầu):

| Hạng | Họ tên | GK | CK | TB | Xếp loại | Chuyên cần (%) | Kết quả |
|:-:|---|:-:|:-:|:-:|---|:-:|---|
| 1 | Trần Mai Vân | 10,00 | 10,00 | 10,00 | Xuất sắc | 100 | Đạt |
| 2 | Hoàng Kim Mai | 7,50 | 9,00 | 8,40 | Giỏi | 100 | Đạt |
| 3 | Bùi Minh Chi | 9,00 | 7,75 | 8,25 | Giỏi | 100 | Đạt |

**Hàm trong ràng buộc CHECK.** Hàm vô hướng có `SCHEMABINDING` còn được dùng trong ràng buộc CHECK để thực thi RB07 (nhân viên từ 18 đến 65 tuổi khi vào làm):

```sql title="Mã lệnh – Ràng buộc CHECK gọi hàm và kiểm thử"
ALTER TABLE NHANVIEN ADD CONSTRAINT CK_NHANVIEN_TuoiLaoDong
    CHECK (dbo.fn_TinhTuoi(NgaySinh, NgayVaoLam) BETWEEN 18 AND 65);

INSERT NHANVIEN (..., NgaySinh, ..., NgayVaoLam) VALUES (..., '1950-01-01', ..., '2026-01-01');
-- Msg 547: The INSERT statement conflicted with the CHECK constraint "CK_NHANVIEN_TuoiLaoDong".
```

Khi chạy lại script, ràng buộc này phải được xoá trước rồi tạo lại, vì SQL Server không cho sửa một hàm đang được ràng buộc CHECK tham chiếu.

**So sánh function và stored procedure.**

| Tiêu chí | Function | Stored procedure |
|---|---|---|
| Giá trị trả về | Bắt buộc: một giá trị vô hướng hoặc một bảng | Tuỳ chọn: tập kết quả, tham số ra, mã trả về |
| Dùng trong câu lệnh | Được: SELECT, WHERE, JOIN, CHECK, cột tính toán | Không, chỉ gọi bằng EXEC |
| Thay đổi dữ liệu | Không (chỉ sửa được biến bảng cục bộ) | Được |
| Giao dịch, TRY…CATCH | Không | Có |
| Gọi đối tượng khác | Chỉ gọi được function | Gọi được cả function và procedure |
| Hiệu năng | Hàm bảng nội tuyến được tối ưu như view; hàm vô hướng chạy từng dòng | Kế hoạch thực thi được lưu đệm |
| Vai trò trong ECMS | Tính toán dùng lại: chuyên cần, xếp loại, công nợ, lịch | Nghiệp vụ ghi dữ liệu: ghi danh, thu phí, điểm danh |

### 3.3.3 Trigger và nhật ký kiểm toán

**Vai trò.** Trigger là lớp bảo vệ cuối cùng: dù dữ liệu được thay đổi qua procedure, qua câu lệnh trực tiếp hay qua bất kỳ ứng dụng nào, trigger vẫn tự động kích hoạt. ECMS có 11 trigger:

| Trigger | Bảng hoặc view | Loại và sự kiện | Nhiệm vụ | RBTV |
|---|---|---|---|---|
| `trg_DangKy_KiemTraSiSo` | DANGKY | AFTER INSERT, UPDATE – chạy đầu tiên | Chặn ghi danh làm lớp vượt sĩ số | RB06 |
| `trg_DangKy_SiSo` | DANGKY | AFTER INSERT, UPDATE, DELETE – chạy cuối cùng | Tính lại sĩ số hiện tại của lớp | RB14 |
| `trg_DangKy_KetQua` | DANGKY | AFTER INSERT, UPDATE điểm | Xác định kết quả Đạt hoặc Không đạt | – |
| `trg_CTPhieuThu_TongTien` | CT_PHIEUTHU | AFTER INSERT, UPDATE, DELETE | Chặn sai học viên, thu vượt; cập nhật tổng tiền phiếu và trạng thái học phí | RB15, RB16 |
| `trg_LichHoc_KiemTraTrung` | LICHHOC | AFTER INSERT, UPDATE | Chặn trùng phòng, trùng giáo viên khi thời gian hai lớp giao nhau | RB09, RB10 |
| `trg_NhatKy_DangKy` | DANGKY | AFTER INSERT, UPDATE, DELETE | Ghi nhật ký, bỏ qua lệnh sửa không làm đổi giá trị | NFR03 |
| `trg_NhatKy_PhieuThu` | PHIEUTHU | AFTER INSERT, UPDATE, DELETE | Ghi nhật ký phiếu thu | NFR03 |
| `trg_NhatKy_Luong` | NHANVIEN | AFTER UPDATE cột lương | Ghi lương cũ, lương mới và phần trăm thay đổi | NFR03 |
| `trg_NhatKy_ChiDoc` | NHATKY | INSTEAD OF UPDATE, DELETE | Nhật ký chỉ được thêm, không được sửa, xoá | NFR03 |
| `trg_vwDangKyChiTiet_Insert` | View vw_DangKyChiTiet | INSTEAD OF INSERT | Ghi danh qua view kết nối bốn bảng, học phí lấy từ khoá học | – |
| `trg_vwDangKyChiTiet_Delete` | View vw_DangKyChiTiet | INSTEAD OF DELETE | "Xoá" qua view nghĩa là huỷ đăng ký (xoá mềm), chặn nếu đã có phiếu thu | – |

**Bảng ảo inserted và deleted.** Khi trigger chạy, SQL Server cung cấp hai bảng ảo có cùng cấu trúc với bảng gốc:

| Thao tác | Bảng `inserted` | Bảng `deleted` |
|---|---|---|
| INSERT | Các dòng vừa thêm | Rỗng |
| DELETE | Rỗng | Các dòng vừa xoá |
| UPDATE | Giá trị sau khi sửa | Giá trị trước khi sửa |

**Phân tích trigger tiêu biểu – trg_DangKy_SiSo.** Trigger trong SQL Server chạy **một lần cho mỗi câu lệnh**, không phải cho mỗi dòng: một câu `INSERT … SELECT` có thể thêm 30 đăng ký cùng lúc và trigger chỉ chạy một lần với 30 dòng trong bảng `inserted`. Vì vậy mọi trigger của ECMS được viết theo hướng tập hợp. Trigger sĩ số không cộng, trừ 1 mà **đếm lại** sĩ số cho mọi lớp bị ảnh hưởng – gồm lớp của các dòng mới (trong `inserted`) và lớp của các dòng cũ (trong `deleted`). Cách này đúng cho cả thêm, xoá, chuyển lớp và đổi trạng thái sang bảo lưu, với một hay nhiều dòng.

```sql title="Mã lệnh – Trigger trg_DangKy_SiSo"
CREATE OR ALTER TRIGGER dbo.trg_DangKy_SiSo
ON dbo.DANGKY
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    UPDATE l
    SET SiSoHienTai = (SELECT COUNT(*) FROM dbo.DANGKY d
                       WHERE d.MaLop = l.MaLop AND d.TrangThai IN (N'Đang học', N'Hoàn thành'))
    FROM dbo.LOPHOC l
    WHERE l.MaLop IN (SELECT MaLop FROM inserted UNION SELECT MaLop FROM deleted);
END
```

Cách viết sai phổ biến là gán `@MaLop = (SELECT MaLop FROM inserted)`: câu lệnh này chỉ đúng khi có một dòng và cho kết quả sai, hoặc báo lỗi, khi câu lệnh gốc tác động nhiều dòng.

**Thứ tự kích hoạt.** Bảng DANGKY có bốn trigger AFTER cho sự kiện INSERT. Nhóm dùng `sp_settriggerorder` để `trg_DangKy_KiemTraSiSo` chạy **đầu tiên** – chặn sớm và trả thông báo tiếng Việt thay vì lỗi ràng buộc CHECK khó hiểu – và `trg_DangKy_SiSo` chạy **cuối cùng**; hai trigger còn lại chạy theo thứ tự không xác định. Thứ tự đầy đủ khi thực hiện một câu INSERT vào DANGKY là: kiểm tra ràng buộc (CHECK, khoá ngoại, UNIQUE), ghi dữ liệu, chạy các trigger AFTER từ đầu đến cuối, xác nhận giao dịch. Trigger INSTEAD OF thì chạy *thay cho* thao tác, trước cả bước kiểm tra ràng buộc.

**Nhật ký kiểm toán.** Mỗi dòng nhật ký lưu dữ liệu cũ và mới dạng JSON (tạo bằng `FOR JSON PATH, WITHOUT_ARRAY_WRAPPER`), login SQL Server thực hiện và tài khoản ứng dụng thực hiện. Thông tin thứ hai là cần thiết vì mọi người dùng web đều kết nối bằng cùng một login `ecms_app`; ứng dụng đặt tên tài khoản vào `SESSION_CONTEXT(N'app_user')` khi đăng nhập để trigger đọc lại. Ví dụ một dòng nhật ký khi tăng lương:

```text title="Ví dụ – Một dòng nhật ký thay đổi lương"
NHANVIEN  {"LuongCoBan":11500000} → {"LuongCoBan":12650000,"PhanTramThayDoi":10.00}  bởi sa / kiemthu
```

**Kiểm thử.** Bộ kiểm thử `test_triggers.sql` thao tác **trực tiếp lên bảng**, bỏ qua procedure, để chứng minh CSDL tự bảo vệ được mình. Lỗi xảy ra trong trigger luôn làm giao dịch không thể xác nhận được nữa, vì vậy mỗi ca chạy trong một giao dịch riêng rồi huỷ.

| Trigger | Ca kiểm thử | Kết quả | Đánh giá |
|---|---|---|:-:|
| trg_DangKy_KiemTraSiSo | Thêm thẳng một đăng ký vào lớp đã đầy IE55-2602 | 50070 Lớp IE55-2602 đã đủ sĩ số, không thể ghi danh thêm | Đạt |
| trg_DangKy_SiSo | Thêm một đăng ký, rồi chuyển đăng ký đó sang Bảo lưu | Sĩ số 10 → 11 → 10 | Đạt |
| trg_DangKy_KetQua | Điểm GK 4, CK 5, sau đó sửa CK thành 7 | 4,60 Không đạt → 5,80 Đạt | Đạt |
| trg_CTPhieuThu_TongTien | Thêm dòng 1,5 triệu, sửa thành 4 triệu, rồi xoá | Đóng một phần → Đã đóng → Chưa đóng; tổng tiền phiếu luôn khớp | Đạt |
| | Thu thêm cho đăng ký đã đóng đủ | 50072 Tổng số tiền đã thu vượt quá học phí phải đóng | Đạt |
| | Dòng chi tiết là đăng ký của học viên khác | 50071 | Đạt |
| trg_LichHoc_KiemTraTrung | Xếp lớp GT3-2601 vào thứ Bảy, ca 1, phòng P101 | 50073 Trùng phòng P101 (CN03) với lớp IE55-2601 | Đạt |
| Các trigger nhật ký | Các thao tác ở trên | 13 dòng nhật ký ghi đúng tài khoản `kiemthu`; tăng lương 10% ghi một dòng, sửa cột khác không ghi | Đạt |
| trg_NhatKy_ChiDoc | Sửa một dòng nhật ký | 50074 Nhật ký kiểm toán chỉ được thêm, không được sửa hoặc xoá | Đạt |
| Trigger trên view | Thêm qua view; xoá qua view; thêm vào lớp đã kết thúc | Học phí 4.000.000, thành tiền 3.600.000, sĩ số tăng 1; huỷ đăng ký, sĩ số giảm 1; lỗi 50075 | Đạt |

Kết quả **17/17 ca đạt**. Bộ kiểm thử procedure vẫn đạt 25/25 ca khi các trigger hoạt động, chứng tỏ procedure và trigger không xung đột nhau.

**So sánh trigger và ràng buộc CHECK.**

| Tiêu chí | Ràng buộc CHECK | Trigger |
|---|---|---|
| Phạm vi | Một dòng của một bảng | Nhiều dòng, nhiều bảng |
| Ví dụ trong ECMS | Giờ kết thúc sau giờ bắt đầu; sĩ số không vượt tối đa | Trùng phòng giữa các lớp; tổng tiền phiếu thu |
| Thời điểm | Trước khi ghi dòng | Sau khi ghi (AFTER) hoặc thay cho thao tác (INSTEAD OF) |
| Thay đổi dữ liệu khác | Không | Có: cập nhật sĩ số, ghi nhật ký |
| Hiệu năng | Rất nhanh, bộ tối ưu tận dụng được | Chậm hơn vì chạy thêm truy vấn mỗi lần ghi |
| Thông báo lỗi | Thông báo chuẩn của SQL Server kèm tên ràng buộc | Tự viết bằng tiếng Việt |
| Có thể bị vô hiệu khi | Dùng `NOCHECK` | Dùng `DISABLE TRIGGER` |

Nguyên tắc nhóm áp dụng: dùng CHECK, khoá ngoại, UNIQUE trước; chỉ dùng trigger khi ràng buộc vượt quá phạm vi một dòng hoặc cần cập nhật dữ liệu khác.

### 3.3.4 Cursor

**Vai trò.** Cursor cho phép xử lý tập kết quả theo từng dòng. ECMS dùng cursor cho ba nghiệp vụ có tính tuần tự, đồng thời viết thêm hai phiên bản xử lý theo tập hợp (set-based) để đối chiếu kết quả và tốc độ:

| Procedure | Cursor | Loại cursor | Nghiệp vụ |
|---|---|---|---|
| `sp_SinhBuoiHoc` | Các dòng lịch học trùng thứ của ngày đang xét | `LOCAL FAST_FORWARD` | Duyệt từng ngày từ ngày khai giảng, bỏ qua ngày lễ, sinh buổi học tới đủ số buổi của khoá, cập nhật ngày kết thúc lớp; không cho sinh lại khi lớp đã điểm danh |
| `sp_TinhLuongGiaoVien` | Các giáo viên đang làm việc | `LOCAL STATIC READ_ONLY` | Đếm số buổi đã dạy trong tháng nhân đơn giá, cộng lương cơ bản, ghi hoặc cập nhật bảng lương |
| `sp_CanhBaoChuyenCan` | Các đăng ký đang học | `LOCAL FAST_FORWARD` | Tính tỷ lệ vắng; vượt ngưỡng thì ghi cảnh báo, trên 30% là mức Nghiêm trọng |
| `sp_TinhLuongGiaoVien_SetBased`, `sp_CanhBaoChuyenCan_SetBased` | – | – | Cùng kết quả bằng một câu `MERGE` hoặc `INSERT … SELECT … GROUP BY` |

**Vòng đời của cursor.** Đoạn mã trích từ `sp_SinhBuoiHoc` thể hiện đủ năm giai đoạn: khai báo, mở, đọc, đóng và giải phóng.

```sql title="Mã lệnh – Vòng đời cursor trong sp_SinhBuoiHoc"
DECLARE cur_Lich CURSOR LOCAL FAST_FORWARD FOR            -- 1. DECLARE: định nghĩa câu SELECT
    SELECT MaCa, MaPhong FROM dbo.LICHHOC WHERE MaLop = @MaLop AND Thu = @Thu ORDER BY MaCa;
OPEN cur_Lich;                                             -- 2. OPEN: thực thi, tạo tập kết quả
FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;             -- 3. FETCH: lấy từng dòng vào biến
WHILE @@FETCH_STATUS = 0 AND @STT < @SoBuoi                --    0: đọc được; -1: hết dòng; -2: dòng đã bị xoá
BEGIN
    SET @STT += 1;
    INSERT dbo.BUOIHOC (...) VALUES (@MaLop, @STT, @Ngay, @MaCa, @MaPhong, ...);
    FETCH NEXT FROM cur_Lich INTO @MaCa, @MaPhong;
END
CLOSE cur_Lich;                                            -- 4. CLOSE: giải phóng tập kết quả và khoá
DEALLOCATE cur_Lich;                                       -- 5. DEALLOCATE: huỷ định nghĩa cursor
```

Từ khoá `LOCAL` giới hạn cursor trong phạm vi procedure để không trùng tên với phiên khác; khối CATCH kiểm tra `CURSOR_STATUS` để giải phóng cursor khi lỗi xảy ra giữa chừng. Thiếu lệnh FETCH ở cuối thân vòng lặp sẽ tạo vòng lặp vô hạn – lỗi phổ biến nhất khi viết cursor.

**Kết quả chạy.** `sp_SinhBuoiHoc 'IE65-2601', 1` sinh **30 buổi học** với ngày kết thúc 07/02/2027, trùng khớp hoàn toàn với lịch trong dữ liệu mẫu. Gọi procedure cho lớp IE55-2602 đã điểm danh thì bị từ chối với lỗi 50083 "Lớp đã điểm danh, không thể sinh lại buổi học". Kết quả tính lương tháng 9/2026 (trích):

| Giáo viên | Số buổi dạy | Đơn giá (đồng) | Lương cơ bản (đồng) | Tổng lương (đồng) |
|---|:-:|--:|--:|--:|
| Wilson David | 8 | 700.000 | 7.000.000 | 12.600.000 |
| Smith John | 8 | 800.000 | 6.000.000 | 12.400.000 |
| Lê Thanh Yến | 8 | 450.000 | 7.500.000 | 11.100.000 |
| Bùi Đức Nhiên | 0 | 400.000 | 8.000.000 | 8.000.000 |

Chạy cảnh báo chuyên cần với ngưỡng vắng 15% sinh ra 11 cảnh báo; ba cảnh báo đầu danh sách:

| Học viên | Lớp | Số buổi đã học | Số buổi vắng | Tỷ lệ vắng | Mức độ |
|---|---|:-:|:-:|--:|---|
| Phạm Khánh Duyên | TC650-2601 | 16 | 7 | 43,75% | Nghiêm trọng |
| Trần Phương Dương | KD2-2601 | 13 | 3 | 23,08% | Nhắc nhở |
| Vũ Minh Châu | KD2-2601 | 10 | 2 | 20,00% | Nhắc nhở |

**Các loại cursor.** Để thấy rõ khác biệt giữa các loại cursor, nhóm mở cursor trên một bảng ba dòng, đọc dòng thứ nhất, rồi trong khi cursor đang mở thì **sửa dòng 2** và **thêm dòng 4**:

| Loại | Thấy dòng bị sửa | Thấy dòng mới | Các giá trị đọc được | Đặc điểm |
|---|:-:|:-:|---|---|
| `STATIC` | Không | Không | 1:10, 2:20, 3:30 | Chụp toàn bộ kết quả vào tempdb lúc mở; cuộn tới lui được; không cập nhật được |
| `KEYSET` | Có | Không | 1:10, **2:999**, 3:30 | Lưu tập khoá lúc mở, đọc giá trị mới nhất theo khoá |
| `DYNAMIC` | Có | Có | 1:10, **2:999**, 3:30, **4:40** | Đánh giá lại ở mỗi lần đọc, tốn tài nguyên nhất |
| `FAST_FORWARD` | Có | Có | 1:10, 2:999, 3:30, 4:40 | Chỉ đọc, chỉ tiến; nhẹ nhất, nên là lựa chọn mặc định |

**So sánh cursor với xử lý theo tập hợp.** Mỗi bài toán được chạy 20 lần bằng cả hai cách, mỗi lần trong một giao dịch rồi huỷ, lấy thời gian trung bình:

| Bài toán | Cursor (ms) | Theo tập hợp (ms) | Cursor chậm hơn | Kết quả giống nhau |
|---|--:|--:|--:|:-:|
| Cảnh báo chuyên cần cho toàn bộ đăng ký đang học | 13,25 | 5,94 | 2,2 lần | Có |
| Bảng lương 12 tháng năm 2025 (tổng 1.000.400.000 đồng) | 47,98 | 11,51 | 4,2 lần | Có |
| Sinh 30 buổi học cho lớp IE65-2601 | 10,50 | 4,77 | 2,2 lần | Có, cùng ngày kết thúc |

**Nhận xét.** Xử lý theo tập hợp nhanh hơn từ 2 đến 4 lần ngay trên dữ liệu nhỏ, và khoảng cách sẽ tăng theo số dòng, vì cursor thực hiện một truy vấn con cho *mỗi* dòng (10 giáo viên × 12 tháng là 120 lần đếm buổi), còn cách tập hợp để bộ tối ưu gộp thành một kế hoạch thực thi duy nhất. Tuy vậy, cursor vẫn hợp lý khi logic của bước sau phụ thuộc vào kết quả của bước trước – như sinh buổi học, nơi số thứ tự và điều kiện dừng phụ thuộc số buổi đã sinh – khi cần gọi procedure cho từng dòng, hoặc khi cần xử lý theo lô nhỏ để tránh giữ khoá lâu. Nguyên tắc nhóm áp dụng: **mặc định xử lý theo tập hợp, chỉ dùng cursor `LOCAL FAST_FORWARD` khi bài toán thực sự tuần tự**.

## 3.4 Tiểu kết chương

Chương 3 đã xây dựng toàn bộ lớp xử lý và bảo vệ thông tin ngay trong CSDL. Về truy vấn, bộ 31 truy vấn SQL và 17 truy vấn XML trả lời các câu hỏi quản lý thực tế, kèm số liệu đo cho thấy tác dụng của chỉ mục và cách viết điều kiện đúng. Về an ninh, hệ thống áp dụng băm mật khẩu có salt, phân quyền tối thiểu với login ứng dụng bị cấm trên mọi bảng, bảo mật theo dòng và theo cột bằng view, chiến lược sao lưu đạt RPO 15 phút đã được diễn tập phục hồi thành công, và quy trình nhập dữ liệu có kiểm soát chất lượng. Về lập trình, 38 procedure, 13 function, 11 trigger và các cursor đóng gói mọi quy tắc nghiệp vụ. Tổng cộng 78 ca kiểm thử tự động (25 procedure, 17 trigger, 36 phân quyền) đều đạt. Lớp xử lý này là nền tảng để Chương 4 xây dựng giao diện chỉ gọi view và procedure mà không truy cập bảng gốc.
