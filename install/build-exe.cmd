@echo off
setlocal
cd /d "%~dp0"
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
"%CSC%" /nologo /target:exe /codepage:65001 /optimize+ ^
 /out:dist\dsh-preset-kit-setup-1.1.91.exe ^
 /resource:dist\dsh-preset-kit-1.1.90.tgz,presetkitctl.payload.tgz ^
 /resource:tools\gateoff.mjs,presetkitctl.tools.gateoff.mjs ^
 /resource:tools\gateoff.cmd,presetkitctl.tools.gateoff.cmd ^
 src\Program.cs
echo build rc=%ERRORLEVEL%
