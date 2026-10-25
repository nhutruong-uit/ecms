"""Kiểm tra đầu vào: nhập điểm 4 kỹ năng → lưu XML (sp_GhiKetQuaKiemTra), xem chi tiết đọc từ XML, gợi ý khoá học (T21)."""
import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "GiaoVu")
ui.header("📝 Kiểm tra đầu vào", "Nhập điểm 4 kỹ năng (0–10). Hệ thống từ chối bài thiếu kỹ năng hoặc điểm sai và gợi ý khoá học phù hợp.")
ui.show_flash()


def chon_hoc_vien(key: str):
    """Tìm học viên theo tên / SĐT / mã rồi chọn trong danh sách (giới hạn theo chi nhánh)."""
    q = st.text_input("Tìm học viên (tên, SĐT hoặc mã)", key=f"{key}_q", placeholder="VD: 0901 hoặc Lan")
    if not q.strip():
        return None
    ds = db.query("""SELECT TOP 30 MaHV, HoTen, SoDienThoai, NgaySinh FROM vw_HocVien_ChiNhanh
                     WHERE HoTen LIKE ? OR SoDienThoai LIKE ? OR MaHV LIKE ? ORDER BY TenHV""", [f"%{q}%"] * 3)
    if ds.empty:
        st.warning("Không tìm thấy. Thêm hồ sơ mới ở trang Hồ sơ học viên.")
        return None
    return st.selectbox("Chọn học viên", ds.MaHV.tolist(), key=f"{key}_sel",
                        format_func=lambda m: " · ".join(str(v) for v in ds.set_index("MaHV").loc[m, ["HoTen", "SoDienThoai"]]) + f" ({m})")


tab_nhap, tab_xem = st.tabs(["Nhập kết quả", "Xem chi tiết (đọc từ XML)"], key="tabs", on_change="rerun")

with tab_nhap:
    hv = chon_hoc_vien("nhap")
    if hv:
        with st.form("f_kt", clear_on_submit=True):
            c1, c2 = st.columns(2)
            with c1:
                ct = ui.pick("Chương trình quan tâm", "SELECT MaCT, TenCT FROM vw_DM_ChuongTrinh ORDER BY MaCT", allow_empty=True,
                             empty_label="— chưa xác định —", key="kt_ct")
            hinh_thuc = c2.radio("Hình thức", ["Tại trung tâm", "Online"], horizontal=True)
            diem, nx = {}, {}
            cols = st.columns(4)
            for col, kn in zip(cols, ["Listening", "Reading", "Writing", "Speaking"]):
                diem[kn] = col.number_input(kn, 0.0, 10.0, 5.0, step=0.5, format="%.1f", key=f"d_{kn}")
                nx[kn] = col.text_input(f"Nhận xét {kn}", key=f"n_{kn}")
            nxc = st.text_area("Nhận xét chung", height=70)
            if st.form_submit_button("Lưu kết quả", type="primary"):
                out = ui.run(lambda: db.call_proc("sp_GhiKetQuaKiemTra", {
                    "MaHV": hv, "Listening": diem["Listening"], "Reading": diem["Reading"], "Writing": diem["Writing"],
                    "Speaking": diem["Speaking"], "MaCT": ct, "HinhThuc": hinh_thuc,
                    "NhanXetL": nx["Listening"] or None, "NhanXetR": nx["Reading"] or None, "NhanXetW": nx["Writing"] or None,
                    "NhanXetS": nx["Speaking"] or None, "NhanXetChung": nxc.strip() or None, "MaNVCham": user["ma_nv"]},
                    outputs={"MaKT": "INT", "MaKHDeXuat": "VARCHAR(6)"}), rerun=False)
                if out is not None:
                    st.session_state["kt_vua_luu"] = (hv, out["MaKT"], out["MaKHDeXuat"])
                    ui.flash(f"Đã lưu bài kiểm tra #{out['MaKT']}. Khoá đề xuất: {out['MaKHDeXuat'] or 'không có khoá phù hợp'}.")
                    st.rerun()
    if st.session_state.get("kt_vua_luu"):
        hv0, ma_kt, kh = st.session_state["kt_vua_luu"]
        tong = db.scalar("SELECT DiemTong FROM vw_KiemTraChiTiet WHERE MaKT = ?", [ma_kt])
        st.markdown(f"**Gợi ý khoá học cho điểm {tong}**")
        gy = db.query("SELECT * FROM dbo.fn_GoiYKhoaHoc(?, NULL) ORDER BY MaCT", [tong])
        ui.table(gy, {"MaKH": "Mã", "TenKH": "Khoá học", "MaCT": "Chương trình", "MucTieuDauRa": "Đầu ra", "HocPhi": "Học phí",
                      "SoLopConCho": "Lớp còn chỗ"}, key="t_gy", select=False, money_cols=("HocPhi",))
        st.page_link("pages/hoc_vien_ghi_danh.py", label="Ghi danh ngay", icon=":material/how_to_reg:")

with tab_xem:
    hv = chon_hoc_vien("xem")
    if hv:
        ds = db.query("SELECT * FROM vw_KiemTraChiTiet WHERE MaHV = ? ORDER BY NgayKT DESC, MaKT DESC", [hv])
        if ds.empty:
            st.info("Học viên chưa có bài kiểm tra nào.")
        for r in ds.itertuples():
            with st.expander(f"#{r.MaKT} · {r.NgayKT:%d/%m/%Y} · {r.HinhThuc} · điểm tổng {r.DiemTong} · đề xuất {r.KhoaDeXuat or '—'}",
                             expanded=r.Index == 0):
                c1, c2 = st.columns([1.2, 1])
                with c1:
                    st.caption("Điểm từng kỹ năng")
                    kn = db.query("SELECT * FROM dbo.fn_KyNangKiemTra(?)", [r.MaKT])
                    st.bar_chart(kn.set_index("KyNang")["Diem"], height=180, y_label="Điểm", x_label="")
                    ui.table(kn, {"KyNang": "Kỹ năng", "Diem": "Điểm", "NhanXet": "Nhận xét"}, key=f"kn_{r.MaKT}", select=False)
                    if r.NhanXetChung:
                        st.markdown(f"**Nhận xét chung:** {r.NhanXetChung}")
                with c2:
                    with st.expander("Dữ liệu gốc (XML)"):          # cho quản trị / kỹ thuật đối chiếu, người dùng không cần xem
                        st.code(r.XmlGoc.replace("><", ">\n<"), language="xml")
