#!/usr/bin/env python3
"""Đồng bộ kế hoạch trong docs/data/tasks.json lên GitHub: labels, milestones, issues.

    python3 scripts/sync_issues.py              # tạo labels, milestones và các issue còn thiếu
    python3 scripts/sync_issues.py --update     # cập nhật lại tiêu đề/nội dung/labels của issue đã có
    python3 scripts/sync_issues.py --dry-run    # chỉ in ra, không gọi GitHub

Cần GitHub CLI (gh) đã đăng nhập với quyền `repo`.
Lưu ý: --update ghi đè nội dung issue, các ô checklist đã tick sẽ bị bỏ tick.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS_FILE = ROOT / "docs" / "data" / "tasks.json"
TEAM_FILE = ROOT / "docs" / "data" / "team.json"

STATUS_LABELS = [
    ("dang-lam", "facc15", "Task đang được thực hiện"),
]


def gh(*args, input_text=None, dry=False):
    if dry:
        print("  [dry-run] gh", " ".join(args))
        return ""
    res = subprocess.run(["gh", *args], input=input_text, capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"Lỗi khi chạy gh {' '.join(args)}:\n{res.stderr}")
    return res.stdout.strip()


def fmt_date(iso):
    y, m, d = iso.split("-")
    return f"{d}/{m}/{y}"


def owner_label(member):
    return f"owner: {member['short']}"


def build_body(task, plan, team, issue_of):
    members = {m["id"]: m for m in team["members"]}
    sprints = {s["id"]: s for s in plan["sprints"]}
    chapters = {c["id"]: c for c in plan["chapters"]}
    m = members[task["owner"]]
    sp = sprints[task["sprint"]]
    lines = [
        f"> **{task['id']}** · {sp['name']} · Hạn **{fmt_date(task['due'])}**",
        f"> Phụ trách: **{m['name']}** ({m['mssv']}){' · @' + m['github'] if m.get('github') else ''}",
        f"> {chapters[task['chapter']]['name']}",
        "",
        "### Mục tiêu",
        task["summary"],
        "",
        f"**Bám đề cương:** {task['syllabus']}",
        "",
        "### Công việc chi tiết",
        *[f"- [ ] {s}" for s in task["steps"]],
        "",
        "### Sản phẩm bàn giao",
        *[f"- {s}" for s in task["deliverables"]],
        "",
        "### Tiêu chí hoàn thành",
        *[f"- [ ] {s}" for s in task["acceptance"]],
        "- [ ] Đã viết mục báo cáo tương ứng trong `report/` (kèm ảnh kết quả)",
    ]
    if task["depends"]:
        deps = []
        for d in task["depends"]:
            n = issue_of.get(d)
            deps.append(f"{d} (#{n})" if n else d)
        lines += ["", "### Phụ thuộc", "- " + ", ".join(deps)]
    lines += [
        "",
        "---",
        f"_Kế hoạch đầy đủ: {plan['project']['pages']}#task-{task['id']} · "
        "Nội dung sinh từ `docs/data/tasks.json` bằng `scripts/sync_issues.py`._",
    ]
    return "\n".join(lines)


def ensure_labels(repo, plan, team, dry):
    print("• Labels")
    specs = []
    for c in plan["chapters"]:
        specs.append((c["label"], c["color"], c["name"]))
    for t in plan["types"]:
        specs.append((t["label"], t["color"], t["name"]))
    for m in team["members"]:
        specs.append((owner_label(m), m["color"].lstrip("#"), f"Phụ trách: {m['name']} ({m['mssv']})"))
    specs += STATUS_LABELS
    for name, color, desc in specs:
        gh("label", "create", name, "--color", color, "--description", desc, "--force", "-R", repo, dry=dry)
        print(f"  ✓ {name}")


def ensure_milestones(repo, plan, dry):
    print("• Milestones")
    existing = {}
    if not dry:
        out = gh("api", f"repos/{repo}/milestones?state=all&per_page=100")
        existing = {m["title"]: m["number"] for m in json.loads(out or "[]")}
    for s in plan["sprints"]:
        args = [
            "-f", f"title={s['name']}",
            "-f", f"due_on={s['end']}T12:00:00Z",
            "-f", f"description={fmt_date(s['start'])} → {fmt_date(s['end'])}: {s['goal']}",
        ]
        if s["name"] in existing:
            gh("api", "-X", "PATCH", f"repos/{repo}/milestones/{existing[s['name']]}", *args, dry=dry)
            print(f"  ↻ {s['name']}")
        else:
            gh("api", "-X", "POST", f"repos/{repo}/milestones", *args, dry=dry)
            print(f"  ✓ {s['name']}")


def write_issue_number(task_id, number):
    text = TASKS_FILE.read_text(encoding="utf-8")
    pattern = re.compile(r'("id":\s*"%s",\s*"issue":\s*)(null|\d+)' % re.escape(task_id))
    new_text, n = pattern.subn(lambda mt: f"{mt.group(1)}{number}", text, count=1)
    if n != 1:
        sys.exit(f"Không ghi được số issue cho {task_id} vào tasks.json")
    TASKS_FILE.write_text(new_text, encoding="utf-8")


def sync_issues(repo, plan, team, update, dry):
    print("• Issues")
    members = {m["id"]: m for m in team["members"]}
    sprints = {s["id"]: s for s in plan["sprints"]}
    chapters = {c["id"]: c for c in plan["chapters"]}
    types = {t["id"]: t for t in plan["types"]}
    issue_of = {t["id"]: t["issue"] for t in plan["tasks"] if t["issue"]}

    for task in plan["tasks"]:
        m = members[task["owner"]]
        title = f"[{task['id']}] {task['title']}"
        labels = [chapters[task["chapter"]]["label"], owner_label(m)] + [types[x]["label"] for x in task["types"]]
        milestone = sprints[task["sprint"]]["name"]
        body = build_body(task, plan, team, issue_of)

        if task["issue"] and not update:
            print(f"  · {task['id']} đã có issue #{task['issue']}")
            continue

        if task["issue"]:
            args = ["issue", "edit", str(task["issue"]), "-R", repo, "--title", title,
                    "--body-file", "-", "--milestone", milestone, "--add-label", ",".join(labels)]
            if m.get("github"):
                args += ["--add-assignee", m["github"]]
            gh(*args, input_text=body, dry=dry)
            print(f"  ↻ {task['id']} → #{task['issue']}")
            continue

        args = ["issue", "create", "-R", repo, "--title", title, "--body-file", "-",
                "--milestone", milestone, "--label", ",".join(labels)]
        if m.get("github"):
            args += ["--assignee", m["github"]]
        url = gh(*args, input_text=body, dry=dry)
        if dry:
            continue
        number = int(url.rstrip("/").rsplit("/", 1)[-1])
        task["issue"] = number
        issue_of[task["id"]] = number
        write_issue_number(task["id"], number)
        print(f"  ✓ {task['id']} → #{number}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--update", action="store_true", help="cập nhật lại issue đã tồn tại")
    ap.add_argument("--dry-run", action="store_true", help="chỉ in lệnh, không gọi GitHub")
    ap.add_argument("--skip-meta", action="store_true", help="bỏ qua bước tạo labels/milestones")
    args = ap.parse_args()

    plan = json.loads(TASKS_FILE.read_text(encoding="utf-8"))
    team = json.loads(TEAM_FILE.read_text(encoding="utf-8"))
    repo = plan["project"]["repo"]

    if not args.skip_meta:
        ensure_labels(repo, plan, team, args.dry_run)
        ensure_milestones(repo, plan, args.dry_run)
    sync_issues(repo, plan, team, args.update, args.dry_run)
    print("Xong.")


if __name__ == "__main__":
    main()
