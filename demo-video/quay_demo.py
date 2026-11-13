#!/usr/bin/env python3
"""Quay video demo ECMS cho buổi báo cáo đồ án – tự động bằng Playwright + ffmpeg (không có giọng đọc, chỉ phụ đề).

Quy trình mỗi lần chạy:
  1. Mở Microsoft Edge 1920×1080, thao tác trên ứng dụng ECMS đang chạy như người dùng thật (con trỏ chuột trượt
     mượt, gõ từng phím, hiện phụ đề giải thích và nhãn vai trò), Playwright ghi lại thành video thô.
  2. ffmpeg chuyển thành ECMS_demo.mp4 (H.264), kèm tệp phụ đề rời ECMS_demo.vi.srt.

Cần: Microsoft Edge, ffmpeg, Python 3.10+ và `pip install playwright` (Playwright 1.60 dùng sẵn ffmpeg trong ms-playwright nếu
đã có trên máy; bản mới hơn tự tải thêm). Video thô và MP4 ghi vào thư mục out/.

Chạy (từ thư mục chứa tệp này; ứng dụng ECMS phải đang mở ở --base-url, CSDL có dữ liệu mẫu):

    python quay_demo.py --base-url http://localhost:8501
    python quay_demo.py --scenes ketoan,hocvien --ma-hv HV0501     # quay lại vài cảnh (cảnh sau cần học viên đã có)
    python quay_demo.py --khong-ghep                                # chỉ quay video thô (webm), không đổi sang mp4

CẢNH BÁO: kịch bản GHI dữ liệu thật (thêm học viên mới, ghi danh, lập phiếu thu) – chỉ chạy trên CSDL demo.
Dựng lại dữ liệu sau khi quay: RESET_DB=1 bash .devcontainer/start.sh (Codespace) hoặc database/run_all.sh (máy thật).
"""
import argparse
import math
import random
import re
import subprocess
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
W, H, ZOOM = 1920, 1080, 1.3            # khung quay Full HD; ZOOM phóng giao diện cho chữ đủ to khi chiếu
RA_W, RA_H = W, H                       # video xuất ra
ROW = 35                                # chiều cao dòng bảng dữ liệu của Streamlit (CSS px, chưa nhân ZOOM)

# Tài khoản mẫu của dự án (database/02_seed.sql) – cũng chính là danh sách hiện sẵn trên trang Đăng nhập
TK = {"GVU": ("giaovu", "Ecms@2026", "Giáo vụ"), "KT": ("ketoan", "Ecms@2026", "Kế toán"),
      "GV": ("giaovien", "Ecms@2026", "Giáo viên"), "HV": ("hocvien", "Hocvien@2026", "Học viên"),
      "QL": ("quanly", "Ecms@2026", "Quản lý trung tâm")}

# ============================================================================ PHỤ ĐỀ GIẢI THÍCH (hiện đủ lâu để đọc, ~13 chữ / giây)
LINES = {
    "intro": "Xin chào quý thầy cô và các bạn. Nhóm chúng em xin giới thiệu ECMS – hệ thống quản lý trung tâm tiếng Anh, đồ án môn Quản lý thông tin.",
    "login1": "ECMS là ứng dụng web, dữ liệu lưu trong SQL Server 2025. Trang đăng nhập có sẵn các tài khoản dùng thử cho năm vai trò.",
    "login2": "Mỗi vai trò chỉ nhìn thấy đúng những chức năng thuộc quyền của mình: quản lý trung tâm, giáo vụ, kế toán, giáo viên và học viên.",
    "login3": "Ta bắt đầu từ hành trình của một học viên mới, với tài khoản giáo vụ của chi nhánh CN01.",
    "gv1": "Menu bên trái được nhóm theo nghiệp vụ: Đào tạo, Học viên, Học tập, Tài chính, Báo cáo và Hệ thống – chỉ hiện những mục giáo vụ được phép dùng.",
    "gv2": "Trang chủ tóm tắt nhanh số lớp đang học, lớp sắp khai giảng, số học viên và công nợ của chi nhánh.",
    "gv3": "Phần Đào tạo quản lý khoá học, lớp học và lịch học. Mỗi chương trình gồm nhiều khoá theo cấp độ, khoá cấp sau có thể yêu cầu khoá tiên quyết.",
    "gv4": "Bây giờ giáo vụ tiếp nhận một học viên mới. Nếu bỏ trống hoặc nhập sai, hệ thống báo lỗi ngay tại từng ô.",
    "gv4b": "Nhập đủ thông tin đúng định dạng, hồ sơ được lưu và hệ thống cấp mã học viên mới.",
    "gv5": "Bước tiếp theo là kiểm tra đầu vào. Giáo vụ nhập điểm bốn kỹ năng, hệ thống lưu kết quả dạng XML và gợi ý khoá học phù hợp với điểm tổng.",
    "gv6": "Cuối cùng là ghi danh. Hệ thống đề xuất khoá theo kết quả kiểm tra, chỉ liệt kê lớp còn chỗ và tự kiểm tra lớp đầy, đăng ký trùng, điều kiện tiên quyết.",
    "gv6b": "Chọn lớp, đặt mức giảm giá nếu có ưu đãi, rồi bấm ghi danh. Sĩ số lớp tự cập nhật và khoản học phí chuyển sang công nợ.",
    "kt1": "Chuyển sang kế toán. Trang Công nợ liệt kê các đăng ký chưa đóng đủ; hạn đóng là mười bốn ngày sau ngày đăng ký, khoản quá hạn được tô màu.",
    "kt2": "Học viên vừa ghi danh đã có mặt ở đây. Sang trang Lập phiếu thu: tìm học viên, hệ thống hiện các khoản còn nợ để chọn thu.",
    "kt3": "Bấm lập phiếu thu. Hệ thống ghi phiếu, trigger tự cập nhật trạng thái học phí, và cho in phiếu thu dạng PDF.",
    "kt4": "Thẻ Tra cứu phiếu thu giúp xem lại mọi phiếu đã lập, kèm chi tiết từng khoản.",
    "gvi1": "Giáo viên chỉ thấy các lớp mình phụ trách. Ở trang Điểm danh, giáo viên chọn lớp và buổi học, đánh dấu có mặt, muộn, có phép hoặc vắng cho cả lớp rồi lưu một lần.",
    "gvi2": "Trang Nhập điểm nhận điểm giữa kỳ và cuối kỳ. Điểm trung bình, xếp loại và kết quả đạt hay không đạt do hệ thống tự tính.",
    "gvi3": "Cảnh báo chuyên cần liệt kê những học viên vắng quá ngưỡng để kịp thời nhắc nhở.",
    "hv1": "Học viên đăng nhập chỉ xem được dữ liệu của chính mình: lịch học theo tuần, bảng điểm và tình hình học phí.",
    "ql1": "Cuối cùng là quản lý trung tâm, với phạm vi toàn trung tâm. Dashboard tổng hợp học viên mới, doanh thu, tỷ lệ lấp đầy lớp, chuyên cần và công nợ, kèm biểu đồ theo tháng.",
    "ql2": "Trang Báo cáo và xuất file cho phép chọn báo cáo, xem trước và tải về dạng PDF, Excel hoặc Word.",
    "ql3": "Mọi thay đổi về đăng ký, phiếu thu, tài khoản, hồ sơ học viên đều được trigger ghi vào nhật ký; nhật ký chỉ thêm, không sửa hay xoá.",
    "ql3b": "Ở đây ta thấy lại các thao tác vừa rồi của giáo vụ và kế toán, kèm tên tài khoản thực hiện và dữ liệu trước, sau khi thay đổi.",
    "outro": "Tóm lại, ECMS đáp ứng trọn vòng đời của một học viên: tiếp nhận, ghi danh, thu học phí, học tập và báo cáo quản lý. Xin cảm ơn quý thầy cô và các bạn đã theo dõi.",
}


# ============================================================================ LỚP PHỦ TRÊN TRANG: con trỏ, phụ đề, nhãn, thẻ tiêu đề
OVERLAY_JS = r"""
(() => {
  if (window.__demo) return;
  const Z = %ZOOM%;
  const css = `
  html { zoom: ${Z}; }
  #__ov { position: fixed; left: 0; top: 0; width: %W%px; height: %H%px; zoom: ${1 / Z}; pointer-events: none;
          z-index: 2147483647; font-family: "Source Sans 3", "Segoe UI", "Helvetica Neue", Arial, sans-serif; }
  #__cur { position: absolute; left: -4px; top: -3px; width: 34px; height: 34px; transform: translate(-200px,-200px); }
  #__cur svg { filter: drop-shadow(0 2px 3px rgba(0,0,0,.5)); }
  .__rip { position: absolute; width: 18px; height: 18px; margin: -9px 0 0 -9px; border-radius: 50%;
           border: 4px solid #ff4b4b; animation: __rip .6s ease-out forwards; }
  @keyframes __rip { to { transform: scale(3.4); opacity: 0; } }
  #__cap { position: absolute; left: 50%; bottom: 40px; transform: translate(-50%, 16px); max-width: 1500px; padding: 16px 32px;
           background: rgba(15,23,42,.9); color: #fff; font-size: 29px; line-height: 1.42; font-weight: 500; text-align: center;
           border-radius: 16px; opacity: 0; transition: opacity .35s, transform .35s; box-shadow: 0 10px 34px rgba(0,0,0,.35); }
  #__cap.on { opacity: 1; transform: translate(-50%, 0); }
  #__cap.top { bottom: auto; top: 30px; }
  #__badge { position: absolute; left: 22px; top: 22px; padding: 7px 16px; border-radius: 999px;
             background: #ff4b4b; color: #fff; font-size: 19px; font-weight: 700; letter-spacing: .2px; opacity: 0;
             transition: opacity .4s; box-shadow: 0 4px 16px rgba(255,75,75,.4); white-space: nowrap; }
  #__badge.on { opacity: 1; }
  #__spot { position: absolute; border: 4px solid #ff4b4b; border-radius: 12px; opacity: 0; transition: opacity .3s;
            box-shadow: 0 0 0 9999px rgba(15,23,42,.12); }
  #__spot.on { opacity: 1; }
  #__card { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; text-align: center;
            background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 55%, #2563eb 100%); color: #fff; opacity: 0;
            transition: opacity .7s; }
  #__card.on { opacity: 1; }
  #__card .in { max-width: 1400px; }
  #__card h1 { font-size: 128px; margin: 0 0 8px; letter-spacing: 6px; font-weight: 800; }
  #__card h2 { font-size: 50px; margin: 0 0 30px; font-weight: 600; }
  #__card p { font-size: 30px; margin: 8px 0; opacity: .85; }
  #__card ul { list-style: none; padding: 0; margin: 28px 0 0; font-size: 34px; line-height: 1.9; text-align: left; display: inline-block; }
  #__card li::before { content: "✔  "; color: #7dd3fc; }
  `;
  const build = () => {
    const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
    const ov = document.createElement('div'); ov.id = '__ov';
    ov.innerHTML = '<div id="__spot"></div><div id="__badge"></div><div id="__cap"></div>'
      + '<div id="__card"><div class="in"></div></div>'
      + '<div id="__cur"><svg width="34" height="34" viewBox="0 0 24 24"><path d="M3 2l7 19 2.6-7.4L20 11z" fill="#fff" '
      + 'stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg></div>';
    document.body.appendChild(ov);
    const cur = ov.querySelector('#__cur');
    window.addEventListener('mousemove', e => { cur.style.transform = `translate(${e.clientX}px,${e.clientY}px)`; }, true);
    window.addEventListener('mousedown', e => {
      const r = document.createElement('div'); r.className = '__rip'; r.style.left = e.clientX + 'px'; r.style.top = e.clientY + 'px';
      ov.appendChild(r); setTimeout(() => r.remove(), 700);
    }, true);
    const $ = id => ov.querySelector(id);
    window.__demo = {
      cap(t, top) { const c = $('#__cap'); if (t) c.textContent = t; c.classList.toggle('top', !!top); c.classList.toggle('on', !!t); },
      badge(t) { const b = $('#__badge'); if (t) b.textContent = t; b.classList.toggle('on', !!t); },
      card(h) { const c = $('#__card'); if (h) c.querySelector('.in').innerHTML = h; c.classList.toggle('on', !!h); },
      spot(r) {
        const s = $('#__spot');
        if (!r) { s.classList.remove('on'); return; }
        Object.assign(s.style, {left: (r.x - 10) + 'px', top: (r.y - 8) + 'px', width: (r.width + 20) + 'px', height: (r.height + 16) + 'px'});
        s.classList.add('on');
      },
    };
  };
  if (document.body) build(); else document.addEventListener('DOMContentLoaded', build);
})();
""".replace("%ZOOM%", str(ZOOM)).replace("%W%", str(W)).replace("%H%", str(H))

SAN_SANG = """() => {
  const a = document.querySelector('[data-testid="stApp"]');
  return !!a && a.getAttribute('data-test-script-state') === 'notRunning'
      && !document.querySelector('[data-stale="true"]') && !document.querySelector('[data-testid="stSpinner"]');
}"""


# ============================================================================ NGƯỜI THAO TÁC
class Demo:
    def __init__(self, page, base: str):
        self.page, self.base = page, base
        self.t0 = time.time()                     # video bắt đầu ghi khi trang được tạo
        self.mx, self.my = W / 2, H / 2
        self.clips: list[tuple[float, float, str]] = []      # (giây bắt đầu, thời lượng, phụ đề) – để ghi tệp .srt
        self.n_end = 0.0
        self.role: str | None = None
        self.ma_hv: str | None = None
        self.sau_ghi_danh = None

    # ----- thời gian, chờ Streamlit
    def settle(self, toi_thieu: float = 0.5, timeout: int = 45_000) -> None:
        time.sleep(toi_thieu)
        self.page.wait_for_function(SAN_SANG, timeout=timeout)
        if self.page.locator(".js-plotly-plot").count():
            self.page.wait_for_function("() => [...document.querySelectorAll('.js-plotly-plot')].every(p => p.querySelector('.main-svg'))",
                                        timeout=timeout)
            time.sleep(1.0)
        time.sleep(0.35)

    def pause(self, s: float) -> None:
        time.sleep(s)

    # ----- phụ đề
    def say(self, key: str, top: bool = False) -> None:
        """Hiện phụ đề `key` (không chặn); thời gian hiện tính theo độ dài chữ để người xem đọc kịp."""
        text = LINES[key]
        dur = max(4.0, len(text) / 13.0 + 1.0)
        self.clips.append((time.time() - self.t0, dur, text))
        self.page.evaluate("([t, top]) => window.__demo.cap(t, top)", [text, top])
        self.n_end = time.time() + dur

    def hold(self, them: float = 0.5) -> None:
        """Chờ phụ đề hiện đủ thời gian rồi ẩn."""
        con = self.n_end - time.time()
        if con > 0:
            time.sleep(con)
        time.sleep(them)
        self.page.evaluate("() => window.__demo.cap(null)")
        time.sleep(0.4)

    def card(self, html: str | None) -> None:
        self.page.evaluate("h => window.__demo.card(h)", html)
        time.sleep(0.9)

    def badge(self, text: str | None) -> None:
        self.page.evaluate("t => window.__demo.badge(t)", text)

    def spot(self, loc) -> None:
        loc.scroll_into_view_if_needed()
        self.page.evaluate("r => window.__demo.spot(r)", self.box(loc))

    def unspot(self) -> None:
        self.page.evaluate("() => window.__demo.spot(null)")

    # ----- chuột
    def glide(self, x: float, y: float, dur: float | None = None) -> None:
        x0, y0 = self.mx, self.my
        d = math.hypot(x - x0, y - y0)
        dur = dur or min(1.0, 0.28 + d / 1900)
        n = max(10, int(dur * 50))
        for i in range(1, n + 1):
            t = i / n
            e = t * t * (3 - 2 * t)
            self.page.mouse.move(x0 + (x - x0) * e, y0 + (y - y0) * e)
            time.sleep(dur / n)
        self.mx, self.my = x, y

    def box(self, loc) -> dict:
        """Khung của phần tử sau khi đã đứng yên (trang còn cuộn mượt / còn dựng lại thì chờ)."""
        loc.wait_for(state="visible", timeout=20_000)
        truoc = None
        for _ in range(40):
            b = loc.bounding_box()
            if b and truoc and all(abs(b[k] - truoc[k]) < 0.6 for k in ("x", "y", "width", "height")):
                return b
            truoc = b
            time.sleep(0.12)
        return loc.bounding_box()

    def centre(self, loc, dx: float = 0.5, dy: float = 0.5) -> tuple[float, float]:
        b = self.box(loc)
        return b["x"] + b["width"] * dx, b["y"] + b["height"] * dy

    def hover(self, loc, dx: float = 0.5, dy: float = 0.5, tre: float = 0.3) -> None:
        x, y = self.centre(loc, dx, dy)
        self.glide(x, y)
        time.sleep(tre)

    def click(self, loc, dx: float = 0.5, dy: float = 0.5, cho: bool = True, tre: float = 0.18) -> None:
        loc.scroll_into_view_if_needed()
        x, y = self.centre(loc, dx, dy)
        self.glide(x, y)
        time.sleep(tre)
        self.page.mouse.click(x, y)
        if cho:
            self.settle(0.4)

    def focus(self, loc, dx: float = 0.3) -> None:
        """Đưa chuột tới ô và bảo đảm ô có focus. Ô đã có focus (do Tab từ ô trước) thì không bấm lại – bấm lần nữa làm mất focus."""
        loc.wait_for(state="visible", timeout=20_000)
        if loc.evaluate("e => document.activeElement === e"):
            self.hover(loc, dx, 0.5, 0.2)
        else:
            self.click(loc, dx=dx, cho=False)

    def go(self, loc, text: str, enter: bool = True, delay: int = 70, xoa: bool = False) -> None:
        """Bấm vào ô rồi gõ từng phím. enter=True: Enter để Streamlit nhận giá trị (ô ngoài form); False: Tab (ô trong form
        – Enter sẽ gửi cả form)."""
        self.focus(loc)
        if xoa:
            self.page.keyboard.press("ControlOrMeta+a")
        self.page.keyboard.type(text, delay=delay)
        self.page.keyboard.press("Enter" if enter else "Tab")
        self.settle(0.5)

    def scroll(self, dy: int, dur: float = 1.4) -> None:
        """Cuộn vùng nội dung chính từ từ (con trỏ nằm trên vùng nội dung để bánh xe cuộn đúng khung)."""
        if self.mx < 560:
            self.glide(1250, 620, 0.5)
        n = max(6, int(dur * 40))
        for _ in range(n):
            self.page.mouse.wheel(0, dy / n)
            time.sleep(dur / n)
        time.sleep(0.8)                          # cuộn mượt của trình duyệt còn chạy thêm sau cú lăn cuối

    def cuon_toi(self, loc, vi_tri: float = 0.3, dur: float = 1.2) -> None:
        """Cuộn từ từ tới khi phần tử nằm ở khoảng `vi_tri` chiều cao màn hình."""
        b = self.box(loc)
        if b:
            self.scroll(int(b["y"] - H * vi_tri), dur)

    def len_dau_trang(self) -> None:
        self.page.evaluate("() => document.querySelector('[data-testid=\"stMain\"]')?.scrollTo({top: 0, behavior: 'smooth'})")
        time.sleep(0.9)

    # ----- Streamlit
    def menu(self, tieu_de: str) -> None:
        lk = self.page.locator('[data-testid="stSidebarNavLink"]').filter(has=self.page.get_by_text(tieu_de, exact=True)).first
        self.click(lk, dx=0.4, cho=False)
        self.settle(0.8)

    def dong_bang(self, dong: int = 0, bang: int = 0) -> None:
        """Bấm chọn dòng `dong` của bảng thứ `bang` (lưới vẽ bằng canvas nên bấm theo toạ độ; ZOOM nhân vào kích thước dòng)."""
        df = self.page.locator('[data-testid="stDataFrame"]').nth(bang)
        df.scroll_into_view_if_needed()
        b = self.box(df)
        x, y = b["x"] + 18 * ZOOM, b["y"] + (ROW + ROW * dong + ROW / 2) * ZOOM
        self.glide(x, y)
        time.sleep(0.2)
        self.page.mouse.click(x, y)
        self.settle(0.8)

    def chon_trong_hop(self, nhan: str, mau: str) -> None:
        sb = self.page.locator('[data-testid="stSelectbox"]').filter(has=self.page.get_by_text(nhan, exact=True)).first
        self.click(sb, cho=False)
        time.sleep(0.6)
        self.click(self.page.get_by_role("option", name=re.compile(mau)).first)

    # ----- đăng nhập / đăng xuất
    def login_as(self, ma: str, gioi_thieu=None) -> None:
        if self.role == ma:
            return
        ten, mk, nhan = TK[ma]
        p = self.page
        if self.role:
            self.badge(None)
            self.click(p.get_by_role("button", name=re.compile("Đăng xuất")))
            self.settle(1.0)
        else:
            p.goto(self.base)
            self.settle(1.0)
        if gioi_thieu:
            gioi_thieu()
        self.go(p.get_by_label("Tên đăng nhập"), ten, enter=False, delay=90)
        self.go(p.get_by_label("Mật khẩu"), mk, enter=False, delay=90)
        self.click(p.get_by_role("button", name=re.compile("Đăng nhập")), cho=False)
        p.wait_for_selector('[data-testid="stSidebarNav"]', timeout=45_000)
        self.settle(1.2)
        self.role = ma
        self.badge(f"Vai trò: {nhan}")
        time.sleep(0.6)


# ============================================================================ CÁC CẢNH
def canh_mo_dau(d: Demo) -> None:
    d.page.goto(d.base)
    d.settle(1.0)
    d.card("<h1>ECMS</h1><h2>Hệ thống quản lý trung tâm tiếng Anh</h2><p>Đồ án môn IE103 – Quản lý thông tin</p>"
           "<p>Ứng dụng web Streamlit · SQL Server 2025</p>")
    d.say("intro")
    d.hold(0.8)
    d.card(None)
    time.sleep(0.6)


def canh_dang_nhap(d: Demo) -> None:
    def gioi_thieu():
        d.say("login1", top=True)
        mo = d.page.get_by_text("Tài khoản demo", exact=False).first
        d.click(mo, cho=False)
        time.sleep(0.8)
        d.hold(0.3)
        d.say("login2", top=True)
        d.glide(d.mx + 10, d.my + 130, 1.0)          # lướt qua bảng tài khoản
        d.glide(d.mx + 10, d.my + 130 + 90, 1.0)
        d.hold(0.3)
        d.say("login3", top=True)

    d.login_as("GVU", gioi_thieu)
    d.hold(0.2)


def canh_giao_vu(d: Demo) -> None:
    p = d.page
    d.login_as("GVU")
    d.say("gv1")
    for t in ("Chương trình & khoá học", "Hồ sơ học viên", "Ghi danh", "Cảnh báo chuyên cần", "Công nợ", "Báo cáo & xuất file"):
        d.hover(p.locator('[data-testid="stSidebarNavLink"]').filter(has=p.get_by_text(t, exact=True)).first, 0.4, 0.5, 0.9)
    d.hold(0.3)
    d.say("gv2")
    d.hover(p.locator('[data-testid="stMetric"]').first, 0.5, 0.5, 0.8)
    d.scroll(450, 1.6)
    d.hold(0.3)
    d.len_dau_trang()

    d.say("gv3")
    d.menu("Chương trình & khoá học")
    d.pause(2.0)
    d.click(p.get_by_role("tab", name="Chương trình"))
    d.pause(1.2)
    d.menu("Lớp học")
    d.pause(2.2)
    d.menu("Xếp lịch & buổi học")
    d.pause(2.0)
    d.hold(0.3)

    # ---- hồ sơ học viên mới (có lỗi nhập liệu cố ý rồi sửa)
    d.say("gv4")
    d.menu("Hồ sơ học viên")
    d.pause(1.0)
    d.cuon_toi(p.get_by_role("heading", name="Thêm học viên mới"), 0.18, 1.6)
    sdt = "09" + "".join(random.choice("0123456789") for _ in range(8))
    d.click(p.get_by_role("button", name=re.compile("Lưu hồ sơ")))            # bấm lưu khi form còn trống → báo lỗi từng ô
    d.pause(2.6)
    d.hold(0.2)
    d.say("gv4b")
    d.go(p.get_by_label("Họ và tên lót *", exact=True), "Nguyễn Minh", enter=False)
    d.go(p.get_by_label("Tên *", exact=True), "Khang", enter=False)
    d.go(p.get_by_label("Điện thoại *", exact=True), sdt, enter=False)
    d.go(p.get_by_label("Email", exact=True), "khang.nguyen@example.com", enter=False)
    d.go(p.get_by_label("Số nhà, đường", exact=True), "12 Võ Văn Ngân", enter=False)
    d.click(p.get_by_role("button", name=re.compile("Lưu hồ sơ")))
    m = re.search(r"HV\d+", p.get_by_text(re.compile(r"Đã lưu hồ sơ HV\d+")).first.inner_text(timeout=20_000))
    d.ma_hv = m.group(0)
    print(f"  → học viên mới {d.ma_hv} (SĐT {sdt})")
    d.len_dau_trang()
    d.pause(1.2)
    d.hold(0.2)


def canh_ghi_danh(d: Demo) -> None:
    p = d.page
    d.login_as("GVU")
    ma = d.ma_hv
    d.say("gv5")
    d.menu("Kiểm tra đầu vào")
    d.go(p.get_by_label("Tìm học viên (tên, SĐT hoặc mã)", exact=True).filter(visible=True).first, ma)
    d.pause(0.6)
    for kn, v in (("Listening", "7"), ("Reading", "7.5"), ("Writing", "6.5"), ("Speaking", "7")):
        o = p.get_by_label(kn, exact=True)
        d.focus(o)
        p.keyboard.press("ControlOrMeta+a")
        p.keyboard.type(v, delay=120)
        p.keyboard.press("Tab")
        d.pause(0.3)
    d.go(p.get_by_label("Nhận xét Speaking", exact=True), "Phát âm khá, cần luyện thêm phản xạ", enter=False, delay=45)
    d.hold(0.2)
    d.click(p.get_by_role("button", name=re.compile("Lưu kết quả")))
    p.get_by_text(re.compile("Gợi ý khoá học cho điểm")).first.wait_for(timeout=20_000)
    d.len_dau_trang()
    d.pause(1.5)
    d.cuon_toi(p.get_by_text(re.compile("Gợi ý khoá học cho điểm")).first, 0.25, 1.4)
    d.pause(2.5)

    d.say("gv6")
    d.menu("Ghi danh")
    d.go(p.get_by_label("Tìm học viên (tên, SĐT hoặc mã)", exact=True), ma)
    d.pause(1.0)
    d.cuon_toi(p.get_by_role("heading", name="Ghi danh lớp mới"), 0.12, 1.4)
    d.dong_bang(0, bang=1)
    d.hold(0.2)
    d.say("gv6b")
    th = p.get_by_role("slider").first
    d.hover(th)
    th.focus()
    p.keyboard.press("ArrowRight")
    d.pause(0.5)
    p.keyboard.press("ArrowRight")
    d.settle(0.8)
    d.click(p.get_by_role("button", name=re.compile("Ghi danh vào")))
    p.get_by_text(re.compile("Đã ghi danh vào lớp")).first.wait_for(timeout=20_000)
    d.len_dau_trang()
    d.pause(2.0)
    d.hold(0.2)


def canh_ke_toan(d: Demo) -> None:
    p = d.page
    d.login_as("KT")
    ma = d.ma_hv
    d.say("kt1")
    d.menu("Công nợ")
    d.pause(1.0)
    d.go(p.get_by_label("Tìm học viên / lớp", exact=True), ma)
    d.pause(1.5)
    d.hold(0.2)

    d.say("kt2")
    d.menu("Lập phiếu thu")
    d.go(p.get_by_label("Tìm học viên (tên, SĐT hoặc mã)", exact=True), ma)
    d.pause(1.0)
    d.cuon_toi(p.get_by_text("2. Chi tiết", exact=False).first, 0.2, 1.2)
    d.pause(1.5)
    d.hold(0.2)

    d.say("kt3")
    d.click(p.get_by_role("button", name=re.compile("Lập phiếu thu")).first)
    p.get_by_text(re.compile(r"Đã lập phiếu thu PT\d+")).first.wait_for(timeout=20_000)
    d.len_dau_trang()
    d.pause(1.2)
    d.click(p.get_by_role("button", name=re.compile("In phiếu")).first, cho=False)
    d.pause(2.5)
    d.hold(0.2)

    d.say("kt4")
    d.click(p.get_by_role("tab", name="Tra cứu phiếu thu"))
    d.pause(1.2)
    d.dong_bang(0)
    d.pause(1.5)
    d.cuon_toi(p.get_by_text(re.compile("Chi tiết phiếu")).first, 0.25, 1.2)
    d.pause(1.5)
    d.hold(0.2)


def canh_giao_vien(d: Demo) -> None:
    p = d.page
    d.login_as("GV")
    d.say("gvi1")
    d.menu("Điểm danh")
    d.pause(1.5)
    sb = p.locator('[data-testid="stSelectbox"]').filter(has=p.get_by_text("Buổi học", exact=True)).first
    d.click(sb, cho=False)                                   # mở danh sách buổi học cho người xem thấy
    d.pause(2.2)
    p.keyboard.press("Escape")
    d.settle(0.5)
    d.scroll(300, 1.2)
    d.hold(0.3)
    d.len_dau_trang()
    d.say("gvi2")
    d.menu("Nhập điểm")
    d.pause(2.0)
    d.scroll(250, 1.2)
    d.hold(0.3)
    d.len_dau_trang()
    d.say("gvi3")
    d.menu("Cảnh báo chuyên cần")
    d.pause(2.0)
    d.hold(0.3)


def canh_hoc_vien(d: Demo) -> None:
    p = d.page
    d.login_as("HV")
    d.say("hv1")
    d.menu("Lịch học & kết quả của tôi")
    d.pause(2.5)
    d.click(p.get_by_role("tab", name="Bảng điểm"))
    d.pause(2.5)
    d.click(p.get_by_role("tab", name="Học phí"))
    d.pause(2.5)
    d.hold(0.3)


def canh_quan_ly(d: Demo) -> None:
    p = d.page
    d.login_as("QL")
    d.say("ql1")
    d.menu("Dashboard")
    d.pause(1.5)
    d.scroll(520, 2.0)
    d.pause(1.2)
    d.scroll(560, 2.0)
    d.pause(1.2)
    d.scroll(560, 2.0)
    d.hold(0.3)
    d.len_dau_trang()

    d.say("ql2")
    d.menu("Báo cáo & xuất file")
    d.pause(1.5)
    d.chon_trong_hop("Báo cáo", "Doanh thu")
    d.pause(1.5)
    d.scroll(350, 1.2)
    d.hold(0.3)
    d.len_dau_trang()

    d.say("ql3")
    d.menu("Nhật ký hệ thống")
    d.pause(2.0)
    d.dong_bang(1)          # dòng UPDATE đăng ký (học phí đổi trạng thái): có đủ dữ liệu trước / sau. Dòng INSERT làm trang lỗi (xem ghi chú)
    d.hold(0.2)
    d.say("ql3b")
    d.cuon_toi(p.get_by_role("heading").filter(has_text=re.compile(r"^(INSERT|UPDATE|DELETE)")).first, 0.3, 1.4)
    d.pause(2.0)
    d.hold(0.3)


def canh_ket(d: Demo) -> None:
    d.badge(None)
    d.card("<h2>ECMS – Quản lý trung tâm tiếng Anh</h2>"
           "<ul><li>5 vai trò, phân quyền theo chức năng</li>"
           "<li>Trọn vòng đời học viên: hồ sơ → kiểm tra → ghi danh → học phí → học tập</li>"
           "<li>SQL Server 2025: thủ tục lưu trữ, trigger, XML, nhật ký kiểm toán</li>"
           "<li>Báo cáo, dashboard và xuất PDF / Excel / Word</li></ul>")
    d.say("outro")
    d.hold(1.0)
    time.sleep(2.0)


SCENES = {"modau": canh_mo_dau, "dangnhap": canh_dang_nhap, "giaovu": canh_giao_vu, "ghidanh": canh_ghi_danh,
          "ketoan": canh_ke_toan, "giaovien": canh_giao_vien, "hocvien": canh_hoc_vien, "quanly": canh_quan_ly, "ket": canh_ket}


# ============================================================================ GHÉP VIDEO
def srt_time(s: float) -> str:
    ms = int(round(s * 1000))
    return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"


def ghep(raw: Path, clips, ra: Path, tre_hinh: float) -> None:
    """Đổi video thô (VP8) sang MP4 H.264 chất lượng cao, ghi phụ đề rời .srt."""
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(raw), "-vf", f"scale={RA_W}:{RA_H}:flags=lanczos", "-c:v", "libx264", "-preset", "slow", "-crf", "17",
                    "-pix_fmt", "yuv420p", "-an", "-movflags", "+faststart", str(ra)], check=True)
    srt = [f"{i}\n{srt_time(off + tre_hinh)} --> {srt_time(off + tre_hinh + dur)}\n{text}\n"
           for i, (off, dur, text) in enumerate(clips, 1)]
    ra.with_suffix(".vi.srt").write_text("\n".join(srt), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base-url", default="http://localhost:8501")
    ap.add_argument("--scenes", default="modau,dangnhap,giaovu,ghidanh,ketoan,giaovien,hocvien,quanly,ket",
                    help="các cảnh cần quay, cách nhau bằng dấu phẩy: " + ",".join(SCENES))
    ap.add_argument("--ma-hv", help="mã học viên đã có (khi quay riêng các cảnh sau 'giaovu')")
    ap.add_argument("--khong-ghep", action="store_true", help="chỉ quay video thô (webm)")
    ap.add_argument("--tre-hinh", type=float, default=0.0, help="độ trễ (giây) video thô so với đồng hồ script; chỉnh nếu tiếng lệch hình")
    ap.add_argument("--ten", default="ECMS_demo")
    a = ap.parse_args()
    ds = [s.strip() for s in a.scenes.split(",") if s.strip()]
    if sai := [s for s in ds if s not in SCENES]:
        ap.error(f"không có cảnh {sai}; chọn trong {list(SCENES)}")

    OUT.mkdir(exist_ok=True)
    for f in OUT.glob("raw_*.webm"):
        f.unlink()

    with sync_playwright() as pw:
        # Edge ngầm vẫn dựng cửa sổ thật: vùng hình = cửa sổ trừ 8 × 84 px viền. Đặt cửa sổ lớn hơn đúng phần đó để vùng hình
        # (và video) vừa khít W × H; không giả lập viewport vì khung quay chỉ chụp vùng hình thật, phần dư bị cắt thành dải xám
        br = pw.chromium.launch(channel="msedge", args=["--hide-scrollbars", f"--window-size={W + 8},{H + 84}"])
        ctx = br.new_context(no_viewport=True, record_video_dir=str(OUT),
                             record_video_size={"width": W, "height": H}, locale="vi-VN", timezone_id="Asia/Ho_Chi_Minh",
                             accept_downloads=True)
        ctx.add_init_script(OVERLAY_JS)
        page = ctx.new_page()
        d = Demo(page, a.base_url.rstrip("/"))
        d.ma_hv = a.ma_hv
        loi = []
        try:
            for s in ds:
                print(f"▶ Cảnh {s}")
                try:
                    SCENES[s](d)
                except Exception as e:                                   # noqa: BLE001 – ghi lỗi, chụp màn hình, quay tiếp
                    loi.append(f"{s}: {str(e).splitlines()[0]}")
                    print(f"  ✗ {loi[-1]}")
                    page.screenshot(path=str(OUT / f"loi_{s}.png"))
                    page.evaluate("() => window.__demo && window.__demo.cap(null)")
        finally:
            video = page.video.path()
            ctx.close()
            br.close()
    raw = OUT / f"raw_{a.ten}.webm"
    Path(video).rename(raw)
    print(f"✓ Video thô: {raw}")
    if loi:
        print("✗ Lỗi:\n  " + "\n  ".join(loi))
    if not a.khong_ghep:
        ra = OUT / f"{a.ten}.mp4"
        ghep(raw, d.clips, ra, a.tre_hinh)
        print(f"✓ Video hoàn chỉnh: {ra}\n✓ Phụ đề: {ra.with_suffix('.vi.srt')}")
    if loi:
        sys.exit(1)


if __name__ == "__main__":
    main()
