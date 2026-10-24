<#
  Dựng lại toàn bộ CSDL ECMS trên Windows: chạy lần lượt các script 01 → 09.

    .\database\run_all.ps1                           # Windows Authentication, server localhost
    .\database\run_all.ps1 -Server ".\SQLEXPRESS"    # SQL Server Express
    .\database\run_all.ps1 -SqlLogin sa -Password "Ecms@12345"
    .\database\run_all.ps1 -Only 01,02

  Cần sqlcmd (cài kèm SSMS hoặc gói "sqlcmd" của Microsoft).
#>
param(
  [string]$Server = "localhost",
  [string]$SqlLogin = "",
  [string]$Password = "",
  [string[]]$Only = @()
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$files = @("01_schema","02_seed","03_functions","04_views","05_procedures","06_triggers","07_cursors","08_security","09_xml")
if ($Only.Count -gt 0) { $files = $Only }

$auth = if ($SqlLogin) { @("-U", $SqlLogin, "-P", $Password) } else { @("-E") }
$sw = [Diagnostics.Stopwatch]::StartNew()
# Chờ SQL Server sẵn sàng (tối đa 2 phút) – cần khi chạy ngay sau khi khởi động dịch vụ / container
$ready = $false
for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
  & sqlcmd -S $Server @auth -C -b -f 65001 -i (Join-Path $root "database\healthcheck.sql") -o NUL 2>$null
  if ($LASTEXITCODE -eq 0) { $ready = $true } else { Start-Sleep -Seconds 2 }
}
if (-not $ready) { throw "SQL Server chưa sẵn sàng sau 2 phút" }
foreach ($p in $files) {
  $matches = Get-ChildItem -Path (Join-Path $root "database") -Filter "$p*.sql" | Sort-Object Name
  if (-not $matches) { Write-Host "· bỏ qua $p (chưa có file)"; continue }
  foreach ($f in $matches) {
    Write-Host "▶ $($f.Name)"
    & sqlcmd -S $Server @auth -C -b -I -f 65001 -i $f.FullName
    if ($LASTEXITCODE -ne 0) { throw "Lỗi khi chạy $($f.Name)" }
  }
}
Write-Host "✓ Xong sau $([int]$sw.Elapsed.TotalSeconds) giây."
