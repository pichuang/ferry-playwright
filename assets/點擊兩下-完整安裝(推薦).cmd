@echo off
chcp 65001 >nul
REM Double-clickable launcher for setup.ps1 (combined runtime + dev pack).
setlocal
set "SCRIPT_DIR=%~dp0"
echo Launching Playwright Offline combined setup...
echo (You will see a UAC prompt to grant Administrator rights.)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1" %*
echo.
echo Setup finished. Press any key to close this window.
pause >nul
endlocal
