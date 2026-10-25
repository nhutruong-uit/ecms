"""Minh hoạ mô hình hướng đối tượng của ECMS bằng Python (T25).

Ánh xạ bảng → lớp theo lược đồ ODL (docs/design/odl-schema.md):
  - OID: Session cấp cho mỗi đối tượng một định danh hệ thống (bộ đếm tăng dần) khi đối tượng xuất hiện lần đầu –
    người dùng không đặt được, không đổi suốt vòng đời, không phụ thuộc giá trị thuộc tính (đổi họ tên, đổi số điện
    thoại… OID vẫn giữ nguyên). Khoá chính quan hệ (MaHV, MaNV…) chỉ còn là thuộc tính nghiệp vụ để tìm đối tượng.
  - identity map theo LỚP GỐC của cây kế thừa: cùng một nhân viên dù lấy qua NhanVien hay GiaoVien vẫn là MỘT đối tượng
  - relationship được nạp *lười* (lazy) khi truy cập lần đầu, quan hệ ngược (inverse) dùng chung đối tượng
  - kế thừa: GiaoVien(NhanVien(Nguoi)), đa hình qua phương thức tinh_luong()
  - đóng gói: thay đổi trạng thái qua phương thức có kiểm tra bất biến (LopHoc.ghi_danh, DangKy.dat_giam_gia)
  - đối tượng bền (persistent): Session.them() + Session.luu() ghi đối tượng mới / đã sửa xuống CSDL

Kết nối bằng tài khoản quản trị trong .env (SA_PASSWORD). demo.py ghi trong transaction rồi rollback.
"""
from __future__ import annotations

import itertools
import os
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import pyodbc
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


class LoiNghiepVu(Exception):
    """Vi phạm bất biến của đối tượng (vd. lớp đã đủ sĩ số) – kiểm tra ngay trong phương thức, không chờ trigger."""


def ket_noi() -> pyodbc.Connection:
    """sa + SA_PASSWORD; SA_TRUSTED=yes → Windows Authentication (máy Windows tắt login sa)."""
    if os.getenv("SA_TRUSTED", "no").strip().lower() in ("1", "yes", "true"):
        xac_thuc = "Trusted_Connection=yes"
    else:
        mk = os.getenv("SA_PASSWORD")
        if not mk:
            raise SystemExit("Thiếu SA_PASSWORD trong .env (xem .env.example).")
        xac_thuc = f"UID=sa;PWD={mk}"
    port = os.getenv("DB_PORT", "1433").strip()
    server = os.getenv("DB_SERVER", "localhost") + (f",{port}" if port else "")
    return pyodbc.connect(f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};SERVER={server};"
                          f"DATABASE=ECMS;{xac_thuc};Encrypt=yes;TrustServerCertificate=yes", autocommit=False)


class Session:
    """Kết nối + bảng đối tượng (OID → đối tượng) + identity map + đếm số câu truy vấn (để thấy vấn đề N+1)."""

    _oid = itertools.count(1)                         # nguồn OID chung: hệ thống cấp, không bao giờ dùng lại

    def __init__(self):
        self.cn = ket_noi()
        self.identity: dict[tuple, object] = {}       # (lớp gốc, khoá nghiệp vụ) → đối tượng
        self.objects: dict[int, object] = {}          # OID → đối tượng (bảng đối tượng của "CSDL hướng đối tượng")
        self.moi: list[object] = []                   # đối tượng mới chờ ghi
        self.so_truy_van = 0

    def cap_oid(self, obj) -> object:
        object.__setattr__(obj, "_oid", next(Session._oid))
        self.objects[obj.oid] = obj
        return obj

    def rows(self, sql: str, *params):
        self.so_truy_van += 1
        cur = self.cn.cursor()
        cur.execute(sql, params)
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

    def get(self, cls, key, row: dict | None = None):
        """Lấy đối tượng theo khoá nghiệp vụ; đã có trong identity map thì trả lại ĐÚNG đối tượng đó (cùng OID).
        Khoá map theo lớp gốc (cls.ROOT) nên get(GiaoVien, x) và get(NhanVien, x) là cùng một đối tượng."""
        k = (getattr(cls, "ROOT", cls).__name__, key)
        if k not in self.identity:
            if row is None:
                found = self.rows(cls.SQL_ONE, key)
                if not found:
                    return None
                row = found[0]
            obj = self.cap_oid(cls.from_row(self, row))
            self.identity[k] = obj
        return self.identity[k]

    def them(self, obj):
        """Đối tượng mới tạo trong bộ nhớ → có OID ngay, chờ luu() để thành đối tượng bền."""
        self.moi.append(self.cap_oid(obj))
        return obj

    def luu(self) -> int:
        """Ghi các đối tượng mới xuống CSDL (đối tượng tự biết cách lưu – phương thức _luu trả khoá CSDL vừa sinh);
        trả số đối tượng đã ghi. Đối tượng đã lưu được đưa vào identity map: get() theo khoá mới trả ĐÚNG đối tượng này."""
        n = 0
        for obj in self.moi:
            khoa = obj._luu(self.cn.cursor())
            self.identity[(getattr(type(obj), "ROOT", type(obj)).__name__, khoa)] = obj
            n += 1
        self.moi.clear()
        return n

    def all(self, cls, where: str = "", *params):
        return [self.get(cls, r[cls.KEY], r) for r in self.rows(cls.SQL_ALL + (" WHERE " + where if where else ""), *params)]


class CoOID:
    """Mixin: OID chỉ đọc – gán một lần bởi Session.cap_oid(), không có setter."""

    @property
    def oid(self) -> int | None:
        return self.__dict__.get("_oid")


@dataclass(eq=False)
class Nguoi(CoOID):
    """Lớp trừu tượng: thuộc tính và phương thức chung của học viên và nhân viên."""
    ho: str
    ten: str
    ngay_sinh: date

    def ho_ten(self) -> str:
        return f"{self.ho} {self.ten}"

    def tuoi(self, ngay: date | None = None) -> int:
        d = ngay or date.today()
        return d.year - self.ngay_sinh.year - ((d.month, d.day) < (self.ngay_sinh.month, self.ngay_sinh.day))


@dataclass(eq=False)
class NhanVien(Nguoi):
    ma_nv: str = ""
    chuc_vu: str = ""
    luong_co_ban: float = 0
    _s: Session = field(default=None, repr=False)
    KEY = "MaNV"
    SQL_ALL = "SELECT n.*, g.LoaiGV, g.DonGiaBuoi FROM NHANVIEN n LEFT JOIN GIAOVIEN g ON g.MaGV = n.MaNV"
    SQL_ONE = SQL_ALL + " WHERE n.MaNV = ?"

    @classmethod
    def from_row(cls, s, r):
        if r.get("LoaiGV"):                      # chuyên biệt hoá: dòng có phần GIAOVIEN → đối tượng GiaoVien
            return GiaoVien(r["HoNV"], r["TenNV"], r["NgaySinh"], r["MaNV"], r["ChucVu"], float(r["LuongCoBan"]), s,
                            loai_gv=r["LoaiGV"], don_gia_buoi=float(r["DonGiaBuoi"]))
        return cls(r["HoNV"], r["TenNV"], r["NgaySinh"], r["MaNV"], r["ChucVu"], float(r["LuongCoBan"]), s)

    def tinh_luong(self, thang: str) -> float:
        return self.luong_co_ban


NhanVien.ROOT = NhanVien


@dataclass(eq=False)
class GiaoVien(NhanVien):
    loai_gv: str = ""
    don_gia_buoi: float = 0

    @property
    def lop_phu_trach(self) -> list[LopHoc]:          # relationship Set<LopHoc> (lazy)
        return self._s.all(LopHoc, "l.MaGV = ?", self.ma_nv)

    def tinh_luong(self, thang: str) -> float:        # đa hình: ghi đè cách tính của NhanVien
        tu = date.fromisoformat(thang + "-01")
        den = date(tu.year + tu.month // 12, tu.month % 12 + 1, 1)
        so_buoi = self._s.rows("""SELECT COUNT(*) AS n FROM BUOIHOC b JOIN LOPHOC l ON l.MaLop = b.MaLop
                                  WHERE COALESCE(b.MaGVDay, l.MaGV) = ? AND b.TrangThai = N'Đã dạy'
                                    AND b.NgayHoc >= ? AND b.NgayHoc < ?""", self.ma_nv, tu, den)[0]["n"]
        return self.luong_co_ban + so_buoi * self.don_gia_buoi


@dataclass(eq=False)
class KhoaHoc(CoOID):
    ma_kh: str
    ten_kh: str
    hoc_phi: float
    _ma_tq: str | None
    _s: Session = field(repr=False)
    KEY = "MaKH"
    SQL_ALL = "SELECT * FROM KHOAHOC k"
    SQL_ONE = SQL_ALL + " WHERE k.MaKH = ?"

    @classmethod
    def from_row(cls, s, r):
        return cls(r["MaKH"], r["TenKH"], float(r["HocPhi"]), r["MaKHTienQuyet"], s)

    @property
    def tien_quyet(self) -> KhoaHoc | None:           # relationship đệ quy
        return self._s.get(KhoaHoc, self._ma_tq) if self._ma_tq else None

    def lo_trinh(self) -> list[KhoaHoc]:
        """Chuỗi khoá cần học trước – duyệt đối tượng thay cho CTE đệ quy (Q26)."""
        return (self.tien_quyet.lo_trinh() if self.tien_quyet else []) + [self]


@dataclass(eq=False)
class LopHoc(CoOID):
    ma_lop: str
    trang_thai: str
    si_so_toi_da: int
    _ma_kh: str
    _ma_gv: str
    _s: Session = field(repr=False)
    KEY = "MaLop"
    SQL_ALL = "SELECT * FROM LOPHOC l"
    SQL_ONE = SQL_ALL + " WHERE l.MaLop = ?"

    @classmethod
    def from_row(cls, s, r):
        return cls(r["MaLop"], r["TrangThai"], int(r["SiSoToiDa"]), r["MaKH"], r["MaGV"], s)

    @property
    def khoa_hoc(self) -> KhoaHoc:
        return self._s.get(KhoaHoc, self._ma_kh)

    @property
    def giao_vien(self) -> GiaoVien:
        return self._s.get(NhanVien, self._ma_gv)

    @property
    def dang_kys(self) -> list[DangKy]:
        return self._s.all(DangKy, "d.MaLop = ?", self.ma_lop)

    def si_so_hien_tai(self) -> int:                  # suy diễn bằng phương thức – không cần cột + trigger
        return sum(1 for d in self.dang_kys if d.trang_thai in ("Đang học", "Hoàn thành"))

    def si_so_con_lai(self) -> int:
        return self.si_so_toi_da - self.si_so_hien_tai()

    def ghi_danh(self, hv: HocVien, giam_gia: float = 0) -> DangKy:
        """Đóng gói: luật ghi danh nằm trong phương thức của đối tượng (tương ứng sp_DangKyHoc + trigger sĩ số)."""
        if self.trang_thai not in ("Sắp mở", "Đang học"):
            raise LoiNghiepVu(f"Lớp {self.ma_lop} không còn nhận ghi danh.")
        if any(d.hoc_vien is hv for d in self.dang_kys):
            raise LoiNghiepVu(f"{hv.ho_ten()} đã đăng ký lớp {self.ma_lop}.")
        if self.si_so_con_lai() <= 0:
            raise LoiNghiepVu(f"Lớp {self.ma_lop} đã đủ sĩ số.")
        dk = DangKy(None, self.khoa_hoc.hoc_phi, 0, None, None, "Đang học", hv.ma_hv, self.ma_lop, self._s)
        dk.dat_giam_gia(giam_gia)
        return self._s.them(dk)


@dataclass(eq=False)
class HocVien(Nguoi):
    ma_hv: str = ""
    _s: Session = field(default=None, repr=False)
    KEY = "MaHV"
    SQL_ALL = "SELECT * FROM HOCVIEN h"
    SQL_ONE = SQL_ALL + " WHERE h.MaHV = ?"

    @classmethod
    def from_row(cls, s, r):
        return cls(r["HoHV"], r["TenHV"], r["NgaySinh"], r["MaHV"], s)

    @property
    def dang_kys(self) -> list[DangKy]:
        return self._s.all(DangKy, "d.MaHV = ?", self.ma_hv)

    def cong_no(self) -> float:
        return sum(d.so_tien_con_no() for d in self.dang_kys if d.trang_thai not in ("Huỷ", "Đã chuyển lớp"))


@dataclass(eq=False)
class DangKy(CoOID):
    """Lớp liên kết HocVien – LopHoc."""
    ma_dk: int
    hoc_phi: float
    giam_gia: float
    diem_gk: float | None
    diem_ck: float | None
    trang_thai: str
    _ma_hv: str
    _ma_lop: str
    _s: Session = field(repr=False)
    KEY = "MaDK"
    SQL_ALL = "SELECT d.MaDK, d.HocPhi, d.GiamGia, d.DiemGK, d.DiemCK, d.TrangThai, d.MaHV, d.MaLop FROM DANGKY d"
    SQL_ONE = SQL_ALL + " WHERE d.MaDK = ?"

    @classmethod
    def from_row(cls, s, r):
        f = lambda v: None if v is None else float(v)
        return cls(r["MaDK"], float(r["HocPhi"]), float(r["GiamGia"]), f(r["DiemGK"]), f(r["DiemCK"]), r["TrangThai"],
                   r["MaHV"], r["MaLop"], s)

    @property
    def hoc_vien(self) -> HocVien:
        return self._s.get(HocVien, self._ma_hv)

    @property
    def lop(self) -> LopHoc:
        return self._s.get(LopHoc, self._ma_lop)

    def dat_giam_gia(self, phan_tram: float) -> None:
        """Bất biến: giảm giá 0–50% (cùng luật CHECK / THROW 50006 phía CSDL)."""
        if not 0 <= phan_tram <= 50:
            raise LoiNghiepVu("Giảm giá phải từ 0 đến 50%.")
        self.giam_gia = phan_tram

    def _luu(self, cur) -> int:
        """Ghi đối tượng DangKy mới xuống bảng DANGKY, nhận và trả MaDK do CSDL sinh."""
        cur.execute("SET NOCOUNT ON; INSERT DANGKY (MaHV, MaLop, HocPhi, GiamGia) VALUES (?, ?, ?, ?); "
                    "SELECT CAST(SCOPE_IDENTITY() AS INT)", self._ma_hv, self._ma_lop, self.hoc_phi, self.giam_gia)
        self.ma_dk = cur.fetchone()[0]
        return self.ma_dk

    def thanh_tien(self) -> float:
        return round(self.hoc_phi * (100 - self.giam_gia) / 100, -3)

    def diem_tb(self) -> float | None:
        return None if self.diem_gk is None or self.diem_ck is None else round(self.diem_gk * 0.4 + self.diem_ck * 0.6, 2)

    def ket_qua(self) -> str | None:
        tb = self.diem_tb()
        return None if tb is None else ("Đạt" if tb >= 5 else "Không đạt")

    def so_tien_con_no(self) -> float:
        da_thu = self._s.rows("SELECT ISNULL(SUM(SoTien), 0) AS t FROM CT_PHIEUTHU WHERE MaDK = ?", self.ma_dk)[0]["t"]
        return self.thanh_tien() - float(da_thu)
