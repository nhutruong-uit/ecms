"""Công nợ học viên (vw_CongNoHocVien) – định dạng có điều kiện: nợ quá hạn tô đỏ (T23)."""
import streamlit as st

from core import auth, db, ui

user = auth.require_role("KeToan", "QuanLy", "GiaoVu")
ui.header("💰 Công nợ học phí", "Đăng ký chưa đóng đủ. Hạn đóng = ngày đăng ký + 14 ngày.")

cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
c1, c2, c3 = st.columns([1, 1, 2])
chi_qua_han = c1.toggle("Chỉ nợ quá hạn")
nguong = c2.number_input("Nợ từ (đ)", 0, 100_000_000, 0, step=500_000)
q = c3.text_input("Tìm học viên / lớp")
df = db.query("""SELECT MaHV, HoTen, SoDienThoai, MaLop, TenKH, MaCN, ThanhTien, DaThu, ConNo, HanDongHP, TrangThaiHP, QuaHan, SoNgayQuaHan
                 FROM vw_CongNoHocVien WHERE (? IS NULL OR MaCN = ?) AND (? = 0 OR QuaHan = 1) AND ConNo >= ?
                 AND (HoTen LIKE ? OR MaHV LIKE ? OR MaLop LIKE ?) ORDER BY QuaHan DESC, SoNgayQuaHan DESC, ConNo DESC""",
              [cn, cn, int(chi_qua_han), nguong, f"%{q}%", f"%{q}%", f"%{q}%"])

c1, c2, c3 = st.columns(3)
c1.metric("Tổng còn nợ", ui.money_short(df.ConNo.sum()), help=ui.money(df.ConNo.sum()))
c2.metric("Số đăng ký còn nợ", len(df))
c3.metric("Quá hạn", int(df.QuaHan.sum()), help=ui.money(df[df.QuaHan == 1].ConNo.sum()))

view = df.rename(columns={"MaHV": "Mã HV", "HoTen": "Học viên", "SoDienThoai": "Điện thoại", "MaLop": "Lớp", "TenKH": "Khoá học",
                          "ThanhTien": "Phải đóng", "DaThu": "Đã thu", "ConNo": "Còn nợ", "HanDongHP": "Hạn đóng",
                          "TrangThaiHP": "Trạng thái", "SoNgayQuaHan": "Quá hạn (ngày)"}).drop(columns=["MaCN", "QuaHan"])


def to_mau(row):
    """Định dạng có điều kiện: quá hạn > 30 ngày đỏ đậm, quá hạn nền đỏ nhạt, sắp đến hạn vàng."""
    n = row["Quá hạn (ngày)"]
    if n > 30:
        return ["background-color: #fecaca; color: #7f1d1d; font-weight: 600"] * len(row)
    if n > 0:
        return ["background-color: #fee2e2; color: #991b1b"] * len(row)
    return ["background-color: #fef9c3; color: #713f12"] * len(row) if row["Đã thu"] == 0 else [""] * len(row)


fmt = {c: (lambda v: ui.money(v)) for c in ("Phải đóng", "Đã thu", "Còn nợ")}
st.dataframe(view.style.apply(to_mau, axis=1).format(fmt), hide_index=True, height=480)
st.caption("🟥 quá hạn trên 30 ngày · đỏ nhạt: quá hạn · 🟨 chưa đóng đồng nào, chưa tới hạn")
