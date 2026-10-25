"""Quản lý tài khoản ứng dụng (T19): tạo, khoá / mở khoá, đặt lại mật khẩu, đổi vai trò."""
import re

import pandas as pd
import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy")
ui.header("👥 Tài khoản", "Sai mật khẩu 5 lần liên tiếp thì tài khoản bị tạm khoá 15 phút – đặt lại mật khẩu hoặc mở khoá "
                         "để gỡ ngay. Vai trò của tài khoản nhân viên luôn theo chức vụ (đổi ở trang Nhân viên).")
ui.show_flash()

c1, c2, c3 = st.columns([1, 1, 2])
f_vt = c1.selectbox("Vai trò", [None, *auth.ROLES], format_func=lambda v: auth.ROLES.get(v, "— tất cả —"))
f_tt = c2.selectbox("Trạng thái", [None, 1, 0], format_func={None: "— tất cả —", 1: "Hoạt động", 0: "Bị khoá"}.get)
f_q = c3.text_input("Tìm tên đăng nhập / họ tên")
df = db.query("""SELECT * FROM vw_TaiKhoan WHERE (? IS NULL OR VaiTro = ?) AND (? IS NULL OR TrangThai = ?)
                 AND (TenDangNhap LIKE ? OR HoTen LIKE ?) ORDER BY VaiTro, TenDangNhap""",
              [f_vt, f_vt, f_tt, f_tt, f"%{f_q}%", f"%{f_q}%"])
df["TrangThaiTen"] = df["TrangThai"].map({True: "Hoạt động", False: "🔒 Bị khoá"})
tam_khoa = pd.to_datetime(df["KhoaDen"]) > pd.Timestamp.now()
df.loc[tam_khoa & df["TrangThai"].astype(bool), "TrangThaiTen"] = "⏳ Tạm khoá"
df["KhoaDenTxt"] = pd.to_datetime(df["KhoaDen"]).dt.strftime("%H:%M %d/%m").where(tam_khoa, "")
df["VaiTroTen"] = df["VaiTro"].map(auth.ROLES)
sel = ui.table(df, {"TenDangNhap": "Tên đăng nhập", "HoTen": "Họ tên", "VaiTroTen": "Vai trò", "MaCN": "Chi nhánh",
                    "TrangThaiTen": "Trạng thái", "KhoaDenTxt": "Tạm khoá đến", "SoLanSai": "Số lần sai",
                    "LanDangNhapCuoi": "Đăng nhập cuối"}, key="t_tk")

MK_HELP = "Ít nhất 8 ký tự, có chữ hoa, chữ thường, chữ số, ký tự đặc biệt"


def mk_hop_le(mk: str) -> bool:
    return len(mk) >= 8 and all(re.search(p, mk) for p in (r"[A-Z]", r"[a-z]", r"\d", r"[^A-Za-z0-9]"))


if sel:
    st.subheader(f"Tài khoản {sel['TenDangNhap']} – {sel['HoTen']}")
    c1, c2 = st.columns(2)
    with c1, st.form("f_sua"):
        st.text_input("Vai trò", auth.ROLES[sel["VaiTro"]], disabled=True,
                      help="Vai trò đi theo chức vụ của nhân viên – đổi chức vụ ở trang Nhân viên & giáo viên")
        mk = st.text_input("Đặt lại mật khẩu (bỏ trống nếu không đổi)", type="password", help=MK_HELP)
        loi = st.empty()
        if st.form_submit_button("Đặt lại mật khẩu", type="primary"):
            if not mk:
                loi.error("Nhập mật khẩu mới.", icon="⚠️")
            elif not mk_hop_le(mk):
                loi.error(MK_HELP, icon="⚠️")
            else:
                ui.run(lambda: db.call_proc("sp_CapNhatTaiKhoan", {"TenDangNhap": sel["TenDangNhap"], "MatKhauMoi": mk}),
                       "Đã đặt lại mật khẩu (đồng thời gỡ tạm khoá nếu có).")
    with c2:
        st.write("")
        if sel["TrangThai"] and sel["KhoaDenTxt"]:
            if st.button("Gỡ tạm khoá", icon=":material/lock_clock:", type="primary"):
                ui.run(lambda: db.call_proc("sp_CapNhatTaiKhoan", {"TenDangNhap": sel["TenDangNhap"], "TrangThai": 1}),
                       f"Đã gỡ tạm khoá {sel['TenDangNhap']}.")
        if sel["TrangThai"]:
            if sel["TenDangNhap"] == user["username"]:
                st.caption("Không thể tự khoá tài khoản đang đăng nhập.")
            elif st.button("Khoá tài khoản", icon=":material/lock:"):
                ui.run(lambda: db.call_proc("sp_CapNhatTaiKhoan", {"TenDangNhap": sel["TenDangNhap"], "TrangThai": 0}),
                       f"Đã khoá {sel['TenDangNhap']}.")
        elif st.button("Mở khoá tài khoản", icon=":material/lock_open:", type="primary"):
            ui.run(lambda: db.call_proc("sp_CapNhatTaiKhoan", {"TenDangNhap": sel["TenDangNhap"], "TrangThai": 1}),
                   f"Đã mở khoá {sel['TenDangNhap']}.")

st.subheader("Tạo tài khoản mới")
loai = st.radio("Cho", ["Nhân viên", "Học viên"], horizontal=True)
with st.form("f_tao", clear_on_submit=True):
    fe = ui.FieldErrors()
    c1, c2, c3 = st.columns(3)
    with c1:
        if loai == "Nhân viên":
            chu = ui.pick("Nhân viên (chưa có tài khoản) *", """SELECT n.MaNV, n.HoTen + N' – ' + n.ChucVu FROM vw_NhanVien n
                              WHERE n.TrangThai = 1 AND NOT EXISTS (SELECT 1 FROM vw_TaiKhoan t WHERE t.MaNV = n.MaNV)""",
                          allow_empty=True, key="tk_nv")
        else:
            ma_hv = st.text_input("Mã học viên *", placeholder="HV0123").strip().upper()
            chu = ma_hv or None
        fe.slot("chu")
    ten = c2.text_input("Tên đăng nhập *", help="Chữ thường không dấu, số, dấu chấm; ≥ 4 ký tự")
    with c2: fe.slot("ten")
    mk = c3.text_input("Mật khẩu ban đầu *", type="password", help=MK_HELP)
    with c3: fe.slot("mk")
    # vai trò suy từ chức vụ của nhân viên (CSDL cũng kiểm tra – lỗi 50098 nếu không khớp)
    vt = "HocVien" if loai == "Học viên" else (db.scalar("SELECT dbo.fn_VaiTroTheoChucVu(?, NULL)", [chu]) if chu else None)
    st.caption(f"Vai trò: **{auth.ROLES.get(vt, '—')}** (theo chức vụ)")
    if st.form_submit_button("Tạo tài khoản", type="primary"):
        fe.check("chu", chu is not None and (loai == "Nhân viên" or re.fullmatch(r"HV\d{4}", chu) is not None),
                 "Chọn nhân viên / nhập mã học viên dạng HV0123")
        fe.check("ten", re.fullmatch(r"[a-z0-9][a-z0-9._]{3,29}", ten.strip()) is not None, "Tên đăng nhập không hợp lệ")
        fe.check("mk", mk_hop_le(mk), MK_HELP)
        if fe.ok:
            ui.run(lambda: db.call_proc("sp_TaoTaiKhoan", {
                "TenDangNhap": ten.strip(), "MatKhau": mk, "VaiTro": vt,
                "MaNV": chu if loai == "Nhân viên" else None, "MaHV": chu if loai == "Học viên" else None}),
                f"Đã tạo tài khoản {ten.strip()}.")
