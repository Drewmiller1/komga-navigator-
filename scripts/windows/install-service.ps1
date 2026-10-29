<#
.SYNOPSIS
  One-time setup: registers a per-user scheduled task that starts the deployed
  Komga jar at logon (hidden, no console window) and starts it now.

.DESCRIPTION
  Expects the jar at %LOCALAPPDATA%\Programs\Komga-navigator\komga.jar
  (put there by build-and-deploy.ps1). Data lives in %LOCALAPPDATA%\Komga.
  Re-running this script replaces the existing task definition.

.PARAMETER ConfigDir
  Komga config/data directory. Defaults to %LOCALAPPDATA%\Komga.

.PARAMETER NoStart
  Register the task without starting it.
#>
[CmdletBinding()]
param(
  [string]$ConfigDir = (Join-Path $env:LOCALAPPDATA 'Komga'),
  [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$taskName = 'Komga'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Komga-navigator'
$jar = Join-Path $installDir 'komga.jar'
if (-not (Test-Path $jar)) { throw "Jar not found at $jar. Run build-and-deploy.ps1 first." }

$jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) { throw 'JDK 21 (Eclipse Temurin) not found under C:\Program Files\Eclipse Adoptium' }
$javaw = Join-Path $jdk.FullName 'bin\javaw.exe'

New-Item -ItemType Directory -Force $ConfigDir | Out-Null

# Note: do NOT wrap the config dir value in quotes. When launched by Task Scheduler the
# quotes reached Spring as part of the value and Komga silently started with an empty
# database elsewhere. Spaces in the path are therefore not supported here.
if ($ConfigDir -match '\s') { throw "ConfigDir '$ConfigDir' contains whitespace, which the scheduled task command line cannot pass safely." }
if ($jar -match '\s') { throw "Install path '$jar' contains whitespace, which the scheduled task command line cannot pass safely." }

$args = "--enable-native-access=ALL-UNNAMED -jar $jar --komga.config-dir=$ConfigDir"
$action = New-ScheduledTaskAction -Execute $javaw -Argument $args -WorkingDirectory $installDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
  -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Registered scheduled task '$taskName' (runs at logon as $env:USERNAME)" -ForegroundColor Green
Write-Host "  $javaw $args"

if (-not $NoStart) {
  Start-ScheduledTask -TaskName $taskName
  Write-Host 'Komga is starting at http://localhost:25600' -ForegroundColor Green
}
