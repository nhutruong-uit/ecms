#!/usr/bin/env bash
# Commit thay mặt một thành viên: ghi đúng tên + email của người phụ trách phần việc.
#
#   scripts/commit-as.sh <id> [tham số của git commit...]
#   scripts/commit-as.sh phu -m "db(procedures): thêm sp_DangKyHoc (#11)"
#   scripts/commit-as.sh --list            # xem danh sách id thành viên
#
# Thông tin thành viên lấy từ docs/data/team.json (sửa email ở đó nếu bạn dùng email khác trên GitHub).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TEAM="$ROOT/docs/data/team.json"

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

if [[ "$1" == "--list" ]]; then
  python3 - "$TEAM" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1], encoding="utf-8"))["members"]:
    print(f'{m["id"]:<7} {m["name"]:<22} <{m["email"]}>')
PY
  exit 0
fi

id="$1"; shift
IFS=$'\t' read -r name email < <(python3 - "$TEAM" "$id" <<'PY'
import json, sys
team = json.load(open(sys.argv[1], encoding="utf-8"))
m = next((m for m in team["members"] if m["id"] == sys.argv[2]), None)
if m is None:
    ids = ", ".join(x["id"] for x in team["members"])
    sys.exit(f"Không có thành viên '{sys.argv[2]}'. Chọn một trong: {ids}")
print(f'{m["name"]}\t{m["email"]}')
PY
)

echo "→ Commit dưới tên: $name <$email>"
GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" \
GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" \
  git commit "$@"
