"""Thành phần giao diện dùng chung cho các trang (T19)."""
import hashlib
from datetime import date
from typing import Callable, Iterable

import pandas as pd
import streamlit as st

from core import db


def header(title: str, caption: str | None = None) -> None:
    st.title(title)
    if caption:
        st.caption(caption)


def money(v) -> str:
    """1234500 → '1.234.500 đ'."""
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return ""
    return f"{int(round(float(v))):,} đ".replace(",", ".")


def money_short(v) -> str:
    """Số tiền rút gọn cho ô KPI: 283218000 → '283,2 tr đ', 1,2 tỷ."""
    v = float(v or 0)
    if abs(v) >= 1e9:
        return f"{v / 1e9:,.2f} tỷ đ".replace(".", ",")
    if abs(v) >= 1e6:
        return f"{v / 1e6:,.1f} tr đ".replace(".", ",")
    return money(v)


def flash(msg: str, kind: str = "success") -> None:
    """Thông báo giữ được qua một lần st.rerun()."""
    st.session_state["_flash"] = (kind, msg)


def show_flash() -> None:
    kind, msg = st.session_state.pop("_flash", (None, None))
    if msg:
        getattr(st, kind)(msg, icon={"success": "✅", "error": "⛔", "warning": "⚠️", "info": "ℹ️"}[kind])


def table(df: pd.DataFrame, labels: dict[str, str], key: str, money_cols: Iterable[str] = (),
          select: bool = True, height: int | None = None) -> dict | None:
    """Bảng dữ liệu có tiêu đề cột tiếng Việt; chọn một dòng để sửa. Trả về dòng đã chọn (dict) hoặc None."""
    view = df[[c for c in labels if c in df.columns]].copy()
    for c in money_cols:
        if c in view.columns:
            view[c] = view[c].map(money)
    for c in view.columns:                     # cột có ô NULL: đổi sang chuỗi để hiển thị trống (Arrow không trộn được date và "")
        if view[c].isna().any():
            view[c] = view[c].map(lambda v: "" if v is None or (isinstance(v, float) and pd.isna(v)) or v is pd.NaT else str(v))
    nhan, dung = {}, set()
    for c in view.columns:                     # hai cột trùng nhãn sẽ làm st.dataframe lỗi → thêm hậu tố
        n = labels[c]
        while n in dung:
            n += " "
        dung.add(n)
        nhan[c] = n
    view = view.rename(columns=nhan)
    kw = {"height": height} if height else {}
    if not select:
        st.dataframe(view, hide_index=True, **kw)
        return None
    # key gắn với tập khoá đang hiển thị (cột đầu): lọc / thêm / xoá làm danh sách đổi thì bỏ chọn, tránh
    # chỉ số dòng cũ trỏ sang một bản ghi khác
    sig = hashlib.md5("|".join(map(str, df.iloc[:, 0].tolist())).encode()).hexdigest()[:8] if len(df) else "0"
    ev = st.dataframe(view, hide_index=True, key=f"{key}_{sig}", on_select="rerun", selection_mode="single-row", **kw)
    rows = ev.selection.rows if ev and ev.selection else []
    return df.iloc[rows[0]].to_dict() if rows and rows[0] < len(df) else None


def nut_xoa(label: str, key: str, icon: str = ":material/delete:",
            canh_bao: str = "Thao tác này không hoàn tác được.") -> bool:
    """Nút xoá hai bước (Chương 4 – chống thao tác nhầm): bấm nút mở hộp xác nhận, phải bấm "Xác nhận" mới xoá."""
    with st.popover(label, icon=icon):
        st.warning(canh_bao, icon="⚠️")
        return st.button("Xác nhận", key=key, type="primary", icon=":material/check:")


class FieldErrors:
    """Hiển thị lỗi ngay dưới ô nhập (nguyên tắc thiết kế form – Chương 4).

        fe = FieldErrors()
        ten = st.text_input("Tên"); fe.slot("ten")
        ...
        if submitted:
            fe.check("ten", ten.strip() != "", "Tên không được để trống")
            if fe.ok: ...
    """

    def __init__(self):
        self.slots: dict[str, st.delta_generator.DeltaGenerator] = {}
        self.ok = True

    def slot(self, name: str) -> None:
        self.slots[name] = st.empty()

    def check(self, name: str, cond: bool, msg: str) -> bool:
        if not cond:
            self.ok = False
            if name in self.slots:
                self.slots[name].error(msg, icon="⚠️")
        return cond


def run(action: Callable[[], object], success: str | None = None, rerun: bool = True):
    """Chạy thao tác ghi CSDL; lỗi nghiệp vụ (THROW trong procedure) hiển thị nguyên văn tiếng Việt."""
    try:
        result = action()
    except db.DbError as e:
        st.error(e.message, icon="⛔")
        return None
    st.cache_data.clear()
    if success:
        flash(success)
    if rerun:
        st.rerun()
    return result


@st.cache_data(ttl=60, show_spinner=False)
def options(sql: str, params: tuple = ()) -> list[tuple]:
    """Danh sách lựa chọn cho selectbox, cache 60 giây (dùng chung mọi phiên: chỉ dùng cho danh mục,
    KHÔNG dùng cho view lọc theo SESSION_CONTEXT như vw_HocVien_ChiNhanh)."""
    df = db.query(sql, list(params))
    return list(df.itertuples(index=False, name=None))


def pick(label: str, sql: str, current=None, allow_empty: bool = False, key: str | None = None,
         empty_label: str = "— không chọn —", params: tuple = (), **kw):
    """selectbox từ câu SELECT 2 cột (giá trị, nhãn), có tham số (?). Trả về giá trị."""
    opts = options(sql, tuple(params))
    values = ([None] if allow_empty else []) + [o[0] for o in opts]
    names = {o[0]: f"{o[0]} – {o[1]}" for o in opts}
    names[None] = empty_label
    idx = values.index(current) if current in values else 0
    return st.selectbox(label, values, index=idx, format_func=lambda v: names.get(v, str(v)), key=key, **kw)


SQL_CHI_NHANH = "SELECT MaCN, TenCN FROM vw_DM_ChiNhanh ORDER BY MaCN"


def chon_chi_nhanh(user: dict, label: str = "Chi nhánh", current=None, allow_all: bool = True, key: str | None = None,
                   **kw):
    """Chọn chi nhánh theo PHẠM VI tài khoản: tài khoản toàn trung tâm ('ALL') chọn tự do (allow_all: có mục
    "— tất cả —"); tài khoản chi nhánh bị khoá ở chi nhánh mình. Procedure vẫn kiểm tra lại (dbo.fn_TrongPhamVi)."""
    if user.get("pham_vi_cn") == "ALL":
        return pick(label, SQL_CHI_NHANH, current, allow_empty=allow_all, key=key, empty_label="— tất cả —", **kw)
    kw.pop("disabled", None)
    pick(label, SQL_CHI_NHANH, user["ma_cn"], key=key, disabled=True, help="Tài khoản chỉ thao tác trên chi nhánh của mình", **kw)
    return user["ma_cn"]


def to_date(v, default: date | None = None) -> date | None:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return default
    return pd.to_datetime(v).date()
