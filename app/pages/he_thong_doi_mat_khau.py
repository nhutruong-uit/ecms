"""Đổi mật khẩu của người đang đăng nhập (T19)."""
import streamlit as st

from core import auth, db, ui

user = auth.require_role()
ui.header("🔑 Đổi mật khẩu")
ui.show_flash()
with st.form("f_mk", clear_on_submit=True):
    fe = ui.FieldErrors()
    cu = st.text_input("Mật khẩu hiện tại", type="password")
    moi = st.text_input("Mật khẩu mới", type="password",
                        help="Ít nhất 8 ký tự, có chữ hoa, chữ thường, chữ số, ký tự đặc biệt"); fe.slot("moi")
    lai = st.text_input("Nhập lại mật khẩu mới", type="password"); fe.slot("lai")
    if st.form_submit_button("Đổi mật khẩu", type="primary"):
        fe.check("moi", len(moi) >= 8, "Mật khẩu mới phải từ 8 ký tự")
        fe.check("lai", moi == lai, "Mật khẩu nhập lại không khớp")
        if fe.ok:
            ui.run(lambda: db.call_proc("sp_DoiMatKhau", {"TenDangNhap": user["username"], "MatKhauCu": cu,
                                                          "MatKhauMoi": moi}), "Đã đổi mật khẩu.")
