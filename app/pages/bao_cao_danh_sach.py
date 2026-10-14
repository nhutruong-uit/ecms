"""Báo cáo & xuất file (T24, Lab 5): 6 báo cáo thuộc 3 loại – định kỳ, theo yêu cầu (có tham số), tổng hợp.
Mỗi báo cáo xem trên màn hình và tải PDF (Page X / Y, tổng phụ, tổng cộng) hoặc Excel."""
from datetime import date

import pandas as pd
import streamlit as st

from core import auth, db, ui
from reports import bao_cao

user = auth.require_role("QuanLy", "KeToan", "GiaoVu", "GiaoVien")
ui.header("📑 Báo cáo & xuất file")
cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
la_gv = user["role"] == "GiaoVien"

BAO_CAO = {
    "ds_lop": ("Danh sách học viên theo lớp", "Định kỳ – đầu khoá", ("QuanLy", "GiaoVu", "GiaoVien")),
    "doanh_thu": ("Doanh thu theo chi nhánh → tháng", "Định kỳ – tháng / quý", ("QuanLy", "KeToan")),
    "bang_diem": ("Bảng điểm lớp", "Theo yêu cầu – tham số lớp", ("QuanLy", "GiaoVu", "GiaoVien")),
    "lich_su": ("Lịch sử học tập học viên", "Theo yêu cầu – tham số học viên", ("QuanLy", "GiaoVu")),
    "cong_no": ("Công nợ học viên", "Theo yêu cầu – tham số ngưỡng", ("QuanLy", "KeToan", "GiaoVu")),
    "luong": ("Bảng lương giáo viên", "Định kỳ – tháng", ("QuanLy", "KeToan")),
    "tong_hop": ("Tổng hợp theo chương trình", "Tổng hợp – nhiều chỉ tiêu", ("QuanLy", "KeToan")),
}
duoc = {k: v for k, v in BAO_CAO.items() if user["role"] in v[2]}
ma = st.selectbox("Báo cáo", list(duoc), format_func=lambda k: f"{duoc[k][0]}  ·  {duoc[k][1]}")


def lop_cho_chon(trang_thai):
    if la_gv:
        df = db.query("SELECT MaLop, TenKH, TrangThai FROM dbo.fn_LopCuaGiaoVien(?)", [user["ma_nv"]])
    else:
        df = db.query("SELECT MaLop, TenKH, TrangThai FROM vw_SiSoLop WHERE ? IS NULL OR MaCN = ?", [cn, cn])
    return df[df.TrangThai.isin(trang_thai)].sort_values("MaLop")


def tai(ten_file: str, pdf_bytes: bytes | None, xlsx_bytes: bytes | None):
    c1, c2, _ = st.columns([1, 1, 3])
    if pdf_bytes:
        c1.download_button("Tải PDF", pdf_bytes, f"{ten_file}.pdf", "application/pdf", icon=":material/picture_as_pdf:")
    if xlsx_bytes:
        c2.download_button("Tải Excel", xlsx_bytes, f"{ten_file}.xlsx",
                           "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", icon=":material/table_view:")


# ------------------------------------------------------------------ 1. Danh sách học viên theo lớp (phẳng)
if ma == "ds_lop":
    ds = lop_cho_chon(["Sắp mở", "Đang học", "Đã kết thúc"])
    lop = st.selectbox("Lớp", ds.MaLop.tolist(), format_func=lambda m: f"{m} – {ds.set_index('MaLop').loc[m, 'TenKH']}")
    if lop:
        info = db.query("SELECT * FROM vw_SiSoLop WHERE MaLop = ?", [lop]).iloc[0]
        df = db.query("""SELECT ROW_NUMBER() OVER (ORDER BY d.HoTenHV) AS STT, d.MaHV, d.HoTenHV AS HoTen, d.SoDienThoai, d.NgayDK,
                                d.HocPhi, d.GiamGia, d.ThanhTien, d.TrangThaiHP, d.TrangThai
                         FROM vw_DangKyChiTiet d WHERE d.MaLop = ? AND d.TrangThai IN (N'Đang học', N'Hoàn thành', N'Bảo lưu')""", [lop])
        tham = f"Lớp {lop} · {info.TenKH} · {info.TenCN} · GV {info.GiaoVien} · khai giảng {pd.to_datetime(info.NgayKhaiGiang):%d/%m/%Y} · {info.Lich}"
        st.caption(tham)
        ui.table(df, {"STT": "STT", "MaHV": "Mã HV", "HoTen": "Họ tên", "SoDienThoai": "Điện thoại", "NgayDK": "Ngày ĐK",
                      "HocPhi": "Học phí", "GiamGia": "Giảm %", "ThanhTien": "Thành tiền", "TrangThaiHP": "TT học phí", "TrangThai": "Trạng thái"},
                 key="r1", select=False, money_cols=("HocPhi", "ThanhTien"))
        cot = [("STT", "STT", 10, None), ("MaHV", "Mã HV", 18, None), ("HoTen", "Họ tên", 50, None), ("SoDienThoai", "Điện thoại", 28, None),
               ("NgayDK", "Ngày ĐK", 22, "date"), ("HocPhi", "Học phí", 28, "money"), ("GiamGia", "Giảm %", 16, "num"),
               ("ThanhTien", "Thành tiền (sau giảm)", 32, "money"), ("TrangThaiHP", "TT học phí", 26, None), ("TrangThai", "Trạng thái", 25, None)]
        if la_gv:      # giáo viên không cần thông tin tài chính
            cot = [c for c in cot if c[0] not in ("HocPhi", "GiamGia", "ThanhTien", "TrangThaiHP")]
        tai(f"DanhSach_{lop}", bao_cao.pdf("Danh sách học viên", tham, df, cot, tong=[] if la_gv else ["ThanhTien"]),
            bao_cao.excel({"DanhSach": (f"Danh sách học viên lớp {lop}", df, {c[0]: c[1] for c in cot})},
                          tong=None if la_gv else {"DanhSach": ["ThanhTien"]}))

# ------------------------------------------------------------------ 2. Doanh thu chi nhánh → tháng (phân nhóm)
elif ma == "doanh_thu":
    c1, c2 = st.columns(2)
    tu = c1.date_input("Từ ngày", date(date.today().year, 1, 1), format="DD/MM/YYYY")
    den = c2.date_input("Đến ngày", date.today(), format="DD/MM/YYYY")
    df = db.query("""SELECT TenCN, CONCAT(RIGHT('0' + CAST(Thang AS VARCHAR), 2), '/', Nam) AS KyThang, Nam, Thang,
                            COUNT(DISTINCT MaPT) AS SoPhieu, COUNT(DISTINCT MaHV) AS SoHocVien, SUM(SoTien) AS DoanhThu
                     FROM vw_BaoCaoDoanhThu WHERE NgayThu BETWEEN ? AND ? AND (? IS NULL OR MaCN = ?)
                     GROUP BY TenCN, MaCN, Nam, Thang ORDER BY MaCN, Nam, Thang""", [tu, den, cn, cn])
    tham = f"Từ {tu:%d/%m/%Y} đến {den:%d/%m/%Y}"
    for ten, g in df.groupby("TenCN", sort=False):
        st.markdown(f"**{ten}** – cộng {ui.money(g.DoanhThu.sum())}")
        ui.table(g, {"KyThang": "Tháng", "SoPhieu": "Số phiếu", "SoHocVien": "Học viên", "DoanhThu": "Doanh thu"}, key=f"r2_{ten}",
                 select=False, money_cols=("DoanhThu",))
    st.markdown(f"### Tổng cộng: {ui.money(df.DoanhThu.sum() if len(df) else 0)}")
    cot = [("KyThang", "Tháng", 45, None), ("SoPhieu", "Số phiếu", 40, "num"), ("SoHocVien", "Số học viên", 40, "num"),
           ("DoanhThu", "Doanh thu", 60, "money")]
    tai("DoanhThu", bao_cao.pdf("Báo cáo doanh thu theo chi nhánh", tham, df, cot, nhom="TenCN", tong=["DoanhThu"], ngang=False),
        bao_cao.excel({"DoanhThu": ("Doanh thu theo chi nhánh – tháng", df, {"TenCN": "Chi nhánh"} | {c[0]: c[1] for c in cot})},
                      tong={"DoanhThu": ["DoanhThu"]}))

# ------------------------------------------------------------------ 3. Bảng điểm lớp (tham số) + định dạng có điều kiện
elif ma == "bang_diem":
    ds = lop_cho_chon(["Đang học", "Đã kết thúc"])
    lop = st.selectbox("Lớp", ds.MaLop.tolist(), format_func=lambda m: f"{m} – {ds.set_index('MaLop').loc[m, 'TenKH']}")
    if lop:
        df = db.query("SELECT * FROM dbo.fn_BangDiemLop(?) ORDER BY ISNULL(Hang, 999), HoTen", [lop])
        view = df[["Hang", "MaHV", "HoTen", "DiemGK", "DiemCK", "DiemTB", "XepLoai", "ChuyenCan", "KetQua", "GhiChu"]].rename(columns={
            "Hang": "Hạng", "MaHV": "Mã HV", "HoTen": "Họ tên", "DiemGK": "GK", "DiemCK": "CK", "DiemTB": "TB", "XepLoai": "Xếp loại",
            "ChuyenCan": "Chuyên cần %", "KetQua": "Kết quả", "GhiChu": "Ghi chú"})

        def mau(row):
            m = "background-color:#fee2e2;color:#991b1b" if row["Kết quả"] == "Không đạt" or (row["Chuyên cần %"] or 100) < 80 else (
                "background-color:#dcfce7;color:#14532d" if row["Xếp loại"] in ("Xuất sắc", "Giỏi") else "")
            return [m] * len(row)
        st.dataframe(view.style.apply(mau, axis=1).format(precision=2, na_rep=""), hide_index=True)
        st.caption("Xanh: Giỏi / Xuất sắc · Đỏ: Không đạt hoặc chuyên cần dưới 80%")
        cot = [("Hang", "Hạng", 12, None), ("MaHV", "Mã HV", 18, None), ("HoTen", "Họ tên", 50, None), ("DiemGK", "GK", 15, "num"),
               ("DiemCK", "CK", 15, "num"), ("DiemTB", "TB", 15, "num"), ("XepLoai", "Xếp loại", 25, None),
               ("ChuyenCan", "Chuyên cần %", 25, "num"), ("KetQua", "Kết quả", 22, None), ("GhiChu", "Ghi chú", 70, None)]
        tai(f"BangDiem_{lop}", bao_cao.pdf("Bảng điểm lớp", f"Lớp {lop} – {ds.set_index('MaLop').loc[lop, 'TenKH']}", df, cot),
            bao_cao.excel({"BangDiem": (f"Bảng điểm lớp {lop}", df, {c[0]: c[1] for c in cot})}))

# ------------------------------------------------------------------ 4. Lịch sử học tập của một học viên
elif ma == "lich_su":
    q = st.text_input("Tìm học viên (tên, SĐT hoặc mã)")
    if q.strip():
        hv = db.query("SELECT TOP 20 MaHV, HoTen FROM vw_HocVien_ChiNhanh WHERE HoTen LIKE ? OR SoDienThoai LIKE ? OR MaHV LIKE ?",
                      [f"%{q}%"] * 3)
        if not hv.empty:
            m = st.selectbox("Học viên", hv.MaHV.tolist(), format_func=lambda x: f"{hv.set_index('MaHV').loc[x, 'HoTen']} ({x})")
            df = db.query("""SELECT d.MaLop, d.TenKH, d.NgayKhaiGiang, b.DiemGK, b.DiemCK, b.DiemTB, b.XepLoai, b.ChuyenCan, d.KetQua,
                                    d.ThanhTien, d.TrangThaiHP, d.TrangThai
                             FROM vw_DangKyChiTiet d LEFT JOIN vw_BangDiem b ON b.MaDK = d.MaDK
                             WHERE d.MaHV = ? ORDER BY d.NgayKhaiGiang""", [m])
            ui.table(df, {"MaLop": "Lớp", "TenKH": "Khoá học", "NgayKhaiGiang": "Khai giảng", "DiemTB": "Điểm TB", "XepLoai": "Xếp loại",
                          "ChuyenCan": "Chuyên cần %", "KetQua": "Kết quả", "ThanhTien": "Học phí", "TrangThaiHP": "Trạng thái HP"},
                     key="r4", select=False, money_cols=("ThanhTien",))
            cot = [("MaLop", "Lớp", 22, None), ("TenKH", "Khoá học", 40, None), ("NgayKhaiGiang", "Khai giảng", 22, "date"),
                   ("DiemGK", "GK", 14, "num"), ("DiemCK", "CK", 14, "num"), ("DiemTB", "TB", 14, "num"), ("XepLoai", "Xếp loại", 24, None),
                   ("ChuyenCan", "Chuyên cần %", 24, "num"), ("KetQua", "Kết quả", 22, None), ("ThanhTien", "Học phí", 28, "money"),
                   ("TrangThaiHP", "Trạng thái HP", 28, None)]
            tai(f"LichSu_{m}", bao_cao.pdf("Lịch sử học tập", f"Học viên {hv.set_index('MaHV').loc[m, 'HoTen']} ({m})", df, cot,
                                           tong=["ThanhTien"]), None)

# ------------------------------------------------------------------ 5. Công nợ
elif ma == "cong_no":
    nguong = st.number_input("Chỉ lấy học viên nợ từ (đ)", 0, 100_000_000, 1_000_000, step=500_000)
    df = db.query("""SELECT MaHV, HoTen, SoDienThoai, COUNT(*) AS SoKhoan, SUM(ThanhTien) AS ThanhTien, SUM(DaThu) AS DaThu,
                            SUM(ConNo) AS ConNo, MAX(SoNgayQuaHan) AS QuaHanNgay
                     FROM vw_CongNoHocVien WHERE ? IS NULL OR MaCN = ?
                     GROUP BY MaHV, HoTen, SoDienThoai HAVING SUM(ConNo) >= ? ORDER BY SUM(ConNo) DESC""", [cn, cn, nguong])
    ui.table(df, {"MaHV": "Mã HV", "HoTen": "Học viên", "SoDienThoai": "Điện thoại", "SoKhoan": "Số khoản", "ThanhTien": "Phải đóng",
                  "DaThu": "Đã thu", "ConNo": "Còn nợ", "QuaHanNgay": "Quá hạn (ngày)"}, key="r5", select=False,
             money_cols=("ThanhTien", "DaThu", "ConNo"))
    cot = {"MaHV": "Mã HV", "HoTen": "Học viên", "SoDienThoai": "Điện thoại", "SoKhoan": "Số khoản", "ThanhTien": "Phải đóng",
           "DaThu": "Đã thu", "ConNo": "Còn nợ", "QuaHanNgay": "Quá hạn (ngày)"}
    chi_tiet = db.query("""SELECT MaHV, HoTen, MaLop, TenKH, ThanhTien, DaThu, ConNo, HanDongHP, SoNgayQuaHan FROM vw_CongNoHocVien
                           WHERE ? IS NULL OR MaCN = ? ORDER BY MaHV""", [cn, cn])
    tai("CongNo", bao_cao.pdf("Công nợ học viên", f"Nợ từ {ui.money(nguong)}", df,
                              [(c, n, w, k) for (c, n), w, k in zip(cot.items(), [20, 50, 28, 18, 32, 32, 32, 24],
                                                                    [None, None, None, None, "money", "money", "money", None])],
                              tong=["ThanhTien", "DaThu", "ConNo"]),
        bao_cao.excel({"TongHop": ("Công nợ theo học viên", df, cot),
                       "ChiTiet": ("Chi tiết từng đăng ký", chi_tiet, {"MaHV": "Mã HV", "HoTen": "Học viên", "MaLop": "Lớp", "TenKH": "Khoá học",
                                                                     "ThanhTien": "Phải đóng", "DaThu": "Đã thu", "ConNo": "Còn nợ",
                                                                     "HanDongHP": "Hạn đóng", "SoNgayQuaHan": "Quá hạn (ngày)"})},
                      tong={"TongHop": ["ThanhTien", "DaThu", "ConNo"], "ChiTiet": ["ConNo"]}))

# ------------------------------------------------------------------ 6. Bảng lương giáo viên (gọi procedure dùng cursor)
elif ma == "luong":
    c1, c2 = st.columns([1, 3])
    thang = c1.text_input("Tháng (yyyy-MM)", f"{date.today():%Y-%m}")
    if c2.button("Tính lại bảng lương tháng này", help="Gọi sp_TinhLuongGiaoVien (cursor – T14)"):
        ui.run(lambda: db.call_proc("sp_TinhLuongGiaoVien", {"Thang": thang}, fetch=True), f"Đã tính lương tháng {thang}.", rerun=False)
    df = db.query("SELECT * FROM vw_BangLuong WHERE Thang = ? AND (? IS NULL OR MaCN = ?) ORDER BY TongLuong DESC", [thang, cn, cn])
    if df.empty:
        st.info("Chưa có bảng lương tháng này – bấm *Tính lại bảng lương*.")
    else:
        nhan = {"MaGV": "Mã GV", "HoTen": "Giáo viên", "LoaiGV": "Loại", "SoBuoiDay": "Số buổi", "DonGiaBuoi": "Đơn giá",
                "LuongCoBan": "Lương cơ bản", "TongLuong": "Tổng lương"}
        ui.table(df, nhan, key="r6", select=False, money_cols=("DonGiaBuoi", "LuongCoBan", "TongLuong"))
        tai(f"BangLuong_{thang}", None, bao_cao.excel({"BangLuong": (f"Bảng lương giáo viên tháng {thang}", df, nhan)},
                                                    tong={"BangLuong": ["TongLuong"]}))

# ------------------------------------------------------------------ 7. Tổng hợp theo chương trình
elif ma == "tong_hop":
    nam = st.selectbox("Năm", [date.today().year, date.today().year - 1])
    df = db.query("""SELECT ct.TenCT,
                            (SELECT COUNT(*) FROM vw_SiSoLop l WHERE l.MaCT = ct.MaCT AND YEAR(l.NgayKhaiGiang) = ?) AS SoLop,
                            (SELECT COUNT(DISTINCT d.MaHV) FROM vw_DangKyChiTiet d JOIN vw_DM_KhoaHoc k ON k.MaKH = d.MaKH
                              WHERE k.MaCT = ct.MaCT AND YEAR(d.NgayDK) = ?) AS SoHocVien,
                            (SELECT AVG(l.TyLeLapDay) FROM vw_SiSoLop l WHERE l.MaCT = ct.MaCT AND YEAR(l.NgayKhaiGiang) = ?) AS LapDay,
                            (SELECT AVG(b.ChuyenCan) FROM vw_BangDiem b JOIN vw_DM_KhoaHoc k ON k.TenKH = b.TenKH
                              WHERE k.MaCT = ct.MaCT) AS ChuyenCan,
                            (SELECT 100.0 * SUM(CASE WHEN b.KetQua = N'Đạt' THEN 1 ELSE 0 END) / NULLIF(COUNT(b.KetQua), 0)
                               FROM vw_BangDiem b JOIN vw_DM_KhoaHoc k ON k.TenKH = b.TenKH WHERE k.MaCT = ct.MaCT) AS TyLeDat,
                            (SELECT ISNULL(SUM(SoTien), 0) FROM vw_BaoCaoDoanhThu r WHERE r.MaCT = ct.MaCT AND r.Nam = ?) AS DoanhThu
                     FROM vw_DM_ChuongTrinh ct ORDER BY DoanhThu DESC""", [nam] * 4)
    for c in ("LapDay", "ChuyenCan", "TyLeDat"):
        df[c] = pd.to_numeric(df[c]).round(1)
    nhan = {"TenCT": "Chương trình", "SoLop": "Số lớp", "SoHocVien": "Học viên", "LapDay": "Lấp đầy %", "ChuyenCan": "Chuyên cần %",
            "TyLeDat": "Tỷ lệ đạt %", "DoanhThu": "Doanh thu"}
    ui.table(df, nhan, key="r7", select=False, money_cols=("DoanhThu",))
    cot = [("TenCT", "Chương trình", 55, None), ("SoLop", "Số lớp", 18, None), ("SoHocVien", "Học viên", 20, None),
           ("LapDay", "Lấp đầy %", 22, "num"), ("ChuyenCan", "Chuyên cần %", 25, "num"), ("TyLeDat", "Tỷ lệ đạt %", 24, "num"),
           ("DoanhThu", "Doanh thu", 35, "money")]
    tai(f"TongHop_{nam}", bao_cao.pdf("Báo cáo tổng hợp theo chương trình", f"Năm {nam}", df, cot, tong=["DoanhThu"]),
        bao_cao.excel({"TongHop": (f"Tổng hợp theo chương trình năm {nam}", df, nhan)}, tong={"TongHop": ["DoanhThu"]}))
