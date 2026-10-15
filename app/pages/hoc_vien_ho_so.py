"""Hồ sơ học viên: tìm kiếm nhiều tiêu chí (sp_TimKiemHocVien, phân trang), thêm / sửa, xem lịch sử học tập (T21)."""
import re
from datetime import date

import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "GiaoVu")
ui.header("🔎 Hồ sơ học viên", "Danh sách tự giới hạn theo chi nhánh của người đăng nhập (row-level security).")
ui.show_flash()

SO_DONG = 15
with st.form("f_tim"):
    c1, c2, c3, c4 = st.columns([2, 1, 1.4, 1])
    tu = c1.text_input("Tên, mã HV, SĐT hoặc email", st.session_state.get("hv_tu", ""))
    with c2:
        cn = ui.pick("Chi nhánh", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN", allow_empty=True, empty_label="— tất cả —",
                     key="hv_cn", disabled=user["pham_vi_cn"] != "ALL")
    with c3:
        kh = ui.pick("Đã / đang học khoá", "SELECT MaKH, TenKH FROM vw_DM_KhoaHoc ORDER BY MaCT, CapDo", allow_empty=True,
                     empty_label="— bất kỳ —", key="hv_kh")
    no = c4.selectbox("Học phí", [None, 1, 0], format_func={None: "— tất cả —", 1: "Còn nợ", 0: "Đã đóng đủ"}.get)
    if st.form_submit_button("Tìm", type="primary", icon=":material/search:"):
        st.session_state["hv_trang"] = 1
        st.session_state["hv_tu"] = tu

trang = st.session_state.get("hv_trang", 1)
try:
    df, out = db.call_proc("sp_TimKiemHocVien", {"TuKhoa": tu or None, "MaCN": cn, "MaKH": kh, "ConNo": no,
                                                 "Trang": trang, "SoDongTrang": SO_DONG},
                           outputs={"TongSo": "INT"}, fetch=True)
except db.DbError as e:
    st.error(e.message)
    st.stop()
tong = int(out.get("TongSo") or 0)
so_trang = max(1, -(-tong // SO_DONG))
c1, c2, c3 = st.columns([3, 1, 1])
c1.caption(f"{tong} học viên · trang {trang}/{so_trang}")
if c2.button("◀ Trang trước", disabled=trang <= 1, width="stretch"):
    st.session_state["hv_trang"] = trang - 1
    st.rerun()
if c3.button("Trang sau ▶", disabled=trang >= so_trang, width="stretch"):
    st.session_state["hv_trang"] = trang + 1
    st.rerun()
sel = ui.table(df, {"MaHV": "Mã", "HoTen": "Họ tên", "NgaySinh": "Ngày sinh", "Tuoi": "Tuổi", "SoDienThoai": "Điện thoại",
                    "Email": "Email", "TenCN": "Chi nhánh", "SoLopDaDangKy": "Số lớp", "ConNo": "Còn nợ"},
               key=f"t_hv_{trang}", money_cols=("ConNo",))

r = {}
if sel:
    r = db.query("SELECT * FROM vw_HocVien_ChiNhanh WHERE MaHV = ?", [sel["MaHV"]]).iloc[0].to_dict()
    st.subheader(f"{r['MaHV']} – {r['HoTen']}")
    t1, t2, t3, t4 = st.tabs(["Lớp đã học & điểm", "Kiểm tra đầu vào", "Học phí", "Sửa hồ sơ"], key="tabs", on_change="rerun")
    with t1:
        lop = db.query("""SELECT d.MaLop, d.TenKH, d.NgayKhaiGiang, d.TrangThaiLop, d.TrangThai, b.DiemGK, b.DiemCK, b.DiemTB,
                                 b.XepLoai, b.ChuyenCan, d.KetQua
                          FROM vw_DangKyChiTiet d LEFT JOIN vw_BangDiem b ON b.MaDK = d.MaDK
                          WHERE d.MaHV = ? ORDER BY d.NgayKhaiGiang""", [r["MaHV"]])
        ui.table(lop, {"MaLop": "Lớp", "TenKH": "Khoá học", "NgayKhaiGiang": "Khai giảng", "TrangThaiLop": "Trạng thái lớp", "TrangThai": "Đăng ký",
                       "DiemGK": "GK", "DiemCK": "CK", "DiemTB": "TB", "XepLoai": "Xếp loại", "ChuyenCan": "Chuyên cần %",
                       "KetQua": "Kết quả"}, key="t_lsh", select=False)
    with t2:
        kt = db.query("""SELECT NgayKT, HinhThuc, Listening, Reading, Writing, Speaking, DiemTong, KhoaDeXuat, NguoiCham
                         FROM vw_KiemTraChiTiet WHERE MaHV = ? ORDER BY NgayKT DESC""", [r["MaHV"]])
        ui.table(kt, {"NgayKT": "Ngày", "HinhThuc": "Hình thức", "Listening": "L", "Reading": "R", "Writing": "W", "Speaking": "S",
                      "DiemTong": "Tổng", "KhoaDeXuat": "Khoá đề xuất", "NguoiCham": "Người chấm"}, key="t_kt", select=False)
    with t3:
        hp = db.query("SELECT MaLop, TenKH, ThanhTien, TrangThaiHP, HanDongHP FROM vw_DangKyChiTiet WHERE MaHV = ? ORDER BY NgayDK", [r["MaHV"]])
        ui.table(hp, {"MaLop": "Lớp", "TenKH": "Khoá học", "ThanhTien": "Phải đóng", "TrangThaiHP": "Trạng thái", "HanDongHP": "Hạn đóng"},
                 key="t_hp", select=False, money_cols=("ThanhTien",))
        st.metric("Tổng còn nợ", ui.money(sel["ConNo"]))
    form_tab = t4
else:
    st.subheader("Thêm học viên mới")
    form_tab = st.container()

with form_tab, st.form("f_hv", clear_on_submit=not r):
    fe = ui.FieldErrors()
    c1, c2, c3, c4 = st.columns([2, 1, 1, 1])
    ho = c1.text_input("Họ và tên lót *", r.get("HoHV", ""))
    with c1: fe.slot("ho")
    ten = c2.text_input("Tên *", r.get("TenHV", ""))
    with c2: fe.slot("ten")
    gt = c3.radio("Giới tính", ["Nam", "Nữ"], index=["Nam", "Nữ"].index(r.get("GioiTinh", "Nam")), horizontal=True)
    ns = c4.date_input("Ngày sinh *", ui.to_date(r.get("NgaySinh"), date(2005, 1, 1)), min_value=date(1950, 1, 1),
                       max_value=date.today(), format="DD/MM/YYYY")
    with c4: fe.slot("ns")
    c1, c2, c3 = st.columns(3)
    sdt = c1.text_input("Điện thoại *", r.get("SoDienThoai", ""))
    with c1: fe.slot("sdt")
    email = c2.text_input("Email", r.get("Email") or "")
    with c2: fe.slot("email")
    ph = c3.text_input("Họ tên phụ huynh (bắt buộc nếu dưới 16 tuổi)", r.get("HoTenPhuHuynh") or "")
    with c3: fe.slot("ph")
    c1, c2, c3, c4 = st.columns([2, 1, 1, 1])
    sn = c1.text_input("Số nhà, đường", r.get("SoNha") or "")
    px = c2.text_input("Phường / xã", r.get("PhuongXa") or "")
    qh = c3.text_input("Quận / huyện", r.get("QuanHuyen") or "")
    tp = c4.text_input("Tỉnh / TP", r.get("TinhTP") or "TP. Hồ Chí Minh")
    c1, c2 = st.columns(2)
    with c1:
        ma_cn = ui.pick("Chi nhánh tiếp nhận *", "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN",
                        r.get("MaCN") or user["ma_cn"], key="hv_f_cn", disabled=user["pham_vi_cn"] != "ALL")
    tt = c2.toggle("Đang theo học", bool(r.get("TrangThai", True)))
    if st.form_submit_button("Lưu hồ sơ", type="primary"):
        fe.check("ho", ho.strip() != "", "Không được để trống")
        fe.check("ten", ten.strip() != "" and " " not in ten.strip(), "Tên là một từ, VD: Lan")
        tuoi = date.today().year - ns.year - ((date.today().month, date.today().day) < (ns.month, ns.day))
        fe.check("ns", tuoi >= 4, "Học viên phải từ 4 tuổi")
        fe.check("sdt", re.fullmatch(r"0\d{8,10}", sdt.strip()) is not None, "SĐT bắt đầu bằng 0, 9–11 chữ số")
        fe.check("email", not email.strip() or re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email.strip()) is not None, "Email không hợp lệ")
        fe.check("ph", tuoi >= 16 or ph.strip() != "", "Học viên dưới 16 tuổi cần họ tên phụ huynh")
        if fe.ok:
            out = ui.run(lambda: db.call_proc("sp_LuuHocVien", {
                "MaHV": r.get("MaHV"), "HoHV": ho.strip(), "TenHV": ten.strip(), "NgaySinh": ns, "GioiTinh": gt,
                "SoDienThoai": sdt.strip(), "Email": email.strip().lower() or None, "SoNha": sn.strip() or None,
                "PhuongXa": px.strip() or None, "QuanHuyen": qh.strip() or None, "TinhTP": tp.strip() or "TP. Hồ Chí Minh",
                "HoTenPhuHuynh": ph.strip() or None, "MaCN": ma_cn, "TrangThai": tt}, outputs={"MaHVMoi": "CHAR(6)"}), rerun=False)
            if out is not None:
                ui.flash(f"Đã lưu hồ sơ {out['MaHVMoi']}." + ("" if r else " Tiếp theo: kiểm tra đầu vào."))
                st.rerun()
