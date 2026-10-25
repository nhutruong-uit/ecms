#!/usr/bin/env python3
"""So sánh SQL Server ↔ MongoDB trên cùng dữ liệu (T27): 6 cặp truy vấn ĐỌC và 3 thao tác GHI.

    python3 nosql/compare.py            # chạy sau nosql/migrate.py
Mỗi phép đo chạy 1 lần khởi động rồi N lần; báo trung vị (median), phân vị 95 (p95) và độ lệch chuẩn – chênh lệch
nhỏ hơn độ lệch chuẩn coi như nằm trong nhiễu đo. Thao tác ghi được hoàn tác sau mỗi lần đo (dữ liệu không đổi).
Các câu MongoDB tương ứng dạng mongosh nằm trong nosql/queries.js.
"""
import statistics
import time
from datetime import datetime

from migrate import mongo_db, so, sql_conn

N = 30
HV = "HV0019"
cn, db = sql_conn(), mongo_db()


def sql(q, *p):
    cur = cn.cursor()
    cur.execute(q, p)
    return [tuple(r) for r in cur.fetchall()]


DOC = []

# 1. Hồ sơ đầy đủ của một học viên: lớp, điểm, số buổi vắng
DOC.append(("1. Hồ sơ học viên kèm lớp, điểm, số buổi vắng",
    lambda: sorted((r[0], float(r[1] or 0), r[2]) for r in sql("""
        SELECT d.MaLop, d.DiemTB, (SELECT COUNT(*) FROM DIEMDANH x WHERE x.MaDK = d.MaDK AND x.TrangThai = N'Vắng')
        FROM HOCVIEN h JOIN DANGKY d ON d.MaHV = h.MaHV JOIN LOPHOC l ON l.MaLop = d.MaLop WHERE h.MaHV = ?""", HV)),
    lambda: sorted((d["lop"], so(d["diem"]["tb"]), sum(1 for x in d["diem_danh"] if x["trang_thai"] == "Vắng"))
                   for d in db.hoc_vien.find_one({"_id": HV})["dang_ky"])))

# 2. Doanh thu theo chi nhánh CỦA LỚP và tháng năm 2026 (cùng chỉ tiêu với vw_DoanhThuThang / báo cáo Chương 4)
DOC.append(("2. Doanh thu theo chi nhánh lớp × tháng 2026",
    lambda: sorted((r[0], r[1], float(r[2])) for r in sql("""
        SELECT l.MaCN, MONTH(p.NgayThu), SUM(c.SoTien) FROM CT_PHIEUTHU c JOIN PHIEUTHU p ON p.MaPT = c.MaPT
        JOIN DANGKY d ON d.MaDK = c.MaDK JOIN LOPHOC l ON l.MaLop = d.MaLop
        WHERE p.NgayThu >= '2026-01-01' AND p.NgayThu < '2027-01-01' GROUP BY l.MaCN, MONTH(p.NgayThu)""")),
    lambda: sorted((r["_id"]["cn"], r["_id"]["thang"], so(r["tong"])) for r in db.phieu_thu.aggregate([
        {"$match": {"ngay_thu": {"$gte": datetime(2026, 1, 1), "$lt": datetime(2027, 1, 1)}}},
        {"$unwind": "$chi_tiet"},
        {"$group": {"_id": {"cn": "$chi_tiet.chi_nhanh", "thang": {"$month": "$ngay_thu"}}, "tong": {"$sum": "$chi_tiet.so_tien"}}}]))))

# 3. Kết quả kiểm tra: Speaking dưới 3 (SQL dùng XQuery trên cột XML, Mongo lọc trực tiếp trường lồng)
DOC.append(("3. Bài kiểm tra có Speaking < 3",
    lambda: sorted(r[0] for r in sql("""SELECT MaHV FROM KIEMTRA_DAUVAO
        WHERE KetQuaChiTiet.exist('/KetQua/KyNang[@Ten="Speaking" and @Diem < 3]') = 1""")),
    lambda: sorted(h["_id"] for h in db.hoc_vien.aggregate([
        {"$unwind": "$kiem_tra"}, {"$match": {"kiem_tra.ky_nang.speaking.diem": {"$lt": 3}}}, {"$project": {"_id": 1}}]))))

# 4. Tỷ lệ vắng của đăng ký đang học, top 10
DOC.append(("4. Top 10 tỷ lệ vắng (đăng ký đang học)",
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
DOC.append(("5. Chuỗi khoá tiên quyết của IE65, TC850",
    lambda: sorted((r[0], r[1]) for r in sql("""
        WITH c AS (SELECT MaKH AS Goc, MaKHTienQuyet AS Can FROM KHOAHOC WHERE MaKH IN ('IE65', 'TC850')
                   UNION ALL SELECT c.Goc, k.MaKHTienQuyet FROM KHOAHOC k JOIN c ON k.MaKH = c.Can)
        SELECT Goc, Can FROM c WHERE Can IS NOT NULL""")),
    lambda: sorted((r["_id"], x["_id"]) for r in db.khoa_hoc.aggregate([
        {"$match": {"_id": {"$in": ["IE65", "TC850"]}}},
        {"$graphLookup": {"from": "khoa_hoc", "startWith": "$tien_quyet", "connectFromField": "tien_quyet",
                          "connectToField": "_id", "as": "chuoi"}}]) for x in r["chuoi"])))

# 6. Lớp đang mở còn chỗ kèm tên khoá (JOIN ↔ $lookup)
DOC.append(("6. Lớp đang mở còn chỗ + tên khoá học",
    lambda: sorted((r[0], r[1], r[2]) for r in sql("""
        SELECT l.MaLop, k.TenKH, l.SiSoToiDa - l.SiSoHienTai FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
        WHERE l.TrangThai IN (N'Sắp mở', N'Đang học') AND l.SiSoHienTai < l.SiSoToiDa""")),
    lambda: sorted((r["_id"], r["kh"]["ten"], r["si_so"]["toi_da"] - r["si_so"]["hien_tai"]) for r in db.lop_hoc.aggregate([
        {"$match": {"trang_thai": {"$in": ["Sắp mở", "Đang học"]}, "$expr": {"$lt": ["$si_so.hien_tai", "$si_so.toi_da"]}}},
        {"$lookup": {"from": "khoa_hoc", "localField": "khoa_hoc", "foreignField": "_id", "as": "kh"}}, {"$unwind": "$kh"}]))))


def do(fn, sau=None):
    """1 lần khởi động + N lần đo; sau(): hoàn tác sau mỗi lần (không tính giờ). Trả (kết quả, [ms…])."""
    fn()
    if sau:
        sau()
    ms = []
    for _ in range(N):
        t = time.perf_counter()
        kq = fn()
        ms.append((time.perf_counter() - t) * 1000)
        if sau:
            sau()
    return kq, ms


def tk(ms):
    q = statistics.quantiles(ms, n=20)
    return statistics.median(ms), q[18], statistics.stdev(ms)       # q[18] = phân vị 95


print(f"{'Thao tác':<48}{'Dòng':>6}{'SQL median':>12}{'p95':>8}{'±σ':>7}{'Mongo median':>14}{'p95':>8}{'±σ':>7}  Giống")
for ten, f_sql, f_mg in DOC:
    a, ms_s = do(f_sql)
    b, ms_m = do(f_mg)
    (m1, p1, s1), (m2, p2, s2) = tk(ms_s), tk(ms_m)
    print(f"{ten:<48}{len(a):>6}{m1:>12.2f}{p1:>8.2f}{s1:>7.2f}{m2:>14.2f}{p2:>8.2f}{s2:>7.2f}  "
          f"{'✓' if a == b else '✗ ' + str(a[:2]) + ' / ' + str(b[:2])}")

# ---------------- GHI: dữ liệu nhúng đọc nhanh nhưng ghi / sửa trùng lặp có giá
print()
hv = db.hoc_vien.find_one({"_id": HV})
dk = next(d for d in hv["dang_ky"] if d["diem_danh"])
buoi = dk["diem_danh"][0]
lop = sql("SELECT MaLop FROM DANGKY WHERE MaDK = ?", dk["ma_dk"])[0][0]
# Giá trị gốc lấy từ SQL Server (phía SQL luôn ROLLBACK nên là nguồn đúng): nếu lần chạy trước bị ngắt giữa chừng,
# bản MongoDB có thể đang lệch – hoàn tác bằng giá trị đọc từ MongoDB sẽ giữ nguyên chỗ lệch đó
buoi["trang_thai"] = sql("SELECT TrangThai FROM DIEMDANH WHERE MaDK = ? AND MaLop = ? AND STT = ?",
                         dk["ma_dk"], lop, buoi["buoi"])[0][0]
cur = cn.cursor()


def sql_diem_danh():
    cur.execute("UPDATE DIEMDANH SET TrangThai = N'Có phép' WHERE MaDK = ? AND MaLop = ? AND STT = ?", dk["ma_dk"], lop, buoi["buoi"])
    n = cur.rowcount
    cn.rollback()
    return n


def mg_diem_danh():
    r = db.hoc_vien.update_one({"_id": HV}, {"$set": {"dang_ky.$[d].diem_danh.$[b].trang_thai": "Có phép"}},
                               array_filters=[{"d.ma_dk": dk["ma_dk"]}, {"b.buoi": buoi["buoi"]}])
    return r.modified_count


def mg_hoan_diem_danh():
    db.hoc_vien.update_one({"_id": HV}, {"$set": {"dang_ky.$[d].diem_danh.$[b].trang_thai": buoi["trang_thai"]}},
                           array_filters=[{"d.ma_dk": dk["ma_dk"]}, {"b.buoi": buoi["buoi"]}])


lop_mo = sql("""SELECT TOP 1 l.MaLop, k.HocPhi FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH
                WHERE l.TrangThai = N'Sắp mở' AND l.SiSoHienTai < l.SiSoToiDa
                  AND NOT EXISTS (SELECT 1 FROM DANGKY d WHERE d.MaLop = l.MaLop AND d.MaHV = ?) ORDER BY l.MaLop""", HV)[0]


def sql_ghi_danh():
    # INSERT kích hoạt các trigger kiểm tra sĩ số, cập nhật sĩ số, nhật ký – chi phí của toàn vẹn dữ liệu
    cur.execute("INSERT DANGKY (MaHV, MaLop, HocPhi, GiamGia) VALUES (?, ?, ?, 0)", HV, lop_mo[0], lop_mo[1])
    n = cur.rowcount
    cn.rollback()
    return n


def mg_ghi_danh():
    # chỉ thêm phần tử vào mảng nhúng – sĩ số lop_hoc.si_so phải tự cập nhật ở bước khác (không có trigger)
    r = db.hoc_vien.update_one({"_id": HV}, {"$push": {"dang_ky": {
        "ma_dk": -1, "lop": lop_mo[0], "hoc_phi": {"thanh_tien": hv["dang_ky"][0]["hoc_phi"]["thanh_tien"],
                                                   "da_thu": hv["dang_ky"][0]["hoc_phi"]["da_thu"]},
        "trang_thai": "Đang học", "diem_danh": []}}})
    return r.modified_count


def mg_hoan_ghi_danh():
    db.hoc_vien.update_one({"_id": HV}, {"$pull": {"dang_ky": {"ma_dk": -1}}})


gv = sql("SELECT TOP 1 l.MaGV, COUNT(*) FROM LOPHOC l GROUP BY l.MaGV ORDER BY COUNT(*) DESC, l.MaGV")[0]
# tên gốc lấy từ SQL Server (nguồn của migrate.py), như W1: đọc từ MongoDB thì lần chạy trước bị ngắt giữa chừng
# để lại tên có dấu cách thừa, lần sau "hoàn tác" về chính tên sai đó và cứ thế lệch dần
ten_cu = sql("SELECT HoTen FROM NHANVIEN WHERE MaNV = ?", gv[0])[0][0]


def sql_doi_ten():
    cur.execute("UPDATE NHANVIEN SET TenNV = TenNV + N' ' WHERE MaNV = ?", gv[0])   # 1 dòng – tên chỉ lưu một nơi
    n = cur.rowcount
    cn.rollback()
    return n


def mg_doi_ten():
    # tên giáo viên được nhúng (sao chép) vào mọi lớp người đó dạy → phải sửa nhiều document
    return db.lop_hoc.update_many({"giao_vien.ma": gv[0]}, {"$set": {"giao_vien.ho_ten": ten_cu + " "}}).modified_count


def mg_hoan_doi_ten():
    db.lop_hoc.update_many({"giao_vien.ma": gv[0]}, {"$set": {"giao_vien.ho_ten": ten_cu}})


GHI = [("W1. Sửa điểm danh 1 buổi của 1 học viên", sql_diem_danh, None, mg_diem_danh, mg_hoan_diem_danh),
       ("W2. Ghi danh thêm 1 lớp", sql_ghi_danh, None, mg_ghi_danh, mg_hoan_ghi_danh),
       (f"W3. Đổi họ tên giáo viên {gv[0]} (dạy {gv[1]} lớp)", sql_doi_ten, None, mg_doi_ten, mg_hoan_doi_ten)]
print(f"{'Thao tác ghi':<48}{'Sửa':>6}{'SQL median':>12}{'p95':>8}{'±σ':>7}{'Mongo median':>14}{'p95':>8}{'±σ':>7}  Số document Mongo")
for ten, f_sql, h_sql, f_mg, h_mg in GHI:
    a, ms_s = do(f_sql, h_sql)
    b, ms_m = do(f_mg, h_mg)
    (m1, p1, s1), (m2, p2, s2) = tk(ms_s), tk(ms_m)
    print(f"{ten:<48}{a:>6}{m1:>12.2f}{p1:>8.2f}{s1:>7.2f}{m2:>14.2f}{p2:>8.2f}{s2:>7.2f}  {b}")
