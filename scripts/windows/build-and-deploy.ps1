<#
.SYNOPSIS
  Builds this Komga fork (both web UIs + server jar) and deploys it as the
  locally installed Komga server on Windows.

.DESCRIPTION
  1. Builds komga-webui and next-ui with npm.
  2. Copies the UI bundles into the backend and builds the Spring Boot jar.
  3. Stops the running "Komga" scheduled task (if any), copies the jar to
     %LOCALAPPDATA%\Programs\Komga-navigator\komga.jar and starts the task again.

  The server keeps its data in %LOCALAPPDATA%\Komga (same folder the official
  tray app uses) and listens on http://localhost:25600.

.PARAMETER SkipUi
  Skip the npm builds and reuse the existing dist folders (backend-only change).

.PARAMETER SkipDeploy
  Build only; do not touch the installed jar or the scheduled task.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\windows\build-and-deploy.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipUi,
  [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Komga-navigator'
$taskName = 'Komga'

# Make sure freshly installed tools (git, node, JDK) are visible even if this
# shell was opened before they were installed.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $env:JAVA_HOME) {
  $jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
}

function Invoke-Step($name, [scriptblock]$body) {
  Write-Host "==> $name" -ForegroundColor Cyan
  & $body
  if ($LASTEXITCODE -ne 0) { throw "$name failed with exit code $LASTEXITCODE" }
}

if (-not $SkipUi) {
  Push-Location (Join-Path $repo 'komga-webui')
  try {
    if (-not (Test-Path node_modules)) { Invoke-Step 'webui npm ci' { npm ci --no-audit --no-fund } }
    $env:NODE_OPTIONS = '--max-old-space-size=4096'
    Invoke-Step 'webui build' { npm run build }
  } finally { Pop-Location; Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue }

  Push-Location (Join-Path $repo 'next-ui')
  try {
    if (-not (Test-Path node_modules)) { Invoke-Step 'next-ui npm ci' { npm ci --no-audit --no-fund } }
    Invoke-Step 'next-ui build' { npm run build:with-i18n }
  } finally { Pop-Location }
}

Push-Location $repo
try {
  Invoke-Step 'gradle bootJar' { .\gradlew.bat :komga:webuiCopyIndex :komga:nextuiCopyIndex :komga:bootJar --console=plain }
} finally { Pop-Location }

$jar = Get-ChildItem (Join-Path $repo 'komga\build\libs') -Filter 'komga-*.jar' |
  Where-Object { $_.Name -notmatch '-plain\.jar$' } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $jar) { throw 'No komga jar found in komga\build\libs' }
Write-Host "Built $($jar.FullName) ($([math]::Round($jar.Length / 1MB)) MB)" -ForegroundColor Green

if ($SkipDeploy) { return }

New-Item -ItemType Directory -Force $installDir | Out-Null

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
  Write-Host "==> Stopping scheduled task '$taskName'" -ForegroundColor Cyan
  Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}
# Also stop any stray server started by hand from the install dir.
Get-CimInstance Win32_Process -Filter "Name = 'java.exe' OR Name = 'javaw.exe'" |
  Where-Object { $_.CommandLine -like "*$installDir*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3

Copy-Item $jar.FullName (Join-Path $installDir 'komga.jar') -Force
Write-Host "Deployed to $installDir\komga.jar" -ForegroundColor Green

if ($task) {
  Write-Host "==> Starting scheduled task '$taskName'" -ForegroundColor Cyan
  Start-ScheduledTask -TaskName $taskName
  Write-Host 'Komga is starting at http://localhost:25600' -ForegroundColor Green
} else {
  Write-Warning "Scheduled task '$taskName' does not exist. Run scripts\windows\install-service.ps1 once to create it."
}
