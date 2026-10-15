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


def _session_context() -> dict:
    """Ngữ cảnh người dùng đang đăng nhập (đặt vào SESSION_CONTEXT của kết nối).

    - app_user: tài khoản ứng dụng → trigger ghi vào NHATKY.NguoiDungUD
    - ma_cn: phạm vi chi nhánh → vw_HocVien_ChiNhanh lọc dòng ('ALL' = mọi chi nhánh)
    """
    try:
        import streamlit as st
        user = st.session_state.get("user")
    except Exception:          # chạy ngoài Streamlit (script, test)
        user = None
    if not user:
        return {}
    return {"app_user": user["username"], "ma_cn": user["pham_vi_cn"], "vai_tro": user["role"],
            "ma_nv": user.get("ma_nv"), "ma_hv": user.get("ma_hv")}


def connect() -> pyodbc.Connection:
    """Mở kết nối mới (ODBC tự quản lý connection pool) và đặt SESSION_CONTEXT của người dùng.

    Khi kết nối được trả về pool, sp_reset_connection xoá SESSION_CONTEXT, nên mỗi lần mở đều đặt lại.
    """
    try:
        conn = pyodbc.connect(DB.connection_string, timeout=5, autocommit=False)
        ctx = {k: v for k, v in _session_context().items() if v is not None}
        if ctx:
            cur = conn.cursor()
            for k, v in ctx.items():
                cur.execute("EXEC sp_set_session_context @key = ?, @value = ?", k, v)
        return conn
    except pyodbc.Error as e:
        raise _friendly(e) from e


@contextmanager
def cursor():
    conn = connect()
    try:
        cur = conn.cursor()
        yield cur
        conn.commit()
    except pyodbc.Error as e:
        conn.rollback()
        raise _friendly(e) from e
    except Exception:
        conn.rollback()
        raise
    finally:
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
