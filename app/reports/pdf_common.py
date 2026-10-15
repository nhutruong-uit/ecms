"""Dùng chung cho báo cáo PDF: font tiếng Việt (DejaVu Sans đóng gói kèm repo), số tiền bằng chữ."""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

FONT_DIR = Path(__file__).resolve().parent / "fonts"
FONT, FONT_BOLD = "DejaVu", "DejaVu-Bold"
_registered = False


def register_fonts() -> None:
    """Font mặc định Helvetica của reportlab không có dấu tiếng Việt → nhúng DejaVu Sans (Unicode)."""
    global _registered
    if _registered:
        return
    pdfmetrics.registerFont(TTFont(FONT, str(FONT_DIR / "DejaVuSans.ttf")))
    pdfmetrics.registerFont(TTFont(FONT_BOLD, str(FONT_DIR / "DejaVuSans-Bold.ttf")))
    pdfmetrics.registerFontFamily(FONT, normal=FONT, bold=FONT_BOLD)
    _registered = True


def styles() -> dict[str, ParagraphStyle]:
    register_fonts()
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle("t", parent=base["Title"], fontName=FONT_BOLD, fontSize=16, leading=20),
        "h": ParagraphStyle("h", parent=base["Heading2"], fontName=FONT_BOLD, fontSize=11, leading=14, spaceBefore=6),
        "n": ParagraphStyle("n", parent=base["Normal"], fontName=FONT, fontSize=9.5, leading=13),
        "small": ParagraphStyle("s", parent=base["Normal"], fontName=FONT, fontSize=8, leading=10, textColor=colors.grey),
        "right": ParagraphStyle("r", parent=base["Normal"], fontName=FONT, fontSize=9.5, leading=13, alignment=2),
        "center": ParagraphStyle("c", parent=base["Normal"], fontName=FONT, fontSize=9.5, leading=13, alignment=1),
    }


def money(v) -> str:
    return f"{int(round(float(v or 0))):,}".replace(",", ".") + " đ"


_SO = ["không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín"]


def _ba_so(n: int, day_du: bool) -> str:
    tram, chuc, dv = n // 100, n // 10 % 10, n % 10
    out = []
    if day_du or tram:
        out += [_SO[tram], "trăm"]
    if chuc > 1:
        out += [_SO[chuc], "mươi"]
    elif chuc == 1:
        out.append("mười")
    elif dv and (day_du or tram):
        out.append("lẻ")
    if dv:
        out.append("mốt" if dv == 1 and chuc > 1 else "lăm" if dv == 5 and chuc >= 1 else _SO[dv])
    return " ".join(out)


def so_thanh_chu(n: int) -> str:
    """12500000 → 'Mười hai triệu năm trăm nghìn đồng'."""
    n = int(round(n))
    if n == 0:
        return "Không đồng"
    don_vi = ["", "nghìn", "triệu", "tỷ"]
    nhom = []
    while n:
        nhom.append(n % 1000)
        n //= 1000
    phan = []
    for i in range(len(nhom) - 1, -1, -1):
        if nhom[i]:
            phan.append((_ba_so(nhom[i], i < len(nhom) - 1) + " " + don_vi[i % 4]).strip())
    s = " ".join(phan) + " đồng"
    return s[0].upper() + s[1:]
