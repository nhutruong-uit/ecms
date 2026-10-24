"""Truy cập SQL Server qua pyodbc.

Mọi câu lệnh đều tham số hoá (dấu ?), không ghép chuỗi giá trị người dùng nhập.
Theo nguyên tắc ở app/README.md, các trang chỉ gọi view / function (query) và stored procedure (call_proc).

    df = query("SELECT * FROM vw_SiSoLop WHERE MaCN = ?", ["CN01"])
    out = call_proc("sp_DangKyHoc", {"MaHV": "HV0001", "MaLop": "L001", "GiamGia": 0},
                    outputs={"MaDK": "INT"})
"""
import re
from contextlib import contextmanager
from typing import Any, Iterable, Mapping

import pandas as pd
import pyodbc

from core.config import DB

_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_SQL_TYPE = re.compile(r"^[A-Za-z]+(\s*\(\s*(\d+|MAX)\s*(,\s*\d+\s*)?\))?$", re.I)


class DbError(Exception):
    """Lỗi CSDL đã được rút gọn thành thông báo tiếng Việt cho người dùng."""

    def __init__(self, message: str, number: int | None = None):
        super().__init__(message)
        self.message = message
        self.number = number


def _friendly(err: pyodbc.Error) -> DbError:
    raw = str(err.args[1] if len(err.args) > 1 else err)
    # Thông báo dạng: [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Lớp đã đủ sĩ số. (50001) (SQLExecDirectW)
    msgs = re.findall(r"\[SQL Server\]([^\[]+?)\s*\((\d+)\)", raw)
    if msgs:
        text, num = msgs[0]
        return DbError(text.strip(), int(num))
    return DbError(raw)


# Không dùng connection pool của ODBC: kết nối lấy lại từ pool GIỮ NGUYÊN SESSION_CONTEXT của người dùng trước
# (đã thử trên ODBC Driver 18 – cùng SPID, khoá cũ còn nguyên), nên người sau có thể "thừa hưởng" phạm vi chi nhánh
# hoặc mã nhân viên của người trước. Thay vào đó mỗi phiên Streamlit giữ MỘT kết nối vật lý riêng (xem connect()).
pyodbc.pooling = False

_CONN_KEY = "_db_conn"          # st.session_state[_CONN_KEY] = (ngữ cảnh, kết nối)


def _session_context() -> dict:
    """Ngữ cảnh người dùng đang đăng nhập (đặt vào SESSION_CONTEXT của kết nối, chế độ read-only).

    - app_user: tài khoản ứng dụng → trigger ghi vào NHATKY.NguoiDungUD
    - ma_cn: phạm vi chi nhánh → vw_HocVien_ChiNhanh lọc dòng ('ALL' = mọi chi nhánh)
    - vai_tro, ma_nv, ma_hv: procedure kiểm tra quyền mức dòng (dbo.fn_DuocThaoTacLop, fn_TrongPhamVi…)
    """
    user = _session_state().get("user") if _session_state() is not None else None
    if not user:
        return {}
    ctx = {"app_user": user["username"], "ma_cn": user["pham_vi_cn"], "vai_tro": user["role"],
           "ma_nv": user.get("ma_nv"), "ma_hv": user.get("ma_hv")}
    return {k: v for k, v in ctx.items() if v is not None}


def _session_state():
    """st.session_state khi chạy trong Streamlit; None khi chạy ngoài (script, test thuần Python)."""
    try:
        import streamlit as st
        from streamlit.runtime.scriptrunner import get_script_run_ctx
        return st.session_state if get_script_run_ctx() is not None else None
    except Exception:
        return None


def _open(ctx: dict) -> pyodbc.Connection:
    """Mở kết nối vật lý mới và đặt SESSION_CONTEXT với @read_only = 1: trong suốt kết nối không câu lệnh nào
    (kể cả câu lệnh bị chèn mã) đổi được phạm vi chi nhánh / vai trò của người dùng nữa."""
    conn = pyodbc.connect(DB.connection_string, timeout=5, autocommit=False)
    cur = conn.cursor()
    for k, v in ctx.items():
        cur.execute("EXEC sp_set_session_context @key = ?, @value = ?, @read_only = 1", k, v)
    conn.commit()
    return conn


def connect() -> tuple[pyodbc.Connection, bool]:
    """Trả (kết nối, có_phải_đóng_sau_khi_dùng).

    Trong Streamlit: dùng lại kết nối riêng của phiên nếu ngữ cảnh người dùng không đổi; đăng nhập / đăng xuất
    (ngữ cảnh đổi) thì đóng kết nối cũ, mở kết nối mới. Ngoài Streamlit: mỗi lần một kết nối, dùng xong đóng.
    """
    ctx = _session_context()
    ss = _session_state()
    try:
        if ss is None:
            return _open(ctx), True
        held = ss.get(_CONN_KEY)
        if held and held[0] == ctx:
            return held[1], False
        if held:
            close()
        conn = _open(ctx)
        ss[_CONN_KEY] = (ctx, conn)
        return conn, False
    except pyodbc.Error as e:
        raise _friendly(e) from e


def close() -> None:
    """Đóng kết nối của phiên (gọi khi đăng xuất)."""
    ss = _session_state()
    held = ss.pop(_CONN_KEY, None) if ss is not None else None
    if held:
        try:
            held[1].close()
        except pyodbc.Error:
            pass


@contextmanager
def cursor():
    conn, owned = connect()
    done = False
    try:
        cur = conn.cursor()
        yield cur
        conn.commit()
        done = True
    except pyodbc.Error as e:
        if e.args and str(e.args[0]) in ("08S01", "08003", "08001", "HYT00"):
            close()              # mất kết nối / hết thời gian: lần gọi sau mở kết nối mới
        raise _friendly(e) from e
    finally:
        # rollback cả khi Streamlit dừng giữa chừng (bấm nút khác → RerunException không phải Exception)
        if not done:
            try:
                conn.rollback()
            except pyodbc.Error:
                pass
        if owned:
            conn.close()


def _frame(cur: pyodbc.Cursor) -> pd.DataFrame:
    cols = [c[0] for c in cur.description]
    return pd.DataFrame.from_records([tuple(r) for r in cur.fetchall()], columns=cols)


def query(sql: str, params: Iterable[Any] | None = None) -> pd.DataFrame:
    """Chạy câu SELECT (view / function), trả về DataFrame."""
    with cursor() as cur:
        cur.execute(sql, list(params or []))
        return _frame(cur)


def scalar(sql: str, params: Iterable[Any] | None = None) -> Any:
    with cursor() as cur:
        cur.execute(sql, list(params or []))
        row = cur.fetchone()
        return row[0] if row else None


def execute(sql: str, params: Iterable[Any] | None = None) -> int:
    """Chạy câu lệnh không trả về dữ liệu, trả về số dòng bị ảnh hưởng."""
    with cursor() as cur:
        cur.execute(sql, list(params or []))
        return cur.rowcount


def call_proc(name: str, params: Mapping[str, Any] | None = None,
              outputs: Mapping[str, str] | None = None, fetch: bool = False):
    """Gọi stored procedure với tham số đặt tên.

    outputs: {tên tham số OUTPUT: kiểu SQL}, ví dụ {"MaDK": "INT"}.
    fetch=True: trả về (DataFrame kết quả đầu tiên, dict output); ngược lại chỉ trả dict output.
    """
    params = dict(params or {})
    outputs = dict(outputs or {})
    for n in list(params) + list(outputs) + [name]:
        if not _IDENT.match(n):
            raise ValueError(f"Tên không hợp lệ: {n}")
    for t in outputs.values():
        if not _SQL_TYPE.match(t):
            raise ValueError(f"Kiểu không hợp lệ: {t}")

    declare = "".join(f"DECLARE @o_{k} {t};" for k, t in outputs.items())
    args = [f"@{k} = ?" for k in params] + [f"@{k} = @o_{k} OUTPUT" for k in outputs]
    sql = f"SET NOCOUNT ON; {declare} EXEC dbo.{name} {', '.join(args)};"
    if outputs:
        sql += " SELECT " + ", ".join(f"@o_{k} AS [{k}]" for k in outputs) + ";"

    with cursor() as cur:
        cur.execute(sql, list(params.values()))
        frames = []
        while True:
            if cur.description is not None:
                frames.append(_frame(cur))
            if not cur.nextset():
                break
    out = {}
    if outputs and frames:
        out = frames.pop().iloc[0].to_dict()
    if fetch:
        return (frames[0] if frames else pd.DataFrame()), out
    return out


def server_info() -> dict:
    """Thông tin cho trang Kiểm tra kết nối."""
    with cursor() as cur:
        cur.execute("""
            SELECT @@VERSION, DB_NAME(), SUSER_SNAME(),
                   (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0),
                   (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0),
                   (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0)
        """)
        r = cur.fetchone()
    return {"version": r[0], "database": r[1], "login": r[2], "tables": r[3], "views": r[4], "procedures": r[5]}
