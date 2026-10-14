"""Xem nhật ký kiểm toán do trigger ghi (T13, T19)."""
import json
from datetime import date, timedelta

import streamlit as st

from core import auth, db, ui

auth.require_role("QuanLy")
ui.header("🕑 Nhật ký hệ thống", "Mọi thay đổi trên đăng ký, phiếu thu và lương nhân viên – chỉ được thêm, không sửa / xoá.")

c1, c2, c3, c4 = st.columns(4)
bang = c1.selectbox("Bảng", [None, "DANGKY", "PHIEUTHU", "NHANVIEN"], format_func=lambda v: v or "— tất cả —")
tt = c2.selectbox("Thao tác", [None, "INSERT", "UPDATE", "DELETE"], format_func=lambda v: v or "— tất cả —")
tu = c3.date_input("Từ ngày", date.today() - timedelta(days=30), format="DD/MM/YYYY")
den = c4.date_input("Đến ngày", date.today(), format="DD/MM/YYYY")
df = db.query("""SELECT TOP 500 * FROM vw_NhatKy WHERE (? IS NULL OR TenBang = ?) AND (? IS NULL OR ThaoTac = ?)
                 AND ThoiGian >= ? AND ThoiGian < DATEADD(DAY, 1, ?) ORDER BY MaNK DESC""", [bang, bang, tt, tt, tu, den])
st.caption(f"{len(df)} dòng (tối đa 500 dòng mới nhất)")
sel = ui.table(df, {"ThoiGian": "Thời gian", "TenBang": "Bảng", "ThaoTac": "Thao tác", "KhoaChinh": "Khoá",
                    "NguoiDungUD": "Tài khoản ứng dụng", "NguoiThucHien": "Login SQL"}, key="t_nk")
if sel:
    cu = json.loads(sel["DuLieuCu"]) if sel["DuLieuCu"] else {}
    moi = json.loads(sel["DuLieuMoi"]) if sel["DuLieuMoi"] else {}
    rows = [{"Trường": k, "Trước": cu.get(k), "Sau": moi.get(k), "Thay đổi": "●" if cu.get(k) != moi.get(k) else ""}
            for k in dict.fromkeys([*cu, *moi])]
    st.subheader(f"{sel['ThaoTac']} {sel['TenBang']} {sel['KhoaChinh']}")
    st.dataframe(rows, hide_index=True)
