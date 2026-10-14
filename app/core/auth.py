"""Phiên đăng nhập lưu trong st.session_state (khung – hoàn thiện ở T19).

session_state["user"] = {"username", "role", "ho_ten", "ma_nv", "ma_hv", "ma_cn"}
"""
import streamlit as st

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


def logout() -> None:
    st.session_state.pop("user", None)
