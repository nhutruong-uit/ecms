"""Dashboard tổng hợp (T24): KPI học viên mới, doanh thu, tỷ lệ lấp đầy, chuyên cần + biểu đồ cột, đường, tròn."""
from datetime import date

import pandas as pd
import plotly.express as px
import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "KeToan")
ui.header("📊 Dashboard", "Thông tin tổng hợp phục vụ ra quyết định (tầng Knowledge trong mô hình DIKW).")

pham_vi = user["pham_vi_cn"] == "ALL"
c1, c2 = st.columns([1, 3])
with c1:
    cn = ui.pick("Chi nhánh", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN", None if pham_vi else user["ma_cn"],
                 allow_empty=pham_vi, empty_label="Toàn trung tâm", key="db_cn", disabled=not pham_vi)
nam = c2.radio("Năm", [date.today().year, date.today().year - 1], horizontal=True)

hom_nay = date.today()
dau_thang = hom_nay.replace(day=1)
thang_truoc = (pd.Timestamp(dau_thang) - pd.DateOffset(months=1)).date()
# vw_HocVien_ChiNhanh lọc theo phạm vi người dùng; lọc thêm chi nhánh đang chọn
k = db.query("""
SELECT (SELECT COUNT(*) FROM vw_HocVien_ChiNhanh WHERE NgayTao >= ? AND (? IS NULL OR MaCN = ?)) AS HVMoi,
       (SELECT COUNT(*) FROM vw_HocVien_ChiNhanh WHERE NgayTao >= ? AND NgayTao < ? AND (? IS NULL OR MaCN = ?)) AS HVMoiTruoc,
       (SELECT ISNULL(SUM(DoanhThu), 0) FROM vw_DoanhThuThang WHERE Nam = ? AND Thang = ? AND (? IS NULL OR MaCN = ?)) AS DTThang,
       (SELECT ISNULL(SUM(DoanhThu), 0) FROM vw_DoanhThuThang WHERE Nam = ? AND Thang = ? AND (? IS NULL OR MaCN = ?)) AS DTTruoc,
       (SELECT ISNULL(SUM(DoanhThu), 0) FROM vw_DoanhThuThang WHERE Nam = ? AND (? IS NULL OR MaCN = ?)) AS DTNam,
       (SELECT 100.0 * SUM(SiSoHienTai) / NULLIF(SUM(SiSoToiDa), 0) FROM vw_SiSoLop
         WHERE TrangThai IN (N'Đang học', N'Sắp mở') AND (? IS NULL OR MaCN = ?)) AS LapDay,
       (SELECT AVG(b.ChuyenCan) FROM vw_BangDiem b JOIN vw_SiSoLop l ON l.MaLop = b.MaLop
         WHERE l.TrangThai = N'Đang học' AND (? IS NULL OR l.MaCN = ?)) AS ChuyenCan,
       (SELECT ISNULL(SUM(ConNo), 0) FROM vw_CongNoHocVien WHERE ? IS NULL OR MaCN = ?) AS CongNo
""", [dau_thang, cn, cn, thang_truoc, dau_thang, cn, cn, hom_nay.year, hom_nay.month, cn, cn,
      thang_truoc.year, thang_truoc.month, cn, cn, nam, cn, cn, cn, cn, cn, cn, cn, cn]).iloc[0]

m1, m2, m3 = st.columns(3)
m4, m5, m6 = st.columns(3)
m1.metric("Học viên mới tháng này", int(k.HVMoi), int(k.HVMoi - k.HVMoiTruoc))
m2.metric("Doanh thu tháng này", ui.money_short(k.DTThang), ui.money_short(float(k.DTThang) - float(k.DTTruoc)))
m3.metric(f"Doanh thu năm {nam}", ui.money_short(k.DTNam))
m4.metric("Lấp đầy lớp đang mở", f"{float(k.LapDay or 0):.1f}%")
m5.metric("Chuyên cần lớp đang học", f"{float(k.ChuyenCan or 0):.1f}%")
m6.metric("Công nợ hiện tại", ui.money_short(k.CongNo), help=ui.money(k.CongNo))

dt = db.query("""SELECT TenCN, Nam, Thang, SUM(SoTien) AS DoanhThu FROM vw_BaoCaoDoanhThu
                 WHERE Nam = ? AND (? IS NULL OR MaCN = ?) GROUP BY TenCN, Nam, Thang""", [nam, cn, cn])
dt["Tháng"] = dt.Thang.map(lambda t: f"T{t:02d}")
dt["DoanhThu"] = dt.DoanhThu.astype(float) / 1e6

c1, c2 = st.columns([3, 2])
with c1:
    st.subheader("Doanh thu theo tháng (triệu đồng)")
    fig = px.bar(dt.sort_values("Thang"), x="Tháng", y="DoanhThu", color="TenCN", barmode="stack",
                 labels={"DoanhThu": "Triệu đồng", "TenCN": "Chi nhánh"})
    luy_ke = dt.groupby("Thang").DoanhThu.sum().cumsum().reset_index()
    fig.add_scatter(x=luy_ke.Thang.map(lambda t: f"T{t:02d}"), y=luy_ke.DoanhThu, mode="lines+markers", name="Luỹ kế", yaxis="y2")
    fig.update_layout(height=360, margin=dict(t=10, b=10), legend=dict(orientation="h", y=-0.2),
                      xaxis=dict(categoryorder="category ascending"),
                      yaxis2=dict(overlaying="y", side="right", showgrid=False, title="Luỹ kế"))
    st.plotly_chart(fig, width="stretch")
with c2:
    st.subheader("Cơ cấu doanh thu theo chương trình")
    ct = db.query("SELECT TenCT, SUM(SoTien) AS DoanhThu FROM vw_BaoCaoDoanhThu WHERE Nam = ? AND (? IS NULL OR MaCN = ?) GROUP BY TenCT",
                  [nam, cn, cn])
    ct["DoanhThu"] = ct.DoanhThu.astype(float)
    fig = px.pie(ct, names="TenCT", values="DoanhThu", hole=0.45)
    fig.update_layout(height=360, margin=dict(t=10, b=10), legend=dict(orientation="h", y=-0.2))
    st.plotly_chart(fig, width="stretch")

c1, c2 = st.columns(2)
with c1:
    st.subheader("Tỷ lệ lấp đầy lớp đang mở")
    lop = db.query("""SELECT MaLop, TenKH, TyLeLapDay, TrangThai FROM vw_SiSoLop
                      WHERE TrangThai IN (N'Đang học', N'Sắp mở') AND (? IS NULL OR MaCN = ?)""", [cn, cn])
    lop["TyLeLapDay"] = lop.TyLeLapDay.astype(float)
    fig = px.bar(lop.sort_values("TyLeLapDay"), x="TyLeLapDay", y="MaLop", color="TrangThai", orientation="h", text="TyLeLapDay",
                 labels={"TyLeLapDay": "% lấp đầy", "MaLop": ""}, range_x=[0, 105])
    fig.add_vline(x=80, line_dash="dot", annotation_text="mục tiêu 80%")
    fig.update_traces(texttemplate="%{text:.0f}%")
    fig.update_layout(height=340, margin=dict(t=10, b=10), legend=dict(orientation="h", y=-0.25))
    st.plotly_chart(fig, width="stretch")
with c2:
    st.subheader("Học viên mới theo tháng")
    hv = db.query("""SELECT MONTH(NgayTao) AS Thang, COUNT(*) AS SoHV FROM vw_HocVien_ChiNhanh
                     WHERE YEAR(NgayTao) = ? AND (? IS NULL OR MaCN = ?) GROUP BY MONTH(NgayTao)""", [nam, cn, cn])
    hv["Tháng"] = hv.Thang.map(lambda t: f"T{t:02d}")
    fig = px.line(hv.sort_values("Thang"), x="Tháng", y="SoHV", markers=True, labels={"SoHV": "Học viên mới"})
    fig.update_layout(height=340, margin=dict(t=10, b=10))
    st.plotly_chart(fig, width="stretch")

st.subheader("Chuyên cần và kết quả theo lớp đã kết thúc trong năm")
kq = db.query("""SELECT b.MaLop, AVG(b.ChuyenCan) AS ChuyenCan, AVG(b.DiemTB) AS DiemTB,
                        100.0 * SUM(CASE WHEN b.KetQua = N'Đạt' THEN 1 ELSE 0 END) / COUNT(*) AS TyLeDat, COUNT(*) AS SiSo
                 FROM vw_BangDiem b JOIN vw_SiSoLop l ON l.MaLop = b.MaLop
                 WHERE l.TrangThai = N'Đã kết thúc' AND YEAR(l.NgayKetThuc) = ? AND (? IS NULL OR l.MaCN = ?)
                 GROUP BY b.MaLop""", [nam, cn, cn])
if kq.empty:
    st.info("Chưa có lớp kết thúc trong năm đã chọn.")
else:
    for c in ("ChuyenCan", "DiemTB", "TyLeDat"):
        kq[c] = kq[c].astype(float)
    fig = px.scatter(kq, x="ChuyenCan", y="DiemTB", size="SiSo", color="TyLeDat", text="MaLop", color_continuous_scale="RdYlGn",
                     labels={"ChuyenCan": "Chuyên cần TB (%)", "DiemTB": "Điểm TB", "TyLeDat": "Tỷ lệ đạt %"})
    fig.update_traces(textposition="top center")
    fig.update_layout(height=380, margin=dict(t=10, b=10))
    st.plotly_chart(fig, width="stretch")
    st.caption("Mỗi bong bóng là một lớp (kích thước = sĩ số). Lớp nằm góc dưới trái hoặc màu đỏ (chuyên cần, điểm, tỷ lệ đạt thấp) "
               "là lớp cần quản lý xem lại giáo viên, lịch học hoặc chăm sóc học viên.")
