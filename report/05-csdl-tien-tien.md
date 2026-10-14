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
