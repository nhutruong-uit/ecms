#!/usr/bin/env python3
"""So sánh 6 cặp truy vấn tương đương SQL Server ↔ MongoDB: kết quả và thời gian (T27).

    python3 nosql/compare.py            # chạy sau nosql/migrate.py; mỗi truy vấn đo trung bình 20 lần
Các câu MongoDB tương ứng dạng mongosh nằm trong nosql/queries.js.
"""
import time
from datetime import datetime

from migrate import mongo_db, sql_conn

N = 20
HV = "HV0019"
cn, db = sql_conn(), mongo_db()


def sql(q, *p):
    cur = cn.cursor()
    cur.execute(q, p)
    return [tuple(r) for r in cur.fetchall()]


CAP = []

# 1. Hồ sơ đầy đủ của một học viên: lớp, điểm, số buổi vắng
CAP.append(("1. Hồ sơ học viên kèm lớp, điểm, số buổi vắng",
    lambda: sorted((r[0], float(r[1] or 0), r[2]) for r in sql("""
        SELECT d.MaLop, d.DiemTB, (SELECT COUNT(*) FROM DIEMDANH x WHERE x.MaDK = d.MaDK AND x.TrangThai = N'Vắng')
        FROM HOCVIEN h JOIN DANGKY d ON d.MaHV = h.MaHV JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE h.MaHV = ?""", HV)),
    lambda: sorted((d["lop"], float(d["diem"]["tb"] or 0), sum(1 for x in d["diem_danh"] if x["trang_thai"] == "Vắng"))
                   for d in db.hoc_vien.find_one({"_id": HV})["dang_ky"])))

# 2. Doanh thu theo chi nhánh (người lập phiếu) và tháng năm 2026
CAP.append(("2. Doanh thu theo chi nhánh × tháng 2026",
    lambda: sorted((r[0], r[1], float(r[2])) for r in sql("""
        SELECT n.MaCN, MONTH(p.NgayThu), SUM(p.TongTien) FROM PHIEUTHU p JOIN NHANVIEN n ON n.MaNV = p.MaNV
        WHERE YEAR(p.NgayThu) = 2026 GROUP BY n.MaCN, MONTH(p.NgayThu)""")),
    lambda: sorted((r["_id"]["cn"], r["_id"]["thang"], float(r["tong"])) for r in db.phieu_thu.aggregate([
        {"$match": {"ngay_thu": {"$gte": datetime(2026, 1, 1), "$lt": datetime(2027, 1, 1)}}},
        {"$group": {"_id": {"cn": "$chi_nhanh", "thang": {"$month": "$ngay_thu"}}, "tong": {"$sum": "$tong_tien"}}}]))))

# 3. Kết quả kiểm tra: Speaking dưới 3 (SQL dùng XQuery trên cột XML, Mongo lọc trực tiếp trường lồng)
CAP.append(("3. Bài kiểm tra có Speaking < 3",
    lambda: sorted(r[0] for r in sql("""SELECT MaHV FROM KIEMTRA_DAUVAO
        WHERE KetQuaChiTiet.exist('/KetQua/KyNang[@Ten="Speaking" and @Diem < 3]') = 1""")),
    lambda: sorted(h["_id"] for h in db.hoc_vien.aggregate([
        {"$unwind": "$kiem_tra"}, {"$match": {"kiem_tra.ky_nang.speaking.diem": {"$lt": 3}}}, {"$project": {"_id": 1}}]))))

# 4. Tỷ lệ vắng của đăng ký đang học, top 10
CAP.append(("4. Top 10 tỷ lệ vắng (đăng ký đang học)",
    lambda: [(r[0], round(float(r[1]), 4)) for r in sql("""
        SELECT TOP 10 d.MaDK, 1.0 * SUM(CASE WHEN x.TrangThai = N'Vắng' THEN 1 ELSE 0 END) / COUNT(*) AS TyLe
        FROM DANGKY d JOIN DIEMDANH x ON x.MaDK = d.MaDK WHERE d.TrangThai = N'Đang học'
        GROUP BY d.MaDK ORDER BY TyLe DESC, d.MaDK""")],
    lambda: [(r["_id"], round(r["ty_le"], 4)) for r in db.hoc_vien.aggregate([
        {"$unwind": "$dang_ky"}, {"$match": {"dang_ky.trang_thai": "Đang học", "dang_ky.diem_danh.0": {"$exists": True}}},
        {"$project": {"_id": "$dang_ky.ma_dk", "ty_le": {"$divide": [
            {"$size": {"$filter": {"input": "$dang_ky.diem_danh", "cond": {"$eq": ["$$this.trang_thai", "Vắng"]}}}},
            {"$size": "$dang_ky.diem_danh"}]}}},
        {"$sort": {"ty_le": -1, "_id": 1}}, {"$limit": 10}])]))

# 5. Lộ trình tiên quyết (đồ thị): CTE đệ quy ↔ $graphLookup
CAP.append(("5. Chuỗi khoá tiên quyết của IE65, TC850",
    lambda: sorted((r[0], r[1]) for r in sql("""
        WITH c AS (SELECT MaKH AS Goc, MaKHTienQuyet AS Can FROM KHOAHOC WHERE MaKH IN ('IE65', 'TC850')
                   UNION ALL SELECT c.Goc, k.MaKHTienQuyet FROM KHOAHOC k JOIN c ON k.MaKH = c.Can)
        SELECT Goc, Can FROM c WHERE Can IS NOT NULL""")),
    lambda: sorted((r["_id"], x["_id"]) for r in db.khoa_hoc.aggregate([
        {"$match": {"_id": {"$in": ["IE65", "TC850"]}}},
        {"$graphLookup": {"from": "khoa_hoc", "startWith": "$tien_quyet", "connectFromField": "tien_quyet",
                          "connectToField": "_id", "as": "chuoi"}}]) for x in r["chuoi"])))

# 6. Lớp đang mở còn chỗ kèm tên khoá (JOIN ↔ $lookup)
CAP.append(("6. Lớp đang mở còn chỗ + tên khoá học",
    lambda: sorted((r[0], r[1], r[2]) for r in sql("""
        SELECT l.MaLop, k.TenKH, l.SiSoToiDa - l.SiSoHienTai FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
        WHERE l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoHienTai < l.SiSoToiDa""")),
    lambda: sorted((r["_id"], r["kh"]["ten"], r["si_so"]["toi_da"] - r["si_so"]["hien_tai"]) for r in db.lop_hoc.aggregate([
        {"$match": {"trang_thai": {"$in": ["Sắp mở", "Đang học"]}, "$expr": {"$lt": ["$si_so.hien_tai", "$si_so.toi_da"]}}},
        {"$lookup": {"from": "khoa_hoc", "localField": "khoa_hoc", "foreignField": "_id", "as": "kh"}}, {"$unwind": "$kh"}]))))


def do(fn):
    fn()                                           # chạy khởi động (nạp cache, kế hoạch thực thi)
    t = time.perf_counter()
    for _ in range(N):
        kq = fn()
    return kq, (time.perf_counter() - t) * 1000 / N


print(f"{'Truy vấn':<46}{'Dòng':>6}{'SQL (ms)':>10}{'Mongo (ms)':>12}  Giống nhau")
for ten, f_sql, f_mg in CAP:
    a, ts = do(f_sql)
    b, tm = do(f_mg)
    print(f"{ten:<46}{len(a):>6}{ts:>10.2f}{tm:>12.2f}  {'✓' if a == b else '✗ ' + str(a[:2]) + ' / ' + str(b[:2])}")
