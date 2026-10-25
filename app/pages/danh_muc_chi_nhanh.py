"""Danh mục: chi nhánh, phòng học, ca học (T19). Đọc qua view, ghi qua procedure."""
import re
from datetime import date, time

import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy")
ui.header("🏢 Chi nhánh, phòng học, ca học", "Danh mục nền của trung tâm. Chọn một dòng trong bảng để sửa.")
ui.show_flash()

tab_cn, tab_ph, tab_ca = st.tabs(["Chi nhánh", "Phòng học", "Ca học"], key="tabs", on_change="rerun")

# ------------------------------------------------------------------ CHI NHÁNH
with tab_cn:
    df = db.query("SELECT * FROM vw_DM_ChiNhanh ORDER BY MaCN")
    sel = ui.table(df, {"MaCN": "Mã", "TenCN": "Tên chi nhánh", "DiaChi": "Địa chỉ", "SoDienThoai": "Điện thoại",
                        "NgayThanhLap": "Thành lập", "QuanLy": "Quản lý", "SoPhong": "Phòng",
                        "SoNhanVien": "Nhân viên", "SoLopDangMo": "Lớp đang mở"}, key="t_cn")
    r = sel or {}
    st.subheader("Sửa chi nhánh " + r["MaCN"] if sel else "Thêm chi nhánh")
    with st.form("f_cn", clear_on_submit=not sel):
        fe = ui.FieldErrors()
        c1, c2 = st.columns([1, 3])
        ma = c1.text_input("Mã chi nhánh *", r.get("MaCN", ""), disabled=bool(sel), help="Dạng CNxx, VD CN04")
        with c1: fe.slot("ma")
        ten = c2.text_input("Tên chi nhánh *", r.get("TenCN", ""))
        with c2: fe.slot("ten")
        dc = st.text_input("Địa chỉ *", r.get("DiaChi", "")); fe.slot("dc")
        c3, c4, c5 = st.columns(3)
        sdt = c3.text_input("Điện thoại *", r.get("SoDienThoai", ""))
        with c3: fe.slot("sdt")
        ntl = c4.date_input("Ngày thành lập", ui.to_date(r.get("NgayThanhLap"), date.today()), format="DD/MM/YYYY")
        with c5:
            ql = ui.pick("Quản lý chi nhánh", "SELECT MaNV, HoTen FROM vw_NhanVien WHERE ChucVu = N'Quản lý' AND TrangThai = 1",
                         r.get("MaNVQuanLy"), allow_empty=True)
        if st.form_submit_button("Lưu", type="primary"):
            fe.check("ma", re.fullmatch(r"CN\d{2}", ma.strip().upper() or "") is not None, "Mã phải có dạng CN + 2 chữ số")
            fe.check("ten", ten.strip() != "", "Tên chi nhánh không được để trống")
            fe.check("dc", dc.strip() != "", "Địa chỉ không được để trống")
            fe.check("sdt", re.fullmatch(r"\d{9,11}", sdt.strip()) is not None, "Điện thoại gồm 9–11 chữ số")
            if fe.ok:
                ui.run(lambda: db.call_proc("sp_LuuChiNhanh", {
                    "MaCN": ma.strip().upper(), "TenCN": ten.strip(), "DiaChi": dc.strip(), "SoDienThoai": sdt.strip(),
                    "NgayThanhLap": ntl, "MaNVQuanLy": ql}), f"Đã lưu chi nhánh {ma.strip().upper()}.")
    if sel and ui.nut_xoa(f"Xoá chi nhánh {r['MaCN']}", key=f"x_cn_{r['MaCN']}"):
        ui.run(lambda: db.call_proc("sp_XoaChiNhanh", {"MaCN": r["MaCN"]}), f"Đã xoá chi nhánh {r['MaCN']}.")

# ------------------------------------------------------------------ PHÒNG HỌC
with tab_ph:
    loc_cn = ui.chon_chi_nhanh(user, key="loc_ph")
    df = db.query("SELECT * FROM vw_DM_PhongHoc WHERE ? IS NULL OR MaCN = ? ORDER BY MaCN, MaPhong", [loc_cn, loc_cn])
    sel = ui.table(df, {"MaCN": "Chi nhánh", "TenCN": "Tên chi nhánh", "MaPhong": "Phòng", "SucChua": "Sức chứa",
                        "LoaiPhong": "Loại", "SoLichDangDung": "Lịch đang dùng"}, key="t_ph")
    r = sel or {}
    st.subheader(f"Sửa phòng {r['MaPhong']} ({r['MaCN']})" if sel else "Thêm phòng")
    with st.form("f_ph", clear_on_submit=not sel):
        fe = ui.FieldErrors()
        c1, c2, c3, c4 = st.columns(4)
        with c1:
            cn = ui.chon_chi_nhanh(user, "Chi nhánh *", r.get("MaCN") or loc_cn, allow_all=False, disabled=bool(sel), key="f_ph_cn")
        ph = c2.text_input("Số phòng *", r.get("MaPhong", ""), disabled=bool(sel), help="VD P105")
        with c2: fe.slot("ph")
        sc = c3.number_input("Sức chứa *", 5, 60, int(r.get("SucChua", 25)))
        loai = c4.selectbox("Loại phòng", ["Thường", "Lab", "Hội trường"],
                            index=["Thường", "Lab", "Hội trường"].index(r.get("LoaiPhong", "Thường")))
        if st.form_submit_button("Lưu", type="primary"):
            fe.check("ph", re.fullmatch(r"[A-Z0-9]{1,5}", ph.strip().upper() or "") is not None, "Số phòng tối đa 5 ký tự chữ / số")
            if fe.ok:
                ui.run(lambda: db.call_proc("sp_LuuPhongHoc", {"MaCN": cn, "MaPhong": ph.strip().upper(), "SucChua": sc,
                                                               "LoaiPhong": loai}), f"Đã lưu phòng {ph.strip().upper()}.")
    if sel and ui.nut_xoa(f"Xoá phòng {r['MaPhong']}", key=f"x_ph_{r['MaCN']}_{r['MaPhong']}"):
        ui.run(lambda: db.call_proc("sp_XoaPhongHoc", {"MaCN": r["MaCN"], "MaPhong": r["MaPhong"]}), "Đã xoá phòng.")

# ------------------------------------------------------------------ CA HỌC
with tab_ca:
    df = db.query("SELECT * FROM vw_DM_CaHoc ORDER BY GioBatDau")
    sel = ui.table(df, {"MaCa": "Mã ca", "TenCa": "Tên ca", "GioBatDau": "Bắt đầu", "GioKetThuc": "Kết thúc",
                        "SoPhut": "Số phút"}, key="t_ca")
    r = sel or {}
    st.subheader(f"Sửa ca {r['MaCa']}" if sel else "Thêm ca học")
    with st.form("f_ca", clear_on_submit=not sel):
        fe = ui.FieldErrors()
        c1, c2, c3, c4 = st.columns(4)
        ke_tiep = min(int(df["MaCa"].max()) + 1, 99) if len(df) else 1     # mã ca là TINYINT; giới hạn 99 để không vượt khoảng
        ma = c1.number_input("Mã ca *", 1, 99, int(r.get("MaCa", ke_tiep)), disabled=bool(sel))
        ten = c2.text_input("Tên ca *", r.get("TenCa", ""))
        with c2: fe.slot("ten")
        bd = c3.time_input("Giờ bắt đầu", r.get("GioBatDau", time(18, 0)), step=900)
        kt = c4.time_input("Giờ kết thúc", r.get("GioKetThuc", time(19, 30)), step=900)
        with c4: fe.slot("kt")
        if st.form_submit_button("Lưu", type="primary"):
            fe.check("ten", ten.strip() != "", "Tên ca không được để trống")
            fe.check("kt", kt > bd, "Giờ kết thúc phải sau giờ bắt đầu")
            if fe.ok:
                ui.run(lambda: db.call_proc("sp_LuuCaHoc", {"MaCa": int(ma), "TenCa": ten.strip(), "GioBatDau": bd,
                                                            "GioKetThuc": kt}), f"Đã lưu ca {ma}.")
    if sel and ui.nut_xoa(f"Xoá ca {r['MaCa']}", key=f"x_ca_{r['MaCa']}"):
        ui.run(lambda: db.call_proc("sp_XoaCaHoc", {"MaCa": int(r["MaCa"])}), "Đã xoá ca học.")
