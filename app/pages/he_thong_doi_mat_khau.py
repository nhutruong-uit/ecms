"""Đổi mật khẩu của người đang đăng nhập (T19)."""
import re

import streamlit as st

from core import auth, db, ui

user = auth.require_role()
ui.header("🔑 Đổi mật khẩu", "Nhập sai mật khẩu hiện tại cũng tính vào số lần sai: sai 5 lần liên tiếp tài khoản bị tạm khoá 15 phút.")
ui.show_flash()
MK_HELP = "Ít nhất 8 ký tự, có chữ hoa, chữ thường, chữ số, ký tự đặc biệt"
lan = st.session_state.setdefault("_mk_lan", 0)          # đổi key form sau khi thành công để xoá các ô đã nhập
with st.form(f"f_mk_{lan}"):
    fe = ui.FieldErrors()
    cu = st.text_input("Mật khẩu hiện tại", type="password"); fe.slot("cu")
    moi = st.text_input("Mật khẩu mới", type="password", help=MK_HELP); fe.slot("moi")
    lai = st.text_input("Nhập lại mật khẩu mới", type="password"); fe.slot("lai")
    if st.form_submit_button("Đổi mật khẩu", type="primary"):
        # cùng chính sách với dbo.fn_MatKhauHopLe – báo ngay cạnh ô, CSDL vẫn kiểm tra lại
        fe.check("cu", cu != "", "Nhập mật khẩu hiện tại")
        fe.check("moi", len(moi) >= 8 and all(re.search(p, moi) for p in (r"[A-Z]", r"[a-z]", r"\d", r"[^A-Za-z0-9]")), MK_HELP)
        fe.check("moi", moi != cu or not moi, "Mật khẩu mới phải khác mật khẩu hiện tại")
        fe.check("lai", moi == lai, "Mật khẩu nhập lại không khớp")
        if fe.ok:
            out = ui.run(lambda: db.call_proc("sp_DoiMatKhau", {"TenDangNhap": user["username"], "MatKhauCu": cu, "MatKhauMoi": moi},
                                              outputs={"ThongBao": "NVARCHAR(200)"}), rerun=False)
            if out is not None:
                if out.get("ThongBao") == "Đã đổi mật khẩu.":
                    st.session_state["_mk_lan"] = lan + 1
                    ui.flash("Đã đổi mật khẩu. Lần đăng nhập sau dùng mật khẩu mới.")
                    st.rerun()
                fe.check("cu", False, out.get("ThongBao") or "Mật khẩu hiện tại không đúng.")
