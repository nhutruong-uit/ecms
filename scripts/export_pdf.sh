#!/usr/bin/env bash
# Xuất PDF bằng Microsoft Word (macOS) từ file .docx do build_report.py sinh ra: Word cập nhật Mục lục, Danh mục
# hình ảnh và số trang rồi lưu PDF cạnh file docx – PDF giống hệt bản Word (A4, Times New Roman 13).
#
#   scripts/export_pdf.sh                                   # cả báo cáo và hướng dẫn sử dụng
#   scripts/export_pdf.sh report/BaoCao_IE103_Nhom1.docx    # một tài liệu
#
# File docx được thay bằng bản Word đã cập nhật trường (mục lục có số trang, không còn cờ updateFields) nên mở bằng
# Word không bị hỏi "cập nhật trường?". Word trên macOS chạy trong sandbox: file được mở bằng "open -a" để macOS tự
# cấp quyền đọc. Nếu Word vẫn hiện "Grant File Access", NGƯỜI DÙNG bấm "Select..." và chọn file (script không tự bấm).
# Không có Word (Windows, Linux): dùng python scripts/build_report.py --pdf (in bằng Chrome/Edge).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/report/.build"          # KHÔNG xoá thư mục này: Word sẽ mất quyền truy cập đã được cấp
[[ "$(uname)" == "Darwin" ]] || { echo "Script chỉ chạy trên macOS." >&2; exit 2; }
[[ -d "/Applications/Microsoft Word.app" ]] || { echo "Chưa cài Microsoft Word." >&2; exit 2; }
PY="${PYTHON:-python3}"
mkdir -p "$BUILD"

if [[ $# -eq 0 ]]; then set -- "$ROOT/report/BaoCao_IE103_Nhom1.docx" "$ROOT/report/HuongDanSuDung_ECMS.docx"; fi

export_one() {
  local DOCX NAME PDF WORK_PDF PID NOTIFIED
  [[ -f "$1" ]] || { echo "Không thấy $1 – chạy python scripts/build_report.py trước." >&2; return 2; }
  DOCX="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  NAME="$(basename "$DOCX")"
  PDF="${DOCX%.docx}.pdf"
  WORK_PDF="$BUILD/${NAME%.docx}.pdf"

  # Bản làm việc bỏ cờ updateFields và w:dirty: có cờ này Word hiện hộp thoại "cập nhật trường?" làm treo tự động hoá.
  # AppleScript bên dưới tự cập nhật mục lục và danh mục hình.
  "$PY" - "$DOCX" "$BUILD/$NAME" <<'PY'
import sys
from docx import Document
from docx.oxml.ns import qn
d = Document(sys.argv[1])
el = d.settings.element.find(qn("w:updateFields"))
if el is not None:
    d.settings.element.remove(el)
for fld in d.element.body.iter(qn("w:fldChar")):
    fld.attrib.pop(qn("w:dirty"), None)
d.save(sys.argv[2])
PY
  rm -f "$WORK_PDF"
  # Khoá "~$…" còn sót từ lần xuất lỗi làm Word không mở được file → xoá nếu Word không đang mở tài liệu này
  if ! osascript -e 'tell application "Microsoft Word" to get name of every document' 2>/dev/null | grep -qF "$NAME"; then
    rm -f "$BUILD/~\$$NAME" "$BUILD/~\$${NAME:2}"
  fi

  open -a "Microsoft Word" "$BUILD/$NAME"
  for _ in $(seq 1 60); do
    sleep 2
    osascript -e 'tell application "Microsoft Word" to get name of every document' 2>/dev/null | grep -qF "$NAME" && break
  done

  osascript - "$WORK_PDF" "$NAME" <<'APPLESCRIPT' &
on run argv
    with timeout of 900 seconds
        tell application "Microsoft Word"
            set d to document (item 2 of argv)
            -- Mục lục và Danh mục hình ảnh đều là "table of contents" trong Word
            repeat with i from 1 to (count of tables of contents of d)
                update (table of contents i of d)
            end repeat
            save d
            save as d file name (item 1 of argv) file format format PDF
            close d saving no
        end tell
    end timeout
end run
APPLESCRIPT
  PID=$!
  NOTIFIED=0
  while kill -0 "$PID" 2>/dev/null; do
    sleep 3
    if [[ $NOTIFIED -eq 0 ]] && osascript -e 'tell application "System Events" to tell (first process whose name is "Microsoft Word") to get name of every window' 2>/dev/null | grep -q "Grant File Access"; then
      echo ">>> Word đang xin quyền truy cập file: bấm \"Select...\" và chọn report/.build/$NAME"
      NOTIFIED=1
    fi
  done
  wait "$PID" || { echo "Word không xuất được PDF." >&2; return 1; }
  [[ -s "$WORK_PDF" ]] || { echo "Word không tạo ra PDF." >&2; return 1; }
  cp "$WORK_PDF" "$PDF"
  cp "$BUILD/$NAME" "$DOCX"
  echo "✓ ${PDF#"$ROOT"/} (docx đã được thay bằng bản Word cập nhật mục lục, số trang)"
}

for f in "$@"; do export_one "$f"; done
