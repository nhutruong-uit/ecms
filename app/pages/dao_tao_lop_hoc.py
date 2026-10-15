"""Đào tạo: mở lớp, sửa lớp, huỷ lớp (T20)."""
from datetime import date, timedelta

import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "GiaoVu")
ui.header("👥 Lớp học", "Mở lớp cho một khoá học tại một chi nhánh, chọn giáo viên phụ trách. Lịch học xếp ở trang Xếp lịch.")
ui.show_flash()

TRANG_THAI = ["Sắp mở", "Đang học", "Đã kết thúc", "Huỷ"]
cn_mac_dinh = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
c1, c2, c3, c4 = st.columns(4)
with c1:
    f_cn = ui.pick("Chi nhánh", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN", cn_mac_dinh, allow_empty=True,
                   empty_label="— tất cả —", key="l_cn")
with c2:
    f_kh = ui.pick("Khoá học", "SELECT MaKH, TenKH FROM vw_DM_KhoaHoc ORDER BY MaCT, CapDo", allow_empty=True,
                   empty_label="— tất cả —", key="l_kh")
f_tt = c3.multiselect("Trạng thái", TRANG_THAI, ["Sắp mở", "Đang học"])
f_q = c4.text_input("Tìm mã / tên lớp / giáo viên")
df = db.query("""SELECT * FROM vw_SiSoLop WHERE (? IS NULL OR MaCN = ?) AND (? IS NULL OR MaKH = ?)
                 AND (MaLop LIKE ? OR TenLop LIKE ? OR GiaoVien LIKE ?) ORDER BY NgayKhaiGiang DESC""",
              [f_cn, f_cn, f_kh, f_kh, f"%{f_q}%", f"%{f_q}%", f"%{f_q}%"])
if f_tt:
    df = df[df["TrangThai"].isin(f_tt)]
st.caption(f"{len(df)} lớp")
sel = ui.table(df, {"MaLop": "Mã lớp", "TenLop": "Tên lớp", "TenKH": "Khoá học", "TenCN": "Chi nhánh", "GiaoVien": "Giáo viên",
                    "NgayKhaiGiang": "Khai giảng", "NgayKetThuc": "Kết thúc", "SiSoHienTai": "Sĩ số", "SiSoToiDa": "Tối đa",
                    "TyLeLapDay": "Lấp đầy %", "Lich": "Lịch", "TrangThai": "Trạng thái"}, key="t_lop")

r = sel or {}
st.subheader(f"Sửa lớp {r['MaLop']}" if sel else "Mở lớp mới")
# Khoá học và chi nhánh chọn ngoài form để danh sách giáo viên / tên lớp gợi ý cập nhật ngay
c1, c2 = st.columns(2)
with c1:
    kh = ui.pick("Khoá học *", "SELECT MaKH, TenKH FROM vw_DM_KhoaHoc ORDER BY MaCT, CapDo", r.get("MaKH") or f_kh,
                 key=f"f_kh_{r.get('MaLop', 'moi')}", disabled=bool(sel) and r.get("SiSoHienTai", 0) > 0)
with c2:
    cn = ui.pick("Chi nhánh *", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN", r.get("MaCN") or f_cn or user["ma_cn"],
                 key=f"f_cn_{r.get('MaLop', 'moi')}", disabled=bool(sel) and r.get("SiSoHienTai", 0) > 0)
ten_kh = next((t for m, t in ui.options("SELECT MaKH, TenKH FROM vw_DM_KhoaHoc") if m == kh), "")

with st.form("f_lop", clear_on_submit=not sel):
    fe = ui.FieldErrors()
    c1, c2 = st.columns([2, 1])
    ngay_mac_dinh = date.today() + timedelta(days=14)
    ten = c1.text_input("Tên lớp *", r.get("TenLop") or f"{ten_kh} – {(cn or '')[-2:]}")
    with c1: fe.slot("ten")
    with c2:
        gv = ui.pick("Giáo viên phụ trách *", """SELECT MaNV, HoTen + ISNULL(N' (' + LoaiGV + N')', N'') FROM vw_NhanVien
                                                 WHERE ChucVu = N'Giáo viên' AND TrangThai = 1 ORDER BY CASE WHEN MaCN = ? THEN 0 ELSE 1 END, TenNV""",
                     r.get("MaGV"), key="f_gv", params=(cn,))
    c1, c2, c3 = st.columns(3)
    kg = c1.date_input("Ngày khai giảng *", ui.to_date(r.get("NgayKhaiGiang"), ngay_mac_dinh), format="DD/MM/YYYY")
    with c1: fe.slot("kg")
    ss = c2.number_input("Sĩ số tối đa *", 5, 40, int(r.get("SiSoToiDa") or 25))
    with c2: fe.slot("ss")
    tt = c3.selectbox("Trạng thái", TRANG_THAI, index=TRANG_THAI.index(r.get("TrangThai", "Sắp mở")), disabled=not sel)
    if st.form_submit_button("Lưu", type="primary"):
        fe.check("ten", ten.strip() != "", "Không được để trống")
        fe.check("kg", bool(sel) or kg >= date.today(), "Lớp mới phải khai giảng từ hôm nay trở đi")
        fe.check("ss", ss >= int(r.get("SiSoHienTai") or 0), f"Lớp đang có {int(r.get('SiSoHienTai') or 0)} học viên")
        if fe.ok:
            out = ui.run(lambda: db.call_proc("sp_LuuLopHoc", {
                "MaLop": r.get("MaLop"), "TenLop": ten.strip(), "MaKH": kh, "MaCN": cn, "MaGV": gv, "NgayKhaiGiang": kg,
                "SiSoToiDa": ss, "TrangThai": tt}, outputs={"MaLopMoi": "VARCHAR(10)"}), rerun=False)
            if out is not None:
                ui.flash(f"Đã lưu lớp {out['MaLopMoi']}." + ("" if sel else " Tiếp theo: xếp lịch học ở trang Xếp lịch & buổi học."))
                st.rerun()

if sel and r.get("TrangThai") in ("Sắp mở",):
    if st.button(f"Xoá / huỷ lớp {r['MaLop']}", icon=":material/cancel:"):
        res = ui.run(lambda: db.call_proc("sp_XoaLopHoc", {"MaLop": r["MaLop"]}, fetch=True), rerun=False)
        if res is not None:
            ui.flash(res[0].iloc[0]["ThongBao"], "info")
            st.rerun()
