"""Hình 2.4 – Cùng dữ liệu ghi danh của chi nhánh CN01 theo mô hình phân cấp (a) và mô hình mạng (b).
Dữ liệu thật trong 02_seed.sql: học viên HV0010, HV0013 cùng học hai lớp IEF-2501 và IE55-2602.

    python3 report/images/ch2/mo-hinh-co-cau-truc.py     # → mo-hinh-co-cau-truc.svg, .png

Đường nối đi từ trung điểm cạnh dưới nút cha, gấp vuông góc, vào trung điểm cạnh trên nút con; tên kiểu tập hợp
(mô hình mạng) đặt cạnh đoạn đứng của đường."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
from so_do import SoDo  # noqa: E402

s = SoDo(co=15.5, co_nhan=13.5)
T, B, L, R = "t", "b", "l", "r"
GOC, CON, SAO = ("#bfdbfe", "#1d4ed8"), ("#dbeafe", "#1d4ed8"), ("#fee2e2", "#b91c1c")
Y0, Y1, Y2 = 0, 92, 186                              # ba tầng bản ghi

# ---------------------------------------------------------------- (a) phân cấp
s.khung(-10, -62, 392, 222, "(a) Phân cấp: mỗi bản ghi con có đúng một cha")
s.hop("a_cn", 191, Y0, "CN01", kieu="tron", w=84, nen=GOC[0], vien=GOC[1])
s.hop("a_l1", 95, Y1, "IEF-2501", kieu="tron", w=96, nen=CON[0], vien=CON[1])
s.hop("a_l2", 287, Y1, "IE55-2602", kieu="tron", w=96, nen=CON[0], vien=CON[1])
for k, (x, t, mau) in enumerate(((45, "HV0010", CON), (145, "HV0013", CON),
                                 (237, "HV0010\n(bản sao)", SAO), (337, "HV0013\n(bản sao)", SAO))):
    s.hop(f"a_h{k}", x, Y2, t, kieu="tron" if mau is CON else "tron_dut", w=86, h=44, nen=mau[0], vien=mau[1])
for cha, con in (("a_cn", ("a_l1", "a_l2")), ("a_l1", ("a_h0", "a_h1")), ("a_l2", ("a_h2", "a_h3"))):
    ym = (s.P(cha, B)[1] + s.P(con[0], T)[1]) / 2
    for c in con:
        s.noi((cha, B), ("y", ym), ("x", s.P(c, T)[0]), (c, T), ten=True)

# ---------------------------------------------------------------- (b) mạng
s.khung(412, -62, 690, 222, "(b) Mạng: tập hợp chủ – thành viên")
s.hop("b_cn", 551, Y0, "CHI NHÁNH", kieu="tron", w=112, nen=GOC[0], vien=GOC[1])
s.hop("b_lop", 470, Y1, "LỚP", kieu="tron", w=70, nen=CON[0], vien=CON[1])
s.hop("b_hv", 626, Y1, "HỌC VIÊN", kieu="tron", w=104, nen=CON[0], vien=CON[1])
s.hop("b_dk", 551, Y2, "ĐĂNG KÝ", kieu="tron", w=104, nen="#fef3c7", vien="#b45309")
s.noi(("b_cn", B, -35), ("y", 46), ("x", 470), ("b_lop", T), ten=True)
s.noi(("b_cn", B, 35), ("y", 46), ("x", 626), ("b_hv", T), ten=True)
s.noi(("b_lop", B), ("y", 140), ("x", 525), ("b_dk", T, -26), ten=True)
s.noi(("b_hv", B), ("y", 140), ("x", 577), ("b_dk", T, 26), ten=True)
s.nhan_tai(464, 58, "CN_LOP", "w", co=13, mau="#334155")
s.nhan_tai(632, 58, "CN_HV", "e", co=13, mau="#334155")
s.nhan_tai(464, 126, "LOP_DK", "w", co=13, mau="#334155")
s.nhan_tai(632, 126, "HV_DK", "e", co=13, mau="#334155")

if __name__ == "__main__":
    s.kiem_tra()
    s.luu(Path(__file__).with_suffix(""), rong_px=2000)
