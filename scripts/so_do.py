"""Thư viện vẽ sơ đồ bằng toạ độ đặt tay (SVG → PNG) cho các hình của báo cáo.

Graphviz tự xếp chỗ nên với sơ đồ dày (ERD, sơ đồ lớp, sơ đồ CSDL) đường nối hay cắt qua hình và nhãn chồng lên
nhau. Ở đây mỗi hình, mỗi đường nối (đoạn thẳng / gấp khúc vuông góc) và mỗi nhãn đều do tệp nguồn của hình đặt
toạ độ; kiem_tra() báo nhãn chồng nhãn, nhãn đè hình hoặc đè đường, đường cắt ngang hình, và số chỗ hai đường cắt
nhau (vẽ "cầu vượt" nhỏ ở chỗ cắt) – nhờ vậy sửa bố cục không cần soi ảnh từng điểm ảnh.

    from so_do import SoDo
    s = SoDo()
    s.hop("A", 0, 0, "LOPHOC")
    ...
    s.luu(Path("docs/design/erd"))      # → erd.svg, erd.png (rsvg-convert)

Toạ độ tính bằng point, trục y hướng xuống. Phông Times New Roman như thân báo cáo; bề rộng chữ đo bằng phông thật.
"""
from __future__ import annotations

import math
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from PIL import ImageFont

PHONG = "Times New Roman"
_TTF = {}


def _ttf(dam=False, nghieng=False):
    k = (dam, nghieng)
    if k not in _TTF:
        ten = {(False, False): "Times New Roman.ttf", (True, False): "Times New Roman Bold.ttf",
               (False, True): "Times New Roman Italic.ttf", (True, True): "Times New Roman Bold Italic.ttf"}[k]
        win = {(False, False): "times.ttf", (True, False): "timesbd.ttf", (False, True): "timesi.ttf", (True, True): "timesbi.ttf"}[k]
        for d in ("/System/Library/Fonts/Supplemental", "/Library/Fonts", r"C:\Windows\Fonts", "/usr/share/fonts/truetype/msttcorefonts"):
            for t in (ten, win):
                if Path(d, t).exists():
                    _TTF[k] = ImageFont.truetype(str(Path(d, t)), 200)
                    return _TTF[k]
        _TTF[k] = None
    return _TTF[k]


def rong(text: str, co: float, dam=False, nghieng=False) -> float:
    """Bề rộng (pt) của một dòng chữ."""
    f = _ttf(dam, nghieng)
    if f is None:
        return len(text) * co * 0.5
    return f.getlength(text) / 200 * co


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ------------------------------------------------------------------ hình học
@dataclass
class Hinh:
    id: str
    x: float
    y: float
    w: float
    h: float
    loai: str                                   # hop | thoi | tamgiac | bang
    svg: str = ""

    @property
    def khung(self):
        return (self.x - self.w / 2, self.y - self.h / 2, self.x + self.w / 2, self.y + self.h / 2)

    def chua(self, px, py, le=0.0) -> bool:
        """Điểm nằm trong hình (thu vào le pt)."""
        if self.loai == "thoi":
            return abs(px - self.x) / (self.w / 2 - le) + abs(py - self.y) / (self.h / 2 - le) < 1 if self.w / 2 > le and self.h / 2 > le else False
        x0, y0, x1, y1 = self.khung
        return x0 + le < px < x1 - le and y0 + le < py < y1 - le


@dataclass
class Nhan:
    x0: float
    y0: float
    x1: float
    y1: float
    text: str


@dataclass
class Duong:
    pts: list
    nets: str = ""
    dau: tuple = ()                              # id hình ở hai đầu (bỏ qua khi kiểm tra cắt hình)
    cau: bool = True                             # vẽ "cầu vượt" khi đoạn ngang cắt đoạn dọc khác
    rong: float = 1.3
    mau: str = "#475569"


def _cat(a, b, c, d):
    """Giao điểm hai đoạn thẳng ab, cd (không tính chạm đầu mút), None nếu không cắt."""
    (x1, y1), (x2, y2), (x3, y3), (x4, y4) = a, b, c, d
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-9:
        return None
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den
    e = 1e-6
    if e < t < 1 - e and e < u < 1 - e:
        return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))
    return None


def _doan_cat_hcn(a, b, r, le=0.5):
    """Đoạn ab đi xuyên qua phần trong của hình chữ nhật r (thu vào le)."""
    x0, y0, x1, y1 = r[0] + le, r[1] + le, r[2] - le, r[3] - le
    if x0 >= x1 or y0 >= y1:
        return False
    # Liang–Barsky
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, ax - x0), (dx, x1 - ax), (-dy, ay - y0), (dy, y1 - ay)):
        if abs(p) < 1e-12:
            if q < 0:
                return False
        else:
            t = q / p
            if p < 0:
                t0 = max(t0, t)
            else:
                t1 = min(t1, t)
    return t0 < t1 - 1e-9


class SoDo:
    def __init__(self, co=15.0, co_nhan=13.5):
        self.co, self.co_nhan = co, co_nhan
        self.hinh: dict[str, Hinh] = {}
        self.nhan: list[Nhan] = []
        self.duong: list[Duong] = []
        self.ve: list[str] = []                  # svg phụ (khung nhóm, chữ tự do) vẽ dưới cùng
        self.chu: list[str] = []
        self.cac_khung: list[tuple] = []

    # -------------------------------------------------------------- chữ
    def _chu(self, x, y, text, co, neo="middle", dam=False, nghieng=False, mau="#111827"):
        dong = text.split("\n")
        lh = co * 1.18
        y0 = y - (len(dong) - 1) * lh / 2
        out = []
        for i, d in enumerate(dong):
            out.append(f'<text x="{x:.1f}" y="{y0 + i * lh + co * 0.34:.1f}" font-family="{PHONG}" font-size="{co}" '
                       f'text-anchor="{neo}" fill="{mau}"' + (' font-weight="bold"' if dam else "")
                       + (' font-style="italic"' if nghieng else "") + f'>{_esc(d)}</text>')
        return "".join(out)

    def rong_chu(self, text, co=None, dam=False):
        return max(rong(d, co or self.co, dam) for d in text.split("\n"))

    # -------------------------------------------------------------- hình
    def hop(self, id, x, y, text, kieu="thuc_the", w=None, h=None, co=None, nen="#dbeafe", vien="#1d4ed8"):
        """Hình chữ nhật: thuc_the | yeu (viền đôi) | da_tri (nét đứt) | tron (bo góc) | tron_dut (bo góc, nét đứt)."""
        co = co or self.co
        n = text.count("\n") + 1
        w = w or self.rong_chu(text, co) + 26
        h = h or co * 1.18 * n + 16
        x0, y0 = x - w / 2, y - h / 2
        if kieu == "yeu":
            nen = "#e0e7ff"
        g = [f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{nen}" stroke="{vien}" stroke-width="1.4"'
             + (' stroke-dasharray="5 3"' if kieu in ("da_tri", "tron_dut") else "")
             + (' rx="7"' if kieu.startswith("tron") else "") + "/>"]
        if kieu == "yeu":
            g.append(f'<rect x="{x0 + 3.5:.1f}" y="{y0 + 3.5:.1f}" width="{w - 7:.1f}" height="{h - 7:.1f}" fill="none" stroke="{vien}" stroke-width="1.1"/>')
        g.append(self._chu(x, y, text, co))
        self.hinh[id] = Hinh(id, x, y, w, h, "hop", "".join(g))
        return self.hinh[id]

    def thoi(self, id, x, y, text, kieu="thuong", w=None, h=None, co=None):
        """Hình thoi mối kết hợp: thuong | dam (thực thể hoá thành bảng) | xac_dinh (viền đôi)."""
        co = co or self.co - 1
        n = text.count("\n") + 1
        w = w or self.rong_chu(text, co) * 1.55 + 26
        h = h or co * 1.18 * n * 1.55 + 14
        nen = "#fde68a" if kieu == "dam" else "#fef3c7"
        def pts(dx, dy):
            return f"{x:.1f},{y - h / 2 + dy:.1f} {x + w / 2 - dx:.1f},{y:.1f} {x:.1f},{y + h / 2 - dy:.1f} {x - w / 2 + dx:.1f},{y:.1f}"
        g = [f'<polygon points="{pts(0, 0)}" fill="{nen}" stroke="#b45309" stroke-width="1.4"/>']
        if kieu == "xac_dinh":
            k = 5.0
            g.append(f'<polygon points="{pts(k * w / h * 0.9 + 2, k)}" fill="none" stroke="#b45309" stroke-width="1.1"/>')
        g.append(self._chu(x, y, text, co))
        self.hinh[id] = Hinh(id, x, y, w, h, "thoi", "".join(g))
        return self.hinh[id]

    def elip(self, id, x, y, text, kieu="don", w=None, h=None, co=None):
        """Thuộc tính (ký hiệu Chen): don | da_tri (viền đôi) | suy_dien (nét đứt)."""
        co = co or self.co - 1
        w = w or self.rong_chu(text, co) + 34
        h = h or co * 1.18 + 18
        g = [f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{w / 2:.1f}" ry="{h / 2:.1f}" fill="#ffffff" stroke="#64748b" stroke-width="1.3"'
             + (' stroke-dasharray="5 3"' if kieu == "suy_dien" else "") + "/>"]
        if kieu == "da_tri":
            g.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{w / 2 - 4:.1f}" ry="{h / 2 - 4:.1f}" fill="none" stroke="#64748b" stroke-width="1.1"/>')
        g.append(self._chu(x, y, text, co))
        self.hinh[id] = Hinh(id, x, y, w, h, "thoi", "".join(g))   # kiểm tra va chạm: xấp xỉ bằng hình thoi nội tiếp
        self.hinh[id].elip = True
        return self.hinh[id]

    def tam_giac(self, id, x, y, text="ISA", w=58, h=44, huong="len"):
        """Tam giác ISA, đỉnh hướng về lớp cha (len | xuong | trai | phai)."""
        if huong in ("len", "xuong"):
            s = -1 if huong == "len" else 1
            p = [(x, y + s * h / 2), (x + w / 2, y - s * h / 2), (x - w / 2, y - s * h / 2)]
            bw, bh = w, h
        else:
            s = -1 if huong == "trai" else 1
            p = [(x + s * h / 2, y), (x - s * h / 2, y - w / 2), (x - s * h / 2, y + w / 2)]
            bw, bh = h, w
        cy = y + (h * 0.12 if huong == "len" else -h * 0.12 if huong == "xuong" else 0)
        cx = x + (h * 0.1 if huong == "trai" else -h * 0.1 if huong == "phai" else 0)
        g = (f'<polygon points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in p)}" fill="#dcfce7" stroke="#15803d" stroke-width="1.4"/>'
             + self._chu(cx, cy, text, self.co - 3))
        self.hinh[id] = Hinh(id, x, y, bw, bh, "tamgiac", g)
        self.hinh[id].dinh = p
        return self.hinh[id]

    def lop(self, id, x, y, ten, thuoc_tinh=(), phuong_thuc=(), khuon="", co=None, w=None):
        """Lớp UML: ngăn tên (khuôn mẫu «…» in nghiêng phía trên), ngăn thuộc tính, ngăn phương thức (bỏ nếu rỗng)."""
        co = co or self.co - 3
        lh = co * 1.22
        dong_ten = ([f"«{khuon}»"] if khuon else []) + [ten]
        w = w or max([rong(t, co, True) for t in dong_ten] + [rong(t, co) for t in (*thuoc_tinh, *phuong_thuc)]) + 18
        h_ten = len(dong_ten) * lh + 10
        h_tt = len(thuoc_tinh) * lh + 8
        h_pt = len(phuong_thuc) * lh + 8 if phuong_thuc else 0
        h = h_ten + h_tt + h_pt
        x0, y0 = x - w / 2, y - h / 2
        g = [f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{h:.1f}" fill="#ffffff" stroke="#1d4ed8" stroke-width="1.3"/>',
             f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{h_ten:.1f}" fill="#dbeafe" stroke="#1d4ed8" stroke-width="1.3"/>']
        for i, t in enumerate(dong_ten):
            g.append(self._chu(x, y0 + 5 + lh * (i + 0.5), t, co - (1 if t.startswith("«") else 0), dam=not t.startswith("«"),
                               nghieng=t.startswith("«")))
        yy = y0 + h_ten
        g.append(f'<line x1="{x0:.1f}" y1="{yy + h_tt:.1f}" x2="{x0 + w:.1f}" y2="{yy + h_tt:.1f}" stroke="#1d4ed8" stroke-width="1.3"/>' if h_pt else "")
        for k, t in enumerate((*thuoc_tinh, *phuong_thuc)):
            base = yy + 4 + lh * (k + 0.5) + (8 if k >= len(thuoc_tinh) else 0)
            g.append(self._chu(x0 + 8, base, t, co, neo="start"))
        self.hinh[id] = Hinh(id, x, y, w, h, "hop", "".join(g))
        return self.hinh[id]

    def khung(self, x0, y0, x1, y1, tieu_de="", co=None):
        """Khung nhóm nét đứt bo góc, tiêu đề ở góc trên trái (vẽ dưới cùng)."""
        co = co or self.co
        self.ve.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{x1 - x0:.1f}" height="{y1 - y0:.1f}" rx="8" fill="#ffffff" '
                       f'stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="6 4"/>')
        if tieu_de:
            self.ve.append(self._chu(x0 + 12, y0 + 8 + co * 0.6, tieu_de, co, neo="start"))
        self.cac_khung.append((x0, y0, x1, y1))

    def bang(self, id, x, y, ten, dong=(), them=0, xam=False, co=None, w=None):
        """Bảng CSDL: tiêu đề nền xanh; mỗi dòng (loại khoá, tên cột[, in đậm]) – cột khoá chính in đậm, "*" là NOT NULL;
        "+ n cột khác" ở cuối. xam=True: bảng thuộc nhóm khác, chỉ có tiêu đề nền xám. y là tâm DÒNG TIÊU ĐỀ."""
        co = co or self.co - 2
        lh = co * 1.5
        c1 = max([rong(d[0], co) for d in dong] + [0]) + 12 if dong else 0
        w = w or max([rong(ten, co + 0.5, True) + 22] + [c1 + rong(d[1], co, len(d) > 2 and d[2]) + 16 for d in dong]
                     + [rong(f"+ {them} cột khác", co, nghieng=True) + 16])
        n = len(dong) + (1 if them else 0)
        h = lh + 4 + n * lh
        x0, y0 = x - w / 2, y - (lh + 4) / 2
        nen, vien, chu = ("#e2e8f0", "#64748b", "#334155") if xam else ("#1d4ed8", "#1e3a8a", "#ffffff")
        g = [f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{h:.1f}" fill="#f8fafc" stroke="{vien}" stroke-width="1.2"/>',
             f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{w:.1f}" height="{lh + 4:.1f}" fill="{nen}" stroke="{vien}" stroke-width="1.2"/>',
             self._chu(x, y, ten, co + 0.5, dam=True, mau=chu)]
        for i, d in enumerate(dong):
            yy = y0 + lh + 4 + i * lh
            g.append(f'<line x1="{x0:.1f}" y1="{yy:.1f}" x2="{x0 + w:.1f}" y2="{yy:.1f}" stroke="#94a3b8" stroke-width="0.8"/>')
            g.append(f'<line x1="{x0 + c1:.1f}" y1="{yy:.1f}" x2="{x0 + c1:.1f}" y2="{yy + lh:.1f}" stroke="#94a3b8" stroke-width="0.8"/>')
            g.append(self._chu(x0 + 6, yy + lh / 2, d[0], co, neo="start", mau="#334155"))
            g.append(self._chu(x0 + c1 + 7, yy + lh / 2, d[1], co, neo="start", dam=len(d) > 2 and d[2]))
        if them:
            yy = y0 + lh + 4 + len(dong) * lh
            g.append(f'<line x1="{x0:.1f}" y1="{yy:.1f}" x2="{x0 + w:.1f}" y2="{yy:.1f}" stroke="#94a3b8" stroke-width="0.8"/>')
            g.append(self._chu(x0 + 6, yy + lh / 2, f"+ {them} cột khác", co, neo="start", nghieng=True, mau="#475569"))
        hn = Hinh(id, x, y0 + h / 2, w, h, "hop", "".join(g))
        hn.dong_y = [y0 + lh + 4 + (i + 0.5) * lh for i in range(len(dong))]
        hn.y_tieu_de = y
        self.hinh[id] = hn
        return hn

    def D(self, id, i, canh):
        """Điểm ở mép trái (canh="l") / phải ("r") của dòng thứ i trong bảng; i = -1: dòng tiêu đề."""
        h = self.hinh[id]
        yy = h.y_tieu_de if i < 0 else h.dong_y[i]
        return (h.x - h.w / 2 if canh == "l" else h.x + h.w / 2, yy)

    def svg_tho(self, id, x, y, w, h, svg):
        """Hình tự vẽ (vd. bảng nhiều ngăn) – chỉ cần khung để kiểm tra va chạm."""
        self.hinh[id] = Hinh(id, x, y, w, h, "bang", svg)
        return self.hinh[id]

    # -------------------------------------------------------------- điểm neo
    def P(self, id, canh, lech=0.0):
        """Điểm trên hình: canh = t (trên) | b (dưới) | l (trái) | r (phải); lech: dịch dọc cạnh (pt).
        Hình thoi: đỉnh của cạnh đó (lech bỏ qua). Tam giác: đỉnh (t/b) hoặc trung điểm cạnh đáy."""
        h = self.hinh[id]
        if h.loai == "thoi":
            return {"t": (h.x, h.y - h.h / 2), "b": (h.x, h.y + h.h / 2), "l": (h.x - h.w / 2, h.y), "r": (h.x + h.w / 2, h.y)}[canh]
        return {"t": (h.x + lech, h.y - h.h / 2), "b": (h.x + lech, h.y + h.h / 2),
                "l": (h.x - h.w / 2, h.y + lech), "r": (h.x + h.w / 2, h.y + lech)}[canh]

    # -------------------------------------------------------------- đường
    def noi(self, *pts, nets="", dau=(), rong=1.3, mau="#475569", cau=True, mui=None, ten=False):
        """Đường gấp khúc qua các điểm; điểm là (x, y) hoặc ("id", canh[, lech]). Điểm trung gian có thể ghi
        ("x", v) / ("y", v): giữ nguyên toạ độ còn lại của điểm trước – tiện vẽ đoạn vuông góc.
        mui: ký hiệu UML ở điểm ĐẦU đường – "ke_thua" (tam giác rỗng), "thanh_phan" (thoi đặc), "ket_tap" (thoi rỗng).
        ten=True: mũi tên đặc ở điểm CUỐI đường."""
        out, ids = [], []
        for p in pts:
            if isinstance(p, tuple) and len(p) >= 2 and isinstance(p[0], str) and p[0] not in ("x", "y"):
                h = self.hinh[p[0]]
                if hasattr(h, "dong_y") and p[1] in ("l", "r"):
                    out.append(self.D(p[0], p[2] if len(p) > 2 else -1, p[1]))
                else:
                    out.append(self.P(*p))
                ids.append(p[0])
            elif isinstance(p, tuple) and p[0] == "x":
                out.append((p[1], out[-1][1]))
            elif isinstance(p, tuple) and p[0] == "y":
                out.append((out[-1][0], p[1]))
            else:
                out.append(tuple(p))
        mui_svg = ""
        if mui in ("ke_thua", "thanh_phan", "ket_tap"):
            (x0, y0), (x1, y1) = out[0], out[1]
            dx, dy = x1 - x0, y1 - y0
            n = math.hypot(dx, dy)
            ux, uy = dx / n, dy / n                      # hướng từ đầu đường vào trong
            px, py = -uy, ux
            dai, nua = (15, 8.5) if mui == "ke_thua" else (22, 7.5)
            if mui == "ke_thua":
                ds = [(x0, y0), (x0 + ux * dai + px * nua, y0 + uy * dai + py * nua), (x0 + ux * dai - px * nua, y0 + uy * dai - py * nua)]
                nen = "#ffffff"
            else:
                m = (x0 + ux * dai / 2, y0 + uy * dai / 2)
                ds = [(x0, y0), (m[0] + px * nua, m[1] + py * nua), (x0 + ux * dai, y0 + uy * dai), (m[0] - px * nua, m[1] - py * nua)]
                nen = "#334155" if mui == "thanh_phan" else "#ffffff"
            mui_svg = (f'<polygon points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in ds)}" fill="{nen}" stroke="{mau}" '
                       f'stroke-width="{rong}" stroke-linejoin="miter"/>')
            out[0] = (x0 + ux * dai, y0 + uy * dai)
        if mui == "mot":                                 # một: vạch ngang gần đầu đường
            (x0, y0), (x1, y1) = out[0], out[1]
            n = math.hypot(x1 - x0, y1 - y0); ux, uy = (x1 - x0) / n, (y1 - y0) / n
            cx, cy = x0 + ux * 8, y0 + uy * 8
            mui_svg = (f'<line x1="{cx - uy * 6:.1f}" y1="{cy + ux * 6:.1f}" x2="{cx + uy * 6:.1f}" y2="{cy - ux * 6:.1f}" '
                       f'stroke="{mau}" stroke-width="{rong + 0.2}"/>')
        if ten == "nhieu":                               # nhiều: chân quạ ở cuối đường
            (x1, y1), (x0, y0) = out[-1], out[-2]
            n = math.hypot(x1 - x0, y1 - y0); ux, uy = (x1 - x0) / n, (y1 - y0) / n
            bx, by = x1 - ux * 11, y1 - uy * 11
            mui_svg += "".join(f'<line x1="{bx:.1f}" y1="{by:.1f}" x2="{x1 + uy * k:.1f}" y2="{y1 - ux * k:.1f}" stroke="{mau}" '
                               f'stroke-width="{rong}"/>' for k in (-6.5, 0, 6.5))
            ten = False
        if ten:
            (x1, y1), (x0, y0) = out[-1], out[-2]
            n = math.hypot(x1 - x0, y1 - y0)
            ux, uy = (x1 - x0) / n, (y1 - y0) / n
            dai, nua = 9.0, 4.2
            bx, by = x1 - ux * dai, y1 - uy * dai
            mui_svg += (f'<polygon points="{x1:.1f},{y1:.1f} {bx - uy * nua:.1f},{by + ux * nua:.1f} {bx + uy * nua:.1f},{by - ux * nua:.1f}" '
                        f'fill="{mau}" stroke="{mau}" stroke-width="0.8"/>')
            out[-1] = (bx + ux * 1.5, by + uy * 1.5)
        d = Duong(out, nets, tuple(ids) + tuple(dau), cau, rong, mau)
        d.mui_svg = mui_svg
        self.duong.append(d)
        return d

    # -------------------------------------------------------------- nhãn
    def nhan_tai(self, x, y, text, neo="c", co=None, nghieng=False, mau="#1f2937", dam=False, nen=True):
        """Nhãn chữ; (x, y) là điểm neo, neo = c | n | s | e | w | ne | nw | se | sw (phía của hộp chữ so với điểm)."""
        co = co or self.co_nhan
        n = text.count("\n") + 1
        w = max(rong(d, co, dam, nghieng) for d in text.split("\n"))
        h = co * 1.18 * n
        dx = {"c": 0, "n": 0, "s": 0, "e": w / 2, "w": -w / 2, "ne": w / 2, "nw": -w / 2, "se": w / 2, "sw": -w / 2}[neo]
        dy = {"c": 0, "n": -h / 2, "s": h / 2, "e": 0, "w": 0, "ne": -h / 2, "nw": -h / 2, "se": h / 2, "sw": h / 2}[neo]
        cx, cy = x + dx, y + dy
        self.nhan.append(Nhan(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, text))
        nen_svg = (f'<rect x="{cx - w / 2 - 1.5:.1f}" y="{cy - h / 2:.1f}" width="{w + 3:.1f}" height="{h:.1f}" fill="white" fill-opacity="0.92"/>'
                   if nen else "")
        self.chu.append(nen_svg + self._chu(cx, cy, text, co, "middle", dam, nghieng, mau))

    def ban_so(self, id, canh, text, phia, lech=0.0, cach=5.0, doc=6.0):
        """Nhãn bản số sát đầu đường nối tại cạnh `canh` của hình `id`. phia: bên nào của đường (với đường dọc:
        "e" | "w"; đường ngang: "n" | "s"). doc: khoảng cách từ mép hình dọc theo đường."""
        x, y = self.P(id, canh, lech)
        if canh in ("t", "b"):
            s = -1 if canh == "t" else 1
            yy = y + s * doc
            self.nhan_tai(x + (cach if phia == "e" else -cach), yy, text, ("n" if s < 0 else "s") + phia)
        else:
            s = -1 if canh == "l" else 1
            xx = x + s * doc
            self.nhan_tai(xx, y + (-cach if phia == "n" else cach), text, phia + ("w" if s < 0 else "e"))

    # -------------------------------------------------------------- kiểm tra
    def _doan(self):
        for k, d in enumerate(self.duong):
            for a, b in zip(d.pts, d.pts[1:]):
                yield k, d, a, b

    def kiem_tra(self, in_ra=True) -> int:
        loi = []
        hcn = {i: h.khung for i, h in self.hinh.items()}
        # nhãn chồng nhãn / nhãn đè hình / nhãn đè đường
        for i, a in enumerate(self.nhan):
            ra = (a.x0, a.y0, a.x1, a.y1)
            for b in self.nhan[i + 1:]:
                if a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1:
                    loi.append(f"nhãn chồng nhãn: {a.text!r} – {b.text!r}")
            for h in self.hinh.values():
                if h.loai == "thoi":
                    cx = min(max(h.x, a.x0), a.x1); cy = min(max(h.y, a.y0), a.y1)
                    if h.chua(cx, cy) or any(h.chua(px, py) for px, py in ((a.x0, a.y0), (a.x1, a.y0), (a.x0, a.y1), (a.x1, a.y1))):
                        loi.append(f"nhãn đè hình: {a.text!r} – {h.id}")
                else:
                    x0, y0, x1, y1 = h.khung
                    if a.x0 < x1 and x0 < a.x1 and a.y0 < y1 and y0 < a.y1:
                        loi.append(f"nhãn đè hình: {a.text!r} – {h.id}")
            for _, d, p, q in self._doan():
                if _doan_cat_hcn(p, q, ra, le=-1.0):
                    loi.append(f"nhãn đè đường: {a.text!r} – đường {d.dau}")
                    break
        # đường cắt qua hình (trừ hình ở hai đầu)
        for _, d, p, q in self._doan():
            for i, r in hcn.items():
                if i in d.dau:
                    continue
                h = self.hinh[i]
                if h.loai == "thoi":
                    n = 24
                    if any(h.chua(p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n, 0.5) for t in range(n + 1)):
                        loi.append(f"đường {d.dau} cắt hình {i}")
                elif _doan_cat_hcn(p, q, r):
                    loi.append(f"đường {d.dau} cắt hình {i}")
        # đường cắt đường
        ds = list(self._doan())
        cat = 0
        for i, (k1, d1, a, b) in enumerate(ds):
            for k2, d2, c, e in ds[i + 1:]:
                if k1 != k2 and _cat(a, b, c, e):
                    cat += 1
                    if in_ra:
                        print(f"  · hai đường cắt nhau: {d1.dau} × {d2.dau}")
        if in_ra:
            for l in dict.fromkeys(loi):
                print("  ! " + l)
            print(f"  {len(set(loi))} lỗi bố cục, {cat} chỗ đường cắt nhau")
        return len(set(loi))

    # -------------------------------------------------------------- xuất
    def _ve_duong(self, d: Duong, cac_doc):
        """Path của một đường; đoạn ngang cắt đoạn dọc của đường khác thì vẽ cung nhỏ (cầu vượt)."""
        r = 4.5
        out = [f"M{d.pts[0][0]:.1f},{d.pts[0][1]:.1f}"]
        for a, b in zip(d.pts, d.pts[1:]):
            if d.cau and abs(a[1] - b[1]) < 0.01 and abs(a[0] - b[0]) > 0.01:
                s = 1 if b[0] > a[0] else -1
                xs = sorted((x for (x, y0, y1, dd) in cac_doc if dd is not d and min(y0, y1) + r < a[1] < max(y0, y1) - r
                             and min(a[0], b[0]) + r < x < max(a[0], b[0]) - r), key=lambda x: s * x)
                for x in xs:
                    out.append(f"L{x - s * r:.1f},{a[1]:.1f} A{r},{r} 0 0 {1 if s > 0 else 0} {x + s * r:.1f},{a[1]:.1f}")
            out.append(f"L{b[0]:.1f},{b[1]:.1f}")
        return (f'<path d="{" ".join(out)}" fill="none" stroke="{d.mau}" stroke-width="{d.rong}" stroke-linejoin="round"'
                + (' stroke-dasharray="6 4"' if d.nets == "dut" else "") + "/>")

    def svg(self, le=14.0) -> str:
        xs, ys = [], []
        for h in self.hinh.values():
            x0, y0, x1, y1 = h.khung
            xs += [x0, x1]; ys += [y0, y1]
        for n in self.nhan:
            xs += [n.x0, n.x1]; ys += [n.y0, n.y1]
        for x0, y0, x1, y1 in self.cac_khung:
            xs += [x0, x1]; ys += [y0, y1]
        for d in self.duong:
            for x, y in d.pts:
                xs.append(x); ys.append(y)
        X0, Y0, X1, Y1 = min(xs) - le, min(ys) - le, max(xs) + le, max(ys) + le
        doc = [(a[0], a[1], b[1], d) for d in self.duong for a, b in zip(d.pts, d.pts[1:]) if abs(a[0] - b[0]) < 0.01]
        body = (self.ve + [self._ve_duong(d, doc) for d in self.duong] + [h.svg for h in self.hinh.values()]
                + [getattr(d, "mui_svg", "") for d in self.duong] + self.chu)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{X0:.1f} {Y0:.1f} {X1 - X0:.1f} {Y1 - Y0:.1f}" '
                f'width="{X1 - X0:.1f}pt" height="{Y1 - Y0:.1f}pt">'
                f'<rect x="{X0:.1f}" y="{Y0:.1f}" width="{X1 - X0:.1f}" height="{Y1 - Y0:.1f}" fill="white"/>'
                + "\n".join(body) + "</svg>\n")

    def luu(self, goc: Path, rong_px=2600):
        """Ghi goc.svg và goc.png (rộng rong_px điểm ảnh)."""
        goc = Path(goc)
        goc.with_suffix(".svg").write_text(self.svg(), encoding="utf-8")
        subprocess.run(["rsvg-convert", "-w", str(rong_px), "-b", "white", "-o", str(goc.with_suffix(".png")),
                        str(goc.with_suffix(".svg"))], check=True)
