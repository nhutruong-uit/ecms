"""Điểm vào ứng dụng ECMS:  streamlit run app/main.py

Chưa đăng nhập → chỉ có trang Đăng nhập. Đã đăng nhập → menu theo vai trò (core/menu.py).
"""
import streamlit as st

from core import auth, menu
from core.config import APP_TITLE

st.set_page_config(page_title=APP_TITLE, page_icon="🎓", layout="wide")

if not auth.is_logged_in():
    st.navigation([st.Page("pages/dang_nhap.py", title="Đăng nhập", icon=":material/login:")], position="hidden").run()
    st.stop()

user = auth.current_user()
pages = {
    group: [st.Page(f"pages/{file}", title=title, icon=icon, default=(file == "trang_chu.py"))
            for file, title, icon in items]
    for group, items in menu.menu_for(user["role"]).items()
}

with st.sidebar:
    st.markdown(f"**{user['ho_ten']}**  \n{auth.ROLES[user['role']]}"
                + (f" · {user['ma_cn']}" if user.get("ma_cn") else "")
                + (" · toàn trung tâm" if user.get("pham_vi_cn") == "ALL" else ""))
    if st.button("Đăng xuất", icon=":material/logout:", width="stretch"):
        auth.logout()
        st.rerun()

st.navigation(pages, expanded=True).run()
