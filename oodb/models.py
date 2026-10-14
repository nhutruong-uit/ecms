"""Minh hoạ mô hình hướng đối tượng của ECMS bằng Python (T25).

Ánh xạ bảng → lớp theo lược đồ ODL (docs/design/odl-schema.md):
  - mỗi đối tượng có OID (id() của Python) tách biệt với khoá nghiệp vụ; Session giữ *identity map*:
    cùng một khoá luôn trả về cùng một đối tượng
  - relationship được nạp *lười* (lazy) khi truy cập lần đầu, quan hệ ngược (inverse) dùng chung đối tượng
  - kế thừa: GiaoVien(NhanVien(Nguoi)), đa hình qua phương thức tinh_luong()
  - thuộc tính suy diễn là phương thức (tuoi(), si_so_hien_tai(), thanh_tien()…)

Chỉ đọc dữ liệu, kết nối bằng tài khoản quản trị trong .env (SA_PASSWORD).
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import pyodbc
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


class Session:
    """Kết nối + identity map + đếm số câu truy vấn đã gửi (để thấy vấn đề N+1 của lazy loading)."""

    def __init__(self):
        self.cn = pyodbc.connect(
            f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};"
            f"SERVER={os.getenv('DB_SERVER', 'localhost')},{os.getenv('DB_PORT', '1433')};DATABASE=ECMS;"
            f"UID=sa;PWD={os.getenv('SA_PASSWORD', 'Ecms@12345')};TrustServerCertificate=yes")
        self.identity: dict[tuple, object] = {}
        self.so_truy_van = 0

    def rows(self, sql: str, *params):
        self.so_truy_van += 1
        cur = self.cn.cursor()
        cur.execute(sql, params)
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

    def get(self, cls, key, row: dict | None = None):
        """Lấy đối tượng theo khoá; đã có trong identity map thì trả lại đúng đối tượng đó (cùng OID)."""
        k = (cls.__name__, key)
        if k not in self.identity:
            if row is None:
                found = self.rows(cls.SQL_ONE, key)
                if not found:
                    return None
                row = found[0]
            obj = cls.from_row(self, row)
            self.identity[k] = obj
        return self.identity[k]

    def all(self, cls, where: str = "", *params):
        return [self.get(cls, r[cls.KEY], r) for r in self.rows(cls.SQL_ALL + (" WHERE " + where if where else ""), *params)]


@dataclass(eq=False)
class Nguoi:
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


@dataclass(eq=False)
class GiaoVien(NhanVien):
    loai_gv: str = ""
    don_gia_buoi: float = 0

    @property
    def lop_phu_trach(self) -> list[LopHoc]:          # relationship Set<LopHoc> (lazy)
        return self._s.all(LopHoc, "l.MaGV = ?", self.ma_nv)

    def tinh_luong(self, thang: str) -> float:        # đa hình: ghi đè cách tính của NhanVien
        so_buoi = self._s.rows("""SELECT COUNT(*) AS n FROM BUOIHOC b JOIN LOPHOC l ON l.MaLop = b.MaLop
                                  WHERE l.MaGV = ? AND b.TrangThai = N'Đã dạy' AND FORMAT(b.NgayHoc, 'yyyy-MM') = ?""",
                               self.ma_nv, thang)[0]["n"]
        return self.luong_co_ban + so_buoi * self.don_gia_buoi


@dataclass(eq=False)
class KhoaHoc:
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
class LopHoc:
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
class DangKy:
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
