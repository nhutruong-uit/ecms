"""Thống kê đóng góp từng thành viên từ lịch sử git (T29) – in bảng Markdown cho Chương 6.

    python3 scripts/thong_ke_dong_gop.py            # mặc định so trên nhánh hiện tại
    python3 scripts/thong_ke_dong_gop.py origin/main

"Dòng tự viết" bỏ qua file sinh tự động (dữ liệu mẫu, CSV/XML/JSON xuất, sơ đồ .drawio, ảnh, font)
để số liệu không bị lệch bởi file sinh bằng script.
"""
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SINH_TU_DONG = re.compile(r"(^data/|^database/02_seed\.sql$|\.drawio$|\.(png|jpg|jpeg|ttf|xlsx|docx|pptx|pdf)$)")


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def so(n: int) -> str:
    return f"{n:,}".replace(",", ".")


def main(ref: str = "HEAD") -> None:
    team = json.loads((ROOT / "docs/data/team.json").read_text(encoding="utf-8"))["members"]
    tasks = json.loads((ROOT / "docs/data/tasks.json").read_text(encoding="utf-8"))["tasks"]
    ten = {m["id"]: m["name"] for m in team}
    so_task = defaultdict(list)
    for t in tasks:
        so_task[ten[t["owner"]]].append(t["id"])

    commit, them, xoa, tu_viet = defaultdict(int), defaultdict(int), defaultdict(int), defaultdict(int)
    tac_gia = None
    for line in git("log", ref, "--no-merges", "--format=@%an", "--numstat").splitlines():
        if line.startswith("@"):
            tac_gia = line[1:]
            commit[tac_gia] += 1
        elif line.strip():
            a, d, path = line.split("\t", 2)
            if a == "-":                      # file nhị phân
                continue
            them[tac_gia] += int(a)
            xoa[tac_gia] += int(d)
            if not SINH_TU_DONG.search(path):
                tu_viet[tac_gia] += int(a)

    tong_commit = sum(commit.values())
    tong_tu_viet = sum(tu_viet.values()) or 1
    print("| Thành viên | Task phụ trách | Số commit | Tỷ lệ commit | Dòng thêm / xoá (mọi file) | Dòng tự viết | Tỷ lệ dòng tự viết |")
    print("|---|---|--:|--:|--:|--:|--:|")
    for m in team:
        n = m["name"]
        print(f"| {n} | {len(so_task[n])} ({', '.join(so_task[n])}) | {commit[n]} | {commit[n] / tong_commit:.0%} "
              f"| +{so(them[n])} / −{so(xoa[n])} | {so(tu_viet[n])} | {tu_viet[n] / tong_tu_viet:.0%} |")
    print(f"| **Tổng** | {len(tasks)} | {tong_commit} | 100% | | {so(tong_tu_viet)} | 100% |")


if __name__ == "__main__":
    main(*sys.argv[1:])
