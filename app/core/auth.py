"""Đăng nhập / phiên làm việc (T19).

Người dùng đăng nhập bằng bảng TAIKHOAN qua sp_DangNhap (mật khẩu băm lặp SHA2_256 + salt, sai 5 lần liên tiếp
thì tạm khoá 15 phút); kết nối CSDL luôn dùng login ít quyền ecms_app. Thông tin phiên lưu trong
st.session_state["user"]:
    {"username", "role", "ho_ten", "ma_nv", "ma_hv", "ma_cn", "pham_vi_cn"}

Phiên không chỉ tin vào dữ liệu đã lưu lúc đăng nhập: cứ KIEM_TRA_LAI_GIAY giây, require_role() đọc lại trạng thái
và vai trò tài khoản – quản lý khoá tài khoản hoặc đổi chức vụ thì tab đang mở bị đăng xuất ngay ở thao tác kế tiếp.
Không thao tác quá HET_HAN_PHUT phút thì phiên hết hạn.
"""
import time

import streamlit as st

from core import db

KIEM_TRA_LAI_GIAY = 60
HET_HAN_PHUT = 30

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
    st.session_state["_hoat_dong"] = st.session_state["_kiem_tra"] = time.time()
    try:
        # lớp "Sắp mở" đã tới ngày khai giảng → "Đang học" (để giáo viên thấy lớp ở trang Điểm danh)
        db.call_proc("sp_CapNhatTrangThaiLop", outputs={"SoLop": "INT"})
    except db.DbError:
        pass
    return True, out.get("ThongBao", "")


def logout(ly_do: str | None = None) -> None:
    """Xoá phiên và đóng kết nối CSDL riêng của phiên. ly_do: thông báo hiện ở trang Đăng nhập."""
    db.close()
    for k in list(st.session_state.keys()):
        del st.session_state[k]
    if ly_do:
        st.session_state["_ly_do_dang_xuat"] = ly_do


def _con_hieu_luc(user: dict) -> str | None:
    """None nếu phiên còn hiệu lực; ngược lại là lý do phải đăng xuất."""
    now = time.time()
    if now - st.session_state.get("_hoat_dong", now) > HET_HAN_PHUT * 60:
        return f"Phiên đã hết hạn do không thao tác quá {HET_HAN_PHUT} phút. Vui lòng đăng nhập lại."
    st.session_state["_hoat_dong"] = now
    if now - st.session_state.get("_kiem_tra", 0) > KIEM_TRA_LAI_GIAY:
        tk = db.query("SELECT TrangThai, VaiTro FROM vw_TaiKhoan WHERE TenDangNhap = ?", [user["username"]])
        if tk.empty or not bool(tk.iloc[0]["TrangThai"]):
            return "Tài khoản đã bị khoá. Liên hệ quản trị viên."
        if tk.iloc[0]["VaiTro"] != user["role"]:
            return "Vai trò của tài khoản vừa thay đổi. Vui lòng đăng nhập lại."
        st.session_state["_kiem_tra"] = now
    return None


def require_role(*roles: str) -> dict:
    """Đặt ở đầu mỗi trang: chặn truy cập trực tiếp bằng URL khi vai trò không được phép."""
    user = current_user()
    if not user:
        st.warning("Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.")
        st.stop()
    ly_do = _con_hieu_luc(user)
    if ly_do:
        logout(ly_do)
        st.rerun()
    if roles and user["role"] not in roles:
        st.error("Bạn không có quyền truy cập chức năng này.")
        st.stop()
    return user
