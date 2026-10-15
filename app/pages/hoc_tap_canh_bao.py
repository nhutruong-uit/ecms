"""Cảnh báo chuyên cần: chạy sp_CanhBaoChuyenCan (cursor – T14), theo dõi và đánh dấu đã xử lý (T22)."""
import streamlit as st

from core import auth, db, lop, ui

user = auth.require_role("GiaoVien", "GiaoVu", "QuanLy")
ui.header("⚠️ Cảnh báo chuyên cần", "Học viên vắng vượt ngưỡng trên các buổi đã điểm danh (không tính buổi có phép).")
ui.show_flash()

ds_lop = lop.lop_duoc_xem(user) if user["role"] == "GiaoVien" else None
c1, c2, c3 = st.columns([1, 1, 2])
nguong = c1.slider("Ngưỡng vắng (%)", 5, 50, 20, step=5)
toi_thieu = c2.number_input("Số buổi tối thiểu", 1, 20, 4)
if c3.button("Quét cảnh báo hôm nay", type="primary", icon=":material/search:"):
    lops = ds_lop.MaLop.tolist() if ds_lop is not None else [None]
    tong = 0
    for m in lops:
        out = ui.run(lambda m=m: db.call_proc("sp_CanhBaoChuyenCan", {"NguongVang": nguong, "SoBuoiToiThieu": toi_thieu, "MaLop": m},
                                              outputs={"SoCanhBao": "INT"}, fetch=True), rerun=False)
        if out is None:
            break
        tong += int(out[1].get("SoCanhBao") or 0)
    else:
        ui.flash(f"Đã quét: {tong} cảnh báo mới.", "info")
        st.rerun()

chua = st.toggle("Chỉ hiện cảnh báo chưa xử lý", True)
cn = None if user["pham_vi_cn"] == "ALL" else user["ma_cn"]
cb = db.query("""SELECT * FROM vw_CanhBao WHERE (? IS NULL OR MaCN = ?) AND (? = 0 OR DaXuLy = 0)
                 ORDER BY NgayCanhBao DESC, TyLeVang DESC""", [cn, cn, int(chua)])
if ds_lop is not None:
    cb = cb[cb.MaLop.isin(ds_lop.MaLop)]
cb["XuLy"] = cb.DaXuLy.map({True: "Đã xử lý", False: "Chưa"})
c1, c2 = st.columns(2)
c1.metric("Nghiêm trọng (> 30%)", int((cb.MucDo == "Nghiêm trọng").sum()))
c2.metric("Nhắc nhở", int((cb.MucDo == "Nhắc nhở").sum()))
sel = ui.table(cb, {"NgayCanhBao": "Ngày", "MaLop": "Lớp", "HoTen": "Học viên", "SoDienThoai": "Điện thoại",
                    "HoTenPhuHuynh": "Phụ huynh", "SoBuoiDaHoc": "Đã học", "SoBuoiVang": "Vắng", "TyLeVang": "Vắng %",
                    "MucDo": "Mức độ", "XuLy": "Xử lý"}, key="t_cb")
if sel:
    nhan = "Đánh dấu chưa xử lý" if sel["DaXuLy"] else "Đã liên hệ / xử lý xong"
    if st.button(nhan, icon=":material/task_alt:"):
        ui.run(lambda: db.call_proc("sp_XuLyCanhBao", {"MaCB": int(sel["MaCB"]), "DaXuLy": not sel["DaXuLy"]}), "Đã cập nhật cảnh báo.")
