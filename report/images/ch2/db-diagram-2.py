"""Hình 2.6 – Sơ đồ CSDL ECMS: nhóm học viên, học tập, tài chính và hệ thống (9 bảng, 15 khoá ngoại):

    python3 report/images/ch2/db-diagram-2.py     # → db-diagram-2.svg, .png

Cùng quy ước với Hình 2.5; bảng nền xám thuộc nhóm còn lại (chỉ vẽ tên). Bảng cha thuộc nhóm khác (KHOAHOC,
NHANVIEN) đặt bên phải nên khoá ngoại của chúng đi vào mép phải bảng con – nhờ vậy các đường không cắt trục khoá
ngoại của HOCVIEN."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
from so_do import SoDo  # noqa: E402

s = SoDo(co=16)
B = {
 "HOCVIEN": ([("PK", "MaHV *", 1), ("FK", "MaCN *")], 15),
 "KIEMTRA_DAUVAO": ([("PK", "MaKT *", 1), ("FK", "MaHV *"), ("FK", "MaKHDeXuat"), ("FK", "MaNVCham")], 3),
 "TAIKHOAN": ([("PK", "TenDangNhap *", 1), ("FK", "MaNV"), ("FK", "MaHV")], 8),
 "PHIEUTHU": ([("PK", "MaPT *", 1), ("FK", "MaHV *"), ("FK", "MaNV *")], 6),
 "DANGKY": ([("PK", "MaDK *", 1), ("FK", "MaHV *"), ("FK", "MaLop *")], 11),
 "CT_PHIEUTHU": ([("PK FK", "MaPT *", 1), ("PK FK", "MaDK *", 1)], 1),
 "CANHBAO_CHUYENCAN": ([("PK", "MaCB *", 1), ("FK", "MaDK *")], 6),
 "DIEMDANH": ([("PK FK", "MaDK *", 1), ("PK FK", "MaLop *", 1), ("PK FK", "STT *", 1)], 2),
 "NHATKY": ([("PK", "MaNK *", 1)], 8),
}
XAM = ("CHINHANH", "LOPHOC", "BUOIHOC", "KHOAHOC", "NHANVIEN")
POS = {                      # tâm dòng tiêu đề; dòng i của bảng nằm ở y + 23 + 21·i
 "CHINHANH": (80, 104), "NHATKY": (80, 330),
 "HOCVIEN": (300, 60), "LOPHOC": (300, 505),
 "KIEMTRA_DAUVAO": (570, 0), "TAIKHOAN": (570, 160), "PHIEUTHU": (570, 300), "DANGKY": (570, 440), "BUOIHOC": (570, 584),
 "KHOAHOC": (870, 65), "NHANVIEN": (870, 204), "CT_PHIEUTHU": (870, 300), "CANHBAO_CHUYENCAN": (870, 419),
 "DIEMDANH": (870, 540),
}
for k, (x, y) in POS.items():
    if k in XAM:
        s.bang(k, x, y, k, xam=True)
    else:
        dong, them = B[k]
        s.bang(k, x, y, k, [d if len(d) == 3 else (*d, False) for d in dong], them)


def yd(bang, i):
    return s.D(bang, i, "l")[1]


def fk(cha, i, con, j, x=None, vao="l"):
    """Khoá ngoại từ dòng i của bảng cha (-1: dòng tiêu đề của bảng xám) tới dòng j của bảng con, đoạn đứng ở x;
    vao = "l" | "r": đi vào mép trái / phải của bảng con."""
    a = s.D(cha, i, "r" if vao == "l" else "l")
    b = s.D(con, j, vao)
    giua = (("x", x), ("y", b[1])) if x is not None and abs(a[1] - b[1]) > 0.1 else ()
    s.noi((cha, "r" if vao == "l" else "l", i), *giua, (con, vao, j), mui="mot", ten="nhieu")


fk("CHINHANH", -1, "HOCVIEN", 1)
XA = 440                                            # trục khoá ngoại MaHV
for con, j in (("KIEMTRA_DAUVAO", 1), ("TAIKHOAN", 2), ("PHIEUTHU", 1), ("DANGKY", 1)):
    fk("HOCVIEN", 0, con, j, XA)
fk("LOPHOC", -1, "DANGKY", 2)
fk("KHOAHOC", -1, "KIEMTRA_DAUVAO", 2, vao="r")
XB = 690                                            # trục khoá ngoại MaNV (vào mép phải)
for con, j in (("KIEMTRA_DAUVAO", 3), ("TAIKHOAN", 1), ("PHIEUTHU", 2)):
    fk("NHANVIEN", -1, con, j, XB, vao="r")
fk("PHIEUTHU", 0, "CT_PHIEUTHU", 0)
XD = 730                                            # trục khoá ngoại MaDK
for con, j in (("CT_PHIEUTHU", 1), ("CANHBAO_CHUYENCAN", 1), ("DIEMDANH", 0)):
    fk("DANGKY", 0, con, j, XD)
fk("BUOIHOC", -1, "DIEMDANH", 1)

if __name__ == "__main__":
    s.kiem_tra()
    s.luu(Path(__file__).with_suffix(""), rong_px=2600)
