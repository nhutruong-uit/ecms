"""Biểu đồ số liệu đo của Chương 3 (cần matplotlib):  python report/images/ch3/bieu-do.py

  chi-muc-xml.png      – X18 (database/09_xml.sql): số trang đọc khi lọc bài có Speaking ≥ 7, có / không chỉ mục XML
  cursor-set-based.png – database/tests/bench_cursor.sql: thời gian trung bình 20 lần chạy, cursor và set-based
Số liệu chép từ kết quả chạy trên SQL Server 2025 (Docker), ngày 25/10/2026.
Khổ hình rộng đúng 15 cm (bề rộng hình trong báo cáo) nên cỡ chữ in ra bằng cỡ chữ khai báo ở đây (≥ 10 pt);
phông Times New Roman như thân báo cáo.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

OUT = Path(__file__).resolve().parent
plt.rcParams.update({"font.family": "Times New Roman", "font.size": 11, "axes.titlesize": 11, "legend.fontsize": 11,
                     "axes.spines.top": False, "axes.spines.right": False})
RONG = 15 / 2.54                      # inch – hình in đúng 15 cm, chữ in đúng cỡ khai báo
XAM, XANH, CAM, TIM = "#94a3b8", "#2e75b6", "#f59e0b", "#7c3aed"


def so(x: float, le: int = 0) -> str:
    """Định dạng số kiểu Việt Nam: 1.234,5"""
    s = f"{x:,.{le}f}"
    return s.replace(",", "_").replace(".", ",").replace("_", ".")


def chi_muc_xml():
    # (trang dữ liệu của bảng, lượt đọc LOB, trang chỉ mục XML)
    quy_mo = [("357 bài (bảng thật)\n52 bài khớp", (361, 1608, 0), (106, 0, 601)),
              ("10.710 bài (nhân 30 lần)\n1.560 bài khớp", (1956, 0, 0), (5658, 0, 34832))]
    fig, axes = plt.subplots(1, 2, figsize=(RONG, 3.1))
    for ax, (ten, khong, co) in zip(axes, quy_mo):
        nhan = ["Không\nchỉ mục", "PRIMARY\n+ PATH"]
        day = [0, 0]
        for k, (mau, chu) in enumerate([(XANH, "trang dữ liệu"), (CAM, "trang LOB"), (TIM, "trang chỉ mục XML")]):
            v = [khong[k], co[k]]
            ax.bar(nhan, v, bottom=day, color=mau, width=0.55, label=chu)
            day = [a + b for a, b in zip(day, v)]
        for x, t in enumerate(day):
            ax.text(x, t, so(t), ha="center", va="bottom", fontweight="bold")
        ax.set_title(ten)
        ax.set_ylim(0, max(day) * 1.18)
        ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: so(v)))
    axes[0].set_ylabel("Số trang đọc logic")
    h, l = axes[0].get_legend_handles_labels()
    fig.legend(h, l, loc="lower center", ncol=3, frameon=False, columnspacing=1.2, handlelength=1.4)
    fig.tight_layout(rect=(0, 0.09, 1, 1))
    fig.savefig(OUT / "chi-muc-xml.png", dpi=200)


def cursor_set_based():
    bai = ["Cảnh báo chuyên cần\n(2 cảnh báo)", "Bảng lương 12 tháng 2025\n(10 giáo viên × 12 tháng)",
           "Sinh 30 buổi học\nlớp IE65-2601"]
    cursor, tap_hop = [24.23, 69.39, 11.52], [8.80, 10.05, 10.72]
    fig, ax = plt.subplots(figsize=(RONG, 3.4))
    x = range(len(bai))
    w = 0.36
    ax.bar([i - w / 2 for i in x], cursor, w, color=XAM, label="Cursor")
    ax.bar([i + w / 2 for i in x], tap_hop, w, color=XANH, label="Theo tập hợp (set-based)")
    for i in x:
        ax.text(i - w / 2, cursor[i], so(cursor[i], 2), ha="center", va="bottom", fontsize=10.5)
        ax.text(i + w / 2, tap_hop[i], so(tap_hop[i], 2), ha="center", va="bottom", fontsize=10.5)
        ax.text(i, max(cursor[i], tap_hop[i]) + 8, f"chậm hơn {so(cursor[i] / tap_hop[i], 1)} lần",
                ha="center", fontweight="bold", color="#1f3864")
    ax.set_xticks(list(x), bai)
    ax.set_ylabel("Thời gian trung bình (ms)")
    ax.set_ylim(0, 88)
    fig.legend(loc="lower center", ncol=2, frameon=False, columnspacing=2.0, handlelength=1.4)   # dưới trục, không đè cột
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    fig.savefig(OUT / "cursor-set-based.png", dpi=200)


if __name__ == "__main__":
    chi_muc_xml()
    cursor_set_based()
    print("✓ chi-muc-xml.png, cursor-set-based.png")
