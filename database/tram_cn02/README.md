# Trạm CN02 trên máy thứ hai – cam kết hai pha qua MSDTC

Dựng trạm CN02 là SQL Server trong Docker trên một máy khác (ví dụ macOS) cùng mạng với máy Windows có instance chính, rồi
chạy `database/13b_2pc_msdtc.sql` trên máy Windows: giao tác chuyển lớp CN02 → CN01 ghi vào hai máy, MSDTC của hai máy
điều phối cam kết hai pha qua mạng.

## 1. Máy thứ hai (macOS, Docker Desktop)

```bash
git switch t30-khac-phuc-sau-review && git pull
WIN_HOST=NHUTRUONG WIN_IP=192.168.1.169 docker compose -f database/tram_cn02/docker-compose.yml up -d
# MSDTC trên Linux mặc định đòi xác thực RPC (Kerberos); hai máy không chung domain thì tắt
docker exec ecms-tram-cn02 /opt/mssql/bin/mssql-conf set distributedtransaction.turnoffrpcsecurity 1
docker restart ecms-tram-cn02
ipconfig getifaddr en0          # IP của máy này – dùng ở bước 2 (IP_MAC)
```

`WIN_HOST`, `WIN_IP` là tên và IP máy Windows (`$env:COMPUTERNAME`, `ipconfig`). macOS có thể hỏi cho phép Docker nhận kết
nối đến – chọn cho phép. Cảnh báo `could not create log file for mssql-conf` khi chạy `mssql-conf` là vô hại; thiết lập có
hiệu lực sau `docker restart`.

## 2. Máy Windows (PowerShell chạy bằng quyền Administrator)

```powershell
$IP_MAC = "192.168.1.168"       # ĐỔI thành IP máy thứ hai lấy ở bước 1 – -RemoteAddress chỉ nhận IP thật
# MSDTC nhận / gửi giao tác qua mạng; hai máy không chung domain nên không xác thực lẫn nhau
Set-DtcNetworkSetting -DtcName Local -AuthenticationLevel NoAuth -InboundTransactionsEnabled $true `
  -OutboundTransactionsEnabled $true -RemoteClientAccessEnabled $true -RemoteAdministrationAccessEnabled $false `
  -XATransactionsEnabled $false -LUTransactionsEnabled $true -Confirm:$false
Restart-Service MSDTC
# Tường lửa: chỉ mở cho đúng máy thứ hai (mạng Wi-Fi đang ở chế độ Public)
New-NetFirewallRule -DisplayName "ECMS demo – MSDTC" -Direction Inbound -Program "$env:SystemRoot\System32\msdtc.exe" `
  -RemoteAddress $IP_MAC -Action Allow -Profile Any
New-NetFirewallRule -DisplayName "ECMS demo – RPC 135" -Direction Inbound -Protocol TCP -LocalPort 135 `
  -RemoteAddress $IP_MAC -Action Allow -Profile Any
# MSDTC của Windows gọi sang trạm CN02 theo tên máy chủ của container
Add-Content "$env:SystemRoot\System32\drivers\etc\hosts" "`r`n$IP_MAC ecms-tram-cn02"
```

## 3. Chạy demo (máy Windows, sau khi đã chạy `13_distributed.sql`)

```powershell
# sqlcmd đọc biến script từ biến môi trường ("-v" không nhận giá trị có dấu phẩy như "IP,cổng")
$env:TRAM_CN02 = "$IP_MAC,14335"; $env:TRAM_CN02_MK = "Ecms@12345"
sqlcmd -S localhost\MSSQLSERVER01 -E -C -b -I -f 65001 -i database\13b_2pc_msdtc.sql
Get-DtcTransactionsStatistics      # số giao tác MSDTC đã cam kết / huỷ tăng thêm
```

Kết quả đo ngày 25/10/2026 (Windows 11 + SQL Server 2025 Developer ↔ macOS + SQL Server 2025 trong Docker, cùng Wi-Fi):
chuyển lớp cam kết ở cả hai máy với cùng một mã giao tác MSDTC (UOW) ở hai phía; lỗi CHECK ở trạm CN01 làm MSDTC huỷ
cả cập nhật đã làm ở trạm CN02; `Get-DtcTransactionsStatistics` tăng 2 giao tác cam kết, 1 giao tác huỷ.

## 4. Dọn sau khi demo

```powershell
Remove-NetFirewallRule -DisplayName "ECMS demo – MSDTC", "ECMS demo – RPC 135"
Set-DtcNetworkSetting -DtcName Local -AuthenticationLevel Mutual -InboundTransactionsEnabled $false `
  -OutboundTransactionsEnabled $false -RemoteClientAccessEnabled $false -Confirm:$false
# xoá dòng "… ecms-tram-cn02" trong C:\Windows\System32\drivers\etc\hosts
```

```bash
docker compose -f database/tram_cn02/docker-compose.yml down        # máy thứ hai
```
