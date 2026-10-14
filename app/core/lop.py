"""Chọn lớp cho phân hệ Học tập (T22): giáo viên chỉ thấy lớp mình (fn_LopCuaGiaoVien), quản lý thấy mọi lớp trong phạm vi."""
import pandas as pd
import streamlit as st

from core import db


def lop_duoc_xem(user: dict, chi_dang_hoc: bool = True) -> pd.DataFrame:
    tt = ["Đang học"] if chi_dang_hoc else ["Đang học", "Đã kết thúc"]
    if user["role"] == "GiaoVien":
        df = db.query("SELECT MaLop, TenLop, TenKH, TrangThai, SiSoHienTai FROM dbo.fn_LopCuaGiaoVien(?)", [user["ma_nv"]])
    else:
        cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
        df = db.query("""SELECT MaLop, TenLop, TenKH, TrangThai, SiSoHienTai FROM vw_SiSoLop
                         WHERE ? IS NULL OR MaCN = ?""", [cn, cn])
    return df[df["TrangThai"].isin(tt)].sort_values("MaLop")


def chon_lop(user: dict, chi_dang_hoc: bool = True, key: str = "lop") -> str | None:
    df = lop_duoc_xem(user, chi_dang_hoc)
    if df.empty:
        st.info("Không có lớp nào " + ("đang học." if chi_dang_hoc else "."))
        return None
    ten = dict(zip(df.MaLop, df.TenKH + " · " + df.TrangThai + " · " + df.SiSoHienTai.astype(str) + " HV"))
    return st.selectbox("Lớp", df.MaLop.tolist(), format_func=lambda m: f"{m} – {ten[m]}", key=key)
