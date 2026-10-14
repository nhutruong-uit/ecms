"""Đào tạo: chương trình và khoá học (T20). Khoá tiên quyết chọn bằng selectbox."""
import re

import streamlit as st

from core import auth, db, ui

auth.require_role("QuanLy", "GiaoVu")
ui.header("📚 Chương trình & khoá học", "Mỗi chương trình gồm nhiều khoá theo cấp độ; khoá cấp sau có thể yêu cầu khoá tiên quyết.")
ui.show_flash()

tab_kh, tab_ct = st.tabs(["Khoá học", "Chương trình"])

with tab_ct:
    df = db.query("SELECT * FROM vw_DM_ChuongTrinh ORDER BY MaCT")
    sel = ui.table(df, {"MaCT": "Mã", "TenCT": "Tên chương trình", "DoiTuong": "Đối tượng", "MoTa": "Mô tả",
                        "SoKhoaHoc": "Số khoá", "SoLopDangMo": "Lớp đang mở"}, key="t_ct")
    r = sel or {}
    st.subheader(f"Sửa chương trình {r['MaCT']}" if sel else "Thêm chương trình")
    with st.form("f_ct", clear_on_submit=not sel):
        fe = ui.FieldErrors()
        c1, c2 = st.columns([1, 3])
        ma = c1.text_input("Mã *", r.get("MaCT", ""), disabled=bool(sel), max_chars=5)
        with c1: fe.slot("ma")
        ten = c2.text_input("Tên chương trình *", r.get("TenCT", ""))
        with c2: fe.slot("ten")
        dt = st.text_input("Đối tượng học viên *", r.get("DoiTuong", "")); fe.slot("dt")
        mt = st.text_area("Mô tả", r.get("MoTa") or "", height=80)
        if st.form_submit_button("Lưu", type="primary"):
            fe.check("ma", re.fullmatch(r"[A-Z]{2,5}", ma.strip().upper()) is not None, "2–5 chữ cái in hoa, VD IELTS")
            fe.check("ten", ten.strip() != "", "Không được để trống")
            fe.check("dt", dt.strip() != "", "Không được để trống")
            if fe.ok:
                ui.run(lambda: db.call_proc("sp_LuuChuongTrinh", {"MaCT": ma.strip().upper(), "TenCT": ten.strip(),
                                                                  "DoiTuong": dt.strip(), "MoTa": mt.strip() or None}),
                       "Đã lưu chương trình.")
    if sel and st.button(f"Xoá chương trình {r['MaCT']}", icon=":material/delete:"):
        ui.run(lambda: db.call_proc("sp_XoaChuongTrinh", {"MaCT": r["MaCT"]}), "Đã xoá chương trình.")

with tab_kh:
    with st.container():
        f_ct = ui.pick("Chương trình", "SELECT MaCT, TenCT FROM vw_DM_ChuongTrinh ORDER BY MaCT", allow_empty=True,
                       empty_label="— tất cả —", key="loc_ct")
    df = db.query("SELECT * FROM vw_DM_KhoaHoc WHERE ? IS NULL OR MaCT = ? ORDER BY MaCT, CapDo", [f_ct, f_ct])
    df["KhoangDiem"] = df["DiemDauVaoTu"].astype(str) + " – " + df["DiemDauVaoDen"].astype(str)
    sel = ui.table(df, {"MaKH": "Mã", "TenKH": "Khoá học", "TenCT": "Chương trình", "CapDo": "Cấp", "KhoangDiem": "Điểm test phù hợp",
                        "MucTieuDauRa": "Đầu ra", "SoBuoi": "Số buổi", "HocPhi": "Học phí", "KhoaTienQuyet": "Tiên quyết",
                        "SoLop": "Số lớp"}, key="t_kh", money_cols=("HocPhi",))
    r = sel or {}
    st.subheader(f"Sửa khoá học {r['MaKH']}" if sel else "Thêm khoá học")
    # Chọn chương trình ngoài form để danh sách khoá tiên quyết cập nhật ngay khi đổi chương trình
    ct = ui.pick("Chương trình của khoá *", "SELECT MaCT, TenCT FROM vw_DM_ChuongTrinh ORDER BY MaCT",
                 r.get("MaCT") or f_ct, key=f"kh_ct_{r.get('MaKH', 'moi')}")
    with st.form("f_kh", clear_on_submit=not sel):
        fe = ui.FieldErrors()
        c1, c2, c4 = st.columns([1, 2.4, 0.8])
        ma = c1.text_input("Mã khoá *", r.get("MaKH", ""), disabled=bool(sel), max_chars=6)
        with c1: fe.slot("ma")
        ten = c2.text_input("Tên khoá học *", r.get("TenKH", ""))
        with c2: fe.slot("ten")
        cap = c4.number_input("Cấp độ *", 1, 10, int(r.get("CapDo") or 1))
        c1, c2, c3, c4, c5 = st.columns(5)
        tu = c1.number_input("Điểm test từ *", 0.0, 10.0, float(r.get("DiemDauVaoTu") or 0), step=0.1, format="%.1f")
        den = c2.number_input("đến *", 0.0, 10.0, float(r.get("DiemDauVaoDen") or 3.9), step=0.1, format="%.1f")
        with c2: fe.slot("den")
        dr = c3.text_input("Mục tiêu đầu ra *", r.get("MucTieuDauRa", ""))
        with c3: fe.slot("dr")
        sb = c4.number_input("Số buổi *", 8, 60, int(r.get("SoBuoi") or 24))
        hp = c5.number_input("Học phí (đ) *", 100_000, 100_000_000, int(r.get("HocPhi") or 4_000_000), step=100_000)
        tq = ui.pick("Khoá tiên quyết (cùng chương trình)", "SELECT MaKH, TenKH FROM vw_DM_KhoaHoc WHERE MaCT = ? ORDER BY CapDo",
                     r.get("MaKHTienQuyet"), allow_empty=True, key="kh_tq", params=(ct,))
        if st.form_submit_button("Lưu", type="primary"):
            fe.check("ma", re.fullmatch(r"[A-Z0-9]{2,6}", ma.strip().upper()) is not None, "2–6 ký tự chữ in hoa / số")
            fe.check("ten", ten.strip() != "", "Không được để trống")
            fe.check("den", tu <= den, "Điểm 'đến' phải lớn hơn hoặc bằng điểm 'từ'")
            fe.check("dr", dr.strip() != "", "Không được để trống")
            if fe.ok:
                if tq == ma.strip().upper():
                    st.error("Khoá học không thể là tiên quyết của chính nó.")
                else:
                    ui.run(lambda: db.call_proc("sp_LuuKhoaHoc", {
                        "MaKH": ma.strip().upper(), "TenKH": ten.strip(), "MaCT": ct, "CapDo": cap, "DiemDauVaoTu": tu,
                        "DiemDauVaoDen": den, "MucTieuDauRa": dr.strip(), "SoBuoi": sb, "HocPhi": hp, "MaKHTienQuyet": tq}),
                        "Đã lưu khoá học.")
    if sel and st.button(f"Xoá khoá học {r['MaKH']}", icon=":material/delete:"):
        ui.run(lambda: db.call_proc("sp_XoaKhoaHoc", {"MaKH": r["MaKH"]}), "Đã xoá khoá học.")
