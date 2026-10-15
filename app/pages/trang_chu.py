"""Trang chủ: lời chào và số liệu nhanh theo vai trò (T19)."""
import streamlit as st

from core import auth, db, ui
from core.config import APP_TITLE

user = auth.require_role()
ui.header(f"Xin chào, {user['ho_ten']}", f"{APP_TITLE} · {auth.ROLES[user['role']]}")
ui.show_flash()

if user["role"] == "HocVien":
    st.info("Xem lịch học, điểm và học phí ở mục **Lịch học & kết quả của tôi**.")
    st.stop()

cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
k = db.query("""
    SELECT (SELECT COUNT(*) FROM vw_SiSoLop WHERE TrangThai = N'Đang học' AND (? IS NULL OR MaCN = ?)) AS LopDangHoc,
           (SELECT COUNT(*) FROM vw_SiSoLop WHERE TrangThai = N'Sắp mở' AND (? IS NULL OR MaCN = ?)) AS LopSapMo,
           (SELECT COUNT(*) FROM vw_HocVien_ChiNhanh WHERE TrangThai = 1) AS HocVien,
           (SELECT ISNULL(SUM(ConNo), 0) FROM vw_CongNoHocVien WHERE ? IS NULL OR MaCN = ?) AS CongNo
""", [cn, cn, cn, cn, cn, cn]).iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Lớp đang học", int(k.LopDangHoc))
c2.metric("Lớp sắp khai giảng", int(k.LopSapMo))
c3.metric("Học viên", int(k.HocVien))
if user["role"] in ("QuanLy", "KeToan", "GiaoVu"):
    c4.metric("Công nợ học phí", ui.money_short(k.CongNo), help=ui.money(k.CongNo))

st.subheader("Lớp đang học và sắp mở")
lop = db.query("""SELECT MaLop, TenKH, TenCN, GiaoVien, NgayKhaiGiang, SiSoHienTai, SiSoToiDa, TyLeLapDay, Lich, TrangThai
                  FROM vw_SiSoLop WHERE TrangThai IN (N'Đang học', N'Sắp mở') AND (? IS NULL OR MaCN = ?)
                  ORDER BY NgayKhaiGiang""", [cn, cn])
ui.table(lop, {"MaLop": "Lớp", "TenKH": "Khoá học", "TenCN": "Chi nhánh", "GiaoVien": "Giáo viên",
               "NgayKhaiGiang": "Khai giảng", "SiSoHienTai": "Sĩ số", "SiSoToiDa": "Tối đa",
               "TyLeLapDay": "Lấp đầy (%)", "Lich": "Lịch học", "TrangThai": "Trạng thái"}, key="lop", select=False)
