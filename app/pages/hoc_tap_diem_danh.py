"""Điểm danh cả lớp một lần lưu (st.data_editor → sp_DiemDanhBuoi) (T22)."""
import json
from datetime import date

import streamlit as st

from core import auth, db, lop, ui

user = auth.require_role("GiaoVien", "QuanLy")
ui.header("✅ Điểm danh", "Chọn lớp và buổi, sửa trạng thái từng học viên rồi lưu một lần cho cả lớp.")
ui.show_flash()

TT = ["Có mặt", "Muộn", "Có phép", "Vắng"]
ma_lop = lop.chon_lop(user, key="dd_lop")
if ma_lop:
    buoi = db.query("SELECT STT, NgayHoc, TenCa, NoiDung, SoDaDiemDanh FROM vw_BuoiHoc WHERE MaLop = ? AND NgayHoc <= ? ORDER BY STT DESC",
                    [ma_lop, date.today()])
    if buoi.empty:
        st.info("Lớp chưa có buổi học nào đến ngày.")
        st.stop()
    nhan = {r.STT: f"Buổi {r.STT} · {r.NgayHoc:%d/%m/%Y} · {r.TenCa} · {r.NoiDung}" + (" ✔" if r.SoDaDiemDanh else " (chưa điểm danh)")
            for r in buoi.itertuples()}
    stt = st.selectbox("Buổi học", list(nhan), format_func=nhan.get)
    hv = db.query("""SELECT d.MaDK, d.MaHV, d.HoTenHV AS HoTen, dd.TrangThai, dd.GhiChu
                     FROM vw_DangKyChiTiet d LEFT JOIN vw_DiemDanh dd ON dd.MaDK = d.MaDK AND dd.STT = ?
                     WHERE d.MaLop = ? AND d.TrangThai = N'Đang học' ORDER BY d.HoTenHV""", [stt, ma_lop])
    da_co = hv["TrangThai"].notna().any()
    hv["TrangThai"] = hv["TrangThai"].fillna("Có mặt")
    hv["GhiChu"] = hv["GhiChu"].fillna("")
    st.caption(("Đã điểm danh – có thể sửa." if da_co else "Chưa điểm danh – mặc định tất cả Có mặt.") + f" {len(hv)} học viên.")
    sua = st.data_editor(
        hv, hide_index=True, key=f"ed_{ma_lop}_{stt}", disabled=["MaDK", "MaHV", "HoTen"],
        column_config={"MaDK": None, "MaHV": "Mã HV", "HoTen": "Họ tên",
                       "TrangThai": st.column_config.SelectboxColumn("Trạng thái", options=TT, required=True),
                       "GhiChu": st.column_config.TextColumn("Ghi chú", max_chars=200)})
    c1, c2, c3, c4 = st.columns(4)
    for col, t in zip((c1, c2, c3, c4), TT):
        col.metric(t, int((sua["TrangThai"] == t).sum()))
    if st.button("Lưu điểm danh", type="primary", icon=":material/save:"):
        ds = json.dumps([{"MaDK": int(r.MaDK), "TrangThai": r.TrangThai, "GhiChu": r.GhiChu or None} for r in sua.itertuples()],
                        ensure_ascii=False)
        ui.run(lambda: db.call_proc("sp_DiemDanhBuoi", {"MaLop": ma_lop, "STT": int(stt), "DanhSach": ds}),
               f"Đã lưu điểm danh buổi {stt} cho {len(sua)} học viên.")
