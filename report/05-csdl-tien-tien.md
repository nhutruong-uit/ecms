# Chương 5. Mô hình cơ sở dữ liệu tiên tiến

Mô hình quan hệ là lựa chọn trung tâm của đồ án, nhưng không phải là mô hình duy nhất. Chương này tìm hiểu ba mô hình CSDL tiên tiến của môn học – hướng đối tượng, phân tán và phi quan hệ (NoSQL) – theo cùng một cách tiếp cận: trình bày đặc điểm của mô hình, chuyển chính dữ liệu ECMS sang mô hình đó, chạy thử và đo đạc, rồi so sánh với mô hình quan hệ. Mục cuối tổng hợp đánh giá cả bốn mô hình cho bài toán của trung tâm. Các thử nghiệm trong chương được chạy trên CSDL ECMS tại thời điểm thử nghiệm, sau khi đã phát sinh thêm một số giao dịch, nên một vài con số (số phiếu thu, tổng công nợ) có thể chênh lệch nhỏ so với dữ liệu mẫu ban đầu ở Chương 2 và Chương 3; mỗi phép so sánh trong chương đều được thực hiện trên cùng một trạng thái dữ liệu.

## 5.1 Cơ sở dữ liệu hướng đối tượng

### 5.1.1 Đặc điểm của mô hình

CSDL hướng đối tượng (OODB) lưu trữ trực tiếp các **đối tượng** của ngôn ngữ lập trình thay vì các dòng trong bảng. Các khái niệm chính theo chuẩn ODMG 3.0 và cách chúng thể hiện trên bài toán ECMS như sau:

| Khái niệm | Ý nghĩa | Ví dụ trên ECMS |
|---|---|---|
| Đối tượng và định danh (OID) | Mỗi đối tượng có định danh do hệ thống cấp, không đổi suốt vòng đời và độc lập với giá trị thuộc tính | Học viên đổi số điện thoại hay đổi mã vẫn là cùng một đối tượng; quan hệ trỏ bằng OID, không cần khoá ngoại |
| Đóng gói | Dữ liệu và hành vi nằm chung trong lớp; bên ngoài chỉ thao tác qua phương thức | `LopHoc.siSoConLai()`, `HocVien.dangKy(lop)` thay cho các procedure rời |
| Kế thừa | Lớp con nhận thuộc tính và phương thức của lớp cha | `Nguoi` → `HocVien`; `Nguoi` → `NhanVien` → `GiaoVien` |
| Đa hình | Cùng một lời gọi, mỗi lớp có cách thực hiện riêng | `tinhLuong(thang)`: nhân viên nhận lương cơ bản; giáo viên nhận lương cơ bản cộng số buổi nhân đơn giá |
| Kiểu phức | Thuộc tính có thể là cấu trúc, tập hợp, danh sách | `diaChi : DiaChi`, `chungChis : set<ChungChi>`, `buoiHocs : list<BuoiHoc>` |
| Quan hệ và quan hệ ngược | Khai báo `relationship … inverse …`, hệ quản trị tự giữ hai chiều nhất quán | `LopHoc.giaoVien` và `GiaoVien.lopPhuTrach` |
| Ngôn ngữ | ODL định nghĩa lược đồ; OQL truy vấn với cú pháp gần SQL nhưng duyệt theo đường dẫn và gọi được phương thức | `select l.khoaHoc.tenKH from l in cacLopHoc` |
| Lưu bền | Đối tượng tồn tại sau khi chương trình kết thúc và được nạp lại khi truy cập | Nạp lười (lazy loading) trong mã minh hoạ |

### 5.1.2 Chuyển lược đồ quan hệ sang lược đồ hướng đối tượng

Nhóm chuyển toàn bộ lược đồ ECMS sang ngôn ngữ ODL, thu được 18 lớp, 1 interface `Nguoi`, 4 kiểu cấu trúc, 4 ngoại lệ nghiệp vụ và hơn 20 cặp quan hệ hai chiều. Các quy tắc chuyển đổi chính và hệ quả của chúng:

| Cấu trúc quan hệ | Cấu trúc hướng đối tượng | Hệ quả |
|---|---|---|
| Khoá ngoại 1 – N (LOPHOC.MaGV) | `relationship GiaoVien giaoVien inverse GiaoVien::lopPhuTrach` | Duyệt `lop.giaoVien.hoTen` thay cho phép kết nối |
| Bảng N – M có thuộc tính (DANGKY) | Lớp liên kết `DangKy` với hai relationship | Giữ nguyên như sơ đồ lớp ở mục 2.3 |
| Chuyên biệt hoá NHANVIEN – GIAOVIEN (hai bảng, khoá chính đồng thời là khoá ngoại) | `class GiaoVien extends NhanVien` | Một đối tượng duy nhất, không phải kết nối hai bảng |
| Thuộc tính đa trị CHUNGCHI_GV (bảng riêng) | `attribute set<ChungChi> chungChis` | Bỏ được một bảng |
| Thuộc tính phức hợp tách cột (SoNha, PhuongXa…) | `struct DiaChi` | Giữ được cấu trúc tự nhiên |
| Thực thể yếu BUOIHOC | `relationship list<BuoiHoc> buoiHocs` – danh sách có thứ tự | Không cần cột STT làm khoá |
| Cột suy diễn duy trì bằng trigger (SiSoHienTai, TongTien) | Phương thức `siSoHienTai()`, `tinhTong()` | Không thể lệch dữ liệu, nhưng phải tính lại mỗi lần gọi |
| Procedure nghiệp vụ (sp_DangKyHoc) | `DangKy dangKy(in LopHoc, in float) raises (LopDay, ThieuTienQuyet)` | Nghiệp vụ gắn liền với lớp |

Trích lược đồ ODL của hai lớp `GiaoVien` và `HocVien` cho thấy ba điểm khác biệt rõ nhất so với lược đồ quan hệ: kế thừa thay cho bảng con, tập hợp thay cho bảng đa trị và phương thức có khai báo ngoại lệ thay cho procedure.

```text title="Lược đồ ODL – Lớp GiaoVien và HocVien"
class GiaoVien extends NhanVien (extent cacGiaoVien) {     // chuyên biệt hoá → kế thừa
    attribute string        loaiGV;
    attribute string        trinhDo;
    attribute double        donGiaBuoi;
    attribute set<ChungChi> chungChis;                      // đa trị → tập hợp, không cần bảng riêng
    relationship Set<LopHoc> lopPhuTrach inverse LopHoc::giaoVien;
    double tinhLuong(in string thang);                      // ghi đè cách tính lương của NhanVien
};

class HocVien : Nguoi (extent cacHocVien key maHV) {
    attribute string  maHV;
    attribute string  email;
    attribute DiaChi  diaChi;                               // phức hợp → struct
    attribute string  hoTenPhuHuynh;
    relationship ChiNhanh             chiNhanh   inverse ChiNhanh::hocViens;
    relationship Set<DangKy>          dangKys    inverse DangKy::hocVien;
    relationship Set<KiemTraDauVao>   kiemTras   inverse KiemTraDauVao::hocVien;
    relationship Set<PhieuThu>        phieuThus  inverse PhieuThu::hocVien;
    DangKy dangKy(in LopHoc lop, in float giamGia) raises (LopDay, ThieuTienQuyet);
    double congNo();
    list<BuoiHoc> lichHoc(in date tuan);
};
```

### 5.1.3 Thử nghiệm bằng Python

Vì các hệ quản trị OODB thuần tuý hiện ít được sử dụng, nhóm hiện thực một phần lược đồ ODL bằng các lớp Python ánh xạ từ bảng của ECMS – một dạng ORM tối giản không dùng thư viện ngoài – để quan sát hành vi của mô hình hướng đối tượng trên dữ liệu thật:

- Lớp `Session` giữ một **identity map**: cùng một khoá luôn trả về **cùng một đối tượng** trong bộ nhớ, mô phỏng định danh OID; đồng thời đếm số câu SQL đã gửi xuống CSDL.
- Các relationship được **nạp lười** khi truy cập lần đầu, ví dụ `lop.giao_vien`, `hoc_vien.dang_kys`.
- `GiaoVien` kế thừa `NhanVien`, `NhanVien` kế thừa `Nguoi` bằng cơ chế kế thừa thật của Python; phương thức `tinh_luong()` được ghi đè ở lớp con để thể hiện tính đa hình.

```python title="Mã lệnh – Đa hình và duyệt đối tượng thay cho truy vấn"
class NhanVien(Nguoi):
    def tinh_luong(self, thang: str) -> float:
        return self.luong_co_ban

class GiaoVien(NhanVien):
    def tinh_luong(self, thang: str) -> float:        # đa hình: ghi đè cách tính của NhanVien
        so_buoi = self._s.rows("""SELECT COUNT(*) AS n FROM BUOIHOC b JOIN LOPHOC l ON l.MaLop = b.MaLop
                                  WHERE l.MaGV = ? AND b.TrangThai = N'Đã dạy' AND FORMAT(b.NgayHoc, 'yyyy-MM') = ?""",
                               self.ma_nv, thang)[0]["n"]
        return self.luong_co_ban + so_buoi * self.don_gia_buoi

class KhoaHoc:
    def lo_trinh(self) -> list:
        """Chuỗi khoá cần học trước – duyệt đối tượng thay cho CTE đệ quy (Q26)."""
        return (self.tien_quyet.lo_trinh() if self.tien_quyet else []) + [self]
```

Kết quả chạy cho thấy đa hình và identity map hoạt động đúng: cùng lời gọi `tinh_luong`, nhân viên văn phòng nhận đúng lương cơ bản, còn giáo viên nhận lương cơ bản cộng tiền dạy; đối tượng giáo viên lấy qua quan hệ của lớp học chính là đối tượng lấy trực tiếp theo khoá.

```text title="Kết quả – Đa hình và identity map"
NhanVien  Dương Mai Yến     27,000,000     ← lương cơ bản
GiaoVien  Lê Thanh Yến      11,100,000     ← 7.500.000 + 8 buổi × 450.000
lop.giao_vien is s.get(NhanVien, 'NV0015') → True ; isinstance(gv, GiaoVien) → True
```

**So sánh với SQL.** Nhóm giải cùng ba bài toán bằng cách duyệt đối tượng và bằng một câu SQL, so sánh kết quả, thời gian và số câu SQL thực tế gửi xuống CSDL:

| Bài toán | Cách làm | Kết quả | Thời gian | Số câu SQL |
|---|---|---|--:|--:|
| Lộ trình tiên quyết tới IELTS 6.5+ | Hướng đối tượng: `KhoaHoc('IE65').lo_trinh()` | IEF → IE55 → IE65 | 16,5 ms | 3 |
| | SQL: CTE đệ quy (Q26) | IEF → IE55 → IE65 | 8,1 ms | 1 |
| Số chỗ trống của các lớp đang học | Hướng đối tượng: `l.si_so_con_lai()` cho từng lớp | Giống nhau | 39,5 ms | 6 |
| | SQL: `SiSoToiDa − SiSoHienTai` | Giống nhau | 5,4 ms | 1 |
| Tổng công nợ toàn trung tâm | Hướng đối tượng: cộng `h.cong_no()` của mọi học viên | 271.743.000 đồng | 1.873,5 ms | **889** |
| | SQL: `SUM` trên `vw_CongNoHocVien` | 271.743.000 đồng | 40,1 ms | 1 |

**Nhận xét.** Cả hai cách cho cùng kết quả. Cách hướng đối tượng viết tự nhiên hơn – đọc như mô tả nghiệp vụ, không cần nhớ điều kiện kết nối – nhưng khi nạp lười thì gặp **vấn đề N+1 truy vấn**: tính tổng công nợ cần tới 889 câu SQL (một câu lấy danh sách học viên, mỗi học viên một câu lấy đăng ký, mỗi đăng ký một câu lấy số tiền đã thu) và chậm gấp khoảng 47 lần so với một câu `SUM` để hệ quản trị quan hệ tối ưu theo tập hợp. Các ORM thực tế như SQLAlchemy, Entity Framework giảm vấn đề này bằng nạp trước (eager loading), nhưng truy vấn thống kê trên toàn bộ dữ liệu vẫn là thế mạnh của SQL.

### 5.1.4 So sánh mô hình quan hệ và hướng đối tượng cho ECMS

| Tiêu chí | Mô hình quan hệ (ECMS hiện tại) | Mô hình hướng đối tượng |
|---|---|---|
| Đơn vị dữ liệu | Dòng trong bảng, định danh bằng khoá | Đối tượng, định danh bằng OID |
| Quan hệ | Khoá ngoại và phép kết nối lúc truy vấn | Tham chiếu trực tiếp, duyệt theo đường dẫn |
| Kế thừa (nhân viên và giáo viên) | Mô phỏng bằng hai bảng, khoá chính đồng thời là khoá ngoại | Hỗ trợ trực tiếp, có đa hình |
| Kiểu phức (địa chỉ, chứng chỉ, kết quả kiểm tra) | Tách cột, tách bảng hoặc dùng XML | Cấu trúc, tập hợp, danh sách một cách tự nhiên |
| Hành vi | Procedure, function, trigger tách rời dữ liệu | Phương thức đóng gói trong lớp |
| Truy vấn tự do, thống kê, báo cáo | Rất mạnh nhờ SQL, bộ tối ưu, chỉ mục, indexed view | Yếu hơn; OQL ít được hỗ trợ đầy đủ |
| Ràng buộc toàn vẹn khai báo | CHECK, khoá ngoại, UNIQUE, giao dịch ACID trưởng thành | Phần lớn phải viết trong phương thức |
| Phân quyền, kiểm toán, sao lưu | Đầy đủ và chuẩn hoá (Chương 3) | Phụ thuộc từng sản phẩm |
| Lệch trở kháng với ứng dụng | Có – phải ánh xạ giữa dòng và đối tượng | Không |
| Công cụ, nhân lực, cộng đồng | Phổ biến (SQL Server, SSMS, Power BI…) | Ít (db4o, ObjectDB, Versant…), nhiều sản phẩm đã ngừng phát triển |
| Phù hợp nhất với | Nghiệp vụ giao dịch kết hợp báo cáo, như trung tâm ngoại ngữ | Dữ liệu có cấu trúc phức tạp, ít truy vấn thống kê (CAD, đa phương tiện, mô phỏng) |

**Đánh giá cho ECMS.** Nếu dùng OODB, ECMS mô hình hoá tự nhiên hơn quan hệ kế thừa giữa nhân viên và giáo viên, chứng chỉ đa trị và kết quả kiểm tra có cấu trúc lồng; mã ứng dụng cũng ngắn hơn vì không cần ánh xạ. Tuy nhiên phần lớn giá trị của ECMS nằm ở **báo cáo, thống kê** (doanh thu theo chi nhánh và tháng, công nợ, chuyên cần) và **ràng buộc giao dịch** (không vượt sĩ số, không thu vượt) – đúng thế mạnh của mô hình quan hệ; đội ngũ và công cụ của trung tâm cũng quen với SQL Server. Nhóm kết luận nên giữ **CSDL quan hệ làm lõi**, áp dụng tư tưởng hướng đối tượng ở **tầng ứng dụng** (lớp nghiệp vụ, ORM có nạp trước) và tận dụng các tính năng đối tượng – quan hệ sẵn có của SQL Server như kiểu XML có lược đồ, cột tính toán và hàm trả về bảng cho phần dữ liệu phức.

## 5.2 Cơ sở dữ liệu phân tán

### 5.2.1 Đặc điểm và sự phù hợp với chuỗi trung tâm

CSDL phân tán là tập hợp nhiều CSDL có liên quan logic, đặt tại nhiều trạm nối mạng, được quản lý sao cho người dùng thấy như **một CSDL duy nhất** – gọi là tính trong suốt phân tán. Dữ liệu được *phân mảnh* và *cấp phát* về nơi sử dụng nhiều nhất, có thể được *nhân bản*, và truy vấn, giao tác có thể trải trên nhiều trạm. Mô hình chuỗi ba chi nhánh của ECMS là một bối cảnh tự nhiên để xem xét phân tán:

| Tiêu chí | Tập trung (ECMS hiện tại) | Phân tán theo chi nhánh |
|---|---|---|
| Vị trí dữ liệu | Một máy chủ | Mỗi chi nhánh giữ dữ liệu của mình |
| Tốc độ truy cập tại chi nhánh | Phụ thuộc đường truyền tới trung tâm | Nhanh – đa số nghiệp vụ (điểm danh, ghi danh, thu phí) chỉ dùng dữ liệu tại chỗ |
| Khi mất kết nối hoặc trung tâm gặp sự cố | Mọi chi nhánh ngừng hoạt động | Chi nhánh vẫn hoạt động với dữ liệu cục bộ |
| Báo cáo toàn hệ thống | Đơn giản | Phải gom dữ liệu từ nhiều trạm |
| Toàn vẹn liên trạm (học viên học ở hai chi nhánh, chuyển lớp liên chi nhánh) | Một giao dịch cục bộ | Giao tác phân tán, cam kết hai pha |
| Bảo mật | Một điểm quản lý | Dữ liệu nhạy cảm như lương có thể chỉ đặt ở trung tâm |
| Chi phí vận hành | Thấp | Cao hơn: nhiều máy chủ, đồng bộ, sao lưu từng trạm |

Với ba chi nhánh, mỗi nơi khoảng một trăm học viên, mô hình tập trung vẫn đủ đáp ứng. Mô hình phân tán trở nên cần thiết khi chuỗi mở rộng ra nhiều tỉnh hoặc kết nối mạng không ổn định. Phần thử nghiệm dưới đây cho thấy cách thiết kế khi cần mở rộng.

### 5.2.2 Thiết kế phân mảnh và cấp phát

Nhóm áp dụng đủ các kiểu phân mảnh của môn học, mỗi kiểu xuất phát từ một nhu cầu nghiệp vụ cụ thể:

| Quan hệ | Kiểu phân mảnh | Định nghĩa | Lý do |
|---|---|---|---|
| HOCVIEN | Ngang chính | HOCVIEN<sub>i</sub> = σ<sub>MaCN = 'CN0i'</sub>(HOCVIEN) | Học viên do chi nhánh lập hồ sơ quản lý |
| LOPHOC | Ngang chính | LOPHOC<sub>i</sub> = σ<sub>MaCN = 'CN0i'</sub>(LOPHOC) | Lớp mở tại một chi nhánh |
| DANGKY | Ngang dẫn xuất | DANGKY<sub>i</sub> = DANGKY ⋉ LOPHOC<sub>i</sub> | Đăng ký đi theo lớp: điểm danh, nhập điểm, thu phí của một lớp nằm cùng một trạm |
| DIEMDANH | Ngang dẫn xuất | DIEMDANH<sub>i</sub> = DIEMDANH ⋉ DANGKY<sub>i</sub> | Như trên |
| NHANVIEN | Dọc | NV_CHUNG = π<sub>MaNV, HoNV, TenNV, ChucVu, SĐT, Email, MaCN</sub>(NHANVIEN); NV_LUONG = π<sub>MaNV, LuongCoBan</sub>(NHANVIEN) | Lương là dữ liệu nhạy cảm, chỉ trung tâm cần |
| NV_CHUNG | Hỗn hợp (dọc rồi ngang) | NV_CHUNG<sub>i</sub> = σ<sub>MaCN = 'CN0i'</sub>(NV_CHUNG) | Danh bạ nhân viên tại từng chi nhánh |
| CHUONGTRINH, KHOAHOC, CAHOC | Nhân bản toàn phần | Mỗi trạm có một bản sao | Ít thay đổi, mọi nghiệp vụ đều cần đọc |

Các mảnh được cấp phát về bốn trạm như sau:

| Trạm | CSDL thử nghiệm | Các mảnh được cấp phát |
|---|---|---|
| Chi nhánh Thủ Đức | `ECMS_CN01` | HOCVIEN<sub>1</sub>, LOPHOC<sub>1</sub>, DANGKY<sub>1</sub>, DIEMDANH<sub>1</sub>, NV_CHUNG<sub>1</sub>, bản sao danh mục |
| Chi nhánh Quận 1 | `ECMS_CN02` | HOCVIEN<sub>2</sub>, LOPHOC<sub>2</sub>, DANGKY<sub>2</sub>, DIEMDANH<sub>2</sub>, NV_CHUNG<sub>2</sub>, bản sao danh mục |
| Chi nhánh Bình Thạnh | `ECMS_CN03` | HOCVIEN<sub>3</sub>, LOPHOC<sub>3</sub>, DANGKY<sub>3</sub>, DIEMDANH<sub>3</sub>, NV_CHUNG<sub>3</sub>, bản sao danh mục |
| Trung tâm | `ECMS_TOANCUC` | NV_LUONG và lược đồ toàn cục |

### 5.2.3 Cài đặt thử nghiệm

Ba trạm chi nhánh được mô phỏng bằng ba CSDL trên cùng một máy chủ SQL Server; trong thực tế đây sẽ là ba máy chủ nối với nhau bằng linked server (script có sẵn mẫu cấu hình). Mỗi mảnh ngang có ràng buộc `CHECK (MaCN = 'CN0i')` trên cột phân mảnh và khoá chính có chứa `MaCN`. Trạm trung tâm định nghĩa các view **trùng tên với bảng gốc** để người dùng truy vấn như trên CSDL tập trung – đó chính là tính trong suốt vị trí:

```sql title="Mã lệnh – Lược đồ toàn cục tại trạm trung tâm"
CREATE VIEW dbo.HOCVIEN AS                        -- trong suốt vị trí: hợp các mảnh ngang
    SELECT * FROM ECMS_CN01.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN02.dbo.HOCVIEN UNION ALL
    SELECT * FROM ECMS_CN03.dbo.HOCVIEN;

CREATE VIEW dbo.NHANVIEN AS                       -- tái thiết mảnh dọc bằng phép kết
    SELECT c.*, l.LuongCoBan FROM (… hợp các NHANVIEN_CHUNG_i …) c JOIN dbo.NHANVIEN_LUONG l ON l.MaNV = c.MaNV;
```

Sau khi phân mảnh, số dòng ở mỗi trạm chi nhánh như sau:

| Trạm | Học viên | Lớp | Đăng ký | Điểm danh |
|---|--:|--:|--:|--:|
| CN01 | 133 | 9 | 195 | 3.280 |
| CN02 | 119 | 8 | 181 | 3.597 |
| CN03 | 97 | 8 | 163 | 3.186 |

**Kiểm tra tính đúng đắn của phân mảnh.** Một thiết kế phân mảnh đúng phải thoả ba điều kiện. Nhóm kiểm tra từng điều kiện bằng truy vấn so sánh với CSDL gốc:

| Điều kiện | Cách kiểm tra | Kết quả |
|---|---|---|
| Đầy đủ – mọi dòng của quan hệ gốc nằm trong ít nhất một mảnh | So sánh số dòng và dùng `EXCEPT` giữa bảng gốc với hợp các mảnh | HOCVIEN 349 = 349, LOPHOC 25 = 25, DANGKY 539 = 539, DIEMDANH 10.063 = 10.063, NHANVIEN 20 = 20 – thoả |
| Rời nhau – không dòng nào thuộc hai mảnh ngang | `INTERSECT` từng cặp trạm trên HOCVIEN và DANGKY | Không có dòng trùng – thoả |
| Tái thiết – ghép lại được quan hệ gốc | Mảnh ngang ghép bằng `UNION ALL`; mảnh dọc ghép bằng kết theo MaNV; so sánh với bảng gốc bằng `EXCEPT` | Không có dòng khác – thoả |

**Truy vấn toàn cục.** Ba truy vấn được viết trên lược đồ toàn cục như thể CSDL là tập trung, rồi so sánh với kết quả trên CSDL gốc:

| Truy vấn | Kết quả trên CSDL phân tán | Đối chiếu với CSDL tập trung |
|---|---|---|
| G1 – số đăng ký, số đạt, tổng phải thu theo 12 khoá học | 12 dòng | Không có dòng khác (so sánh `EXCEPT` hai chiều) |
| G2 – học viên học ở chi nhánh khác nơi lập hồ sơ (kết mảnh HOCVIEN của trạm A với DANGKY của trạm B) | 136 | 136 |
| G3 – quỹ lương theo chi nhánh | CN01 89 triệu, CN02 69,5 triệu, CN03 72 triệu đồng | Chỉ trả lời được tại trạm trung tâm |

**Loại bỏ mảnh.** Câu `SELECT COUNT(*) FROM dbo.HOCVIEN WHERE MaCN = 'CN02'` trên view toàn cục chỉ đọc bảng của trạm CN02 (thống kê I/O cho thấy chỉ một bảng được đọc với 4 trang). Nhờ các ràng buộc CHECK trên cột phân mảnh, bộ tối ưu biết trạm CN01 và CN03 không thể chứa dòng thoả điều kiện nên không gửi truy vấn tới đó. Đây là cơ chế giúp truy vấn cục bộ trên CSDL phân tán vẫn nhanh.

### 5.2.4 Giao tác phân tán và điều khiển đồng thời

- **Chuyển lớp liên chi nhánh** – đăng ký cũ ở CN02, đăng ký mới ở CN01 – phải cập nhật hai trạm như một đơn vị. SQL Server thực hiện bằng `BEGIN DISTRIBUTED TRANSACTION` thông qua dịch vụ MSDTC theo **giao thức cam kết hai pha (2PC)**. Ở *pha chuẩn bị*, bộ điều phối hỏi mọi trạm đã sẵn sàng ghi chưa; các trạm ghi nhật ký và khoá dữ liệu rồi trả lời. Ở *pha cam kết*, nếu mọi trạm đồng ý thì bộ điều phối gửi lệnh xác nhận; chỉ cần một trạm từ chối là toàn bộ giao tác bị huỷ.
- **Điểm yếu của 2PC** là các trạm phải giữ khoá trong suốt thời gian chờ, và nếu bộ điều phối gặp sự cố giữa hai pha thì các trạm bị treo. Vì vậy thiết kế phân mảnh dẫn xuất ở mục 5.2.2 được chọn để **phần lớn giao tác chỉ chạm một trạm**: ghi danh, điểm danh, thu phí của một lớp đều là giao tác cục bộ.
- **Điều khiển đồng thời**: mỗi trạm dùng khoá cục bộ như cơ chế `UPDLOCK` trong `sp_DangKyHoc`; giao tác toàn cục phải khoá ở mọi trạm tham gia theo một thứ tự cố định để tránh bế tắc phân tán, còn truy vấn báo cáo toàn cục nên dùng mức cô lập snapshot để không khoá dữ liệu của chi nhánh.
- **Nhân bản danh mục**: thay đổi về khoá học, học phí được thực hiện tại trung tâm và lan truyền tới các chi nhánh bằng cơ chế nhân bản (replication) của SQL Server; độ trễ vài giây là chấp nhận được vì danh mục ít thay đổi.

## 5.3 Cơ sở dữ liệu phi quan hệ (NoSQL)

### 5.3.1 Hạn chế của mô hình quan hệ với một phần dữ liệu ECMS

Trong quá trình làm đồ án, nhóm nhận thấy một số loại dữ liệu của ECMS không thật sự "vừa" với mô hình quan hệ:

| Dữ liệu | Khó khăn trên mô hình quan hệ |
|---|---|
| Kết quả kiểm tra đầu vào (bốn kỹ năng, nhận xét, có thể thêm kỹ năng hoặc điểm thành phần) | Cấu trúc thay đổi theo đề thi nên phải dùng cột XML, XML Schema và XQuery (mục 3.1.3); truy vấn dài dòng |
| Hồ sơ học tập (đăng ký, điểm, điểm danh từng buổi) | Đọc một hồ sơ phải kết nối 4 – 5 bảng; bảng điểm danh tăng nhanh nhất, khoảng 10.000 dòng chỉ với 25 lớp |
| Nhật ký kiểm toán | Cấu trúc dữ liệu cũ và mới khác nhau theo từng bảng, hiện đang lưu JSON trong cột chuỗi |
| Phiên đăng nhập, bộ đếm sai mật khẩu, bộ nhớ đệm danh sách lớp | Đọc ghi rất thường xuyên, không cần kết nối, dữ liệu chỉ có tính tạm thời |
| Đồ thị khoá tiên quyết, gợi ý lộ trình | Phải dùng CTE đệ quy |

### 5.3.2 Bốn mô hình NoSQL áp dụng trên ECMS

Mỗi loại dữ liệu ở trên phù hợp với một mô hình NoSQL khác nhau:

| Mô hình | Cấu trúc | Ví dụ áp dụng trên ECMS | Sản phẩm tiêu biểu |
|---|---|---|---|
| Key-value | Khoá ánh xạ tới một giá trị, hệ thống không đọc bên trong giá trị | `session:<token>` lưu thông tin người đăng nhập, tự hết hạn sau 8 giờ; `login_fail:<user>` đếm số lần sai, hết hạn sau 15 phút; bộ nhớ đệm `lop_dang_mo:CN01` | Redis |
| Document | Khoá ánh xạ tới một tài liệu JSON/BSON lồng nhau, lược đồ linh hoạt | Hồ sơ học viên nhúng kết quả kiểm tra, đăng ký, điểm danh; phiếu thu nhúng chi tiết | MongoDB (thử nghiệm) |
| Column-family | Mỗi dòng có nhiều họ cột, cột thưa, ghi rất nhanh, phân tán theo khoá phân vùng | Nhật ký điểm danh, nhật ký truy cập theo (lớp, ngày) khi mở rộng tới hàng trăm chi nhánh | Cassandra, HBase |
| Graph | Đỉnh và cạnh đều có thuộc tính, duyệt quan hệ nhiều bước | Khoá học nối với khoá học bằng cạnh TIEN_QUYET, học viên nối với khoá học bằng cạnh DA_HOC kèm điểm; dùng để gợi ý khoá tiếp theo và tìm học viên cùng lộ trình | Neo4j |

### 5.3.3 Thiết kế tài liệu MongoDB

Nhóm chọn MongoDB để thử nghiệm vì đây là mô hình có nhiều ứng dụng nhất cho ECMS. Nguyên tắc thiết kế: **nhúng** khi dữ liệu con luôn được đọc cùng dữ liệu cha và chỉ thuộc về một cha duy nhất; **tham chiếu** khi dữ liệu được dùng chung hoặc có thể tăng không giới hạn.

| Collection | Dữ liệu nhúng | Dữ liệu tham chiếu | Lý do |
|---|---|---|---|
| `khoa_hoc` | Tên chương trình | `tien_quyet` trỏ tới `khoa_hoc._id` | Danh mục nhỏ, dùng chung; quan hệ tiên quyết có dạng đồ thị |
| `lop_hoc` | Lịch học (thứ, ca, phòng), tóm tắt giáo viên | `khoa_hoc` | Lịch luôn được đọc cùng lớp |
| `hoc_vien` | Địa chỉ, mảng `kiem_tra` (bốn kỹ năng), mảng `dang_ky` (học phí, điểm, mảng `diem_danh`) | `dang_ky.lop`, `dang_ky.khoa_hoc` | Hồ sơ học viên đọc được bằng **một truy vấn**; mỗi học viên vài lớp, mỗi lớp khoảng 30 buổi nên tài liệu dưới 30 KB, rất xa giới hạn 16 MB |
| `phieu_thu` | Mảng `chi_tiet` (cặp master – detail) | `hoc_vien`, `chi_tiet.ma_dk` | Phiếu thu không thay đổi sau khi lập |

Cấu trúc một tài liệu học viên (đã lược bớt):

```json title="Tài liệu MongoDB – Hồ sơ học viên"
{ "_id": "HV0019", "ho_ten": { "ho": "Nguyễn Thành", "ten": "Khoa" }, "sdt": "0853337655", "chi_nhanh": "CN01",
  "kiem_tra": [ { "ngay": "2025-01-…", "diem_tong": 1.4, "de_xuat": "IEF",
                  "ky_nang": { "listening": { "diem": 1.2, "nhan_xet": "…" }, "speaking": { "diem": 1.0 }, … } } ],
  "dang_ky": [ { "ma_dk": 18, "lop": "IEF-2501", "khoa_hoc": "IEF",
                 "hoc_phi": { "goc": 5500000, "giam_gia": 0, "thanh_tien": 5500000, "da_thu": 5500000, "trang_thai": "Đã đóng" },
                 "diem": { "gk": 7.25, "ck": 7.6, "tb": 7.45 }, "ket_qua": "Đạt",
                 "diem_danh": [ { "buoi": 1, "ngay": "2025-02-10", "trang_thai": "Có mặt" }, … ] }, … ] }
```

### 5.3.4 Chuyển dữ liệu từ SQL Server sang MongoDB

Chương trình chuyển đổi đọc dữ liệu từ SQL Server bằng pyodbc, tách XML kết quả kiểm tra thành tài liệu lồng, gom đăng ký và điểm danh theo học viên, ghi vào MongoDB bằng pymongo và tạo chỉ mục trên các trường thường tìm kiếm (số điện thoại, lớp đăng ký, ngày thu, chi nhánh kèm trạng thái). Kết quả đối chiếu số lượng giữa hai hệ:

| MongoDB | SQL Server | Số lượng |
|---|---|--:|
| `khoa_hoc` | KHOAHOC | 12 = 12 |
| `lop_hoc` | LOPHOC | 25 = 25 |
| `hoc_vien` | HOCVIEN | 349 = 349 |
| `phieu_thu` | PHIEUTHU | 502 = 502 |
| `hoc_vien.dang_ky[]` | DANGKY | 539 = 539 |
| `hoc_vien.dang_ky[].diem_danh[]` | DIEMDANH | 10.063 = 10.063 |
| `hoc_vien.kiem_tra[]` | KIEMTRA_DAUVAO | 357 = 357 |
| `phieu_thu.chi_tiet[]` | CT_PHIEUTHU | 510 = 510 |

Toàn bộ 22 bảng quan hệ được thu gọn thành **4 collection** với dung lượng khoảng 1,1 MB, quá trình chuyển mất 0,7 giây. Số lượng ở mọi cấp đều khớp, chứng tỏ không mất dữ liệu khi chuyển.

### 5.3.5 So sánh truy vấn tương đương

Nhóm viết sáu cặp truy vấn trả lời cùng một câu hỏi trên hai hệ, kiểm tra kết quả giống nhau và đo thời gian trung bình của 20 lần chạy. Cả SQL Server 2025 và MongoDB 7 cùng chạy trong Docker trên một máy, truy vấn qua trình điều khiển Python.

| Câu | Câu hỏi | Cách viết trên SQL Server | Cách viết trên MongoDB | Số dòng | SQL (ms) | MongoDB (ms) | Kết quả khớp |
|:-:|---|---|---|--:|--:|--:|:-:|
| 1 | Hồ sơ học viên kèm lớp, điểm, số buổi vắng | Kết nối 3 bảng và truy vấn con | `find_one` theo `_id` trên dữ liệu nhúng | 6 | 4,53 | 1,47 | Có |
| 2 | Doanh thu chi nhánh theo tháng năm 2026 | Kết nối và `GROUP BY` | `$match` và `$group` | 18 | 3,70 | 1,92 | Có |
| 3 | Bài kiểm tra có điểm Speaking dưới 3 | XQuery `.exist()` trên cột XML | Lọc theo trường lồng `kiem_tra.ky_nang.speaking.diem` | 160 | 18,77 | 2,93 | Có |
| 4 | Mười học viên có tỷ lệ vắng cao nhất | Kết nối, `GROUP BY`, `ORDER BY` | `$unwind`, `$filter`, `$sort` | 10 | 4,30 | 2,46 | Có |
| 5 | Chuỗi khoá tiên quyết | CTE đệ quy | `$graphLookup` | 4 | 1,58 | 1,49 | Có |
| 6 | Lớp đang mở còn chỗ kèm tên khoá | Kết nối | `$lookup` | 8 | 1,31 | 1,48 | Có |

**Nhận xét.** MongoDB nhanh hơn rõ rệt ở các truy vấn đọc theo **đơn vị đã nhúng** như hồ sơ học viên và kết quả kiểm tra – câu 3 nhanh hơn khoảng 6 lần so với XQuery – vì không phải kết nối bảng hay phân tích XML. Với truy vấn cần **kết nối nhiều tập dữ liệu** (câu 5, câu 6), hai hệ tương đương nhau và `$lookup` thậm chí chậm hơn phép kết nối của SQL. Cái giá của việc nhúng là cập nhật phức tạp hơn: sửa một ô điểm danh phải dùng `arrayFilters` trên mảng lồng hai cấp; thông tin lớp, khoá học bị lặp lại trong nhiều tài liệu; và không có khoá ngoại, CHECK hay trigger để giữ nhất quán – sĩ số, tổng tiền phiếu thu phải do ứng dụng tự tính.

### 5.3.6 Đánh giá các hệ NoSQL cho ECMS

| Hệ | Mô hình | Điểm mạnh | Hạn chế | Vai trò phù hợp trong ECMS |
|---|---|---|---|---|
| MongoDB | Document | Lược đồ linh hoạt, truy vấn và aggregation mạnh, có chỉ mục phụ, hỗ trợ giao dịch nhiều tài liệu | Không có ràng buộc giữa các collection, dữ liệu lặp khi nhúng | Lưu kết quả kiểm tra đầu vào; bản sao chỉ đọc của hồ sơ học tập để tra cứu nhanh |
| Redis | Key-value trên bộ nhớ | Độ trễ dưới một mili giây, tự xoá theo thời hạn, có cấu trúc danh sách và tập hợp | Dữ liệu chủ yếu nằm trên RAM, chỉ truy vấn theo khoá | Phiên đăng nhập, đếm sai mật khẩu, bộ nhớ đệm danh mục và dashboard |
| Cassandra | Column-family | Ghi cực nhanh, mở rộng theo chiều ngang, không có điểm lỗi đơn | Phải thiết kế bảng theo truy vấn, không có kết nối, nhất quán cuối cùng | Chỉ cần khi chuỗi có hàng trăm chi nhánh, dùng lưu nhật ký điểm danh và truy cập |
| Neo4j | Graph | Truy vấn đường đi nhiều bước rất nhanh | Không phù hợp cho thống kê tổng hợp | Lộ trình học, gợi ý khoá tiếp theo dựa trên học viên tương tự |

## 5.4 So sánh, đánh giá các mô hình cho bài toán ECMS

Bảng dưới đây tổng hợp đánh giá cả bốn mô hình đã tìm hiểu, kèm số liệu đo được trong các thử nghiệm của chương:

| Tiêu chí | Quan hệ (SQL Server) | Hướng đối tượng | Phân tán theo chi nhánh | NoSQL (MongoDB) |
|---|---|---|---|---|
| Mô hình hoá bài toán | Tốt, cần tách bảng cho thuộc tính đa trị và phức hợp | Tự nhiên nhất nhờ kế thừa và kiểu phức | Như mô hình quan hệ, thêm phân mảnh | Tự nhiên cho hồ sơ học viên và kết quả kiểm tra |
| Toàn vẹn và giao dịch | Mạnh nhất: khoá chính, khoá ngoại, CHECK, trigger, ACID | Phải viết trong phương thức | ACID cục bộ, cam kết hai pha giữa các trạm | Yếu: không có khoá ngoại, giao dịch có giới hạn |
| Truy vấn thống kê, báo cáo | Mạnh nhất | Yếu (vấn đề N+1, ít hỗ trợ OQL) | Tốt với truy vấn cục bộ, truy vấn toàn cục chậm hơn | Khá (aggregation), kém khi cần kết nối |
| Đọc trọn một hồ sơ | Cần nhiều phép kết nối | Duyệt đối tượng | Như mô hình quan hệ | Nhanh nhất – một tài liệu |
| Thay đổi lược đồ | ALTER TABLE | Sửa lớp | Phải sửa ở mọi trạm | Linh hoạt nhất |
| Mở rộng quy mô | Theo chiều dọc (máy mạnh hơn) | Theo chiều dọc | Theo chiều ngang, theo chi nhánh | Theo chiều ngang (sharding) |
| Bảo mật, kiểm toán, sao lưu | Đầy đủ | Phụ thuộc sản phẩm | Phải thực hiện ở mọi trạm | Có, nhưng kém chi tiết hơn |
| Số liệu thử nghiệm | – | Tổng công nợ: 889 câu SQL, 1.873 ms khi nạp lười, so với 1 câu, 40 ms | Truy vấn toàn cục khớp hoàn toàn; lọc theo chi nhánh chỉ đọc một trạm | Hồ sơ học viên 1,47 ms so với 4,53 ms; lọc kết quả kiểm tra 2,93 ms so với 18,77 ms |

**Kết luận.** Với quy mô hiện tại – ba chi nhánh, vài trăm học viên – và yêu cầu chính là *giao dịch đúng* (ghi danh, thu phí) cùng *báo cáo* (doanh thu, công nợ, chuyên cần), **CSDL quan hệ tập trung** là lựa chọn phù hợp cho ECMS và cũng là phần nhóm đã cài đặt đầy đủ. Các mô hình khác được bổ sung có chọn lọc khi có nhu cầu:

1. **Hướng đối tượng** ở tầng ứng dụng – lớp nghiệp vụ, ORM có nạp trước – không thay thế CSDL.
2. **Phân tán** khi chuỗi mở rộng ra nhiều tỉnh: phân mảnh ngang theo chi nhánh với thiết kế đã được kiểm chứng ở mục 5.2.
3. **NoSQL** làm kho phụ trợ: Redis cho phiên đăng nhập và bộ nhớ đệm; MongoDB làm bản sao chỉ đọc cho cổng thông tin học viên và lưu kết quả kiểm tra có cấu trúc linh hoạt. Kiến trúc kết hợp nhiều loại CSDL này gọi là *polyglot persistence*, trong đó SQL Server vẫn là nguồn dữ liệu gốc.

## 5.5 Tiểu kết chương

Chương 5 đã thử nghiệm ba mô hình CSDL tiên tiến trên chính dữ liệu của ECMS thay vì chỉ trình bày lý thuyết. Mô hình hướng đối tượng mô tả bài toán tự nhiên nhất nhưng gặp vấn đề N+1 truy vấn khi thống kê. Mô hình phân tán được thiết kế với đủ các kiểu phân mảnh và đã kiểm chứng ba tính chất đầy đủ, rời nhau, tái thiết. Mô hình NoSQL với MongoDB đọc hồ sơ học viên nhanh hơn nhưng phải đánh đổi tính toàn vẹn. Các số liệu đo được củng cố lựa chọn mô hình quan hệ làm lõi cho ECMS và chỉ ra vai trò bổ trợ phù hợp của từng mô hình còn lại.
