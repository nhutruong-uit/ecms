"""In phiếu thu học phí ra PDF (T23) – reportlab, font tiếng Việt."""
from io import BytesIO
from xml.sax.saxutils import escape

import pandas as pd
from reportlab.lib import colors
from reportlab.lib.pagesizes import A5, landscape
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from reports.pdf_common import FONT, FONT_BOLD, money, so_thanh_chu, styles


def phieu_thu_pdf(pt: dict, ct: pd.DataFrame) -> bytes:
    """pt: một dòng vw_PhieuThu; ct: các dòng vw_CTPhieuThu của phiếu."""
    st = styles()
    # Paragraph của reportlab hiểu markup (<b>, <br/>…): giá trị người dùng nhập phải escape, nếu không ghi chú
    # kiểu "<KM10>" hay "A & B" làm hỏng việc dựng PDF hoặc chèn được định dạng lạ vào phiếu
    e = {k: escape(str(v)) if v is not None else "" for k, v in pt.items()}
    buf = BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=landscape(A5), leftMargin=12 * mm, rightMargin=12 * mm,
                            topMargin=10 * mm, bottomMargin=10 * mm, title=f"Phiếu thu {pt['SoPhieu']}", author="ECMS")
    ngay = pd.to_datetime(pt["NgayThu"])
    el = [
        Table([[Paragraph(f"<b>TRUNG TÂM TIẾNG ANH ECMS</b><br/>{e['TenCN']}<br/>{e['DiaChiCN']} · ĐT {e['DienThoaiCN']}", st["n"]),
                Paragraph(f"Số: <b>{e['SoPhieu']}</b><br/>Ngày {ngay:%d/%m/%Y %H:%M}", st["right"])]],
              colWidths=[120 * mm, 66 * mm], style=[("VALIGN", (0, 0), (-1, -1), "TOP")]),
        Spacer(0, 3 * mm),
        Paragraph("PHIẾU THU HỌC PHÍ", st["title"]),
        Paragraph(f"Họ tên học viên: <b>{e['HoTenHV']}</b> ({e['MaHV']}) · Điện thoại: {e['SoDienThoai']}", st["n"]),
        Paragraph(f"Địa chỉ: {e['DiaChiHV'] or '—'}", st["n"]),
        Paragraph(f"Hình thức thanh toán: {e['HinhThuc']}" + (f" · Ghi chú: {e['GhiChu']}" if pt.get("GhiChu") else ""), st["n"]),
        Spacer(0, 3 * mm),
    ]
    rows = [["STT", "Lớp", "Khoá học", "Học phí", "Giảm", "Phải đóng", "Thu lần này", "Còn nợ"]]
    for i, r in enumerate(ct.itertuples(), 1):
        rows.append([i, r.MaLop, r.TenKH, money(r.HocPhi), f"{float(r.GiamGia):g}%", money(r.ThanhTien), money(r.SoTien), money(r.ConNo)])
    rows.append(["", "", "", "", "", "Tổng cộng", money(pt["TongTien"]), ""])
    t = Table(rows, colWidths=[9 * mm, 22 * mm, 40 * mm, 23 * mm, 12 * mm, 25 * mm, 27 * mm, 25 * mm], repeatRows=1)
    t.setStyle(TableStyle([
        ("FONT", (0, 0), (-1, -1), FONT, 8.5), ("FONT", (0, 0), (-1, 0), FONT_BOLD, 8.5), ("FONT", (0, -1), (-1, -1), FONT_BOLD, 9),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1d4ed8")), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("ALIGN", (3, 1), (-1, -1), "RIGHT"), ("ALIGN", (0, 0), (0, -1), "CENTER"),
        ("GRID", (0, 0), (-1, -2), 0.4, colors.HexColor("#94a3b8")), ("LINEABOVE", (0, -1), (-1, -1), 1, colors.black),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#f1f5f9")]),
    ]))
    el += [t, Spacer(0, 2 * mm), Paragraph(f"Số tiền bằng chữ: <b>{so_thanh_chu(pt['TongTien'])}</b>", st["n"]), Spacer(0, 5 * mm),
           Table([[Paragraph("<b>Người nộp tiền</b><br/>(ký, ghi rõ họ tên)", st["center"]),
                   Paragraph(f"<b>Người lập phiếu</b><br/>(ký, ghi rõ họ tên)<br/><br/><br/>{e['NguoiLap']}", st["center"])]],
                 colWidths=[93 * mm, 93 * mm], style=[("VALIGN", (0, 0), (-1, -1), "TOP")]),
           Spacer(0, 3 * mm), Paragraph("Học phí đã đóng không hoàn lại sau buổi học thứ 3. Phiếu được in từ hệ thống ECMS.", st["small"])]
    doc.build(el)
    return buf.getvalue()
