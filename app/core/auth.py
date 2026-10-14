"""Đăng nhập / phiên làm việc (T19).

Người dùng đăng nhập bằng bảng TAIKHOAN qua sp_DangNhap (mật khẩu băm SHA2_256 + salt, khoá sau 5 lần sai);
kết nối CSDL luôn dùng login ít quyền ecms_app. Thông tin phiên lưu trong st.session_state["user"]:
    {"username", "role", "ho_ten", "ma_nv", "ma_hv", "ma_cn", "pham_vi_cn"}
"""
import streamlit as st

from core import db

ROLES = {
    "QuanLy": "Quản lý",
    "GiaoVu": "Giáo vụ",
    "KeToan": "Kế toán",
    "GiaoVien": "Giáo viên",
    "HocVien": "Học viên",
}


def current_user() -> dict | None:
    return st.session_state.get("user")


def is_logged_in() -> bool:
    return current_user() is not None


def has_role(*roles: str) -> bool:
    user = current_user()
    return bool(user) and user["role"] in roles


def login(username: str, password: str) -> tuple[bool, str]:
    """Gọi sp_DangNhap. Trả (thành công, thông báo)."""
    username = (username or "").strip().lower()
    if not username or not password:
        return False, "Nhập tên đăng nhập và mật khẩu."
    df, out = db.call_proc("sp_DangNhap", {"TenDangNhap": username, "MatKhau": password},
                           outputs={"ThongBao": "NVARCHAR(200)"}, fetch=True)
    if df.empty:
        return False, out.get("ThongBao") or "Đăng nhập thất bại."
    r = df.iloc[0]
    st.session_state["user"] = {
        "username": r["TenDangNhap"], "role": r["VaiTro"], "ho_ten": r["HoTen"],
        "ma_nv": r["MaNV"], "ma_hv": r["MaHV"], "ma_cn": r["MaCN"], "pham_vi_cn": r["PhamViCN"],
    }
    return True, out.get("ThongBao", "")


def logout() -> None:
    for k in list(st.session_state.keys()):
        del st.session_state[k]


def require_role(*roles: str) -> dict:
    """Đặt ở đầu mỗi trang: chặn truy cập trực tiếp bằng URL khi vai trò không được phép."""
    user = current_user()
    if not user:
        st.warning("Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.")
        st.stop()
    if roles and user["role"] not in roles:
        st.error("Bạn không có quyền truy cập chức năng này.")
        st.stop()
    return user
