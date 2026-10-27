"""Trang đăng nhập (T19)."""
import streamlit as st

from core import auth, db
from core.config import APP_TITLE, SHOW_DEMO_ACCOUNTS

left, mid, right = st.columns([1, 1.2, 1])
with mid:
    st.title("🎓 ECMS")
    st.caption(APP_TITLE)
    if st.session_state.get("_ly_do_dang_xuat"):
        st.info(st.session_state.pop("_ly_do_dang_xuat"), icon="ℹ️")
    with st.form("dang_nhap"):
        username = st.text_input("Tên đăng nhập", placeholder="vd: giaovu")
        password = st.text_input("Mật khẩu", type="password")
        ok = st.form_submit_button("Đăng nhập", type="primary", width="stretch")
    if ok:
        try:
            success, msg = auth.login(username, password)
        except db.DbError as e:
            success, msg = False, f"Không kết nối được CSDL: {e.message}"
        if success:
            st.rerun()
        st.error(msg, icon="⛔")
    if SHOW_DEMO_ACCOUNTS:          # chỉ môi trường phát triển (ECMS_SHOW_DEMO=yes trong .env) – tắt khi triển khai thật
        with st.expander("Tài khoản demo (môi trường phát triển)"):
            st.dataframe(
                [{"Tài khoản": tk, "Mật khẩu": mk, "Vai trò": vt} for tk, mk, vt in (
                    ("quanly", "Ecms@2026", "Quản lý trung tâm"),
                    ("giaovu", "Ecms@2026", "Giáo vụ CN01"),
                    ("ketoan", "Ecms@2026", "Kế toán CN01"),
                    ("giaovien", "Ecms@2026", "Giáo viên"),
                    ("hocvien", "Hocvien@2026", "Học viên"),
                )],
                hide_index=True, width="stretch",
            )
