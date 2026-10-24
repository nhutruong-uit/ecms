"""Smoke test giao diện: chạy mọi trang Streamlit với mỗi vai trò, không được phát sinh exception;
vai trò không được phép bị chặn; phạm vi chi nhánh, kiểm tra lại phiên và quyền mặc định từ chối của CSDL.

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
# mọi cặp (vai trò, trang) KHÔNG có trong menu của vai trò đó: gõ thẳng URL cũng phải bị chặn
CAM = [(vai_tro, f) for vai_tro in TAI_KHOAN for _, f, _, _, roles in menu.MENU
       if vai_tro not in roles and (APP / "pages" / f).exists() and f != "trang_chu.py"]


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


@pytest.mark.parametrize("vai_tro", ["QuanLy", "KeToan", "GiaoVu", "GiaoVien"])
def test_moi_bao_cao(users, vai_tro):
    at = chay("bao_cao_danh_sach.py", users[vai_tro])
    hop = at.selectbox[0]
    for opt in hop.options:
        hop.set_value(opt).run()
        assert not at.exception, f"báo cáo {opt} ({vai_tro}): {at.exception[0].message}"
        hop = at.selectbox[0]


@pytest.mark.parametrize("vai_tro,trang", CAM)
def test_vai_tro_khong_duoc_vao(users, vai_tro, trang):
    at = chay(trang, users[vai_tro])
    assert any("không có quyền" in e.value for e in at.error), f"{vai_tro} vào được {trang}"


def test_chi_nhanh_khoa_theo_pham_vi(users):
    """Giáo vụ CN01: bộ lọc chi nhánh bị khoá ở CN01; quản lý toàn trung tâm chọn tự do."""
    at = chay("dao_tao_lop_hoc.py", users["GiaoVu"])
    hop = at.selectbox(key="l_cn")
    assert hop.disabled and hop.value == "CN01"
    at = chay("dao_tao_lop_hoc.py", users["QuanLy"])
    assert not at.selectbox(key="l_cn").disabled


def test_doi_vai_tro_bi_dang_xuat(users):
    """Phiên lưu vai trò cũ (quản lý đã đổi chức vụ) → lần kiểm tra lại kế tiếp đăng xuất ngay."""
    gia = dict(users["QuanLy"], role="KeToan")
    at = chay("bao_cao_dashboard.py", gia)
    assert "user" not in at.session_state
    assert "thay đổi" in at.session_state["_ly_do_dang_xuat"]


def test_dang_nhap_qua_giao_dien():
    at = AppTest.from_file(str(APP / "pages" / "dang_nhap.py"), default_timeout=60)
    at.run()
    at.text_input[0].input("giaovu")
    at.text_input[1].input("Ecms@2026")
    at.button[0].click().run()
    assert at.session_state["user"]["role"] == "GiaoVu" and at.session_state["user"]["pham_vi_cn"] == "CN01"


def test_csdl_tu_choi_khi_khong_co_ngu_canh():
    """Kết nối ecms_app không có ngữ cảnh người dùng (gọi ngoài ứng dụng): procedure ghi phải từ chối (fail-closed)."""
    lop = db.scalar("SELECT TOP 1 MaLop FROM vw_SiSoLop WHERE TrangThai = N'Đang học'")
    with pytest.raises(db.DbError) as e:
        db.call_proc("sp_NhapDiem", {"MaLop": lop, "DanhSach": "[]"})
    assert e.value.number == 50043
    with pytest.raises(db.DbError) as e:
        db.call_proc("sp_ThuHocPhi", {"MaHV": "HV0001", "MaNV": "NV0008", "ChiTiet": "[]"}, outputs={"MaPT": "INT"})
    assert e.value.number == 50015


def test_in_phieu_thu_tu_du_lieu_that():
    from reports.phieu_thu_pdf import phieu_thu_pdf
    pt = db.query("SELECT TOP 1 * FROM vw_PhieuThu ORDER BY SoDong DESC, MaPT").iloc[0].to_dict()
    ct = db.query("SELECT * FROM vw_CTPhieuThu WHERE MaPT = ? ORDER BY MaLop", [pt["MaPT"]])
    assert phieu_thu_pdf(pt, ct)[:5] == b"%PDF-"


def test_dang_nhap_sai():
    df, out = db.call_proc("sp_DangNhap", {"TenDangNhap": "khongco", "MatKhau": "x"}, outputs={"ThongBao": "NVARCHAR(200)"}, fetch=True)
    assert df.empty and "Sai" in out["ThongBao"]
