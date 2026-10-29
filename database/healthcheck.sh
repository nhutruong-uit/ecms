#!/usr/bin/env bash
# healthcheck.sh – SQL Server trong Docker đã sẵn sàng để dựng CSDL ECMS chưa? (chạy BÊN TRONG container ecms-mssql)
# Dùng bởi healthcheck của docker-compose.yml và database/run_all.sh (chế độ docker). Exit 0: sẵn sàng.
#
# Lần khởi động đầu, ngay sau dòng "SQL Server is now ready for client connections" (khoảng 0,1 giây) máy chủ đổi
# collation sang MSSQL_COLLATION và reindex master. Bất kỳ kết nối nào lúc đó – kể cả kết nối của chính healthcheck
# chạy healthcheck.sql – có thể deadlock với việc reindex (Msg 1205 → 3434), máy chủ tự tắt (CI ngày 28/10/2026).
# Vì vậy đọc errorlog thẳng từ file, chỉ kết nối khi chắc chắn không có lần đổi collation nào đang hoặc sắp diễn ra.
set -u

# errorlog ghi UTF-16: bỏ byte 0 để grep được
log="$(tr -d '\000\r' < /var/opt/mssql/log/errorlog 2>/dev/null)" || exit 1
ready="$(grep -m1 'SQL Server is now ready for client connections' <<<"$log")" || exit 1

if grep -q 'Attempting to change default collation' <<<"$log"; then
  # Đang đổi collation: chờ tới khi errorlog báo xong
  grep -q 'default collation was successfully changed' <<<"$log" || exit 1
else
  # Chưa thấy lần đổi nào (khởi động lại với volume cũ, hoặc chưa kịp ghi dòng "Attempting…"): chờ 10 giây sau dòng
  # ready cho chắc. Giờ trong errorlog và lệnh date cùng múi giờ TZ của container.
  t="$(date -d "${ready:0:22}" +%s 2>/dev/null)" || exit 1
  (( $(date +%s) - t >= 10 )) || exit 1
fi

exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -i /database/healthcheck.sql -o /dev/null
