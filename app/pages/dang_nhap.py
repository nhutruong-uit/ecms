"""Trang đăng nhập (T19)."""
import streamlit as st

from core import auth, db
from core.config import APP_TITLE

left, mid, right = st.columns([1, 1.2, 1])
with mid:
    st.title("🎓 ECMS")
    st.caption(APP_TITLE)
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
    with st.expander("Tài khoản demo (môi trường phát triển)"):
        st.markdown("`quanly`, `giaovu`, `ketoan`, `giaovien` – mật khẩu `Ecms@2026` · `hocvien` – mật khẩu `Hocvien@2026`")
