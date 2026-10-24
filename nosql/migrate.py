#!/usr/bin/env python3
"""Chuyển dữ liệu ECMS từ SQL Server sang MongoDB (T27).

    pip install pymongo
    python3 nosql/migrate.py                     # MONGO_URI mặc định mongodb://localhost:27017

Thiết kế document (nhúng hay tham chiếu – xem report mục 5.3):
  khoa_hoc   : danh mục nhỏ; tien_quyet tham chiếu _id khoá khác (đồ thị tiên quyết)
  lop_hoc    : NHÚNG lich (thứ – ca – phòng), giao_vien (bản tóm tắt); THAM CHIẾU khoa_hoc
  hoc_vien   : NHÚNG dia_chi, kiem_tra[] (kết quả 4 kỹ năng – vốn là XML bán cấu trúc),
               dang_ky[] (điểm, học phí, diem_danh[] từng buổi) → đọc hồ sơ học viên bằng 1 truy vấn
  phieu_thu  : NHÚNG chi_tiet[] (master–detail, mỗi dòng ghi chi nhánh của LỚP để tính doanh thu như vw_DoanhThuThang);
               THAM CHIẾU hoc_vien
Chuyển 14 bảng nghiệp vụ thành 4 collection; 8 bảng còn lại (CHINHANH, PHONGHOC, CHUNGCHI_GV, NGAYLE, TAIKHOAN,
NHATKY, CANHBAO_CHUYENCAN, BANGLUONG) là danh mục / hệ thống / kết quả tính toán – giữ ở SQL Server.
Tiền lưu Decimal128 (không dùng double: 0,1 + 0,2 ≠ 0,3). $jsonSchema kiểm tra cấu trúc document khi ghi.
"""
import os
import sys
import time
from collections import defaultdict
from datetime import date, datetime, time as dtime
from decimal import Decimal
from pathlib import Path

import pyodbc
from dotenv import load_dotenv
from bson.decimal128 import Decimal128
from pymongo import ASCENDING, MongoClient

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")


def sql_conn():
    mk = os.getenv("SA_PASSWORD")
    if not mk:
        sys.exit("Thiếu SA_PASSWORD trong .env (xem .env.example).")
    port = os.getenv("DB_PORT", "1433").strip()
    server = os.getenv("DB_SERVER", "localhost") + (f",{port}" if port else "")
    return pyodbc.connect(f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};SERVER={server};"
                          f"DATABASE=ECMS;UID=sa;PWD={mk};Encrypt=yes;TrustServerCertificate=yes")


def mongo_db():
    """MONGO_URI trong .env (có tài khoản – nosql/docker-compose.yml bật xác thực)."""
    uri = os.getenv("MONGO_URI")
    if not uri:
        sys.exit("Thiếu MONGO_URI trong .env (xem .env.example).")
    return MongoClient(uri)["ecms"]


def so(v) -> float:
    """Decimal128 / int / float → float để so sánh, in kết quả."""
    return float(v.to_decimal()) if isinstance(v, Decimal128) else float(v or 0)


def conv(v):
    """Kiểu SQL → kiểu BSON. DECIMAL → Decimal128 (giữ đúng tiền đồng, không sai số dấu phẩy động)."""
    if isinstance(v, Decimal):
        return Decimal128(v)
    if isinstance(v, date) and not isinstance(v, datetime):
        return datetime(v.year, v.month, v.day)
    if isinstance(v, dtime):
        return v.strftime("%H:%M")
    return v


def rows(cn, sql):
    cur = cn.cursor()
    cur.execute(sql)
    cols = [c[0] for c in cur.description]
    return [{k: conv(v) for k, v in zip(cols, r)} for r in cur.fetchall()]


def main():
    t0 = time.perf_counter()
    cn, db = sql_conn(), mongo_db()
    for c in ("khoa_hoc", "lop_hoc", "hoc_vien", "phieu_thu"):
        db[c].drop()
    # $jsonSchema: MongoDB không có khoá ngoại / CHECK, nhưng kiểm tra được cấu trúc và kiểu khi ghi
    tien = {"bsonType": "decimal"}
    db.create_collection("hoc_vien", validator={"$jsonSchema": {
        "bsonType": "object", "required": ["_id", "ho_ten", "sdt", "chi_nhanh", "dang_ky"],
        "properties": {
            "_id": {"bsonType": "string", "pattern": "^HV[0-9]{4}$"},
            "ho_ten": {"bsonType": "object", "required": ["ho", "ten"]},
            "sdt": {"bsonType": "string", "pattern": "^[0-9]{9,11}$"},
            "chi_nhanh": {"enum": ["CN01", "CN02", "CN03"]},
            "dang_ky": {"bsonType": "array", "items": {
                "bsonType": "object", "required": ["ma_dk", "lop", "hoc_phi", "trang_thai"],
                "properties": {"hoc_phi": {"bsonType": "object", "required": ["thanh_tien", "da_thu"],
                                           "properties": {"thanh_tien": tien, "da_thu": tien}},
                               "diem_danh": {"bsonType": "array", "items": {
                                   "bsonType": "object", "required": ["buoi", "trang_thai"],
                                   "properties": {"trang_thai": {"enum": ["Có mặt", "Vắng", "Muộn", "Có phép"]}}}}}}}}}})
    db.create_collection("phieu_thu", validator={"$jsonSchema": {
        "bsonType": "object", "required": ["_id", "hoc_vien", "ngay_thu", "tong_tien", "chi_tiet"],
        "properties": {"tong_tien": tien, "chi_tiet": {"bsonType": "array", "minItems": 1, "items": {
            "bsonType": "object", "required": ["ma_dk", "so_tien", "chi_nhanh"], "properties": {"so_tien": tien}}}}}})

    # ---------------- khoa_hoc
    kh = rows(cn, "SELECT k.*, ct.TenCT FROM KHOAHOC k JOIN CHUONGTRINH ct ON ct.MaCT = k.MaCT")
    db.khoa_hoc.insert_many([{
        "_id": r["MaKH"], "ten": r["TenKH"], "chuong_trinh": {"ma": r["MaCT"], "ten": r["TenCT"]}, "cap_do": r["CapDo"],
        "diem_dau_vao": {"tu": r["DiemDauVaoTu"], "den": r["DiemDauVaoDen"]}, "dau_ra": r["MucTieuDauRa"],
        "so_buoi": r["SoBuoi"], "hoc_phi": r["HocPhi"], "tien_quyet": r["MaKHTienQuyet"]} for r in kh])

    # ---------------- lop_hoc (nhúng lịch, giáo viên tóm tắt)
    lich = defaultdict(list)
    for r in rows(cn, "SELECT lh.*, c.TenCa, c.GioBatDau, c.GioKetThuc FROM LICHHOC lh JOIN CAHOC c ON c.MaCa = lh.MaCa"):
        lich[r["MaLop"]].append({"thu": r["Thu"], "ca": r["TenCa"], "gio": f"{r['GioBatDau']}–{r['GioKetThuc']}", "phong": r["MaPhong"]})
    lop = rows(cn, "SELECT l.*, n.HoTen AS TenGV, g.LoaiGV FROM LOPHOC l JOIN NHANVIEN n ON n.MaNV = l.MaGV JOIN GIAOVIEN g ON g.MaGV = l.MaGV")
    db.lop_hoc.insert_many([{
        "_id": r["MaLop"], "ten": r["TenLop"], "khoa_hoc": r["MaKH"], "chi_nhanh": r["MaCN"],
        "giao_vien": {"ma": r["MaGV"], "ho_ten": r["TenGV"], "loai": r["LoaiGV"]},
        "khai_giang": r["NgayKhaiGiang"], "ket_thuc": r["NgayKetThuc"], "si_so": {"toi_da": r["SiSoToiDa"], "hien_tai": r["SiSoHienTai"]},
        "trang_thai": r["TrangThai"], "lich": lich[r["MaLop"]]} for r in lop])

    # ---------------- hoc_vien (nhúng kiểm tra, đăng ký, điểm danh)
    dd = defaultdict(list)
    for r in rows(cn, "SELECT d.MaDK, d.STT, d.TrangThai, b.NgayHoc FROM DIEMDANH d JOIN BUOIHOC b ON b.MaLop = d.MaLop AND b.STT = d.STT"):
        dd[r["MaDK"]].append({"buoi": r["STT"], "ngay": r["NgayHoc"], "trang_thai": r["TrangThai"]})
    da_thu = {r["MaDK"]: r["DaThu"] for r in rows(cn, "SELECT MaDK, SUM(SoTien) AS DaThu FROM CT_PHIEUTHU GROUP BY MaDK")}
    dk = defaultdict(list)
    for r in rows(cn, "SELECT d.*, l.MaKH, l.MaCN AS CNLop FROM DANGKY d JOIN LOPHOC l ON l.MaLop = d.MaLop"):
        dk[r["MaHV"]].append({
            "ma_dk": r["MaDK"], "lop": r["MaLop"], "khoa_hoc": r["MaKH"], "chi_nhanh": r["CNLop"], "ngay_dk": r["NgayDK"],
            "hoc_phi": {"goc": r["HocPhi"], "giam_gia": r["GiamGia"], "thanh_tien": r["ThanhTien"],
                        "da_thu": da_thu.get(r["MaDK"], Decimal128("0")),
                        "trang_thai": r["TrangThaiHP"]},
            "diem": {"gk": r["DiemGK"], "ck": r["DiemCK"], "tb": r["DiemTB"]}, "ket_qua": r["KetQua"], "trang_thai": r["TrangThai"],
            "diem_danh": sorted(dd[r["MaDK"]], key=lambda x: x["buoi"])})
    kt = defaultdict(list)
    for r in rows(cn, """SELECT t.MaKT, t.MaHV, t.NgayKT, t.DiemTong, t.MaKHDeXuat,
                                t.KetQuaChiTiet.value('(/KetQua/@HinhThuc)[1]', 'NVARCHAR(20)') AS HinhThuc,
                                CAST(t.KetQuaChiTiet AS NVARCHAR(MAX)) AS X FROM KIEMTRA_DAUVAO t"""):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(r["X"])
        kt[r["MaHV"]].append({"ngay": r["NgayKT"], "hinh_thuc": r["HinhThuc"], "diem_tong": r["DiemTong"], "de_xuat": r["MaKHDeXuat"],
                              "ky_nang": {k.get("Ten").lower(): {"diem": float(k.get("Diem")), "nhan_xet": k.findtext("NhanXet")}
                                          for k in root.findall("KyNang")},
                              "nhan_xet_chung": root.findtext("NhanXetChung")})
    hv = rows(cn, "SELECT * FROM HOCVIEN")
    db.hoc_vien.insert_many([{
        "_id": r["MaHV"], "ho_ten": {"ho": r["HoHV"], "ten": r["TenHV"]}, "ngay_sinh": r["NgaySinh"], "gioi_tinh": r["GioiTinh"],
        "sdt": r["SoDienThoai"], "email": r["Email"],
        "dia_chi": {"so_nha": r["SoNha"], "phuong": r["PhuongXa"], "quan": r["QuanHuyen"], "tinh": r["TinhTP"]},
        "phu_huynh": r["HoTenPhuHuynh"], "chi_nhanh": r["MaCN"], "ngay_tao": r["NgayTao"],
        "kiem_tra": kt[r["MaHV"]], "dang_ky": dk[r["MaHV"]]} for r in hv])

    # ---------------- phieu_thu (master–detail nhúng)
    ct = defaultdict(list)
    for r in rows(cn, """SELECT c.MaPT, c.MaDK, c.SoTien, d.MaLop, l.MaCN FROM CT_PHIEUTHU c
                         JOIN DANGKY d ON d.MaDK = c.MaDK JOIN LOPHOC l ON l.MaLop = d.MaLop"""):
        ct[r["MaPT"]].append({"ma_dk": r["MaDK"], "lop": r["MaLop"], "chi_nhanh": r["MaCN"], "so_tien": r["SoTien"]})
    pt = rows(cn, "SELECT p.*, n.MaCN FROM PHIEUTHU p JOIN NHANVIEN n ON n.MaNV = p.MaNV")
    db.phieu_thu.insert_many([{
        "_id": r["SoPhieu"], "hoc_vien": r["MaHV"], "nguoi_lap": r["MaNV"], "chi_nhanh_lap": r["MaCN"], "ngay_thu": r["NgayThu"],
        "hinh_thuc": r["HinhThuc"], "tong_tien": r["TongTien"], "chi_tiet": ct[r["MaPT"]]} for r in pt])

    # ---------------- chỉ mục
    db.hoc_vien.create_index([("sdt", ASCENDING)])
    db.hoc_vien.create_index([("dang_ky.lop", ASCENDING)])
    db.phieu_thu.create_index([("ngay_thu", ASCENDING)])
    db.lop_hoc.create_index([("chi_nhanh", ASCENDING), ("trang_thai", ASCENDING)])

    # ---------------- đối chiếu số lượng
    kiem = [("khoa_hoc", "KHOAHOC", db.khoa_hoc.count_documents({})), ("lop_hoc", "LOPHOC", db.lop_hoc.count_documents({})),
            ("hoc_vien", "HOCVIEN", db.hoc_vien.count_documents({})), ("phieu_thu", "PHIEUTHU", db.phieu_thu.count_documents({})),
            ("hoc_vien.dang_ky[]", "DANGKY", next(db.hoc_vien.aggregate([{"$project": {"n": {"$size": "$dang_ky"}}},
                                                                          {"$group": {"_id": None, "s": {"$sum": "$n"}}}]))["s"]),
            ("hoc_vien.dang_ky[].diem_danh[]", "DIEMDANH", next(db.hoc_vien.aggregate([
                {"$unwind": "$dang_ky"}, {"$project": {"n": {"$size": "$dang_ky.diem_danh"}}},
                {"$group": {"_id": None, "s": {"$sum": "$n"}}}]))["s"]),
            ("hoc_vien.kiem_tra[]", "KIEMTRA_DAUVAO", next(db.hoc_vien.aggregate([{"$project": {"n": {"$size": "$kiem_tra"}}},
                                                                                {"$group": {"_id": None, "s": {"$sum": "$n"}}}]))["s"]),
            ("phieu_thu.chi_tiet[]", "CT_PHIEUTHU", next(db.phieu_thu.aggregate([{"$project": {"n": {"$size": "$chi_tiet"}}},
                                                                                {"$group": {"_id": None, "s": {"$sum": "$n"}}}]))["s"])]
    cur = cn.cursor()
    print(f"{'MongoDB':<34}{'SQL Server':<16}{'Mongo':>8}{'SQL':>8}")
    ok = True
    for m, s_, n in kiem:
        so = cur.execute(f"SELECT COUNT(*) FROM {s_}").fetchone()[0]
        ok &= so == n
        print(f"{m:<34}{s_:<16}{n:>8}{so:>8}  {'✓' if so == n else '✗'}")
    size = db.command("dbstats")["dataSize"] / 1024
    print(f"→ {'Đầy đủ' if ok else 'THIẾU DỮ LIỆU'} · {size:,.0f} KB dữ liệu BSON · {time.perf_counter() - t0:.1f} s")
    # $jsonSchema chặn document sai cấu trúc (số điện thoại chữ, trạng thái điểm danh lạ, thiếu trường bắt buộc)
    from pymongo.errors import WriteError
    for mo_ta, doc in [("SĐT có chữ", {"_id": "HV9999", "ho_ten": {"ho": "A", "ten": "B"}, "sdt": "09ab", "chi_nhanh": "CN01", "dang_ky": []}),
                       ("thiếu chi_nhanh", {"_id": "HV9998", "ho_ten": {"ho": "A", "ten": "B"}, "sdt": "0901234567", "dang_ky": []})]:
        try:
            db.hoc_vien.insert_one(doc)
            db.hoc_vien.delete_one({"_id": doc["_id"]})
            print(f"  $jsonSchema – {mo_ta}: KHÔNG chặn")
        except WriteError as e:
            print(f"  $jsonSchema – {mo_ta}: bị chặn (mã {e.code} Document failed validation)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
