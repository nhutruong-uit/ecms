#!/usr/bin/env python3
"""So sánh truy vấn kiểu hướng đối tượng (duyệt đường dẫn, gọi phương thức) với SQL thuần (T25).

    python3 oodb/demo.py

1–3. truy vấn: phương thức đệ quy / lazy loading (N+1) / gọi phương thức trên từng đối tượng so với SQL
4.   OID và identity map, đa hình tinh_luong()
5.   đóng gói (luật trong phương thức) và đối tượng bền (lưu xuống CSDL) – chạy trong transaction rồi rollback
6.   truy vấn đường dẫn kiểu OQL so với JOIN
7.   ba chiến lược ánh xạ kế thừa NhanVien ← GiaoVien sang bảng: single table / joined (ECMS) / concrete table
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from models import DangKy, GiaoVien, HocVien, KhoaHoc, LoiNghiepVu, LopHoc, NhanVien, Session  # noqa: E402


def do(ten, fn):
    s = Session()
    t = time.perf_counter()
    kq = fn(s)
    return ten, kq, (time.perf_counter() - t) * 1000, s.so_truy_van


def in_bang(ds):
    print(f"{'Cách làm':<52}{'Kết quả':<32}{'ms':>8}{'câu SQL':>9}")
    for ten, kq, ms, n in ds:
        print(f"{ten:<52}{str(kq)[:30]:<32}{ms:>8.1f}{n:>9}")
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

# 4. OID, identity map và đa hình
s = Session()
nv = s.all(NhanVien, "n.MaCN = 'CN01'")
print("Đa hình tinh_luong('2026-09'):")
for x in nv[:6]:
    print(f"  OID {x.oid:<4} {type(x).__name__:<9} {x.ho_ten():<22} {x.tinh_luong('2026-09'):>14,.0f}")
lop = s.get(LopHoc, s.all(LopHoc, "l.TrangThai = N'Đang học'")[0].ma_lop)
gv = lop.giao_vien
print(f"\nIdentity map: lop.giao_vien is s.get(NhanVien, '{gv.ma_nv}') → {gv is s.get(NhanVien, gv.ma_nv)}; "
      f"s.get(GiaoVien, …) is s.get(NhanVien, …) → {s.get(GiaoVien, gv.ma_nv) is s.get(NhanVien, gv.ma_nv)}; "
      f"isinstance(gv, GiaoVien) = {isinstance(gv, GiaoVien)}; lớp có trong gv.lop_phu_trach → "
      f"{any(l is lop for l in gv.lop_phu_trach)}")
oid_truoc = gv.oid
gv.ten = gv.ten + " (đổi tên)"                         # đổi giá trị thuộc tính – OID không đổi
try:
    gv.oid = 999                                        # OID do hệ thống cấp: không có setter
    doi_duoc = "ĐỔI ĐƯỢC (sai)"
except AttributeError:
    doi_duoc = "không gán được"
print(f"OID: {oid_truoc} → sau khi đổi tên vẫn là {gv.oid}; gán gv.oid = 999 → {doi_duoc}; "
      f"bảng đối tượng đang có {len(s.objects)} đối tượng, mỗi OID một đối tượng\n")

# 5. Đóng gói + đối tượng bền: luật ghi danh nằm trong LopHoc.ghi_danh(); luu() ghi xuống DANGKY (rollback sau đó)
s = Session()
day = s.all(LopHoc, "l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoHienTai = l.SiSoToiDa")
mo = s.all(LopHoc, "l.TrangThai = N'Sắp mở' AND l.SiSoHienTai < l.SiSoToiDa")
hv = s.all(HocVien, "NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaHV = h.MaHV)")[0]
print("Đóng gói – luật ghi danh trong phương thức LopHoc.ghi_danh():")
for ten, fn in [("lớp đã đủ sĩ số", lambda: day[0].ghi_danh(hv)),
                ("giảm giá 70%", lambda: mo[0].ghi_danh(hv, 70))]:
    try:
        fn()
        print(f"  {ten:<20} → không báo lỗi")
    except (LoiNghiepVu, IndexError) as e:
        print(f"  {ten:<20} → {type(e).__name__}: {e}")
truoc = s.rows("SELECT COUNT(*) AS n FROM DANGKY")[0]["n"]
dk = mo[0].ghi_danh(hv, 10)
print(f"  ghi danh hợp lệ      → đối tượng DangKy OID {dk.oid}, chưa có MaDK (={dk.ma_dk}), thành tiền {dk.thanh_tien():,.0f}")
n = s.luu()
sau = s.rows("SELECT COUNT(*) AS n FROM DANGKY")[0]["n"]
si_so = s.rows("SELECT SiSoHienTai FROM LOPHOC WHERE MaLop = ?", mo[0].ma_lop)[0]["SiSoHienTai"]
print(f"  s.luu() ghi {n} đối tượng → MaDK = {dk.ma_dk}; DANGKY {truoc} → {sau} dòng; "
      f"sĩ số lớp {mo[0].ma_lop} (trigger cập nhật) = {si_so}; "
      f"s.get(DangKy, {dk.ma_dk}) is dk → {s.get(DangKy, dk.ma_dk) is dk} (vẫn OID {dk.oid})")
s.cn.rollback()                                         # demo không đổi dữ liệu mẫu
print(f"  rollback → DANGKY còn {s.rows('SELECT COUNT(*) AS n FROM DANGKY')[0]['n']} dòng\n")

# 6. Truy vấn đường dẫn kiểu OQL:  SELECT l.ma_lop FROM GiaoVien g, g.lop_phu_trach l WHERE l.khoa_hoc.ten_kh LIKE 'IELTS%'
in_bang([
    do("OO: duyệt g.lop_phu_trach → l.khoa_hoc (kiểu OQL)",
       lambda s: len([l.ma_lop for g in s.all(NhanVien, "g.LoaiGV IS NOT NULL") for l in g.lop_phu_trach
                      if l.khoa_hoc.ten_kh.startswith("IELTS")])),
    do("SQL: JOIN GIAOVIEN – LOPHOC – KHOAHOC",
       lambda s: len(s.rows("""SELECT l.MaLop FROM GIAOVIEN g JOIN LOPHOC l ON l.MaGV = g.MaGV
                               JOIN KHOAHOC k ON k.MaKH = l.MaKH WHERE k.TenKH LIKE 'IELTS%'"""))),
])

# 7. Ba chiến lược ánh xạ kế thừa NhanVien ← GiaoVien (bảng tạm trong tempdb, kết quả phải như nhau)
s = Session()
s.cn.cursor().execute("""
    DROP TABLE IF EXISTS #ST, #CT_NV, #CT_GV;
    -- (1) Single table: cả cây kế thừa trong 1 bảng + cột phân loại (discriminator)
    SELECT n.MaNV, n.HoTen, n.ChucVu, n.LuongCoBan, CASE WHEN g.MaGV IS NULL THEN 'NV' ELSE 'GV' END AS Loai,
           g.LoaiGV, g.QuocTich, g.TrinhDo, g.DonGiaBuoi
    INTO #ST FROM NHANVIEN n LEFT JOIN GIAOVIEN g ON g.MaGV = n.MaNV;
    -- (3) Concrete table: mỗi lớp cụ thể một bảng, lặp lại toàn bộ cột của lớp cha
    SELECT n.MaNV, n.HoTen, n.ChucVu, n.LuongCoBan INTO #CT_NV FROM NHANVIEN n
    WHERE NOT EXISTS (SELECT 1 FROM GIAOVIEN g WHERE g.MaGV = n.MaNV);
    SELECT n.MaNV, n.HoTen, n.ChucVu, n.LuongCoBan, g.LoaiGV, g.QuocTich, g.TrinhDo, g.DonGiaBuoi INTO #CT_GV
    FROM NHANVIEN n JOIN GIAOVIEN g ON g.MaGV = n.MaNV;""")
q_moi_nv = {   # truy vấn đa hình: mọi nhân viên + đơn giá buổi nếu là giáo viên
    "Single table": "SELECT MaNV, DonGiaBuoi FROM #ST",
    "Joined (ECMS)": "SELECT n.MaNV, g.DonGiaBuoi FROM NHANVIEN n LEFT JOIN GIAOVIEN g ON g.MaGV = n.MaNV",
    "Concrete table": "SELECT MaNV, CAST(NULL AS DECIMAL(10,0)) AS DonGiaBuoi FROM #CT_NV UNION ALL SELECT MaNV, DonGiaBuoi FROM #CT_GV",
}
q_gv = {       # truy vấn lớp con: tổng đơn giá buổi của giáo viên
    "Single table": "SELECT SUM(DonGiaBuoi) AS t FROM #ST WHERE Loai = 'GV'",
    "Joined (ECMS)": "SELECT SUM(g.DonGiaBuoi) AS t FROM NHANVIEN n JOIN GIAOVIEN g ON g.MaGV = n.MaNV",
    "Concrete table": "SELECT SUM(DonGiaBuoi) AS t FROM #CT_GV",
}
o_null = s.rows("SELECT SUM(CASE WHEN LoaiGV IS NULL THEN 4 ELSE 0 END) AS n, COUNT(*) * 4 AS tong FROM #ST")[0]
dac_diem = {"Single table": f"1 bảng; {o_null['n']}/{o_null['tong']} ô cột giáo viên để NULL",
            "Joined (ECMS)": "2 bảng nối bằng khoá; không NULL, không lặp cột",
            "Concrete table": "2 bảng; 4 cột của lớp cha lặp ở cả 2 bảng"}
phep = {"Single table": ("1 bảng, không JOIN", "lọc Loai = 'GV'"), "Joined (ECMS)": ("LEFT JOIN", "JOIN"),
        "Concrete table": ("UNION ALL 2 bảng", "1 bảng")}
mau = sorted((r["MaNV"], r["DonGiaBuoi"]) for r in s.rows(q_moi_nv["Joined (ECMS)"]))
print(f"{'Chiến lược':<17}{'Cấu trúc':<50}{'Mọi nhân viên':<20}{'Chỉ giáo viên':<17}Kết quả")
for k in q_moi_nv:
    ok = sorted((r["MaNV"], r["DonGiaBuoi"]) for r in s.rows(q_moi_nv[k])) == mau
    tong = s.rows(q_gv[k])[0]["t"]
    print(f"{k:<17}{dac_diem[k]:<50}{phep[k][0]:<20}{phep[k][1]:<17}{'✓ giống' if ok else '✗ khác'} "
          f"(tổng đơn giá {float(tong):,.0f})")
