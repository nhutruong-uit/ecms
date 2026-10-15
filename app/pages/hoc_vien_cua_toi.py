"""Trang của học viên: lịch học tuần, bảng điểm, học phí (T21). Chỉ đọc dữ liệu của chính học viên đăng nhập."""
from datetime import date, timedelta

import streamlit as st

from core import auth, db, ui

user = auth.require_role("HocVien")
ma_hv = user["ma_hv"]
ui.header("🎒 Lịch học & kết quả của tôi", user["ho_ten"])

t1, t2, t3 = st.tabs(["Lịch học tuần", "Bảng điểm", "Học phí"], key="tabs", on_change="rerun")
with t1:
    ngay = st.date_input("Tuần chứa ngày", date.today(), format="DD/MM/YYYY")
    dau = ngay - timedelta(days=ngay.weekday())
    st.caption(f"Từ {dau:%d/%m} đến {dau + timedelta(days=6):%d/%m/%Y}")
    lich = db.query("SELECT * FROM dbo.fn_LichHocHocVien(?, ?) ORDER BY NgayHoc, GioBatDau", [ma_hv, ngay])
    if lich.empty:
        st.info("Không có buổi học nào trong tuần này.")
    ui.table(lich, {"NgayHoc": "Ngày", "Thu": "Thứ", "TenCa": "Ca", "GioBatDau": "Từ", "GioKetThuc": "Đến", "MaLop": "Lớp",
                    "TenKH": "Khoá học", "MaPhong": "Phòng", "BuoiThu": "Buổi", "NoiDung": "Nội dung", "GiaoVien": "Giáo viên"},
             key="t_lich", select=False)
with t2:
    bd = db.query("""SELECT MaLop, TenKH, DiemGK, DiemCK, DiemTB, XepLoai, ChuyenCan, KetQua, TrangThai
                     FROM vw_BangDiem WHERE MaHV = ? ORDER BY MaLop""", [ma_hv])
    ui.table(bd, {"MaLop": "Lớp", "TenKH": "Khoá học", "DiemGK": "Giữa kỳ", "DiemCK": "Cuối kỳ", "DiemTB": "Trung bình",
                  "XepLoai": "Xếp loại", "ChuyenCan": "Chuyên cần %", "KetQua": "Kết quả", "TrangThai": "Trạng thái"},
             key="t_bd", select=False)
with t3:
    hp = db.query("SELECT MaLop, TenKH, ThanhTien, TrangThaiHP, HanDongHP FROM vw_DangKyChiTiet WHERE MaHV = ? ORDER BY NgayDK", [ma_hv])
    no = db.scalar("SELECT ISNULL(SUM(ConNo), 0) FROM vw_CongNoHocVien WHERE MaHV = ?", [ma_hv])
    st.metric("Còn phải đóng", ui.money(no))
    ui.table(hp, {"MaLop": "Lớp", "TenKH": "Khoá học", "ThanhTien": "Học phí", "TrangThaiHP": "Trạng thái", "HanDongHP": "Hạn đóng"},
             key="t_hp", select=False, money_cols=("ThanhTien",))
