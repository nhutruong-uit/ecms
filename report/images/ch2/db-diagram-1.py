"""Hình 2.5 – Sơ đồ CSDL ECMS: nhóm danh mục và đào tạo (13 bảng, 18 khoá ngoại), vẽ bằng toạ độ đặt tay:

    python3 report/images/ch2/db-diagram-1.py     # → db-diagram-1.svg, .png

Bảng và khoá lấy từ sys.columns / sys.foreign_keys sau khi chạy database/run_all; mỗi bảng chỉ liệt kê cột khoá
(PK, FK), các cột còn lại ở Phụ lục C; * là NOT NULL. Mỗi đường nối đi từ dòng khoá chính của bảng cha (vạch ngang:
một) tới dòng khoá ngoại của bảng con (chân quạ: nhiều); bảng cha ở bên trái, bảng con ở bên phải."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
from so_do import SoDo  # noqa: E402

s = SoDo(co=16)
B = {
 "CHUONGTRINH": ([("PK", "MaCT *", 1)], 3),
 "NGAYLE": ([("PK", "Ngay *", 1)], 1),
 "KHOAHOC": ([("PK", "MaKH *", 1), ("FK", "MaCT *"), ("FK", "MaKHTienQuyet")], 7),
 "CHINHANH": ([("PK", "MaCN *", 1), ("FK", "MaNVQuanLy")], 4),
 "NHANVIEN": ([("PK", "MaNV *", 1), ("FK", "MaCN *"), ("FK", "MaNVQuanLy")], 11),
 "PHONGHOC": ([("PK FK", "MaCN *", 1), ("PK", "MaPhong *", 1)], 2),
 "GIAOVIEN": ([("PK FK", "MaGV *", 1)], 4),
 "CAHOC": ([("PK", "MaCa *", 1)], 3),
 "LOPHOC": ([("PK", "MaLop *", 1), ("FK", "MaKH *"), ("FK", "MaCN *"), ("FK", "MaGV *")], 6),
 "CHUNGCHI_GV": ([("PK FK", "MaGV *", 1), ("PK", "TenChungChi *", 1)], 3),
 "BANGLUONG": ([("PK", "Thang *", 1), ("PK FK", "MaGV *", 1)], 5),
 "LICHHOC": ([("PK FK", "MaLop *", 1), ("PK", "Thu *", 1), ("PK FK", "MaCa *", 1), ("FK", "MaCN *"), ("FK", "MaPhong *")], 0),
 "BUOIHOC": ([("PK FK", "MaLop *", 1), ("PK", "STT *", 1), ("FK", "MaCa *"), ("FK", "MaGVDay")], 4),
}
POS = {                      # tâm dòng tiêu đề; dòng i của bảng nằm ở y + 23 + 21·i
 "CHUONGTRINH": (80, 0), "NGAYLE": (80, 470),
 "KHOAHOC": (330, 0), "CHINHANH": (330, 180), "NHANVIEN": (330, 330),
 "PHONGHOC": (590, 323), "GIAOVIEN": (590, 470),
 "LOPHOC": (850, 0), "CAHOC": (850, 200), "CHUNGCHI_GV": (850, 440), "BANGLUONG": (850, 560),
 "BUOIHOC": (1110, 60), "LICHHOC": (1110, 260),
}
for k, (x, y) in POS.items():
    dong, them = B[k]
    s.bang(k, x, y, k, [d if len(d) == 3 else (*d, False) for d in dong], them)


def y(bang, i):
    return s.D(bang, i, "l")[1]


def fk(cha, i, con, j, *giua):
    """Khoá ngoại từ dòng i (khoá chính) của bảng cha tới dòng j (khoá ngoại) của bảng con; giua: các điểm gấp
    ("x", v) / ("y", v) / (x, y). Không ghi gì: một đoạn đứng ở giữa khe giữa hai cột."""
    a, b = s.D(cha, i, "r"), s.D(con, j, "l")
    giua = giua or (("x", (a[0] + b[0]) / 2),)
    s.noi((cha, "r", i), *giua, ("y", b[1]), (con, "l", j), mui="mot", ten="nhieu")


def vong(bang, i, j, x, ben="r"):
    """Khoá ngoại tự tham chiếu: vòng ra mép phải / trái của bảng từ dòng i tới dòng j."""
    s.noi((bang, ben, i), ("x", x), ("y", y(bang, j)), (bang, ben, j), mui="mot", ten="nhieu")


xr = lambda k: s.hinh[k].x + s.hinh[k].w / 2       # noqa: E731 – mép phải
xl = lambda k: s.hinh[k].x - s.hinh[k].w / 2       # noqa: E731 – mép trái
fk("CHUONGTRINH", 0, "KHOAHOC", 1)
vong("KHOAHOC", 0, 2, xr("KHOAHOC") + 16)
fk("KHOAHOC", 0, "LOPHOC", 1, ("x", xl("LOPHOC") - 22))
fk("CHINHANH", 0, "LOPHOC", 2, ("x", 470))
fk("CHINHANH", 0, "PHONGHOC", 0, ("x", 470))
s.noi(("CHINHANH", "l", 0), ("x", xl("NHANVIEN") - 26), ("y", y("NHANVIEN", 1)), ("NHANVIEN", "l", 1), mui="mot", ten="nhieu")
s.noi(("NHANVIEN", "r", 0), ("x", 452), ("y", y("CHINHANH", 1)), ("CHINHANH", "r", 1), mui="mot", ten="nhieu")
vong("NHANVIEN", 0, 2, xr("NHANVIEN") + 16)
fk("NHANVIEN", 0, "GIAOVIEN", 0, ("x", 452))
XG = 728                                            # trục dọc chung của bốn khoá ngoại từ GIAOVIEN
fk("GIAOVIEN", 0, "LOPHOC", 3, ("x", XG))
fk("GIAOVIEN", 0, "CHUNGCHI_GV", 0, ("x", XG))
fk("GIAOVIEN", 0, "BANGLUONG", 1, ("x", XG))
XB = xr("LICHHOC") + 26
s.noi(("GIAOVIEN", "r", 0), ("x", XG), ("y", 410), ("x", XB), ("y", y("BUOIHOC", 3)), ("BUOIHOC", "r", 3), mui="mot", ten="nhieu")
fk("PHONGHOC", 1, "LICHHOC", 4)
XL, XC = xl("BUOIHOC") - 24, xl("BUOIHOC") - 48     # trục của LOPHOC, CAHOC sang BUOIHOC / LICHHOC
fk("LOPHOC", 0, "BUOIHOC", 0, ("x", XL)); fk("LOPHOC", 0, "LICHHOC", 0, ("x", XL))
fk("CAHOC", 0, "BUOIHOC", 2, ("x", XC)); fk("CAHOC", 0, "LICHHOC", 2, ("x", XC))

if __name__ == "__main__":
    s.kiem_tra()
    s.luu(Path(__file__).with_suffix(""), rong_px=2600)
