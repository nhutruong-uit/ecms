"""Thu học phí theo mẫu Master–Detail (T23).
Master: học viên, hình thức, ghi chú. Detail: lưới các đăng ký còn nợ, chọn nhiều dòng → sp_ThuHocPhi.
Tổng tiền phiếu và trạng thái học phí do trigger trg_CTPhieuThu_TongTien cập nhật."""
import json
from datetime import date, timedelta

import pandas as pd
import streamlit as st

from core import auth, db, ui
from reports.phieu_thu_pdf import phieu_thu_pdf

user = auth.require_role("KeToan", "QuanLy")
ui.header("🧾 Phiếu thu học phí")
ui.show_flash()


def nut_in(ma_pt: int, key: str) -> None:
    pt = db.query("SELECT * FROM vw_PhieuThu WHERE MaPT = ?", [ma_pt]).iloc[0].to_dict()
    ct = db.query("SELECT * FROM vw_CTPhieuThu WHERE MaPT = ? ORDER BY MaLop", [ma_pt])
    st.download_button(f"In phiếu {pt['SoPhieu']} (PDF)", phieu_thu_pdf(pt, ct), f"{pt['SoPhieu']}.pdf", "application/pdf",
                       icon=":material/print:", key=key)


tab_lap, tab_tra = st.tabs(["Lập phiếu thu", "Tra cứu phiếu thu"], key="tabs", on_change="rerun")

with tab_lap:
    if st.session_state.get("pt_vua_lap"):
        st.success(f"Đã lập phiếu thu. Tổng {ui.money(st.session_state['pt_vua_lap'][1])}.")
        nut_in(st.session_state["pt_vua_lap"][0], "in_moi")
    st.markdown("##### 1. Thông tin phiếu (master)")
    q = st.text_input("Tìm học viên (tên, SĐT hoặc mã)", placeholder="VD: HV0019")
    hv = None
    if q.strip():
        ds = db.query("""SELECT TOP 30 h.MaHV, h.HoTen, h.SoDienThoai, ISNULL(SUM(c.ConNo), 0) AS ConNo
                         FROM vw_HocVien_ChiNhanh h LEFT JOIN vw_CongNoHocVien c ON c.MaHV = h.MaHV
                         WHERE h.HoTen LIKE ? OR h.SoDienThoai LIKE ? OR h.MaHV LIKE ?
                         GROUP BY h.MaHV, h.HoTen, h.SoDienThoai, h.TenHV ORDER BY h.TenHV""", [f"%{q}%"] * 3)
        if ds.empty:
            st.warning("Không tìm thấy học viên.")
        else:
            nhan = {r.MaHV: f"{r.HoTen} · {r.SoDienThoai} ({r.MaHV}) · còn nợ {ui.money(r.ConNo)}" for r in ds.itertuples()}
            hv = st.selectbox("Học viên", list(nhan), format_func=nhan.get)
    if hv:
        no = db.query("""SELECT MaDK, MaLop, TenKH, ThanhTien, DaThu, ConNo, HanDongHP, QuaHan
                         FROM vw_CongNoHocVien WHERE MaHV = ? ORDER BY HanDongHP""", [hv])
        if no.empty:
            st.info("Học viên không còn khoản nào phải đóng.")
        else:
            st.markdown("##### 2. Chi tiết – chọn các đăng ký cần thu (detail)")
            no.insert(0, "Thu", True)
            no["SoTien"] = no["ConNo"].astype("int64")
            for c in ("ThanhTien", "DaThu", "ConNo"):
                no[c] = no[c].astype("int64")
            no["QuaHan"] = no["QuaHan"].map({1: "⚠ Quá hạn", 0: ""})
            sua = st.data_editor(no, hide_index=True, key=f"ct_{hv}", disabled=["MaDK", "MaLop", "TenKH", "ThanhTien", "DaThu", "ConNo",
                                                                                "HanDongHP", "QuaHan"],
                                 column_config={
                                     "MaDK": None, "Thu": st.column_config.CheckboxColumn("Thu"), "MaLop": "Lớp", "TenKH": "Khoá học",
                                     "ThanhTien": st.column_config.NumberColumn("Phải đóng", format="localized"),
                                     "DaThu": st.column_config.NumberColumn("Đã thu", format="localized"),
                                     "ConNo": st.column_config.NumberColumn("Còn nợ", format="localized"),
                                     "SoTien": st.column_config.NumberColumn("Thu lần này (đ)", min_value=1000, step=1000, format="localized"),
                                     "HanDongHP": "Hạn đóng", "QuaHan": ""})
            chon = sua[sua["Thu"]]
            loi = chon[(chon.SoTien > chon.ConNo) | (chon.SoTien <= 0)]
            tong = int(chon.SoTien.sum())
            with st.form("f_pt"):
                c1, c2, c3 = st.columns([1, 2, 1])
                ht = c1.selectbox("Hình thức", ["Tiền mặt", "Chuyển khoản", "Thẻ"])
                gc = c2.text_input("Ghi chú", placeholder="VD: đóng đợt 1")
                c3.metric("Tổng phiếu", ui.money_short(tong), f"{len(chon)} dòng", help=ui.money(tong))
                if not loi.empty:
                    st.error(f"Lớp {', '.join(loi.MaLop)}: số tiền thu phải lớn hơn 0 và không vượt số còn nợ.")
                if st.form_submit_button("Lập phiếu thu", type="primary", icon=":material/receipt_long:",
                                         disabled=chon.empty or not loi.empty):
                    ct_json = json.dumps([{"MaDK": int(r.MaDK), "SoTien": int(r.SoTien)} for r in chon.itertuples()])
                    out = ui.run(lambda: db.call_proc("sp_ThuHocPhi", {"MaHV": hv, "MaNV": user["ma_nv"], "HinhThuc": ht,
                                                                       "ChiTiet": ct_json, "GhiChu": gc.strip() or None},
                                                      outputs={"MaPT": "INT", "TongTien": "DECIMAL(12,0)"}), rerun=False)
                    if out is not None:
                        st.session_state["pt_vua_lap"] = (int(out["MaPT"]), out["TongTien"])
                        st.rerun()

with tab_tra:
    c1, c2, c3 = st.columns([1, 1, 2])
    tu = c1.date_input("Từ ngày", date.today() - timedelta(days=30), format="DD/MM/YYYY")
    den = c2.date_input("Đến ngày", date.today(), format="DD/MM/YYYY")
    q2 = c3.text_input("Số phiếu / học viên")
    cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
    pts = db.query("""SELECT * FROM vw_PhieuThu WHERE NgayThu >= ? AND NgayThu < DATEADD(DAY, 1, ?) AND (? IS NULL OR MaCN = ?)
                      AND (SoPhieu LIKE ? OR HoTenHV LIKE ? OR MaHV LIKE ?) ORDER BY NgayThu DESC""",
                   [tu, den, cn, cn, f"%{q2}%", f"%{q2}%", f"%{q2}%"])
    st.caption(f"{len(pts)} phiếu · tổng {ui.money(pts.TongTien.sum() if len(pts) else 0)}")
    sel = ui.table(pts, {"SoPhieu": "Số phiếu", "NgayThu": "Ngày thu", "HoTenHV": "Học viên", "HinhThuc": "Hình thức",
                         "SoDong": "Số dòng", "TongTien": "Tổng tiền", "NguoiLap": "Người lập", "GhiChu": "Ghi chú"},
                   key="t_pt", money_cols=("TongTien",))
    if sel:
        ct = db.query("SELECT MaLop, TenKH, ThanhTien, SoTien, ConNo FROM vw_CTPhieuThu WHERE MaPT = ?", [sel["MaPT"]])
        st.markdown(f"**Chi tiết phiếu {sel['SoPhieu']}**")
        ui.table(ct, {"MaLop": "Lớp", "TenKH": "Khoá học", "ThanhTien": "Phải đóng", "SoTien": "Thu", "ConNo": "Còn nợ hiện tại"},
                 key="t_ct", select=False, money_cols=("ThanhTien", "SoTien", "ConNo"))
        nut_in(int(sel["MaPT"]), "in_cu")
