@echo off
rem Portable version of dsh-preset-kit-swap-to-app-dir.cmd
rem Switches the DSH desktop from resources\app.asar to the unpacked resources\app tree,
rem so host-side patches (dsh-preset-kit code layer) actually load.
rem
rem Usage:  swap-to-app-dir.cmd                 (auto-detect install dir)
rem         swap-to-app-dir.cmd "D:\Some\DeepSeek Harness"
setlocal EnableExtensions
chcp 65001 >nul
title dsh-preset-kit: switch desktop to resources\app

set "LOG=%TEMP%\dsh-preset-kit-manual-swap.log"

if not "%~1"=="" (
  set "ROOT=%~1"
) else (
  set "ROOT=%LOCALAPPDATA%\Programs\DeepSeek Harness"
)
if not exist "%ROOT%\DeepSeek Harness.exe" (
  echo [x] DeepSeek Harness.exe not found under: %ROOT%
  echo     pass the install dir as the first argument, e.g.
  echo     swap-to-app-dir.cmd "D:\Apps\DeepSeek Harness"
  pause
  exit /b 2
)

set "EXE=%ROOT%\DeepSeek Harness.exe"
set "ASAR=%ROOT%\resources\app.asar"
set "BAK=%ROOT%\resources\app.asar.dshpresetkit.bak"

call :log "=== start: switch load path app.asar -> resources\app ==="
call :log "root: %ROOT%"

if not exist "%ASAR%" (
  call :log "app.asar already gone - nothing to do"
  goto :end
)
if not exist "%ROOT%\resources\app\package.json" (
  call :log "ABORT: resources\app\package.json missing (unpacked tree unusable)"
  goto :end
)

taskkill /F /IM "DeepSeek Harness.exe" >nul 2>&1
call :log "desktop processes terminated"
timeout /t 3 /nobreak >nul

set /a tries=0
:retry
set /a tries+=1
move /y "%ASAR%" "%BAK%" >nul 2>&1
if errorlevel 1 (
  if %tries% geq 12 (
    call :log "ABORT: app.asar still locked after %tries% tries"
    goto :end
  )
  timeout /t 2 /nobreak >nul
  goto retry
)
call :log "renamed: app.asar -> app.asar.dshpresetkit.bak (rollback copy kept)"

start "" "%EXE%"
call :log "desktop relaunched, waiting 20s"
timeout /t 20 /nobreak >nul

tasklist /fi "imagename eq DeepSeek Harness.exe" | find /i "DeepSeek Harness.exe" >nul
if errorlevel 1 (
  call :log "WARN: desktop did not come up - rolling back to app.asar"
  move /y "%BAK%" "%ASAR%" >nul 2>&1
  start "" "%EXE%"
  call :log "rollback done, desktop relaunched"
  goto :end
)
call :log "OK: desktop is running from resources\app"

:end
call :log "=== done ==="
echo.
echo Log file: %LOG%
pause
exit /b 0

:log
echo %~1
>>"%LOG%" echo %date% %time% %~1
exit /b 0