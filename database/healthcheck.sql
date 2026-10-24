/* =====================================================================
   healthcheck.sql – SQL Server trong Docker đã sẵn sàng để dựng CSDL ECMS chưa?
   Dùng bởi healthcheck của docker-compose.yml và database/run_all.sh (chạy với -b: lỗi → exit code 1).

   Lần khởi động đầu, container đổi collation máy chủ sang Vietnamese_CI_AS (biến MSSQL_COLLATION).
   SQL Server đã nhận kết nối và SERVERPROPERTY('Collation') đã trả về giá trị mới TRƯỚC khi việc đổi
   xong; nếu lúc đó tạo CSDL ECMS (có indexed view, filtered index) thì bước reindex thất bại
   (Msg 1934 → 3434) và máy chủ tự tắt. Vì vậy chỉ báo sẵn sàng khi errorlog đã có dòng
   "The default collation was successfully changed" (hoặc không có lần đổi nào đang diễn ra).
   ===================================================================== */
SET NOCOUNT ON;

DECLARE @log TABLE (LogDate DATETIME, ProcessInfo NVARCHAR(64), Text NVARCHAR(MAX));
INSERT @log EXEC master.dbo.xp_readerrorlog 0, 1, N'collation';

IF EXISTS (SELECT 1 FROM @log WHERE Text LIKE N'Attempting to change default collation%')
   AND NOT EXISTS (SELECT 1 FROM @log WHERE Text LIKE N'%default collation was successfully changed%')
    THROW 50000, N'SQL Server đang đổi collation máy chủ – chờ thêm.', 1;

SELECT N'ready' AS TrangThai;
