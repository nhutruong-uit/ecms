#!/usr/bin/env python3
"""So sánh truy vấn kiểu hướng đối tượng (duyệt đường dẫn, gọi phương thức) với SQL thuần (T25).

    python3 oodb/demo.py
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from models import GiaoVien, HocVien, KhoaHoc, LopHoc, NhanVien, Session  # noqa: E402


def do(ten, fn):
    s = Session()
    t = time.perf_counter()
    kq = fn(s)
    return ten, kq, (time.perf_counter() - t) * 1000, s.so_truy_van


def in_bang(ds):
    print(f"{'Cách làm':<48}{'Kết quả':<32}{'ms':>8}{'câu SQL':>9}")
    for ten, kq, ms, n in ds:
        print(f"{ten:<48}{str(kq)[:30]:<32}{ms:>8.1f}{n:>9}")
    print()


# 1. Lộ trình tiên quyết của IELTS 6.5+: phương thức đệ quy vs CTE đệ quy
in_bang([
    do("OO: KhoaHoc('IE65').lo_trinh()", lambda s: " → ".join(k.ma_kh for k in s.get(KhoaHoc, "IE65").lo_trinh())),
    do("SQL: CTE đệ quy (Q26)", lambda s: " → ".join(r["MaKH"] for r in s.rows("""
        WITH c AS (SELECT MaKH, MaKHTienQuyet, 0 AS b FROM KHOAHOC WHERE MaKH = 'IE65'
                   UNION ALL SELECT k.MaKH, k.MaKHTienQuyet, c.b + 1 FROM KHOAHOC k JOIN c ON k.MaKH = c.MaKHTienQuyet)
        SELECT MaKH FROM c ORDER BY b DESC"""))),
])

# 2. Sĩ số còn lại của các lớp đang học: lazy loading (N+1) vs một câu GROUP BY
in_bang([
    do("OO: [l.si_so_con_lai() for l in lop đang học]",
       lambda s: sorted((l.ma_lop, l.si_so_con_lai()) for l in s.all(LopHoc, "l.TrangThai = N'Đang học'"))),
    do("SQL: một câu SELECT … SiSoToiDa - SiSoHienTai",
       lambda s: sorted((r["MaLop"], r["c"]) for r in s.rows(
           "SELECT MaLop, SiSoToiDa - SiSoHienTai AS c FROM LOPHOC WHERE TrangThai = N'Đang học'"))),
])

# 3. Tổng công nợ toàn trung tâm: gọi phương thức trên từng học viên vs SUM một lần
in_bang([
    do("OO: sum(h.cong_no() for h in HocVien)", lambda s: f"{sum(h.cong_no() for h in s.all(HocVien)):,.0f}"),
    do("SQL: SUM qua view vw_CongNoHocVien", lambda s: f"{float(s.rows('SELECT SUM(ConNo) AS t FROM vw_CongNoHocVien')[0]['t']):,.0f}"),
])

# 4. Đa hình và identity map
s = Session()
nv = s.all(NhanVien, "n.MaCN = 'CN01'")
print("Đa hình tinh_luong('2026-09'):")
for x in nv[:6]:
    print(f"  {type(x).__name__:<9} {x.ho_ten():<22} {x.tinh_luong('2026-09'):>14,.0f}")
lop = s.get(LopHoc, s.all(LopHoc, "l.TrangThai = N'Đang học'")[0].ma_lop)
gv = lop.giao_vien
print(f"\nIdentity map: lop.giao_vien is s.get(NhanVien, '{gv.ma_nv}') → {gv is s.get(NhanVien, gv.ma_nv)}; "
      f"isinstance(gv, GiaoVien) = {isinstance(gv, GiaoVien)}; lớp có trong gv.lop_phu_trach → "
      f"{any(l is lop for l in gv.lop_phu_trach)}")
