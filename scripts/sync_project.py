#!/usr/bin/env python3
"""Tạo / cập nhật GitHub Project (bảng công việc) từ docs/data/tasks.json.

    python3 scripts/sync_project.py

Việc script làm:
  1. Tìm project theo tên trong tasks.json (chưa có thì tạo), để chế độ công khai, liên kết với repo.
  2. Tạo các trường: Thành viên, Sprint, Chương, Hạn chót.
  3. Thêm mọi issue của task vào project, điền các trường trên và Status (Todo / Done).

Cần chạy scripts/sync_issues.py trước (để task có số issue) và gh có quyền `project`:
    gh auth refresh -h github.com -s project,read:project
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS_FILE = ROOT / "docs" / "data" / "tasks.json"
TEAM_FILE = ROOT / "docs" / "data" / "team.json"


def gh(*args):
    res = subprocess.run(["gh", *args], capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit(f"Lỗi khi chạy gh {' '.join(args)}:\n{res.stderr}")
    return res.stdout.strip()


def gh_json(*args):
    out = gh(*args, "--format", "json")
    return json.loads(out) if out else {}


def write_project_info(number, url):
    text = TASKS_FILE.read_text(encoding="utf-8")
    text = re.sub(r'("projectNumber":\s*)(null|\d+)', lambda m: f"{m.group(1)}{number}", text, count=1)
    text = re.sub(r'("projectUrl":\s*)(null|"[^"]*")', lambda m: f'{m.group(1)}"{url}"', text, count=1)
    TASKS_FILE.write_text(text, encoding="utf-8")


def ensure_project(owner, title, repo, pages):
    projects = gh_json("project", "list", "--owner", owner, "--limit", "100").get("projects", [])
    proj = next((p for p in projects if p["title"] == title), None)
    if proj is None:
        proj = gh_json("project", "create", "--owner", owner, "--title", title)
        print(f"  ✓ Tạo project #{proj['number']}")
    else:
        print(f"  · Đã có project #{proj['number']}")
    number = str(proj["number"])
    readme = (
        f"Bảng công việc đồ án IE103 – Quản lý thông tin (Nhóm 1).\n\n"
        f"- Kế hoạch & phân công chi tiết: {pages}\n"
        f"- Repo: https://github.com/{repo}\n\n"
        "Mỗi thẻ là một issue. Kéo thẻ sang In Progress khi bắt đầu, issue đóng (PR merge) thì thẻ tự sang Done."
    )
    gh("project", "edit", number, "--owner", owner, "--visibility", "PUBLIC",
       "--description", "Đồ án IE103 – Hệ thống Quản lý Trung tâm Tiếng Anh (Nhóm 1)", "--readme", readme)
    linked = subprocess.run(["gh", "project", "link", number, "--owner", owner, "--repo", repo],
                            capture_output=True, text=True)
    if linked.returncode == 0:
        print("  ✓ Liên kết project với repo")
    view = gh_json("project", "view", number, "--owner", owner)
    return number, view["id"], view["url"]


def ensure_fields(owner, number, specs):
    """specs: {tên trường: None (DATE) hoặc [danh sách lựa chọn]}"""
    fields = gh_json("project", "field-list", number, "--owner", owner, "--limit", "50").get("fields", [])
    by_name = {f["name"]: f for f in fields}
    for name, options in specs.items():
        if name in by_name:
            have = {o["name"] for o in by_name[name].get("options", [])}
            missing = [o for o in (options or []) if o not in have]
            if missing:
                print(f"  ! Trường '{name}' thiếu lựa chọn {missing} – thêm tay trên giao diện Project")
            continue
        if options is None:
            gh("project", "field-create", number, "--owner", owner, "--name", name, "--data-type", "DATE")
        else:
            gh("project", "field-create", number, "--owner", owner, "--name", name,
               "--data-type", "SINGLE_SELECT", "--single-select-options", ",".join(options))
        print(f"  ✓ Tạo trường '{name}'")
    fields = gh_json("project", "field-list", number, "--owner", owner, "--limit", "50").get("fields", [])
    return {f["name"]: f for f in fields}


def option_id(field, name):
    for o in field.get("options", []):
        if o["name"] == name:
            return o["id"]
    return None


def main():
    plan = json.loads(TASKS_FILE.read_text(encoding="utf-8"))
    team = json.loads(TEAM_FILE.read_text(encoding="utf-8"))
    repo = plan["project"]["repo"]
    owner = repo.split("/")[0]
    members = {m["id"]: m for m in team["members"]}
    sprints = {s["id"]: s for s in plan["sprints"]}
    chapters = {c["id"]: c for c in plan["chapters"]}

    print("• Project")
    number, project_id, url = ensure_project(owner, plan["project"]["name"], repo, plan["project"]["pages"])
    write_project_info(number, url)

    print("• Trường dữ liệu")
    fields = ensure_fields(owner, number, {
        "Thành viên": [m["short"] for m in team["members"]],
        "Sprint": [s["name"] for s in plan["sprints"]],
        "Chương": [c["name"] for c in plan["chapters"]],
        "Hạn chót": None,
    })

    print("• Thẻ công việc")
    items = gh_json("project", "item-list", number, "--owner", owner, "--limit", "300").get("items", [])
    item_by_issue = {}
    for it in items:
        content = it.get("content") or {}
        if content.get("type") == "Issue":
            item_by_issue[content.get("number")] = it["id"]

    issues = json.loads(gh("issue", "list", "-R", repo, "--state", "all", "--limit", "300", "--json", "number,state,url"))
    issue_info = {i["number"]: i for i in issues}

    def set_select(item_id, field_name, value):
        f = fields.get(field_name)
        oid = option_id(f, value) if f else None
        if oid:
            gh("project", "item-edit", "--id", item_id, "--project-id", project_id,
               "--field-id", f["id"], "--single-select-option-id", oid)

    for task in plan["tasks"]:
        n = task.get("issue")
        if not n or n not in issue_info:
            print(f"  ! {task['id']} chưa có issue – bỏ qua")
            continue
        item_id = item_by_issue.get(n)
        is_new = item_id is None
        if is_new:
            item_id = gh_json("project", "item-add", number, "--owner", owner, "--url", issue_info[n]["url"])["id"]
        set_select(item_id, "Thành viên", members[task["owner"]]["short"])
        set_select(item_id, "Sprint", sprints[task["sprint"]]["name"])
        set_select(item_id, "Chương", chapters[task["chapter"]]["name"])
        if "Hạn chót" in fields:
            gh("project", "item-edit", "--id", item_id, "--project-id", project_id,
               "--field-id", fields["Hạn chót"]["id"], "--date", task["due"])
        # Không ghi đè trạng thái In Progress mà thành viên đã kéo trên bảng
        if issue_info[n]["state"] == "CLOSED":
            set_select(item_id, "Status", "Done")
        elif is_new:
            set_select(item_id, "Status", "Todo")
        print(f"  ✓ {task['id']} (#{n})")

    print(f"Xong: {url}")


if __name__ == "__main__":
    main()
