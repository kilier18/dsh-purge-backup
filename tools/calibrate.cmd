@echo off
setlocal
set "ELECTRON_RUN_AS_NODE=1"
set "DSH_EXE=%LOCALAPPDATA%\Programs\DeepSeek Harness\DeepSeek Harness.exe"
if not exist "%DSH_EXE%" set "DSH_EXE=%ProgramFiles%\DeepSeek Harness\DeepSeek Harness.exe"
if not exist "%DSH_EXE%" (
  echo 没找到 DeepSeek Harness.exe
  exit /b 1
)
"%DSH_EXE%" "%~dp0calibrate.mjs" %*
