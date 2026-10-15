# Lược đồ hướng đối tượng ECMS – ODL (T25)

Chuyển từ lược đồ quan hệ (`relational-schema.md`) và Class Diagram (`class-diagram.png`) sang **ODL** (Object Definition Language, chuẩn ODMG 3.0).

Quy tắc chuyển đổi đã áp dụng:

| Lược đồ quan hệ | ODL |
|---|---|
| Bảng thực thể mạnh | `class … (extent …, key …)` |
| Khoá chính | `key` – nhưng đối tượng còn có **OID** do hệ thống cấp, khoá chỉ là ràng buộc nghiệp vụ |
| Khoá ngoại 1–N | cặp `relationship` + `inverse` (một phía `Set<…>`, phía kia đối tượng đơn) |
| Bảng liên kết N–M không thuộc tính | `relationship Set<…>` hai phía, không cần lớp riêng |
| Bảng liên kết có thuộc tính (DANGKY, CT_PHIEUTHU, DIEMDANH) | lớp riêng (*association class*) có 2 relationship |
| Chuyên biệt hoá NHANVIEN ⊃ GIAOVIEN | `class GiaoVien extends NhanVien` |
| Thuộc tính phức hợp (Họ tên, Địa chỉ) | `struct` |
| Thuộc tính đa trị (chứng chỉ GV) | `set<struct ChungChi>` – không cần bảng riêng |
| Thực thể yếu (PHONGHOC, BUOIHOC) | lớp có relationship bắt buộc tới lớp chủ, khoá gồm cả lớp chủ |
| Thuộc tính suy diễn (tuổi, sĩ số, thành tiền) | **phương thức** (`operation`) thay cho cột lưu sẵn + trigger |
| Procedure nghiệp vụ (`sp_DangKyHoc`, `sp_ThuHocPhi`) | phương thức của lớp tương ứng, có `raises(...)` |

```odl
module ECMS {

    struct HoTen   { string ho; string ten; };
    struct DiaChi  { string soNha; string phuongXa; string quanHuyen; string tinhTP; };
    struct ChungChi { string ten; float diem; date ngayCap; string noiCap; };
    struct ThoiGian { time batDau; time ketThuc; };

    exception LopDay {};
    exception ThieuTienQuyet { string khoaCanDat; };
    exception ThuVuotNo {};
    exception TrungLich { string lopTrung; };

    // ---------------------------------------------------------------- Người (trừu tượng)
    interface Nguoi {
        attribute HoTen    hoTen;
        attribute date     ngaySinh;
        attribute string   gioiTinh;
        attribute string   soDienThoai;
        short   tuoi();                                   // suy diễn từ ngaySinh
        string  hoTenDayDu();
    };

    class ChiNhanh (extent cacChiNhanh key maCN) {
        attribute string maCN;
        attribute string tenCN;
        attribute string diaChi;
        attribute string soDienThoai;
        relationship NhanVien        quanLy      inverse NhanVien::chiNhanhQuanLy;
        relationship Set<NhanVien>   nhanViens   inverse NhanVien::chiNhanh;
        relationship Set<PhongHoc>   phongHocs   inverse PhongHoc::chiNhanh;
        relationship Set<LopHoc>     lopHocs     inverse LopHoc::chiNhanh;
        relationship Set<HocVien>    hocViens    inverse HocVien::chiNhanh;
        double doanhThu(in date tu, in date den);
    };

    class NhanVien : Nguoi (extent cacNhanVien key maNV) {
        attribute string maNV;
        attribute string chucVu;
        attribute double luongCoBan;
        attribute date   ngayVaoLam;
        relationship ChiNhanh        chiNhanh        inverse ChiNhanh::nhanViens;
        relationship ChiNhanh        chiNhanhQuanLy  inverse ChiNhanh::quanLy;
        relationship NhanVien        nguoiQuanLy     inverse NhanVien::capDuoi;      // đệ quy
        relationship Set<NhanVien>   capDuoi         inverse NhanVien::nguoiQuanLy;
        relationship Set<PhieuThu>   phieuDaLap      inverse PhieuThu::nguoiLap;
        PhieuThu lapPhieuThu(in HocVien hv, in string hinhThuc);
    };

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

    class ChuongTrinh (extent cacChuongTrinh key maCT) {
        attribute string maCT;
        attribute string tenCT;
        attribute string doiTuong;
        relationship Set<KhoaHoc> khoaHocs inverse KhoaHoc::chuongTrinh;   // kết tập
    };

    class KhoaHoc (extent cacKhoaHoc key maKH) {
        attribute string maKH;
        attribute string tenKH;
        attribute short  capDo;
        attribute float  diemDauVaoTu;
        attribute float  diemDauVaoDen;
        attribute short  soBuoi;
        attribute double hocPhi;
        relationship ChuongTrinh      chuongTrinh  inverse ChuongTrinh::khoaHocs;
        relationship KhoaHoc          tienQuyet    inverse KhoaHoc::laTienQuyetCua;   // đệ quy
        relationship Set<KhoaHoc>     laTienQuyetCua inverse KhoaHoc::tienQuyet;
        relationship Set<LopHoc>      lopHocs      inverse LopHoc::khoaHoc;
        boolean phuHop(in float diem);
        list<KhoaHoc> loTrinh();                               // chuỗi tiên quyết – thay cho CTE đệ quy
    };

    class PhongHoc (extent cacPhongHoc key (chiNhanh, maPhong)) {        // thực thể yếu
        attribute string maPhong;
        attribute short  sucChua;
        attribute string loaiPhong;
        relationship ChiNhanh      chiNhanh inverse ChiNhanh::phongHocs;
        relationship Set<LichHoc>  lichs    inverse LichHoc::phong;
    };

    class CaHoc (extent cacCaHoc key maCa) {
        attribute short    maCa;
        attribute string   tenCa;
        attribute ThoiGian khung;
        relationship Set<LichHoc> lichs inverse LichHoc::ca;
    };

    class LopHoc (extent cacLopHoc key maLop) {
        attribute string maLop;
        attribute date   ngayKhaiGiang;
        attribute date   ngayKetThuc;
        attribute short  siSoToiDa;
        attribute string trangThai;
        relationship KhoaHoc        khoaHoc   inverse KhoaHoc::lopHocs;
        relationship ChiNhanh       chiNhanh  inverse ChiNhanh::lopHocs;
        relationship GiaoVien       giaoVien  inverse GiaoVien::lopPhuTrach;
        relationship Set<LichHoc>   lichs     inverse LichHoc::lop;
        relationship list<BuoiHoc>  buoiHocs  inverse BuoiHoc::lop;      // thành phần, có thứ tự
        relationship Set<DangKy>    dangKys   inverse DangKy::lop;
        short siSoHienTai();                                 // suy diễn – thay cho cột + trigger
        short siSoConLai();
        void  xepLich(in short thu, in CaHoc ca, in PhongHoc phong) raises (TrungLich);
        void  sinhBuoiHoc();
    };

    class LichHoc (extent cacLichHoc key (lop, thu, ca)) {               // liên kết 3 ngôi
        attribute short thu;
        relationship LopHoc   lop   inverse LopHoc::lichs;
        relationship PhongHoc phong inverse PhongHoc::lichs;
        relationship CaHoc    ca    inverse CaHoc::lichs;
    };

    class BuoiHoc (extent cacBuoiHoc key (lop, stt)) {                   // thực thể yếu
        attribute short  stt;
        attribute date   ngayHoc;
        attribute string noiDung;
        relationship LopHoc         lop        inverse LopHoc::buoiHocs;
        relationship Set<DiemDanh>  diemDanhs  inverse DiemDanh::buoi;
        void diemDanh(in dictionary<HocVien, string> trangThai);
    };

    class DangKy (extent cacDangKy key (hocVien, lop)) {                 // lớp liên kết HocVien – LopHoc
        attribute date   ngayDK;
        attribute double hocPhi;
        attribute float  giamGia;
        attribute float  diemGK;
        attribute float  diemCK;
        attribute string trangThai;
        relationship HocVien          hocVien    inverse HocVien::dangKys;
        relationship LopHoc           lop        inverse LopHoc::dangKys;
        relationship Set<DiemDanh>    diemDanhs  inverse DiemDanh::dangKy;
        relationship Set<CTPhieuThu>  khoanThus  inverse CTPhieuThu::dangKy;
        double thanhTien();
        float  diemTB();
        string ketQua();
        float  tyLeChuyenCan();
        double soTienConNo();
    };

    class DiemDanh (extent cacDiemDanh) {
        attribute string trangThai;
        attribute string ghiChu;
        relationship DangKy  dangKy inverse DangKy::diemDanhs;
        relationship BuoiHoc buoi   inverse BuoiHoc::diemDanhs;
    };

    class KiemTraDauVao (extent cacKiemTra) {
        attribute date  ngayKT;
        attribute struct KetQua { float listening; float reading; float writing; float speaking; string nhanXet; } ketQua;
        relationship HocVien hocVien inverse HocVien::kiemTras;
        relationship KhoaHoc deXuat;                         // một chiều, không cần inverse
        float diemTong();
    };

    class PhieuThu (extent cacPhieuThu key soPhieu) {
        attribute string    soPhieu;
        attribute timestamp ngayThu;
        attribute string    hinhThuc;
        relationship HocVien         hocVien  inverse HocVien::phieuThus;
        relationship NhanVien        nguoiLap inverse NhanVien::phieuDaLap;
        relationship list<CTPhieuThu> dongs   inverse CTPhieuThu::phieu;  // thành phần
        double tinhTong();
        void   themDong(in DangKy dk, in double soTien) raises (ThuVuotNo);
    };

    class CTPhieuThu (extent cacCTPhieuThu) {
        attribute double soTien;
        relationship PhieuThu phieu  inverse PhieuThu::dongs;
        relationship DangKy   dangKy inverse DangKy::khoanThus;
    };
};
```

**Thống kê:** 1 interface, **18 lớp** (≥ 8 theo yêu cầu), 4 struct, 4 exception; hơn 20 cặp `relationship / inverse` (mỗi khoá ngoại 1–N của mô hình quan hệ thành một cặp), 2 relationship đệ quy (`nguoiQuanLy`, `tienQuyet`), 1 kế thừa lớp (`GiaoVien extends NhanVien`) và 2 kế thừa interface (`Nguoi`).

**Truy vấn OQL tương ứng một số câu SQL ở Chương 3:**

```oql
// Q06 – lớp đang học kèm giáo viên: duyệt đường dẫn thay cho JOIN
select struct(lop: l.maLop, khoa: l.khoaHoc.tenKH, gv: l.giaoVien.hoTen.ten)
from l in cacLopHoc where l.trangThai = "Đang học"

// Q20 – học viên còn nợ: gọi phương thức thay cho truy vấn con
select h from h in cacHocVien where h.congNo() > 0

// Q26 – lộ trình tiên quyết: phương thức đệ quy thay cho CTE đệ quy
element(select k from k in cacKhoaHoc where k.maKH = "IE65").loTrinh()
```
