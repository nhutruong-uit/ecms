"""Hình 2.1 – ERD tổng quan (ký hiệu Chen), vẽ bằng toạ độ đặt tay:

    python3 docs/design/erd.py          # → docs/design/erd.svg, erd.png

Hình chữ nhật: thực thể · viền đôi: thực thể yếu · nét đứt: thuộc tính đa trị tách bảng · hình thoi: mối kết hợp
(viền đôi: mối kết hợp xác định; nền đậm: thực thể hoá thành bảng; nét đậm: cạnh nối với mối kết hợp đã thực thể
hoá) · tam giác ISA: chuyên biệt hoá, đỉnh hướng về lớp cha. Nhãn (min,max) đặt sát đầu thực thể tham gia.
Mọi đường nối là đoạn đứng / ngang; chạy lại sẽ in lỗi bố cục (nhãn chồng, đường cắt qua hình) nếu có."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from so_do import SoDo  # noqa: E402

s = SoDo(co=17, co_nhan=14.5)
T, B, L, R = "t", "b", "l", "r"
Y0, YB, Y1, Y2, Y3 = 0, 85, 225, 368, 508    # khoá học · buổi học · lớp – đăng ký – học viên · phiếu thu · nhân sự
YQ, YG = 575, 642                             # quản lý chi nhánh · giáo viên (phụ trách)
XN = 980                                      # cột nhân viên

# ---------------------------------------------------------------- thực thể
s.hop("CT", -30, Y0, "CHUONGTRINH")
s.hop("KH", 265, Y0, "KHOAHOC", w=146)
s.hop("KT", 790, Y0, "KIỂM TRA\nĐẦU VÀO")
s.hop("BUOI", 550, YB, "BUOIHOC", kieu="yeu")
s.hop("LOP", 300, Y1, "LOPHOC", w=134)
s.hop("HV", 790, Y1, "HOCVIEN", w=152)
s.hop("TK", 1068, Y1, "TAIKHOAN")
s.hop("CA", 70, YB, "CAHOC")
s.hop("PH", 70, Y2, "PHONGHOC", kieu="yeu")
s.hop("PT", 650, Y2, "PHIEUTHU")
s.hop("CN", 600, Y3, "CHINHANH", w=146)
s.hop("NV", XN, Y3, "NHANVIEN", w=220)
s.hop("GV", 945, YG, "GIAOVIEN")
s.elip("CC", 1128, YG, "Chứng chỉ", kieu="da_tri")

# ---------------------------------------------------------------- mối kết hợp
s.thoi("gom", 118, Y0, "Gồm")
s.thoi("tq", 265, -74, "Tiên quyết", h=42)
s.thoi("dexuat", 540, Y0, "Đề xuất")
s.thoi("mo", 265, 112, "Mở")
s.thoi("cobuoi", 420, YB, "Có buổi", kieu="xac_dinh")
s.thoi("diemdanh", 550, 152, "ĐIỂM DANH", kieu="dam", w=152, h=38)
s.thoi("du", 790, 112, "Dự")
s.thoi("dk", 550, Y1, "ĐĂNG KÝ", kieu="dam", w=126)
s.thoi("lich", 70, Y1, "LỊCH HỌC\n(3 ngôi)", kieu="dam", w=142, h=66)
s.thoi("dunghv", 937, Y1, "Dùng", w=66)
s.thoi("ctpt", 550, 300, "CT PHIẾU THU", kieu="dam", w=164, h=44)
s.thoi("dong", 752, 298, "Đóng")
s.thoi("dungnv", 1068, 368, "Dùng", w=66)
s.thoi("lap", 900, 448, "Lập", h=38)
s.thoi("tiepnhan", 735, 462, "Tiếp nhận", w=120, h=38)
s.thoi("tochuc", 428, Y3, "Tổ chức")
s.thoi("cophong", 70, 448, "Có phòng", kieu="xac_dinh")
s.thoi("lamviec", 770, Y3, "Làm việc", w=104)
s.thoi("qlcn", 770, YQ, "Quản lý CN", w=128)
s.thoi("quanly", 1206, Y3, "Quản lý", w=100)
s.thoi("phutrach", 600, YG, "Phụ trách", w=116)
s.tam_giac("isa", 945, 578, huong="len", h=42)

# ---------------------------------------------------------------- đường nối
s.noi(("CT", R), ("gom", L)); s.noi(("gom", R), ("KH", L))
s.noi(("tq", L), ("x", 207), ("KH", T, -58)); s.noi(("tq", R), ("x", 323), ("KH", T, 58))
s.noi(("KH", R), ("dexuat", L)); s.noi(("dexuat", R), ("KT", L))
s.noi(("KH", B), ("mo", T)); s.noi(("mo", B), ("LOP", T, -35))
s.noi(("KT", B), ("du", T)); s.noi(("du", B), ("HV", T))
s.noi(("LOP", T, 35), ("y", YB), ("cobuoi", L)); s.noi(("cobuoi", R), ("BUOI", L))
s.noi(("LOP", R), ("dk", L)); s.noi(("dk", R), ("HV", L))
s.noi(("dk", T), ("diemdanh", B), rong=2.6); s.noi(("diemdanh", T), ("BUOI", B))
s.noi(("lich", R), ("LOP", L)); s.noi(("lich", T), ("CA", B)); s.noi(("lich", B), ("PH", T))
s.noi(("dk", B), ("ctpt", T), rong=2.6); s.noi(("ctpt", B), ("y", Y2), ("PT", L))
s.noi(("HV", B, -38), ("dong", T)); s.noi(("dong", B), ("y", Y2), ("PT", R))
s.noi(("HV", R), ("dunghv", L)); s.noi(("dunghv", R), ("TK", L))
s.noi(("TK", B), ("dungnv", T)); s.noi(("dungnv", B), ("NV", T, 1068 - XN))
s.noi(("PT", B), ("y", 410), ("x", 900), ("lap", T)); s.noi(("lap", B), ("NV", T, 900 - XN))
s.noi(("HV", B, 38), ("y", 462), ("tiepnhan", R)); s.noi(("tiepnhan", L), ("x", 600), ("CN", T))
s.noi(("LOP", B, 30), ("y", Y3), ("tochuc", L)); s.noi(("tochuc", R), ("CN", L))
s.noi(("PH", B), ("cophong", T)); s.noi(("cophong", B), ("y", 545), ("x", 570), ("CN", B, -30))
s.noi(("CN", R), ("lamviec", L)); s.noi(("lamviec", R), ("NV", L))
s.noi(("CN", B, 40), ("y", YQ), ("qlcn", L)); s.noi(("qlcn", R), ("x", 895), ("NV", B, 895 - XN))
s.noi(("NV", R), ("quanly", L)); s.noi(("quanly", B), ("y", 560), ("x", 1062), ("NV", B, 1062 - XN))
s.noi(("NV", B, 945 - XN), ("isa", T)); s.noi(("isa", B), ("GV", T))
s.noi(("GV", R), ("CC", L))
s.noi(("LOP", B, -30), ("y", YG), ("phutrach", L)); s.noi(("phutrach", R), ("GV", L))

# ---------------------------------------------------------------- bản số
s.ban_so("CT", R, "(1,n)", "n"); s.ban_so("KH", L, "(1,1)", "n")
s.ban_so("KH", T, "là TQ (0,n)", "w", -58); s.ban_so("KH", T, "cần TQ (0,1)", "e", 58)
s.ban_so("KH", R, "(0,n)", "n"); s.ban_so("KT", L, "(0,1)", "n")
s.ban_so("KH", B, "(0,n)", "e"); s.ban_so("LOP", T, "(1,1)", "w", -35)
s.ban_so("KT", B, "(1,1)", "e"); s.ban_so("HV", T, "(0,n)", "e")
s.ban_so("LOP", T, "(0,n)", "e", 35); s.ban_so("BUOI", L, "(1,1)", "s")
s.ban_so("LOP", R, "(0,n)", "n"); s.ban_so("HV", L, "(0,n)", "n")
s.ban_so("BUOI", B, "(0,n)", "e", doc=3); s.ban_so("dk", T, "(0,n)", "e", doc=4)
s.ban_so("dk", B, "(0,n)", "e", doc=4)
s.ban_so("LOP", L, "(1,n)", "n"); s.ban_so("CA", B, "(0,n)", "e"); s.ban_so("PH", T, "(0,n)", "e")
s.ban_so("PT", L, "(1,n)", "n"); s.ban_so("HV", B, "(0,n)", "w", -38); s.ban_so("PT", R, "(1,1)", "n")
s.ban_so("HV", R, "(0,1)", "n"); s.ban_so("TK", L, "(0,1)", "n")
s.ban_so("TK", B, "(0,1)", "e"); s.ban_so("NV", T, "(0,1)", "w", 1068 - XN)
s.ban_so("PT", B, "(1,1)", "w", doc=2); s.ban_so("NV", T, "(0,n)", "w", 900 - XN)
s.ban_so("HV", B, "(1,1)", "e", 38); s.ban_so("CN", T, "(0,n)", "w")
s.ban_so("LOP", B, "(1,1)", "e", 30); s.ban_so("CN", L, "(0,n)", "n")
s.ban_so("PH", B, "(1,1)", "e"); s.ban_so("CN", B, "(1,n)", "e", -30)
s.ban_so("CN", R, "(1,n)", "n"); s.ban_so("NV", L, "(1,1)", "n")
s.ban_so("CN", B, "(0,1)", "e", 40); s.ban_so("NV", B, "(0,1)", "w", 895 - XN)
s.ban_so("NV", R, "quản lý\n(0,n)", "n"); s.ban_so("NV", B, "bị QL (0,1)", "e", 1062 - XN)
s.ban_so("LOP", B, "(1,1)", "w", -30); s.ban_so("GV", L, "(0,n)", "n")
s.ban_so("GV", R, "(0,n)", "n")
s.nhan_tai(975, 584, "d, partial", "e", nen=False)

if __name__ == "__main__":
    s.kiem_tra()
    s.luu(Path(__file__).with_name("erd"))
