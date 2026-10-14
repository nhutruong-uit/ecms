"""Nhập điểm giữa kỳ / cuối kỳ cả lớp (sp_NhapDiem); trigger tự tính kết quả (T22)."""
import json

import pandas as pd
import streamlit as st

from core import auth, db, lop, ui

user = auth.require_role("GiaoVien", "QuanLy")
ui.header("💯 Nhập điểm", "Điểm 0–10, bước 0,25. Điểm TB = 0,4·GK + 0,6·CK; Đạt khi TB ≥ 5 (trigger trg_DangKy_KetQua).")
ui.show_flash()

ma_lop = lop.chon_lop(user, chi_dang_hoc=False, key="nd_lop")
if ma_lop:
    bd = db.query("""SELECT MaDK, MaHV, HoTen, DiemGK, DiemCK, DiemTB, XepLoai, ChuyenCan, KetQua
                     FROM vw_BangDiem WHERE MaLop = ? ORDER BY HoTen""", [ma_lop])
    for c in ("DiemGK", "DiemCK", "DiemTB", "ChuyenCan"):
        bd[c] = pd.to_numeric(bd[c]).astype("float64")      # ô trống hiển thị rỗng thay vì "None"
    for c in ("XepLoai", "KetQua"):
        bd[c] = bd[c].fillna("")
    diem = st.column_config.NumberColumn(min_value=0.0, max_value=10.0, step=0.25, format="%.2f")
    sua = st.data_editor(
        bd, hide_index=True, key=f"nd_{ma_lop}", disabled=["MaDK", "MaHV", "HoTen", "DiemTB", "XepLoai", "ChuyenCan", "KetQua"],
        column_config={"MaDK": None, "MaHV": "Mã HV", "HoTen": "Họ tên",
                       "DiemGK": st.column_config.NumberColumn("Giữa kỳ", min_value=0.0, max_value=10.0, step=0.25, format="%.2f"),
                       "DiemCK": st.column_config.NumberColumn("Cuối kỳ", min_value=0.0, max_value=10.0, step=0.25, format="%.2f"),
                       "DiemTB": st.column_config.NumberColumn("TB", format="%.2f"), "XepLoai": "Xếp loại",
                       "ChuyenCan": st.column_config.ProgressColumn("Chuyên cần", min_value=0, max_value=100, format="%.0f%%"),
                       "KetQua": "Kết quả"})
    thay_doi = sua[(sua.DiemGK.fillna(-1) != bd.DiemGK.fillna(-1)) | (sua.DiemCK.fillna(-1) != bd.DiemCK.fillna(-1))]
    st.caption(f"{len(thay_doi)} học viên có thay đổi chưa lưu.")
    if st.button("Lưu điểm", type="primary", icon=":material/save:", disabled=thay_doi.empty):
        ds = json.dumps([{"MaDK": int(r.MaDK),
                          "DiemGK": None if pd.isna(r.DiemGK) else float(r.DiemGK),
                          "DiemCK": None if pd.isna(r.DiemCK) else float(r.DiemCK)} for r in thay_doi.itertuples()])
        ui.run(lambda: db.call_proc("sp_NhapDiem", {"MaLop": ma_lop, "DanhSach": ds}, outputs={"SoDong": "INT"}),
               f"Đã lưu điểm cho {len(thay_doi)} học viên.")
