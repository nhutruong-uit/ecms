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
