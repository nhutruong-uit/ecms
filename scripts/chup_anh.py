"""Chụp lại ảnh màn hình ECMS cho báo cáo (Chương 4) và hướng dẫn sử dụng – tự động bằng Playwright (T30).

Mỗi ảnh được chụp bằng ĐÚNG tài khoản của vai trò mà mục đó mô tả (giáo vụ cho phân hệ Đào tạo / Học viên, giáo viên
cho Học tập, kế toán cho Tài chính…), trên CSDL vừa dựng từ dữ liệu mẫu, khung nhìn 1280 px × hệ số điểm ảnh 2.
Ảnh vùng nội dung rộng khoảng 1.700 px, ảnh cả cửa sổ (thấy menu) 2.000 px – chữ trên giao diện khi in khổ 15 cm
khoảng 7 pt; khung nhìn được kéo dài vừa khít nội dung nên trang dài không bị cắt. Chuột đưa ra khỏi vùng nội dung,
ô đang focus được bỏ focus, chờ Streamlit chạy xong và bảng / biểu đồ vẽ xong rồi mới chụp. Hai ảnh PDF (phiếu
thu, báo cáo doanh thu) được tải về từ chính nút "In phiếu" / "Tải PDF" của ứng dụng rồi kết xuất trang đầu thành ảnh.

Cài đặt một lần (Windows PowerShell, macOS, Linux – trong môi trường ảo của ứng dụng):

    pip install playwright pypdfium2
    python -m playwright install chromium

Chạy (từ thư mục gốc repo, CSDL đã dựng bằng database/run_all.ps1 hoặc run_all.sh, .env trỏ tới CSDL đó):

    python scripts/chup_anh.py                       # tự khởi động Streamlit ở cổng trống, chụp toàn bộ, ghi đè ảnh trong repo
    python scripts/chup_anh.py --ghi                 # thêm 2 ảnh cần ghi CSDL: quét cảnh báo chuyên cần, nhật ký hệ thống
    python scripts/chup_anh.py --only 10_ghi_danh 14_phieu_thu --out-dir tmp_anh
    python scripts/chup_anh.py --base-url http://localhost:8501   # dùng ứng dụng đang chạy sẵn

--ghi chỉ dùng trên CSDL vừa dựng: bấm "Quét cảnh báo hôm nay" (thêm dòng CANHBAO_CHUYENCAN) và đặt lại mật khẩu
tài khoản `hocvien` thành chính mật khẩu mẫu (để nhật ký hệ thống có một dòng TAIKHOAN). Không ảnh nào ghi đăng ký,
phiếu thu hay điểm, nên số liệu trong báo cáo (công nợ, doanh thu, sĩ số) vẫn khớp với ảnh.

Không có Chromium của Playwright thì script thử Microsoft Edge rồi Google Chrome đã cài trên máy (--trinh-duyet).
"""
import argparse
import io
import os
import re
import socket
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
CH4 = ROOT / "report" / "images" / "ch4"
HDSD = ROOT / "docs" / "user-guide" / "images"

# tài khoản mẫu (database/02_seed.sql, scripts/gen_seed.py) – chỉ có trong môi trường thử nghiệm
TAI_KHOAN = {"QL": ("quanly", "Ecms@2026"), "GVU": ("giaovu", "Ecms@2026"), "KT": ("ketoan", "Ecms@2026"),
             "GV": ("giaovien", "Ecms@2026"), "HV": ("hocvien", "Hocvien@2026")}
RONG, CAO, CAO_TOI_DA = 1280, 800, 2600          # khung nhìn (CSS px); trang dài hơn được mở rộng khung nhìn tới CAO_TOI_DA
ANH_TOI_DA = 2000                                # chiều rộng ảnh lưu (px)

SAN_SANG = """() => {
  const a = document.querySelector('[data-testid="stApp"]');
  return !!a && a.getAttribute('data-test-script-state') === 'notRunning'
      && !document.querySelector('[data-stale="true"]') && !document.querySelector('[data-testid="stSpinner"]');
}"""
CHIEU_CAO = """() => {
  const m = document.querySelector('[data-testid="stMain"]');
  if (m) m.scrollTo(0, 0);
  const day = sel => { const e = document.querySelector(sel); return e ? e.getBoundingClientRect().bottom : 0; };
  // đáy nội dung thật (không tính khoảng đệm dưới của Streamlit), đáy menu và hộp thoại đang mở (popover)
  const pop = [...document.querySelectorAll('[data-baseweb="popover"]')].map(e => e.getBoundingClientRect().bottom);
  return Math.ceil(Math.max(day('[data-testid="stMainBlockContainer"] [data-testid="stVerticalBlock"]'),
                            day('[data-testid="stSidebarUserContent"]'), ...pop) + 48);
}"""
VUNG_NOI_DUNG = """() => {
  const r = document.querySelector('[data-testid="stMainBlockContainer"]').getBoundingClientRect();
  let x0 = r.left, y0 = r.top, x1 = r.right, y1 = r.bottom;
  for (const e of document.querySelectorAll('[data-baseweb="popover"]')) {      // hộp xác nhận xoá nằm ngoài khối nội dung
    const b = e.getBoundingClientRect();
    x0 = Math.min(x0, b.left); y0 = Math.min(y0, b.top); x1 = Math.max(x1, b.right); y1 = Math.max(y1, b.bottom + 16);
  }
  return {x: x0, y: y0, width: x1 - x0, height: y1 - y0};
}"""


# ============================================================================= thao tác trên giao diện Streamlit
def cho(page, toi_thieu: float = 0.4, timeout: int = 45_000) -> None:
    """Chờ lượt chạy script hiện tại xong (không còn phần tử 'stale', không còn spinner) rồi chờ thêm cho canvas vẽ."""
    time.sleep(toi_thieu)
    page.wait_for_function(SAN_SANG, timeout=timeout)
    if page.locator(".js-plotly-plot").count():
        page.wait_for_function("() => [...document.querySelectorAll('.js-plotly-plot')].every(p => p.querySelector('.main-svg'))",
                               timeout=timeout)
        time.sleep(1.2)
    time.sleep(0.4)


def dang_nhap(page, base: str, ma: str) -> None:
    ten, mk = TAI_KHOAN[ma]
    page.goto(base)
    cho(page)
    page.get_by_label("Tên đăng nhập").fill(ten)
    page.get_by_label("Mật khẩu").fill(mk)
    page.get_by_role("button", name="Đăng nhập").click()
    page.wait_for_selector('[data-testid="stSidebarNav"]', timeout=45_000)
    cho(page)


def _lien_ket(page, tieu_de: str):
    return page.locator('[data-testid="stSidebarNavLink"]').filter(has=page.get_by_text(tieu_de, exact=True)).first


def mo_trang(page, tieu_de: str) -> None:
    """Đi tới trang qua menu bên trái (điều hướng trong ứng dụng – giữ phiên đăng nhập). Trang đang mở thì đi qua
    Trang chủ rồi quay lại để mọi ô nhập, dòng đã chọn của lần chụp trước được xoá – form luôn ở trạng thái ban đầu."""
    lk = _lien_ket(page, tieu_de)
    if page.url.rstrip("/") == (lk.get_attribute("href") or "").rstrip("/"):
        _lien_ket(page, "Trang chủ").click()
        cho(page, 0.6)
    lk.click()
    cho(page, 0.8)


def go(page, nhan: str, gia_tri: str) -> None:
    """Gõ vào ô nhập có nhãn `nhan` rồi Enter (Streamlit nhận giá trị khi Enter)."""
    o = page.get_by_label(nhan, exact=True).filter(visible=True).first      # trang có thẻ: ô cùng tên ở thẻ ẩn
    o.fill(gia_tri)
    o.press("Enter")
    cho(page, 0.6)


def chon(page, nhan: str, mau: str) -> None:
    """Chọn mục khớp biểu thức `mau` trong hộp chọn có nhãn `nhan`."""
    page.locator('[data-testid="stSelectbox"]').filter(has=page.get_by_text(nhan, exact=True)).first.click()
    time.sleep(0.3)
    page.get_by_role("option", name=re.compile(mau)).first.click()
    cho(page, 0.6)


def chon_dong(page, dong: int = 0, bang: int = 0) -> None:
    """Chọn dòng thứ `dong` của bảng dữ liệu thứ `bang` trên trang (bấm ô chọn ở đầu dòng của lưới)."""
    df = page.locator('[data-testid="stDataFrame"]').nth(bang)
    df.scroll_into_view_if_needed()
    box = df.bounding_box()
    page.mouse.click(box["x"] + 18, box["y"] + 35 + 35 * dong + 17)
    cho(page, 0.8)


def bam(page, ten: str, vai: str = "button") -> None:
    page.get_by_role(vai, name=re.compile(ten)).first.click()
    cho(page, 0.6)


def co_tieu_de(page, chu: str) -> None:
    """Dừng nếu trang không ở trạng thái mong đợi – tránh bấm Lưu trên một bản ghi đang sửa (ghi nhầm CSDL)."""
    if not page.get_by_role("heading", name=re.compile("^" + re.escape(chu))).count():
        raise RuntimeError(f"không thấy tiêu đề '{chu}' – bỏ qua để không ghi nhầm dữ liệu")


def tai_ve(page, nut: str) -> bytes:
    """Bấm nút tải tệp (download_button) và trả nội dung tệp."""
    with page.expect_download(timeout=60_000) as d:
        page.locator('[data-testid="stDownloadButton"]').filter(has_text=nut).first.click()
    return Path(d.value.path()).read_bytes()


# ============================================================================= lưu ảnh
def cat_le(im: Image.Image, le: int = 28) -> Image.Image:
    """Bỏ phần nền trắng thừa quanh nội dung (khoảng đệm trên / dưới của Streamlit), chừa lề `le` px."""
    nen = Image.new(im.mode, im.size, im.getpixel((im.width - 1, im.height - 1)))
    hop = ImageChops.difference(im, nen).convert("L").point(lambda v: 255 if v > 12 else 0).getbbox()
    if not hop:
        return im
    x0, y0, x1, y1 = hop
    return im.crop((max(0, x0 - le), max(0, y0 - le), min(im.width, x1 + le), min(im.height, y1 + le)))


def luu(anh: Image.Image, dich: Path, cat: bool = True) -> None:
    anh = anh.convert("RGB")
    if cat:
        anh = cat_le(anh)
    if anh.width > ANH_TOI_DA:
        anh = anh.resize((ANH_TOI_DA, round(anh.height * ANH_TOI_DA / anh.width)), Image.LANCZOS)
    dich.parent.mkdir(parents=True, exist_ok=True)
    anh.save(dich, "JPEG", quality=85, optimize=True, progressive=True)
    print(f"  ✓ {dich.relative_to(ROOT) if dich.is_relative_to(ROOT) else dich}  ({anh.width}×{anh.height})")


def chup(page, dich: Path, vung: str) -> None:
    """vung = 'full': cả cửa sổ (thấy menu theo vai trò); 'main': chỉ vùng nội dung – chữ to hơn khi in."""
    page.evaluate("() => document.activeElement && document.activeElement.blur()")   # bỏ viền đỏ của ô đang focus
    page.mouse.move(RONG * 0.6, 8)                               # khỏi hover bảng (hiện thanh công cụ) hay menu
    cao = min(max(int(page.evaluate(CHIEU_CAO)), 300), CAO_TOI_DA)
    page.set_viewport_size({"width": RONG, "height": cao})       # vừa khít nội dung: không bị cắt, không thừa nền trắng
    cho(page, 0.5)
    page.mouse.move(RONG * 0.6, 8)
    page.evaluate("() => document.querySelector('[data-testid=\"stMain\"]')?.scrollTo(0, 0)")
    png = (page.screenshot(clip=page.evaluate(VUNG_NOI_DUNG), animations="disabled") if vung == "main"
           else page.screenshot(animations="disabled"))
    page.set_viewport_size({"width": RONG, "height": CAO})
    luu(Image.open(io.BytesIO(png)), dich, cat=vung == "main")


def pdf_thanh_anh(pdf: bytes, dich: Path) -> None:
    try:
        import pypdfium2 as pdfium
    except ImportError:
        print(f"  – bỏ qua {dich.name}: chưa cài pypdfium2 (pip install pypdfium2)")
        return
    trang = pdfium.PdfDocument(pdf)[0]
    w, h = trang.get_size()
    anh = trang.render(scale=1800 / max(w, h)).to_pil()            # cạnh dài 1.800 px
    khung = Image.new("RGB", (anh.width + 2, anh.height + 2), (190, 190, 190))   # viền xám mảnh như trang giấy
    khung.paste(anh, (1, 1))
    luu(khung, dich, cat=False)


# ============================================================================= danh sách ảnh
@dataclass
class Anh:
    ten: str                               # tên tệp (không đuôi)
    tai_khoan: str | None                  # QL, GVU, KT, GV, HV; None = chưa đăng nhập
    trang: str | None                      # tiêu đề mục menu
    thao_tac: Callable | None = None       # thao tác trước khi chụp; trả bytes PDF nếu là ảnh PDF
    vung: str = "main"
    thu_muc: Path = CH4
    ghi: bool = False                      # cần ghi CSDL – chỉ chạy với --ghi
    pdf: bool = False
    ghi_chu: str = ""


def _xoa_mo(page):                         # mở hộp xác nhận xoá (không bấm Xác nhận)
    chon_dong(page, 1)
    bam(page, "Xoá chi nhánh")


def _quet_canh_bao(page):
    bam(page, "Quét cảnh báo hôm nay")


def _nhat_ky(page):
    # đặt lại mật khẩu tài khoản học viên mẫu thành CHÍNH mật khẩu cũ → nhật ký có dòng TAIKHOAN (DoiMatKhau)
    mo_trang(page, "Tài khoản")
    go(page, "Tìm tên đăng nhập / họ tên", TAI_KHOAN["HV"][0])
    chon_dong(page, 0)
    co_tieu_de(page, f"Tài khoản {TAI_KHOAN['HV'][0]} – ")
    page.get_by_label("Đặt lại mật khẩu (bỏ trống nếu không đổi)", exact=True).fill(TAI_KHOAN["HV"][1])
    bam(page, "^Đặt lại mật khẩu$")
    mo_trang(page, "Nhật ký hệ thống")
    chon_dong(page, 0)


DANH_SACH = [
    Anh("01_dang_nhap", None, None),
    # ---- Quản lý (toàn trung tâm)
    Anh("02_trang_chu", "QL", "Trang chủ", vung="full"),
    Anh("04_kiem_tra_nhap_lieu", "QL", "Chi nhánh, phòng, ca học", lambda p: (co_tieu_de(p, "Thêm chi nhánh"), bam(p, "^Lưu$"))),
    Anh("03_danh_muc_chi_nhanh", "QL", "Chi nhánh, phòng, ca học", lambda p: chon_dong(p, 1)),
    Anh("21_xac_nhan_xoa", "QL", "Chi nhánh, phòng, ca học", _xoa_mo),
    Anh("05_nhan_vien", "QL", "Nhân viên & giáo viên"),
    Anh("15_bao_cao_danh_sach", "QL", "Báo cáo & xuất file", lambda p: (chon(p, "Báo cáo", "^Bảng điểm lớp"), chon(p, "Lớp", "^TC650-2501"))),
    Anh("20_pdf_doanh_thu", "QL", "Báo cáo & xuất file",
        lambda p: (chon(p, "Báo cáo", "^Doanh thu"), tai_ve(p, "Tải PDF"))[1], pdf=True),
    Anh("16_dashboard", "QL", "Dashboard"),
    Anh("17_tai_khoan", "QL", "Tài khoản", lambda p: chon_dong(p, 0)),
    Anh("18_nhat_ky", "QL", None, _nhat_ky, ghi=True, ghi_chu="đặt lại mật khẩu hocvien (giữ nguyên mật khẩu)"),
    # ---- Giáo vụ chi nhánh CN01
    Anh("06_lop_hoc", "GVU", "Lớp học"),
    Anh("07_xep_lich", "GVU", "Xếp lịch & buổi học"),
    Anh("08_ho_so_hoc_vien", "GVU", "Hồ sơ học viên", lambda p: chon_dong(p, 0)),
    Anh("09_kiem_tra_dau_vao", "GVU", "Kiểm tra đầu vào", lambda p: go(p, "Tìm học viên (tên, SĐT hoặc mã)", "HV0341")),
    Anh("10_ghi_danh", "GVU", "Ghi danh",
        lambda p: (go(p, "Tìm học viên (tên, SĐT hoặc mã)", "HV0341"), chon_dong(p, 0, bang=1))),
    # ---- Giáo viên NV0012
    Anh("02b_trang_chu_giao_vien", "GV", "Trang chủ", vung="full"),
    Anh("11_diem_danh", "GV", "Điểm danh"),
    Anh("12_nhap_diem", "GV", "Nhập điểm"),
    Anh("doi_mat_khau", "GV", "Đổi mật khẩu", thu_muc=HDSD),
    # giáo vụ quét cả chi nhánh CN01 – lớp của tài khoản giaovien mẫu không có học viên vắng quá ngưỡng
    Anh("13_canh_bao", "GVU", "Cảnh báo chuyên cần", _quet_canh_bao, ghi=True, ghi_chu="quét cảnh báo chuyên cần"),
    # ---- Kế toán chi nhánh CN01
    Anh("14_phieu_thu", "KT", "Lập phiếu thu", lambda p: go(p, "Tìm học viên (tên, SĐT hoặc mã)", "HV0019")),
    Anh("14b_cong_no", "KT", "Công nợ"),
    Anh("19_pdf_phieu_thu", "KT", "Lập phiếu thu",
        lambda p: (bam(p, "^Tra cứu phiếu thu$", "tab"), chon_dong(p, 0), tai_ve(p, "In phiếu"))[2], pdf=True),
    # ---- Học viên HV0016
    Anh("hoc_vien_cua_toi", "HV", "Lịch học & kết quả của tôi", vung="full", thu_muc=HDSD),
]


# ============================================================================= trình duyệt, máy chủ Streamlit
def mo_trinh_duyet(pw, kenh: str):
    thu = ["chromium", "msedge", "chrome"] if kenh == "auto" else [kenh]
    loi = []
    for k in thu:
        try:
            return pw.chromium.launch() if k == "chromium" else pw.chromium.launch(channel=k)
        except Exception as e:                                     # noqa: BLE001 – thử trình duyệt kế tiếp
            loi.append(f"{k}: {str(e).splitlines()[0]}")
    raise SystemExit("Không mở được trình duyệt:\n  " + "\n  ".join(loi) + "\nChạy: python -m playwright install chromium")


def cong_trong() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def khoi_dong_streamlit() -> tuple[subprocess.Popen, str]:
    cong = cong_trong()
    proc = subprocess.Popen([sys.executable, "-m", "streamlit", "run", "app/main.py", "--server.port", str(cong),
                             "--server.headless", "true", "--browser.gatherUsageStats", "false"],
                            cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
                            env=os.environ | {"ECMS_SHOW_DEMO": os.getenv("ECMS_SHOW_DEMO", "yes")})
    base = f"http://localhost:{cong}"
    for _ in range(120):
        try:
            if urllib.request.urlopen(f"{base}/_stcore/health", timeout=1).status == 200:
                return proc, base
        except OSError:
            time.sleep(0.5)
    proc.terminate()
    raise SystemExit("Streamlit không khởi động được – thử chạy tay: streamlit run app/main.py")


# ============================================================================= main
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base-url", help="địa chỉ ứng dụng đang chạy (mặc định: tự khởi động Streamlit ở cổng trống)")
    ap.add_argument("--out-dir", type=Path, help="ghi mọi ảnh vào thư mục này thay vì report/images/ch4 và docs/user-guide/images")
    ap.add_argument("--only", nargs="+", metavar="TEN", help="chỉ chụp các ảnh này (tên tệp không đuôi, VD 10_ghi_danh)")
    ap.add_argument("--ghi", action="store_true", help="chụp cả ảnh cần ghi CSDL (chỉ dùng trên CSDL vừa dựng)")
    ap.add_argument("--trinh-duyet", default="auto", choices=["auto", "chromium", "msedge", "chrome"])
    a = ap.parse_args()
    from playwright.sync_api import sync_playwright

    ds = [x for x in DANH_SACH if not a.only or x.ten in a.only]
    if a.only and (thieu := set(a.only) - {x.ten for x in ds}):
        ap.error(f"không có ảnh {sorted(thieu)}; chọn trong {[x.ten for x in DANH_SACH]}")
    bo_qua = [x for x in ds if x.ghi and not a.ghi]
    ds = [x for x in ds if x not in bo_qua]

    proc, base = (None, a.base_url.rstrip("/")) if a.base_url else khoi_dong_streamlit()
    print(f"ECMS: {base}")
    loi = []
    try:
        with sync_playwright() as pw:
            trinh = mo_trinh_duyet(pw, a.trinh_duyet)
            for tk in dict.fromkeys(x.tai_khoan for x in ds):             # mỗi tài khoản một phiên riêng
                ctx = trinh.new_context(viewport={"width": RONG, "height": CAO}, device_scale_factor=2, locale="vi-VN",
                                        timezone_id="Asia/Ho_Chi_Minh", accept_downloads=True)
                page = ctx.new_page()
                print(f"[{TAI_KHOAN[tk][0] if tk else 'chưa đăng nhập'}]")
                try:
                    if tk:
                        dang_nhap(page, base, tk)
                    else:
                        page.goto(base)
                        cho(page)
                    for x in (x for x in ds if x.tai_khoan == tk):
                        dich = (a.out_dir or x.thu_muc) / f"{x.ten}.jpg"
                        try:
                            if x.trang:
                                mo_trang(page, x.trang)
                            kq = x.thao_tac(page) if x.thao_tac else None
                            if x.pdf:
                                pdf_thanh_anh(kq, dich)
                            else:
                                chup(page, dich, x.vung)
                        except Exception as e:                       # noqa: BLE001 – ghi lỗi, chụp tiếp ảnh khác
                            loi.append(f"{x.ten}: {str(e).splitlines()[0]}")
                            print(f"  ✗ {x.ten}: {str(e).splitlines()[0]}")
                            page.keyboard.press("Escape")
                finally:
                    ctx.close()
            trinh.close()
    finally:
        if proc:
            proc.terminate()
    for x in bo_qua:
        print(f"  – bỏ qua {x.ten}: cần --ghi ({x.ghi_chu})")
    if loi:
        raise SystemExit(f"{len(loi)} ảnh lỗi:\n  " + "\n  ".join(loi))


if __name__ == "__main__":
    main()
