"""Danh mục nhân viên, giáo viên và chứng chỉ (T19).
Lương chỉ hiển thị cho Quản lý và Kế toán; Kế toán chỉ xem."""
import re
from datetime import date

import streamlit as st

from core import auth, db, ui

user = auth.require_role("QuanLy", "KeToan")
sua_duoc = user["role"] == "QuanLy"
ui.header("🪪 Nhân viên & giáo viên", "Giáo viên là nhân viên có thêm loại, trình độ, đơn giá buổi dạy và chứng chỉ.")
ui.show_flash()

CHUC_VU = ["Quản lý", "Giáo vụ", "Kế toán", "Giáo viên"]
c1, c2, c3, c4 = st.columns([1, 1, 1, 2])
with c1:
    f_cn = ui.chon_chi_nhanh(user, key="f_cn")           # kế toán / quản lý chi nhánh chỉ thấy lương chi nhánh mình
f_cv = c2.selectbox("Chức vụ", [None] + CHUC_VU, format_func=lambda v: v or "— tất cả —")
f_tt = c3.selectbox("Trạng thái", [1, 0, None], format_func={1: "Đang làm", 0: "Đã nghỉ", None: "— tất cả —"}.get)
f_q = c4.text_input("Tìm theo tên, mã, SĐT, email")
q = f"%{f_q.strip()}%"
df = db.query("""SELECT * FROM vw_NhanVien
                 WHERE (? IS NULL OR MaCN = ?) AND (? IS NULL OR ChucVu = ?) AND (? IS NULL OR TrangThai = ?)
                   AND (HoTen LIKE ? OR MaNV LIKE ? OR SoDienThoai LIKE ? OR Email LIKE ?)
                 ORDER BY MaCN, ChucVu, TenNV""", [f_cn, f_cn, f_cv, f_cv, f_tt, f_tt, q, q, q, q])
st.caption(f"{len(df)} nhân viên")
sel = ui.table(df, {"MaNV": "Mã", "HoTen": "Họ tên", "ChucVu": "Chức vụ", "TenCN": "Chi nhánh", "SoDienThoai": "Điện thoại",
                    "Email": "Email", "LuongCoBan": "Lương cơ bản", "LoaiGV": "Loại GV", "DonGiaBuoi": "Đơn giá buổi",
                    "ChungChi": "Chứng chỉ", "NguoiQuanLy": "Quản lý trực tiếp"},
               key="t_nv", money_cols=("LuongCoBan", "DonGiaBuoi"))

if not sua_duoc:
    st.info("Kế toán chỉ xem danh sách để tính lương; mọi thay đổi do Quản lý thực hiện.")
    st.stop()

r = sel or {}
st.subheader(f"Sửa {r['MaNV']} – {r['HoTen']}" if sel else "Thêm nhân viên")
with st.form("f_nv", clear_on_submit=not sel):
    fe = ui.FieldErrors()
    c1, c2, c3, c4 = st.columns([2, 1, 1, 1])
    ho = c1.text_input("Họ và tên lót *", r.get("HoNV", ""))
    with c1: fe.slot("ho")
    ten = c2.text_input("Tên *", r.get("TenNV", ""))
    with c2: fe.slot("ten")
    gt = c3.radio("Giới tính", ["Nam", "Nữ"], index=["Nam", "Nữ"].index(r.get("GioiTinh", "Nam")), horizontal=True)
    ns = c4.date_input("Ngày sinh *", ui.to_date(r.get("NgaySinh"), date(1995, 1, 1)), min_value=date(1950, 1, 1),
                       max_value=date.today(), format="DD/MM/YYYY")
    with c4: fe.slot("ns")
    c1, c2, c3, c4 = st.columns(4)
    sdt = c1.text_input("Điện thoại *", r.get("SoDienThoai", ""))
    with c1: fe.slot("sdt")
    email = c2.text_input("Email *", r.get("Email", ""))
    with c2: fe.slot("email")
    cv = c3.selectbox("Chức vụ *", CHUC_VU, index=CHUC_VU.index(r.get("ChucVu", "Giáo vụ")))
    luong = c4.number_input("Lương cơ bản (đ) *", 0, 200_000_000, int(r.get("LuongCoBan") or 8_000_000), step=500_000)
    c1, c2, c3, c4 = st.columns(4)
    with c1:
        cn = ui.chon_chi_nhanh(user, "Chi nhánh *", r.get("MaCN"), allow_all=False, key="nv_cn")
    nvl = c2.date_input("Ngày vào làm *", ui.to_date(r.get("NgayVaoLam"), date.today()), format="DD/MM/YYYY")
    with c2: fe.slot("nvl")
    with c3:
        ql = ui.pick("Quản lý trực tiếp", "SELECT MaNV, HoTen FROM vw_NhanVien WHERE TrangThai = 1 AND ChucVu IN (N'Quản lý', N'Giáo viên')",
                     r.get("MaNVQuanLy"), allow_empty=True, key="nv_ql")
    tt = c4.toggle("Đang làm việc", bool(r.get("TrangThai", True)))
    st.markdown("**Thông tin giáo viên** (bắt buộc khi chức vụ là Giáo viên)")
    c1, c2, c3, c4 = st.columns(4)
    loai = c1.selectbox("Loại giáo viên", ["Việt Nam", "Bản ngữ"], index=["Việt Nam", "Bản ngữ"].index(r.get("LoaiGV") or "Việt Nam"))
    qt = c2.text_input("Quốc tịch", r.get("QuocTich") or "Việt Nam")
    td = c3.selectbox("Trình độ", ["Cử nhân", "Thạc sĩ", "Tiến sĩ"], index=["Cử nhân", "Thạc sĩ", "Tiến sĩ"].index(r.get("TrinhDo") or "Cử nhân"))
    dg = c4.number_input("Đơn giá buổi (đ)", 100_000, 5_000_000, int(r.get("DonGiaBuoi") or 400_000), step=50_000)
    if st.form_submit_button("Lưu", type="primary"):
        fe.check("ho", ho.strip() != "", "Không được để trống")
        fe.check("ten", ten.strip() != "" and " " not in ten.strip(), "Tên là một từ, VD: Mai")
        fe.check("sdt", re.fullmatch(r"0\d{9,10}", sdt.strip()) is not None, "SĐT bắt đầu bằng 0, gồm 10–11 chữ số")
        fe.check("email", re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email.strip()) is not None, "Email không hợp lệ")
        tuoi = nvl.year - ns.year - ((nvl.month, nvl.day) < (ns.month, ns.day))
        fe.check("ns", 18 <= tuoi <= 65, "Phải từ 18 đến 65 tuổi tại ngày vào làm")
        fe.check("nvl", nvl <= date.today(), "Ngày vào làm không được ở tương lai")
        if fe.ok:
            p = {"MaNV": r.get("MaNV"), "HoNV": ho.strip(), "TenNV": ten.strip(), "NgaySinh": ns, "GioiTinh": gt,
                 "SoDienThoai": sdt.strip(), "Email": email.strip().lower(), "ChucVu": cv, "LuongCoBan": luong,
                 "NgayVaoLam": nvl, "MaCN": cn, "MaNVQuanLy": ql if ql != r.get("MaNV") else None, "TrangThai": tt}
            if cv == "Giáo viên":
                p |= {"LoaiGV": loai, "QuocTich": qt.strip() or "Việt Nam", "TrinhDo": td, "DonGiaBuoi": dg}
            out = ui.run(lambda: db.call_proc("sp_LuuNhanVien", p, outputs={"MaNVMoi": "CHAR(6)"}), rerun=False)
            if out is not None:
                ui.flash(f"Đã lưu nhân viên {out['MaNVMoi']}.")
                st.rerun()

if sel:
    if ui.nut_xoa(f"Xoá / cho nghỉ {r['MaNV']}", key=f"x_nv_{r['MaNV']}", icon=":material/person_remove:",
                  canh_bao="Nhân viên đã có lớp, phiếu thu, bảng lương… sẽ được chuyển sang Đã nghỉ và khoá tài khoản thay vì xoá."):
        res = ui.run(lambda: db.call_proc("sp_XoaNhanVien", {"MaNV": r["MaNV"]}, fetch=True), rerun=False)
        if res is not None:
            ui.flash(res[0].iloc[0]["ThongBao"], "info")
            st.rerun()

    if r.get("ChucVu") == "Giáo viên":
        st.subheader(f"Chứng chỉ của {r['HoTen']}")
        cc = db.query("SELECT TenChungChi, Diem, NgayCap, NoiCap FROM vw_ChungChiGV WHERE MaGV = ? ORDER BY NgayCap", [r["MaNV"]])
        csel = ui.table(cc, {"TenChungChi": "Chứng chỉ", "Diem": "Điểm", "NgayCap": "Ngày cấp", "NoiCap": "Nơi cấp"}, key="t_cc")
        with st.form("f_cc", clear_on_submit=True):
            c1, c2, c3, c4 = st.columns(4)
            ten_cc = c1.text_input("Tên chứng chỉ *", (csel or {}).get("TenChungChi", ""))
            diem = c2.number_input("Điểm (bỏ trống nếu không có)", 0.0, 990.0, float((csel or {}).get("Diem") or 0), step=0.5)
            ngay = c3.date_input("Ngày cấp *", ui.to_date((csel or {}).get("NgayCap"), date.today()), max_value=date.today(),
                                 format="DD/MM/YYYY")
            noi = c4.text_input("Nơi cấp", (csel or {}).get("NoiCap") or "")
            if st.form_submit_button("Lưu chứng chỉ"):
                if not ten_cc.strip():
                    st.error("Nhập tên chứng chỉ.")
                else:
                    ui.run(lambda: db.call_proc("sp_LuuChungChi", {"MaGV": r["MaNV"], "TenChungChi": ten_cc.strip(),
                                                                  "Diem": diem or None, "NgayCap": ngay, "NoiCap": noi.strip() or None}),
                           "Đã lưu chứng chỉ.")
        if csel and ui.nut_xoa(f"Xoá chứng chỉ {csel['TenChungChi']}", key=f"x_cc_{r['MaNV']}_{csel['TenChungChi']}"):
            ui.run(lambda: db.call_proc("sp_XoaChungChi", {"MaGV": r["MaNV"], "TenChungChi": csel["TenChungChi"]}), "Đã xoá chứng chỉ.")
