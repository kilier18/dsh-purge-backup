$ErrorActionPreference = 'Continue'
$root = if ($env:ROOT) { $env:ROOT } else { Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness' }
if (-not (Test-Path (Join-Path $root 'DeepSeek Harness.exe'))) { Write-Host "[!] DSH not found at $root"; exit 2 }
$exe  = Join-Path $root 'DeepSeek Harness.exe'
$res  = Join-Path $root 'resources'
$asar = Join-Path $res 'app.asar'
$bak  = Join-Path $res 'app.asar.dshpresetkit.bak'
$log  = Join-Path $env:TEMP 'dsh-preset-kit-manual-swap.log'

function Log([string]$m) {
  $line = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' ' + $m
  Write-Host $line
  try { Add-Content -LiteralPath $log -Value $line -Encoding UTF8 } catch {}
}

Log '=== start: switch desktop load path from app.asar to resources\app ==='

if (-not (Test-Path -LiteralPath $asar)) {
  Log 'app.asar not found - already switched, nothing to do.'
  exit 0
}
if (-not (Test-Path -LiteralPath (Join-Path $res 'app\package.json'))) {
  Log 'ABORT: resources\app\package.json missing - unpacked tree is not usable.'
  exit 1
}

$rootLow = $root.ToLower()
$all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
  $_.ExecutablePath -and $_.ExecutablePath.ToLower().StartsWith($rootLow)
})
$main = @($all | Where-Object {
  $_.ExecutablePath.ToLower() -eq $exe.ToLower() -and ($_.CommandLine -notmatch '--type=')
})
foreach ($p in $main) { Log ("kill main pid " + $p.ProcessId); Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 900
foreach ($p in $all) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 700

$free = $false
for ($i = 0; $i -lt 60; $i++) {
  try {
    $fs = [System.IO.File]::Open($asar, 'Open', 'ReadWrite', 'None')
    $fs.Close()
    $free = $true
    break
  } catch { Start-Sleep -Milliseconds 500 }
}
if (-not $free) { Log 'ABORT: app.asar still locked after 30s (some process holding it).'; exit 1 }

try {
  Rename-Item -LiteralPath $asar -NewName 'app.asar.dshpresetkit.bak' -ErrorAction Stop
  Log 'renamed app.asar -> app.asar.dshpresetkit.bak (rollback copy kept)'
} catch {
  Log ('ABORT: rename failed: ' + $_.Exception.Message)
  exit 1
}

Log 'launching desktop...'
Start-Process -FilePath $exe
Start-Sleep -Seconds 25

$alive = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
  $_.ExecutablePath -and $_.ExecutablePath.ToLower() -eq $exe.ToLower()
})
if ($alive.Count -eq 0) {
  Log 'WARN: desktop did not come up within 25s -> rolling back to app.asar'
  try {
    Rename-Item -LiteralPath $bak -NewName 'app.asar' -ErrorAction Stop
    Log 'rolled back: app.asar restored'
  } catch {
    Log ('rollback failed: ' + $_.Exception.Message + ' -> rename app.asar.dshpresetkit.bak back manually')
  }
  Start-Process -FilePath $exe
  exit 1
}

Log ('OK: desktop running from resources\app (pids: ' + ($alive.ProcessId -join ',') + ')')
Log '=== done ==='
exit 0