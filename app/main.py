"""Điểm vào ứng dụng ECMS:  streamlit run app/main.py"""
import streamlit as st

from core.config import APP_TITLE

st.set_page_config(page_title=APP_TITLE, page_icon="🎓", layout="wide")

pages = {
    "Hệ thống": [
        st.Page("pages/trang_chu.py", title="Trang chủ", icon="🏠", default=True),
        st.Page("pages/he_thong_ket_noi.py", title="Kiểm tra kết nối", icon="🔌"),
    ],
}

st.navigation(pages).run()
