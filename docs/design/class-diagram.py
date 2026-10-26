"""Hình 2.3 – Sơ đồ lớp UML của ECMS, vẽ bằng toạ độ đặt tay:

    python3 docs/design/class-diagram.py          # → docs/design/class-diagram.svg, class-diagram.png

Bố cục cùng "xương sống" với ERD (Hình 2.1): LopHoc —học— HocVien nằm giữa, lớp liên kết DangKy treo dưới đường
liên kết (nét đứt). Tam giác rỗng: kế thừa · thoi đặc: thành phần · thoi rỗng: kết tập (đặt ở đầu lớp toàn thể);
bội số ở hai đầu, tên liên kết in nghiêng. Hai liên kết dài (phụ trách, làm việc) chạy vòng phía dưới, không cắt đường
nào. Chạy lại sẽ in lỗi bố cục (nhãn chồng, đường cắt qua hình) nếu có."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from so_do import SoDo  # noqa: E402

# lớp: id -> (tên, thuộc tính, phương thức, khuôn mẫu)
LOP = {
 "Nguoi": ("Nguoi", ["# ho : String", "# ten : String", "# ngaySinh : Date", "# gioiTinh : String", "# soDienThoai : String"], ["+ hoTen() : String", "+ tuoi() : int"], "abstract"),
 "HocVien": ("HocVien", ["- maHV : String", "- email : String", "- diaChi : DiaChi", "- hoTenPhuHuynh : String"], ["+ dangKy(lop : LopHoc, giamGia : float) : DangKy", "+ congNo() : Money", "+ lichHoc(tuan : Date) : List"], ""),
 "NhanVien": ("NhanVien", ["- maNV : String", "- chucVu : String", "- luongCoBan : Money", "- ngayVaoLam : Date"], ["+ nguoiQuanLy() : NhanVien", "+ lapPhieuThu(hv : HocVien) : PhieuThu"], ""),
 "GiaoVien": ("GiaoVien", ["- loaiGV : String", "- quocTich : String", "- trinhDo : String", "- donGiaBuoi : Money"], ["+ lopDangDay() : List", "+ tinhLuong(thang : String) : Money"], ""),
 "ChungChi": ("ChungChi", ["- ten : String", "- diem : float", "- ngayCap : Date"], [], ""),
 "ChiNhanh": ("ChiNhanh", ["- maCN : String", "- tenCN : String", "- diaChi : String"], ["+ doanhThu(tu : Date, den : Date) : Money"], ""),
 "PhongHoc": ("PhongHoc", ["- maPhong : String", "- sucChua : int", "- loaiPhong : String"], ["+ trong(thu : int, ca : CaHoc) : bool"], ""),
 "CaHoc": ("CaHoc", ["- maCa : int", "- gioBatDau : Time", "- gioKetThuc : Time"], [], ""),
 "ChuongTrinh": ("ChuongTrinh", ["- maCT : String", "- tenCT : String", "- doiTuong : String"], [], ""),
 "KhoaHoc": ("KhoaHoc", ["- maKH : String", "- tenKH : String", "- capDo : int", "- soBuoi : int", "- hocPhi : Money"], ["+ khoaTienQuyet() : KhoaHoc", "+ phuHop(diem : float) : bool"], ""),
 "LopHoc": ("LopHoc", ["- maLop : String", "- ngayKhaiGiang : Date", "- siSoToiDa : int", "- trangThai : String"], ["+ siSoHienTai() : int", "+ siSoConLai() : int", "+ xepLich(thu, ca, phong) : void", "+ sinhBuoiHoc() : void"], ""),
 "LichHoc": ("LichHoc", ["- thu : int"], [], ""),
 "BuoiHoc": ("BuoiHoc", ["- stt : int", "- ngayHoc : Date", "- noiDung : String"], ["+ diemDanh(ds : Map) : void"], ""),
 "DangKy": ("DangKy", ["- ngayDK : Date", "- hocPhi : Money", "- giamGia : float", "- diemGK : float", "- diemCK : float"], ["+ thanhTien() : Money", "+ diemTB() : float", "+ ketQua() : String", "+ tyLeChuyenCan() : float", "+ soTienConNo() : Money"], "association class"),
 "DiemDanh": ("DiemDanh", ["- trangThai : String", "- ghiChu : String"], [], ""),
 "KiemTra": ("KiemTraDauVao", ["- ngayKT : Date", "- listening, reading, writing, speaking : float", "- nhanXet : String"], ["+ diemTong() : float", "+ deXuatKhoa() : KhoaHoc"], ""),
 "PhieuThu": ("PhieuThu", ["- soPhieu : String", "- ngayThu : DateTime", "- hinhThuc : String"], ["+ tinhTong() : Money", "+ themDong(dk : DangKy, tien : Money) : void", "+ inPDF() : File"], ""),
 "CTPhieuThu": ("CTPhieuThu", ["- soTien : Money"], [], ""),
 "TaiKhoan": ("TaiKhoan", ["- tenDangNhap : String", "- matKhauHash : bytes", "- vaiTro : String"], ["+ dangNhap(mk : String) : bool", "+ doiMatKhau(cu, moi : String) : void"], ""),
}

s = SoDo(co=17, co_nhan=13)
T, B, L, R = "t", "b", "l", "r"
R1, R2, R3, R4 = 80, 320, 540, 720           # hàng: khoá học · lớp học – học viên · phiếu thu, nhân viên · giáo viên
YP, YL = 815, 845                            # đường vòng dưới: phụ trách, làm việc
XL, XH, XN = 300, 940, 1270                  # cột lớp học · học viên · người – nhân viên
POS = {
 "ChuongTrinh": (60, R1), "KhoaHoc": (XL + 35, R1), "KiemTra": (XH, R1), "TaiKhoan": (XN, R1),
 "CaHoc": (60, 195), "LichHoc": (60, R2), "LopHoc": (XL, R2), "HocVien": (XH, R2), "Nguoi": (XN, R2),
 "PhongHoc": (60, 445), "ChiNhanh": (60, 625), "BuoiHoc": (XL + 130, R3), "DangKy": (640, 560),
 "DiemDanh": (XL + 130, R4), "CTPhieuThu": (XH - 95, R4), "PhieuThu": (XH, R3), "NhanVien": (XN, R3),
 "GiaoVien": (XN - 60, R4), "ChungChi": (972, R4),
}
for k, (x, y) in POS.items():
    ten, tt, pt, kh = LOP[k]
    s.lop(k, x, y, ten, tt, pt, kh, w=230 if k == "LopHoc" else None)


def ten(x, y, t, neo="n"):
    s.nhan_tai(x, y, t, neo, nghieng=True, co=14)


def cao(k):
    return s.hinh[k].h / 2


# ---------------------------------------------------------------- khoá học, kiểm tra đầu vào
s.noi(("ChuongTrinh", R), ("KhoaHoc", L), mui="ket_tap")
s.ban_so("ChuongTrinh", R, "1", "n", doc=26); s.ban_so("KhoaHoc", L, "1..*", "n")
xk, yk = XL + 35 + s.hinh["KhoaHoc"].w / 2, R1 + cao("KhoaHoc")
s.noi(("KhoaHoc", B, 55), ("y", yk + 28), ("x", xk + 40), ("y", R1 + 45), ("KhoaHoc", R, 45))
s.ban_so("KhoaHoc", B, "0..1", "w", 55, doc=3); s.ban_so("KhoaHoc", R, "0..*", "n", 45, doc=4)
ten(xk + 46, yk + 2, "tiên quyết", "e")
s.noi(("KhoaHoc", R, -20), ("KiemTra", L, -20))
s.ban_so("KhoaHoc", R, "0..1", "n", -20); s.ban_so("KiemTra", L, "0..*", "n", -20); ten(660, R1 - 16, "đề xuất", "s")
s.noi(("KhoaHoc", B, -35), ("LopHoc", T))
s.ban_so("KhoaHoc", B, "1", "w", -35); s.ban_so("LopHoc", T, "0..*", "w"); ten(XL + 6, 200, "mở", "e")
s.noi(("KiemTra", B), ("HocVien", T)); s.ban_so("KiemTra", B, "0..*", "e"); s.ban_so("HocVien", T, "1", "e")
# ---------------------------------------------------------------- lịch học, phòng, chi nhánh
s.noi(("LichHoc", T), ("CaHoc", B)); s.ban_so("CaHoc", B, "1", "e"); s.ban_so("LichHoc", T, "0..*", "e")
s.noi(("LichHoc", B), ("PhongHoc", T)); s.ban_so("PhongHoc", T, "1", "e"); s.ban_so("LichHoc", B, "0..*", "e")
s.noi(("LopHoc", L), ("LichHoc", R)); s.ban_so("LopHoc", L, "1", "n"); s.ban_so("LichHoc", R, "1..*", "n")
s.noi(("ChiNhanh", T), ("PhongHoc", B), mui="thanh_phan")
s.ban_so("ChiNhanh", T, "1", "e", doc=26); s.ban_so("PhongHoc", B, "1..*", "e")
s.noi(("ChiNhanh", R), ("x", XL - 65), ("LopHoc", B, -65))
s.ban_so("ChiNhanh", R, "1", "n"); s.ban_so("LopHoc", B, "0..*", "w", -65); ten(XL - 59, 520, "tổ chức", "e")
# ---------------------------------------------------------------- học + lớp liên kết DangKy, buổi học, điểm danh
s.noi(("LopHoc", R), ("HocVien", L))
s.ban_so("LopHoc", R, "0..*", "n"); s.ban_so("HocVien", L, "0..*", "n"); ten(540, R2 - 4, "học")
s.noi((640, R2), ("DangKy", T), nets="dut")
s.noi(("LopHoc", B, 65), ("BuoiHoc", T, -65), mui="thanh_phan")
s.ban_so("LopHoc", B, "1", "e", 65, doc=26); s.ban_so("BuoiHoc", T, "0..*", "e", -65)
s.noi(("BuoiHoc", B), ("DiemDanh", T)); s.ban_so("BuoiHoc", B, "1", "e"); s.ban_so("DiemDanh", T, "0..*", "e")
s.noi(("DangKy", B, -30), ("y", R4), ("DiemDanh", R))
s.ban_so("DangKy", B, "1", "w", -30); s.ban_so("DiemDanh", R, "0..*", "n")
s.noi(("DangKy", B, 30), ("y", R4), ("CTPhieuThu", L))
s.ban_so("DangKy", B, "1", "e", 30); s.ban_so("CTPhieuThu", L, "0..*", "n")
# ---------------------------------------------------------------- người, phiếu thu, nhân viên
s.noi(("Nguoi", L), ("HocVien", R), mui="ke_thua")
s.noi(("Nguoi", B), ("NhanVien", T), mui="ke_thua")
s.noi(("NhanVien", B, -60), ("GiaoVien", T), mui="ke_thua")
s.noi(("Nguoi", T), ("TaiKhoan", B)); s.ban_so("Nguoi", T, "1", "e"); s.ban_so("TaiKhoan", B, "0..1", "e")
s.noi(("HocVien", B), ("PhieuThu", T)); s.ban_so("HocVien", B, "1", "e"); s.ban_so("PhieuThu", T, "0..*", "e")
s.noi(("PhieuThu", B, -95), ("CTPhieuThu", T), mui="thanh_phan")
s.ban_so("PhieuThu", B, "1", "e", -95, doc=26); s.ban_so("CTPhieuThu", T, "1..*", "e")
s.noi(("PhieuThu", R, 30), ("NhanVien", L, 30))
s.ban_so("PhieuThu", R, "0..*", "n", 30); s.ban_so("NhanVien", L, "1", "n", 30); ten((XH + XN) / 2 + 22, R3 + 36, "lập", "s")
xn, yn = XN - s.hinh["NhanVien"].w / 2, R3 - cao("NhanVien")
s.noi(("NhanVien", T, -85), ("y", yn - 26), ("x", xn - 36), ("y", R3 - 25), ("NhanVien", L, -25))
s.ban_so("NhanVien", T, "0..1", "e", -85, doc=3); s.ban_so("NhanVien", L, "0..*", "n", -25, doc=4)
ten(xn - 40, yn - 16, "quản lý", "w")
s.noi(("GiaoVien", L), ("ChungChi", R), mui="thanh_phan")
s.ban_so("GiaoVien", L, "1", "n", doc=26); s.ban_so("ChungChi", R, "0..*", "n")
# ---------------------------------------------------------------- hai liên kết dài chạy vòng phía dưới
s.noi(("LopHoc", B), ("y", YP), ("x", XN - 60), ("GiaoVien", B))
s.ban_so("LopHoc", B, "0..*", "e"); s.ban_so("GiaoVien", B, "1", "e"); ten(760, YP - 2, "phụ trách")
s.noi(("ChiNhanh", B), ("y", YL), ("x", XN + 95), ("NhanVien", B, 95))
s.ban_so("ChiNhanh", B, "1", "e"); s.ban_so("NhanVien", B, "1..*", "e", 95); ten(760, YL + 3, "làm việc", "s")

if __name__ == "__main__":
    s.kiem_tra()
    s.luu(Path(__file__).with_name("class-diagram"))
