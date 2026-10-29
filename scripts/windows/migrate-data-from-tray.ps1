<#
.SYNOPSIS
  One-time migration of library data from the official Komga tray app (MSIX
  package) to the folder the server-jar deployment uses.

.DESCRIPTION
  The tray app stores its data under the MSIX package's LocalCache folder:
    %LOCALAPPDATA%\Packages\Komga_fj8s550zp45ee\LocalCache\Local\Komga
  Uninstalling the package deletes that folder, so this script:
    1. stops the 'Komga' scheduled task (and any stray javaw) if present,
    2. copies the package data to %LOCALAPPDATA%\Komga-tray-backup-<date> (safety copy),
    3. mirrors the package data into %LOCALAPPDATA%\Komga (the new data dir),
    4. restarts the scheduled task and reports whether the server sees existing users.

  Run this from a normal PowerShell window (not from a sandboxed tool), AFTER
  quitting the tray app and BEFORE uninstalling it.
#>
[CmdletBinding()]
param(
  [string]$Source = (Join-Path $env:LOCALAPPDATA 'Packages\Komga_fj8s550zp45ee\LocalCache\Local\Komga'),
  [string]$Target = (Join-Path $env:LOCALAPPDATA 'Komga'),
  [string]$Backup = (Join-Path $env:LOCALAPPDATA ('Komga-tray-backup-' + (Get-Date -Format 'yyyy-MM-dd')))
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $Source 'database.sqlite'))) { throw "No database.sqlite found in $Source" }

Write-Host "==> Stopping any running Komga server" -ForegroundColor Cyan
if (Get-ScheduledTask -TaskName Komga -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName Komga -ErrorAction SilentlyContinue }
Get-Process -Name Komga, javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

Write-Host "==> Backing up $Source -> $Backup" -ForegroundColor Cyan
robocopy $Source $Backup /E /NFL /NDL /NP /NJH | Select-Object -Last 6
if ($LASTEXITCODE -ge 8) { throw "robocopy backup failed with code $LASTEXITCODE" }

Write-Host "==> Mirroring $Source -> $Target" -ForegroundColor Cyan
robocopy $Source $Target /MIR /NFL /NDL /NP /NJH | Select-Object -Last 6
if ($LASTEXITCODE -ge 8) { throw "robocopy mirror failed with code $LASTEXITCODE" }

Write-Host "==> Target now contains:" -ForegroundColor Cyan
Get-ChildItem $Target | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize

if (Get-ScheduledTask -TaskName Komga -ErrorAction SilentlyContinue) {
  Write-Host "==> Starting scheduled task 'Komga'" -ForegroundColor Cyan
  Start-ScheduledTask -TaskName Komga
  $claim = $null
  for ($i = 0; $i -lt 40 -and -not $claim; $i++) {
    Start-Sleep -Seconds 3
    try { $claim = (Invoke-WebRequest -Uri 'http://localhost:25600/api/v1/claim' -UseBasicParsing -TimeoutSec 5).Content } catch { }
  }
  Write-Host "Server claim status: $claim" -ForegroundColor Green
  if ($claim -match 'true') { Write-Host 'OK: the server is using the migrated database (existing users found).' -ForegroundColor Green }
  else { Write-Warning 'The server did not report existing users. Do not uninstall the tray app yet.' }
}
