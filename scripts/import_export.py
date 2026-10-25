#!/usr/bin/env python3
"""Nhập / xuất dữ liệu ECMS bằng Python (pandas ↔ SQL Server) – T18.

    python3 scripts/import_export.py import data/import/hocvien_online.csv     # kiểm tra + nạp vào staging
    python3 scripts/import_export.py export --format csv xlsx json xml           # xuất ra data/export/
    python3 scripts/import_export.py bench                                       # so sánh tốc độ với 10.000 dòng

Kết nối bằng tài khoản quản trị (sa) đọc từ .env: SA_PASSWORD, DB_SERVER, DB_PORT.
Cần bảng staging dbo.STG_HOCVIEN_ONLINE (tạo bởi database/12_import_export.sql).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import pandas as pd
import pyodbc
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")
EXPORT_DIR = ROOT / "data" / "export"
COLS = ["HoHV", "TenHV", "NgaySinh", "GioiTinh", "SoDienThoai", "Email", "QuanHuyen", "MaCN", "MaKHQuanTam", "NgayDangKy"]


def xac_thuc_quan_tri() -> str:
    """sa với mật khẩu trong .env (SA_PASSWORD) – không viết cứng trong mã nguồn; SA_TRUSTED=yes thì dùng Windows
    Authentication của người đang chạy (máy Windows tắt login sa, người dùng Windows là sysadmin)."""
    if os.getenv("SA_TRUSTED", "no").strip().lower() in ("1", "yes", "true"):
        return "Trusted_Connection=yes"
    mk = os.getenv("SA_PASSWORD")
    if not mk:
        sys.exit("Thiếu SA_PASSWORD trong .env (xem .env.example).")
    return f"UID=sa;PWD={mk}"


def connect(fast=True):
    port = os.getenv("DB_PORT", "1433").strip()
    server = os.getenv("DB_SERVER", "localhost") + (f",{port}" if port else "")   # Express: localhost\SQLEXPRESS, không cổng
    cs = (f"DRIVER={{{os.getenv('DB_DRIVER', 'ODBC Driver 18 for SQL Server')}}};SERVER={server};DATABASE=ECMS;"
          f"{xac_thuc_quan_tri()};Encrypt=yes;TrustServerCertificate=yes")
    cn = pyodbc.connect(cs, autocommit=False)
    return cn


def read_df(cn, sql):
    """pandas.read_sql chỉ hỗ trợ chính thức SQLAlchemy – đọc qua cursor pyodbc cho gọn phụ thuộc."""
    cur = cn.cursor()
    cur.execute(sql)
    return pd.DataFrame.from_records([tuple(r) for r in cur.fetchall()], columns=[c[0] for c in cur.description])


# ------------------------------------------------------------------ import
def validate(df: pd.DataFrame, cn) -> pd.DataFrame:
    """Kiểm tra chất lượng – CÙNG 12 quy tắc với phần ETL trong 12_import_export.sql, trả về DataFrame có cột Loi."""
    cur = cn.cursor()
    cns = {r[0] for r in cur.execute("SELECT MaCN FROM CHINHANH").fetchall()}
    khs = {r[0] for r in cur.execute("SELECT MaKH FROM KHOAHOC").fetchall()}
    phones = {r[0] for r in cur.execute("SELECT SoDienThoai FROM HOCVIEN").fetchall()}
    df = df.fillna("")
    ns = pd.to_datetime(df["NgaySinh"], format="%d/%m/%Y", errors="coerce")
    ndk_txt = df["NgayDangKy"].astype(str).str.strip() if "NgayDangKy" in df else pd.Series("", index=df.index)
    ndk = pd.to_datetime(ndk_txt, format="%d/%m/%Y", errors="coerce")
    nam_tuoi_4 = pd.Timestamp.today().normalize() - pd.DateOffset(years=4)
    sdt = df["SoDienThoai"].str.replace(r"[\s.\-]", "", regex=True)
    loi = pd.Series([[] for _ in range(len(df))])
    rules = [
        ((df["HoHV"].str.strip() == "") | (df["TenHV"].str.strip() == ""), "Thiếu họ tên"),
        ((df["HoHV"].str.strip().str.len() > 50) | (df["TenHV"].str.strip().str.len() > 20), "Họ tên quá dài"),
        ((ndk_txt != "") & ndk.isna(), "Ngày đăng ký sai định dạng"),
        (ns.isna(), "Ngày sinh sai định dạng"),
        (ns.notna() & (ns > nam_tuoi_4), "Ngày sinh không hợp lệ"),
        (~df["GioiTinh"].isin(["Nam", "Nữ"]), "Giới tính sai"),
        (~sdt.str.fullmatch(r"\d{9,11}"), "Số điện thoại sai"),
        ((df["Email"] != "") & ~df["Email"].str.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+"), "Email sai"),
        (~df["MaCN"].isin(cns), "Chi nhánh không tồn tại"),
        ((df["MaKHQuanTam"] != "") & ~df["MaKHQuanTam"].isin(khs), "Khoá học không tồn tại"),
        (sdt.isin(phones), "Trùng SĐT học viên đã có"),
    ]
    for mask, msg in rules:
        for i in df.index[mask]:
            loi[i].append(msg)
    ok = loi.map(len) == 0
    dup = sdt.where(ok).duplicated(keep="first") & ok
    for i in df.index[dup]:
        loi[i].append("Trùng SĐT trong file")
    df = df.assign(SoDienThoai=sdt, Loi=loi.map("; ".join))
    return df


def cmd_import(args):
    t0 = time.perf_counter()
    df = pd.read_csv(args.file, dtype=str, encoding="utf-8-sig", keep_default_na=False)
    t_read = time.perf_counter() - t0
    with connect() as cn:
        df = validate(df, cn)
        good = df[df["Loi"] == ""]
        cur = cn.cursor()
        cur.execute("TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE")
        cur.fast_executemany = True
        t1 = time.perf_counter()
        cur.executemany(f"INSERT dbo.STG_HOCVIEN_ONLINE ({', '.join(COLS)}) VALUES ({', '.join('?' * len(COLS))})",
                        good[COLS].values.tolist())
        cn.commit()
        t_load = time.perf_counter() - t1
    bad = df[df["Loi"] != ""]
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    bad.to_csv(EXPORT_DIR / "hocvien_online_loi.csv", index=False, encoding="utf-8-sig")
    print(f"Đọc {len(df)} dòng ({t_read * 1000:.0f} ms) · hợp lệ {len(good)} · lỗi {len(bad)} "
          f"→ data/export/hocvien_online_loi.csv · nạp staging {t_load * 1000:.0f} ms")
    print(bad["Loi"].value_counts().to_string())


# ------------------------------------------------------------------ export
EXPORT_QUERY = """
SELECT MaLop, TenLop, TenKH, TenCN, GiaoVien, NgayKhaiGiang, NgayKetThuc, SiSoHienTai, SiSoToiDa, TyLeLapDay, TrangThai, Lich
FROM dbo.vw_SiSoLop ORDER BY MaCN, NgayKhaiGiang"""


def cmd_export(args):
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    with connect() as cn:
        df = read_df(cn, EXPORT_QUERY)
        no = read_df(cn, "SELECT MaHV, HoTen, SoDienThoai, MaLop, TenKH, ThanhTien, DaThu, ConNo, HanDongHP, QuaHan "
                         "FROM dbo.vw_CongNoHocVien ORDER BY ConNo DESC")
    for c in df.columns:                                   # ngày dạng yyyy-MM-dd thay vì timestamp
        if df[c].map(lambda v: hasattr(v, "isoformat")).any():
            df[c] = df[c].map(lambda v: v.isoformat() if hasattr(v, "isoformat") else v)
    done = []
    for fmt in args.format:
        path = EXPORT_DIR / f"si_so_lop.{fmt}"
        if fmt == "csv":
            df.to_csv(path, index=False, encoding="utf-8-sig")             # BOM để Excel mở đúng tiếng Việt
        elif fmt == "xlsx":
            with pd.ExcelWriter(path, engine="openpyxl") as xw:
                df.to_excel(xw, sheet_name="SiSoLop", index=False)
                no.to_excel(xw, sheet_name="CongNo", index=False)
                for ws in xw.book.worksheets:
                    for col in ws.columns:
                        ws.column_dimensions[col[0].column_letter].width = min(40, max(10, max(len(str(c.value or "")) for c in col) + 2))
        elif fmt == "json":
            path.write_text(json.dumps(json.loads(df.to_json(orient="records", force_ascii=False)),
                                       ensure_ascii=False, indent=2), encoding="utf-8")
        elif fmt == "xml":
            df.to_xml(path, root_name="SiSoLop", row_name="Lop", index=False, encoding="utf-8")
        done.append(f"{path.relative_to(ROOT)} ({path.stat().st_size // 1024 or 1} KB)")
    print("Đã xuất:", *done, sep="\n  ")


# ------------------------------------------------------------------ bench
def cmd_bench(args):
    rows = pd.read_csv(ROOT / "data" / "import" / "hocvien_10000.csv", dtype=str, keep_default_na=False)[COLS].values.tolist()
    sql = f"INSERT dbo.STG_HOCVIEN_ONLINE ({', '.join(COLS)}) VALUES ({', '.join('?' * len(COLS))})"
    out = []
    with connect() as cn:
        cur = cn.cursor()

        def run(name, fn):
            cur.execute("TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE"); cn.commit()
            t = time.perf_counter(); fn(); cn.commit(); ms = (time.perf_counter() - t) * 1000
            n = cur.execute("SELECT COUNT(*) FROM dbo.STG_HOCVIEN_ONLINE").fetchone()[0]
            out.append((name, n, ms))

        def one_by_one():
            for r in rows:
                cur.execute(sql, r)
        run("Python: execute() từng dòng", one_by_one)

        def many_slow():
            cur.fast_executemany = False
            cur.executemany(sql, rows)
        run("Python: executemany()", many_slow)

        def many_fast():
            cur.fast_executemany = True
            cur.executemany(sql, rows)
        run("Python: executemany(fast_executemany=True)", many_fast)

        def bulk():
            cur.execute(f"BULK INSERT dbo.STG_HOCVIEN_ONLINE FROM '{args.server_dir}hocvien_10000.csv' "
                        "WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '\"', TABLOCK)")
        try:
            run("T-SQL: BULK INSERT (file trên máy chủ)", bulk)
        except pyodbc.Error as e:
            out.append(("T-SQL: BULK INSERT", 0, float("nan"))); print("  bỏ qua BULK INSERT:", str(e)[:120])

        if args.container:
            def bcp():
                cmd = ["docker", "exec", args.container, "/opt/mssql-tools18/bin/bcp", "ECMS.dbo.STG_HOCVIEN_ONLINE", "in",
                       f"{args.server_dir}hocvien_10000.csv", "-c", "-t,", "-F", "2", "-S", "localhost", "-U", "sa",
                       "-P", os.getenv("SA_PASSWORD", ""), "-u", "-b", "5000"]   # bcp chỉ nhận mật khẩu qua -P – chỉ dùng trên máy demo
                subprocess.run(cmd, check=True, capture_output=True)
            try:
                run("bcp in (công cụ dòng lệnh)", bcp)
            except subprocess.CalledProcessError as e:
                print("  bỏ qua bcp:", e.stderr[:200])
        cur.execute("TRUNCATE TABLE dbo.STG_HOCVIEN_ONLINE"); cn.commit()
    print(f"{'Phương pháp':<45}{'Số dòng':>9}{'Thời gian (ms)':>16}{'dòng/giây':>12}")
    for name, n, ms in out:
        print(f"{name:<45}{n:>9}{ms:>16.0f}{(n / ms * 1000 if ms == ms and ms else 0):>12.0f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("import"); p.add_argument("file", type=Path); p.set_defaults(fn=cmd_import)
    p = sub.add_parser("export"); p.add_argument("--format", nargs="+", default=["csv", "xlsx", "json", "xml"],
                                                 choices=["csv", "xlsx", "json", "xml"]); p.set_defaults(fn=cmd_export)
    p = sub.add_parser("bench")
    p.add_argument("--server-dir", default="/data/import/", help="thư mục chứa CSV trên máy chủ SQL Server")
    p.add_argument("--container", default="ecms-mssql", help="container để chạy bcp ('' để bỏ qua)")
    p.set_defaults(fn=cmd_bench)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
