"""Ghi danh: chọn học viên → lớp còn chỗ (lọc theo khoá đề xuất) → sp_DangKyHoc; huỷ, chuyển lớp (T21)."""
import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "GiaoVu")
ui.header("✍️ Ghi danh", "Chọn học viên, xem kết quả kiểm tra đầu vào rồi ghi danh vào lớp còn chỗ. Hệ thống tự kiểm tra "
                         "lớp đầy, đăng ký trùng và điều kiện khoá tiên quyết.")
ui.show_flash()
cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]     # tài khoản chi nhánh chỉ ghi danh / chuyển vào lớp chi nhánh mình

q = st.text_input("Tìm học viên (tên, SĐT hoặc mã)", placeholder="VD: 0901 hoặc Lan")
if not q.strip():
    st.info("Nhập tên, số điện thoại hoặc mã học viên để bắt đầu.")
    st.stop()
ds = db.query("""SELECT TOP 30 MaHV, HoTen, SoDienThoai FROM vw_HocVien_ChiNhanh
                 WHERE (HoTen LIKE ? OR SoDienThoai LIKE ? OR MaHV LIKE ?) AND TrangThai = 1 ORDER BY TenHV""", [f"%{q}%"] * 3)
if ds.empty:
    st.warning("Không tìm thấy học viên.")
    st.stop()
hv = st.selectbox("Học viên", ds.MaHV.tolist(),
                  format_func=lambda m: f"{ds.set_index('MaHV').loc[m, 'HoTen']} · {ds.set_index('MaHV').loc[m, 'SoDienThoai']} ({m})")

kt = db.query("SELECT TOP 1 NgayKT, DiemTong, MaKHDeXuat, KhoaDeXuat FROM vw_KiemTraChiTiet WHERE MaHV = ? ORDER BY NgayKT DESC, MaKT DESC", [hv])
if kt.empty:
    st.warning("Học viên chưa kiểm tra đầu vào – vẫn ghi danh được khoá không yêu cầu tiên quyết.")
    de_xuat = None
else:
    k = kt.iloc[0]
    de_xuat = k.MaKHDeXuat
    st.markdown(f"Kiểm tra gần nhất **{k.NgayKT:%d/%m/%Y}** · điểm **{k.DiemTong}** · khoá đề xuất **{k.KhoaDeXuat or '—'}**")

st.subheader("Đăng ký hiện có")
dk = db.query("""SELECT MaDK, MaLop, TenKH, NgayDK, ThanhTien, TrangThaiHP, TrangThai, KetQua, MaKH
                 FROM vw_DangKyChiTiet WHERE MaHV = ? ORDER BY NgayDK DESC""", [hv])
dsel = ui.table(dk, {"MaLop": "Lớp", "TenKH": "Khoá học", "NgayDK": "Ngày ĐK", "ThanhTien": "Thành tiền",
                     "TrangThaiHP": "Học phí", "TrangThai": "Trạng thái", "KetQua": "Kết quả"}, key="t_dk", money_cols=("ThanhTien",))
if dsel and dsel["TrangThai"] in ("Đang học", "Bảo lưu"):
    c1, c2, c3 = st.columns([1, 2, 1])
    with c1:
        huy = ui.nut_xoa("Huỷ đăng ký", key=f"x_dk_{dsel['MaDK']}", icon=":material/cancel:",
                         canh_bao="Chỉ huỷ được đăng ký chưa đóng tiền và học viên chưa đi buổi nào (ghi danh nhầm). "
                                  "Học viên đã đi học thì dùng Chuyển lớp.")
    if huy:
        ui.run(lambda: db.call_proc("sp_HuyDangKy", {"MaDK": int(dsel["MaDK"])}), f"Đã huỷ đăng ký lớp {dsel['MaLop']}.")
    cung_khoa = db.query("""SELECT MaLop, TenLop, ConCho FROM vw_SiSoLop WHERE MaKH = ? AND MaLop <> ?
                            AND TrangThai IN (N'Sắp mở', N'Đang học') AND ConCho > 0 AND (? IS NULL OR MaCN = ?)""",
                         [dsel["MaKH"], dsel["MaLop"], cn, cn])
    if not cung_khoa.empty:
        dich = c2.selectbox("Chuyển sang lớp cùng khoá", cung_khoa.MaLop.tolist(),
                            format_func=lambda m: f"{m} (còn {cung_khoa.set_index('MaLop').loc[m, 'ConCho']} chỗ)")
        if c3.button("Chuyển lớp", icon=":material/swap_horiz:"):
            ui.run(lambda: db.call_proc("sp_ChuyenLop", {"MaDK": int(dsel["MaDK"]), "MaLopMoi": dich}, outputs={"MaDKMoi": "INT"}),
                   f"Đã chuyển sang lớp {dich}; khoản đã đóng được chuyển theo.")

st.subheader("Ghi danh lớp mới")
chi_de_xuat = st.toggle("Chỉ hiện lớp của khoá đề xuất", value=bool(de_xuat), disabled=not de_xuat)
lop = db.query("""SELECT MaLop, TenLop, TenKH, MaKH, TenCN, GiaoVien, NgayKhaiGiang, Lich, SiSoHienTai, SiSoToiDa, ConCho, TrangThai
                  FROM vw_SiSoLop WHERE TrangThai IN (N'Sắp mở', N'Đang học') AND (? IS NULL OR MaCN = ?)
                    AND (? = 0 OR MaKH = ?) ORDER BY ConCho DESC, NgayKhaiGiang""",
               [cn, cn, int(chi_de_xuat), de_xuat])
lop["ConChoTxt"] = lop.apply(lambda x: "ĐẦY" if x.ConCho <= 0 else str(x.ConCho), axis=1)
lsel = ui.table(lop, {"MaLop": "Lớp", "TenKH": "Khoá học", "TenCN": "Chi nhánh", "GiaoVien": "Giáo viên",
                      "NgayKhaiGiang": "Khai giảng", "Lich": "Lịch", "SiSoHienTai": "Sĩ số", "SiSoToiDa": "Tối đa",
                      "ConChoTxt": "Còn chỗ", "TrangThai": "Trạng thái"}, key="t_lop_dk")
if lsel:
    hp = db.scalar("SELECT HocPhi FROM vw_DM_KhoaHoc WHERE MaKH = ?", [lsel["MaKH"]])
    with st.form("f_dk"):
        c1, c2 = st.columns(2)
        gg = c1.slider("Giảm giá (%)", 0, 50, 0, step=5, help="Học viên cũ học tiếp thường được 10%")
        c2.metric("Thành tiền", ui.money(round(float(hp) * (100 - gg) / 100, -3)), help=f"Học phí khoá: {ui.money(hp)}")
        if st.form_submit_button(f"Ghi danh vào {lsel['MaLop']}", type="primary", icon=":material/how_to_reg:"):
            ui.run(lambda: db.call_proc("sp_DangKyHoc", {"MaHV": hv, "MaLop": lsel["MaLop"], "GiamGia": gg}, outputs={"MaDK": "INT"}),
                   f"Đã ghi danh vào lớp {lsel['MaLop']}. Kế toán có thể lập phiếu thu.")
