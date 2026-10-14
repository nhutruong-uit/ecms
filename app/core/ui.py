"""Thành phần giao diện dùng chung cho các trang (T19)."""
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
    view = view.astype(object).where(view.notna(), "").rename(columns=labels)   # ô NULL hiển thị trống
    kw = {"height": height} if height else {}
    if not select:
        st.dataframe(view, hide_index=True, **kw)
        return None
    ev = st.dataframe(view, hide_index=True, key=key, on_select="rerun", selection_mode="single-row", **kw)
    rows = ev.selection.rows if ev and ev.selection else []
    return df.iloc[rows[0]].to_dict() if rows else None


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


def to_date(v, default: date | None = None) -> date | None:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return default
    return pd.to_datetime(v).date()
