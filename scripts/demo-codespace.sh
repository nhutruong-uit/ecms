#!/usr/bin/env bash
# Bật / tắt link demo ECMS trên GitHub Codespaces (Codespace "ECMS demo" của tài khoản nhutruong-uit).
#   scripts/demo-codespace.sh bat         # bật Codespace, chạy ECMS, đặt cổng 8501 Public, in link
#   scripts/demo-codespace.sh tat         # tắt Codespace: link ngừng hoạt động, không tốn giờ miễn phí
#   scripts/demo-codespace.sh trangthai   # Codespace đang chạy hay tắt, link mở được chưa
# Cần gh đăng nhập tài khoản sở hữu Codespace, có quyền codespace: gh auth refresh -h github.com -s codespace
# Codespace khác: CODESPACE=<tên> scripts/demo-codespace.sh bat (tên xem bằng gh codespace list)
set -uo pipefail

CS="${CODESPACE:-ecms-demo-7vj9gq5977vpc97r}"
URL="https://$CS-8501.app.github.dev"

case "${1:-trangthai}" in
  bat)
    echo "▶ Bật Codespace $CS và khởi động ECMS (Codespace đang tắt thì mất khoảng 1–2 phút)"
    # gh codespace ssh tự bật Codespace đang tắt. Bật bằng gh thì không mở VS Code nên start.sh không tự chạy (postAttach):
    # chạy nền bằng setsid để Streamlit vẫn sống khi phiên SSH đóng
    gh codespace ssh -c "$CS" -- 'cd /workspaces/ecms && { curl -fs localhost:8501/_stcore/health >/dev/null ||
      { nohup setsid bash .devcontainer/start.sh > /tmp/ecms.log 2>&1 < /dev/null & }; }' || true
    if ! gh codespace ssh -c "$CS" -- 'for i in $(seq 1 150); do curl -fs localhost:8501/_stcore/health >/dev/null && exit 0; sleep 2; done
      tail -20 /tmp/ecms.log; exit 1'; then
      echo "✗ ECMS chưa chạy sau 5 phút – log ở trên" >&2
      exit 1
    fi
    # Codespace bật lại thì cổng 8501 về Private: người xem sẽ gặp trang đăng nhập GitHub
    gh codespace ports visibility 8501:public -c "$CS" >/dev/null
    echo "✓ $URL"
    echo "  Lần đầu mở, GitHub hiện trang cảnh báo → Continue. Codespace tự tắt khi không ai dùng một thời gian."
    ;;
  tat)
    gh codespace stop -c "$CS" && echo "✓ Đã tắt Codespace – link ngừng hoạt động cho tới lần bật sau"
    ;;
  trangthai)
    echo "Codespace $CS: $(gh codespace view -c "$CS" --json state -q .state)"
    code="$(curl -s -o /dev/null -w '%{http_code}' "$URL/_stcore/health")"
    case "$code" in
      200) echo "Link: $URL – mở được" ;;
      302) echo "Link: $URL – cổng 8501 còn Private (chạy lại: $0 bat)" ;;
      *)   echo "Link: $URL – chưa mở được (HTTP $code; chạy: $0 bat)" ;;
    esac
    ;;
  *)
    sed -n '2,7p' "$0"
    exit 1
    ;;
esac
