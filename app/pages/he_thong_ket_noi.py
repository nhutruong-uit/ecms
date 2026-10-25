"""Trang Kiểm tra kết nối: xác nhận ứng dụng kết nối được tới CSDL ECMS."""
import streamlit as st

from core import auth, db
from core.config import DB

auth.require_role("QuanLy")
st.title("🔌 Kiểm tra kết nối")
st.caption(f"Máy chủ `{DB.server}{',' + DB.port if DB.port.strip() else ''}` · CSDL `{DB.database}` · Driver `{DB.driver}`")

try:
    info = db.server_info()
except db.DbError as e:
    st.error(f"Không kết nối được CSDL: {e.message}")
    st.markdown("Kiểm tra: container SQL Server đã chạy (`docker compose ps`), file `.env` đúng tài khoản, "
                "đã cài **ODBC Driver 18** – xem `docs/SETUP.md`.")
    st.stop()

st.success(f"Kết nối thành công tới **{info['database']}** bằng tài khoản **{info['login']}**.")
c1, c2, c3 = st.columns(3)
c1.metric("Số bảng (thấy được)", info["tables"])
c2.metric("Số view", info["views"])
c3.metric("Số procedure", info["procedures"])
st.caption("Tài khoản ứng dụng `ecms_app` bị DENY trên mọi bảng nên số bảng thấy được là 0 – đúng nguyên tắc quyền tối thiểu.")
st.code(info["version"], language="text")
