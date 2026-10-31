@echo off
setlocal
chcp 65001 >nul
where pwsh.exe >nul 2>nul
if "%errorlevel%"=="0" (
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" %*
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" %*
)
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo Deinstallation wurde mit einem Fehler beendet.
if not "%UNDERZEE_NO_PAUSE%"=="1" pause
exit /b %result%
