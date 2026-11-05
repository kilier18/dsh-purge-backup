@echo off
rem One-click offline install of dsh-preset-kit into a DSH profile (default: desktop).
rem   install.cmd
rem   install.cmd -Profile work
setlocal EnableExtensions
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-offline.ps1" %*
echo.
pause