"""Sinh báo cáo PDF / Excel (T24) – thay cho Crystal Report của Bài thực hành 5.

Cấu trúc một báo cáo: Report Header (tên trung tâm, tiêu đề, tham số) → Page Header (tiêu đề cột lặp lại mỗi trang)
→ Detail (dòng dữ liệu) / Group Header – Group Footer (tổng phụ) → Report Footer (tổng cộng)
→ Page Footer ("Trang X / Y", thời điểm in).
"""
from datetime import datetime
from io import BytesIO

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from reports.pdf_common import FONT, FONT_BOLD, money, styles

XANH = colors.HexColor("#1d4ed8")
NHAT = colors.HexColor("#f1f5f9")
NHOM = colors.HexColor("#dbeafe")


class _CanvasDanhSo(canvas.Canvas):
    """Page Footer: 'Trang X / Y' – cần biết tổng số trang nên vẽ chân trang sau khi dựng xong toàn bộ."""

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self._trang = []

    def showPage(self):
        self._trang.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        tong = len(self._trang)
        for t in self._trang:
            self.__dict__.update(t)
            w, _ = self._pagesize
            self.setFont(FONT, 7.5)
            self.setFillColor(colors.grey)
            self.drawString(12 * mm, 8 * mm, f"ECMS · in lúc {datetime.now():%d/%m/%Y %H:%M}")
            self.drawRightString(w - 12 * mm, 8 * mm, f"Trang {self._pageNumber} / {tong}")
            super().showPage()
        super().save()


def _fmt(v, kieu: str | None):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return ""
    if kieu == "money":
        return money(v)
    if kieu == "date":
        return pd.to_datetime(v).strftime("%d/%m/%Y")
    if kieu == "num":
        return f"{float(v):,.2f}".rstrip("0").rstrip(".").replace(",", "X").replace(".", ",").replace("X", ".")
    return str(v)


def pdf(tieu_de: str, tham_so: str, df: pd.DataFrame, cot: list[tuple[str, str, float, str | None]],
        nhom: str | None = None, tong: list[str] = (), ngang: bool = True) -> bytes:
    """cot: [(tên cột df, tiêu đề, độ rộng mm, kiểu: money|date|num|None)]. nhom: cột phân nhóm (Group Header/Footer)."""
    st = styles()
    buf = BytesIO()
    size = landscape(A4) if ngang else A4
    doc = SimpleDocTemplate(buf, pagesize=size, leftMargin=12 * mm, rightMargin=12 * mm, topMargin=12 * mm, bottomMargin=14 * mm,
                            title=tieu_de, author="ECMS")
    el = [Paragraph("TRUNG TÂM TIẾNG ANH ECMS", st["n"]), Paragraph(tieu_de.upper(), st["title"]),
          Paragraph(tham_so, st["center"]), Spacer(0, 4 * mm)]                                   # Report Header
    head = [c[1] for c in cot]
    rows, kieu_dong = [head], []

    def dong_tong(nhan, d):
        r = [""] * len(cot)
        r[0] = nhan
        for i, (c, _, _, k) in enumerate(cot):
            if c in tong:
                r[i] = _fmt(d[c].sum(), k)
        return r

    if nhom:
        for g, d in df.groupby(nhom, sort=False):
            nhan = dict((c[0], c[1]) for c in cot).get(nhom)
            rows.append([f"{nhan}: {g}" if nhan else str(g)] + [""] * (len(cot) - 1)); kieu_dong.append("gh")
            for r in d.itertuples(index=False):
                rows.append([_fmt(getattr(r, c), k) for c, _, _, k in cot]); kieu_dong.append("d")
            if tong:
                rows.append(dong_tong(f"Cộng {g}", d)); kieu_dong.append("gf")                    # Group Footer
    else:
        for r in df.itertuples(index=False):
            rows.append([_fmt(getattr(r, c), k) for c, _, _, k in cot]); kieu_dong.append("d")
    if tong:
        rows.append(dong_tong("TỔNG CỘNG", df)); kieu_dong.append("rf")                          # Report Footer
    kha_dung = size[0] - 24 * mm                                                                 # co cột cho vừa khổ giấy
    rong = [c[2] * mm for c in cot]
    he_so = min(1.0, kha_dung / sum(rong))
    t = Table(rows, colWidths=[w * he_so for w in rong], repeatRows=1)                           # Page Header lặp lại
    sty = [("FONT", (0, 0), (-1, -1), FONT, 8.5), ("FONT", (0, 0), (-1, 0), FONT_BOLD, 8.5),
           ("BACKGROUND", (0, 0), (-1, 0), XANH), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
           ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#cbd5e1")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]
    for i, (_, _, _, k) in enumerate(cot):
        if k in ("money", "num"):
            sty.append(("ALIGN", (i, 1), (i, -1), "RIGHT"))
    for j, kd in enumerate(kieu_dong, start=1):
        if kd == "gh":
            sty += [("SPAN", (0, j), (-1, j)), ("BACKGROUND", (0, j), (-1, j), NHOM), ("FONT", (0, j), (-1, j), FONT_BOLD, 9)]
        elif kd == "gf":
            sty += [("FONT", (0, j), (-1, j), FONT_BOLD, 8.5), ("LINEABOVE", (0, j), (-1, j), 0.8, XANH)]
        elif kd == "rf":
            sty += [("FONT", (0, j), (-1, j), FONT_BOLD, 9.5), ("BACKGROUND", (0, j), (-1, j), NHAT),
                    ("LINEABOVE", (0, j), (-1, j), 1.2, colors.black)]
        elif j % 2 == 0:
            sty.append(("BACKGROUND", (0, j), (-1, j), NHAT))
    t.setStyle(TableStyle(sty))
    el += [t, Spacer(0, 3 * mm), Paragraph(f"Số dòng: {len(df)}", st["small"])]
    doc.build(el, canvasmaker=_CanvasDanhSo)
    return buf.getvalue()


def excel(sheets: dict[str, tuple[str, pd.DataFrame, dict[str, str]]], tong: dict[str, list[str]] | None = None) -> bytes:
    """sheets: {tên sheet: (tiêu đề, df, {cột: tiêu đề hiển thị})}. Định dạng tiền, ngày, tiêu đề, dòng tổng."""
    wb = Workbook()
    wb.remove(wb.active)
    vien = Border(*(Side(style="thin", color="CBD5E1"),) * 4)
    for ten, (tieu_de, df, nhan) in sheets.items():
        ws = wb.create_sheet(ten[:31])
        cols = list(nhan)
        ws.cell(1, 1, "TRUNG TÂM TIẾNG ANH ECMS").font = Font(bold=True, color="1D4ED8")
        ws.cell(2, 1, tieu_de).font = Font(bold=True, size=14)
        ws.cell(3, 1, f"In lúc {datetime.now():%d/%m/%Y %H:%M}").font = Font(italic=True, color="64748B")
        for j, c in enumerate(cols, 1):
            cell = ws.cell(5, j, nhan[c])
            cell.font, cell.fill, cell.border = Font(bold=True, color="FFFFFF"), PatternFill("solid", fgColor="1D4ED8"), vien
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        for i, r in enumerate(df[cols].itertuples(index=False), 6):
            for j, v in enumerate(r, 1):
                v = None if (isinstance(v, float) and pd.isna(v)) else v
                cell = ws.cell(i, j, float(v) if hasattr(v, "is_finite") else v)
                cell.border = vien
                if cols[j - 1] in ("HocPhi", "ThanhTien", "DaThu", "ConNo", "DoanhThu", "SoTien", "TongLuong", "LuongCoBan", "DonGiaBuoi"):
                    cell.number_format = '#,##0" đ"'
        cuoi = 5 + len(df)
        if tong and ten in tong and len(df):
            ws.cell(cuoi + 1, 1, "TỔNG CỘNG").font = Font(bold=True)
            for c in tong[ten]:
                j = cols.index(c) + 1
                L = get_column_letter(j)
                cell = ws.cell(cuoi + 1, j, f"=SUM({L}6:{L}{cuoi})")                             # công thức Excel, không ghi số cứng
                cell.font, cell.number_format = Font(bold=True), '#,##0" đ"'
        for j, c in enumerate(cols, 1):
            w = max([len(str(nhan[c]))] + [len(str(v)) for v in df[c].head(200)]) + 2
            ws.column_dimensions[get_column_letter(j)].width = min(45, max(9, w))
        ws.freeze_panes = "A6"
        ws.auto_filter.ref = f"A5:{get_column_letter(len(cols))}{max(cuoi, 6)}"
    out = BytesIO()
    wb.save(out)
    return out.getvalue()
