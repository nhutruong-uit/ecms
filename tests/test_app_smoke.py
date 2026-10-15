"""Smoke test giao diện: chạy mọi trang Streamlit với mỗi vai trò, không được phát sinh exception.

    pytest tests/ -q          # cần CSDL ECMS đã dựng (database/run_all.sh) và .env trỏ tới ecms_app
"""
import sys
from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

APP = Path(__file__).resolve().parent.parent / "app"
sys.path.insert(0, str(APP))

from core import db, menu  # noqa: E402


def nguoi_dung(ten: str, mat_khau: str) -> dict:
    df, _ = db.call_proc("sp_DangNhap", {"TenDangNhap": ten, "MatKhau": mat_khau}, outputs={"ThongBao": "NVARCHAR(200)"}, fetch=True)
    r = df.iloc[0]
    return {"username": r.TenDangNhap, "role": r.VaiTro, "ho_ten": r.HoTen, "ma_nv": r.MaNV, "ma_hv": r.MaHV,
            "ma_cn": r.MaCN, "pham_vi_cn": r.PhamViCN}


TAI_KHOAN = {"QuanLy": ("quanly", "Ecms@2026"), "GiaoVu": ("giaovu", "Ecms@2026"), "KeToan": ("ketoan", "Ecms@2026"),
             "GiaoVien": ("giaovien", "Ecms@2026"), "HocVien": ("hocvien", "Hocvien@2026")}
CASES = [(vai_tro, f) for vai_tro in TAI_KHOAN for _, f, _, _, roles in menu.MENU if vai_tro in roles and (APP / "pages" / f).exists()]


def chay(trang: str, user: dict) -> AppTest:
    at = AppTest.from_file(str(APP / "pages" / trang), default_timeout=60)
    at.session_state["user"] = user
    at.run()
    return at


@pytest.fixture(scope="module")
def users():
    return {k: nguoi_dung(*v) for k, v in TAI_KHOAN.items()}


@pytest.mark.parametrize("vai_tro,trang", CASES)
def test_trang_chay_duoc(users, vai_tro, trang):
    at = chay(trang, users[vai_tro])
    assert not at.exception, f"{trang} ({vai_tro}): {at.exception[0].message if at.exception else ''}"


@pytest.mark.parametrize("vai_tro", ["QuanLy", "KeToan", "GiaoVien"])
def test_moi_bao_cao(users, vai_tro):
    at = chay("bao_cao_danh_sach.py", users[vai_tro])
    hop = at.selectbox[0]
    for opt in hop.options:
        hop.set_value(opt).run()
        assert not at.exception, f"báo cáo {opt} ({vai_tro}): {at.exception[0].message}"
        hop = at.selectbox[0]


def test_vai_tro_khong_duoc_vao(users):
    at = chay("tai_chinh_phieu_thu.py", users["GiaoVien"])
    assert any("không có quyền" in e.value for e in at.error)


def test_dang_nhap_sai():
    df, out = db.call_proc("sp_DangNhap", {"TenDangNhap": "khongco", "MatKhau": "x"}, outputs={"ThongBao": "NVARCHAR(200)"}, fetch=True)
    assert df.empty and "Sai" in out["ThongBao"]
