# Chương 5. Mô hình cơ sở dữ liệu tiên tiến

## 5.1 Cơ sở dữ liệu hướng đối tượng

### 5.1.1 Tính chất và đặc điểm

CSDL hướng đối tượng (OODB) lưu trữ trực tiếp **đối tượng** của ngôn ngữ lập trình thay vì dòng trong bảng. Các khái niệm chính (theo chuẩn ODMG 3.0):

| Khái niệm | Ý nghĩa | Ví dụ trên ECMS |
|---|---|---|
| **Đối tượng & OID** | Mỗi đối tượng có định danh do hệ thống cấp, không đổi suốt vòng đời, độc lập với giá trị thuộc tính | Học viên đổi số điện thoại hay mã HV vẫn là cùng đối tượng; quan hệ trỏ bằng OID, không cần khoá ngoại |
| **Đóng gói** | Dữ liệu và hành vi nằm chung trong lớp; bên ngoài chỉ thao tác qua phương thức | `LopHoc.siSoConLai()`, `HocVien.dangKy(lop)` thay cho procedure rời |
| **Kế thừa** | Lớp con nhận thuộc tính, phương thức của lớp cha | `Nguoi` → `HocVien`, `Nguoi` → `NhanVien` → `GiaoVien` |
| **Đa hình** | Cùng lời gọi, mỗi lớp có cách thực hiện riêng | `nv.tinhLuong(thang)`: nhân viên = lương cơ bản; giáo viên = cơ bản + số buổi × đơn giá |
| **Kiểu phức** | Thuộc tính có thể là struct, tập hợp, danh sách | `diaChi : DiaChi`, `chungChis : set<ChungChi>`, `buoiHocs : list<BuoiHoc>` |
| **Quan hệ & quan hệ ngược** | `relationship … inverse …` – hệ quản trị tự giữ hai chiều nhất quán | `LopHoc.giaoVien` ↔ `GiaoVien.lopPhuTrach` |
| **Ngôn ngữ** | ODL định nghĩa lược đồ, OQL truy vấn (cú pháp gần SQL nhưng duyệt đường dẫn, gọi phương thức) | `select l.khoaHoc.tenKH from l in cacLopHoc` |
| **Lưu bền (persistence)** | Đối tượng tồn tại sau khi chương trình kết thúc, nạp lại khi truy cập | Lazy loading trong mã minh hoạ |

### 5.1.2 Chuyển lược đồ quan hệ ECMS sang lược đồ hướng đối tượng

Lược đồ ODL đầy đủ: [`docs/design/odl-schema.md`](../docs/design/odl-schema.md) – **18 lớp**, 1 interface `Nguoi`, 4 struct, 4 exception, hơn 20 cặp `relationship / inverse`. Quy tắc chuyển đổi chính:

| Cấu trúc quan hệ | Cấu trúc hướng đối tượng | Hệ quả |
|---|---|---|
| Khoá ngoại 1–N (LOPHOC.MaGV) | `relationship GiaoVien giaoVien inverse GiaoVien::lopPhuTrach` | Duyệt `lop.giaoVien.hoTen` thay cho JOIN |
| Bảng N–M có thuộc tính (DANGKY) | Lớp liên kết `DangKy` với 2 relationship | Giữ nguyên như Class Diagram (mục 2.3) |
| Chuyên biệt hoá NHANVIEN / GIAOVIEN (2 bảng, PK = FK) | `class GiaoVien extends NhanVien` | Một đối tượng, không phải JOIN hai bảng |
| Thuộc tính đa trị CHUNGCHI_GV (bảng riêng) | `attribute set<ChungChi> chungChis` | Bỏ được một bảng |
| Thuộc tính phức hợp tách cột (SoNha, PhuongXa…) | `struct DiaChi` | Giữ được cấu trúc tự nhiên |
| Thực thể yếu BUOIHOC | `relationship list<BuoiHoc> buoiHocs` – danh sách có thứ tự | Không cần cột STT làm khoá |
| Cột suy diễn + trigger (SiSoHienTai, TongTien) | Phương thức `siSoHienTai()`, `tinhTong()` | Không thể lệch dữ liệu, nhưng phải tính mỗi lần gọi |
| Procedure nghiệp vụ (sp_DangKyHoc) | `DangKy dangKy(in LopHoc, in float) raises (LopDay, ThieuTienQuyet)` | Nghiệp vụ gắn với lớp |

### 5.1.3 Minh hoạ bằng Python

Thư mục [`oodb/`](../oodb/) cài đặt một phần lược đồ ODL bằng các lớp Python ánh xạ từ bảng (kiểu ORM tối giản, không dùng thư viện ngoài):

- `Session` giữ **identity map**: cùng một khoá luôn trả về **cùng một đối tượng** (mô phỏng OID) và đếm số câu SQL đã gửi;
- relationship được **nạp lười** khi truy cập lần đầu (`lop.giao_vien`, `hoc_vien.dang_kys`);
- `GiaoVien(NhanVien(Nguoi))` dùng kế thừa thật của Python, `tinh_luong()` đa hình; thuộc tính suy diễn là phương thức.

Chạy `python3 oodb/demo.py` (dữ liệu mẫu):

| Bài toán | Cách làm | Kết quả | Thời gian | Số câu SQL |
|---|---|---|--:|--:|
| Lộ trình tiên quyết IELTS 6.5+ | OO: `KhoaHoc('IE65').lo_trinh()` (đệ quy theo đối tượng) | IEF → IE55 → IE65 | 16,5 ms | 3 |
| | SQL: CTE đệ quy (Q26) | IEF → IE55 → IE65 | 8,1 ms | 1 |
| Chỗ trống các lớp đang học | OO: `l.si_so_con_lai()` cho từng lớp | giống nhau | 39,5 ms | 6 |
| | SQL: `SiSoToiDa − SiSoHienTai` | giống nhau | 5,4 ms | 1 |
| Tổng công nợ toàn trung tâm | OO: `sum(h.cong_no() for h in HocVien)` | 271 743 000 đ | 1 873,5 ms | **889** |
| | SQL: `SUM(ConNo)` trên `vw_CongNoHocVien` | 271 743 000 đ | 40,1 ms | 1 |

Đa hình và identity map:

```text
NhanVien  Dương Mai Yến     27,000,000     ← lương cơ bản
GiaoVien  Lê Thanh Yến      11,100,000     ← 7.500.000 + 8 buổi × 450.000
lop.giao_vien is s.get(NhanVien, 'NV0015') → True ; isinstance(gv, GiaoVien) → True
```

**Nhận xét.** Cả hai cách cho cùng kết quả. Cách hướng đối tượng viết tự nhiên hơn (đọc như nghiệp vụ, không cần nhớ điều kiện JOIN) nhưng khi nạp lười gặp **vấn đề N+1 truy vấn**: tính tổng công nợ cần 889 câu SQL (1 câu lấy học viên + mỗi học viên lấy đăng ký + mỗi đăng ký lấy số tiền đã thu), chậm gấp ~47 lần một câu `SUM` để hệ quản trị quan hệ tối ưu theo tập hợp. Các ORM thực tế (SQLAlchemy, Entity Framework) giảm vấn đề này bằng nạp trước (*eager loading*, `JOIN FETCH`), nhưng truy vấn thống kê trên toàn bộ dữ liệu vẫn là thế mạnh của SQL.

### 5.1.4 So sánh mô hình quan hệ và hướng đối tượng cho bài toán ECMS

| Tiêu chí | Mô hình quan hệ (ECMS hiện tại) | Mô hình hướng đối tượng |
|---|---|---|
| Đơn vị dữ liệu | Dòng trong bảng, định danh bằng khoá | Đối tượng, định danh bằng OID |
| Quan hệ | Khoá ngoại + JOIN lúc truy vấn | Tham chiếu trực tiếp, duyệt đường dẫn |
| Kế thừa (Nhân viên / Giáo viên) | Mô phỏng bằng 2 bảng PK = FK | Hỗ trợ trực tiếp, có đa hình |
| Kiểu phức (địa chỉ, chứng chỉ, kết quả test) | Tách cột / tách bảng / dùng XML | struct, set, list tự nhiên |
| Hành vi | Procedure, function, trigger tách rời dữ liệu | Phương thức đóng gói trong lớp |
| Truy vấn tự do, thống kê, báo cáo | **Rất mạnh** (SQL, optimizer, chỉ mục, indexed view) | Yếu hơn; OQL ít được hỗ trợ đầy đủ |
| Ràng buộc toàn vẹn khai báo | CHECK, FK, UNIQUE, transaction ACID trưởng thành | Phần lớn viết trong phương thức |
| Phân quyền, kiểm toán, sao lưu | Đầy đủ, chuẩn hoá (Chương 3) | Phụ thuộc sản phẩm |
| Lệch trở kháng với ứng dụng (impedance mismatch) | Có – phải ánh xạ dòng ↔ đối tượng | Không |
| Công cụ, nhân lực, cộng đồng | Phổ biến (SQL Server, SSMS, Power BI…) | Ít (db4o, ObjectDB, Versant…) – nhiều sản phẩm đã ngừng |
| Phù hợp nhất với | Nghiệp vụ giao dịch + báo cáo như trung tâm ngoại ngữ | Dữ liệu cấu trúc phức tạp, ít truy vấn thống kê (CAD, đa phương tiện, mô phỏng) |

**Đánh giá cho trung tâm ECMS**

- *Điểm mạnh nếu dùng OODB:* mô hình hoá tự nhiên kế thừa Nhân viên – Giáo viên, chứng chỉ đa trị, kết quả kiểm tra có cấu trúc lồng; mã ứng dụng ngắn hơn vì không cần ánh xạ.
- *Điểm yếu:* phần lớn giá trị của ECMS nằm ở **báo cáo và thống kê** (doanh thu theo chi nhánh – tháng, công nợ, chuyên cần) và **ràng buộc giao dịch** (không vượt sĩ số, không thu vượt) – đúng thế mạnh của mô hình quan hệ; đội ngũ và công cụ của trung tâm cũng quen SQL Server.
- *Kết luận:* giữ **CSDL quan hệ** làm lõi, áp dụng tư tưởng hướng đối tượng ở **tầng ứng dụng** (lớp nghiệp vụ, ORM có eager loading) và dùng các tính năng *đối tượng – quan hệ* sẵn có của SQL Server (kiểu XML có schema, cột tính toán, hàm trả về bảng) cho phần dữ liệu phức.

## 5.2 Cơ sở dữ liệu phân tán

### 5.2.1 Đặc điểm và lựa chọn cho chuỗi trung tâm

CSDL phân tán là tập hợp nhiều CSDL logic liên quan, đặt tại nhiều trạm nối mạng, được quản lý sao cho người dùng thấy như **một CSDL duy nhất** (trong suốt phân tán). Các đặc trưng: dữ liệu được *phân mảnh* và *cấp phát* về nơi dùng nhiều nhất, có thể *nhân bản*, truy vấn và giao tác có thể trải trên nhiều trạm.

| Tiêu chí | Tập trung (ECMS hiện tại) | Phân tán theo chi nhánh |
|---|---|---|
| Vị trí dữ liệu | Một máy chủ | Mỗi chi nhánh giữ dữ liệu của mình |
| Tốc độ truy cập tại chi nhánh | Phụ thuộc đường truyền tới trung tâm | Nhanh – đa số nghiệp vụ (điểm danh, ghi danh, thu phí) chỉ chạm dữ liệu tại chỗ |
| Khi mất kết nối / trung tâm sự cố | Toàn bộ chi nhánh ngừng | Chi nhánh vẫn hoạt động với dữ liệu cục bộ |
| Báo cáo toàn hệ thống | Đơn giản | Phải gom từ nhiều trạm (truy vấn toàn cục) |
| Toàn vẹn liên trạm (học viên học ở 2 chi nhánh, chuyển lớp liên chi nhánh) | Một transaction cục bộ | Giao tác phân tán, cam kết 2 pha |
| Bảo mật | Một điểm quản lý | Dữ liệu nhạy cảm (lương) có thể chỉ để ở trung tâm |
| Chi phí vận hành | Thấp | Cao hơn: nhiều máy chủ, đồng bộ, sao lưu từng trạm |

Với 3 chi nhánh và ~100 học viên mỗi nơi, mô hình tập trung vẫn đủ; phân tán phù hợp khi chuỗi mở rộng (nhiều tỉnh, kết nối không ổn định). Demo dưới đây cho thấy cách thiết kế nếu cần mở rộng.

### 5.2.2 Thiết kế phân mảnh

| Quan hệ | Kiểu phân mảnh | Định nghĩa | Lý do |
|---|---|---|---|
| HOCVIEN | **Ngang chính** | HOCVIEN_i = σ<sub>MaCN = 'CN0i'</sub>(HOCVIEN) | Học viên do chi nhánh lập hồ sơ quản lý |
| LOPHOC | Ngang chính | LOPHOC_i = σ<sub>MaCN = 'CN0i'</sub>(LOPHOC) | Lớp mở tại một chi nhánh |
| DANGKY | **Ngang dẫn xuất** | DANGKY_i = DANGKY ⋉ LOPHOC_i | Đăng ký đi cùng lớp: điểm danh, nhập điểm, thu phí của lớp đều ở cùng trạm |
| DIEMDANH | Ngang dẫn xuất | DIEMDANH_i = DIEMDANH ⋉ DANGKY_i | |
| NHANVIEN | **Dọc** | NV_CHUNG = π<sub>MaNV, HoNV, TenNV, ChucVu, SĐT, Email, MaCN</sub>(NHANVIEN); NV_LUONG = π<sub>MaNV, LuongCoBan</sub>(NHANVIEN) | Lương là dữ liệu nhạy cảm, chỉ trung tâm cần |
| NV_CHUNG | **Hỗn hợp** (dọc rồi ngang) | NV_CHUNG_i = σ<sub>MaCN = 'CN0i'</sub>(NV_CHUNG) | Danh bạ nhân viên ở chi nhánh |
| CHUONGTRINH, KHOAHOC, CAHOC | **Nhân bản** toàn phần | bản sao ở mọi trạm | Ít thay đổi, mọi nghiệp vụ đều đọc |

**Lược đồ cấp phát**

| Trạm | CSDL demo | Mảnh được cấp phát |
|---|---|---|
| Chi nhánh Thủ Đức | `ECMS_CN01` | HOCVIEN_1, LOPHOC_1, DANGKY_1, DIEMDANH_1, NV_CHUNG_1, bản sao danh mục |
| Chi nhánh Quận 1 | `ECMS_CN02` | HOCVIEN_2, LOPHOC_2, DANGKY_2, DIEMDANH_2, NV_CHUNG_2, bản sao danh mục |
| Chi nhánh Bình Thạnh | `ECMS_CN03` | HOCVIEN_3, LOPHOC_3, DANGKY_3, DIEMDANH_3, NV_CHUNG_3, bản sao danh mục |
| Trung tâm | `ECMS_TOANCUC` | NV_LUONG + **lược đồ toàn cục** (partitioned view) |

### 5.2.3 Cài đặt demo

[`database/13_distributed.sql`](../database/13_distributed.sql) mô phỏng 3 trạm bằng 3 CSDL trên cùng instance (trên thực tế là 3 máy chủ nối bằng **linked server**, mẫu ở mục 6 của script). Mỗi mảnh có `CHECK (MaCN = 'CN0i')` trên cột phân mảnh và khoá chính chứa `MaCN`. Trạm trung tâm định nghĩa view cùng tên với bảng gốc:

```sql
CREATE VIEW dbo.HOCVIEN AS                        -- ECMS_TOANCUC: trong suốt vị trí
    SELECT * FROM ECMS_CN01.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN02.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN03.dbo.HOCVIEN;

CREATE VIEW dbo.NHANVIEN AS                       -- tái thiết mảnh dọc bằng phép kết
    SELECT c.*, l.LuongCoBan FROM (… ∪ NHANVIEN_CHUNG_i …) c JOIN dbo.NHANVIEN_LUONG l ON l.MaNV = c.MaNV;
```

**Số dòng mỗi trạm**

| Trạm | Học viên | Lớp | Đăng ký | Điểm danh |
|---|--:|--:|--:|--:|
| CN01 | 133 | 9 | 195 | 3 280 |
| CN02 | 119 | 8 | 181 | 3 597 |
| CN03 | 97 | 8 | 163 | 3 186 |

**Kiểm tra tính đúng đắn của phân mảnh**

| Điều kiện | Cách kiểm tra | Kết quả |
|---|---|---|
| **Đầy đủ** – mọi dòng của quan hệ gốc nằm trong ít nhất một mảnh | So số dòng + `EXCEPT` giữa bảng gốc và hợp các mảnh | HOCVIEN 349 = 349, LOPHOC 25 = 25, DANGKY 539 = 539, DIEMDANH 10 063 = 10 063, NHANVIEN 20 = 20 ✓ |
| **Rời nhau** – không dòng nào thuộc hai mảnh ngang | `INTERSECT` từng cặp trạm (HOCVIEN, DANGKY) | 0 dòng trùng ✓ |
| **Tái thiết** – ghép lại được quan hệ gốc | Ngang: `UNION ALL`; dọc: `JOIN` theo MaNV, `EXCEPT` với bảng gốc | 0 dòng khác ✓ |

**Truy vấn toàn cục** viết như trên CSDL tập trung:

| Truy vấn | Phân tán (ECMS_TOANCUC) | Tập trung (ECMS) |
|---|---|---|
| G1 – số đăng ký, số đạt, tổng phải thu theo 12 khoá học | 12 dòng | **0 dòng khác** (`EXCEPT` hai chiều) |
| G2 – học viên học ở chi nhánh khác nơi lập hồ sơ (kết mảnh HOCVIEN trạm A với DANGKY trạm B) | 136 | 136 |
| G3 – quỹ lương theo chi nhánh | CN01 89 tr · CN02 69,5 tr · CN03 72 tr | chỉ trả lời được ở trạm trung tâm |

**Loại bỏ mảnh** (*partition elimination*): `SELECT COUNT(*) FROM dbo.HOCVIEN WHERE MaCN = 'CN02'` trên view toàn cục chỉ đọc bảng của trạm CN02 (`STATISTICS IO`: 1 bảng, 4 logical reads) – nhờ các ràng buộc CHECK, optimizer biết CN01 và CN03 không thể chứa dòng thoả điều kiện nên không gửi truy vấn tới đó.

### 5.2.4 Giao tác phân tán và điều khiển đồng thời

- **Chuyển lớp liên chi nhánh** (đăng ký cũ ở CN02, đăng ký mới ở CN01) phải cập nhật hai trạm như một đơn vị: SQL Server dùng `BEGIN DISTRIBUTED TRANSACTION` + **MSDTC** theo **giao thức cam kết hai pha (2PC)**: *pha chuẩn bị* – điều phối viên hỏi mọi trạm "sẵn sàng ghi chưa?", các trạm ghi log và khoá dữ liệu; *pha cam kết* – nếu tất cả đồng ý thì gửi COMMIT, chỉ một trạm từ chối là ROLLBACK toàn bộ.
- **Điểm yếu của 2PC:** trạm giữ khoá suốt thời gian chờ; điều phối viên sự cố giữa hai pha làm trạm bị "treo" (blocking). Vì vậy thiết kế phân mảnh dẫn xuất để **phần lớn giao tác chỉ chạm một trạm** (ghi danh, điểm danh, thu phí của lớp đều cục bộ).
- **Đồng thời:** mỗi trạm dùng khoá cục bộ (như `UPDLOCK` trong `sp_DangKyHoc`); giao tác toàn cục cần khoá ở mọi trạm tham gia theo thứ tự cố định để tránh deadlock phân tán, hoặc dùng mức cô lập *snapshot* cho truy vấn báo cáo toàn cục để không khoá chi nhánh.
- **Nhân bản danh mục:** thay đổi khoá học / học phí được thực hiện ở trung tâm và lan truyền tới chi nhánh (SQL Server Replication kiểu *transactional* hoặc *merge*); chấp nhận trễ vài giây vì danh mục ít thay đổi.

## 5.3 Cơ sở dữ liệu phi quan hệ (NoSQL)

### 5.3.1 Hạn chế của mô hình quan hệ với một phần dữ liệu ECMS

| Dữ liệu | Khó khăn trên mô hình quan hệ |
|---|---|
| Kết quả kiểm tra đầu vào (4 kỹ năng, nhận xét, có thể thêm kỹ năng / điểm thành phần) | Cấu trúc thay đổi theo đề thi → phải dùng cột XML + XML Schema + XQuery (mục 3.1.3), truy vấn dài dòng |
| Hồ sơ học tập (đăng ký → điểm → điểm danh từng buổi) | Đọc một hồ sơ cần JOIN 4–5 bảng; DIEMDANH tăng nhanh nhất (~10 000 dòng chỉ với 25 lớp) |
| Nhật ký kiểm toán | Cấu trúc dữ liệu cũ / mới khác nhau theo bảng → đang lưu JSON trong cột NVARCHAR(MAX) |
| Phiên đăng nhập, bộ đếm sai mật khẩu, cache danh sách lớp | Đọc / ghi rất thường xuyên, không cần JOIN, dữ liệu tạm |
| Đồ thị khoá tiên quyết, gợi ý lộ trình | Phải dùng CTE đệ quy |

### 5.3.2 Bốn mô hình NoSQL áp dụng trên ECMS

| Mô hình | Cấu trúc | Ví dụ trên ECMS | Sản phẩm |
|---|---|---|---|
| **Key-value** | khoá → giá trị (không xem bên trong) | `session:<token>` → thông tin người đăng nhập (TTL 8 giờ); `login_fail:<user>` → số lần sai (TTL 15 phút); cache `lop_dang_mo:CN01` | Redis |
| **Document** | khoá → document JSON/BSON lồng nhau, lược đồ linh hoạt | Hồ sơ học viên nhúng kết quả kiểm tra, đăng ký, điểm danh; phiếu thu nhúng chi tiết | **MongoDB** (demo) |
| **Column-family** | dòng → nhiều họ cột, cột thưa, ghi rất nhanh, phân tán theo khoá phân vùng | Nhật ký điểm danh / truy cập theo `(MaLop, ngày)` khi mở rộng hàng trăm chi nhánh | Cassandra, HBase |
| **Graph** | đỉnh – cạnh có thuộc tính, duyệt quan hệ nhiều bước | `(:KhoaHoc)-[:TIEN_QUYET]->(:KhoaHoc)`, `(:HocVien)-[:DA_HOC {diem}]->(:KhoaHoc)` → gợi ý khoá tiếp theo, học viên cùng lộ trình | Neo4j |

### 5.3.3 Thiết kế document MongoDB

Nguyên tắc: **nhúng** khi dữ liệu con luôn đọc cùng cha và thuộc về một cha duy nhất; **tham chiếu** khi dữ liệu dùng chung hoặc tăng không giới hạn.

| Collection | Nhúng | Tham chiếu | Lý do |
|---|---|---|---|
| `khoa_hoc` | chương trình (tên) | `tien_quyet` → `khoa_hoc._id` | Danh mục nhỏ, dùng chung; tiên quyết là đồ thị |
| `lop_hoc` | lịch (thứ – ca – phòng), giáo viên tóm tắt | `khoa_hoc` | Lịch luôn đọc cùng lớp |
| `hoc_vien` | địa chỉ, `kiem_tra[]` (4 kỹ năng), `dang_ky[]` (học phí, điểm, `diem_danh[]`) | `dang_ky.lop`, `dang_ky.khoa_hoc` | Hồ sơ học viên đọc bằng **một truy vấn**; mỗi học viên vài lớp × ~30 buổi → document < 30 KB, xa giới hạn 16 MB |
| `phieu_thu` | `chi_tiet[]` (master–detail) | `hoc_vien`, `chi_tiet.ma_dk` | Phiếu thu bất biến sau khi lập |

```json
{ "_id": "HV0019", "ho_ten": { "ho": "Nguyễn Thành", "ten": "Khoa" }, "sdt": "0853337655", "chi_nhanh": "CN01",
  "kiem_tra": [ { "ngay": "2025-01-…", "diem_tong": 1.4, "de_xuat": "IEF",
                  "ky_nang": { "listening": { "diem": 1.2, "nhan_xet": "…" }, "speaking": { "diem": 1.0 }, … } } ],
  "dang_ky": [ { "ma_dk": 18, "lop": "IEF-2501", "khoa_hoc": "IEF",
                 "hoc_phi": { "goc": 5500000, "giam_gia": 0, "thanh_tien": 5500000, "da_thu": 5500000, "trang_thai": "Đã đóng" },
                 "diem": { "gk": 7.25, "ck": 7.6, "tb": 7.45 }, "ket_qua": "Đạt",
                 "diem_danh": [ { "buoi": 1, "ngay": "2025-02-10", "trang_thai": "Có mặt" }, … ] }, … ] }
```

### 5.3.4 Chuyển dữ liệu SQL Server → MongoDB

[`nosql/migrate.py`](../nosql/migrate.py) đọc SQL Server bằng pyodbc, tách XML kết quả kiểm tra thành document lồng, gom đăng ký + điểm danh theo học viên, ghi bằng pymongo và tạo chỉ mục (`sdt`, `dang_ky.lop`, `ngay_thu`, `chi_nhanh + trang_thai`). Kết quả đối chiếu số lượng:

| MongoDB | SQL Server | Số lượng |
|---|---|--:|
| `khoa_hoc` | KHOAHOC | 12 = 12 ✓ |
| `lop_hoc` | LOPHOC | 25 = 25 ✓ |
| `hoc_vien` | HOCVIEN | 349 = 349 ✓ |
| `phieu_thu` | PHIEUTHU | 502 = 502 ✓ |
| `hoc_vien.dang_ky[]` | DANGKY | 539 = 539 ✓ |
| `hoc_vien.dang_ky[].diem_danh[]` | DIEMDANH | 10 063 = 10 063 ✓ |
| `hoc_vien.kiem_tra[]` | KIEMTRA_DAUVAO | 357 = 357 ✓ |
| `phieu_thu.chi_tiet[]` | CT_PHIEUTHU | 510 = 510 ✓ |

22 bảng quan hệ thành **4 collection** (~1,1 MB BSON), chuyển trong 0,7 giây.

### 5.3.5 So sánh truy vấn tương đương

[`nosql/queries.js`](../nosql/queries.js) (mongosh) và [`nosql/compare.py`](../nosql/compare.py) chạy cùng câu hỏi trên hai hệ, kiểm tra kết quả giống nhau và đo trung bình 20 lần (SQL Server 2025 và MongoDB 7 cùng chạy Docker trên một máy, truy vấn qua driver Python):

| # | Câu hỏi | SQL Server | MongoDB | Dòng | SQL (ms) | Mongo (ms) | Kết quả |
|:-:|---|---|---|--:|--:|--:|:-:|
| 1 | Hồ sơ học viên kèm lớp, điểm, số buổi vắng | JOIN 3 bảng + truy vấn con | `find_one({_id})` – dữ liệu nhúng | 6 | 4,53 | 1,47 | ✓ |
| 2 | Doanh thu chi nhánh × tháng 2026 | JOIN + `GROUP BY` | `$match` + `$group` | 18 | 3,70 | 1,92 | ✓ |
| 3 | Bài kiểm tra có Speaking < 3 | XQuery `.exist()` trên cột XML | lọc trường lồng `kiem_tra.ky_nang.speaking.diem` | 160 | 18,77 | 2,93 | ✓ |
| 4 | Top 10 tỷ lệ vắng | JOIN + `GROUP BY` + `ORDER BY` | `$unwind` + `$filter` + `$sort` | 10 | 4,30 | 2,46 | ✓ |
| 5 | Chuỗi khoá tiên quyết | CTE đệ quy | `$graphLookup` | 4 | 1,58 | 1,49 | ✓ |
| 6 | Lớp đang mở còn chỗ + tên khoá | `JOIN` | `$lookup` | 8 | 1,31 | 1,48 | ✓ |

**Nhận xét.** MongoDB nhanh hơn rõ ở truy vấn đọc theo **đơn vị đã nhúng** (hồ sơ học viên, kết quả kiểm tra – nhanh hơn ~6 lần so với XQuery) vì không phải JOIN hay phân tích XML. Với truy vấn cần **kết nối nhiều tập** (#5, #6) hai bên tương đương, `$lookup` thậm chí chậm hơn JOIN. Cái giá của việc nhúng là cập nhật phức tạp hơn: sửa một ô điểm danh phải dùng `arrayFilters` trên mảng lồng 2 cấp (mục 7 của `queries.js`); thông tin lớp, khoá học bị lặp trong nhiều document và không có khoá ngoại / CHECK / trigger để giữ nhất quán (sĩ số, tổng phiếu thu phải do ứng dụng tự tính).

### 5.3.6 Giới thiệu và đánh giá các hệ NoSQL cho ECMS

| Hệ | Mô hình | Điểm mạnh | Hạn chế | Dùng cho ECMS |
|---|---|---|---|---|
| **MongoDB** | Document | Lược đồ linh hoạt, truy vấn và aggregation mạnh, chỉ mục phụ, transaction đa document (4.0+) | Không có ràng buộc liên collection, dữ liệu lặp khi nhúng | Kết quả kiểm tra đầu vào, hồ sơ học tập để đọc nhanh (bản sao chỉ đọc từ SQL Server) |
| **Redis** | Key-value (in-memory) | Độ trễ dưới mili giây, TTL tự xoá, cấu trúc list/set/sorted set | Dữ liệu chủ yếu trong RAM, truy vấn theo khoá | Phiên đăng nhập, đếm sai mật khẩu, cache danh mục và dashboard |
| **Cassandra** | Column-family | Ghi cực nhanh, mở rộng ngang, không có điểm lỗi đơn | Phải thiết kế bảng theo truy vấn, không JOIN, nhất quán cuối cùng | Chỉ cần khi chuỗi có hàng trăm chi nhánh, lưu nhật ký điểm danh / truy cập |
| **Neo4j** | Graph | Truy vấn đường đi nhiều bước (Cypher) rất nhanh | Không hợp cho thống kê tổng hợp | Lộ trình học, gợi ý khoá tiếp theo dựa trên học viên tương tự |

## 5.4 So sánh, đánh giá các mô hình cho bài toán ECMS

| Tiêu chí | Quan hệ (SQL Server) | Hướng đối tượng | Phân tán (theo chi nhánh) | NoSQL (MongoDB) |
|---|---|---|---|---|
| Mô hình hoá ECMS | Tốt, cần tách bảng cho đa trị / phức hợp | Tự nhiên nhất (kế thừa, kiểu phức) | Như quan hệ, thêm phân mảnh | Tự nhiên cho hồ sơ, kết quả test |
| Toàn vẹn & giao dịch | **Mạnh nhất**: PK/FK/CHECK/trigger, ACID | Trong phương thức | ACID cục bộ, 2PC liên trạm | Yếu: không FK, transaction có giới hạn |
| Truy vấn thống kê, báo cáo | **Mạnh nhất** | Yếu (N+1, ít hỗ trợ OQL) | Tốt nếu truy vấn cục bộ; toàn cục chậm hơn | Khá (aggregation), kém khi cần JOIN |
| Đọc một hồ sơ trọn vẹn | Cần nhiều JOIN | Duyệt đối tượng | Như quan hệ | **Nhanh nhất** (1 document) |
| Lược đồ thay đổi | ALTER TABLE | Sửa lớp | Sửa ở mọi trạm | **Linh hoạt nhất** |
| Mở rộng quy mô | Dọc (máy mạnh hơn) | Dọc | **Ngang theo chi nhánh** | **Ngang** (sharding) |
| Bảo mật, kiểm toán, sao lưu | **Đầy đủ** | Phụ thuộc sản phẩm | Phải làm ở mọi trạm | Có, kém chi tiết hơn |
| Số liệu demo | – | Tổng công nợ: 889 câu SQL, 1 873 ms (lazy) so với 1 câu, 40 ms | Truy vấn toàn cục khớp 100%, chỉ đọc 1 trạm khi lọc chi nhánh | Hồ sơ học viên 1,47 ms so với 4,53 ms; lọc kết quả test 2,93 ms so với 18,77 ms |

**Kết luận của nhóm.** Với quy mô hiện tại (3 chi nhánh, vài trăm học viên) và yêu cầu chính là *giao dịch đúng* (ghi danh, thu phí) + *báo cáo* (doanh thu, công nợ, chuyên cần), **CSDL quan hệ tập trung** là lựa chọn đúng cho ECMS và là phần nhóm đã cài đặt đầy đủ. Các mô hình khác bổ sung có chọn lọc:

1. **Hướng đối tượng** ở tầng ứng dụng (lớp nghiệp vụ / ORM có eager loading) – không thay CSDL.
2. **Phân tán** khi mở rộng nhiều tỉnh: phân mảnh ngang theo chi nhánh với thiết kế đã kiểm chứng ở 5.2.
3. **NoSQL** làm kho phụ: Redis cho phiên đăng nhập / cache; MongoDB làm bản sao chỉ đọc cho cổng thông tin học viên và lưu kết quả kiểm tra linh hoạt – kiến trúc *polyglot persistence*, SQL Server vẫn là nguồn dữ liệu gốc.
