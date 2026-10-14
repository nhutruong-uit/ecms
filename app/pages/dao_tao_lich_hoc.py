"""Đào tạo: xếp lịch cố định cho lớp, sinh buổi học tự động, xem lịch tuần (T20).
Xếp lịch gọi sp_XepLichLop (báo trùng phòng / giáo viên); sinh buổi gọi sp_SinhBuoiHoc (cursor – T14)."""
from datetime import date, timedelta

import pandas as pd
import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "GiaoVu")
ui.header("🗓️ Xếp lịch & buổi học")
ui.show_flash()

THU = {2: "Thứ 2", 3: "Thứ 3", 4: "Thứ 4", 5: "Thứ 5", 6: "Thứ 6", 7: "Thứ 7", 8: "Chủ nhật"}
tab_lop, tab_tuan = st.tabs(["Lịch của một lớp", "Lịch tuần toàn chi nhánh"], key="tabs", on_change="rerun")

def lich_cua_lop():
    cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
    lop = ui.pick("Lớp", """SELECT MaLop, TenLop + N' · ' + TrangThai FROM vw_SiSoLop
                           WHERE TrangThai IN (N'Sắp mở', N'Đang học') AND (? IS NULL OR MaCN = ?) ORDER BY NgayKhaiGiang""",
                  key="lh_lop", params=(cn, cn))
    if not lop:
        st.info("Chưa có lớp sắp mở / đang học.")
        return
    info = db.query("SELECT * FROM vw_SiSoLop WHERE MaLop = ?", [lop]).iloc[0]
    sb = int(db.scalar("SELECT SoBuoi FROM vw_DM_KhoaHoc WHERE MaKH = ?", [info.MaKH]))
    st.markdown(f"**{info.TenKH}** · {info.TenCN} · GV **{info.GiaoVien}** · khai giảng "
                f"**{pd.to_datetime(info.NgayKhaiGiang):%d/%m/%Y}** · {sb} buổi · sĩ số {info.SiSoHienTai}/{info.SiSoToiDa}")

    lich = db.query("SELECT * FROM vw_LichHoc WHERE MaLop = ? ORDER BY Thu, GioBatDau", [lop])
    buoi = db.query("SELECT * FROM vw_BuoiHoc WHERE MaLop = ? ORDER BY STT", [lop])

    st.markdown("#### Lịch cố định trong tuần")
    ui.table(lich, {"TenThu": "Thứ", "TenCa": "Ca", "GioBatDau": "Từ", "GioKetThuc": "Đến", "MaPhong": "Phòng"}, key="t_lh", select=False)
    if buoi.empty:
        with st.form("f_lh"):
            c1, c2, c3 = st.columns(3)
            thu = c1.selectbox("Thứ", list(THU), format_func=THU.get)
            with c2:
                ca = ui.pick("Ca", "SELECT MaCa, TenCa + N' (' + LEFT(CONVERT(VARCHAR, GioBatDau, 108), 5) + N')' FROM vw_DM_CaHoc ORDER BY GioBatDau", key="lh_ca")
            with c3:
                ph = ui.pick("Phòng", "SELECT MaPhong, LoaiPhong + N', ' + CAST(SucChua AS NVARCHAR) + N' chỗ' FROM vw_DM_PhongHoc WHERE MaCN = ? ORDER BY MaPhong",
                             key="lh_ph", params=(info.MaCN,))
            if st.form_submit_button("Thêm vào lịch", type="primary"):
                ui.run(lambda: db.call_proc("sp_XepLichLop", {"MaLop": lop, "Thu": thu, "MaCa": ca, "MaPhong": ph}),
                       f"Đã xếp {THU[thu]} – ca {ca} – phòng {ph}.")
        if not lich.empty:
            c1, c2 = st.columns([3, 1])
            bo = c1.selectbox("Bỏ một buổi khỏi lịch", list(lich.itertuples(index=False)),
                              format_func=lambda x: f"{x.TenThu} · {x.TenCa} · {x.MaPhong}")
            if c2.button("Bỏ khỏi lịch", icon=":material/remove:"):
                ui.run(lambda: db.call_proc("sp_XoaLichLop", {"MaLop": lop, "Thu": int(bo.Thu), "MaCa": int(bo.MaCa)}), "Đã bỏ khỏi lịch.")

    st.markdown("#### Buổi học")
    if buoi.empty:
        if lich.empty:
            st.info("Xếp lịch cố định trước, rồi sinh buổi học.")
        elif st.button(f"Sinh {sb} buổi học tự động", type="primary", icon=":material/auto_awesome:",
                       help="Duyệt từng ngày từ ngày khai giảng theo lịch cố định, bỏ qua ngày lễ"):
            out = ui.run(lambda: db.call_proc("sp_SinhBuoiHoc", {"MaLop": lop}, outputs={"SoBuoiTao": "INT"}), rerun=False)
            if out is not None:
                ui.flash(f"Đã sinh {out['SoBuoiTao']} buổi học.")
                st.rerun()
    else:
        da_dd = int(buoi["SoDaDiemDanh"].sum())
        st.caption(f"{len(buoi)} buổi · từ {buoi.NgayHoc.min():%d/%m/%Y} đến {buoi.NgayHoc.max():%d/%m/%Y}"
                   + (f" · đã điểm danh {(buoi.SoDaDiemDanh > 0).sum()} buổi" if da_dd else ""))
        ui.table(buoi, {"STT": "Buổi", "NgayHoc": "Ngày", "Thu": "Thứ", "TenCa": "Ca", "MaPhong": "Phòng",
                        "NoiDung": "Nội dung", "TrangThai": "Trạng thái", "SoDaDiemDanh": "Đã điểm danh", "SoVang": "Vắng"},
                 key="t_bh", select=False, height=320)
        if da_dd == 0 and st.button("Sinh lại buổi học", icon=":material/refresh:",
                                    help="Xoá các buổi đã sinh và sinh lại theo lịch hiện tại"):
            ui.run(lambda: db.call_proc("sp_SinhBuoiHoc", {"MaLop": lop, "SinhLai": 1}, outputs={"SoBuoiTao": "INT"}),
                   "Đã sinh lại buổi học.")


with tab_lop:
    lich_cua_lop()

with tab_tuan:
    c1, c2 = st.columns(2)
    with c1:
        cn = ui.pick("Chi nhánh", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN",
                     None if user["pham_vi_cn"] == "ALL" else user["ma_cn"], key="tuan_cn")
    ngay = c2.date_input("Tuần chứa ngày", date.today(), format="DD/MM/YYYY")
    dau = ngay - timedelta(days=ngay.weekday())
    b = db.query("""SELECT NgayHoc, MaCa, TenCa, MaLop, MaPhong FROM vw_BuoiHoc
                    WHERE MaCN = ? AND NgayHoc >= ? AND NgayHoc < ?""", [cn, dau, dau + timedelta(days=7)])
    st.caption(f"Tuần {dau:%d/%m} – {dau + timedelta(days=6):%d/%m/%Y} · {len(b)} buổi")
    ca = db.query("SELECT MaCa, TenCa, GioBatDau FROM vw_DM_CaHoc ORDER BY GioBatDau")
    cols = [f"{THU[(dau + timedelta(days=i)).weekday() + 2]} {dau + timedelta(days=i):%d/%m}" for i in range(7)]
    grid = pd.DataFrame("", index=[f"{r.TenCa} ({r.GioBatDau.strftime('%H:%M')})" for r in ca.itertuples()], columns=cols)
    for r in b.itertuples():
        row = ca.index[ca.MaCa == r.MaCa][0]
        col = (pd.to_datetime(r.NgayHoc).date() - dau).days
        cell = grid.iat[row, col]
        grid.iat[row, col] = (cell + " | " if cell else "") + f"{r.MaLop} · {r.MaPhong}"
    grid = grid.rename_axis("Ca").reset_index().astype(object)
    st.dataframe(grid, hide_index=True, height=260)
